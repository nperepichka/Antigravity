"""
Antigravity Protobuf Utility Library
Provides parsing and serialization for Antigravity IDE internal protobuf data structures
stored in state.vscdb SQLite database (e.g. sidebarWorkspaces, trajectorySummaries).
"""

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
