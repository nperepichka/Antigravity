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
}
$secondaryRoot = "$env:APPDATA\Antigravity IDE - Secondary"

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
                Copy-Item -Path $srcFile -Destination $dstFile -Force -ErrorAction SilentlyContinue
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

# 4. Dynamic Pre-Launch SQLite State Synchronization (Option A)
# Reads primary state.vscdb non-destructively (immutable mode) and merges new
# workspaces, chat trajectories, and recent lists without touching secondary auth tokens.
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1

if ($pythonCmd -and (Test-Path -LiteralPath $primaryVscdb)) {
    try {
        $syncScript = @'
import sqlite3, json, sys, base64, os, shutil

primary_db = sys.argv[1]
secondary_db = sys.argv[2]

def parse_protobuf(data):
    i = 0; records = []
    while i < len(data):
        key = 0; shift = 0
        while True:
            b = data[i]; i += 1
            key |= (b & 0x7F) << shift; shift += 7
            if not (b & 0x80): break
        field_num = key >> 3; wire_type = key & 0x7
        if wire_type == 0:
            val = 0; shift = 0
            while True:
                b = data[i]; i += 1
                val |= (b & 0x7F) << shift; shift += 7
                if not (b & 0x80): break
            records.append((field_num, wire_type, val))
        elif wire_type == 2:
            length = 0; shift = 0
            while True:
                b = data[i]; i += 1
                length |= (b & 0x7F) << shift; shift += 7
                if not (b & 0x80): break
            val = data[i:i+length]; i += length
            records.append((field_num, wire_type, val))
        else: break
    return records

def serialize_varint(val):
    buf = bytearray()
    while val > 0x7F:
        buf.append((val & 0x7F) | 0x80)
        val >>= 7
    buf.append(val & 0x7F)
    return buf

def serialize_message(records):
    buf = bytearray()
    for field_num, wire_type, val in records:
        key = (field_num << 3) | wire_type
        buf.extend(serialize_varint(key))
        if wire_type == 0:
            buf.extend(serialize_varint(val))
        elif wire_type == 2:
            buf.extend(serialize_varint(len(val)))
            buf.extend(val)
    return bytes(buf)

# 1. Initial creation if secondary DB does not exist
if not os.path.isfile(secondary_db):
    os.makedirs(os.path.dirname(secondary_db), exist_ok=True)
    p_conn = sqlite3.connect(f"file:{primary_db}?immutable=1", uri=True)
    s_conn = sqlite3.connect(secondary_db)
    p_conn.backup(s_conn)
    p_conn.close()
    s_cur = s_conn.cursor()
    s_cur.execute("DELETE FROM ItemTable WHERE key IN ('antigravityUnifiedStateSync.oauthToken', 'antigravity.profileUrl', 'antigravityUnifiedStateSync.userStatus', 'antigravity.userStatus', 'google.antigravity') OR key LIKE 'google.antigravity%'")
    s_conn.commit()
    s_conn.close()
    print("Seeded secondary state database (credentials stripped).")
    sys.exit(0)

# 2. Dynamic Merge from primary (non-blocking immutable read)
p_conn = sqlite3.connect(f"file:{primary_db}?immutable=1", uri=True)
p_cur = p_conn.cursor()
p_cur.execute("SELECT key, value FROM ItemTable WHERE key IN ('antigravityUnifiedStateSync.sidebarWorkspaces', 'antigravityUnifiedStateSync.trajectorySummaries', 'history.recentlyOpenedPathsList', 'content.trust.model.key')")
p_data = dict(p_cur.fetchall())
p_conn.close()

s_conn = sqlite3.connect(secondary_db)
s_cur = s_conn.cursor()
s_cur.execute("SELECT key, value FROM ItemTable WHERE key IN ('antigravityUnifiedStateSync.sidebarWorkspaces', 'antigravityUnifiedStateSync.trajectorySummaries', 'history.recentlyOpenedPathsList', 'content.trust.model.key')")
s_data = dict(s_cur.fetchall())

# A. Merge sidebarWorkspaces (Protobuf)
if 'antigravityUnifiedStateSync.sidebarWorkspaces' in p_data:
    p_raw = base64.b64decode(p_data['antigravityUnifiedStateSync.sidebarWorkspaces'])
    p_recs = parse_protobuf(p_raw)
    s_recs = []
    existing_uris = set()
    if 'antigravityUnifiedStateSync.sidebarWorkspaces' in s_data and s_data['antigravityUnifiedStateSync.sidebarWorkspaces']:
        s_raw = base64.b64decode(s_data['antigravityUnifiedStateSync.sidebarWorkspaces'])
        s_recs = parse_protobuf(s_raw)
        for f_num, w_type, val in s_recs:
            sub = parse_protobuf(val)
            for sf, sw, sv in sub:
                if sf == 1 and sw == 2:
                    existing_uris.add(sv.decode('utf-8', errors='ignore').lower().rstrip('/'))
                    break

    added_sb = 0
    for f_num, w_type, val in p_recs:
        sub = parse_protobuf(val)
        uri = None
        for sf, sw, sv in sub:
            if sf == 1 and sw == 2:
                uri = sv.decode('utf-8', errors='ignore').lower().rstrip('/')
                break
        if uri and uri not in existing_uris:
            s_recs.append((f_num, w_type, val))
            existing_uris.add(uri)
            added_sb += 1

    if added_sb > 0 or not s_data.get('antigravityUnifiedStateSync.sidebarWorkspaces'):
        new_b64 = base64.b64encode(serialize_message(s_recs)).decode('ascii')
        s_cur.execute("INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('antigravityUnifiedStateSync.sidebarWorkspaces', ?)", (new_b64,))
        if added_sb > 0:
            print(f"Synced {added_sb} new workspace(s) to secondary sidebar.")

# B. Merge trajectorySummaries (Protobuf)
if 'antigravityUnifiedStateSync.trajectorySummaries' in p_data:
    p_raw = base64.b64decode(p_data['antigravityUnifiedStateSync.trajectorySummaries'])
    p_recs = parse_protobuf(p_raw)
    s_recs = []
    existing_cids = set()
    if 'antigravityUnifiedStateSync.trajectorySummaries' in s_data and s_data['antigravityUnifiedStateSync.trajectorySummaries']:
        s_raw = base64.b64decode(s_data['antigravityUnifiedStateSync.trajectorySummaries'])
        s_recs = parse_protobuf(s_raw)
        for f_num, w_type, val in s_recs:
            sub = parse_protobuf(val)
            for sf, sw, sv in sub:
                if sf == 1 and sw == 2:
                    existing_cids.add(sv.decode('utf-8', errors='ignore').lower())
                    break

    added_traj = 0
    for f_num, w_type, val in p_recs:
        sub = parse_protobuf(val)
        cid = None
        for sf, sw, sv in sub:
            if sf == 1 and sw == 2:
                cid = sv.decode('utf-8', errors='ignore').lower()
                break
        if cid and cid not in existing_cids:
            s_recs.append((f_num, w_type, val))
            existing_cids.add(cid)
            added_traj += 1

    if added_traj > 0 or not s_data.get('antigravityUnifiedStateSync.trajectorySummaries'):
        new_b64 = base64.b64encode(serialize_message(s_recs)).decode('ascii')
        s_cur.execute("INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('antigravityUnifiedStateSync.trajectorySummaries', ?)", (new_b64,))
        if added_traj > 0:
            print(f"Synced {added_traj} conversation trajectory(ies) to secondary session.")

# C. Merge recentlyOpenedPathsList (JSON)
if 'history.recentlyOpenedPathsList' in p_data:
    try:
        p_json = json.loads(p_data['history.recentlyOpenedPathsList'])
        s_json = json.loads(s_data.get('history.recentlyOpenedPathsList', '{"entries":[]}'))
        s_entries = s_json.get('entries', [])
        s_uris = set()
        for e in s_entries:
            u = e.get('folderUri') or (e.get('workspace', {}).get('configPath')) or e.get('fileUri')
            if u: s_uris.add(u.lower().rstrip('/'))

        added_recent = 0
        for e in p_json.get('entries', []):
            u = e.get('folderUri') or (e.get('workspace', {}).get('configPath')) or e.get('fileUri')
            if u and u.lower().rstrip('/') not in s_uris:
                s_entries.append(e)
                s_uris.add(u.lower().rstrip('/'))
                added_recent += 1
        if added_recent > 0:
            s_json['entries'] = s_entries
            s_cur.execute("INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('history.recentlyOpenedPathsList', ?)", (json.dumps(s_json),))
    except Exception: pass

# D. Merge content.trust.model.key (JSON)
if 'content.trust.model.key' in p_data:
    try:
        p_trust = json.loads(p_data['content.trust.model.key'])
        s_trust = json.loads(s_data.get('content.trust.model.key', '{"uriTrustInfo":[]}'))
        s_uris = set([t.get('uri', {}).get('external', '').lower().rstrip('/') for t in s_trust.get('uriTrustInfo', [])])
        added_t = 0
        for t in p_trust.get('uriTrustInfo', []):
            ext = t.get('uri', {}).get('external', '').lower().rstrip('/')
            if ext and ext not in s_uris:
                s_trust.setdefault('uriTrustInfo', []).append(t)
                s_uris.add(ext)
                added_t += 1
        if added_t > 0:
            s_cur.execute("INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('content.trust.model.key', ?)", (json.dumps(s_trust),))
    except Exception: pass

s_conn.commit()
s_conn.close()
'@
        $pyOutput = $syncScript | & $pythonCmd.Source - $primaryVscdb $secondaryVscdb 2>&1
        if ($pyOutput) {
            Write-Host $pyOutput -ForegroundColor Green
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