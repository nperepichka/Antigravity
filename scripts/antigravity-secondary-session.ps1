[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [string]$WorkspacePath
)

# ==============================================================================
# Antigravity IDE - Secondary Session Launcher
# Launches an isolated profile for secondary Google account / session authentication
# with isolated workspace & chat history, while sharing customizations, settings & extensions.
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

$primaryUser   = Join-Path $primaryRoot "User"
$secondaryUser = Join-Path $secondaryRoot "User"
$extensionsDir = "$env:USERPROFILE\.antigravity-ide\extensions"

# Ensure target user profile directory exists
if (-not (Test-Path -LiteralPath $secondaryUser)) {
    New-Item -ItemType Directory -Path $secondaryUser -Force | Out-Null
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

# 4. Launch Secondary Session
# Note:
# - Workspace lists and chat trajectory history remain isolated between profiles to prevent
#   context cross-contamination and SQLite lock collisions across active accounts.
# - Agent customizations (skills, rules, workflows in ~/.gemini/config/ and project .agents/)
#   are shared natively across all sessions under the active Windows user profile.
# - Extensions are shared via --extensions-dir.
# - User preferences, keybindings, and snippets are shared via User/ directory links.
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