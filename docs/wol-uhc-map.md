# Wars of Liberty `uhc.dll`

## What this is

A map of WoL's closed-source DLL: what it adds beyond upstream AoE3UnHardcoded, and which `age3y.exe` addresses each cfg key touches.

**First pass, 2026-10-28.** Every patch site the DLL encodes upstream-style is listed exactly. For the WoL-only keys, the addresses are **candidates**:
- they are age3y constants found in each key's handler function;
- each was classified against the stock exe;
- the per-site patch type and behavior are not traced yet.

**Reference only.** Record addresses and behavior here, but never copy the DLL's code or pseudocode into `src/`.

## Identity

| | |
|---|---|
| Path | `Wars of Liberty\uhc.dll` |
| SHA-256 | `c070d138c2b4ead70ef07f44dae57a6667ffc53b59a178ddade39db48e01efb2` (1,187,840 B) |
| Build | PE32 DLL, x86 |
| Toolchain | MSVC linker 14.16 (VS 2017 15.9) |
| TimeDateStamp | `0x67E04ABB` (2025-03-23 17:54 UTC) |
| PDB | none |
| Layout | ImageBase `0x10000000`, relocatable (DYNAMIC_BASE, NX_COMPAT); 6,834 Ghidra functions |
| Exports | `_UHCMain@0`, `CheckRevBanner`, `LoadPersonalities`, `RegisterSyscallGroup`, `TableIDExists`, `NvOptimusEnablement`, `AmdPowerXpressRequestHighPerformance` |
| Imports | KERNEL32 (80, including `VirtualProtect`, `VirtualProtectEx`, `WriteProcessMemory`, `ReadProcessMemory`, `VirtualAllocEx`, `LoadLibraryW`) |
| | USER32 (`MessageBoxA/W`, `wsprintfW`, `keybd_event`) |
| | WS2_32 (`WSAStartup`/`WSACleanup` only) |
| | MSVCP140 / VCRUNTIME140 / UCRT |

About the exports:
- The first five are the upstream DLL's names.
- The NVIDIA/AMD exports ask hybrid-GPU laptops for the discrete GPU.

Libraries, identified from RTTI and strings:
- spdlog + fmt v5 (logging);
- moodycamel ConcurrentQueue;
- `std::filesystem`;
- a patch / global-pointer library called **`remod`**;
- a feature framework under the **`UHCDLL`** namespace: `BaseFeature`, `IUHCApi`, `IUHCConfig`, `IUHCCustomManager`, `IUHCDataEffectCollection`, `IUHCWorkQueue`, `IUHCAsyncServiceManager`, `BasicMemoryPatch<char>` / `<int>`.

**Verdict:**
- WoL's DLL is a fork of upstream. It keeps every upstream code cave in upstream's own encoding (below).
- On top of that it adds a C++ feature framework with 54 `*Feature` classes.

Evidence:
- `W1` = `ev_990315c54f733057137b19ce2cf54d87ff2a1b38c73064495af2b86159ee53d3`: `binary_overview`.
- `W2` = `ev_41b792341050b516e9af0187ab52de5b8f4b0436f797951850cce063e32a9705`: `list_procedures`.
- `W3` = `ev_94d9ec3f8ed976899a391942988d3a0379fa7263ab79ff0be00aff7ed1e2d5be`: `batch_decompile` of `_UHCMain@0`, the patch helpers and every key handler.
- `cs` = pefile/capstone scans of the DLL and the stock exe.
- Scripts, outputs and the saved JSON records are in `rea/evidence/wol-uhc-c070d138/`. The snapshot is `rea/snapshots/wol-uhc-c070d138.json`.

## Patch mechanisms

1. **Upstream caves.** The DLL code holds upstream's fake instructions: `F1 <op> <VA>`, with ops CALL32/JMP32/JE32/JNE32/CASE/CC_BEGIN/CC_END. There are 242 of them in 0x1002B4C0–0x1002CBD8 (cs). Data patches still go through upstream-style helpers:

   | Helper | Calls | Example |
   |---|---|---|
   | 0x100139F0 | `PatchAddress` | FameTrickle 0x51B026 ← 0xBD62F8 |
   | 0x10013F20 | `PatchData` | Conversion 0x9D5B6C |
   | 0x10013A60 / 0x10013F70 | the code-cave / fake-instruction walkers | |

2. **`remod::trackable_memory_patch`** objects (W3):
   - **Layout:** target at `+8`, new bytes `std::vector` at `+0Ch`, saved original bytes at `+18h`.
   - **apply** (0x10030F00): saves the original, then writes the new bytes.
   - **restore** (0x10030F30): writes the original back.
   - **destructor** (0x10030D80): restores if the patch is applied.
   - **Byte I/O:** 0x10031C40 reads and 0x10031CC0 writes, both with `VirtualProtect` + `memcpy`.

   The target addresses come from object fields rather than immediates at the call, so the sites below were taken from the handlers instead.
3. **Call-site redirection and imm patches.** Most WoL-only features name `call` instructions or immediate operands in the exe (see the per-key table). This suggests they rewrite call targets and constants, instead of hooking inside the callee. That is an inference; the patch byte contents are not read yet.

## Upstream caves: cross-check against `uhc-address-map.md`

Every Site/End pair in [uhc-address-map.md](uhc-address-map.md) appears in WoL's fake-instruction stream with the same addresses, except:

| Site | Upstream | WoL | Notes |
|---|---|---|---|
| 0x7A0709 (TeamLimit SP) | detour (End 0x7A0709) | replace, End **0x7A070E** | WoL replaces the stolen `push 8D31h` instead of relocating it. |
| **0x699D31** | — | detour; CALL32 0x444EFB, JMP32 0x699DE6 | WoL-only. Same shape as AttackTypeIcons #3 (0x69B909, which calls 0x444EFB and jumps to 0x4D7F44); probably a second type-icon tooltip site. Not verified against the stock exe yet. |

The upstream keys are still parsed in one function, 0x10010540. It holds all 20 upstream key strings, reads the cfg path at VA 0xC65083, and references 0xBEAF98, whose role is unknown.

## Per cfg key

"Upstream?" means the key exists in upstream v1.10.

"Candidates" are age3y constants in the handler (W3), classified in the stock exe (cs):
- `fn` = a function entry;
- `call→X` = a call instruction to X;
- `imm@insn` = an immediate operand inside that instruction;
- `insn` = an instruction inside a function.

Status: `candidates` (sites are known, but how they are patched is not), `unknown` (the handler has no direct constants), or `upstream` (see the address map).

WoL's own `Startup\uhc.cfg` spells one key `NativeCivs`, while the DLL holds only the string `nativeCivs`. Whether the parser compares keys case-insensitively is not checked; if it does not, that line is ignored.

| cfg key (WoL `uhc.cfg`) | Upstream? | Handler | Feature class (inferred) | Candidates in `age3y.exe` | Status |
|---|---|---|---|---|---|
| upstream keys (`enableAllTeams`, `removeFameRestriction`, `asianCivs`, `explorerUnits`, …) | yes | 0x10010540 | — | same sites as upstream | upstream |
| `noAILimitV2` | no | 0x10057030 | NoAILimitV2Feature | 0x603C34 `test al,al` before `je 658900h`, the TAD/vanilla personality-table branch inside the AILimit range. V2 hooks at 0x603C34 instead of upstream's 0x603B0B. | candidates |
| `basePop`, `extraPop` | yes | 0x10034BF0 | ExtendLimitsByXmlFeature? | 0x4581F3, the upstream PopLimit site | candidates |
| `deckCardCount` | yes | 0x10034F20 | ExtendLimitsByXmlFeature? | the `19h` (25) in `mov eax,19h` @0x7EF005 (+1), `cmp eax,19h` @0x7EF026 (+2) and `mov eax,19h` @0x7EF02B (+1). These are imm patches instead of upstream's cave, and they add a third site, 0x7EF005. | candidates |
| `selectionLimit` | no | 0x10034F20 | ExtendLimitsByXmlFeature? | the `32h` (50) in `mov eax,32h` @ 0x4E0BEE, 0x4E0F5F, 0x4E0F7E, 0x4E10A5, 0x4FC457, 0x4FE663, 0x4FEB94, 0x503DCE (+1 each). WoL's cfg sets 75. | candidates |
| `enablerandomtecheffect`, `enabletechrenameeffect` | no | 0x10036680 | AdditionalTechEffectsFeature | none. Registers the tech effect types `RandomTech` and `SetTechName`. Our DLL implements `SetTechName` per player as `techRenameEffect` (alias `enableTechRenameEffect`; modding guide). | unknown |
| `loadingScreenCount` | no | — | MoreLoadingScreensFeature | none (no direct string reference) | unknown |
| `unstretchedui` | no | 0x10050E20 | UnstretchedUiFeature | fn 0x402FAA, fn 0x44812E | candidates |
| `optionhighpolycliff` | no | 0x100517F0 | HighPolyCliffFeature | fn 0x402CE9 and 25 `call→402CE9` sites, 0x7B6F78 … 0x82E9CD | candidates |
| `exportCiv`, `danceCiv`, `wonderCiv`, `wonderCivUnitType` | no | 0x10052EE0 | CustomizeCivExtrasFeature | `isAsianCiv` 0x454ED7 and 13 `call→454ED7` sites; `isNativeCiv` 0x453D37 and 3 `call→453D37` sites (0x6440F0, 0x64414C, 0x6441B8); `call→44CAC4` @0x7E6919, 0x7E8050; insn 0x818230 | candidates |
| `compatMode` | no | 0x10053A00 | CompatFeature | fn 0x54D605; `call→54D605` @0x54D6D1 | candidates |
| `relaxedWaterObstruction` (not set in WoL's cfg) | no | 0x10053D20 | RelaxedWaterObstructionFeature | fn 0x4CB69E; `call→4CB69E` @0x759B81 | candidates |
| `unrandomizeBroadsideAttack` (commented out in WoL's cfg) | no | 0x10053E40 | BroadsideBalanceFixFeature / BroadsideNoTurnFeature | insn 0x4CEEFC; rel32 of `jne` @0x50FFFC (+4); +2 inside `call [edx+68h]` @0x848E89 | candidates |
| `nowalkfarm` | no | 0x10054130 | NoWalkFarmFeature | `call→9DDADE` (farm gather) @0x6A9067 | candidates |
| `repairWallGlobal` | no | 0x10054310, 0x10054380 | RepairWallFeature | none | unknown |
| `flagoverrideeffect` | no | 0x10055390 | FlagOverrideFeature | fn 0x520F08, `call→520F08` @0x5EE664; fn 0x5BE665, `call→5BE665` @0x64561B, 0x760981; insns 0x451FAF, 0x4B9ED4, 0x78FBBA, 0x7902F3, 0x792080, 0x792719, 0x792F32, 0x81724A | candidates |
| `flagoverridetex`, `flagoverridebuttonset`, `flagpostgameoverridetex` | no | 0x100562F0 | FlagOverrideFeature | none (data keys read by the feature) | unknown |
| `alpha2coverage` | no | — | Alpha2CoverageFeature | none (no direct string reference) | unknown |
| `customBars` (not set in WoL's cfg) | no | 0x10057510 | AdditionalBarsFeature | fn 0x544FBA; `call→544FBA` @0x5AAA0B | candidates |
| `multiarmor`, `multiautogathertype` | no | 0x100590F0 | ProtoUnitExtensionFeature / ExtendedDataSubtypesFeature? | fn 0x67E011 | candidates |
| `trainSingleAbstractType` | no | 0x1005ABF0 | TrainSingleAbstractTypeFeature | `call→44CAC4` @0x9CE573, 0x9CE767. String `AbstractTrainLimitOne`. | candidates |
| `betterfreedynamicunit` | no | 0x1004A690 | FreeDynamicUnitFixFeature | insn 0x7FA6ED (`nop`), insn 0x8D8C6F | candidates |
| `map` (hotkey line), `uhcSyncTrack()` | no | — | SyncTrackerFeature | none. The syscall string is `uhcSyncTrack`. | unknown |

## WoL-only feature classes (RTTI, 54)

AdditionalBars, AdditionalLogging, AdditionalTechEffects, AiCreateDefendPlan2, Alpha2Coverage, AprilFools,
BetterCeaseFire, BroadsideBalanceFix, BroadsideNoTurn, CivSpecificTextTechRollover, Compat,
CustomizeCivExtras, Diplomacy, DisableEffectOnTechFix, DoubleShipmentsInspectFix, ESOCMPGameOverride,
ExtendLimitsByXml, ExtendedDataSubtypes, FallenHeroTacticsFix, FastPlaybackFactor, FlagOverride, FocusFix,
FreeDynamicUnitFix, GatherFix, HighPolyCliff, KbUnitGetNumberTargeters, KbUnitGetNumberWorkersIfSeeable,
KbUnitInventory, MPSaveAndRestore, ModifyActionFix, MoreLoadingScreens, NoAILimitV2,
NoDamageOnUnbuiltFoundations, NoKnockoutDanceBonusHealFix, NoWalkFarm, ObserverDisplayPath, ObserverUI,
PreventSavedataOptionsOverride, ProfileGame, ProtoUnitExtension, ROFFix, ReimplAIDebugInfoCommands,
RelaxedWaterObstruction, RepairWall, SafeSquadMode, SlowBuildFix, SmallUIFixes, SoundReload,
StunMovingTargetFix, SyncTracker, Temp, TrainSingleAbstractType, UnstretchedUi, WagonSingleUsageFix
(each with a `Feature` suffix).

Many of these have no cfg key and appear to be always-on fixes, for example GatherFix, ROFFix, SlowBuildFix and FocusFix (inference).

There are also lobby/UI overrides: ESOC `BMPESOGameList`, `BMPLANBrowserDialog`, `MPGameSetupPage`, `MPPlayerSlot`. Their strings include `ObserverModeCheckButton`, `LockedTeamsCheckButton`, `MapVariantDropdown`, `InviteShieldCheckButton`, `CRCFilterCheckButton` and `ESOCDiplomacyUI`.

## WoL-only syscalls and commands (strings; registration not traced)

| Area | Names |
|---|---|
| Diagnostics | `uhcToggleProfiling`, `uhcSyncTrack` |
| AI debug | `aiOpportunities`, `aiChatHistory`, `aiDebugBattles` |
| Unit path display | `uiShow/Hide/ToggleUnitPathRough`, `uiShow/Hide/ToggleUnitPathSimple`, `uiShow/Hide/ToggleUnitGatherPointPath` |
| Observer | `trClearObserverOwnedObjects`, `rmIsObserverMode` |
| Map variants and events | `rmIsSummerVariant`, `rmIsWinterVariant`, `rmIsSpecialEventVariant`, `rmIsUnexpectedEventsVariant`, `rmGetMapVariant`, `rmActivateRandomEvents` |
| Misc commands | `setSquadModeByIndex`, `reloadAllSounds`, `setFastPlaybackFactor`, `saveUnresponsiveGame` (`saveonoos`), `activate/deactivateAprilFoolsTextures` |
| kb queries | `kbUnitIsInventoryFull`, `kbUnitGetCurrentInventory`, `kbUnitGetInventoryCapacity`, `kbUnitGetNumberTargeters`, `kbUnitGetNumberWorkersIfSeeable` (registered at 0x1004F21E.. with group 2; rebuilt in our DLL as `kbUnitSyscalls`, 2026-11-03) |
| AI plans | `trCreateDefendPlan2` |

### Engine symbol table

The DLL resolves its imports from `Bang.dll` (the delay-load notify hook 0x1000F9D0 answers that
name; the lookup 0x1006CA00 hashes the mangled name with FNV-1a into a table) from **1,218 pairs of
mangled name and stock exe address** that its code builds at startup (`push name / ... / mov
[ebp-93BCh],addr / call`). `rea/evidence/wol-uhc-c070d138/wolsyms.py` extracts them to
`wolsyms.txt` (sorted by name order in the code). Spot checks against the stock exe matched:
`BWorld::getUnitByID` 0x44CC6D, `BWorld::getPlayer` 0x44CB21, `BProtoUnit::isAbstractType`
0x44CAC4, `BUnit::isSeeable` 0x48A9EF, `BUnit::getSquad` 0x4E2A03,
`BResourceInventory::isFull` 0x4DC520, `BUnit::getCarryCapacity` 0x494503. Treat the names as
hints: check each address with `cs` before relying on it, and record it in `engine-symbols.md`.

## Runtime patch list (memory diff, 2026-10-28)

**Method:**
1. Copy WoL to `C:\WoL-Test` (the Steam install is untouched).
2. Start its `age3y.exe` and wait 30 s, until the main menu.
3. Read `.text`/`.rdata` of the live process.
4. Diff them against that exe on disk.

Because the exe on disk already contains WoL's static patches, every difference is a patch applied by `uhc.dll` at runtime.

**Result:** 287 changed ranges.
- 261 are in `.text`: 60 jmp/call hooks (5+ bytes) and the rest are rel32 call-target rewrites and imm/byte patches. They include every upstream cave and the candidates listed above.
- 26 are in `.rdata`. Most of them are the IAT, which the loader resolves, so they are not patches. The real ones are:
  - function-pointer/vtable slots at 0xB92CB0, 0xB92CE0 and 0xB9E5AC;
  - `%.1fx` → `%.2fx` at 0xBA2068 (playback-speed display).
- **Card unlock not identified yet.** None of the patched functions touches the home city card array (`+204h`). Inspected with `batch_decompile` of the 148 sites not already explained (`batch_decompile_patch_sites.json`, `ev_908b7e94…`).
- **Next probe:** diff again while the deck builder is open, in case the patch is applied lazily.
- **Files:** `rea/evidence/wol-uhc-c070d138/memdiff.py`, `wol-memdiff.txt`.

## Running beside WoL's DLL (`dinput8.dll`, 2026-11-05)

JTMaston's request: keep WoL's `uhc.dll`, `Startup\wol.cfg` and `data\uhc` as they are, and add ours beside them. Bed: `C:\AoE3-UHC-WoLReal4`.

**Design as built.**
- The exe, `uhc.dll`, `wol.cfg` and `data\uhc` are untouched: their hashes equal `C:\WoL-Test`'s after every test.
- `dinput8.dll` next to the exe is the same code as `UHC.dll` (CMake target `EngineExt`, `src/engineext.cpp`, `src/engineext_forward.cpp`, `src/engineext.def`). All 6 exports go to the system's DLL by full path, resolved on the first call.
- Its `DllMain` checks ImageBase, TimeDateStamp, SizeOfImage, EP RVA 0x7836BE and the stub's bytes, and only moves the `jmp 0x5876AC` at 0xB836EC to `EngineExtEntry`. So the order is: loader, WoL's `UHCMain`, `EngineExtMain`, game entry point.
- Its files are in `engine-ext\`: `engine-ext.cfg`, `engine-ext.log`, `customabstracttypes.xml`, `customprotounitcommands.xml`. It never reads 0xC65083, `Startup` or `data\uhc`.
- WoL's hooks are never patched over: running second, a key whose site WoL changed fails `VerifyAll` and writes nothing.
- **Not `version.dll`, as first planned.** The exe imports it, but the game loaded `C:\WINDOWS\SYSTEM32\VERSION.dll` with ours next to the exe (`EnumProcessModulesEx`). It is not in `\KnownDlls32`, so the likely cause is an earlier import that pulls it from System32; that cause is an inference. `C:\AoE3-UHC-WoLReal4\DINPUT8.dll` is what loads (same list), and `DINPUT8` is not in `\KnownDlls32`.

**WoL's DLL writes no `UHC.log`,** in this bed or in the control `C:\WoL-Test`, so there is no log of its own to compare.

**Result with every key of ours on (`examples/Startup/uhc.cfg`, example values): 55 applied, 31 FAILED.** Checked with the live bytes of all 502 sites at the main menu, once with two runtime keys of ours (86 sites changed by WoL) and once with all keys: no site of an applied key was overwritten by WoL afterwards.

| Key group | Beside WoL's DLL | Why |
|---|---|---|
| `hcTargetTechs`, `transformSpan` | **works, shown by effect**, with a control | See below |
| `accuracyTechs` | **works, value shown** | Log with a `Crossbowman` tech: `action 44, relativity 3, amount 0.05: 1 -> 0.05`, one line per action |
| `nextResearchFree` | **works, effect path shown** | Log: `proto 304: effect applied, 1 left`. No research was paid for in the test |
| `workRateByAbstractType`, `resourceGatherAuras`, `resourceDebt`, `liveBuildingWorkRate`, `buildingWorkRateAuras`, `trainBatchSize`, `sharedBuildLimit`, `noTrainNearEnemyTC`, `damageOverTime`, `dodge*`, `teamKillBounty`, `resourceBounty`, `veterancyBonus`, `cantBeSlowed`, `showGatherRate`, `decimalPopulation`, `basePop`/`extraPop`, `deckCardCount`, `startingTC`, `civFirstTC`, `danceBonusCivs`, `transformInventory`, `transformUpdatesLOS`, `techPrereqRecheck`, `lifespanAfterConstruction`, `noCorpseDopples`, `snareOnlyHitUnit`, `overheal*`, `customHotkeyContexts`, `customAbstractTypes` | applied, **hook reached** in the AI skirmish or at load | Effect not checked one by one |
| `autoGatherScaleByContained`, `unitResourceAuras`, `costEscalationTechs`, `detonationDeath`, `cratePriority`, `doNotQueue`, `killBountyTechs`, `healNonIdle`, `smartHealTargets`, `spreadAnyAccuracy`, `maintainWaitForPop`, `broadsideMuzzleLimit`, `abilitySlots`, `wonderPanelSkipAuras`, `gaiaSocketsOnly`, `hcShipmentPointFallback` | applied | Needs data the test did not have. The shared hooks they use (proto tags, action tag, ModifyType names, tech subtypes) were reached |
| `perfStats`, `perfAutoExec`, `perfExecFile`, `bufferedFileReads`, `fastVertexFill`, `rendererOption`, `multipleInstances` | applied | Runtime only. `fastVertexFill` (2026-11-10, `C:\WoL-Test`): hook reached, `verify` 0 mismatches in 15.4 M vertices, +14 to +15 % FPS; see the tests below. `rendererOption` (2026-11-10, same copy): the Renderer entry shows and switches, DXVK loads and draws (ReShade, that copy's `d3d9.dll`, is then bypassed) |
| `containedUnitsROF`, `nativePreview`, `annexFacing`; spreadAnyAccuracy's hooks of 2026-11-08 (0x4A9455, 0x49BE95); the shared death observers (0x493D8F, written by `deathobservers.cpp` since 2026-11-08, and the `Destroy` call 0x9828E7) | **applied beside WoL's DLL, not played** (2026-11-09, see the table below) | Added after these runs. None of their sites is in WoL's 287 patched ranges (`wol-memdiff.txt`, checked 2026-11-08), so they should apply, but WoL may patch more in a game. spreadAnyAccuracy's hooks at 0x4997AE and 0x4C4DEC (2026-11-06) were already in the code of the 2026-11-06 run below |
| `decimalPopulation` | applied, **one line left out** | `DoubleShipmentsInspectFixFeature` wraps the format at 0x710651, a population cost. That line prints K times too large. The other seven format calls are ours |
| `removeConversionRestriction`, `ignoreRegistryPath`, `noAILimit`/`noAILimitV2`, `customRevolutionBanners`, `removeFameRestriction`, `asianCivs`, `twoScoutCivs`, `nativeCivs`, `bigButtonCivs`/`noBigButtonBlds`, `marketUnits`, `explorerUnits`, `enableFarmAnim`/`enableRectFarmAnim`, `farmingRadius`, `wonderCivUnitType`, `trainSingleAbstractType`, `multiarmor`, `betterfreedynamicunit`, `nowalkfarm`, `repairWallGlobal`, `compatMode`, `selectionLimit`, `enableAllTeams`, `techRenameEffect`, `customSyscalls`/`customCheats` | FAILED, as intended | WoL's own key, set in `wol.cfg`, holds the site. Use it in `wol.cfg` |
| `gatherFix`, `rofFix`, `stunMovingTargetFix`, `noDamageOnUnbuiltFoundations`, `fallenHeroTacticsFix` | FAILED, as intended | WoL patches the same sites at start with no key in `wol.cfg` |
| `kbUnitSyscalls` | FAILED | `AddSyscall` needs `SyscallAi` 0x7294F4 and the other group sites, all WoL's. WoL has these syscalls itself |
| `customProtoUnitCommands` | FAILED | `CmdTypeRegLast` 0x5269FB and `CmdRecordReserve` 0x52711D are WoL's. New command types go in WoL's `data\uhc` file |

**What had to change so the new keys run beside WoL's DLL.** Each one also ran through the plain `UHC.dll` flow on WoL's data (42 applied, 0 failed, same log lines).
- `hcTargetTechs`: WoL wraps the flag reader's only call, 0x620C23. The key now hooks the reader's head, 0x620C2F, which WoL's wrapper still calls for flags it does not know.
- Tech subtypes: WoL replaces 0x6206BF..0x6206CF, so the call 0x6206D7 is applied and never runs. The hook moved to the head of the lookup, 0x61FF5D, plus the read of the attribute at 0x6206B2 for the effect and its node. Without this, `accuracyTechs`, `costEscalationTechs`, `nextResearchFree` and `killBountyTechs` said `applied` and did nothing.
- `AbstractTypesEnd` now starts at 0x51BA2F: WoL writes the loop's bound at 0x51BA2B.
- `decimalPopulation` skips 0x710651 when it is not stock, and logs it.
- `buildingWorkRateAuras` no longer checks the ModifyType hook itself: with `resourceGatherAuras` or `unitResourceAuras` on, it saw that hook and failed. This bug did not depend on WoL.

**The tests** (with WoL's `uhc.dll`, `wol.cfg` and every key on):

| Test | Key on | Key off |
|---|---|---|
| `hcTargetTechs`: player 1 gets a tech with `HCTargetEnemy`, `Hussar` HP ×0.5 | player 1: 352, player 2: 176 | player 1: 176, player 2: 352 |
| `transformSpan`: 6 `Pikeman`, `transformspan='20'` to `Rodelero` | `Pikeman` again 20 s later | still `Rodelero` 46 s later |
| Skirmish: one European AI, `wolOtto`, 4 min | Runs. The AI's XS calls reach our hooks (`aiSetEconomyPop`, `kbGetPop`), it built a `Manor`, 24 units, score 78 | not run |
| Rings: `resourceGatherAuras`, `unitResourceAuras log`, `buildingWorkRateAuras log`, an Explorer with gold and work rings, a Sawmill with `ring_wood`, 8 villagers | 5 applied, 0 failed, both ring hooks reached (0x9D0584, 0x9D06DC). Each ring in its colour. The miners lose the ring when sent to a tree at 34 s. Town Center `x3.000`. Hashes of `uhc.dll`, `wol.cfg` and the tactics unchanged | not run |
| `linkedResource log`, Ethiopians, a `UhcMonastery` by a Mine, villagers on it (2026-11-06; `uhc.dll` `c070d138`, `engine-ext.cfg` with only this key, `multipleInstances background` and `perfStats`) | 3 applied, 0 failed, hooks 0x9BFE5A, 0x4C378A and 0x49A5E6 reached. Mine 1386.66, player 613.24 at 149 s | Mine 2000, the building's own stock falls, player 191.59 at 62 s |
| Every key of `examples/Startup/uhc.cfg` on (2026-11-06) | 62 applied, 28 failed, the same groups as above; `auraStacking`, `xsErrorLog`, `dataLint`, `unitTypeTechs`, `linkedResource`, `snareValues`, `pillageGold`, `displayedRange` applied | With WoL's own DLL gone: 91 applied, 0 failed, and an AI skirmish of 114 s with 16 units and no XS error |
| Release zip 0.3.0 (2026-11-09): its `beside-another-dll\` in `C:\WoL-Test` (`uhc.dll` `c070d138`), `engine-ext.cfg` with `steadyHitpointBars`, `veterancyBonus`, `nativePreview`, `annexFacing`, `containedUnitsROF` and `spreadAnyAccuracy AbstractRangedInfantry` | `dinput8.dll 0.3.0`, 6 keys, 6 applied, 0 failed, at the main menu; no game played | not run |
| `fastVertexFill` (2026-11-10): `C:\WoL-Test` (`uhc.dll` `c070d138`, ReShade's `d3d9.dll` left in place), this session's `dinput8.dll`, `engine-ext.cfg` with `perfStats`, `perfExecFile`, `multipleInstances background` and the key line; a 32-minute five-player save, and a skirmish against `wolOtto` with `xsErrorLog` | `dinput8.dll 0.3.0`, 3 applied, 0 failed; hook 0x40D523 reached; the save made with our `UHC.dll` loads; `verify`: 129,140 fills, 15.4 M vertices, 0 mismatches; skirmish: the AI at 29 units after 4 minutes, no XS message, the flag drawn, `res()` twice and minimize/restore went on drawing. FPS with the line on: 176.0 at 1920×1080, 174.8 at 2560×1440 (performance.md §11, "fastVertexFill in WoL"; ReShade included) | Line off: 152.5 and 153.8 FPS; the read-back 11–14 % of the main thread |
| Removing `dinput8.dll` and `engine-ext\` | Game reaches WoL's main menu, hashes unchanged, no `engine-ext` created | |
| Removing them again after the `fastVertexFill` runs (2026-11-10) | WoL's main menu; `uhc.dll`, `wol.cfg`, `age3y.exe`, `d3d9.dll` and `data\uhc` with the hashes of before the first run | |

`Error 0003`: none in `Age3Log.txt`, but that file is shared with other games and was rewritten by a later start, so the proof that the AI compiled is its XS calls and its base.

**Not shown:** multiplayer, saved games, and any key's effect beyond the table's first rows. WoL may patch more in a game than at the menu; only the menu was diffed.

## Next steps

1. For each `candidates` row, read the bytes the feature writes (the `remod` patch objects' `+0Ch` vectors, or the call/imm rewrite). Then confirm the site against the stock exe in the same way as the address map.
2. Verify the WoL-only cave at 0x699D31 and the changed TeamLimit SP range.
3. Resolve `loadingScreenCount`, `alpha2coverage`, `repairWallGlobal` and the tech effects, whose handlers have no direct exe constants. Follow the feature classes' vtables.
4. Next target: `wolPlugin.upl` / `wolai.upl` (custom syscalls; out of scope here).
