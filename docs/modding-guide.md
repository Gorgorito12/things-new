# Modding guide for Wars of Liberty

How to add these features to Wars of Liberty (WoL): what each one does in WoL, the `wol.cfg` line and
the WoL data it needs, how to check it in the game, and how far it was tested in WoL.

This page is private, as WoL's own files are. For the code of each feature, written for WoL's DLL, see
[porting-to-another-dll.md](porting-to-another-dll.md). For how the features work inside the engine,
see [how-it-works.md](how-it-works.md). To build the DLL, see
[developer-guide.md](developer-guide.md).

Contents:
- [Latest changes](#latest-changes): every feature, newest first, with day, date and time
- [Adding these features to WoL](#adding-these-features-to-wol): start here
1. [What you need](#1-what-you-need)
2. [WoL's folder](#2-wols-folder)
3. [The wol.cfg file](#3-the-wolcfg-file)
4. [Reading UHC.log](#4-reading-uhclog)
5. [Feature reference](#5-feature-reference)
6. [Editing the game data](#6-editing-the-game-data)
7. [Multiplayer, saved games and replays](#7-multiplayer-saved-games-and-replays)
8. [WoL's keys that are not implemented](#8-wols-keys-that-are-not-implemented)
9. [Troubleshooting](#9-troubleshooting)

## Latest changes

Every feature, newest first, with the day, date and time of its latest change (the commit's
local time). The details are in the feature's section, under its heading.

A new test video counts as a change: a feature filmed again in WoL moves back to the top.

| Date and time | Key | What changed | Status |
|---|---|---|---|
| Wednesday 2026-11-04 10:29 | [`overhealHitpointBars`](#overhealhitpointbars) | Filmed in WoL, with a control. The HP bars and HP texts of marked units take `InitialHitpoints` as 100 %, not `MaxHitpoints`. | `MaxHitpoints` above `InitialHitpoints` on those units (no unit has it today), and the unit type on them, or an existing type such as `AbstractCavalryInfantry`. |
| Wednesday 2026-11-04 10:29 | [`overhealSources`](#overhealsources) | Filmed in WoL, with a control. Only source healers heal those units above `InitialHitpoints`; every other heal stops there. | `overhealHitpointBars`, and the source unit type on the healers that may overheal. |
| Wednesday 2026-11-04 10:29 | [`overhealDecay`](#overhealdecay) | Filmed in WoL, with a control. The HP of those units above `InitialHitpoints` goes back down to it over time. | `overhealHitpointBars`. |
| Wednesday 2026-11-04 09:59 | [`decimalPopulation`](#decimalpopulation) | Filmed in WoL, with a control. Population with decimals: `<PopulationCount>0.5`, `<PopulationCapAddition>7.5` and decimal amounts in their tech effects; the counter and the tooltips show them. | The decimals in `protoy` and `techtreey`. |
| Wednesday 2026-11-04 09:54 | [`noTrainNearEnemyTC`](#notrainnearenemytc) | Filmed in WoL, with a control. Marked units (the Daimyos and the Shogun by default) do not train while they stand near an enemy's first Town Center or an enemy building of a `near` type, with a warning over your own held units; the queue resumes when the blocker dies. | Nothing for the Daimyos; with a new marker, that type on the trainers (or on the blocking buildings) in `protoy`. |
| Wednesday 2026-11-04 09:20 | [`showGatherRate`](#showgatherrate) | Filmed in WoL, with a control. Shows a gathering unit's rate per second in the stat panel, and through the data ref `{currentUnitGatherRateString}`. | Nothing; for the data ref, a `formatText` gadget in your UI. |
| Wednesday 2026-11-04 08:32 | [`customHotkeyContexts`](#customhotkeycontexts) | Filmed in WoL, with a control. Makes keymap contexts named `<ProtoName>Accel` work, such as WoL's `WOLBarracksGreekAccel`. | Those contexts in `data\DefaultKeyMapY.xml`; WoL's file already has three. |
| Wednesday 2026-11-04 08:32 | [`techRenameEffect`](#techrenameeffect) | Filmed in WoL, with a control. The tech effect `SetTechName`: a tech gives another tech a new name, rollover and help text, for the players it reaches only. | `<Effect type='SetTechName' …/>` in a tech, and the string IDs in `stringtabley.xml`. |
| Wednesday 2026-11-04 08:32 | [`lifespanAfterConstruction`](#lifespanafterconstruction) | Filmed in WoL, with a control. Starts the `<Lifespan>` of marked buildings when their construction is finished, not when the foundation is placed. | A `<Lifespan>` on the buildings, and the unit type on them (or a type or proto name in the cfg). |
| Wednesday 2026-11-04 08:11 | [`danceBonusCivs`](#dancebonuscivs) | Filmed in WoL, with a control. Lets the civs you list get the fire pit's Training, XPTrickle, Gathering and Regeneration dances, which the exe applies only to `XPIroquois`, `XPSioux`, `XPAztec` and `XPSPC`. | A building with `AbstractFirePit`, its dance enabled for those civs, and villagers that can work on it. |
| Wednesday 2026-11-04 08:11 | [`snareOnlyHitUnit`](#snareonlyhitunit) | Filmed in WoL, with a control. A snared unit no longer slows the group it moves with; only the hit unit slows. | Nothing. |
| Wednesday 2026-11-04 08:11 | [`maintainWaitForPop`](#maintainwaitforpop) | Filmed in WoL, with a control. When a marked building's automatic production finishes a unit while its player is at the population cap, keeps the unit and spawns it as soon as there is room. | That unit type on the producing buildings in `protoy`, or the name of an existing type or proto. |
| Wednesday 2026-11-04 08:11 | [`transformUpdatesLOS`](#transformupdateslos) | Filmed in WoL, with a control. A unit transformed in place (a `TransformUnit` tech effect, a revolution) takes the line of sight of its new proto. | Nothing. |
| Wednesday 2026-11-04 08:11 | [`transformInventory`](#transforminventory) | Filmed in WoL, with a control. A unit transformed in place (a `TransformUnit` tech effect, a revolution) takes its new proto's `InitialResource` when the two protos hold different resource types. | Nothing; with a new marker, that type on the target protos. |
| Wednesday 2026-11-04 08:11 | [`abilitySlots`](#abilityslots) | Filmed in WoL, with a control. Lets the command panel show up to N abilities per unit instead of 6. | Units with more than 6 abilities in `abilities.xml`. |
| Wednesday 2026-11-04 08:11 | [`wonderPanelSkipAuras`](#wonderpanelskipauras) | Filmed in WoL, with a control. The wonder power panel shows a wonder's first available ability that is not a passive aura, instead of only its first ability. | The power listed after the aura in `abilities.xml`, on an `AbstractWonder` with an `Abilities` command. |
| Wednesday 2026-11-04 08:11 | [`noCorpseDopples`](#nocorpsedopples) | Filmed in WoL, with a control. A dead unit of a marked type (a hunt's carcass) leaves no frozen copy in the fog of war. | `<Flag>Doppled</Flag>` on those protos, and the unit type in the cfg (`Huntable` needs no data change). |
| Wednesday 2026-11-04 07:31 | [`liveBuildingWorkRate`](#livebuildingworkrate) | Filmed in WoL, with a control. Makes `BuildingWorkRate` techs (train, research and `Maintain` speed) apply to buildings that already stand, not only to those completed after the tech, and `TrainPoints` techs to units already queued or in training. | Nothing. |
| Wednesday 2026-11-04 07:31 | [`buildingWorkRateAuras`](#buildingworkrateauras) | Filmed in WoL, with a control. Lets auras and other stat modifiers use the `ModifyType` `BuildingWorkRate`, which scales train, research and `Maintain` speed. | An `AutoRangedModify` action (or a power) with that `ModifyType`. |
| Wednesday 2026-11-04 07:31 | [`techPrereqRecheck`](#techprereqrecheck) | Filmed in WoL, with a control. Re-checks techs whose prerequisites count units (`<TypeCount>`) when units are created or die, not only at the player's next house, age-up or tech change. | Techs with `<TypeCount>` prerequisites in `techtreey` (stock data has none). |
| Wednesday 2026-11-04 07:20 | [`healNonIdle`](#healnonidle) | Filmed in WoL, with a control. Lets healers marked with a unit type heal units that are busy (moving, fighting or doing something else). | That unit type on the healers in `protoy.xml`, or the name of an existing type (`xpMedicineMan`, `AbstractMonk`). |
| Wednesday 2026-11-04 07:20 | [`dodgeAnyUnit`](#dodgeanyunit-dodgesoundset-and-criticalsoundset), [`dodgeSoundSet`](#dodgeanyunit-dodgesoundset-and-criticalsoundset), [`criticalSoundSet`](#dodgeanyunit-dodgesoundset-and-criticalsoundset) | Filmed in WoL, with a control. Lets units marked with a unit type dodge hits like the Japanese monk (no damage, 15 % of the hits, while their player has `YPDodge`). | That unit type on the units in `protoy.xml`, or a type or proto name in the cfg, and `YPDodge` active for their players. |
| Wednesday 2026-11-04 07:20 | [`dodgeChance`](#dodgechance) | Filmed in WoL, with a control. A dodge chance per unit type, with the tech it needs (or none) and a filter for ranged or melee hits; the first matching rule decides. | A unit type or proto name in the cfg, and the rule's tech active for their players unless `notech`. |
| Wednesday 2026-11-04 07:20 | [`damageOverTime`](#damageovertime) | Filmed in WoL, with a control. Poison: an attack that names an attachment proto keeps damaging its target every few seconds after the hit. | `<AttachProtoUnit>` on the attack, a new attachment proto in `protoy.xml`, and a small tactics file. |
| Wednesday 2026-11-04 07:20 | [`spreadAnyAccuracy`](#spreadanyaccuracy) | Filmed in WoL, with a control. Reads `<maxspread>` and `<spreadfactor>`, which 317 of WoL's tactics files have and the exe ignores, for every miss, and makes every shot of marked units scatter like that whatever their accuracy, dealing its area damage where it lands. | The tags are there; a `<DamageArea>` on the attacks that should always scatter, and their unit type or proto name in the cfg. |
| Wednesday 2026-11-04 06:59 | [`smartHealTargets`](#smarthealtargets) | Filmed in WoL, with a control. A healer's automatic search heals the best candidate, not the first: listed unit types, then the lowest HP ratio, the nearest, the lowest unit ID. | Nothing (unit types or proto names are optional). |
| Tuesday 2026-11-03 14:51 | [`broadsideMuzzleLimit`](#broadsidemuzzlelimit) | Filmed in WoL, with a control. Lets a ship's broadside fire from up to N muzzles per side instead of 6. | A ship model with more than 6 muzzles per side: `ypTekkousen` has 10. |
| Tuesday 2026-11-03 11:26 | [`rofFix`](#roffix-stunmovingtargetfix-nodamageonunbuiltfoundations-and-fallenherotacticsfix), [`stunMovingTargetFix`](#roffix-stunmovingtargetfix-nodamageonunbuiltfoundations-and-fallenherotacticsfix), [`noDamageOnUnbuiltFoundations`](#roffix-stunmovingtargetfix-nodamageonunbuiltfoundations-and-fallenherotacticsfix), [`fallenHeroTacticsFix`](#roffix-stunmovingtargetfix-nodamageonunbuiltfoundations-and-fallenherotacticsfix) | Added. Four small combat fixes: orders keep the attack timer, stuns survive a moving target, unbuilt foundations take no damage, units keep their tactic when knocked out. | Nothing. |
| Tuesday 2026-11-03 11:15 | [`gatherFix`](#gatherfix) | Added. Gatherers collect on a fixed interval, so the gather rate is the data's and not the animation's. | Nothing. |
| Tuesday 2026-11-03 10:43 | [`compatMode`](#compatmode) | Added. Offers every 32-bit display mode as a 16-bit mode too. | Nothing. |
| Tuesday 2026-11-03 10:43 | [`nowalkfarm`](#nowalkfarm) | Added. Gatherers on a farm keep the spot they take. | Nothing. |
| Tuesday 2026-11-03 10:43 | [`betterfreedynamicunit`](#betterfreedynamicunit) | Added. Dynamic free units grow smoothly with game time, not in 2-minute steps. | Nothing. |
| Tuesday 2026-11-03 10:43 | [`repairWallGlobal`](#repairwallglobal) | Added. A UI syscall that repairs every wall of the local player. | A button or hotkey that calls `repairWallGlobal()`. |
| Tuesday 2026-11-03 09:33 | [`multiarmor`](#multiarmor) | Added. A proto keeps one armor per damage type, and `Armor` tech effects change the one their `damagetype` names. | Several `<Armor>` lines on the protos. |
| Tuesday 2026-11-03 08:39 | [`customProtoUnitCommands`](#customprotounitcommands) | Added. Adds the command types (buttons) listed in `data\uhc\customprotounitcommands.xml` (55 today). | The file, and the `<Command>` lines that use them. |
| Tuesday 2026-11-03 08:16 | [`kbUnitSyscalls`](#kbunitsyscalls) | Added. Five KB syscalls for AI scripts: a unit's inventory, its workers and its targeters. | AI scripts that call them. |
| Tuesday 2026-11-03 07:25 | [`wonderCivUnitType`](#wondercivunittype) | Added. `Rangatira` may start the Maori age-up. | Nothing. |
| Tuesday 2026-11-03 07:25 | [`trainSingleAbstractType`](#trainsingleabstracttype) | Added. Marked units leave a training building one at a time, not as a batch. | That unit type on the protos. |
| Tuesday 2026-11-03 06:49 | [`enableFarmAnim`](#enablefarmanim-enablerectfarmanim-and-farmingradius), [`enableRectFarmAnim`](#enablefarmanim-enablerectfarmanim-and-farmingradius), [`farmingRadius`](#enablefarmanim-enablerectfarmanim-and-farmingradius) | Added. Mill and Rice Paddy gathering on more buildings, and a gather area per building. | Nothing. |
| Monday 2026-11-02 21:22 | [`customSyscalls`](#customsyscalls) | Filmed in WoL, with a control. Loads `wolPlugin.upl` and `wolai.upl` and adds the XS syscalls they register. | The plugins. |
| Monday 2026-11-02 21:19 | [`nativeCivs`](#nativecivs) | Added. WallMapu, Tupinamba and Tawantinsuyu count as native civs: fire pit, dances and council age-up. | Those civs' data. |
| Monday 2026-11-02 21:19 | [`bigButtonCivs`](#bigbuttoncivs-and-nobigbuttonblds), [`noBigButtonBlds`](#bigbuttoncivs-and-nobigbuttonblds) | Added. Gives the command panel's big button to the listed civs, and takes it from the listed buildings. | Nothing. |
| Monday 2026-11-02 21:10 | [`twoScoutCivs`](#twoscoutcivs) | Added. The Koreans get the interface of the civs that start with two heroes. | A second hero. |
| Monday 2026-11-02 21:10 | [`marketUnits`](#marketunits) | Added. Owning a unit of a listed proto counts as owning a Market. | Nothing. |
| Monday 2026-11-02 21:10 | [`explorerUnits`](#explorerunits) | Added. Listed protos get a hero's name and knockout message. | The string IDs. |
| Monday 2026-11-02 20:47 | [`customCheats`](#customcheats) | Added. The cheats of WoL's plugins work in the chat. | `customSyscalls`, and plugins that register cheats. |
| Monday 2026-11-02 20:40 | [`enableAllTeams`](#enableallteams) | Added. Teams 3 and 4 in the single-player game setup. | Nothing. |
| Monday 2026-11-02 20:33 | [`selectionLimit`](#selectionlimit) | Added. A selection holds up to N units (50 in the exe). | Nothing. |
| Monday 2026-11-02 20:27 | [`asianCivs`](#asiancivs) | Added. Egyptians, Ethiopians, Koreans, Zulu and Maori count as Asian civs: consulate, export and wonders. | Those civs' data. |
| Monday 2026-11-02 20:04 | [`customAbstractTypes`](#customabstracttypes) | Added. Turns every name in `data\uhc\customabstracttypes.xml` (47 today) into an abstract unit type that protos, techs, auras and XS scripts can use. | The file. |
| Monday 2026-11-02 19:51 | [`noAILimitV2`](#noailimitv2) | Added. Shows WoL's 52 `AI4\*.personality` files in game setup. | The personality files. |
| Thursday 2026-10-29 12:03 | [`civFirstTC`](#civfirsttc) | Added. A civ's `<firstTC>Proto</firstTC>` in `civs.xml` replaces the `TownCenter` that random maps place for its players (not in a Nomad start); that building is their first town center (`FirstTC`) and receives their town starting units. | The tag in `civs.xml`; for the town starting units, `<Flag>StartingColonyBuilding</Flag>` on the proto and the proto in `placementrules\colonies.xml` `<starttypes>`; for shipments, `hcShipmentPointFallback FirstTC`. |
| Thursday 2026-10-29 10:35 | [`startingTC`](#startingtc) | Added. Lets buildings of a marked type be a player's first town center, the unit the placement rules call `FirstTC` (no enemy building within 65 m), not only a `TownCenter`; one also replaces a first town center that is gone, dead or about to expire. | That unit type on the starting buildings in `protoy` (e.g. `MaoriPa`), or an existing type or proto name in the cfg. |
| Thursday 2026-10-29 06:39 | [`gaiaSocketsOnly`](#gaiasocketsonly) | Added. Lets a socketed building (TradingPost, or a mod's) be placed only on a socket that Gaia owns, as the placement preview already shows. | Nothing for the global rule; with a new marker, that type on the sockets in `protoy`. |
| Wednesday 2026-10-28 19:12 | [`multipleInstances`](#multipleinstances) | Added. Lets this copy of the game run while a copy from another folder is running. | Nothing. |
| Wednesday 2026-10-28 16:34 | [`bufferedFileReads`](#bufferedfilereads) | Added. Reads the game's files through a read-ahead buffer instead of millions of tiny reads, for fewer and shorter stutters and faster loading. | Nothing. |
| Wednesday 2026-10-28 12:48 | [`hcShipmentPointFallback`](#hcshipmentpointfallback) | Added. When the building holding the shipment point dies and none of the 10 stock fallback types (Town Center, Outpost, forts, …) is left, moves the point to the first alive building of the types you list, or to the player's first town center (`FirstTC`). | Nothing beyond the proto names in the cfg; `FirstTC` needs `startingTC` or `civFirstTC`. |
| Wednesday 2026-10-28 10:56 | [`ignoreRegistryPath`](#ignoreregistrypath) | Added. Reads the game data from WoL's folder (the exe's folder), and not from the Steam install in the registry. | Nothing. |
| Wednesday 2026-10-28 10:56 | [`basePop`](#basepop-and-extrapop), [`extraPop`](#basepop-and-extrapop) | Added. Raises the population caps (200 and 50 in the exe) and removes the 250 hard cap. | Enough population buildings: 20 houses of 10 give 200 today. |
| Wednesday 2026-10-28 10:56 | [`deckCardCount`](#deckcardcount) | Added. Raises the 25-card deck cap. | A higher `<maxdecksize>` in `data\homecitylevels.xml` (25 at all 132 levels today). |
| Wednesday 2026-10-28 10:56 | [`noAILimit`](#noailimit) | Added. Shows every `AI4\*.personality` file in game setup. | The personality files. |
| Wednesday 2026-10-28 10:56 | [`customRevolutionBanners`](#customrevolutionbanners) | Added. Shows a banner for each of WoL's 29 `XPRevolution<Name>` techs, not only O'Higgins. | A banner texture per revolution. |
| Wednesday 2026-10-28 10:56 | [`removeFameRestriction`](#removefamerestriction) | Added. Shows Fame, XP and shipment costs on politician screens, and Fame/XP icons on home city cards. | Two icon textures. |
| Wednesday 2026-10-28 10:56 | [`removeConversionRestriction`](#removeconversionrestriction) | Added. Lets `ConvertGuardian` convert any unit, not only treasure guardians. | Nothing. |

## Adding these features to WoL

There are two ways. In both, the `wol.cfg` lines and the data edits of this guide are the same.

**1. Add the feature to WoL's own `uhc.dll` (the way to ship).** WoL's DLL has features this project
does not have yet ([section 8](#8-wols-keys-that-are-not-implemented)), so WoL keeps its DLL and adds
the code of the features it wants. [porting-to-another-dll.md](porting-to-another-dll.md) has that
code, with the patch sites, the expected bytes and how to check each one.

**2. Run WoL on this project's `UHC.dll` (the way to try a feature).** Every video in this guide was
filmed like this, on a copy of WoL. It takes five minutes, and it is how to see a feature working
before porting it:

1. **Work on a copy of the WoL folder,** never on the one your players use. Keep the copy complete.
2. **Keep WoL's DLL:** rename `uhc.dll` to `uhc.dll.wol-orig`.
3. **Copy this project's `UHC.dll` next to `age3y.exe`.** Build it as
   [developer-guide.md](developer-guide.md#1-build) says. WoL's exe needs no patch: it already has the
   loader, and its `LoadLibraryA("UHC.dll")` finds the file whatever the case of its name.
4. **Add these lines to `Startup\wol.cfg`.** WoL's DLL does these things always, and this DLL only
   when asked:

   ```
   customAbstractTypes
   customProtoUnitCommands
   kbUnitSyscalls
   gatherFix
   rofFix
   stunMovingTargetFix
   noDamageOnUnbuiltFoundations
   fallenHeroTacticsFix
   ```

5. **Add the lines of the features you are trying,** with the data each section asks for.
6. **Start the copy's `age3y.exe`,** then read `UHC.log` next to it
   ([reading the log](#4-reading-uhclog)):
   - the first lines are `UHC.dll x.y.z` and `UHCMain: working directory <the copy>`;
   - every key you added says `applied`;
   - seven of WoL's own keys say `not implemented yet`
     ([section 8](#8-wols-keys-that-are-not-implemented)). That is expected.

To go back, delete `UHC.dll` and rename `uhc.dll.wol-orig`.

**What this way does not cover yet.** Besides the seven keys, WoL's DLL has work this one has not
rebuilt: the `Data` tech subtypes `ROF`, `GathererLimit`, `MinimumRange` and `Bounty`, a group of
smaller fixes, multiplayer save and restore, and the ESOC lobby. Do not ship WoL on this DLL. The
list is in [wol-migration.md](wol-migration.md#wols-always-on-patches-inventory-2026-11-03).

**Notes:**
- **Multiplayer:** nothing here has been tested in multiplayer, and every player needs the same
  files ([section 7](#7-multiplayer-saved-games-and-replays)).
- **Home cities and the profile** live in `Documents\My Games\Wars of Liberty`. A copy of WoL shares
  them with the real one. A copy that starts with other settings can change your resolution
  ([section 9](#9-troubleshooting)).

## 1. What you need

- **A complete WoL folder.** WoL's `age3y.exe` has the SHA-256 `0a277f14e08df516…`: it is the stock
  game with the UHC loader and WoL's own patches (`AI3` to `AI4`, `RM3` to `RM4`, large address
  aware). The DLL checks the exe at startup and does nothing if the build is different.
- **To port a feature:** WoL's DLL source, and [porting-to-another-dll.md](porting-to-another-dll.md).
- **To try a feature on this DLL:** the `UHC.dll` of this repository. It needs Visual Studio with the
  C++ tools and CMake ([developer-guide.md](developer-guide.md#1-build)).
- **Python 3 and the `tools/` folder** only if you edit XMB or BAR files
  ([section 6](#6-editing-the-game-data)). WoL's data is plain XML, so most keys need neither.

### Getting an exe with the UHC loader

You don't need to: WoL's exe already has it. The loader calls `_UHCMain@0` in `UHC.dll` before the
game's own startup code, and reads the path of the cfg from the exe, which in WoL's exe is
`Startup\wol.cfg`. The exact bytes are in [binaries.md](binaries.md).

If something goes wrong:
- **`host is not a UHC-patched age3y.exe`:** the exe is a different build, and the DLL does nothing.
- **The loader shows *Failed to load UHC.dll!* and the game exits:** the DLL is missing, or a library
  it needs is. This project's DLL needs the Visual C++ runtime only if it was built with it.
- **No `UHC.log` at all:** the DLL next to the exe is WoL's. It writes no `UHC.log`.

## 2. WoL's folder

```
Wars of Liberty\
    age3y.exe            WoL's exe, with the UHC loader
    uhc.dll              WoL's DLL, or this project's during a test
    uhc.dll.wol-orig     WoL's DLL, kept during a test
    UHC.log              written by this project's DLL; it grows by one block on every start
    Startup\wol.cfg      the features to enable. The Startup\uhc.cfg next to it is not read.
    AI4\  RM4\           WoL's AI scripts and random maps (AI3\ and RM3\ are not read)
    data\                WoL's data: XML, tactics, BAR archives
    data\plugins\        wolPlugin.upl and wolai.upl, loaded by customSyscalls
    data\uhc\            customabstracttypes.xml, customprotounitcommands.xml
    art\                 WoL's art
```

- **Where the data comes from.** WoL's `wol.cfg` has [`ignoreRegistryPath`](#ignoreregistrypath), so the
  game reads the data of the folder it started from, and not the Steam install's.
- **The working directory.** This DLL makes the exe's folder the working directory at startup. A
  double-click, a shortcut and a launcher all start the mod the same way.
- **User files:** `Documents\My Games\Wars of Liberty` holds the profile, the home cities, the saved
  games, the scenarios and the game's own logs.

## 3. The wol.cfg file

`Startup\wol.cfg` selects the features. The syntax below is this DLL's, and it also reads every line
of WoL's own file as it is.

- **Syntax:** one key per line, followed by its arguments, separated by spaces or tabs. The form
  `basePop=500` also works.
- **Case:** keys are case-insensitive (`NativeCivs` = `nativeCivs`). Arguments keep their case.
- **Comments:** a line whose first word starts with `#`, and anything after `//`, even at the end of a
  line. A `#` later in a line is **not** a comment: in `deckCardCount 40 # more cards`, the words `#`,
  `more` and `cards` are arguments.
- **One line per key:** a key that takes values reads only its first line. Write
  `hcShipmentPointFallback` once, with all its names. The exceptions: `dodgeSoundSet`,
  `criticalSoundSet`, `danceBonusCivs` and `perfAutoExec` read every line, and
  `broadsideMuzzleLimit` and `noTrainNearEnemyTC` refuse a second line.
- **Unknown keys:** a key this DLL does not handle, whether one of WoL's or a misspelling, is logged in
  lowercase as `<key>: not implemented yet; ignored`.
- **Absent keys** leave the game as it is.

## 4. Reading UHC.log

`UHC.log` is appended on every start; delete it before a test to read a single run.

| Line | Meaning |
|---|---|
| `UHC.dll x.y.z` | The version of the DLL that wrote this run. Always the first line of a run. |
| `UHCMain: working directory <folder>` | The DLL made the exe's folder the working directory ([section 2](#2-wols-folder)). |
| `UHCMain: <path>, N keys` | The cfg was read; N distinct keys. |
| `UHCMain: host is not a UHC-patched age3y.exe; doing nothing` | Wrong exe. See [section 1](#getting-an-exe-with-the-uhc-loader). |
| `UHCMain: cannot read <path> (error N); no features applied` | The cfg is missing or unreadable. |
| `<feature>: applied` | The feature patched the game. |
| `<feature>: FAILED` | It did not. The line before says why (bad arguments, or the next row). |
| `<feature>: site <Name> at 0x… does not hold the stock bytes; feature not applied` | The exe differs from the stock build at that address. Nothing was written there. |
| `<key>: not implemented yet; ignored` | A key this DLL does not handle: one of WoL's ([section 8](#8-wols-keys-that-are-not-implemented)), or a misspelled key. |
| `UHCMain: N applied, M failed` | The summary of this start. |
| `hook reached: <name> (0x…)` | The first time the game ran that patched code. Use it to confirm that a feature is really used in a game. |

Feature-specific lines are listed in each section below.

## 5. Feature reference

Each feature that works in game shows a short clip of a test, with the live numbers (game time, hit points, LOS and the feature's own `log` lines) drawn over it by `tools/testbed.py record`, and a link to the full recording.

Each section gives the `wol.cfg` line, what changes in the game, what WoL's data must provide, how to
confirm it works, and its test status. "Simulation" says whether every player in a multiplayer game
needs the same setting ([section 7](#7-multiplayer-saved-games-and-replays)).

The tables have a column, **WoL's DLL**:

| Value | Meaning |
|---|---|
| **in `wol.cfg`** | WoL's DLL has it, and WoL's cfg turns it on. There is nothing to port. |
| **in WoL's DLL** | WoL's DLL has it, but WoL's cfg does not use it. |
| **always on** | WoL's DLL does it with no cfg line. This DLL needs the line. |
| **new** | WoL's DLL does not have it. Its code is in the [porting guide](porting-to-another-dll.md). |
| **for tests** | A tool for testing a mod. Don't port it. |

The features are grouped by what they change. Each group starts with a table of its keys;
each feature's section starts with the day, date and time it was added. [Latest changes](#latest-changes) lists them all by date.

- [Game files and startup](#game-files-and-startup): Where the game reads its data, how it reads it, and how it starts.
- [Population, decks and limits](#population-decks-and-limits): Caps that are fixed in the exe.
- [New data and scripting](#new-data-and-scripting): New names the game's data and scripts can use.
- [Civs](#civs): What the exe decides by civ.
- [Healing and hit points](#healing-and-hit-points): Who heals, whom, and how far.
- [Combat](#combat): Attacks, armor, and what a hit does.
- [Gathering and farms](#gathering-and-farms): Resources, gatherers, and what pays for them.
- [Buildings and training](#buildings-and-training): How buildings train, spawn, live and get replaced.
- [Techs and transforms](#techs-and-transforms): What happens when a tech activates or a unit changes proto.
- [Interface](#interface): What the panels and the fog of war show.

No feature has been tested in multiplayer yet.

### Game files and startup

Where the game reads its data, how it reads it, and how it starts.

| Key | What it does | WoL's DLL | WoL also needs | In-game status |
|---|---|---|---|---|
| [`ignoreRegistryPath`](#ignoreregistrypath) | Reads the game data from WoL's folder (the exe's folder), and not from the Steam install in the registry. | **in `wol.cfg`** | Nothing. | confirmed |
| [`bufferedFileReads`](#bufferedfilereads) | Reads the game's files through a read-ahead buffer instead of millions of tiny reads, for fewer and shorter stutters and faster loading. | **new** | Nothing. | confirmed (single player) |
| [`multipleInstances`](#multipleinstances) | Lets this copy of the game run while a copy from another folder is running. With `background`, its window stays behind every other window and never takes the focus. | for tests | Nothing. | confirmed (two copies, single player) |
| [`compatMode`](#compatmode) | Offers every 32-bit display mode as a 16-bit mode too. | **in `wol.cfg`** | Nothing. | confirmed |

#### ignoreRegistryPath

**Added:** Wednesday 2026-10-28 10:56

```
ignoreRegistryPath
```

- **Effect:** the game uses its current working directory as the install folder, and not the path
  stored in the registry, which is the Steam install. `wol.cfg` has this line, and WoL does not load
  without it. Since this DLL makes the exe's folder the working directory at startup, the game reads
  WoL's data however it is started.
- **WoL needs:** nothing.
- **Check:** WoL's data loads. This key writes no `hook reached` line, because it only rewrites one
  branch.
- **Simulation:** no.
- **Status:** confirmed: every test in this guide depends on it.

#### bufferedFileReads

**Added:** Wednesday 2026-10-28 16:34

```
bufferedFileReads [<KB>] [verify]      default 64 KB
```

- **In WoL today:** the exe reads the archives (`art\Art*.bar`, `data\Data*.bar`, `sound\*.bar`, …) and
  the loose files a few bytes at a time, with one Windows read call for every 1 to 16 bytes. WoL reads
  far more loose files than the stock game (all its XML and 622 tactics files). When a match needs a
  model or an animation it has not loaded yet, those reads run inside the frame, and the frame stalls
  (a stutter).
- **Effect:** every file the game opens for reading only gets a read-ahead buffer. One Windows read
  fills the buffer, and the game's small reads are served from memory. The game receives the
  same bytes.
- **Measured** in a late 8-AI game of the stock game ([performance.md](performance.md), §9,
  "bufferedFileReads A/B"), on a 150 s recording. It was not measured in WoL yet:

  | | Without | With |
  |---|---|---|
  | Frames over 100 ms | 11 | 3 |
  | Frames over 50 ms | 19 | 11 |
  | Longest frame | 251 ms | 116 ms |
  | Time in file reads, whole session (most of it loading) | 14.9 s | 1.0 s |

- **What it does not fix:** most of the remaining stutter is the animation library (granny)
  setting up the model it just read. That is processing work, not reading.
- **WoL needs:** nothing.
  - `<KB>` (4 to 1024) is the buffer size per open file.
  - `verify` also reads every buffered request from the file for real and compares the two. It is
    a correctness test and makes reading slower.
- **Log:**
  - at startup, `bufferedFileReads: read-only files get a 64 KB read-ahead buffer (multiplayer-safe: same bytes)`;
  - with `verify`, at exit: `bufferedFileReads verify: N buffered reads checked, M mismatches`.
    M must be 0.
- **Simulation:** no. It changes how the bytes are fetched, not which bytes, so players do not
  need the same setting.
- **Status:** confirmed in single player, on the stock game: on a 25-minute save, `verify` checked 7.5
  million buffered reads against the file and found no mismatch. Not tested in WoL or in multiplayer.

#### multipleInstances

**Added:** Wednesday 2026-10-28 19:12

```
multipleInstances [background]
```

A tool for testing, not for WoL's players: nothing needs porting.

- **In WoL today:** one copy of the game per machine. A second copy, even one started from another
  folder, stops at "Only one copy of the game can run at a time".
- **Effect:** this copy no longer collides with copies in other folders. Two copies started from the
  same folder still refuse each other, because they would share that folder's files (`UHC.log`, the
  `perfExecFile` file, …). Only one of the two copies needs the key.
- **`background`:** this copy's windows open behind every other window, stay there and never take the
  focus. The copy cannot cover another window or receive the clicks and keys meant for it. This is
  for unattended tests driven through `perfExecFile`
  ([developer guide](developer-guide.md#driving-the-game-unattended)). Define
  `config("DontPauseWhenLosingFocus")` too: a game in progress pauses whenever its window is not
  focused, which with `background` is always.
- **Shared files:** every copy of WoL uses the same `Documents\My Games\Wars of Liberty` folder: the
  profile (the last copy to exit writes it), saved games, scenarios and the game's own `Age3Log.txt`.
  Give saves and scenarios different names in each copy.
- **WoL needs:** nothing.
- **Log:**
  - at startup, `multipleInstances: this copy may run beside copies in other folders (semaphore suffix -XXXXXXXX)`;
  - when the game checks for another copy, `multipleInstances: single-instance semaphore "…" renamed to "…-XXXXXXXX"`;
  - with `background`, one line per window: `multipleInstances background: window of class … placed at the bottom, never activated`.
- **Simulation:** no.
- **Status:** confirmed on 2026-10-28 with two copies on one machine.
  - A copy with `multipleInstances background` started while a copy without the key sat at the main
    menu. It loaded a 25-minute save and ran a 60 s benchmark at 179 FPS (195 when alone).
  - Its log showed the stock name `Global\Age3` renamed to `Global\Age3-BCD865D7`.
  - Sampled every second, its window stayed second from the bottom of 50 windows and was never the
    focused window. The copy without the key did take the focus when it started.
  - Every video in this guide marked `--background` was filmed with this key, on the WoL copy.
  - Not tested: three or more copies, multiplayer.

#### compatMode

**Added:** Tuesday 2026-11-03 10:43

```
compatMode
```

- **Effect:** every 32-bit display mode the graphics card reports is also offered as a 16-bit mode.
  Current drivers report only 32-bit modes, so the game's list has no 16-bit entry. `wol.cfg` has
  this line.
- **Log:** `compatMode: 32-bit display modes are also offered at 16 bits`; at startup, `hook
  reached: compatMode (0x54D6D1): <W>x<H> also offered at 16 bits`.
- **Simulation:** display only.
- **Status:** confirmed (2026-11-03): the hook runs at startup for the adapter's modes and the game
  starts and plays normally.

### Population, decks and limits

Caps that are fixed in the exe.

| Key | What it does | WoL's DLL | WoL also needs | In-game status |
|---|---|---|---|---|
| [`basePop`, `extraPop`](#basepop-and-extrapop) | Raises the population caps (200 and 50 in the exe) and removes the 250 hard cap. | in WoL's DLL | Enough population buildings: 20 houses of 10 give 200 today. | partly confirmed |
| [`decimalPopulation`](#decimalpopulation) | Population with decimals: `<PopulationCount>0.5`, `<PopulationCapAddition>7.5` and decimal amounts in their tech effects; the counter and the tooltips show them. | **new** | The decimals in `protoy` and `techtreey`. | confirmed (single player, also a skirmish vs AI) |
| [`deckCardCount`](#deckcardcount) | Raises the 25-card deck cap. | in WoL's DLL | A higher `<maxdecksize>` in `data\homecitylevels.xml` (25 at all 132 levels today). | confirmed above the level table; see the section |
| [`selectionLimit`](#selectionlimit) | A selection holds up to N units (50 in the exe). `wol.cfg` sets 75. | **in `wol.cfg`** | Nothing. | confirmed |
| [`noAILimit`](#noailimit) | Shows every `AI4\*.personality` file in game setup. WoL uses `noAILimitV2` instead. | in WoL's DLL | The personality files. | confirmed |
| [`noAILimitV2`](#noailimitv2) | Shows WoL's 52 `AI4\*.personality` files in game setup. Without it, a random AI crashes the game. | **in `wol.cfg`** | The personality files. | confirmed |
| [`enableAllTeams`](#enableallteams) | Teams 3 and 4 in the single-player game setup. | **in `wol.cfg`** | Nothing. | partly confirmed |

#### basePop and extraPop

**Added:** Wednesday 2026-10-28 10:56

```
basePop <N>              N from 0 to 10000, stock 200
extraPop <N>             N from 0 to 10000, stock 50
```

- **In WoL today:** `wol.cfg` does not set these keys, so the exe's limits apply. The cap is what the
  player's buildings provide (houses, Town Centers, …), limited to 200 plus the extra population
  granted by techs and cards, which is itself limited to 50. It is also limited to that extra
  population plus a world-level value of 200. Then a player bonus is added, and the result never
  exceeds 250.
- **Effect:** the 200 becomes `basePop`, the 50 becomes `extraPop`, and the world-level clamp and the
  250 cap are removed. Either key alone keeps the other at the exe's value.
- **WoL needs:** buildings must still provide the population. WoL's `House`, `Manor`, `HouseAztec` and
  `ypHouseIndian` give 10 each with a `BuildLimit` of 20, so to reach 300 raise one of the two in
  `protoy.xml`.
- **Not changed:** the shared team population mode keeps the exe's limit of 200 per player.
- **With [`decimalPopulation`](#decimalpopulation):** both limits stay in whole population
  (`basePop 300` is 300 population with any K).
- **Log:** `basePop/extraPop: base X, extra Y (…)`;
  `basePop/extraPop: expected integers from 0 to 10000`;
  `hook reached: basePop/extraPop/decimalPopulation (0x4581F3)`.
- **Simulation:** yes.
- **Status:** partly confirmed, on the stock game: a skirmish went past 200 with `basePop 300`; the
  limit reached was the number of houses that could be built. Not filmed in WoL yet.
- **Fixed from UHC 1.10:** upstream missed the path taken when the extra population is negative,
  where the stock 200/250 limits stayed active.

#### decimalPopulation

**Added:** Thursday 2026-10-29 21:24 · **Filmed in WoL:** Wednesday 2026-11-04 09:59

![decimalPopulation in WoL](media/decimalPopulation-wol.gif)

*In WoL, with `decimalPopulation 10 log` (Ethiopians, the Town Center selected):* in the bed's data, for
the test, a villager costs 1.5 population and a house gives 7.5. The panel reads `17.5 / 17.5` with 11
villagers and the Explorer, and the next villager in the queue waits: there is no room for 1.5.
[Full video (MP4)](media/decimalPopulation-wol.mp4).

![decimalPopulation in WoL, key off](media/decimalPopulation-wol-control.gif)

*In WoL, key off (the same data):* the exe drops the decimals: a villager costs 1 and the house gives 7,
so the panel reads `14 / 17` with 13 villagers and the queue goes on.
[Full video (MP4)](media/decimalPopulation-wol-control.mp4).

![decimalPopulation and the population limits](media/decimalPopulation-caps.png)

*The limits:* a test tech gives `PopulationCap` +300 at 12 population. With `decimalPopulation 10` the cap stops at the exe's 200; with `basePop 300` added, at 300; with `basePop 300` alone (the control), at 300, the decimals dropped (6 population).

```
decimalPopulation [<K>] [log]      K from 2 to 1000, default 10: population in steps of 1/K
```

- **In WoL today:** `<PopulationCount>` and `<PopulationCapAddition>` are whole numbers. The exe reads
  them with `%d`, so `0.5` becomes 0 (a free unit) and `7.5` becomes 7, with no message. WoL's `Kami`
  has `<PopulationCount>0.5</PopulationCount>` and is free for that reason. A player's population,
  the population its queues reserve and its cap are sums of them, and every test (can this unit be
  queued, can it spawn, is the player at the cap) compares those sums.
- **Effect:** both tags take decimals, and population works in steps of 1/K. Inside the engine
  every population number is kept K times larger, so all of its tests stay exact:
  - **tech effects:** `PopulationCount` and `PopulationCapAddition` (on protos) and
    `PopulationCap` (on the player) take decimal amounts (`amount='0.5'`). `Absolute` adds the
    amount and `Assign` sets it, rounded to the nearest step; `BasePercent` is rounded to the
    nearest step too (the exe truncates it, so a decrease came out one step high: 1.5 × 0.6 gives
    0.9, the exe's formula 1.0); `Percent` multiplies by a whole number, as in the exe. A
    `PopulationCount` effect that would bring a unit to 0 or less still gives it 1, as in the exe.
    WoL's `techtreey.xml` has 97 `PopulationCount`, 44 `PopulationCapAddition` and 20
    `PopulationCap` effects;
  - **limits:** the cap keeps the exe's limits (200 from buildings, plus 0 to 50 extra, at most 250),
    or those of [`basePop` and `extraPop`](#basepop-and-extrapop), in whole population;
  - **interface:** the population counter (`{totalPop} / {popcap}`, and `{pop}` and `{futurepop}`) and
    its tooltip show decimals (`16.5 / 17.5`), and so do the population cost in unit tooltips (red when
    it does not fit), the unit help (`Population: 0.5`) and the population of a shipment;
  - **AI and scripts:** XS still sees whole numbers. `kbGetPop`, `kbGetPopCap`,
    `trPlayerGetPopulation`, `aiGetEconomyPop`, `aiGetMilitaryPop`, `aiGetAvailableEconomyPop`,
    `aiGetAvailableMilitaryPop`, `aiGetCurrentEconomyPop`, `aiGetPopNeeds`, `kbGetPopCapAddition`
    and `kbGetPopulationSlotsBy{QueryID,UnitTypeID}` return the population rounded to the nearest
    whole number (halves away from zero); `kbGetPopSlots` (a unit's cost) rounds up, so a unit
    that costs population never reads as 0 (an AI script may divide by it);
    `kbUnitPickGet{Minimum,Maximum}Pop` round, and keep −1 as −1. `aiSetEconomyPop`,
    `aiSetMilitaryPop` and `kbUnitPickSet{Minimum,Maximum}Pop` take whole numbers as before (−1
    stays −1).
- **WoL needs:** the decimals, in the two tags and in the effect amounts. With the key, `Kami` costs
  0.5 and stops being free: decide if that is what you want. Whole numbers behave exactly as without
  the key. A UI gadget that shows `{pop}`, `{popcap}`, `{futurepop}` or `{totalPop}` now gets text
  such as `12.5` instead of a number; that is fine in a `formatText` gadget, which is how WoL uses
  them.
- **Choosing K:** 10 for one decimal (0.5, 1.5), 100 for two (0.25), or any value from 2 to 1000.
  Texts show up to three decimals, trailing zeros dropped (K = 3 shows 0.333).
- **Not adapted:** the post-game timeline's population curves draw K times the population: a player
  with 9 population is drawn at 90 (seen in game). The AI's debug text (`AIDebugPopToggle`) does the
  same (read in the code, not seen).
- **Saved games** keep the population as stored: load them with the same K. A game saved without
  the key, or with another K, loads with wrong populations.
- **Log:** at startup `decimalPopulation: population in 1/10 steps (<PopulationCount> and
  <PopulationCapAddition> take decimals; caps (stock limits), effects, 19 XS syscalls and the
  population texts scaled)` (`(basePop/extraPop limits)` with those keys; `, decimal values and
  changes logged` with `log`); `decimalPopulation: expected a scale from 2 to 1000 and/or log, got
  "x"`. Hooks: `hook reached: decimalPopulation <PopulationCount> (0x5FB92E)`,
  `… <PopulationCapAddition> (0x5FD719)`, `… effect PopulationCount (0x8FA835)`,
  `… effect PopulationCapAddition (0x8FA8CF)`, `… PopulationCap effect (0x8D87AB)`,
  `… start cap bonus (0xA0D2D1)`, `basePop/extraPop/decimalPopulation (0x4581F3)`,
  `… data ref totalpop` (and `popcap`, `futurepop`, `pop`), `… colorizePop argument (0x6F576F)`,
  `… printed population (unit help, costs)` (and `(colorizePop)`, `(population help)`), and one
  `… XS <name>` per syscall. With `log` (at most 200 lines): each decimal value read
  (`decimalPopulation: Settler <PopulationCount>1.5</PopulationCount> = 1.5`), each effect
  (`decimalPopulation: effect PopulationCount, relativity 2, amount 0.6: 1.5 -> 0.9`; relativity 1
  is `Absolute`, 2 `BasePercent`, 3 `Assign`), and each XS setter's value when it changes
  (`decimalPopulation: aiSetEconomyPop(80) stored as 800`).
- **Simulation:** yes: every player needs the same key and the same K. Not tested in multiplayer.
- **Status:** confirmed in single player.
  - **In WoL (2026-11-04):** Ethiopian villagers at 1.5 and a house at 7.5, K = 10: the panel reads
    `17.5 / 17.5` and the next villager waits; without the key, `14 / 17` and the queue goes on.
  - **On the stock game (2026-10-29),** K = 10 and 100, with the data of
    [`tools/pop_testdata.py`](../tools/README.md#pop_testdatapy): training refused and allowed at the
    right sums, the four effect modes, `PopulationCapAddition` and `PopulationCap`, the counter, its
    tooltip and the tooltips' cost in red, a saved game (K = 100, saved at 17 / 20, loaded at
    17 / 20), bad values (`1`, `abc`, `5000` log the error and `FAILED`), shipment tooltips, the
    shared team population, and all 19 XS syscalls. Three skirmishes against two Hard AIs ran with no
    XS error, and a Russian AI reached 62.5 population of a 95 cap.
  - **Not run:** multiplayer; taking back a `PopulationCap` effect (0x8D20AB): a trigger that sets the
    tech's status back does not take its effects back, and no path that does was found; the unit help
    `Population: %d` (FUN_004C8748).

#### deckCardCount

**Added:** Wednesday 2026-10-28 10:56

```
deckCardCount <N>        N from 20 to 10000
```

- **In WoL today:** `wol.cfg` does not set this key, so the exe's cap applies. The maximum deck size of
  a home city is the `<maxdecksize>` of its level in `data\homecitylevels.xml`, clamped to 20..25. A
  home city whose level is past the end of that table gets 25. WoL's table has 132 levels, all with
  `<maxdecksize>25</maxdecksize>`.
- **Effect:** the upper clamp becomes N instead of 25, and levels past the table get N.
- **WoL needs:** to reach N cards at normal levels, raise `<maxdecksize>` in `data\homecitylevels.xml`,
  which is plain XML in WoL. Without that edit, only home cities above the last level (131) get N
  cards.
- **Check:**
  - a deck can only hold cards that its home city has unlocked, so a 40-card deck also needs a home
    city with at least 40 unlocked cards, i.e. a high level;
  - in the deck screen, the deck must accept more than 25 cards;
  - `UHC.log` must show `hook reached: deckCardCount (0x7EF026)`.

  Home cities are shared between copies of WoL
  ([notes](#adding-these-features-to-wol)).
- **Log:** `deckCardCount: limit N`; `deckCardCount: expected an integer from 20 to 10000`;
  `hook reached: deckCardCount (0x7EF026)`.
- **Simulation:** decks are part of the game setup; give every player the same value.
- **Status:**
  - confirmed on the stock game with 40 cards for a Japanese home city of level 9999 (past the table);
  - with a raised `homecitylevels.xml`, the engine's level table reads 40 at every level, but
    building a 40-card deck at a normal level has not been tried in game yet;
  - not filmed in WoL yet.

#### selectionLimit

**Added:** Monday 2026-11-02 20:33

![selectionLimit in game](media/selectionLimit.gif)

*In game:* With `selectionLimit 75`, a box over 89 Pikemen selects 75 (the number on the selection icon); without the key it stops at 50. [Full video (MP4)](media/selectionLimit.mp4).

```
selectionLimit N
```

- **Effect:** one selection holds up to N units (1 to 200; 50 in the exe), for box selection, double
  click and control groups alike. `wol.cfg` has `selectionLimit 75`.
- **Log:** `selectionLimit: a selection holds up to N units (stock 50)` (`; above 75 not tested`
  for larger values); `selectionLimit: needs a number from 1 to 200` for a bad value (not
  applied).
- **Simulation:** no: it only changes what the local player can select. Players may set it
  differently.
- **Status:** confirmed (2026-11-02, single player): with 75, a box over 89 Pikemen selected 75;
  without the key, 50. Video `selectionLimit.mp4`, with `--perf` (no frame over 50 ms).

#### noAILimit

**Added:** Wednesday 2026-10-28 10:56

```
noAILimit
```

- **Effect:** the AI personality list in game setup shows every `AI4\*.personality` file of WoL's
  folder, sorted by file name (case-insensitive). The exe's built-in list has 14 stock personalities.
  The folder name and the extension are read from the exe, so WoL's `AI4\` works. WoL's `wol.cfg` uses
  [`noAILimitV2`](#noailimitv2), which gives the same list.
- **WoL needs:** the personality files. To add one, copy a file of `AI4\` to a new name and change its
  fields. WoL's `wolRauparaha.personality` is a good model:

  ```xml
  <AI>
     <version>2</version>
     <script>_TeRauparaha</script>
     <nameID>1001432</nameID>
     <tooltipID>1001433</tooltipID>
     <forcedciv>Maori</forcedciv>
     <rushboom>0</rushboom>
     <icon>WoL\ui\singleplayer\cpai_avatar_maori-xs</icon>
     <chatset>huayna</chatset>
     <playerNames>
        <nameID>1001432<civ>Maori</civ></nameID>
     </playerNames>
  </AI>
  ```

  `nameID` and `tooltipID` are string table IDs. Give each personality its own strings in
  `data\stringtabley.xml`.
- **Log:** `noAILimit: N personalities from <folder>\AI3\*.personality`;
  `noAILimit: no personality files match …; keeping the stock list`;
  `hook reached: noAILimit (0x603B0B)`.
- **Simulation:** the list feeds game setup; every player needs the same personality files.
- **Status:** confirmed on the stock game: an added personality appeared in game setup and played.
- **Fixed from UHC 1.10:** upstream leaves two of the function's variables uninitialized.

#### noAILimitV2

**Added:** Monday 2026-11-02 19:51

```
noAILimitV2
```

- **In WoL without it:** the game has only the exe's stock personalities, which WoL does not ship. A
  random-personality AI gets one of them, starts with no civ, and the game crashes at 0x7C252C.
- **Effect:** the same list as `noAILimit`, every `AI4\*.personality` file sorted by file name, 52 in
  WoL. It is installed later in the same function: the exe's code that builds the built-in list runs,
  then only its count and table are replaced. With both keys, `noAILimit` is used.
- **Log:** `noAILimitV2: N personalities from <folder>\AI3\*.personality`;
  `hook reached: noAILimitV2 (0x603C34)`.
- **Simulation:** as `noAILimit`.
- **Status:** confirmed (2026-11-02): the list held WoL's 52 personality files, sorted, with a random
  personality playing a skirmish. A hardware breakpoint at 0x603C4F read the same table (52 names,
  `ai22` first) with WoL's own DLL and with this one.

#### enableAllTeams

**Added:** Monday 2026-11-02 20:40

![enableAllTeams in game](media/enableAllTeams.gif)

*In game:* The setup's team list offers Team 3 and Team 4; player 1 takes Team 3 and the AI Team 4 (1.5x speed). [Full video (MP4)](media/enableAllTeams.mp4).

```
enableAllTeams
```

- **Effect:** the single-player game setup offers Team 3 and Team 4 besides Team 1, Team 2 and
  "?". The multiplayer lobby is not changed yet.
- **WoL needs:** nothing: string IDs 36143 and 36144, `Team 3` and `Team 4`, are in WoL's string table.
- **Log:** `enableAllTeams: Team 3 and Team 4 in the single-player setup (multiplayer lobby not
  changed yet)`; `hook reached: enableAllTeams setup list (0x7A0709)`.
- **Simulation:** it only adds choices; the teams chosen are part of the game setup as usual.
- **Status:** partly confirmed (2026-11-02, single player): the list shows Team 1–4 and "?", and
  a skirmish with Team 3 against Team 4 started and played; how the game numbers the teams
  inside was not read. Video `enableAllTeams.mp4`.
- **Fixed from UHC 1.10:** upstream loads the temporary string's destructor but never calls it
  (a leak per list fill).

### New data and scripting

New names the game's data and scripts can use.

| Key | What it does | WoL's DLL | WoL also needs | In-game status |
|---|---|---|---|---|
| [`customAbstractTypes`](#customabstracttypes) | Turns every name in `data\uhc\customabstracttypes.xml` (47 today) into an abstract unit type that protos, techs, auras and XS scripts can use. | always on | The file. | confirmed |
| [`customProtoUnitCommands`](#customprotounitcommands) | Adds the command types (buttons) listed in `data\uhc\customprotounitcommands.xml` (55 today). | always on | The file, and the `<Command>` lines that use them. | confirmed |
| [`customHotkeyContexts`](#customhotkeycontexts) | Makes keymap contexts named `<ProtoName>Accel` work, such as WoL's `WOLBarracksGreekAccel`. Today the exe drops them. | **new** | Those contexts in `data\DefaultKeyMapY.xml`; WoL's file already has three. | confirmed (single player) |
| [`techRenameEffect`](#techrenameeffect) | The tech effect `SetTechName`: a tech gives another tech a new name, rollover and help text, for the players it reaches only. | **in `wol.cfg`**, but WoL's renames for all players | `<Effect type='SetTechName' …/>` in a tech, and the string IDs in `stringtabley.xml`. | confirmed (single player) |
| [`customSyscalls`](#customsyscalls) | Loads `wolPlugin.upl` and `wolai.upl` and adds the XS syscalls they register. WoL's AI needs it. | **in `wol.cfg`** | The plugins. | confirmed |
| [`customCheats`](#customcheats) | The cheats of WoL's plugins work in the chat. | **in `wol.cfg`** | `customSyscalls`, and plugins that register cheats. | confirmed |
| [`kbUnitSyscalls`](#kbunitsyscalls) | Five KB syscalls for AI scripts: a unit's inventory, its workers and its targeters. | always on | AI scripts that call them. | confirmed |

#### customAbstractTypes

**Added:** Monday 2026-11-02 20:04

```
customAbstractTypes [file]
```

- **In WoL today:** WoL's DLL reads `data\uhc\customabstracttypes.xml` always, so `wol.cfg` has no line
  for it. This DLL needs the line. Without it, WoL's 47 types are dropped from about 2,800 `<UnitType>`
  uses, and the AI does not compile (`cUnitTypeAbstractWoLHandCavalry`).
- **Effect:** every name in the file becomes an abstract unit type, as if it were compiled into the
  game: protos list it in `<UnitType>`, techs and auras target it, XS scripts use `cUnitType<Name>`.
  The exe drops any `<UnitType>` that is not on its built-in list, silently. The names get their IDs in
  file order, before the types other keys add, so their IDs do not depend on the other keys.
- **WoL needs:** the file, by default `data\uhc\customabstracttypes.xml` (relative to the game folder; an
  absolute path works too). To add a type, add a line to WoL's file:

  ```xml
  <AbstractTypes>
     <AbstractType stringId="430103">AbstractWoLCavalry</AbstractType>  <!-- comment -->
     <AbstractType>AbstractTrainLimitOne</AbstractType>
  </AbstractTypes>
  ```

  A name is letters, digits and `_`. `stringId` is read but not used yet (a display name for the
  type). A name the game already knows keeps its ID.
- **Log:** `customAbstractTypes: N abstract types from <file> (M with a stringId, not used yet)`;
  on each data load, one `unit types: <Name> -> <ID> (bit …), added` line per name;
  `customAbstractTypes: cannot read <file>`; `<Name> is listed twice`.
- **Simulation:** changes the data every player loads: everyone needs the same file.
- **Status:** confirmed (2026-11-02, single player, on WoL): WoL's 47 names registered (IDs 3837–3883),
  carried by the protos that list them (668 protos for the most used one), and WoL's AI scripts, which
  use `cUnitType<Name>` constants, compiled. Before it, `aiLoaderStandard.xs` failed on
  `cUnitTypeAbstractWoLHandCavalry`.

#### customProtoUnitCommands

**Added:** Tuesday 2026-11-03 08:39

![customProtoUnitCommands in game](media/customProtoUnitCommands.gif)

*In WoL (Zulu `AFRICANyouth`):* the unit's `<Command>` buttons use WoL's command types. Their tooltips
come from `protounitcommands.xml`, and a click runs their command: two transforms into "maturing"
units, which become a Tradesman and a Bowman about 10 s later. Without the key the same unit has no
such buttons (top of the still below):
![customProtoUnitCommands off and on](media/customProtoUnitCommands-control.png)
[Full video (MP4)](media/customProtoUnitCommands.mp4).

```
customProtoUnitCommands [file]
```

- **In WoL today:** WoL's DLL does this always, so `wol.cfg` has no line for it. This DLL needs the line.
  Without it, WoL's 55 command types and their `<Command>` buttons on 36 protos are dropped.
- **Effect:** every `<CommandType>` name in the file becomes a command type, like the 129 compiled into
  the exe (`MarketBuy1` ... `Tactic32` ... `RansomExplorerAsian`). Entries of `protounitcommands.xml` with
  that `<name>` and protos' `<Command>` tags with that name are kept instead of dropped, so the button
  shows and runs its `<command>`.
- **WoL needs:** the file (default `data\uhc\customprotounitcommands.xml`). To add one:

  ```xml
  <ProtoUnitCommandTypes>
    <CommandType>TransformWOLCentralAmericaBananaMaturing</CommandType>
  </ProtoUnitCommandTypes>
  ```

  plus a `protounitcommands.xml` entry and a `<Command>` per button, as for any other type. Names are
  letters, digits and `_`; a name the exe already knows is skipped.
- **Buttons on the tactics page** (`page="9"`) of a building show only for the buildings the exe lets
  switch tactics (Factory, Rice Paddy...); the key does not change that. So the Fazenda's four tactic
  buttons need more than this key, and they were not seen in a test.
- **Log:** `customProtoUnitCommands: N command type(s) from <file>; M command records`; when the
  game builds its tables, `customProtoUnitCommands: N command type(s) added (IDs 129..), K already
  known, R refused`.
- **Simulation:** changes the data: every player needs the same file.
- **Status:** confirmed (2026-11-03, single player, on WoL): with WoL's 55 names, a Zulu `AFRICANyouth`
  showed its six transform buttons with their tooltips, and two clicks transformed two units; each
  became a maturing unit and then the final unit (a Tradesman, a Bowman). The maturing unit trains the
  final unit with a `Maintain` action that the Zulu start tech `Age0zulu` enables. Without the key the
  same unit showed none. The game's command records are a fixed array (130), and a first build that
  only added the names showed no button and wrote past it; the key enlarges the array. Video
  `customProtoUnitCommands.mp4`.

#### customHotkeyContexts

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Wednesday 2026-11-04 08:32

![customHotkeyContexts in WoL](media/customHotkeyContexts-wol.gif)

*In WoL, with `customHotkeyContexts log` (Greeks in age II, the Greek barracks selected):* WoL's own
`DefaultKeyMapY.xml` maps `o` to `tis("Klepht")` in the context `WOLBarracksGreekAccel`, which the
exe does not know. The DLL registers it (`registered keymap context WOLBarracksGreekAccel as context
153`) and turns it on when the barracks is selected; three real presses of `o` queue three Klephts.
[Full video (MP4)](media/customHotkeyContexts-wol.mp4).

![customHotkeyContexts in WoL, key off](media/customHotkeyContexts-wol-control.gif)

*In WoL, key off (the same scene and key presses):* the context is dropped when the keymap loads,
so `o` does nothing and no Klepht is queued.
[Full video (MP4)](media/customHotkeyContexts-wol-control.mp4).

```
customHotkeyContexts [log]
```

- **In WoL today:** every hotkey in `data\DefaultKeyMapY.xml` belongs to a `<context>`, e.g. `BarracksAccel`
  for the keys that train units while a Barracks is selected. The exe knows a fixed list of 123 context
  names (35 of them are unit contexts, `TownCenterAccel` … `WonderAccel`) and silently drops every
  `<keymapdata>` whose context is not on that list. So the entries of WoL's three new contexts,
  `WOLBarracksGreekAccel`, `WOLBarracksKoreanAccel` and `WOLStableGreekAccel`, do nothing. Which context a
  selected unit turns on is also fixed in the exe: a table of about 40 protos (for example
  `ypCaravanserai` → `StableAccel`), plus shrines and wonders by unit type. A selected unit that is not
  a building but has a `<Train>` list only ever gets `BuildAccel`.
- **Effect:** a `<context>` named `<ProtoName>Accel` that the exe does not know is registered when
  the game reads the keymap, so its entries are kept. `<ProtoName>` is the `name` of a `<Unit>` in
  `protoy.xml` (case does not matter). While a unit of that proto is selected, that context is on,
  **instead of** the context the exe gives that proto, if it had one. Selecting anything else switches
  it off. Contexts the exe already knows are never redirected.
- **Which units use it:** only units that enter a hotkey context at all:
  - a building with a `<Train>` list;
  - any other unit with a `<Train>` list (a wagon, a settler), which then enters its own context
    instead of `BuildAccel`;
  - a fire pit (`AbstractFirePit`);
  - a unit whose proto has the flag `EnterHotkeyContext`.

  Other units (a soldier, a hero) never enter a context, so theirs stays off although it is
  registered: give them the flag `EnterHotkeyContext`.
- **WoL needs:** nothing for its three contexts: `DefaultKeyMapY.xml` already names them this way. For a
  new one, add its entries to that file. `<context>` is `<ProtoName>Accel`:

  ```xml
  <keymapgroup name="Greek Barracks Hotkeys" displayname="Greek Barracks Hotkeys">
    <keymapdata>
      <name>Train Klepht</name>
      <displayname>Train Klepht</displayname>
      <event>o</event>
      <context>WOLBarracksGreekAccel</context>
      <command>tis("Klepht")</command>
    </keymapdata>
  </keymapgroup>
  ```

  An added context replaces the one the exe would turn on, so copy into it every key the unit should
  keep. For a trainer that is not a building, copy the `BuildAccel` keys it needs.
- **`log`:** one line each time the selection turns an added context on (repeats of the same unit
  and context are not logged again in a game), and once per proto when a unit that is not a
  building enters its context.
- **Log:**
  - at startup, `customHotkeyContexts: a keymap context named <ProtoName>Accel that the game does
    not know becomes that proto's hotkey context` (`, every switch logged` with `log`);
  - when the keymap is read, `hook reached: customHotkeyContexts (0x5C1778)` and one line per added
    context: `customHotkeyContexts: registered keymap context WOLBarracksGreekAccel as context 153`;
  - on the first selection, `hook reached: customHotkeyContexts (0x79F1A5)` and `… (0x79F897)`; on
    the first selected trainer that is not a building, `… (0x64A034)`;
  - with `log`: `customHotkeyContexts: unit N (WOLBarracksGreek) selected: hotkey context
    WOLBarracksGreekAccel (153) instead of stock context -1` (-1: the proto had none) and `customHotkeyContexts: unit N
    (ForgeCaravan) is not a building: units of this proto enter hotkey context ForgeCaravanAccel
    (152) instead of BuildAccel (logged once per proto)`;
  - when the context table is too full: `customHotkeyContexts: N contexts are registered; keymap
    context X not registered, its entries are dropped (the last 32 of the 255 context IDs stay free
    for the game)`.
- **Limits:**
  - at most 255 contexts in all; the DLL stops adding at ID 222 to leave the game room. About 70 can
    be added: the game registers about 151 before the keymap;
  - names the exe already knows (`SettlerAccel`, `CoveredWagonAccel`, …) keep the exe's meaning;
  - a context is on only for the last unit of the selection;
  - the hotkey letter on train-button tooltips comes from the exe's fixed list of contexts, so keys of
    an added context are not shown there (static reading).
- **Simulation:** no. A hotkey issues the same command as clicking the button, so players may set
  the key differently. Not tested in multiplayer.
- **Status:** confirmed in single player. In WoL (2026-11-03), three real presses of `o` queued three
  Klephts at the selected Greek barracks; without the key the context is dropped and the same presses
  do nothing. On the stock game (2026-10-29), test contexts on a Sacred Field, a Caravanserai (instead
  of its `StableAccel`) and a market wagon (not a building, instead of `BuildAccel`) switched by the
  log. Not tested in WoL: a trainer that is not a building.

#### techRenameEffect

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Wednesday 2026-11-04 08:32

![techRenameEffect in WoL](media/techRenameEffect-wol.gif)

*In WoL, with `techRenameEffect log` (Ethiopians; the cursor rests on the Town Center's GW button
so its rollover stays on screen):* a test tech (`UHCRenameTest`, appended to the bed's techtree and
removed after) carries `<Effect type='SetTechName' tech='GreatWarButton' newName='11070'
newRolloverTextID='10670'/>` and turns on at 22 s. The button takes Gangsaw's name and rollover (the
video is in Spanish: "Declarar Guerra Total" becomes "Sierra de tajo"); cost and effect stay those of
`GreatWarButton`. [Full video (MP4)](media/techRenameEffect-wol.mp4).

![techRenameEffect in WoL, key off](media/techRenameEffect-wol-control.gif)

*In WoL, key off (both `techRenameEffect` and WoL's `enableTechRenameEffect` line removed from the
cfg):* the game drops the `SetTechName` effect, and the button keeps its name.
[Full video (MP4)](media/techRenameEffect-wol-control.mp4).

```
techRenameEffect [log]
enableTechRenameEffect [log]     the same key under WoL's name
```

- **In WoL today:** `wol.cfg` has `enableTechRenameEffect`, and WoL's DLL adds the effect `SetTechName`.
  It writes the new string IDs into the database's copy of the tech, which all players share: when one
  civ's tech renames a tech, every player sees the new name. WoL's `techtreey.xml` has no `SetTechName`
  yet. The exe's own `SetName` effect renames a *unit* for one player.
- **What changes for WoL:** the same effect and attributes, so WoL's data works unchanged, but the
  rename reaches only the players of the tech that carries it. To have this, replace WoL's handler
  with the code in the porting guide.
- **Effect:** adds the tech effect `SetTechName`. When a tech that carries it becomes active for a
  player, the named tech shows the new name, rollover and help text **for that player only**. If
  the carrier is a team tech, every member of the team gets the rename. Costs, prerequisites,
  effects, icon and research stay as before.
- **WoL needs:** the effect in the `<Effects>` of any tech:

  ```xml
  <Effect type='SetTechName' tech='HuntingDogs' newName='11070' newRolloverTextID='10670'/>
  ```

  | Attribute | Meaning |
  |---|---|
  | `tech` | Required. The name of the tech to rename. |
  | `newName` | New `DisplayNameID` (the button and message name). |
  | `newRolloverTextID` | New `RolloverTextID` (the button's rollover). |
  | `newLongRolloverTextID` | New `LongRolloverTextID` (the long help text). WoL's effect has no such attribute. |

  The three string IDs are optional, but at least one must be given; leave one out, or write `-1`, to
  keep that text. The IDs come from `data\stringtabley.xml`. "Per civ" means placing the effect in a
  tech that only that civ gets, such as its `Age0<Civ>` shadow tech or a home city card's tech.
- **Where the new texts show:** wherever the game reads the tech through the player's own tech
  tree: the buttons and rollovers of that player's buildings and the "researching" /
  "researched" messages. From the code, these keep the original texts: the in-game help (F1), the home
  city screens and every screen outside a game. Other players and observers see the original texts.
- **When:** from the moment the carrier tech becomes active. A saved game re-applies the rename
  when it loads (static reading; not tested). Nothing undoes a rename: a carrier that is
  deactivated later leaves the new texts, as `SetName` does. Two carriers that rename
  the same tech for one player: the last one applied wins, text by text.
- **Without the key** the game does not know `SetTechName`: it drops each such effect with its own
  error and loads the rest of the techtree.
- **`log`:** one line per `SetTechName` read from the data and one per rename.
- **Log:** at startup `techRenameEffect: the tech effect SetTechName (tech, newName,
  newRolloverTextID, newLongRolloverTextID) renames a tech for the players it reaches (multiplayer
  unverified)` (the line starts with `enableTechRenameEffect:` under WoL's key name; with `log`,
  `…reaches, every rename logged (multiplayer unverified)`), then
  `techRenameEffect/enableTechRenameEffect: applied`; at data load `hook reached: techRenameEffect
  register (0x524CB5)`, `techRenameEffect: effect type SetTechName -> 17` and, at the first effect
  read, `hook reached: techRenameEffect factory (0x62146F)`. Data errors are always logged, and
  the effect is dropped while the rest of the file loads:
  - `techRenameEffect: SetTechName: unknown tech 'X'; this effect is dropped`;
  - `techRenameEffect: SetTechName without tech='...'; this effect is dropped`;
  - `techRenameEffect: SetTechName on X: newName='abc' is not a string ID (a number from 0, or -1 to
    keep the text); this effect is dropped`;
  - `techRenameEffect: SetTechName on X sets none of newName, newRolloverTextID,
    newLongRolloverTextID; this effect is dropped`.

  With `log`: `techRenameEffect: read SetTechName on X (tech N): newName …` per effect read, and
  `techRenameEffect: player P: tech N (X), from tech M: name a -> b, rollover c -> d, long rollover
  e -> f (node …, NodeData … -> copy …)` per rename.
- **Simulation:** no gameplay change: only string IDs differ. The effect does run inside the
  simulation (tech activation), so give every player the same setting; multiplayer is not tested.
- **Status:** confirmed in single player. In WoL (2026-11-04), a test tech renamed `GreatWarButton` for
  player 1, and the button and its rollover changed. On the stock game (2026-10-29), memory showed the
  database's tech data, which other players see, unchanged, and only player 1's copy with the new IDs;
  a second effect naming an unknown tech was logged and dropped, and the techtree still loaded. Saved
  games were not tested.

#### customSyscalls

**Added:** Monday 2026-11-02 20:13 · **Filmed in WoL:** Monday 2026-11-02 21:22

![customSyscalls-wol-ai in game](media/customSyscalls-wol-ai.gif)

*In WoL:* with `customSyscalls wolPlugin.upl wolai.upl`, WoL's AI compiles and plays: the counter shows its settlers and houses growing (2x speed), with the performance numbers on top. [Full video (MP4)](media/customSyscalls-wol-ai.mp4).

```
customSyscalls [file or pattern ...]
```

- **In WoL without it:** the AI does not compile (`aiWoLMain.xs` calls `kbGetTechID` 36 times), and 36
  `RM4\ESOC_*` maps need it too.
- **Effect:** loads UHC plugins (`.upl` files) and adds the XS syscalls they register to AI, trigger,
  random-map and UI scripts. Without arguments it loads every `*.upl` file in the game folder; with
  arguments, the files or patterns listed, relative to the game folder. A plugin that crashes while it
  starts is logged and skipped. `wol.cfg` has `customSyscalls wolPlugin.upl wolai.upl`.
- **Plugins:** a `.upl` is a 32-bit DLL that exports `int UHCPluginMain(UHCPluginInfo*)` (cdecl).
  `UHCPluginInfo` holds five cdecl function pointers, in this order:
  `RegisterCheat(text, enabled, callback)`,
  `RegisterSyscall(group, returnType, name, function, paramCount, comment)` (returns a handle),
  `SyscallSetParam(handle, index, type, defaultValue)`, `CheatAddResource(playerData, resource,
  amount, flag)` and `CheatSpawnUnit(playerData, protoName)`. Groups: 0 AI, 1 HC, 2 KB, 3 RM,
  4 TR, 5 UI, 6 UI2, 7 XS. Types: 1 void, 2 int, 4 float, 8 bool, 16 string, 32 vector. A
  syscall function is cdecl and takes the XS arguments in order. WoL's two plugins load unchanged.
  Cheats go to the game with `customCheats` (below).
- **Log:** `customSyscalls: <file>: N syscalls, M cheats (UHCPluginMain returned R)`;
  `customSyscalls: K of L plugin(s) loaded, …`; once per script module,
  `syscalls: group XS: N added, M refused`; a refused syscall (a name the game already has, a bad
  type) is named, and the others still register; `hook reached: syscall group XS (0x6257D9)` and
  the other seven groups.
- **Simulation:** scripts compiled with these syscalls need them on every player's machine:
  everyone needs the same plugins.
- **Status:** confirmed (2026-11-02, single player, on WoL): both plugins loaded (17 syscalls in the XS,
  AI and KB groups, 33 cheats collected), and WoL's AI compiled and played a skirmish.
- **Fixed from UHC 1.10:** upstream's syscall table overflows into the population and deck limits
  when the list is long, loads plugins by bare file name (directories do not resolve), and stops
  a whole group at the first refused syscall.

#### customCheats

**Added:** Monday 2026-11-02 20:47

![customCheats in game](media/customCheats.gif)

*In WoL:* `kill 'em all`, a cheat of `wolPlugin.upl` typed in the chat (second ~4), spawns 50 Cannons; the two frames over 100 ms are the moment the 50 units appear. [Full video (MP4)](media/customCheats.mp4).

```
customCheats
```

- **Effect:** the 33 cheats that WoL's plugins register (see `customSyscalls`) work in the chat like the
  game's own: typed as written (lower case), they run on every player's machine through the game's
  cheat command. Plugins load when either `customSyscalls` or `customCheats` is set;
  without `customSyscalls` their syscalls are ignored.
- **Log:** `customCheats: N plugin cheat(s) added to the cheat table (M entries)` the first time
  the table is built; `hook reached: customCheats cheat table (0x551FE6)`.
- **Simulation:** a cheat runs as a game command, as the game's own cheats do; every player needs the
  same plugins.
- **Status:** confirmed (2026-11-02, single player, on WoL): 33 plugin cheats added after the exe's 23,
  and `kill 'em all` spawned 50 Cannons. Video `customCheats.mp4` (two frames over 100 ms while the 50
  units appear).

#### kbUnitSyscalls

**Added:** Tuesday 2026-11-03 08:16

![kbUnitSyscalls in game](media/kbUnitSyscalls.gif)

*In WoL (the Maori AI Te Rauparaha):* its script calls the five syscalls, compiles and plays; a test rule
prints them in the chat for what the AI's villagers gather (here a hunted animal: 6 visible workers,
the exe's `kbUnitGetNumberWorkers` 0) and for its livestock (food 50 of 300, not full).
[Full video (MP4)](media/kbUnitSyscalls.mp4).

```
kbUnitSyscalls
```

- **In WoL today:** WoL's DLL has these always, so `wol.cfg` has no line for them. This DLL needs the
  line. Only the Maori personality Te Rauparaha uses them (`AI4\_TeRauparaha.xs`, 38 calls), and without
  them that AI does not compile (`Error 0172` on `kbUnitGetCurrentInventory`).
- **Effect:** adds five KB syscalls for AI scripts, about resource units. "The player" is the AI whose
  script runs.

  | Syscall | Returns |
  |---|---|
  | `float kbUnitGetCurrentInventory(int unitID, int resourceID)` | the amount of that resource the unit holds (a mine's gold, a bush's food, an animal's food) |
  | `float kbUnitGetInventoryCapacity(int unitID, int resourceID)` | how much of it the unit can hold (its proto's carry capacity) |
  | `bool kbUnitIsInventoryFull(int unitID)` | the engine's own "inventory full" test (for livestock: fully fattened) |
  | `int kbUnitGetNumberWorkersIfSeeable(int unitID)` | for a unit the player can see, the number of its gatherers the player can see; 0 if it cannot see the unit. The exe's `kbUnitGetNumberWorkers` answers only for the player's own units |
  | `int kbUnitGetNumberTargeters(int unitID)` | the number of the player's gatherers ordered to the unit that are not working it yet |

  An unknown unit ID gives 0 (inventory), false, or -1 (the two counts).
- **WoL needs:** nothing; AI scripts call the syscalls. A script that calls them fails to compile
  without the key (`XS: Error 0003: could not compile file ...`).
- **Log:** `kbUnitSyscalls: 5 kb syscalls added`, then `syscalls: group KB: 5 added, 0 refused`
  when the game builds its KB syscalls; the first call of each, `hook reached: kbUnitSyscalls
  <name>`.
- **Simulation:** reads only; AI scripts run on the host, so only the host needs the line.
- **Status:** confirmed (2026-11-03, single player, against the AI Te Rauparaha): the script compiled and
  ran. A test rule printed the syscalls every 20 s: a hunted animal's food fell from 207.7 to 62.5 while
  `kbUnitGetNumberWorkersIfSeeable` gave 6 (`kbUnitGetNumberWorkers` gave 0 for that Gaia unit; game
  memory showed the same 6 gatherer IDs); the AI's livestock showed food 50 of capacity 300, not full; a
  mine and a bush at full showed "full". `kbUnitGetNumberTargeters` was reached but gave 0 in that
  window (every gatherer was already working its target). Video `kbUnitSyscalls.mp4`: about 1,200 fps
  on average, no frame over 50 ms.

### Civs

What the exe decides by civ.

| Key | What it does | WoL's DLL | WoL also needs | In-game status |
|---|---|---|---|---|
| [`asianCivs`](#asiancivs) | Egyptians, Ethiopians, Koreans, Zulu and Maori count as Asian civs: consulate, export and wonders. | **in `wol.cfg`** | Those civs' data. | confirmed |
| [`nativeCivs`](#nativecivs) | WallMapu, Tupinamba and Tawantinsuyu count as native civs: fire pit, dances and council age-up. Without it, WallMapu's age-up crashes the game. | **in `wol.cfg`** | Those civs' data. | confirmed |
| [`twoScoutCivs`](#twoscoutcivs) | The Koreans get the interface of the civs that start with two heroes. | **in `wol.cfg`** | A second hero. | not tested in game |
| [`bigButtonCivs`](#bigbuttoncivs-and-nobigbuttonblds), [`noBigButtonBlds`](#bigbuttoncivs-and-nobigbuttonblds) | Gives the command panel's big button to the listed civs, and takes it from the listed buildings. | **in `wol.cfg`** | Nothing. | partly confirmed |
| [`danceBonusCivs`](#dancebonuscivs) | Lets the civs you list get the fire pit's Training, XPTrickle, Gathering and Regeneration dances, which the exe applies only to `XPIroquois`, `XPSioux`, `XPAztec` and `XPSPC`. | **new** | A building with `AbstractFirePit`, its dance enabled for those civs, and villagers that can work on it. | confirmed (single player) |
| [`wonderCivUnitType`](#wondercivunittype) | `Rangatira` may start the Maori age-up. Without it, the Maori cannot age up. | **in `wol.cfg`** | Nothing. | confirmed |
| [`startingTC`](#startingtc) | Lets buildings of a marked type be a player's first town center, the unit the placement rules call `FirstTC` (no enemy building within 65 m), not only a `TownCenter`; one also replaces a first town center that is gone, dead or about to expire. | **new** | That unit type on the starting buildings in `protoy` (e.g. `MaoriPa`), or an existing type or proto name in the cfg. | confirmed from the log and memory (single player) |
| [`civFirstTC`](#civfirsttc) | A civ's `<firstTC>Proto</firstTC>` in `civs.xml` replaces the `TownCenter` that random maps place for its players (not in a Nomad start); that building is their first town center (`FirstTC`) and receives their town starting units. | **new** | The tag in `civs.xml`; for the town starting units, `<Flag>StartingColonyBuilding</Flag>` on the proto and the proto in `placementrules\colonies.xml` `<starttypes>`; for shipments, `hcShipmentPointFallback FirstTC`. | confirmed (single player; Nomad start not tested) |
| [`customRevolutionBanners`](#customrevolutionbanners) | Shows a banner for each of WoL's 29 `XPRevolution<Name>` techs, not only O'Higgins. | **in `wol.cfg`** | A banner texture per revolution. | partly confirmed |
| [`removeFameRestriction`](#removefamerestriction) | Shows Fame, XP and shipment costs on politician screens, and Fame/XP icons on home city cards. | **in `wol.cfg`** | Two icon textures. | not tested in game |

#### asianCivs

**Added:** Monday 2026-11-02 20:27

![asianCivs-koreans in game](media/asianCivs-koreans.gif)

*In WoL (Koreans):* the two Korean monks get their hero names (`explorerUnits`), then the villager opens the wonder age-up list with the Koreans' five wonders. [Full video (MP4)](media/asianCivs-koreans.mp4).

```
asianCivs Civ [Civ ...] [log]
```

- **In WoL today:** `wol.cfg` has `asianCivs Egyptians Ethiopians Koreans Zulu Maori`. Without the line
  those civs lose export, the consulate and the wonder age-up.
- **Effect:** the listed civs (names from `civs.xml`) count as Asian civs where the game compares a
  player's civ with the Asian civs: the extended Asian-civ test (consulate, export and the other Asian
  features that call it), the Asian civs' value branch, and the wonder age-up list. In that list a
  listed civ gets the wonders whose civ name is its name in the cfg; the exe gives a civ that is not
  Chinese, Japanese or Indian no wonder at all.
- **WoL needs:** for the wonder age-up, entries in `data\politiciandata.xml` with `nativeciv="<Civ>"` and
  the civ's wonders. The file has 20 entries each for `Koreans` and `Maori`, which are the model.
- **Log:** `asianCivs: N civ(s) count as Asian civs`; when `civs.xml` is read, one
  `asianCivs: <Civ> -> civ <ID>` line per name (`… is not a civ in civs.xml; ignored` otherwise);
  with `log`, `asianCivs: <Civ> gets its wonders in the age-up list` once;
  `hook reached: asianCivs isAsianCiv (0x454F1D)`, `… civ value (0x8D6AC4)`,
  `… wonder age-up (0x818284)`.
- **Simulation:** changes what the listed civs may do: every player needs the same line.
- **Status:** confirmed (2026-11-02, single player): the five civs resolved, and a Korean villager
  opened the wonder age-up list with its five wonders. Video `asianCivs-koreans.mp4`.
- **Fixed from UHC 1.10:** upstream tests EAX instead of AL after `0x49A2D8` in the wonder list,
  so the "civ has no entry" path (EAX = 0xFFFFFF00) counted as true.

#### nativeCivs

**Added:** Monday 2026-11-02 21:19

![nativeCivs-mapuche in game](media/nativeCivs-mapuche.gif)

*In WoL (WallMapu):* the Town Center opens the council age-up list with its five council members; the log lines on top show the civ resolved by the native civ tests and the dance gates. [Full video (MP4)](media/nativeCivs-mapuche.mp4).

```
nativeCivs Civ [Civ ...]
```

- **In WoL today:** `wol.cfg` has `NativeCivs Tupinamba WallMapu Tawantinsuyu`. Without the line, the
  WallMapu age-up closes the game: the civ is taken for a European one, and the politician dialog reads
  a gadget it does not have (0x81A5FB to 0x81A80C in the exe).
- **Effect:** the listed civs count as native civs: the civ flag the `civs.xml` loader sets for
  the native civs, the game's native civ tests, the fire pit's Training, XPTrickle, Gathering and
  Regeneration dances (through the same four gates as `danceBonusCivs`), and the council age-up
  list, where a listed civ gets the council members whose civ name is its name in the cfg.
- **WoL needs:** for the council age-up, entries in `data\politiciandata.xml` with `nativeciv="<Civ>"`.
  The file has 20 each for `WallMapu`, `Tupinamba` and `Tawantinsuyu`.
- **Log:** `nativeCivs: N civ(s) count as native civs`; `nativeCivs: K of N civ(s) marked native
  in civs.xml`; `nativeCivs: <Civ> -> civ <ID>` and `danceBonusCivs: <Civ> -> civ <ID>` when
  `civs.xml` is read; `hook reached: nativeCivs civ flags (0x52B581)`, `... test 2 (0x51271F)`,
  `... isNativeCiv (0x453D5E)`, `... test 7 (0x67B0A5)`, `... test 9 (0x8D52AF)`,
  `... council age-up (0x81ADEB)`.
- **Simulation:** changes what the listed civs may do: every player needs the same line.
- **Status:** confirmed (2026-11-03, single player): the three civs marked native, every hook ran in a
  skirmish, the four dance gates resolved them, and the WallMapu Town Center opened the council age-up
  list with its five council members. Without the key, the same click closed the game. Video
  `nativeCivs-mapuche.mp4`.
- **Fixed from UHC 1.10:** upstream compares a dword where isNativeCiv compares a byte, and its
  council hook clobbers EAX.

#### twoScoutCivs

**Added:** Monday 2026-11-02 21:10

```
twoScoutCivs Civ [Civ ...]
```

- **Effect:** the listed civs get the hero interface of the civs that start with two heroes (Japanese
  and Indians) in the four places the game decides it by civ. `wol.cfg` has `twoScoutCivs Koreans`.
- **Log:** `twoScoutCivs: N civ(s) get the two-hero UI`; `twoScoutCivs: <Civ> -> civ <ID>` when
  `civs.xml` is read; `hook reached: twoScoutCivs hero UI 1 (0x77EBB2)` to `... 4 (0x77DFF4)`.
- **Simulation:** no: interface only.
- **Status:** implemented, not tested in game (2026-11-02): the four functions did not run during a
  skirmish, in the home city menus or in its customize screen; they are probably the new home city
  dialog, which names the heroes.

#### bigButtonCivs and noBigButtonBlds

**Added:** Monday 2026-11-02 21:19

```
bigButtonCivs Civ [Civ ...]
noBigButtonBlds Proto [Proto ...]
```

- **Effect:** the command panel's big button, which the exe gives to native civs, also goes to the
  listed civs; and neither native nor listed civs get it on a building of a `noBigButtonBlds` proto.
  Either line may be used alone. `wol.cfg` has `bigButtonCivs Tawantinsuyu WallMapu Tupinamba` and a
  `noBigButtonBlds` list that starts with `SANmonument`.
- **Log:** `bigButtonCivs/noBigButtonBlds: N civ(s) get the native big button, M building proto(s)
  never show it`; `hook reached: bigButtonCivs command panel (0x461BD8)`.
- **Simulation:** no: interface only.
- **Status:** partly confirmed (2026-11-02, single player): the hook ran when a WallMapu Town Center was
  selected; a building of a listed proto was not checked.

#### danceBonusCivs

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Wednesday 2026-11-04 08:11

![danceBonusCivs in WoL](media/danceBonusCivs-wol.gif)

*In WoL, with `danceBonusCivs Ethiopians log` (Ethiopians, the Town Center selected so its queue
shows):* ten settlers do WoL's Fertility Dance (`FertilityDance`, a `Training` dance, turned on for
the test by an appended tech, removed after) at a fire pit while the TC trains villagers. The
Ethiopian TC gets the dance's train bonus (`reads its fire pit's Training dances`): 4 villagers
trained by 65 s of game time. [Full video (MP4)](media/danceBonusCivs-wol.mp4).

![danceBonusCivs in WoL, key off](media/danceBonusCivs-wol-control.gif)

*In WoL, key off (the same scene):* the settlers dance but the bonus applies only to the native
civs, so the TC trains at its normal rate: 2 villagers by 65 s.
[Full video (MP4)](media/danceBonusCivs-wol-control.mp4).

```
danceBonusCivs <Civ> [<Civ> ...] [log]     civ names as in civs.xml; several lines add up
```

- **In WoL today:** a fire pit dance is a tactic of the building (`data\tactics\firepit.tactics`); its
  actions have `<type>DanceBonus</type>` and a `<dancebonustype>`. Four kinds act by themselves for any
  civ that owns the building and has the tactic: `UnitModification`, `UnitSpawn`, `PopCap` and
  `WarChiefRansom`. The other four are applied by the engine where it needs them, and only for the
  civs `XPIroquois`, `XPSioux`, `XPAztec` and `XPSPC`, a list fixed in the exe:
  - `Training`: train rate (Fertility Dance, action `VillagerTrainFaster`);
  - `XPTrickle`: XP trickle (Gift Dance, `XPTrickleIncrease`);
  - `Gathering`: gather rate of every resource (the action `GatherRateIncrease` is in
    `firepit.tactics`);
  - `Regeneration`: heals the units of `<modifyabstracttype>` that have been idle for 3.5 s (Healing
    Dance, `RegenAllUnits`).

  For any other civ these four dances run, the villagers dance and (except Gift Dance) the tooltip
  even shows the bonus, but nothing happens. WoL's own key `danceCiv` only changes interface checks.
- **Effect:** the listed civs get these four kinds exactly as those four civs do: the same strength,
  the same building (the player's first `AbstractFirePit` building) and the same targets. The civ does
  not become "native" for anything else, unlike [`nativeCivs`](#nativecivs), which also misses the Gift
  Dance.
- **WoL needs:**
  - the internal civ names (the `<name>` in `civs.xml`: `Ethiopians`, `Greeks`, …); case does not
    matter;
  - a building with `<UnitType>AbstractFirePit</UnitType>`: WoL's `FirePit`, `WOLMaypole`, `SANmonument`
    or the `ypWCSummerPalace2` to `5`. Only the player's first such building is read, and the dancer
    count needs that type;
  - the dance tactic in the building's tactics file, enabled for the civ by a tech, and a button for
    it;
  - villagers that can work on the building (a `Gather` rate for it in their tactics:
    `settler.tactics` already has `FirePit`).
- **`log`:** one line the first time each player passes each of the four checks in a game. A
  listed civ with no fire pit gets the line too: the check passes, then the engine finds no
  building and the bonus stays 1.0.
- **Log:** at startup `danceBonusCivs: civs A, B get the fire pit's Training, XPTrickle, Gathering
  and Regeneration dances like the native civs (multiplayer unverified)` (with `log`: `…civs, each
  player's first use of each kind logged (multiplayer unverified)`); on the first use with each
  data load, one `danceBonusCivs: <Civ> -> civ <ID>` line per name, or `danceBonusCivs: <Civ> is not
  a civ in civs.xml; ignored` (and, when no name is valid, `danceBonusCivs: none of the listed civs
  exists; the four dance kinds stay native-only`). In a game: `hook reached: danceBonusCivs
  Training (0x8D47AB)`, `… XPTrickle (0x4E0DFF)`, `… Gathering (0x4ECD53)` and `… Regeneration
  (0x49048B)` the first time the game evaluates each kind for any player. With `log`:
  `danceBonusCivs: player N (<Civ>) reads its fire pit's <Kind> dances (game time T ms)`. Without
  any civ name: `danceBonusCivs: expected "danceBonusCivs <Civ> [<Civ> ...] [log]" with at least
  one civ name; feature not applied`.
- **Limits:**
  - only the player's first `AbstractFirePit` building counts, as for the native civs;
  - each listed civ now looks for its fire pit (a scan of its units) on every train, gather-rate,
    XP trickle and regeneration evaluation, as the native civs always did. List only the civs that
    can own a dance building;
  - new dance kinds, more dance buttons and several dance buildings per player are not covered.
- **Simulation:** yes.
- **Status:** confirmed in single player for two kinds. `Training` in WoL (2026-11-04): Ethiopian settlers
  dancing the Fertility Dance, 4 villagers by 65 s, 2 without the key. `Regeneration` in WoL
  ([overhealSources](#overhealsources)), and on the stock game (2026-10-29), where damaged units healed
  to full with the key and stayed at 90 without. XPTrickle and Gathering were not tested in game.

#### wonderCivUnitType

**Added:** Tuesday 2026-11-03 07:25

![wonderCivUnitType in game](media/wonderCivUnitType.gif)

*In WoL (Maori):* the Maori age up with voyages and start without a Town Center. The `Rangatira` opens
the age-up list; without the key the same click opens nothing.
[Full video (MP4)](media/wonderCivUnitType.mp4).

```
wonderCivUnitType Proto [Proto ...]
```

- **In WoL without it:** the Maori cannot age up: their Rangatira cannot start the voyage.
- **Effect:** for a civ that ages up with wonders (the Asian civs and those of
  [`asianCivs`](#asiancivs)), units of the listed protos may start the age-up and place its wonder,
  besides the units the exe accepts (abstract type 16h). `wol.cfg` has `wonderCivUnitType Rangatira`.
- **Log:** `wonderCivUnitType: N proto(s) may place the age-up wonder of a wonder civ`; when
  `protoy.xml` is read, `wonderCivUnitType: K of N protos found in the data`; the first time it
  applies, `wonderCivUnitType: <Proto> accepted for the wonder age-up`.
- **Simulation:** changes who may age up: every player needs the same line.
- **Status:** confirmed (2026-11-03, single player): the Maori Rangatira opened the age-up list; without
  the key the same click opened nothing. Video `wonderCivUnitType.mp4`.

#### startingTC

**Added:** Thursday 2026-10-29 10:35

```
startingTC [<UnitType>] [log]          default AbstractStartingTC
```

- **In WoL today:** each player has one *first town center*, the unit the placement rules call
  `FirstTC`: the first unit of the exact proto `TownCenter` that is added to him (placed by the map,
  shipped, built, converted). The placement rules use it twice: no building within 65 m of an enemy's
  first town center (`buildingsmall.xml`, `buildinglarge.xml`, …: error 25521), and, in a no-rush game
  (`norushonly`), buildings only within 75 m of a team's first town center. The choice is made once and
  never undone:
  - a player who starts with another building (a Pa, a Presidio) has no first town center, so no enemy
    is kept 65 m away from him;
  - a player whose first town center dies keeps the dead one, and the rules skip him too.

  WoL's Maori start is the second case (static reading of WoL's techtree and of the exe): `Age0Maori`
  gives `TownCenter` a `Lifespan` of 0.5 s, then a free `MaoriPa`. The Pa is added while the town center
  still lives, so the first town center stays the town center, which dies half a second later. From
  then on the Maori have no 65 m protection, and the no-rush rule fails for their team.
- **Effect:** a building whose proto is of `<UnitType>` can be a first town center too:
  - a player who has none takes the first marked building added to him, as the exe takes a
    `TownCenter`;
  - a player whose first town center is **gone** (no longer in the game), **dead**, or has a
    **pending lifespan** (it is about to expire, like WoL's town center under `Lifespan 0.5`)
    takes the next marked building added to him instead.

  The `FirstTC` rules then measure from that building. A `TownCenter` behaves as before, and a live
  first town center with no lifespan is never replaced.
- **What it does not cover:** only the `FirstTC` rules follow the marked building. Other code
  still looks for the `TownCenter` proto itself (scoping of request #3, static reading):
  - the age-up picker (`uiPoliticianUI`) and the age-up progress display;
  - the start camera;
  - the AI: its automatic main base, its build plan and its chat lines;
  - the `trPlayerToggleAllowTCSpawning` gate on `Maintain`;
  - the town starting units (`<townstartingunit>`: settlers, crates), which go to the first
    built `TownCenter` ([`civFirstTC`](#civfirsttc) sends them to its own building);
  - the `CoveredWagon` build limit and a Town Center's fixed repair cost.

  The home city shipment point is covered by [`hcShipmentPointFallback`](#hcshipmentpointfallback):
  list `FirstTC` there (the marked building that is the player's first town center), or the marked
  protos. For a civ that starts with another building on every map, see [`civFirstTC`](#civfirsttc), as
  Mandos designed request #3 ([wol-requests.md](wol-requests.md)); the other checks above stay as they
  are.
- **WoL needs the marker** on the buildings that stand in for a town center at the start, in
  `data\protoy.xml`: `MaoriPa`, `Presidio`, `EGYtowncenterCARAVAN` and the `*Colony` protos
  (`AmericanColony`, `FrenchColony`, …):

  ```xml
  <Unit id ='…' name ='MaoriPa'>
      ...
      <UnitType>AbstractStartingTC</UnitType>
  ```

  The DLL registers the marker. An existing type or proto name works too (`startingTC MaoriPa`).
  `TownCenter` needs nothing. `Age0Maori` needs no change: the Pa replaces the dying town center the
  moment it is added.
- **Choose the marked protos with care:** once a player's first town center is dead or gone, the
  next marked building he gets becomes his first town center, wherever it stands. Mark the
  buildings that replace a town center, not a common building. A `TownCenter` built after the first
  one died does not replace it, unless `TownCenter` is marked too.
- **With [`civFirstTC`](#civfirsttc):** both keys can be on; they share the hook that sets a
  player's first town center. A player with none takes the first unit added to it that is a
  `TownCenter`, of its civ's `<firstTC>` proto, or of the marked type. Only `startingTC`
  replaces a first town center that is gone, dead or about to expire.
- **`log`:** one line for each marked building that becomes a first town center. This happens
  about once per player per game, so it can stay on.
- **Log:** at startup `startingTC: units of unittype X can be a player's first town center
  (FirstTC) like TownCenter, and replace one that is gone, dead or has a pending lifespan
  (multiplayer unverified)` (with `log`: `…pending lifespan, every new FirstTC logged (multiplayer
  unverified)`); when the data loads, `unit types: X -> <ID> …`; in a game,
  `hook reached: startingTC (0x49880A)` and `hook reached: FirstTC proto check (0x506B3B)` (the
  hook it shares with `civFirstTC`) as the map's first units are added to their players. With
  `log`:
  - `startingTC: unit N (Market) is player 2's first town center (FirstTC)`;
  - `startingTC: unit N (MaoriPa) replaces player 2's first town center M (TownCenter), whose
    lifespan ends in 0.50 s`, or `…first town center M (TownCenter), which is dead`, or `…first
    town center M, which is gone`.
- **Limits:**
  - a first town center captured by another player is not replaced: it still exists and lives;
  - a dead first town center is replaced only when a marked building is added afterwards; nothing
    happens at its death;
  - the no-rush rule passes for everyone while **any** player has no first town center. A player who
    gets one through this key therefore turns that rule back on for the whole game, as a `TownCenter`
    would.
- **Simulation:** yes: the first town center decides where buildings may be placed. Every player
  needs the same line and the same data. It also adds a unit type when the name is new.
- **Status:** confirmed from the log and memory in single player, on the stock game (2026-10-29): a
  `Market` marked `AbstractStartingTC` and created for player 2, who had no Town Center, became his
  first town center (`[player+4F0h]` read 3, where the exe leaves -1). Not driven in game: the visible
  effect on placement (the 65 m refusal), and the replacement of a first town center that is dead or
  has a pending lifespan, which is the Maori case. Not filmed in WoL yet.

#### civFirstTC

**Added:** Thursday 2026-10-29 12:03

![civFirstTC in game](media/civFirstTC.gif)

*On the stock game (not filmed in WoL yet):* a skirmish start on the map Mongolia: player 1, whose civ has `<firstTC>Market</firstTC>`, starts with a Market where the map puts the Town Center; then the Market is selected, with its 6 starting Settlers. The Iroquois AI, whose civ has no tag, keeps its Town Center. [Full video (MP4)](media/civFirstTC.mp4).

```
civFirstTC [log]
```

In `civs.xml`, inside a `<civ>`, next to its `<startingunit>` entries:

```xml
<civ>
    <name>Egyptians</name>
    ...
    <firstTC>EGYtowncenterCARAVAN</firstTC>
</civ>
```

- **In WoL today:** no civ in `civs.xml` has this tag. Each random map script places the players' first buildings itself,
  usually `rmAddObjectDefItem(startingTCID, "TownCenter", 1, 0.0)` and then an `rmPlaceObjectDef*` call,
  or a `CoveredWagon` in a Nomad start (`rmGetNomadStart()`). That is why the Maori start with a
  `TownCenter` that a tech removes ([`startingTC`](#startingtc)). `civs.xml` only lists a civ's units: `<startingunit>` (placed by
  `rmCreateStartingUnitsObjectDef`) and `<townstartingunit>` (settlers and crates that appear at
  the first built Town Center). A civ therefore cannot start with another building unless every
  map script is changed, and only a `TownCenter` becomes the player's first town center
  (`FirstTC`, see [`startingTC`](#startingtc)).
- **Effect,** for the players of a civ that has `<firstTC>Proto</firstTC>`:
  - **Map placement:** where a random map places `TownCenter` through an object def, the player
    gets `Proto` instead, at the same place. The placement uses the larger of the two footprints.
    The same object def still places a `TownCenter` for the players of other civs, and the map
    scripts are not changed. Items are compared by proto ID, so any spelling of `TownCenter` in a
    script counts.
  - **First town center:** the building becomes the player's `FirstTC`, as a `TownCenter` does: the
    placement rules (no enemy building within 65 m, the no-rush rule),
    [`noTrainNearEnemyTC`](#notrainnearenemytc) and `hcShipmentPointFallback FirstTC` use it. A
    unit of that proto added in any other way while the player has no first town center becomes
    it too, so a scenario or a saved game loaded later gets the same first town center.
  - **Town starting units:** the civ's `<townstartingunit>` units appear at the building, when the
    data below allows it.
- **Nomad start:** when `rmGetNomadStart()` is true, nothing is substituted: the map's own start
  (a `CoveredWagon`) stays, and a building of the `<firstTC>` proto does not become the first
  town center through this key. A `TownCenter` the player builds becomes it.
- **Not substituted:** a `TownCenter` from the civ's `<startingunit>` list (the
  `Special_StartingUnits` object def of `rmCreateStartingUnitsObjectDef`, whose items the game
  rebuilds from the civ's list), by design; and Town Centers that triggers, cards, techs or
  players create.
- **The tag:** its name may be written in any case; its text is a proto name as in `protoy.xml`
  (matched in any case; spaces around it are dropped); the last `<firstTC>` of a civ counts. An
  empty tag, or a name that is not a proto, leaves the civ's players with `TownCenter` (logged).
  `<firstTC>TownCenter</firstTC>` changes nothing. The exe ignores the tag, so the file still loads with
  the key off: the civ then starts with its `TownCenter`.
- **WoL needs:**
  - **`data\civs.xml`:** the tag.
  - **For the town starting units,** two more edits. Without them the player gets those units
    only once the player builds a `TownCenter`; none is lost.
    - `<Flag>StartingColonyBuilding</Flag>` on the proto, in `protoy.xml`. The game asks for the town
      starting units when a unit with that flag is created; `TownCenter`
      has it, `Market` does not. In the test, a Market without the flag became the first town
      center and a colony started at it, but no settler came.
    - The proto in the `<starttypes>` of `placementrules\colonies.xml`, e.g.
      `<type maxcount="1">Market</type>`. The units spawn only at a building where a colony
      starts; otherwise the log says `no colony starts at player N's first town center …`.
  - **For shipments:** the exe's fallback of the shipment point knows only 10 building types
    (`TownCenter`, `Outpost`, forts, …). Add `hcShipmentPointFallback FirstTC` (or the proto name)
    so that home city shipments arrive at the building
    ([hcShipmentPointFallback](#hcshipmentpointfallback)).
  - `TownCenter` also has the flags `ColonyPlacementCenter`, `HasGatherPoint`,
    `AllowAutoGarrison` and `ShowGarrisonButton`, which `Market` lacks. This key needs none of
    them; what they change on another building was not tested.
- **What it does not cover:** other code still looks for the `TownCenter` proto itself:
  - the AI scripts: in the test, an AI whose civ had the tag got its Market and its settlers, then
    stayed idle, because its scripts expect a Town Center. WoL's AI must learn the new building;
  - the engine's automatic AI main base;
  - the age-up picker (`uiPoliticianUI`);
  - the start camera (it looks for `TownCenter`, then `CoveredWagon`, `Explorer`, …);
  - the `trPlayerToggleAllowTCSpawning` gate on `Maintain`;
  - the water shipment point.

  The [`startingTC`](#startingtc) section lists the rest.
- **With other keys:** [`startingTC`](#startingtc) can be on too: the two share the hook that sets
  the first town center, and only `startingTC` replaces one that is gone, dead or about to
  expire. [`hcShipmentPointFallback`](#hcshipmentpointfallback) `FirstTC` sends shipments to the
  building, and [`noTrainNearEnemyTC`](#notrainnearenemytc) measures to its edge.
- **`log`:** adds a line for each substitution (per player and object def, when the map is
  generated), one when the building becomes a first town center, and one per game and player
  when the town starting units go to it. That is a few lines per game, so it can stay on.
- **Log:**
  - at startup, `civFirstTC: a civ's <firstTC> proto in civs.xml replaces the TownCenter random
    maps place for its players (not in a Nomad start) and is their first town center (FirstTC)
    (multiplayer unverified)` (with `log`: `…(FirstTC), every substitution logged (multiplayer
    unverified)`);
  - each time `civs.xml` is read, for each tag: `civFirstTC: civ N (Egyptians) starts with Market
    instead of TownCenter`, or `civFirstTC: civ N (Egyptians): empty <firstTC>; its players keep
    TownCenter`;
  - the first time a name is used after the data loads, if it is not a proto: `civFirstTC: civ N
    (Egyptians): <firstTC> names no proto unit (Markt); its players keep TownCenter`;
  - once per game for each player and building, when no colony starts at the building:
    `civFirstTC: no colony starts at player 1's first town center N (Market): its town starting
    units wait for a TownCenter (add the proto to placementrules\colonies.xml <starttypes>)`;
  - `hook reached: civFirstTC civs.xml (0x52BB07)` when `civs.xml` is read, `civFirstTC map
    placement (0x925F4C)` when the map places its first object def, `FirstTC proto check
    (0x506B3B)` (the hook it shares with `startingTC`) and `civFirstTC town units (0x679AC8)` in
    a game.

  With `log`:
  - `civFirstTC: player 1 gets Market instead of TownCenter in object def D 'startingTC'`;
  - `civFirstTC: player 1 keeps TownCenter in object def D 'startingTC' (Nomad start)`;
  - `civFirstTC: unit N (Market) is player 1's first town center (FirstTC)`;
  - `civFirstTC: player 1's town starting units go to its first town center N (Market)`, once per
    game for each player and building.
- **Simulation:** yes: the substitution, the first town center and the town starting units are
  all game state. Every machine needs the same line, `civs.xml`, `placementrules\colonies.xml`
  and `protoy`. A recorded game generates its map again when it is played back, so playback needs
  them too. The key adds no unit type.
- **Status:** confirmed in single player, on the stock game (2026-10-29), with `<firstTC>Market</firstTC>`:
  - a test map that places a `TownCenter` for both players: the tagged civ got a Market, which became
    its first town center, and the other kept its `TownCenter`;
  - a skirmish on Mongolia, with the Market in `colonies.xml` `<starttypes>`: without
    `StartingColonyBuilding` a colony started at it but no settler came; with the flag, 6 Settlers
    spawned at it;
  - an AI of a tagged civ got a Market and its settlers, then stayed idle. An Iroquois AI without the
    tag kept its Town Center and played normally, and a shipment landed at player 1's Market
    ([hcShipmentPointFallback](#hcshipmentpointfallback)).

  Not tested: WoL's civs and buildings, a Nomad start, multiplayer, recorded games, the `no colony` log
  line, and any building other than the Market.

#### customRevolutionBanners

**Added:** Wednesday 2026-10-28 10:56

```
customRevolutionBanners
```

- **Effect:** every revolution tech named `XPRevolution<Name>` shows the banner texture
  `ui\ingame\politicians\REV_banner_<Name>`. The exe shows a banner only for `XPRevolutionOHiggins`
  (`REV_banner_chile`), and that one is kept. `wol.cfg` has this line.
- **WoL needs:** `art\ui\ingame\politicians\REV_banner_<Name>.ddt` for each revolution. WoL's 29 revolution
  techs include `XPRevolutionWOLAlbania` and `XPRevolutionWOLAlgeria`, and their banners are already
  loose in that folder (`rev_banner_wolalbania.ddt`, …). A new revolution only needs its file. File
  names are not case-sensitive.
- **Log:** `hook reached: customRevolutionBanners (0x81A7CC)`.
- **Simulation:** no (interface only).
- **Status:** partly confirmed, on the stock game: the hook runs and the O'Higgins banner still shows.
  WoL's banners were not tested with this DLL.
- **Fixed from UHC 1.10:** the banner path is bounded; upstream overflows its buffer on long tech
  names.

#### removeFameRestriction

**Added:** Wednesday 2026-10-28 10:56

```
removeFameRestriction
```

Three changes:
1. **Politician (age-up) screens** list the Fame, XP and shipment costs of a choice. The second
   politician screen also lists the export resource. The exe shows only food, wood, gold and, on the
   first screen, export.
2. **Home city cards** that cost Fame or XP show an icon for those resources.
3. **"Fame trickle":** the built-in abstract unit type `FavoriteUnit` is renamed `Fame` (same ID). The
   original UnHardcoded project applies this change under that name; how it enables a Fame trickle was
   not traced. WoL's `protoy.xml` and `techtreey.xml` use neither name.

- **WoL needs:** the icons `art\ui\home_city\xp_hc_icon.ddt` and `art\ui\home_city\fame_hc_icon.ddt`.
  They are not in WoL's art, loose or in the archives. Without them, those cards show no icon. `wol.cfg`
  has this line.
- **Log:** `removeFameRestriction: icons need …`;
  `hook reached: removeFameRestriction costs #1 (0x80E490)` (also `#2`, `icon load`,
  `fame icon case`, `XP icon case`).
- **Simulation:** the unit type rename changes game data; give every player the same setting.
- **Status:** not tested in game, on any game.
- **Fixed from UHC 1.10:** on the second politician screen, upstream passes the wrong object
  as the owner of each cost line.

### Healing and hit points

Who heals, whom, and how far.

| Key | What it does | WoL's DLL | WoL also needs | In-game status |
|---|---|---|---|---|
| [`healNonIdle`](#healnonidle) | Lets healers marked with a unit type heal units that are busy (moving, fighting or doing something else). | **new** | That unit type on the healers in `protoy.xml`, or the name of an existing type (`xpMedicineMan`, `AbstractMonk`). | confirmed (automatic healing) |
| [`smartHealTargets`](#smarthealtargets) | A healer's automatic search heals the best candidate, not the first: listed unit types, then the lowest HP ratio, the nearest, the lowest unit ID. | **new** | Nothing (unit types or proto names are optional). | confirmed |
| [`overhealHitpointBars`](#overhealhitpointbars) | The HP bars and HP texts of marked units take `InitialHitpoints` as 100 %, not `MaxHitpoints`. | **new** | `MaxHitpoints` above `InitialHitpoints` on those units (no unit has it today), and the unit type on them, or an existing type such as `AbstractCavalryInfantry`. | confirmed (single player, UI) |
| [`overhealSources`](#overhealsources) | Only source healers heal those units above `InitialHitpoints`; every other heal stops there. | **new** | `overhealHitpointBars`, and the source unit type on the healers that may overheal. | confirmed |
| [`overhealDecay`](#overhealdecay) | The HP of those units above `InitialHitpoints` goes back down to it over time. | **new** | `overhealHitpointBars`. | confirmed |

#### healNonIdle

**Added:** Wednesday 2026-10-28 12:48 · **Filmed in WoL:** Wednesday 2026-11-04 07:20

![healNonIdle in WoL](media/healNonIdle-wol.gif)

*In WoL, with `healNonIdle xpMedicineMan` (Iroquois; the two units are selected):* a Tomahawk fights
a `WOLLineInfantry` while the medicine man heals it between hits: its bar drops with each hit and
fills again. It wins and ends at full HP.
[Full video (MP4)](media/healNonIdle-wol.mp4).

![healNonIdle in WoL, key off](media/healNonIdle-wol-control.gif)

*In WoL, key off (the same scene):* the medicine man does not heal the fighting Tomahawk; its bar
only shrinks and it dies at about 57 s of game time, the enemy left at 51 HP. The medicine man is
next.
[Full video (MP4)](media/healNonIdle-wol-control.mp4).

```
healNonIdle [<UnitType>]      default AbstractHealNonIdle
```

- **In WoL today:** a healer (`Surgeon`, `NAnurse`, `xpMedicineMan`, a monk) only picks targets that are
  idle, and stops healing as soon as its target moves or fights. So a healer behind a line of infantry
  does nothing during a fight.
- **Effect:** healers whose proto is of `<UnitType>` also pick targets that are busy (moving, fighting
  or doing something else), and keep healing them while they move or fight. The other checks still
  apply: the target must be damaged, a valid heal target for that healer, and reachable. Any other
  healer behaves as before.
- **WoL needs:** the name of an existing type or proto needs no data change: `healNonIdle xpMedicineMan`
  (the video) applies the feature to that proto, `healNonIdle AbstractMonk` to WoL's 11 monks. To choose
  the healers one by one, use a marker. Abstract unit types are a fixed list compiled into the exe, and
  any other `<UnitType>` in `protoy.xml` is silently dropped, so this DLL **registers `<UnitType>` as a
  new abstract type** when the data does not define it. List it on any healer in `data\protoy.xml`:

  ```xml
  <Unit id ='424' name ='Surgeon'>
      ...
      <UnitType>LogicalTypeHealed</UnitType>
      <UnitType>AbstractHealNonIdle</UnitType>
  ```

  In WoL's own DLL, add the name to `data\uhc\customabstracttypes.xml` instead.
- **Monks and other fighting healers** may still choose to attack instead of heal: that is the unit's
  own behavior and is not changed. Pure healers such as `Surgeon`, `NAnurse` and `xpMedicineMan` show the
  feature best.
- **Log:** `healNonIdle: healers of unittype X heal busy targets (multiplayer unverified)`; when
  the data loads, `hook reached: abstract unit types (0x51BA31)` and
  `unit types: X -> <ID> (bit B of N), added` (or `already defined`); in a game,
  `hook reached: healNonIdle auto-search (0x9CD9C7)` and `hook reached: healNonIdle (0x9E0C79)`.
- **Check the data:** with the game running, `python -I tools/re/inspect_unittypes.py
  AbstractHealNonIdle` lists the protos that carry the type.
- **Simulation:** yes. It also adds a unit type, which changes the unit type count.
- **Status:** confirmed in WoL (2026-11-04), through the automatic search: the medicine man heals the
  fighting Tomahawk, which wins at full HP; without the key it dies at about 57 s. A direct order
  (right-click) on a fighting unit was not verified.

#### smartHealTargets

**Added:** Thursday 2026-10-29 13:19 · **Filmed in WoL:** Wednesday 2026-11-04 06:59

![smartHealTargets in WoL](media/smartHealTargets-wol.gif)

*In WoL, with `smartHealTargets log` (United States; the units are selected, so their HP bars show):*
four settlers are hit at once (90, 70, 45 and 33 % HP); the `NAnurse` heals the one at 33 % first
(8.2 m away), then 45, 70 and 90 %.
[Full video (MP4)](media/smartHealTargets-wol.mp4).

![smartHealTargets in WoL, key off](media/smartHealTargets-wol-control.gif)

*In WoL, key off (the same scene):* the nurse takes the first settler the query returns, the one
at 45 % 4 m away, while the one at 33 % waits at 50 HP; the settlers at 70 and 90 % wait too.
[Full video (MP4)](media/smartHealTargets-wol-control.mp4).

```
smartHealTargets [<UnitType> ...] [log]   up to 8 types, in priority order
```

- **In WoL today:** an idle healer looks for a unit to heal on its own: it asks for the units around it
  and heals the **first** one that passes every test (damaged, alive, idle, a valid heal
  target, not already healed by others, in range). The order is the query's, so a healer often
  tops up a nearly full unit next to it while a badly hurt one waits.
- **Effect:** the same tests decide which units can be healed, and among them the healer picks:
  1. the unit types you list, in their order (a unit of none of them comes after them);
  2. then the lowest HP ratio (HP / max);
  3. then the nearest to the healer;
  4. then the lowest unit ID.

  No memory address and no query order is used, so every machine picks the same unit. With no
  type, it is the most hurt unit in reach. Only the automatic search changes: a direct order
  (right-click) heals what the player chose.
- **Every healer:** the key applies to every healer, with no marker on the healers: the search is
  the same function for surgeons, nurses, monks, priests and the others, and the key only reorders
  units the exe already accepts. Name a type to favour targets, e.g.
  `smartHealTargets AbstractInfantry Settler`.
- **With `healNonIdle`:** both keys hook the same search at different points and work together:
  marked healers also see busy units, and the best of all candidates is healed.
- **Log:** `smartHealTargets: automatic heal searches pick the best candidate: <types, >lowest HP
  ratio, nearest, lowest unit ID (multiplayer unverified)`; in a game `hook reached:
  smartHealTargets candidate (0x9CDA36)` and `pick (0x9CDA58)`; with `log`, every pick (the first
  200): `smartHealTargets: unit 0 (Surgeon) heals unit 4 (Settler, rank 0, HP ratio 0.333, 10.0
  m) among 4 candidates; stock would heal unit 1 (Settler, HP ratio 0.900)`.
- **Simulation:** yes, every machine needs the same line. A listed name that is not a type yet is
  registered as a marker unit type, which changes the unit type count.
- **Status:** confirmed in single player. In WoL (2026-11-04), a `NAnurse` with four settlers hit at once
  healed them in the order 33, 45, 70, 90 %; without the key it took the first the query returned, at
  45 %. On the stock game (2026-10-29), with a listed type, that type came first, and with
  `healNonIdle` both hooks ran. A skirmish against the AI with the key on played normally. Multiplayer
  was not tested.

#### overhealHitpointBars

**Added:** Thursday 2026-10-29 10:35 · **Filmed in WoL:** Wednesday 2026-11-04 10:29

![overheal in WoL](media/overhealHitpointBars-wol.gif)

*In WoL, with `overhealHitpointBars segment stat log`, `overhealSources log` and `overhealDecay 2 3 log`
(Iroquois; the Tomahawk selected):* for the test the Tomahawk is marked and has `MaxHitpoints` 180 over
its 150, and the medicine man is a source healer (bed data, removed after). It is hit, the medicine man
heals it past its 100 %, and the panel reads `180/150` and, in orange, `Overheal: 30/30`. When he is
killed at 62 s it loses 2 HP a second back to 150, and the row goes. The Aenna next to it, not marked,
stops at 110.
[Full video (MP4)](media/overhealHitpointBars-wol.mp4).

![overheal in WoL, keys off](media/overhealHitpointBars-wol-control.gif)

*In WoL, keys off (the same data and scene):* the panel counts the 180 as the 100 % (`180/180`), there
is no row, and nothing brings the Tomahawk back down after the healer dies.
[Full video (MP4)](media/overhealHitpointBars-wol-control.mp4).

```
overhealHitpointBars [<UnitType> ...] [segment[=RRGGBB]] [stat[=<Label>]] [log]   default AbstractOverheal; up to 8 types
```

- **In WoL today:** a unit is created with its proto's `<InitialHitpoints>` and can be healed up to
  `<MaxHitpoints>`. Every HP display takes `MaxHitpoints` as 100 %: the floating HP bar over a unit, the
  selection panel's HP bar (green, yellow below 66 %, red below 33 %), and the texts `HP/max`, or
  `HP/max (base+bonus)` when techs raised the max. WoL plans `MaxHitpoints` = 1.1 × `InitialHitpoints` on
  infantry and cavalry, so that healers can push them above their starting HP. Today no unit in
  `protoy.xml` has it, and with that data every fresh unit would show as damaged: a 91 % bar and
  `150/165`.
- **Effect:** for a unit whose proto is of `<UnitType>` and has `InitialHitpoints` below
  `MaxHitpoints`, the displays take `InitialHitpoints` as 100 %:
  - a fresh unit (HP = `InitialHitpoints`) shows a full bar and `150/150`;
  - an overhealed unit shows a full bar (the bar is not drawn past 100 %) and `165/150`;
  - a damaged unit shows its HP against `InitialHitpoints`: 105 HP is a 70 % green bar and `105/150`,
    where the exe shows a 64 % yellow bar and `105/165`;
  - the selection's average health counts each unit at most 100 %;
  - `(base+bonus)`: the base is the proto's `InitialHitpoints` in the data, the bonus what techs
    added since.

  Units of other types, and marked units whose `InitialHitpoints` is not below `MaxHitpoints`, display
  as before.
- **`segment`** (Overwatch style): the HP above 100 % is shown too.
  - The floating bar stays full and the overheal is drawn over its right end, in orange: a unit at
    165/150 has its right 10 % orange; from twice its 100 % the whole bar is orange. The bar keeps its
    width.
  - The unit panel's HP text above 100 % is orange too (`165/150`), through the game's own colour
    markup.
  - `segment=RRGGBB` sets another colour (hex, e.g. `segment=40C0FF`).
  - The floating bar is drawn in the player's colour, so the segment sits next to it.
  - No data change is needed beyond the marker for these.
  - The bar under the selected unit's portrait shows the overheal too, when the UI data has a
    fourth bar for it (below, "The portrait bar"): while the selected units have overheal and the green
    bar is full, that bar is drawn over it, its mask (green) on the left and its background (the
    overheal colour) on the right end, (HP − 100 %) / 100 % of its width (the average of the selected
    units). Below 100 % the green / yellow / red bar shows, as without the key.
- **`stat`:** in WoL's minimized interface (`optionminimizedui`), which has no stat panel, the row goes in
  the unit panel, in the gadgets `unitResourceRateLabel` and `unitResourceRateValue` that
  `showGatherRate` also uses, with one unit selected and only while it has overheal: `Overheal: 30/30`,
  the HP above its 100 % and the most it can have (max − 100 %), truncated like the HP row. A gathering
  unit shows its rate instead, since the row is one. With `segment` the value is in the segment colour.
  The label is `Overheal`, or `stat=<Label>`: one word, `_` for a space (`stat=Sobre_curación`; UTF-8 or
  ANSI), or a number, which takes that string from `stringtabley.xml` (`stat=90001`), so a language can
  translate it.
  - In the normal interface, the same row goes in the "Unit information" panel, right after the HP
    row, for every marked unit, and the rows below move down one.
- **What does not change:** the hit points themselves, healing (healers still heal up to
  `MaxHitpoints`, which is what makes the overheal possible), techs, auras, AI, triggers and every
  other game rule: they all keep reading `MaxHitpoints`.
- **Choosing the units:** an existing type works with no marker: `overhealHitpointBars
  AbstractCavalryInfantry` covers the 910 protos that carry that type, WoL's infantry and cavalry. A
  proto name works too, and up to 8 names may follow the key on one line. The default marker
  `AbstractOverheal` is registered by the DLL, like `healNonIdle`'s.
- **WoL needs:** `<MaxHitpoints>` above `<InitialHitpoints>` on the units, in `data\protoy.xml`:

  ```xml
  <Unit name ='Tomahawk'>
      ...
      <InitialHitpoints>150.0000</InitialHitpoints>
      <MaxHitpoints>165.0000</MaxHitpoints>
  ```

- **Techs and auras:** a `Hitpoints` tech adds the same amount to `InitialHitpoints` as to
  `MaxHitpoints`. A percentage tech therefore leaves a full unit slightly below 100 %: after
  +10 % on 150/165, `InitialHitpoints` is 166.5 and a unit that was at 150 HP has 165 (99 %). An aura or
  modifier that changes one unit's max scales its reference by the same factor, so a full unit stays
  full (seen on the stock game: a Golden Pavilion's MaxHP x1.1 aura took a unit from `165/150` to
  `181/165 (150+15)`, `Overheal 15/15` to `16/16`). In a skirmish, an Explorer marked for a test (400 /
  440 in the data) showed `180/180` and `Overheal 0/40`: a start-of-game effect lowers both values by
  the same amount, and the reference follows it.
- **The portrait bar (UI data).** WoL's selection panel looks up its bars by name in
  `data\uiunitselectionmin.xml`: three `progressBar` gadgets at the same place,
  `unitselectionpanel-unitHealthBarGreen`, `…Yellow` and `…Red`, of which it shows one. With `segment`, the
  key looks up a fourth, `unitselectionpanel-unitHealthBarOverheal`, and shows, fills and hides it
  itself. Without it, the portrait bar stays as it is (the log says which), which is why the videos
  above show no orange there. To have it, add this after the `…Red` gadget of that file (and of
  `uiunitselection.xml`, for the normal interface): the same `size1024`, a higher `z`, the overheal
  colour as its background and the HP colour as its mask. A progress bar draws nothing without a
  background:

  ```xml
  <gadget name="unitselectionpanel-unitHealthBarOverheal" type="progressBar" size1024="342 759 412 766"
          z="111" progressbarbackground="ui\ingame\uhc_health_overheal" progressbarbackgroundsize="104 8"
          progressbarmask="ui\ingame\ingame_ui_health_green"/>
  ```

  The background texture is yours: the tests used a 16 x 8 DXT1 orange gradient,
  `art\ui\ingame\uhc_health_overheal.ddt` (`ui\ingame\ingame_ui_health_yellow` works too). The gadget
  was tested in the normal interface of the stock game, and not yet in WoL's file.
- **`log`:** one line for the first unit of each proto whose reference differs from its max (once
  per proto name in a session).
- **Log:** at startup `overhealHitpointBars: HP bars and HP texts of units of unittype X take
  InitialHitpoints as 100 % (display only)` (several types are listed as `X, Y`; with `log`: `…as
  100 %, the first unit of each proto logged (display only)`); when the data loads, `unit types: X
  -> <ID> …`; in a game, `hook reached: overhealHitpointBars (0x45FAAF)` (the first floating HP
  bar), `(0x4C5014)` (the first selection), and for the HP texts `(0x698B35)`, `(0x4D7575)` with
  `(0x4D7615)`, or `(0x9AFA2A)` with `(0x9AFA4E)`, depending on which panel shows them. With
  `log`: `overhealHitpointBars: unit N (Tomahawk) HP 150.0 is shown against 150.0 instead of its
  max 165.0 (InitialHitpoints 150.0, MaxHitpoints 165.0); logged once per proto`.
  With `segment`: the startup line adds `HP above it shown as a segment and texts coloured
  FF8C00`; in a game `hook reached: overhealHitpointBars segment queue (0x45FB6C)`, `segment fit
  (0x45C4B9)`, `segment vertices (0x45CB72)` and `text (0x4D7651)` (`text (0x69A9C0)` for the
  `(base+bonus)` form); with `log`, `overhealHitpointBars: unit N (Tomahawk) HP 165.0 is above its
  100 % 150.0: overheal segment of 10.0 % of the bar; logged once per proto`; and, only if a frame
  ever has more bars than the vertex buffer holds (about 9,700), `… bars do not fit in the vertex
  buffer …: this frame's K overheal segments were dropped (logged once)`. A wrong colour stops the
  key: `overhealHitpointBars: segment=…: expected segment or segment=RRGGBB (hex); feature not
  applied`. The portrait bar: `hook reached: overhealHitpointBars portrait bar (0x4C83DF)`, then
  `overhealHitpointBars: the UI has unitselectionpanel-unitHealthBarOverheal: the portrait bar
  shows the overheal (logged once)` or `the UI has no …: the portrait bar stays stock`; with `log`,
  `the portrait bar shows an overheal of 10.0 % of the bar (1 units; logged once)`.
  With `stat`: the startup line adds `an overheal stat row labelled 'Overheal'` (or `labelled by
  string N`); in a game `hook reached: overhealHitpointBars stat row (0x4D76DB)`; with `log`,
  `stat row 2 of unit N (Tomahawk): overheal 15/15 (logged once)` (with its colour markup). A bad
  label stops the key: `overhealHitpointBars: stat=…: expected stat or stat=<label> (a word, '_'
  for a space, or a string table ID); feature not applied`.
- **Limits:**
  - without `segment` the floating bar stops at 100 %;
  - the portrait bar needs the fourth gadget in the UI data (above);
  - in the minimized interface `unitHitPointsValue` prints colour markup as text (seen in game), so the
    HP text stays white and only the `stat` row is coloured. The ObjectInfo panel (the scenario
    editor's) is not coloured either;
  - other places still compare HP with `MaxHitpoints` and see a fresh marked unit as damaged: the
    damage-state visuals, the AutoRepairUnit command check (moot for infantry and cavalry), and the
    HP shown in tech and card rollovers;
  - whether the multi-selection stack buttons draw their own HP bars was not established.
- **Simulation:** no. Only display code is hooked (floating bars, the selection's group, three HP
  texts, the portrait bar's gadget, the stat row); every game rule reads the real max. Players may set it differently. A new marker name
  adds a unit type, which changes the unit type count: load saved games and replays with the same
  cfg.
- **Status:** confirmed in single player.
  - **In WoL (2026-11-04):** a marked Tomahawk at `180/150` with `Overheal: 30/30` in the unit panel; an
    unmarked Aenna at its own max; without the keys, `180/180` and no row.
  - **On the stock game (2026-10-29), normal interface:** fresh units at `150/150` with a full bar, the
    orange segment and text, `segment=40C0FF`, a `Hitpoints` tech (`189/174 (150+24)`), an allied
    player's units, the portrait bar with the fourth gadget (90 % green, 10 % orange), the aura case
    above, and a skirmish against the AI.
  - **Not tested:** the portrait bar in WoL's interface, the ObjectInfo panel, multiplayer.

#### overhealSources

**Added:** Thursday 2026-10-29 13:37 · **Filmed in WoL:** Wednesday 2026-11-04 10:29

![overhealSources in WoL](media/overhealSources-wol.gif)

*In WoL, with `overhealSources log` (a `NAnurse` next to the marked Tomahawk, selected):* the Tomahawk
is hit at 24 s. The nurse is not a source healer: she heals it to `150/150` and stops (`a heal of unit 1
stops at its 100 %`). At 52 s a source medicine man appears, and the panel climbs to `179/150`, with
`Overheal: 29/30`. [Full video (MP4)](media/overhealSources-wol.mp4).

![overhealSources in WoL, key off](media/overhealSources-wol-control.gif)

*In WoL, key off (the same scene):* the nurse herself heals it past its 100 %.
[Full video (MP4)](media/overhealSources-wol-control.mp4).

![overhealSources with the Regeneration dance in WoL](media/overhealSources-dance-wol.gif)

*In WoL, an area heal, the Regeneration dance (Ethiopian fire pit, `danceBonusCivs Ethiopians`; the
tactic is turned on for the test):* it heals the marked Tomahawk to `150/150` and stops there, because
a dance is not a source. [Full video (MP4)](media/overhealSources-dance-wol.mp4).

![overhealSources with the dance in WoL, key off](media/overhealSources-dance-wol-control.gif)

*In WoL, key off (the same scene):* the dance takes it to `180/150`, `Overheal: 30/30`.
[Full video (MP4)](media/overhealSources-dance-wol-control.mp4).

```
overhealSources [<UnitType> ...] [log]   default AbstractOverhealer; up to 8 types
```

- **Needs** [`overhealHitpointBars`](#overhealhitpointbars): its unit types mark the units that
  have overheal, and its 100 % (`InitialHitpoints`, scaled when an aura changes the max) is the
  limit here. Without that line the key is not applied.
- **Effect,** for a marked unit:
  - a healer whose proto is of a source type (default `AbstractOverhealer`, a new marker; an existing
    type or a proto name works too) heals it up to `MaxHitpoints`;
  - any other healer heals it only up to its 100 %: its automatic search does not pick a marked
    unit at its 100 %, and its heal action ends when the unit gets there (the healer goes idle);
    a direct order on such a unit ends at once;
  - every other way of gaining HP stops at the 100 % too: regeneration, the Regeneration dance,
    area heals, self heals, powers and triggers that add HP. Only the single-target heal action of
    a source healer overheals. Damage, and code that sets HP rather than adding it (creation,
    transforms, the aura rescale), are not touched.

  Unmarked units heal as before.
- **WoL needs:** the source type on the healers that may overheal, e.g.
  `<UnitType>AbstractOverhealer</UnitType>` on `xpMedicineMan` in `data\protoy.xml`, or name an existing
  type: `overhealSources AbstractMonk`, or a proto: `overhealSources xpMedicineMan`.
- **Log:** `overhealSources: only healers of unittype X heal marked units above their 100 %; every
  other heal stops there (multiplayer unverified)`; when the data loads `unit types: X -> <ID> …`;
  in a game `hook reached: overhealSources heal search (0x9CD984)`, `heal tick (0x9E0BBB)`, `heal
  (0x9E0CE9)` and `overheal add HP (0x4823A3)`. With `log`, the first of each proto: `overhealSources:
  a heal of unit N (Tomahawk) stops at its 100 % 150.0 (…; not from a source healer)` and `…unit N
  (Tomahawk) is healed above its 100 % 150.0 by a source healer (…)`. Without
  `overhealHitpointBars`: `overhealSources: needs overhealHitpointBars, …; feature not applied`.
- **Simulation:** yes. Every machine needs the same line (and `overhealHitpointBars` with the same
  types). The source type is a new unit type, which changes the unit type count.
- **Status:** confirmed in single player.
  - **In WoL (2026-11-04):** a `NAnurse` healed a marked Tomahawk to `150/150` and stopped, and a source
    medicine man took it to `179/150`; without the key the nurse herself went past it. The Regeneration
    dance stopped at `150/150`, and went to `180/150` without the key.
  - **On the stock game (2026-10-29):** a healing building stopped at the 100 %, an idle surgeon ignored
    a marked unit at its 100 %, a direct order ended on arrival, and a unit's own regeneration stopped
    at its 100 %. A knocked-out hero still gets up, at about 40 % of its HP. A skirmish against the AI
    played normally.
  - **Not tested:** powers (`PowerHeal` goes through the same add-HP entry, 0x7C378C / 0x8CCA6F),
    multiplayer.

#### overhealDecay

**Added:** Thursday 2026-10-29 13:50 · **Filmed in WoL:** Wednesday 2026-11-04 10:29

![overhealDecay in WoL](media/overhealDecay-wol.gif)

*In WoL, with `overhealDecay 2 1 log` (Menelik II marked for the test, 400 of 480 HP):* Explorers
regenerate, and the decay takes back what goes above the 100 %: he stays at `400/400`, with no row.
[Full video (MP4)](media/overhealDecay-wol.mp4).

![overhealDecay in WoL, key off](media/overhealDecay-wol-control.gif)

*In WoL, key off (the same scene):* he regenerates past his 100 %, and the panel climbs with it:
`447/400`, `Overheal: 47/80`, on the way to 480. [Full video (MP4)](media/overhealDecay-wol-control.mp4).

```
overhealDecay <rate>[%] [<delay>] [<UnitType> ...] [log]
```

- **Needs** [`overhealHitpointBars`](#overhealhitpointbars): its types mark the units and its
  100 % (`InitialHitpoints`, scaled when an aura changes the max) is where the decay stops.
- **Effect:** a marked unit whose HP is above its 100 % loses `rate` HP per second (`2`), or
  `rate` percent of its 100 % per second (`1%`), counted in game time (paused games and game speed
  follow), once `delay` seconds (default 0, decimals allowed) have passed since it last gained HP
  above its 100 %. It stops exactly at its 100 %: the decay never goes below it and never kills.
  With unit types (or proto names) listed, only marked units of those types decay. Works with or
  without [`overhealSources`](#overhealsources): with it, only source healers create overheal to
  decay; without it, any heal above the 100 % does.
- **What counts as a gain:** any heal that takes the unit above its 100 % (healers, area heals,
  powers…) restarts the delay. Regeneration (the unit's own, and the Regeneration dance) does not:
  it heals a little on every step, so it would hold the delay forever; a unit that regenerates
  above its 100 % decays at once (the rate minus what it regenerates). With `overhealSources`,
  regeneration never passes the 100 % anyway. HP that a unit has above its 100 % without any gain
  (a transform into another marked proto, for instance) does not decay until its next gain.
- **Log:** `overhealDecay: marked units above their 100 % lose R HP per second of game time, D s
  after their last gain, down to it (multiplayer unverified)`; in a game `hook reached: overheal add
  HP (0x4823A3)`, `hook reached: world update (0x481A57)`, `hook reached: overhealDecay
  regeneration (0x490881)` and, with a Regeneration dance, `overhealDecay Regeneration dance
  (0x67A03B)`. With `log`, the first of each proto:
  `overhealDecay: unit N (Tomahawk) decays from 165.0 toward its 100 % 150.0 at 2.00 HP/s` and
  `… is back at its 100 % 150.0`. Without `overhealHitpointBars`: `overhealDecay: needs
  overhealHitpointBars, …; feature not applied`; a bad rate: `overhealDecay: expected <HP per
  second>[%] [delay seconds] [UnitType ...] [log], …; feature not applied`.
- **Simulation:** yes, every machine needs the same line. A listed name that is not a type yet is
  registered as a marker unit type.
- **Status:** confirmed in single player.
  - **In WoL (2026-11-04):** with `overhealDecay 2 1`, Menelik II, marked, stayed at `400/400` while he
    regenerated; without the key he went to `447/400` and on. With `overhealDecay 2 3`, a Tomahawk fell
    back to 150 after its healer died.
  - **On the stock game (2026-10-29):** `overhealDecay 2% 1 Musketeer` took 3 HP per second (2 % of 150)
    down to 150, and naming another proto left that unit alone; other players' units decay too; poison
    (`damageOverTime`) ticked normally; a skirmish against the AI played normally. Only the game world
    decays: the world update also runs for the home city's world, which the key ignores.
  - **Not tested:** multiplayer.

### Combat

Attacks, armor, and what a hit does.

| Key | What it does | WoL's DLL | WoL also needs | In-game status |
|---|---|---|---|---|
| [`multiarmor`](#multiarmor) | A proto keeps one armor per damage type, and `Armor` tech effects change the one their `damagetype` names. | **in `wol.cfg`** | Several `<Armor>` lines on the protos. | confirmed |
| [`dodgeAnyUnit`](#dodgeanyunit-dodgesoundset-and-criticalsoundset) | Lets units marked with a unit type dodge hits like the Japanese monk (no damage, 15 % of the hits, while their player has `YPDodge`). | **new** | That unit type on the units in `protoy.xml`, or a type or proto name in the cfg, and `YPDodge` active for their players. | confirmed (single player) |
| [`dodgeSoundSet`, `criticalSoundSet`](#dodgeanyunit-dodgesoundset-and-criticalsoundset) | Chooses the sound set a unit plays when it dodges or lands a critical hit. | **new** | A sound set name in the cfg. | confirmed (single player, from the log) |
| [`dodgeChance`](#dodgechance) | A dodge chance per unit type, with the tech it needs (or none) and a filter for ranged or melee hits; the first matching rule decides. | **new** | A unit type or proto name in the cfg, and the rule's tech active for their players unless `notech`. | confirmed (single player) |
| [`damageOverTime`](#damageovertime) | Poison: an attack that names an attachment proto keeps damaging its target every few seconds after the hit. | **new** | `<AttachProtoUnit>` on the attack, a new attachment proto in `protoy.xml`, and a small tactics file. | confirmed (single player) |
| [`spreadAnyAccuracy`](#spreadanyaccuracy) | Reads `<maxspread>` and `<spreadfactor>`, which 317 of WoL's tactics files have and the exe ignores, for every miss, and makes every shot of marked units scatter like that whatever their accuracy, dealing its area damage where it lands. | **new** | The tags are there; a `<DamageArea>` on the attacks that should always scatter, and their unit type or proto name in the cfg. | confirmed (single player) |
| [`broadsideMuzzleLimit`](#broadsidemuzzlelimit) | Lets a ship's broadside fire from up to N muzzles per side instead of 6. | **new** | A ship model with more than 6 muzzles per side: `ypTekkousen` has 10. | confirmed (single player) |
| [`snareOnlyHitUnit`](#snareonlyhitunit) | A snared unit no longer slows the group it moves with; only the hit unit slows. | **new** | Nothing. | confirmed (single player) |
| [`rofFix`](#roffix-stunmovingtargetfix-nodamageonunbuiltfoundations-and-fallenherotacticsfix), [`stunMovingTargetFix`](#roffix-stunmovingtargetfix-nodamageonunbuiltfoundations-and-fallenherotacticsfix), [`noDamageOnUnbuiltFoundations`](#roffix-stunmovingtargetfix-nodamageonunbuiltfoundations-and-fallenherotacticsfix), [`fallenHeroTacticsFix`](#roffix-stunmovingtargetfix-nodamageonunbuiltfoundations-and-fallenherotacticsfix) | Four small combat fixes: orders keep the attack timer, stuns survive a moving target, unbuilt foundations take no damage, units keep their tactic when knocked out. | always on | Nothing. | applied, effects not seen yet |
| [`removeConversionRestriction`](#removeconversionrestriction) | Lets `ConvertGuardian` convert any unit, not only treasure guardians. | **in `wol.cfg`** | Nothing. | not confirmed |

#### multiarmor

**Added:** Tuesday 2026-11-03 09:33

![multiarmor in game](media/multiarmor.gif)

*In WoL:* a `HonorGuard`, with `<Armor type="Hand" value="0.2"/>` and `<Armor type="Ranged" value="0.2"/>`,
under pikemen: each pike hit takes 38 HP (armor 0.2); without the key it took 47.5 (the unit kept only
its last armor, Ranged). [Full video (MP4)](media/multiarmor.mp4).

```
multiarmor
```

- **In WoL today:** `wol.cfg` has this line, and 32 protos and 76 tech effects depend on it. Without it,
  the exe keeps one armor per proto: each `<Armor>` replaces the one before, so only the last one
  counts. It also reads no `damagetype` on effects: an `Armor` effect always changes that one armor.
- **Effect:** a proto keeps one armor per damage type, and an `Armor` tech effect changes the one its
  `damagetype` names. The unit uses the armor of the incoming damage type. An effect whose `damagetype`
  is the last armor's type, or that has no `damagetype`, works as in the exe.
- **WoL needs:** several `<Armor>` lines on the proto, as `HonorGuard` has, and `damagetype` on the
  effects:

  ```xml
  <Armor type="Hand" value="0.2000" />
  <Armor type="Ranged" value="0.2000" />
  ```

  ```xml
  <Effect type='Data' amount='1.50' subtype='Armor' damagetype='Ranged' relativity='BasePercent'>
    <Target type='ProtoUnit'>AbstractLightInfantry</Target></Effect>
  ```

  Up to 8 armors per proto. An effect on a damage type the proto has no armor for starts from 0 (so
  `BasePercent` changes nothing there).
- **What stays as it is:** the unit panel shows the last armor only, and saved games do not keep the
  other armors' tech changes (a loaded game has their data values).
- **Log:** `multiarmor: protos keep one armor per damage type; ...`; `multiarmor: <Proto> has N
  armors` for the first proto with several; `multiarmor: an Armor effect changed damage type T of
  <Proto> (now V; stock type S kept)` the first time an effect goes to another armor;
  `unknown damagetype "..."` for a name the game does not know.
- **Simulation:** changes combat: every player needs the same line.
- **Status:** confirmed (2026-11-03, single player, on WoL): `HonorGuard` took 38 per pike hit with the
  key and 47.5 without it. `gwDreadnought`, with `GWantitorpedobulge` (+0.1 Ranged, +0.1 Siege effects):
  with the key Siege went to 0.4 and Ranged to 0.5; without it Siege went to 0.5. Performance A/B in a
  battle of 160 units, 60 s each: 1263 / 1289 fps, update 0.138 / 0.136 ms, one frame over 50 ms each
  (no measurable cost). Video `multiarmor.mp4`.

#### dodgeAnyUnit, dodgeSoundSet and criticalSoundSet

**Added:** Wednesday 2026-10-28 19:12 · **Filmed in WoL:** Wednesday 2026-11-04 07:20

```
dodgeAnyUnit [<UnitType>] [log]          default AbstractDodge
dodgeSoundSet <UnitType> <SoundSet>      one line per unit type; the first match wins
criticalSoundSet <UnitType> <SoundSet>   one line per unit type; the first match wins
```

- **In WoL today:** a hit can be dodged (it does no damage) only when the target is a Japanese monk: the
  exe compares the target's proto with `ypMonkJapanese`, `ypMonkJapanese2` and `ypMonkJapanese3`. The
  dodge then needs the tech `YPDodge` to be active for the target's player (`ypMonasteryJapaneseCombat`
  activates it), and happens on 15 % of the hits. A dodge shows a floating text and plays the sound set
  `PowerEvade`; a critical hit (an attack with `<HitPercentType>CriticalAttack</HitPercentType>`, e.g.
  the Chinese monk's) plays `PowerCriticalStrike`. Both sound sets are the same for every unit.
- **Effect of `dodgeAnyUnit`:** units whose proto is of `<UnitType>` can dodge too, through the same
  code: the `YPDodge` tech of their player, the 15 % roll, the floating text and the sound are
  unchanged. The Japanese monks keep dodging.
- **WoL needs:** a type or proto name in the cfg (`dodgeAnyUnit Settler`, `dodgeAnyUnit AbstractInfantry`)
  needs no data change, or put the marker `AbstractDodge` on the protos. Then make `YPDodge` active for
  the players who should have it, from a tech of that civ, such as its `Age0<Civ>` tech or a home city
  card:

  ```xml
  <Effect type ='TechStatus' status ='active'>YPDodge</Effect>
  ```

- **Effect of `dodgeSoundSet` / `criticalSoundSet`:** a unit of `<UnitType>` (a unit type, which may be a
  marker, or a proto name) plays `<SoundSet>` instead of the usual set: when it dodges, for
  `dodgeSoundSet`; when it lands a critical hit, for `criticalSoundSet` (the sound belongs to the
  attacker). `<SoundSet>` is the name of a sound set of the game's sound data (`soundsetsy.xml`). A unit
  that matches no line keeps the usual sound. These two keys work with or without `dodgeAnyUnit`.
- **`log`:** writes one line per dodge, and, while `dodgeAnyUnit … log` is set, one line per
  dodge or critical sound with the set it played. Use it to check your data, not in a release:
  a long game writes many lines.
- **Log:** `dodgeAnyUnit: units of unittype X can dodge like ypMonkJapanese (tech ypDodge, 15 %)`
  and one `dodgeSoundSet:` / `criticalSoundSet:` line per rule; when the data loads,
  `unit types: X -> <ID> …`; in a game, `hook reached: dodge test (0x49ACE5)` (the first time a
  unit with a player is hit while the tech tree exists), `hook reached: dodgeSoundSet (0x6A2628)`
  (the first visible dodge) and `hook reached: criticalSoundSet (0x6A2A9A)` (the first critical
  hit). With `log`: `dodgeAnyUnit: unit N (Proto) dodged a hit` and
  `dodgeSoundSet: unit N (Proto) plays sound set S`.
- **Simulation:** `dodgeAnyUnit` yes (a dodged hit does no damage; it also adds a unit type, which
  changes the unit type count). The sound keys no.
- **Status:** confirmed in single player. In WoL (2026-11-04), with `dodgeAnyUnit Settler`: the video
  under [dodgeChance](#dodgechance), a European settler dodging at 15 %. On the stock game (2026-10-28), a
  marked Explorer dodged 5 hits of four attackers in 30 s, a Japanese monk next to it still dodged, and
  with a marker no unit had the Explorer never dodged. `dodgeSoundSet` and `criticalSoundSet` picked the
  configured sets, in the log; the sound itself was not listened to, and the floating text was not
  checked.

#### dodgeChance

**Added:** Thursday 2026-10-29 16:57 · **Filmed in WoL:** Wednesday 2026-11-04 07:20

![dodgeChance and dodgeAnyUnit in WoL](media/dodge-wol.gif)

*In WoL, with `dodgeChance ypSettlerJapanese 50 notech ranged log` and `dodgeAnyUnit Settler log`
(`YPDodge` active; the villagers are selected):* three Redcoats shoot four villagers that do not
shoot back. The two Japanese settlers dodge 18 of their 31 rolls, the European settler dodges at the
exe's 15 %, and the unmarked Indian settler, which never dodges, dies first.
[Full video (MP4)](media/dodge-wol.mp4).

![dodge in WoL, keys off](media/dodge-wol-control.gif)

*In WoL, keys off (the same scene):* no villager dodges; every hit takes HP off the bars and all
four are dead before 65 s of game time.
[Full video (MP4)](media/dodge-wol-control.mp4).

```
dodgeChance <UnitType> <percent> [tech <TechName> | notech] [ranged | melee | all] [log]
```

One line per rule; several lines add up, and the first rule that matches a hit decides.

- **In WoL today:** only the three Japanese monks dodge, on 15 % of the hits (15 of the 101 values of the
  roll), while their player has `YPDodge` ([dodgeAnyUnit](#dodgeanyunit-dodgesoundset-and-criticalsoundset)).
- **Effect:** each hit on a unit is matched against the rules, in cfg order. A rule matches
  when the unit's proto is of `<UnitType>` (a marker, an existing type or a proto name) and, with
  `ranged` or `melee`, when the hit's damage type is `Ranged` or `Hand` (of `damagetypes.xml`;
  `all`, the default, matches every hit, `Siege` included). The first matching rule decides:
  - its tech must be active for the unit's player: `YPDodge` by default;
    `tech <TechName>` another tech; `notech` none. Otherwise the hit lands;
  - the hit is then dodged with `<percent>` % chance: 0 to 100, one decimal at most (`12.5`),
    drawn from the game's synced random numbers. 0 % and 100 % draw nothing;
  - a dodge is the exe's dodge: no damage, the floating text, the dodge sound (`dodgeSoundSet` still
    picks it).

  A rule's units dodge with or without `dodgeAnyUnit`. A hit that no rule matches keeps the other keys'
  behaviour: a unit with `dodgeAnyUnit`'s marker gets 15 % with `YPDodge`, a Japanese monk its usual
  dodge, any other unit no dodge.
- **Per damage type:** `dodgeChance X 40 ranged` then `dodgeChance X 10 melee` gives 40 % against
  ranged hits and 10 % against melee hits; siege hits match neither and fall back as above.
  `dodgeChance X 0 melee` alone stops marked units from dodging melee hits.
- **WoL needs:** a type or proto name in the rule, or a marker on the units, as for
  [dodgeAnyUnit](#dodgeanyunit-dodgesoundset-and-criticalsoundset), and the rule's tech active for their
  players (none with `notech`).
- **`log`** (on any line): once per data load, each rule's resolved tech and damage type; then
  one line per roll: `dodgeChance: unit N (Explorer), rule 1 (50.0 %): roll 238 -> dodged` (the
  roll is 0..999 and dodges below the percent × 10; −1 when nothing is drawn), or `… rule 2: tech
  X not active -> hit`. For checking data: a long game writes many lines.
- **Log:** at startup `dodgeChance: rule K: units of X dodge P % of ranged hits, with tech T
  (multiplayer unverified)`; in a game `hook reached: dodge test (0x49ACE5)`. A tech or damage
  type that does not exist is logged once per data load and disables its rule (the next rules
  still apply): `dodgeChance: rule K (X): no tech named T; rule disabled`. A bad line stops the
  key, and the other dodge keys with it: `dodgeChance: expected "dodgeChance <UnitType> <percent
  0-100> …" (bad percent 150); feature not applied` or `dodgeChance X: unexpected argument …`,
  then `dodgeAnyUnit/dodgeChance/dodgeSoundSet/criticalSoundSet: FAILED`.
- **Simulation:** yes, every player needs the same lines. The rolls use the stream of the game's synced
  random numbers that the exe's dodge uses, only for hits that a rule between 0 and 100 %
  matches, the same on every machine. A rule's type that the data does not define adds a unit
  type: load saved games and replays with the same cfg.
- **Status:** confirmed in single player. In WoL (2026-11-04): `dodgeChance ypSettlerJapanese 50 notech
  ranged` gave 18 dodges in 31 rolls, and nobody dodged without the keys. On the stock game (2026-10-29):
  - 50 % `ranged`: 18 dodges in 46 rolls, then 28 in 50; 0 % `melee`: 0 in 57;
  - 30 % `notech`, `YPDodge` not active: 20 in 71;
  - 100 % with an active tech: 49 of 49; a rule whose tech was not active: 15 hits, no dodge;
  - an unknown tech: logged, the rule disabled; bad lines (`150`, `12.25`, `-5`, an unknown word, no
    percent, `tech` with no name): logged, the key not applied, the game normal;
  - a skirmish against the AI with these keys on played normally.

  Not tested: multiplayer, siege hits.

#### damageOverTime

**Added:** Wednesday 2026-10-28 16:34 · **Filmed in WoL:** Wednesday 2026-11-04 07:20

![damageOverTime stacks, snare and tick text](media/damageOverTime-stacks.gif)

*On the stock game (not filmed in WoL yet), `AttachMaxStacks`, `AttachSnare` and `AttachTickText`:* three Longbowmen whose arrows attach a 5 Siege poison with up to 3 stacks, a snare to half speed and a green tick text. Two Hussars charge them. The three first arrows put three stacks on one Hussar within a fraction of a second, so each tick deals 15 (`x3` in the overlay) and shows a small green `-15` over its health bar; its speed reads 3.38 instead of 6.75. When the archers are down the stacks expire one by one (10, then 5) and the last tick kills it (2x speed). [Full video (MP4)](media/damageOverTime-stacks.mp4).

![damageOverTime with noticktext and snareOnlyHitUnit](media/damageOverTime-noticktext.gif)

*On the stock game (not filmed in WoL yet), `noticktext`, and the snare in a group:* the same fight with `damageOverTime log noticktext` and `snareOnlyHitUnit log`: three Hussars charge together, the poisoned one takes its 10 and 15-damage ticks with no green number over it, and the overlay shows `snareOnlyHitUnit` treating the poison's slow as a snare (`counts 6.750 instead of 3.375 toward its group's pace`, `lags behind its formation slot`) (2x speed). [Full video (MP4)](media/damageOverTime-noticktext.mp4).

![damageOverTime in WoL](media/damageOverTime-wol.gif)

*In WoL, with `damageOverTime log` (Iroquois; the archers are selected):* three Aenna whose arrows
carry a poison (4 Ranged a second for 8 s, up to 3 stacks, green tick text, written by
`dot_testdata.py --wol`) meet a charging Landsknecht. With three stacks each tick takes 12 (the
green numbers over it, the `(x3)` lines), and the last tick kills it at 36 s; no archer dies.
[Full video (MP4)](media/damageOverTime-wol.mp4).

![damageOverTime in WoL, key off](media/damageOverTime-wol-control.gif)

*In WoL, key off (the same data and scene):* the arrows do only their own damage; the Landsknecht
lives until about 45 s, kills one archer and leaves another at 7 HP.
[Full video (MP4)](media/damageOverTime-wol-control.mp4).

```
damageOverTime [log] [noticktext]
```

- **In WoL today:** there is no damage over time. The exe still contains Age of Mythology's poison, but
  the function that would apply it is empty, so nothing happens.
- **Effect:** an attack whose `<ProtoAction>` lists `<AttachProtoUnit>X</AttachProtoUnit>` poisons
  every unit it damages.
  - For X's `<Lifespan>` seconds, the unit takes the damage of X's `Attaching` action every `ROF`
    seconds. The first tick comes one ROF after the hit.
  - Each tick is a normal hit: the damage type, the damage bonuses, the armor and X's
    `DamageFlags` apply, also after the attacking unit is gone. Kills and XP go to the attacker's
    player. (Bonuses and kill credit follow from the code; see the status below.)
  - Once the attacking unit is gone, the ticks still hurt but no longer cause the reactions to a
    hit, such as retaliation and under-attack alerts.
  - Another hit by the same player renews the duration and keeps the tick timer (with
    `<AttachMaxStacks>`, it adds a stack instead; see below).
  - Poisons from different players, or from different attachment protos, run side by side.
  - It works with every kind of attack tested: hand attacks, instant shots, flying arrows, grenades
    and cannon balls, and area damage (one grenade poisoned all four units it hit).
- **WoL needs** three pieces:
  1. **The attacks.** Add the tag inside the attacker's existing `<ProtoAction>` blocks in
     `protoy.xml`:

     ```xml
     <ProtoAction>
         <Name>StaggerRangedAttack</Name>
         ...
         <AttachProtoUnit>PoisonArrow</AttachProtoUnit>
     </ProtoAction>
     ```

     - The game reads a `<ProtoAction>` only when its `<Name>` is its first child and names an
       action of the unit's tactics file. It skips any other block without a message, and the
       tag with it.
     - A unit has one attack per stance, and each needs its own tag. Use the `<Name>`s of the unit's
       existing blocks. `xpAenna` (`archer.tactics`), for example, has no `RangedAttack`: its ranged
       attacks are `StaggerRangedAttack`, `DefendRangedAttack` and others, and its melee attacks are
       `MeleeHandAttack`, `DefendHandAttack` and `StaggerHandAttack`.
     - The load-time line `<Unit>/<Action> attaches <X>` in `UHC.log` lists every tag the game
       read.

  2. **The attachment proto X**, a new `<Unit>` in `protoy.xml`. It holds data only: it is never
     created in the world.

     ```xml
     <Unit id ='6055515' name ='PoisonArrow'>
         <DBID>6055515</DBID>
         <Lifespan>6.0</Lifespan>
         <Tactics>uhcattachment.tactics</Tactics>
         <ProtoAction>
             <Name>Attaching</Name>
             <Damage>4.0</Damage>
             <DamageType>Ranged</DamageType>
             <ROF>1.0</ROF>
             <DamageFlags>GAIAEnemy</DamageFlags>
             <DamageBonus type ='AbstractInfantry'>1.5</DamageBonus>
         </ProtoAction>
     </Unit>
     ```

     - `id` and `DBID`: WoL's IDs are not in order. Any value that no other unit uses works: the
       largest in WoL's `protoy.xml` is 6055514 for both, and the test used the next one.
     - `Lifespan` is the duration in seconds and `ROF` the seconds between ticks, so a poison
       deals Lifespan ÷ ROF ticks, rounded down (6 here).
     - `DamageFlags` says whose units the ticks hurt: `GAIA`, `Self`, `Ally` and `Enemy`,
       combined, as in `GAIAEnemy`. Without the tag they hurt everyone. Treasure guardians and
       animals are Gaia. The attack's own `DamageFlags` decide what gets poisoned. A poisoned unit
       that X's flags exclude takes `0.00` damage per tick, for example after a conversion.
     - Techs can change X for the player who researches them. Target X by name: the attacker's
       own upgrades do not reach it. Two effects apply:
       - its `Lifespan` (`subtype ='Lifespan'`), from the next hit;
       - the damage of its `Attaching` action, from the next tick:
         `<Effect type ='Data' action ='Attaching' amount ='1.25' subtype ='Damage'
         relativity ='BasePercent'><Target type ='ProtoUnit'>PoisonArrow</Target></Effect>`.

       This DLL has no tech effect for ROF, so the tick interval is always the `<ROF>` of the data.
  3. **A tactics file for X.** The game ignores a `<ProtoAction>` whose name is not an action in
     the proto's tactics file, so X needs one with an action named `Attaching`. Save
     [examples/data/tactics/uhcattachment.tactics](../examples/data/tactics/uhcattachment.tactics)
     as `data\tactics\uhcattachment.tactics`; one file serves every attachment proto:

     ```xml
     <tactics>
       <action>
         <name>Attaching</name>
         <type>Attack</type>
         <rate type="Unit">1.0</rate>
       </action>
       <tactic>Normal<action priority="100">Attaching</action></tactic>
     </tactics>
     ```

     Keep `<tactic>Normal` and its `<action>` on one line, as here. A line break after the tactic
     name can break every AI player in the game ([tactics files](#tactics-files)).
- **Optional tags**, in the same attacker `<ProtoAction>` as `<AttachProtoUnit>` (each one changes
  only the poisons of that attack; without them the poison is the one above):

  ```xml
  <ProtoAction>
      <Name>StaggerRangedAttack</Name>
      ...
      <AttachProtoUnit>PoisonArrow</AttachProtoUnit>
      <AttachMaxStacks>3</AttachMaxStacks>
      <AttachSnare>0.5</AttachSnare>
      <AttachTickText>40FF40</AttachTickText>
  </ProtoAction>
  ```

  - **`<AttachMaxStacks>N</AttachMaxStacks>`** (a whole number from 1 to 100): each hit adds a
    stack, up to N, and a tick deals X's damage times the stacks alive at that moment (the
    damage type, bonuses and armor apply to the whole). **Each stack expires on its own,**
    Lifespan seconds after the hit that made it; a hit at N stacks renews the oldest one. So
    steady hits keep N stacks, and when the hits stop the ticks fall back one stack at a time
    (15, 10, 5 in the tests). N = 1 is the poison without the tag. When attacks with different N
    hit the same unit with the same X, the last hit's N counts.
  - **`<AttachSnare>F</AttachSnare>`** (a number from 0 to 10): while poisoned, a unit that can
    move goes at F times its speed. It is the snare of `<TargetSpeedBoost>` (a speed modifier that
    multiplies), with F instead of 0.65; it starts with the poison, is renewed at every tick, and ends
    a quarter of a second after the last tick. Only the first snare counts when several apply, and [`snareOnlyHitUnit`](#snareonlyhitunit) treats
    it as a snare. Buildings are not slowed.
  - **`<AttachTickText>RRGGBB</AttachTickText>`** (a colour in hex; empty for green 40FF40): each
    tick shows the damage it dealt, for example `-15`, over the unit in that colour. It is the floating
    text of the dodge, without its rise, and only the player whose screen shows the unit sees it.
    `damageOverTime noticktext` in a player's `wol.cfg` turns all tick texts off for that player; it
    changes nothing else.

  A value the DLL cannot read is logged and that tag is ignored.
- **Not done:**
  - no model or effect shows the poison, since X never exists in the world (`AttachTickText`
    shows the ticks as text);
  - poisons are not saved in saved games, so a loaded game starts without them (tested);
  - the exe's `Poison` flag is not used.
- **`log`** writes every poison, renewal, tick and end to `UHC.log`, and once per attack the
  attacks that deal damage without `<AttachProtoUnit>` (`damage by proto N (Name), action A …:
  no <AttachProtoUnit> there`, at most 200 a session), which tells you the name the game uses for
  an attack. Use it while tuning the numbers; in a long game the log grows quickly.
- **Log:**
  - at startup, `damageOverTime: <AttachProtoUnit> in protoy.xml ProtoActions attaches damage
    over time, with <AttachMaxStacks>, <AttachSnare> and <AttachTickText> (multiplayer
    unverified)` (with `noticktext`, `…; tick texts off on this machine …`);
  - while the data loads, `hook reached: action tag (0x5FA11E)` (the tag hook it shares with
    `spreadAnyAccuracy`) and, for each
    tag, `damageOverTime: <Proto>/<Action> attaches <X>`, `…: up to <N> stacks`, `…: poisoned
    units move at <F> times their speed`, `…: ticks shown in colour <RRGGBB>`, or why a value was
    ignored (`<AttachMaxStacks>…</AttachMaxStacks> is not a whole number from 1 to 100; ignored`,
    and the same for the other two); an attack with the optional tags but no `<AttachProtoUnit>`
    logs `… but no <AttachProtoUnit>; ignored` on its first hit;
  - on the first hit with each tag, `damageOverTime: <X> -> proto <ID>: Lifespan <L> s, Attaching
    every <N> ms`, or the reason it cannot work:
    - `<X> is not a proto unit`: the name in `<AttachProtoUnit>` is not the name of a unit;
    - `<X> has no ProtoAction named Attaching`: the tactics file is missing, or has no action
      named `Attaching`;
  - the first poison and the first tick of a run: `damageOverTime: poison: unit <N> (<proto>) by
    player <P>, proto <X>, stack <S>/<N> …` and `damageOverTime: tick: unit <N> (<proto>) took <D>
    damage (x<stacks>), <H> hitpoints left …`; a tick line ends with `, attacker gone` once the
    attacking unit no longer exists, `, army unit` for a unit of an AI army, and `, speed <V>`
    (the unit's current speed) with `<AttachSnare>`;
  - once each: `… has Lifespan 0.00; unit <N> not poisoned` (set a Lifespan), and
    `unit <N> is no longer alive and damageable; not poisoned` (the hit killed the unit, which is
    normal);
  - with `log`, also `poison renewed` and `poison on unit <N> ended …: expired`, `unit dead or
    not damageable`, or `unit gone`;
  - when you leave a game with poisons still running and start or load another one,
    `damageOverTime: another game started; <N> running poison(s) dropped`, or
    `damageOverTime: the data was reloaded; <N> running poison(s) dropped`. That is normal;
  - `hook reached: damageOverTime TakeDamage (0x49B3D9)` and `hook reached: world update
    (0x481A57)` (the world update wrapper, shared with `overhealDecay`).
- **Check:** hit a unit once and pull back. Its hitpoints keep dropping by one tick every ROF
  seconds. In the tests, poisoned guardians and animals sometimes jumped back to full hitpoints,
  most likely when they went back to their spot. The exe does that (not traced), and it can hide the
  poison; the `log` lines show the ticks anyway.
- **Simulation:** yes. Every player needs the same data and the same key; `noticktext` only
  changes what that player sees and may differ.
- **Status:** confirmed in single player.
  - **In WoL (2026-11-04):** three Aenna with a poison of 4 Ranged a second for 8 s, up to 3 stacks and
    a green tick text (`tools/dot_testdata.py --wol`): ticks of 12 at three stacks killed a Landsknecht
    at 36 s; without the key it lived to about 45 s.
  - **On the stock game (2026-10-28 and 29),** with `tools/dot_testdata.py`:
    - hand attacks, instant shots, flying arrows, grenades (one poisoned all four units it hit) and
      cannon balls; Gaia units too;
    - `DamageBonus` on X (18 a tick on a Hussar, 4.80 on infantry), a tech on X (from 18 to 36), and
      `DamageFlags`: a poisoned unit converted to the attacker's side took 0.00 per tick;
    - a removed attacker: the ticks went on and killed the unit, and the kill gave the attacker's
      player its XP bounty. A unit that is only killed keeps its ID while its body lies there, so the
      attacker counts as gone once the body disappears;
    - `AttachMaxStacks 3`, `AttachSnare 0.5`, `AttachTickText` and `noticktext`, as in the videos, and
      invalid values (`dot_testdata.py --bad`), each logged and ignored;
    - AI: in 12 minutes, 49 poisons and 242 ticks between two AIs; in a 25-minute game with a 120 s
      poison, 902 ticks after the attacker was gone; no XS error and no crash;
    - saved games: a game saved with a poison running loaded without it (`the data was reloaded; 1
      running poison(s) dropped`).
  - **Not tested:** poison in an AI game of WoL, multiplayer.
  - **Not reproduced:** a tick on a unit of an engine army after the attacking unit is gone (the p11 = 0
    path of [how-it-works](how-it-works.md#damageovertime)). No unit carried the army flag in any test,
    so that guard stays a reading of the code.

#### spreadAnyAccuracy

**Added:** Friday 2026-10-30 10:12 · **Filmed in WoL:** Wednesday 2026-11-04 07:20

![spreadAnyAccuracy in WoL](media/spreadAnyAccuracy-wol.gif)

*In WoL, with `spreadAnyAccuracy Escopetero log` (the Escopeteros are selected):* four Escopeteros
(WoL's own data: accuracy 0.41, `maxspread` 3 and `spreadfactor` 1.5 in their tactics, `DamageArea`
1) shoot eight charging Scythemen. Every shot, hits included, is logged as made a ground shot at a
point up to 3 m away, and it hurts whoever stands within 1 m of it.
[Full video (MP4)](media/spreadAnyAccuracy-wol.mp4).

![spreadAnyAccuracy in WoL, key off](media/spreadAnyAccuracy-wol-control.gif)

*In WoL, key off (the same scene):* the 59 % of shots that miss do no damage, the hits damage their
target. In this melee-range fight the total damage is about the same either way: seven
Scythemen survive with 827 HP without the key, and with it 800 and 562 HP in two runs (one with all
eight alive). [Full video (MP4)](media/spreadAnyAccuracy-wol-control.mp4).

```
spreadAnyAccuracy [<UnitType>] [log]     default AbstractSpreadAnyAccuracy
```

- **In WoL today:** each ranged shot that is not `InstantBallistics` rolls its `Accuracy` when it is
  fired (the roll also counts the distance, so even accuracy 1.0 misses about 8 % of the shots at 16 m).
  A hit flies to its target and damages it. A miss lands at a random point up to `r` away on each axis,
  with `r = min(0.25 × distance, 5)` for every unit, and **deals no damage at all**, not even with
  `<DamageArea>`. The `<maxspread>` and `<spreadfactor>` lines of WoL's tactics files (317 files, 647
  actions) are ignored: the exe has no code for them.
- **Effect:**
  - Every action reads **`<MaxSpread>`** (a number from 0 to 100, in metres) and
    **`<SpreadFactor>`** (a number from 0 to 10), in a tactics file's `<action>` or in a `protoy.xml`
    `<ProtoAction>` (a `<ProtoAction>` overrides the tactics file). Without a tag the exe's value stays
    (5 and 0.25).
  - **Every miss** of every unit uses its action's values: `r = min(SpreadFactor × distance,
    MaxSpread)`. The random draws are the exe's; only `r` changes. So the key changes every miss of
    WoL's 647 actions at once, with their current values: check the balance.
  - **Units of `<UnitType>`** scatter every shot that rolls, whatever the accuracy (1.0 and
    `PerfectAccuracy` included): each shot lands at the offset point as a **ground shot** (what
    grenades and mortars fire) and deals its attack where it lands. With `<DamageArea>` the units
    within that radius of the point take the damage, the target included when it is close enough;
    without `<DamageArea>` the shot hits nothing.
  - Unmarked units keep their hits; only their misses change.
- **WoL needs:**

  ```xml
  <!-- data\tactics\<file>.tactics, in the <action> (keep <name> first) -->
  <maxspread>3</maxspread>
  <spreadfactor>1.5</spreadfactor>
  ```

  ```xml
  <!-- or protoy.xml, per proto -->
  <Unit id ='...' name ='Escopetero'>
      ...
      <UnitType>AbstractSpreadAnyAccuracy</UnitType>
      <ProtoAction>
          <Name>VolleyRangedAttack</Name>
          ...
          <DamageArea>2.000000</DamageArea>
          <DamageFlags>GAIAEnemy</DamageFlags>
          <MaxSpread>3</MaxSpread>
          <SpreadFactor>1.5</SpreadFactor>
      </ProtoAction>
  ```

  Mark only units whose attack has `<DamageArea>`, such as shotguns: a marked attack without area
  does no damage. The marker is registered by the DLL, like `healNonIdle`'s; an existing type or
  proto name works too (`spreadAnyAccuracy Escopetero`).
- **Not covered** (these shots never reach the code, and stay as they are):
  - actions with `<InstantBallistics>` (sure hits: most muskets) or `<TargetGround>` (grenades,
    mortars). Of WoL's 647 actions with spread tags, 304 and 122; the current shotgun files
    (`wolinfantryrangedescopetero`, `wolinfantryrangedbacamarteer`, the trench fighter's volley)
    are covered;
  - shots at the ground with no target unit, and every shot when the startup cfg does not define
    `ballisticPrecalcHits` (`Startup\gamey.cfg` defines it; keep that line);
  - `<NumberProjectiles>`: a shot is still one projectile.
- **`log`:** one line per value that differs from the exe's 5 / 0.25 (the first 200 per data load),
  and the first 5 offset shots of each attack (at most 100): who shot, a miss or a marked shot, `r`
  and the values used. Invalid values are logged with or without `log`.
- **Log:**
  - at startup, `spreadAnyAccuracy: <MaxSpread> and <SpreadFactor> are read per action (stock 5.0
    and 0.25) and every miss uses them; units of unittype X scatter every precalculated shot
    (multiplayer unverified)` (with `log`: `…; values and shots logged …`);
  - while the data loads, `unit types: X -> <ID> …`, `hook reached: action tag (0x5FA11E)` and,
    for each invalid value, `spreadAnyAccuracy: Escopetero/VolleyRangedAttack (protoy):
    <MaxSpread>abc</MaxSpread> is not a number from 0 to 100; ignored` (or `… before the action's
    <name>; ignored (put <name> first)`); with `log`, `spreadAnyAccuracy:
    Crossbowman/VolleyRangedAttack (tactics): MaxSpread 20.00`;
  - in a game, `hook reached: spreadAnyAccuracy hit roll (0x499890)`, `… miss offset (0x4CEF7B)`
    and `… miss radius (0x4CF00B)`, then at the first miss `spreadAnyAccuracy: 622 action(s) of this
    data carry <MaxSpread> or <SpreadFactor>, 23 of them with values other than the stock 5.0 and
    0.25` (once per data load). With `log`: `spreadAnyAccuracy: shot by unit 20
    (xpAenna/VolleyRangedAttack): marked unit, a hit made a ground shot at the offset point, r =
    3.00 m (SpreadFactor 1.50, MaxSpread 3.00)` or `shot by unit 1 (Crossbowman/VolleyRangedAttack):
    a miss, r = 20.00 m (SpreadFactor 2.00, MaxSpread 20.00)`.
- **Simulation:** yes (where shots land and what they damage; it also adds a unit type, which
  changes the unit type count).
- **Status:** confirmed in single player.
  - **In WoL (2026-11-04):** WoL's own Escopeteros, as in the videos. The total damage in that fight at
    melee range is about the same with and without the key.
  - **On the stock game (2026-10-30):** values read from a tactics file (20 / 2) and from `<ProtoAction>`
    lines, which overrode the file (3 / 1.5); invalid values (`abc`, `-1`, `1000`, `2x`, `-3`) logged and
    ignored; unmarked misses with `r = 20 m`, and with the default `0.25 × d`; marked archers with
    accuracy 1 or `PerfectAccuracy`, every shot a ground shot; marked archers with `DamageArea` 2.5
    killed by area hits, and without it hit nothing; marked Grenadiers (`TargetGround`) never reached
    the hooks; a skirmish against two AIs played normally.
  - **Not tested:** multiplayer, saved games. The area damage of the ground shots was seen on HP, the
    landing points only on video.

#### broadsideMuzzleLimit

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Tuesday 2026-11-03 14:51

![broadsideMuzzleLimit in WoL](media/broadsideMuzzleLimit-wol.gif)

*In WoL, with `broadsideMuzzleLimit 11 ypTekkousen log` (Japanese, on a water map):* a Tekkousen
created in the game fights two Fluyts. Its broadside gets all 10 muzzles per side of its model
(`has 10 right and 10 left muzzle slots (limit 11 per side)`) and sinks both. A scan of 17 WoL
warships with a limit of 30 found no other model above 6 per side (Battleship, Galleon, Frigate,
Destroyer 6; Geobukseon, Joukisen, Windjammer 5; Corvette 4; Dreadnought 3).
[Full video (MP4)](media/broadsideMuzzleLimit-wol.mp4).

![broadsideMuzzleLimit in WoL, key off](media/broadsideMuzzleLimit-wol-control.gif)

*In WoL, key off (the same scene):* the exe keeps 6 slots per side, so the Tekkousen fires fewer shots
per volley. [Full video (MP4)](media/broadsideMuzzleLimit-wol-control.mp4).

```
broadsideMuzzleLimit <N> [<UnitType>] [log]     N from 1 to 255; without a UnitType, every ship
```

- **In WoL today:** most ships' attacks are `BroadsideAttack` actions in their tactics file: the normal
  ranged attack of the warships (the Tekkousen uses `frigate.tactics`), the action of the
  `PowerBroadside` ability, and the ironclad's long-range shot. When such an action is set up, each
  muzzle of the ship's model gets a firing slot; the muzzles are the model's MuzzleR (right) and MuzzleL
  (left) attach points. The exe keeps at most **6 slots per side**, and only **1** when the attack has
  `<SingleUsePlayer>`. A volley fires one projectile per slot on the side that faces the target, so a
  ship fires at most 6 shots per side whatever its model has. The Tekkousen's model has 10 muzzles per
  side, and 4 of them never fire. `<NumberProjectiles>` is not read at all.
- **Effect:** for the matched ships the limit becomes N.
  - The model still decides how many muzzles there are: a model with 5 per side fires 5 whatever N
    is.
  - `SingleUsePlayer` attacks keep 1 per side, and ships that do not match keep 6.
  - N below 6 lowers the limit.
- **Choosing the ships:** `<UnitType>` can be a proto name (`broadsideMuzzleLimit 11 ypTekkousen`), an
  existing unit type (`AbstractWarShip`), or a new marker, which the DLL registers like `healNonIdle`'s.
  With no `<UnitType>`, every ship gets the limit. The exe only gives muzzle slots to units of the built-in type `Ship`.
- **Which attacks:** every `BroadsideAttack` action of a matched ship, its normal attack as well as
  the ability's. In continuous fire, more slots mean a longer rotation over more muzzles: the rate
  stays about one shot per `ROF`. A single-volley ability (`PowerBroadside`) fires all its slots
  once, so it gains the most. Attacks of type `Attack` never use muzzle slots.
- **WoL needs:** a ship model with more than 6 muzzle attach points per side. Of 17 WoL warships scanned,
  only the Tekkousen has them (see the video). Two rules of the exe stay:
  - the right side drives both schedules: the left side fires at most as many shots as the right
    side has slots, and a model with no MuzzleR point never fires its broadside;
  - each slot waits a random 0.25 to 1.75 × `ROF` after the previous one (sync RNG).
- **When it takes effect:** an action gets its slots when it is set up, which is when it is
  created. A saved game keeps the slot count its actions were saved with.
- **`log`:** one line per action set-up of a matched ship, with the slots it got, at most 500
  lines per run.
- **Log:** at startup `broadsideMuzzleLimit: ships of unittype X use up to N muzzles per side in a
  broadside (stock 6; SingleUsePlayer attacks keep 1) (multiplayer unverified)` (without a type,
  `broadsideMuzzleLimit: every ship uses up to N …`; with `log`, `…keep 1), every set-up logged
  (multiplayer unverified)`); when the data loads, `unit types: X -> <ID> …`; in a game,
  `hook reached: broadsideMuzzleLimit (0x5033D5)` the first time any ship's broadside action is
  set up, and with `log` `hook reached: broadsideMuzzleLimit log (0x5034E2)` and
  `broadsideMuzzleLimit: unit N (ypTekkousen) has 10 right and 10 left muzzle slots (limit 11 per
  side)` (`limit 1` there means a `SingleUsePlayer` attack). Bad arguments: `broadsideMuzzleLimit:
  expected "broadsideMuzzleLimit <N> [UnitType] [log]" with N from 1 to 255, got "X"; feature not
  applied`, and `broadsideMuzzleLimit: N lines, expected one; feature not applied` for a second
  line.
- **Simulation:** yes: more projectiles, and one more sync-RNG draw per extra slot and volley. A
  new marker also adds a unit type.
- **Status:** confirmed in single player, in WoL (2026-11-03) with `broadsideMuzzleLimit 11 ypTekkousen
  log`: the Tekkousen got `10 right and 10 left muzzle slots` and fired from all of them. The
  `PowerBroadside` ability and `SingleUsePlayer` attacks were not tested. WoL's ironclad long-range
  attack has `SingleUsePlayer`, so it keeps 1. A projectile count set in the data, independent of the
  model (`numberprojectiles`), is a different and larger change; it is not provided.

#### snareOnlyHitUnit

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Wednesday 2026-11-04 08:11

![snareOnlyHitUnit in WoL](media/snareOnlyHitUnit-wol.gif)

*In WoL, with `snareOnlyHitUnit log` (British, the camera follows the group):* six Redcoats march
east in one group while an Uhlan chases and lances them (`handCavalry.tactics`, a
`TargetSpeedBoost` attack). Each snared Redcoat counts at its full speed toward the group's pace
(`counts 4.000 instead of 2.600 toward its group's pace`): it falls back alone while the others go
on, and the group reaches the end of the map (151 m) at 50 s of game time.
[Full video (MP4)](media/snareOnlyHitUnit-wol.mp4).

![snareOnlyHitUnit in WoL, key off](media/snareOnlyHitUnit-wol-control.gif)

*In WoL, key off (the same scene):* every snare slows the whole group to the snared unit's pace, so
it stays together and arrives at about 54 s; at 41-42 s its mean position is 117 m against 123 m
with the key (sampled once a second).
[Full video (MP4)](media/snareOnlyHitUnit-wol-control.mp4).

```
snareOnlyHitUnit [log]
```

- **In WoL today:** an attack whose tactics action has `<TargetSpeedBoost>1</TargetSpeedBoost>` snares its
  target: the target's speed is multiplied by 0.65 for 3 seconds. WoL gives it to most melee attacks and
  many more. A unit that moves in a group (several units ordered together) does not use its own speed: the group
  moves at the speed of its slowest member. One snared unit therefore slows its whole group to
  0.65× for 3 s.
- **Effect:** the group's pace ignores the snare: a snared member counts with the speed it would
  have without it (other speed modifiers, such as auras, still count). While the snare lasts, the
  snared member also no longer makes the group wait when it falls behind its place in the
  formation. Only the hit unit slows down.
- **After the snare:** the exe's rule for stragglers applies again. If the unit is then more than
  2 m behind its place, the group moves at 0.83× its speed until the unit is back, as for a unit
  that got stuck. A unit snared again and again keeps falling behind while the group goes on.
- **WoL needs:** nothing. Every `<TargetSpeedBoost>` attack is covered, and only those: the attacker's own
  `<SpeedBoost>`, speed auras and techs still act on the group.
- **`log`:** one line per snare and unit when the snare is left out of the group's pace, and one
  when the snared unit falls behind without making the group wait.
- **Log:** at startup `snareOnlyHitUnit: a snared unit (TargetSpeedBoost) no longer slows its
  group; the group neither paces at nor waits for it while the snare lasts (multiplayer
  unverified)` (with `log`: `…lasts, every snared member logged (multiplayer unverified)`); in a
  game, `hook reached: snareOnlyHitUnit (0x4FD3FD)` (the first time any group recomputes its
  speed), and `(0x4FA17D)`, `(0x6AA514)` or `(0x6AA56A)` the first time a member falls more than
  2 m behind its place. With `log`: `snareOnlyHitUnit: unit N (Redcoat) is snared; it counts
  4.000 instead of 2.600 toward its group's pace` and `snareOnlyHitUnit: unit N (Redcoat) is
  snared and lags behind its formation slot; its group does not wait for it (0x4FA17D)`.
- **Limits:** a unit that is not in a group already slowed alone. A snare is exclusive: while a unit is
  snared, its later speed modifiers are ignored and several snares do not stack; the key keeps that.
  The value and duration (0.65, 3 s) do not change.
- **Simulation:** yes.
- **Status:** confirmed in single player. In WoL (2026-11-04), six Redcoats harassed by an Uhlan reached the
  end of the map at 50 s with the key and about 54 s without, positions sampled once a second.

#### rofFix, stunMovingTargetFix, noDamageOnUnbuiltFoundations and fallenHeroTacticsFix

**Added:** Tuesday 2026-11-03 11:26

```
rofFix
stunMovingTargetFix
noDamageOnUnbuiltFoundations
fallenHeroTacticsFix
```

WoL's DLL does these four always, so `wol.cfg` has no lines for them. This DLL needs the lines, and with
them WoL plays as it does with its own DLL.

- **rofFix:** ordering a unit to use an ability or command no longer clears its attack timer, so
  orders cannot be used to fire sooner.
- **stunMovingTargetFix:** a stun action is no longer cancelled when its target check fails (a
  target that moves away).
- **noDamageOnUnbuiltFoundations:** a building whose construction has not started yet (a
  foundation just placed) takes no damage, unless the attacker's player is in the state the game
  sets when an effect changes that player's diplomacy with every other player.
- **fallenHeroTacticsFix:** a unit keeps the tactic its player chose when it is knocked out,
  stunned or building; the exe resets it to the first tactic.
- **Log:** one line per key at startup; `noDamageOnUnbuiltFoundations: <Proto> (an unbuilt
  foundation) took no damage from player N` the first time it applies.
- **Simulation:** change combat: every player needs the same lines.
- **Status:** applied and running in WoL (2026-11-03): the four load, and the damage test runs on every
  hit with no change to normal damage (a finished House took 20 per shot with the key). Their effects
  were not seen in a test yet: the trigger that should place a foundation placed none.

#### removeConversionRestriction

**Added:** Wednesday 2026-10-28 10:56

```
removeConversionRestriction
```

- **Effect:** the `ConvertGuardian` action, which converts treasure guardians, may target any unit. The
  exe checks a unit flag that only treasure guardians have. `wol.cfg` has this line.
- **Who has the action:** explorers, war chiefs and some cavalry list it in their tactics (59 uses in
  WoL's tactics files), and a tech enables it (for example the `HCXPMorningStar` card).
- **Check:** this key writes no `hook reached` line, because it only removes one branch. Check it
  in game: a unit with `ConvertGuardian` converts a unit that is not a treasure guardian.
- **Simulation:** yes.
- **Status:** not confirmed: one test with the Sioux war chief, on the stock game, was inconclusive.

### Gathering and farms

Resources, gatherers, and what pays for them.

| Key | What it does | WoL's DLL | WoL also needs | In-game status |
|---|---|---|---|---|
| [`gatherFix`](#gatherfix) | Gatherers collect on a fixed interval, so the gather rate is the data's and not the animation's. | always on | Nothing. | confirmed |
| [`showGatherRate`](#showgatherrate) | Shows a gathering unit's rate per second in the stat panel, and through the data ref `{currentUnitGatherRateString}`. | **new** | Nothing; for the data ref, a `formatText` gadget in your UI. | confirmed (single player, UI; the data ref not tested) |
| [`enableFarmAnim`](#enablefarmanim-enablerectfarmanim-and-farmingradius), [`enableRectFarmAnim`](#enablefarmanim-enablerectfarmanim-and-farmingradius), [`farmingRadius`](#enablefarmanim-enablerectfarmanim-and-farmingradius) | Mill and Rice Paddy gathering on more buildings, and a gather area per building. | **in `wol.cfg`** | Nothing. | confirmed |
| [`nowalkfarm`](#nowalkfarm) | Gatherers on a farm keep the spot they take. | **in `wol.cfg`** | Nothing. | confirmed |
| [`betterfreedynamicunit`](#betterfreedynamicunit) | Dynamic free units grow smoothly with game time, not in 2-minute steps. | **in `wol.cfg`** | Nothing. | confirmed |
| [`marketUnits`](#marketunits) | Owning a unit of a listed proto counts as owning a Market. | **in `wol.cfg`** | Nothing. | confirmed |

#### gatherFix

**Added:** Tuesday 2026-11-03 11:15

![gatherFix in game](media/gatherFix.gif)

*In game:* settlers on a Mill and on trees; with the key they gather at the rate the data gives.
[Full video (MP4)](media/gatherFix.mp4).

```
gatherFix
```

- **Effect:** gatherers collect on a fixed time interval, so the gather rate is the one in the data.
  Stock collects once per loop of the gather animation, an amount for the animation's length, which
  makes the real rate depend on the animation.
- **Log:** `gatherFix: gatherers collect on a fixed interval, ...`; the first collection, `interval
  I s (protoAction+78h V), collectStuff | collectStuff_2`.
- **Simulation:** changes gathering: every player needs the same line.
- **Performance:** a collection every 0.5 s per gatherer. With 40 gatherers: update 0.143 / 0.142
  ms with / without, no frame over 50 ms, about 10% fewer frames per second (711–733 vs 815).
- **Status:** confirmed (2026-11-03, single player): in 120 s, 3 settlers on trees (rate 0.5)
  gathered 179.5 wood with the key (0.50 per second each) and 281.3 without it (0.78), and 4 on a
  Mill 235.5 food against 367.3. Video `gatherFix.mp4`.

#### showGatherRate

**Added:** Thursday 2026-10-29 10:35 · **Filmed in WoL:** Wednesday 2026-11-04 09:20

![showGatherRate in WoL](media/showGatherRate-wol.gif)

*In WoL, with `showGatherRate log` (Ethiopians, in the minimized interface, no data change):* a
villager gathers berries, and the unit panel shows `Food (icon): 0.67/s` in WoL's own rate gadgets.
[Full video (MP4)](media/showGatherRate-wol.mp4).

![showGatherRate in WoL, key off](media/showGatherRate-wol-control.gif)

*In WoL, key off (the same scene):* the panel shows no rate.
[Full video (MP4)](media/showGatherRate-wol-control.mp4).

```
showGatherRate [<UnitType>] [log]      no UnitType: every unit
```

- **How stock behaves:** the stat panel (the rows next to the selected unit's portrait,
  `uiunitstatpanel3`, up to 9 rows) shows a rate per second only for **AutoGather** units, such as
  a Bank: right after the HP row, a row `Food (icon): 0.67/s`, or `8/s` for a whole number. A
  villager has no such row: its rate exists only inside the gather code, which runs once per
  gather animation loop, multiplies the rate by the loop's time and adds the result to the
  stockpile. The data refs `currentUnitGatherRate`, `currentUnitGatherRateFloat` and
  `currentUnitGatherRateString` exist in the exe but always fail (their provider is an empty
  stub).
- **Effect:** when **one** unit is selected and it is gathering (berries, a hunt, a tree, a mine,
  a farm, a crate, a sheep, …), the stat panel gets one more row after the HP row (and after a
  stock AutoGather row, if the unit has one), in the stock style: `Food (icon): 0.67/s`. The rate
  is the one the game used for the unit's last gather loop: the proto's gather rate for that
  target type with techs and work-rate modifiers, the Gathering dance and the player's gather
  multiplier. It is the amount per second the stockpile receives while the unit gathers. The row
  appears after the unit's first gather loop (about 1 to 2 s after it starts) and goes away as
  soon as the unit does something else, or at most 2.5 s (two loops for slow animations) after
  its last loop. The label is the resource's name from the string table, as in the stock row
  (`Alim.` in the Spanish game).
- **`<UnitType>`:** only units whose proto is of that unit type (or that proto) get the row. A
  new name is registered as an abstract unit type, like `healNonIdle`'s marker. A name that no
  unit has turns the row off and keeps the data ref.
- **Hiding the row for a proto:** `<Flag>DoNotShowAutoGatherRate</Flag>`, the stock flag that
  hides the stock AutoGather row, hides this row too.
- **The data ref, for your own UI:** `{currentUnitGatherRateString}` in a `formatText` gadget
  returns `Food 0.67/s` (`Food 8/s` for a whole number) for the data refs' current unit (the one
  the stock refs such as `{currentUnitLOS}` show), and an empty string when that unit is not
  gathering. Give the gadget a `datarefreshrate`, as WoL does for `{currentUnitLOS}`:

  ```xml
  <gadget name="myGatherRate" type="formatText" datarefreshrate=".5" ...>Gather: {currentUnitGatherRateString}</gadget>
  ```

  The data ref works for any unit, with or without `<UnitType>`, and ignores the stat panel's
  rules (selection size, `DoNotShowAutoGatherRate`). `{currentUnitGatherRate}` (whole number) and
  `{currentUnitGatherRateFloat}` are **not** changed: WoL's `uimainnew.xml` already uses
  `{currentUnitGatherRate(gold)}` in a tooltip, and they keep failing as in stock.
- **Minimized interface:** with the game option `optionminimizedui` on, the exe does not fill the
  stat panel at all. The rate then goes in the unit panel's own rate gadgets,
  `unitselectionpanel-unitResourceRateLabel` and `...RateValue` of `uiunitselectionmin.xml`, the
  ones stock uses for AutoGather units, with the same text: `Food (icon): 0.67/s`. A file without
  those gadgets shows no rate there; `{currentUnitGatherRateString}` still works in any gadget. As in
  the normal interface, the rate shows only with one unit selected.
- **Your data:** nothing. A mod whose stat panel has fewer rows (WoL's `uiunitstatpanel3.xml` has
  5) loses its last row while the gather row is shown: the row goes right after HP and the rows
  after it move down. Such a mod may prefer the data ref and a `<UnitType>` that no unit has.
- **Limits:**
  - one selected unit only (the stock rule for the AutoGather row); nothing for a group;
  - the stock AutoGather row's other conditions apply too: a building must be finished, and the
    selection must pass a stock test whose meaning is not known (a selection byte; possibly units
    the player does not own);
  - gathering into the unit's own inventory (`<addresourcestoinventory>`, for example herd animals
    fattening at a pen) runs other code and gets no row;
  - a target of type `AbstractShrine` and a defeated player give nothing, so they show no row;
  - the rate is that of the last gather loop: a tech researched during a loop shows from the next
    loop on;
  - the row follows the stat panel's own refresh.
- **`log`:** one line the first time a unit's rate for a resource is shown in the stat panel, and
  one the first time the data ref returns it. A new game starts the list again.
- **Log:** at startup `showGatherRate: the stat panel shows the gather rate per second of a
  selected gathering unit, and {currentUnitGatherRateString} returns it (UI only)` (with a unit
  type: `…of a selected unit of unittype X, and {currentUnitGatherRateString} returns it for any
  unit (UI only)`; with `log`, `…, each unit's first rate per resource logged (UI only)`); with a
  unit type, when the data loads, `unit types: X -> <ID> …`. In a game:
  `hook reached: showGatherRate record (0x4ED044)` (the first gather loop of any unit),
  `hook reached: showGatherRate panel (0x4D7834)` (the first stat panel fill),
  `hook reached: showGatherRate unit panel (0x699456)` (the first unit panel fill of the minimized
  interface),
  `hook reached: showGatherRate row value (0x69AFE0)` (the first rate row, this one or a stock
  AutoGather row), and `hook reached: showGatherRate data ref (0x5D2D3C)` (the first time a gadget
  reads the data ref). With `log`: `showGatherRate: unit N (Settler) of player 1 gathers Alim.
  (resource 2) at 0.670/s from unit T (BerryBush), shown in the stat panel` (or `…, shown in the
  data ref currentUnitGatherRateString`).
- **Simulation:** no. The hook in the gather code copies the rate into the DLL's memory and writes
  nothing in the game; everything else is the interface. Players may set it differently (not
  tested in multiplayer).
- **Status:** confirmed in single player (2026-10-29), in the interface: a Settler gathering a
  `BerryBush` got a new row `Alim. (icon): 0.67/s` right under its HP row, and the log showed
  `showGatherRate: unit 0 (Settler) of player 1 gathers Alim. (resource 2) at 0.670/s from unit 1
  (BerryBush), shown in the stat panel`. In WoL (2026-11-04), with the minimized interface: the row
  in the unit panel, gone when the villager stops and with two villagers selected, and the data ref.
  Other targets, whole-number rates, a `<UnitType>` and `DoNotShowAutoGatherRate` were not tested.
- **New in this DLL:** not in UHC 1.10. WoL request #28 ([wol-requests.md](wol-requests.md)).

#### enableFarmAnim, enableRectFarmAnim and farmingRadius

**Added:** Tuesday 2026-11-03 06:49

![enableFarmAnim in game](media/enableFarmAnim.gif)

*In game:* Iroquois gatherers on a listed plantation (Mill-like, front) and a listed farm (Rice
Paddy-like, right) spread over the fields and use the farming animations; the log lines on top
are the keys'. [Full video (MP4)](media/enableFarmAnim.mp4). Without the keys
(left of the still below) the same gatherers stand bunched at one side of each building:
![enableFarmAnim off and on](media/enableFarmAnim-control.png)

![farmingRadius in game](media/farmingRadius-12.gif)

*In game:* the same plantation with `farmingRadius 3 12.0 12.0`: its four gatherers (HP lines on
top) range up to 11.9 m from its centre, against about 5 m with the stock 4.5.
[Full video (MP4)](media/farmingRadius-12.mp4).

```
enableFarmAnim Proto [Proto ...]
enableRectFarmAnim Proto [Proto ...]
farmingRadius Index X Z [Index X Z ...]
```

- **Effect:** gatherers on a building of an `enableFarmAnim` proto are placed and animated as on a
  Mill (they spread over the area around it); on an `enableRectFarmAnim` proto, as on a Rice
  Paddy (they work in its rows). `farmingRadius` gives, per `enableFarmAnim` entry (`Index` counts
  that line's protos from 1), the X and Z extent of that spread (stock 4.5 x 4.5; up to 100).
- **Your data:** the building still needs a gather action in its tactics (or the data's own way of
  gathering): these keys change where and how gatherers work, not whether the building can be
  gathered. A building whose tactics only modify other gatherers (`ModifyGather...`) gets no
  gatherers.
- **Log:** `enableFarmAnim/enableRectFarmAnim: N proto(s) work like a Mill, M like a Rice Paddy`;
  when `protoy.xml` is read, `enableFarmAnim: K of N protos found in the data` (and each unknown
  name); `farmingRadius: N farm proto(s) get their own gather area`, or `needs enableFarmAnim`,
  `needs triples ...`, `bad triple ...` (not applied); `hook reached: enableFarmAnim site 1
  (0x4EDA85)` to `... 8`, `enableRectFarmAnim site 1` to `4`, `farmingRadius (0x9DE04D)`.
- **Simulation:** changes where gatherers stand (the spread uses the game's synced random
  numbers): every player needs the same lines.
- **Status:** confirmed (2026-11-03, single player): with both lists, ten of the twelve placement
  sites and the radius ran, gatherers spread over a listed plantation and worked inside a listed
  farm's rows, and without the keys they stood bunched at one side (gathering in both cases);
  `farmingRadius` 12 widened the spread from about 5 m to 11.9 m. Sites 3 and 8 did not run in
  that test.
- **Fixed from UHC 1.10:** upstream reloads EBP before site 1 instead of keeping it, jumps to the
  Mill and Rice Paddy branches without the registers those branches have, and at site 5 skips the
  Mill flag the code after it reads.

#### nowalkfarm

**Added:** Tuesday 2026-11-03 10:43

![nowalkfarm in game](media/nowalkfarm.gif)

*In game:* four settlers on a Mill keep their spots; without the key (below) each walked 33–47 m
in a minute, moving to new spots around the field.
![nowalkfarm off](media/nowalkfarm-control.gif)
[Full video (MP4)](media/nowalkfarm.mp4), [without the key (MP4)](media/nowalkfarm-control.mp4).

```
nowalkfarm
```

- **Effect:** gatherers on a farm keep the spot they take when they start; stock moves them to a
  new spot around the farm from time to time.
- **Log:** `nowalkfarm: farm gatherers keep their first spot`.
- **Simulation:** changes where units stand: every player needs the same line.
- **Status:** confirmed (2026-11-03, single player): four settlers on a Mill moved 0 m in 60 s
  with the key and 33–47 m each without it, gathering in both cases. Video `nowalkfarm.mp4`.

#### betterfreedynamicunit

**Added:** Tuesday 2026-11-03 10:43

![betterfreedynamicunit in game](media/betterfreedynamicunit.gif)

*In game:* a tech with `amount="-2.00"` free Sheep, set at 3 minutes: 3 Sheep (1.5 two-minute
steps × 2). [Full video (MP4)](media/betterfreedynamicunit.mp4).

```
betterfreedynamicunit
```

- **Effect:** "dynamic" free units (a `FreeHomeCityUnit` effect with a negative `amount`) grow
  smoothly with game time: `-amount × min(time / 2 min, 15)`. Stock uses a whole number of
  2-minute steps, rounded up (at 3.5 steps it already counts 4).
- **Your data:** none beyond the negative amounts. The player needs a home city (the free units
  come from it; scenario players without one get none, with or without the key).
- **Log:** `betterfreedynamicunit: dynamic free units grow ...`; the first time, `amount A at S
  steps of 2 min -> N`.
- **Simulation:** changes how many units arrive: every player needs the same line.
- **Status:** confirmed (2026-11-03, single player): the same −2 Sheep tech at 420 s gave 7 Sheep
  with the key and 8 without; at 180 s, 3 with the key. Video `betterfreedynamicunit.mp4`.
  In the WoL copy: Argentineans, `Corderos` (−2 Sheep), set by a map trigger.

#### marketUnits

**Added:** Monday 2026-11-02 21:10

![marketUnits in game](media/marketUnits.gif)

*In game:* With only a listed market building, each click buys 100 food (food 200 to 500, gold falling); without the key the same clicks change nothing. [Full video (MP4)](media/marketUnits.mp4).

```
marketUnits Proto [Proto ...]
```

- **Effect:** owning a unit of a listed proto counts as owning a Market for buying and selling
  resources (stock requires the `Market` proto or the second market type).
- **Your data:** the listed buildings need the market's buy and sell commands.
- **Log:** `marketUnits: N proto(s) count as a Market for trading`; when `protoy.xml` is read,
  `marketUnits: K of N protos found in the data` (and each unknown name);
  `hook reached: marketUnits trade test (0x7DEF70)`.
- **Simulation:** changes who may trade: every player needs the same line.
- **Status:** confirmed (2026-11-02, single player): with only a `WOLMarketGreek` and 1000 gold,
  buying food worked (food 0 to 500, gold 1000 to 362); without the key the same clicks changed
  nothing. Video `marketUnits.mp4`.

### Buildings and training

How buildings train, spawn, live and get replaced.

| Key | What it does | WoL's DLL | WoL also needs | In-game status |
|---|---|---|---|---|
| [`liveBuildingWorkRate`](#livebuildingworkrate) | Makes `BuildingWorkRate` techs (train, research and `Maintain` speed) apply to buildings that already stand, not only to those completed after the tech, and `TrainPoints` techs to units already queued or in training. | **new** | Nothing. | confirmed (single player) |
| [`buildingWorkRateAuras`](#buildingworkrateauras) | Lets auras and other stat modifiers use the `ModifyType` `BuildingWorkRate`, which scales train, research and `Maintain` speed. | **new** | An `AutoRangedModify` action (or a power) with that `ModifyType`. | confirmed (single player, `Maintain`) |
| [`maintainWaitForPop`](#maintainwaitforpop) | When a marked building's automatic production finishes a unit while its player is at the population cap, keeps the unit and spawns it as soon as there is room. | **new** | That unit type on the producing buildings in `protoy`, or the name of an existing type or proto. | confirmed (single player) |
| [`trainSingleAbstractType`](#trainsingleabstracttype) | Marked units leave a training building one at a time, not as a batch. | **in `wol.cfg`** | That unit type on the protos. | confirmed |
| [`noTrainNearEnemyTC`](#notrainnearenemytc) | Marked units (the Daimyos and the Shogun by default) do not train while they stand near an enemy's first Town Center or an enemy building of a `near` type, with a warning over your own held units; the queue resumes when the blocker dies. | **new** | Nothing for the Daimyos; with a new marker, that type on the trainers (or on the blocking buildings) in `protoy`. | confirmed (single player) |
| [`lifespanAfterConstruction`](#lifespanafterconstruction) | Starts the `<Lifespan>` of marked buildings when their construction is finished, not when the foundation is placed. | **new** | A `<Lifespan>` on the buildings, and the unit type on them (or a type or proto name in the cfg). | confirmed (single player) |
| [`gaiaSocketsOnly`](#gaiasocketsonly) | Lets a socketed building (TradingPost, or a mod's) be placed only on a socket that Gaia owns, as the placement preview already shows. | **new** | Nothing for the global rule; with a new marker, that type on the sockets in `protoy`. | not tested in game |
| [`repairWallGlobal`](#repairwallglobal) | A UI syscall that repairs every wall of the local player. | **in `wol.cfg`** | A button or hotkey that calls `repairWallGlobal()`. | confirmed |
| [`hcShipmentPointFallback`](#hcshipmentpointfallback) | When the building holding the shipment point dies and none of the 10 stock fallback types (Town Center, Outpost, forts, …) is left, moves the point to the first alive building of the types you list, or to the player's first town center (`FirstTC`). | **new** | Nothing beyond the proto names in the cfg; `FirstTC` needs `startingTC` or `civFirstTC`. | confirmed (single player; `FirstTC` with `civFirstTC`) |

#### liveBuildingWorkRate

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Wednesday 2026-11-04 07:31

![liveBuildingWorkRate with TrainPoints in game](media/liveBuildingWorkRate-trainpoints.gif)

*TrainPoints:* Six settlers were queued at 12 s, with Settler `TrainPoints` 25; a test tech sets them to 6.25 at 30 s. The settler in training finishes at once (it already had more than 6.25 points of work) and the five already queued are trained in 6.25 s each; the log lines are at the top (2x speed). In stock all six would take 25 s. [Full video (MP4)](media/liveBuildingWorkRate-trainpoints.mp4).

![liveBuildingWorkRate in WoL](media/liveBuildingWorkRate-wol.gif)

*In WoL, with `liveBuildingWorkRate log` (an African civ's Town Center, selected so its queue
shows):* the TC trains 15 `AFRICANvillager`; at 30 s a test tech (`UHCBwrTest`, BuildingWorkRate x3
on `TownCenter`, appended to the bed's techtree for the test and removed after) turns on. The
standing TC works at 3.0 at once (`works at BuildingWorkRate 3.000, not its snapshot 1.000`), and
it has 13 villagers by 94 s (5 at the start).
[Full video (MP4)](media/liveBuildingWorkRate-wol.mp4).

![liveBuildingWorkRate in WoL, key off](media/liveBuildingWorkRate-wol-control.gif)

*In WoL, key off (the same scene):* stock keeps the TC's snapshot of 1.0, so the tech changes
nothing for it: 8 villagers by 96 s, the queue still long.
[Full video (MP4)](media/liveBuildingWorkRate-wol-control.mp4).

```
liveBuildingWorkRate [log]
```

- **How stock behaves:** two kinds of tech change how fast units are trained, and stock applies
  both late (WoL request #5, "workrate techs only affect units / buildings created after the
  tech"):
  - **`BuildingWorkRate`** (`type='Data' subtype='BuildingWorkRate'`, 15 techs in WoL). A
    building's `<BuildingWorkRate>` (1.0 on every stock proto) scales how fast it trains units,
    researches techs and spawns the units of its `Maintain` actions. The exe copies the proto's
    value into the building once, when the building is completed (for a unit with the flag
    `ForceBuildingData`, when it is created), and the train, research and `Maintain` code read that
    copy. The tech changes only the proto. So the buildings completed after the tech get the new
    speed, and the ones already standing keep the old one, although their stat panel shows the new
    value. Loading a saved game copies the value again for completed buildings, so the bug seems to
    vanish after a save and load.
  - **`TrainPoints`** (`type='Data' subtype='TrainPoints'` on the trained unit, 328 techs in WoL).
    Each queued unit (or batch) takes the unit's TrainPoints when it is queued and keeps them. A
    tech therefore misses the unit in training and every unit already in the queue, on old and new
    buildings alike; only the units queued after the tech train faster. A `Maintain` action takes
    them when its cycle starts, so the current cycle keeps the old time.
  - **Already live in stock:** `ResearchPoints` (`type='Data' subtype='ResearchPoints'` on a tech,
    85 techs in WoL). A research reads them on every tick, so the tech reaches every building, even
    a research in progress (in game: one at 17 of 30 points finished at once when the tech set
    7.5). WoL has no `WorkRate` / `WorkRateSpecific` effect with `action='Train'` or `'Research'`.
- **Effect:**
  - every building and `ForceBuildingData` unit trains, researches and spawns at its proto's
    current `BuildingWorkRate`;
  - a unit in training or in a queue, and the current `Maintain` cycle, take the trained unit's
    current `TrainPoints` on every tick. The progress already made is kept in points, as it is for
    research: when the points drop below it, the unit is done at once.

  So both techs apply at once to everything that exists, in both directions (a tech that is
  removed again, a trigger, any later change of the value). Units without building data already
  worked this way for `BuildingWorkRate` in stock.
- **Your mod:** nothing. It works with the techs you have:

  ```xml
  <Effect type ='Data' amount ='2.00' subtype ='BuildingWorkRate' relativity ='BasePercent'>
      <Target type ='ProtoUnit'>Stable</Target></Effect>
  <Effect type ='Data' amount ='0.75' subtype ='TrainPoints' relativity ='BasePercent'>
      <Target type ='ProtoUnit'>Musketeer</Target></Effect>
  ```

- **`YPForceTrainAtBaseTrainPoints`:** a trainer whose proto has this flag (stock: the Confucian
  Academy and Summer Palace wonders) trains at the base proto's TrainPoints, which no tech changes
  (stock rule); the key keeps that rule.
- **Not covered:** the action rates. `type='Data' subtype='WorkRate'` effects (gathering,
  building, healing, …) and `type='Data2' subtype='WorkRateSpecific'` effects are read live by
  stock already (static reading), so they already reach existing units; this key does not change
  them.
- **Transformed buildings:** a building that changes proto in place (a `TransformUnit` tech) now
  works at the new proto's rate; stock kept the old proto's copy. With stock data there is no
  difference, since every stock proto has 1.0.
- **`log`:** one line for each building whose speed this key changes, and for each trainer and
  unit type whose points it changes, the first time and again only if the values change later.
  Use it to check your data, not in a release.
- **Log:** at startup `liveBuildingWorkRate: train, research and Maintain speed follow the
  proto's current BuildingWorkRate, and queued, training and Maintain units their current
  TrainPoints (multiplayer unverified)` (with `log`: `…TrainPoints, every building and unit it
  changes logged (multiplayer unverified)`). In a game, `hook reached: liveBuildingWorkRate
  (0x9BFE33)` the first time any building trains, researches or spawns, `hook reached:
  liveBuildingWorkRate TrainPoints (0x9EA1FA)` the first time a unit trains, and `hook reached:
  liveBuildingWorkRate Maintain TrainPoints (0x9E27E4)` the first time a `Maintain` cycle runs.
  With `log`:
  - `liveBuildingWorkRate: unit N (Proto, player P) works at BuildingWorkRate 4.000, not its
    snapshot 1.000`;
  - `liveBuildingWorkRate: unit N (TownCenter, player 1) trains Settler at TrainPoints 6.250, not
    the 25.000 it was queued with`;
  - `liveBuildingWorkRate: unit N (BloodFactory, player 1) spawns Musketeer at 7.500 points per
    cycle, not the 30.000 its cycle started with`.
- **Limits:**
  - with `log`, a unit is logged once per unit ID (and trained type) and pair of values in a game;
    a new game starts the list again;
  - whether a building under construction can train or research was not checked. If it can, it
    now uses the proto's rate there, where stock used 1.0. `Maintain` never runs on an unfinished
    building;
  - a queued unit that has not started yet keeps the points it was queued with until it starts
    (nothing reads them before), so the queue panel may show its old time until then.
- **Simulation:** yes. Saved games load with or without the key: the building's copy and the
  queued points are kept and saved as in stock (with the key, the values it last wrote).
- **Status:** confirmed in single player.
  - 2026-10-29, `Maintain`: each of two players got a `BloodFactory` (which spawns musketeers
    through a `Maintain` action) at 1 s; at 20 s a test tech gave player 1's `BloodFactory`
    `BuildingWorkRate` 4. At 112 s player 1 had 12 musketeers and player 2 had 3. With the key
    off, both had 3 (the bug).
  - 2026-10-30, train and research. A scenario: player 1's Town Center and Market placed by the
    map, a second Town Center and Market created 5 s after the test tech (30 s); the train and
    research progress read from memory every second.
    - `BuildingWorkRate` 4 on `TownCenter` and `Market`. Key off: the existing Town Center trained
      every settler in 25 s, also those queued after the tech; the new one in 6.25 s; the existing
      Market took 30 s for a research the tech landed in and 20 s for `HuntingDogs` after it, the
      new Market 7.5 s for `Gangsaw` (30 points). Key on: the settler in training sped up at 30 s
      and every later one took 6.25 s; the research in progress finished 3.2 s after the tech, and
      `HuntingDogs` took 5 s.
    - `TrainPoints` ×0.25 on `Settler` and `Musketeer`. Key off: the three settlers queued before
      the tech took 25 s each, though two of them started after it; the settlers queued after it
      took 6.25 s on the old and the new Town Center; the factory's current cycle kept 30 points.
      Key on: the settler in training finished at the tech and the queued ones took 6.25 s; the
      cycle took the new 7.5 points at once. The same with `buildingWorkRateAuras`,
      `noTrainNearEnemyTC` and `maintainWaitForPop` on, and again after loading a game saved
      before the tech.
    - `ResearchPoints` ×0.25: live in stock, with or without the key.
  - An AI skirmish with the key and those three keys on: both AIs trained and built, with no XS
    error.
  - `liveBuildingWorkRate foo`: logged as an unexpected argument, the key not applied.
- **New in this DLL:** not in UHC 1.10. WoL request #5 ([wol-requests.md](wol-requests.md)).

#### buildingWorkRateAuras

**Added:** Thursday 2026-10-29 10:35 · **Filmed in WoL:** Wednesday 2026-11-04 07:31

![buildingWorkRateAuras in WoL](media/buildingWorkRateAuras-wol.gif)

*In WoL, with `buildingWorkRateAuras log` (an African civ, the two Town Centers selected):* both TCs
train 10 `AFRICANvillager`; the Explorer next to the left one carries a test aura (`UHCBwrAura`:
`AutoRangedModify`, `BuildingWorkRate` x3, 10 m, on `TownCenter`, added to the bed's
`explorer.tactics` and removed after). The left TC works at x3 (`works at x3.000 from
BuildingWorkRate modifiers`) and trains 7 villagers while the right one trains 2.
[Full video (MP4)](media/buildingWorkRateAuras-wol.mp4).

![buildingWorkRateAuras in WoL, key off](media/buildingWorkRateAuras-wol-control.gif)

*In WoL, key off (the same data and scene):* stock reads `BuildingWorkRate` as no stat, so the aura
does nothing: each TC trains 2 villagers.
[Full video (MP4)](media/buildingWorkRateAuras-wol-control.mp4).

```
buildingWorkRateAuras [log]
```

- **How stock behaves:** an aura (a tactics action of type `AutoRangedModify`) changes one stat of
  the units in range, named by `<ModifyType>`. The exe knows 13 names: `Speed`, `MaxHP`, `Damage`,
  `MovingDamage`, `Bounty`, `SiegeDamage`, `UnitDamage`, `LOS`, `Armor`, `GatherRate`,
  `AbilityROF`, `ROF` and `AutoGatherRate` (case is ignored). Any other name is read as "no stat"
  without an error, and the aura does nothing. `BuildingWorkRate`, the speed at which a building
  trains units, researches techs and spawns its `Maintain` units, is not one of them.
- **Effect:** `BuildingWorkRate` becomes a valid `<ModifyType>`. A unit that a modifier with it
  reaches trains, researches and spawns its `Maintain` units at its normal rate times the
  modifier's `<ModifyMultiplier>`. The factor starts at 1.0, like `GatherRate`: several auras
  multiply each other, and an aura with `<ModifyExclusive>1</ModifyExclusive>` stops the ones
  after it, as for every stock stat.
- **Your mod:** an `AutoRangedModify` action with the new name, in the tactics file of the unit
  that carries the aura, listed in each of its tactics. Pick the buildings with `<ModifyProtoID>`
  or `<ModifyAbstractType>`. For example, an aura like the one of the in-game test, on the
  Explorer:

  ```xml
  <action>
      <name>UHCBwrAura</name>
      <type>AutoRangedModify</type>
      <active>1</active>
      <persistent>1</persistent>
      <maxrange>40</maxrange>
      <modifyprotoid>BloodFactory</modifyprotoid>
      <modifytype>BuildingWorkRate</modifytype>
      <modifymultiplier>4.0</modifymultiplier>
  </action>
  ```

  and, in each of the unit's tactics, the action on the tactic name's line:
  `<tactic>Volley<action>UHCBwrAura</action>…`. Ship the tactics file compiled
  ([Tactics files](#tactics-files)). The aura reaches only its owner's own units (unless its
  tactics action allows other players) and only finished ones (static reading). A power's
  `<unitModify apply='Multiply' amount='1.5'>BuildingWorkRate</unitModify>` works too (static
  reading, not tested).
- **With `liveBuildingWorkRate`:** the two combine. The aura multiplies the building's rate, which
  is the proto's current `BuildingWorkRate` with that key, or the copy taken when the building was
  completed without it.
- **With `noTrainNearEnemyTC`:** that key owns the Train call; its hook calls this key's factor
  through a shared pointer, so trainers still get it. The log says so at startup.
- **`log`:** one line when a unit's factor changes, and one when it is back to 1.0.
- **Log:** at startup `buildingWorkRateAuras: modifiers with ModifyType BuildingWorkRate (stat
  0x40) scale train, research and Maintain speed (multiplayer unverified)` (with `log`: `…speed,
  every change of a unit's factor logged (multiplayer unverified)`), and, with
  `noTrainNearEnemyTC`, `buildingWorkRateAuras: the Train call at 0x009EA410 is already hooked
  (noTrainNearEnemyTC); Train speed gets the factor only through that hook's call of
  g_uhcBwrTrainGetter`. While the data loads, `hook reached: buildingWorkRateAuras (0x5FE6D7)` and,
  once a tactics file uses the name, `hook reached: buildingWorkRateAuras ModifyType
  BuildingWorkRate (0x5FE6D7)`; in a game, `hook reached: buildingWorkRateAuras (calls of
  0x9BFE33)` (the first train, research or `Maintain` tick) and `hook reached:
  buildingWorkRateAuras: a unit with modifiers (calls of 0x9BFE33)`. With `log`:
  `buildingWorkRateAuras: unit N (BloodFactory, player 1) works at x4.000 from BuildingWorkRate
  modifiers (Maintain)` and `buildingWorkRateAuras: unit N (Proto, player P) works at x1.000
  again: no BuildingWorkRate modifier left (Train)`. The last word is `Train`, `Research`,
  `CommandResearch`, `Maintain`, or `through g_uhcBwrTrainGetter` for the Train call when
  `noTrainNearEnemyTC` owns it.
- **Limits:**
  - only train, research and `Maintain` speed. Build, repair and heal speed come from each
    action's own rate and are not covered. `GatherRate` and `AutoGatherRate` auras already work in
    stock;
  - the stat panel still shows the proto's `BuildingWorkRate`, and the aura's tooltip has no line
    for this stat;
  - with `log`, a unit is logged once per unit ID and factor in a session, so a unit of a later
    game with the same ID and factor is not logged again;
  - the value 0x40 that stands for the new stat is this DLL's choice. Another DLL that adds its own
    `ModifyType`s must not use it.
- **WoL data** (static scan): `alguacil.tactics` already has such an aura (`GuatemalaAura`,
  `EscuelaPolitecnica`, 1.20), but it is `<active>0</active>` and no tech turns it on. Five
  tactics use `GATHER` (`GatherRate` is meant), two use `Hitpoints` (`MaxHP` is meant) and one
  uses `UnitResource`, which is no stat: stock reads all three as unknown, so those auras do
  nothing, with or without this DLL.
- **Simulation:** yes. A saved game keeps the modifier's stat; loading it without the key ignores
  it.
- **Status:** confirmed in single player (2026-10-29), with an aura on the Explorer (multiplier
  4.0, range 40, `ModifyProtoID` `BloodFactory`): player 1's BloodFactory logged `works at x4.000
  from BuildingWorkRate modifiers (Maintain)` and spawned 11 musketeers, while player 2's factory,
  without the aura, spawned 2 in the same time. `liveBuildingWorkRate` and `noTrainNearEnemyTC`
  were on in the same run. Train and research speed, the removal of the aura, powers and saved
  games were not tested.
- **New in this DLL:** not in UHC 1.10. WoL request #22 ([wol-requests.md](wol-requests.md)).

#### maintainWaitForPop

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Wednesday 2026-11-04 08:11

![maintainWaitForPop in WoL](media/maintainWaitForPop-wol.gif)

*In WoL, with `maintainWaitForPop TownCenter log` (WoL's `Age0Ottoman` turns on the TC's
`MaintainSettlersOttoman`; the TC is selected):* the population is over its cap (11 of 10), so at
62 s the TC holds its finished settler (`holds a finished Settler (pop 1, 11 of 10 used)`). Two
settlers die at 70 s and the held one comes out at once (`releases its Settler (pop 1, 9 of 10
used)`). [Full video (MP4)](media/maintainWaitForPop-wol.mp4).

![maintainWaitForPop in WoL, key off](media/maintainWaitForPop-wol-control.gif)

*In WoL, key off (the same scene):* the cycle that ended at full population is lost; after the
two deaths at 70 s the next settler needs a whole new cycle and appears about 23 s later.
[Full video (MP4)](media/maintainWaitForPop-wol-control.mp4).

```
maintainWaitForPop [<UnitType>] [log]     default AbstractMaintainWaitForPop
```

- **How stock behaves:** some buildings produce units on their own, through a `Maintain` action
  in their tactics file: the factory's `SpawnCannon`, the Ottoman Town Center's settlers, the
  dock's `SpawnBoat`, the native trading posts' warriors, and many more in WoL. The building fills
  a timer: `<rate type="X">n</rate>` gives the unit X and n units per cycle, and the cycle costs
  n × X's `TrainPoints` at the building's work rate. When the timer is full, the game tries to
  spawn the units. A unit that does not fit in the player's population is not created, and the
  game does not check whether anything was spawned:
  - a normal action starts the next cycle from zero, so after a house is built the next unit
    comes a whole cycle later;
  - a `SingleUse` action (dock boats, native warriors) ends, so its units are lost.
- **Effect:** for a building whose proto is of `<UnitType>`, a cycle that ends while the first
  unit does not fit is **held**: the timer stays full and no new cycle starts. The unit spawns on
  the first game update with room (a unit dies, a house is finished, a tech raises the cap). A
  held `SingleUse` action waits instead of ending. Any other building behaves as in stock.
- **"Does not fit"** is exactly the stock test that would have refused the unit: its
  `PopulationCount` against the player's current population and cap, with `AllowOverPopCap` and
  `AlwaysAllowOverPopCap`, and with the cap set by `basePop` / `extraPop`. A unit with no
  population cost is never held. After a revolution, settlers and coureurs are tested as
  `xpColonialMilitia`, as the game spawns them.
- **Which buildings:** the marker goes on the **producing building**, not on the produced unit.
  - The default `AbstractMaintainWaitForPop` is registered by the DLL, like `healNonIdle`'s
    marker; list it on the buildings you want and edit `protoy.xml` and its XMB as described
    there:

    ```xml
    <Unit id ='348' name ='Factory'>
        ...
        <UnitType>AbstractMaintainWaitForPop</UnitType>
    ```

  - An existing type or proto name works with no data change: `maintainWaitForPop Factory` covers
    factories only, `maintainWaitForPop Building` every building.
- **Balance:** this is a gameplay change. With `Building`, a housed Ottoman player gets the next
  free settler as soon as a house is up, instead of a whole cycle later. Mark only the buildings
  you mean.
- **Limits** (stock behavior kept):
  - batches (`<rate>` above 1): a cycle is held only while its **first** unit does not fit. When
    there is room for some but not all, the stock spawn creates what fits and drops the rest;
  - `AbstractMonk` spawns: stock may reuse an existing unit without testing the population, so
    they are never held;
  - a cycle that spawns nothing for another reason (the build limit, no room to place the unit)
    still restarts as in stock.
- **`log`:** one line when a building starts holding a unit and one when it releases it.
- **Log:** at startup `maintainWaitForPop: buildings of unittype X keep a finished Maintain unit
  until there is population room (multiplayer unverified)` (with `log`: `…room, holds and releases
  logged (multiplayer unverified)`); when the data loads, `unit types: X -> <ID> …`; in a game,
  `hook reached: maintainWaitForPop (0x6AB27D)` the first time any `Maintain` cycle ends. With
  `log`: `maintainWaitForPop: unit N (TownCenter) holds a finished Settler (pop 1, 10 of 10 used)`
  and `maintainWaitForPop: unit N (TownCenter) releases its Settler (pop 1, 9 of 10 used)`.
- **Saved games:** a held cycle is saved as a full timer, with no extra data. Loaded without the
  key, it behaves as in stock.
- **Simulation:** yes. It may also add a unit type, which changes the unit type count.
- **Status:** confirmed in single player (2026-10-29), with an Ottoman Town Center (the tech
  `Age0Ottoman` gives it its settler `Maintain` action) at 10 of 10 population. It held its
  finished settler (`holds a finished Settler (pop 1, 10 of 10 used)`) and released it right after
  two settlers died (`releases its Settler (pop 1, 9 of 10 used)`). With the key off, no settler
  came until the next full cycle. Factory cannons, batches and `SingleUse` spawns were not tested.
- **New in this DLL:** not in UHC 1.10. WoL request #8 ([wol-requests.md](wol-requests.md)).

#### trainSingleAbstractType

**Added:** Tuesday 2026-11-03 07:25

![trainSingleAbstractType in game](media/trainSingleAbstractType.gif)

*In game:* three marked hussars queued at once come out one at a time (the unit lines on top grow
from one to two); without the key the same order brought three out together.
[Full video (MP4)](media/trainSingleAbstractType.mp4).

```
trainSingleAbstractType [UnitType]
```

- **Effect:** units of the marker type (default `AbstractTrainLimitOne`) leave a training
  building one at a time, as monks do in stock, instead of as one batch.
- **Your data:** `<UnitType>AbstractTrainLimitOne</UnitType>` (or your type) on the protos.
- **Log:** `trainSingleAbstractType: units of unittype <Type> are trained one at a time`; the
  first time it applies, `trainSingleAbstractType: <Proto> is trained one at a time`.
- **Simulation:** changes how units are created: every player needs the same line.
- **Status:** confirmed (2026-11-03, single player): a queue of marked hussars produced one, then
  a second about a minute later; without the key the same queue produced three together (the
  proto's `BuildLimit` is 3). Video `trainSingleAbstractType.mp4`.

#### noTrainNearEnemyTC

**Added:** Thursday 2026-10-29 10:35 · **Filmed in WoL:** Wednesday 2026-11-04 09:54

![noTrainNearEnemyTC in WoL](media/noTrainNearEnemyTC-wol.gif)

*In WoL, with `noTrainNearEnemyTC 40 near Settler log` (Japanese, the Daimyo selected so its queue
shows):* a Daimyo queues 3 Kihei with an enemy unit 12.1 m away (`near` also takes moving units). The
queue stays paused (`paused training: player 2's unit 7 (Settler) is 12.1 m away`) until that unit
dies at 48 s (`resumed training`), and then the Kihei come out.
[Full video (MP4)](media/noTrainNearEnemyTC-wol.mp4).

![noTrainNearEnemyTC in WoL, key off](media/noTrainNearEnemyTC-wol-control.gif)

*In WoL, key off (the same scene):* nothing holds the queue: the 3 Kihei are out by 40 s of game
time, with the enemy still next to the Daimyo.
[Full video (MP4)](media/noTrainNearEnemyTC-wol-control.mp4).

![noTrainNearEnemyTC in game](media/noTrainNearEnemyTC.gif)

*1. Near an enemy's first Town Center:* A Daimyo 34 m from an enemy Town Center pauses its queue, then resumes when the Town Center dies (2.5x speed). [Full video (MP4)](media/noTrainNearEnemyTC.mp4).

![noTrainNearEnemyTC near a Stable, with the warning](media/noTrainNearEnemyTC-near.gif)

*2. `near Stable` and the warning:* `noTrainNearEnemyTC 40 near Stable near FirstTC log`, the camera on the Daimyo. It stands 21 m from the edge of an enemy Stable with 5 Ashigaru queued: the queue does not move, and every 8 s of game time the red text "Too close to the enemy: training paused" appears over it (the overlay shows each `warning shown` line). The Stable is destroyed at 75 s: the log reads `resumed training`, now with the enemy Town Center 138.6 m away as the nearest, and the Ashigaru are trained (2x speed). [Full video (MP4)](media/noTrainNearEnemyTC-near.mp4).

![noTrainNearEnemyTC with its own warning text](media/noTrainNearEnemyTC-warn.gif)

*3. Your own text:* with `warn=¡Demasiado_cerca!`, the same held Daimyo shows "¡Demasiado cerca!" (1.5x speed). [Full video (MP4)](media/noTrainNearEnemyTC-warn.mp4).

```
noTrainNearEnemyTC <meters> [<UnitType>] [near <UnitType>|FirstTC]... [nowarn | warn=<text> | warn=<stringID>] [log]
    default AbstractDaimyo, near FirstTC, the English warning; up to 4 near; one line
```

- **How stock behaves:** each player remembers his first Town Center, the `FirstTC` of the
  placement rules (see [`startingTC`](#startingtc)). The stock rule
  `distanceatleastfromtype player=enemy distance=65 FirstTC` keeps buildings 65 m away from an
  enemy's first Town Center. Nothing limits a unit that trains: a Daimyo or the Shogun can walk
  into the enemy base and train an army next to his Town Center.
- **Effect:** a unit whose proto is of `<UnitType>` does not train while an enemy's first Town
  Center, or an enemy's unit of a `near` type, is alive and less than `<meters>` away. Its queue
  keeps the progress it has, and goes on as soon as nothing is that close any more (the blocker is
  destroyed). Nothing is refunded or cancelled, and the order is accepted as in stock. "Enemy" is
  the stance of the blocker's owner toward the trainer's player, as for `player=enemy` in the
  placement rules: your own and your allies' buildings never block, nor do Gaia's (natives,
  treasures).
- **Choosing the trainers:** the default `AbstractDaimyo` is a stock type that the Daimyos and the
  Shogun already have, so it needs no data change. In WoL it also covers `MapucheWarchief`, the
  `WOLGensui*` units, `EGYtowncenterCARAVAN`, `EGYbarracks3CARAVAN` and `DummyGather` (static scan
  of WoL's `protoy`). To pick the trainers yourself, give them a new marker (for example
  `AbstractNoTrainNearEnemyTC`) in `protoy.xml` and its XMB, as for `healNonIdle`, and name it in
  the cfg. A proto name works too.
- **Choosing what blocks (`near`):** without `near`, only an enemy's first Town Center blocks.
  Each `near <UnitType>` adds a type: a proto name (`near Stable`, `near Barracks`), a stock type
  (`near AbstractTownCenter` for every Town Center, not only the first) or a new marker
  that you put on your buildings in `protoy`. As soon as the line has one `near`, only the listed
  entries block: add `near FirstTC` to keep the first Town Center. Up to 4 entries. A building
  blocks only once it is built (a foundation does not; static reading), and while it is alive. A
  type of moving units works too (units always count as built): `near Hussar` held a Daimyo
  while an enemy Hussar stood 17.3 m away.
- **How the distance is measured:** from the trainer's centre to the nearest edge of the
  blocker's footprint, 0 inside it. It is the engine's own distance, the one the placement rules
  use, so `65` matches the stock 65 m rule. For example, a Stable (3 × 5 m half-sizes) whose
  centre is 24 m from the Daimyo is 21 m away. For units without such a footprint (units that can
  move) the engine uses the centre distance minus the unit's radius × 1.41: a Hussar whose centre
  was 18.4 m away counted 17.3 m.
- **Choosing the distance:** `<meters>` is a number above 0 and at most 1000 (decimals allowed).
- **Which Town Center counts for `FirstTC`:** only each player's first Town Center, not every Town
  Center. A player whose first Town Center was destroyed gives no protection, even if he built
  another one. WoL's Maori (whose first Town Center dies at 0.5 s) are protected only with
  [`startingTC`](#startingtc) and the `MaoriPa` marked. A civ that starts with another building
  through [`civFirstTC`](#civfirsttc) is protected by that building (static reading; not tested
  with this key). `near AbstractTownCenter` covers every Town Center instead.
- **The warning:** while one of your units is held, a red text appears over it, at most once every
  8 s of game time per unit, and only on your own screen: other players see nothing, not even for
  units they can see. It is the stock dodge's floating text ("¡Esquiva!" uses it) without its rise,
  so it stays over the unit for about 1.5 s. `warn=<text>` replaces the English default "Too close
  to the enemy: training paused": `_` stands for a space, at most 127 characters, UTF-8 (else the
  Windows code page). `warn=<number>` takes that string from the string table (`warn=63950` shows
  the stock "Dodge!" in the game's language), so a mod can translate its own text in
  `stringtabley.xml`. `nowarn` turns it off.
- **A held trainer stays where it is.** In stock, a Daimyo with units in its queue does not move: a
  right-click on the ground sets its gather point, and move orders (a trigger, the console's
  `uiMoveAllMilitaryAtPointer`) are ignored until the queue is empty (seen in game). So a held
  Daimyo waits until the blocker is destroyed, or until the player cancels the queue (stock refund),
  moves it away and queues again.
- **With other keys:** with [`buildingWorkRateAuras`](#buildingworkrateauras), a trainer out of
  range trains at its aura-boosted rate, and with `liveBuildingWorkRate` at its proto's current
  rate: this key's hook calls the same getter.
- **`log`:** one line the first time each marked unit trains (whether it may train, with the
  nearest blocker and its distance), then one line each time it pauses or resumes, and one per
  warning. The list of logged units starts again at each data load; at most 1000 lines per session.
  Use it to check your data and your distance, not in a release.
- **Log:** at startup `noTrainNearEnemyTC: units of unittype X do not train within 40.0 m (from the
  trainer's centre to the edge of the building) of an enemy's Stable, an enemy's first Town Center
  (FirstTC), with a warning over the local player's held units, every pause and resume logged
  (multiplayer unverified)` (the warning and `log` parts only when on); when the data loads,
  `unit types: AbstractDaimyo -> <ID> (…), already defined` and one such line per `near` type; in a
  game, `hook reached: noTrainNearEnemyTC (0x9EA410)` the first time any unit or building trains.
  With `log`:
  - `noTrainNearEnemyTC: unit N (ypDaimyoKiyomasa, player 1) paused training: player 2's unit M
    (Stable) is 21.0 m away (limit 40.0 m)`;
  - `noTrainNearEnemyTC: unit N (…) resumed training: …`, with the nearest blocker left, or
    `nothing to keep away from`;
  - `noTrainNearEnemyTC: unit N (…) trains: …` the first time a unit trains with no block;
  - `noTrainNearEnemyTC: warning shown over unit N (ypDaimyoKiyomasa)` (`: refused by the engine`
    when the game did not take the text);
  - `noTrainNearEnemyTC: 1000 lines logged; the next changes are not`.

  A bad line, and the key is not applied:
  - `noTrainNearEnemyTC: expected "noTrainNearEnemyTC <meters> [UnitType] [near <UnitType> ...]
    [nowarn | warn=<text>] [log]" with meters above 0 and at most 1000, got "…"`;
  - `noTrainNearEnemyTC: near needs a unit type (or FirstTC), at most 4`;
  - `noTrainNearEnemyTC: warn=…: expected warn=<text> (at most 127 characters, '_' for a space) or
    warn=<string table ID>`;
  - `noTrainNearEnemyTC: unexpected argument … (expected: …)`.
- **Limits:**
  - training pauses; the command is not refused, and the interface still shows the queue (its
    progress bar stops);
  - a held trainer does not walk away with its queue (stock, above);
  - `FirstTC` is only the first Town Center (see above);
  - the AI does not know about the rule: it may queue units in a Daimyo that stands near an enemy
    building and wait.
- **Simulation:** yes. Every player needs the same meters, trainer type and `near` entries; a new
  marker name adds a unit type. `nowarn` and `warn=` only change what the local player sees and may
  differ.
- **Status:** confirmed in single player (2026-10-29), in a test map (no AI) unless noted:
  - `noTrainNearEnemyTC 65 log` (with every WoL key on): a `ypDaimyoKiyomasa` 34.1 m from player
    2's first Town Center made no progress on 2 `ypAshigaru`, and trained both once the Town Center
    was killed (`resumed training: no enemy FirstTC` in that version of the log). The same test
    with `nowarn`: paused at 34.1 m, no warning line, resumed when the Town Center died;
  - `noTrainNearEnemyTC 40 near Stable near FirstTC log`, with `liveBuildingWorkRate` and
    `buildingWorkRateAuras`: paused 21.0 m from a Stable's edge (Town Center 138.6 m away), 9
    warnings 8 s apart, all 5 Ashigaru trained once the Stable was killed; walked next to the enemy
    Town Center, it paused again (`player 2's unit 1 (TownCenter) is 6.4 m away`) with 1 Ashigaru
    queued (video 2);
  - `warn=¡Demasiado_cerca!` and `warn=63950` showed "¡Demasiado cerca!" and "¡Esquiva!" (video 3);
  - four bad lines (`near` with no type, 5 `near`, `warn=` empty, a 140-character text): one log
    line each, the key `FAILED`, the game normal;
  - AI: a skirmish against a Japanese AI with this key (`near Barracks near Stable near FirstTC`)
    and every WoL key on: the AI went from 15 to 25 units in 2 minutes and started its wonder, no
    XS error.

  - `noTrainNearEnemyTC 30 near AbstractTownCenter near Hussar log`: held by an enemy Hussar 17.3 m
    away (a moving type), and in another game by an enemy's second Town Center 22.0 m away (not
    its first; the first, 150 m away, did not count); each resumed when its blocker was removed,
    and the 3 queued Ashigaru were trained;
  - saved games: a game saved with the Daimyo held and loaded again logged `paused training` at
    once and stayed held until the blockers were removed (the decision keeps no state).

  Not tested: a foundation near the trainer, multiplayer. For such a test, the Daimyo trains only
  from Age II and needs population room and food.
- **New in this DLL:** not in UHC 1.10. WoL request #27 ([wol-requests.md](wol-requests.md)).

#### lifespanAfterConstruction

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Wednesday 2026-11-04 08:32

![lifespanAfterConstruction in WoL](media/lifespanAfterConstruction-wol.gif)

*In WoL, with `lifespanAfterConstruction Outpost log` (Spanish, the settlers and the foundation
selected; 3x speed):* for the test the bed's Outpost gets `<Lifespan>15</Lifespan>` (removed after).
Two settlers build one: its lifespan waits while it is a foundation (`0 % built; its lifespan
(15.00 s left) waits`), the Outpost is finished at 59 s, and it comes down 15 s later.
[Full video (MP4)](media/lifespanAfterConstruction-wol.mp4).

![lifespanAfterConstruction in WoL, key off](media/lifespanAfterConstruction-wol-control.gif)

*In WoL, key off (the same scene):* the countdown runs from the placement, so the foundation dies
half built 15 s later and leaves rubble. This is what happens to WoL buildings whose Lifespan is
shorter than their construction (`WOLVillagerMaturing`: Lifespan 10, BuildPoints 15).
[Full video (MP4)](media/lifespanAfterConstruction-wol-control.mp4).

```
lifespanAfterConstruction [<UnitType>] [log]     default AbstractLifespanAfterConstruction
```

- **How stock behaves:** `<Lifespan>` (seconds) is a countdown that starts when the unit is
  created. A building is created when its foundation is placed, so the countdown runs while the
  building is under construction, and nothing restarts it when the construction ends. A building
  whose Lifespan is shorter than its construction dies as a foundation; any other one lives
  Lifespan minus its construction time once built. With `<Flag>AlphaFadeLifespan</Flag>`, the
  fade-out before the end runs on its own timer from placement too, and its end kills the unit by
  itself. No stock building has a Lifespan; mods such as WoL use it (its `*Maturing` buildings).
- **Effect:** for a unit whose proto is of `<UnitType>`, the countdown and the lifespan fade-out do
  not advance while the unit is not fully built. When the construction is finished, both run from
  their full values as in stock: the building lives `Lifespan` seconds after it is finished. Any
  other unit, and every unit that is already built, behaves as in stock.
- **Marking the buildings:** the protos also need a `<Lifespan>`:

  ```xml
  <Unit id ='293' name ='House'>
      ...
      <Lifespan>20</Lifespan>
      <UnitType>AbstractLifespanAfterConstruction</UnitType>
  ```

  The marker is registered by the DLL, like `healNonIdle`'s; edit `protoy.xml` and its XMB as
  described there. An existing type or proto name works too, with no data change:
  `lifespanAfterConstruction Outpost` covers outposts only, `lifespanAfterConstruction Building`
  every building.
- **"Built"** means the unit has no construction data, or its build percent is at least 100 %.
  Units that are not buildings (projectiles, rubble, …) are always built, so a marker on them
  changes nothing.
- **Destroyed or deleted foundations** are never held: once the unit is dying, its corpse fades
  and is removed as in stock.
- **A Lifespan set during construction** (a tech with a `Lifespan` data effect, or a trigger) also
  waits for the construction.
- **`log`:** one line the first time each unit's countdown is held, one when its fade-out is held,
  and one when its countdown runs again, with the reason and the seconds left.
- **Log:** at startup `lifespanAfterConstruction: units of unittype X keep their Lifespan and its
  fade-out until their construction is finished (multiplayer unverified)` (with `log`:
  `…finished, every hold and start logged (multiplayer unverified)`); when the data loads,
  `unit types: X -> <ID> …`; in a game, `hook reached: lifespanAfterConstruction fade (0x482A1A)`
  (the first step of any game) and `hook reached: lifespanAfterConstruction (0x483EEC)` (the first
  time any unit with a Lifespan counts down, e.g. a cannonball). With `log`:
  - `lifespanAfterConstruction: unit N (Proto) is P % built; its lifespan (S s left) waits for the
    construction (game time T ms)`;
  - `lifespanAfterConstruction: unit N (Proto) is P % built; its fade-out (due in S s, D s long)
    waits for the construction (game time T ms)`;
  - `lifespanAfterConstruction: unit N (Proto) is built; its lifespan starts with S s left (game
    time T ms)`, or, instead of `is built; its lifespan starts`: `is dying; its lifespan runs as in
    stock`, `lost the marker unittype; its lifespan runs` or `is no longer held; its lifespan runs`.
- **Limits:**
  - `FadeInOnCreation` together with `AlphaFadeLifespan` (a stock limitation): the creation
    fade-in reuses the lifespan fade's timer, so in stock such a unit dies right after its fade-in.
    With this key a marked building with both flags dies when its construction ends. Do not
    combine the two flags on a marked building;
  - the hold lasts while the unit is not fully built: if a building's percent dropped below 100 %
    again, its countdown would stop again.
- **Simulation:** yes. It may also add a unit type, which changes the unit type count.
- **Status:** confirmed in single player (2026-10-29), with `lifespanAfterConstruction Outpost log`
  and test data (Outpost `Lifespan` 20, 50 build points, `PlaceAsFoundation`). An Outpost placed by
  a settler at 19.5 s was held through its construction, finished at 70.5 s (`its lifespan starts
  with 20.00 s left`) and died at about 90 s. In the control, an unmarked Outpost died at 20 s,
  still under construction (the bug). The `AlphaFadeLifespan` fade-out hold was not checked in
  game. To test it yourself, place the foundation in game: a building placed by a scenario is
  complete once the scenario is loaded.
- **New in this DLL:** not in UHC 1.10. WoL request #7 ([wol-requests.md](wol-requests.md)).

#### gaiaSocketsOnly

**Added:** Thursday 2026-10-29 06:39

```
gaiaSocketsOnly [<UnitType>] [log]       no unit type: every socket follows the rule
```

- **How stock behaves:** a building with `<SocketUnitType>` (stock: `TradingPost`,
  `ypTradingPostAsian`) must stand exactly on a socket unit of that type. Only the placement
  preview checks the socket's owner: the building snaps onto a socket only if Gaia owns it, so a
  socket a player owns shows red. The check that decides (run when the order executes, on every
  machine, and before it by the UI and the AI) never reads the owner. According to the static
  reading, an order that carries the socket's exact position (an AI build plan) therefore builds
  on a player's socket; WoL reports this with its saltpeter sockets. Stock data never shows it,
  because every stock socket has the flag `ForceToGaia` (it is created for Gaia).
- **Effect:** when a socketed building is placed, a socket that a player owns no longer counts.
  The order fails as if there were no socket. The rule also covers the socket's owner himself, as
  the stock preview does. Gaia sockets behave as in stock, and so does the preview.
- **`<UnitType>`:** only sockets whose proto is of that type (or that proto name) follow the rule;
  every other socket keeps the stock behavior. Use it to apply the rule to your own sockets only,
  for example a marker on the saltpeter socket:

  ```xml
  <Unit id ='…' name ='SaltpeterSocket'>
      ...
      <UnitType>AbstractGaiaOnlySocket</UnitType>
  ```

  The marker is registered by the DLL, like `healNonIdle`'s; edit `protoy.xml` and its XMB as
  described there. Without a unit type, in stock data the rule only matters for
  `ypTradingPostCapture` and `AIStart`, the two socket-typed protos without `ForceToGaia`.
- **Not covered:** placement that skips this check or runs it without a player's knowledge: the
  scenario editor, units created by triggers or random map scripts, and the in-place
  transformation of a unit into a socketed building.
- **AI:** an AI build plan that is given a socket takes the first socket of the right type,
  whatever its owner, and then fails its placement check on a refused one. An AI script that
  hands a build plan a socket should pick one that Gaia owns.
- **`log`:** one line per refused order, once per socket, owner, player and building in a game
  (at most 1000 per game): an AI build plan that picked a refused socket may retry on every
  update.
- **Log:** at startup `gaiaSocketsOnly: socketed buildings take only sockets owned by Gaia
  (multiplayer unverified)` or, with a unit type, `gaiaSocketsOnly: sockets of unittype X take a
  socketed building only while Gaia owns them (multiplayer unverified)` (`, refusals logged`
  before the parenthesis with `log`); with a unit type, when the data loads,
  `unit types: X -> <ID> …`; in a game, `hook reached: gaiaSocketsOnly (0x508CC1)` the first time
  a socketed building is checked exactly on a socket (any owner). With `log`:
  `gaiaSocketsOnly: refused TradingPost for player 1 on socket N (Proto), owned by player 2`.
- **Simulation:** yes. With a new marker it also adds a unit type.
- **Status:** implemented, not tested in game. In the test (2026-10-29) the stock interface itself
  refused a Trading Post on a player-owned socket: no foundation, and the message that it must be
  built near a native settlement or trade route. Scenario triggers cannot give build orders, so
  the order path that bypasses that check, WoL's case, was not driven. The code was reviewed
  adversarially and no defect was found.
- **New in this DLL:** not in UHC 1.10. WoL request #9 ([wol-requests.md](wol-requests.md)).

#### repairWallGlobal

**Added:** Tuesday 2026-11-03 10:43

![repairWallGlobal in game](media/repairWallGlobal.gif)

*In game:* three damaged walls (1200 / 1500) back to full a few seconds after one
`repairWallGlobal()`. [Full video (MP4)](media/repairWallGlobal.mp4).

```
repairWallGlobal
```

- **Effect:** adds the UI syscall `repairWallGlobal()`, which orders the repair of every wall of
  the local player (the units of abstract type `AbstractWall`), as the single-wall repair does.
  Put it in a command: `<command>repairWallGlobal</command>` in a `protounitcommands.xml` entry.
- **Your data:** the repair costs resources as stock repair does.
- **Log:** `repairWallGlobal: UI syscall repairWallGlobal() added`; the first call, `hook reached:
  repairWallGlobal (player P: N wall(s) ordered to repair)`.
- **Simulation:** sends one game command per wall: safe in multiplayer.
- **Status:** confirmed (2026-11-03, single player): three walls at 1200 / 1500 went back to 1500
  after one call; without the key the call did nothing. Video `repairWallGlobal.mp4`.

#### hcShipmentPointFallback

**Added:** Wednesday 2026-10-28 12:48

![hcShipmentPointFallback in game](media/hcShipmentPointFallback.gif)

*In game:* No Town Center on the map: the food crates of a home city card land beside player 1's Market, its first town center (made by [`civFirstTC`](#civfirsttc)), through `hcShipmentPointFallback FirstTC`. [Full video (MP4)](media/hcShipmentPointFallback.mp4).

```
hcShipmentPointFallback <Proto|FirstTC> [<Proto|FirstTC> ...]     1 to 64 entries
```

- **How stock behaves:** home city shipments arrive at the player's shipment point, a building
  (usually the Town Center). The game keeps that point while the building is alive and built.
  When it is destroyed or deleted, the game moves the point to the first alive, built building of
  the player among 10 fixed types, in this order: `TownCenter`, `Outpost`, `FortFrontier`,
  `WarHut`, `Blockhouse`, `NoblesHut`, any `AbstractAgraFort`, any `AbstractDaimyo`, `ypCastle`,
  `ypVillage`. If none of those is left, there is no shipment point (a `FreeHomeCityUnit` effect,
  for example, then creates nothing).
- **Effect:** after that stock list, the entries are tried in cfg order.
  - A **proto name:** the first alive building of the player of that proto that passes the same
    checks as stock becomes the point. When there are several, the stock unit query order
    decides, so every machine picks the same one.
  - **`FirstTC`** (any case): the player's first town center, the unit the placement rules call
    `FirstTC`. It becomes the point when it still belongs to the player and passes the same
    checks as stock (alive, built). A first town center that was converted or captured is
    skipped: the game never clears `FirstTC`, so it can belong to another player.
- **`FirstTC` needs `startingTC` or `civFirstTC`:** stock makes only a `TownCenter` a first town
  center, and the stock list already tries every `TownCenter` first, so without
  [`startingTC`](#startingtc) or [`civFirstTC`](#civfirsttc) the keyword finds nothing new (the
  key is still applied, with a warning in the log). With one of them, another building, for
  example the Market a civ starts with instead of a Town Center, is the player's `FirstTC` and
  receives the shipments. Without this key, a player whose buildings are none of the 10 stock
  types has no shipment point at all (read from the stock search; not tested in game).
- **Your mod:** list proto names exactly as in `protoy.xml`, and `FirstTC` where it should be
  tried, e.g. `hcShipmentPointFallback Barracks Stable ArtilleryDepot Market Church`, or for WoL
  `hcShipmentPointFallback FirstTC Barracks Market` (with `startingTC` or `civFirstTC`). A proto
  named `FirstTC` cannot be listed: the keyword wins.
- **The point then stays:** as in stock, once a building is the point it stays the point while
  it is alive and built, even if a Town Center is built later. The player can still move the flag.
- **Not affected:** the water shipment point and the consulate's drop point (`ypConsulate`) are
  chosen by other code.
- **Log:**
  - at startup, `hcShipmentPointFallback: N extra types after the stock list (multiplayer
    unverified)`; with `FirstTC` listed, `hcShipmentPointFallback: N extra types after the stock
    list, including each player's first town center (FirstTC) (multiplayer unverified)`;
  - at startup, with `FirstTC` but neither a `startingTC` nor a `civFirstTC` line:
    `hcShipmentPointFallback: FirstTC without startingTC: a first town center can only be a
    TownCenter, which the stock list already tries first`;
  - the first time in a run of the game that no stock fallback building is left,
    `hcShipmentPointFallback: <Name> -> proto <ID>` for each name (or `(unknown proto;
    skipped)`), `hcShipmentPointFallback: FirstTC -> each player's first town center (FirstTC)`
    for the keyword, and `hook reached: hcShipmentPointFallback (0x669E2E)`;
  - the first time a `FirstTC` entry is tried, `hook reached: hcShipmentPointFallback FirstTC
    (0x669E2E)`;
  - when a player's first town center is chosen, `hcShipmentPointFallback: player <N>'s shipment
    point -> unit <ID> (<Proto>), its first town center (FirstTC)`. The game also asks for the
    point while drawing the interface, so the line is written only when the chosen unit changes
    for that player.

  A move to another stock building, such as a second Town Center, logs nothing.
- **Simulation:** yes. Every choice reads only game state, so every machine with the same cfg
  picks the same building. Every player needs the same line (and the same `startingTC` or
  `civFirstTC` line).
- **Status:**
  - proto names: confirmed: after deleting the Town Center, the point moved to a listed building
    and shipments arrived there;
  - `FirstTC`: confirmed in single player (2026-10-29) with `civFirstTC`. In a skirmish where
    player 1's civ started with a Market instead of a Town Center, a card of 300 food sent with no
    Town Center on the map logged `hcShipmentPointFallback: player 1's shipment point -> unit 148
    (Market), its first town center (FirstTC)`; the point `[hc+18Ch]` read 148 in memory, and
    three `CrateofFood` landed beside the Market (food 200 → 500). It also ran with
    `noTrainNearEnemyTC 65 log` on. Not tested: `FirstTC` with `startingTC`, and a converted
    first town center (the owner check);
  - water shipment points were not tested (the key does not change them).
- **New in this DLL:** not in UHC 1.10.

### Techs and transforms

What happens when a tech activates or a unit changes proto.

| Key | What it does | WoL's DLL | WoL also needs | In-game status |
|---|---|---|---|---|
| [`techPrereqRecheck`](#techprereqrecheck) | Re-checks techs whose prerequisites count units (`<TypeCount>`) when units are created or die, not only at the player's next house, age-up or tech change. | **new** | Techs with `<TypeCount>` prerequisites in `techtreey` (stock data has none). | confirmed (single player) |
| [`transformUpdatesLOS`](#transformupdateslos) | A unit transformed in place (a `TransformUnit` tech effect, a revolution) takes the line of sight of its new proto. | **new** | Nothing. | confirmed (single player) |
| [`transformInventory`](#transforminventory) | A unit transformed in place (a `TransformUnit` tech effect, a revolution) takes its new proto's `InitialResource` when the two protos hold different resource types. | **new** | Nothing; with a new marker, that type on the target protos. | confirmed (single player) |

#### techPrereqRecheck

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Wednesday 2026-11-04 07:31

![techPrereqRecheck in WoL](media/techPrereqRecheck-wol.gif)

*In WoL, with `techPrereqRecheck log` (Ethiopians: the Explorer is Menelik II, selected so his HP
shows in the panel):* a trigger creates a Dock at 24 s. A test tech (`UHCTypeCountDock`: no research
time, prerequisite one living Dock, Explorer hit points x0.5; appended to the bed's techtree and
removed after) is the same pattern as WoL's `WOLEnableInfanteDeMarina`. It activates in the same
update (`prerequisites now met ... game time 24002 ms`): 400/400 becomes 200/200.
[Full video (MP4)](media/techPrereqRecheck-wol.mp4).

![techPrereqRecheck in WoL, key off](media/techPrereqRecheck-wol-control.gif)

*In WoL, key off (the same scene):* the Dock stands but nothing re-checks the tech, so the Explorer
keeps 400 HP (stock waits for a tech change or a house).
[Full video (MP4)](media/techPrereqRecheck-wol-control.mp4).

```
techPrereqRecheck [N] [full] [log]       N: check each player every N world updates (default 1)
```

- **How stock behaves:** the game evaluates a tech's `<Prereqs>` only when the player's tech tree
  is marked for a re-check: when one of the player's techs changes status (researched, activated,
  made obtainable, a shipment), at an age-up, at a home city level-up, and when the player's
  population cap changes (a house is built or destroyed). Creating or killing any other unit never
  does. A `<TypeCount>` prerequisite counts the player's units, so it is noticed late: a tech with
  `<TypeCount unit='Dock' count='1' state='noneState aliveState' operator='gte'/>` waits for the
  player's next house after the first dock is built. Stock data has no `<TypeCount>`; WoL has 12
  in 9 techs.
- **Effect:** on every world update (or every N), for each tech with a `<TypeCount>`
  prerequisite, the DLL evaluates the tech's prerequisites for each player exactly as the stock
  re-check does, and compares the result with the one the game cached. On a difference it starts
  the stock re-check at once. What follows is the stock re-check, the same as after a house:
  - a tech with no research time (`<ResearchPoints>0</ResearchPoints>`) whose prerequisites are now
    met activates;
  - a `Volatile` tech activates or deactivates;
  - the AI's tech list and the UI are updated.

  Techs without `<TypeCount>` are not checked by the DLL, but the stock re-check it starts
  re-evaluates them too.
- **`N`:** each player is checked every N world updates, offset by its player number so the
  players' checks are spread out. A larger N costs less and reacts later.
- **`full`:** for measurements only. It starts the stock re-check of every tech for each player
  every N updates, whether anything changed or not. The stock re-check walks every tech, so use a
  large N (e.g. 60) on a big techtree.
- **Writing `<TypeCount>`** (from the stock XML handler, static reading):
  - all four attributes are required: `unit`, `count`, `operator`, `state`. Without one, the game
    drops the prerequisite with an error;
  - `state` is a list of words. It starts as "any state"; `noneState` clears it, then
    `aliveState`, `deadState` and `buildingState` add those states. A lone `state='aliveState'`
    still means any state: write `state='noneState aliveState'`;
  - `operator` is read as substrings `lt`, `e` and `gt`, so `gte` means "greater or equal";
  - `count` is read as an integer.

  ```xml
  <Tech name ='MyDockBonus' type ='Normal'>
      <DBID>…</DBID>
      <ResearchPoints>0.0000</ResearchPoints>
      <Status>OBTAINABLE</Status>
      <Flag>Shadow</Flag>
      <Prereqs>
          <TypeCount unit ='Dock' count ='1' state ='noneState aliveState' operator ='gte'></TypeCount></Prereqs>
      <Effects>…</Effects>
  </Tech>
  ```
- **`log`:** one line per re-check started, and a summary per game minute (checks, evaluations,
  re-checks started, time spent in the checks). Use it to check your data or measure the cost,
  not in a release.
- **Log:**
  - at startup, `techPrereqRecheck: techs with TypeCount prerequisites are re-checked every N
    world update(s); a change starts the stock re-check (multiplayer unverified)` (with `log`,
    `…; every re-check and a summary every game minute are logged (multiplayer unverified)`; with
    `full`, `techPrereqRecheck: full: the stock re-check of every tech runs every N world
    update(s) for each player (multiplayer unverified)`);
  - in a game, `hook reached: techPrereqRecheck (0x491A18)`;
  - once per data load, `techPrereqRecheck: K tech(s) of T have TypeCount prerequisites (P in
    all)` and one `techPrereqRecheck:   tech <ID> (<Name>), n TypeCount prerequisite(s)` line per
    tech, up to 100. With none: `…; nothing to re-check`;
  - the first re-check is always logged: `techPrereqRecheck: player P, tech <ID> (<Name>):
    prerequisites now met; stock re-check at step S, game time T ms (add log to see every
    re-check)` (or `no longer met`). With `log`, every re-check is, and every game minute
    `techPrereqRecheck: game minute M: … check(s), … evaluation(s), … re-check(s) started, … full
    pass(es) requested, … us in checks`;
  - a bad argument: `techPrereqRecheck: unexpected argument X (expected: [N] [full] [log], N a whole
    number of world updates from 1 to 1000000); feature not applied`.
- **Limits:**
  - the counts are the ones the player's knowledge base keeps, the counts XS `kbUnitCount` reads;
  - only `<TypeCount>` prerequisites are watched; `<Culture>` and `<Civilization>` prerequisites
    after a civilization change are not;
  - a tech that is not relevant to the player yet (unobtainable and not named by its civ's techs)
    has no status entry. Neither stock nor the DLL evaluates it until a status change creates one.
- **Simulation:** yes: techs activate earlier than in stock. Every player needs the same setting,
  N included. The check reads only game state and the world's step count.
- **Status:** confirmed in single player (2026-10-29). Two test techs with `<TypeCount>`
  prerequisites and no research time, one met when the player has a live Settler and one when he
  has no live Musketeer, activated in the same world update as the Settler's creation (20.0 s) and
  the Musketeer's death (32.0 s). With the key off they waited for an unrelated tech change at
  70 s. With these 2 techs, the checks cost about 4 ms per game minute (the `log` summary).
- **New in this DLL:** not in UHC 1.10. WoL request #6 ([wol-requests.md](wol-requests.md)).

#### transformUpdatesLOS

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Wednesday 2026-11-04 08:11

![transformUpdatesLOS in WoL](media/transformUpdatesLOS-wol.gif)

*In WoL, with `transformUpdatesLOS log` (Romanians, the units selected):* WoL's
`ShiftingCalarasToVanator` turns four Calarashi (LOS 15) into Vanatori (LOS 22) at 26 s; they take
LOS 22 at once (`LOS 15 -> 22`, the panel and the lit area grow).
[Full video (MP4)](media/transformUpdatesLOS-wol.mp4).

![transformUpdatesLOS in WoL, key off](media/transformUpdatesLOS-wol-control.gif)

*In WoL, key off (the same scene):* the Vanatori keep the Calarashi's LOS 15 (the panel shows 15)
and the lit area does not change. Some WoL cards work around the bug in their data:
`WOLHCItaliaIrredenta` (Pikeman 12 to WOLAlpino 28) also assigns LOS 28 to the Alpino, so it is
right with or without the key; 45 of WoL's transforms have no such line.
[Full video (MP4)](media/transformUpdatesLOS-wol-control.mp4).

```
transformUpdatesLOS [log]
```

- **How stock behaves:** each unit has its own line of sight. The game copies it from the proto's
  `<LOS>` when the unit is created, when a building is finished, and when a tech changes that
  proto's LOS. A tech effect `<Effect type ='TransformUnit' fromprotoid ='A' toprotoid ='B'>` and a
  revolution change living units into another proto in place: the unit keeps its ID, HP ratio
  and orders, but also keeps A's LOS. Stock TAD has four such pairs with different LOS values:
  `HCXPTirailleurs` (Crossbowman 20 → Skirmisher 24), `HCXPEveningStar` (xpAxeRider 12 →
  xpRifleRider 15), `YPHCBannerReforms` (ypChuKoNu 20 → ypArquebusier 24) and
  `YPHCSepoyRebellion` (ypSettlerIndian 14 → ypSepoy 16). A revolution turns Settlers (14) into
  xpColonialMilitia (18). The old LOS stays until something resets it, for example a later tech
  that changes B's LOS, so the bug looks random.
- **Effect:** the transformed unit takes the LOS of its player's copy of B, so LOS techs that
  player already has for B count. The fog of war around it and everything else that reads its LOS
  use the new value from the moment it changes.
- **Units that keep their own LOS:** a unit whose LOS is not its old proto's at the moment of the
  transform keeps it. Stock gives some units a LOS of their own on purpose: a foundation under
  construction and a knocked-out hero (6). One case is kept by mistake: a unit converted from
  another player keeps the LOS of its former owner's copy of the proto (stock does not update it
  on conversion), so if the two players' LOS techs for that proto differ, a later transform leaves
  that unit's LOS alone too. With `log` these units show up as `keeps its own LOS`.
- **Not affected (already right in stock):** transforms that replace the unit with a new unit,
  such as walls into gates, and the trigger effect "Change Unit Type" (`trUnitChangeProtoUnit`),
  which takes another path: in game the unit kept its ID and already had the new proto's LOS.
- **Your mod:** nothing. The key covers every in-place transform; there is no per-unit marker.
- **`log`:** one line per unit transformed in place. A tech that transforms many units writes one
  line for each.
- **Log:** at startup `transformUpdatesLOS: units transformed in place (TransformUnit, revolution)
  take their new proto's LOS (multiplayer unverified)` (with `log`: `…LOS, every transform logged
  (multiplayer unverified)`); in a game, `hook reached: transformUpdatesLOS (0x9C763F)` the first
  time a unit is transformed in place. With `log`: `transformUpdatesLOS: unit N (Crossbowman ->
  Skirmisher) LOS 20 -> 24`, or `transformUpdatesLOS: unit N (A -> B) keeps its own LOS 6 (its
  proto's is 18)`.
- **Simulation:** yes: line of sight decides what a player sees and what units can target.
- **Status:** confirmed in single player (2026-10-29). Four Crossbowmen turned into Skirmishers by
  `HCXPTirailleurs` got LOS 24, the Skirmisher's; with the key off they kept 20 (the bug).
  Pikemen turned into Rodeleros logged `12 -> 12`. "Change Unit Type" never reached the hook and
  was already right in stock. Revolutions were not tested.
- **New in this DLL:** not in UHC 1.10. WoL request #10 ([wol-requests.md](wol-requests.md)).

#### transformInventory

**Added:** Thursday 2026-10-29 10:35 · **Filmed in WoL:** Wednesday 2026-11-04 08:11

![transformInventory in WoL](media/transformInventory-wol.gif)

*In WoL, with `transformInventory log` (Ethiopians, the units selected so the panel shows the
crate):* WoL's card `HCCardDogTaxWar` turns two `PetWolf` into `CrateofCoin` at 24 s. Each crate
gets the coin crate's inventory (`inventory created: none -> {0: 100}`), and the panel shows
`Moneda: 100.0`. [Full video (MP4)](media/transformInventory-wol.mp4).

![transformInventory in WoL, key off](media/transformInventory-wol-control.gif)

*In WoL, key off (the same scene):* the crates have no inventory: the panel shows no coin line, and
they can never be gathered. [Full video (MP4)](media/transformInventory-wol-control.mp4).

```
transformInventory [all] [scale] [<UnitType>] [log]
```

- **How stock behaves:** a unit that holds resources (a crate, a herdable, a mine, a tree) has
  its own resource inventory. The game fills it from the proto's `<InitialResource>` when the unit
  is created, and gatherers take from that inventory, not from the proto. A tech effect
  `<Effect type ='TransformUnit' fromprotoid ='A' toprotoid ='B'>` and a revolution change living
  units into another proto in place, but never touch the inventory: the unit keeps A's resource
  types and amounts, or has none at all. Stock TAD never hits this (none of its 7 `TransformUnit`
  effects involves an inventory). WoL has 64 such effects (static scan of its techtree):
  - `CrateofCoin` → `CrateofXP` (`WOLNatAssyrianTWO`): the "XP crate" still holds 100 gold;
  - `MerinoRam` → `Cow` (`WOLHCBlueBreed`): the cow holds the ram's gold;
  - a pet or a priest → a crate (`HCCardDogTaxWar`, `WOLHCOrganizedSecularism`): the crate has no
    inventory, so it can never be gathered and never empties;
  - a later conversion or capture of such a unit makes it worse: the owner change rescales each
    resource by the proto's `InitialResource` and zeroes every type the proto does not list. A
    gold-holding XP crate that changes owner ends up with nothing.
- **Effect:** when the old and new protos list different resource types in `<InitialResource>`,
  the unit gets the new proto's `InitialResource` (its player's copy, so that player's
  `InventoryAmount` techs count), as if it had just been created. A unit that had no inventory
  gets one. A unit whose two protos list the same types keeps its inventory, as in stock: a
  fattened goat turned into a cow keeps its food.
- **`all`:** also rebuilds units whose protos list the same types (a `ypGoatFat` with 300 food
  turned into a `Cow` gets the cow's 50), and removes the inventory of a unit whose new proto has
  no resources at all (as the trigger "Change Unit Type" does). Without `all`, such a unit keeps
  its old inventory, as in stock.
- **`scale`:** the new amounts are scaled by the fraction of the old `InitialResource` the unit
  still held: a coin crate half gathered becomes half an XP crate. A unit that held more than its
  old `InitialResource` (fattened) gets the full new amounts.
- **`<UnitType>`:** only transforms into protos of that type are changed; any other transform
  behaves as in stock. A new name is registered as a marker unit type (like `healNonIdle`'s); a
  stock type or a proto name works too (`transformInventory AbstractResourceCrate`). Without a
  type, every in-place transform is covered.
- **Your mod:** nothing, unless you use a marker. The key covers every `TransformUnit` effect and
  revolution. The trigger effect "Change Unit Type" and `uiTransformSelectedUnit` (WoL's
  `*Maturing`) already give the new proto's resources in stock and are not changed.
- **Gatherers:** a unit already gathering a target whose resource type changes keeps gathering the
  old type; that amount is now 0, so it stops at its next gather tick and must be re-tasked. In
  stock it would keep collecting the old resource.
- **`log`:** one line per unit transformed in place that holds or receives resources. A tech that
  transforms many units writes one line for each.
- **Log:** at startup `transformInventory: units transformed in place (TransformUnit, revolution)
  take their new proto's InitialResource when the resource types differ (multiplayer
  unverified)`. With a type the line reads `…(TransformUnit, revolution) into protos of unittype
  X take…`; with `all`, `…InitialResource always, and lose their inventory when it has none…`;
  `scale` adds `, scaled by the fraction left`, and `log` `, every transform logged`. With a type,
  when the data loads, `unit types: X -> <ID> …`. In a game, `hook reached: transformInventory
  (0x9C7625)` the first time any unit is transformed in place. With `log`:
  - `transformInventory: unit N (Sheep -> CrateofCoin) inventory rebuilt: {2: 53.6} -> {0: 100}`;
  - `transformInventory: unit N (Musketeer -> CrateofXP) inventory created: none -> {5: 100}`;
  - `transformInventory: unit N (ypGoatFat -> Cow) keeps its inventory {2: 300} (same resource
    types)`;
  - `transformInventory: unit N (ypCrateofCoin1 -> Pikeman) keeps its inventory {0: 100} (the new
    proto has no resources; "all" frees it)`;
  - with `all`: `transformInventory: unit N (A -> B) inventory freed: {0: 100} -> none`;
  - with `scale`: `… inventory rebuilt: {1: 80} -> {2: 80} (scaled by 0.8)`;
  - `transformInventory: unit N (A -> B) got no inventory (pool exhausted)`, if the engine's
    inventory pool is empty (not seen).

  The numbers before the colons are resource IDs in the order the exe registers the resource names
  (0x5381E0): Gold 0, Wood 1, Food 2, Fame 3, SkillPoints 4, XP 5, Ships 6, Trade 7. That these are
  also the inventory's indices was checked in game for Food: a crate logged `{2: 100}` showed
  100 food in the game's panel. For the other resources it is an inference.
- **Simulation:** yes. Inventories decide what and how much gatherers collect, what the AI sees,
  and when a `DieAtZeroResources` unit dies. Every player needs the same DLL and the same line;
  `scale` divides two game values in the DLL, so every player also needs the same build.
- **Limits:** units that a saved game already holds with a mismatched inventory are not fixed when
  it loads; only their next transform fixes them. Callers of the in-place transform other than
  `TransformUnit` and the revolution (construction objects and a few internal ones) are covered
  too; their stock data was not surveyed.
- **Status:** confirmed in single player (2026-10-29), with a test tech `UHCInvTransformTest` of
  six `TransformUnit` effects:
  - a Sheep holding 53.6 food became a `CrateofCoin` with 100 gold;
  - a `CrateofWood` (100 wood) became a `CrateofFood` with 100 food, which the game's panel then
    showed (`Alim.: 100`);
  - a Musketeer (no inventory) became a `CrateofXP` with a new inventory of 100 XP;
  - a `ypGoatFat` (300 food) became a `Cow` and kept its food (same resource types);
  - a `ypCrateofCoin1` (100 gold) became a Pikeman and kept its inventory, without `all` (the log
    says `all` frees it);
  - Crossbowman → Skirmisher: no inventory on either side, nothing logged.

  The stock behavior (the inventory is never rebuilt) comes from static analysis; no run with the
  key off was made. `all`, `scale`, a marker, revolutions and a conversion after a transform were
  not tested.
- **New in this DLL:** not in UHC 1.10. WoL request #4 ([wol-requests.md](wol-requests.md)).

### Interface

What the panels and the fog of war show.

| Key | What it does | WoL's DLL | WoL also needs | In-game status |
|---|---|---|---|---|
| [`abilitySlots`](#abilityslots) | Lets the command panel show up to N abilities per unit instead of 6. | **new** | Units with more than 6 abilities in `abilities.xml`. | confirmed (single player, UI) |
| [`wonderPanelSkipAuras`](#wonderpanelskipauras) | The wonder power panel shows a wonder's first available ability that is not a passive aura, instead of only its first ability. | **new** | The power listed after the aura in `abilities.xml`, on an `AbstractWonder` with an `Abilities` command. | confirmed (single player, UI) |
| [`explorerUnits`](#explorerunits) | Listed protos get a hero's name and knockout message. | **in `wol.cfg`** | The string IDs. | confirmed for names |
| [`noCorpseDopples`](#nocorpsedopples) | A dead unit of a marked type (a hunt's carcass) leaves no frozen copy in the fog of war. Live units are still remembered. | **new** | `<Flag>Doppled</Flag>` on those protos, and the unit type in the cfg (`Huntable` needs no data change). | confirmed (single player) |

#### abilitySlots

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Wednesday 2026-11-04 08:11

![abilitySlots in WoL](media/abilitySlots-wol.gif)

*In WoL, with `abilitySlots 8 log` (Ethiopians; close-up of the selected Explorer's command
panel):* WoL's Explorer lists 8 abilities in `abilities.xml`. With `Industrialize` active, the
Habilidades row shows Regen, Sharpshooter and Crackshot. At 24 s `WOLAbilityHeal` turns on and
ability 7 (PowerHeal) gets a button; at 30 s `WOLHCMachiavellianism` turns on and ability 8
(Counterintelligence) gets one too (`shows ability 7 of its list ... past the stock 6`).
[Full video (MP4)](media/abilitySlots-wol.mp4).

![abilitySlots in WoL, key off](media/abilitySlots-wol-control.gif)

*In WoL, key off (the same scene):* the panel asks for the first 6 abilities only, so the two WoL
powers never get a button although their techs are active.
[Full video (MP4)](media/abilitySlots-wol-control.mp4).

```
abilitySlots <N> [log]      N from 6 (stock) to 36
```

- **How stock behaves:** a unit's abilities (powers such as Sharpshooter or Crackshot) are listed
  per proto in `data\abilities\abilities.xml`; a proto shows them on the Abilities page of its
  command panel through `<Command page ='11' column ='0'>Abilities</Command>`. The panel asks for
  the first 6 abilities of the unit's list, and only those:
  - an ability whose `<tech>` is not active, or whose `<age>` is not the player's age, gets no
    button, but it still counts as one of the 6;
  - an ability with `<NeverShowInGrid>` does not count;
  - an ability with `<AlwaysDisabledInGrid>` counts and is shown greyed.

  So a 7th ability never gets a button, even when its tech is active and the first 6 are all
  disabled.
- **Effect:** the panel asks for the first N abilities of the list. A unit with 6 abilities or
  fewer looks exactly as before. Enabled abilities past the 6th get buttons; a page with more than
  6 buttons wraps to the next row, as Train and Tech pages already do. The panel still has 6 rows
  of 6 buttons: whatever does not fit is not drawn, as in stock.
- **Your mod:** use N at least the length of the longest ability list in your `abilities.xml`
  (WoL's explorer has 8). A larger N costs a little: each refresh of the panel scans the whole
  ability list once per extra slot.
- **Existing data:** abilities that were silently dropped at position 7 or later now appear. In
  WoL, the 7th ability of `ypMonkJapanese`, `ypMonkJapanese2` and `ypMonkChinese` is an
  `AlwaysDisabledInGrid` aura (scoping, not tested): with the key it shows as a greyed button once
  its tech is active.
- **`log`:** one line per unit and ability the first time the panel shows a button past the 6th
  (once per unit ID and ability record in a game).
- **Log:** at startup `abilitySlots: the command panel asks for N abilities per unit (stock 6)`
  (with `log`: `…(stock 6), every button past the 6th logged once per unit`); without `log` the key
  writes no `hook reached` line, because it only changes one number. With `log`, in a game,
  `hook reached: abilitySlots log (0x696C70)` the first time any selected unit gets an ability
  button, and `abilitySlots: unit N (Explorer) shows ability 7 of its list (record R, power P,
  enabled), past the stock 6`: `record` is the ability's position in `abilities.xml`, counted from
  0 over the whole file; `greyed` instead of `enabled` means an `AlwaysDisabledInGrid` or
  recharging ability. A bad value: `abilitySlots: expected an integer from 6 to 36, then
  optionally log; feature not applied`.
- **Simulation:** no. Only the local command panel changes; a click sends the same
  `ability(record, unit)` command as a stock button. Players may set it differently (static
  reading; not tested in multiplayer).
- **Limits:** the second row of a wrapped Abilities page may have no page label, or a stale one
  (not checked). The wonder power panel is separate: see `wonderPanelSkipAuras`.
- **Status:** confirmed in single player (2026-10-29), in the interface. A test Explorer with 8
  abilities, the first 6 locked by techs: with `abilitySlots 8` the 7th showed a button at once and
  the 8th when its tech was activated; with the key off, no ability button.
- **New in this DLL:** not in UHC 1.10. WoL request #16 ([wol-requests.md](wol-requests.md)).

#### wonderPanelSkipAuras

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Wednesday 2026-11-04 08:11

![wonderPanelSkipAuras in WoL](media/wonderPanelSkipAuras-wol.gif)

*In WoL, with `wonderPanelSkipAuras log` (two Korean wonders; close-up of the bottom left):* for the
test, the bed's `abilities.xml` lists the passive `ypPowerShrineAura` before the Pyongyang Gate's
`PowerRighteousArmy` (removed after). The wonder power panel (above the resource counters) shows
the Righteous Army button: the DLL skips the aura (`shows its ability n=1 in the wonder power
panel`). [Full video (MP4)](media/wonderPanelSkipAuras-wol.mp4).

![wonderPanelSkipAuras in WoL, key off](media/wonderPanelSkipAuras-wol-control.gif)

*In WoL, key off (the same data):* stock asks only for the Gate's first ability, the aura, and adds
no button for it, so the panel shows the Puyong Hall's Whirlpool instead. In these WoL runs the
panel held one button at a time: with WoL's own data it shows the Gate's power and not the Puyong
Hall's. [Full video (MP4)](media/wonderPanelSkipAuras-wol-control.mp4).

```
wonderPanelSkipAuras [log]
```

- **How stock behaves:** the Asian wonders' global powers sit in the wonder power panel, a row of
  up to five buttons that is always on screen. For each wonder of the local player with
  `<Command page='11' column='1'>Abilities</Command>`, the panel asks for the wonder's **first**
  ability in `abilities.xml` and nothing else. It adds no button when that ability is
  `<alwaysdisabledingrid>true</alwaysdisabledingrid>`, as every stock passive aura is
  (`ypPowerShrineAura`, …), or is not available yet (its `<tech>` is not active, or its `<age>` is
  not the player's). So a power listed after an aura (for example a power added to the Toshogu
  Shrine) never gets a panel button, although the selected wonder's command panel shows both
  abilities.
- **Effect:** the panel tries the wonder's abilities in file order (up to 8) and shows the first
  one that is available and is not `alwaysdisabledingrid`. A wonder whose first ability already
  qualifies is shown exactly as in stock, so with stock data nothing changes: every stock wonder
  has a single ability. The button does what a command panel button does
  (`ability(<record>, <unit>, true)`).
- **Your data:** the wonder's proto must be an `AbstractWonder` with
  `<Command page='11' column='1'>Abilities</Command>`. In `abilities.xml`, list the power after the
  aura under the proto's lowercase name:

  ```xml
  <ypwjtoshogushrine2>
    <ability>ypPowerShrineAura
      <alwaysdisabledingrid>true</alwaysdisabledingrid>
    </ability>
    <ability>ypPowerInformers<rof>300</rof><castonself>true</castonself></ability>
  </ypwjtoshogushrine2>
  ```

  The stock file is inside `Data3.bar`: extract it with `tools\bar.py`, convert it with
  `xmbedit.py to-xml`, and ship the edited `data\abilities\abilities.xml` with an
  `abilities.xml.xmb` compiled from it ([section 6](#6-editing-the-game-data)). **Every child of a
  proto element must be `<ability>`:** any other tag makes the whole file fail to load, and then no
  unit has abilities (static reading).
- **Limits:** one panel button per `Abilities` command, so a wonder still shows a single global
  power; only `AbstractWonder` units appear in the panel; only the first 8 abilities of a wonder
  are tried.
- **Without the key** (not tested): listing the power *before* the aura, or marking the aura
  `<nevershowingrid>true</nevershowingrid>` (which also hides its icon from the command panel),
  should give the power its panel button in stock.
- **`log`:** one line the first time in a game the panel shows each ability that stock would not
  have shown (an ability past the first).
- **Log:** at startup `wonderPanelSkipAuras: the wonder power panel shows a wonder's first
  available ability that is not a passive aura (AlwaysDisabledInGrid) (UI only)` (with `log`:
  `…(AlwaysDisabledInGrid), each ability it shows past the first logged once (UI only)`); in a
  game, `hook reached: wonderPanelSkipAuras (0x69EE5D)` once the panel looks at a wonder with an
  `Abilities` command. With `log`: `wonderPanelSkipAuras: unit N (Proto) shows its ability n=K in
  the wonder power panel (record R, power P)`, where K counts from 0.
- **Simulation:** no. Only what the panel shows changes; the button sends the same command a
  command panel button sends. Players may set it differently (not tested in multiplayer).
- **Status:** confirmed in single player (2026-10-29), in the interface: with a test ability added
  after the Toshogu Shrine's aura, the panel showed 2 buttons; with the key off, 1.
- **New in this DLL:** not in UHC 1.10. WoL request #20 ([wol-requests.md](wol-requests.md)).

#### explorerUnits

**Added:** Monday 2026-11-02 21:10

```
explorerUnits Proto Type StringID [Proto Type StringID ...]
```

- **Effect:** listed protos are heroes for two things: their name and their knockout message.
  `Type` picks the name: 1 the home city's explorer name, 0 the stock path for other units, any
  other value the first of the home city's hero names (as the second monk of a two-hero civ).
  `StringID` is the message shown when the unit is knocked out.
- **Log:** `explorerUnits: N hero proto(s)`; when `protoy.xml` is read, `explorerUnits: K of N
  protos found in the data` and each unknown name; `hook reached: explorerUnits hero name
  (0x6A012A)`, `... knockout message (0x50B01F)`; `explorerUnits: needs triples ...` or
  `bad triple ...` (not applied).
- **Simulation:** no: names and messages.
- **Status:** confirmed for names (2026-11-02, single player): a civ's two monks listed with
  Type 1 and Type 2 were named after the explorer and the first hero name of the home city; the
  knockout message was not driven. Video `asianCivs-koreans.mp4` (the two monks, then the wonder
  list).

#### noCorpseDopples

**Added:** Thursday 2026-10-29 06:39 · **Filmed in WoL:** Wednesday 2026-11-04 08:11

![noCorpseDopples in WoL](media/noCorpseDopples-wol.gif)

*In WoL, with `noCorpseDopples Deer log` (WoL's own data: its Deer and Bison are `Doppled`):* three
Rangers watch two herds; at 18 s three deer and three bison are killed, and at 26 s the Rangers walk
away, so the spot falls into the fog. The dead deer leave no copy (`left player 1's view dead; no
dopple`); the dead bison, not named by the rule, stay in the fog as frozen carcasses.
[Full video (MP4)](media/noCorpseDopples-wol.mp4).

![noCorpseDopples in WoL, key off](media/noCorpseDopples-wol-control.gif)

*In WoL, key off (the same scene):* every carcass stays in the fog in its death pose, deer and
bison alike. [Full video (MP4)](media/noCorpseDopples-wol-control.mp4).

```
noCorpseDopples [<UnitType>] [log]      default AbstractNoCorpseDopple
```

- **How stock behaves:** a *dopple* is the copy of a unit that a player keeps seeing in the fog of
  war after the unit left his view. Only protos with `<Flag>Doppled</Flag>` get one (stock:
  buildings, mines, trees, …). The game makes it when the unit leaves the player's view, for him
  and for the players who share his vision, and removes it only when the player sees the unit or
  the spot again. It never asks whether the unit is alive. Stock hunts use
  `VisibleUnderFogOnlyAfterSeen` instead. A mod that makes its hunts `Doppled`, so that a herd
  stays where it was last seen (WoL does this for most of its hunts), also gets corpse dopples: a
  carcass that still holds food when it leaves a player's view stays in his fog in its death pose,
  long after it was eaten or abandoned, until he looks at the spot again.
- **Effect:** a unit whose proto is of `<UnitType>` and that is not alive (0 hitpoints, killed)
  gets no dopple when it leaves a player's view, for any player: it simply disappears into the
  fog. A live unit of that type is still doppled. A carcass that is fully gathered was never
  doppled: the game takes it out of the world before it decays.
- **Choosing the units:** `noCorpseDopples Huntable` covers every hunt with no data change
  (`Huntable` is a built-in type). A proto name works too (`noCorpseDopples Deer`). With the
  default marker, or any new name, add it to the protos and edit `protoy.xml` and its XMB as for
  `healNonIdle`. Units without `<Flag>Doppled</Flag>` have no dopples anyway.
- **Do not mark livestock** or other `DoppleOnlyWhenDead` protos: that flag exists to leave a
  corpse dopple, and the key removes it.
- **`log`:** one line per dopple it skips, up to 1000 lines per session.
- **Log:** at startup `noCorpseDopples: dead units of unittype X leave no dopple in the fog of war
  (multiplayer unverified)` (with `log`: `…of war, every skipped dopple logged (multiplayer
  unverified)`); when the data loads, `unit types: X -> <ID> …` (`already defined` for `Huntable`
  or a proto name); in a game, `hook reached: noCorpseDopples (0x49534D)` the first time any
  doppled unit (a building, a tree, …) leaves a player's view. With `log`: `noCorpseDopples: unit N
  (Deer, hp 0.0) left player 1's view dead; no dopple`.
- **Limits:**
  - the dopple of a **live** animal that is then killed and eaten out of the player's sight still
    shows the live animal until he looks at the spot again. Removing dopples when a unit leaves
    the world would fix that; it is not implemented;
  - a saved game made without the key keeps the corpse dopples it already had;
  - `MutateDopples` protos (none in stock or WoL data) refresh their dopples through another path
    that the key does not cover.
- **Simulation:** probably not, but unverified. Dopples belong to the game state, which every
  machine keeps the same way; the key only reads that state (unit types, hitpoints). Give every
  player the same setting. With a new marker it also adds a unit type.
- **Status:** confirmed in single player (2026-10-29), with `noCorpseDopples Deer log` and Deer and
  Bison given `<Flag>Doppled</Flag>` in the test data: after leaving them, player 1 kept 6 dopples
  (3 dead Bison, 3 live Deer) and none for the 3 dead Deer. With the key off, 9 (the 3 dead Deer
  too).
- **New in this DLL:** not in UHC 1.10. WoL request #18 ([wol-requests.md](wol-requests.md)).

## 6. Editing the game data

Work on a copy of the WoL folder.

- **Most of WoL's data is plain XML, so an edit needs no tool.** Unlike the stock game, WoL ships no
  compiled twin of these files: edit the file, then restart the game.
  - In `data\`: `protoy.xml`, `techtreey.xml`, `stringtabley.xml`, `civs.xml`, `DefaultKeyMapY.xml`,
    `homecitylevels.xml`, the interface files such as `uiunitselectionmin.xml`.
  - In its folders: `data\abilities\abilities.xml`, `data\abilities\powers.xml`,
    `data\placementrules\colonies.xml`, and the 622 `data\tactics\*.tactics`.
- **Everything else is in archives:** `data\Data.bar`, `Data2.bar`, `Data3.bar`, and `art\Art*.bar` for
  textures. A loose file overrides the archive's copy.
- **XML or XMB: the newer one wins.** When a data file exists both as XML and as compiled `.xmb`, the
  game loads the XMB unless the XML file is newer. With only one of the two, it uses that one. WoL's
  only `.XMB` files in `data\` are `randomnames.xml.XMB` and `unithelpstrings.xml.XMB`: if you edit
  one of those two XML files, delete its XMB or compile it again. The rule was read from the game's
  loader (FUN_00599A7D, see [engine-symbols.md](engine-symbols.md), "Damage and poison").
- **A file that is only in an archive:**
  1. extract it;
  2. if it is compiled, convert it to XML with `xmbedit.py to-xml`;
  3. edit the XML;
  4. save it loose in `data\` under the stored name without `.xmb`.
- **List and extract archive files** with `tools\bar.py`. `--extract` recreates the stored path below
  the folder you give:

  ```
  python -I tools\bar.py "<WoL>\data\Data3.bar" tactics/explorer
  python -I tools\bar.py "<WoL>\data\Data3.bar" homecitylevels --extract work
  ```

- **Read and write XMB files** with `tools\xmbedit.py`:

  ```
  python -I tools\xmbedit.py to-xml work\Data\homecitylevels.xml.xmb homecitylevels.xml
  python -I tools\xmbedit.py from-xml "<WoL>\data\randomnames.xml" "<WoL>\data\randomnames.xml.XMB" --compress
  ```

- **A marker unit type** is one line inside the unit in `protoy.xml`, among its other unit types:
  `<UnitType>AbstractHealNonIdle</UnitType>`. A name the game does not know yet is dropped unless the
  key that uses it registers it (each section says so), or it is in
  `data\uhc\customabstracttypes.xml`, as with WoL's 47 own types.
- **Once the game has loaded,** `python -I tools\re\inspect_unittypes.py AbstractHealNonIdle` shows which
  protos carry a type.

### Tactics files

A proto's `<Tactics>` file (`data\tactics\<name>.tactics`) lists its actions and its tactics (`Volley`,
`Melee`, `Normal`, …). WoL ships all of them as plain XML, so the layout of their `<tactic>` lines
matters:

- **Keep the Windows (CRLF) line endings.** All 622 of WoL's files have them.
- **Why:** with Unix (LF) line endings, which many editors and scripts write, a line break after a
  tactic name stays part of the name. When the game compiles the AI scripts, it then defines the XS
  constant `cTacticNormal` twice. The compile fails, and no AI player does anything in any game after
  that file was loaded. The game only shows `XS: Error 0003: could not compile file
  'aiLoaderStandard.xs'.`; the cause, `Error 0014: 'cTacticNormal' is already defined.`, shows in
  `python -I tools\re\trace_xs.py <log file>` ([tools/README.md](../tools/README.md)).
- **A safe layout:** put the name and its first child on one line:
  `<tactic>Normal<action priority="100">Attaching</action></tactic>`. A compiled `.tactics.xmb` is also
  safe.
- **Tested** on the stock tactics files: the one-line layout, CRLF line endings and the compiled file
  worked in game; the LF layout with the name alone on its line broke the AI. Restart the game after
  fixing a file.
- **Extra action tags:** with [`spreadAnyAccuracy`](#spreadanyaccuracy), an `<action>` also reads
  `<maxspread>` and `<spreadfactor>`. Keep its `<name>` as the first child, as WoL's files do.

More about the tools: [tools/README.md](../tools/README.md).

## 7. Multiplayer, saved games and replays

Nothing in this guide has been tested in multiplayer or in replays. What follows comes from reading
the code. Saved games were tested only where a section says so.

- **Every player needs the same DLL, the same `wol.cfg` and the same data.** That is how WoL ships
  already, and it is the safe rule for every key.
- **Keys that may differ between players,** because they change only what the local player sees or
  which keys work: `ignoreRegistryPath`, `bufferedFileReads`, `multipleInstances`, `compatMode`,
  `selectionLimit`, `customHotkeyContexts`, `twoScoutCivs`, `bigButtonCivs`, `noBigButtonBlds`,
  `customRevolutionBanners`, `overhealHitpointBars`, `showGatherRate`, `abilitySlots`,
  `wonderPanelSkipAuras`, `explorerUnits`, `dodgeSoundSet` and `criticalSoundSet`.
- **Everything else changes the game state,** or a list every machine must agree on. A difference
  between players can desynchronize the game. Each section has a **Simulation** line.
- **A key that adds a unit type** changes the unit type count: `healNonIdle`, `dodgeAnyUnit`,
  `removeFameRestriction`, and any key with a marker name the game does not know yet. Load saved games
  and replays with the same DLL and cfg they were made with.
- **Random map replays:** `civFirstTC` also needs the same `civs.xml`, `placementrules\colonies.xml` and
  `protoy.xml` when a recorded game plays back, because the map is generated again.
- **`damageOverTime`** keeps its poisons in the DLL, not in the game state: a saved game loads without
  the poisons that were running.
- **`buildingWorkRateAuras`:** its modifiers are saved with the game, but a game loaded without the
  key ignores them.
- **`decimalPopulation`** stores every population K times larger, and saved games keep it so: load them
  with the same K (tested with K = 100: a game saved at 17 / 20 loaded at 17 / 20).
- **No feature sends network commands of its own,** but for `repairWallGlobal`, which sends the game's
  own repair command: they all act inside the normal simulation, on every machine, in the same order.

## 8. WoL's keys that are not implemented

These lines of WoL's `wol.cfg` work with WoL's DLL only. This project's DLL logs each one as `<key>: not
implemented yet; ignored`, and nothing changes:

| Key | What it does in WoL |
|---|---|
| `attackTypeIcons` | The icons of the attack types. |
| `enablerandomtecheffect` | The `RandomTech` tech effect. Nothing in WoL's data uses it today. |
| `flagoverrideeffect` | WoL's flags. |
| `optionhighpolycliff` | Higher-detail cliffs. |
| `alpha2coverage` | A graphics option. |
| `loadingScreenCount` | More loading screens. |
| `map` | The hotkey for `uhcSyncTrack()`, WoL's sync tracker. |

`tacticSwitching` is not implemented either, and `wol.cfg` does not use it. Their patch sites are
listed in [wol-uhc-map.md](wol-uhc-map.md).

## 9. Troubleshooting

- **No `UHC.log` at all,** although the game starts: the DLL next to the exe is WoL's. The log is always
  written next to the exe that loaded the DLL.
- **`does not hold the stock bytes`:** this DLL expects the exe's original bytes at that address, and
  something changed them: a different exe, or another tool. In a port, that line means another of
  WoL's patches already uses the site ([porting guide](porting-to-another-dll.md)).
- **A key you set is reported as `not implemented yet`:** check its spelling, or
  [section 8](#8-wols-keys-that-are-not-implemented). The log prints keys in lowercase.
- **A feature is `applied` but nothing changes:** look for its `hook reached` line after playing. If it
  is missing, the game never ran that code; check the feature's data requirements above.
  `ignoreRegistryPath`, `removeConversionRestriction` and `abilitySlots` without `log` write no such
  line: check them by their effect.
- **The unit panel shows nothing new:** the profile has `optionminimizedui` on, as WoL plays by default,
  and the exe skips the stat panel. Each section says what shows there.
- **Data changes are ignored:** the game is reading another folder. Check `ignoreRegistryPath`. Also
  check that a newer `.xmb` is not shadowing the `.xml` you edited ([section 6](#6-editing-the-game-data)).
- **A poison does nothing.** Read the `damageOverTime` lines of `UHC.log` in order
  ([damageOverTime](#damageovertime)):
  - **no `<Unit>/<Action> attaches <X>` line for that attack:** the game did not see the tag. Possible
    causes:
    - `ignoreRegistryPath` is off;
    - the tag is not inside a `<ProtoAction>` of `protoy.xml` (a tactics `<action>` or the `<Unit>`
      itself does not work);
    - the block's `<Name>` is not its first child, or is not an action of the unit's tactics file. The
      game skips such a block silently.
  - **`<X> is not a proto unit`:** the text of `<AttachProtoUnit>` is not the name of a `<Unit>`.
  - **`<X> has no ProtoAction named Attaching`:** X's tactics file is missing or has no `Attaching`
    action, or X's `<Tactics>` line comes after its `<ProtoAction>`.
  - **no `poison:` line:** that attack never dealt damage, or its hits killed the unit.
  - **`tick … took 0.00 damage`:** X's `DamageFlags` exclude that unit, or X's `Attaching` action has no
    `<Damage>`.
- **`XS: Error 0003: could not compile file 'aiLoaderStandard.xs'`** when a game starts, and the AI
  players do nothing: an AI script or the game's own declarations failed to compile. On this DLL,
  check that `customAbstractTypes` and `customSyscalls` are `applied`: WoL's AI needs both. Another
  cause is a tactics file with a line break after a tactic name ([tactics files](#tactics-files)).
  `tools\re\trace_xs.py` logs the hidden error that names the cause.
- **The resolution changed** after starting a copy: the copy shares your profile
  (`Documents\My Games\Wars of Liberty\Users3\<profile>.xml`) with the real WoL. Set it back in the
  options.
