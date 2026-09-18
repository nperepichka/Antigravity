"""
Antigravity VSCDB State Management Tool
Provides CLI subcommands to inspect and purge workspace & session records
stored in Antigravity IDE's SQLite state database (state.vscdb).
"""

import os
import sys
import json
import base64
import sqlite3

# --- Internal Protobuf Parser & Serializer ---

def parse_protobuf(data):
    """
    Parse raw protobuf byte stream into a list of (field_num, wire_type, val) tuples.
    Supports wire_type 0 (varint) and wire_type 2 (length-delimited).
    Guards against truncated data without raising IndexError.
    """
    i = 0
    records = []
    data_len = len(data) if data else 0
    while i < data_len:
        key = 0
        shift = 0
        while True:
            if i >= data_len:
                return records
            b = data[i]
            i += 1
            key |= (b & 0x7F) << shift
            shift += 7
            if not (b & 0x80):
                break
        field_num = key >> 3
        wire_type = key & 0x7
        if wire_type == 0:
            val = 0
            shift = 0
            while True:
                if i >= data_len:
                    return records
                b = data[i]
                i += 1
                val |= (b & 0x7F) << shift
                shift += 7
                if not (b & 0x80):
                    break
            records.append((field_num, wire_type, val))
        elif wire_type == 2:
            length = 0
            shift = 0
            while True:
                if i >= data_len:
                    return records
                b = data[i]
                i += 1
                length |= (b & 0x7F) << shift
                shift += 7
                if not (b & 0x80):
                    break
            if i + length > data_len:
                val = data[i:]
                i = data_len
            else:
                val = data[i:i + length]
                i += length
            records.append((field_num, wire_type, val))
        else:
            break
    return records


def serialize_varint(val):
    """
    Serialize an unsigned integer into protobuf varint bytes.
    Raises ValueError if val is negative.
    """
    if val < 0:
        raise ValueError(f"varint cannot be negative, got {val}")
    buf = bytearray()
    while val > 0x7F:
        buf.append((val & 0x7F) | 0x80)
        val >>= 7
    buf.append(val & 0x7F)
    return buf


def serialize_message(records):
    """
    Serialize a list of (field_num, wire_type, val) tuples into protobuf bytes.
    """
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
        print("  purge-workspaces <db_path> <payload_b64>")
        sys.exit(1)

    command = sys.argv[1].lower()

    if command == "extract-workspaces":
        if len(sys.argv) < 3:
            print("[]")
            sys.exit(1)
        extract_workspaces(sys.argv[2])
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
