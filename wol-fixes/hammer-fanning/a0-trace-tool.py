# Trace the Explorer's power attack: Attack tag events, the flag-17h test after a shot, the "done" branch.
import sys, time
sys.path.insert(0, r"C:\Users\Jeison\Documents\GitHub\UHC-r1127-H\tools\re")
import debugger as D
pid = int(sys.argv[1]); out = sys.argv[2]; minutes = float(sys.argv[3])
path = D._image_path(pid)
assert path and 'WoLReal4' in path, path
log = D.Logger(out)
proc = D.Process(pid)
dbg = D.Debugger(pid, log)
bps = [D.Breakpoint(0x48F739, label="attack-tag-event"),
       D.Breakpoint(0x48F992, label="after-shot-flag17"),
       D.Breakpoint(0x48F12B, label="done-after-shot"),
       D.Breakpoint(0x48F7DA, label="tag-state-test")]
def now():
    try: return proc.i32(proc.u32(proc.u32(0xC66234) + 0x13C) + 0x108)
    except Exception: return -1
def on_hit(tid, ctx, slots):
    ebp = D.reg(ctx, "ebp")
    try:
        unit = proc.u32(ebp + 0x10); uid = proc.i32(unit + 0x10)
    except Exception:
        return
    if uid != 0: return
    try:
        nbits = proc.u32(ebp + 0x34); bits = proc.read(proc.u32(ebp + 0x30), (nbits + 7) // 8).hex() if nbits < 512 else '?'
        st = proc.read(ebp + 0x61, 1)[0]; shots = proc.i32(ebp + 0x68); tgt = proc.i32(ebp + 0x14)
    except Exception as e:
        bits, st, shots, tgt = str(e), -1, -1, -1
    for s in slots:
        log(f"{now()} ms {bps[s].label} ua={ebp:#x} eax={D.reg(ctx,'eax'):#x} state={st:#x} shots={shots} target={tgt} uaflags({nbits})={bits}")
dbg.attach(); dbg.set_breakpoints(bps)
try:
    dbg.run(time.time() + 60 * minutes, on_hit)
finally:
    dbg.detach(); log("detached")
