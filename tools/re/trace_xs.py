"""Log the XS compiler's error messages in a running age3y.exe (hardware breakpoints).

Usage:
    python -I tools/re/trace_xs.py <log file> [--minutes N]

When an XS script fails to compile, the game shows only the last message, for example
"XS: Error 0003: could not compile file 'aiLoaderStandard.xs'.", and every AI player then does
nothing. This tracer logs each parser error with its argument, so the cause shows, for example
"Error 0014: 'cTacticNormal' is already defined." (docs/modding-guide.md, "Tactics files").

Breakpoints (stock Steam build, docs/engine-symbols.md, "XS compiler"):
  0xA48EB4  parser error with one argument (thiscall: format, argument)
  0xA48F61  parser error without argument (thiscall: format)
  0xA5667F  compiler message (cdecl: message log, format, ...), for example Error 0003
  0x5B4E4C  compile one file: logged with the error count it starts with, so each error can be
            matched to a compile

The script waits for age3y.exe to start, attaches, and detaches without killing the game when
the game exits or the time runs out. Start it, then start the game that fails. Stop it with
Ctrl+C, never by killing it.
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import debugger as D  # noqa: E402

PARSER_ERROR, PARSER_ERROR0, MESSAGE, COMPILE = 0xA48EB4, 0xA48F61, 0xA5667F, 0x5B4E4C
MAX_LINES = 500


def main(argv):
    minutes = 20.0
    if "--minutes" in argv:
        i = argv.index("--minutes")
        minutes = float(argv[i + 1])
        argv = argv[:i] + argv[i + 2:]
    if len(argv) != 1:
        sys.exit(__doc__)
    log = D.Logger(argv[0])
    deadline = time.time() + 60 * minutes

    log("waiting for age3y.exe")
    pid = D.wait_for_pid(deadline)
    if pid is None:
        log("the game did not start in time")
        return
    proc = D.Process(pid)
    dbg = D.Debugger(pid, log)
    lines = [0]

    def on_hit(tid, ctx, slots):
        if lines[0] >= MAX_LINES:
            return
        lines[0] += 1
        esp, eip = D.reg(ctx, "esp"), D.reg(ctx, "eip")
        chain = [hex(c) for c in proc.call_chain(esp, 5)]
        if eip == PARSER_ERROR:
            log(f"error: {proc.cstr(proc.u32(esp + 4), 200)!r} with {proc.cstr(proc.u32(esp + 8), 200)!r} "
                f"(chain {chain})")
        elif eip == PARSER_ERROR0:
            log(f"error: {proc.cstr(proc.u32(esp + 4), 200)!r} (chain {chain})")
        elif eip == MESSAGE:
            fmt = proc.cstr(proc.u32(esp + 8), 200)
            arg = proc.u32(esp + 12)
            value = proc.wstr(arg, 100) if "%S" in fmt else proc.cstr(arg, 100) if "%s" in fmt else ""
            log(f"message: {fmt!r} {value!r} (chain {chain})")
        elif eip == COMPILE:
            messages = proc.u32(D.reg(ctx, "ecx") + 0x118)
            log(f"compile: {proc.i32(messages + 0x14)} error(s) before it (chain {chain})")

    try:
        time.sleep(2)  # let a just-started game map its image
        dbg.attach()
        dbg.set_breakpoints([D.Breakpoint(PARSER_ERROR, label="parser error"),
                             D.Breakpoint(PARSER_ERROR0, label="parser error"),
                             D.Breakpoint(MESSAGE, label="message"), D.Breakpoint(COMPILE, label="compile")])
        dbg.run(deadline, on_hit)
    finally:
        dbg.detach()
        log(f"{lines[0]} line(s) logged")


if __name__ == "__main__":
    main(sys.argv[1:])
