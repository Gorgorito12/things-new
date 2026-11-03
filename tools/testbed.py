"""Drive the test-bed game unattended: start it, run console commands, play a scripted test map,
take screenshots, read units and UHC.log, and check that the Steam install was not touched.

Usage: python -I tools/testbed.py [--bed <folder>] <command> ...

  deploy [cfg]               copy build\\Release\\UHC.dll into the bed; with cfg, also copy it as
                             the cfg the bed's exe reads (Startup\\uhc.cfg, or Startup\\wol.cfg
                             in the WoL bed; perfExecFile is appended when missing)
  launch                     start age3y.exe +noIntroCinematics and wait for the main menu
  close                      leave the game, close the window, kill it after 30 s
  exec <cmd> [<cmd> ...]     run console commands through perfExecFile and wait until they ran
  map <name> <spec> ...      write RM3\\<name>.xs/.xml, a test map (spec syntax below); RM4
                             when the bed's exe reads RM4 (WoL)
  scenario <map> [--seed N]  editor route: generate <map>, save it as scenario uhc-<map>, leave,
                             load it as a game and unpause. Players have no AI.
  wait <seconds>             let that much game time pass (polls the world clock)
  state                      process, window, world and game time
  units [--player N] [--proto TEXT] [--los]   live units: ID, player, proto, HP, position
                             (--los adds the unit's own line of sight and its proto's)
  shot <out.png> [scale]     PrintWindow capture, works while the window is covered
  record <out.mp4> [seconds] [fps] [width] [--watch ID|Proto,...] [--log REGEX] [--frame ID] [--follow ID]
         [--select ID|Proto,...] [--crop F[@cx,cy]] [--zoom N] [--perf] [--perf-csv <out.csv>]
                             films the window in real time to an H.264 MP4 (default 30 s, 10 fps,
                             1280 px wide); needs ffmpeg (UHC_FFMPEG, PATH or
                             C:\\Tools\\ffmpeg\\ffmpeg.exe). --watch draws the game time and the
                             live HP of those units (IDs or proto names) on every frame, --log the
                             latest UHC.log lines that match, --frame centres the camera on a unit once and keeps it
                             still, --follow moves it only when that unit walks 10 m off,
                             --select keeps those units (yours) selected for the whole video, so
                             their HP bars show on screen (re-selected when new ones appear),
                             --crop F films only that fraction of the window (around cx,cy,
                             default 0.5,0.43: the play area's middle), enlarged: a close-up
                             with the camera untouched, --zoom N zooms in N wheel steps (the
                             game eases it back in ~20 s),
                             --perf the performance numbers once a second (fps, longest frame,
                             frames over 50 ms, simulation speed, main-thread CPU, memory; the
                             frame numbers need perfStats in the cfg), --perf-csv also saves them
  profile                    the bed's exe build, cfg path, AI and map folders, My Games folder
  profile backup             copy the bed's player profiles (Users3\\*.xml) to .bak-uhc-<date>
  profile hc [civ | file]    list the saved single-player home cities and their civs; with a civ
                             or a file name, make it the one a skirmish uses (LastSelectedSPHC;
                             the game must be closed)
  click <x> <y> | rclick <x> <y> [right]   posted click / real click (moves the cursor)
  drag <x1> <y1> <x2> <y2>   real left drag (box selection), client coordinates
  wheel <x> <y> <steps>      real mouse wheel at a client point (+ zooms in, - out)
  front                      keep the game window above every other window and focus it
  key <name>... | rkey <name>...           posted / real key presses (rkey takes ctrl+x combos)
  type <text>                real typing (keyboard focus needed)
  log [--grep RE] [--tail N] UHC.log lines
  monitors                   the monitors and the one tests use (UHC_TEST_MONITOR)
  safety record|check [wol]  Steam bin listing and the stock age3y.exe hash; with wol, the Steam
                             Wars of Liberty folder (top level, Startup, data, AI4, RM4), its exe
                             and its uhc.dll

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

The game window is moved to the test monitor when it starts and before every real click or
key: by default the primary monitor (the user's "monitor 1"); UHC_TEST_MONITOR=secondary picks
the first other monitor, a number N picks the Nth monitor in Windows' order (\\\\.\\DISPLAYN). `monitors` lists them.

Console commands only reach the game through `perfExecFile <bed>\\uhc-exec.txt` in the bed's
uhc.cfg (posted key presses never reach the console). Without `DontPauseWhenLosingFocus` the game
pauses when it loses focus; `launch` defines it. A scenario is written to the shared
Documents\\<My Games folder>\\Scenario folder (string 42265 of the bed's stringtabley.xml:
My Games\\Age of Empires 3, or My Games\\Wars of Liberty in the WoL bed); `close` removes the ones this copy saved
(listed in <bed>\\uhc-scenarios.txt), never another session's. The data (protoy.xml, ...) is
parsed once, at startup: after a data edit, close and launch again.
"""
import ctypes
import ctypes.wintypes as wt
import hashlib
import math
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
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import debugger as D  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[1]
STEAM_BIN = pathlib.Path(r"C:\Program Files (x86)\Steam\steamapps\common\Age Of Empires 3\bin")
STOCK_SHA256 = "b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d"
DOCUMENTS = pathlib.Path(os.path.expanduser("~")) / "Documents"
STEAM_WOL = STEAM_BIN.parent / "Wars of Liberty"
WOL_SHA256 = "0a277f14e08df516fe1abd3fd9f8175b40664f3371793afff507f652d5067726"
WOL_DLL_SHA256 = "c070d138c2b4ead70ef07f44dae57a6667ffc53b59a178ddade39db48e01efb2"
# age3y.exe builds a bed may run (docs/binaries.md); any other hash gets a warning.
KNOWN_EXES = {
    "d21d0173": "Knights and Barbarians (stock + UHC loader)",
    "8970565c": "Knights and Barbarians + large-address-aware (set_laa.py)",
    "0a277f14": "Wars of Liberty (loader, LAA, AI4/RM4, Startup\\wol.cfg)",
}
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
gdi32.CreateFontW.restype = wt.HFONT
gdi32.CreateFontW.argtypes = [ctypes.c_int] * 5 + [wt.DWORD] * 8 + [wt.LPCWSTR]
gdi32.SetBkMode.argtypes = [wt.HDC, ctypes.c_int]
gdi32.SetBkColor.argtypes = [wt.HDC, wt.DWORD]
gdi32.SetTextColor.argtypes = [wt.HDC, wt.DWORD]
gdi32.TextOutW.argtypes = [wt.HDC, ctypes.c_int, ctypes.c_int, wt.LPCWSTR, ctypes.c_int]


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


def _exe_wstring(data, offset, limit):
    return data[offset:offset + 2 * limit].decode("utf-16-le", "replace").split("\0")[0]


_PROFILES = {}


def bed_profile(bed):
    """What the bed's exe reads, from its own bytes: the UHC loader's cfg path (VA 0xC65083), the
    AI folder (0xBE3A98) and the random-map folder (0xBE3AD8), which mods patch (WoL: wol.cfg, AI4,
    RM4); and the My Games folder, string 42265 (cStringLuaFolder) of the bed's stringtabley.xml."""
    if bed in _PROFILES:
        return _PROFILES[bed]
    data = (bed / "age3y.exe").read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    cfg = _exe_wstring(data, 0x865083, 21) or "Startup\\uhc.cfg"
    ai = _exe_wstring(data, 0x7E3A98, 5).rstrip("\\") or "AI3"
    rm = _exe_wstring(data, 0x7E3AD8, 5).rstrip("\\") or "RM3"
    games = "My Games\\Age of Empires 3"
    table = bed / "data" / "stringtabley.xml"
    if table.exists():
        raw = table.read_bytes()
        text = raw.decode("utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8", "replace")
        m = re.search(r"""_locID\s*=\s*['"]42265['"][^>]*>([^<]+)<""", text)
        if m:
            games = m.group(1).strip().rstrip("\\")
    profile = {"sha256": digest, "build": KNOWN_EXES.get(digest[:8]), "cfg": cfg, "ai": ai, "rm": rm,
               "my_games": DOCUMENTS / games}
    if profile["build"] is None:
        print(f"testbed: warning: {bed / 'age3y.exe'} is an unknown build ({digest[:8]}); see docs/binaries.md")
    _PROFILES[bed] = profile
    return profile


def my_games(bed):
    return bed_profile(bed)["my_games"]


def saved_home_cities(bed):
    """(file name, civ) of every single-player home city saved in the bed's My Games folder."""
    out = []
    for path in sorted((my_games(bed) / "Savegame").glob("sp_*_homecity.xml")):
        raw = path.read_bytes()
        text = raw.decode("utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8", "replace")
        m = re.search(r"<civ>([^<]+)</civ>", text, re.I)
        out.append((path.name, m.group(1) if m else "?"))
    return out


def profile_hc(bed, choice):
    users = my_games(bed) / "Users3"
    cities = saved_home_cities(bed)
    if not choice:
        for name, civ in cities:
            print(f"  {civ:20} {name}")
        return
    wanted = [n for n, c in cities if choice.lower() in (n.lower(), c.lower())]
    if not wanted:
        sys.exit(f"testbed: no saved home city of civ or file {choice!r} (run `profile hc` for the list)")
    if bed_pid():
        sys.exit("testbed: close the game first; it writes the profile when it exits")
    for path in sorted(users.glob("*.xml")):
        raw = path.read_bytes()
        text = raw.decode("utf-16")
        new, n = re.subn(r"<LastSelectedSPHC>[^<]*</LastSelectedSPHC>",
                         f"<LastSelectedSPHC>{wanted[0]}</LastSelectedSPHC>", text, count=1)
        if n:
            path.write_bytes(new.encode("utf-16"))
            print(f"testbed: {path.name}: skirmish home city -> {wanted[0]}")


def show_profile(bed):
    p = bed_profile(bed)
    print(f"testbed: {bed}\n  exe   {p['sha256'][:8]} {p['build'] or 'unknown build'}\n  cfg   {bed / p['cfg']}\n"
          f"  AI    {bed / p['ai']}\n  maps  {bed / p['rm']}\n  games {p['my_games']}")


def profile_backup(bed):
    users = my_games(bed) / "Users3"
    stamp = time.strftime("%Y%m%d")
    files = sorted(users.glob("*.xml")) if users.exists() else []
    if not files:
        sys.exit(f"testbed: no profile in {users}")
    for path in files:
        target = path.with_name(f"{path.name}.bak-uhc-{stamp}")
        if target.exists():
            print(f"testbed: {target} exists; kept")
            continue
        shutil.copy2(path, target)
        print(f"testbed: {path} -> {target}")


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


FOLLOW_SLACK = 10.0  # metres a followed unit may walk before the camera moves


def exec_file(bed):
    return bed / "uhc-exec.txt"


def select_commands(ids, look=None):
    """Console commands that select all these units (number group 9 collects them one by one, since
    uiLookAtAndSelectUnit selects a single unit), then put the camera back on `look`."""
    commands = ["uiClearSelection()"]
    for i, uid in enumerate(ids):
        commands.append(f"uiLookAtAndSelectUnit({uid})")
        if i:
            commands.append("uiAddSelectNumberGroup(9)")
        commands.append("uiCreateNumberGroup(9)")
    if look is not None:
        commands.append(f"uiLookAtUnit({look})")
    return commands


def matching_units(proc, ids, protos, player=None):
    """Live units whose ID is in `ids` or whose proto name contains one of `protos` (lowercase)."""
    return [u for u in D.units(proc)
            if (proc.u32(u + 0x10) in ids
                or any(p in D.proto_name(proc, proc.u32(u + 0x5C)).lower() for p in protos))
            and proc.f32(u + 0x64) > 0
            and (player is None or D.unit_player(proc, u) == player)]


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


def bed_allows_second_copy(bed):
    """True if the bed's cfg has multipleInstances (the DLL then lets it run beside a copy from
    another folder)."""
    cfg = bed / bed_profile(bed)["cfg"]
    try:
        lines = cfg.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return False
    return any(line.split()[:1] and line.split()[0].lower() == "multipleinstances" for line in lines)


def launch(bed):
    running = game_processes()
    if any(path.lower() == str(bed / "age3y.exe").lower() for _, path in running):
        sys.exit("testbed: this copy is already running")
    if running and not bed_allows_second_copy(bed):
        # Another copy may belong to another session's test: never run two at once unless this
        # copy's cfg has multipleInstances (and the other session agreed).
        sys.exit("testbed: a game is already running: " + ", ".join(f"pid {p} {path}" for p, path in running))
    if running:
        print("testbed: another copy is running; this one starts beside it (multipleInstances)")
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
    place_window(window())
    print(f"testbed: main menu ready (pid {proc.pid}) on {test_monitor()[0]}")


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
        scn = my_games(bed) / "Scenario" / f"{name}.age3Yscn"
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
    # The game skips techs inside comments, so they take no index (WoL's techtree has some).
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
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
    # p0= groups belong to Gaia, which the map must not place as a player.
    players = sorted(({g[0] for g in groups} | {t[0] for t in techs} | {1, 2}) - {0})
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
    folder = bed / bed_profile(bed)["rm"]
    (folder / f"{name}.xs").write_text(text, encoding="utf-8")
    (folder / f"{name}.xml").write_text(MAP_INFO, encoding="utf-8")
    print(f"testbed: wrote {folder / (name + '.xs')} ({len(groups)} unit groups, {len(techs)} techs, "
          f"{len(timed)} timed effects)")


def scenario(bed, map_name, seed):
    proc = process() or sys.exit("testbed: the game is not running")
    name = f"uhc-{map_name}"
    target = my_games(bed) / "Scenario" / f"{name}.age3Yscn"
    target.unlink(missing_ok=True)
    record = scenario_record(bed)
    names = set(record.read_text(encoding="utf-8").split()) if record.exists() else set()
    record.write_text("\n".join(sorted(names | {name})) + "\n", encoding="utf-8")
    if D.world(proc):  # a game or the editor is open: back to the main menu first
        run_commands(bed, ["leaveGame()"])
        wait_until(lambda: not D.world(proc), 60, 1, "the main menu")
        time.sleep(3)
    # flashHitpointBarsOnDamage: the game shows the HP bar of every damaged unit, for videos.
    run_commands(bed, ['config("DontPauseWhenLosingFocus")', 'config("flashHitpointBarsOnDamage")',
                       "startRandomGame(true)"])
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


class PerfReader:
    """The performance numbers of `record --perf`, read once a second from outside the game with
    tools/perfprobe.py's readers (no thread is suspended): UHC.dll's perfStats mapping (fps, longest
    frame, frames over 50 ms), the main thread's CPU, the working set, the game's own update and
    render averages and the simulation speed. Like perfprobe, it clears perfStats' per-interval
    longest frame, so do not run perfprobe on the same game at the same time."""

    COLUMNS = ["t", "game_s", "fps", "max_frame_ms", "over50", "over100", "update_ms", "render_ms", "sim_speed",
               "main_cpu", "process_cpu", "ws_mb", "private_mb"]

    def __init__(self, pid, csv_path=None):
        import perfprobe as P
        self.P, self.pid = P, pid
        self.process = P.k32.OpenProcess(P.PROCESS_ACCESS, False, pid)
        self.proc = D.Process(pid)
        self.stats = P.open_stats(pid)
        self.threads = {}
        self.t0 = self.last_t = time.perf_counter()
        self.last_frames, self.last_sim, self.over50, self.over100 = None, None, 0, 0
        self.lines, self.next = [], 0.0
        self.rows = []
        self.csv = open(csv_path, "w", encoding="utf-8", newline="") if csv_path else None
        if self.csv:
            self.csv.write(",".join(self.COLUMNS) + "\n")
        if self.stats is None:
            print("testbed: --perf: no perfStats mapping (add perfStats to the cfg); fps and frame times are missing")
        else:
            self.last_frames = P.read_stats(self.stats)  # also clears the longest frame seen before the recording
        self._cpu(1.0)

    def _cpu(self, dt):
        P, usage = self.P, {}
        for tid in P.thread_ids(self.pid):
            if tid not in self.threads:
                handle = P.k32.OpenThread(P.THREAD_QUERY_INFORMATION, False, tid)
                times = P.thread_times(handle) if handle else None
                if times is not None:
                    self.threads[tid] = {"handle": handle, "created": times[0], "last": times[1]}
                continue
            th = self.threads[tid]
            times = P.thread_times(th["handle"])
            if times is not None:
                usage[tid] = (times[1] - th["last"]) / 1e7 / dt * 100
                th["last"] = times[1]
        main = min(self.threads, key=lambda t: self.threads[t]["created"]) if self.threads else None
        return usage.get(main, 0.0), sum(usage.values())

    def text(self, now):
        if now < self.next:
            return self.lines
        self.next = now + 1.0
        P = self.P
        dt = max(now - self.last_t, 1e-3)
        self.last_t = now
        main_cpu, process_cpu = self._cpu(dt)
        memory = P.PROCESS_MEMORY_COUNTERS_EX()
        memory.cb = ctypes.sizeof(memory)
        P.psapi.GetProcessMemoryInfo(self.process, ctypes.byref(memory), memory.cb)
        row = {"t": f"{now - self.t0:.1f}", "main_cpu": f"{main_cpu:.0f}", "process_cpu": f"{process_cpu:.0f}",
               "ws_mb": f"{memory.WorkingSetSize / 2**20:.0f}", "private_mb": f"{memory.PrivateUsage / 2**20:.0f}"}
        timers = P.game_timers(self.process)
        if timers is not None:
            row["update_ms"], row["render_ms"] = f"{timers[0]:.1f}", f"{timers[1]:.1f}"
        played = game_time(self.proc)
        if played is not None:
            row["game_s"] = f"{played / 1000:.1f}"
        sim = P.sim_clock(self.process)
        if sim is not None:
            if self.last_sim is not None and sim >= self.last_sim:
                row["sim_speed"] = f"{(sim - self.last_sim) / 1000 / dt:.2f}"
        self.last_sim = sim
        if self.stats is None:
            self.stats = P.open_stats(self.pid)
        stats = P.read_stats(self.stats) if self.stats else None
        if stats:
            if self.last_frames is not None:
                row["fps"] = f"{(stats['frames'] - self.last_frames['frames']) / dt:.0f}"
                self.over50 += stats["over50"] - self.last_frames["over50"]
                self.over100 += stats["over100"] - self.last_frames["over100"]
                row["over50"], row["over100"] = str(self.over50), str(self.over100)
            row["max_frame_ms"] = f"{stats['max_us'] / 1000:.0f}"
            self.last_frames = stats
        self.rows.append(row)
        if self.csv:
            self.csv.write(",".join(str(row.get(c, "")) for c in self.COLUMNS) + "\n")
            self.csv.flush()
        g = row.get
        self.lines = [
            f"perf  fps {g('fps', '-')}  frame max {g('max_frame_ms', '-')} ms  >50 ms {g('over50', '-')}"
            f"  sim {g('sim_speed', '-')}x",
            f"perf  CPU main {row['main_cpu']}%  update {g('update_ms', '-')} ms  render {g('render_ms', '-')} ms"
            f"  memory {row['ws_mb']} MB",
        ]
        return self.lines

    def close(self):
        if self.csv:
            self.csv.close()
        fps = [float(r["fps"]) for r in self.rows if r.get("fps")]
        worst = max((float(r["max_frame_ms"]) for r in self.rows if r.get("max_frame_ms")), default=0)
        cpu = [float(r["main_cpu"]) for r in self.rows]
        if self.rows:
            print(f"testbed: perf over {len(self.rows)} s: fps avg {sum(fps) / len(fps) if fps else 0:.0f}, "
                  f"longest frame {worst:.0f} ms, frames over 50 ms {self.over50}, over 100 ms {self.over100}, "
                  f"main CPU avg {sum(cpu) / len(cpu):.0f}%")


class Overlay:
    """Live text drawn on every recorded frame, so a video shows what the numbers do: the game time,
    the hit points of the watched units (unit IDs or proto names, matched again every second, so new
    units appear and dead ones go) and the latest UHC.log lines that match a pattern."""

    def __init__(self, bed, watch, log_pattern, follow=None, perf=None, select=None, look=None):
        self.proc = process()
        self.perf = perf
        self.bed, self.follow, self.next_follow = bed, follow, 0.0
        self.follow_center = None
        # --select: the units kept selected (their HP bars show); `selected` is the set last applied.
        self.select = select or []
        self.select_ids = {int(w) for w in self.select if w.isdigit()}
        self.select_protos = [w.lower() for w in self.select if not w.isdigit()]
        self.selected, self.look = set(), look
        self.ids = {int(w) for w in watch if w.isdigit()}
        self.protos = [w.lower() for w in watch if not w.isdigit()]
        self.pattern = re.compile(log_pattern) if log_pattern else None
        self.log_path = bed / "UHC.log"
        # Show the lines of the current game: read from the last scenario load on.
        data = self.log_path.read_bytes() if self.log_path.exists() else b""
        start = data.rfind(b"loadScenario(")
        self.log_pos = data.rfind(b"\n", 0, start) + 1 if start >= 0 else len(data)
        self.log_lines, self.units, self.lines = [], [], []
        self.next_scan = self.next_text = 0.0

    def text(self, now):
        if self.follow is not None and now >= self.next_follow and self.proc is not None:
            # Keep that unit in view without moving the camera all the time: re-centre only when
            # it has walked FOLLOW_SLACK metres from where the camera was last centred, and stop
            # following once it is gone (no jump to wherever a dead unit's ID leads).
            # perfExecFile runs the file within 30 frames; written without waiting.
            self.next_follow = now + 0.5
            unit = next((u for u in D.units(self.proc) if self.proc.i32(u + 0x10) == self.follow), None)
            if unit is None or self.proc.f32(unit + 0x64) <= 0:
                self.follow = None
            else:
                pos = (self.proc.f32(unit + 0x14), self.proc.f32(unit + 0x1C))
                far = self.follow_center is None or math.dist(pos, self.follow_center) > FOLLOW_SLACK
                path = exec_file(self.bed)
                if far and not path.exists():
                    tmp = path.with_suffix(".tmp")
                    tmp.write_text(f"uiLookAtUnit({self.follow})\r\n", encoding="ascii")
                    os.replace(tmp, path)
                    self.follow_center = pos
        perf_lines = self.perf.text(now) if self.perf is not None else []
        if self.select and now >= self.next_scan and self.proc is not None:
            # Re-select only when a unit appears (a dead one leaves the selection by itself), so
            # the camera is not touched again for nothing.
            live = {self.proc.i32(u + 0x10)
                    for u in matching_units(self.proc, self.select_ids, self.select_protos, 1)}
            path = exec_file(self.bed)
            if live - self.selected and not path.exists():
                look = self.follow if self.follow is not None else self.look
                tmp = path.with_suffix(".tmp")
                tmp.write_text("\r\n".join(select_commands(sorted(live), look)) + "\r\n", encoding="ascii")
                os.replace(tmp, path)
                self.selected = live
        if now < self.next_text or self.proc is None:
            return perf_lines + self.lines
        proc = self.proc
        if now >= self.next_scan:
            self.next_scan = now + 1.0
            self.units = [u for u in D.units(proc)
                          if proc.u32(u + 0x10) in self.ids
                          or any(p in D.proto_name(proc, proc.u32(u + 0x5C)).lower() for p in self.protos)]
            self.read_log()
        lines = [f"game time {(game_time(proc) or 0) / 1000:.1f} s"]
        if len(self.units) > 6:  # many units: one count per proto and player instead of one line each
            counts = {}
            for unit in self.units:
                key = (D.proto_name(proc, proc.u32(unit + 0x5C)), D.unit_player(proc, unit))
                counts[key] = counts.get(key, 0) + 1
            lines += [f"{n} x {name} (player {player})" for (name, player), n in sorted(counts.items())]
        for unit in self.units if len(self.units) <= 6 else []:
            proto = proc.u32(unit + 0x5C)
            block = proc.u32(unit + 0xB4)  # the unit's own LOS is [[unit+B4h]+90h]
            los = f", LOS {proc.f32(block + 0x90):.0f}" if block else ""
            lines.append(f"unit {proc.u32(unit + 0x10)} {D.proto_name(proc, proto)} (player {D.unit_player(proc, unit)}): "
                         f"HP {proc.f32(unit + 0x64):.1f} / {proc.f32(proto + 0x98):.0f}{los}")
        if not self.ids and not self.protos:
            lines = lines[:1]  # --perf or --log alone: no unit lines
        self.lines = lines + self.log_lines[-4:]
        self.next_text = now + 0.25
        return perf_lines + self.lines

    def read_log(self):
        if self.pattern is None or not self.log_path.exists():
            return
        try:  # the game may hold the file a moment while it writes; try again next second
            with open(self.log_path, "rb") as f:
                f.seek(self.log_pos)
                data = f.read()
        except PermissionError:
            return
        self.log_pos += len(data)
        self.log_lines += [line[:140] for line in data.decode("utf-8", "replace").splitlines()
                           if self.pattern.search(line)]


def record(path, seconds=30.0, fps=10, width=1280, overlay=None, crop=None):
    """Films the game window to an H.264 MP4 in real time, with PrintWindow like `shot` (it works
    while the window is covered). A frame that takes longer than 1/fps to capture is repeated, so
    the video keeps the game's real speed. With an Overlay, its text is drawn on every frame.
    crop = (fraction, cx, cy): film only that fraction of the window, centred on (cx, cy) (window
    fractions), enlarged to the video size: a close-up without zooming the game's camera."""
    ffmpeg = ffmpeg_path()
    # The game stops drawing while another window has the foreground (PrintWindow then returns
    # black frames), so bring it to the front first and give it a moment to draw again.
    hwnd = focus()
    time.sleep(1.0)
    rc = RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rc))
    w, h = rc.right - rc.left, rc.bottom - rc.top
    sx, sy, sw, sh = 0, 0, w, h
    if crop is not None:
        frac, cx, cy = crop
        sw, sh = max(64, int(w * frac)), max(64, int(h * frac))
        sx = min(max(0, int(cx * w - sw / 2)), w - sw)
        sy = min(max(0, int(cy * h - sh / 2)), h - sh)
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
    line_height = max(14, oh // 48)
    font = gdi32.CreateFontW(-line_height, 0, 0, 0, 700, 0, 0, 0, 0, 0, 0, 5, 0, "Consolas")  # bold, ClearType
    gdi32.SelectObject(small_dc, font)
    gdi32.SetBkMode(small_dc, 2)                 # OPAQUE: each line on a black band
    gdi32.SetBkColor(small_dc, 0x000000)
    gdi32.SetTextColor(small_dc, 0x0000FFFF)     # yellow (COLORREF is 0x00BBGGRR)

    def grab():
        user32.PrintWindow(hwnd, full_dc, 2)  # PW_RENDERFULLCONTENT
        gdi32.StretchBlt(small_dc, 0, 0, ow, oh, full_dc, sx, sy, sw, sh, 0x00CC0020)  # SRCCOPY
        if overlay is not None:
            for i, line in enumerate(overlay.text(time.perf_counter())):
                gdi32.TextOutW(small_dc, 8, oh // 18 + i * (line_height + 2), line, len(line))
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
    # Guard the camera: a cursor moved by someone else to a screen edge scrolls it. Put the cursor
    # back on its parked spot, and centre again on the framed unit, whenever it moves.
    parked, cursor, moved = park_cursor(), POINT(), 0
    t0 = time.perf_counter()
    try:
        while written < total:
            delay = t0 + written / fps - time.perf_counter()
            if delay > 0:
                time.sleep(delay)
            user32.GetCursorPos(ctypes.byref(cursor))
            if (cursor.x, cursor.y) != parked:
                user32.SetCursorPos(*parked)
                moved += 1
                look = overlay.look if overlay is not None else None
                if look is not None and overlay.bed is not None and not exec_file(overlay.bed).exists():
                    tmp = exec_file(overlay.bed).with_suffix(".tmp")
                    tmp.write_text(f"uiLookAtUnit({look})\r\n", encoding="ascii")
                    os.replace(tmp, exec_file(overlay.bed))
            frame = grab()
            captured += 1
            due = min(total, max(written + 1, int((time.perf_counter() - t0) * fps) + 1))
            encoder.stdin.write(frame * (due - written))
            written = due
    finally:
        encoder.stdin.close()
        encoder.wait()
        if overlay is not None and overlay.perf is not None:
            overlay.perf.close()
        for obj in (full, small, font):
            gdi32.DeleteObject(obj)
        for dc in (full_dc, small_dc):
            gdi32.DeleteDC(dc)
        user32.ReleaseDC(None, screen)
    game_end = game_time(proc) if proc else None
    game = f", game time {game_start} -> {game_end} ms" if game_start is not None and game_end is not None else ""
    size = os.path.getsize(path) / 1e6 if os.path.exists(path) else 0
    print(f"testbed: {path}: {seconds:g} s at {fps} fps, {ow}x{oh}, {captured} frames captured "
          f"({written - captured} repeated){game}, {size:.1f} MB, ffmpeg exit {encoder.returncode}"
          + (f"; the cursor was moved {moved} time(s) and put back" if moved else ""))


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


# --- the test monitor ------------------------------------------------------------------------------

class MONITORINFOEXW(ctypes.Structure):
    _fields_ = [("cbSize", wt.DWORD), ("rcMonitor", RECT), ("rcWork", RECT), ("dwFlags", wt.DWORD),
                ("szDevice", wt.WCHAR * 32)]


MONITORENUMPROC = ctypes.WINFUNCTYPE(wt.BOOL, wt.HMONITOR, wt.HDC, ctypes.POINTER(RECT), wt.LPARAM)
user32.EnumDisplayMonitors.argtypes = [wt.HDC, ctypes.c_void_p, MONITORENUMPROC, wt.LPARAM]
user32.GetMonitorInfoW.argtypes = [wt.HMONITOR, ctypes.POINTER(MONITORINFOEXW)]
user32.SetWindowPos.argtypes = [wt.HWND, wt.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wt.UINT]


def monitors():
    """(device, primary, work rect) of every monitor, in physical pixels (the script is DPI aware)."""
    out = []

    def visit(handle, _dc, _rect, _data):
        info = MONITORINFOEXW()
        info.cbSize = ctypes.sizeof(info)
        if user32.GetMonitorInfoW(handle, ctypes.byref(info)):
            w = info.rcWork
            out.append((info.szDevice, bool(info.dwFlags & 1), (w.left, w.top, w.right, w.bottom)))
        return True

    user32.EnumDisplayMonitors(None, None, MONITORENUMPROC(visit), 0)
    return sorted(out, key=lambda m: m[0])


def test_monitor():
    """The work rect tests use: unset or primary for the primary monitor, secondary for the first
    other one, or a number N for DISPLAYN."""
    mons = monitors()
    choice = os.environ.get("UHC_TEST_MONITOR", "").strip().lower()
    if choice in ("", "primary"):
        return next(m for m in mons if m[1])
    if choice == "secondary":
        return next((m for m in mons if not m[1]), mons[0])
    if choice.isdigit():
        for m in mons:
            if m[0].upper().endswith(f"DISPLAY{choice}"):
                return m
        sys.exit(f"testbed: no monitor DISPLAY{choice}; run `monitors`")
    sys.exit(f"testbed: UHC_TEST_MONITOR={choice!r}: use primary, secondary or a display number")


def place_window(hwnd):
    """Moves the game window onto the test monitor (top-left of its work area) unless it is there."""
    device, _primary, (left, top, right, bottom) = test_monitor()
    rc = RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rc))
    cx, cy = (rc.left + rc.right) // 2, (rc.top + rc.bottom) // 2
    if left <= cx < right and top <= cy < bottom:
        return
    # SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
    user32.SetWindowPos(hwnd, None, left, top, 0, 0, 0x0001 | 0x0004 | 0x0010)
    time.sleep(0.3)


def show_monitors():
    chosen = test_monitor()
    for device, primary, rect in monitors():
        mark = "  <- tests" if device == chosen[0] else ""
        print(f"  {device}  {'primary' if primary else '       '}  work area {rect}{mark}")


def send(*inputs):
    arr = (INPUT * len(inputs))(*inputs)
    user32.SendInput(len(inputs), arr, ctypes.sizeof(INPUT))


def focus():
    hwnd = window()
    place_window(hwnd)
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.25)
    if user32.GetForegroundWindow() != hwnd:
        # Windows refuses SetForegroundWindow to a process that is not in the foreground; a real
        # click on the title bar activates the window without sending a click into the game.
        rc = RECT()
        user32.GetWindowRect(hwnd, ctypes.byref(rc))
        user32.SetCursorPos((rc.left + rc.right) // 2, rc.top + 10)
        time.sleep(0.1)
        down, up = INPUT(type=0), INPUT(type=0)
        down.u.mi = MOUSEINPUT(0, 0, 0, 0x0002, 0, 0)
        up.u.mi = MOUSEINPUT(0, 0, 0, 0x0004, 0, 0)
        send(down)
        time.sleep(0.05)
        send(up)
        time.sleep(0.3)
        # Left on the title bar, the cursor sits at the screen's top edge and scrolls the camera.
        park_cursor()
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


def real_drag(x1, y1, x2, y2, steps=12):
    """A real left-button drag in client coordinates, e.g. a selection box."""
    hwnd = focus()
    def move(cx, cy):
        pt = POINT(int(cx), int(cy))
        user32.ClientToScreen(hwnd, ctypes.byref(pt))
        user32.SetCursorPos(pt.x, pt.y)
    move(x1, y1)
    time.sleep(0.15)
    down = INPUT(type=0)
    down.u.mi = MOUSEINPUT(0, 0, 0, 0x0002, 0, 0)
    send(down)
    for i in range(1, steps + 1):
        time.sleep(0.03)
        move(x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps)
    time.sleep(0.1)
    up = INPUT(type=0)
    up.u.mi = MOUSEINPUT(0, 0, 0, 0x0004, 0, 0)
    send(up)
    time.sleep(0.2)


def park_cursor():
    """Puts the cursor in the top right of the play area: away from the units (no tooltip) and from
    the screen edges (a cursor at an edge scrolls the camera)."""
    hwnd = window()
    rc = RECT()
    user32.GetClientRect(hwnd, ctypes.byref(rc))
    pt = POINT(rc.right * 7 // 8, rc.bottom // 6)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    user32.SetCursorPos(pt.x, pt.y)
    return pt.x, pt.y


def real_wheel(cx, cy, steps):
    """Real mouse-wheel steps at a client point: the camera zooms in (steps > 0) or out."""
    hwnd = focus()
    pt = POINT(cx, cy)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    user32.SetCursorPos(pt.x, pt.y)
    time.sleep(0.15)
    for _ in range(abs(steps)):
        i = INPUT(type=0)
        i.u.mi = MOUSEINPUT(0, 0, 120 if steps > 0 else -120, 0x0800, 0, 0)
        send(i)
        time.sleep(0.12)


def front():
    """Keeps the game window above every other window (HWND_TOPMOST, until it closes) and focuses it.
    The game draws nothing while another window covers it or has the focus, and focus() clicks the
    title bar, which must then be the game's."""
    hwnd = window()
    user32.SetWindowPos(hwnd, wt.HWND(-1), 0, 0, 0, 0, 0x0001 | 0x0002)  # SWP_NOSIZE | SWP_NOMOVE
    time.sleep(0.3)
    focus()


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
        target = bed / bed_profile(bed)["cfg"]
        target.write_text(text, encoding="utf-8")
        print(f"testbed: wrote {target}")
    (bed / "UHC.log").unlink(missing_ok=True)


def steam_listing():
    rows = []
    for path in sorted(STEAM_BIN.rglob("*")):
        if path.is_file():
            st = path.stat()
            rows.append(f"{path.relative_to(STEAM_BIN)}\t{st.st_size}\t{st.st_mtime_ns}")
    return rows


def wol_listing():
    rows = []
    for path in sorted(STEAM_WOL.iterdir()):
        if path.is_file():
            st = path.stat()
            rows.append(f"{path.name}\t{st.st_size}\t{st.st_mtime_ns}")
    for sub in ("Startup", "data", "AI4", "RM4"):
        for path in sorted((STEAM_WOL / sub).rglob("*")):
            if path.is_file():
                st = path.stat()
                rows.append(f"{path.relative_to(STEAM_WOL)}\t{st.st_size}\t{st.st_mtime_ns}")
    return rows


def safety_wol(mode):
    listing = LISTING.with_name("uhc-wol-listing.tsv")
    for name, want in (("age3y.exe", WOL_SHA256), ("uhc.dll", WOL_DLL_SHA256)):
        digest = hashlib.sha256((STEAM_WOL / name).read_bytes()).hexdigest()
        print(f"testbed: Steam WoL {name} {'is' if digest == want else 'is NOT'} the known build ({digest[:8]})")
        if digest != want:
            sys.exit(1)
    rows = wol_listing()
    if mode == "record":
        listing.write_text("\n".join(rows), encoding="utf-8")
        print(f"testbed: recorded {len(rows)} files in {listing}")
        return
    before = listing.read_text(encoding="utf-8").splitlines() if listing.exists() else None
    if before is None:
        sys.exit("testbed: no recorded WoL listing; run `safety record wol` first")
    changed = sorted(set(before) ^ set(rows))
    print(f"testbed: Steam Wars of Liberty {'unchanged' if not changed else 'CHANGED'} ({len(rows)} files)")
    for row in changed[:20]:
        print("  ", row)
    if changed:
        sys.exit(1)


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
    if cmd == "monitors":
        show_monitors()
        return
    if cmd == "safety":
        mode = next((a for a in args if a in ("record", "check")), "check")
        safety_wol(mode) if "wol" in args else safety(mode)
        return
    global BED
    bed = BED = bed_folder(bed_arg)
    if cmd == "deploy":
        deploy(bed, args[0] if args else None)
    elif cmd == "profile":
        if args[:1] == ["backup"]:
            profile_backup(bed)
        elif args[:1] == ["hc"]:
            profile_hc(bed, " ".join(args[1:]))
        else:
            show_profile(bed)
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
        watch = args[args.index("--watch") + 1].split(",") if "--watch" in args else []
        log_pattern = args[args.index("--log") + 1] if "--log" in args else None
        follow = int(args[args.index("--follow") + 1]) if "--follow" in args else None
        frame = int(args[args.index("--frame") + 1]) if "--frame" in args else None
        select = args[args.index("--select") + 1].split(",") if "--select" in args else []
        zoom = int(args[args.index("--zoom") + 1]) if "--zoom" in args else 0
        crop = None
        if "--crop" in args:  # --crop F[@cx,cy]: film that fraction of the window around (cx, cy)
            spec = args[args.index("--crop") + 1]
            frac, _, at = spec.partition("@")
            cx, cy = (float(v) for v in at.split(",")) if at else (0.5, 0.43)
            crop = (float(frac), cx, cy)
        perf_csv = args[args.index("--perf-csv") + 1] if "--perf-csv" in args else None
        flags = {i for f in ("--watch", "--log", "--follow", "--frame", "--select", "--zoom", "--crop", "--perf-csv")
                 if f in args for i in (args.index(f), args.index(f) + 1)}
        look = frame if frame is not None else follow
        ids = []
        if select:
            # Select them before filming (the Overlay keeps the selection up to date).
            proc = process()
            ids = sorted(proc.i32(u + 0x10) for u in matching_units(
                proc, {int(w) for w in select if w.isdigit()}, [w.lower() for w in select if not w.isdigit()], 1))
            run_commands(bed, select_commands(ids, look))
        elif look is not None:
            # Centre the camera on that unit once, before filming, and leave it still.
            run_commands(bed, [f"uiLookAtUnit({look})"])
        if zoom:
            # Centre first, then zoom with the cursor on the centred unit (the middle of the window):
            # the wheel zooms towards the cursor, so the units stay in the middle of the picture.
            rc = RECT()
            user32.GetClientRect(window(), ctypes.byref(rc))
            real_wheel(rc.right // 2, rc.bottom // 2, zoom)
            park_cursor()
            # The game smooths the zoom: the camera keeps moving for a few seconds. Let it settle,
            # then centre again so the picture is still from the first frame.
            time.sleep(4.0)
            if look is not None:
                run_commands(bed, [f"uiLookAtUnit({look})"])
            time.sleep(0.5)
        # A cursor left at a screen edge scrolls the camera while the game has the focus: park it.
        park_cursor()
        flags |= {i for i, a in enumerate(args) if a == "--perf"}
        pos = [a for i, a in enumerate(args) if i not in flags]
        perf = None
        if "--perf" in args or perf_csv:
            pid = bed_pid() or sys.exit("testbed: the game is not running")
            perf = PerfReader(pid, perf_csv)
        overlay = (Overlay(bed, watch, log_pattern, follow, perf, select, look)
                   if watch or log_pattern or follow is not None or perf or select else None)
        if overlay is not None:
            overlay.selected = set(ids)
        record(pos[0], float(pos[1]) if len(pos) > 1 else 30.0, int(pos[2]) if len(pos) > 2 else 10,
               int(pos[3]) if len(pos) > 3 else 1280, overlay, crop)
    elif cmd == "click":
        posted_click(int(args[0]), int(args[1]))
    elif cmd == "rclick":
        real_click(int(args[0]), int(args[1]), len(args) > 2 and args[2] == "right")
    elif cmd == "drag":
        real_drag(*(int(a) for a in args[:4]))
    elif cmd == "wheel":
        real_wheel(int(args[0]), int(args[1]), int(args[2]))
    elif cmd == "front":
        front()
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
