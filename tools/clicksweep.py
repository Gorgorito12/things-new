"""Click every kind of unit of a skirmish, as a player would, and watch for a crash: made for the "NEW"
Levant crash hunt (#78), where players reported crashes "after or when clicking on trade units or
guardians".

    python -I tools/clicksweep.py --bed <copy> --out <dir> --map NEWLevant --players 6 --teams
           [--ffa] [--ai wolOtto,wolVictoria,...] [--difficulty 3] [--minutes 12] [--per-proto 3]
           [--label TEXT] [--no-trading-post] [--no-debugger]

What one run does (a copy at the main menu or closed; the skirmish route of tools/mapsweep.py, so the
profile, the home cities and the AI personalities are backed up and restored byte for byte):
  1. starts the skirmish (player 1 is the profile's human, idle; the AIs play), with re/debugger.py's
     crash watch attached, and reveals the map (console `fog()` and `blackmap()`), since a unit under
     the black map cannot be clicked;
  2. builds a Trading Post on the trade route socket nearest player 1's Town Center (a settler or the
     explorer in build mode, `tis("TradingPost")`, a posted click on the socket; when wood is short,
     player 1's settlers gather the nearest wood and it tries again), so trade units exist;
  3. puts player 1's explorer and settlers in number group 8;
  4. clicks units in passes until --minutes of game time: per unit, the camera on it
     (`uiLookAtUnit`), a posted left click at its place (select), a posted double click plus
     `uiDoubleClickSelect(0)` (select all of its kind on screen), then group 8 selected and a posted
     right click on it (gather, attack, garrison, trade or build, whatever the
     game makes of it). Each pass takes every unit whose name looks special (trade, camel, caravan,
     nugget, guard, socket, native, wagon, Trading Post) and up to --per-proto units of each other
     proto and player; trees and props at most 2 per proto;
  5. keeps the game running to --minutes, then closes it.
Writes <out>/<tag>.clicks.csv (one row per unit clicked), <tag>.summary.json (counts per proto and per
player, the result: ok, crash with the crash watch's report, hang), shots in <out>/shots/, and the
engine-ext log lines of the run. Exit code 0 ok, 3 crash, 4 hang, 1 other.
"""
import csv
import ctypes
import json
import pathlib
import re
import struct
import sys
import time

TOOLS = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import mapsweep as MS  # noqa: E402

T = MS.T
D = T.D
user32 = ctypes.windll.user32

SPECIAL = re.compile(r"trad|camel|caravan|nugget|guard|socket|native|wagon|treasure|pirate|bandit|outlaw"
                     r"|bhakti|sufi|village|merc", re.I)
SCENERY = re.compile(r"^(tree|underbrush|prop|rock|bush|grass|cliff|terrain|fx|ambient|bird|cloud)|tree|prop", re.I)
SKIP = re.compile(r"^(HomeCityWaterSpawnFlag|SPC|Revealer|AIPlaceholder|Target$|Bat$|CinematicBlock|NativeTownObstruction"
                  r"|RT_Bone|WOL_RT_Bone)", re.I)  # not drawn or not clickable
WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_LBUTTONUP, WM_LBUTTONDBLCLK = 0x200, 0x201, 0x202, 0x203
WM_RBUTTONDOWN, WM_RBUTTONUP = 0x204, 0x205
# Player 1's villagers: WoL's Dutch start with DutchSettler, JavaneseLabourer and AfricanSlaveBrit.
VILLAGER = re.compile(r"settler|labou?rer|slave|villager|coolie|peasant|serf|immigrant", re.I)
CENTRE = (0.49, 0.47)  # where uiLookAtUnit puts a unit, in window fractions (testbed's CROP_CENTRE)


def say(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


def arg(argv, name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


# --- input --------------------------------------------------------------------------------------

def centre():
    rc = T.RECT()
    user32.GetClientRect(T.window(), ctypes.byref(rc))
    return int(rc.right * CENTRE[0]), int(rc.bottom * CENTRE[1])


def post(msg, wparam, x, y):
    user32.PostMessageW(T.window(), msg, wparam, (y & 0xFFFF) << 16 | (x & 0xFFFF))


def left_click(x, y):
    post(WM_MOUSEMOVE, 0, x, y)
    time.sleep(0.05)
    post(WM_LBUTTONDOWN, 1, x, y)
    time.sleep(0.05)
    post(WM_LBUTTONUP, 0, x, y)


def double_click(x, y):
    left_click(x, y)
    time.sleep(0.05)
    post(WM_LBUTTONDBLCLK, 1, x, y)
    time.sleep(0.05)
    post(WM_LBUTTONUP, 0, x, y)


def right_click(x, y):
    post(WM_MOUSEMOVE, 0, x, y)
    time.sleep(0.05)
    post(WM_RBUTTONDOWN, 2, x, y)
    time.sleep(0.05)
    post(WM_RBUTTONUP, 0, x, y)


# --- the world ----------------------------------------------------------------------------------

def live_units(proc):
    out = []
    for u in D.units(proc):
        hp = proc.f32(u + 0x64)
        if not hp or hp <= 0:
            continue
        x, _y, z = struct.unpack("<fff", proc.read(u + 0x14, 12) or b"\0" * 12)
        out.append({"id": proc.u32(u + 0x10), "player": D.unit_player(proc, u),
                    "proto": D.proto_name(proc, proc.u32(u + 0x5C)), "hp": hp, "x": x, "z": z})
    return out


def minutes(proc):
    return (T.game_time(proc) or 0) / 60000


def nearest(units, x, z):
    return min(units, key=lambda u: (u["x"] - x) ** 2 + (u["z"] - z) ** 2) if units else None


class Run:
    def __init__(self, bed, out, tag, per_proto):
        self.bed, self.out, self.tag, self.per_proto = bed, out, tag, per_proto
        self.rows, self.clicked = [], set()
        self.csv = out / f"{tag}.clicks.csv"

    def cmd(self, *commands):
        T.run_commands(self.bed, list(commands), timeout=90)

    def shot(self, name):
        MS.testbed(self.bed, "shot", str(self.out / "shots" / f"{self.tag}.{name}.png"), "4", timeout=60)

    # -- the Trading Post
    def trading_post(self, proc, tries=4):
        for attempt in range(1, tries + 1):
            units = live_units(proc)
            mine = [u for u in units if u["player"] == 1]
            if any(u["proto"].lower() == "tradingpost" for u in mine):
                say("trading post: player 1 has one")
                return True
            tc = next((u for u in mine if u["proto"].lower() == "towncenter"), None)
            # A socket another player has already built on is taken: "Other objects prevent you from placing
            # this here" (an AI took the socket nearest player 1 within 2 minutes in the first run).
            posts = [u for u in units if "tradingpost" in u["proto"].lower()]
            sockets = [u for u in units if u["proto"].lower() == "sockettraderoute"
                       and not any((p["x"] - u["x"]) ** 2 + (p["z"] - u["z"]) ** 2 < 36 for p in posts)]
            builders = [u for u in mine if VILLAGER.search(u["proto"])] or [u for u in mine if "explorer" in u["proto"].lower()]
            if not (tc and sockets and builders):
                say(f"trading post: no town center, socket or builder (try {attempt})")
                return False
            socket = nearest(sockets, tc["x"], tc["z"])
            builder = nearest(builders, socket["x"], socket["z"])
            x, y = centre()
            self.cmd("uiClearSelection()", f"uiLookAtAndSelectUnit({builder['id']})", f"uiLookAtUnit({socket['id']})")
            time.sleep(0.5)
            post(WM_MOUSEMOVE, 0, x, y)
            self.cmd('tis("TradingPost")')
            time.sleep(0.5)
            left_click(x, y)
            time.sleep(4)
            if any(u["proto"].lower() == "tradingpost" and u["player"] == 1 for u in live_units(proc)):
                say(f"trading post: placed on socket {socket['id']} by {builder['proto']} {builder['id']}")
                self.shot("tradingpost")
                return True
            # Short of wood: every settler gathers the wood nearest to it, then try again.
            woods = [u for u in units if u["player"] == 0 and re.search(r"tree|crateofwood", u["proto"], re.I)]
            for s in [u for u in mine if VILLAGER.search(u["proto"])][:8]:
                w = nearest(woods, s["x"], s["z"])
                if w:
                    self.cmd("uiClearSelection()", f"uiLookAtAndSelectUnit({s['id']})", f"uiLookAtUnit({w['id']})")
                    time.sleep(0.3)
                    right_click(x, y)
            say(f"trading post: not placed (try {attempt}); settlers sent to gather wood")
            T.wait_game_time(30)
        return False

    def group(self, proc):
        mine = [u for u in live_units(proc) if u["player"] == 1]
        ids = [u["id"] for u in mine if VILLAGER.search(u["proto"]) or "explorer" in u["proto"].lower()][:5]
        if ids:
            self.cmd(*T.select_commands(ids), "uiCreateNumberGroup(8)", "uiClearSelection()")
        say(f"group 8: {len(ids)} units of player 1")

    # -- one pass
    def pass_units(self, proc, pass_no):
        units = live_units(proc)
        seen, picks = {}, []
        for u in sorted(units, key=lambda u: (u["id"] in self.clicked, u["id"])):
            if SKIP.match(u["proto"]):
                continue
            special = bool(SPECIAL.search(u["proto"]))
            cap = 10 ** 6 if special else 2 if SCENERY.search(u["proto"]) else self.per_proto
            key = (u["player"], u["proto"])
            if seen.get(key, 0) >= cap:
                continue
            seen[key] = seen.get(key, 0) + 1
            picks.append((0 if special else 1, u))
        # Specials first (trade, guardians, nuggets, natives), then the others round robin over (player, proto),
        # so a pass that the clock cuts short has still touched every player: the first run's single pass spent
        # its 12 minutes on Gaia (105 clicks, 65 of them special).
        special = [u for s, u in picks if s == 0]
        groups = {}
        for s, u in picks:
            if s:
                groups.setdefault((u["player"], u["proto"]), []).append(u)
        rest, k = [], 0
        while any(groups.values()):
            for key in list(groups):
                if len(groups[key]) > k:
                    rest.append(groups[key][k])
            k += 1
            if all(len(v) <= k for v in groups.values()):
                break
        # interleave: one special, one other, so both kinds are reached early
        picks = [u for pair in zip(special, rest) for u in pair] + special[len(rest):] + rest[len(special):]
        say(f"pass {pass_no}: {len(picks)} of {len(units)} live units")
        with open(self.out / f"{self.tag}.pass{pass_no}.units.txt", "w", encoding="utf-8") as f:
            for u in units:  # every live unit as the pass starts, so a crash's unit and its neighbours are known
                f.write(f"{u['id']}\t{u['player']}\t{u['proto']}\t{u['hp']:.0f}\t{u['x']:.1f}\t{u['z']:.1f}\n")
        return picks

    def click(self, proc, u, pass_no):
        x, y = centre()
        t0 = T.game_time(proc)
        if t0 != getattr(self, "last_ms", None):
            self.last_ms, self.last_moved = t0, time.time()
        elif time.time() - self.last_moved > 90:  # the clock stands still: ended, paused or stuck
            T.hung("the clicks", f"the world clock stood at {t0} ms for 90 s")
        # Two console round trips per unit (each waits for perfExecFile's next read): the camera, then the
        # double-click selection and group 8. The posted right click is the order (it sent villagers to
        # gather in the first run), so uiWorkAtPointer is no longer sent as well.
        # The unit at hand, written before anything is sent: after a crash it names the last unit clicked.
        self.current = dict(u, pass_no=pass_no, game_ms=t0)
        self.cmd(f"uiLookAtUnit({u['id']})")
        time.sleep(0.25)
        left_click(x, y)
        time.sleep(0.3)
        double_click(x, y)
        time.sleep(0.2)
        self.cmd("uiDoubleClickSelect(0)", "uiSelectNumberGroup(8)")
        time.sleep(0.2)
        right_click(x, y)
        time.sleep(0.2)
        row = {"pass": pass_no, "game_ms": t0, "id": u["id"], "player": u["player"], "proto": u["proto"],
               "hp": round(u["hp"], 1), "x": round(u["x"], 1), "z": round(u["z"], 1),
               "special": int(bool(SPECIAL.search(u["proto"])))}
        self.rows.append(row)
        self.clicked.add(u["id"])
        new = not self.csv.exists()
        with open(self.csv, "a", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, list(row))
            if new:
                w.writeheader()
            w.writerow(row)


def main(argv):
    if "--bed" not in argv or "--out" not in argv or "--map" not in argv:
        sys.exit(__doc__)
    bed = T.BED = T.bed_folder(arg(argv, "--bed"))
    out = pathlib.Path(arg(argv, "--out")).resolve()
    (out / "shots").mkdir(parents=True, exist_ok=True)
    map_name = arg(argv, "--map")
    players = int(arg(argv, "--players", "6"))
    total = float(arg(argv, "--minutes", "12"))
    ai = arg(argv, "--ai", "wolOtto").split(",")
    opts = {"mode": "teams" if "--teams" in argv else "ffa" if "--ffa" in argv else None,
            "difficulty": arg(argv, "--difficulty")}
    label = arg(argv, "--label", f"{opts['mode'] or 'setup'}-d{opts['difficulty'] or 'p'}")
    tag = re.sub(r"[^\w.-]+", "_", f"{map_name}-p{players}-{label}")
    if T.bed_pid():
        sys.exit(f"clicksweep: a game already runs in {bed}; close it first")
    game = MS.Game(bed, out, "--no-debugger" not in argv)
    state = MS.SkirmishState(bed, ai)
    log = T.log_path(bed)
    log_at = MS.size(log)
    summary = {"map": map_name, "players": players, "mode": opts["mode"], "difficulty": opts["difficulty"],
               "ai": ai, "started": time.strftime("%Y-%m-%d %H:%M:%S"), "result": "?"}
    run = Run(bed, out, tag, int(arg(argv, "--per-proto", "3")))
    code = 1
    try:
        state.__enter__()
        MS.set_skirmish(bed, map_name, players, ai, opts)
        MS.wait_memory()
        if not game.start():
            summary["result"] = "launch-failed"
            return 1
        rc, msg = MS.start_skirmish(bed, map_name, out / "shots" / f"{tag}.setup.png", players, opts)
        say(msg)
        if rc:
            summary["result"] = f"start-failed: {msg}"
            return rc
        proc = T.process()
        dmp = T.my_games(bed) / T.bed_profile(bed)["rm"] / f"Age3RM{map_name}.dmp.txt"
        summary["map_dump"] = time.strftime("%H:%M:%S", time.localtime(dmp.stat().st_mtime)) if dmp.exists() else None
        trig = T.my_games(bed) / "Trigger3" / "trigtemp.xs"
        if trig.exists():
            (out / "runs").mkdir(exist_ok=True)
            (out / "runs" / f"{tag}.trigtemp.xs").write_bytes(trig.read_bytes())
        T.wait_game_time(5)
        # The whole map revealed (as performance.md's views do), so that a unit anywhere is drawn and
        # can be clicked: under the black map a click at a hidden unit selects nothing.
        run.cmd("fog()", "blackmap()")
        units = live_units(proc)
        summary["units_at_start"] = {str(p): sum(1 for u in units if u["player"] == p)
                                     for p in sorted({u["player"] for u in units})}
        run.shot("start")
        summary["trading_post"] = ("--no-trading-post" not in argv) and run.trading_post(proc)
        run.group(proc)
        pass_no = 0
        while minutes(proc) < total:
            pass_no += 1
            run.group(proc) if pass_no > 1 else None
            for u in run.pass_units(proc, pass_no):
                if minutes(proc) >= total:
                    break
                run.click(proc, u, pass_no)
            run.shot(f"pass{pass_no}")
            say(f"pass {pass_no} done at {minutes(proc):.1f} min, {len(run.rows)} clicks so far")
        T.wait_game_time(30)
        units = live_units(proc)
        summary["units_at_end"] = {str(p): sum(1 for u in units if u["player"] == p)
                                   for p in sorted({u["player"] for u in units})}
        summary["game_minutes"] = round(minutes(proc), 2)
        summary["result"] = "ok"
        run.shot("end")
        code = 0
    except SystemExit as e:
        code = e.code if isinstance(e.code, int) else 1
        summary["result"] = {3: "crash", 4: "hang"}.get(code, f"stopped: {e.code}")
        say(f"stopped: {e.code}")
    finally:
        summary["last_unit"] = getattr(run, "current", None)  # the unit being clicked when the run stopped
        if summary["result"] == "crash":
            pid = game.pid or 0
            game.ended()
            reports = [r for r in game.reports() if not r["first_chance"]] or game.reports()
            summary["crash"] = reports[-1] if reports else MS.event_log_crash(pid, time.time() - 7200)
        _, xs = MS.tail_since(log, log_at, 20, MS.XS_LINE)
        summary["xs_errors"] = xs
        summary["log_tail"] = MS.tail_since(log, log_at, 15)[1]
        game.close()
        state.__exit__()
        counts = {}
        for r in run.rows:
            k = f"p{r['player']} {r['proto']}"
            counts[k] = counts.get(k, 0) + 1
        summary["clicks"] = len(run.rows)
        summary["clicked_units"] = len(run.clicked)
        summary["special_clicks"] = sum(r["special"] for r in run.rows)
        summary["per_proto"] = dict(sorted(counts.items()))
        summary["ended"] = time.strftime("%Y-%m-%d %H:%M:%S")
        (out / f"{tag}.summary.json").write_text(json.dumps(summary, indent=1), encoding="utf-8")
        say(f"{tag}: {summary['result']}, {summary['clicks']} clicks on {summary['clicked_units']} units "
            f"({summary['special_clicks']} special), {summary.get('game_minutes')} min")
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
