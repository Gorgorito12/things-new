# things-new <!-- private -->
<!-- public: # tad-engine-extensions -->

Engine extensions for Age of Empires III: The Asian Dynasties (Steam). A DLL removes hard-coded limits
and adds new engine features, and a mod turns each one on with a line in its cfg file.

## Features

<!-- private:begin -->
Every key, with what it needs and how far it was tested, is in the
[modding guide](docs/modding-guide.md#5-feature-reference), but for the keys that fix a bug and the performance
keys, which are in [bug-fixes.md](docs/bug-fixes.md) (the benchmark harness is in
[performance.md](docs/performance.md), "Benchmark harness"). By theme:
<!-- private:end -->
<!-- public:begin
Every key, with its options, is in the commented [`examples/Startup/uhc.cfg`](examples/Startup/uhc.cfg); the
[modding guide](docs/modding-guide.md#5-feature-reference) covers the earlier keys in depth. By theme:
public:end -->

| Theme | Keys |
|---|---|
| **Game files and startup** | `ignoreRegistryPath`, `bufferedFileReads`, `fastVertexFill`, `rendererOption`, `xsErrorLog`, `dataLint`, `multipleInstances`, `compatMode`, `modelCacheLimit`, `dmgPartBoneFix`, `fastLastInLine`, `menuOptions`, `preloadDll`, `lanAutoStart` |
| **Population, decks and limits** | `basePop`, `extraPop`, `decimalPopulation`, `deckCardCount`, `selectionLimit`, `noAILimit`, `noAILimitV2`, `enableAllTeams`, `ageFiveShipments`, `resendableCards`, `quickArrivalCards` |
| **New data and scripting** | `customAbstractTypes`, `customProtoUnitCommands`, `customHotkeyContexts`, `techRenameEffect`, `customSyscalls`, `customCheats`, `kbUnitSyscalls`, `auraStacking` |
| **Civs** | `asianCivs`, `nativeCivs`, `twoScoutCivs`, `bigButtonCivs`, `noBigButtonBlds`, `danceBonusCivs`, `wonderCivUnitType`, `firstTC`, `startingTC`, `civFirstTC`, `customRevolutionBanners`, `removeFameRestriction`, `ageUpBuildings`, `politicianEnablesTech`, `scenarioCivs` |
| **Healing and hit points** | `healNonIdle`, `smartHealTargets`, `overhealHitpointBars`, `overhealSources`, `overhealDecay` |
| **Combat** | `detonationDeath`, `multiarmor`, `dodgeAnyUnit`, `dodgeChance`, `dodgeSoundSet`, `criticalSoundSet`, `damageOverTime`, `spreadAnyAccuracy`, `accuracyTechs`, `containedUnitsROF`, `broadsideMuzzleLimit`, `cantBeSlowed`, `veterancyBonus`, `snareOnlyHitUnit`, `snareValues`, `killBountyTechs`, `resourceBounty`, `teamKillBounty`, `pillageGold`, `rofFix`, `stunMovingTargetFix`, `noDamageOnUnbuiltFoundations`, `fallenHeroTacticsFix`, `removeConversionRestriction`, `numberOfShots`, `retargetInAction`, `broadsideSoundSet`, `killSpawn`, `customImpactTypes`, `directionalAttack`, `stealthTargeting`, `impactBoneFix` |
| **Gathering and farms** | `gatherFix`, `showGatherRate`, `workRateByAbstractType`, `autoGatherScaleByContained`, `nurseryFactor`, `unitResourceAuras`, `linkedResource`, `resourceGatherAuras`, `resourceDebt`, `cratePriority`, `enableFarmAnim`, `enableRectFarmAnim`, `farmingRadius`, `nowalkfarm`, `betterfreedynamicunit`, `marketUnits`, `autoGatherFrom`, `buildingGather`, `truckAttackResourceFix`, `herdWalkAwayFix`, `deadReplacementAtZeroInventory`, `faithResource` (optional) |
| **Buildings and training** | `liveBuildingWorkRate`, `buildingWorkRateAuras`, `maintainWaitForPop`, `trainSingleAbstractType`, `noTrainNearEnemyTC`, `lifespanAfterConstruction`, `gaiaSocketsOnly`, `repairWallGlobal`, `hcShipmentPointFallback`, `sharedBuildLimit`, `doNotQueue`, `nextResearchFree`, `researchGrants`, `trainBatchSize`, `costEscalationTechs`, `randomCost`, `annexFacing`, `customWalls`, `researchOnTheMove`, `shipTechLimit`, `homeCityTechsInUnits` |
| **Techs and transforms** | `hcTargetTechs`, `perCivEffects`, `techPrereqRecheck`, `transformUpdatesLOS`, `transformInventory`, `transformSpan`, `unitTypeTechs`, `kothTimer`, `shipmentCounts`, `orPrereqsQty`, `transformChecks`, `garrisonConvert` |
| **Interface** | `nativePreview`, `displayedRange`, `abilitySlots`, `wonderPanelSkipAuras`, `explorerUnits`, `noCorpseDopples`, `steadyHitpointBars`, `inventoryBars`, `attackTypeIcons`, `multiplierDecimals`, `minUIStats`, `playerIcon`, `autoScout`, `editorSearch`, `editorAutosave`, `techGadgets`, `cultureUI`, `incomeRates`, `selectFattened`, `politicianPlacesFix` |

## Status

- Tested in single player, each key as its section in the guide says. Most keys have a test video.
- Multiplayer and replays are not tested for any key.
- A key the DLL does not handle is logged and ignored.

## Using it in your mod

<!-- private:begin -->
For Wars of Liberty, see [adding these features to WoL](docs/modding-guide.md#adding-these-features-to-wol):
WoL keeps its own DLL and takes the code of the features it wants, from the
[porting guide](docs/porting-to-another-dll.md).

In any other mod:
<!-- private:end -->
1. **Get the release zip** from [Releases](https://github.com/Gorgorito12/things-new/releases).
   It holds `dinput8.dll`, an `engine-ext\engine-ext.cfg` with every key commented out, a short `README.txt`
   and the license, plus `art\effects\uhc_rings\` (the aura and range rings, for the mod's `art` folder),
   `art\ui\uhc\health_overheal.ddt` (the orange end of the portrait HP bar, for `overhealHitpointBars`) and
   `dxvk\` (DXVK's `d3d9.dll` and its license, for `rendererOption`). There is no `UHC.dll` and no patcher.
2. **Make your mod folder a complete game folder:** a copy of the game's `bin` folder plus your files.
   Never modify the Steam install.
3. **Copy `dinput8.dll` and the `engine-ext` folder** next to the mod's `age3y.exe`. It works with the
   unmodified Steam exe, and also beside a loader that runs another `UHC.dll`.
4. **Enable keys** in `engine-ext\engine-ext.cfg` by removing the `#` in front of them: `ignoreRegistryPath`
   when nothing else makes the game read the mod folder's data, then the ones you want, with the data each
   needs (data files go in `engine-ext\`).
5. **Start the mod's `age3y.exe`.** `engine-ext\engine-ext.log` appears; its first line is
   `dinput8.dll x.y.z`, and every key you enabled says `applied`.

## Building

Visual Studio with the C++ desktop workload and CMake. The DLL must be 32-bit:

```
cmake -S . -B build -A Win32
cmake --build build --config Release
```

The result is `build\Release\UHC.dll`, which exports `_UHCMain@0`. Those names, and `uhc.cfg`, are what
the loader asks for. The same build writes `build\Release\dinput8.dll`, the same code for a game that keeps
another `UHC.dll` (it reads `engine-ext\engine-ext.cfg`).

## Documentation

| Document | For |
|---|---|
| [docs/modding-guide.md](docs/modding-guide.md) | The keys in depth: what each does, what it needs, how to check it, multiplayer. |
| [docs/bug-fixes.md](docs/bug-fixes.md) | The same, for the keys that fix a bug of the game or of WoL's data, and the performance keys. | <!-- private -->
| [docs/performance.md](docs/performance.md) | What limits CPU and GPU use, the A/B measurements, and the benchmark harness (the dev keys `perfStats`, `perfAutoExec`, `perfExecFile`, `perfFileLog`). | <!-- private -->
| [docs/how-it-works.md](docs/how-it-works.md) | How each feature works inside the engine. |
| [docs/porting-to-another-dll.md](docs/porting-to-another-dll.md) | Adding the features to WoL's own DLL, with the code in [docs/porting-code/](docs/porting-code/helpers.md). | <!-- private -->
| [docs/developer-guide.md](docs/developer-guide.md) | Building, the test beds, adding a feature. | <!-- private -->
| [tools/README.md](tools/README.md) | The data tools and the runtime tracers. | <!-- private -->
| [docs/wol-migration.md](docs/wol-migration.md), [docs/wol-requests.md](docs/wol-requests.md) | WoL: progress, and its requests. | <!-- private -->
| [docs/wol-maps.md](docs/wol-maps.md), [docs/wol-campaign.md](docs/wol-campaign.md) | WoL: the random map crash hunt, and the diagnosis of its campaign. | <!-- private -->
| [docs/nursery-design.md](docs/nursery-design.md) | WoL: the design of the "Nursery" factor (request #107), and its open questions. | <!-- private -->

## Compatibility

Only the Steam TAD exe, SHA-256 `b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d`, plus
the loader patch. The DLL checks its host and does nothing in any other exe.

## Credits and license

- This project's code is under the [MIT license](LICENSE).
- The release zip ships [DXVK](https://github.com/doitsujin/dxvk) 3.1.1 (its 32-bit `d3d9.dll`, unmodified)
  for `rendererOption`: Copyright (c) 2017 Philip Rebohle and its contributors, under the zlib license
  (`dxvk\LICENSE.txt` in the zip). It is not in this repository.
- Age of Empires is a trademark of Microsoft. This project is not affiliated with or endorsed by
  Microsoft.
