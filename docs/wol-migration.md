# Wars of Liberty on this DLL

**Private.** Never exported (`tools/export_public.py` bans the name).

## Goal

Wars of Liberty (WoL) runs entirely on this repo's `UHC.dll`, so WoL can replace its closed
`uhc.dll` (`c070d138`, [wol-uhc-map.md](wol-uhc-map.md)) with ours. Decided with the user on
2026-11-02. The order: first what keeps WoL from loading or playing, then what degrades play,
then cosmetics, then WoL's always-on fixes and multiplayer. The other direction (WoL rebuilds
our features inside its DLL) stays documented in [porting-to-another-dll.md](porting-to-another-dll.md).

Pick the next key from the table below.

## The test bed

`C:\AoE3-UHC-WoLReal` is a robocopy of `C:\WoL-Test` (a full WoL copy; the Steam folder is never
touched):

```
robocopy C:\WoL-Test C:\AoE3-UHC-WoLReal /E /MT:8 /XD avi "History Channel Trailers" AoE3-Mod-Launcher reshade-shaders /XF d3d9.dll ReShade.ini ReShade.log ReShadePreset.ini UHC.log Age3Log.txt
```

- WoL's DLL is kept as `uhc.dll.wol-orig`; ours is `UHC.dll` (the loader's
  `LoadLibraryA("UHC.dll")` finds either name). `wol.dll` (a 2016 market patcher nothing loads),
  `wolPlugin.upl` and `wolai.upl` stay: the plugins are what `customSyscalls` loads.
- ReShade's `d3d9.dll` is left out: `perfStats` hooks the D3D9 device. One run with it is part of
  the last phase.
- WoL's exe (`0a277f14`) passes our host guard. Its loader reads **`Startup\wol.cfg`** (string at
  VA 0xC65083), its AI folder is `AI4\`, its maps `RM4\`, and its `My Games` folder is
  `My Games\Wars of Liberty` (string 42265). `testbed.py profile` prints these;
  `deploy`, `map` and `scenario` use them.
- The bed's cfg is WoL's own (`Startup\wol.cfg.wol-orig`) plus `perfStats`, `customAbstractTypes`
  and `perfExecFile` (written by `deploy` from a scratch copy). WoL's cfg has no
  `customAbstractTypes` line because WoL's DLL reads `data\uhc\customabstracttypes.xml` always: a
  drop-in needs that one line added.
- `C:\WoL-Test` is the **control**: same data, WoL's own DLL. Use it for A/B runs and memory
  probes (`Start-Process C:\WoL-Test\age3y.exe -WorkingDirectory C:\WoL-Test`).
- The player profile is shared with the user's real WoL: `Documents\My Games\Wars of
  Liberty\Users3\NewProfile3.xml` (UTF-16, `optiongrfxres` 1920 x 1080). Backup:
  `NewProfile3.xml.bak-uhc-20261102` (`testbed.py profile backup`).
- `testbed.py safety record|check wol` checks the Steam WoL folder; the listing of 2026-11-02 is in
  `%TEMP%\uhc-wol-listing.tsv`.

### Which civs to test with

Only civs players can pick in the public game (user, 2026-11-03). **Not public**, kept only in the
data files: Tawantinsuyu (Incas), Tupinamba (Tupi), XPAztec (Aztecs). Public: WallMapu (Mapuche),
XPIroquois, XPSioux, Maori, Australians, and every European, Asian, American, Balkan and African
civ. The local data cannot tell: the civ picker lists a civ when an `AI4\*.personality` declares
its `<forcedciv>`, Tawantinsuyu has one (`wolTupac`), and an earlier audit of the mod gave XPAztec
one by hand (`wolMariano`). For native-civ features use WallMapu, the Iroquois or the Sioux. A
first `nativeCivs` test used Tawantinsuyu (2026-11-02); it was redone with WallMapu.

Tests run on the primary monitor (the user's "monitor 1"): `testbed.py` moves the game window
there at launch and before each real click (`UHC_TEST_MONITOR` changes it, `monitors` lists them).

### Driving a skirmish

`python -I tools/testbed.py --bed C:\AoE3-UHC-WoLReal profile hc <Civ>` picks the skirmish home
city (`LastSelectedSPHC`, game closed); `profile hc` lists the 60 saved ones. Restore
`sp_Addis Ababa_homecity.xml` after a test (the user's real WoL reads the same profile). In the home
city screen, "Administrar Metrópolis" opens the card view, whose "Restablecer" button resets the
city: never click near it.

The profile's home city is the Ethiopians (one of WoL's `asianCivs`). Client coordinates at
1920 x 1080: main menu "Un jugador" (257, 803), "Escaramuza" (689, 803), home city "Jugar"
(181, 1029), setup "Jugar" (477, 979); the map list opens at (1557, 437) and "Mapas ESOC" is
(1487, 635). Use ESOC maps: the user reports the `*NEW*` maps are broken. Wait 5 s between menu
clicks, 10–12 s before each "Jugar", about 55 s for the game to load.

## Progress

| Step | Result |
|---|---|
| Baseline, 2026-11-02 | Main menu reached; `6 applied, 0 failed`, 29 keys "not implemented yet". A skirmish crashed at 0x7C252C: a random-personality AI got a stock personality WoL does not ship, started with no civ, and the starting colony spawn read a null civ. |
| `noAILimitV2` | The skirmish loads (52 personalities from `AI4\`, the same table as WoL's DLL, read at 0x603C4F). Next failure: `aiLoaderStandard.xs` does not compile: `cUnitTypeAbstractWoLHandCavalry`. |
| `customAbstractTypes` | 47 types registered; next failure: `kbGetTechID`. |
| `customSyscalls` | Both plugins load (17 syscalls, 33 cheats collected). **The AI compiles and plays** (Indians: houses, settlers, monks fighting). Video: `wol-ai-plugins.mp4`, with `--perf` (about 350 fps, 2 frames over 50 ms in 30 s, main thread 93 %). |
| End of 2026-11-02 | `UHCMain: 23 applied, 0 failed` with WoL's cfg plus the bed's keys; 17 of WoL's keys still "not implemented yet" (29 at the start). Also confirmed in the bed: the restored `dodgeAnyUnit`, `dodgeChance` and `spreadAnyAccuracy` apply again. Next: farms (`enableFarmAnim`, `enableRectFarmAnim`, `farmingRadius`), `wonderCivUnitType`, `customProtoUnitCommands`, the Maori AI's kb syscalls. |
| `kbUnitSyscalls`, 2026-11-03 | **The Maori AI (Te Rauparaha) compiles and plays**: the last AI personality that did not. Its five syscalls are rebuilt on engine functions whose addresses come from the name table inside WoL's DLL (`wol-uhc-map.md`, "Engine symbol table"), each checked in the stock exe. |

## Keys

Status words as in the README. "Blocks" = WoL does not load or its AI does not play without it.

| Key | Origin | Effect on WoL without it | Status |
|---|---|---|---|
| `noAILimitV2` | WoL | blocks (crash with a random AI) | **done**, confirmed |
| (`customAbstractTypes`) | WoL, always on | blocks (AI compile); 47 types dropped from ~2,800 `<UnitType>` uses | **done**, confirmed |
| `customSyscalls wolPlugin.upl wolai.upl` | upstream | blocks (AI compile: `kbGetTechID` ×36 in `aiWoLMain.xs`; 36 `RM4\ESOC_*` maps) | **done**, confirmed |
| `customCheats` | upstream | cosmetic (33 plugin cheats) | **done**, confirmed (`kill 'em all`: 50 Cannons) |
| `asianCivs Egyptians Ethiopians Koreans Zulu Maori` | upstream | degrades: export, consulate, wonder age-up for those civs | **done**, confirmed (Koreans: five wonders in the age-up list) |
| `NativeCivs Tupinamba WallMapu Tawantinsuyu` | upstream | **blocks** for WallMapu (age-up crashes without it: stock code, 0x81A80C) | **done**, confirmed (WallMapu: council list, dances resolved) |
| `twoScoutCivs Koreans` | upstream | degrades | **done**, not reached in game yet (probably the new home city dialog) |
| `bigButtonCivs`, `noBigButtonBlds` | upstream | degrades | **done**, partly confirmed (hook reached) |
| `enableAllTeams` | upstream | degrades (teams 3/4) | **done** for single player, partly confirmed; MP lobby pending (needs a LAN test) |
| `wonderCivUnitType Rangatira` | WoL | **blocks** the Maori age-up (their Rangatira cannot start it without the key) | **done**, confirmed (voyage list opens; nothing without the key) |
| `marketUnits` | upstream | degrades (trade without a stock Market) | **done**, confirmed (`WOLMarketGreek`; refused without the key) |
| `explorerUnits` (40 triples) | upstream | degrades (hero names, KO text) | **done**, names confirmed (Korean monks Yi Sun and Kwon Hwan); 4 protos of WoL's cfg do not exist in its data |
| `enableFarmAnim`, `enableRectFarmAnim`, `farmingRadius` | upstream | cosmetic: placement and animation (the buildings gather anyway in WoL's data) | **done**, confirmed (Iroquois plantation and farm; radius measured). `Fazenda` gets no gatherers: its tactics only modify others |
| `customProtoUnitCommands` (always on in WoL) | WoL | degrades (55 command types; their `<Command>` buttons on 36 protos are dropped) | **done**, confirmed (Zulu youth: six transform buttons shown and run; none without the key; the maturing units became a Tradesman and a Bowman). WoL's cfg needs the line `customProtoUnitCommands`. The Fazenda's four tactic buttons (`page="9"`) also need the tactics gate (`tacticSwitching`, not in WoL's cfg; WoL's DLL does not patch that gate): check them in the control copy |
| `selectionLimit 75` | WoL | degrades | **done**, confirmed (75 of 89 Pikemen; 50 without) |
| `trainSingleAbstractType` | WoL | degrades (`AbstractTrainLimitOne`, 36 protos) | **done**, confirmed (Totenkopf hussars one at a time; a batch without the key) |
| `multiarmor` | WoL | degrades (32 protos, 76 effects) | **done**, confirmed (HonorGuard 38 vs 47.5 per pike hit; gwDreadnought + `GWantitorpedobulge`: each effect reaches its armor). Not kept in saved games; the panel shows the last armor |
| WoL-DLL kb syscalls (`kbUnitGetNumberTargeters`, …) | WoL, always on | blocks the Maori AI (`wolRauparaha`) only | **done**, confirmed (`kbUnitSyscalls`: Te Rauparaha compiles and plays; 6 visible workers on a hunt, 0 with the stock call; without the key `Error 0172` on `kbUnitGetCurrentInventory`). WoL's cfg needs the line `kbUnitSyscalls` (WoL's DLL has them always on) |
| `enablerandomtecheffect` | WoL | none in current data | pending |
| `betterfreedynamicunit` | WoL | degrades (about 55 techs with dynamic free units) | **done**, confirmed (7 vs 8 Sheep at 420 s) |
| `nowalkfarm` | WoL | cosmetic: gatherers wander around farms | **done**, confirmed (0 m vs 33–47 m per minute) |
| `repairWallGlobal` | WoL | degrades (the walls' `<command>repairWallGlobal</command>` button does nothing) | **done**, confirmed (three walls repaired) |
| `compatMode` | WoL | display: no 16-bit modes on current drivers | **done**, confirmed at startup |
| `attackTypeIcons`, `loadingScreenCount 28`, `flagoverrideeffect`, `optionhighpolycliff`, `alpha2coverage`, `map` / `uhcSyncTrack` | upstream / WoL | cosmetic | pending |

The data scan behind the table (2026-11-02): WoL has 3,634 protos, 10,542 techs and 168 civs;
nothing in its data keeps the stock exe from loading (unknown types and effects are dropped).
The subtypes `ROF`, `GathererLimit`, `MinimumRange` and `Bounty` in `Data` effects need a check of
FUN_008F973F before deciding whether a key is needed.

## Re-recording the earlier features in WoL (from 2026-11-03)

The features made before the migration were filmed in the TAD test copies, several before the
`--perf` rule. Each is filmed again in `C:\AoE3-UHC-WoLReal` with WoL's data, `--perf`, and a WoL
civ that fits it; the video is `docs/media/<key>-wol.mp4` (+ GIF), next to the TAD one.

| Key | WoL setup (civ / unit) | Status |
|---|---|---|
| `healNonIdle` | Iroquois: `xpMedicineMan` heals a `xpTomahawk` fighting a Musketeer (`healNonIdle xpMedicineMan`) | **done**: healed between hits and wins; without the key it dies at about 60 s (`healNonIdle-wol*.mp4`, redone 2026-11-03 with `--select` and `--crop 0.45`). The WallMapu `MapucheShaman` does not heal even idle units in WoL |
| `smartHealTargets` | United States: `NAnurse` and four settlers hit to 90/70/45/33 % (`smartHealTargets log`) | **done**: heals 33 % first, then 45, 70, 90 %; without the key it starts with the query's first, at 45 % (`smartHealTargets-wol*.mp4`). Filmed with `record --frame 1 --select Settler,NAnurse --crop 0.4` (still camera, HP bars, close-up) |
| `dodgeAnyUnit`, `dodgeChance` | Koreans or Japanese monks / a WoL light infantry | pending |
| `damageOverTime` | WallMapu or Iroquois archers with a poison attachment | pending |
| `spreadAnyAccuracy` | a WoL shotgun / grenade unit | pending |
| `liveBuildingWorkRate`, `buildingWorkRateAuras` | an Asian civ (Japanese, Chinese) production building | pending |
| `techPrereqRecheck`, `maintainWaitForPop` | Ottomans (auto-produced units), a `TypeCount` tech | pending |
| `transformUpdatesLOS`, `transformInventory` | a WoL transform (Zulu maturing, wagons) | pending |
| `broadsideMuzzleLimit` | a WoL ship with a barrage attack | pending |
| `abilitySlots`, `wonderPanelSkipAuras` | an explorer with many powers; a Japanese wonder with auras | pending |
| `lifespanAfterConstruction`, `gaiaSocketsOnly` | a WoL temporary building; a trade/native socket | pending |
| `customHotkeyContexts` | a WoL building with its own keymap context | pending |
| `snareOnlyHitUnit` | a WoL snare attack on a group | pending |
| `techRenameEffect` | a WoL tech that renames | pending |
| `noCorpseDopples` | WoL hunts | pending |
| `danceBonusCivs`, `nativeCivs` dances | WallMapu fire pit | pending |
| `startingTC`, `civFirstTC` | a WoL civ with its own first TC | pending |
| `noTrainNearEnemyTC` | a WoL TC with enemy units near | pending |
| `overhealHitpointBars`, `overhealSources`, `overhealDecay` | WoL infantry with overheal | pending |
| `showGatherRate` | a WoL gatherer | pending |
| `hcShipmentPointFallback` | a WoL shipment with its gather point lost | pending |
| `decimalPopulation`, `basePop` / `extraPop`, `deckCardCount` | WoL units with decimal pop; a big deck | pending |
| `customRevolutionBanners`, `removeFameRestriction`, `removeConversionRestriction` | the WoL keys of these upstream features | pending |
| `bufferedFileReads`, `multipleInstances` | load time; two copies | pending |

## WoL's always-on patches (inventory, 2026-11-03)

WoL's DLL changes 287 ranges of the running game (`rea/evidence/wol-uhc-c070d138/wol-memdiff.txt`).
`attribute.py` there matches them against our sites (76 at sites we patch), `installers.py` finds
the WoL function that installs each of the other 211, and `rtti_owner.py` names its feature class
(`installers_named.txt`). The `.rdata` block at 0xB84000 is the import table (filled at load, not a
patch).

| WoL feature (class) | Patches | What, from the sites | Ours |
|---|---|---|---|
| ExtendedDataSubtypes / AdditionalTechEffects (installers 0x10079850, 0x10076180, 0x1007AC70) | 0x525BA0, 0x526D60, 0x5F215C, 0x620C24, 0x622F44, BDataEffect calls 0x7F86FE..0x7F87A8 | new Data effect subtypes (`ROF`, `GathererLimit`, `MinimumRange`, `Bounty` in WoL's data) | pending (next) |
| GatherFix | 0x4EC8DE, 0x4ECC8E | gathering on a fixed interval (WoL's balance assumes it: stock gathers 56% more on trees) | **done** (`gatherFix`; WoL's cfg needs the line) |
| ROFFix | 0x9CECB4 | an order clears the unit's attack timer | **done** (`rofFix`), not seen in a test |
| StunMovingTargetFix | 0x9E909E | a stun ends when the target check fails | **done** (`stunMovingTargetFix`), not seen in a test |
| FallenHeroTacticsFix | 0x6AAE6D, 0x7D8F07, 0x9D6BE7, 0x9EBB0B | four resets of the unit AI's tactic to 0 | **done** (`fallenHeroTacticsFix`), not seen in a test |
| NoKnockoutDanceBonusHealFix | 0x679FBA, 0x6A5C35..0x6A5CE2 | NOPs a `0x4802C6` test (0x679FBA) and the `hasPlacer` tests, and replaces `hasSpecificPlacer` with a version that also checks `isSingleUse` (WoL 0x10048E40) | pending (RE) |
| ModifyActionFix | 0x49F252, 0x9E36D0 | retypes the tactics-driven modifier class 2Ch → 46h (0x9E36D0) and collects both types at 0x49F251 (WoL 0x1004A330 calls the collector for 2Ch and 46h) | pending: our modifier walk (`modifiers.h`) must then take 46h too |
| DisableEffectOnTechFix | 0x94CE4C, 0x94CEBC | keeps the tech flag bit 1 that 0x94CE4F clears, and sets it again only around the `techStatusActive` call at 0x94CEBB (WoL 0x10049660, 0x10049690) | pending (purpose not clear yet) |
| DoubleShipmentsInspectFix | 0x71063D, 0x9A652D | marks the load of string 37461 (the shipment cost text, 0x71063C) and wraps 0x9A5658 for another player's view (WoL 0x10047960, 0x10047990) | pending (UI) |
| NoDamageOnUnbuiltFoundations | 0x49B3F3 | unbuilt foundations take no damage | **done** (`noDamageOnUnbuiltFoundations`), hook reached; not seen (no foundation in the test) |
| CivSpecificTextTechRollover | 0x4C7481, 0x81A5CB | tech rollover text per civ | pending (cosmetic) |
| FlagOverride | 11 sites (0x451FAF, 0x4B9ED4, 0x5EE665, ...) | `flagoverrideeffect` | pending (cosmetic key) |
| HighPolyCliff | 25 calls of `BDataSet::getData` (0x7B6F79..0x7C0B82, 0x82E9CE) | `optionhighpolycliff` | pending (cosmetic key) |
| MoreLoadingScreens | 0x538A3E, 0x538A59, 0x648D4D | `loadingScreenCount` | pending (cosmetic key) |
| SyncTracker | 20 sites (0x494D4F, 0x4E237C.., 0x6AE5A8..) | `uhcSyncTrack` | pending (cosmetic key) |
| BroadsideNoTurn | 0x4C0EB8, 0x4C142C, 0x5030FE, 0x503579 | `unrandomizeBroadsideAttack` (commented out in WoL's cfg) | not needed |
| ProtoUnitExtension | 0x51D7E0, 0x6206C0, 0x698BFF, 0x69B34F, 0x86FDE4; the proto ctor/dtor/copy calls | extends the proto object (`multiarmor`, ...) | done our way (`multiarmor`) |
| MPSaveAndRestore, AI debug commands, AdditionalLogging, Temp | 0x7DC13F, 0x7E5B28; 0x5335DD..; 0x5F62B4; 0x67DE5B | multiplayer save, debug | later |
| Upstream caves (installer 0x1002B580, 0x1002C380) | 0x4904B5, 0x4ECD6B, 0x5126C1, 0x8D0318, 0x8D47C9, 0x8DABA3, 0x77674A; 0x51C945, 0x5C2287, 0x5EE78B, 0x699D31, 0x69B909 | `nativeCivs`, name checks, `enableAllTeams` (MP), `attackTypeIcons` | done our way, except `enableAllTeams` MP and `attackTypeIcons` |
| Syscall groups (0x10072DB0, 0x1006FC00) | 0x535486, 0x53562E, 0x5B7995, 0x6148C7, 0x627340, 0x96FC7B | registration of its syscalls | done our way (`customSyscalls` registry) |
| Lobby / ESOC UI | 0x8AC970..0x8BC55A, AMPPlayerSlot ctor/dtor 0x775E36, 0x775FCD | ESOC lobby, observer, diplomacy | ask WoL's team |
| Not identified yet | 0x404FD5, 0x4060D2 (`BGame::update`), 0x4099BC/0x415587/0x44ED3F (-> 0x4203AB), 0x450B30/0x459C58, 0x4EF2E5 (BUnitBuildAction ctor), 0x511AD9, 0x562AD7, 0x58D9E4, save/load chunks (0x62DCD0, 0x765FC9, 0x83212D, 0x83228A, 0x8329B9, 0x835085), 0x8310A4 / 0x912xxx, BPlayer ctor/dtor calls, 0x6A3C08, 0x6A3C90, 0x7D1727, 0x7DE90E | | to study |

## Performance

Rules: [developer-guide.md, section 4](developer-guide.md#4-definition-of-done) (A/B per key with a
hot path, `--perf` in every video, vary the civ).

| Run | Copy | fps avg | frames > 50 ms | main CPU | Notes |
|---|---|---|---|---|---|
| 2026-11-02, 30 s, early game, Ethiopians vs AI Indians | WoLReal (ours) | ~350 | 2 | 93 % | `record --perf-csv` during the `customSyscalls` video |

Pending: the A/B baseline against the control (`perfprobe.py`, 120 s, same scenario), and the
load-time A/B for `customAbstractTypes`.

## Civs used in tests

| Test | Civ / unit |
|---|---|
| AI skirmish, `customSyscalls` | player: Ethiopians; AI: Indians (Bahadur Shah) |
| `asianCivs` wonders, `explorerUnits` names | Koreans (Hanseong): villager, WOLMonkKorean, WOLMonkKorean2 |
| `marketUnits` | scenario: WOLMarketGreek (Greek market) |
| `gatherFix` | scenario: 4 Settlers on a Mill, 3 on trees; perf A/B with 40 on 4 Mills |
| `betterfreedynamicunit` | skirmish on a test map (RM4 in My Games, removed after): Argentineans, `Corderos` (−2 Sheep) |
| `nowalkfarm` | scenario: 4 Settlers on a Mill |
| `repairWallGlobal` | scenario: 3 WallStraight5 damaged to 1200, resources granted |
| `multiarmor` | scenario: HonorGuard vs Pikemen; gwDreadnought (sea map) with `GWantitorpedobulge`; perf A/B with 160 units (HonorGuard, WoLVoltigero, Pikeman, Musketeer) |
| `customProtoUnitCommands` | scenario, player Ethiopians: Zulu `AFRICANyouth` (transforms to Tradesman and Bowman); Brazilian Fazenda (tactics page, not shown) |
| `kbUnitSyscalls` | AI skirmish: player Australians (Melbourne); AI Maori, personality Te Rauparaha (other personalities moved aside so the random pick is that one; the clicks on the AI slot opened nothing) |
| `wonderCivUnitType` | Maori (Parihaka): Rangatira, voyages |
| `trainSingleAbstractType` | Germans (Age0German, age IV): WOLTotenkopfHussar at a Barracks (scenario) |
| farms | XPIroquois: WOLPlantationIroquois, WOLFarmIroquois (scenario); Brazilian Fazenda (not gatherable) |
| `nativeCivs`, `bigButtonCivs` | WallMapu (Perquenco): Town Center council; control without the key crashes |
| `selectionLimit` | scenario: 89 Pikemen |
| `customCheats` | Ethiopians: 50 Cannons |
