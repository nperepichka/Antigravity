"""
Antigravity VSCDB State Management Tool
Provides CLI subcommands to inspect, synchronize, and purge workspace & session records
stored in Antigravity IDE's SQLite state database (state.vscdb).
"""

import os
import sys
import json
import base64
import sqlite3

# Ensure current lib directory is in sys.path for local module imports
_lib_dir = os.path.dirname(os.path.abspath(__file__))
if _lib_dir not in sys.path:
    sys.path.insert(0, _lib_dir)

from antigravity_protobuf import parse_protobuf, serialize_message


def extract_workspaces(db_path: str) -> None:
    """
    Extract workspace URIs from antigravityUnifiedStateSync.sidebarWorkspaces in state.vscdb.
    Outputs a JSON list of URIs to stdout.
    """
    if not os.path.isfile(db_path):
        print("[]")
        return

    try:
        conn = sqlite3.connect(f"file:{db_path}?immutable=1", uri=True)
        cur = conn.cursor()
        cur.execute("SELECT value FROM ItemTable WHERE key='antigravityUnifiedStateSync.sidebarWorkspaces'")
        row = cur.fetchone()
        uris = []
        if row and row[0]:
            raw = base64.b64decode(row[0])
            for f_num, w_type, val in parse_protobuf(raw):
                if w_type == 2:
                    for sf_num, sw_type, sval in parse_protobuf(val):
                        if sf_num == 1 and sw_type == 2:
                            uris.append(sval.decode('utf-8', errors='ignore'))
                            break
        print(json.dumps(uris))
        conn.close()
    except Exception:
        print("[]")


def sync_session(primary_db: str, secondary_db: str) -> None:
    """
    Synchronize workspace list, chat trajectories, recent files, and trust settings
    from primary state.vscdb to secondary state.vscdb without copying sensitive auth tokens.
    """
    if not os.path.isfile(primary_db):
        print(f"Warning: Primary database not found at '{primary_db}'.", file=sys.stderr)
        return

    # 1. Initial creation if secondary DB does not exist
    if not os.path.isfile(secondary_db):
        os.makedirs(os.path.dirname(secondary_db), exist_ok=True)
        p_conn = sqlite3.connect(f"file:{primary_db}?immutable=1", uri=True)
        s_conn = sqlite3.connect(secondary_db)
        p_conn.backup(s_conn)
        p_conn.close()

        s_cur = s_conn.cursor()
        s_cur.execute(
            "DELETE FROM ItemTable WHERE key IN ("
            "'antigravityUnifiedStateSync.oauthToken', "
            "'antigravity.profileUrl', "
            "'antigravityUnifiedStateSync.userStatus', "
            "'antigravity.userStatus', "
            "'google.antigravity'"
            ") OR key LIKE 'google.antigravity%'"
        )
        s_conn.commit()
        s_conn.close()
        print("Secondary session profile initialized from primary.")
        return

    # 2. Incremental merge into existing secondary DB
    p_conn = sqlite3.connect(f"file:{primary_db}?immutable=1", uri=True)
    s_conn = sqlite3.connect(secondary_db)
    p_cur = p_conn.cursor()
    s_cur = s_conn.cursor()

    keys = (
        'antigravityUnifiedStateSync.sidebarWorkspaces',
        'antigravityUnifiedStateSync.trajectorySummaries',
        'history.recentlyOpenedPathsList',
        'content.trust.model.key',
    )
    placeholders = ','.join('?' for _ in keys)

    p_cur.execute(f"SELECT key, value FROM ItemTable WHERE key IN ({placeholders})", keys)
    p_data = dict(p_cur.fetchall())
    p_conn.close()

    s_cur.execute(f"SELECT key, value FROM ItemTable WHERE key IN ({placeholders})", keys)
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
                        existing_uris.add(sv.decode('utf-8', errors='ignore'))
                        break

        added_sb = 0
        for f_num, w_type, val in p_recs:
            sub = parse_protobuf(val)
            uri = None
            for sf, sw, sv in sub:
                if sf == 1 and sw == 2:
                    uri = sv.decode('utf-8', errors='ignore')
                    break
            if uri and uri not in existing_uris:
                s_recs.append((f_num, w_type, val))
                existing_uris.add(uri)
                added_sb += 1

        if added_sb > 0 or not s_data.get('antigravityUnifiedStateSync.sidebarWorkspaces'):
            new_b64 = base64.b64encode(serialize_message(s_recs)).decode('ascii')
            s_cur.execute(
                "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('antigravityUnifiedStateSync.sidebarWorkspaces', ?)",
                (new_b64,),
            )
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
            s_cur.execute(
                "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('antigravityUnifiedStateSync.trajectorySummaries', ?)",
                (new_b64,),
            )
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
                if u:
                    s_uris.add(u.lower().rstrip('/'))

            added_recent = 0
            for e in p_json.get('entries', []):
                u = e.get('folderUri') or (e.get('workspace', {}).get('configPath')) or e.get('fileUri')
                if u and u.lower().rstrip('/') not in s_uris:
                    s_entries.append(e)
                    s_uris.add(u.lower().rstrip('/'))
                    added_recent += 1
            if added_recent > 0:
                s_json['entries'] = s_entries
                s_cur.execute(
                    "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('history.recentlyOpenedPathsList', ?)",
                    (json.dumps(s_json),),
                )
        except Exception:
            pass

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
                s_cur.execute(
                    "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('content.trust.model.key', ?)",
                    (json.dumps(s_trust),),
                )
        except Exception:
            pass

    s_conn.commit()
    s_conn.close()


def purge_workspaces(db_path: str, payload_b64: str) -> None:
    """
    Purge specified workspaces, conversation trajectories, and notifications from state.vscdb.
    """
    if not os.path.isfile(db_path):
        return

    try:
        payload = json.loads(base64.b64decode(payload_b64).decode('utf-8'))
    except Exception as ex:
        print(f"Error decoding purge payload: {ex}", file=sys.stderr)
        return

    uris_to_remove = set([u.lower().rstrip('/') for u in payload.get('uris', []) if u])
    for u in list(uris_to_remove):
        if '%3a' in u:
            uris_to_remove.add(u.replace('%3a', ':'))
        if ':' in u and '%3a' not in u:
            uris_to_remove.add(u.replace(':', '%3a'))

    conv_ids_to_remove = set([c.lower() for c in payload.get('conv_ids', []) if c])

    if not uris_to_remove and not conv_ids_to_remove:
        return

    try:
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()

        # 1. antigravityUnifiedStateSync.sidebarWorkspaces (Protobuf in Settings list)
        cur.execute("SELECT value FROM ItemTable WHERE key='antigravityUnifiedStateSync.sidebarWorkspaces'")
        row = cur.fetchone()
        if row and row[0]:
            raw = base64.b64decode(row[0])
            records = parse_protobuf(raw)
            new_records = []
            removed_sb = 0
            for f_num, w_type, val in records:
                sub = parse_protobuf(val)
                drop = False
                for sf_num, sw_type, sval in sub:
                    if sf_num == 1 and sw_type == 2:
                        u = sval.decode('utf-8', errors='ignore').lower().rstrip('/')
                        if u in uris_to_remove or sval.decode('utf-8', errors='ignore').lower() in uris_to_remove:
                            drop = True
                            break
                if drop:
                    removed_sb += 1
                    continue
                new_records.append((f_num, w_type, val))
            if removed_sb > 0:
                new_raw = serialize_message(new_records)
                new_b64 = base64.b64encode(new_raw).decode('ascii')
                cur.execute(
                    "UPDATE ItemTable SET value=? WHERE key='antigravityUnifiedStateSync.sidebarWorkspaces'",
                    (new_b64,),
                )
                print(f"Purged {removed_sb} workspace(s) from Antigravity sidebarWorkspaces (Settings list).")

        # 2. history.recentlyOpenedPathsList (JSON in Open Recent)
        cur.execute("SELECT value FROM ItemTable WHERE key='history.recentlyOpenedPathsList'")
        row = cur.fetchone()
        if row and row[0]:
            try:
                data = json.loads(row[0])
                orig_entries = data.get('entries', [])
                new_entries = []
                for e in orig_entries:
                    uri = e.get('folderUri') or (e.get('workspace', {}).get('configPath')) or e.get('fileUri')
                    if uri and (uri.lower().rstrip('/') in uris_to_remove or uri.lower() in uris_to_remove):
                        continue
                    new_entries.append(e)
                if len(new_entries) != len(orig_entries):
                    data['entries'] = new_entries
                    cur.execute(
                        "UPDATE ItemTable SET value=? WHERE key='history.recentlyOpenedPathsList'",
                        (json.dumps(data),),
                    )
                    print(f"Purged {len(orig_entries) - len(new_entries)} entry(ies) from recent opened list.")
            except Exception:
                pass

        # 3. content.trust.model.key (JSON trust info)
        cur.execute("SELECT value FROM ItemTable WHERE key='content.trust.model.key'")
        row = cur.fetchone()
        if row and row[0]:
            try:
                data = json.loads(row[0])
                orig = data.get('uriTrustInfo', [])
                new_t = [t for t in orig if (t.get('uri', {}).get('external', '').lower().rstrip('/') not in uris_to_remove)]
                if len(new_t) != len(orig):
                    data['uriTrustInfo'] = new_t
                    cur.execute(
                        "UPDATE ItemTable SET value=? WHERE key='content.trust.model.key'",
                        (json.dumps(data),),
                    )
                    print(f"Purged {len(orig) - len(new_t)} entry(ies) from workspace trust store.")
            except Exception:
                pass

        # 4. antigravityUnifiedStateSync.trajectorySummaries (Protobuf trajectory history)
        cur.execute("SELECT value FROM ItemTable WHERE key='antigravityUnifiedStateSync.trajectorySummaries'")
        row = cur.fetchone()
        if row and row[0]:
            raw = base64.b64decode(row[0])
            records = parse_protobuf(raw)
            new_records = []
            removed_traj = 0
            for f_num, w_type, val in records:
                sub = parse_protobuf(val)
                drop = False
                for sf_num, sw_type, sval in sub:
                    if sf_num == 1 and sw_type == 2:
                        cid = sval.decode('utf-8', errors='ignore').lower()
                        if cid in conv_ids_to_remove:
                            drop = True
                            break
                    elif sf_num == 2 and sw_type == 2:
                        sub_text = sval.decode('latin1', errors='ignore').lower()
                        for u in uris_to_remove:
                            if u in sub_text:
                                drop = True
                                break
                if drop:
                    removed_traj += 1
                    continue
                new_records.append((f_num, w_type, val))
            if removed_traj > 0:
                new_raw = serialize_message(new_records)
                new_b64 = base64.b64encode(new_raw).decode('ascii')
                cur.execute(
                    "UPDATE ItemTable SET value=? WHERE key='antigravityUnifiedStateSync.trajectorySummaries'",
                    (new_b64,),
                )
                print(f"Purged {removed_traj} trajectory summarie(s) from Antigravity session history.")

        # 5. antigravity.notification.agent-finished-* (Old agent notifications)
        removed_notifs = 0
        for cid in conv_ids_to_remove:
            cur.execute("DELETE FROM ItemTable WHERE key LIKE ?", (f"antigravity.notification.agent-finished-{cid}%",))
            if cur.rowcount and cur.rowcount > 0:
                removed_notifs += cur.rowcount
        if removed_notifs > 0:
            print(f"Purged {removed_notifs} agent notification(s) from state database.")

        conn.commit()
        conn.close()
    except Exception as ex:
        print(f"Warning updating state.vscdb: {ex}", file=sys.stderr)


def main():
    if len(sys.argv) < 2:
        print("Usage: vscdb_tool.py <command> [<args>...]")
        print("Commands:")
        print("  extract-workspaces <db_path>")
        print("  sync-session <primary_db> <secondary_db>")
        print("  purge-workspaces <db_path> <payload_b64>")
        sys.exit(1)

    command = sys.argv[1].lower()

    if command == "extract-workspaces":
        if len(sys.argv) < 3:
            print("[]")
            sys.exit(1)
        extract_workspaces(sys.argv[2])
    elif command == "sync-session":
        if len(sys.argv) < 4:
            print("Error: sync-session requires <primary_db> and <secondary_db>", file=sys.stderr)
            sys.exit(1)
        sync_session(sys.argv[2], sys.argv[3])
    elif command == "purge-workspaces":
        if len(sys.argv) < 4:
            print("Error: purge-workspaces requires <db_path> and <payload_b64>", file=sys.stderr)
            sys.exit(1)
        purge_workspaces(sys.argv[2], sys.argv[3])
    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
