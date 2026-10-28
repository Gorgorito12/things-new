"""Log the code that writes (or reads) up to four 4-byte fields in a running age3y.exe.

Usage:
    python -I tools/re/trace_writes.py <log file> TARGET [TARGET ...] [--rw] [--minutes N]
                                       [--max-per-chain N]

TARGET is one of
    0xADDRESS                   a fixed address
    hc:PLAYER+OFFSET            a field of a player's home city object, e.g.
                                hc:1+0x18C (land shipment point) and hc:1+0x190 (water)
    unit:PROTO[:PLAYER]+OFFSET  a field of the first unit of PLAYER (default 1) whose proto is
                                PROTO, e.g. unit:Explorer+0x64 (hitpoints, a float)

Hardware breakpoints stop right after the accessing instruction, so the log shows the address
of the NEXT instruction ("after"); the writer is the instruction just before it. With --rw,
reads stop too. hc: and unit: targets are resolved every 2 s while a game is running; a unit
target moves to another matching unit when its unit dies or leaves the world.

For every distinct (target, instruction, call chain) the first few hits are logged with the
value before and after (as integer and as float); a summary is written on detach.

Examples (the traces in docs/engine-symbols.md):
    python -I tools/re/trace_writes.py gather.txt hc:1+0x18C hc:1+0x190 --rw
    python -I tools/re/trace_writes.py hp.txt unit:Explorer+0x64
"""
import os
import re
import struct
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import debugger as D  # noqa: E402


class Target:
    def __init__(self, text):
        self.text = text
        self.kind, self.address, self.unit = None, 0, 0
        fixed = re.fullmatch(r"0x[0-9a-fA-F]+", text)
        hc = re.fullmatch(r"hc:(\d+)\+(0x[0-9a-fA-F]+|\d+)", text)
        unit = re.fullmatch(r"unit:([^:+]+)(?::(\d+))?\+(0x[0-9a-fA-F]+|\d+)", text)
        if fixed:
            self.kind, self.fixed = "fixed", int(text, 16)
        elif hc:
            self.kind, self.player, self.offset = "hc", int(hc.group(1)), int(hc.group(2), 0)
        elif unit:
            self.kind, self.proto = "unit", unit.group(1)
            self.player = int(unit.group(2)) if unit.group(2) else 1
            self.offset = int(unit.group(3), 0)
        else:
            raise ValueError(f"bad TARGET {text!r}")
        # Checked before attaching: the fields watched are 4 bytes and the objects are aligned.
        if (self.fixed if self.kind == "fixed" else self.offset) % 4:
            raise ValueError(f"TARGET {text!r} is not 4-byte aligned")

    def resolve(self, proc, live_units):
        """Updates self.address; returns True if it changed."""
        old = self.address
        if self.kind == "fixed":
            self.address = self.fixed
        elif self.kind == "hc":
            hc = D.home_city(proc, self.player)
            self.address = hc + self.offset if hc else 0
        elif self.kind == "unit":
            alive = self.unit in live_units and proc.f32(self.unit + 0x64) > 0.0
            if not alive:
                self.unit = next((u for u in live_units
                                  if D.unit_player(proc, u) == self.player
                                  and D.proto_name(proc, proc.u32(u + 0x5C)) == self.proto
                                  and proc.f32(u + 0x64) > 0.0), 0)
            self.address = self.unit + self.offset if self.unit else 0
        return self.address != old


def main(argv):
    minutes, max_per_chain, kind = 20.0, 3, "write"
    texts = []
    i = 1
    while i < len(argv):
        if argv[i] == "--minutes":
            minutes, i = float(argv[i + 1]), i + 2
        elif argv[i] == "--max-per-chain":
            max_per_chain, i = int(argv[i + 1]), i + 2
        elif argv[i] == "--rw":
            kind, i = "rw", i + 1
        else:
            texts.append(argv[i])
            i += 1
    if not argv or not 1 <= len(texts) <= 4:
        sys.exit(__doc__)
    log = D.Logger(argv[0])
    targets = [Target(t) for t in texts]
    deadline = time.time() + 60 * minutes

    log(f"waiting for age3y.exe; {kind} breakpoints on " + ", ".join(t.text for t in targets))
    pid = D.wait_for_pid(deadline)
    if pid is None:
        log("the game did not start in time")
        return
    proc = D.Process(pid)
    dbg = D.Debugger(pid, log)
    last = {}  # target index -> last raw value
    seen = {}
    next_resolve = [0.0]
    active = []  # target index per breakpoint slot

    def refresh():
        live = set(D.units(proc)) if any(t.kind == "unit" for t in targets) else set()
        changed = False
        for t in targets:
            changed |= t.resolve(proc, live)
        if changed:
            active[:] = [n for n, t in enumerate(targets) if t.address]
            dbg.set_breakpoints([D.Breakpoint(targets[n].address, kind, 4, targets[n].text) for n in active])
            for n in active:
                t = targets[n]
                last[n] = proc.read(t.address, 4)
                what = f" ({D.unit_info(proc, t.unit)})" if t.kind == "unit" else ""
                log(f"watching {t.text} at {t.address:#x}{what}")
            if not active:
                log("no target resolved; waiting for a game")

    def on_idle():
        if time.time() >= next_resolve[0]:
            next_resolve[0] = time.time() + 2
            refresh()

    def on_hit(tid, ctx, slots):
        after = D.reg(ctx, "eip")
        chain = proc.call_chain(D.reg(ctx, "esp"))
        for slot in slots:
            n = active[slot]
            t = targets[n]
            before, now = last.get(n) or b"\0\0\0\0", proc.read(t.address, 4) or b"\0\0\0\0"
            last[n] = now
            key = (n, after, tuple(chain[:5]))
            seen[key] = seen.get(key, 0) + 1
            if seen[key] > max_per_chain:
                continue
            (b_int,), (a_int,) = struct.unpack("<I", before), struct.unpack("<I", now)
            (b_flt,), (a_flt,) = struct.unpack("<f", before), struct.unpack("<f", now)
            log(f"{t.text} #{seen[key]} after={after:#x} value {b_int:#x} -> {a_int:#x} "
                f"(float {b_flt:.2f} -> {a_flt:.2f})")
            log(f"    chain {[hex(c) for c in chain]}")
            log("    " + " ".join(f"{r}={D.reg(ctx, r):#x}" for r in ("eax", "ecx", "edx", "ebx", "esi", "edi", "ebp", "esp")))
            if t.kind == "unit" and a_flt <= 0.0 and t.offset == 0x64:
                next_resolve[0] = 0.0  # the unit died; look for another one

    try:
        time.sleep(2)
        dbg.attach()
        refresh()
        dbg.run(deadline, on_hit, on_idle)
    finally:
        dbg.detach()
        for (n, after, chain), count in sorted(seen.items(), key=lambda kv: -kv[1]):
            log(f"  {targets[n].text} x{count} after={after:#x} chain {[hex(c) for c in chain]}")


if __name__ == "__main__":
    main(sys.argv[1:])
