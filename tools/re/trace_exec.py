"""Log who executes up to four code addresses in a running age3y.exe (hardware breakpoints).

Usage:
    python -I tools/re/trace_exec.py <log file> SPEC [SPEC ...] [--minutes N] [--max-per-chain N]

SPEC is ADDRESS[=LABEL][@UNIT], for example
    0x9E0B53=heal-tick@[ecx+0x10]
    0x4C6D91=pred-0x41@esi
ADDRESS is where execution stops (an instruction boundary). UNIT, optional, names a register
or a [register+offset] memory slot that holds a unit pointer at that moment; the log then
shows the unit's proto name, owner and hitpoints.

For every distinct call chain (the first 5 return addresses) the first few hits are logged with
the registers and the chain; a summary with counts is written when the tracer detaches.

The script waits for age3y.exe to start, attaches, and detaches without killing the game when
the game exits or the time runs out. Start the game first or within the time limit.

Example (the heal trace in docs/engine-symbols.md, "Unit types and healing"):
    python -I tools/re/trace_exec.py heal-trace.txt 0x4C6D91=pred-0x41@esi \
        0x4C6DDD=pred-0x42@esi 0x9E0B53=heal-tick@[ecx+0x10] --minutes 20
"""
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import debugger as D  # noqa: E402


def parse_spec(text):
    m = re.fullmatch(r"(0x[0-9a-fA-F]+)(?:=([^@]+))?(?:@(.+))?", text)
    if not m:
        raise ValueError(f"bad SPEC {text!r}; expected ADDRESS[=LABEL][@UNIT]")
    address = int(m.group(1), 16)
    unit = None
    if m.group(3):
        text = m.group(3).lower()
        register = r"(e(?:ax|bx|cx|dx|si|di|bp|sp))"
        bare = re.fullmatch(register, text)
        slot = re.fullmatch(r"\[" + register + r"(?:\+(0x[0-9a-f]+|\d+))?\]", text)
        if bare:
            unit = (bare.group(1), 0, False)
        elif slot:
            unit = (slot.group(1), int(slot.group(2), 0) if slot.group(2) else 0, True)
        else:
            raise ValueError(f"bad UNIT {m.group(3)!r}; expected a register or [register+offset]")
    return D.Breakpoint(address, "exec", 1, m.group(2) or ""), unit


def unit_pointer(proc, ctx, unit):
    register, offset, deref = unit
    value = D.reg(ctx, register)
    return proc.u32(value + offset) if deref else value


def main(argv):
    minutes, max_per_chain = 20.0, 3
    specs = []
    i = 1
    while i < len(argv):
        if argv[i] == "--minutes":
            minutes, i = float(argv[i + 1]), i + 2
        elif argv[i] == "--max-per-chain":
            max_per_chain, i = int(argv[i + 1]), i + 2
        else:
            specs.append(argv[i])
            i += 1
    if not argv or not 1 <= len(specs) <= 4:
        sys.exit(__doc__)
    log = D.Logger(argv[0])
    parsed = [parse_spec(s) for s in specs]
    breakpoints = [bp for bp, _ in parsed]
    units = [unit for _, unit in parsed]
    deadline = time.time() + 60 * minutes

    log("waiting for age3y.exe; breakpoints: " + ", ".join(f"{bp.label} at {bp.address:#x}" for bp in breakpoints))
    pid = D.wait_for_pid(deadline)
    if pid is None:
        log("the game did not start in time")
        return
    proc = D.Process(pid)
    dbg = D.Debugger(pid, log)
    seen, totals = {}, [0] * len(breakpoints)

    def on_hit(tid, ctx, slots):
        esp = D.reg(ctx, "esp")
        chain = proc.call_chain(esp)
        for slot in slots:
            totals[slot] += 1
            key = (slot, tuple(chain[:5]))
            seen[key] = seen.get(key, 0) + 1
            if seen[key] > max_per_chain:
                continue
            bp = breakpoints[slot]
            extra = ""
            if units[slot] is not None:
                extra = f" unit {D.unit_info(proc, unit_pointer(proc, ctx, units[slot]))}"
            regs = " ".join(f"{r}={D.reg(ctx, r):#x}" for r in ("eax", "ecx", "edx", "ebx", "esi", "edi", "ebp", "esp"))
            # At a function's first instruction these are its first three stack arguments.
            regs += " args=" + ",".join(f"{proc.u32(esp + 4 * k):#x}" for k in (1, 2, 3))
            log(f"{bp.label} #{seen[key]} (thread {tid}){extra}")
            log(f"    chain {[hex(c) for c in chain]}")
            log(f"    {regs}")

    try:
        time.sleep(2)  # let a just-started game map its image
        dbg.attach()
        dbg.set_breakpoints(breakpoints)
        dbg.run(deadline, on_hit)
    finally:
        dbg.detach()
        log("totals: " + ", ".join(f"{bp.label} {n}" for bp, n in zip(breakpoints, totals)))
        for (slot, chain), n in sorted(seen.items(), key=lambda kv: -kv[1]):
            log(f"  {breakpoints[slot].label} x{n} chain {[hex(c) for c in chain]}")


if __name__ == "__main__":
    main(sys.argv[1:])
