# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

things-new (GitHub: `Gorgorito12/things-new`, formerly `Unharcoded-AOE3--NEW`; the local folder keeps its old name, because Claude's memory, the worktrees and `.claude/workflows/` depend on that path).

Reverse engineer Age of Empires III: The Asian Dynasties (`age3y.exe`) with REA, and build a **new `UHC.dll`** that drops into the existing loader. It succeeds the community patch ([danielpereira/AoE3UnHardcoded](https://github.com/danielpereira/AoE3UnHardcoded)). Before adding features, verify every site the original patches against the stock exe; that work is tracked in `docs/uhc-address-map.md`.

All binary analysis goes through the REA MCP server (`mcp__rea__*`, deferred tools: load them with ToolSearch). Load the `reverse-engineer-anything` skill before the first REA call.

**Rule:** when something cannot be solved or found with the code or by trying it in the game, go to REA at once, before more blind attempts and before calling it blocked.

## Commands

CMake and MSVC come from VS 2026 (`C:\Program Files\Microsoft Visual Studio\18\Insiders`) and are not on PATH. Use a VS x86 developer prompt, or call `Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe` by full path.

```
cmake -S . -B build -G "Visual Studio 18 2026" -A Win32   # must be Win32; x64 fails on purpose
cmake --build build --config Release                      # -> build\Release\UHC.dll and dinput8.dll
dumpbin -exports build\Release\UHC.dll                    # must list _UHCMain@0 (in Git Bash, "/exports" is mangled)
python -I tools/gen_sites.py "<Steam>\Age Of Empires 3\bin\age3y.exe"   # regenerates src/generated/sites.h
```

Add a site to the `SITES` list in `tools/gen_sites.py` and regenerate before a feature uses it. The script refuses any exe that is not the stock build.

Before the commit of every new key, changed `src/` or new test video:

```
python -I tools/guide_dates.py      # the day, date and time of each feature in the modding guide (a new video counts as new)
python -I tools/porting_code.py     # docs/porting-code/*.md from src/; a new key goes in its PAGES
python -I tools/export_public.py --check
```

## Testing

There are no unit tests. Every copy of the game, with its data and how to drive it, is in [`docs/developer-guide.md`, section 2](docs/developer-guide.md#2-a-safe-test-bed). The main ones:

- `C:\AoE3-UHC-WoLReal`: the real WoL with **our** DLL (`--bed C:\AoE3-UHC-WoLReal`), and `C:\AoE3-UHC-WoLReal2`, `3` and `4`, copies to run beside it, one per agent. `C:\WoL-Test` is the control with WoL's DLL.
- `C:\AoE3-UHC-Test`, and private copies per feature (`-Poison`, `-WoL`, `-Spread`).

`python -I tools/testbed.py` plays a test with no clicks: `deploy`, `map`, `launch`, `scenario`, `skirmish`, `wait`, `log`, `units`, `shot`, `close`, `record`. `skirmish` uses posted clicks, so it needs no cursor or focus ([`docs/wol-migration.md`, "Skirmish route"](docs/wol-migration.md#skirmish-route-for-videos-2026-11-04)). Put a `timeout` on every `wait`: when a game ends the clock stops and `wait` never returns.

Rules:
- **Read `UHC.log` next to the exe** (`engine-ext\engine-ext.log` in a bed with an `engine-ext` folder, where `testbed.py` deploys `dinput8.dll` and leaves `UHC.dll` alone): `applied` / `FAILED`, and `hook reached: …`. Put `TRACE_ONCE` from `hooks/common.inc` at the top of every new hook.
- **`applied` is not `reached`:** hook the callee or the head rather than a call site another DLL may detour; beside WoL's DLL, `tech subtype lookup` at the old call 0x6206D7 was applied and never ran.
- **Every test video shows the feature on screen:** the units it acts on selected (`record --select`), a still camera (`--frame`), `--perf`, `normalZoom` set by console before the game loads, `--crop` at native pixels, `--master` into `rea/media-masters/`, and the GIF from `tools/make_gifs.py` (800 px, 8 fps, 12 s, 4 MB; cuts in `tools/gifs.txt`). Vary the civ, public civs only, and film a control with the key off. A/B every hot-path key with `perfprobe.py`.
- **An aura is filmed with its ring,** the one of `tools/rings` copied to `art/effects/uhc_rings` in the bed and removed after, in a scene with a Town Center, and the ring marks only what gets the effect: if a frame cannot show that, change the scene. Say in the control's caption when the ring is there with the key off.
- **Check the AI after data or combat changes.** `XS: Error 0003: could not compile file 'aiLoaderStandard.xs'` means the AI is dead; `python -I tools/re/trace_xs.py <log>` shows the hidden error.
- **Definition of done:** the checklist in [`docs/developer-guide.md`, section 4](docs/developer-guide.md#4-definition-of-done), before a feature is reported as done.
- **Two games at once:** only with `multipleInstances background` in both cfgs, and another session's game only if it agreed. Such a copy ignores real input: `click`, `exec` and `record` work; a test that needs `rkey`, `drag` or `wheel` runs alone without `background`. Stop yours when one asks. Stop a tracer with Ctrl+C, never by killing it.
- **Never modify the Steam install.** Test on copies only. `testbed.py safety check wol` checks Steam's WoL folder.

## Layout

- `src/`: the DLL. `dllmain.cpp` (host guard), `startup.*` (config load, the feature loop), `engineext*` (the `dinput8.dll` build), `config.*` (the cfg parser; keys are case-insensitive), `patch.*` (`VerifyAll` checks the stock bytes before any write), `features.h` (the registry and the handled keys), `features/*.cpp` (one apply function per key group), `hooks/*.asm` (MASM hooks), `generated/sites.h`.
- **Hooks never relocate instructions.** Each one re-executes or replaces the stock code itself and leaves through an explicit `jmp` to the verified continuation.
- **Shared hooks: add to them, never a second `jmp` at their site:**
  - `AddWorldTick` (`worldtick.*`, 0x481A57);
  - `AddActionTagHandler` (`actiontags.*`, 0x5FA11E);
  - `AddModifyType` (`modifytypes.*`, 0x5FE6D7);
  - `AddTechSubtype` and `AddTechActionSubtype` (`techsubtypes.*`, the call 0x6206D7, 0x8F978D, 0x8FB051);
  - `AddProtoTagHandler` (`prototags.*`, 0x51DB0F);
  - `AddCivTagHandler` (`civtags.*`, the civs.xml unknown-tag path 0x52BB07; `civFirstTC` (or its alias `firstTC`) and `sharedBuildLimit` read their civ tags there);
  - `AddTransformObserver` (`transformcalls.*`, the seven calls of 0x9C754C); a key's own transform calls `TransformUnit`;
  - `AddUnitPanelRow` (`unitpanel.*`, 0x699456);
  - `AddSyscall` (`syscalls.*`, the group sites);
  - `AuraClaim` (`aurastacking.h`): a take that replaces the aura update asks it, as the filter 0x9D0633 does not see it;
  - `floatingtext.*`, `modifiers.h` (the read-only walk over a unit's modifiers), `unitmodels.*` (a model hung on a unit), `unittypes.*` (extra abstract types).
- **Order in `kFeatures` matters:** `customAbstractTypes` first, `customSyscalls` last; `noTrainNearEnemyTC` after `liveBuildingWorkRate`; `buildingWorkRateAuras` last of the WoL keys (the two share `g_uhcBwrTrainGetter`); `civFirstTC` after `startingTC` (they share the hook at 0x506B3B; `firstTC` is read by both); `resourceGatherAuras` after `showGatherRate`; `resourceDebt` after both (it writes inside what they verify); `overhealSources` and `overhealDecay` after `overhealHitpointBars`; `decimalPopulation` after `basePop`/`extraPop`; `spreadAnyAccuracy` after `damageOverTime`; `cantBeSlowed` after `damageOverTime` and `snareOnlyHitUnit`, which verify its site; `detonationDeath` after `overhealDecay` (it extends the add-HP hook that `overhealSources` verifies raw); `linkedResource` after `resourceDebt` (it writes the heads that `unitResourceAuras` and `transformInventory` verify). `dataLint` after the keys that verify what it writes, and a new tag a key reads goes in its `kKnownTags`. Hook the callee where `maintainWaitForPop` verifies the call 0x6AB264.
- `docs/`:
  - `modding-guide.md`: for WoL's modders, private; a new key gets a row in its theme's table in section 5 and its section there;
  - `porting-to-another-dll.md` and `porting-code/*.md` (generated): adding the features to WoL's DLL;
  - `how-it-works.md`: the internals of each feature, exported;
  - `developer-guide.md`: build, test beds, adding a feature, RE workflow;
  - `uhc-address-map.md`, `engine-symbols.md`, `binaries.md`: sites, names and hashes, with a status per row;
  - `wol-migration.md`, `wol-requests.md`, `wol-uhc-map.md`: WoL's progress, requests and DLL; pick the next item in the first two;
  - `de-parity.md`, `de-architecture.md`: how DE does it. Read-only install, no DE code or data in the repo or the DLL.
- `examples/Startup/uhc.cfg`: every implemented key, commented; the release template is generated from it.
- `README.md`: short. Key status lives in the modding guide.
- `tools/`: usage in `tools/README.md`.
- `reference/AoE3UnHardcoded/` (gitignored): the original. **It has no license:** read it for addresses and behavior, never copy its code. Zydis (MIT) is the only clearly reusable dependency.
- `rea/` (gitignored): snapshots and evidence, named `<target>-<sha8>`.
- **Version:** only in `project(UHC VERSION x.y.z)` in `CMakeLists.txt`. `python -I tools/package_release.py` builds `dist/UHC-x.y.z.zip`; the user uploads it (`docs/developer-guide.md`, section 7). A new key also goes in the key list of `README.txt` inside that script.

## Two repos

This repo is **private** and holds everything. The public repo `Gorgorito12/tad-engine-extensions` gets an export of an allowlist of files, never this history, and changes flow one way.

- The UHC team asked for discretion (fear of a cease and desist), so the public text names no WoL, DE, upstream / AoE3UnHardcoded / UHC 1.10 or Knights and Barbarians, and links no private doc.
- `docs/modding-guide.md` is **not exported**: the public repo keeps the copy it has (`KEEP_IN_CLONE`).
- `python -I tools/export_public.py --check` must pass; `--out <public clone>` writes the export, then commit and push the clone by hand. Never push anything public the user has not asked for, and never make this repo public.
- In exported `.md` files, hide text with `<!-- private -->` (end of a line) or a line `<!-- private:begin -->` ... `<!-- private:end -->`, and add public text with `<!-- public: TEXT -->` or `<!-- public:begin` ... `public:end -->`. Code comments and `examples/Startup/uhc.cfg` have no markers: keep them neutral.

## Target

| | |
|---|---|
| Path | `C:\Program Files (x86)\Steam\steamapps\common\Age Of Empires 3\bin\age3y.exe` |
| SHA-256 | `b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d` (11,598,648 B) |
| Format | PE32 i386, TimeDateStamp `0x49EF86AC`, SizeOfImage `0xB22000`, EP VA `0x5876AC` |
| Layout | ImageBase `0x400000`; no ASLR, no NX, not Large-Address-Aware |

Without ASLR, static VAs are the runtime addresses. For `.text`, `.rdata` and `.data`, file offset = VA − `0x400000`. `.rsrc` is shifted by another `0x14000`.

## Loader contract

A loader exe is the stock exe with the Authenticode certificate stripped (hence 11,591,680 B) plus a byte patch. **The import table is unchanged.**

- The entry point is redirected to a stub at VA `0xB836BE`. The stub calls `LoadLibraryA("UHC.dll")`, then `GetProcAddress("_UHCMain@0")`, calls that function, then jumps to the original EP. If either step fails, it shows a MessageBox and exits.
- `UHCMain` therefore runs **before the game's own startup code**. It must be `extern "C" __declspec(dllexport) void __stdcall`.
- The config path is a wide string of at most 20 chars at VA `0xC65083`: `Startup\uhc.cfg`, or `Startup\wol.cfg` in WoL's exe.
- Fixed addresses are only valid in this build. `src/dllmain.cpp` checks ImageBase, TimeDateStamp, SizeOfImage and the `"UHC.dll"` string before touching any of them; keep that guard.
- **Beside another `UHC.dll`:** the target `EngineExt` builds the same sources as `dinput8.dll`, a proxy of the system DLL the exe imports. Its DllMain only moves the boot stub's last `jmp` (0xB836EC), so `EngineExtMain` runs after the loader's `UHCMain` and before the game's entry point. It reads and writes only `engine-ext\` (`engine-ext.cfg`, `engine-ext.log`, its data files), never 0xC65083, `Startup` or `data\uhc`, and has its own exe guard. A site the other DLL patched fails `VerifyAll`, so that key logs FAILED and writes nothing. `hostfiles.h` holds the paths that differ; `startup.cpp` is what both builds run. Not `version.dll`: it loads from System32 here. Key table: `docs/wol-uhc-map.md`.

Full byte layout: `docs/binaries.md`.

## REA

Setup (2026-10-27): Ghidra 12.1.4 at `C:\Tools\ghidra_12.1.4_PUBLIC`, JDK 21 at `C:\Tools\jdk-21.0.12.1+1`. Neither is on PATH. REA 6.7.0 accepts only Ghidra 12.1.x. The env lives in `~/.claude.json` under `mcpServers.rea`; if `binary_session` shows Ghidra unavailable, check that block first.

- Open the stock exe with `open_binary` and `provider_id: "ghidra"`. The first analysis takes 15–30 minutes: never cancel it. The Windows mode is read-only, and the project is deleted on `close_binary`, so record names and findings in `docs/`.
- Run REA calls sequentially in one session: they share one server and one target.
- For large results, use `detail: "summary"`, then page the Evidence with `inspect_analysis_view`.
- Before finishing: `export_evidence_bundle` to `rea/evidence/`, then `close_binary` with `snapshot_path` `rea/snapshots/age3y-b1a1dab7.json` (absolute). Pass the same path to `open_binary` later.
- `docs/` tables: status `unverified` → `confirmed` / `mismatch`, with the Evidence ID and containing function. Keep observed facts, inferences and unknowns distinct. Pseudocode is analysis output, not source.

## Pitfalls

- `age3.exe` and `age3x.exe` sit next to `age3y.exe`. TAD data uses the `y` suffix (`protoy.xml`, `techtreey.xml`).
- Mod folders ship their own `age3y.exe`: check the SHA-256 before trusting an address (`docs/binaries.md`).
- WoL's `uhc.dll` has options that are not in the original; only its binary is available. Its exe patches `AI3`→`AI4`, `RM3`→`RM4`, `eso.com`→`age3.us`, and sets LAA.
- The original has known defects (`docs/uhc-address-map.md`). Don't reproduce them, notably the `customSyscalls` table overflow.
- Don't give a `.asm` file the same base name as a `.cpp`: `ml.exe` fails with A1000.
- A tactics file with LF line endings and a line break after a tactic name defines `cTacticNormal` twice, and the AI stops compiling.
