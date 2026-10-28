# UHC.dll for Age of Empires III: The Asian Dynasties

A new `UHC.dll` for the Steam version of AoE3 TAD. It removes hard-coded limits of the engine
and adds new engine features, which a mod turns on in `Startup\uhc.cfg`.

It drops into the existing UnHardcoded (UHC) loader: an `age3y.exe` patched with the UHC
patcher loads `UHC.dll` at startup. It is a from-scratch successor to the community
[AoE3UnHardcoded](https://github.com/danielpereira/AoE3UnHardcoded) project (UHC 1.10):
- every patch site was re-verified against the stock exe;
- the known upstream defects are fixed;
- it adds features that UHC 1.10 does not have.

## Features

| Key | What it does | In game |
|---|---|---|
| `ignoreRegistryPath` | Reads the game data from the mod folder instead of the Steam install. | confirmed |
| `deckCardCount N` | Raises the 25-card deck cap. | confirmed above the level table (see the guide) |
| `basePop N`, `extraPop N` | Raises the population caps (stock 200 and 50) and removes the 250 hard cap. | partly confirmed |
| `noAILimit` | Lists every `AI3\*.personality` file in game setup. | confirmed |
| `customRevolutionBanners` | A banner for every `XPRevolution<Name>` tech. | partly confirmed |
| `removeFameRestriction` | Fame, XP and shipment costs on politician screens; Fame and XP icons on cards. | not tested in game |
| `removeConversionRestriction` | `ConvertGuardian` may target any unit. | not confirmed |
| `hcShipmentPointFallback Proto…` | **New.** When the building holding the shipment point dies and no stock fallback building (Town Center, fort, …) is left, shipments move to the first listed building type that still stands. | confirmed |
| `healNonIdle [UnitType]` | **New.** Healers marked with a unit type heal units that are busy (moving, fighting or doing something else). | confirmed |
| `bufferedFileReads [KB]` | **New.** Reads the game's files through a read-ahead buffer instead of millions of tiny reads. In a late 8-AI game, frames over 100 ms dropped from 11 to 3, and time spent reading files fell from 14.9 s to 1 s per session. It does not change the simulation. | confirmed (single player) |
| `perfStats`, `perfAutoExec`, `perfExecFile`, `perfFileLog` | In development: performance diagnostics. See [docs/performance.md](docs/performance.md). | in progress |

No feature has been tested in multiplayer yet. Details, data requirements and limits for each
key are in the [modding guide](docs/modding-guide.md).

## Using it in your mod

No compiler is needed.

**What you need:**
- **The release zip** `UHC-x.y.z.zip`, from
  [Releases](https://github.com/Gorgorito12/Unharcoded-AOE3--NEW/releases). It holds `UHC.dll`, a
  `Startup\uhc.cfg` with every key commented out, a short `README.txt` and the license.
- **`UHCPatcher.exe`**, from
  [AoE3UnHardcoded/Release](https://github.com/danielpereira/AoE3UnHardcoded/tree/master/Release),
  used once.
- **Python 3 and this repository's `tools/` folder** (Code → Download ZIP), only for keys that
  need data edits.

**Steps:**
1. **Make your mod folder a complete game folder:** a copy of the game's `bin` folder plus your
   files. Never modify the Steam install.
2. **Patch the mod folder's `age3y.exe` once** with `UHCPatcher.exe`, run from outside the game
   folders. The exe must be the unmodified Steam exe. The patcher also writes UHC 1.10's own
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
uses UHC 1.10 can swap in this `UHC.dll`, since its `uhc.cfg` syntax is accepted. A mod with its
own `uhc.dll`, such as Wars of Liberty, rebuilds the features inside it instead:
see [porting to another DLL](docs/porting-to-another-dll.md). To build the DLL
yourself, see the [developer guide](docs/developer-guide.md#1-build).

## Documentation

| Document | For |
|---|---|
| [docs/modding-guide.md](docs/modding-guide.md) | Using the DLL in a mod: every key, the data and art it needs, how to check it, multiplayer. |
| [docs/how-it-works.md](docs/how-it-works.md) | How each feature works inside the engine, to understand or reimplement it. |
| [docs/developer-guide.md](docs/developer-guide.md) | Building, testing safely, adding a feature, the reverse-engineering workflow. |
| [docs/porting-to-another-dll.md](docs/porting-to-another-dll.md) | Rebuilding the new features inside a mod's own `uhc.dll` (for example Wars of Liberty): sites to check, files to copy, hook contracts. |
| [tools/README.md](tools/README.md) | Data tools (archives, compiled XML) and the runtime tracers. |
| [docs/uhc-address-map.md](docs/uhc-address-map.md) | Every UHC 1.10 patch site, verified against the stock exe, and the upstream defects. |
| [docs/engine-symbols.md](docs/engine-symbols.md) | Engine functions, globals and object layouts found so far. |
| [docs/binaries.md](docs/binaries.md) | Hashes of known exes and DLLs, and the byte layout of the UHC loader. |
| [docs/wol-uhc-map.md](docs/wol-uhc-map.md) | Notes on the Wars of Liberty `uhc.dll`, studied as a black box. |
| [docs/performance.md](docs/performance.md) | The performance investigation (in progress). |

## Status and roadmap

- **Implemented:**
  - 8 of the 23 UHC 1.10 keys: `ignoreRegistryPath`, `deckCardCount`, `basePop`, `extraPop`,
    `noAILimit`, `customRevolutionBanners`, `removeFameRestriction`,
    `removeConversionRestriction`;
  - 3 new features: `hcShipmentPointFallback`, `healNonIdle`, `bufferedFileReads`.
- **In research:**
  - DE-style poison: damage over time driven by `<AttachProtoUnit>` in the data, as in AoE3 DE.
    The engine findings so far are in [engine-symbols.md](docs/engine-symbols.md).
  - `unlockAllCards` (every card usable from a new home city): paused.
- **Later:** the remaining UHC 1.10 keys (civilizations, units, teams, syscalls, cheats and
  plugins). The keys not implemented yet are logged and ignored.

## Compatibility

- Only the Steam TAD exe, SHA-256 `b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d`,
  plus the UHC loader patch.
- The DLL checks its host and does nothing in any other exe.

## Credits and license

- This project's code is under the [MIT license](LICENSE).
- The concept, the loader and the original patch addresses come from the community
  [AoE3UnHardcoded](https://github.com/danielpereira/AoE3UnHardcoded) project. It has no
  license, so none of its code is included: its addresses were used as leads, and each one was
  re-verified against the stock exe.
- The Wars of Liberty `uhc.dll` was studied as a black box ([notes](docs/wol-uhc-map.md)). None
  of its code is included.
- Age of Empires is a trademark of Microsoft. This project is not affiliated with or endorsed by
  Microsoft.
