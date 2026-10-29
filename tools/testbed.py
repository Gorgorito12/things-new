"""Drive the test-bed game unattended: start it, run console commands, play a scripted test map,
take screenshots, read units and UHC.log, and check that the Steam install was not touched.

Usage: python -I tools/testbed.py [--bed <folder>] <command> ...

  deploy [cfg]               copy build\\Release\\UHC.dll into the bed; with cfg, also copy it as
                             Startup\\uhc.cfg (perfExecFile is appended when missing)
  launch                     start age3y.exe +noIntroCinematics and wait for the main menu
  close                      leave the game, close the window, kill it after 30 s
  exec <cmd> [<cmd> ...]     run console commands through perfExecFile and wait until they ran
  map <name> <spec> ...      write RM3\\<name>.xs/.xml, a test map (spec syntax below)
  scenario <map> [--seed N]  editor route: generate <map>, save it as scenario uhc-<map>, leave,
                             load it as a game and unpause. Players have no AI.
  wait <seconds>             let that much game time pass (polls the world clock)
  state                      process, window, world and game time
  units [--player N] [--proto TEXT] [--los]   live units: ID, player, proto, HP, position
                             (--los adds the unit's own line of sight and its proto's)
  shot <out.png> [scale]     PrintWindow capture, works while the window is covered
  record <out.mp4> [seconds] [fps] [width]   films the window in real time to an H.264 MP4
                             (default 30 s, 10 fps, 1280 px wide); needs ffmpeg (UHC_FFMPEG,
                             PATH or C:\\Tools\\ffmpeg\\ffmpeg.exe)
  click <x> <y> | rclick <x> <y> [right]   posted click / real click (moves the cursor)
  key <name>... | rkey <name>...           posted / real key presses (rkey takes ctrl+x combos)
  type <text>                real typing (keyboard focus needed)
  log [--grep RE] [--tail N] UHC.log lines
  safety record|check        Steam bin listing and the stock age3y.exe hash

Map spec, one argument each:
  p<N>=<Proto>*<count>@<x>,<z>   units of player N around (x, z), fractions of the map side
  tech<N>=<TechName>             a trigger sets the tech active for player N at the start
  go<N>=<seconds>@<x>,<z>        after that many seconds, player N's units attack-move there
                                 (place the groups out of sight of each other to delay a fight)
  at<seconds>=<Effect>;<Param>=<value>;...
                                 after that many seconds, run one trigger effect of
                                 trigger3\\typetest.xml with these parameters (quote the spec),
                                 e.g. "at20=Change Unit Type;SrcObject=g0;ProtoUnit=Grenadier".
                                 Values: g<i> = every unit of the i-th p<N>= group (from 0),
                                 g<i>.<k> = its k-th unit, tech:<Name> = a tech, pt:<x>,<z> = a
                                 point (fractions of the map side); numbers and text as written
  size=<metres>                  map side, default 80
  sea=<SeaType>                  a water map ("sea=ceylon coast", quoted), for ship tests

Console commands only reach the game through `perfExecFile <bed>\\uhc-exec.txt` in the bed's
uhc.cfg (posted key presses never reach the console). Without `DontPauseWhenLosingFocus` the game
pauses when it loses focus; `launch` defines it. A scenario is written to the shared
Documents\\My Games\\Age of Empires 3\\Scenario folder; `close` removes the ones this copy saved
(listed in <bed>\\uhc-scenarios.txt), never another session's. The data (protoy.xml, ...) is
parsed once, at startup: after a data edit, close and launch again.
"""
import ctypes
import ctypes.wintypes as wt
import hashlib
import os
import pathlib
import re
import shutil
import struct
import subprocess
import sys
import time
import zlib

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "re"))
import debugger as D  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[1]
STEAM_BIN = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\Age Of Empires 3\bin")
STOCK_SHA256 = "b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d"
MY_GAMES = pathlib.Path(os.path.expanduser("~")) / "Documents" / "My Games" / "Age of Empires 3"
LISTING = pathlib.Path(os.environ.get("TEMP", ".")) / "uhc-steam-listing.tsv"
WORKER_JOBS = 0xC692E4  # the skinning worker's done count; it moves while the menu animates

user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32")
try:
    user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
except (AttributeError, OSError):
    pass
user32.FindWindowW.restype = wt.HWND
user32.FindWindowW.argtypes = [wt.LPCWSTR, wt.LPCWSTR]
user32.GetDC.restype = wt.HDC
user32.GetDC.argtypes = [wt.HWND]
user32.ReleaseDC.argtypes = [wt.HWND, wt.HDC]
user32.PrintWindow.argtypes = [wt.HWND, wt.HDC, wt.UINT]
user32.PostMessageW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]
user32.MapVirtualKeyW.argtypes = [wt.UINT, wt.UINT]
user32.GetWindowThreadProcessId.argtypes = [wt.HWND, ctypes.POINTER(wt.DWORD)]
gdi32.CreateCompatibleDC.restype = wt.HDC
gdi32.CreateCompatibleDC.argtypes = [wt.HDC]
gdi32.CreateCompatibleBitmap.restype = wt.HBITMAP
gdi32.CreateCompatibleBitmap.argtypes = [wt.HDC, ctypes.c_int, ctypes.c_int]
gdi32.SelectObject.restype = wt.HGDIOBJ
gdi32.SelectObject.argtypes = [wt.HDC, wt.HGDIOBJ]
gdi32.GetDIBits.argtypes = [wt.HDC, wt.HBITMAP, wt.UINT, wt.UINT, ctypes.c_void_p, ctypes.c_void_p, wt.UINT]
gdi32.DeleteObject.argtypes = [wt.HGDIOBJ]
gdi32.DeleteDC.argtypes = [wt.HDC]
gdi32.SetStretchBltMode.argtypes = [wt.HDC, ctypes.c_int]
gdi32.SetBrushOrgEx.argtypes = [wt.HDC, ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
gdi32.StretchBlt.argtypes = [wt.HDC, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                             wt.HDC, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wt.DWORD]


class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long), ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


class POINT(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", wt.WORD), ("wScan", wt.WORD), ("dwFlags", wt.DWORD), ("time", wt.DWORD),
                ("dwExtraInfo", ctypes.c_size_t)]


class MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", ctypes.c_long), ("dy", ctypes.c_long), ("mouseData", wt.DWORD), ("dwFlags", wt.DWORD),
                ("time", wt.DWORD), ("dwExtraInfo", ctypes.c_size_t)]


class _INPUTUNION(ctypes.Union):
    _fields_ = [("ki", KEYBDINPUT), ("mi", MOUSEINPUT), ("pad", ctypes.c_byte * 32)]


class INPUT(ctypes.Structure):
    _fields_ = [("type", wt.DWORD), ("u", _INPUTUNION)]


# --- the bed and the game process ---------------------------------------------------------------

def bed_folder(arg):
    bed = pathlib.Path(arg or os.environ.get("UHC_TESTBED", r"C:\AoE3-UHC-Test")).resolve()
    if "steamapps" in (part.lower() for part in bed.parts):
        sys.exit(f"testbed: {bed} is inside a Steam library; use a test copy")
    if not (bed / "age3y.exe").exists():
        sys.exit(f"testbed: no age3y.exe in {bed}")
    return bed


BED = None  # set by main(); every process and window lookup is limited to this copy's exe

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
k32.OpenProcess.restype = wt.HANDLE
k32.QueryFullProcessImageNameW.argtypes = [wt.HANDLE, wt.DWORD, wt.LPWSTR, ctypes.POINTER(wt.DWORD)]
WNDENUMPROC = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
user32.EnumWindows.argtypes = [WNDENUMPROC, wt.LPARAM]
user32.GetWindowTextW.argtypes = [wt.HWND, wt.LPWSTR, ctypes.c_int]


def game_processes():
    """(pid, exe path) of every running age3y.exe, whichever folder it runs from."""
    out = []
    snap = D.k32.CreateToolhelp32Snapshot(0x2, 0)
    entry = D._ProcessEntry()
    entry.dwSize = ctypes.sizeof(entry)
    ok = D.k32.Process32FirstW(snap, ctypes.byref(entry))
    while ok:
        if entry.szExeFile.lower() == "age3y.exe":
            path = ""
            handle = k32.OpenProcess(0x1000, False, entry.th32ProcessID)  # PROCESS_QUERY_LIMITED_INFORMATION
            if handle:
                buf = ctypes.create_unicode_buffer(1024)
                size = wt.DWORD(len(buf))
                if k32.QueryFullProcessImageNameW(handle, 0, buf, ctypes.byref(size)):
                    path = buf.value
                D.k32.CloseHandle(handle)
            out.append((entry.th32ProcessID, path))
        ok = D.k32.Process32NextW(snap, ctypes.byref(entry))
    D.k32.CloseHandle(snap)
    return out


def bed_pid():
    exe = str(BED / "age3y.exe").lower()
    for pid, path in game_processes():
        if path.lower() == exe:
            return pid
    return None


def window(required=True):
    """The main window of this copy's game (never another copy's: sessions may test in parallel)."""
    pid, found = bed_pid(), []
    if pid:
        def visit(hwnd, _):
            owner = wt.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
            if owner.value == pid and user32.IsWindowVisible(hwnd):
                title = ctypes.create_unicode_buffer(128)
                user32.GetWindowTextW(hwnd, title, 128)
                if title.value.startswith("Age of Empires"):
                    found.append(hwnd)
            return True
        user32.EnumWindows(WNDENUMPROC(visit), 0)
    if not found and required:
        sys.exit("testbed: no game window for this copy")
    return found[0] if found else 0


def process():
    pid = bed_pid()
    return D.Process(pid) if pid else None


def game_time(proc):
    w = D.world(proc) if proc else 0
    return proc.u32(w + 0x108) if w else None


def exec_file(bed):
    return bed / "uhc-exec.txt"


def run_commands(bed, commands, timeout=60):
    """Writes the commands for perfExecFile (one per line) and waits until the game ran them."""
    path = exec_file(bed)
    tmp = path.with_suffix(".tmp")
    tmp.write_text("\r\n".join(commands) + "\r\n", encoding="ascii")
    os.replace(tmp, path)
    deadline = time.time() + timeout
    while time.time() < deadline:
        if not path.exists():
            return True
        time.sleep(0.25)
    path.unlink(missing_ok=True)
    sys.exit("testbed: the exec file was not consumed; is perfExecFile in the bed's uhc.cfg and the game running?")


def wait_until(predicate, timeout, step=0.5, what="condition"):
    deadline = time.time() + timeout
    while time.time() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(step)
    sys.exit(f"testbed: timed out waiting for {what}")


def launch(bed):
    running = game_processes()
    if running:  # another copy may belong to another session's test: never run two at once
        sys.exit("testbed: a game is already running: " + ", ".join(f"pid {p} {path}" for p, path in running))
    subprocess.Popen([str(bed / "age3y.exe"), "+noIntroCinematics"], cwd=str(bed))

    def main_window():
        hwnd = window(required=False)
        if not hwnd:
            return 0
        rc = RECT()
        user32.GetClientRect(hwnd, ctypes.byref(rc))
        return hwnd if rc.right > 640 else 0

    wait_until(main_window, 120, 1, "the game window")
    proc = wait_until(process, 30, 1, "the game process")
    last = proc.u32(WORKER_JOBS)
    start = time.time()
    while time.time() - start < 90:  # the main menu animates skinned units
        time.sleep(1)
        now = proc.u32(WORKER_JOBS)
        if now - last > 200:
            break
        last = now
    run_commands(bed, ['config("DontPauseWhenLosingFocus")'])
    print(f"testbed: main menu ready (pid {proc.pid})")


def close(bed):
    hwnd = window(required=False)
    if not hwnd:
        print("testbed: no game window")
    else:
        pid = bed_pid()
        user32.PostMessageW(hwnd, 0x0010, 0, 0)  # WM_CLOSE
        deadline = time.time() + 30
        while time.time() < deadline and bed_pid():
            time.sleep(1)
        if bed_pid():  # no tracer is attached, so killing it is safe
            subprocess.run(["taskkill", "/F", "/PID", str(pid)], check=False)
    remove_own_scenarios(bed)
    exec_file(bed).unlink(missing_ok=True)


def scenario_record(bed):
    return bed / "uhc-scenarios.txt"  # the scenarios this copy saved, so close removes only those


def remove_own_scenarios(bed):
    record = scenario_record(bed)
    names = record.read_text(encoding="utf-8").split() if record.exists() else []
    for name in names:
        scn = MY_GAMES / "Scenario" / f"{name}.age3Yscn"
        if scn.exists():
            scn.unlink()
            print(f"testbed: removed {scn}")
    record.unlink(missing_ok=True)


# --- test maps ------------------------------------------------------------------------------------

MAP_TEMPLATE = """// Written by tools/testbed.py: a UHC test map, not a playable map.
void main(void)
{{
   rmSetStatusText("",0.01);
   rmSetMapSize({size}, {size});
{terrain}
   rmSetWorldCircleConstraint(false);
{players}
{units}
   rmCreateTrigger("uhcSetup");
   rmSwitchToTrigger(rmTriggerID("uhcSetup"));
   rmSetTriggerPriority(4);
   rmSetTriggerActive(true);
   rmSetTriggerRunImmediately(true);
   rmSetTriggerLoop(false);
   rmAddTriggerCondition("Always");
{effects}
   rmSetStatusText("",1.0);
}}
"""

LAND_TERRAIN = """   rmSetSeaLevel(0.0);
   rmSetBaseTerrainMix("texas_grass");
   rmTerrainInitialize("yukon\\ground1_yuk", 0.0);
   rmSetLightingSet("great plains");
   rmSetMapType("land");
   rmSetMapType("grass");"""

# sea=<SeaType>: the whole map is water, set up as RM3\Ceylon.xs does, for ship tests.
SEA_TERRAIN = """   rmSetSeaLevel(1.0);
   rmSetSeaType("{sea}");
   rmSetLightingSet("great plains");
   rmSetMapType("water");
   rmTerrainInitialize("water");"""

MAP_INFO = """<?xml version = "1.0" encoding = "UTF-8"?>
<mapinfo details = "28599" imagepath = "ui\\random_map\\great_plains" displayNameID = "28598" cannotReplace = ""
		loadDetails="35943" loadBackground="ui\\random_map\\great_plains\\great_plains_map">
</mapinfo>
"""


def tech_indices(bed):
    """Tech name (lowercase) -> its index in the bed's techtreey.xml, the ID triggers take."""
    text = (bed / "data" / "techtreey.xml").read_text(encoding="utf-8", errors="replace")
    return {name.lower(): i for i, name in enumerate(re.findall(r"<Tech name\s*=\s*'([^']+)'", text))}


def effect_param(bed, groups, size, name, value):
    """One trigger-effect parameter as an rmSetTriggerEffectParam* call (see the at<seconds> spec)."""
    m = re.fullmatch(r"g(\d+)\.(\d+)", value)
    if m:  # one unit placed by a p<N>= group (timed_effects expands a whole group g<i>)
        if int(m[1]) >= len(groups):
            sys.exit(f"testbed: {value} names group {m[1]}, but the map has {len(groups)} p<N>= group(s)")
        return f'   rmSetTriggerEffectParamInt("{name}", rmGetUnitPlaced(uhcGroup{m[1]}, {m[2]}), false);'
    if value.startswith("tech:"):  # a trigger's tech parameter is the tech's index in techtreey.xml
        ids = tech_indices(bed)
        tech = value[5:]
        if tech.lower() not in ids:
            sys.exit(f"testbed: no tech {tech} in {bed / 'data' / 'techtreey.xml'}")
        return f'   rmSetTriggerEffectParamInt("{name}", {ids[tech.lower()]}, false);'
    m = re.fullmatch(r"pt:([0-9.]+),([0-9.]+)", value)
    if m:  # a point, in fractions of the map side
        return f'   rmSetTriggerEffectParam("{name}", "{float(m[1]) * size:.1f},0,{float(m[2]) * size:.1f}", false);'
    if re.fullmatch(r"-?\d+", value):
        return f'   rmSetTriggerEffectParamInt("{name}", {value}, false);'
    if re.fullmatch(r"-?\d+\.\d*", value):
        return f'   rmSetTriggerEffectParamFloat("{name}", {value}, false);'
    return f'   rmSetTriggerEffectParam("{name}", "{value}", false);'


def write_map(bed, name, specs):
    size, groups, techs, moves, timed, sea = 80, [], [], [], [], None
    for spec in specs:
        if spec.startswith("size="):
            size = int(spec[5:])
            continue
        if spec.startswith("sea="):
            sea = spec[4:]
            continue
        m = re.fullmatch(r"p(\d)=([A-Za-z0-9_]+)\*(\d+)@([0-9.]+),([0-9.]+)", spec)
        if m:
            groups.append((int(m[1]), m[2], int(m[3]), float(m[4]), float(m[5])))
            continue
        m = re.fullmatch(r"tech(\d)=([A-Za-z0-9_]+)", spec)
        if m:
            techs.append((int(m[1]), m[2]))
            continue
        m = re.fullmatch(r"go(\d)=(\d+)@([0-9.]+),([0-9.]+)", spec)
        if m:
            moves.append((int(m[1]), int(m[2]), float(m[3]), float(m[4])))
            continue
        m = re.fullmatch(r"at(\d+)=([^;]+)((?:;[A-Za-z0-9_]+=[^;]*)*)", spec)
        if m:
            timed.append((int(m[1]), m[2].strip(), [p.split("=", 1) for p in m[3].split(";")[1:]]))
            continue
        sys.exit(f"testbed: bad map spec {spec!r} (expected p<N>=<Proto>*<count>@<x>,<z>, tech<N>=<Tech>, "
                 f"go<N>=<seconds>@<x>,<z>, at<seconds>=<Effect>;<Param>=<value>..., size=<m> or sea=<SeaType>)")
    players = sorted({g[0] for g in groups} | {t[0] for t in techs} | {1, 2})
    first = {}
    for g in groups:
        first.setdefault(g[0], (g[3], g[4]))
    player_lines = "\n".join(f"   rmPlacePlayer({p}, {first.get(p, (0.3 + 0.4 * (p % 2), 0.5))[0]}, "
                             f"{first.get(p, (0.3 + 0.4 * (p % 2), 0.5))[1]});" for p in players)
    unit_lines = []
    for i, (player, proto, count, x, z) in enumerate(groups):
        unit_lines += [
            f'   int uhcGroup{i} = rmCreateObjectDef("uhc group {i}");',
            f'   rmAddObjectDefItem(uhcGroup{i}, "{proto}", {count}, 3.0);',
            f"   rmSetObjectDefMinDistance(uhcGroup{i}, 0.0);",
            f"   rmSetObjectDefMaxDistance(uhcGroup{i}, 2.0);",
            f"   rmPlaceObjectDefAtLoc(uhcGroup{i}, {player}, {x}, {z}, 1);",
        ]
    effect_lines = []
    tech_ids = tech_indices(bed) if techs else {}
    for player, tech in techs:
        if tech.lower() not in tech_ids:
            sys.exit(f"testbed: no tech {tech} in {bed / 'data' / 'techtreey.xml'}")
        effect_lines += [  # a trigger's tech parameter is the tech's index in techtreey.xml
            '   rmAddTriggerEffect("Set Tech Status");',
            f'   rmSetTriggerEffectParamInt("PlayerID", {player}, false);',
            f'   rmSetTriggerEffectParamInt("TechID", {tech_ids[tech.lower()]}, false);',
            '   rmSetTriggerEffectParamInt("Status", 2, false);',
        ]
    if not effect_lines:
        effect_lines = ['   rmAddTriggerEffect("Send Chat");', '   rmSetTriggerEffectParam("Message", "uhc", false);']
    for k, (player, seconds, x, z) in enumerate(moves):
        group = next((i for i, g in enumerate(groups) if g[0] == player), None)
        if group is None:
            sys.exit(f"testbed: go{player} needs a p{player}= group")
        effect_lines += [  # after <seconds>, every unit of the player near its first group attack-moves
            f'   rmCreateTrigger("uhcGo{k}");',
            f'   rmSwitchToTrigger(rmTriggerID("uhcGo{k}"));',
            "   rmSetTriggerPriority(4);",
            "   rmSetTriggerActive(true);",
            "   rmSetTriggerRunImmediately(true);",
            "   rmSetTriggerLoop(false);",
            '   rmAddTriggerCondition("Timer");',
            f'   rmSetTriggerConditionParamInt("Param1", {seconds}, false);',
            '   rmAddTriggerEffect("Move From Area");',
            f'   rmSetTriggerEffectParamInt("RefObject", rmGetUnitPlacedOfPlayer(uhcGroup{group}, {player}), false);',
            '   rmSetTriggerEffectParam("UnitType", "Unit", false);',
            f'   rmSetTriggerEffectParamInt("PlayerID", {player}, false);',
            f'   rmSetTriggerEffectParamFloat("Radius", {max(10.0, size * 0.15):.1f}, false);',
            f'   rmSetTriggerEffectParam("DstPoint", "{x * size:.1f},0,{z * size:.1f}", false);',
            '   rmSetTriggerEffectParam("AttackMove", "true", false);',
        ]
    for k, (seconds, effect, params) in enumerate(timed):
        effect_lines += [  # any trigger effect of trigger3\typetest.xml, once, after <seconds>
            f'   rmCreateTrigger("uhcAt{k}");',
            f'   rmSwitchToTrigger(rmTriggerID("uhcAt{k}"));',
            "   rmSetTriggerPriority(4);",
            "   rmSetTriggerActive(true);",
            "   rmSetTriggerRunImmediately(true);",
            "   rmSetTriggerLoop(false);",
            '   rmAddTriggerCondition("Timer");',
            f'   rmSetTriggerConditionParamInt("Param1", {seconds}, false);',
        ]
        # The trigger compiler treats a unit list "3,4" as one name, so a whole group g<i> becomes
        # one copy of the effect per unit.
        whole = next(((n, int(v[1:])) for n, v in params if re.fullmatch(r"g\d+", v)), None)
        if whole and whole[1] >= len(groups):
            sys.exit(f"testbed: g{whole[1]} names a group the map does not have ({len(groups)} p<N>= group(s))")
        for unit in range(groups[whole[1]][2]) if whole else [None]:
            effect_lines.append(f'   rmAddTriggerEffect("{effect}");')
            effect_lines += [effect_param(bed, groups, size, param, f"g{whole[1]}.{unit}" if whole and param == whole[0]
                                          else value) for param, value in params]
    terrain = SEA_TERRAIN.format(sea=sea) if sea else LAND_TERRAIN
    text = MAP_TEMPLATE.format(size=size, terrain=terrain, players=player_lines, units="\n".join(unit_lines),
                               effects="\n".join(effect_lines))
    folder = bed / "RM3"
    (folder / f"{name}.xs").write_text(text, encoding="utf-8")
    (folder / f"{name}.xml").write_text(MAP_INFO, encoding="utf-8")
    print(f"testbed: wrote {folder / (name + '.xs')} ({len(groups)} unit groups, {len(techs)} techs, "
          f"{len(timed)} timed effects)")


def scenario(bed, map_name, seed):
    proc = process() or sys.exit("testbed: the game is not running")
    name = f"uhc-{map_name}"
    target = MY_GAMES / "Scenario" / f"{name}.age3Yscn"
    target.unlink(missing_ok=True)
    record = scenario_record(bed)
    names = set(record.read_text(encoding="utf-8").split()) if record.exists() else set()
    record.write_text("\n".join(sorted(names | {name})) + "\n", encoding="utf-8")
    if D.world(proc):  # a game or the editor is open: back to the main menu first
        run_commands(bed, ["leaveGame()"])
        wait_until(lambda: not D.world(proc), 60, 1, "the main menu")
        time.sleep(3)
    run_commands(bed, ['config("DontPauseWhenLosingFocus")', "startRandomGame(true)"])
    wait_until(lambda: D.world(proc), 120, 1, "the scenario editor")
    time.sleep(5)
    run_commands(bed, [f'startRandomGame2("{map_name}", 2, {seed}, "", false, 2, 1, 0, false)'])
    time.sleep(10)
    run_commands(bed, [f'saveScenario("{name}")'])
    wait_until(lambda: target.exists() and target.stat().st_size > 0, 60, 1, f"{target}")
    time.sleep(2)
    run_commands(bed, ["leaveGame()"])
    wait_until(lambda: not D.world(proc), 60, 1, "the main menu")
    time.sleep(3)
    run_commands(bed, [f'loadScenario("{name}")'])
    wait_until(lambda: D.world(proc) and game_time(proc) is not None, 120, 1, "the scenario to load")
    time.sleep(5)
    run_commands(bed, ["pause(0)"])
    t0 = game_time(proc)
    time.sleep(3)
    print(f"testbed: scenario {name} running, game time {t0} -> {game_time(proc)} ms")


# --- reading the game ---------------------------------------------------------------------------

def list_units(player=None, proto_filter=None, los=False):
    proc = process() or sys.exit("testbed: the game is not running")
    for unit in D.units(proc):
        owner = D.unit_player(proc, unit)
        name = D.proto_name(proc, proc.u32(unit + 0x5C))
        if player is not None and owner != player:
            continue
        if proto_filter and proto_filter.lower() not in name.lower():
            continue
        x, y, z = struct.unpack("<fff", proc.read(unit + 0x14, 12) or b"\0" * 12)
        extra = ""
        if los:  # the unit's own LOS [[unit+B4h]+90h] and its proto's [[unit+5Ch]+48h]
            block = proc.u32(unit + 0xB4)
            unit_los = proc.f32(block + 0x90) if block else float("nan")
            extra = f"  los {unit_los:5.1f} (proto {proc.f32(proc.u32(unit + 0x5C) + 0x48):5.1f})"
        print(f"{proc.u32(unit + 0x10):7d}  player {owner}  {name:32s} hp {proc.f32(unit + 0x64):8.1f}  "
              f"at {x:6.1f},{z:6.1f}{extra}")


def state():
    proc = process()
    if not proc:
        print("testbed: the game is not running")
        return
    hwnd = window(required=False)
    rc = RECT()
    if hwnd:
        user32.GetClientRect(hwnd, ctypes.byref(rc))
    w = D.world(proc)
    print(f"pid {proc.pid}, window {'%dx%d' % (rc.right, rc.bottom) if hwnd else 'none'}, "
          f"world {w:#x}, game time {game_time(proc)} ms")


def wait_game_time(seconds):
    proc = process() or sys.exit("testbed: the game is not running")
    start = game_time(proc) or 0
    wait_until(lambda: (game_time(proc) or 0) - start >= seconds * 1000, seconds * 10 + 60, 0.5, "game time")
    print(f"testbed: game time {start} -> {game_time(proc)} ms")


def show_log(bed, pattern, tail):
    path = bed / "UHC.log"
    lines = path.read_text(encoding="utf-8-sig", errors="replace").splitlines() if path.exists() else []
    if pattern:
        lines = [line for line in lines if re.search(pattern, line)]
    for line in lines[-tail:] if tail else lines:
        print(line)


# --- screenshots and input ------------------------------------------------------------------------

def png(path, w, h, rows):
    def chunk(kind, data):
        c = struct.pack(">I", len(data)) + kind + data
        return c + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    raw = b"".join(b"\0" + r for r in rows)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) +
                chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def shot(path, scale=2):
    hwnd = window()
    rc = RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rc))
    w, h = rc.right - rc.left, rc.bottom - rc.top
    screen = user32.GetDC(None)
    mem = gdi32.CreateCompatibleDC(screen)
    bmp = gdi32.CreateCompatibleBitmap(screen, w, h)
    gdi32.SelectObject(mem, bmp)
    ok = user32.PrintWindow(hwnd, mem, 2)  # PW_RENDERFULLCONTENT
    header = struct.pack("<IiiHHIIiiII", 40, w, -h, 1, 32, 0, 0, 0, 0, 0, 0)
    bmi = ctypes.create_string_buffer(header + b"\0" * 16)
    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(mem, bmp, 0, h, buf, bmi, 0)
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mem)
    user32.ReleaseDC(None, screen)
    data = buf.raw
    rows = []
    for yy in range(0, h, scale):
        line = data[yy * w * 4:(yy + 1) * w * 4]
        px = bytearray()
        for xx in range(0, w, scale):
            px += bytes((line[xx * 4 + 2], line[xx * 4 + 1], line[xx * 4]))
        rows.append(bytes(px))
    png(path, (w + scale - 1) // scale, len(rows), rows)
    print(f"{path}: window {w}x{h}, PrintWindow {'ok' if ok else 'FAILED'}, saved at 1/{scale}")


def ffmpeg_path():
    """ffmpeg for `record`: UHC_FFMPEG, then PATH, then C:\\Tools\\ffmpeg (a static build)."""
    for candidate in (os.environ.get("UHC_FFMPEG"), shutil.which("ffmpeg"), r"C:\Tools\ffmpeg\ffmpeg.exe"):
        if candidate and os.path.isfile(candidate):
            return candidate
    sys.exit("testbed: record needs ffmpeg (set UHC_FFMPEG, put it on PATH or in C:\\Tools\\ffmpeg)")


def record(path, seconds=30.0, fps=10, width=1280):
    """Films the game window to an H.264 MP4 in real time, with PrintWindow like `shot` (it works
    while the window is covered). A frame that takes longer than 1/fps to capture is repeated, so
    the video keeps the game's real speed."""
    ffmpeg = ffmpeg_path()
    hwnd = window()
    rc = RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rc))
    w, h = rc.right - rc.left, rc.bottom - rc.top
    ow = min(width, w) // 2 * 2
    oh = round(h * ow / w / 2) * 2
    screen = user32.GetDC(None)
    full_dc, small_dc = gdi32.CreateCompatibleDC(screen), gdi32.CreateCompatibleDC(screen)
    full, small = gdi32.CreateCompatibleBitmap(screen, w, h), gdi32.CreateCompatibleBitmap(screen, ow, oh)
    gdi32.SelectObject(full_dc, full)
    gdi32.SelectObject(small_dc, small)
    gdi32.SetStretchBltMode(small_dc, 4)  # HALFTONE: averages pixels, so text stays readable
    gdi32.SetBrushOrgEx(small_dc, 0, 0, None)
    bmi = ctypes.create_string_buffer(struct.pack("<IiiHHIIiiII", 40, ow, -oh, 1, 32, 0, 0, 0, 0, 0, 0) + b"\0" * 16)
    buf = ctypes.create_string_buffer(ow * oh * 4)

    def grab():
        user32.PrintWindow(hwnd, full_dc, 2)  # PW_RENDERFULLCONTENT
        gdi32.StretchBlt(small_dc, 0, 0, ow, oh, full_dc, 0, 0, w, h, 0x00CC0020)  # SRCCOPY
        gdi32.GetDIBits(small_dc, small, 0, oh, buf, bmi, 0)
        return buf.raw

    encoder = subprocess.Popen(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgra",
         "-s", f"{ow}x{oh}", "-framerate", str(fps), "-i", "-", "-c:v", "libx264", "-preset", "veryfast",
         "-crf", "23", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(path)],
        stdin=subprocess.PIPE)
    total, written, captured = int(seconds * fps), 0, 0
    proc = process()
    game_start = game_time(proc) if proc else None
    t0 = time.perf_counter()
    try:
        while written < total:
            delay = t0 + written / fps - time.perf_counter()
            if delay > 0:
                time.sleep(delay)
            frame = grab()
            captured += 1
            due = min(total, max(written + 1, int((time.perf_counter() - t0) * fps) + 1))
            encoder.stdin.write(frame * (due - written))
            written = due
    finally:
        encoder.stdin.close()
        encoder.wait()
        for obj in (full, small):
            gdi32.DeleteObject(obj)
        for dc in (full_dc, small_dc):
            gdi32.DeleteDC(dc)
        user32.ReleaseDC(None, screen)
    game_end = game_time(proc) if proc else None
    game = f", game time {game_start} -> {game_end} ms" if game_start is not None and game_end is not None else ""
    size = os.path.getsize(path) / 1e6 if os.path.exists(path) else 0
    print(f"testbed: {path}: {seconds:g} s at {fps} fps, {ow}x{oh}, {captured} frames captured "
          f"({written - captured} repeated){game}, {size:.1f} MB, ffmpeg exit {encoder.returncode}")


WM_KEYDOWN, WM_KEYUP, WM_CHAR = 0x100, 0x101, 0x102
WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_LBUTTONUP = 0x200, 0x201, 0x202
VK = {"return": 0x0D, "escape": 0x1B, "space": 0x20, "tab": 0x09, "back": 0x08, "grave": 0xC0,
      "up": 0x26, "down": 0x28, "left": 0x25, "right": 0x27, "home": 0x24, "end": 0x23,
      "shift": 0x10, "control": 0x11, "ctrl": 0x11, "alt": 0x12, "delete": 0x2E}
VK.update({f"f{i}": 0x6F + i for i in range(1, 13)})


def vk_of(name):
    return VK[name] if name in VK else ord(name.upper())


def posted_key(name):
    hwnd = window()
    vk = vk_of(name)
    scan = user32.MapVirtualKeyW(vk, 0)
    user32.PostMessageW(hwnd, WM_KEYDOWN, vk, 1 | scan << 16)
    time.sleep(0.05)
    user32.PostMessageW(hwnd, WM_KEYUP, vk, 1 | scan << 16 | 0xC0000000)
    time.sleep(0.1)


def posted_click(x, y):
    hwnd = window()
    lp = (y & 0xFFFF) << 16 | (x & 0xFFFF)
    user32.PostMessageW(hwnd, WM_MOUSEMOVE, 0, lp)
    time.sleep(0.05)
    user32.PostMessageW(hwnd, WM_LBUTTONDOWN, 1, lp)
    time.sleep(0.05)
    user32.PostMessageW(hwnd, WM_LBUTTONUP, 0, lp)


def send(*inputs):
    arr = (INPUT * len(inputs))(*inputs)
    user32.SendInput(len(inputs), arr, ctypes.sizeof(INPUT))


def focus():
    hwnd = window()
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.25)
    return hwnd


def real_click(cx, cy, right=False):
    hwnd = focus()
    pt = POINT(cx, cy)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    user32.SetCursorPos(pt.x, pt.y)
    time.sleep(0.15)
    down, up = (0x0008, 0x0010) if right else (0x0002, 0x0004)
    i1 = INPUT(type=0)
    i1.u.mi = MOUSEINPUT(0, 0, 0, down, 0, 0)
    i2 = INPUT(type=0)
    i2.u.mi = MOUSEINPUT(0, 0, 0, up, 0, 0)
    send(i1)
    time.sleep(0.08)
    send(i2)
    time.sleep(0.2)


def real_key(combo):
    focus()
    vks = [vk_of(k) for k in combo.lower().split("+")]
    downs, ups = [], []
    for v in vks:
        s = user32.MapVirtualKeyW(v, 0)
        d = INPUT(type=1)
        d.u.ki = KEYBDINPUT(v, s, 0x8, 0, 0)
        u = INPUT(type=1)
        u.u.ki = KEYBDINPUT(v, s, 0x8 | 0x2, 0, 0)
        downs.append(d)
        ups.append(u)
    send(*downs)
    time.sleep(0.06)
    send(*reversed(ups))
    time.sleep(0.15)


def real_type(text):
    focus()
    for ch in text:
        d = INPUT(type=1)
        d.u.ki = KEYBDINPUT(0, ord(ch), 0x4, 0, 0)
        u = INPUT(type=1)
        u.u.ki = KEYBDINPUT(0, ord(ch), 0x4 | 0x2, 0, 0)
        send(d, u)
        time.sleep(0.02)


# --- deploying and safety ----------------------------------------------------------------------------

def deploy(bed, cfg):
    dll = REPO / "build" / "Release" / "UHC.dll"
    shutil.copy2(dll, bed / "UHC.dll")
    print(f"testbed: copied {dll} -> {bed / 'UHC.dll'}")
    if cfg:
        text = pathlib.Path(cfg).read_text(encoding="utf-8")
        if "perfexecfile" not in text.lower():
            text = text.rstrip("\n") + f"\nperfExecFile {exec_file(bed)}\n"
        (bed / "Startup" / "uhc.cfg").write_text(text, encoding="utf-8")
        print(f"testbed: wrote {bed / 'Startup' / 'uhc.cfg'}")
    (bed / "UHC.log").unlink(missing_ok=True)


def steam_listing():
    rows = []
    for path in sorted(STEAM_BIN.rglob("*")):
        if path.is_file():
            st = path.stat()
            rows.append(f"{path.relative_to(STEAM_BIN)}\t{st.st_size}\t{st.st_mtime_ns}")
    return rows


def safety(mode):
    digest = hashlib.sha256((STEAM_BIN / "age3y.exe").read_bytes()).hexdigest()
    print(f"testbed: Steam age3y.exe {'is' if digest == STOCK_SHA256 else 'is NOT'} the stock build ({digest[:8]})")
    rows = steam_listing()
    if mode == "record":
        LISTING.write_text("\n".join(rows), encoding="utf-8")
        print(f"testbed: recorded {len(rows)} files in {LISTING}")
        return
    before = LISTING.read_text(encoding="utf-8").splitlines() if LISTING.exists() else None
    if before is None:
        sys.exit("testbed: no recorded listing; run `safety record` first")
    changed = sorted(set(before) ^ set(rows))
    print(f"testbed: Steam bin {'unchanged' if not changed else 'CHANGED'} ({len(rows)} files)")
    for row in changed[:20]:
        print("  ", row)
    if changed or digest != STOCK_SHA256:
        sys.exit(1)


def main(argv):
    bed_arg = None
    if len(argv) >= 2 and argv[0] == "--bed":
        bed_arg, argv = argv[1], argv[2:]
    if not argv:
        sys.exit(__doc__)
    cmd, args = argv[0], argv[1:]
    if cmd == "safety":
        safety(args[0] if args else "check")
        return
    global BED
    bed = BED = bed_folder(bed_arg)
    if cmd == "deploy":
        deploy(bed, args[0] if args else None)
    elif cmd == "launch":
        launch(bed)
    elif cmd == "close":
        close(bed)
    elif cmd == "exec":
        run_commands(bed, args)
    elif cmd == "map":
        write_map(bed, args[0], args[1:])
    elif cmd == "scenario":
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else 1234
        scenario(bed, args[0], seed)
    elif cmd == "wait":
        wait_game_time(float(args[0]))
    elif cmd == "state":
        state()
    elif cmd == "units":
        player = int(args[args.index("--player") + 1]) if "--player" in args else None
        proto = args[args.index("--proto") + 1] if "--proto" in args else None
        list_units(player, proto, "--los" in args)
    elif cmd == "shot":
        shot(args[0], int(args[1]) if len(args) > 1 else 2)
    elif cmd == "record":
        record(args[0], float(args[1]) if len(args) > 1 else 30.0, int(args[2]) if len(args) > 2 else 10,
               int(args[3]) if len(args) > 3 else 1280)
    elif cmd == "click":
        posted_click(int(args[0]), int(args[1]))
    elif cmd == "rclick":
        real_click(int(args[0]), int(args[1]), len(args) > 2 and args[2] == "right")
    elif cmd == "key":
        for name in args:
            posted_key(name)
    elif cmd == "rkey":
        for name in args:
            real_key(name)
    elif cmd == "type":
        real_type(" ".join(args))
    elif cmd == "log":
        pattern = args[args.index("--grep") + 1] if "--grep" in args else None
        tail = int(args[args.index("--tail") + 1]) if "--tail" in args else 0
        show_log(bed, pattern, tail)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
