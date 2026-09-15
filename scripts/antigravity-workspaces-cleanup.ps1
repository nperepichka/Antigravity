[CmdletBinding()]
param(
    [string]$BasePath = "$env:APPDATA\Antigravity IDE\User",
    [string[]]$AdditionalProfilePaths = @(),
    [switch]$SingleProfileOnly
)

# --- 0. Safety Check: Verify IDE Process ---
$runningProcs = Get-Process -Name "Antigravity IDE", "Antigravity" -ErrorAction SilentlyContinue
if ($runningProcs) {
    Write-Warning "Antigravity IDE is currently running ($($runningProcs.Count) process(es) detected)."
    Write-Warning "Running cleanup while the IDE is active can cause locked file errors and data overwrite upon IDE shutdown."
    $proceedAnyway = Read-Host "Do you want to continue anyway? (NOT recommended) (y/n)"
    if ($proceedAnyway -notmatch '^[Yy]$') {
        Write-Host "Operation cancelled. Please close Antigravity IDE and run this script again." -ForegroundColor Yellow
        return
    }
}

# Normalize BasePath if user passed AppData root without \User
if (Test-Path -LiteralPath (Join-Path $BasePath "User")) {
    $BasePath = Join-Path $BasePath "User"
}

# Profile registry to support multi-instance / multi-account profiles
$targetProfiles = [System.Collections.Generic.List[PSCustomObject]]::new()

function Register-Profile([string]$userDir, [string]$label) {
    if (-not $userDir -or -not (Test-Path -LiteralPath $userDir)) { return }
    $resolved = [System.IO.Path]::GetFullPath($userDir).TrimEnd('\', '/')
    foreach ($p in $targetProfiles) {
        if ($p.UserDir.Equals($resolved, [System.StringComparison]::OrdinalIgnoreCase)) {
            return
        }
    }
    $targetProfiles.Add([PSCustomObject]@{
        Name                = $label
        UserDir             = $resolved
        WorkspaceStorageDir = Join-Path $resolved "workspaceStorage"
        GlobalStorageDir    = Join-Path $resolved "globalStorage"
        GlobalStorageFile   = Join-Path $resolved "globalStorage\storage.json"
        GlobalVscdbFile     = Join-Path $resolved "globalStorage\state.vscdb"
        LocalHistoryDir     = Join-Path $resolved "History"
        BackupsDir          = Join-Path (Split-Path -Path $resolved -Parent) "Backups"
    })
}

# Register primary profile
if (Test-Path -LiteralPath $BasePath) {
    Register-Profile -userDir $BasePath -label "Primary (Antigravity IDE)"
}

if (-not $SingleProfileOnly) {
    # Check default secondary profile
    $secPath = "$env:APPDATA\Antigravity IDE - Secondary\User"
    if (Test-Path -LiteralPath $secPath) {
        Register-Profile -userDir $secPath -label "Secondary (Antigravity IDE - Secondary)"
    }

    # Discover any other custom profiles in APPDATA
    if ($env:APPDATA -and (Test-Path -Path $env:APPDATA)) {
        $otherProfileDirs = Get-ChildItem -Path $env:APPDATA -Directory -Filter "Antigravity IDE*" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne "Antigravity IDE" -and $_.Name -ne "Antigravity IDE - Secondary" }
        foreach ($d in $otherProfileDirs) {
            $uDir = Join-Path $d.FullName "User"
            if (Test-Path -LiteralPath $uDir) {
                Register-Profile -userDir $uDir -label "Profile ($($d.Name))"
            }
        }
    }

    # Register user-supplied profile paths
    foreach ($extraPath in $AdditionalProfilePaths) {
        if ($extraPath) {
            $resolvedExtra = if (Test-Path -LiteralPath (Join-Path $extraPath "User")) { Join-Path $extraPath "User" } else { $extraPath }
            Register-Profile -userDir $resolvedExtra -label "Custom ($([System.IO.Path]::GetFileName((Split-Path -Path $resolvedExtra -Parent))))"
        }
    }
}

if ($targetProfiles.Count -eq 0) {
    Write-Error "No valid Antigravity IDE profile directories found. Checked: $BasePath"
    return
}

Write-Host "Target Profile(s) for Cleanup ($($targetProfiles.Count)): " -ForegroundColor Cyan
foreach ($p in $targetProfiles) {
    Write-Host "  * $($p.Name): $($p.UserDir)" -ForegroundColor DarkGray
}

$BrainDir   = "$env:USERPROFILE\.gemini\antigravity-ide\brain"
$libDir     = Join-Path $PSScriptRoot "lib"
$pythonCmd  = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1

# --- Non-exported internal helper functions for path and URI canonicalization ---
function Normalize-Path([string]$uriString) {
    if (-not $uriString) { return $null }
    try {
        $decoded = [System.Uri]::UnescapeDataString($uriString)
        $u = [System.Uri]$decoded
        $path = $u.LocalPath
        if ($path -match '^/([a-zA-Z]:.*)$') {
            $path = $Matches[1]
        }
        return [System.IO.Path]::GetFullPath($path)
    } catch {
        return $uriString
    }
}

function Normalize-Uri([string]$uriString) {
    if (-not $uriString) { return $null }
    try {
        $p = Normalize-Path $uriString
        if ($p) {
            $u = [System.Uri]::new("file:///" + $p.Replace('\', '/'))
            return $u.AbsoluteUri
        }
    } catch {
        Write-Verbose "Could not normalize URI '$uriString': $_"
    }
    return $uriString.TrimEnd('/')
}

# Workspaces collection keyed by NormalizedUri or unique ID
$workspaces = [System.Collections.Generic.Dictionary[string, PSObject]]::new([System.StringComparer]::OrdinalIgnoreCase)

function Get-OrCreateWorkspaceItem([string]$key, [string]$rawUri, [string]$cleanPath, [string]$profileLabel) {
    if ([string]::IsNullOrWhiteSpace($key)) { return $null }
    if (-not $workspaces.ContainsKey($key)) {
        $name = if ($cleanPath -and -not $cleanPath.StartsWith("[")) {
            Split-Path -Path $cleanPath -Leaf
        } else {
            "[Untitled Session]"
        }
        $dispPath = if ($cleanPath) { $cleanPath } else { "[Path Missing / Ephemeral]" }

        $workspaces[$key] = [PSCustomObject]@{
            Key           = $key
            Ids           = [System.Collections.Generic.List[string]]::new()
            FolderPaths   = [System.Collections.Generic.List[string]]::new()
            RawUris       = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            Profiles      = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            NormalizedUri = if ($rawUri) { Normalize-Uri $rawUri } else { $null }
            Name          = $name
            Path          = $dispPath
            HasFolder     = $false
            InJson        = $false
        }
    }
    if ($rawUri) {
        [void]$workspaces[$key].RawUris.Add($rawUri)
    }
    if ($profileLabel) {
        [void]$workspaces[$key].Profiles.Add($profileLabel)
    }
    return $workspaces[$key]
}

# --- 1. Scan physical folders in workspaceStorage across target profiles ---
foreach ($prof in $targetProfiles) {
    if (Test-Path -LiteralPath $prof.WorkspaceStorageDir) {
        $folders = Get-ChildItem -LiteralPath $prof.WorkspaceStorageDir -Directory -ErrorAction SilentlyContinue
        foreach ($folder in $folders) {
            $id = $folder.Name
            $wsJsonPath = Join-Path $folder.FullName "workspace.json"
            $rawUri = $null
            $path = $null

            if (Test-Path -LiteralPath $wsJsonPath) {
                try {
                    $wsData = Get-Content -LiteralPath $wsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    $rawUri = if ($wsData.folder) { $wsData.folder } else { $wsData.workspace }
                    $path = Normalize-Path $rawUri
                } catch {
                    Write-Verbose "Failed to read/parse workspace.json at '$wsJsonPath': $_"
                }
            }

            $key = if ($rawUri) { Normalize-Uri $rawUri } else { "$($prof.Name)-untitled-$id" }
            $item = Get-OrCreateWorkspaceItem -key $key -rawUri $rawUri -cleanPath $path -profileLabel $prof.Name
            $item.Ids.Add($id)
            $item.FolderPaths.Add($folder.FullName)
            $item.HasFolder = $true
        }
    }
}

# --- 2. Read globalStorage/storage.json and state.vscdb across target profiles ---
foreach ($prof in $targetProfiles) {
    if (Test-Path -LiteralPath $prof.GlobalStorageFile) {
        try {
            $storageJson = Get-Content -LiteralPath $prof.GlobalStorageFile -Raw -Encoding UTF8 | ConvertFrom-Json

            # 2.1 Check profileAssociations.workspaces
            if ($storageJson.profileAssociations -and $storageJson.profileAssociations.workspaces) {
                foreach ($prop in $storageJson.profileAssociations.workspaces.PSObject.Properties) {
                    $uri = $prop.Name
                    $norm = Normalize-Uri $uri
                    $path = Normalize-Path $uri
                    $item = Get-OrCreateWorkspaceItem -key $norm -rawUri $uri -cleanPath $path -profileLabel $prof.Name
                    $item.InJson = $true
                }
            }

            # 2.2 Check backupWorkspaces
            if ($storageJson.backupWorkspaces) {
                if ($storageJson.backupWorkspaces.folders) {
                    foreach ($f in $storageJson.backupWorkspaces.folders) {
                        if ($f.folderUri) {
                            $norm = Normalize-Uri $f.folderUri
                            $path = Normalize-Path $f.folderUri
                            $item = Get-OrCreateWorkspaceItem -key $norm -rawUri $f.folderUri -cleanPath $path -profileLabel $prof.Name
                            $item.InJson = $true
                        }
                    }
                }
                if ($storageJson.backupWorkspaces.workspaces) {
                    foreach ($w in $storageJson.backupWorkspaces.workspaces) {
                        $wUri = if ($w.configURI) { $w.configURI } else { $w.id }
                        if ($wUri) {
                            $norm = Normalize-Uri $wUri
                            $path = Normalize-Path $wUri
                            $item = Get-OrCreateWorkspaceItem -key $norm -rawUri $wUri -cleanPath $path -profileLabel $prof.Name
                            $item.InJson = $true
                        }
                    }
                }
            }

            # 2.3 Legacy check for openedPathsList (older VS Code formats)
            $openedEntries = @()
            if ($storageJson.openedPathsList) {
                if ($storageJson.openedPathsList.entries) { $openedEntries += $storageJson.openedPathsList.entries }
                if ($storageJson.openedPathsList.workspaces3) { $openedEntries += $storageJson.openedPathsList.workspaces3 }
            }

            foreach ($entry in $openedEntries) {
                $uri = if ($entry.folderUri) { $entry.folderUri } elseif ($entry.workspace.configPath) { $entry.workspace.configPath } elseif ($entry -is [string]) { $entry } else { $entry.id }
                if (-not $uri) { continue }
                $norm = Normalize-Uri $uri
                $path = Normalize-Path $uri
                $item = Get-OrCreateWorkspaceItem -key $norm -rawUri $uri -cleanPath $path -profileLabel $prof.Name
                $item.InJson = $true
            }
        } catch {
            Write-Warning "Error reading $($prof.GlobalStorageFile): $_"
        }
    }

    # 2.4 Check Antigravity sidebarWorkspaces in SQLite state.vscdb
    if ($pythonCmd -and (Test-Path -LiteralPath $prof.GlobalVscdbFile)) {
        try {
            $vscdbTool = Join-Path $libDir "vscdb_tool.py"
            if (Test-Path -LiteralPath $vscdbTool) {
                $sbJson = & $pythonCmd.Source $vscdbTool "extract-workspaces" $prof.GlobalVscdbFile 2>$null
                if ($sbJson) {
                    $sbUris = $sbJson | ConvertFrom-Json
                    foreach ($sbUri in $sbUris) {
                        if ($sbUri) {
                            $norm = Normalize-Uri $sbUri
                            $path = Normalize-Path $sbUri
                            $item = Get-OrCreateWorkspaceItem -key $norm -rawUri $sbUri -cleanPath $path -profileLabel $prof.Name
                            $item.InJson = $true
                        }
                    }
                }
            }
        } catch {
            Write-Verbose "Failed to inspect sidebarWorkspaces in state.vscdb: $_"
        }
    }
}

if ($workspaces.Count -eq 0) {
    Write-Host "No workspaces found in any location." -ForegroundColor Green
    return
}

# --- 3. Build structured list ---
$workspaceEntries = foreach ($item in $workspaces.Values) {
    $cacheStatus = if ($item.HasFolder -and $item.InJson) { "OK (Folder + JSON)" }
    elseif ($item.HasFolder) { "Folder Only (Orphan)" }
    else { "JSON Only (Ghost)" }

    $projectExists = "Missing"
    if ($item.Path -and -not $item.Path.StartsWith("[")) {
        if (Test-Path -LiteralPath $item.Path) {
            $projectExists = "Exists"
        }
    }
    else {
        $projectExists = "Unknown"
    }

    $profilesLabel = if ($item.Profiles.Count -gt 0) { ($item.Profiles -join ", ") } else { "Unknown" }

    [PSCustomObject]@{
        Name          = $item.Name
        ProjectExists = $projectExists
        Path          = $item.Path
        Profiles      = $profilesLabel
        CacheStatus   = $cacheStatus
        FolderCount   = $item.FolderPaths.Count
        OriginalItem  = $item
    }
}

# --- GUI Selection Dialog with Checkboxes ---
function Show-WorkspaceSelectionDialog($items) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        $form = [System.Windows.Forms.Form]::new()
        $form.Text = "Antigravity IDE - Workspaces Cleanup"
        $form.Size = [System.Drawing.Size]::new(1000, 630)
        $form.MinimumSize = [System.Drawing.Size]::new(780, 450)
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        $form.Font = [System.Drawing.Font]::new("Segoe UI", 9)

        # Top search panel
        $topPanel = [System.Windows.Forms.Panel]::new()
        $topPanel.Dock = [System.Windows.Forms.DockStyle]::Top
        $topPanel.Height = 52
        $topPanel.Padding = [System.Windows.Forms.Padding]::new(12, 10, 12, 5)

        $lblSearch = [System.Windows.Forms.Label]::new()
        $lblSearch.Text = "Filter:"
        $lblSearch.AutoSize = $true
        $lblSearch.Location = [System.Drawing.Point]::new(14, 16)
        $lblSearch.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

        $txtSearch = [System.Windows.Forms.TextBox]::new()
        $txtSearch.Location = [System.Drawing.Point]::new(65, 13)
        $txtSearch.Size = [System.Drawing.Size]::new(380, 24)

        $lblHint = [System.Windows.Forms.Label]::new()
        $lblHint.Text = "(Check boxes on the left to select workspaces to purge)"
        $lblHint.AutoSize = $true
        $lblHint.Location = [System.Drawing.Point]::new(460, 16)
        $lblHint.ForeColor = [System.Drawing.Color]::Gray

        $topPanel.Controls.AddRange(@($lblSearch, $txtSearch, $lblHint))

        # Bottom buttons panel
        $bottomPanel = [System.Windows.Forms.Panel]::new()
        $bottomPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
        $bottomPanel.Height = 52

        $btnSelectAll = [System.Windows.Forms.Button]::new()
        $btnSelectAll.Text = "Select All"
        $btnSelectAll.Location = [System.Drawing.Point]::new(12, 10)
        $btnSelectAll.Size = [System.Drawing.Size]::new(90, 32)

        $btnSelectMissing = [System.Windows.Forms.Button]::new()
        $btnSelectMissing.Text = "Select 'Missing' Only"
        $btnSelectMissing.Location = [System.Drawing.Point]::new(110, 10)
        $btnSelectMissing.Size = [System.Drawing.Size]::new(150, 32)

        $btnDeselectAll = [System.Windows.Forms.Button]::new()
        $btnDeselectAll.Text = "Deselect All"
        $btnDeselectAll.Location = [System.Drawing.Point]::new(268, 10)
        $btnDeselectAll.Size = [System.Drawing.Size]::new(95, 32)

        $lblCount = [System.Windows.Forms.Label]::new()
        $lblCount.AutoSize = $true
        $lblCount.Location = [System.Drawing.Point]::new(375, 17)
        $lblCount.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $lblCount.ForeColor = [System.Drawing.Color]::DimGray

        $btnCancel = [System.Windows.Forms.Button]::new()
        $btnCancel.Text = "Cancel"
        $btnCancel.Size = [System.Drawing.Size]::new(90, 32)
        $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

        $btnOk = [System.Windows.Forms.Button]::new()
        $btnOk.Text = "OK"
        $btnOk.Size = [System.Drawing.Size]::new(95, 32)
        $btnOk.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

        # Reposition right buttons on resize
        $repositionRightButtons = {
            $btnCancel.Location = [System.Drawing.Point]::new($bottomPanel.Width - 200, 10)
            $btnOk.Location = [System.Drawing.Point]::new($bottomPanel.Width - 105, 10)
        }
        $bottomPanel.add_Resize($repositionRightButtons)

        $bottomPanel.Controls.AddRange(@($btnSelectAll, $btnSelectMissing, $btnDeselectAll, $lblCount, $btnCancel, $btnOk))

        # Center ListView with CheckBoxes
        $listView = [System.Windows.Forms.ListView]::new()
        $listView.View = [System.Windows.Forms.View]::Details
        $listView.CheckBoxes = $true
        $listView.FullRowSelect = $true
        $listView.GridLines = $true
        $listView.Dock = [System.Windows.Forms.DockStyle]::Fill

        [void]$listView.Columns.Add("Workspace Name", 185)
        [void]$listView.Columns.Add("Project On Disk", 105)
        [void]$listView.Columns.Add("Full Path", 340)
        [void]$listView.Columns.Add("Profiles", 130)
        [void]$listView.Columns.Add("Cache Status", 130)
        [void]$listView.Columns.Add("Cache Folders", 90)

        $allListViewItems = [System.Collections.Generic.List[System.Windows.Forms.ListViewItem]]::new()

        foreach ($entry in $items) {
            $lvi = [System.Windows.Forms.ListViewItem]::new($entry.Name)
            [void]$lvi.SubItems.Add($entry.ProjectExists)
            [void]$lvi.SubItems.Add($entry.Path)
            [void]$lvi.SubItems.Add($entry.Profiles)
            [void]$lvi.SubItems.Add($entry.CacheStatus)
            [void]$lvi.SubItems.Add($entry.FolderCount.ToString())
            $lvi.Tag = $entry.OriginalItem

            if ($entry.ProjectExists -eq "Missing") {
                $lvi.ForeColor = [System.Drawing.Color]::Firebrick
            }

            $allListViewItems.Add($lvi)
            [void]$listView.Items.Add($lvi)
        }

        $updateCountLabel = {
            $checkedCount = ($allListViewItems | Where-Object { $_.Checked }).Count
            $lblCount.Text = "Selected: $checkedCount of $($allListViewItems.Count)"
            if ($checkedCount -gt 0) {
                $btnOk.Text = "OK ($checkedCount)"
                $btnOk.BackColor = [System.Drawing.Color]::Firebrick
                $btnOk.ForeColor = [System.Drawing.Color]::White
            }
            else {
                $btnOk.Text = "OK"
                $btnOk.BackColor = [System.Drawing.SystemColors]::Control
                $btnOk.ForeColor = [System.Drawing.Color]::Black
            }
        }
        & $updateCountLabel

        $listView.add_ItemChecked({
            & $updateCountLabel
        })

        $btnSelectAll.add_Click({
            foreach ($lvi in $allListViewItems) { $lvi.Checked = $true }
            & $updateCountLabel
        })

        $btnDeselectAll.add_Click({
            foreach ($lvi in $allListViewItems) { $lvi.Checked = $false }
            & $updateCountLabel
        })

        $btnSelectMissing.add_Click({
            foreach ($lvi in $allListViewItems) {
                if ($lvi.SubItems[1].Text -eq "Missing") {
                    $lvi.Checked = $true
                }
            }
            & $updateCountLabel
        })

        $txtSearch.add_TextChanged({
            $filter = $txtSearch.Text.Trim()
            $listView.BeginUpdate()
            $listView.Items.Clear()
            if ([string]::IsNullOrWhiteSpace($filter)) {
                foreach ($lvi in $allListViewItems) {
                    [void]$listView.Items.Add($lvi)
                }
            }
            else {
                foreach ($lvi in $allListViewItems) {
                    $match = ($lvi.Text -like "*$filter*") -or ($lvi.SubItems[2].Text -like "*$filter*") -or ($lvi.SubItems[3].Text -like "*$filter*")
                    if ($match) {
                        [void]$listView.Items.Add($lvi)
                    }
                }
            }
            $listView.EndUpdate()
        })

        $btnOk.add_Click({
            $checked = @($allListViewItems | Where-Object { $_.Checked })
            if ($checked.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Please select at least one workspace to purge by checking its box on the left.",
                    "No Workspaces Selected",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
                return
            }
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        })

        $form.AcceptButton = $btnOk
        $form.CancelButton = $btnCancel

        $form.Controls.Add($listView)
        $form.Controls.Add($topPanel)
        $form.Controls.Add($bottomPanel)
        $topPanel.BringToFront()
        $bottomPanel.BringToFront()
        $listView.BringToFront()
        & $repositionRightButtons

        $result = $form.ShowDialog()

        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            return @($allListViewItems | Where-Object { $_.Checked } | ForEach-Object { $_.Tag })
        }
        return $null
    }
    catch {
        # Fallback to Out-GridView without exposing internal _Item
        Write-Warning "GUI Form unavailable, falling back to Out-GridView: $_"
        $map = @{}
        $gvList = foreach ($idx in 0..($items.Count - 1)) {
            $e = $items[$idx]
            $map[$idx] = $e.OriginalItem
            [PSCustomObject]@{
                "#"             = $idx + 1
                "Workspace"     = $e.Name
                "On Disk"       = $e.ProjectExists
                "Full Path"     = $e.Path
                "Profiles"      = $e.Profiles
                "Cache Status"  = $e.CacheStatus
                "Cache Folders" = $e.FolderCount
            }
        }
        $chosen = $gvList | Out-GridView -Title "Select workspaces TO PURGE (Hold Ctrl/Shift to multi-select, then click OK)" -OutputMode Multiple
        if ($chosen) {
            return @($chosen | ForEach-Object { $map[$_."#" - 1] })
        }
        return $null
    }
}

Write-Host "Opening selection window with checkboxes..." -ForegroundColor Cyan
$itemsToDelete = Show-WorkspaceSelectionDialog -items $workspaceEntries

if (-not $itemsToDelete -or $itemsToDelete.Count -eq 0) {
    Write-Host "Nothing selected. Operation cancelled." -ForegroundColor Yellow
    return
}

# --- 4. Confirmation Prompt ---
Write-Host "`nSelected for removal ($($itemsToDelete.Count) item(s)):" -ForegroundColor Magenta
$itemsToDelete | ForEach-Object { 
    $exists = if ($_.Path -and -not $_.Path.StartsWith("[")) {
        if (Test-Path -LiteralPath $_.Path) { "Exists" } else { "Missing" }
    }
    else { "Unknown" }
    $pInfo = if ($_.Profiles.Count -gt 0) { " [" + ($_.Profiles -join ", ") + "]" } else { "" }
    Write-Host " - [$exists] $($_.Name) -> $($_.Path)$pInfo (Cache folders: $($_.FolderPaths.Count))" 
}

$confirmation = Read-Host "`nAre you sure you want to permanently delete cache, JSON records, session backups, and local history? (y/n)"
if ($confirmation -notmatch '^[Yy]$') {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    return
}

# Collect all IDs, URIs, and path patterns targeted for removal
$idsToRemoveSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$urisToRemoveSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$validPathPrefixes = [System.Collections.Generic.List[string]]::new()
$purgePatterns = [System.Collections.Generic.List[string]]::new()
$preservePatterns = [System.Collections.Generic.List[string]]::new()

foreach ($target in $itemsToDelete) {
    foreach ($id in $target.Ids) {
        [void]$idsToRemoveSet.Add($id)
    }
    foreach ($uri in $target.RawUris) {
        [void]$urisToRemoveSet.Add($uri)
        $nUri = Normalize-Uri $uri
        if ($nUri) { [void]$urisToRemoveSet.Add($nUri) }
        $purgePatterns.Add($uri.ToLowerInvariant().TrimEnd('/'))
    }
    if ($target.NormalizedUri) {
        [void]$urisToRemoveSet.Add($target.NormalizedUri)
        $purgePatterns.Add($target.NormalizedUri.ToLowerInvariant().TrimEnd('/'))
    }
    if ($target.Path -and -not $target.Path.StartsWith("[")) {
        $pNorm = $target.Path.ToLowerInvariant().TrimEnd('\', '/')
        $validPathPrefixes.Add(($pNorm + '\'))
        $purgePatterns.Add($pNorm)
        $purgePatterns.Add($pNorm.Replace('\', '\\'))
        $purgePatterns.Add($pNorm.Replace('\', '/'))
        $purgePatterns.Add("file:///" + $pNorm.Replace('\', '/').Replace(':', '%3a'))
        $purgePatterns.Add("file:///" + $pNorm.Replace('\', '/'))
    }
}

# Preserved active workspaces patterns to prevent accidental session deletion
foreach ($w in $workspaces.Values) {
    if (-not $itemsToDelete.Contains($w)) {
        if ($w.Path -and -not $w.Path.StartsWith("[")) {
            $pNorm = $w.Path.ToLowerInvariant().TrimEnd('\', '/')
            $preservePatterns.Add($pNorm)
            $preservePatterns.Add($pNorm.Replace('\', '\\'))
            $preservePatterns.Add($pNorm.Replace('\', '/'))
            $preservePatterns.Add("file:///" + $pNorm.Replace('\', '/').Replace(':', '%3a'))
            $preservePatterns.Add("file:///" + $pNorm.Replace('\', '/'))
        }
        foreach ($u in $w.RawUris) {
            $preservePatterns.Add($u.ToLowerInvariant().TrimEnd('/'))
        }
    }
}

# --- 5. Clean globalStorage/storage.json across target profiles ---
foreach ($prof in $targetProfiles) {
    if (Test-Path -LiteralPath $prof.GlobalStorageFile) {
        try {
            $profStorageJson = Get-Content -LiteralPath $prof.GlobalStorageFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $backupPath = "$($prof.GlobalStorageFile).bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $prof.GlobalStorageFile -Destination $backupPath -Force
            Write-Host "`n[$($prof.Name)] Created backup of storage.json: $backupPath" -ForegroundColor DarkGray

            $modified = $false

            # 5.1 profileAssociations.workspaces
            if ($profStorageJson.profileAssociations -and $profStorageJson.profileAssociations.workspaces) {
                $propsToRemove = @()
                foreach ($prop in $profStorageJson.profileAssociations.workspaces.PSObject.Properties) {
                    $propNorm = Normalize-Uri $prop.Name
                    if ($urisToRemoveSet.Contains($prop.Name) -or ($propNorm -and $urisToRemoveSet.Contains($propNorm))) {
                        $propsToRemove += $prop.Name
                    }
                }
                foreach ($pName in $propsToRemove) {
                    $profStorageJson.profileAssociations.workspaces.PSObject.Properties.Remove($pName)
                    $modified = $true
                }
            }

            # 5.2 backupWorkspaces
            if ($profStorageJson.backupWorkspaces) {
                if ($profStorageJson.backupWorkspaces.folders) {
                    $origCount = $profStorageJson.backupWorkspaces.folders.Count
                    $profStorageJson.backupWorkspaces.folders = @($profStorageJson.backupWorkspaces.folders | Where-Object {
                        $n = Normalize-Uri $_.folderUri
                        -not ($urisToRemoveSet.Contains($_.folderUri) -or ($n -and $urisToRemoveSet.Contains($n)))
                    })
                    if ($profStorageJson.backupWorkspaces.folders.Count -ne $origCount) { $modified = $true }
                }

                if ($profStorageJson.backupWorkspaces.workspaces) {
                    $origCount = $profStorageJson.backupWorkspaces.workspaces.Count
                    $profStorageJson.backupWorkspaces.workspaces = @($profStorageJson.backupWorkspaces.workspaces | Where-Object {
                        $wUri = if ($_.configURI) { $_.configURI } else { $_.id }
                        $n = Normalize-Uri $wUri
                        -not ($urisToRemoveSet.Contains($wUri) -or ($n -and $urisToRemoveSet.Contains($n)))
                    })
                    if ($profStorageJson.backupWorkspaces.workspaces.Count -ne $origCount) { $modified = $true }
                }

                if ($profStorageJson.backupWorkspaces.emptyWindows) {
                    $origCount = $profStorageJson.backupWorkspaces.emptyWindows.Count
                    $profStorageJson.backupWorkspaces.emptyWindows = @($profStorageJson.backupWorkspaces.emptyWindows | Where-Object {
                        -not ($idsToRemoveSet.Contains($_.backupFolder))
                    })
                    if ($profStorageJson.backupWorkspaces.emptyWindows.Count -ne $origCount) { $modified = $true }
                }
            }

            # 5.3 windowsState
            if ($profStorageJson.windowsState) {
                if ($profStorageJson.windowsState.lastActiveWindow) {
                    $lawUri = $profStorageJson.windowsState.lastActiveWindow.folder
                    $lawNorm = Normalize-Uri $lawUri
                    if ($urisToRemoveSet.Contains($lawUri) -or ($lawNorm -and $urisToRemoveSet.Contains($lawNorm))) {
                        $profStorageJson.windowsState.PSObject.Properties.Remove("lastActiveWindow")
                        $modified = $true
                    }
                }
                if ($profStorageJson.windowsState.openedWindows) {
                    $origCount = $profStorageJson.windowsState.openedWindows.Count
                    $profStorageJson.windowsState.openedWindows = @($profStorageJson.windowsState.openedWindows | Where-Object {
                        $wUri = if ($_.folder) { $_.folder } else { $_.workspace.configPath }
                        $n = Normalize-Uri $wUri
                        -not ($urisToRemoveSet.Contains($wUri) -or ($n -and $urisToRemoveSet.Contains($n)))
                    })
                    if ($profStorageJson.windowsState.openedWindows.Count -ne $origCount) { $modified = $true }
                }
            }

            # 5.4 Legacy openedPathsList
            if ($profStorageJson.openedPathsList) {
                if ($profStorageJson.openedPathsList.workspaces3) {
                    $origCount = $profStorageJson.openedPathsList.workspaces3.Count
                    $profStorageJson.openedPathsList.workspaces3 = @($profStorageJson.openedPathsList.workspaces3 | Where-Object {
                        $u = if ($_ -is [string]) { $_ } else { $_.id }
                        $n = Normalize-Uri $u
                        -not ($urisToRemoveSet.Contains($u) -or ($n -and $urisToRemoveSet.Contains($n)))
                    })
                    if ($profStorageJson.openedPathsList.workspaces3.Count -ne $origCount) { $modified = $true }
                }
                if ($profStorageJson.openedPathsList.entries) {
                    $origCount = $profStorageJson.openedPathsList.entries.Count
                    $profStorageJson.openedPathsList.entries = @($profStorageJson.openedPathsList.entries | Where-Object {
                        $u = if ($_.folderUri) { $_.folderUri } else { $_.workspace.configPath }
                        $n = Normalize-Uri $u
                        -not ($urisToRemoveSet.Contains($u) -or ($n -and $urisToRemoveSet.Contains($n)))
                    })
                    if ($profStorageJson.openedPathsList.entries.Count -ne $origCount) { $modified = $true }
                }
            }

            if ($modified) {
                $jsonString = $profStorageJson | ConvertTo-Json -Depth 30
                [System.IO.File]::WriteAllText($prof.GlobalStorageFile, $jsonString, [System.Text.UTF8Encoding]::new($false))
                Write-Host "[$($prof.Name)] Records in storage.json updated successfully." -ForegroundColor Green
            } else {
                Write-Host "[$($prof.Name)] No matching records in storage.json found to remove." -ForegroundColor DarkGray
            }
        } catch {
            Write-Warning "[$($prof.Name)] Failed to update storage.json: $_"
        }
    }
}

# --- 6. Purge cache folders in workspaceStorage ---
$deletedFoldersCount = 0
foreach ($target in $itemsToDelete) {
    foreach ($fPath in $target.FolderPaths) {
        if (Test-Path -LiteralPath $fPath) {
            try {
                Remove-Item -LiteralPath $fPath -Recurse -Force -ErrorAction Stop
                $folderId = Split-Path -Path $fPath -Leaf
                Write-Host "Deleted workspace cache folder: $folderId" -ForegroundColor Green
                $deletedFoldersCount++
            } catch {
                Write-Error "Failed to delete folder $fPath : $_"
            }
        }
    }
}

# --- 7. Purge session recovery backups (Backups) across target profiles ---
foreach ($prof in $targetProfiles) {
    if (Test-Path -LiteralPath $prof.BackupsDir) {
        foreach ($id in $idsToRemoveSet) {
            if ($id -and $id -notlike "*untitled-*") {
                $backupSessionFolder = Join-Path $prof.BackupsDir $id
                if (Test-Path -LiteralPath $backupSessionFolder) {
                    try {
                        Remove-Item -LiteralPath $backupSessionFolder -Recurse -Force -ErrorAction Stop
                        Write-Host "[$($prof.Name)] Deleted session recovery backup: Backups\$id" -ForegroundColor Green
                    } catch {
                        Write-Warning "[$($prof.Name)] Failed to delete session backup ${backupSessionFolder}: $_"
                    }
                }
            }
        }
    }
}

# --- 8. Purge editor Local History files associated with workspaces across target profiles ---
if ($validPathPrefixes.Count -gt 0) {
    foreach ($prof in $targetProfiles) {
        if (Test-Path -LiteralPath $prof.LocalHistoryDir) {
            $deletedHistoryCount = 0
            $historyFolders = Get-ChildItem -LiteralPath $prof.LocalHistoryDir -Directory -ErrorAction SilentlyContinue
            foreach ($hFolder in $historyFolders) {
                $entryJson = Join-Path $hFolder.FullName "entries.json"
                if (Test-Path -LiteralPath $entryJson) {
                    try {
                        $entryData = Get-Content -LiteralPath $entryJson -Raw -Encoding UTF8 | ConvertFrom-Json
                        if ($entryData.resource) {
                            $resourcePath = Normalize-Path $entryData.resource
                            if ($resourcePath) {
                                $resLower = $resourcePath.ToLowerInvariant()
                                $matchedPrefix = $false
                                foreach ($prefix in $validPathPrefixes) {
                                    if ($resLower.StartsWith($prefix)) {
                                        $matchedPrefix = $true
                                        break
                                    }
                                }
                                if ($matchedPrefix) {
                                    Remove-Item -LiteralPath $hFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
                                    $deletedHistoryCount++
                                }
                            }
                        }
                    } catch {
                        Write-Verbose "Failed processing local history entry '$($hFolder.FullName)': $_"
                    }
                }
            }
            if ($deletedHistoryCount -gt 0) {
                Write-Host "[$($prof.Name)] Purged $deletedHistoryCount Local History entries associated with deleted workspaces." -ForegroundColor Green
            }
        }
    }
}

# --- 9. Purge associated AI Agent sessions in ~/.gemini/antigravity-ide/brain ---
$purgedBrainConvIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$deletedBrainBytes = 0
$deletedBrainCount = 0

if (Test-Path -LiteralPath $BrainDir) {
    $brainFolders = Get-ChildItem -LiteralPath $BrainDir -Directory -ErrorAction SilentlyContinue
    # Skip sessions with recent write activity (< 2 min) to protect active agent conversations
    $brainRecencyThreshold = (Get-Date).AddMinutes(-2)
    foreach ($bFolder in $brainFolders) {
        $convId = $bFolder.Name
        if ($bFolder.LastWriteTime -gt $brainRecencyThreshold) { continue }

        $files = Get-ChildItem -Path $bFolder.FullName -Recurse -File -ErrorAction SilentlyContinue
        $folderSize = ($files | Measure-Object -Property Length -Sum).Sum
        if (-not $folderSize) { $folderSize = 0 }

        $shouldPurge = $false

        $isOldEnough = $bFolder.LastWriteTime -lt (Get-Date).AddMinutes(-5)
        if ($isOldEnough -and ($files.Count -eq 0 -or ($files.Count -eq 1 -and $files[0].Name -eq "cursor.json"))) {
            $shouldPurge = $true
        }
        else {
            $matchedPreserve = $false
            $matchedPurge = $false

            foreach ($f in $files) {
                if ($f.Extension -in @(".jsonl", ".txt", ".log", ".md", ".json")) {
                    try {
                        $stream = [System.IO.File]::OpenRead($f.FullName)
                        try {
                            $bufSize = [Math]::Min(131072, [int]$stream.Length)
                            $buf = [byte[]]::new($bufSize)
                            [void]$stream.Read($buf, 0, $bufSize)
                            $text = [System.Text.Encoding]::UTF8.GetString($buf).ToLowerInvariant()
                        } finally {
                            $stream.Dispose()
                        }

                        foreach ($p in $preservePatterns) {
                            if ($text.Contains($p)) {
                                $matchedPreserve = $true
                                break
                            }
                        }
                        if ($matchedPreserve) { break }

                        foreach ($p in $purgePatterns) {
                            if ($text.Contains($p)) {
                                $matchedPurge = $true
                                break
                            }
                        }
                        if ($matchedPurge) { break }
                    } catch {
                        Write-Verbose "Failed reading file '$($f.FullName)': $_"
                    }
                }
            }

            if (-not $matchedPreserve -and $matchedPurge) {
                $shouldPurge = $true
            }
        }

        if ($shouldPurge) {
            try {
                Remove-Item -LiteralPath $bFolder.FullName -Recurse -Force -ErrorAction Stop
                [void]$purgedBrainConvIds.Add($convId)
                $deletedBrainCount++
                $deletedBrainBytes += $folderSize
            } catch {
                Write-Warning "Could not delete brain session $convId : $_"
            }
        }
    }

    if ($deletedBrainCount -gt 0) {
        $mb = [Math]::Round($deletedBrainBytes / 1MB, 2)
        Write-Host "Purged $deletedBrainCount AI Agent session(s) (~$mb MB) from brain ($BrainDir)." -ForegroundColor Green
    }
}

# --- 10. Opportunistic Cleanup of SQLite state.vscdb across target profiles ---
if ($pythonCmd) {
    try {
        $vscdbTool = Join-Path $libDir "vscdb_tool.py"
        if (Test-Path -LiteralPath $vscdbTool) {
            $payload = @{
                uris     = @($urisToRemoveSet)
                conv_ids = @($purgedBrainConvIds)
            }
            $payloadB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Compress)))

            foreach ($prof in $targetProfiles) {
                if (Test-Path -LiteralPath $prof.GlobalVscdbFile) {
                    try {
                        $vscdbBackup = "$($prof.GlobalVscdbFile).bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                        Copy-Item -LiteralPath $prof.GlobalVscdbFile -Destination $vscdbBackup -Force

                        Write-Host "`n[$($prof.Name)] Purging state.vscdb references..." -ForegroundColor Cyan
                        $pyOutput = & $pythonCmd.Source $vscdbTool "purge-workspaces" $prof.GlobalVscdbFile $payloadB64 2>&1
                        if ($pyOutput) {
                            Write-Host $pyOutput -ForegroundColor Green
                        }
                    } catch {
                        Write-Warning "[$($prof.Name)] Non-fatal error updating state.vscdb: $_"
                    }
                }
            }
        }
    } catch {
        Write-Warning "Non-fatal error preparing state.vscdb cleanup: $_"
    }
} else {
    Write-Host "Notice: Python not detected in PATH; skipping state.vscdb recent list cleanup (core cleanup is 100% complete)." -ForegroundColor DarkGray
}

Write-Host "`nWorkspace and session purge completed successfully!" -ForegroundColor Cyan