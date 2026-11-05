# Porting the features to WoL's DLL

How to add these features to Wars of Liberty's own `uhc.dll`, with their code. WoL's DLL has features
this project does not have yet, so WoL keeps its DLL and takes the code of the features it wants. For
what each feature does in WoL (the `wol.cfg` line, the data, the log, the videos), see the
[modding guide](modding-guide.md#5-feature-reference). For the engine internals, see
[how-it-works.md](how-it-works.md).

This page covers every key the modding guide marks **new**, 34 keys in all:

| Theme | Keys | Code |
|---|---|---|
| Game files | `bufferedFileReads` | [game-files](porting-code/game-files.md) |
| Population | `decimalPopulation` | [population](porting-code/population.md) |
| Data and scripting | `customHotkeyContexts`, `techRenameEffect` | [data](porting-code/data.md) |
| Civs | `danceBonusCivs`, `startingTC`, `civFirstTC` | [civs](porting-code/civs.md) |
| Healing and hit points | `healNonIdle`, `smartHealTargets`, `overhealHitpointBars`, `overhealSources`, `overhealDecay` | [healing](porting-code/healing.md) |
| Combat | `dodgeAnyUnit`, `dodgeChance`, `dodgeSoundSet`, `criticalSoundSet`, `damageOverTime`, `spreadAnyAccuracy`, `broadsideMuzzleLimit`, `snareOnlyHitUnit` | [combat](porting-code/combat.md) |
| Gathering | `showGatherRate`, `workRateByAbstractType`, `autoGatherScaleByContained`, `unitResourceAuras`, `resourceGatherAuras`, `resourceDebt` | [gathering](porting-code/gathering.md) |
| Buildings and training | `liveBuildingWorkRate`, `buildingWorkRateAuras`, `costEscalationTechs`, `trainBatchSize`, `maintainWaitForPop`, `noTrainNearEnemyTC`, `lifespanAfterConstruction`, `gaiaSocketsOnly`, `hcShipmentPointFallback` | [buildings](porting-code/buildings.md) |
| Techs and transforms | `techPrereqRecheck`, `transformUpdatesLOS`, `transformInventory` | [techs](porting-code/techs.md) |
| Interface | `abilitySlots`, `wonderPanelSkipAuras`, `noCorpseDopples` | [interface](porting-code/interface.md) |
| What they all use | the site table, patching, the log, shared hooks | [helpers](porting-code/helpers.md) |

The code pages are the code itself, C++ and MASM, generated from `src/` with `tools/porting_code.py`, so
they cannot drift from what ran in the videos. They are separate pages because GitHub stops showing a
Markdown file of about 512 KB. The code is under the [MIT license](../LICENSE): copy it into WoL's DLL,
keeping the license notice.

**What has not been done:** none of this has been built inside WoL's DLL. We only have its binary, not
its source, so what this page says about `remod` and `IUHCConfig` comes from reading the binary. Every
feature ran on WoL's exe and data with this project's DLL in place of WoL's
([section 7](#7-what-is-not-verified)), never next to WoL's own code.

Contents:
1. [Check that you can use the sites](#1-check-that-you-can-use-the-sites)
2. [What to copy](#2-what-to-copy)
3. [Building the hooks in WoL's DLL](#3-building-the-hooks-in-wols-dll)
4. [Each feature's contract](#4-each-features-contract)
5. [Integration rules](#5-integration-rules)
6. [Data and testing](#6-data-and-testing)
7. [What is not verified](#7-what-is-not-verified)

## 1. Check that you can use the sites

All addresses are virtual addresses in WoL's `age3y.exe` (`0a277f14…`), which are the same as in the
stock Steam exe (`b1a1dab7…`): WoL's exe is the stock exe plus the loader, LAA and four string patches
([binaries.md](binaries.md#extra-patches-in-the-wars-of-liberty-exe)), and none of those patches falls
inside the ranges below.

**The ranges.** Each hook writes a 5-byte `jmp` (NOP-padded where it covers more), the rel32 of a
`call`, or a single constant, and relies on stock code around it: the instructions it
re-executes, the code it jumps back to, and the stock code its C++ side mirrors or calls (for
example the search block of `hcShipmentPointFallback`, or the population test of
`maintainWaitForPop`). Rows with "—" in the Written column are such verify-only ranges.
**Nothing else may patch these ranges**, neither WoL's DLL nor any other tool, unless the section below
says so:

| Site | VA | Length | Written | Stock bytes at the written VA | Role |
|---|---|---|---|---|---|
| `GatherFallbackExit` | `0x669E2E` | 10 B | 5 B at `0x669E2E` | `5D 5F 5E 33 C0` (`pop ebp; pop edi; pop esi; xor eax,eax`) | "nothing found" exit of FUN_004C6B9E; hcShipmentPointFallback hook |
| `GatherFallbackStore` | `0x4C6CB2` | 12 B | — | — | store-and-return path the hook jumps to |
| `GatherFallbackBlock` | `0x6698B4` | `0xB0` B | — | — | stock FortFrontier search block; the hook repeats its logic, so it must be unchanged |
| `GatherPointValid` | `0x85302C` | `0x38` B | — | — | stock stored-point check, `bool thiscall(hc, unit)`, `ret 4`; the FirstTC helper calls it |
| `HealIdleCheck` | `0x9E0C79` | `0x2C` B | 5 B at `0x9E0C79` | `8B 4F 58 85 C9` (`mov ecx,[edi+58h]; test ecx,ecx`) | busy test of each heal tick (FUN_009E0B53) |
| `HealAutoSearchIdle` | `0x9CD9C0` | `0x15` B | 5 B at `0x9CD9C7` | `E8 DB 17 A8 FF` (`call 44F1A7h`) | idle test of the automatic heal search (FUN_009CD865) |
| `SmartHealRange` | `0x9CDA21` | `0x1E` B | 5 B at `0x9CDA36` | `E8 F2 F4 E2 FF` (`call 7FCF2Dh`) | the heal search's range test; smartHealTargets |
| `SmartHealLoopEnd` | `0x9CDA3F` | `0x40` B | 5 B at `0x9CDA58` | `5E 5B 5F 32 C0` (`pop esi; pop ebx; pop edi; xor al,al`) | the search's loop step, no-target exit and accept path; smartHealTargets |
| `SmartHealLoop` | `0x9CD923` | `0x5F` B | — | — | the search's loop head (verified only); smartHealTargets |
| `AbstractTypesEnd` | `0x51BA23` | `0x15` B | 5 B at `0x51BA31` | `5F 5E B0 01 5B` (`pop edi; pop esi; mov al,1; pop ebx`) | epilogue of the abstract unit type registration (FUN_0051A5DC) |
| `DotProtoActionTag` | `0x5FA10F` | `0x1B` B | 8 B at `0x5FA11E` | `85 C0 0F 84 C7 33 00 00` (`test eax,eax; je 5FD4EDh`) | unknown-tag fall-through of the action parser FUN_005F98A0; the shared action tag hook (`actiontags.cpp`: damageOverTime, spreadAnyAccuracy) |
| `DotProtoActionCall` | `0x5FA20E` | 5 B | — | — | the `<ProtoAction>` handler's `call 5F98A0h`; the tag hook checks its return address 0x5FA213 |
| `TacticsActionCall` | `0x5FA60A` | `0x19` B | — | — | a tactics `<action>`'s parse in FUN_005FA5B3, up to its `call 5F98A0h`; the tag hook checks its return address 0x5FA623 |
| `SpreadHitRoll` | `0x499890` | `0x17` B | 9 B at `0x499890` | `83 FB 02 0F 84 E2 56 03 00` (`cmp ebx,2; je 4CEF7Bh`) | the projectile launch after the precalculated roll; spreadAnyAccuracy hit hook (continuation 0x499899 `mov [esi+20h],ebx` and the reloads after it) |
| `SpreadMissStub` | `0x4CEF7B` | `0x11` B | 7 B at `0x4CEF7B` | `8D 44 24 28 50 8B CE` (`lea eax,[esp+28h]; push eax; mov ecx,esi`) | the miss stub (`call 4CEF8Ch; jmp 499899h`); spreadAnyAccuracy miss hook |
| `SpreadRadius` | `0x4CF00B` | `0x2C` B | 27 B at `0x4CF00B` | `D8 0D EC 0A BA 00 D9 54 24 0C D8 1D F8 0A BA 00 DF E0 F6 C4 41 0F 84 BD 3C 01 00` (`fmul [0BA0AECh]; fst [esp+0Ch]; fcomp [0BA0AF8h]; fnstsw ax; test ah,41h; je 4E2CE3h`) | the radius of the miss offset FUN_004CEF8C; spreadAnyAccuracy radius hook (continuation 0x4CF026, the `r > 1e-6` test) |
| `SpreadDraws` | `0x4CF037` | `0x40` B | — | — | the offset's two random draws, which the radius hook leaves to the stock code |
| `DotTakeDamageEntry` | `0x49B3D9` | 14 B | 6 B at `0x49B3D9` | `81 EC 8C 00 00 00` (`sub esp,8Ch`) | entry of TakeDamage FUN_0049B3D9; damageOverTime hit hook |
| `DotWorldUpdateEntry` | `0x481A57` | 8 B | 5 B at `0x481A57` | `83 EC 0C 53 55` (`sub esp,0Ch; push ebx; push ebp`) | entry of the world update FUN_00481A57; the shared tick wrapper (`worldtick.cpp`: damageOverTime, overhealDecay) |
| `HpSetter` | `0x4820A1` | `0x22` B | — | — | the HP setter overhealDecay calls (verified only) |
| `DodgeProtoCheck` | `0x49ACE5` | 12 B | 6 B at `0x49ACE5` | `8B 46 5C 8B 40 04` (`mov eax,[esi+5Ch]; mov eax,[eax+4]`) | proto test of the dodge FUN_0049ACAA; dodgeAnyUnit hook |
| `DodgeTechCheck` | `0x6A249C` | 10 B | — | — | the stock dodge path the hook enters (`push "ypDodge"; call 600BE1h`) |
| `DodgeCall` | `0x49B023` | 7 B | 5 B at `0x49B023`, only with `log` | `E8 82 FC FF FF` (`call 49ACAAh`) | the damage function's call to the dodge; dodgeAnyUnit log wrapper |
| `DodgeTest`, `DodgeRollPath`, `DodgeCaller` | `0x49ACAA`, `0x6A249C`, `0x49AF98` | `0x6E`, `0x1B5`, `0x92` B | — | — | the dodge test's frame and exits, its roll path and feedback, the caller's EDI = damage info; dodgeChance (verified only) |
| `SyncRandom`, `TechActive`, `TechByName`, `DamageTypeLoad` | `0x407CE7`, `0x94AF27`, `0x600BE1`, `0x52D454` | `0x40`, `0x33`, `0x10`, `0x51` B | — | — | the synced RNG, the tech test, tech by name and the damage type list loader; dodgeChance (verified only) |
| `DodgeSound` | `0x6A2628` | 8 B | 5 B at `0x6A2628` | `68 E0 74 BD 00` (`push "PowerEvade"`) | the dodge's sound set; dodgeSoundSet hook |
| `CriticalSound` | `0x6A2A9A` | 8 B | 5 B at `0x6A2A9A` | `68 18 75 BD 00` (`push "PowerCriticalStrike"`) | the critical hit's sound set; criticalSoundSet hook |
| `SingleInstanceSemaphore` | `0x55A185` | 6 B | — (the IAT slot `0xB843F0` instead) | `FF 15 F0 43 B8 00` (`call [CreateSemaphoreW]`) | the single-instance check; multipleInstances knows this call by its return address `0x55A18B` |
| `BuildingWorkRateGetter` | `0x9BFE33` | `0x15` B | 5 B at `0x9BFE33` | `8B 41 68 85 C0` (`mov eax,[ecx+68h]; test eax,eax`) | the BuildingWorkRate getter, including the tail `0x9BFE3E` the hook continues at; liveBuildingWorkRate |
| `WorkRateTrainCall` | `0x9EA410` | `0x14` B | 8 B at `0x9EA410` (`jmp` + 3 NOP), noTrainNearEnemyTC only | `8B 4E 10 E8 1B 5A FD FF` (`mov ecx,[esi+10h]; call 9BFE33h`) | the Train update's getter call (FUN_009EA28B), up to its first write of EAX; liveBuildingWorkRate verifies it, noTrainNearEnemyTC hooks it (continuation `0x9EA418`) |
| `BwrTrainCall` | `0x9EA410` | 8 B | 5 B at `0x9EA413` (a `call` to the wrapper), buildingWorkRateAuras, only while all 8 bytes are stock | `E8 1B 5A FD FF` (`call 9BFE33h`) | the same call, checked on its own: with noTrainNearEnemyTC on, buildingWorkRateAuras leaves it to that key's hook |
| `WorkRateResearchCall`, `WorkRateCommandResearchCall`, `WorkRateMaintainCall` | `0x9E65F4`, `0x9D58D1`, `0x6AB23C` | `0x0D`, `0x0D`, `0x14` B | 5 B each at `0x9E65F7`, `0x9D58D4`, `0x6AB23F` (a `call` to the wrapper), buildingWorkRateAuras only | `E8 37 98 FD FF`, `E8 5A A5 FE FF`, `E8 EF 4B 31 00` (`call 9BFE33h`) | the getter's other three callers, each up to its first write of EAX (the hooks return another EAX); liveBuildingWorkRate verifies them |
| `TrainFrac`, `MaintainFrac` | `0x9EA1FA`, `0x9E27E4` | `0x45` B each | 9 B at each (`jmp` + 4 NOP) | `D9 41 64 D8 1D 5C 75 C3 00` (`fld [ecx+64h]; fcomp [0C3755Ch]`), `D9 41 6C D8 1D 68 74 C3 00` (`fld [ecx+6Ch]; fcomp [0C37468h]`) | the Train and Maintain fraction functions, `void thiscall(action)`, one caller each (0x9EA4B3, 0x6AB264); liveBuildingWorkRate TrainPoints hooks (continuations `0x9EA203`, `0x9E27ED`) |
| `TrainPointsProto`, `TrainPointsSet`, `MaintainPointsProto`, `MaintainPointsSet` | `0x9EAC3D`, `0x9EB19F`, `0x9E28BD`, `0x9E2A05` | `0x29`, `0x43`, `0x11`, `0x3D` B | — | — | the stock rule the TrainPoints refresh repeats (the player's proto by 0x45311B, flag 9Eh by 0x44D063, the base proto by 0x45316E, `+6Ch`, × count for Maintain); liveBuildingWorkRate |
| `TechPrereqDirtyCheck` | `0x491A18` | 10 B | 10 B at `0x491A18` (`jmp` + 5 NOP) | `80 7F 10 00 0F 85 B2 7C 07 00` (`cmp byte [edi+10h],0; jne 5096D4h`) | dirty test of a player's tech tree (FUN_004919CE); techPrereqRecheck |
| `TechPrereqNoPass`, `TechPrereqPassEntry`, `TechPrereqPassLoop`, `TechPrereqEntryUpdate`, `TechPrereqListEval`, `TechPrereqListLoop`, `TypeCountCtor`, `PrereqBaseCtor`, `TypeCountEval`, `TechTemplateFallback`, `TechTemplateLoop`, `TechNameById`, `TechStatusUpdateCall`, `WorldStepCount` | `0x491A22`, `0x5096D4`, `0x5095A1`, `0x5094EB`, `0x5094B4`, `0x50946A`, `0x8EE860`, `0x6201AA`, `0x8EE8E7`, `0x48050F`, `0x61FE63`, `0x5C400B`, `0x481D3D`, `0x481A87` | 10, 9, `0x77`, `0x51`, `0x24`, `0x4A`, `0x10`, `0x16`, `0x34`, `0x1B`, `0x3C`, `0x19`, `0x19`, `0x0F` B | — | — | the two continuations, the stock re-check and evaluator the check mirrors and calls, the TypeCount layout, the template records, the tech names, the world update's call and step count |
| `MaintainSpawn` | `0x6AB27D` | `0x2C` B | 6 B at `0x6AB27D` | `8B 56 68 8B 46 64` (`mov edx,[esi+68h]; mov eax,[esi+64h]`) | cycle-complete path of the Maintain update FUN_00492F3E; maintainWaitForPop (continues at `0x6AB283`) |
| `MaintainCycleDone`, `MaintainRestart`, `MaintainNotDone`, `MaintainEpilogue`, `MaintainSpawnSetup`, `MaintainSpawnPopTest`, `MaintainSpawnPopTest2`, `MaintainGroupPopTest` | `0x6AB264`, `0x6AB2D1`, `0x6AB180`, `0x493039`, `0x9E2E35`, `0x9E2F79`, `0x9E3110`, `0x9E2B69` | `0x19`, `0x0F`, 6, 7, `0xBA`, `0x6D`, `0x19`, `0x71` B | — | — | the ≥ 1.0 test, the restart a held cycle skips, the "not complete" exit and the epilogue, and the spawn's population tests the predicate repeats |
| `TransformSetProto` | `0x9C763F` | 14 B | 5 B at `0x9C763F` | `E8 AF 0B AD FF` (`call 4981F3h`) | setProto in the transform in place FUN_009C754C; transformUpdatesLOS (continues at `0x9C7644`) |
| `TransformProtoLookup`, `TransformPushProto`, `TransformVisRemove`, `TransformVisAdd`, `LosBuildCopyRead`, `LosBuildCopyWrite`, `LosGetter` | `0x9C754C`, `0x9C763C`, `0x9C756A`, `0x9C772A`, `0x6A20B2`, `0x6A20ED`, `0x48207E` | 22, 3, 11, 11, 8, 16, `0x20` B | — | — | the new proto in EBP and at `[esp]`, the visibility remove and add around the hook, and the LOS layout (build completion's copy, the getter) |
| `BroadsideMuzzleCap` | `0x5033CF` | `0x11` B | 5 B at `0x5033D5` | `BE 06 00 00 00` (`mov esi,6`) | the stock limit of 6 muzzles per side in FUN_0050339A; broadsideMuzzleLimit |
| `BroadsideMuzzleClampL` | `0x5034E2` | 12 B | 6 B at `0x5034E2`, only with `log` | `3B C6 89 44 24 1C` (`cmp eax,esi; mov [esp+1Ch],eax`) | the MuzzleL clamp; broadsideMuzzleLimit log hook |
| `BroadsideInitHead`, `BroadsideMuzzleClampR`, `BroadsideMuzzleReload`, `BroadsideSingleUseCap`, `BroadsideClampCold` | `0x50339A`, `0x503447`, `0x5034B3`, `0x6A8236`, `0x6A8247` | `0x35`, 12, 13, 17, 22 B | — | — | the set-up up to the Ship test, the MuzzleR clamp, the limit reload, the `SingleUsePlayer` block and the cold clamps |
| `AbilitySlotCopies` | `0x695BB6` | `0x4C` B | 4 B at `0x695BD3` | `05 00 00 00` (imm32 of `mov edi,5`) | page-11 copy loop of the command panel refresh FUN_0046188E; abilitySlots |
| `AbilityButtonRecharge` | `0x696C70` | 11 B | 5 B at `0x696C70`, only with `log` | `E8 C2 81 DC FF` (`call 45EE37h`) | first instruction of GetNth's true path; abilitySlots log hook |
| `AbilityPage11Branch`, `AbilityNthCall` | `0x4C5AEB`, `0x696C0B` | `0x10`, `0x65` B | — | — | the only entry of the copy loop, and the GetNth call frame the log hook reads |
| `WonderPanelAbilityCall` | `0x69EE5D` | `0x2D` B | 5 B at `0x69EE5D` (a `call` to the hook) | `E8 6A F7 04 00` (`call 6EE5CCh`) | the wonder power panel's ability request and the stock re-check after it; wonderPanelSkipAuras (returns to `0x69EE62`) |
| `WonderPanelAbilityArgs`, `NthVisibleAbility`, `AbilityByIndex` | `0x69EE37`, `0x6EE5CC`, `0x44E702` | `0x26`, `0x14`, `0x1D` B | — | — | the arguments the hook re-pushes, and the two functions it calls |
| `LifespanTick` | `0x483EEC` | 12 B | 10 B at `0x483EEC` | `D9 44 24 0C D8 1D E4 4B B8 00` (`fld [esp+0Ch]; fcomp [0B84BE4h]`) | start of the lifespan tick's cold part; lifespanAfterConstruction tick hook (continues at `0x483EF6`) |
| `FadeTimerCommit` | `0x482A1A` | 12 B | 6 B at `0x482A1A` | `75 0A 8B 4C 24 10` (`jne 482A26h; mov ecx,[esp+10h]`) | store of the fade timer in FUN_004829FA; lifespanAfterConstruction fade hook (continues at `0x482A20` or `0x482A26`) |
| `LifespanTickHead`, `LifespanTickReturn`, `FadeUpdateHead`, `FadeDispatch`, `FadeOutTimerTest`, `IsBuilt`, `IsBuiltFalse`, `IsA`, `IsATrue` | `0x482BF6`, `0x482C20`, `0x4829FA`, `0x482A26`, `0x4A174A`, `0x44DDB4`, `0x69F904`, `0x44D7FA`, `0x44F139` | `0x2A`, 5, `0x20`, `0x63`, `0x15`, `0x1F`, 3, `0x69`, 5 B | — | — | the frames the hooks read, the exit a held unit takes, the fade branches, and the isBuilt and is-a functions the hooks call |
| `GaiaSocketFound` | `0x508CC1` | 10 B | 5 B at `0x508CC1` | `C6 44 24 37 01` (`mov byte [esp+37h],1`) | "socket found" in PLACE (FUN_0050703D); gaiaSocketsOnly (continues at the `jmp 50757Eh` at `0x508CC6`) |
| `GaiaSocketMatch`, `GaiaSocketLoopNext`, `GaiaSocketMissing` | `0x508BE6`, `0x50757E`, `0x509215` | `0xDB`, `0x11`, `0x15` B | — | — | PLACE's socket test (frame and registers the hook relies on), its next entry, and its "no socket" failure |
| `HotkeyFindCall` | `0x5C1778` | 10 B | 5 B at `0x5C1778` (a `call` to the hook) | `E8 2E FF FF FF` (`call 5C16ABh`) | keymap find in FUN_005C16EA; customHotkeyContexts registration wrapper |
| `HotkeyDeactivateLast` | `0x79F1A5` | 7 B | 5 B at `0x79F1A5` (a `call` to the hook) | `E8 49 30 CA FF` (`call 4421F3h`) | last switch-off (`WonderAccel`) in FUN_0079EF9C; customHotkeyContexts switch-off wrapper |
| `HotkeyUnitContext` | `0x79F897` | 14 B | 6 B at `0x79F897` | `8B BE 78 01 00 00` (`mov edi,[esi+178h]`) | the selected unit's context in FUN_0079F851; customHotkeyContexts context hook |
| `HotkeyTrainerBuildFlag` | `0x64A034` | 7 B | 5 B at `0x64A034` | `C6 44 24 13 01` (`mov byte [esp+13h],1`) | BuildAccel byte for a trainer that is not a building; customHotkeyContexts trainer hook |
| `HotkeyFindContext`, `HotkeyRegisterContext`, `HotkeyUnitActivate`, `HotkeyDeactivateById`, `HotkeyTrainerQualified` | `0x5C16AB`, `0x628FC0`, `0x79F9BF`, `0xAB397F`, `0x64A05A` | `0x3F`, `0x2F`, `0x26`, 14, 4 B | — | — | the find and register functions the wrapper calls, the code that turns EDI on, the switch-off by ID, and the Building path the trainer hook enters |
| `SnareGroupPace` | `0x4FD3FD` | `0x1D` B | `0x1A` B at `0x4FD3FD` (`jmp` + NOPs to `0x4FD417`) | `8B 17 8B CF 8B 42 34 E8 41 C3 FA FF D8 5E 7C DF E0 F6 C4 05 0F 8B 23 01 00 00` (`mov edx,[edi]` … `jnp 4FD53Ah`) | member velocity compare of the group recompute FUN_004FD289; snareOnlyHitUnit pace hook |
| `SnareSlotWait` | `0x4FA172` | `0x15` B | 6 B at `0x4FA17D` | `8B 46 04 80 08 80` (`mov eax,[esi+4]; or byte [eax],80h`) | straggler bit of the member step FUN_004FA03B |
| `SnarePathWait` | `0x6AA510` | `0x0D` B | 6 B at `0x6AA514` | `8B 43 04 80 08 80` (`mov eax,[ebx+4]; or byte [eax],80h`) | straggler bit for a member with its own path |
| `SnarePathCheck` | `0x6AA537` | `0x3E` B | 6 B at `0x6AA56A` | `8B 40 04 80 08 80` (`mov eax,[eax+4]; or byte [eax],80h`) | the same path's distance check, up to the `jmp 4F9F99h` it continues at |
| `SnareGroupPaceStore`, `SnareCreate`, `SnareModifierInit`, `SnareCollector`, `SnareModifierSum`, `SnareModifierSumEnd`, `SnareModifierSumTactic`, `SnareVelocityGetter`, `SnareVelocityRecord`, `SnareUnitById` | `0x4FD53A`, `0x4DD201`, `0x4B3D44`, `0x49F34B`, `0x4B3C48`, `0x4E2A8E`, `0x6A88D6`, `0x487E27`, `0x488612`, `0x4F9EB7` | `0x14`, `0x2C`, `0x5A`, `0x79`, `0xB7`, `0x1B`, `0x22`, `0x4D`, `0x1E`, `0x44` B | — | — | the stock store the pace hook leaves to, and the stock code the helpers mirror (the snare's parameters, the modifier layout, the collector, the velocity sum, the getter, the unit lookup) |
| `TechRenameRegister` | `0x524CAA` | `0x1C` B | 7 B at `0x524CB5` | `83 BE 04 35 00 00 00` (`cmp dword ptr [esi+3504h],0`) | after the last stock effect type registration in FUN_0052277E; techRenameEffect registration hook |
| `TechRenameFactoryDefault` | `0x62146F` | `0x13` B | 5 B at `0x62146F` | `68 1F 05 00 00` (`push 51Fh`) | default case of the effect factory FUN_00620535; techRenameEffect factory hook |
| `TechRenameTypeByName`, `TechRenameFactoryHead`, `TechRenameEffectParse`, `TechRenameEffectCtor`, `TechRenameEffectVtable`, `TechRenameApplyCall`, `TechRenameLocalTechNode` | `0x61FF1B`, `0x620535`, `0x6205C7`, `0x620B8F`, `0xB965C0`, `0x7F80FD`, `0x8D0005` | `0x10`, `0x0F`, `0x2D`, `0x1D`, `0x44`, `0x17`, `0x27` B | — | — | the type lookup, the factory head and the parse around the hook, the BEffect ctor and vtable (`.rdata`) the effect copies, the apply dispatcher's call and the player's tech node function |
| `NoCorpseDoppleCreate` | `0x49534D` | `0x24` B | 8 B at `0x49534D` | `8B 44 24 2C 8B 4C 24 54` (`mov eax,[esp+2Ch]; mov ecx,[esp+54h]`) | dopple creation in the unit visibility update FUN_0048679A, through `call 4DB3D0h` and `jmp 486A30h`; noCorpseDopples |
| `NoCorpseDoppleGaiaCheck`, `NoCorpseDoppleSkip`, `NoCorpseDoppleAliveCall` | `0x4F1088`, `0x486A30`, `0x4868FA` | `0x11`, `0x17`, `0x15` B | — | — | the second way into the site, the "no dopple" exit the hook takes, and the stock virtual isAlive call it imitates |
| `DanceTrainGate`, `DanceXpGate`, `DanceGatherGate`, `DanceRegenGate` | `0x8D47A6`, `0x4E0DFA`, `0x4ECD4E`, `0x490486` | 13, 13, 13, 17 B | 6 B each at `0x8D47AB`, `0x4E0DFF`, `0x4ECD53`, `0x49048B` | `3B 05 50 FB C6 00` (`cmp eax,[0C6FB50h]`) at each | the first native civ compare of the four dance readers; danceBonusCivs. Each range covers the civ load before it and the `je` after it |
| `DanceTrainBranch`, `DanceXpBranch`, `DanceGatherBranch`, `DanceRegenBranch` | `0x8D47CF`, `0x4E0E29`, `0x4ECD7D`, `0x679E66` | 13, 10, 10, 13 B | — | — | the native branches the hooks enter |
| `FirstTcGate` | `0x49880A` | `0x16` B | 13 B at `0x49880A` (`jmp` + 8 NOP) | `83 BE F0 04 00 00 00 0F 8C 13 E3 06 00` (`cmp dword ptr [esi+4F0h],0; jl 506B2Ah`) | FirstTC gate at the end of Player::addUnit FUN_0049874F, with the exit `0x498817` both startingTC hooks continue at; startingTC gate hook |
| `FirstTcProtoCheck` | `0x506B3B` | `0x11` B | 6 B at `0x506B3B` (`jmp` + 1 NOP), once for startingTC and civFirstTC | `3B 81 08 5E 00 00` (`cmp eax,[ecx+5E08h]`) | the TownCenter test of addUnit's cold chunk; the FirstTC proto hook both keys share |
| `FirstTcChunk`, `FirstTcSet`, `FirstTcRuleLookup`, `SetLifespanArm`, `UnitAliveSlot` | `0x506B2A`, `0x67ABD4`, `0x8CE597`, `0x48DCB9`, `0xB9355C` | `0x11`, `0x0E`, `0x44`, `0x28`, 4 B | — | — | the registers the proto hook is entered with, the FirstTC store both hooks leave through, the rule's unit lookup the helper mirrors, the lifespan bit, and the unit vtable's alive slot (`.rdata`); startingTC (also `IsA`). civFirstTC verifies `FirstTcChunk`, `FirstTcSet` and `UnitAliveSlot` too; `FirstTcSet` is also verified by hcShipmentPointFallback when `FirstTC` is listed |
| `CivTagUnknown` | `0x52BAFA` | `0x20` B | 8 B at `0x52BB07` (`jmp` + 3 NOP) | `33 FF 39 BB 80 00 00 00` (`xor edi,edi; cmp [ebx+80h],edi`) | the unknown-tag path of the `<civ>` child loop in the civs.xml parser FUN_0052A590, with the last tag compare before it and the `jle 52B43Dh / jmp 52C066h` after it (continuation `0x52BB0F`); civFirstTC tag hook |
| `RmPlaceCall` | `0x925F45` | `0x0E` B | 5 B at `0x925F4C` (a `call` to the wrapper) | `E8 E5 F9 FF FF` (`call 925936h`) | the only call of objectDef::place, in FUN_00925F11, which every `rmPlaceObjectDef*` reaches; civFirstTC placement wrapper (returns to `0x925F51`) |
| `TownStartQuery` | `0x679AC1` | `0x15` B | 6 B at `0x679AC8` (`jmp` + 1 NOP) | `8B 99 08 5E 00 00` (`mov ebx,[ecx+5E08h]`) | the TownCenter proto the town starting units' query (FUN_0049039A) looks for; civFirstTC town hook (continues at `0x679ACE`) |
| `CivTagNextNode`, `CivById`, `CivOfPlayer`, `ProtoByName`, `ProtoById`, `RmPlace`, `RmItemFootprint`, `RmNomadStart`, `TownStartSpawn`, `TownStartColonyLoop` | `0x52B43D`, `0x405C2E`, `0x4539D3`, `0x5A2346`, `0x45316E`, `0x925936`, `0x924B1D`, `0x90B683`, `0x679B50`, `0x7C2407` | `0x14`, `0x18`, `0x10`, `0x20`, `0x1E`, `0x6F`, `0x9E`, `0x19`, `0x1A`, `0x31` B | — | — | the next-child step the tag hook jumps to, the civ by ID and a player's civ ID, the two proto lookups, the head of objectDef::place up to its `Special_StartingUnits` test, addItem's footprint, rmGetNomadStart, the spawn and request clear after the query, and the spawn's colony test the helper repeats; civFirstTC (also `ProtoFlag`, `FirstTcChunk`, `FirstTcProtoCheck` while it is stock, `FirstTcSet`, `PlayerById`, `UnitById`, `UnitAliveSlot`) |
| `TransformInvHook` | `0x9C7625` | `0x17` B | 7 B at `0x9C7625` (`jmp` + 2 NOP) | `8B 46 58 85 C0 74 10` (`mov eax,[esi+58h]; test eax,eax; je 9C763Ch`) | action manager test in the transform in place FUN_009C754C; transformInventory (continues at `0x9C762C` or `0x9C763C`) |
| `TransformKbRemove`, `TransformKbReAdd`, `InventorySeed`, `InventoryRecreate`, `InventoryFree`, `ResListCopy`, `ResListScale`, `ResListTotal` | `0x9C75CF`, `0x9C766F`, `0x67DE0D`, `0x9BFE5A`, `0x4BA757`, `0x480A73`, `0x480B94`, `0x58EF02` | `0x56`, `0x23`, `0x1E`, `0x6E`, `0x50`, `0x49`, `0x7E`, `0x81` B | — | — | the knowledge-base remove and re-add around the hook, creation's inventory recipe, the engine functions the helper calls, and the list encoding it decodes; transformInventory (also `TransformProtoLookup`, `TransformPushProto`, `IsA`) |
| `TrainUpdateTrainer`, `TrainRateScale`, `FirstTcRuleLoop`, `FirstTcRuleFilter`, `PlayerById`, `PlayerByIdNull`, `UnitById`, `UnitByIdNull`, `PlayerIsEnemy` | `0x9EA2B2`, `0x9EA424`, `0x8CE9BE`, `0x8CEB45`, `0x44CB21`, `0x4649E1`, `0x44CC6D`, `0x4E2A35`, `0x484D2D` | `0x0B`, `0x13`, `0x68`, `0x37`, `0x1E`, 5, `0x3A`, 5, `0x20` B | — | — | the Train action's registers, the code after the continuation, the placement rule's FirstTC loop and player filter the helper mirrors, and the three functions it calls; noTrainNearEnemyTC (also `WorkRateTrainCall`, `IsA`, `IsATrue`, `NoCorpseDoppleAliveCall`); `PlayerById(Null)` and `UnitById(Null)` are also verified by hcShipmentPointFallback when `FirstTC` is listed, and `PlayerById` and `UnitById` by civFirstTC |
| `UnitsNearPoint`, `TypeRuleQuery` (+ `IsBuilt`) | `0x4A1C55`, `0x8CEA69` | `0xF8`, `0x22` B | — | — | noTrainNearEnemyTC with a `near` type: the world's spatial query the helper calls (`int thiscall(world, point, radius, 1, IdList*)`, `ret 10h`) and the placement rule's call of it |
| `DodgeFloatingText`, `FloatingTextAdd`, `UnitVisibleTo`, `ConfigInt` (+ `BStringFromWide`, `BStringFromId`, `BStringFree`) | `0x6A24FC`, `0x8023AE`, `0x4818F4`, `0x46A144` | `0x10D`, `0xC4`, `0x45`, `0x3F` B | — | — | the shared floating text (`src/floatingtext.cpp`), for noTrainNearEnemyTC's warning (unless `nowarn`) and damageOverTime's tick text: the dodge's floating text block it repeats, the text add (`ret 24h`), the visible-to test and the cfg int reader |
| `SnareTargetCheck`, `SnareApply` (+ `SnareCreate`) | `0x4DD1DE`, `0x4DD22D` | `0x23`, `0x82` B | — | — | damageOverTime's `AttachSnare`: the stock snare's "can move" test (`vtbl+90h`) and the modifier creator it calls (`ret 28h`) |
| `OverhealBarRatio` | `0x45FAA7` | `0x11` B | 5 B at `0x45FAAF` | `E8 E1 F7 FF FF` (`call 45F295h`) | floating HP bar fill in the unit visual update's bar chunk; overhealHitpointBars |
| `OverhealGroupRatio` | `0x4C5012` | `0x0F` B | 5 B at `0x4C5014` | `E8 7C A2 F9 FF` (`call 45F295h`) | selection group average in FUN_004C4FB5 |
| `OverhealPanelMax` | `0x698B18` | `0x26` B | 5 B at `0x698B35` | `E8 CE 78 DE FF` (`call 480408h`) | unitHitPointsValue max |
| `OverhealStatMax` | `0x4D7560` | `0x51` B | 6 B at `0x4D7575` | `8B 81 B4 00 00 00` (`mov eax,[ecx+0B4h]`) | the max HP getter inlined in the 'Hit Points' stat row; the rest of it (to `0x4D75AC`) becomes dead code |
| `OverhealStatBase` | `0x4D75DA` | `0x45` B | 6 B at `0x4D7615` | `D9 80 98 00 00 00` (`fld [eax+98h]`) | the stat row's base |
| `OverhealInfoBase` | `0x9AFA07` | `0x2D` B | 6 B at `0x9AFA2A` | `D9 81 98 00 00 00` (`fld [ecx+98h]`) | ObjectInfo base (FUN_009AF31A) |
| `OverhealInfoMax` | `0x9AFA34` | `0x23` B | 5 B at `0x9AFA4E` | `E8 B5 09 AD FF` (`call 480408h`) | ObjectInfo max |
| `OverhealSegmentQueue` | `0x45FB3F` | `0x32` B | 5 B at `0x45FB6C` | `E9 42 1B FF FF` (`jmp 4516B3h`) | after the floating bar is queued; `segment` |
| `HpBarRenderStart` | `0x45C4AF` | `0x3F` B | 6 B at `0x45C4B9` | `8B 9D D4 08 00 00` (`mov ebx,[ebp+8D4h]`) | the renderer's count, before the vertex lock; `segment` |
| `HpBarRenderLoop` | `0x45C60B` | `0x587` B | 6 B at `0x45CB72` | `83 C0 01 83 C1 1C` (`add eax,1 / add ecx,1Ch`) | the whole per-record loop (the vertex layout the hook relies on) and its end; `segment` |
| `OverhealTextStat`, `OverhealTextStatSplit` | `0x4D7647`, `0x69A9B0` | `0x15`, `0x1B` B | 5 B at `0x4D7651`, `0x69A9C0` | `68 54 20 BA 00`, `68 54 4A C3 00` (`push` format) | the stat row's HP text formats; `segment` |
| `OverhealPortraitTail` | `0x4C82E6` | `0x102` B | 9 B at `0x4C83DF` | `8D 4C 24 70 E8 E2 8C F3 FF` (`lea ecx,[esp+70h]; call 4010CAh`) | the portrait bar's tail; `segment` (also `OverhealPortraitColours` 0x69A614, `HealthBarGadgets` 0x9BAEE5, verify only) |
| `OverhealStatRow` | `0x4D76DB` | 9 B | 9 B at `0x4D76DB` | `BF 02 00 00 00 89 7C 24 2C` (`mov edi,2; mov [esp+2Ch],edi`) | the row after the HP row; `stat` (also `GroupHealthRow` 0x69A9D3, verify only) |
| `GadgetByName`, `ProgressGadget`, `GadgetRelease`, `ProgressFill`, `GadgetShow`, `GadgetHide`, `GadgetRef`, `BStringFromWide`, `BStringSet` | `0xAB7C2F`, `0x44B8B8`, `0x40431B`, `0x590772`, `0x447F7B`, `0x448F13`, `0x4C519C`, `0x401A12`, `0x40196F` | — | — | — | the UI functions the portrait bar and the Overheal row call (verified only) |
| `RegenAddHp`, `DanceRegenAddHp` | `0x49087C`, `0x67A036` | `0x12`, `0x15` B | 5 B at `0x490881`, `0x67A03B` | `E8 1D 1B FF FF`, `E8 63 83 E0 FF` (`call 4823A3h`) | the regeneration adds; overhealDecay |
| `OverhealAddEntry` | `0x4823A3` | `0x0A` B | 8 B at `0x4823A3` | `51 56 8B F1 83 7E 08 08` | entry of the add-HP function FUN_004823A3; overhealSources |
| `HealTickMax` | `0x9E0BA5` | `0x29` B | 5 B at `0x9E0BBB` | `E8 48 F8 A9 FF` (`call 480408h`) | the heal tick's HP < max test; overhealSources |
| `HealTickAdd` | `0x9E0CCF` | `0x26` B | 5 B at `0x9E0CE9` | `E8 B5 16 AA FF` (`call 4823A3h`) | the heal tick's heal; overhealSources |
| `HealSearchRatio` | `0x9CD982` | `0x18` B | 5 B at `0x9CD984` | `E8 0C 19 A9 FF` (`call 45F295h`) | the heal search's first ratio; overhealSources |
| `HpBarQueue`, `DynamicVbLock`, `DynamicVbFull` | `0x45FB71`, `0x40A6A2`, `0x40A689` | `0x6F`, `0x45`, `0x19` B | — | — | the queue the segment hook calls, and the vertex buffer's size check; `segment` |
| `OverhealInfoProto`, `MaxHitpointsGetter`, `HealthRatio`, `InitialHitpointsTag`, `MaxHitpointsTag` | `0x9AF33B`, `0x480408`, `0x45F295`, `0x5F5CE3`, `0x5F5D39` | `0x19`, `0x26`, `0x48`, 6, 6 B | — | — | where ObjectInfo stores the database proto, the getter the hooks call, the ratio the helper mirrors, and the stores that put InitialHitpoints / MaxHitpoints at `[proto+9Ch]` / `[proto+98h]`; overhealHitpointBars (also `IsA`, `IsATrue`) |
| `GatherTickRate` | `0x4ED02A` | `0x26` B | 8 B at `0x4ED044` (`jmp` + 3 NOP) | `D8 4C 24 30 D9 54 24 14` (`fmul [esp+30h]; fst [esp+14h]`) | the gather tick's rate per second in ST0 (FUN_004ECD87); showGatherRate record hook (continues at `0x4ED04C`) |
| `GatherTickHead`, `GatherTickPushEbp`, `GatherTickPushEbx`, `GatherTickGatherer`, `GatherTickPlayerRate`, `GatherTickPlayerBlock`, `GatherTickAddResource` | `0x4ECD87`, `0x4ECDCC`, `0x4ECE16`, `0x4ECE6D`, `0x4ED130`, `0x4ED1A4`, `0x4ED1E1` | `0x14`, 7, `0x0A`, `0x15`, `0x2A`, `0x14`, `0x12` B | — | — | the tick's frame and ESI, the non-null gatherer and player, and the multiplier, shrine and defeated tests and the add that the record and its reader mirror |
| `StatPanelAfterAutoGather` | `0x4D7834` | `0x0B` B | 7 B at `0x4D7834` (`jmp` + 2 NOP) | `8B 74 24 38 8B 4E 5C` (`mov esi,[esp+38h]; mov ecx,[esi+5Ch]`) | join point after the stat panel's AutoGather row (FUN_004D70ED); showGatherRate panel hook (continues at `0x4D783B`) |
| `StatPanelAgLoop` | `0x69AFE0` | `0x4A` B | 6 B at `0x69AFE0` (`jmp` + 1 NOP) | `8B 0D 34 62 C6 00` (`mov ecx,[0C66234h]`) | start of the AutoGather resource loop; showGatherRate row value hook (continues at `0x69AFE6`, or `0x69B02A` for the new row) |
| `UnitPanelAfterRate` | `0x699456` | 6 B | 6 B at `0x699456` (`jmp` + 1 NOP) | `8B 7C 24 54 8B CF` (`mov edi,[esp+54h]; mov ecx,edi`) | join point after the unit panel's AutoGather rate: the minimized interface's rate gadgets |
| `GatherRateStringRef` | `0x5D2D38` | 8 B | 4 B at `0x5D2D3C` (imm32) | `49 DE 5F 00` (`5FDE49h`) | provider of data ref 68h `currentUnitGatherRateString` in FUN_005CFA7C; showGatherRate |
| `StatPanelAutoGatherGate`, `StatPanelRowWriter`, `StatPanelRowFormat`, `DataRefStub`, `DataRefStringEval`, `CurrentUnitRef`, `ProtoFlag`, `IsAbstractIndex`, `ResourceNameId`, `BStringFromId`, `BStringAssign`, `BStringFree` | `0x4D76FF`, `0x69AF7C`, `0x69B02A`, `0x5FDE49`, `0x44A635`, `0x6F49B1`, `0x45EE02`, `0x44CAC4`, `0x60782A`, `0x58EA52`, `0x443BB8`, `0x4010CA` | `0x135`, `0x64`, `0x15D`, 5, `0x64`, `0x41`, `0x35`, `0x46`, `0x22`, `0x19`, `0x0F`, `0x1F` B | — | — | the gate the panel hook mirrors, the row writer and formatter it reuses, the stub and the string evaluator, the current-unit lookup, and the functions the C++ side calls; showGatherRate (also `IsBuilt`, `IsA`) |
| `ModifyTypeNameTail` | `0x5FE6C7` | `0x1B` B | 6 B at `0x5FE6D7` (`jmp` + 1 NOP) | `F7 D8 1B C0 24 F1` (`neg eax; sbb eax,eax; and al,0F1h`) | tail of the ModifyType parser FUN_005F5645, through the `pop esi; add eax,0Eh; ret` at `0x5FE6DD`; buildingWorkRateAuras name hook |
| `ModifyTypeNameCompare`, `BwrTrainCallNext`, `BwrGetterTail`, `BwrGatherRateRecord`, `BwrGatherRateRule` | `0x443C10`, `0x9EA418`, `0x9BFE38`, `0x4ECFE9`, `0x69FE53` | `0x10`, `0x0C`, `0x10`, `0x14`, `0x1C` B | — | — | the head of the name compare the hook calls, the Train call's continuation up to its first write of EAX, the getter after its first two instructions, and the GatherRate reader whose rule the factor mirrors; buildingWorkRateAuras (also `SnareCollector`, `SnareModifierSum`, `SnareModifierSumEnd`, `SnareModifierSumTactic`, and the getter head `BuildingWorkRateGetter`, which must be stock or liveBuildingWorkRate's `jmp`) |
| `PopCountParse`, `PopCapAddParse` | `0x5FB92E`, `0x5FD719` | `0x1E` B each | 5 B at each (call rel32) | `E8 …` (`call 59A71Dh`) | the `%d` parse of `<PopulationCount>` / `<PopulationCapAddition>`; decimalPopulation |
| `PopCountEffect`, `PopCapAddEffect` | `0x8FA835`, `0x8FA8CF` | `0x1D`, `0x1A` B | 5 B at each (call rel32); 4 B at `0x8FA84A` (imm32, K) | `E8 …` (`call 7F899Bh`); `01 00 00 00` | the int effect calls of the PopulationCount / PopulationCapAddition proto effects, and PopulationCount's floor `mov eax,1`; decimalPopulation |
| `PopCapEffectAdd`, `PopCapEffectRemove` | `0x8D87AB`, `0x8D20AB` | 8 B each | 8 B at each (`jmp` + 3 NOP) | `D9 44 24 34 D9 7C 24 34`; `D9 44 24 20 D9 7C 24 20` (`fld [esp+X]; fnstcw [esp+X]`) | the amount of the player effect PopulationCap and of its removal; decimalPopulation (continues at `0x8D87B3` / `0x8D20B3`) |
| `TeamPopCap` | `0x679694` | `0x26` B | `0x24` B at `0x679694` (`jmp` + NOPs) | `3D C8 00 00 00` (`cmp eax,0C8h`) | getCap's shared-team path; decimalPopulation (continues at `0x6796B8`) |
| `StartPopBonus` | `0xA0D2D1` | 9 B | 8 B at `0xA0D2D1` (`jmp` + 3 NOP) | `03 C3 03 86 20 03 00 00` (`add eax,ebx; add eax,[esi+320h]`) | the game-start cap bonus; decimalPopulation (continues at `0xA0D2D9`) |
| `Xs*` (19: `XsAiGetAvailableEconomyPop` … `XsTrPlayerGetPopulation`) | see `tools/gen_sites.py` | `0x0A` B each | 4 B at each `+1` (the impl imm32 of `push impl`) | the stock impl addresses | the XS registrations of the population syscalls; decimalPopulation |
| `RefPopReg`, `RefPopCapReg`, `RefFuturePopReg`, `RefTotalPopReg` | `0x5D0B47`, `0x5D0BC3`, `0x5D0C3F`, `0x5D0CBB` | `0x2B` B each | 4 B at `+4` (provider imm32) and 4 B at `+20h` (`push 3; pop eax; nop`) | the stock provider; `8B 44 24 1C` (`mov eax,[esp+1Ch]`) | the registration of the data refs pop, popcap, futurepop, totalpop; decimalPopulation |
| `ColorizePopArg`, `ColorizePopFormat` | `0x6F576F`, `0x6F580C` | 8, `0x0C` B | 5 B at each (call rel32) | `E8 …` (`call 6F2A1Dh`, `call 444EFBh`) | colorizePop's argument parse and its print; decimalPopulation |
| `PopFormatHelp`, `PopFormatHelp2`, `PopFormatCost`, `PopFormatCost2`, `PopFormatCost3`, `PopFormatCapLine`, `PopFormatCap` | `0x63F98D`, `0x70FF3A`, `0x63FEC5`, `0x70F58F`, `0x710651`, `0x6F2DB5`, `0x6F2E34` | 8 B each | 5 B at each (call rel32) | `E8 …` (`call 444EFBh`) | the sprintf calls that print a population; decimalPopulation (**WoL redirects `0x710651`**) |
| `RefPopProvider`, `RefPopCapProvider`, `RefFuturePopProvider`, `RefTotalPopProvider`, `IntEffect`, `BStringFormat`, `PopLimit` | `0x6F2274`, `0x458244`, `0x44CE3A`, `0x45809D`, `0x7F899B`, `0x444EFB`, `0x4581F3` | `0x0A` ×4, `0x23`, `0x14`, `0x50` B | — (`PopLimit`: basePop's cap hook, see below) | — | the stock functions the wrappers call, and the cap hook decimalPopulation scales; decimalPopulation |

The full expected bytes of every range are in [`src/generated/sites.h`](../src/generated/sites.h),
generated from the stock exe by [`tools/gen_sites.py`](../tools/gen_sites.py). Two features write
inside ranges that others verify, and the order in [`src/features.h`](../src/features.h) handles
both: noTrainNearEnemyTC writes `WorkRateTrainCall`, and buildingWorkRateAuras the four getter
calls, all of which liveBuildingWorkRate verifies first; buildingWorkRateAuras comes last and
leaves the Train call to noTrainNearEnemyTC when that key owns it
([section 5](#5-integration-rules)). startingTC and civFirstTC share one write, the proto hook at
`0x506B3B`: whichever applies first writes it, and civFirstTC then verifies `FirstTcChunk` instead
of `FirstTcProtoCheck`. No other write falls inside another feature's range (checked with a script
over `tools/gen_sites.py` and the written addresses, 2026-10-29, again after civFirstTC and
`GatherPointValid` were added), so any combination of keys can be enabled together.
decimalPopulation and basePop/extraPop share the cap hook (`PopLimit`): it is written once, by
basePop/extraPop when they are set, otherwise by decimalPopulation, which is applied after them
and only sets the scale the hook reads.

**Status for WoL's DLL (2026-11-04).** `rea/evidence/wol-uhc-c070d138/wol-memdiff.txt` lists the 287 ranges
WoL's DLL had changed in the running game, 30 s after start, with WoL's own `wol.cfg`. Every site of the
new keys was compared with that list:

| Key | Overlap | What to do |
|---|---|---|
| `decimalPopulation` | `PopFormatCost3`: WoL patches `0x710652` (4 B), the `call` at `0x710651`. This is `DoubleShipmentsInspectFixFeature`, which also marks `0x71063C`. | Chain them: call WoL's wrapper from the population text wrapper. Also scale WoL's basePop hook at `0x4581F3` (see the contract). |
| `techRenameEffect` | `TechRenameEffectParse` (`0x6205C9`, 4 B) and `TechRenameRegister` (`0x524CB1`, 4 B): WoL's own `SetTechName` and `RandomTech`. | Don't install a second hook. Change WoL's effect (see the contract). |
| Extra abstract unit types | `AbstractTypesEnd`: WoL patches `0x51BA2B` (4 B). The hook itself, at `0x51BA31`, is not touched. | Start the verified range at `0x51BA2F`, or use WoL's own registration (see the contract). |

No other new key overlaps: none of their sites, and none of the addresses their code writes directly,
is in the list. That covers `transformInventory`, `noTrainNearEnemyTC`, the overheal keys,
`techPrereqRecheck`, `transformUpdatesLOS`, `abilitySlots`, `lifespanAfterConstruction`,
`snareOnlyHitUnit`, `civFirstTC`, `showGatherRate` and the unit panel row. `bufferedFileReads` writes in
the import table, which the list shows as a whole because Windows fills it at load: check that no other
code wraps those six imports.

The list has limits:
- it shows what was patched 30 s after start, so a patch WoL's DLL applies later, in a game, is not in
  it;
- it shows bytes, not meaning. A feature can avoid every patch and still depend on what a WoL patch
  changes.

Three such dependencies are known:
- `buildingWorkRateAuras` and `snareOnlyHitUnit`: WoL's `ModifyActionFix` retypes the tactics-driven
  modifier class (`0x9E36D0`: 2Ch → 46h) and replaces the collector call at `0x49F251`, so inside WoL's DLL
  the walk over modifiers must take types 2Ch **and** 46h (see the contract). This does not show on this
  DLL, which lacks that fix;
- `liveBuildingWorkRate`: WoL owns the effect pipeline that writes `[proto+D0h]`. If it moves
  BuildingWorkRate elsewhere, the getter reads the wrong field;
- `danceBonusCivs`: WoL's `NativeCivs` caves at `0x4904B5`, `0x4ECD6B` and `0x8D47C9` end before these
  ranges, and its `danceCiv` key is interface only. They do not overlap, but read the two side by side.

**The reliable check is at runtime.** Port the `VerifyAll` step ([helpers](#helpers-you-need)) and run it
after WoL's DLL has applied all its own patches. A range that another patch changed then makes the feature
log a mismatch and refuse to apply, instead of corrupting the game.

## 2. What to copy

Each key's page has the code of every file below, the helpers it needs and its sites.

| Files | What they are | Needs |
|---|---|---|
| [`src/unittypes.h`](../src/unittypes.h), [`src/unittypes.cpp`](../src/unittypes.cpp), [`src/hooks/unittype_hooks.asm`](../src/hooks/unittype_hooks.asm) | Registers extra abstract unit type names on every data load. | site `AbstractTypesEnd`, `VerifyAll`, `WriteJmp`, `Log`, `TRACE_ONCE` |
| [`src/features/heal.cpp`](../src/features/heal.cpp), [`src/hooks/heal_hooks.asm`](../src/hooks/heal_hooks.asm) | `healNonIdle`. | unittypes, sites `HealIdleCheck` and `HealAutoSearchIdle`, your cfg reader |
| [`src/features/shipments.cpp`](../src/features/shipments.cpp), [`src/hooks/shipment_hooks.asm`](../src/hooks/shipment_hooks.asm) | `hcShipmentPointFallback`. | sites `GatherFallback*` and `GatherPointValid`; with `FirstTC` also `FirstTcSet`, `PlayerById`, `PlayerByIdNull`, `UnitById`, `UnitByIdNull`; your cfg reader |

| [`src/features/instances.cpp`](../src/features/instances.cpp) (no `.asm`) | `multipleInstances`. | site `SingleInstanceSemaphore`, `VerifyAll`, `WriteDword`, `Log`, your cfg reader |
| [`src/features/workrate.cpp`](../src/features/workrate.cpp), [`src/hooks/workrate_hooks.asm`](../src/hooks/workrate_hooks.asm) | `liveBuildingWorkRate`. | sites `BuildingWorkRateGetter`, `WorkRate*Call`, `TrainFrac`, `MaintainFrac`, `TrainPoints*`, `MaintainPoints*`, your cfg reader |
| [`src/features/techprereq.cpp`](../src/features/techprereq.cpp), [`src/hooks/techprereq_hooks.asm`](../src/hooks/techprereq_hooks.asm) | `techPrereqRecheck`. | sites `TechPrereq*`, `TypeCount*`, `PrereqBaseCtor`, `TechTemplate*`, `TechNameById`, `TechStatusUpdateCall`, `WorldStepCount`; `OnDatabaseLoad` (unittypes); your cfg reader |
| [`src/features/maintain.cpp`](../src/features/maintain.cpp), [`src/hooks/maintain_hooks.asm`](../src/hooks/maintain_hooks.asm) | `maintainWaitForPop`. | unittypes (and `OnDatabaseLoad` for `log`), sites `Maintain*`, your cfg reader |
| [`src/features/transform.cpp`](../src/features/transform.cpp), [`src/hooks/transform_hooks.asm`](../src/hooks/transform_hooks.asm) | `transformUpdatesLOS`. | sites `Transform*` and `Los*`, your cfg reader |
| [`src/features/broadside.cpp`](../src/features/broadside.cpp), [`src/hooks/broadside_hooks.asm`](../src/hooks/broadside_hooks.asm) | `broadsideMuzzleLimit`. | unittypes (only with a UnitType), sites `Broadside*`, your cfg reader (`Config::All`) |
| [`src/features/abilityslots.cpp`](../src/features/abilityslots.cpp), [`src/hooks/abilityslot_hooks.asm`](../src/hooks/abilityslot_hooks.asm) | `abilitySlots`. | sites `Ability*` (not `AbilityByIndex`), `WriteDword`, your cfg reader (`Config::Int`) |
| [`src/features/wonderpanel.cpp`](../src/features/wonderpanel.cpp), [`src/hooks/wonderpanel_hooks.asm`](../src/hooks/wonderpanel_hooks.asm) | `wonderPanelSkipAuras`. | sites `WonderPanel*`, `NthVisibleAbility`, `AbilityByIndex`, `WriteCall`, your cfg reader |
| [`src/features/lifespan.cpp`](../src/features/lifespan.cpp), [`src/hooks/lifespan_hooks.asm`](../src/hooks/lifespan_hooks.asm) | `lifespanAfterConstruction`. | unittypes (and `OnDatabaseLoad` for `log`), sites `Lifespan*`, `Fade*`, `IsBuilt*`, `IsA*`, `WriteBytes`, your cfg reader |
| [`src/features/sockets.cpp`](../src/features/sockets.cpp), [`src/hooks/socket_hooks.asm`](../src/hooks/socket_hooks.asm) | `gaiaSocketsOnly`. | unittypes (only with a UnitType), sites `GaiaSocket*`, your cfg reader |
| [`src/features/hotkeys.cpp`](../src/features/hotkeys.cpp), [`src/hooks/hotkey_hooks.asm`](../src/hooks/hotkey_hooks.asm) | `customHotkeyContexts`. | sites `Hotkey*`, `WriteCall`, your cfg reader |
| [`src/features/snare.cpp`](../src/features/snare.cpp), [`src/hooks/snare_hooks.asm`](../src/hooks/snare_hooks.asm), [`src/modifiers.h`](../src/modifiers.h) | `snareOnlyHitUnit`. `modifiers.h` holds the read-only walk over a unit's modifier actions (`WalkModifiers`, `ModifierList`), shared with `buildingWorkRateAuras`. | sites `Snare*`, your cfg reader |
| [`src/features/techrename.cpp`](../src/features/techrename.cpp), [`src/hooks/techrename_hooks.asm`](../src/hooks/techrename_hooks.asm) | `techRenameEffect`. | sites `TechRename*`, your cfg reader |
| [`src/features/dopples.cpp`](../src/features/dopples.cpp), [`src/hooks/dopple_hooks.asm`](../src/hooks/dopple_hooks.asm) | `noCorpseDopples`. | unittypes, sites `NoCorpseDopple*`, your cfg reader |
| [`src/features/dance.cpp`](../src/features/dance.cpp), [`src/hooks/dance_hooks.asm`](../src/hooks/dance_hooks.asm) | `danceBonusCivs`. | sites `Dance*`, your cfg reader (`Config::All`) |
| [`src/features/startingtc.cpp`](../src/features/startingtc.cpp), [`src/hooks/startingtc_hooks.asm`](../src/hooks/startingtc_hooks.asm) | `startingTC`, and the FirstTC proto hook it shares with `civFirstTC` (`InstallFirstTcProtoHook`, `UhcStartingTcProtoHook`). | unittypes, sites `FirstTcGate`, `FirstTcChunk`, `FirstTcProtoCheck`, `FirstTcSet`, `FirstTcRuleLookup`, `SetLifespanArm`, `UnitAliveSlot`, `IsA`, `WriteBytes`; the data symbol `g_uhcCivFirstTcOn` and the function `UhcCivFirstTcMatches` (defined in `civfirsttc.cpp`; without that feature, define the global as 0 and a stub that returns false); your cfg reader |
| [`src/features/civfirsttc.cpp`](../src/features/civfirsttc.cpp), [`src/hooks/civfirsttc_hooks.asm`](../src/hooks/civfirsttc_hooks.asm) | `civFirstTC`. | the startingTC files above for the shared proto hook; sites `CivTagUnknown`, `CivTagNextNode`, `CivById`, `CivOfPlayer`, `ProtoByName`, `ProtoById`, `ProtoFlag`, `RmPlaceCall`, `RmPlace`, `RmItemFootprint`, `RmNomadStart`, `TownStartQuery`, `TownStartSpawn`, `TownStartColonyLoop`, `FirstTcChunk`, `FirstTcProtoCheck`, `FirstTcSet`, `PlayerById`, `UnitById`, `UnitAliveSlot`; `WriteCall`, `UhcTraceHook` (the wrapper's trace line is written from C++); your cfg reader |
| [`src/features/transforminv.cpp`](../src/features/transforminv.cpp), [`src/hooks/transforminv_hooks.asm`](../src/hooks/transforminv_hooks.asm) | `transformInventory`. | unittypes (only with a UnitType), sites `TransformInvHook`, `TransformProtoLookup`, `TransformKbRemove`, `TransformPushProto`, `TransformKbReAdd`, `Inventory*`, `ResList*`, `IsA`, your cfg reader |
| [`src/features/notrainneartc.cpp`](../src/features/notrainneartc.cpp), [`src/hooks/notrainneartc_hooks.asm`](../src/hooks/notrainneartc_hooks.asm) | `noTrainNearEnemyTC`. | unittypes (and `OnDatabaseLoad` for `log`), sites `WorkRateTrainCall`, `TrainUpdateTrainer`, `TrainRateScale`, `FirstTcRuleLoop`, `FirstTcRuleFilter`, `PlayerById*`, `UnitById*`, `PlayerIsEnemy`, `IsA`, `IsATrue`, `NoCorpseDoppleAliveCall`; the data symbol `g_uhcBwrTrainGetter` (defined in `bwrauras.cpp`; define it yourself as `0x9BFE33` without that feature); your cfg reader (`Config::All`) |
| [`src/features/overheal.cpp`](../src/features/overheal.cpp), [`src/hooks/overheal_hooks.asm`](../src/hooks/overheal_hooks.asm) | `overhealHitpointBars`. | unittypes, sites `Overheal*`, `MaxHitpointsGetter`, `HealthRatio`, `InitialHitpointsTag`, `MaxHitpointsTag`, `IsA`, `IsATrue`, your cfg reader |
| [`src/unitpanel.cpp`](../src/unitpanel.cpp), [`src/unitpanel.h`](../src/unitpanel.h), [`src/hooks/unitpanelrow_hooks.asm`](../src/hooks/unitpanelrow_hooks.asm) | The row of the minimized interface, shared by `showGatherRate` and `overhealHitpointBars stat`; the code is in [section 4](#unit-panel-row-the-minimized-interface). | |
| [`src/features/gatherrate.cpp`](../src/features/gatherrate.cpp), [`src/hooks/gatherrate_hooks.asm`](../src/hooks/gatherrate_hooks.asm) | `showGatherRate`. | unittypes (only with a UnitType), sites `GatherTick*`, `StatPanel*`, `GatherRateStringRef`, `DataRef*`, `CurrentUnitRef`, `ProtoFlag`, `IsAbstractIndex`, `ResourceNameId`, `BString*`, `IsBuilt`, `IsA`, `WriteDword`, your cfg reader |
| [`src/features/decimalpop.cpp`](../src/features/decimalpop.cpp), [`src/hooks/decimalpop_hooks.asm`](../src/hooks/decimalpop_hooks.asm), and the cap hook in [`src/features/limits.cpp`](../src/features/limits.cpp) / [`src/hooks/limit_hooks.asm`](../src/hooks/limit_hooks.asm) | `decimalPopulation`. | sites `PopCountParse`, `PopCapAddParse`, `PopCountEffect`, `PopCapAddEffect`, `IntEffect`, `PopCapEffect*`, `TeamPopCap`, `StartPopBonus`, `Xs*`, `Ref*`, `ColorizePop*`, `BStringFormat`, `PopFormat*`, `PopLimit`; `WriteCall`, `WriteDword`, `WriteBytes`, `UhcTraceHook`; your cfg reader |
| [`src/features/bwrauras.cpp`](../src/features/bwrauras.cpp), [`src/hooks/bwraura_hooks.asm`](../src/hooks/bwraura_hooks.asm), [`src/modifiers.h`](../src/modifiers.h) | `buildingWorkRateAuras`. | sites `ModifyTypeName*`, `Bwr*`, `WorkRateResearchCall`, `WorkRateCommandResearchCall`, `WorkRateMaintainCall`, `SnareCollector`, `SnareModifierSum*`, `BuildingWorkRateGetter`; liveBuildingWorkRate's `UhcBwrGetterHook` symbol for the getter-head check (or drop that check); `WriteCall`, `Matches`; your cfg reader |

### Helpers you need

Every feature uses a few small helpers, all in the [helpers page](porting-code/helpers.md). They depend on
nothing else, so you can copy them as they are. Or keep WoL's own, as the table says. The functions in the
right column come from reading the binary: the names may differ in the source, and this mapping was not
compiled.

| This project | What it does | In WoL's DLL |
|---|---|---|
| `Site`, `sites.h` | Name, address and expected stock bytes of each range. | Nothing like it: copy the table, or the entries of the features you port. |
| `VerifyAll` | Compares live memory with the expected bytes, logs a mismatch and refuses. | Nothing like it was seen. **Keep it,** and call it before every write. |
| `Matches` | Checks one site without logging. | The same. |
| `WriteJmp` | Writes `jmp rel32`, and NOPs up to the length. | `remod::trackable_memory_patch` writes bytes: `VirtualProtect`, then `memcpy`. Build the 5 bytes, `E9` and `target - (va + 5)`, and the NOPs. |
| `WriteCall` | Writes a 5-byte `call rel32`. | The same, with `E8`. |
| `WriteDword`, `WriteBytes` | Write a constant. | `BasicMemoryPatch<int>` / `<char>`. |
| `Log`, `UhcTraceHook` | Printf-style log, and the `hook reached` line. | spdlog. `Log` takes wide strings, so point it at your logger. |
| `TRACE_ONCE` (`common.inc`) | The `hook reached` line of each hook. | Optional: delete those lines if you don't want them. |
| `Config::First`, `All`, `Int` | The key's first line, every line, or an integer. | `IUHCConfig`. `broadsideMuzzleLimit`, `noTrainNearEnemyTC`, `danceBonusCivs` and the dodge sound keys read every line; `abilitySlots` an integer. |
| `Apply…` returning `Outcome` | One function per key. | `BaseFeature`: put the body in the feature's install method. |
| `RequestAbstractUnitType`, `OnDatabaseLoad` | Registers a type, and calls a feature on every data load. | [See below](#extra-abstract-unit-types). |
| `AddWorldTick`, `AddActionTagHandler`, `FloatingText`, `AddUnitPanelRow` | The hooks several features share. | Nothing like them. Copy them once: never add a second `jmp` at their sites. |

A `trackable_memory_patch` restores its bytes when it is destroyed, so keep the patch objects alive for the
life of the game.

## 3. Building the hooks in WoL's DLL

- **x86 only.** The game is a 32-bit process.
- **MASM.** The hooks are `.asm` files for `ml.exe`, with `.model flat, c`. The C++ side declares
  every shared symbol `extern "C"`:
  - the hook procedures, such as `UhcHealNonIdleHook`;
  - the globals, such as `g_uhcHealNonIdleType`;
  - the `__stdcall` callbacks, such as `UhcRegisterAbstractUnitTypes`;
  - for `damageOverTime`, the two `__fastcall` wrappers, which the hooks reach through the
    pointer variables `g_uhcDotTakeDamage` and `g_uhcWorldUpdate` (the shared world update
    wrapper of `worldtick.cpp`), so MASM never needs their decorated names. The trampolines
    `UhcDotTakeDamageStock` and `UhcWorldUpdateStock` go the
    other way: C++ casts their addresses to function pointers. `customHotkeyContexts` reaches its
    two `__fastcall` wrappers the same way (`g_uhcHotkeyFindContext`,
    `g_uhcHotkeyDeactivateAll`);
  - for `techRenameEffect`, no MASM is involved in the effect's methods: they are `__fastcall`
    C++ functions in a vtable the DLL fills;
  - one data symbol links two features: `g_uhcBwrTrainGetter`, defined in `bwrauras.cpp` and
    called by `notrainneartc_hooks.asm` (`call g_uhcBwrTrainGetter`, an indirect call through the
    variable);
  - startingTC and civFirstTC are linked both ways: `startingtc_hooks.asm` reads
    `g_uhcCivFirstTcOn` and calls `UhcCivFirstTcMatches` (stdcall), both defined in
    `civfirsttc.cpp`, and `civfirsttc.cpp` calls `InstallFirstTcProtoHook` and
    `FirstTcProtoHookInstalled` from `startingtc.cpp`;
  - civFirstTC's map placement wrapper `UhcRmPlaceObjectDef` is a `__fastcall` C++ function that
    `WriteCall` targets directly; no MASM is involved.
- **Build setup:** WoL's DLL is built with MSVC 14.16 (VS 2017 15.9):
  - a Visual Studio project: enable **Build Dependencies → Build Customizations → masm**, then add the
    `.asm` files;
  - CMake: `project(... LANGUAGES CXX ASM_MASM)`, as in this repository's `CMakeLists.txt`.
  - With `/SAFESEH` (the x86 default), pass `/safeseh` to `ml.exe` too.
- **Object names.** With CMake, don't give a `.asm` file the same base name as a `.cpp`: the object goes in
  a subfolder that `ml.exe` doesn't create, and the build fails with A1000.
- **Inline assembly instead of MASM** also works (`__declspec(naked)` functions; MSVC x86 only).
  Keep two things:
  - continuations and engine calls go through absolute addresses stored in data
    (`jmp dword ptr [label]`, `call dword ptr [label]`);
  - each hook re-executes the stolen instructions exactly as the `.asm` comments say.
- **A relocatable DLL is fine:** WoL's uses DYNAMIC_BASE. The exe has no ASLR, so its addresses are fixed,
  and the DLL's own symbols are relocated by the loader.

## 4. Each feature's contract

What each hook expects and must preserve. The `.asm` files repeat this in their comments; the reasoning is
in [how-it-works.md](how-it-works.md#4-the-features). Each section starts with a link to its code.

### Extra abstract unit types

Code: [helpers](porting-code/helpers.md#extra-abstract-unit-types).

- **Why:** the exe registers a fixed list of abstract unit types, compiled into it. Any other `<UnitType>`
  in `protoy.xml` is dropped silently. `healNonIdle` needs its marker
  (`AbstractHealNonIdle` by default) to exist as a type, and so does every other key that takes a
  `<UnitType>` when it is given a new name.
- **API:** `RequestAbstractUnitType(name, &id)`. The first call installs the hook at `0x51BA31`.
  Call it from `UHCMain`, before the game loads its data.
- **The hook** runs at the end of FUN_0051A5DC, on every data load, with EDI = database:
  - for each requested name it looks the name up (`0x58E685` hash bucket, `0x40295B` find);
  - if the name is missing, it adds it with `0x5E3549(table, name, &id)`, where
    `table = database+190h` and `id = [database+194h]`. IDs must be dense;
  - it writes the ID to the caller's variable on every load;
  - it then re-executes `pop edi; pop esi; mov al,1; pop ebx` and jumps to `0x51BA36`.
- **In WoL's DLL:** it reads `data\uhc\customabstracttypes.xml` always, through a patch at `0x51BA2B`, just
  before this hook. So:
  - the hook can stay: its `jmp` at `0x51BA31` does not touch WoL's patch, and it runs after it. Start the
    `AbstractTypesEnd` range at `0x51BA2F`, or `VerifyAll` refuses;
  - or use WoL's registration, and skip this one. Then add each marker name to that file. Two conditions:
  - the name must be registered before the protos load, so the proto loader sets its bit;
  - its ID must reach the feature's variable (`g_uhcHealNonIdleType`, `g_uhcLifespanType`, …) on
    every data load.

### healNonIdle

Code: [healing](porting-code/healing.md#healnonidle).

- **Global:** `g_uhcHealNonIdleType`, the marker's unit type ID. It may also hold a proto ID.
  While it is -1, both hooks run the stock code.
- **Is-a test:** `0x44D7FA`, `bool thiscall(proto, typeId)`. The healer's proto is
  `[unit+5Ch]`. The result is in AL only.
- **Heal tick hook** at `0x9E0C79`, in FUN_009E0B53:
  - entry state: EDI = target, ESI = heal action, healer at `[esi+10h]`. ECX is free, since the
    stolen `mov ecx,[edi+58h]` overwrites it;
  - marked healer: jump to `0x9E0C9F`, the heal path;
  - any other healer: re-execute `mov ecx,[edi+58h]; test ecx,ecx`. Jump to `0x9E0C9F` if ECX is
    zero, else to `0x9E0C80`, the stock busy tests.
- **Automatic search hook** at `0x9CD9C7`, in FUN_009CD865. It replaces `call 44F1A7h`:
  - entry state: ECX = the candidate's action manager, ESI = candidate, healer at `[ebp+4]`;
  - marked healer: AL = 1;
  - any other healer: AL from the stock call, with ECX unchanged;
  - both continue at `0x9CD9CC` (`test al,al`).
  - **Both hooks are needed.** With the tick hook alone nothing changes: the search never starts a
    heal on a busy unit, so the tick hook is never reached.

### smartHealTargets

Code: [healing](porting-code/healing.md#smarthealtargets).

- **Globals:** `g_uhcSmartHealTypes[8]` (type or proto IDs, -1 until the data loads),
  `g_uhcSmartHealTypeCount`; the search state (healer, best and first candidate, count) is private
  to `smartheal.cpp`.
- **Range hook** at `0x9CDA36` (5 B, `call 7FCF2Dh`): ECX = healer, `[esp]` = candidate,
  `[esp+4]` = range; ESI = candidate, EBP = owner (healer at `[ebp+4]`). Call 0x7FCF2D (thiscall,
  `ret 8`); if AL: `UhcSmartHealConsider(healer, candidate)` with every register kept; then jump
  to `0x9CDA3F` (never to the accept path).
- **Pick hook** at `0x9CDA58` (5 B, `pop esi / pop ebx / pop edi / xor al,al`): `UhcSmartHealPick
  (healer)`; a unit: ESI = it, jump to `0x9CDA62`; none: re-execute the four instructions, jump to
  `0x9CDA5D`.
- **Score** (smallest wins, compared in this order): index of the first listed type the unit's
  proto is of (0x44D7FA; none: the type count), the stock ratio 0x45F295, (Δx² + Δz²) between
  `[unit+14h]`/`[unit+1Ch]` and the healer's, the unit ID `[unit+10h]`. Never a pointer.
- **Coexists** with `healNonIdle` (0x9CD9C7, same loop, other site).

### dodgeAnyUnit, dodgeSoundSet and criticalSoundSet

Code: [combat](porting-code/combat.md#dodgeanyunit-dodgesoundset-and-criticalsoundset).

- **Global:** `g_uhcDodgeType`, the marker's unit type ID (or a proto ID). While it is -1 the
  proto hook runs the stock code.
- **Proto hook** at `0x49ACE5`, in FUN_0049ACAA (`bool thiscall(unit)`, the dodge test):
  - entry state: ESI = the unit hit, ECX = database, EBX = its player, EDI = `[world+7Ch]`;
  - marked unit (`0x44D7FA([esi+5Ch], type)`): restore ECX and jump to `0x6A249C`, the stock dodge
    path (tech `ypDodge`, 15 % roll, floating text, sound);
  - any other unit: re-execute `mov eax,[esi+5Ch]; mov eax,[eax+4]` and jump to `0x49ACEB`, the
    stock compares with the three `ypMonkJapanese` IDs. ECX must still hold the database.
- **Log wrapper** (only with `log`): the `call 49ACAAh` at `0x49B023` is redirected to a function
  that calls `0x49ACAA` with the same ECX, logs the unit when AL = 1 and returns AL. The caller
  continues at `0x49B028` (`test al,al`).
- **Sound hooks** replace a `push imm32` of a sound set name and push another name instead:
  - `0x6A2628`, ESI = the unit that dodged; continue at `0x6A262D`;
  - `0x6A2A9A`, EBX = the attacking unit (non-null there); continue at `0x6A2A9F`;
  - preserve ECX (the game object, used by the call `0x4AA24C` that follows); EAX and EDX are
    free. The pushed pointer must stay valid until the call returns; the rules' strings live as
    long as the DLL.
- **Marker registration:** through the abstract unit types above. The sound rules register
  their type names the same way, which returns the existing ID for a proto or stock type.
- **dodgeChance** uses the same proto hook. At `0x49ACE5`, `[esp]` is the caller's EDI (saved by
  `push edi` at `0x49ACDD`), which at the only call, `0x49B023`, is the action's damage info
  `[ebp+24h]`; its byte `+5` is the hit's damage type (`Hand` 0, `Ranged` 1 in stock, by name in
  `[db+44h]`, count `[db+48h]`, name at `[entry+4]`). The hook saves ECX, calls the decision and
  leaves:
  - no rule matches: as above (the marker's path or the stock compares);
  - a rule matches: its tech must be active (`0x94AF27([world+7Ch], [[esi+44h]], tech)`), then
    `0x407CE7(0C66588h, 2, 999)` < percent × 10; dodged → `0x6A24FC` (ESI, EBX and the frame as at
    the hook; EDI is reloaded there), hit → `0x49AD0F`.
  - Resolve tech names (`0x600BE1`) and damage type names after each data load, never per hit by
    name, and draw only for chances strictly between 0 and 100 %, so every machine draws the same.

### hcShipmentPointFallback

Code: [buildings](porting-code/buildings.md#hcshipmentpointfallback).

- **Globals:** `g_uhcGatherFallbackTypes[64]` (proto IDs; -1 = skip, -2 = `FirstTC`) and
  `g_uhcGatherFallbackCount`.
- **Name resolution:** on the first call of the hook, through `0x5A2346`
  (`thiscall(database, name)` → proto ID), with database = `[[C66234h]+140h]`. `FirstTC` (any
  case) becomes -2 before any lookup, also when the database is null. This happens once per
  process, so every game in a run must use the same data.
- **The hook** at `0x669E2E` sits on the "nothing found" exit of FUN_004C6B9E, after the stock
  search of its ten fixed types (TownCenter at `0x4C6BF1`, then nine in the cold chunk
  `0x669804..0x669E2C`).
  - Entry state: ESI = the unit query object, `[esp+10h]` = home city, `[esp+18h]` = store
    flag. EBX, EBP and EDI are free, because the epilogue pops them.
  - An entry of -2 is tested before -1 and before any query: `push [esp+10h]` (the home city),
    `call UhcGatherFirstTcUnit`; a non-null result goes to EDI and the hook jumps to `0x4C6CB2`;
    null goes to the next entry.
  - For each configured proto it repeats the stock block at `0x6698B4..0x669963`:
    - the same query calls (`0x453618`, `0x45356D`, `0x4532B4`, `0x453484`, `0x453A36`);
    - the same unit lookup in the world;
    - the same three checks: `vtbl+A4h`, `0x44DDB4`, `0x4802C6 != 1`.
  - Found: EDI = the unit, then jump to `0x4C6CB2`. That stock path stores the unit's ID in
    `[hc+18Ch]` when the store flag is 1, and returns the unit.
  - Nothing found: re-execute `pop ebp; pop edi; pop esi; xor eax,eax` and jump to `0x669E33`.
- **`const char* __stdcall UhcGatherFirstTcUnit(const char* hc)`** (C++, changes EAX, ECX and
  EDX only):
  - world = `[[C66234h]+13Ch]`; null world or null `[hc+8]` → null;
  - player ID = `[[hc+8]]`; player = `0x44CB21(world, id)`; null → null;
  - FirstTC = `[player+4F0h]`; < 0 → null; unit = `0x44CC6D(world, FirstTC)`; null → null;
  - owner `[unit+44h]` null or `[[unit+44h]]` != player ID → null (a converted FirstTC);
  - `0x85302C(hc, unit)` false → null; else the unit.
  - It writes no game state: the store = 0 callers (the command panel) may call it every frame.
    Its log line is written only when the chosen unit changes for that player (a log-only array
    of 32 IDs, reset when the world pointer changes).
- **Dependency:** `FirstTC` finds something new only when a non-`TownCenter` unit can be FirstTC
  (`startingTC` or `civFirstTC`); without either line in the cfg the DLL logs a warning and still
  applies the key.

### damageOverTime

Code: [combat](porting-code/combat.md#damageovertime).

- **State, all in `damageovertime.cpp`:**
  - the attachments read from the data, keyed by (attacker proto ID, action name index): X's
    name, then its proto ID, the stack limit (1..100, default 1), the snare factor (none by
    default) and the tick colour (none by default);
  - the running poisons, keyed by (unit ID, attachment proto ID, attacker player): attacker unit
    ID, next tick, end, the stacks (end times in expiry order) and the last hit's options;
  - the "Attaching" name index.

  The poisons live in a `std::map`, so every machine walks them in the same order.
- **Tag hook** at `0x5FA11E`, in FUN_005F98A0, over `test eax,eax; je 5FD4EDh`, shared with
  spreadAnyAccuracy (`actiontags.cpp`, written once by `AddActionTagHandler`):
  - re-execute the test: on EAX = 0 (the `ModifyExclusive` compare matched), jump to `0x5FD4ED`;
  - otherwise, only when `[esp+C0h]` is `0x5FA213` (a `protoy` `<ProtoAction>`) or `0x5FA623` (a
    `.tactics` `<action>`), call `UhcActionTag(tagName = ESI, node = EDI, proto = [esp+C4h],
    action = [esp+C8h], returnAddress = [esp+C0h])` inside `pushad`/`popad`, which calls each
    handler with the tag name, the child's text (the UTF-16 string at `[node+14h]`), the proto,
    the action and the source;
  - then jump to `0x5FA126`, the next child. damageOverTime's handler takes only `<ProtoAction>`
    tags: `AttachProtoUnit`, `AttachMaxStacks`, `AttachSnare` and `AttachTickText`
    (case-insensitive).
- **TakeDamage hook** at `0x49B3D9`, a `jmp` to the wrapper `UhcDotTakeDamage`:
  - `float __fastcall(unit, unused, 13 stock arguments)`, so it pops 34h bytes and returns in
    st0, exactly like the stock thiscall function;
  - it calls the stock function through `UhcDotTakeDamageStock` (`sub esp,8Ch; jmp 49B3DFh`);
  - when damage was dealt, it adds a stack to the poison (dropping expired stacks, then the
    oldest at the limit) and, for a new poison with `AttachSnare`, snares the unit. Projectile and
    area damage reach it with the launcher's proto ID and action, one call per damaged unit.
- **World update hook** at `0x481A57`, a `jmp` to the shared wrapper `UhcWorldUpdate`
  (`worldtick.cpp`, written once by `AddWorldTick`, whichever key comes first):
  - `bool __fastcall(world, unused, int, int deltaMs)`, `ret 8`, result in AL;
  - it calls the stock update through `UhcWorldUpdateStock` (`sub esp,0Ch; push ebx;
    push ebp; jmp 481A5Ch`), then each registered tick in kFeatures order; damageOverTime's
    applies the due ticks when `world == [[C66234h]+13Ch]`;
  - each tick calls the **stock** TakeDamage (the trampoline, not the wrapper) with multiplier =
    the stacks alive at the tick's time (TakeDamage scales the computed damage by it) and p8..p13
    = `0, 0, 1, 1, -2, 1`, but with p11 = 0 when the attacking unit is gone (its ID no longer
    gives a unit; a dead unit's body keeps it). With p11 = 1, TakeDamage's army code (0x6A3253)
    reads the attacking unit with no null check, so a tick on an AI army unit would crash;
  - after a tick that is not the last, `AttachSnare F` calls
    `0x4DD22D(unit, 0, F, -1f, -1f, 0, 2, ROF + 250, -1, -1, 1)` when `vtbl+90h` says the unit can
    move; `AttachTickText` shows `-N` through `floatingtext.cpp` (interface only, off with
    `noticktext`);
  - another game drops every poison: a jump of the world's step count `[world+F8h]` (normally +1
    per update), game time going back, another world pointer, or a new data load.
- **Engine calls:** `0x5A2346` (proto ID by name), `0x45311B` (a player's copy of a proto), unit
  `vtbl+A4h` (alive), `vtbl+90h` (can move), `0x4DD22D` (the snare), the floating text of
  `floatingtext.cpp`; for the log only, `vtbl+34h` (speed) and the army flag 37h. The layouts read (unit, world, player, action set, action, the
  action-name table) are listed in [engine-symbols.md](engine-symbols.md), "Damage and poison".
- **If WoL's DLL already hooks TakeDamage or the world update,** call this feature's logic from
  your own wrapper instead of installing a second `jmp` at the same entry: `VerifyAll` would
  refuse the second patch anyway.

### spreadAnyAccuracy

Code: [combat](porting-code/combat.md#spreadanyaccuracy).

- **State, all in `spread.cpp`:** the values read from the data, a `std::map` keyed by (proto ID
  `[proto+4]`, action name index `[action+4]`) of `SpreadFactor` and `MaxSpread` (default 0.25 and
  5.0), cleared by `OnDatabaseLoad`; the marker type ID; two globals `g_uhcSpreadFactor` /
  `g_uhcSpreadMax` that hold the stock values except during the miss hook's call.
- **Tag handler** on the shared tag hook (see damageOverTime): `MaxSpread` (0..100) and
  `SpreadFactor` (0..10), case-insensitive, from both sources; an action whose name index is still
  -1 (a tag before `<name>` in a tactics file) or a value that does not parse is logged and ignored.
- **Hit hook** at `0x499890` (9 B: `cmp ebx,2; je 4CEF7Bh`). EBX = the roll's result (1 also for
  `PerfectAccuracy`), ESI = the projectile, EDI = the tactics action, `[esp+0E8h]` = the shooting
  unit. EBX = 2 jumps to the miss hook. Otherwise `bool __stdcall UhcSpreadForceMiss(shooter,
  action)` (inside `pushad`/`popad`) tests the shooter's proto `[unit+5Ch]` for the marker
  (0x44D7FA); true sets EBX = 2 and jumps to the miss hook, false jumps to `0x499899`.
- **Miss hook** at `0x4CEF7B` (7 B over the stub). Both entries (`0x499893`, now the hit hook, and
  `0x6A4BCA`, a failed lead) have the launch's frame and EBX = 2. It calls
  `UhcSpreadSelect(unitAction = [esp+18h], shooter = [esp+0E8h])`, which puts the action's values in
  the globals; then `lea eax,[esp+28h]; push eax; mov ecx,esi; call 4CEF8Ch` as the stub did; then
  `int __stdcall UhcSpreadDone()`, which restores the globals and returns the result to store: 2,
  or 3 (a ground shot, the `TargetGround` mode, which deals the attack where it lands) for a
  marked shooter. The hook writes it into `popad`'s EBX slot and jumps to `0x499899`
  (`mov [esi+20h],ebx`).
- **Radius hook** at `0x4CF00B` (27 B) in FUN_004CEF8C, ST0 = d: `fmul [g_uhcSpreadFactor]; fst
  [esp+0Ch]; fcomp [g_uhcSpreadMax]; fnstsw ax`; if r > MaxSpread, `[esp+0Ch] = MaxSpread`; jump to
  `0x4CF026` (the stock `r > 1e-6` test and the two draws). The x87 stack is empty on leaving.
- **Engine calls:** 0x44D7FA (is-a) and the stock FUN_004CEF8C; reads the action-name table for the
  log.
- **If WoL's DLL already reads action tags at 0x5FA11E,** add these two tags to your handler instead
  of a second hook; if it changes the launch at 0x499890 or the miss offset, merge the logic there.

### bufferedFileReads

Code: [game-files](porting-code/game-files.md#bufferedfilereads).

- **IAT hooks:** six KERNEL32 slots of the exe: `CreateFileA` `0xB842A4`, `CreateFileW` `0xB84304`, `ReadFile`
  `0xB8424C`, `SetFilePointer` `0xB84244`, `CloseHandle` `0xB84330`, `DuplicateHandle` `0xB843A0`. Each slot
  must still hold the address `GetProcAddress` gives for that function, or nothing is written. If WoL's DLL
  wraps one of these imports, chain the two.
- **What is buffered:** a handle opened for reading only, without `FILE_FLAG_OVERLAPPED` or
  `FILE_FLAG_NO_BUFFERING`, on a disk file. Every other handle passes through.
- **Must preserve:** the game receives the same bytes, and the position it sees is the one it asked for. The
  `verify` argument checks this against the file.
- **Why it can differ between players:** it changes how the bytes are fetched, not which bytes.
- **The design:** [how-it-works.md](how-it-works.md#bufferedfilereads).

### multipleInstances

A tool for testing: WoL's players don't need it, so it has no code page. Its code is `src/features/instances.cpp`.

- **IAT hook** on `CreateSemaphoreW`, slot `0xB843F0`. The slot must hold the `GetProcAddress`
  address when the feature applies; if WoL's DLL also wraps that import, chain the two.
- **Only the call with return address `0x55A18B`** (the single-instance check, stock name
  `Global\Age3`) gets `-` and an FNV-1a hash of the exe's lowercase folder appended. Every other
  call passes through unchanged.
- **`background`** installs a `WH_CBT` hook for the calling thread. It must run on the game's main
  thread, before the game creates its first window: the loader's `UHCMain` does. A DLL that
  initializes elsewhere must target the main thread's ID instead. The hook creates top-level windows
  with `hwndInsertAfter = HWND_BOTTOM`, wraps their window procedure to keep that z-order, and
  refuses every `HCBT_ACTIVATE`.

### liveBuildingWorkRate

Code: [buildings](porting-code/buildings.md#livebuildingworkrate).

- **Global:** `g_uhcBwrLog`, 1 with `log`. Without `log` the hook calls nothing.
- **Getter hook** at `0x9BFE33`, the entry of `float thiscall(unit)`:
  - entry state: ECX = the unit, `[esp]` = the return address into one of the four callers, x87
    stack empty;
  - with `log`, call the logger inside `pushad` / `popad` (it compares `[[ecx+68h]+28h]` with
    `[[ecx+5Ch]+0D0h]` as dwords and changes no game state);
  - re-execute `mov eax,[ecx+68h]; test eax,eax` (for EFLAGS) and jump to `0x9BFE3E`
    (`mov eax,[ecx+5Ch]; fld dword ptr [eax+0D0h]; ret`);
  - on return: ST0 = the proto's rate, EAX = the proto (stock: the building data, when there is
    one), every other register and EFLAGS as in stock.
- **Callers' contract:** each of the four callers writes EAX before reading it (sites
  `WorkRate*Call`). A caller you add that reads EAX after the call gets the proto.
  `buildingWorkRateAuras` and `noTrainNearEnemyTC` later redirect or replace these calls, but their
  hooks still call the getter, so this hook keeps running.
- **Without a hook:** `74 04` → `EB 04` at `0x9BFE38` gives the same result with no log.
- **TrainPoints hooks** at `0x9EA1FA` (Train) and `0x9E27E4` (Maintain), the heads of the two
  fraction functions, `void thiscall(action)`:
  - entry state: ECX = the action, `[esp]` = the return address (0x9EA4B8 / 0x6AB269), x87 stack
    empty; the caller reuses ECX after the call;
  - `pushad`, call the refresh (stdcall, the action), `popad`; re-execute `fld [ecx+64h]; fcomp
    [0C3755Ch]` (Train) or `fld [ecx+6Ch]; fcomp [0C37468h]` (Maintain); jump to `0x9EA203` /
    `0x9E27ED` (`fnstsw ax`);
  - the refresh, Train: skip when the entry count `[a+74h]` ≤ 0; trainer `t = [a+10h]`, player
    `[t+44h]`, proto ID `[[a+70h]]`; `p = 0x45311B(player, id)` (thiscall), skip when null; points
    = `[p+6Ch]`; when `0x44D063(t, 9Eh)` (`YPForceTrainAtBaseTrainPoints`) and the database
    `[[0C66234h]+140h]` gives `b = 0x45316E(db, [p+8])` non-null, points = `[b+6Ch]`; write
    `[a+64h]` when the bits differ;
  - Maintain: proto ID `[a+64h]`, count `[a+68h]` (skip when ≤ 0), points = (float)(count ×
    `[p+6Ch]`) rounded once, or `[b+6Ch]` not multiplied with the flag; write `[a+6Ch]`.
  - Keep the progress (`[a+68h]` / `[a+70h]`) as it is: a unit already past the new points
    finishes on that tick, as research does in stock.
  - `maintainWaitForPop` verifies the Maintain call 0x6AB264 as stock bytes, so hook the callee,
    not the call.

### techPrereqRecheck

Code: [techs](porting-code/techs.md#techprereqrecheck).

- **State, all in `techprereq.cpp`:** N, `full`, `log`; the IDs of the techs with a TypeCount
  prerequisite (ascending), rebuilt on the first check after each data load (`OnDatabaseLoad`);
  the log counters.
- **The hook** at `0x491A18`, in FUN_004919CE (`thiscall(tree, Player*)`, `ret 4`), over
  `cmp byte [edi+10h],0; jne 5096D4h` (10 bytes):
  - entry state: EDI = the player's tree, EBP = the player (non-null); the flags are dead;
  - `pushad`, `UhcTechPrereqMaybeMark(tree = EDI, player = EBP)` (stdcall), `popad`;
  - re-execute `cmp byte [edi+10h],0`; set → `jmp 0x5096D4`, clear → `jmp 0x491A22`.
- **The check** may only set `[tree+10h]` = 1; never write `[tree+11h]`.
  - Skip when the byte is set, when the world or database is null, or when `[player+80h]` (the
    KB) is null.
  - The player's turn: N = 1, or (`[world+F8h]` + `[player]`) % N = 0.
  - For each listed tech ID below `[tree+8]` whose entry `e = [[tree+4]+4·id]` has a definition
    `[e]`, a bit array `[e+4]` and a bit count `[e+8]` > 3:
    `met = 0x5094B4([e]+1Ch, player, [e+8] > 21 && (byte [[e+4]+2] & 20h))`; when `met` differs
    from `byte [[e+4]] & 8`, set the byte and stop.
- **The tech list:** template records `[[db+5D9Ch]+0Ch]`, 24h bytes, count `[[db+5D9Ch]+10h]`;
  keep the IDs whose definition (record `+0`) has a prerequisite with byte `[p+5]` = 0 in
  `[def+1Ch][0..byte def+20h)`.

### maintainWaitForPop

Code: [buildings](porting-code/buildings.md#maintainwaitforpop).

- **Global:** the marker's unit type ID (or a proto ID), set on each data load; while it is -1 the
  predicate answers "not blocked".
- **Hook** at `0x6AB27D`, in the cold chunk of the Maintain update, 6 bytes (`jmp` + NOP):
  - entry state: the cycle is complete; ESI = the action, ECX = ESI (`this` of the spawn call),
    EBX pushed by the chunk, FPU stack empty;
  - call the predicate with every register preserved (`pushad` / `push esi` / `call` /
    `test al,al` / `popad`);
  - not blocked: re-execute `mov edx,[esi+68h]; mov eax,[esi+64h]` and jump to `0x6AB283`;
  - blocked: `mov eax,[esi+6Ch]; mov [esi+70h],eax` and jump to `0x6AB180`.
- **Predicate** (read-only; any failed step answers "not blocked"): owner `[a+10h]` and player
  `[owner+44h]` non-null, `[a+68h]` ≥ 1; `0x44D7FA([owner+5Ch], marker)`; the proto ID `[a+64h]`,
  replaced by `[db+609Ch]` when byte `[player+50Ah]` ≠ 0 and the ID is `[db+5E1Ch]`, `[db+6054h]`,
  `[db+6050h]` or `[db+6058h]`; `proto = 0x45311B(player, id)` non-null; not `0x44CAC4(proto, 5Dh)`;
  `pop = [proto+D8h]` > 0; not `0x45EE02(proto, A3h)`; `used = [player+78h] + 0x45805C(player)`,
  `cap = 0x4581A1(player)` (32-bit wrap); blocked = `(int)(cap − used) <= 0` with
  `0x45EE02(proto, 9Fh)`, else `(int)cap < (int)(used + pop)`.
- **Requirement:** nothing else may patch the spawn's population test (the verify-only ranges),
  or the predicate and the engine disagree. A DLL that changes that test must change the
  predicate the same way.

### transformUpdatesLOS

Code: [techs](porting-code/techs.md#transformupdateslos).

- **Hook** at `0x9C763F`, replacing `call 4981F3h` (setProto, `thiscall(unit, Proto*)`, `ret 4`):
  - entry state: ESI = ECX = the unit, `[esp]` = the new proto, `[unit+5Ch]` = the old proto. The
    unit is off the visibility map (`0x9C7570`) and goes back on it at `0x9C7730`;
  - when the dword `[[unit+B4h]+90h]` equals the old proto's `[proto+48h]`, copy the new proto's
    `[proto+48h]` there; skip if either proto or `[unit+B4h]` is null. Compare and copy as integers;
  - re-execute `call 4981F3h` with the argument still at `[esp]`, then jump to `0x9C7644`;
  - preserve ESI, EDI, EBX, EBP and ESP; EAX, ECX, EDX and the flags are what setProto leaves.
- **Keep the write before setProto:** the old proto is only readable there, and the per-player
  LOS cache (`0x9C768D`) and the visibility add (`0x9C7730`) must both see the new value.

### broadsideMuzzleLimit

Code: [combat](porting-code/combat.md#broadsidemuzzlelimit).

- **Globals:** `g_uhcBroadsideLimit` (N), `g_uhcBroadsideAll` (1 = every ship),
  `g_uhcBroadsideType` (the marker's ID; while it is -1 and `All` is 0, the hook keeps 6),
  `g_uhcBroadsideAction` (the last action given N, read only by the log hook).
- **Limit hook** at `0x5033D5`, in FUN_0050339A:
  - entry state: EDI = the action, its owner `[edi+10h]` and that unit's proto were tested
    non-null, and the proto is a `Ship`. ECX = `[edi+4]` (the proto action), ZF = its
    `test ecx,ecx`. The caller's ESI is already pushed;
  - set ESI = 6, or N for a matched owner (`0x44D7FA([[edi+10h]+5Ch], type)`, or always with
    `All`);
  - preserve ECX, re-create ZF with `test ecx,ecx`, keep EBX/EBP/EDI/ESP, and jump to `0x5033DA`.
    EAX and EDX are free. Leave the `SingleUsePlayer` code after it alone.
- **Log hook** (only with `log`) at `0x5034E2`: EAX = MuzzleL count, ESI = final limit, EDI = the
  action, `[edi+80h]` = MuzzleR slots. After logging, re-execute `cmp eax,esi; mov [esp+1Ch],eax`
  with ESP as on entry, and jump to `0x5034E8` (`jg`, which reads that compare).

### abilitySlots

Code: [interface](porting-code/interface.md#abilityslots).

- **The patch:** one dword, N − 1 at `0x695BD3` (the imm32 of `mov edi,5`). Keep N − 1 ≥ 1 (the
  loop is a do-while: 0 would run about 4 billion times), N ≥ 6 so stock abilities are not hidden,
  and N ≤ 36 (the grid).
- **Log hook** (optional) at `0x696C70`, on GetNth's true path in FUN_0046188E:
  - entry state: the stock frame; EDI = the unit; `[esp+34h]` = n + 1; GetNth's outputs at
    `[esp+0Ch]` (enabled byte), `[esp+2Ch]` (record), `[esp+78h]` (power); ECX = `[esp+58h]`;
  - log only when n ≥ 6, inside `pushad` / `popad`, **before** the stock call (it returns a float
    in ST0);
  - re-execute `call 45EE37h` with ECX unchanged and jump to `0x696C75`. EAX, EDX and the flags are
    dead at the hook.

### wonderPanelSkipAuras

Code: [interface](porting-code/interface.md#wonderpanelskipauras).

- **Global:** `g_uhcWonderPanelLog`, nonzero with `log`.
- **Call redirect** at `0x69EE5D`: the hook must be a drop-in for `0x6EE5CC`,
  `bool __thiscall(mgr, n, player, unit, cost*, icon*, rollover*, usable*, recIdx*, powerId*)`,
  `ret 24h`. ECX = the ability manager (never 0 there); the caller passes n = 0.
  - For n = 0..7, call `0x6EE5CC` with the same ECX, that n and the caller's eight other
    arguments. On AL = 1, take `0x44E702(mgr, *recIdx)`; when it is non-null and `[rec+1Dh] & 1`
    is clear, return AL = 1.
  - When no n qualifies, return AL = 0.
  - Preserve EBX, ESI, EDI and EBP. The caller continues at `0x69EE62` (`test al,al`) and reads
    nothing else.
- **Log callback** (only with `log`): `UhcWonderPanelLogAbility(unit, n, record, power)`, stdcall,
  for n > 0; it logs once per record.

### lifespanAfterConstruction

Code: [buildings](porting-code/buildings.md#lifespanafterconstruction).

- **Globals:** `g_uhcLifespanType` (the marker's ID or a proto ID; while it is -1 both hooks run
  the stock code), `g_uhcLifespanLog`, and `g_uhcLifespanHeldCount` (log only: logged held units
  not yet running again).
- **Held unit:** state bit 11 of `[unit+4]` clear (when the bit count `[unit+8]` > 11),
  `0x44DDB4(unit)` false, `[unit+5Ch]` non-null and `0x44D7FA([unit+5Ch], type)` true. Results
  are in AL only.
- **Tick hook** at `0x483EEC` (10 B), reached only from the `ja` at `0x482C1A`:
  - entry state: ESI = unit, `[esp+0Ch]` = dt; EAX/ECX/EDX free; keep EBX, EDI, EBP;
  - held unit: jump to `0x482C20` (`pop esi; pop ecx; ret 4`);
  - any other unit: re-execute `fld dword ptr [esp+0Ch]; fcomp dword ptr [0B84BE4h]` and jump to
    `0x483EF6`. Push nothing before the `fld`.
- **Fade hook** at `0x482A1A` (6 B), entered with the flags of `cmp bl,1`:
  - entry state: ESI = unit, EAX = `[esi+B4h]`, EBX = commit flag, `[esp+10h]` = t; ECX and EDX
    free; keep EAX for the store, EBX and the stack;
  - commit clear (`jne`): jump to `0x482A26`;
  - held unit with bits 5 and 3 set and bits 4 and 61 clear: `[esp+10h] = [eax+88h]`, jump to
    `0x482A26` (no store);
  - any other unit: `mov ecx,[esp+10h]`, jump to `0x482A20` with EAX intact. Preserve the entry
    flags until the `jne` if you add tracing.
- **Both hooks are needed**, and **never drop the alive test:** dead foundations stay below 100 %,
  and their corpse removal goes through the same fade and lifespan.

### gaiaSocketsOnly

Code: [buildings](porting-code/buildings.md#gaiasocketsonly).

- **Globals:** the mode (every socket, or marker) and the marker's ID; in marker mode, while the ID
  is -1 the rule never applies.
- **Hook** at `0x508CC1`, in PLACE (FUN_0050703D, `ret 2Ch`):
  - entry state, reached only by falling through from `0x508CBB`: ESI = socket unit + 14h,
    EDI = the building's proto, ESP = PLACE's body frame: a1 (player) at `[esp+1C0h]`, a5
    (knowledge) at `[esp+1D0h]`, the found flag at `[esp+37h]`;
  - a5 = 0: re-execute `mov byte [esp+37h],1`;
  - else accept (re-execute the store) when the socket is out of the rule's scope (marker mode and
    not `0x44D7FA([unit+5Ch], id)`), when `[unit+44h]` is null, or when `[[unit+44h]] == 0`;
    refuse (skip the store) otherwise;
  - continue at `0x508CC6` on both paths. EAX, ECX, EDX and the flags are free; keep EBX, ESI,
    EDI, EBP and ESP (the frame offsets are ESP-relative). The x87 stack is empty there.

### customHotkeyContexts

Code: [data](porting-code/data.md#customhotkeycontexts).

- **State:** a list of added contexts `{proto name, context name, ID}` and the manager they belong
  to (`[[[0xC66244]+74h]+34h]` when they were registered). The selection hooks act only while the
  current manager is that one.
- **Find wrapper** (the `call 5C16ABh` at `0x5C1778`, redirected to a stub that jumps to a
  `__fastcall(manager, edx, name, record)` function, `ret 8`): call `0x5C16AB` with the same
  arguments; when it returns 3, the context (a BString: `[name]` is its UTF-16 text) ends in
  `Accel` and `[manager+34h]` < 223, call `0x628FC0(manager, narrowName, 5)`, then `0x5C16AB`
  again, record the context and return the second result. The caller continues at `0x5C177D`;
  EBX/ESI/EDI/EBP must survive.
- **Switch-off wrapper** (the `call 4421F3h` at `0x79F1A5`, same mechanism): the same call, then
  `0xAB397F(manager, id, flag)` for every added ID; return to `0x79F1AA` with ESI intact.
- **Context hook** at `0x79F897` (6 B): ESI = the database proto (name at `[esi+10h]`), EBP = the
  unit. EDI = the added ID of a proto with that name, else `mov edi,[esi+178h]`; jump to
  `0x79F89D`. EAX/ECX/EDX are free.
- **Trainer hook** at `0x64A034` (5 B): ESI = the unit (its proto may be null when entered from
  `0x64A027`). If the proto has an added context jump to `0x64A05A`; else
  `mov byte [esp+13h],1` and jump to `0x64A05C`. EAX/ECX/EDX are free; keep EBX, ESI, EDI, EBP and
  ESP.
- **Ordering:** write the switch-off wrapper first and the trainer hook last, so a failed write
  leaves contexts that are never on, or on and switched off.

### snareOnlyHitUnit

Code: [combat](porting-code/combat.md#snareonlyhitunit).

- **Snare test:** walk the unit's actions `[[unit+58h]+14h]` (`{count +0, data +8}`; children at
  `[+40h]`, depth first, parent first) and take the first action with byte `[+60h]` = 2Ch,
  `[+64h]` = 0, `[+78h]` = 2, and flags 15h and 16h set in the bitset `{[+30h] bytes, [+34h]
  count}`. Read-only; stop at 16 levels and answer "not snared".
- **Pace hook** at `0x4FD3FD` (`jmp`, NOP to `0x4FD417`), in FUN_004FD289:
  - entry state: ESI = group, EDI = member, EBX/EBP = member count/index, FPU stack empty;
    EAX/ECX/EDX and the flags are free;
  - snared member: compute its velocity without the snares (below); if it is lower than the float
    `[esi+7Ch]`, store it there; continue at `0x4FD417`;
  - any other member: re-execute `mov edx,[edi]; mov ecx,edi; mov eax,[edx+34h]; call eax;
    fcomp dword [esi+7Ch]; fnstsw ax; test ah,5`, then `jnp` → `0x4FD53A`, else → `0x4FD417`.
- **Velocity without the snares:** `v = [[unit+5Ch]+80h]`; for each type-2Ch action in walk order
  with `[+64h]` = 0 that is not a snare: op 0 `v = value`, 1 `v = value + v`, 2 `v = value · v`
  (float, rounded each step), other ignored; stop after it if flag 16h is set or its tactics
  action `[+4]` has bit 33. Use v if the record `[[unit+B4h]+C8h]` exists, a modifier matched and
  `v > -1e-6f`, else `[[unit+5Ch]+80h]`; multiply by `m` from `0x44734C(0xC66500, **(int**)0xCEFFA0,
  &m)` with `m = 1.0f` first.
- **Straggler hooks** (6 B each, `mov eax,[reg+4]; or byte [eax],80h`): `0x4FA17D` (ESI = group,
  EBP = member; continue at `0x4FA183`), `0x6AA514` (EBX = group, ESI = member; `0x6AA51A`),
  `0x6AA56A` (EAX = group, ESI = the member's **ID**, looked up as at `0x4F9EB7`; `0x6AA570`).
  Snared member: skip both instructions; otherwise re-execute them.

### techRenameEffect

Code: [data](porting-code/data.md#techrenameeffect).

- **Globals:** `g_uhcTechRenameType`, SetTechName's effect type ID (-1 until the database init
  ran; while it is -1 the factory hook runs the stock code). The DLL vtable (17 slots) is filled
  before the hooks are written.
- **Registration hook** at `0x524CB5`, in FUN_0052277E, over `cmp dword ptr [esi+3504h],0`:
  ESI = database; `pushad`, `UhcTechRenameRegister(esi)`, `popad`; re-execute the `cmp` **last**
  (its flags feed the `jne` at `0x524CC4`) and jump to `0x524CBC`. The registration adds
  `SetTechName` with ID `[db+3360h]` (must be 11h..FFh) through `0x5375AC(db+335Ch, name, &id)`
  unless `0x61FF1B` already finds it.
- **Factory hook** at `0x62146F`, over `push 51Fh`: EAX = the type, `[esp]` = the ESI the factory
  pushed. Our type: `UhcTechRenameCreate()` (EAX = the effect or 0), then `pop esi; ret`, the
  factory's epilogue; any other type: `push 51Fh` and jump to `0x621474`.
- **The effect** (1Ch bytes from `0x401398`) must keep `+9 = 28h` from the ctor `0x620B8F`. Its
  methods are `__fastcall` with a dummy EDX: slot 0 `ret 4`, 1 `ret 4`, 2 and 3 `ret 8`, 4 `ret 4`,
  15 `ret 10h`; 16 keeps the stock no-op.
- **The apply** reads `[player+0]`, calls `0x8D0005(player, tech)`, keeps one 34h-byte copy per
  (player ID, tech ID) that is never freed or moved, refreshes it from `[node]` whenever `[node]`
  is not the copy, writes the IDs that are not -1, then sets `[node+0]`.
- **If WoL's DLL already creates extra effect types** (WoL's `RandomTech` and `SetTechName` use the
  same factory default case), merge this into your factory hook: `VerifyAll` refuses a second
  patch. WoL's own `SetTechName` can be fixed in place by replacing its apply with the
  copy-and-repoint logic.

### noCorpseDopples

Code: [interface](porting-code/interface.md#nocorpsedopples).

- **Globals:** `g_uhcNoCorpseDoppleType` (the marker's ID or a proto ID; while it is -1 the hook
  runs the stock code) and `g_uhcNoCorpseDoppleLog`.
- **Hook** at `0x49534D`, in FUN_0048679A, 8 bytes (`jmp` + 3 NOP):
  - entry state: ESI = the unit, EBX = the index of the player whose view it left, EBP =
    `1 << EBX`, EDI = that player; `[esp+2Ch]` = the new mask, `[esp+54h]` = forced. EAX, ECX, EDX
    and the flags are free;
  - skip when EBX ≠ 0, `[esi+5Ch]` ≠ 0, `0x44D7FA([esi+5Ch], type)` is true and
    `call [[esi]+0A4h]` (ECX = ESI) returns AL = 0: `jmp 486A30h`, with every register except
    EAX/ECX/EDX and the stack as on entry;
  - otherwise: `mov eax,[esp+2Ch]; mov ecx,[esp+54h]; jmp 495355h`.

### danceBonusCivs

Code: [civs](porting-code/civs.md#dancebonuscivs).

- **Helper:** `bool __stdcall UhcDanceCivAllowed(int kind, player*, int civ)`, true if `civ` is
  listed. It resolves the cfg names with `0x58E71F(database, name)` on the first call for each
  database (or civ count `[database+28h]`), and returns false for -1 and while the civ count is 0.
  The answer depends only on the cfg and the data.
- **Four hooks**, each over `cmp eax,[0C6FB50h]` (6 B), with EAX = the player's first civ ID or -1
  and the flags dead:
  - train rate `0x8D47AB` (ECX = player): listed → `0x8D47CF`; else re-execute the compare →
    `0x8D47B1`;
  - XP trickle `0x4E0DFF` (ECX = player): listed → `0x4E0E29`; else → `0x4E0E05`;
  - gather rate `0x4ECD53` (ECX = player): listed → `0x4ECD7D`; else → `0x4ECD59`;
  - regeneration `0x49048B` (EDI = player): listed → `0x679E66`; else → `0x490491`;
  - preserve EAX, ECX, EDX, EDI and ESP on both exits.
- **Coexistence with `nativeCivs`:** upstream's patches #5 (`0x4904B5`), #6 (`0x4ECD6B`) and #8
  (`0x8D47C9`) are later compares of the same gates; leave these four ranges alone in a
  `nativeCivs` port. Such a port should also patch the XP gate's compare at `0x4E0E17`, which
  upstream misses.

### startingTC

Code: [civs](porting-code/civs.md#startingtc).

- **Globals:** `g_uhcStartingTcType` (the marker's ID or a proto ID; while it is -1 both hooks run
  the stock code) and `g_uhcStartingTcLog`.
- **Helpers:**
  - `bool __stdcall UhcStartingTcStale(player*, unit*)`: false when `[player+4F0h]` is the unit's
    ID, when `[[0xC66234]+13Ch]` (the main world) is 0, or when the world's player of ID
    `[player]` (`[world+58h]`, count `[world+5Ch]`) is not this player; else true when
    `[player+4F0h]` is not in the world's unit table (`[world+0Ch]`, count `[world+10h]`, index
    `id & 3FFFFh`, `[unit+10h]` = ID), when `call [[u]+0A4h]` returns 0, or when bit 3 of the
    bitset `[u+4]` is set with a bit count `[u+8]` above 3; else false. It only reads game state.
  - `void __stdcall UhcStartingTcFirst(player*, unit*)`: the log line, only with `log`.
- **Gate hook** at `0x49880A`, 13 bytes (`jmp` + 8 NOP):
  - entry state: ESI = player, EDI = the unit just added, EBX and EBP the function's own; EAX,
    ECX, EDX and the flags are free;
  - `cmp dword ptr [esi+4F0h],0; jl` → `jmp 506B2Ah` (the stock cold chunk, registers unchanged);
  - else if the marker ID ≥ 0, `[edi+5Ch]` ≠ 0, `0x44D7FA([edi+5Ch], type)` and
    `UhcStartingTcStale(esi, edi)` → `jmp 67ABD4h`;
  - else `jmp 498817h`. EBX, EBP, ESI, EDI and ESP as on entry on every path.
- **Proto hook** at `0x506B3B`, 6 bytes (`jmp` + 1 NOP), shared with civFirstTC:
  - entry state: EAX = the unit's proto ID, ECX = database, EDX = proto, EDI = unit, ESI = player;
  - `cmp eax,[ecx+5E08h]`; equal → `jmp 67ABD4h`;
  - else if `g_uhcCivFirstTcOn` ≠ 0: `UhcCivFirstTcMatches(esi, eax, edi)` (stdcall; it changes
    EAX, ECX and EDX); true → `jmp 67ABD4h`;
  - else if the marker ID ≥ 0, `[edi+5Ch]` ≠ 0 and `0x44D7FA([edi+5Ch], type)` → (log) →
    `jmp 67ABD4h`;
  - else `jmp 498817h`. EBX, EBP, ESI, EDI and ESP as on entry.
- **Install both or neither:** the proto hook alone gives FirstTC to marked units but never
  replaces a dead one. This DLL writes the proto hook first and puts its bytes back if the gate
  hook cannot be written.
- **One proto hook for two keys:** `InstallFirstTcProtoHook()` writes the `jmp` once, for
  whichever of startingTC and civFirstTC applies first (`FirstTcProtoHookInstalled()` tells the
  other); write it only once, and verify `FirstTcProtoCheck` only while it is still stock.

### civFirstTC

Code: [civs](porting-code/civs.md#civfirsttc).

- **State** (`civfirsttc.cpp`): the tags by civ ID (the civ object each was read for, its text,
  and the resolved proto with the proto array it was resolved in); `g_uhcCivFirstTcOn`, 1 once the
  key is applied, read by the shared proto hook; the `log` flag and the once-per-game log table.
- **A player's proto** (`CivFirstTcProto`): database `[[C66234h]+140h]`; civ ID as `0x4539D3`
  (`[[player+20h]]` when `[player+24h]` > 0). No tag, an empty text, or `0x405C2E(db, civ ID)` not
  the civ object the tag was read for → -1. Resolve the text with `0x5A2346` whenever `[db+54h]` is
  another array than the one it was resolved in; an unknown name gives -1 and one log line.
- **Tag hook** at `0x52BB07`, 8 bytes (`jmp` + 3 NOP), in the civs.xml parser FUN_0052A590:
  - entry state: ESI = the child node, EBX = database, `[esp+10h]` = the civ;
  - `pushad`, then `UhcCivFirstTcTag(node = ESI, civ = [esp+30h])` (stdcall), with AL carried
    through `popad`;
  - true → `jmp 52B43Dh`, the next child, which reads only the stack;
  - false → re-execute `xor edi,edi; cmp dword ptr [ebx+80h],edi` and `jmp 52BB0Fh`, whose `jle`
    reads those flags;
  - `UhcCivFirstTcTag`: element name `[[node+4]+18h][[node+18h]]` (index below `[[node+4]+1Ch]`),
    compared with L"firstTC" without case; text `[node+14h]`, narrowed to ASCII and trimmed;
    stored under the civ ID `[civ+8]` with the civ pointer; true for every `<firstTC>`, whatever
    its text.
- **Placement wrapper:** `WriteCall(0x925F4C, UhcRmPlaceObjectDef)`, an
  `int __fastcall(def, unused, player, x, z, count)` with the thiscall frame of `0x925936`
  (`ret 10h`; x and z are floats, passed on as raw dwords):
  - call `0x925936` unchanged unless a tag exists, the world and database exist, `[def+0Ch]` > 0,
    `[def+55h]` = 0, an item (`[def+8]`, 20 B each, `+0` proto ID) holds `[db+5E08h]`, and the
    owner `[world+58h][player]` (0 ≤ player < `[world+5Ch]`) has a resolved proto other than
    `TownCenter`;
  - in a Nomad start (`[game+92Ch]` non-null and its byte `+1A95h` ≠ 0, as `0x90B683`), call it
    unchanged (and log, with `log`);
  - otherwise compute the new proto's footprint as `0x924B1D` (proto `0x45316E(db, id)`; when
    `0x45EE02(proto, 2)`, `(int)([proto+88h] × [[world+88h]+1Ch] × 2 + 0.5)` and the same with
    `[proto+8Ch]`, else 0); save each `TownCenter` item and set its `+0` to the proto and `+0Ch` /
    `+10h` to the larger footprint; call `0x925936` with the same arguments; put back each saved
    item that is still below `[def+0Ch]` and still holds the proto; return place's result.
- **FirstTC:** the civFirstTC branch of the shared proto hook (startingTC above).
  `UhcCivFirstTcMatches(player, protoId, unit)` is true when the player's proto is `protoId`
  (≥ 0) and the Nomad byte is 0; it logs with `log`.
- **Town hook** at `0x679AC8`, 6 bytes (`jmp` + 1 NOP), in FUN_0049039A:
  - entry state: EDI = player, ECX = database; after `0x679ACE`, EAX, ECX and EDX are written
    before they are read;
  - re-execute `mov ebx,[ecx+5E08h]`; call `UhcCivFirstTcTownProto(EDI)` (stdcall); a result
    ≥ 0 replaces EBX; `jmp 679ACEh`;
  - `UhcCivFirstTcTownProto`: the player's proto, or -1, unless the FirstTC `[player+4F0h]` is in
    the unit table (as `0x44CC6D`), of exactly that proto (`[[unit+5Ch]+4]`), owned by the player
    (`[unit+44h]`), alive (`call [[unit]+0A4h]`), and a colony starts at it: `[player+3E0h]`
    non-null, bit 0 of its first byte clear, and a colony `[[list+8]+4·[[list+14h]+4k]]`
    (k < `[list+18h]`) with `[colony+28h]` = the FirstTC ID, as the loop at `0x7C2407` tests.
    Return -1 when any of these fails (the colony case is logged once per game).
  - Keep the colony test: FUN_007C238E spawns only at such a colony, and `0x679B63` clears the
    request after the call whether or not anything spawned. Without the test, a building with no
    colony would use up the request with nothing spawned.
- **Order:** after startingTC, as in `features.h`; or install the shared proto hook yourself, once.

### transformInventory

Code: [techs](porting-code/techs.md#transforminventory).

- **Hook** at `0x9C7625`, replacing `mov eax,[esi+58h] / test eax,eax / je 9C763Ch` (7 B):
  - entry state: ESI = the unit, EBP = the player's copy of the new proto, `[esi+5Ch]` = the old
    proto, x87 stack empty. The unit has left the other players' knowledge bases (0x9C75FE) and
    its player's lists (0x9C7620); it goes back at 0x9C7658 / 0x9C768D, and setHP's checkState runs
    at 0x9C76F3;
  - call the helper `UhcTransformInventory(unit, newProto)` (stdcall) with every register
    preserved (`pushad` / `popad`);
  - re-execute the stolen code: `mov eax,[esi+58h]; test eax,eax`; jump to `0x9C762C` when EAX is
    not 0 (it pushes EAX), else to `0x9C763C`. The flags are dead after the `je`.
- **Helper rules:**
  - treat `[proto+E0h]` as the resource object (InitialResource list at `+0`) and
    `[[unit+B4h]+94h]` as the inventory (list at `+4`);
  - compare resource types by decoding entries (`[list][r] ^ [0xC6DF14+4r]`, r < `[0xC6DF38]`) and
    testing `> 1e-6`; never write decoded values back, copy raw with 0x480A73;
  - reuse an existing inventory (set `+0Ch` and `+10h` to −1), create a missing one with 0x9BFE5A,
    never free one that you then re-create in the same call;
  - free (only for a new proto without a resource object, if you offer `all`) with cdecl 0x4BA757
    followed by `[[unit+B4h]+94h] = 0`, as 0x4BA74C / 0x4BA7A7 do;
  - with `scale`, compute the factor before the copy and apply it with 0x480B94.
- **Coexistence:** it runs with transformUpdatesLOS (0x9C763F); do not verify `TransformSetProto`
  in this feature, since that feature may have written its `jmp` there.

### costEscalationTechs

Code: [buildings](porting-code/buildings.md#costescalationtechs). It needs `AddTechSubtype`, in the
[helpers](porting-code/helpers.md#tech-subtypes).

- **Sites:** the `call` at `0x6206D7` (`E8 81 F8 FF FF`), and 9-byte `jmp`s at `0x8F978D` (`83 F8 63 0F 87 5E 17 00 00`) and
  `0x8FB051` (`83 F8 5E 0F 87 40 11 00 00`). Check them against your DLL first: another key that adds a Data subtype
  must share them.
- **Test:** a tech with the effect in the [modding guide](modding-guide.md#costescalationtechs): the button's cost changes
  and the food drops by it.

### trainBatchSize

Code: [buildings](porting-code/buildings.md#trainbatchsize). It needs `AddProtoTagHandler`, in the
[helpers](porting-code/helpers.md#proto-tags).

- **Sites:** a 5-byte `jmp` at `0x9CE645` (`call 0x8D051B`), continue at `0x9CE64A`; and a 5-byte `jmp` at `0x51DB0F`
  (`5F B0 01 5E 59`), continue at the `ret` `0x51DB14`. Check them against your DLL first: another key that adds a proto
  tag must share the second.
- **Test:** the tag on a proto: five clicks queue in that size, and the log shows the proto.

### noTrainNearEnemyTC

Code: [buildings](porting-code/buildings.md#notrainnearenemytc).

- **Globals:** `g_uhcNoTrainType` (the marker's ID; while it is -1 the hook runs the stock code),
  and the pointer `g_uhcBwrTrainGetter` it calls (owned by buildingWorkRateAuras; `0x9BFE33` by
  default).
- **Helper:** `bool __stdcall UhcNoTrainBlocked(unit* trainer)`: false unless
  `0x44D7FA([trainer+5Ch], type)`; then the nearest enemy FirstTC as in
  [how-it-works.md](how-it-works.md#notrainnearenemytc): players 1 .. `[world+5Ch]`-1 in order,
  `0x44CB21`, `[p+4F0h]` ≥ 0, `0x44CC6D`, owner `[tc+44h]` ≠ the trainer's, `0x484D2D(owner,
  [[trainer+44h]])`, `call [[tc]+0A4h]` (alive), `call [[tc]+0B8h](tc, trainer+14h)`; with
  `near` types, for each one `0x4A1C55(world, trainer+14h, meters, 1, &list)` (one list kept for
  the session: `{int* data; int count; int capacity}`, zero-initialised; the engine grows it) and,
  per ID, `0x44CC6D`, owner not null, not the trainer's, not player 0, `0x44D7FA(proto, type)`,
  `0x484D2D`, alive, `0x44DDB4` (built), then the same distance call. True when the smallest
  distance is below the cfg value. The distance is to the blocker's footprint edge
  ([how-it-works.md](how-it-works.md#notrainnearenemytc)). The decision reads only simulation
  state.
- **Warning (interface only, the shared `floatingtext.cpp`):** after a blocked decision, when
  `[[trainer+44h]]` equals `[[0C66234h]+3C0h]`, `[world+8A8h]` is not null and
  `0x4818F4(trainer, local player)` is true, at most once per 8000 ms of `[world+108h]` per
  trainer ID: two cfg ints through `0x46A144` on
  `0xC66500` with the IDs `[[0CEFFF8h]]` and `[[0CF0000h]]` (defaults 1000 and 2000), a BString
  (`0x401A12` from a wide text or `0x58EA52` from a string ID), then
  `0x8023AE([world+8A8h], &text, t1, t2, [trainer+10h], float[3]{0,0,0}, 0xFFFF4040, 1.0f, 0, -1)`
  and `0x4010CA` on the text. A non-zero second float makes the text rise (the stock 0.1 left the
  screen in about 0.3 s in the test bed).
- **Hook** at `0x9EA410`, in FUN_009EA28B, 8 bytes (`jmp` + 3 NOP):
  - entry state: ESI = the Train action, EDI = the trainer's player, x87 stack empty; EAX, ECX,
    EDX and the flags are free; EBX is reloaded at `0x9EA418`;
  - blocked: `fldz`, `jmp 9EA418h`;
  - otherwise: `mov ecx,[esi+10h]; call [g_uhcBwrTrainGetter]; jmp 9EA418h`;
  - keep ESI, EDI, EBP and ESP; leave exactly one value on the x87 stack.
- **Order:** apply it after `liveBuildingWorkRate`, which checks the stock bytes of
  `WorkRateTrainCall`, and before `buildingWorkRateAuras`, which then sees the Train call hooked
  and only sets the pointer.

### overhealHitpointBars

Code: [healing](porting-code/healing.md#overhealhitpointbars).

- **Globals:** `g_uhcOverhealTypes[8]` (marker or proto IDs, -1 until the data loads; a -1 entry is
  skipped), `g_uhcOverhealTypeCount` (entries in use) and `g_uhcOverhealLog`.
- **"Uses initial":** proto P is of one of the types (`0x44D7FA(P, id)`) and
  1e-6 < `[P+9Ch]` < `[P+98h]` (strict, float compares).
- **Reference** (`float thiscall(unit)` in ST0, called with an empty FPU stack): m =
  `0x480408(unit)`; if `[unit+5Ch]` is not null and uses initial: `[P+9Ch]` when m == `[P+98h]`,
  else m × `[P+9Ch]` / `[P+98h]`; otherwise m. Keep the exact `[P+9Ch]` when there is no override:
  the texts truncate.
- **Ratio** (`float thiscall(unit)`): r = reference; 0.0 when r < 1e-6; 1.0 when `[unit+64h]` ≥ r;
  else `[unit+64h]` / r. The comparisons must treat NaN as 0x45F295 does (`test ah,5 / jnp`,
  `test ah,41h / jnp`).
- **Base** (`float thiscall(database proto)`): `[P+9Ch]` when P uses initial, else `[P+98h]`.
- **Hooks** (each: the result in ST0, then `jmp` to the next stock instruction):
  - `0x45FAAF` (5 B) ECX = ESI = unit: ratio, → `0x45FAB4`;
  - `0x4C5014` (5 B) ECX = EBP = unit: ratio, → `0x4C5019`; keep EBX, EDI, ESI, EBP (popped
    after);
  - `0x698B35` (5 B) ECX = EBX = unit: reference, → `0x698B3A`;
  - `0x4D7575` (6 B) ECX = EDI = unit: reference, → `0x4D75AD` (skips the inlined getter);
  - `0x4D7615` (6 B) EAX = database proto (not null): base, → `0x4D761B`;
  - `0x9AFA2A` (6 B) ECX = database proto (not null): base, → `0x9AFA30`;
  - `0x9AFA4E` (5 B) ECX = ESI = unit: reference, → `0x9AFA53`.

  At every site the FPU stack is empty and EAX, ECX, EDX and the flags are dead after the
  continuation. Preserve EBX, ESI, EDI and EBP.
- **Log callback** (only with `log`): `UhcOverhealLogReference(unit, reference, max)`, stdcall,
  floats by value, called with an empty FPU stack whenever a reference differs from the stock
  max; it logs once per proto name.
- **Display only:** never patch 0x480408 or 0x45F295 themselves; their other callers are
  simulation code.
- **`segment`** (five more hooks, installed only with the option, after their own VerifyAll):
  - `0x45FB6C` (5 B, `jmp 4516B3h`), ESI = unit, `[esp+18h]` = the bar's position, `[esp+15h]` =
    under construction: unless under construction, compute the reference (empty FPU stack), then
    `UhcOverhealQueueSegment(unit, pos, reference)` queues `0x45FB71(world, pos, 1.0, share,
    804F5648h, FFh)` when HP > reference, share = min((HP − reference) / reference, 1). Keep every
    register; → `0x4516B3`.
  - `0x45C4B9` (6 B, `mov ebx,[ebp+8D4h]`), EBP = world: when count × 216 > `[[[0C66044h]+660h]+4]`,
    remove the records of player 804F5648h from `[world+8D0h]` and lower the count; redo the
    load; → `0x45C4BF`.
  - `0x45CB72` (6 B, `add eax,1 / add ecx,1Ch`), ECX = the record's offset, EDI = its sixth vertex
    (the first at EDI − 0B4h), ESI = camera, x87 stack empty: for player 804F5648h only, add
    scale × (1 − share) × `[camera+28h..30h]` to the positions of vertices 0, 2 and 3, set u
    (`+1Ch`) to 1.0 on those and 0.5 on 1, 4 and 5, and the colour (`+18h`, ARGB) on all six; redo
    the adds; → `0x45CB78`.
  - `0x4D7651` and `0x69A9C0` (5 B, `push` of the UTF-16 format), `[esp]` = HP, `[esp+4]` = the
    100 % value: push `<color=r, g, b>` + the stock format + `</color>` when HP > the value, else
    the stock one; change only the flags; → `0x4D7656`, `0x69A9C5`.
  - These depend on the renderer's vertex layout (verified as the whole loop, site
    `HpBarRenderLoop`) and on the marker player ID never being a real player.
  - `0x4C83DF` (9 B, `lea ecx,[esp+70h]; call 4010CAh`), the portrait bar's tail: `[esp+50h]` =
    panel, `[esp+78h]` = group (FPU empty). Work on WoL's own green bar, `handle = [panel+310h]`; add no
    gadget. When `[group+1Ch]` ≥ 0.999 and the group's average min((HP − reference) / reference, 1) is
    above 0 (IDs `[group+10h]`, count `[group+14h]`): `bar = 0x44B8B8(handle)`, `0x40431B(handle)`,
    then `background = [bar+140h]`, and the first time call its vtable +7Ch, `thiscall(background,
    &BString texture, -1)`, with the overheal texture; `0x590772(bar, 1 − share)`. When the overheal
    ends, the same call with `ui\ingame\ui_health_bar`. Reset that state when the panel or its handle
    changes. Don't call the setter `0x5CAF02`: it creates a drawable with no size. Redo the stolen pair;
    → `0x4C83E8`.
- **`stat` in WoL's interface:** the hook below never runs there. The row goes through the
  [unit panel row](#unit-panel-row-the-minimized-interface).
- **`stat`**: `0x4D76DB` (9 B, `mov edi,2; mov [esp+2Ch],edi`): redo both, then for a marked unit
  `[esp+38h]` write row EDI of panel `[esp+50h]` as the Group Health branch (0x69A9D3) does
  (gadgets `[panel+174h+EDI*4]` / `[panel+198h+EDI*4]` through 0x4C519C; vtable +84h with
  0D6F5D0h / 0C6657Ch, +80h with the text, +54h; `[gadget+68h]` = `L""`), and on success
  `add edi,1; mov [esp+2Ch],edi`; → `0x4D76E4`. EAX, ECX, EDX and the flags are dead there.
- **Public helpers** for the other overheal keys (cdecl, in `overheal_hooks.asm`):
  `float UhcOverhealReferenceOf(unit)`, `float UhcOverhealRatioOf(unit)`,
  `int UhcOverhealMarked(proto)`.

### overhealSources

Code: [healing](porting-code/healing.md#overhealsources).

- **Needs** overhealHitpointBars' types and helpers (above); apply it after that key.
- **Globals:** `g_uhcOverhealSourceTypes[8]`, `g_uhcOverhealSourceTypeCount`, `g_uhcOverhealAllow`.
- **Add-HP hook** at `0x4823A3` (8 B: `push ecx; push esi; mov esi,ecx; cmp dword ptr [esi+8],8`),
  ECX = unit, `[esp+4]` = amount (float), `[esp+8]` = flag: pushad, `UhcOverhealAddHp(unit,
  &amount)` (may lower the amount in place), popad, redo the 8 bytes, → `0x4823AB` (`jbe` on the
  `cmp`). Lowering rule: amount > 0, the unit's proto marked, `g_uhcOverhealAllow` = 0 and
  HP + amount > reference → amount = max(reference − HP, 0).
- **Tick max hook** at `0x9E0BBB` (5 B, `call 480408h`), ECX = EDI = target, ESI = the action
  (healer `[esi+10h]`), FPU stack empty: ST0 = the reference for a marked target and a non-source
  healer, else the stock max; → `0x9E0BC0`.
- **Tick add hook** at `0x9E0CE9` (5 B, `call 4823A3h`): `g_uhcOverhealAllow` = the healer is a
  source; the stolen call; `g_uhcOverhealAllow` = 0; → `0x9E0CEE`.
- **Search hook** at `0x9CD984` (5 B, `call 45F295h`), ECX = ESI = candidate, healer `[ebp+4]`:
  ST0 = HP / reference (stock rules) for a marked candidate and a non-source healer, else the stock
  ratio; → `0x9CD989`. Coexists with smartHealTargets and healNonIdle (other sites of the loop).
- **The add-HP hook is shared** with overhealDecay: `InstallOverhealAddHook()` writes it once.

### overhealDecay

Code: [healing](porting-code/healing.md#overhealdecay).

- **Needs** overhealHitpointBars' helpers; apply after overhealSources (they share the add-HP hook,
  and the second one must not verify bytes the first already replaced).
- **Gain:** the add-HP hook calls `g_overhealGain(unit, restartDelay)` (set by this key) for a
  positive amount on a marked unit that still takes it above its reference; it stores
  `[world+108h]` in a map keyed by unit ID, or, for a regeneration (restartDelay false), adds the
  unit only if missing, with `[world+108h]` − delay.
- **Regeneration hooks:** `0x490881` and `0x67A03B` (5 B each, `call 4823A3h`): set
  `g_uhcOverhealRegen` = 1, the stolen call, set it to 0; → `0x490886`, `0x67A040`. Without them an
  idle unit that regenerates restarts the delay on every step and never decays.
- **Tick** (registered with `AddWorldTick`, after damageOverTime's): elapsed = `[world+108h]` − the
  last tick's (another world, the time going back or `[world+F8h]` jumping by more than 1 clears
  the map, as does a data reload); for each unit in ID order: look it up (`[world+0Ch]`, ID check),
  alive (`vtbl+A4h`), marked; at or below the reference → forget; inside the delay → skip; else
  `FUN_004820A1(unit, max(HP − rate × elapsed / 1000, reference), 0)` (rate in HP/s, or the
  reference × % / 100).
- **Never** below the reference, never the real clock, never pointer order.

### Unit panel row (the minimized interface)

Code: [helpers](porting-code/helpers.md#unit-panel-row-the-minimized-interface); the two rows are `UhcGatherUnitPanel` in
[`gathering`](porting-code/gathering.md) and `UhcOverhealUnitPanel` in [`healing`](porting-code/healing.md).

**Why WoL needs it.** WoL plays with the minimized interface (`optionminimizedui`). With that option
the exe returns from the stat panel fill FUN_004D70ED at `0x4D7261`, before any row, so everything
that adds a stat panel row (`showGatherRate`, `overhealHitpointBars stat`) shows nothing. The unit
panel keeps one row of its own, the AutoGather rate, in the gadgets `unitResourceRateLabel` and
`unitResourceRateValue` of `uiunitselectionmin.xml`. This code writes that row. It needs no change to
the mod's data.

- **Hook** at `0x699456` (6 B, `jmp` + 1 NOP): stock bytes `8B 7C 24 54 8B CF` (`mov edi,[esp+54h];
  mov ecx,edi`), the join point after the stock AutoGather block. Entry: `[esp+50h]` = the panel,
  `[esp+54h]` = the unit. Re-execute the two instructions and jump to `0x69945C`.
- **Gadgets:** `[panel+33Ch]` label, `[panel+340h]` value, as handles for `0x4C519C`. A null gadget
  means an interface without that row (the normal one): write nothing.
- **Selection:** `0x453B28` returns the current selection from the UI globals alone. Require count
  `[+14h]` = 1 and byte `[+21h]` = 0, as the stat panel's rows do: with a group the panel shows the
  first unit, and its rate would read as the group's.
- **Hiding:** nothing to do. The panel hides these gadgets each time it fills, so the row goes away
  by itself when a writer stops writing.
- **Order:** one row, several keys: the last key added is asked first, so a gathering unit shows its
  rate. In `kFeatures`, `overhealHitpointBars` comes before `showGatherRate`.
- **Add a row with `AddUnitPanelRow`, never a second `jmp` at `0x699456`.**

Check it in the game: with `showGatherRate`, select one gathering villager: `Food (icon): 0.67/s` next
to Resists; it goes when the villager stops, and with two villagers selected. With
`overhealHitpointBars stat`, select a marked unit above its 100 %: `Overheal: 15/30`. The log shows
`hook reached: unit panel row (0x699456)`.

### workRateByAbstractType

Code: [gathering](porting-code/gathering.md#workratebyabstracttype).

- **Sites:** two 5-byte `jmp`s, at `0x8F987C` (`8B 7F 44 3B FD`: `mov edi,[edi+44h]; cmp edi,ebp`, continue at
  `0x8F9881`) and `0x8FB11A` (`8B 76 44 3B F5`: `mov esi,[esi+44h]; cmp esi,ebp`, continue at `0x8FB11F`). No
  range of WoL's DLL overlaps them.
- **In the hook:** the target proto, its base proto, and from the frame the action, key, amount and
  relativity. See the comments in the assembly for the offsets, which differ by 4 in the second site.
- **Data:** WoL must decide about the techs that name both types: see the [modding
  guide](modding-guide.md#workratebyabstracttype).

Check it in the game: with `showGatherRate`, select a villager on an `OlivePlantation` and activate
`Amalgamation`: the rate goes from 0.28 to 0.34.

### autoGatherScaleByContained

Code: [gathering](porting-code/gathering.md#autogatherscalebycontained).

- **Site:** a 6-byte `jmp` at `0x49EBE4` (`51 53 8B 5C 24 0C`: `push ecx; push ebx; mov ebx,[esp+0Ch]`), continue at
  `0x49EBEA`. No range of WoL's DLL overlaps it.
- **In the hook:** only the assembly; there is no C++ logic but the key.

Check it in the game: add the tag to an AutoGather action of a building that can garrison, select it and put two
units inside: the rate row doubles.

### unitResourceAuras

Code: [gathering](porting-code/gathering.md#unitresourceauras). It needs `AddActionTagHandler` and `AddModifyType`
from the [helpers](porting-code/helpers.md).

- **Sites:** a 5-byte `jmp` at `0x9D033E` (`A1 34 62 C6 00`: `mov eax,[0C66234h]`), continue at `0x9D0343`. It does not
  overlap WoL's DLL. The name hook at `0x5FE6D7` is the one `buildingWorkRateAuras` uses; with both keys there is one
  `jmp` and one list of names.
- **Data:** none: `AreaGatherTree` is already in `sawmill.tactics`.

Check it in the game: a `WOLSawmill` among trees, with `log`: a line about every 3 s per tree, for at most 5 trees.

### resourceGatherAuras

Code: [gathering](porting-code/gathering.md#resourcegatherauras). It needs `AddModifyType` from the
[helpers](porting-code/helpers.md).

- **Site:** the `call 4ECD39h` at `0x4ED02A` goes to the wrapper, and the wrapper calls it. WoL's DLL patches `0x4ECD6B`, inside
  that function, for its `danceCiv`: the wrapper calls through it, so the two combine. No range overlaps the call.

Check it in the game: an aura with `MineGatherRate` 2 on an Explorer, and `showGatherRate` on a miner.

### resourceDebt

Code: [gathering](porting-code/gathering.md#resourcedebt).

- **Sites:** an 8-byte `jmp` at `0x679A0E` (`C7 44 24 10 00 00 00 00`), continue at `0x49A9D0`; at `0x6798F4` (`C7 44 24 74 00 00
  00 00`), continue at `0x49A8E3`; and at `0x6799D4` (`C7 44 24 18 00 00 00 00`), continue at `0x6799DC`. None overlaps WoL's DLL.
- **The gates of negative rates:** a 6-byte `jmp` at `0x48D186` (`0F 8A 93 3D 03 00`), `0x49EE07` (`0F 8A 27 1C 02 00`) and
  `0x4ED03E` (`0F 8B A6 BA 1B 00`). Check them against your DLL's gather hooks: WoL's gather code may already sit near the tick.
- **The return addresses that have no floor** are constants in the helper: `0x4E0CFE`, `0x4C379D`, `0x4ED1F3`. A hook of yours on
  those three calls changes nothing as long as the stock return address stays on the stack.

### showGatherRate

Code: [gathering](porting-code/gathering.md#showgatherrate).

- **WoL's interface:** the panel hook below writes the stat panel, which the minimized interface
  never fills. Add the [unit panel row](#unit-panel-row-the-minimized-interface) too.
- **Globals:** `g_uhcGatherRecords` (4000h records of 20h bytes: `+0` gatherer ID, written last;
  `+4` action; `+8` resource; `+0Ch` target ID; `+10h` float rate; `+14h` float elapsed; `+18h`
  game time), `g_uhcGatherRowPending`, `g_uhcGatherRowRes`, `g_uhcGatherRowRate` (float).
- **Record hook** at `0x4ED044` (8 B), on the simulation path, every gather loop of every unit:
  - entry: ST0 = R (rate per second), the only x87 value; ESI = the Gather action; `[esi+10h]` the
    gatherer and `[[esi+10h]+44h]` its player, both non-null; elapsed at `[esp+30h]`; flags dead;
  - write only DLL memory; keep ST0 exactly (multiply a copy: `fld st(0); fmul [player+37Ch];
    fstp`), leave the x87 depth and control word as found, preserve EAX / ECX / EDX (dead, but
    cheap) and EBX / ESI / EDI / EBP;
  - re-execute `fmul dword ptr [esp+30h]; fst dword ptr [esp+14h]` and jump to `0x4ED04C`.
- **Panel hook** at `0x4D7834` (7 B):
  - entry: the fill's frame (`[esp+2Ch]` row, `[esp+38h]` unit, `[ebp+8]` selection), x87 empty,
    flags dead; EAX, EBX, EDX, EDI may be anything (the stock AutoGather path arrives so);
  - pending flag set: clear it and take the stock path;
  - otherwise call `bool __stdcall UhcGatherPanelRow(unit, selection, row)` with EAX / ECX / EDX
    saved; on true set the pending flag, EBX = `[esp+2Ch]`, jump to `0x69AF7C`;
  - stock path: `mov esi,[esp+38h]; mov ecx,[esi+5Ch]`, jump to `0x4D783B`.
- **Row value hook** at `0x69AFE0` (6 B): pending → EBX = `g_uhcGatherRowRes`, `[esp+1Ch]` =
  `g_uhcGatherRowRate`, jump to `0x69B02A` (keep ESI / EDI, the gadgets; EAX is free); else
  `mov ecx,[0C66234h]`, jump to `0x69AFE6`. Write this hook before the panel hook.
- **Never use a stack slot as the re-entry guard:** the formatter's `%d/s` branch writes
  `[esp+0Ch]` (0x69B0EF, 0x69B0FB); a whole-number rate would then repeat the row in rows 2..8.
- **Provider** at the imm32 `0x5D2D3C`: `bool __stdcall(Value*)` (`ret 4`, ECX unused). Return
  false unless `Value.type` = 3; otherwise assign the text to `Value+4` with
  `0x443BB8(&value->text, &src, -1, -1)` (src = a BString whose first dword points to your
  `wchar_t` buffer) and return true, or return true without assigning (empty string). Do **not**
  write the imm32 at `0x5D06E8` (ids 19h / 1Ah): WoL's `uimainnew.xml` reads
  `{currentUnitGatherRate(gold)}`, which must keep failing.
- **Record validity**, shared by both readers: same ID; `[[unit+58h]+24h]` = the action; byte
  `[action+61h]` = 5; `[action+10h]` = the unit; resource < `[db+80h]`; rate > 0; age in
  `[world+108h]` ms within max(2500, 2000 × elapsed), at most 60000; `[player+338h]` = 0; the
  target, if found, not `0x44CAC4(proto, 58h)`.

### buildingWorkRateAuras

Code: [buildings](porting-code/buildings.md#buildingworkrateauras).

- **Globals:** `g_uhcBwrTrainGetter` (exported data, `void*`, default `0x9BFE33`): set it to the
  wrapper when the feature applies. A hook that replaces the Train call at `0x9EA410` (this DLL's
  noTrainNearEnemyTC) must call through it.
- **Name hook** at `0x5FE6D7` (`jmp`, 1 NOP), in FUN_005F5645:
  - entry state: EAX = the result of `0x443C10(name, L"AutoGatherRate", 0, -1)` (0 = equal), ESI =
    the name (`BString*`), `[esp]` = the ESI the function saved;
  - EAX = 0: keep it; else call `0x443C10` again with `push -1; push 0; push L"BuildingWorkRate";
    mov ecx,esi` (thiscall, `ret 0Ch`) and set EAX = `40h - 0Eh` on 0, `-0Fh` otherwise;
  - continue at `0x5FE6DD` (`pop esi; add eax,0Eh; ret`). EBX, ESI, EDI, EBP kept; ECX, EDX and the
    flags free.
- **Rate wrapper**, the target of the calls at `0x9E65F7`, `0x9D58D4`, `0x6AB23F` and (when
  `0x9EA410..0x9EA417` are stock) `0x9EA413`, and the value of `g_uhcBwrTrainGetter`:
  - entry state: ECX = the unit, `[esp]` = the return address, x87 stack empty;
  - `[ecx+0B4h]` null or `[[ecx+0B4h]+0C8h]` null: `jmp 9BFE33h`;
  - otherwise: push ECX, EDX; call `0x9BFE33` (ECX = the unit; ST0 = base); factor = 1.0f;
    collect the unit's actions with type byte `[+60h]` = 2Ch (**and, in WoL, 46h**: its
    ModifyActionFix retypes the tactics-driven class) from `[[unit+58h]+14h]` (`{count +0, data
    +8}`, children at `[+40h]`, depth first, parent first; stop at 16 levels and use 1.0) whose
    `[+64h]` = 40h; call `0x4B3C7D(ecx = 0, &factor, &{data, count}, 40h)` (`ret 0Ch`); use 1.0
    when it returns false or `factor < 1e-6f`; ST0 = base × factor (base itself when the factor is
    1.0); pop EDX, ECX; `ret`;
  - on return: ST0 = the rate, ECX, EDX, EBX, ESI, EDI, EBP as on entry; EAX and EFLAGS clobbered
    (each caller writes EAX before reading it and calls a function before reading the flags).
- **Getter head:** the wrapper calls `0x9BFE33`, so a getter hook (liveBuildingWorkRate) applies
  first; this DLL checks that the getter's first 5 bytes are stock or that hook's `jmp`.
- **Order:** apply it after every feature that verifies the four call sites as stock bytes
  (liveBuildingWorkRate, noTrainNearEnemyTC). Check the Train call (`BwrTrainCall`) on its own and
  leave it alone when it is not stock.
- **Stat 40h** is this DLL's number for BuildingWorkRate. Keep it, or agree on another one, if your
  DLL adds its own ModifyTypes.

### decimalPopulation

Code: [population](porting-code/population.md#decimalpopulation).

- **Globals:** `g_uhcPopScale` (K; 1 without the key) and `g_uhcPopStockClamps` (1 when this key
  installs the cap hook itself), both read by the cap hook of basePop/extraPop
  (`src/hooks/limit_hooks.asm`).
- **Cap hook** at `0x4581F3` (basePop's): every limit is in whole population and is multiplied by
  K: base + extra, the bonus `[player+4F4h]`, and with the stock clamps on, `[world+31Ch]` + extra
  and 250. **In WoL** this site is WoL's own basePop/extraPop hook
  (`ExtendLimitsByXmlFeature?`): scale its limits the same way instead of installing this one.
- **Parse calls** (`0x5FB92E`, `0x5FD719`): `bool __cdecl f(const char* text, int* out)`. The
  text is ANSI. `out` is the handler's argument slot; `out + 1` holds the proto. Write
  `round(value × K)` and return true, or return false (the stock error path).
- **Effect calls** (`0x8FA835`, `0x8FA8CF`): `void __cdecl f(rel, int* out, int base, float
  amount, negate)` with the stock five arguments; call `0x7F899B` with `round(amount × K)` for
  relativity 1 (or any value but 0, 2, 3), `amount × K` for 3, and for 2 with relativity 1 and
  `lround(base × amount − base)`. Write K into the imm32 at `0x8FA84A`.
- **PopulationCap hooks** (`0x8D87AB`, `0x8D20AB`): `fld [esp+X]; fimul K; frndint; fnstcw
  [esp+X]`, continue 8 bytes later. X = 34h / 20h.
- **Team cap** (`0x679694`): EAX = an ally's raw cap; `min(EAX, 200 × K, [world+31Ch] × K)`;
  ECX, EDX free; continue at `0x6796B8`. **Start bonus** (`0xA0D2D1`): EAX += (EBX +
  `[ESI+320h]`) × K, keep EBX, EDX free; continue at `0xA0D2D9`.
- **XS wrappers:** cdecl, two arguments read in place (declare none: a caller may push fewer, and
  a declared parameter's slot can be reused as scratch); call the stock impl from the site's
  bytes with both. Getters divide (half away from zero; `kbGetPopSlots` rounds a positive value
  up; `kbUnitPickGet*` keep negatives); setters multiply a value ≥ 0 (argument 1, or 2 for
  `kbUnitPickSet*`). Return the stock EAX.
- **Data refs:** write the wrapper into the provider imm32 (`+4`) and `6A 03 58 90` at `+20h`;
  the wrapper is `bool __stdcall f(Value*)`: type must be 3; call the stock provider with
  `{2, 0}`; assign the text to the Value's BString (`0x443BB8`, `-1, -1`).
- **colorizePop:** `int __cdecl f(BString* arg)`: the number after the first `(` × K, −1 if none.
- **Format wrappers:** cdecl, arguments read in place: `(dest, format, a0..a3)`; replace the
  i-th conversion (i = 0, or 1 at `0x6F580C`, 2 at `0x6F2DB5`) with `%s`, pass the text in its
  slot, call `0x444EFB`. **In WoL** `0x710651` (and `0x71063C`) are redirected by
  `DoubleShipmentsInspectFixFeature`: call this wrapper from WoL's replacement, or the reverse.
- **Order:** after basePop/extraPop.

## 5. Integration rules

- **Keep the cfg keys and their syntax:**
  - `healNonIdle [UnitType]`, default `AbstractHealNonIdle`;
  - `hcShipmentPointFallback <Proto|FirstTC> …`, 1 to 64 entries;
  - `damageOverTime [log] [noticktext]`, with `<AttachProtoUnit>` (and optionally
    `<AttachMaxStacks>`, `<AttachSnare>`, `<AttachTickText>`) in `protoy.xml` and an `Attaching`
    action on
    the attachment proto;
  - `dodgeAnyUnit [UnitType] [log]`, default `AbstractDodge`, and any number of
    `dodgeSoundSet <UnitType> <SoundSet>` / `criticalSoundSet <UnitType> <SoundSet>` lines;
  - `liveBuildingWorkRate [log]`, `transformUpdatesLOS [log]`, `snareOnlyHitUnit [log]`,
    `wonderPanelSkipAuras [log]`, `customHotkeyContexts [log]`;
  - `techPrereqRecheck [N] [full] [log]`, N from 1 to 1000000;
  - `maintainWaitForPop [UnitType] [log]` (default `AbstractMaintainWaitForPop`),
    `lifespanAfterConstruction [UnitType] [log]` (default `AbstractLifespanAfterConstruction`),
    `noCorpseDopples [UnitType] [log]` (default `AbstractNoCorpseDopple`),
    `gaiaSocketsOnly [UnitType] [log]` (no default: every socket);
  - `broadsideMuzzleLimit <N> [UnitType] [log]`, N from 1 to 255, one line;
  - `abilitySlots <N> [log]`, N from 6 to 36;
  - `techRenameEffect [log]`, also read as `enableTechRenameEffect`;
  - `danceBonusCivs <Civ> [<Civ> ...] [log]`, several lines add up;
  - `startingTC [UnitType] [log]` (default `AbstractStartingTC`);
  - `civFirstTC [log]`, with `<firstTC>Proto</firstTC>` inside a `<civ>` of `civs.xml`;
  - `transformInventory [all] [scale] [UnitType] [log]` (no default: every in-place transform);
  - `noTrainNearEnemyTC <meters> [UnitType] [near <UnitType>|FirstTC]... [nowarn | warn=<text> |
    warn=<stringID>] [log]`, meters above 0 and at most 1000, up to 4 `near`, one line (default
    `AbstractDaimyo`, `near FirstTC`, the warning on);
  - `overhealHitpointBars [UnitType ...] [segment[=RRGGBB]] [bar=<texture>] [stat[=Label]] [log]` (default `AbstractOverheal`, up to 8 types, one
    line);
  - `showGatherRate [UnitType] [log]` (no default: every unit);
  - `buildingWorkRateAuras [log]`;
  - `decimalPopulation [K] [log]`, K from 2 to 1000 (default 10).

  The [modding guide](modding-guide.md#5-feature-reference) then applies as written.
- **Verify, then write.** Check all of a feature's ranges first, and write nothing if any range
  differs.
- **Order.** Apply the features in the order of `kFeatures` in
  [`src/features.h`](../src/features.h). Three constraints matter: `noTrainNearEnemyTC` after
  `liveBuildingWorkRate` (both check `WorkRateTrainCall` as stock bytes; only the first writes
  inside it), `buildingWorkRateAuras` after both (it redirects the four getter calls and finds
  the Train call already hooked when `noTrainNearEnemyTC` is on), and `civFirstTC` after
  `startingTC` (they share the proto hook at `0x506B3B`, written once by whichever applies first).
  `noTrainNearEnemyTC` and `buildingWorkRateAuras` share `g_uhcBwrTrainGetter`: port both, or
  define that pointer as `0x9BFE33` in a port of `noTrainNearEnemyTC` alone.
- **Apply from `UHCMain`.** Every hook is in code that runs later, during data load or in game.
- **Multiplayer determinism** ([how-it-works.md](how-it-works.md#5-rules-that-keep-multiplayer-deterministic)):
  - names are resolved inside the game, from its own database;
  - choices follow cfg order, then the stock unit query order;
  - poisons tick on the game time `[world+108h]`, in integer milliseconds and key order;
  - `techPrereqRecheck` schedules on the world's step count, never on a clock;
  - predicates that mirror stock code (`maintainWaitForPop`, `snareOnlyHitUnit`, `startingTC`,
    `civFirstTC`, `noTrainNearEnemyTC`, `buildingWorkRateAuras`) call the same engine functions
    with the same arithmetic;
  - `civFirstTC` reads its tags while `civs.xml` is parsed on every machine, decides from each
    player's civ and the random map's Nomad byte, and restores the object def after each
    placement;
  - `transformInventory` copies the encoded amounts raw; only `scale` divides two game values
    (single precision);
  - `overhealHitpointBars` and `showGatherRate` change only the interface; `showGatherRate`'s
    record hook runs in the gather code but writes only the DLL's memory;
  - no hook sends a network command.

  Keep it that way if you change the code. In particular, never set the shipment point through
  `aiSetHCGatherPoint`'s setter (`0x82D9CB`): it sends a network command, which every machine
  would then send.
- **Saved games and replays:** `healNonIdle` and `dodgeAnyUnit` add a unit type, which changes the
  unit type count, and so do `maintainWaitForPop`, `lifespanAfterConstruction`,
  `noCorpseDopples`, `broadsideMuzzleLimit`, `gaiaSocketsOnly`, `startingTC`,
  `transformInventory`, `noTrainNearEnemyTC`, `overhealHitpointBars` and `showGatherRate` when
  their type is a new name. Load saves and replays with the same DLL and cfg they were made with.
  `damageOverTime` keeps its poisons outside the game state, so a loaded game has none.
  `buildingWorkRateAuras` modifiers are saved with stat 40h; a DLL without the feature ignores
  them. `civFirstTC` adds no unit type, but a recorded game generates its map again on playback,
  so it needs the same `civs.xml`, `placementrules\colonies.xml` and `protoy` as well.

## 6. Data and testing

- **Data.** WoL's data is plain XML: each section of the [modding guide](modding-guide.md#5-feature-reference)
  says what its key needs, and an existing type or proto name in the cfg needs no edit.
- **Log.** If you kept `Log` and `TRACE_ONCE`, the lines to expect are listed per key in the
  [modding guide](modding-guide.md#5-feature-reference):
  - at startup, `applied`;
  - while the data loads, `hook reached: abstract unit types (0x51BA31)` and
    `unit types: AbstractHealNonIdle -> <ID> (…), added`;
  - in game, the `hook reached` line of each feature hook.
- **In game:**
  - **healNonIdle:** with `healNonIdle xpMedicineMan`, a medicine man heals a Tomahawk while it fights.
  - **hcShipmentPointFallback:** delete every Town Center (and every other stock fallback
    building) and send a shipment. It must arrive at the first listed building that still
    stands. With `civFirstTC` (or `startingTC`) and `hcShipmentPointFallback FirstTC`, a player
    whose first town center is a Market and who has no Town Center receives a shipment at the
    Market (the log names it as FirstTC).
  - **civFirstTC:** give a civ `<firstTC>Market</firstTC>` in `data\civs.xml`, the Market
    `<Flag>StartingColonyBuilding</Flag>` and a `<type maxcount="1">Market</type>` in the
    `<starttypes>` of `placementrules\colonies.xml`, then start a skirmish as that civ: the map's
    Town Center is a Market, and the starting Settlers stand at it. A skirmish against an AI of
    an untagged civ checks that it still gets its Town Center and plays. Real clicks are needed
    for the skirmish and for sending a card
    ([developer guide](developer-guide.md#driving-the-game-unattended)).
  - **damageOverTime:** with the data of the
    [modding guide](modding-guide.md#damageovertime) and `damageOverTime log`, hit a unit once and pull
    back. The log must show one `tick` line per ROF with the hitpoints falling. Then start a skirmish
    against an AI and check that the AI plays. A tactics file with a line break after a tactic name
    stops the AI scripts from compiling ([modding guide, "Tactics files"](modding-guide.md#tactics-files)).
  - **dodgeAnyUnit:** mark a non-monk unit, make `YPDodge` active for its player, and let enemies
    shoot it. With `dodgeAnyUnit … log`, about one hit in seven logs
    `dodgeAnyUnit: unit N (Proto) dodged a hit`; a Japanese monk still dodges.
    `tools/testbed.py` builds such a fight with no clicks
    ([developer guide](developer-guide.md#driving-the-game-unattended)).
  - **dodgeChance:** with `dodgeChance <marker> 50 ranged log` and `dodgeChance <marker> 0 melee`,
    about half of the musket shots and none of the pike thrusts on a marked unit log `roll … ->
    dodged`; a rule with `notech` dodges without `YPDodge`, one with an unknown tech logs `rule
    disabled`.
  - **The other features:** the test that confirmed each one, with its data, is in its "Status" in the
    [modding guide](modding-guide.md#5-feature-reference). For each, run the same test with and without
    the key: the run without it must show the bug. Two pitfalls from these tests:
    scenario triggers cannot give build or work orders (use real clicks for placing foundations,
    `lifespanAfterConstruction` and `gaiaSocketsOnly`), and synthetic key presses do not reach the
    game's hotkeys (`customHotkeyContexts`).
- **Check the type table** with the game running: `python -I tools/re/inspect_unittypes.py
  AbstractHealNonIdle` lists the protos that carry the type.

## 7. What is not verified

- **In WoL (updated 2026-11-04):** the features below ran on WoL's exe and data, with this project's DLL
  replacing WoL's in a test copy, single player, each with a run without its key. None has run next to
  WoL's own DLL, so a clash with its patches can only be read from
  [section 1](#1-check-that-you-can-use-the-sites).
  - **Filmed, with the key off as control:** `healNonIdle`, `smartHealTargets`, `dodgeAnyUnit`,
    `dodgeChance`, `damageOverTime`, `spreadAnyAccuracy`, `liveBuildingWorkRate`,
    `buildingWorkRateAuras`, `techPrereqRecheck`, `maintainWaitForPop`, `transformUpdatesLOS`,
    `transformInventory`, `broadsideMuzzleLimit`, `abilitySlots`, `wonderPanelSkipAuras`,
    `lifespanAfterConstruction`, `customHotkeyContexts`, `snareOnlyHitUnit`, `techRenameEffect`,
    `noCorpseDopples`, `danceBonusCivs`, `noTrainNearEnemyTC`, `startingTC`, `showGatherRate`,
    `decimalPopulation` and the three overheal keys.
  - **Partly:** `snareOnlyHitUnit`'s gain was measured in one run each way: the group arrived
    at 50 s with the key and about 54 s without.
  - **Test data, not WoL's own:** poison, the test techs and auras, the Outpost's lifespan, the
    aura before a wonder's power, and overheal's `MaxHitpoints` were added to the test copy for the
    video and removed after. WoL's data has no `SetTechName` effect, no wonder with two abilities and
    no overheal yet.
  - **Filmed on a test map only:** `civFirstTC`, the substitution and the first town center.
  - **Not filmed in WoL:**
    `gaiaSocketsOnly`, `multipleInstances`.
- **Multiplayer, saved games and replays:** untested for every feature.
- **hcShipmentPointFallback:**
  - `FirstTC` was confirmed in game with `civFirstTC` only; with `startingTC`, and the owner check
    on a converted first town center, it was not tested;
  - water shipment points (`[hc+190h]`) were not tested (the key does not change them).
- **healNonIdle:**
  - a direct order (right-click) on a fighting unit was not verified.
- **dodgeAnyUnit / dodgeSoundSet / criticalSoundSet:** confirmed in single player only; the
  sound sets were checked in the log, not by ear. The unit's rollover text about dodging (if any)
  still names only the Japanese monks (0x6AB049, not traced).
- **damageOverTime:** confirmed in single player only, with hand attacks, instant shots, arrows, grenades,
  cannon balls and area damage, `DamageBonus` and a tech on X, X's DamageFlags after a conversion, an
  attacker removed, kill XP, and the three optional tags. A tick on an AI army unit after the attacking unit is gone (the p11 = 0 path) comes from the
  code; the attacker-gone path ran in game, but not on an army unit.
- **multipleInstances:** confirmed with two copies on one machine, in single player only.
- **The WoL Tier 2 features** (2026-10-29, single player only; "(multiplayer unverified)" for every
  one that changes the simulation):
  - **confirmed in game:** `liveBuildingWorkRate` (`Maintain`; train, research and the
    TrainPoints refresh on 2026-10-30), `techPrereqRecheck`, `maintainWaitForPop` (Ottoman settlers; batches and `SingleUse`
    not tested), `transformUpdatesLOS` (tech transforms; revolutions not tested),
    `broadsideMuzzleLimit` (normal attack; `PowerBroadside` not tested), `abilitySlots`,
    `wonderPanelSkipAuras`, `lifespanAfterConstruction` (the countdown hold; the
    `AlphaFadeLifespan` fade-out hold not checked), `techRenameEffect` (saved games not tested),
    `noCorpseDopples`, `danceBonusCivs` (Regeneration; Training in WoL, 2026-11-04; XPTrickle and Gathering not tested);
  - **confirmed in game, 2026-11-04 in WoL:** `snareOnlyHitUnit` (positions sampled with and without
    the key), `customHotkeyContexts` (real key presses queued the units; without the key, nothing);
  - **not tested in game:** `gaiaSocketsOnly`. The stock interface already refused a player's
    socket in the test, and the order path that bypasses it (WoL's case) was not driven.
- **The WoL Tier 1 and Tier 3 features** (2026-10-29, single player only, all 21 WoL keys on
  together):
  - **confirmed in game:** `transformInventory` (six `TransformUnit` cases, and WoL's `HCCardDogTaxWar` with a key-off run;
    `all`, `scale`, a marker, revolutions and a conversion afterwards not tested),
    `noTrainNearEnemyTC` (pause near an enemy Town Center or a `near` Stable, resume when it died,
    the warning with its default, UTF-8 and string-table texts; a trainer with a queue does not
    move in stock, so walking away does not happen), `buildingWorkRateAuras` (`Maintain`; train, research and powers not tested);
  - **confirmed in the interface:** `overhealHitpointBars` (the unit panel's text and bar; the
    floating and group bars not compared on their own), `showGatherRate` (the stat panel row for
    berries; in WoL, 2026-11-04, the data ref and the unit panel row);
  - **confirmed in game:** `startingTC` (a marked building became the first town center of a player
    without one, and in WoL the `MaoriPa` replaced a dead `TownCenter`); a pending lifespan and the
    placement effect were not driven. The other `TownCenter` checks are not covered (question Q2 in [wol-requests.md](wol-requests.md)).
- **civFirstTC** (2026-10-29, single player): confirmed in game on a test map (editor route) and
  in skirmishes on Mongolia: the substitution, the first town center, the town starting units
  (with `StartingColonyBuilding` and `<starttypes>`), an untagged AI keeping its Town Center, and
  a shipment to the building through `hcShipmentPointFallback FirstTC`. Not tested: a Nomad start, WoL's
  civs and buildings, multiplayer, recorded games, the `no colony` log path. Not
  covered: AI scripts that expect a Town Center (a tagged AI stayed idle), the engine AI's
  automatic base, the age-up picker, the start camera, the `Maintain` spawn gate, the water
  shipment point.
