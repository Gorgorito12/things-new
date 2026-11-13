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

- `C:\AoE3-UHC-WoLReal`: the real WoL with **our** DLL (`--bed C:\AoE3-UHC-WoLReal`), and `C:\AoE3-UHC-WoLReal2`, `3`, `4` and `5`, copies to run beside it, one per agent. `5` opens at the same corner of the screen as `C:\AoE3-UHC-WoLReal` (top left), so not both at once. `C:\WoL-Test` is the control with WoL's DLL.
- `C:\AoE3-UHC-Test`, and private copies per feature (`-Poison`, `-WoL`, `-Spread`).

`python -I tools/testbed.py` plays a test with no clicks: `deploy`, `map`, `launch`, `scenario`, `skirmish`, `wait`, `log`, `units`, `shot`, `close`, `record`. `skirmish` uses posted clicks, so it needs no cursor or focus ([`docs/wol-migration.md`, "Skirmish route"](docs/wol-migration.md#skirmish-route-for-videos-2026-11-04)). Put a `timeout` on every `wait`: when a game ends the clock stops and `wait` never returns.

Rules:
- **Read `UHC.log` next to the exe** (`engine-ext\engine-ext.log` in a bed with an `engine-ext` folder, where `testbed.py` deploys `dinput8.dll` and leaves `UHC.dll` alone): `applied` / `FAILED`, and `hook reached: …`. Put `TRACE_ONCE` from `hooks/common.inc` at the top of every new hook.
- **`applied` is not `reached`:** hook the callee or the head rather than a call site another DLL may detour; beside WoL's DLL, `tech subtype lookup` at the old call 0x6206D7 was applied and never ran.
- **Every test video shows the feature on screen:** the units it acts on selected (`record --select`), a still camera (`--frame`), `--perf`, `normalZoom` set by console before the game loads, `--crop` at native pixels, `--master` into `rea/media-masters/`, and the GIF from `tools/make_gifs.py` (800 px, 8 fps, 12 s, 4 MB; cuts in `tools/gifs.txt`). Vary the civ, public civs only, and film a control with the key off. A/B every hot-path key with `perfprobe.py`.
- **An aura is filmed with its ring,** the one of `tools/rings` (drawn by aoe3-blender-tools' `make_rings.py --folder uhc_rings`) copied to `art/effects/uhc_rings` in the bed and removed after, in a scene with a Town Center, and the ring marks only what gets the effect: if a frame cannot show that, change the scene. Say in the control's caption when the ring is there with the key off.
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
  - `AddTechSubtype`, `AddTechActionSubtype` and `AddTechTypeSubtype` (`techsubtypes.*`, all three on the same sites: the name lookup's head 0x61FF5D, the call 0x6206B2 that reads the attribute's subtype, and the apply and unapply switches 0x8F978D and 0x8FB051); `AddTechPlayerSubtype` adds a player Data subtype at the player Data switch's `ja` 0x8D843E (`shipmentCounts`' `FreeHomeCityUnitByShipmentCount`);
  - `AddProtoTagHandler` (`prototags.*`, 0x51DB0F);
  - `AddCivTagHandler` (`civtags.*`, the civs.xml unknown-tag path 0x52BB07; `civFirstTC` (or its alias `firstTC`) and `sharedBuildLimit` read their civ tags there);
  - `AddTransformObserver` (`transformcalls.*`, the seven calls of 0x9C754C); a key's own transform calls `TransformUnit`;
  - `AddUnitPanelRow` (`unitpanel.*`, 0x699456);
  - `AddDeathObserver` (`deathobservers.*`, the kill queue drain's call 0x493D8F of the kill handler; `detonationDeath` and `annexFacing` observe every death there; `AddDestroyObserver`, its second list, is the trigger `Destroy`'s call 0x9828E7 of the unit removal, which skips the kill queue: `annexFacing` only);
  - `AddSyscall` (`syscalls.*`, the group sites);
  - `AddResearchPayer` (`researchpay.*`: the research payment calls 0x9E67E1 and 0x9D54CF and the refund copies 0x9E68A0 and 0x9D5548; `nextResearchFree`, then `researchGrants`, claim a research with a share of its cost);
  - the attack applier's head 0x49BE95, hooked by `spreadAnyAccuracy` (`spread_hooks.asm`): every projectile hit and landing goes through it, so a key that needs that site extends that hook;
  - `d3d9hooks.*`: the IAT slot 0xB84164 of `Direct3DCreate9` and the CreateDevice / Reset / Present vtable entries. `ReplaceDirect3DCreate9` (only `rendererOption`, before any observer) swaps the D3D9 the game gets; `AddD3D9Observer` (`perfStats`, `rendererOption`) watches the device. Never write the slot or those vtable entries elsewhere;
  - `AuraClaim` (`aurastacking.h`): a take that replaces the aura update asks it, as the filter 0x9D0633 does not see it;
  - `AddMenuOption` (`menuoptions.*`, `hooks/menuoptions_hooks.asm`): the options menu's virtual options, the name lookup's not-found return 0x9322A1 and the out-of-range returns 0x6B794B, 0x6B7676 and 0x518B26; `rendererOption` owns one, `menuOptions` one per key it names (a new on/off key: one line in `kMenuSwitches`). The choices go to `uhc-options.cfg`;
  - `AddRofFilter` (`rofreads.*`, `hooks/rofreads_hooks.asm`): the five reads of an attack's tactics ROF, 0x48A821, 0x48A99A and 0x48EA0C (after an attack that did not fire), 0x48F8B5 (after a shot) and 0x4A1189 (a cycle begins); `containedUnitsROF` and `numberOfShots` filter them, each with its gate (`SetRofGate`);
  - `AddFloatingBarQueued` and `AddFloatingBarKind` (`floatingbars.*`, `hooks/floatingbars_hooks.asm`): the HP bar queue's exit 0x45FB6C (after a unit's bar, with the Alt state in BL), the renderer's count 0x45C4B9 and its per-record end 0x45CB72; an added bar is a record with a negative player ID whose high three bytes are its kind (`overhealHitpointBars` segment 804F56xxh, `inventoryBars` 80494Exxh);
  - `floatingtext.*`, `modifiers.h` (the read-only walk over a unit's modifiers), `unitmodels.*` (a model hung on a unit), `unittypes.*` (extra abstract types).
- **Order in `kFeatures` matters:** `customAbstractTypes` first, `customSyscalls` last; `noTrainNearEnemyTC` after `liveBuildingWorkRate`; `buildingWorkRateAuras` last of the WoL keys (the two share `g_uhcBwrTrainGetter`); `civFirstTC` after `startingTC` (they share the hook at 0x506B3B; `firstTC` is read by both) and after `hcShipmentPointFallback` (`firstTC` adds FirstTC to its list); `resourceGatherAuras` after `showGatherRate`; `resourceDebt` after both (it writes inside what they verify); `overhealSources` and `overhealDecay` after `overhealHitpointBars`; `decimalPopulation` after `basePop`/`extraPop`; `spreadAnyAccuracy` after `damageOverTime`; `cantBeSlowed` after `damageOverTime` and `snareOnlyHitUnit`, which verify its site; `snareValues` after `cantBeSlowed` (its hook continues at 0x4DD207); `detonationDeath` after `overhealDecay` (it extends the add-HP hook that `overhealSources` verifies raw); `annexFacing` after `detonationDeath` (their death observers run in that order); `linkedResource` after `resourceDebt` (it writes the heads that `unitResourceAuras` and `transformInventory` verify); `orPrereqsQty` after `techPrereqRecheck` (it writes the evaluator head that key verifies); `researchGrants` after `nextResearchFree` (their claims on the shared research payment are asked in that order). `numberOfShots` after `containedUnitsROF` (its ROF filter runs on that key's result); `inventoryBars` after `overhealHitpointBars` (their observers of the shared bar queue run in that order). `menuOptions` is not in `kFeatures`: `ApplyFeatures` runs it before the first key, since it edits the cfg the keys see. `rendererOption` before `perfStats` (it replaces the `Direct3DCreate9` that perfStats then observes, `d3d9hooks.*`). `dataLint` after the keys that verify what it writes, and a new tag a key reads goes in its `kKnownTags`. Hook the callee where `maintainWaitForPop` verifies the call 0x6AB264.
- `docs/`:
  - `modding-guide.md`: for WoL's modders, private; a new key gets a row in its theme's table in section 5 and its section there, which starts with one line in italics saying in plain words what it does (`guide_dates.py` refuses a section without it);
  - `bug-fixes.md`: the same, private, for the keys that fix a bug of the game or of WoL's data and the performance keys; the guide's "Latest changes" lists both;
  - `porting-to-another-dll.md` and `porting-code/*.md` (generated): adding the features to WoL's DLL;
  - `how-it-works.md`: the internals of each feature, exported;
  - `developer-guide.md`: build, test beds, adding a feature, RE workflow;
  - `uhc-address-map.md`, `engine-symbols.md`, `binaries.md`: sites, names and hashes, with a status per row;
  - `wol-migration.md`, `wol-requests.md`, `wol-uhc-map.md`: WoL's progress, requests and DLL; pick the next item in the first two;
  - `de-parity.md`, `de-architecture.md`: how DE does it. Read-only install, no DE code or data in the repo or the DLL.
- `examples/Startup/uhc.cfg`: every implemented key, commented; the release template is generated from it. The dev keys `perfStats`, `perfAutoExec`, `perfExecFile` and `perfFileLog` are not in it: they are documented only in `docs/performance.md`, "Benchmark harness".
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

## Art and models

**Rule:** any work on art (models `.gr2`, textures `.ddt`, anim files, `.dmg`, impact effects, icons, new buildings or units) goes through the sibling repo `C:\Users\Jeison\Documents\GitHub\aoe3-blender-tools` (read its CLAUDE.md): use its Granny, DDT and anim code and its tools, and add a missing tool there rather than here. When a bug lives in a mod's art, fix the file with such a tool as well as, or instead of, a DLL key. That repo is public: neutral text, no mod or team names, no mod files or survey reports in it.

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
