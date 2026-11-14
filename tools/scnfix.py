"""Rename civs in a scenario's civ table, so a scenario saved with a civ the data no longer has loads.

Usage:
    python -I tools/scnfix.py <in.age3Yscn> <out.age3Yscn> OLD=NEW [OLD=NEW ...] [proto:OLD=NEW ...]

proto:OLD=NEW renames an entry of the saved proto table instead, so the units placed as a proto
the data no longer has load as NEW (same length rule).
--data=<game folder> player:NAME=CIV sets the civ of the player(s) named NAME to CIV of that
folder's civs.xml (a player's civ is stored as a number and is not re-mapped at load).

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
    for pair in argv[2:]:
        if pair.startswith("--data="):
            root = pair[7:]
            continue
        old, _, new = pair.partition("=")
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
    # The file ends with a CRC-32 (zlib's) of the whole file with those last 4 bytes zeroed; the
    # game refuses the scenario when it does not match (FUN_0082EAFD).
    body = b"l33t" + struct.pack("<I", len(raw)) + zlib.compress(bytes(raw), 9)
    crc = zlib.crc32(body + b"\0\0\0\0") & 0xFFFFFFFF
    dst.write_bytes(body + struct.pack("<I", crc))
    print(f"wrote {dst} ({len(raw)} bytes decompressed)")


if __name__ == "__main__":
    main(sys.argv[1:])
