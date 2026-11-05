# things-new

Engine extensions for Age of Empires III: The Asian Dynasties (Steam). A DLL removes hard-coded limits
and adds new engine features, and a mod turns each one on with a line in its cfg file.

## Features

Every key, with what it needs and how far it was tested, is in the
[modding guide](docs/modding-guide.md#5-feature-reference). By theme:

| Theme | Keys |
|---|---|
| **Game files and startup** | `ignoreRegistryPath`, `bufferedFileReads`, `multipleInstances`, `compatMode` |
| **Population, decks and limits** | `basePop`, `extraPop`, `decimalPopulation`, `deckCardCount`, `selectionLimit`, `noAILimit`, `noAILimitV2`, `enableAllTeams` |
| **New data and scripting** | `customAbstractTypes`, `customProtoUnitCommands`, `customHotkeyContexts`, `techRenameEffect`, `customSyscalls`, `customCheats`, `kbUnitSyscalls` |
| **Civs** | `asianCivs`, `nativeCivs`, `twoScoutCivs`, `bigButtonCivs`, `noBigButtonBlds`, `danceBonusCivs`, `wonderCivUnitType`, `startingTC`, `civFirstTC`, `customRevolutionBanners`, `removeFameRestriction` |
| **Healing and hit points** | `healNonIdle`, `smartHealTargets`, `overhealHitpointBars`, `overhealSources`, `overhealDecay` |
| **Combat** | `multiarmor`, `dodgeAnyUnit`, `dodgeChance`, `dodgeSoundSet`, `criticalSoundSet`, `damageOverTime`, `spreadAnyAccuracy`, `broadsideMuzzleLimit`, `snareOnlyHitUnit`, `rofFix`, `stunMovingTargetFix`, `noDamageOnUnbuiltFoundations`, `fallenHeroTacticsFix`, `removeConversionRestriction` |
| **Gathering and farms** | `gatherFix`, `showGatherRate`, `workRateByAbstractType`, `autoGatherScaleByContained`, `unitResourceAuras`, `resourceGatherAuras`, `resourceDebt`, `enableFarmAnim`, `enableRectFarmAnim`, `farmingRadius`, `nowalkfarm`, `betterfreedynamicunit`, `marketUnits` |
| **Buildings and training** | `liveBuildingWorkRate`, `buildingWorkRateAuras`, `maintainWaitForPop`, `trainSingleAbstractType`, `noTrainNearEnemyTC`, `lifespanAfterConstruction`, `gaiaSocketsOnly`, `repairWallGlobal`, `hcShipmentPointFallback` |
| **Techs and transforms** | `techPrereqRecheck`, `transformUpdatesLOS`, `transformInventory` |
| **Interface** | `abilitySlots`, `wonderPanelSkipAuras`, `explorerUnits`, `noCorpseDopples` |

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
1. **Get the release zip** from [Releases](https://github.com/Gorgorito12/tad-engine-extensions/releases).
   It holds `UHC.dll`, a `Startup\uhc.cfg` with every key commented out, a short `README.txt` and the
   license.
2. **Make your mod folder a complete game folder:** a copy of the game's `bin` folder plus your files.
   Never modify the Steam install.
<!-- private:begin -->
3. **Patch the mod folder's `age3y.exe` once** with `UHCPatcher.exe`, It must
   be the unmodified Steam exe.
<!-- private:end -->
<!-- public: 3. **Patch the mod folder's `age3y.exe` once** with `UHCPatcher.exe`. It must be the unmodified Steam exe. -->
4. **Copy `UHC.dll` and `Startup\uhc.cfg` from the zip** over the patcher's files.
5. **Enable keys** by removing the `# ` in front of them: always `ignoreRegistryPath`, then the ones you
   want, with the data each needs.
6. **Start the mod's `age3y.exe`.** `UHC.log` appears next to it, and every key you enabled says
   `applied`.

<!-- public: The full version is in [Adding UHC.dll to your mod](docs/modding-guide.md#adding-uhcdll-to-your-mod). -->

## Building

Visual Studio with the C++ desktop workload and CMake. The DLL must be 32-bit:

```
cmake -S . -B build -A Win32
cmake --build build --config Release
```

The result is `build\Release\UHC.dll`, which exports `_UHCMain@0`. Those names, and `uhc.cfg`, are what
the loader asks for.

## Documentation

| Document | For |
|---|---|
| [docs/modding-guide.md](docs/modding-guide.md) | Every key: what it does, what it needs, how to check it, multiplayer. |
| [docs/how-it-works.md](docs/how-it-works.md) | How each feature works inside the engine. |
| [docs/porting-to-another-dll.md](docs/porting-to-another-dll.md) | Adding the features to WoL's own DLL, with the code in [docs/porting-code/](docs/porting-code/helpers.md). | <!-- private -->
| [docs/developer-guide.md](docs/developer-guide.md) | Building, the test beds, adding a feature. | <!-- private -->
| [tools/README.md](tools/README.md) | The data tools and the runtime tracers. | <!-- private -->
| [docs/wol-migration.md](docs/wol-migration.md), [docs/wol-requests.md](docs/wol-requests.md) | WoL: progress, and its requests. | <!-- private -->

## Compatibility

Only the Steam TAD exe, SHA-256 `b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d`, plus
the loader patch. The DLL checks its host and does nothing in any other exe.

## Credits and license

- This project's code is under the [MIT license](LICENSE).
<!-- private:end -->
- Age of Empires is a trademark of Microsoft. This project is not affiliated with or endorsed by
  Microsoft.
