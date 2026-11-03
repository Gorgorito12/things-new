# UHC.dll for Age of Empires III: The Asian Dynasties

A new `UHC.dll` for the Steam version of AoE3 TAD. It removes hard-coded limits of the engine
and adds new engine features, which a mod turns on in `Startup\uhc.cfg`.

<!-- private:begin -->
It drops into the existing UnHardcoded (UHC) loader: an `age3y.exe` patched with the UHC
patcher loads `UHC.dll` at startup. It is a from-scratch successor to the community
[AoE3UnHardcoded](https://github.com/danielpereira/AoE3UnHardcoded) project (UHC 1.10):
- every patch site was re-verified against the stock exe;
- the known upstream defects are fixed;
- it adds features that UHC 1.10 does not have.
<!-- private:end -->
<!-- public:begin
It loads through the UHC loader: an `age3y.exe` patched with the UHC patcher loads `UHC.dll` at
startup. Every patch site is checked against the stock exe before it is written.
public:end -->

## Features

| Key | What it does | In game |
|---|---|---|
| `ignoreRegistryPath` | Reads the game data from the mod folder instead of the Steam install. | confirmed |
| `deckCardCount N` | Raises the 25-card deck cap. | confirmed above the level table (see the guide) |
| `basePop N`, `extraPop N` | Raises the population caps (stock 200 and 50) and removes the 250 hard cap. | partly confirmed |
| `decimalPopulation [K] [log]` | **New.** Population with decimals: `<PopulationCount>0.5`, `<PopulationCapAddition>7.5` and decimal amounts in their tech effects, in steps of 1/K (default 10). The population counter and the tooltips show the decimals; AI scripts still see whole numbers. | confirmed (single player, also a skirmish vs AI) |
| `noAILimit` | Lists every `AI3\*.personality` file in game setup. | confirmed |
| `noAILimitV2` | **New.** The same list, hooked later in the same function (for mods whose cfg uses this name). | confirmed (single player) |
| `customAbstractTypes [file]` | **New.** Every name in an XML file (default `data\uhc\customabstracttypes.xml`) becomes an abstract unit type usable in protos, techs and XS. | confirmed (single player) |
| `customSyscalls [files]` | Loads `.upl` plugins and adds their XS syscalls. | confirmed (single player, AI skirmish) |
| `customCheats` | The cheats plugins register work in the chat. | confirmed (single player) |
| `selectionLimit N` | **New.** A selection holds up to N units (stock 50). | confirmed (single player) |
| `enableAllTeams` | Team 3 and Team 4 in the single-player game setup. | partly confirmed |
| `asianCivs Civ ...` | Listed civs count as Asian civs (consulate, export, wonder age-up). | confirmed (single player) |
| `twoScoutCivs Civ ...` | Listed civs get the two-hero interface. | not tested in game |
| `marketUnits Proto ...` | Listed buildings count as a Market for trading. | confirmed (single player) |
| `explorerUnits Proto Type StringID ...` | Listed protos get hero names and their own knockout message. | partly confirmed (names) |
| `customRevolutionBanners` | A banner for every `XPRevolution<Name>` tech. | partly confirmed |
| `removeFameRestriction` | Fame, XP and shipment costs on politician screens; Fame and XP icons on cards. | not tested in game |
| `removeConversionRestriction` | `ConvertGuardian` may target any unit. | not confirmed |
| `hcShipmentPointFallback Proto…` / `FirstTC` | **New.** When the building holding the shipment point dies and none of the 10 stock fallback types (Town Center, Outpost, forts, …) is left, shipments move to the first listed building type that still stands. `FirstTC` is the player's first town center, which `startingTC` or `civFirstTC` can make another building (a civ that starts with a Market). | confirmed (single player; `FirstTC` with `civFirstTC`) |
| `healNonIdle [UnitType]` | **New.** Healers marked with a unit type heal units that are busy (moving, fighting or doing something else). | confirmed |
| `smartHealTargets [UnitType…] [log]` | **New.** A healer's automatic search heals the best of the units the stock rules accept, not the first one: the listed unit types first, then the lowest HP ratio, the nearest, the lowest unit ID. | confirmed (single player) |
| `dodgeAnyUnit [UnitType] [log]` | **New.** Units marked with a unit type can dodge hits like the Japanese monk: no damage, 15 % of the time, while their player has the tech `YPDodge`. Stock allows it only for `ypMonkJapanese`. | confirmed (single player) |
| `dodgeChance <UnitType> <percent> [tech <TechName> \| notech] [ranged \| melee \| all] [log]` | **New.** A dodge chance per unit type, with the tech it needs (`YPDodge` by default, another, or none) and a filter for ranged or melee hits; one rule per line, the first that matches decides. | confirmed (single player) |
| `dodgeSoundSet UnitType SoundSet`, `criticalSoundSet UnitType SoundSet` | **New.** Choose the sound set a unit plays when it dodges, or when it lands a critical hit, instead of the stock `PowerEvade` / `PowerCriticalStrike`. | confirmed (single player; the choice is logged, the sound itself was not listened to) |
| `damageOverTime [log] [noticktext]` | **New.** Poison: an attack that lists `<AttachProtoUnit>X</AttachProtoUnit>` keeps damaging what it hits, with X's `Attaching` action every `ROF` seconds for X's `Lifespan`. Damage type, bonuses, armor and techs on X apply as for any hit; arrows, grenades, cannon balls and area damage poison too. Optional tags on the attack: `<AttachMaxStacks>` (stacks that expire one by one), `<AttachSnare>` (slow) and `<AttachTickText>` (the damage shown over the unit). | confirmed (single player; a tick on an AI army unit after its attacker is gone not reproduced) |
| `spreadAnyAccuracy [UnitType] [log]` | **New.** `<MaxSpread>` and `<SpreadFactor>` of each attack (tactics or `<ProtoAction>`) set how far its misses land, instead of the hardcoded `min(0.25 × distance, 5)`; stock reads neither tag. Units marked with the unit type scatter every shot that way whatever their accuracy (1.0 and `PerfectAccuracy` too), and each shot deals its area damage where it lands. `InstantBallistics` and `TargetGround` attacks are not covered. | confirmed (single player) |
| `liveBuildingWorkRate [log]` | **New.** A `BuildingWorkRate` tech (train, research and `Maintain` speed) also speeds up the buildings that already stand, and a `TrainPoints` tech the units already queued or in training and the current `Maintain` cycle. Stock only speeds up the buildings completed, and the units queued, after the tech. | confirmed (single player) |
| `techPrereqRecheck [N] [full] [log]` | **New.** Techs whose prerequisites count units (`<TypeCount>`) react as soon as such units are created or die. Stock re-checks them only at the player's next house, age-up or tech change. | confirmed (single player) |
| `maintainWaitForPop [UnitType] [log]` | **New.** A marked building whose automatic production (`Maintain`: factory cannons, Ottoman settlers, …) finishes a unit at the population cap keeps it and spawns it as soon as there is room. Stock throws it away and starts the cycle again. | confirmed (single player) |
| `transformUpdatesLOS [log]` | **New.** A unit that a tech (`TransformUnit`) or a revolution changes into another proto takes that proto's line of sight. Stock keeps the old one. | confirmed (single player) |
| `broadsideMuzzleLimit N [UnitType] [log]` | **New.** A ship's broadside fires from up to N muzzles per side instead of 6, as many as its model has. | confirmed (single player) |
| `abilitySlots N [log]` | **New.** The command panel shows up to N abilities per unit instead of 6, so a 7th ability gets a button even when the first 6 are disabled. | confirmed (single player, UI) |
| `wonderPanelSkipAuras [log]` | **New.** The wonder power panel shows a wonder's first available ability that is not a passive aura, so a global power listed after an aura gets its button. | confirmed (single player, UI) |
| `lifespanAfterConstruction [UnitType] [log]` | **New.** A marked building starts its `<Lifespan>` when its construction is finished, not when the foundation is placed. | confirmed (single player) |
| `gaiaSocketsOnly [UnitType] [log]` | **New.** A socketed building (`TradingPost`, or a mod's) may only be placed on a socket that Gaia owns, as the red placement preview already shows. | not tested in game |
| `customHotkeyContexts [log]` | **New.** A keymap context named `<ProtoName>Accel` becomes that proto's hotkey context, for buildings the exe has no context for (a mod's, or the Sacred Field). | partly confirmed (contexts registered and switched; key presses not tested) |
| `snareOnlyHitUnit [log]` | **New.** A snared unit (`<TargetSpeedBoost>`) no longer slows the group it moves with; only the hit unit slows. | confirmed from the log (single player) |
| `techRenameEffect [log]` | **New.** The tech effect `SetTechName` gives a tech new texts for the players the effect reaches, and only for them. The alias key `enableTechRenameEffect` is read too. | confirmed (single player) |
| `noCorpseDopples [UnitType] [log]` | **New.** A dead unit of a marked type (a hunt's carcass) leaves no frozen copy in the fog of war. Live units are still remembered. | confirmed (single player) |
| `danceBonusCivs Civ… [log]` | **New.** The fire pit's Training, XPTrickle, Gathering and Regeneration dances also work for the civs you list, not only for the native civs. | confirmed (single player, Healing Dance) |
| `startingTC [UnitType] [log]` | **New.** A building of a marked type can be a player's first town center (`FirstTC` in the placement rules), like a `TownCenter`: a player with none takes it, and it replaces a first town center that is gone, dead or about to expire (a start whose town center expires at once). | confirmed from the log and memory (single player; the placement effect not driven) |
| `civFirstTC [log]` | **New.** A civ's `<firstTC>Proto</firstTC>` in `civs.xml` replaces the `TownCenter` that random maps place for its players, except in a Nomad start. That building is their first town center (`FirstTC`) and, with the data the guide lists, receives their town starting units (settlers, crates). | confirmed (single player; a Nomad start and multiplayer not tested; AI scripts still expect a `TownCenter`) |
| `transformInventory [all] [scale] [UnitType] [log]` | **New.** A unit that a tech (`TransformUnit`) or a revolution changes into another proto takes that proto's resources (`InitialResource`) when the two protos hold different resource types: a wood crate turned into a food crate holds food. Stock keeps the old resources (or none). | confirmed (single player) |
| `noTrainNearEnemyTC M [UnitType] [near UnitType] [nowarn \| warn=Text] [log]` | **New.** Marked units (default `AbstractDaimyo`: the Daimyos and the Shogun) do not train while they stand less than M metres from an enemy's first Town Center, or from an enemy building of a `near` type (up to 4), measured to the building's edge; the queue keeps its progress and resumes when the blocker dies. Your own held units show a red warning (your text, a string ID, or `nowarn`). | confirmed (single player) |
| `overhealHitpointBars [UnitType…] [segment[=RRGGBB]] [stat[=Label]] [log]` | **New.** HP bars and HP texts of marked units take `InitialHitpoints` as 100 %, not `MaxHitpoints`, so a mod whose healers push units above their starting HP shows fresh units as full. With `segment`, the HP above it shows Overwatch style: an orange segment over the right end of the full floating bar, an orange `165/150` in the unit panel, and, with a fourth bar in the UI data, an orange end on the portrait bar. `stat` adds an `Overheal 15/15` row to the unit information panel. Display only. | confirmed (single player, UI) |
| `overhealSources [UnitType…] [log]` | **New.** Only healers of the source types (default `AbstractOverhealer`) heal units marked by `overhealHitpointBars` above their `InitialHitpoints`; every other heal (other healers, regeneration, dances, area heals, powers) stops there, and a normal healer's heal action ends there. Needs `overhealHitpointBars`. | confirmed (single player) |
| `overhealDecay <rate>[%] [delay] [UnitType…] [log]` | **New.** Overwatch-style decay: the HP of marked units above their `InitialHitpoints` goes back down to it at `rate` HP (or % of it) per second of game time, `delay` seconds after their last heal (regeneration does not hold it); never below it, never fatal. Needs `overhealHitpointBars`. | confirmed (single player, also a skirmish vs AI) |
| `showGatherRate [UnitType] [log]` | **New.** The stat panel shows a gathering unit's rate per second under its HP row (`Food (icon): 0.67/s`), and the data ref `{currentUnitGatherRateString}` returns it to a mod's own UI. | confirmed (single player, stat panel; the data ref not tested) |
| `buildingWorkRateAuras [log]` | **New.** Auras and other stat modifiers may use `<ModifyType>BuildingWorkRate</ModifyType>`: the multiplier then scales how fast the units they reach train, research and spawn their `Maintain` units. Stock reads the name as unknown and the aura does nothing. | confirmed (single player, `Maintain`) |
| `bufferedFileReads [KB]` | **New.** Reads the game's files through a read-ahead buffer instead of millions of tiny reads. In a late 8-AI game, frames over 100 ms dropped from 11 to 3, and time spent reading files fell from 14.9 s to 1 s per session. It does not change the simulation. | confirmed (single player) |
| `multipleInstances [background]` | **New.** Lets this copy run while a copy of the game from another folder is running; stock allows one copy per machine. `background` keeps its windows behind all others and never focused, for unattended tests. | confirmed (two copies, single player) |
| `perfStats`, `perfAutoExec`, `perfExecFile`, `perfFileLog` | In development: performance diagnostics. | in progress |

No feature has been tested in multiplayer yet. Details, data requirements and limits for each
key are in the [modding guide](docs/modding-guide.md), where most features confirmed in game
show a short clip of their test, with the live numbers (hit points, line of sight, the
feature's own log lines) drawn over the game, and a link to the full recording.

## Using it in your mod

No compiler is needed.

**What you need:**
- **The release zip** `UHC-x.y.z.zip`, from
  [Releases](https://github.com/Gorgorito12/tad-engine-extensions/releases). It holds `UHC.dll`, a
  `Startup\uhc.cfg` with every key commented out, a short `README.txt` and the license.
<!-- private:begin -->
- **`UHCPatcher.exe`**, from
  [AoE3UnHardcoded/Release](https://github.com/danielpereira/AoE3UnHardcoded/tree/master/Release),
  used once.
<!-- private:end -->
<!-- public: - **`UHCPatcher.exe`** (the UHC patcher), used once. -->
- **Python 3 and this repository's `tools/` folder** (Code → Download ZIP), only for keys that
  need data edits.

**Steps:**
1. **Make your mod folder a complete game folder:** a copy of the game's `bin` folder plus your
   files. Never modify the Steam install.
2. **Patch the mod folder's `age3y.exe` once** with `UHCPatcher.exe`, run from outside the game
   folders. The exe must be the unmodified Steam exe. The patcher also writes its own
   `UHC.dll` and a `Startup\uhc.cfg`.
3. **Copy this release's `UHC.dll` and `Startup\uhc.cfg` over the patcher's files.** Take them
   from inside the zip's `UHC-x.y.z\` folder.
4. **Enable keys** by removing the `# ` in front of them: always `ignoreRegistryPath`, then the
   ones you want. Add the data or art each needs.
5. **Start the mod's `age3y.exe`.** `UHC.log` appears next to it: its first line is the DLL
   version, and every key you enabled says `applied`.
6. **Ship your files, the patched exe, `UHC.dll` and `Startup\uhc.cfg`.** Do not ship a copy of
   the game: your installer builds the complete folder from each player's own game install.
   Players then start the mod however they like, since UHC.dll makes the exe's folder the working
   directory. They install nothing else.

The full version, with what each key needs from your mod, is in
[Adding UHC.dll to your mod](docs/modding-guide.md#adding-uhcdll-to-your-mod). A mod that already
uses the UHC loader can swap in this `UHC.dll`, since the patcher's `uhc.cfg` syntax is accepted.
<!-- private:begin -->
A mod with its own `uhc.dll`, such as Wars of Liberty, rebuilds the features inside it instead:
see [porting to another DLL](docs/porting-to-another-dll.md). To build the DLL
yourself, see the [developer guide](docs/developer-guide.md#1-build).
<!-- private:end -->

## Building

Visual Studio with the C++ desktop workload and CMake. The DLL must be 32-bit (`-A Win32`; an
x64 configure fails on purpose):

```
cmake -S . -B build -A Win32
cmake --build build --config Release
```

The result is `build\Release\UHC.dll`, which exports `_UHCMain@0`. The bytes each feature
expects in the exe are in `src/generated/sites.h`; `python -I tools/gen_sites.py <stock age3y.exe>`
regenerates it, and refuses any exe that is not the stock build.

## Documentation

| Document | For |
|---|---|
| [docs/modding-guide.md](docs/modding-guide.md) | Using the DLL in a mod: every key, the data and art it needs, how to check it, multiplayer. |
| [docs/how-it-works.md](docs/how-it-works.md) | How each feature works inside the engine, to understand or reimplement it. |
| [docs/developer-guide.md](docs/developer-guide.md) | Building, testing safely, adding a feature, the reverse-engineering workflow. | <!-- private -->
| [docs/porting-to-another-dll.md](docs/porting-to-another-dll.md) | Rebuilding the new features inside a mod's own `uhc.dll` (for example Wars of Liberty): sites to check, files to copy, hook contracts. | <!-- private -->
| [tools/README.md](tools/README.md) | Data tools (archives, compiled XML) and the runtime tracers. | <!-- private -->
| [docs/uhc-address-map.md](docs/uhc-address-map.md) | Every UHC 1.10 patch site, verified against the stock exe, and the upstream defects. | <!-- private -->
| [docs/engine-symbols.md](docs/engine-symbols.md) | Engine functions, globals and object layouts found so far. | <!-- private -->
| [docs/binaries.md](docs/binaries.md) | Hashes of known exes and DLLs, and the byte layout of the UHC loader. | <!-- private -->
| [docs/wol-uhc-map.md](docs/wol-uhc-map.md) | Notes on the Wars of Liberty `uhc.dll`, studied as a black box. | <!-- private -->
| [docs/performance.md](docs/performance.md) | The performance investigation (in progress). | <!-- private -->

## Status and roadmap

- **Implemented:**
<!-- private:begin -->
  - 8 of the 23 UHC 1.10 keys: `ignoreRegistryPath`, `deckCardCount`, `basePop`, `extraPop`,
    `noAILimit`, `customRevolutionBanners`, `removeFameRestriction`,
    `removeConversionRestriction`;
<!-- private:end -->
<!-- public:begin
  - from the UHC loader's key set: `ignoreRegistryPath`, `deckCardCount`, `basePop`, `extraPop`,
    `noAILimit`, `customRevolutionBanners`, `removeFameRestriction`,
    `removeConversionRestriction`;
public:end -->
  - new keys: `hcShipmentPointFallback`, `healNonIdle`, `smartHealTargets`, `dodgeAnyUnit`,
    `dodgeChance`, `dodgeSoundSet`, `criticalSoundSet`, `damageOverTime`, `spreadAnyAccuracy`,
    `liveBuildingWorkRate`, `techPrereqRecheck`, `maintainWaitForPop`, `transformUpdatesLOS`, `broadsideMuzzleLimit`,
    `abilitySlots`, `wonderPanelSkipAuras`, `lifespanAfterConstruction`, `gaiaSocketsOnly`,
    `customHotkeyContexts`, `snareOnlyHitUnit`, `techRenameEffect`, `noCorpseDopples`,
    `danceBonusCivs`, `startingTC`, `civFirstTC`, `transformInventory`, `noTrainNearEnemyTC`,
    `overhealHitpointBars`, `showGatherRate`, `buildingWorkRateAuras`, `decimalPopulation`,
    `bufferedFileReads`, `multipleInstances`.
    Most of them answer Wars of Liberty's requests ([docs/wol-requests.md](docs/wol-requests.md)). <!-- private -->
- **In research:**
  - `unlockAllCards` (every card usable from a new home city): paused.
- **Later:** more keys (civilizations, units, teams, syscalls, cheats and
  plugins). The keys not implemented yet are logged and ignored.

## Compatibility

- Only the Steam TAD exe, SHA-256 `b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d`,
  plus the UHC loader patch.
- The DLL checks its host and does nothing in any other exe.

## Credits and license

- This project's code is under the [MIT license](LICENSE).
<!-- private:begin -->
- The concept, the loader and the original patch addresses come from the community
  [AoE3UnHardcoded](https://github.com/danielpereira/AoE3UnHardcoded) project. It has no
  license, so none of its code is included: its addresses were used as leads, and each one was
  re-verified against the stock exe.
- The Wars of Liberty `uhc.dll` was studied as a black box ([notes](docs/wol-uhc-map.md)). None
  of its code is included.
<!-- private:end -->
- Age of Empires is a trademark of Microsoft. This project is not affiliated with or endorsed by
  Microsoft.
