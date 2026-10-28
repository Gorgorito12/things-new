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
| `ignoreRegistryPath` | Uses the folder the game starts in, so a standalone mod folder reads its own data. | confirmed |
| `deckCardCount N` | Raises the 25-card deck cap. | confirmed above the level table (see the guide) |
| `basePop N`, `extraPop N` | Raises the population caps (stock 200 and 50) and removes the 250 hard cap. | partly confirmed |
| `noAILimit` | Lists every `AI3\*.personality` file in game setup. | confirmed |
| `customRevolutionBanners` | A banner for every `XPRevolution<Name>` tech. | partly confirmed |
| `removeFameRestriction` | Fame, XP and shipment costs on politician screens; Fame and XP icons on cards. | not tested in game |
| `removeConversionRestriction` | `ConvertGuardian` may target any unit. | not confirmed |
| `hcShipmentPointFallback Proto…` | **New.** When the building holding the shipment point dies, shipments move to the next listed building type. | confirmed |
| `healNonIdle [UnitType]` | **New.** Healers marked with a unit type heal units that are moving or fighting. | confirmed |
| `perfStats` | In development: performance diagnostics. See [docs/performance.md](docs/performance.md). | in progress |

No feature has been tested in multiplayer yet. Details, data requirements and limits for each
key are in the [modding guide](docs/modding-guide.md).

## Quick start

1. **Copy the game** to a new folder. Never modify the Steam install.
2. **Patch the copy's `age3y.exe`** with `UHCPatcher.exe` from
   [AoE3UnHardcoded/Release](https://github.com/danielpereira/AoE3UnHardcoded/tree/master/Release).
3. **Build `UHC.dll`** ([developer guide](docs/developer-guide.md#1-build)) and put it next to
   the exe.
4. **Copy [examples/Startup/uhc.cfg](examples/Startup/uhc.cfg)** to `<copy>\Startup\uhc.cfg` and
   keep the keys you want.
5. **Start the game** with the copy as its working directory, then read `UHC.log` next to the
   exe. Every key you set should show `applied`.

## Documentation

| Document | For |
|---|---|
| [docs/modding-guide.md](docs/modding-guide.md) | Using the DLL in a mod: every key, the data and art it needs, how to check it, multiplayer. |
| [docs/how-it-works.md](docs/how-it-works.md) | How each feature works inside the engine, to understand or reimplement it. |
| [docs/developer-guide.md](docs/developer-guide.md) | Building, testing safely, adding a feature, the reverse-engineering workflow. |
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
  - 2 new features: `hcShipmentPointFallback`, `healNonIdle`.
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
