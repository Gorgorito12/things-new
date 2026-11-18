"""Check King of the Hill placement in random maps, hands-off: real King of the Hill generation in the
scenario editor, the hill's distance to every Town Center, the normal map unchanged, and whether every
player's units reach the hill.

    python -I tools/kothcheck.py --bed <copy> --csv <out.csv> --maps A,B [options]

Options:
  --src <dir>          take each map's .xs from this folder (the edited maps; default: the copy's RM4).
                       It is copied into the copy's RM4 as uhck_<name>.xs (and .xml), generated, and
                       removed at the end; the copy's own map is never written
  --players 2,4,8      player counts, 2 teams (default 2,4,8)
  --seeds 1,2          map seeds (default 1,2)
  --ffa 4              also these player counts in free-for-all, seed 1 (default 4; "" for none)
  --normal             also check the normal game: King of the Hill off, the original map and the
                       --src map with the same seed (4 players, seed 1 and 8 players, seed 2) must
                       place the same units at the same points
  --reach [seconds]    also play the --src map (4 players, seed 1, King of the Hill on) as a scenario,
                       with a trigger that sends all units of every player to the hill, and measure
                       after that much game time (default 240) how close each player got
  --shots <dir>        a crop of the minimap per generation, with the hill and the Town Centers marked
                       (default: <csv folder>/shots)
  --mapsize 0          the startRandomGame2 map size argument (default 0)
  --survey             only generate the maps as they are, King of the Hill off (see below)
  --uninstall          remove trigger3\\uhckoth.xml and RM4\\uhckothInclude.xs from the copy

How King of the Hill is set: rmGetIsKOTH() returns byte [[[0xC66234]+92Ch]+1A98h] of the random map
generator, copied when the map is generated (0x709F85) from game setting 27h (GameKOTH) of the game
settings object; its values are 5-byte records {type, value} (getter 0x402CE9). The tool generates one
map with a known seed, finds the settings by that record (setting 13h, GameRandomSeed), and writes
GameKOTH there. startRandomGame2 does not reset it, so it stays on for the next maps of the session.

Reach: the copy's trigger3 folder needs uhckoth.xml (one effect, "UHC KOTH Go": it finds the hill by
its proto and moves all of a player's units to it). The game reads trigger3 at startup, so the first
--reach run writes the file and stops: launch the copy again (--uninstall removes it afterwards). The
reach copy (uhckr_<name>) includes RM4\\uhckothInclude.xs, the library plus uhcKothReach(), called at
the start of the map's first King of the Hill block; it adds one trigger per player. A player reaches
the hill when one of its units ends within 15 m of it.

Survey: --survey generates the maps as they are (King of the Hill off) and saves the minimap crop with
the Town Centers and the map centre marked, to choose where a hill can go.

The fairness numbers: d = straight-line distance from the hill to each player's Town Center (a covered
wagon, or the mean of the player's units, when there is none); per team the mean d; team_ratio =
largest team mean / smallest; player_ratio = largest d / smallest. Teams come from the players'
stances ([player+1D4h+4*id], 1 = ally).
"""
import csv
import ctypes
import ctypes.wintypes as wt
import math
import os
import pathlib
import re
import shutil
import struct
import sys
import time

TOOLS = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(TOOLS / "re"))
import debugger as D  # noqa: E402
import testbed as T  # noqa: E402

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
FIELDS = ["map", "mode", "players", "teams", "seed", "result", "hills", "hill_x", "hill_z", "map_x", "map_z",
          "hill_fx", "hill_fz", "dists", "team_means", "team_ratio", "player_ratio", "min_dist", "reach",
          "detail", "shot"]
FIND_SEED = 917263


class MBI(ctypes.Structure):
    _fields_ = [("BaseAddress", ctypes.c_void_p), ("AllocationBase", ctypes.c_void_p),
                ("AllocationProtect", wt.DWORD), ("RegionSize", ctypes.c_size_t), ("State", wt.DWORD),
                ("Protect", wt.DWORD), ("Type", wt.DWORD)]


k32.VirtualQueryEx.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.POINTER(MBI), ctypes.c_size_t]
k32.ReadProcessMemory.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                                  ctypes.POINTER(ctypes.c_size_t)]
k32.WriteProcessMemory.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                                   ctypes.POINTER(ctypes.c_size_t)]


def say(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


class Bench:
    def __init__(self, bed):
        self.bed = bed
        self.pid = T.bed_pid()
        if not self.pid:
            sys.exit("kothcheck: the copy's game is not running (testbed.py launch)")
        self.proc = T.watch(D.Process(self.pid))
        self.handle = k32.OpenProcess(0x0400 | 0x0008 | 0x0010 | 0x0020, False, self.pid)
        self.settings = None
        self.editor = False
        self.rm = bed / T.bed_profile(bed)["rm"]
        self.dumps = T.my_games(bed) / T.bed_profile(bed)["rm"]
        self.log = T.log_path(bed)

    # --- memory ---
    def write(self, address, data):
        got = ctypes.c_size_t()
        buf = ctypes.create_string_buffer(data, len(data))
        return k32.WriteProcessMemory(self.handle, address, buf, len(data), ctypes.byref(got))

    def find_settings(self, seed, players):
        """The game settings' value records: setting 13h holds `seed`, setting 4 `players`."""
        pat = struct.pack("<i", seed)
        addr, hits = 0x10000, []
        while addr < 0x7FFF0000:
            m = MBI()
            if not k32.VirtualQueryEx(self.handle, addr, ctypes.byref(m), ctypes.sizeof(m)):
                break
            base, size = m.BaseAddress or 0, m.RegionSize
            if m.State == 0x1000 and m.Protect in (0x04, 0x40) and size < 512 * 2 ** 20:
                buf = ctypes.create_string_buffer(size)
                got = ctypes.c_size_t()
                if k32.ReadProcessMemory(self.handle, base, buf, size, ctypes.byref(got)):
                    data = buf.raw[:got.value]
                    i = data.find(pat)
                    while i >= 0:
                        arr = i - 1 - 0x13 * 5
                        if (arr >= 0 and data[i - 1] & 0xF == 2 and data[arr + 4 * 5] & 0xF == 2
                                and struct.unpack_from("<i", data, arr + 4 * 5 + 1)[0] == players
                                and data[arr + 0x27 * 5] & 0xF == 5):
                            hits.append(base + arr)
                        i = data.find(pat, i + 1)
            addr = base + size
        return hits

    def koth(self, on):
        """Sets GameKOTH; finds the settings first if needed."""
        if self.settings:
            rec = self.proc.read(self.settings + 0x27 * 5, 2)
            if not rec or rec[0] & 0xF != 5:
                self.settings = None
        if not self.settings:
            self.generate("anatolia", 3, FIND_SEED, 2, check=False)
            hits = self.find_settings(FIND_SEED, 3)
            if len(hits) != 1:
                sys.exit(f"kothcheck: found {len(hits)} game settings records, expected 1")
            self.settings = hits[0]
            say(f"game settings values at {self.settings:#x}")
        self.write(self.settings + 0x27 * 5 + 1, bytes([1 if on else 0]))
        return self.proc.read(self.settings + 0x27 * 5 + 1, 1) == bytes([1 if on else 0])

    # --- the editor ---
    def in_editor(self):
        """Opens the scenario editor (startRandomGame(true)) unless this run already did; a game left
        running (a scenario) is left first."""
        if self.editor and D.world(self.proc):
            return
        if D.world(self.proc):
            T.run_commands(self.bed, ["leaveGame()"])
            T.wait_until(lambda: not D.world(self.proc), 60, 1, "the main menu")
            time.sleep(3)
        T.run_commands(self.bed, ['config("DontPauseWhenLosingFocus")', "startRandomGame(true)"])
        T.wait_until(lambda: D.world(self.proc), 120, 1, "the scenario editor")
        time.sleep(4)
        self.editor = True

    def unit_ids(self):
        return {self.proc.u32(u + 0x10) for u in D.units(self.proc)}

    def generate(self, name, players, seed, teams, mapsize=0, check=True):
        """startRandomGame2 in the editor; returns (ok, detail)."""
        self.in_editor()
        dump = self.dumps / f"Age3RM{name}.dmp.txt"
        before = dump.stat().st_mtime if dump.exists() else 0
        ids_before = self.unit_ids()
        log_at = self.log.stat().st_size if self.log.exists() else 0
        T.run_commands(self.bed, [f'startRandomGame2("{name}", {players}, {seed}, "", false, {teams}, {mapsize}, 0, false)'])
        t0 = time.time()
        while time.time() - t0 < 120:
            if dump.exists() and dump.stat().st_mtime > before:
                break
            time.sleep(0.5)
        else:
            return False, "no map dump: the map did not compile"
        last, stable = -1, 0
        while time.time() - t0 < 240 and stable < 4:
            time.sleep(1)
            T.check_alive("the map to generate")
            n = len(D.units(self.proc))
            stable = stable + 1 if n == last and n > 0 else 0
            last = n
        errors = self.xs_errors(log_at)
        if check and not ids_before and not last:
            return False, "no units: " + errors
        return (not errors), errors

    def xs_errors(self, offset):
        if not self.log.exists():
            return ""
        with open(self.log, "rb") as f:
            f.seek(offset)
            text = f.read().decode("utf-8", "replace")
        rows = [r for r in text.splitlines() if re.search(r"xsErrorLog: (?!applied)|XS: ", r)]
        return " || ".join(rows[-4:])[:600]

    # --- reading the map ---
    def map_size(self):
        terrain = self.proc.u32(D.world(self.proc) + 0x88)
        cell = self.proc.f32(terrain + 0x18)
        return self.proc.i32(terrain + 8) * cell, self.proc.i32(terrain + 0xC) * cell

    def units(self):
        out = []
        for u in D.units(self.proc):
            x, _, z = struct.unpack("<fff", self.proc.read(u + 0x14, 12) or b"\0" * 12)
            out.append((self.proc.u32(u + 0x10), D.unit_player(self.proc, u),
                        D.proto_name(self.proc, self.proc.u32(u + 0x5C)), round(x, 1), round(z, 1),
                        self.proc.f32(u + 0x64)))
        return out

    def teams(self):
        w = D.world(self.proc)
        n = self.proc.u32(w + 0x5C)
        table = self.proc.u32(w + 0x58)
        groups = {}
        for p in range(1, n):
            pl = self.proc.u32(table + 4 * p)
            allies = tuple(sorted(i for i in range(1, n) if i == p or self.proc.i32(pl + 0x1D4 + 4 * i) == 1))
            groups.setdefault(allies, allies)
        return sorted(set(groups.values()))


def player_anchor(units, player):
    own = [u for u in units if u[1] == player]
    for test in (lambda n: "towncenter" in n and not re.search(r"rubble|ruins", n), lambda n: "coveredwagon" in n):
        hit = [u for u in own if test(u[2].lower())]
        if hit:
            return hit[0][3], hit[0][4], hit[0][2]
    if own:
        return (sum(u[3] for u in own) / len(own), sum(u[4] for u in own) / len(own), "units")
    return None


def unmatched(a, b, tolerance=6.0):
    """Units (player, proto, x, z) of one list with no unit of the same player and proto within
    `tolerance` metres in the other: a Gaia cart that wanders between two generations still matches."""
    def rest(xs, ys):
        pool = {}
        for u in ys:
            pool.setdefault((u[0], u[1]), []).append(u)
        out = []
        for u in xs:
            cands = pool.get((u[0], u[1]), [])
            best = min(cands, key=lambda c: math.hypot(c[2] - u[2], c[3] - u[3]), default=None)
            if best is not None and math.hypot(best[2] - u[2], best[3] - u[3]) <= tolerance:
                cands.remove(best)
            else:
                out.append(u)
        return out
    # Gaia carts that drive around, and the revealer and ruins some civs get in the editor
    skip = re.compile(r"travois|attackrevealer|ruins|rubble", re.I)
    a = [u for u in a if not skip.search(u[1])]
    b = [u for u in b if not skip.search(u[1])]
    return [("orig", u) for u in rest(a, b)] + [("new", u) for u in rest(b, a)]


def fairness(units, teams, players):
    hills = [u for u in units if u[2] == "ypKingsHill"]
    row = {"hills": len(hills)}
    if not hills:
        return row
    hx, hz = hills[0][3], hills[0][4]
    row.update(hill_x=hx, hill_z=hz)
    dists = {}
    for p in range(1, players + 1):
        a = player_anchor(units, p)
        if a:
            dists[p] = math.hypot(a[0] - hx, a[1] - hz)
    if not dists:
        return row
    row["dists"] = " ".join(f"p{p}:{d:.0f}" for p, d in sorted(dists.items()))
    means = []
    for team in teams:
        ds = [dists[p] for p in team if p in dists]
        if ds:
            means.append(sum(ds) / len(ds))
    row["team_means"] = " ".join(f"{m:.0f}" for m in means)
    row["team_ratio"] = f"{max(means) / max(min(means), 1):.2f}" if len(means) > 1 else "1.00"
    row["player_ratio"] = f"{max(dists.values()) / max(min(dists.values()), 1):.2f}"
    row["min_dist"] = f"{min(dists.values()):.0f}"
    return row


# --- the minimap crop ---------------------------------------------------------------------------------

MM_FROM_RIGHT, MM_FROM_BOTTOM, MM_DIAMETER = 221.5, 161.0, 268.0  # editor, 1926 x 1115 window


def minimap_shot(bed, out, units, size, players):
    tmp = out.with_suffix(".full.png")
    time.sleep(1.5)  # the minimap is drawn a few frames after the units appear
    T.shot(tmp, 1)
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return str(tmp)
    im = Image.open(tmp).convert("RGB")
    w, h = im.size
    cx, cy = w - MM_FROM_RIGHT, h - MM_FROM_BOTTOM
    r = MM_DIAMETER / 2 + 14
    crop = im.crop((int(cx - r), int(cy - r), int(cx + r), int(cy + r))).resize((int(4 * r), int(4 * r)))
    d = ImageDraw.Draw(crop)
    k = MM_DIAMETER / max(size)

    def at(x, z):
        dx, dz = x - size[0] / 2, z - size[1] / 2
        sx = (dx - dz) / math.sqrt(2) * k
        sy = -(dx + dz) / math.sqrt(2) * k
        return 2 * (r + sx), 2 * (r + sy)

    for p in range(1, players + 1):
        a = player_anchor(units, p)
        if a:
            x, y = at(a[0], a[1])
            d.rectangle((x - 7, y - 7, x + 7, y + 7), outline=(255, 255, 255), width=2)
            d.text((x + 9, y - 6), str(p), fill=(255, 255, 255))
    for u in units:
        if u[2] == "ypKingsHill":
            x, y = at(u[3], u[4])
            d.ellipse((x - 12, y - 12, x + 12, y + 12), outline=(255, 0, 255), width=4)
    crop.save(out)
    tmp.unlink(missing_ok=True)
    return str(out)


# --- the copies in RM4 ----------------------------------------------------------------------------

def slug(name):
    return "uhck_" + re.sub(r"[^A-Za-z0-9]+", "", name)


def install_copy(bench, name, src, instrument=False, tag="uhck_"):
    """Copies <src>/<name>.xs into RM4 under a test name; returns that name."""
    text = (src / f"{name}.xs").read_text(encoding="latin-1")
    copy = tag + re.sub(r"[^A-Za-z0-9]+", "", name)
    if instrument:
        text, n = re.subn(r'(?m)^(\s*)include\s+"ypKOTHInclude\.xs"\s*;', r'\1include "uhckothInclude.xs";', text)
        if not n:
            text = 'include "uhckothInclude.xs";\n' + text
        # the reach triggers, created at the start of the first King of the Hill block
        text, n = re.subn(r"(?m)^(\s*(?:else\s+)?if\s*\(\s*rmGetIsKOTH\(\)\s*\)\s*\{)", r"\1 uhcKothReach();", text, count=1)
        if not n:
            say(f"{name}: no King of the Hill block with braces; the reach test gets no trigger")
    (bench.rm / f"{copy}.xs").write_text(text, encoding="latin-1", newline="")
    shutil.copy2(bench.rm / f"{name}.xml", bench.rm / f"{copy}.xml")
    return copy


def remove_copies(bench, names):
    for copy in names:
        for ext in (".xs", ".xml"):
            (bench.rm / f"{copy}{ext}").unlink(missing_ok=True)
        (bench.dumps / f"Age3RM{copy}.dmp.txt").unlink(missing_ok=True)


REACH_INCLUDE_TAIL = r"""
// kothcheck.py: every player's units walk to the hill (a test copy, never shipped). The effect finds
// the hill by its proto when it runs, so this can be called before the hill is placed.
bool uhcKothReachDone = false;
void uhcKothReach(int unused = -1) {
  if (uhcKothReachDone)
    return;
  uhcKothReachDone = true;
  for (i = 1; < cNumberPlayers) {
    rmCreateTrigger("uhcKothGo" + i);
    rmSwitchToTrigger(rmTriggerID("uhcKothGo" + i));
    rmSetTriggerPriority(4);
    rmSetTriggerActive(true);
    rmSetTriggerRunImmediately(true);
    rmSetTriggerLoop(false);
    rmAddTriggerCondition("Timer");
    rmSetTriggerConditionParamInt("Param1", 2, false);
    rmAddTriggerEffect("UHC KOTH Go");
    rmSetTriggerEffectParamInt("PlayerID", i, false);
  }
}
"""

REACH_EFFECT = """<?xml version="1.0"?>
<trigger version="2">
  <Conditions>
  </Conditions>
  <Effects>
    <Effect name="UHC KOTH Go">
      <Param name="PlayerID" dispName="Player" varType="player">1</Param>
      <Command>xsSetContextPlayer(0);</Command>
      <Command>kbLookAtAllUnitsOnMap();</Command>
      <Command>int uhcQ = kbUnitQueryCreate("uhcKothHill%PlayerID%");</Command>
      <Command>kbUnitQuerySetPlayerID(uhcQ, 0);</Command>
      <Command>kbUnitQuerySetUnitType(uhcQ, kbGetProtoUnitID("ypKingsHill"));</Command>
      <Command>kbUnitQuerySetState(uhcQ, cUnitStateAlive);</Command>
      <Command>kbUnitQueryResetResults(uhcQ);</Command>
      <Command>kbUnitQueryExecute(uhcQ);</Command>
      <Command>vector uhcV = kbUnitGetPosition(kbUnitQueryGetResult(uhcQ, 0));</Command>
      <Command>trUnitSelectClear();</Command>
      <Command>trUnitSelectByID(kbUnitQueryGetResult(uhcQ, 0));</Command>
      <Command>trUnitMoveFromArea(xsVectorGetX(uhcV), 0.0, xsVectorGetZ(uhcV), -1, false, %PlayerID%, "Unit", 3000.0);</Command>
    </Effect>
  </Effects>
</trigger>
"""


def install_reach(bench):
    effect = bench.bed / "trigger3" / "uhckoth.xml"
    if not effect.exists() or effect.read_text(encoding="utf-8") != REACH_EFFECT:
        effect.write_text(REACH_EFFECT, encoding="utf-8")
        sys.exit(f"kothcheck: wrote {effect}; the game reads trigger3 at startup, so close and launch the "
                 "copy again, then repeat (kothcheck.py --bed <copy> --uninstall removes it)")
    lib = REACH_INCLUDE_TAIL + (bench.rm / "ypKOTHInclude.xs").read_text(encoding="latin-1")
    (bench.rm / "uhckothInclude.xs").write_text(lib, encoding="latin-1", newline="")


def remove_reach(bench, effect_too=False):
    (bench.rm / "uhckothInclude.xs").unlink(missing_ok=True)
    if effect_too:
        (bench.bed / "trigger3" / "uhckoth.xml").unlink(missing_ok=True)


def play_scenario(bench, copy, players, seed, teams, mapsize):
    """Generates `copy` (King of the Hill on), saves it as a scenario and plays it. Returns the
    units at the start."""
    ok, detail = bench.generate(copy, players, seed, teams, mapsize)
    if not ok:
        return None, detail
    proc, bed = bench.proc, bench.bed
    name = f"uhc-{copy}"
    target = T.my_games(bed) / "Scenario" / f"{name}.age3Yscn"
    target.unlink(missing_ok=True)
    record = T.scenario_record(bed)
    names = set(record.read_text(encoding="utf-8").split()) if record.exists() else set()
    record.write_text("\n".join(sorted(names | {name})) + "\n", encoding="utf-8")
    T.run_commands(bed, [f'saveScenario("{name}")'])
    T.wait_until(lambda: target.exists() and target.stat().st_size > 0, 60, 1, f"{target}")
    time.sleep(2)
    T.run_commands(bed, ["leaveGame()"])
    T.wait_until(lambda: not D.world(proc), 60, 1, "the main menu")
    bench.editor = False
    time.sleep(3)
    T.run_commands(bed, [f'loadScenario("{name}")'])
    T.wait_until(lambda: D.world(proc) and T.game_time(proc) is not None, 180, 1, "the scenario to load")
    time.sleep(5)
    T.run_commands(bed, ["pause(0)"])
    time.sleep(2)
    return bench.units(), "ok"


def reach(bench, copy, players, seed, teams, mapsize, seconds):
    start, detail = play_scenario(bench, copy, players, seed, teams, mapsize)
    if start is None:
        return {"result": "error", "detail": detail}
    hills = [u for u in start if u[2] == "ypKingsHill"]
    if not hills:
        return {"result": "no-hill", "detail": "no hill in the scenario"}
    hx, hz = hills[0][3], hills[0][4]
    t0 = T.game_time(bench.proc) or 0
    deadline = time.time() + seconds * 3 + 120
    while (T.game_time(bench.proc) or 0) - t0 < seconds * 1000 and time.time() < deadline:
        T.check_alive("game time")
        time.sleep(2)
    end = bench.units()
    best = {}
    for uid, p, proto, x, z, hp in end:
        if p >= 1 and hp > 0:
            d = math.hypot(x - hx, z - hz)
            if d < best.get(p, (1e9, ""))[0]:
                best[p] = (d, proto)
    moved = {}
    first = {u[0]: u for u in start}
    for uid, p, proto, x, z, hp in end:
        if uid in first and p >= 1 and math.hypot(x - first[uid][3], z - first[uid][4]) > 5:
            moved[p] = moved.get(p, 0) + 1
    text = " ".join(f"p{p}:{best[p][0]:.0f}m({best[p][1]},{moved.get(p, 0)} moved)" for p in sorted(best))
    far = [p for p in range(1, players + 1) if best.get(p, (1e9,))[0] > 15]
    played = ((T.game_time(bench.proc) or t0) - t0) / 1000
    T.run_commands(bench.bed, ["leaveGame()"])
    T.wait_until(lambda: not D.world(bench.proc), 60, 1, "the main menu")
    time.sleep(3)
    return {"result": "ok" if not far else "far:" + ",".join(f"p{p}" for p in far), "reach": text,
            "hill_x": hx, "hill_z": hz, "detail": f"after {played:.0f} s"}


# --- main -------------------------------------------------------------------------------------------

def arg(argv, name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


def append(path, row):
    new = not path.exists()
    with open(path, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, FIELDS)
        if new:
            w.writeheader()
        w.writerow({k: row.get(k, "") for k in FIELDS})


def survey(bench, maps, players, out, shots, mapsize):
    """The maps as they are (King of the Hill off): size, Town Centers, a minimap crop."""
    bench.koth(False)
    for name in maps:
        for p in players:
            ok, detail = bench.generate(name, p, 1, 2, mapsize)
            row = {"map": name, "mode": "survey", "players": p, "teams": 2, "seed": 1, "detail": detail,
                   "result": "ok" if ok else "error"}
            if ok:
                units = bench.units()
                size = bench.map_size()
                row.update(map_x=f"{size[0]:.0f}", map_z=f"{size[1]:.0f}")
                fake = units + [(0, 0, "ypKingsHill", size[0] / 2, size[1] / 2, 1.0)]  # the centre, for scale
                row.update(fairness(fake, bench.teams(), p))
                row["shot"] = minimap_shot(bench.bed, shots / f"survey-{re.sub(r'[^\w.-]+', '_', name)}-p{p}.png",
                                           fake, size, p)
            append(out, row)
            say(f"survey {name} p{p}: {row['result']} size {row.get('map_x')}x{row.get('map_z')} centre "
                f"ratio {row.get('team_ratio', '-')} ({row.get('dists', '')}) {detail[:100]}")


def main(argv):
    if "--uninstall" in argv and "--bed" in argv:
        bed = T.bed_folder(arg(argv, "--bed"))
        for p in (bed / "trigger3" / "uhckoth.xml", bed / T.bed_profile(bed)["rm"] / "uhckothInclude.xs"):
            if p.exists():
                p.unlink()
                print(f"kothcheck: removed {p}")
        return
    if "--bed" not in argv or "--csv" not in argv or "--maps" not in argv:
        sys.exit(__doc__)
    bed = T.BED = T.bed_folder(arg(argv, "--bed"))
    out = pathlib.Path(arg(argv, "--csv")).resolve()
    shots = pathlib.Path(arg(argv, "--shots", str(out.parent / "shots"))).resolve()
    shots.mkdir(parents=True, exist_ok=True)
    bench = Bench(bed)
    src = pathlib.Path(arg(argv, "--src", str(bench.rm))).resolve()
    maps = [m.strip() for m in arg(argv, "--maps").split(",") if m.strip()]
    players = [int(v) for v in arg(argv, "--players", "2,4,8").split(",") if v]
    seeds = [int(v) for v in arg(argv, "--seeds", "1,2").split(",") if v]
    ffa = [int(v) for v in arg(argv, "--ffa", "4").split(",") if v]
    mapsize = int(arg(argv, "--mapsize", "0"))
    reach_s = None
    if "--reach" in argv:
        nxt = arg(argv, "--reach", "")
        reach_s = float(nxt) if re.fullmatch(r"\d+(\.\d+)?", nxt or "") else 240.0
    if "--survey" in argv:
        try:
            survey(bench, maps, players, out, shots, mapsize)
        finally:
            bench.koth(False)
        return
    done = set()  # runs already in the CSV are skipped, so a stopped run can go on
    if out.exists():
        with open(out, newline="", encoding="utf-8") as f:
            done = {(r["map"], r["mode"], r["players"], r["teams"], r["seed"]) for r in csv.DictReader(f)}
    copies = []
    try:
        if reach_s:
            install_reach(bench)
        for name in maps:
            copy = install_copy(bench, name, src)
            copies.append(copy)
            runs = [(p, 2, s) for p in players for s in seeds] + [(p, p, 1) for p in ffa]
            runs = [r for r in runs if (name, "koth", str(r[0]), "ffa" if r[1] == r[0] and r[0] > 2 else str(r[1]),
                                        str(r[2])) not in done]
            if not bench.koth(True):
                sys.exit("kothcheck: could not set GameKOTH")
            for p, teams, s in runs:
                ok, detail = bench.generate(copy, p, s, teams, mapsize)
                row = {"map": name, "mode": "koth", "players": p, "teams": "ffa" if teams == p and p > 2 else teams,
                       "seed": s, "detail": detail}
                if ok:
                    units = bench.units()
                    size = bench.map_size()
                    row.update(map_x=f"{size[0]:.0f}", map_z=f"{size[1]:.0f}")
                    row.update(fairness(units, bench.teams(), p))
                    if row.get("hills"):
                        row.update(hill_fx=f"{row['hill_x'] / size[0]:.3f}", hill_fz=f"{row['hill_z'] / size[1]:.3f}")
                    tag = re.sub(r"[^\w.-]+", "_", f"{name}-p{p}{'ffa' if row['teams'] == 'ffa' else ''}-s{s}")
                    row["shot"] = minimap_shot(bed, shots / f"{tag}.png", units, size, p)
                    row["result"] = "ok" if row.get("hills") == 1 else ("no-hill" if not row.get("hills") else "hills>1")
                    if row["result"] == "ok" and float(row.get("team_ratio", "9")) > 1.5:
                        row["result"] = "unfair"
                else:
                    row["result"] = "error"
                append(out, row)
                say(f"{name} p{p} t{row['teams']} s{s}: {row['result']} hill {row.get('hill_fx', '-')},{row.get('hill_fz', '-')} "
                    f"team ratio {row.get('team_ratio', '-')} ({row.get('dists', '')}) {detail[:120]}")
            if "--normal" in argv and (name, "normal", "8", "2", "2") not in done:
                bench.koth(False)
                for p, s in ((4, 1), (8, 2)):
                    ok1, d1 = bench.generate(name, p, s, 2, mapsize)
                    a = sorted((u[1], u[2], u[3], u[4]) for u in bench.units()) if ok1 else None
                    ok2, d2 = bench.generate(copy, p, s, 2, mapsize)
                    b = sorted((u[1], u[2], u[3], u[4]) for u in bench.units()) if ok2 else None
                    sym = unmatched(a or [], b or [])
                    same = a is not None and b is not None and not sym
                    hills = sum(1 for u in (b or []) if u[1] == "ypKingsHill")
                    diff = "" if same else f"{len(sym)} units differ: " + "; ".join(
                        f"{side} {u[1]} p{u[0]} {u[2]},{u[3]}" for side, u in sym[:4])
                    row = {"map": name, "mode": "normal", "players": p, "teams": 2, "seed": s,
                           "result": "same" if same and not hills else "DIFFERENT", "hills": hills,
                           "detail": f"{len(a or [])} units; {diff} {d1} {d2}".strip()}
                    append(out, row)
                    say(f"{name} normal p{p} s{s}: {row['result']} ({row['detail'][:120]})")
                bench.koth(True)
            if reach_s and (name, "reach", "4", "2", "1") not in done:
                rcopy = install_copy(bench, name, src, instrument=True, tag="uhckr_")
                copies.append(rcopy)
                row = {"map": name, "mode": "reach", "players": 4, "teams": 2, "seed": 1}
                row.update(reach(bench, rcopy, 4, 1, 2, mapsize, reach_s))
                append(out, row)
                say(f"{name} reach: {row['result']} {row.get('reach', '')} {row.get('detail', '')}")
                bench.koth(True)
    finally:
        try:
            bench.koth(False)
        except SystemExit:
            pass
        remove_copies(bench, copies)
        if reach_s:
            remove_reach(bench)


if __name__ == "__main__":
    main(sys.argv[1:])
