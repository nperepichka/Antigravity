[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$WorkspacePath
)

# ==============================================================================
# Antigravity IDE - Secondary Session Launcher
# Launches an isolated profile for secondary Google account / session authentication
# while dynamically synchronizing workspaces, chat history, settings & extensions.
# ==============================================================================

# 1. Discover Antigravity IDE Executable
$potentialExePaths = @(
    "$env:LOCALAPPDATA\Programs\Antigravity IDE\Antigravity IDE.exe",
    "C:\Program Files\Antigravity IDE\Antigravity IDE.exe",
    "$env:LOCALAPPDATA\Programs\Antigravity\Antigravity.exe",
    "C:\Program Files\Antigravity\Antigravity.exe"
)

$exePath = $null
foreach ($p in $potentialExePaths) {
    if (Test-Path -LiteralPath $p) {
        $exePath = $p
        break
    }
}

if (-not $exePath) {
    $proc = Get-Process -Name "Antigravity IDE", "Antigravity" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc -and $proc.Path) {
        $exePath = $proc.Path
    }
}

if (-not $exePath) {
    Write-Error "Could not find Antigravity IDE.exe. Please verify installation path."
    return
}

Write-Host "Detected executable: $exePath" -ForegroundColor DarkGray

# 2. Configure Profile Directories
$primaryRoot   = "$env:APPDATA\Antigravity IDE"
if (-not (Test-Path -LiteralPath $primaryRoot)) {
    $primaryRoot = "$env:APPDATA\Antigravity"
    $secondaryRoot = "$env:APPDATA\Antigravity - Secondary"
} else {
    $secondaryRoot = "$env:APPDATA\Antigravity IDE - Secondary"
}

$primaryUser            = Join-Path $primaryRoot "User"
$secondaryUser          = Join-Path $secondaryRoot "User"
$primaryGlobalStorage   = Join-Path $primaryUser "globalStorage"
$secondaryGlobalStorage = Join-Path $secondaryUser "globalStorage"
$primaryVscdb           = Join-Path $primaryGlobalStorage "state.vscdb"
$secondaryVscdb         = Join-Path $secondaryGlobalStorage "state.vscdb"
$extensionsDir          = "$env:USERPROFILE\.antigravity-ide\extensions"

# Ensure target directories exist
if (-not (Test-Path -LiteralPath $secondaryUser)) {
    New-Item -ItemType Directory -Path $secondaryUser -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $secondaryGlobalStorage)) {
    New-Item -ItemType Directory -Path $secondaryGlobalStorage -Force | Out-Null
}

# 3. Synchronize Preferences & Keybindings (Hardlinks with copy fallback)
$configFiles = @("settings.json", "keybindings.json", "tasks.json")
foreach ($file in $configFiles) {
    $srcFile = Join-Path $primaryUser $file
    $dstFile = Join-Path $secondaryUser $file

    if (Test-Path -LiteralPath $srcFile) {
        if (-not (Test-Path -LiteralPath $dstFile)) {
            try {
                New-Item -ItemType HardLink -Path $dstFile -Target $srcFile -Force -ErrorAction Stop | Out-Null
            } catch {
                Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force
            }
        }
    }
}

# Snippets junction
$srcSnippets = Join-Path $primaryUser "snippets"
$dstSnippets = Join-Path $secondaryUser "snippets"
if ((Test-Path -LiteralPath $srcSnippets) -and (-not (Test-Path -LiteralPath $dstSnippets))) {
    try {
        New-Item -ItemType Junction -Path $dstSnippets -Target $srcSnippets -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# 4. Synchronize VSCDB Workspace State & Trajectories (Protobuf & SQLite)
$libDir = Join-Path $PSScriptRoot "lib"
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1

if ($pythonCmd -and (Test-Path -LiteralPath $primaryVscdb)) {
    try {
        $vscdbTool = Join-Path $libDir "vscdb_tool.py"
        if (Test-Path -LiteralPath $vscdbTool) {
            $pyOutput = & $pythonCmd.Source $vscdbTool "sync-session" $primaryVscdb $secondaryVscdb 2>&1
            if ($pyOutput) {
                Write-Host $pyOutput -ForegroundColor Green
            }
        }
    } catch {
        Write-Warning "Could not synchronize state to secondary profile: $_"
    }
}

# 5. Launch Secondary Session
# Note: workspaceStorage is kept independent to prevent concurrent SQLite lock collisions.
# Extensions are shared via --extensions-dir, while global agent customizations
# (skills, rules, workflows in ~/.gemini/config/) and transcripts (~/.gemini/antigravity-ide/brain)
# are automatically accessible under the active Windows user profile.
$launchArgs = @(
    "--user-data-dir", "`"$secondaryRoot`"",
    "--extensions-dir", "`"$extensionsDir`""
)

if ($WorkspacePath) {
    if (Test-Path -LiteralPath $WorkspacePath) {
        $resolvedPath = (Resolve-Path -LiteralPath $WorkspacePath).Path
        $launchArgs += "`"$resolvedPath`""
    } else {
        $launchArgs += "`"$WorkspacePath`""
    }
}

Write-Host "Launching secondary Antigravity IDE session..." -ForegroundColor Cyan
Start-Process -FilePath $exePath -ArgumentList $launchArgs