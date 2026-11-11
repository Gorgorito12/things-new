"""Unattended legacy benchmark in a test copy: start age3y.exe, load a saved game through UHC.dll's
console harness, unpause it, record with tools/perfprobe.py (and optionally tools/threadprobe.py at
the same time), then leave and close the game. docs/performance.md §8 describes the protocol.

Usage: python -I tools/legacybench.py <label> [--save uhcbench25] [--seconds 150] [--hz 200]
                                      [--bed C:\\AoE3-UHC-Perf] [--threadprobe]

Needs in <bed>\\Startup\\uhc.cfg (wol.cfg in a WoL copy): ignoreRegistryPath, perfStats, and perfExecFile <bed>\\uhc-exec.txt.
It prints the load time: from the game taking the loadGame command (the exec file polled every 20 ms)
until the end of the last frame over 50 ms after it (perfStats' ring of slow frames, version 2), and when
the world exists and perfStats counts 5 frames within 0.25 s.
Outputs go to rea/evidence/age3y-b1a1dab7/bench-<label>.csv (+ .stacks.gz, .samples.txt) and, with
--threadprobe, bench-<label>.threads.csv (+ .threads.txt, its console summary).

It sends no keyboard or mouse input and never activates the game window: the intros are skipped with
+noIntroCinematics, the window opens without activation, commands go through perfExecFile, the window
is closed with a posted WM_CLOSE, and both probes get the game's pid. The game allows one running copy
per machine (a `Global\\...` semaphore, 0x55A185 in docs/engine-symbols.md), so the script refuses to
start while another age3y.exe runs, unless the bed's cfg has `multipleInstances background`: then this
copy runs beside the other one, behind every window, and the numbers share the CPU with it.
"""
import argparse
import ctypes
import ctypes.wintypes as wt
import os
import struct
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(REPO, "tools")
WORKER_JOBS = 0xC692E4  # skinning jobs run by the worker; the count moves while the main menu animates
k32 = ctypes.WinDLL("kernel32", use_last_error=True)
k32.OpenProcess.restype = wt.HANDLE
k32.ReadProcessMemory.argtypes = [wt.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                                  ctypes.POINTER(ctypes.c_size_t)]
k32.QueryFullProcessImageNameW.argtypes = [wt.HANDLE, wt.DWORD, wt.LPWSTR, ctypes.POINTER(wt.DWORD)]
k32.CloseHandle.argtypes = [wt.HANDLE]
k32.OpenFileMappingW.restype = wt.HANDLE
k32.OpenFileMappingW.argtypes = [wt.DWORD, wt.BOOL, wt.LPCWSTR]
k32.MapViewOfFile.restype = ctypes.c_void_p
k32.MapViewOfFile.argtypes = [wt.HANDLE, wt.DWORD, wt.DWORD, wt.DWORD, ctypes.c_size_t]
k32.UnmapViewOfFile.argtypes = [ctypes.c_void_p]
user32 = ctypes.WinDLL("user32", use_last_error=True)
WNDENUMPROC = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
user32.EnumWindows.argtypes = [WNDENUMPROC, wt.LPARAM]
user32.GetWindowThreadProcessId.argtypes = [wt.HWND, ctypes.POINTER(wt.DWORD)]
user32.GetWindowTextW.argtypes = [wt.HWND, wt.LPWSTR, ctypes.c_int]
user32.IsWindowVisible.argtypes = [wt.HWND]
user32.PostMessageW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]


def read_u32(process, va):
    buf, got = ctypes.create_string_buffer(4), ctypes.c_size_t()
    ok = k32.ReadProcessMemory(process, ctypes.c_void_p(va), buf, 4, ctypes.byref(got))
    return struct.unpack("<I", buf.raw)[0] if ok else 0


def world(process):
    game = read_u32(process, 0xC66234)  # docs/engine-symbols.md: game object; +0x13C world
    return read_u32(process, game + 0x13C) if game else 0


def running_games():
    """(pid, exe path) of every running age3y.exe."""
    out = []
    listing = subprocess.run(["tasklist", "/FI", "IMAGENAME eq age3y.exe", "/FO", "CSV", "/NH"],
                             capture_output=True, text=True, errors="replace").stdout
    for line in listing.splitlines():
        fields = line.strip().strip('"').split('","')
        if len(fields) < 2 or not fields[1].isdigit():
            continue
        pid, path = int(fields[1]), ""
        handle = k32.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
        if handle:
            buf, size = ctypes.create_unicode_buffer(1024), wt.DWORD(1024)
            if k32.QueryFullProcessImageNameW(handle, 0, buf, ctypes.byref(size)):
                path = buf.value
            k32.CloseHandle(handle)
        out.append((pid, path))
    return out


def bed_cfg(bed):
    """The cfg UHC.dll reads in that bed: Startup\\wol.cfg in a WoL copy, else Startup\\uhc.cfg."""
    wol = os.path.join(bed, "Startup", "wol.cfg")
    return wol if os.path.exists(wol) else os.path.join(bed, "Startup", "uhc.cfg")


def runs_in_background(bed):
    """True if the bed's cfg has `multipleInstances background` (UHC.dll's keys are case-insensitive)."""
    try:
        with open(bed_cfg(bed), encoding="utf-8", errors="replace") as f:
            for line in f:
                words = line.split("//")[0].replace("=", " ").lower().split()
                if words and words[0] == "multipleinstances" and "background" in words[1:]:
                    return True
    except OSError:
        pass
    return False


def start_lock():
    """The launch lock of tools/testbed.py: copies of a mod share My Games, and two that start together
    collide on the log file there ("Cannot create log file"). Held until the main menu runs."""
    lock = os.path.join(os.environ.get("TEMP", "."), "uhc-testbed-launch.lock")
    deadline = time.time() + 300
    while True:
        try:
            os.close(os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY))
            return lock
        except FileExistsError:
            try:
                if time.time() - os.stat(lock).st_mtime > 240:  # a launch that died
                    os.unlink(lock)
                    continue
            except OSError:
                continue
            if time.time() > deadline:
                sys.exit(f"another copy is still starting; if none is, delete {lock}")
            time.sleep(1)


def game_window(pid):
    """The game's main window, looked up by its process (never another copy's window)."""
    found = []

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
    return found[0] if found else 0


def console(bed, *commands, poll=0.5):
    """Queue console commands for UHC.dll's perfExecFile harness and wait until they ran."""
    path = os.path.join(bed, "uhc-exec.txt")
    with open(path + ".tmp", "w") as f:
        f.write("\r\n".join(commands) + "\r\n")
    os.replace(path + ".tmp", path)
    for _ in range(int(120 / poll)):
        if not os.path.exists(path):
            return
        time.sleep(poll)
    sys.exit("the game did not run the console commands (is perfExecFile in uhc.cfg?)")


def perf_shared(pid):
    """perfStats' shared block (Local\\UHCPerfStats-<pid>) as bytes, or None before the device exists:
    the Present count at offset 8; since version 2 the slow-frame count at 60, the QPC frequency at 64 and
    a ring of 64 (start, end) QPC pairs of the frames over 50 ms at 72."""
    mapping = k32.OpenFileMappingW(0x0004, False, f"Local\\UHCPerfStats-{pid}")  # FILE_MAP_READ
    if not mapping:
        return None
    view = k32.MapViewOfFile(mapping, 0x0004, 0, 0, 72 + 64 * 16)
    try:
        if not view:
            return None
        data = ctypes.string_at(view, 72 + 64 * 16)
        return data if struct.unpack_from("<I", data, 0)[0] == 0x50434855 else None
    finally:
        if view:
            k32.UnmapViewOfFile(ctypes.c_void_p(view))
        k32.CloseHandle(mapping)


def time_load(process, pid, start):
    """The load of a save, timed from `start` (time.perf_counter(), the QPC clock, when the game took the
    loadGame command). Returns (steady, last_long, long_count, long_total) in seconds: when the world exists
    and the game presents 5 frames within 0.25 s; when the last frame over 50 ms that began after `start`
    ended (perfStats' ring, read until the game has presented frames for 3 s without a new one: a frame
    enters the ring only when it ends, so the wait restarts while no frame is presented); how many such
    frames and their time."""
    marks, steady = [], None
    while time.perf_counter() - start < 300 and steady is None:
        data = perf_shared(pid) if world(process) else None
        if data is not None:
            now = time.perf_counter()
            marks.append((now, struct.unpack_from("<I", data, 8)[0]))
            marks = [(t, n) for t, n in marks if now - t <= 0.25]
            if marks[-1][1] - marks[0][1] >= 5:
                steady = now - start
        time.sleep(0.02)
    if steady is None:
        return None
    long_frames, quiet_since, presented, presented_at = {}, time.perf_counter(), None, time.perf_counter()
    while time.perf_counter() - quiet_since < 3 and time.perf_counter() - start < 300:
        data = perf_shared(pid)
        now = time.perf_counter()
        if data is not None and struct.unpack_from("<I", data, 4)[0] >= 2:
            frames_now, = struct.unpack_from("<I", data, 8)
            if frames_now != presented:
                presented, presented_at = frames_now, now
            elif now - presented_at > 0.1:  # a long frame is under way: it is not in the ring yet
                quiet_since = now
            count, = struct.unpack_from("<I", data, 60)
            freq, = struct.unpack_from("<q", data, 64)
            for i in range(max(0, count - 64), count):
                begin, end = struct.unpack_from("<qq", data, 72 + 16 * (i % 64))
                if begin / freq >= start - 0.1 and i not in long_frames:
                    long_frames[i] = (begin / freq, end / freq)
                    quiet_since = now
        time.sleep(0.05)
    frames = sorted(long_frames.values())
    if not frames:
        return steady, steady, 0, 0.0, ""
    last = max(end for _, end in frames) - start
    detail = ", ".join(f"{b - start:.2f}+{(e - b) * 1000:.0f}ms" for b, e in frames)
    return steady, max(steady, last), len(frames), sum(e - b for b, e in frames), detail


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("label")
    parser.add_argument("--save", default="uhcbench25")
    parser.add_argument("--seconds", type=int, default=150)
    parser.add_argument("--hz", type=int, default=200)
    parser.add_argument("--bed", default=r"C:\AoE3-UHC-Perf")
    parser.add_argument("--threadprobe", action="store_true")
    parser.add_argument("--load-probe", type=int, metavar="SECONDS", default=0,
                        help="also profile the load: perfprobe from just before loadGame, for SECONDS, into "
                             "bench-<label>-load.csv; the recording then starts after it")
    args = parser.parse_args()
    bed = os.path.abspath(args.bed)
    exe = os.path.join(bed, "age3y.exe")
    if "steamapps" in exe.lower():
        sys.exit(f"{bed} is inside a Steam library; use a test copy")
    evidence = os.path.join(REPO, "rea", "evidence", "age3y-b1a1dab7")
    csv_path = os.path.join(evidence, f"bench-{args.label}.csv")

    running = running_games()
    if any(path.lower() == exe.lower() for _, path in running):
        sys.exit(f"a game already runs from {bed}")
    if running and not runs_in_background(bed):  # one copy per machine; another session may be testing
        sys.exit("a game is already running: " + ", ".join(f"pid {pid} {path}" for pid, path in running) +
                 f"; add `multipleInstances background` to {bed_cfg(bed)} to run beside it")
    for pid, path in running:
        print(f"[{args.label}] note: pid {pid} ({path}) runs at the same time and shares the CPU", flush=True)

    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 4  # SW_SHOWNOACTIVATE: never take the focus from another copy's game
    lock = start_lock()
    try:
        game = subprocess.Popen([exe, "+noIntroCinematics"], cwd=bed, startupinfo=startup)
        process = k32.OpenProcess(0x0010 | 0x0400, False, game.pid)
        print(f"[{args.label}] started pid {game.pid}", flush=True)
        for _ in range(180):
            if game_window(game.pid):
                break
            time.sleep(1)
        else:
            sys.exit("no game window after 180 s")
        last, start = read_u32(process, WORKER_JOBS), time.time()
        while time.time() - start < 90:  # the main menu animates skinned units
            time.sleep(1)
            now = read_u32(process, WORKER_JOBS)
            if now - last > 200:
                break
            last = now
    finally:
        os.unlink(lock)
    load_probe = None
    if args.load_probe:
        load_probe = subprocess.Popen([sys.executable, "-I", os.path.join(TOOLS, "perfprobe.py"),
                                       csv_path.replace(".csv", "-load.csv"), str(args.load_probe), "1.0",
                                       "--pid", str(game.pid), "--sample-hz", str(args.hz)])
        time.sleep(2)
    console(bed, 'config("DontPauseWhenLosingFocus")', f'loadGame("{args.save}")', poll=0.02)
    print(f"[{args.label}] loading {args.save}", flush=True)
    load = time_load(process, game.pid, time.perf_counter())
    if load is None:
        print(f"[{args.label}] load: not timed (no world or no perfStats frames after 300 s)", flush=True)
    else:
        print(f"[{args.label}] load {load[1]:.2f} s (the last frame over 50 ms ends then; {load[2]} such frames, "
              f"{load[3]:.2f} s in all; the main loop runs again after {load[0]:.2f} s)", flush=True)
        print(f"[{args.label}] frames over 50 ms after loadGame (start s + length): {load[4]}", flush=True)
    time.sleep(10)
    if load_probe is not None:
        load_probe.wait()
    console(bed, "pause(0)")  # a loaded save starts paused
    print(f"[{args.label}] recording {args.seconds} s", flush=True)
    probes = [subprocess.Popen([sys.executable, "-I", os.path.join(TOOLS, "perfprobe.py"), csv_path,
                                str(args.seconds), "1.0", "--pid", str(game.pid), "--sample-hz", str(args.hz)])]
    if args.threadprobe:
        probes.append(subprocess.Popen([sys.executable, "-I", os.path.join(TOOLS, "threadprobe.py"), str(game.pid),
                                        csv_path.replace(".csv", ".threads.csv"), str(args.seconds), "1.0"],
                                       stdout=open(csv_path.replace(".csv", ".threads.txt"), "w")))
    for probe in probes:
        probe.wait()
    console(bed, "leaveGame()")
    time.sleep(4)
    hwnd = game_window(game.pid)
    if hwnd:
        user32.PostMessageW(hwnd, 0x0010, 0, 0)  # WM_CLOSE
    try:
        game.wait(30)
    except subprocess.TimeoutExpired:
        game.kill()  # no tracer is attached, so killing it is safe
        game.wait(30)
    print(f"[{args.label}] done, exit code {game.returncode}", flush=True)


if __name__ == "__main__":
    main()
