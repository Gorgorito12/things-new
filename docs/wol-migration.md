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

### Driving a skirmish

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

## Keys

Status words as in the README. "Blocks" = WoL does not load or its AI does not play without it.

| Key | Origin | Effect on WoL without it | Status |
|---|---|---|---|
| `noAILimitV2` | WoL | blocks (crash with a random AI) | **done**, confirmed |
| (`customAbstractTypes`) | WoL, always on | blocks (AI compile); 47 types dropped from ~2,800 `<UnitType>` uses | **done**, confirmed |
| `customSyscalls wolPlugin.upl wolai.upl` | upstream | blocks (AI compile: `kbGetTechID` ×36 in `aiWoLMain.xs`; 36 `RM4\ESOC_*` maps) | **done**, confirmed |
| `customCheats` | upstream | cosmetic (33 plugin cheats) | **done**, confirmed (`kill 'em all`: 50 Cannons) |
| `asianCivs Egyptians Ethiopians Koreans Zulu Maori` | upstream | degrades: export, consulate, wonder age-up for those civs | **done**, confirmed (Koreans: five wonders in the age-up list) |
| `NativeCivs Tupinamba WallMapu Tawantinsuyu` | upstream | degrades: fire pit, council age-up | **done**, confirmed (Tawantinsuyu: council list, dances resolved) |
| `twoScoutCivs Koreans` | upstream | degrades | **done**, not reached in game yet (probably the new home city dialog) |
| `bigButtonCivs`, `noBigButtonBlds` | upstream | degrades | **done**, partly confirmed (hook reached) |
| `enableAllTeams` | upstream | degrades (teams 3/4) | **done** for single player, partly confirmed; MP lobby pending (needs a LAN test) |
| `wonderCivUnitType Rangatira` | WoL | degrades (Maori age-up) | pending, RE |
| `marketUnits` | upstream | degrades (trade without a stock Market) | **done**, confirmed (`WOLMarketGreek`; refused without the key) |
| `explorerUnits` (40 triples) | upstream | degrades (hero names, KO text) | **done**, names confirmed (Korean monks Yi Sun and Kwon Hwan); 4 protos of WoL's cfg do not exist in its data |
| `enableFarmAnim`, `enableRectFarmAnim`, `farmingRadius` | upstream | degrades (gathering on WoL farms) | pending |
| `customProtoUnitCommands` (always on in WoL) | WoL | degrades (41 `<Command>` buttons) | pending, RE |
| `selectionLimit 75` | WoL | degrades | **done**, confirmed (75 of 89 Pikemen; 50 without) |
| `trainSingleAbstractType` | WoL | degrades (`AbstractTrainLimitOne`, 36 protos) | pending |
| `multiarmor` | WoL | degrades (32 protos, 76 effects) | pending, RE |
| WoL-DLL kb syscalls (`kbUnitGetNumberTargeters`, …) | WoL, always on | blocks the Maori AI (`wolRauparaha`) only | pending |
| `enablerandomtecheffect` | WoL | none in current data | pending |
| `betterfreedynamicunit`, `nowalkfarm`, `repairWallGlobal`, `compatMode` | WoL | degrades | pending, RE |
| `attackTypeIcons`, `loadingScreenCount 28`, `flagoverrideeffect`, `optionhighpolycliff`, `alpha2coverage`, `map` / `uhcSyncTrack` | upstream / WoL | cosmetic | pending |

The data scan behind the table (2026-11-02): WoL has 3,634 protos, 10,542 techs and 168 civs;
nothing in its data keeps the stock exe from loading (unknown types and effects are dropped).
The subtypes `ROF`, `GathererLimit`, `MinimumRange` and `Bounty` in `Data` effects need a check of
FUN_008F973F before deciding whether a key is needed.

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
| `nativeCivs`, `bigButtonCivs` | Tawantinsuyu (Cuzco): Town Center council |
| `selectionLimit` | scenario: 89 Pikemen |
| `customCheats` | Ethiopians: 50 Cannons |
