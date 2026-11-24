"""Time the AI scripts in a running age3y.exe: each XS compile, and each AI player's script runs.

Usage:
    python -I tools/re/time_xs.py <log> [--minutes N] [--update-seconds S] [--target rules|update]
                                        [--csv <calls.csv>] [--no-update]

Start it at the main menu (UHC_GAME_DIR picks the copy among several), then start the game. It logs:
  - every compile of a file, with its name, the compiler object, the caller, the main thread's CPU
    time and the wall time it took, and the process's private bytes before and after;
  - for S seconds from the first one (default 120), every call of the target, per player: calls,
    CPU time per call (mean, 95th percentile, maximum), the calls over 10 ms, and the CPU per real
    second. Target `rules` (default): BXSRuntime::interpretRules called by BAI::update, the XS
    interpreter running an AI player's rules, the part a smaller script could change (the AI's
    event handlers and the other XS runtimes, triggers and the UI, are left out); `update`: BAI::update, the whole AI
    update (the script and the engine's knowledge base), called every frame for every AI player.
    --csv writes one row per call. --no-update times the compiles only.
Then it detaches and the game keeps running. Stop it early with Ctrl+C, never by killing it.

Breakpoints (stock Steam build, docs/engine-symbols.md, "XS compiler" and "Stutters"):
  0x5B52FF  compile a file: thiscall(compiler, ?, BString* file, ...), ret 14h; the file is [[esp+8]];
            once per AI player (through 0x5B50F6, from 0x720BD5), then the map and the triggers
  0x5B4E4C  compile one file (also each include): thiscall(compiler, BString* file, ...); [[esp+4]]
  0x428E1F  interpretRules: thiscall(runtime, context, currentTime, timeLimit, out); called by
            BAI::update at 0x721203 with ESI = the BAI, so the player is [ESI+4] at its entry
  0x720CA7  BAI::update: thiscall(BAI, int currentTime); the player is [BAI+4]
  DR3       the return address of the innermost timed call, moved on every entry and return
            (one hardware slot serves every pending call: the calls nest on one thread)

Times. The CPU time is the thread's cycle count (QueryThreadCycleTime, converted with a clock
measured at start), read while the thread is stopped at the entry and at the return: the time the
debugger keeps the game stopped is not in it, only the kernel's exception dispatch of the two
breakpoints. That floor is the smallest call seen (about 30 us here); the summary gives the totals
raw and with the floor taken off every call. The wall time also holds the debugger's own delay, so
it is only meaningful for compiles. While it times calls the game runs slower: measure frame times
and the AI's share of the frame without it, with perfprobe.py --sample-hz.
"""
import ctypes
import ctypes.wintypes as wt
import os
import struct
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import debugger as D  # noqa: E402

COMPILE_FILE, COMPILE_ONE = 0x5B52FF, 0x5B4E4C
TARGETS = {"rules": 0x428E1F, "update": 0x720CA7}  # BXSRuntime::interpretRules, BAI::update
NAMES = {COMPILE_FILE: "compile file", COMPILE_ONE: "compile one"}
RULES_FROM_AI = 0x721208  # the return of BAI::update's call of interpretRules
SLOW_MS = 10.0

k32 = D.k32
k32.QueryThreadCycleTime.argtypes = [wt.HANDLE, ctypes.POINTER(ctypes.c_ulonglong)]
k32.QueryThreadCycleTime.restype = wt.BOOL
k32.GetCurrentThread.restype = wt.HANDLE


class _MemCounters(ctypes.Structure):
    _fields_ = [("cb", wt.DWORD), ("PageFaultCount", wt.DWORD)] + \
               [(n, ctypes.c_size_t) for n in ("PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage",
                                               "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage",
                                               "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage",
                                               "PrivateUsage")]


D.psapi.GetProcessMemoryInfo.argtypes = [wt.HANDLE, ctypes.POINTER(_MemCounters), wt.DWORD]


def private_mb(handle):
    c = _MemCounters()
    c.cb = ctypes.sizeof(c)
    return c.PrivateUsage / 2 ** 20 if D.psapi.GetProcessMemoryInfo(handle, ctypes.byref(c), c.cb) else 0.0


def cycles(handle):
    value = ctypes.c_ulonglong()
    return value.value if k32.QueryThreadCycleTime(handle, ctypes.byref(value)) else 0


def cycle_hz():
    """The rate of QueryThreadCycleTime, from a busy loop on this thread (best of three)."""
    me = k32.GetCurrentThread()
    best = 0.0
    for _ in range(3):
        c0, t0 = cycles(me), time.perf_counter()
        while time.perf_counter() - t0 < 0.2:
            pass
        best = max(best, (cycles(me) - c0) / (time.perf_counter() - t0))
    return best


def pct(values, q):
    s = sorted(values)
    return s[min(len(s) - 1, int(q * len(s)))] if s else 0.0


def main(argv):
    def opt(name, default=None, flag=False):
        nonlocal argv
        if name not in argv:
            return default
        i = argv.index(name)
        if flag:
            argv = argv[:i] + argv[i + 1:]
            return True
        value = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
        return value

    minutes = float(opt("--minutes", 30))
    update_seconds = float(opt("--update-seconds", 120))
    target_name = opt("--target", "rules")
    csv_path = opt("--csv")
    no_update = opt("--no-update", flag=True)
    if len(argv) != 1 or target_name not in TARGETS:
        sys.exit(__doc__)
    target = TARGETS[target_name]
    NAMES[target] = target_name
    log = D.Logger(argv[0])
    hz = cycle_hz()
    log(f"cycle clock {hz / 1e6:.1f} MHz; timing {target_name} at {target:#x}")
    end = [time.time() + 60 * minutes]

    log("waiting for age3y.exe")
    pid = D.wait_for_pid(end[0])
    if pid is None:
        log("the game did not start in time")
        return
    proc = D.Process(pid)
    dbg = D.Debugger(pid, log)
    frames = {}        # tid -> [(function, entry esp, return address, cycles, wall, info)]
    calls = []         # (wall s, player, game time ms, cpu ms)
    first = [None]
    compiles = [0]
    csv = open(csv_path, "w", encoding="utf-8") if csv_path else None
    if csv:
        csv.write("wall_s,player,game_ms,cpu_ms\n")

    def set_return(ctx, address):
        """Point DR3 at a return address in this thread's context (written back by the debugger)."""
        struct.pack_into("<I", ctx, D.OFF_DR[3], address)
        dbg.breakpoints[3].address = address

    def on_hit(tid, ctx, slots):
        handle = dbg.threads.get(tid)
        now_c, now_w = cycles(handle), time.perf_counter()
        esp, eip = D.reg(ctx, "esp"), D.reg(ctx, "eip")
        stack = frames.setdefault(tid, [])
        if eip in (COMPILE_FILE, COMPILE_ONE, target):
            ret = proc.u32(esp)
            if eip == target:
                if no_update or (target_name == "rules" and ret != RULES_FROM_AI):
                    return  # another XS runtime (triggers, the UI), or an AI's event handler
                # The player is [BAI+4]; at interpretRules' first instruction ESI is still BAI::update's BAI
                # ([runtime+4] is not the player: it reads 5 for player 2).
                bai = D.reg(ctx, "esi" if target_name == "rules" else "ecx")
                info = (proc.i32(bai + 4), proc.i32(esp + (8 if target_name == "rules" else 4)))
                if first[0] is None:
                    first[0] = now_w
                    end[0] = min(end[0], time.time() + update_seconds)
                    log(f"first {target_name} call (player {info[0]}, game time {info[1]} ms); timing for "
                        f"{update_seconds:.0f} s")
            else:
                name = proc.wstr(proc.u32(proc.u32(esp + (8 if eip == COMPILE_FILE else 4))), 120)
                mem = private_mb(proc.handle)
                info = (name, D.reg(ctx, "ecx"), mem)
                compiles[0] += 1
                log(f"{NAMES[eip]} enter '{name}' compiler {D.reg(ctx, 'ecx'):#x} return {ret:#x} "
                    f"depth {len(stack)} private {mem:.1f} MB (chain {[hex(c) for c in proc.call_chain(esp, 6)]})")
            stack.append((eip, esp, ret, now_c, now_w, info))
            set_return(ctx, ret)
            return
        # A return site: pop every call whose frame lies below the stack pointer now.
        while stack and stack[-1][1] < esp:
            fn, _, ret, c0, w0, info = stack.pop()
            cpu_ms = (now_c - c0) / hz * 1000
            if fn == target:
                calls.append((now_w, info[0], info[1], cpu_ms))
                if csv:
                    csv.write(f"{now_w - first[0]:.4f},{info[0]},{info[1]},{cpu_ms:.4f}\n")
            else:
                mem = private_mb(proc.handle)
                log(f"{NAMES[fn]} return '{info[0]}' ok {D.reg(ctx, 'eax') & 0xFF} cpu {cpu_ms:.1f} ms "
                    f"wall {(now_w - w0) * 1000:.1f} ms private {mem:.1f} MB ({mem - info[2]:+.1f})")
        set_return(ctx, stack[-1][2] if stack else 0)

    try:
        time.sleep(2)  # let a just-started game map its image
        dbg.attach()
        # DR3 starts on a return site of compile one (in compile file); it moves to each pending return.
        dbg.set_breakpoints([D.Breakpoint(COMPILE_FILE, label="compile file"),
                             D.Breakpoint(COMPILE_ONE, label="compile one"),
                             D.Breakpoint(target, label=target_name),
                             D.Breakpoint(0x5B532C, label="return")])
        result = dbg.run(lambda: end[0], on_hit)
        log(f"stopped: {result}")
    except KeyboardInterrupt:
        log("stopped: Ctrl+C")
    finally:
        dbg.detach()
        if csv:
            csv.close()
        summarize(log, target_name, calls, compiles[0])


def summarize(log, name, calls, compiles):
    log(f"{compiles} compile(s) timed, {len(calls)} {name} call(s) timed")
    if not calls:
        return
    span = max(c[0] for c in calls) - min(c[0] for c in calls) or 1.0
    floor = min(c[3] for c in calls)
    log(f"{name} calls over {span:.1f} s of real time (the game runs slower while traced); smallest call "
        f"{floor * 1000:.1f} us, taken as the tracer's floor")
    log("player  calls  calls/s  cpu ms: total  -floor    mean    p95     max  over 10 ms  ms per s -floor")
    rows = [(p, [c[3] for c in calls if c[1] == p]) for p in sorted({c[1] for c in calls})]
    rows.append(("all", [c[3] for c in calls]))
    for player, mine in rows:
        net = sum(mine) - floor * len(mine)
        log(f"{player!s:>6} {len(mine):6d} {len(mine) / span:8.1f} {sum(mine):13.1f} {net:7.1f} {sum(mine) / len(mine):7.3f} "
            f"{pct(mine, 0.95):6.3f} {max(mine):7.2f} {sum(1 for m in mine if m > SLOW_MS):6d} {net / span:15.2f}")


if __name__ == "__main__":
    main(sys.argv[1:])
