# Tools

Python 3 scripts, with no third-party packages except where noted. Run them with `python -I`
(isolated mode) from the repository root.

| Tool | What it does |
|---|---|
| [`gen_sites.py`](#gen_sitespy) | Writes `src/generated/sites.h` from the stock exe. |
| [`bar.py`](#barpy) | Lists and extracts files from the game's `.bar` archives. |
| [`xmbedit.py`](#xmbeditpy) | Checks, converts and edits compiled XML (`.xmb`). |
| [`re/trace_writes.py`](#retrace_writespy) | Logs the code that writes or reads a field in the running game. |
| [`re/trace_exec.py`](#retrace_execpy) | Logs who runs a code address in the running game. |
| [`re/inspect_unittypes.py`](#reinspect_unittypespy) | Shows a unit type's ID and the protos that carry it. |
| `re/debugger.py` | The shared debugger and game-memory helpers the `re/` scripts use. |
| `perfprobe.py`, `set_laa.py` | Part of the performance work in progress; see [docs/performance.md](../docs/performance.md) and each script's docstring. |

Never point a tool that writes at the Steam install. The data tools write only the output file
you name, and `gen_sites.py` only reads the exe.

## gen_sites.py

```
python -I tools/gen_sites.py "<Steam>\steamapps\common\Age Of Empires 3\bin\age3y.exe" [out.h]
```

Reads the bytes of every patch site in its `SITES` list from the stock exe and writes them, as C++
arrays, to `src/generated/sites.h` (or `out.h`). The DLL compares live memory with them before
patching. It refuses any exe whose SHA-256 is not the stock build's. To add a site, see
[developer-guide.md, section 3](../docs/developer-guide.md#3-adding-a-feature-step-by-step).

## bar.py

```
python -I tools/bar.py <archive.bar> [filter]
python -I tools/bar.py <archive.bar> [filter] --extract <output folder>
```

Reads the legacy archives (`data\Data*.bar`, `art\Art*.bar`, header `ESPN`). The filter is a
case-insensitive part of the stored path; `/` and `\` both work.

```
python -I tools/bar.py "<game>\data\Data3.bar" tactics/explorer
python -I tools/bar.py "<game>\art\Art4.bar" rev_banner --extract work
```

Files are written exactly as stored. Compiled XML usually starts with `l33t`: read it with
`xmbedit.py`. Stored paths that would leave the output folder are refused.

## xmbedit.py

```
python -I tools/xmbedit.py check <file.xmb>
python -I tools/xmbedit.py to-xml <file.xmb> <out.xml>
python -I tools/xmbedit.py add-unittype <in.xmb> <out.xmb> <Unit> <UnitType> [<Unit> <UnitType> ...]
```

- `check` decodes and re-encodes the file and confirms the result is byte-identical. Every
  command does this first, so an edit cannot change anything else.
- `to-xml` writes readable XML, with element names as stored (lowercase).
- `add-unittype` adds `<unittype>` entries to units of a `protoy.xml.XMB`. It warns about unit
  names it cannot find, and keeps the input's compression.

It handles compressed (`l33t` + zlib) and uncompressed (`X1`) files, version 8, the format of
the TAD data.

## re/trace_writes.py

```
python -I tools/re/trace_writes.py <log> TARGET [TARGET ...] [--rw] [--minutes N] [--max-per-chain N]
```

Hardware breakpoints on up to four 4-byte fields. `TARGET` is one of:
- `0xADDRESS`, a fixed address;
- `hc:PLAYER+OFFSET`, a field of a player's home city object, e.g. `hc:1+0x18C` (the land
  shipment point);
- `unit:PROTO[:PLAYER]+OFFSET`, a field of the first unit of `PLAYER` (default 1) with that
  proto, e.g. `unit:Explorer+0x64` (hit points). When the unit dies, it moves on to the next one.

`--rw` also stops on reads.

For every distinct writer and call chain, it logs the first hits, with the value before and after
(as an integer and as a float) and the registers. A summary is written when it detaches.

## re/trace_exec.py

```
python -I tools/re/trace_exec.py <log> SPEC [SPEC ...] [--minutes N] [--max-per-chain N]
```

`SPEC` is `ADDRESS[=LABEL][@UNIT]`, for example `0x9E0B53=heal-tick@[ecx+0x10]`. `UNIT`, when
given, names a register or a `[register+offset]` slot that holds a unit pointer; the log then
shows that unit's proto, owner and hit points. Each hit logs the registers and the call chain.

## re/inspect_unittypes.py

```
python -I tools/re/inspect_unittypes.py <Name> [<Name> ...] [--max N]
python -I tools/re/inspect_unittypes.py --list-abstract
```

Reads the running game's unit type table without attaching a debugger. It prints a name's ID,
whether it is a proto or an abstract type, and the protos that carry an abstract type. Use it to
confirm that a `<UnitType>` you added to `protoy.xml`, or one that `UHC.dll` registers, really
loaded.

```
> python -I tools/re/inspect_unittypes.py AbstractHealNonIdle
1667 unittype names: 1463 protos, 204 abstract types
AbstractHealNonIdle: abstract type ID 1666, bit 203; carried by 3 protos
    Surgeon
    ypMonkIndian
    ypMonkIndian2
```

## Using the tracers safely

- **Start a tracer before or while the game runs.** It waits up to `--minutes` for
  `age3y.exe`, attaches, and detaches when the game exits or the time runs out. The game keeps
  running.
- **Stop it with Ctrl+C, never by killing its process.** A hardware breakpoint left in the game
  after the debugger is gone crashes the game.
- **Only one debugger at a time.** `inspect_unittypes.py` does not attach, so it can run next to
  a tracer.
- **Hot addresses slow the game.** A breakpoint on code that runs thousands of times per second
  slows the game down while the tracer is attached.
- **The tracers only work with the stock build.** Their engine offsets come from
  [docs/engine-symbols.md](../docs/engine-symbols.md) and are valid only there (or for a
  UHC-patched copy of it).
