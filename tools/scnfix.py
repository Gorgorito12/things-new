"""Rename civs in a scenario's civ table, so a scenario saved with a civ the data no longer has loads.

Usage:
    python -I tools/scnfix.py <in.age3Yscn> <out.age3Yscn> OLD=NEW [OLD=NEW ...] [proto:OLD=NEW ...]

proto:OLD=NEW renames an entry of the saved proto table instead, so the units placed as a proto
the data no longer has load as NEW (same length rule).
--data=<game folder> player:NAME=CIV sets the civ of the player(s) named NAME to CIV of that
folder's civs.xml (a player's civ is stored as a number and is not re-mapped at load).
unit:ID=PROTO gives the placed unit with that ID (the ID its triggers use) another proto of the
scenario's saved proto table.
trigger:OLD=NEW replaces a proto name in trigger parameters (ProtoName, UnitType); tech:OLD=NEW
points tech parameters at another tech of the saved tech table. These two may change a value's
length: the trigger section ("TR") and root ("BG") chunk sizes are corrected.

A scenario keeps a civ table: one "SH" chunk per civ the game had when it was saved (name, home
city file, default deck). When it loads, the game looks each name up in civs.xml and fails the
whole load ("Scenario: ... failed to load.") when one is missing (FUN_0085BA5E, called per record
by FUN_00831F90; docs/wol-campaign.md). Renaming such a record to a civ that civs.xml has, and
that the table does not already list, lets the scenario load.

NEW must have as many characters as OLD: the record keeps its size, so no chunk size changes.
The output is a new file as the game writes it ("l33t", the decompressed size, the zlib stream,
then the CRC-32 the game checks); the input is never written. Refuses a name that is not in exactly one civ record, and an output path equal to the input.
"""
import re
import struct
import sys
import zlib
from pathlib import Path


def civ_records(raw):
    """(offset of the name, name) of every SH civ record: tag, size, version 2, then the UTF-16 name."""
    out = []
    for m in re.finditer(rb"SH(....)\x02\x00\x00\x00(....)", raw, flags=re.S):
        size = struct.unpack_from("<I", m.group(1))[0]
        n = struct.unpack_from("<I", m.group(2))[0]
        if 100 < size < 0x100000 and 0 < n < 64:
            name = raw[m.end():m.end() + 2 * n].decode("utf-16le", errors="replace")
            out.append((m.end(), name))
    return out


def rename_proto(raw, old, new):
    """Renames one entry of the saved proto table ("PT", size, 0, count, then length-prefixed
    ASCII names); the placed units keep their table index, so they become NEW when loaded."""
    m = re.search(rb"PT(....)\x00\x00\x00\x00(....)", raw, flags=re.S)
    if not m:
        sys.exit("scnfix: no proto table")
    p, count, hits = m.end(), struct.unpack_from("<I", m.group(2))[0], []
    for _ in range(count):
        n = struct.unpack_from("<I", raw, p)[0]
        if raw[p + 4:p + 3 + n] == old.encode("latin-1"):
            hits.append(p + 4)
        p += 4 + n
    if len(hits) != 1:
        sys.exit(f"scnfix: proto {old} is in the proto table {len(hits)} times")
    raw[hits[0]:hits[0] + len(new)] = new.encode("latin-1")
    print(f"proto {old} -> {new} at 0x{hits[0]:x}")


def set_player_civ(raw, player, civ, root):
    """Sets the civ of every player record named PLAYER to CIV, by its ID now: 0 is Mother Nature,
    then the <civ> entries of <root>\\data\\civs.xml from 1 in file order. The game stores the ID
    as a number 17 bytes after the record's name and does not re-map it at load."""
    text = re.sub(r"<!--.*?-->", "", (Path(root) / "data" / "civs.xml").read_text(encoding="utf-8", errors="replace"),
                  flags=re.S)
    names = [re.search(r"<name>([^<]+)</name>", b).group(1).strip()
             for b in re.findall(r"<civ>(.*?)</civ>", text, flags=re.S | re.I)]
    if civ not in names:
        sys.exit(f"scnfix: {civ} is not a civ of {root}\\data\\civs.xml")
    civ_id = names.index(civ) + 1
    want = player.encode("utf-16le")
    hits = 0
    for m in re.finditer(rb"BP(....)(....)(....)(....)", raw, flags=re.S):
        n = struct.unpack_from("<I", m.group(4))[0]
        end = m.end() + 2 * n
        if n == len(player) and raw[m.end():end] == want and raw[end + 4:end + 8] == b"\xff\xff\xff\xff":
            old = struct.unpack_from("<i", raw, end + 17)[0]
            struct.pack_into("<i", raw, end + 17, civ_id)
            print(f"player {player}: civ {old} -> {civ_id} ({civ}) at 0x{end + 17:x}")
            hits += 1
    if not hits:
        sys.exit(f"scnfix: no player named {player}")


def name_table(raw, which):
    """(start, names) of a saved name table: which = 0 protos ("PT"), 2 techs (the second "TM")."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import campaigncheck
    tables = campaigncheck.name_tables(bytes(raw))
    return tables[which][2]


def set_unit_proto(raw, unit_id, proto):
    """Gives the placed unit with this ID (the ID triggers name) another proto of the saved proto
    table. A unit record is an H1 chunk: EN (size 0x50: the unit ID, ...) then UN (its name, then
    the proto's table index twice)."""
    protos = name_table(raw, 0)
    if proto not in protos:
        sys.exit(f"scnfix: {proto} is not in the scenario's saved proto table")
    idx = protos.index(proto)
    for m in re.finditer(rb"H1(....)ENP\x00\x00\x00", raw, flags=re.S):
        if struct.unpack_from("<i", raw, m.end())[0] != unit_id:
            continue
        end = m.start() + 6 + struct.unpack_from("<I", m.group(1))[0]
        u = raw.find(b"UN", m.end(), end)
        n, l = struct.unpack_from("<II", raw, u + 2)
        q = u + 10 + l
        old = struct.unpack_from("<I", raw, q)[0]
        struct.pack_into("<II", raw, q, idx, idx)
        print(f"unit {unit_id}: {protos[old]} -> {proto} at 0x{q:x}")
        return
    sys.exit(f"scnfix: no placed unit with ID {unit_id}")


def edit_trigger_params(raw, edits):
    """edits: [(kind, old, new)], kind 'proto' (ProtoName / unit type values) or 'tech' (tech
    names, stored as the saved table's index). Rewrites the matching parameter values; a value of
    another length moves the rest of the file, so the trigger section ("TR") and the root ("BG")
    sizes are corrected. Returns the new bytearray."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import campaigncheck
    techs = name_table(raw, 2)
    table = []
    for kind, old, new in edits:
        if kind == "tech":
            for n in (old, new):
                if n not in techs:
                    sys.exit(f"scnfix: tech {n} is not in the scenario's saved tech table")
            table.append(("tech", str(techs.index(old)), str(techs.index(new)), old, new))
        else:
            table.append(("proto", old, new, old, new))
    trig = campaigncheck.triggers(bytes(raw))
    if not trig:
        sys.exit("scnfix: no triggers found")
    first, last = trig[0][0], trig[-1][0]
    tr = None
    for p in range(first - 1, 6, -1):
        if raw[p:p + 2] == b"TR":
            size = struct.unpack_from("<I", raw, p + 2)[0]
            if p + 6 + size > last:
                tr = p
                break
    if tr is None:
        sys.exit("scnfix: trigger section not found")
    hits = []
    for off, ename, params in trig:
        for pname, disp, vtype, value, len_at in params:
            for kind, old, new, label_old, label_new in table:
                if value != old:
                    continue
                if kind == "tech" and not pname.lower().startswith("tech"):
                    continue
                if kind == "proto" and pname.lower() not in ("protoname", "unittype", "proto", "protounit"):
                    continue
                hits.append((len_at, old, new, f"{ename}.{pname}: {label_old} -> {label_new}"))
    if not hits:
        sys.exit("scnfix: no trigger parameter matched")
    delta = 0
    for len_at, old, new, label in sorted(hits, reverse=True):
        n = struct.unpack_from("<I", raw, len_at)[0]
        assert n == len(old), (label, n)
        raw[len_at:len_at + 4 + 2 * n] = struct.pack("<I", len(new)) + new.encode("utf-16le")
        delta += 2 * (len(new) - len(old))
        print(f"0x{len_at:x} {label}")
    for at in (tr, 0):
        size = struct.unpack_from("<I", raw, at + 2)[0]
        struct.pack_into("<I", raw, at + 2, size + delta)
    return raw


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    src, dst = Path(argv[0]), Path(argv[1])
    if src.resolve() == dst.resolve():
        sys.exit("scnfix: the output must be another file")
    blob = src.read_bytes()
    if blob[:4] != b"l33t":
        sys.exit(f"scnfix: {src} is not an l33t scenario")
    raw = bytearray(zlib.decompress(blob[8:]))
    records = civ_records(raw)
    names = [n for _, n in records]
    root = None
    param_edits = []
    for pair in argv[2:]:
        if pair.startswith("--data="):
            root = pair[7:]
            continue
        old, _, new = pair.partition("=")
        if old.startswith("unit:"):
            set_unit_proto(raw, int(old[5:]), new)
            continue
        if old.startswith("trigger:") or old.startswith("tech:"):
            kind, _, name = old.partition(":")
            param_edits.append(("proto" if kind == "trigger" else "tech", name, new))
            continue
        if old.startswith("player:"):
            if not root:
                sys.exit("scnfix: player:NAME=CIV needs --data=<game folder> before it")
            set_player_civ(raw, old[7:], new, root)
            continue
        is_proto = old.startswith("proto:")
        old = old[6:] if is_proto else old
        if len(old) != len(new):
            sys.exit(f"scnfix: {old} and {new} differ in length")
        if is_proto:
            rename_proto(raw, old, new)
            continue
        hits = [off for off, n in records if n == old]
        if len(hits) != 1:
            sys.exit(f"scnfix: {old} is in {len(hits)} civ records (table: {', '.join(names)})")
        if new in names:
            sys.exit(f"scnfix: {new} is already in the civ table")
        raw[hits[0]:hits[0] + 2 * len(new)] = new.encode("utf-16le")
        names[names.index(old)] = new
        print(f"{old} -> {new} at 0x{hits[0]:x}")
    if param_edits:  # last: they may move the rest of the file
        raw = edit_trigger_params(raw, param_edits)
    # The file ends with a CRC-32 (zlib's) of the whole file with those last 4 bytes zeroed; the
    # game refuses the scenario when it does not match (FUN_0082EAFD).
    body = b"l33t" + struct.pack("<I", len(raw)) + zlib.compress(bytes(raw), 9)
    crc = zlib.crc32(body + b"\0\0\0\0") & 0xFFFFFFFF
    dst.write_bytes(body + struct.pack("<I", crc))
    print(f"wrote {dst} ({len(raw)} bytes decompressed)")


if __name__ == "__main__":
    main(sys.argv[1:])
