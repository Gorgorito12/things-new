"""Unattended legacy benchmark in a test copy: start age3y.exe, load a saved game through UHC.dll's
console harness, unpause it, record with tools/perfprobe.py (and optionally tools/threadprobe.py at
the same time), then leave and close the game. docs/performance.md §8 describes the protocol.

Usage: python -I tools/legacybench.py <label> [--save uhcbench25] [--seconds 150] [--hz 200]
                                      [--bed C:\\AoE3-UHC-Perf] [--threadprobe]

Needs in <bed>\\Startup\\uhc.cfg: ignoreRegistryPath, perfStats, and perfExecFile <bed>\\uhc-exec.txt.
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


def runs_in_background(bed):
    """True if the bed's uhc.cfg has `multipleInstances background` (UHC.dll's keys are case-insensitive)."""
    try:
        with open(os.path.join(bed, "Startup", "uhc.cfg"), encoding="utf-8", errors="replace") as f:
            for line in f:
                words = line.split("//")[0].replace("=", " ").lower().split()
                if words and words[0] == "multipleinstances" and "background" in words[1:]:
                    return True
    except OSError:
        pass
    return False


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


def console(bed, *commands):
    """Queue console commands for UHC.dll's perfExecFile harness and wait until they ran."""
    path = os.path.join(bed, "uhc-exec.txt")
    with open(path + ".tmp", "w") as f:
        f.write("\r\n".join(commands) + "\r\n")
    os.replace(path + ".tmp", path)
    for _ in range(240):
        if not os.path.exists(path):
            return
        time.sleep(0.5)
    sys.exit("the game did not run the console commands (is perfExecFile in uhc.cfg?)")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("label")
    parser.add_argument("--save", default="uhcbench25")
    parser.add_argument("--seconds", type=int, default=150)
    parser.add_argument("--hz", type=int, default=200)
    parser.add_argument("--bed", default=r"C:\AoE3-UHC-Perf")
    parser.add_argument("--threadprobe", action="store_true")
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
                 f"; add `multipleInstances background` to {bed}\\Startup\\uhc.cfg to run beside it")
    for pid, path in running:
        print(f"[{args.label}] note: pid {pid} ({path}) runs at the same time and shares the CPU", flush=True)

    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 4  # SW_SHOWNOACTIVATE: never take the focus from another copy's game
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
    console(bed, 'config("DontPauseWhenLosingFocus")', f'loadGame("{args.save}")')
    print(f"[{args.label}] loading {args.save}", flush=True)
    for _ in range(180):
        if world(process):
            break
        time.sleep(1)
    time.sleep(10)
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
