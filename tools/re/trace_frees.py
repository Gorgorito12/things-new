"""Crash watch plus a log of what the game frees in Granny, for the #78 crash (a model or animation used after
it was freed: age3y.exe 0x40C07C, granny2.dll+0x3A02A).

    set UHC_GAME_DIR=C:\\AoE3-UHC-WoLReal3
    python -I tools/re/trace_frees.py <out prefix> [--minutes N]

Waits for the copy's age3y.exe, attaches, and sets four hardware breakpoints on the paths that free Granny data
(SITES below): a model cache entry's unload (with the entry's file name), the loader's reload of a loaded entry,
GrannyFreeModelInstance (only counted: hundreds a second) and the part declaration's reload after an invalid bone.
At each hit the freed pointer is remembered with the time, the game time, the entry's name and the call chain; the
first hits of each chain go to <prefix>.log, every unload and reload to <prefix>.frees.tsv. (The first version,
used for the crash of 2026-11-22, broke on the four GrannyFreeFile/FreeModelInstance calls instead: 0x46F5DF,
0x43B607, 0x46E8D4, 0x588B30.) When the game crashes (a
second-chance exception) the report of debugger.crash_report (with the model's cache name at 0x40C07C) goes to
<prefix>.crash.json, together with every register, stack word and pointer read from the crashing visual that
equals a freed pointer, and the free that freed it. Stop it with Ctrl+C, never by killing it (breakpoints).
"""
import collections
import ctypes
import json
import os
import struct
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import debugger as D  # noqa: E402

SITES = [(0x46C210, "ModelUnload"), (0x46E7ED, "ModelReloadLoaded"), (0x46F5DF, "FreeModelInstance"),
         (0x658C35, "PartBoneReload")]
# 0x658C35: FUN_004F0187 (a "part" declaration: bone, mesh, shape, blueprint, effect) after its error "Invalid
#   bone name ... in part declaration for model ..., this probably means the bone was not defined in the unit's
#   anim XML" (0xC0B878): it calls the loader on the model (edi, a cache entry that is loaded), which unloads it.
# 0x46C210: a model cache entry's unload (ecx = the entry; [ecx+4] its file name, [ecx+8] the Granny file it
#   frees). Called by the loader 0x46D7C3 before every load (at 0x46D80D) and from 0x589003 and 0xAD9FFA.
# 0x46E7ED: the loader's branch for an entry that is already loaded ([ebp+8] != 0, ebp = the entry): a
#   reload, which frees the loaded file while model instances made from it may still exist.
NAMED = {0x46C210: "ecx", 0x46E7ED: "ebp", 0x658C35: "edi"}


def main(argv):
    if not argv:
        sys.exit(__doc__)
    prefix = argv[0]
    minutes = float(argv[argv.index("--minutes") + 1]) if "--minutes" in argv else 60
    log = D.Logger(prefix + ".log")
    deadline = time.time() + minutes * 60
    pid = D.wait_for_pid(deadline)
    if not pid:
        sys.exit("trace_frees: no game")
    dbg = D.Debugger(pid, log)
    dbg.attach()
    proc = D.Process(pid)
    dbg.set_breakpoints([D.Breakpoint(a, "exec", 1, label) for a, label in SITES])
    freed = {}  # pointer -> (site, entry name, time, game ms, chain)
    unloads = []  # every model unload that freed a file, in order
    per_chain = collections.Counter()
    tsv = open(prefix + ".frees.tsv", "a", encoding="utf-8")
    t0 = time.time()

    def game_ms():
        w = D.world(proc)
        return proc.u32(w + 0x108) if w else 0

    def on_hit(tid, ctx, slots):
        esp = D.reg(ctx, "esp")
        bp = dbg.breakpoints[slots[0]]
        label = bp.label
        name = ""
        if bp.address in NAMED:  # a model cache entry: the file it frees, and its name
            entry = D.reg(ctx, NAMED[bp.address])
            arg = proc.u32(entry + 8)
            pname = proc.u32(entry + 4)
            name = (proc.wstr(pname, 120) or proc.cstr(pname, 120)) if pname else ""
            if not arg:
                return  # nothing loaded: the loader's unload before a first load frees nothing
            if bp.address == 0x658C35:  # the error text the game just formatted: the bone and the model
                for i in range(48):
                    p = proc.u32(esp + 4 * i)
                    for text in ((proc.cstr(p, 300) if p else ""), (proc.wstr(p, 300) if p else "")):
                        if text and "part declaration" in text:
                            name = f"{name} | {text}"
                            break
                    else:
                        continue
                    break
        else:
            arg = proc.u32(esp)
        chain = proc.call_chain(esp, depth=6, scan=0x400)
        key = (label, tuple(chain[:4]))
        per_chain[key] += 1
        gms = game_ms()
        freed[arg] = (label, name, round(time.time() - t0, 1), gms, [f"{c:#x}" for c in chain])
        if bp.address in NAMED:
            unloads.append((gms, label, name, f"{arg:#x}", [f"{c:#x}" for c in chain]))
        if bp.address != 0x46F5DF:  # model instances are freed hundreds of times a second: only counted
            tsv.write(f"{time.time() - t0:.1f}\t{gms}\t{label}\t{arg:#x}\t{name}\t{' '.join(f'{c:#x}' for c in chain)}\n")
        if per_chain[key] <= 3 or (bp.address in NAMED and per_chain[key] <= 50):
            log(f"{label} {arg:#x} {name} game {gms} ms chain {' '.join(f'{c:#x}' for c in chain)}")

    event = (ctypes.c_ubyte * 192)()
    result = "deadline"
    try:
        while time.time() < deadline:
            if not D.k32.WaitForDebugEvent(event, 500):
                continue
            code, epid, tid = struct.unpack_from("<III", event, 0)
            status = D.DBG_CONTINUE
            try:
                if code == 1:
                    exc = struct.unpack_from("<I", event, 16)[0]
                    address = struct.unpack_from("<Q", event, 32)[0]
                    nparams = struct.unpack_from("<I", event, 40)[0]
                    info = [struct.unpack_from("<Q", event, 48 + 8 * i)[0] for i in range(min(nparams, 15))]
                    first_chance = struct.unpack_from("<I", event, 168)[0]
                    if exc in (0x80000004, 0x4000001E):
                        status = dbg._on_single_step(tid, on_hit)
                    elif exc in (0x80000003, 0x4000001F) and first_chance:
                        status = D.DBG_CONTINUE
                    else:
                        status = D.DBG_NOT_HANDLED
                        if not first_chance:
                            r = D.crash_report(proc, dbg.threads.get(tid), exc, address, info, first_chance)
                            regs = {k: int(v, 16) for k, v in r["registers"].items()}
                            esp = regs.get("esp", 0)
                            words = list(struct.unpack("<256I", proc.read(esp, 1024) or b"\0" * 1024)) if esp else []
                            looked = {f"reg {k}": v for k, v in regs.items()}
                            looked.update({f"stack+{4 * i:#x}": w for i, w in enumerate(words)})
                            ebx = regs.get("ebx", 0)
                            if address == 0x40C07C and ebx:
                                inst = proc.u32(ebx + 0x24)
                                looked["visual+24h (model instance)"] = inst
                                looked["[instance] (source model)"] = proc.u32(inst) if inst else 0
                            r["freed_matches"] = {k: {"value": f"{v:#x}", "freed": freed[v]}
                                                  for k, v in looked.items() if v in freed}
                            r["frees_seen"] = len(freed)
                            model = (r.get("model") or {})
                            mname = model.get("name_utf16") or model.get("name") or ""
                            r["unloads_of_this_model"] = [u for u in unloads if mname and u[2] == mname]
                            r["last_unloads"] = unloads[-20:]
                            r["frees_by_site"] = dict(collections.Counter(v[0] for v in freed.values()))
                            log(D.format_report(r))
                            log(f"freed matches: {json.dumps(r['freed_matches'])}")
                            with open(prefix + ".crash.json", "w", encoding="utf-8") as f:
                                json.dump(r, f, indent=1)
                            result = "crash"
                elif code == 2:
                    handle = struct.unpack_from("<Q", event, 16)[0]
                    dbg.threads[tid] = handle
                    dbg._apply(handle, False)
                elif code in (3, 6):
                    D.k32.CloseHandle(struct.unpack_from("<Q", event, 16)[0])
                elif code == 4:
                    dbg.threads.pop(tid, None)
                elif code == 5:
                    log(f"game exited, exit code {struct.unpack_from('<I', event, 16)[0]:#010x}")
                    dbg.attached = False
                    break
            finally:
                D.k32.ContinueDebugEvent(epid, tid, status)
    except KeyboardInterrupt:
        result = "stopped"
    finally:
        if dbg.attached:
            dbg.detach()
        tsv.close()
        log(f"trace_frees ended: {result}; {sum(per_chain.values())} frees")
        summary = collections.Counter()
        for (label, _), n in per_chain.items():
            summary[label] += n
        log("by site: " + ", ".join(f"{k} {v}" for k, v in summary.items()))
    return result


if __name__ == "__main__":
    main(sys.argv[1:])
