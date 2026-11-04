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
civ that fits it; the video is `docs/media/<key>-wol.mp4` (+ GIF). Once a feature has its WoL
videos, its TAD GIF and MP4 are deleted (user rule, 2026-11-03). Filming (2026-11-04): camera height
by console, `record --background --crop 960x640 --master`, GIF from the lossless master at native
pixels, 2x speed, 10 fps, cut to the key moment.

| Key | WoL setup (civ / unit) | Status |
|---|---|---|
| `healNonIdle` | Iroquois: `xpMedicineMan` heals a `xpTomahawk` fighting a `WOLLineInfantry` (`healNonIdle xpMedicineMan`) | **done**: healed between hits and wins; without the key it dies at about 57 s (`healNonIdle-wol*.mp4`). The WallMapu `MapucheShaman` does not heal even idle units in WoL |
| `smartHealTargets` | United States: `NAnurse` and four settlers hit to 90/70/45/33 % (`smartHealTargets log`) | **done**: heals 33 % first, then 45, 70, 90 %; without the key it starts with the query's first, at 45 % (`smartHealTargets-wol*.mp4`). |
| `dodgeAnyUnit`, `dodgeChance` | Japanese villagers (`ypSettlerJapanese`, rule 50 % `notech ranged`), a European `Settler` with `dodgeAnyUnit` (stock 15 %, `YPDodge`), an unmarked `ypSettlerIndian`, vs 3 `Redcoat` | **done**: 18 of 31 Japanese rolls dodged, the Settler dodges at 15 %, the Indian dies first; keys off, nobody dodges (`dodge-wol*.mp4`). Soldiers shoot back and end the fight too soon; villagers do not |
| `damageOverTime` | Iroquois: 3 `xpAenna` with poison arrows (`dot_testdata.py --wol`, restored after) vs 1 `Landsknecht` | **done**: ticks of 12 (x3 stacks), the last one kills it at 36 s, no archer lost; key off, it lives until 45 s, 1 archer lost (`damageOverTime-wol*.mp4`) |
| `spreadAnyAccuracy` | 4 `Escopetero` (WoL's own spread tags, no data edit) vs 8 `WOLScytheman` | **done**: every shot logged as a ground shot at r = 3 m; survivors' HP 800 / 562 with the key vs 827 without, so no clear damage change in a melee-range fight (`spreadAnyAccuracy-wol*.mp4`) |
| `liveBuildingWorkRate` | African civ TC training `AFRICANvillager`; test tech `UHCBwrTest` (BWR x3 on TownCenter, appended to techtreey, restored after) at 30 s | **done**: 13 villagers by 94 s vs 8 by 96 s without the key (5 at start) (`liveBuildingWorkRate-wol*.mp4`). WoL's own BWR techs did not fit: the Krupp factory's Maintain spawns take minutes, and the daimyos (`WOLHCKazoku`) train nothing in age I |
| `buildingWorkRateAuras` | African civ, two TCs training `AFRICANvillager`; an Explorer with a test aura (`UHCBwrAura`, BWR x3, 10 m, in `explorer.tactics`, restored after) beside one | **done**: the aura TC trains 7 vs 2 for the other; key off, 2 each (`buildingWorkRateAuras-wol*.mp4`) |
| `techPrereqRecheck` | Ethiopians (Menelik II); test tech `UHCTypeCountDock` (1 Dock, Explorer HP x0.5, appended, restored after), Dock created at 24 s | **done**: 400 to 200 HP in the same update; key off, 400 kept (`techPrereqRecheck-wol*.mp4`). WoL's `WOLEnableInfanteDeMarina` (Age0Spanish, 1 Dock) is the real case, but its unit needs age II and a fort |
| `maintainWaitForPop` | WoL's `Age0Ottoman` (TC `MaintainSettlersOttoman`), pop 11/10, 2 settlers killed at 70 s (`maintainWaitForPop TownCenter log`) | **done**: held at 62 s, released at once at 70 s; key off, the next settler ~23 s later (`maintainWaitForPop-wol*.mp4`) |
| `transformUpdatesLOS` | Romanians: WoL's `ShiftingCalarasToVanator` (Calarashi 15 to Vanator 22) at 26 s | **done**: LOS 22 with the key, 15 without (`transformUpdatesLOS-wol*.mp4`). `WOLHCItaliaIrredenta` was tried first: it assigns the new LOS in its own data, so it shows no bug |
| `transformInventory` | Ethiopians: WoL's `HCCardDogTaxWar` turns 2 `PetWolf` into `CrateofCoin` | **done**: `Moneda: 100.0` in the panel with the key, no inventory without (`transformInventory-wol*.mp4`) |
| `broadsideMuzzleLimit` | Japanese `ypTekkousen` (created in game: a loaded scenario keeps the saved slots) vs 2 `Fluyt`, `ceylon coast` | **done**: 10 slots per side with the key, 6 without; a scan of 17 WoL warships found no other model above 6 per side (`broadsideMuzzleLimit-wol*.mp4`) |
| `abilitySlots` | Ethiopians: WoL's Explorer (8 abilities), `WOLAbilityHeal` at 24 s and `WOLHCMachiavellianism` at 30 s | **done**: buttons 7 and 8 appear with the key, never without (`abilitySlots-wol*.mp4`) |
| `wonderPanelSkipAuras` | Korean wonders `wolwkpyongyanggate2` (test: `ypPowerShrineAura` put before its `PowerRighteousArmy` in `abilities.xml`, restored after) and `wolwkpuyonghall2` | **done**: the panel shows Righteous Army with the key, the Puyong Hall's Whirlpool without (`wonderPanelSkipAuras-wol*.mp4`). WoL has no wonder with two abilities in its own data |
| `lifespanAfterConstruction` | Spanish (`Age0Spanish`): 2 settlers build an Outpost given `Lifespan` 15 (bed protoy, restored after), placed with a real click (`tis("Outpost")` + `rclick`) | **done**: built at 59 s, gone 15 s later; key off, dies as a foundation (`lifespanAfterConstruction-wol*.mp4`). WoL's own `*Maturing` buildings are not built by any unit in protoy |
| `gaiaSocketsOnly` | none | **not filmed**: the case it fixes is an AI build plan given a player-owned socket; the UI refuses that placement by itself and neither the console nor scenario triggers can give the order. Needs an AI skirmish whose script builds on such a socket |
| `customHotkeyContexts` | Greeks (`Age0Greeks`, `Player : SetAge` 1): `WOLBarracksGreek` selected, 3 real `o` presses (WoL's `WOLBarracksGreekAccel` maps `o` to Klepht) | **done**: 3 Klephts queued with the key, none without (`customHotkeyContexts-wol*.mp4`) |
| `snareOnlyHitUnit` | British: 6 `Redcoat` marching (Move From Area) vs 1 `Uhlan` (`handCavalry.tactics` snare), map 160 m | **done**: the group arrives at 50 s with the key, ~54 s without; mean position 123 vs 117 m at 41-42 s (`snareOnlyHitUnit-wol*.mp4`, samples in `rea/evidence/age3y-b1a1dab7/snareOnlyHitUnit-wol-groupx-*.txt`) |
| `techRenameEffect` | Ethiopians: test tech `UHCRenameTest` (`SetTechName` on `GreatWarButton`, appended, restored after) at 22 s; `record --hover` keeps the GW button's rollover on screen | **done**: "Declarar Guerra Total" becomes "Sierra de tajo"; key off (also without WoL's `enabletechrenameeffect` line, the same key), unchanged (`techRenameEffect-wol*.mp4`). WoL's data has no `SetTechName` effect today |
| `noCorpseDopples` | WoL's own `Doppled` Deer and Bison (no data edit), 3 `WOLRanger` watch then leave; `noCorpseDopples Deer log` | **done**: dead deer vanish into the fog, dead bison stay; key off, all stay (`noCorpseDopples-wol*.mp4`) |
| `danceBonusCivs` | Ethiopians: 10 settlers do the `FertilityDance` (enabled by an appended test tech, restored after) while the TC trains `AFRICANvillager` | **done**: 4 trained by 65 s with the key, 2 without (`danceBonusCivs-wol*.mp4`) |
| `startingTC` | Japanese `ypDaimyoMototada` against the Maori: player 2 of a scenario has `Age0Maori`, so its `TownCenter` dies at once; `MaoriPa` placed by the map (`startingTC MaoriPa`, `noTrainNearEnemyTC 40`), fog off | **done**: the Pa replaces the dead TC, the Daimyo holds at 18 m until it falls; without the key it trains (`startingTC-wol*.mp4`) |
| `civFirstTC` | Ethiopians with `<firstTC>EGYtowncenterCARAVAN</firstTC>` (bed `civs.xml`, restored after), a test map that places `TownCenter` | **done** on a test map: the caravan instead of the TC, FirstTC; no town starting units, the flag is not on it (`civFirstTC-wol*.mp4`). A skirmish is pending |
| `noTrainNearEnemyTC` | Japanese `ypDaimyoMototada` (age III, `YPAge0JapaneseUnits`) training Kihei, an enemy `Settler` 12 m away killed at 48 s (`near Settler`); `near Stable` with the warning and a text of its own (`-near-wol`, `-warn-wol`); FirstTC in `startingTC-wol` | **done for `near` units**: paused, resumed when it dies; key off, trained at once (`noTrainNearEnemyTC-wol*.mp4`). **FirstTC not filmed in WoL:** in this bed's scenarios player 2's buildings do not last (a `TownCenter` is rubble at once, a `Stable` and a `Barracks` are gone by the first check; cause not found, player 2's civ may be Maori, whose `Age0Maori` gives TC a 0.5 s Lifespan). The TAD videos of FirstTC, `near Stable` and the warning stay in the guide |
| `overhealHitpointBars`, `overhealSources`, `overhealDecay` | Iroquois: `xpTomahawk` marked, 150 of 180 HP, `xpMedicineMan` source healer (bed protoy, restored after), `xpAenna` unmarked; `overhealDecay 2 3` | **done**: hit, healed to 180, `Overheal: 30/30` in the unit panel (the `stat` row, through `unitpanel.cpp`), the healer dies at 62 s, back to 150; a nurse and the Regeneration dance stop at 150, 180 without the key; Menelik stays at 400, 447 and rising without the key (`overheal*-wol*.mp4`). The portrait bar needs a fourth bar gadget in `uiunitselectionmin.xml`, so WoL's interface does not show that part |
| `showGatherRate` | Ethiopian villager on berries | **done**: `Food (icon): 0.67/s` in WoL's unit panel with no data change. With `optionminimizedui`, the user's setting, the exe skips the stat panel fill, so since 2026-11-04 the key also writes the unit panel's rate gadgets (hook 0x699456). The normal interface (TAD copy) still gets the stat panel row. With several units selected no rate shows, in both interfaces (`showGatherRate-wol*.mp4`) |
| `hcShipmentPointFallback` | a WoL shipment with its gather point lost | pending |
| `decimalPopulation` | Ethiopians: `AFRICANvillager` 1.5, `HouseAfrican` +7.5 (bed protoy, restored after) | **done**: `17.5 / 17.5`, queue waits; key off, `14 / 17`, queue goes on (`decimalPopulation-wol*.mp4`) |
| `basePop` / `extraPop` | three `BloodFactory` (+100 each) | **done**: `6 / 300`, `6 / 200` without the key (`basePop-wol*.mp4`) |
| `deckCardCount` | a big deck | pending |
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

## Language of the bed

Since 2026-11-04 the bed runs in WoL's original English, so new videos are in English:
`data\stringtabley.xml` is `translations\_originals\stringtabley.xml` (md5 `33fa355c…`, the same file as
Steam's WoL). The user's Spanish one is kept as `data\stringtabley.xml.es-la`. Videos filmed before that
date show the Spanish interface, and their captions quote it.

## Civs used in tests

**Scenario player 2 has `Age0Maori`:** its `TownCenter` gets `Lifespan` 0.5 and dies at once, and other buildings stay (2026-11-04). That was the "player 2's buildings do not last" of the earlier notes. Console `fog()` and `blackmap()` turn the fog off, so that an enemy building shows on video.

Enemy units rotate too (user rule, 2026-11-03): no more `Musketeer` as the opposing unit. Use
WoL's own infantry, a different one each test, from the public civs: ranged `WOLLineInfantry`,
`Redcoat`, `WOLJaeger`, `Grenzer`, `Highlander`, `WOLRegular`, `WOLForeignLegion`, `GreenJacket`,
`Sarbaz`, `Jawan`, `WOLFlankeur`, `Seimen`, `WOLRanger`; melee `WOLLandwehr`, `WOLScytheman`,
`WOLPicket`, `Landsknecht`, `Doppelsoldner`, `Azap`.

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
