# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Reverse engineer Age of Empires III: The Asian Dynasties (`age3y.exe`) with REA, and build a **new `UHC.dll`** that drops into the existing UHC loader. It is a successor to the community UnHardCoded patch ([danielpereira/AoE3UnHardcoded](https://github.com/danielpereira/AoE3UnHardcoded)). Before adding features, verify every site upstream patches against the stock exe; that work is tracked in `docs/uhc-address-map.md`.

All binary analysis goes through the REA MCP server (`mcp__rea__*`, deferred tools: load them with ToolSearch). Load the `reverse-engineer-anything` skill before the first REA call.

## Commands

CMake and MSVC come from VS 2026 (`C:\Program Files\Microsoft Visual Studio\18\Insiders`) and are not on PATH. Use a VS x86 developer prompt, or call `Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe` by full path.

```
cmake -S . -B build -G "Visual Studio 18 2026" -A Win32   # must be Win32; x64 fails on purpose
cmake --build build --config Release                      # -> build\Release\UHC.dll
dumpbin /exports build\Release\UHC.dll                    # must list _UHCMain@0
```

There are no tests yet. Nothing here launches the game.

## Layout

- `src/`: the DLL. It currently only identifies the host and logs the config path to `UHC.log` next to the exe.
- `docs/binaries.md`: hashes of every `age3y.exe` / `UHC.dll` build in the install, the loader stub layout, and what each mod's exe patches.
- `docs/uhc-address-map.md`: every upstream patch site, with a verification status per row.
- `docs/engine-symbols.md`: functions, globals, IAT slots and object offsets named by upstream, with a status per row.
- `reference/AoE3UnHardcoded/` (gitignored): shallow clone of upstream. **It has no license.** Read it for addresses and behavior, but never copy its code into `src/`. Zydis (MIT) is the only clearly reusable dependency.
- `rea/` (gitignored): REA snapshots (`rea/snapshots/`) and exported evidence bundles (`rea/evidence/`).

## Target

| | |
|---|---|
| Path | `C:\Program Files (x86)\Steam\steamapps\common\Age Of Empires 3\bin\age3y.exe` |
| SHA-256 | `b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d` (11,598,648 B) |
| Format | PE32 i386, TimeDateStamp `0x49EF86AC`, SizeOfImage `0xB22000`, EP VA `0x5876AC` |
| Layout | ImageBase `0x400000`; no ASLR, no NX, not Large-Address-Aware |

Without ASLR, static VAs are the runtime addresses. For `.text`, `.rdata` and `.data`, file offset = VA − `0x400000`. `.rsrc` is shifted by another `0x14000`.

## UHC loader contract

A UHC exe is the stock exe with the Authenticode certificate stripped (hence 11,591,680 B) plus a byte patch. **The import table is unchanged.**

- The entry point is redirected to a stub at VA `0xB836BE`. The stub calls `LoadLibraryA("UHC.dll")`, then `GetProcAddress("_UHCMain@0")`, calls that function, then jumps to the original EP. If either step fails, it shows a MessageBox and exits.
- `UHCMain` therefore runs **before the game's own startup code**. It must be `extern "C" __declspec(dllexport) void __stdcall`.
- The config path is a wide string of at most 20 chars at VA `0xC65083`, default `Startup\uhc.cfg`.
- Fixed addresses are only valid in this build. `src/dllmain.cpp` checks ImageBase, TimeDateStamp, SizeOfImage and the `"UHC.dll"` string before touching any of them; keep that guard.

Full byte layout: `docs/binaries.md`.

## REA setup on this machine (configured 2026-10-27)

- Provider: Ghidra 12.1.4 at `C:\Tools\ghidra_12.1.4_PUBLIC`, with JDK 21 at `C:\Tools\jdk-21.0.12.1+1`. Neither is on PATH and no global env vars are set.
  - REA 6.7.0 accepts only Ghidra 12.1.x; do not upgrade to 12.2.
  - On Windows, REA finds Java only through `JAVA_HOME`.
- The env lives in `~/.claude.json` under `mcpServers.rea`:
  - `env`: `GHIDRA_INSTALL_DIR`, `JAVA_HOME`, `REA_ANALYSIS_PROVIDER=ghidra`, `REA_GHIDRA_STARTUP_TIMEOUT_MS=1800000`, `GHIDRA_HEADLESS_MAXMEM=8G`
  - plus a per-server `"timeout": 2400000`
  - If `binary_session` shows Ghidra unavailable, check that block first. To check outside MCP, set the same variables in a shell and run `rea doctor --provider ghidra --json`.
- The Windows "P0" Ghidra mode is read-only:
  - `annotate_native_function`, `set_address_name` and comments are unavailable, so record names and findings in `docs/` instead.
  - The Ghidra project is deleted on `close_binary`; a new MCP session re-analyzes from scratch. The first analysis of the 11.6 MB exe can take 15–30 minutes. Never cancel it: cancelling discards the database.
- `binary_session {}` output (~70 KB) overflows the tool result and is saved to a file. `jq` is not installed, so parse it with `python -I`.

## Working with REA

- Open the stock exe with `open_binary` and `provider_id: "ghidra"`, using the path above. Then use focused tools: `search_strings`, `search_procedures`, `analyze_function`, `procedure_pseudo_code`, `procedure_assembly`, `read_function_instructions`, `xrefs`, `procedure_callers` / `procedure_callees`, `resolve_containing_procedure`, `read_bytes`.
- Run REA calls sequentially in one session. Don't fan REA work out to parallel agents, since they share one MCP server and one target.
- For large results, request `detail: "summary"` where supported, then page the retained Evidence with `inspect_analysis_view` instead of re-running the analysis.
- Before finishing: export with `export_evidence_bundle` to `rea/evidence/`, then `close_binary` with `snapshot_path` `rea/snapshots/age3y-b1a1dab7.json` (absolute path). Pass the same `snapshot_path` to `open_binary` later to replay cached queries.
- Recording results in the `docs/` tables:
  - Status is `unverified` → `confirmed` / `mismatch`. Fill in the Evidence ID and containing function.
  - Keep observed facts, inferences and unknowns distinct. Pseudocode is analysis output, not source.

## Pitfalls

- `age3.exe` (vanilla) and `age3x.exe` (The WarChiefs) sit next to `age3y.exe`. TAD data uses the `y` suffix (`protoy.xml`, `techtreey.xml`, `stringtabley.xml`, `DataPY.bar`; compiled XML is `.xml.xmb`).
- Mod folders inside the install ship their own `age3y.exe`. Check the SHA-256 before trusting any address; known builds are listed in `docs/binaries.md`.
- WoL's `uhc.dll` implements options that are not in upstream (e.g. `noAILimitV2`); only its binary is available. Its exe also patches `AI3`→`AI4`, `RM3`→`RM4`, `eso.com`→`age3.us`, and sets LAA.
- Upstream has known defects; the list is in `docs/uhc-address-map.md`. Don't reproduce them, notably the `customSyscalls` table overflow.
- Never modify anything in the Steam install. The sibling `AoE3-Mod-Launcher` project uses a folder with a stock `age3y.exe` as the clean clone source for mods. Test on copies only.
