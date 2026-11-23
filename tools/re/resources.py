"""Print every player's resources (the stockpile ResList at [player+230h], each entry xored with its key at
0xC6DF14 + 4*i) and, for a player with a home city, its level [HC+54h], XP [HC+1F0h] and skill points
[HC+1F4h], once or every N seconds.

    python -I tools/re/resources.py --bed <game copy> [--every N] [--count K]

Resources: Gold 0, Wood 1, Food 2, Fame 3 (Wars of Liberty's oil), SkillPoints 4 (its faith with the
faithResource key), XP 5, Ships 6, Trade 7 (docs/engine-symbols.md, "Resource names").
"""
import argparse
import os
import pathlib
import struct
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import debugger as D  # noqa: E402

NAMES = ["gold", "wood", "food", "fame/oil", "skill/faith", "xp", "ships", "trade"]
KEYS = 0xC6DF14


def f32(raw):
    return struct.unpack("<f", struct.pack("<I", raw & 0xFFFFFFFF))[0]


def snapshot(proc):
    w = D.world(proc)
    if not w:
        return []
    players, count = proc.u32(w + 0x58), proc.i32(w + 0x5C)
    out = []
    for pid in range(max(0, min(count, 16))):
        p = proc.u32(players + 4 * pid)
        if not p:
            continue
        arr = proc.u32(p + 0x230)
        res = [f32(proc.u32(arr + 4 * i) ^ proc.u32(KEYS + 4 * i)) for i in range(8)] if arr else []
        hc = proc.u32(p + 0x84)
        hcinfo = (proc.i32(hc + 0x54), proc.i32(hc + 0x1F0), proc.i32(hc + 0x1F4)) if hc else None
        out.append((pid, res, hcinfo))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bed", required=True)
    ap.add_argument("--every", type=float, default=0)
    ap.add_argument("--count", type=int, default=1)
    a = ap.parse_args()
    import testbed  # noqa: E402  (finds the copy's process)
    testbed.BED = pathlib.Path(a.bed)
    proc = testbed.process()
    if proc is None:
        sys.exit("resources: the game of that copy is not running")
    for n in range(a.count):
        stamp = (testbed.game_time(proc) or 0) / 1000
        for pid, res, hc in snapshot(proc):
            line = " ".join(f"{NAMES[i]}={v:.2f}" for i, v in enumerate(res))
            hct = f" | HC level {hc[0]} xp {hc[1]} sp {hc[2]}" if hc else ""
            print(f"t={stamp:.1f} p{pid}: {line}{hct}")
        if n + 1 < a.count:
            time.sleep(a.every)


if __name__ == "__main__":
    main()
