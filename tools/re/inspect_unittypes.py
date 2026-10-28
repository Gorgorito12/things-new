"""Show how a running age3y.exe knows a unit type: its ID, and which protos carry it.

Usage:
    python -I tools/re/inspect_unittypes.py NAME [NAME ...] [--max N]
    python -I tools/re/inspect_unittypes.py --list-abstract

It only reads the game's memory (no debugger, no breakpoints), so it can run next to a
tracer. Use it from the main menu or during a game, once the data has loaded.

For each NAME (case-insensitive) it prints:
  - its unittype ID, and whether it is a proto or an abstract type;
  - for an abstract type, its bit in the per-proto bitset and up to N protos (default 40)
    that have the bit set, i.e. that list <UnitType>NAME</UnitType> in protoy.xml.
A name that is not in the table is not known to the engine: stock drops unknown <UnitType>
entries while loading. For a UHC marker such as AbstractHealNonIdle, check that UHC.log shows
"unit types: NAME -> ID".

Layout read (docs/engine-symbols.md, "Unit types and healing"):
    db = [[0xC66234]+0x140]
    name table at db+0x190: names [db+0x190] (one pointer to a UTF-16 string each),
                            count [db+0x194], IDs [db+0x19C]
    proto count [db+0x19B0]: IDs below it are protos, abstract types follow
    protos [db+0x54], count [db+0x58]; proto+0x10 name, proto+0x30 bitset, proto+0x34 bits
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import debugger as D  # noqa: E402


def name_table(proc, db):
    names_data, count = proc.u32(db + 0x190), proc.u32(db + 0x194)
    ids_data = proc.u32(db + 0x19C)
    if not names_data or not ids_data or not 0 < count < 100000:
        return []
    out = []
    for i in range(count):
        pointer = proc.u32(names_data + 4 * i)  # each name is a UTF-16 string
        out.append((proc.wstr(pointer, 96) if pointer else "", proc.i32(ids_data + 4 * i)))
    return out


def has_bit(proc, proto, bit):
    bits, nbits = proc.u32(proto + 0x30), proc.u32(proto + 0x34)
    if not bits or not 0 <= bit < nbits:
        return False
    byte = proc.read(bits + bit // 8, 1)
    return bool(byte and byte[0] >> (bit % 8) & 1)


def main(argv):
    limit = 40
    if "--max" in argv:
        i = argv.index("--max")
        limit = int(argv[i + 1])
        del argv[i:i + 2]
    if not argv:
        sys.exit(__doc__)
    pid = D.find_pid()
    if pid is None:
        sys.exit("age3y.exe is not running")
    proc = D.Process(pid)
    db = D.database(proc)
    table = name_table(proc, db) if db else []
    if not table:
        sys.exit("the game database is not loaded yet; try again from the main menu")
    proto_count = proc.u32(db + 0x19B0)
    protos_data, protos_n = proc.u32(db + 0x54), proc.u32(db + 0x58)
    protos = [proc.u32(protos_data + 4 * i) for i in range(protos_n)] if protos_data else []
    print(f"{len(table)} unittype names: {proto_count} protos, {len(table) - proto_count} abstract types")

    if argv == ["--list-abstract"]:
        for name, uid in table[proto_count:]:
            print(f"  {uid:5}  bit {uid - proto_count:4}  {name}")
        return

    by_name = {name.lower(): (name, uid) for name, uid in table}
    for wanted in argv:
        hit = by_name.get(wanted.lower())
        if hit is None:
            print(f"{wanted}: not in the unittype table (the engine does not know this name)")
            continue
        name, uid = hit
        if uid < proto_count:
            print(f"{name}: proto ID {uid}")
            continue
        bit = uid - proto_count
        carriers = [D.proto_name(proc, p) for p in protos if p and has_bit(proc, p, bit)]
        print(f"{name}: abstract type ID {uid}, bit {bit}; carried by {len(carriers)} protos")
        for proto in carriers[:limit]:
            print(f"    {proto}")
        if len(carriers) > limit:
            print(f"    ... and {len(carriers) - limit} more (use --max)")


if __name__ == "__main__":
    main(sys.argv[1:])
