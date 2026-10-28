# Wars of Liberty `uhc.dll`

## What this is

A map of WoL's closed-source UHC build: what it adds beyond upstream AoE3UnHardcoded, and which `age3y.exe` addresses each cfg key touches.

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
| `enablerandomtecheffect`, `enabletechrenameeffect` | no | 0x10036680 | AdditionalTechEffectsFeature | none. Registers the tech effect types `RandomTech` and `SetTechName`. | unknown |
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
| kb queries | `kbUnitIsInventoryFull`, `kbUnitGetCurrentInventory`, `kbUnitGetInventoryCapacity`, `kbUnitGetNumberTargeters`, `kbUnitGetNumberWorkersIfSeeable` |
| AI plans | `trCreateDefendPlan2` |

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

## Next steps

1. For each `candidates` row, read the bytes the feature writes (the `remod` patch objects' `+0Ch` vectors, or the call/imm rewrite). Then confirm the site against the stock exe in the same way as the address map.
2. Verify the WoL-only cave at 0x699D31 and the changed TeamLimit SP range.
3. Resolve `loadingScreenCount`, `alpha2coverage`, `repairWallGlobal` and the tech effects, whose handlers have no direct exe constants. Follow the feature classes' vtables.
4. Next target: `wolPlugin.upl` / `wolai.upl` (custom syscalls; out of scope here).
