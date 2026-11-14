"""Rename civs in a scenario's civ table, so a scenario saved with a civ the data no longer has loads.

Usage:
    python -I tools/scnfix.py <in.age3Yscn> <out.age3Yscn> OLD=NEW [OLD=NEW ...] [proto:OLD=NEW ...]

proto:OLD=NEW renames an entry of the saved proto table instead, so the units placed as a proto
the data no longer has load as NEW (same length rule).
--data=<game folder> player:NAME=CIV sets the civ of the player(s) named NAME to CIV of that
folder's civs.xml (a player's civ is stored as a number and is not re-mapped at load).
unit:ID=PROTO gives the placed unit with that ID another proto of the scenario's saved proto
table. ID is the in-game ID (the EN record's, the one Trigger3\\trigtemp.xs uses); the triggers
stored in the scenario name the unit by its editor ID (its UN record's name), which
campaigncheck.py --inventory prints beside it (Laguna's Town Center: editor 1168, in game 647).
trigger:OLD=NEW replaces a proto name in trigger parameters (ProtoName, UnitType); tech:OLD=NEW
points tech parameters at another tech of the saved tech table. These two may change a value's
length: the trigger section ("TR") and root ("BG") chunk sizes are corrected.
trigger[PARAM]:OLD=NEW limits the rename to the parameters named PARAM (e.g. ProtoUnit, the
Change Unit Type target, against ProtoName, an Army Deploy's unit).
units:PLAYER:OLD=NEW gives every placed unit of player number PLAYER whose proto is OLD the proto
NEW (both in the saved proto table).
name:OLD=NEW renames the player(s) named OLD, and the team named "Team OLD".
homecity:PLAYER=FILE sets the home city file of the player(s) named PLAYER.
text:OLD=NEW replaces the text OLD, wherever it is a part of an objective's name, text or hint,
of the scenario's own name or description (the objectives chunk "OM"), or of a trigger text
parameter (chat, overlay, counters, unit and army names). Texts may change length: the chunks
that hold them get the difference (OM or BP or TE, then J1 and BG; or TR and BG).
@FILE reads more edits from FILE, one per line (UTF-8; a line starting with # is skipped), for
texts with spaces or many edits.

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
    for kind, old, new, only in edits:
        if kind == "tech":
            for n in (old, new):
                if n not in techs:
                    sys.exit(f"scnfix: tech {n} is not in the scenario's saved tech table")
            table.append(("tech", str(techs.index(old)), str(techs.index(new)), old, new, only))
        else:
            table.append(("proto", old, new, old, new, only))
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
            for kind, old, new, label_old, label_new, only in table:
                if value != old or (only and pname.lower() != only):
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


# ---------------------------------------------------------------- texts (name:, text:)
#
# Layout (observed in the three WoL missions; docs/wol-campaign.md, "Historical version: what was
# built"): the root "BG" chunk holds, among raw fields, "TR" (the triggers) and right after it
# "J1". J1 holds, directly, the player records ("BP", one per player, each followed by one byte),
# the team records ("TE": size, version, team number, the UTF-16 name) and the objectives chunk
# ("OM"). A text is a length (UTF-16 units) and the characters, so a text of another length moves
# the rest of the file: the chunks that hold it get the difference, and nothing else does.

def sections(raw):
    """(TR offset, J1 offset): TR is found from the triggers, J1 starts where TR ends."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import campaigncheck
    trig = campaigncheck.triggers(bytes(raw))
    if not trig:
        sys.exit("scnfix: no triggers found")
    first, last = trig[0][0], trig[-1][0]
    for p in range(first - 1, 6, -1):
        if raw[p:p + 2] == b"TR":
            size = struct.unpack_from("<I", raw, p + 2)[0]
            if p + 6 + size > last:
                j1 = p + 6 + size
                if raw[j1:j1 + 2] != b"J1":
                    sys.exit("scnfix: no J1 chunk after the triggers")
                return p, j1, trig
    sys.exit("scnfix: trigger section not found")


def chunk_end(raw, at):
    return at + 6 + struct.unpack_from("<I", raw, at + 2)[0]


def replace_text(raw, len_at, new, chunks, label):
    """Replaces the length-prefixed UTF-16 text at len_at and adds the length difference to the
    size of each chunk (header offsets, all before len_at)."""
    n = struct.unpack_from("<I", raw, len_at)[0]
    old = raw[len_at + 4:len_at + 4 + 2 * n].decode("utf-16le")
    raw[len_at:len_at + 4 + 2 * n] = struct.pack("<I", len(new)) + new.encode("utf-16le")
    delta = 2 * (len(new) - n)
    for at in chunks:
        assert at < len_at, (label, at, len_at)
        struct.pack_into("<I", raw, at + 2, struct.unpack_from("<I", raw, at + 2)[0] + delta)
    print(f"0x{len_at:x} {label}: {old!r} -> {new!r}")


def om_chunk(raw, j1):
    """The objectives chunk inside J1: tag, size, version, next ID, count."""
    end = chunk_end(raw, j1)
    for m in re.finditer(rb"OM(....)(....)(....)(....)", raw[j1:end], flags=re.S):
        size, ver, next_id, count = struct.unpack("<IIII", m.group(1) + m.group(2) + m.group(3) + m.group(4))
        at = j1 + m.start()
        if ver < 32 and 0 < count < 200 and count <= next_id < 1000 and at + 6 + size <= end:
            return at
    sys.exit("scnfix: no objectives chunk")


def om_texts(raw, om):
    """(length offset, text) of every length-prefixed UTF-16 text in the objectives chunk."""
    out = []
    body_end = chunk_end(raw, om)
    p = om + 6
    for m in re.finditer(rb"(?:[\x20-\xff]\x00)+", raw[p:body_end]):
        at = p + m.start()
        n = struct.unpack_from("<I", raw, at - 4)[0]
        if n and 2 * n <= len(m.group()):
            out.append((at - 4, raw[at:at + 2 * n].decode("utf-16le")))
    return out


def rename_player(raw, old, new):
    """Renames the player record(s) named OLD, and the team named "Team OLD"."""
    tr, j1, _ = sections(raw)
    want = old.encode("utf-16le")
    hits = []
    for m in re.finditer(rb"BP(....)(....)(....)(....)", raw, flags=re.S):
        n = struct.unpack_from("<I", m.group(4))[0]
        end = m.end() + 2 * n
        if n == len(old) and raw[m.end():end] == want and raw[end + 4:end + 8] == b"\xff\xff\xff\xff" \
                and j1 < m.start() < chunk_end(raw, j1):
            hits.append((m.start(), "BP"))
    team = ("Team " + old).encode("utf-16le")
    for m in re.finditer(rb"TE(....)(....)(....)(....)", raw, flags=re.S):
        n = struct.unpack_from("<I", m.group(4))[0]
        if n == len(old) + 5 and raw[m.end():m.end() + 2 * n] == team and j1 < m.start() < chunk_end(raw, j1):
            hits.append((m.start(), "TE"))
    if not any(k == "BP" for _, k in hits):
        sys.exit(f"scnfix: no player named {old}")
    for at, kind in sorted(hits, reverse=True):
        text = new if kind == "BP" else "Team " + new
        replace_text(raw, at + 14, text, [at, j1, 0], f"{kind} name")


def set_player_homecity(raw, player, new):
    """Sets the home city file of the player record(s) named PLAYER (the first homecity*.xml text
    of the record)."""
    _, j1, _ = sections(raw)
    want = player.encode("utf-16le")
    hits = 0
    for m in re.finditer(rb"BP(....)(....)(....)(....)", raw, flags=re.S):
        n = struct.unpack_from("<I", m.group(4))[0]
        end = m.end() + 2 * n
        if n != len(player) or raw[m.end():end] != want or not j1 < m.start() < chunk_end(raw, j1):
            continue
        bp_end = chunk_end(raw, m.start())
        h = re.search(rb"(?i)h\x00o\x00m\x00e\x00c\x00i\x00t\x00y\x00", raw[end:bp_end])
        if not h:
            sys.exit(f"scnfix: player {player} has no home city text")
        replace_text(raw, end + h.start() - 4, new, [m.start(), j1, 0], f"player {player} home city")
        hits += 1
    if not hits:
        sys.exit(f"scnfix: no player named {player}")


def edit_texts(raw, old, new):
    """Replaces the substring OLD by NEW in every objective text (names, texts, hints, the
    scenario's own name and description) and every trigger text parameter (type 22: chat,
    overlays, counters, unit names)."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    tr, j1, trig = sections(raw)
    om = om_chunk(raw, j1)
    hits = []
    for len_at, text in om_texts(raw, om):
        if old in text:
            hits.append((len_at, text.replace(old, new), [om, j1, 0], "objectives"))
    for off, ename, params in trig:
        for pname, disp, vtype, value, len_at in params:
            if vtype != 22 or value != "":
                continue
            q = len_at + 4
            n = struct.unpack_from("<I", raw, q)[0]
            text = raw[q + 4:q + 4 + 2 * n].decode("utf-16le", errors="replace")
            if old in text:
                hits.append((q, text.replace(old, new), [tr, 0], f"{ename}.{pname}"))
    if not hits:
        sys.exit(f"scnfix: no text contains {old!r}")
    for len_at, text, chunks, label in sorted(hits, key=lambda h: h[0], reverse=True):
        replace_text(raw, len_at, text, chunks, label)


def set_player_units(raw, player, old, new):
    """Gives every placed unit of PLAYER (a number) whose proto is OLD the proto NEW, both of the
    scenario's saved proto table."""
    protos = name_table(raw, 0)
    for p in (old, new):
        if p not in protos:
            sys.exit(f"scnfix: {p} is not in the scenario's saved proto table")
    a, b = protos.index(old), protos.index(new)
    n = 0
    for m in re.finditer(rb"H1(....)ENP\x00\x00\x00", raw, flags=re.S):
        uid, _, owner = struct.unpack_from("<iii", raw, m.end())
        if owner != player:
            continue
        end = m.start() + 6 + struct.unpack_from("<I", m.group(1))[0]
        u = raw.find(b"UN", m.end(), end)
        if u < 0:
            continue
        ln = struct.unpack_from("<I", raw, u + 6)[0]
        q = u + 10 + ln
        if struct.unpack_from("<II", raw, q) == (a, a):
            struct.pack_into("<II", raw, q, b, b)
            n += 1
    if not n:
        sys.exit(f"scnfix: player {player} has no placed {old}")
    print(f"player {player}: {n} placed {old} -> {new}")


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
    text_edits = []
    args = []
    for a in argv[2:]:
        if a.startswith("@"):  # a file of edits, one per line (UTF-8; # starts a comment)
            args += [ln.rstrip("\r\n") for ln in Path(a[1:]).read_text(encoding="utf-8").splitlines()
                     if ln.strip() and not ln.lstrip().startswith("#")]
        else:
            args.append(a)
    for pair in args:
        if pair.startswith("--data="):
            root = pair[7:]
            continue
        old, _, new = pair.partition("=")
        if old.startswith("name:") or old.startswith("text:"):
            text_edits.append((old[:4], old[5:], new))
            continue
        if old.startswith("units:"):
            _, pl, proto = old.split(":", 2)
            set_player_units(raw, int(pl), proto, new)
            continue
        if old.startswith("unit:"):
            set_unit_proto(raw, int(old[5:]), new)
            continue
        m = re.fullmatch(r"(trigger|tech)(?:\[(\w+)\])?:(.+)", old)
        if m:  # trigger[PARAM]:OLD=NEW limits the rename to the parameters named PARAM
            param_edits.append(("proto" if m[1] == "trigger" else "tech", m[3], new, (m[2] or "").lower()))
            continue
        if old.startswith("homecity:"):
            text_edits.append(("homecity", old[9:], new))
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
    for kind, old, new in text_edits:  # each one parses the file again
        if kind == "name":
            rename_player(raw, old, new)
        elif kind == "homecity":
            set_player_homecity(raw, old, new)
        else:
            edit_texts(raw, old, new)
    # The file ends with a CRC-32 (zlib's) of the whole file with those last 4 bytes zeroed; the
    # game refuses the scenario when it does not match (FUN_0082EAFD).
    body = b"l33t" + struct.pack("<I", len(raw)) + zlib.compress(bytes(raw), 9)
    crc = zlib.crc32(body + b"\0\0\0\0") & 0xFFFFFFFF
    dst.write_bytes(body + struct.pack("<I", crc))
    print(f"wrote {dst} ({len(raw)} bytes decompressed)")


if __name__ == "__main__":
    main(sys.argv[1:])
