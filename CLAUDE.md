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

```
python -I tools/gen_sites.py "<Steam>\Age Of Empires 3\bin\age3y.exe"   # regenerates src/generated/sites.h
```

Add a site to the `SITES` list in `tools/gen_sites.py` and regenerate before a feature uses it. The script refuses any exe that is not the stock build.

### Test bed

`C:\AoE3-UHC-Test` is a robocopy of the Steam `bin\` folder, with two changes:
- `age3y.exe` is replaced by the Knights and Barbarians exe (stock + UHC loader, `d21d0173…`);
- `UHC.dll` is our build, next to `Startup\uhc.cfg`.

To test:
1. Copy `build\Release\UHC.dll` there.
2. Launch `age3y.exe` with that folder as the working directory; `ignoreRegistryPath` makes the game use it.
3. Read `UHC.log` next to the exe. It shows:
   - each feature as `applied` / `FAILED`;
   - the keys not implemented yet;
   - `hook reached: …` the first time the game runs each hook. Put `TRACE_ONCE` from `hooks/common.inc` at the top of every new hook.

**Shared profile.** The copy shares the user profile with the normal game: `Documents\My Games\Age of Empires 3\Users3\NewProfile3.xml`. This file is UTF-16.
- Its first run reset `optiongrfxres` to `800 x 600`. It was restored to `1920 x 1080` on 2026-10-28; the backup is `NewProfile3.xml.bak-uhc-20261028`.
- Check that setting if the resolution changes again.

**Test data.** `data\` holds both `protoy.xml` and the compiled `protoy.xml.XMB`, and which one the game prefers is not established. In the copy both carry `AbstractHealNonIdle` on `Surgeon`, `ypMonkIndian` and `ypMonkIndian2`:
- the XMB was edited with `python -I tools/xmbedit.py add-unittype <in.XMB> <out.XMB> <unit> AbstractHealNonIdle …` (it skips units that already have the type and warns about unknown unit names);
- the XML was edited by hand;
- the originals are `protoy.xml.uhc-orig` and `protoy.xml.XMB.uhc-orig`.

There are no unit tests yet.

## Layout

- `src/`: the DLL.
  - `dllmain.cpp`: host guard, config load, then the feature loop.
  - `config.*`: the `uhc.cfg` parser. Keys are case-insensitive.
  - `patch.*`: patch helpers. `VerifyAll` checks the stock bytes before any write.
  - `features.h`: the registry and the handled keys.
  - `features/*.cpp`: one apply function per key group.
  - `hooks/*.asm`: MASM hooks.
  - `generated/sites.h`: the expected bytes, written by `tools/gen_sites.py`.
  - `unittypes.*`: extra abstract unit types that features request. Stock only knows the abstract types compiled into the exe and drops any other `<UnitType>`.

  Hooks never relocate instructions. Each one re-executes or replaces the stock code itself and leaves through an explicit `jmp` to the verified continuation. Implemented so far:
  - `removeConversionRestriction`, `ignoreRegistryPath`, `deckCardCount`, `basePop`/`extraPop` (M2);
  - `noAILimit`, `customRevolutionBanners`, `removeFameRestriction` (M3);
  - beyond upstream: `hcShipmentPointFallback`, `healNonIdle` (`docs/uhc-address-map.md`, "Beyond upstream").

  `customCheats` waits for the plugin loader (M6): upstream registers cheats only from `.upl` plugins.
- `README.md`, `LICENSE` (MIT): the public entry point. The README's feature table keeps one honest in-game status per key; update it with every feature.
- Documentation for modders (keep these in step with the code):
  - `docs/modding-guide.md`: every cfg key, its data/art requirements, log lines and status;
  - `docs/how-it-works.md`: the internals of each feature;
  - `docs/developer-guide.md`: build, safe test bed, adding a feature, RE workflow.
- `examples/Startup/uhc.cfg`: every implemented key, commented. Add new keys here too.
- `tools/`: `gen_sites.py`, `bar.py` (BAR archives), `xmbedit.py` (XMB check / to-xml / add-unittype), and `re/` (a ctypes debugger: `trace_writes.py`, `trace_exec.py`, `inspect_unittypes.py`). Usage: `tools/README.md`. Stop a tracer with Ctrl+C, never by killing it: a breakpoint left behind crashes the game.
- `docs/binaries.md`: hashes of every `age3y.exe` / `UHC.dll` build in the install, the loader stub layout, and what each mod's exe patches.
- `docs/uhc-address-map.md`: every upstream patch site, with a verification status per row.
- `docs/engine-symbols.md`: functions, globals, IAT slots and object offsets named by upstream, with a status per row.
- `docs/wol-uhc-map.md`: WoL's `uhc.dll`. It covers:
  - identity, libraries and patch mechanisms (upstream fake-instruction caves plus `remod::trackable_memory_patch`);
  - a cross-check of the upstream caves;
  - per-cfg-key candidate sites;
  - the 54 `*Feature` classes.
- `reference/AoE3UnHardcoded/` (gitignored): shallow clone of upstream. **It has no license.** Read it for addresses and behavior, but never copy its code into `src/`. Zydis (MIT) is the only clearly reusable dependency.
- `rea/` (gitignored): REA snapshots (`rea/snapshots/`) and exported evidence bundles (`rea/evidence/`).
  - Both are named `<target>-<sha8>`, e.g. `age3y-b1a1dab7`, `wol-uhc-c070d138`.
  - Each evidence folder also holds the capstone/pefile scripts and their outputs that back the `cs` evidence in `docs/`.
  - Those scripts need a venv with `capstone` 5.0.6 and `pefile`, which is not part of the repo.

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
- **MASM object names.** Don't give a `.asm` file the same base name as a `.cpp` (for example `limits.asm` and `limits.cpp`). CMake then puts the object in a subfolder that `ml.exe` doesn't create, and the build fails with A1000.
- Never modify anything in the Steam install. The sibling `AoE3-Mod-Launcher` project uses a folder with a stock `age3y.exe` as the clean clone source for mods. Test on copies only.
