"""Generate a random map many times in the scenario editor and count each player's Town Centers and
units, to find seeds and player counts where the map leaves a player without a start.

    python -I tools/mapstarts.py --bed <copy> --map <file name> [--players 2,4,6,8] [--seeds 1-20]
                                 [--teams 2] [--csv out.csv]

The copy must be at the main menu (testbed.py launch) with testbed.py's harness (perfExecFile). The
tool opens the editor once (startRandomGame(true)) and calls startRandomGame2(map, players, seed, "",
false, teams, 1, 0, false) for each run, without saving or loading a scenario, so a run takes about
10 s. A player "has no start" when it owns no Town Center and fewer than 3 units (the water flag
alone, for example). The game is left in the editor; `testbed.py close` ends it.
"""
import csv
import pathlib
import sys
import time

TOOLS = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(TOOLS / "re"))
import testbed as T  # noqa: E402

D = T.D


def arg(argv, name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


def numbers(text):
    out = []
    for part in text.split(","):
        if "-" in part:
            a, b = part.split("-")
            out += range(int(a), int(b) + 1)
        elif part:
            out.append(int(part))
    return out


def census(proc, players):
    tcs = {p: 0 for p in range(1, players + 1)}
    units = {p: 0 for p in range(1, players + 1)}
    for unit in D.units(proc):
        owner = D.unit_player(proc, unit)
        if owner in units:
            units[owner] += 1
            if D.proto_name(proc, proc.u32(unit + 0x5C)).lower() in ("towncenter", "coveredwagon"):
                tcs[owner] += 1
    return tcs, units


def main(argv):
    if "--bed" not in argv or "--map" not in argv:
        sys.exit(__doc__)
    bed = T.BED = T.bed_folder(arg(argv, "--bed"))
    name = arg(argv, "--map")
    players = numbers(arg(argv, "--players", "2,4,6,8"))
    seeds = numbers(arg(argv, "--seeds", "1-10"))
    teams = int(arg(argv, "--teams", "2"))
    out = pathlib.Path(arg(argv, "--csv", f"mapstarts-{name}.csv"))
    proc = T.process() or sys.exit("mapstarts: the game is not running")
    if not D.world(proc):
        T.run_commands(bed, ['config("DontPauseWhenLosingFocus")', "startRandomGame(true)"])
        T.wait_until(lambda: D.world(proc), 120, 1, "the scenario editor")
        time.sleep(5)
    new = not out.exists()
    with open(out, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["map", "players", "teams", "seed", "no_start", "tcs", "units"])
        for p in players:
            for s in seeds:
                T.run_commands(bed, [f'startRandomGame2("{name}", {p}, {s}, "", false, {teams}, 1, 0, false)'])
                time.sleep(4)
                last, steady = None, 0
                for _ in range(60):  # the map is done when the unit count stops changing
                    time.sleep(1)
                    now = sum(1 for _ in D.units(proc)) if D.world(proc) else 0
                    steady = steady + 1 if now == last and now > 0 else 0
                    last = now
                    if steady >= 3:
                        break
                tcs, units = census(proc, p)
                bad = [q for q in tcs if tcs[q] == 0 and units[q] < 3]
                w.writerow([name, p, teams, s, " ".join(map(str, bad)),
                            " ".join(f"p{q}:{tcs[q]}" for q in tcs), " ".join(f"p{q}:{units[q]}" for q in units)])
                f.flush()
                print(f"{name} p{p} s{s}: no start {bad or '-'}  TCs {tcs}", flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
