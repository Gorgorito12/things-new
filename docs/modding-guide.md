# Modding guide

How to use `UHC.dll` in an Age of Empires III: The Asian Dynasties mod: what to install, how to
configure each feature, what data or art your mod must provide, and how to check that it works.

For how the features work inside the engine, see [how-it-works.md](how-it-works.md). To build
the DLL or reverse engineer new features, see [developer-guide.md](developer-guide.md).

Contents:
1. [What you need](#1-what-you-need)
2. [Mod folder layout](#2-mod-folder-layout)
3. [The uhc.cfg file](#3-the-uhccfg-file)
4. [Reading UHC.log](#4-reading-uhclog)
5. [Feature reference](#5-feature-reference)
6. [Editing the game data](#6-editing-the-game-data)
7. [Multiplayer, saved games and replays](#7-multiplayer-saved-games-and-replays)
8. [Keys from UHC 1.10 that are not implemented](#8-keys-from-uhc-110-that-are-not-implemented)
9. [Troubleshooting](#9-troubleshooting)

## 1. What you need

- **The Steam version of TAD.** Its `bin\age3y.exe` must be the stock build, SHA-256
  `b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d` (see
  [binaries.md](binaries.md)). Use it only as the source you copy from: never modify the Steam
  install. Check a file's hash in PowerShell with `Get-FileHash age3y.exe`.
- **A copy of the game, or your mod's own folder,** containing:
  - an `age3y.exe` patched with the **UHC loader** (next section);
  - `UHC.dll` from this project, built as described in [developer-guide.md](developer-guide.md);
  - `Startup\uhc.cfg`, which selects the features.
- **Python 3**, only for the data tools in `tools/` (no extra packages).

### Getting an exe with the UHC loader

The loader is a small patch to `age3y.exe`. When the game starts, it loads `UHC.dll` from the
exe's folder and calls it before the game's own startup code. Its exact bytes are in
[binaries.md](binaries.md). This project does not ship a patcher; use the one from the original
UnHardcoded project:

1. Copy the stock `age3y.exe` into your mod folder.
2. Download `Release/UHCPatcher.exe` from
   [danielpereira/AoE3UnHardcoded](https://github.com/danielpereira/AoE3UnHardcoded).
3. Drag **the copy** in your mod folder onto `UHCPatcher.exe` and apply the patch.
   - Do not run the patcher from inside the Steam folder: it then picks the Steam exe by itself.
   - Keep the default config path, `Startup\uhc.cfg`.
4. Put `UHC.dll` next to the patched exe and start the game once. The first line of `UHC.log`
   must be `UHCMain: <path>\Startup\uhc.cfg, N keys`.

If `UHC.log` says `host is not a UHC-patched age3y.exe`, the exe is not the stock build plus the
loader, and the DLL does nothing. If `UHC.dll` is missing, the loader shows *Failed to load
UHC.dll!* and the game exits.

This DLL was tested with the Knights and Barbarians exe (SHA-256 `d21d0173…`, stock + loader
only). The upstream patcher itself was not run during this project's tests.

## 2. Mod folder layout

```
<mod folder>\
    age3y.exe            the UHC-patched copy
    UHC.dll              this project
    UHC.log              written by UHC.dll; it grows by one block on every start
    Startup\uhc.cfg      the features to enable
    data\  art\  AI3\    the game files, and your mod's changes to them
```

Start the game **with the mod folder as the working directory**: in a shortcut, set "Start in"
to the mod folder. With [`ignoreRegistryPath`](#ignoreregistrypath) the game reads its data from
that folder. Without it, the game reads its install folder from the registry, which for a Steam
install is the Steam folder: a standalone mod copy would then load the Steam data instead of its
own.

`UHC.dll` resolves `Startup\uhc.cfg` relative to the exe's folder, and writes `UHC.log` there.

## 3. The uhc.cfg file

A ready-to-copy file with every implemented key is in
[examples/Startup/uhc.cfg](../examples/Startup/uhc.cfg).

- One key per line, followed by its arguments, separated by spaces or tabs.
- Keys are case-insensitive (`deckCardCount` = `deckcardcount`). Arguments keep their case.
- A line whose first word starts with `#` is a comment. **There are no end-of-line comments:**
  in `deckCardCount 40 # more cards`, the words `#`, `more` and `cards` are arguments.
- A key that takes values reads only its first line. Write `hcShipmentPointFallback` once, with
  all its names.
- A key this DLL does not implement is logged as `<key>: not implemented yet; ignored`.
- A key that is absent keeps the stock behavior.

## 4. Reading UHC.log

`UHC.log` is appended on every start; delete it before a test to read a single run.

| Line | Meaning |
|---|---|
| `UHCMain: <path>, N keys` | The cfg was read; N distinct keys. |
| `UHCMain: host is not a UHC-patched age3y.exe; doing nothing` | Wrong exe. See [section 1](#getting-an-exe-with-the-uhc-loader). |
| `UHCMain: cannot read <path> (error N); no features applied` | The cfg is missing or unreadable. |
| `<feature>: applied` | The feature patched the game. |
| `<feature>: FAILED` | It did not. The line before says why (bad arguments, or the next row). |
| `<feature>: site <Name> at 0x… does not hold the stock bytes; feature not applied` | The exe differs from the stock build at that address. Nothing was written there. |
| `<key>: not implemented yet; ignored` | See [section 8](#8-keys-from-uhc-110-that-are-not-implemented). |
| `UHCMain: N applied, M failed` | The summary of this start. |
| `hook reached: <name> (0x…)` | The first time the game ran that patched code. Use it to confirm that a feature is really used in a game. |

Feature-specific lines are listed in each section below.

## 5. Feature reference

Each section gives the syntax, what changes in the game, what your mod must provide, how to
confirm it works, and its test status. "Changes the simulation" means every player in a
multiplayer game needs the same setting (see [section 7](#7-multiplayer-saved-games-and-replays)).

| Key | In-game status |
|---|---|
| [`ignoreRegistryPath`](#ignoreregistrypath) | confirmed |
| [`deckCardCount`](#deckcardcount) | confirmed above the level table; see the section |
| [`basePop`, `extraPop`](#basepop-and-extrapop) | partly confirmed |
| [`noAILimit`](#noailimit) | confirmed |
| [`customRevolutionBanners`](#customrevolutionbanners) | partly confirmed |
| [`removeFameRestriction`](#removefamerestriction) | not tested in game |
| [`removeConversionRestriction`](#removeconversionrestriction) | not confirmed |
| [`hcShipmentPointFallback`](#hcshipmentpointfallback) | confirmed |
| [`healNonIdle`](#healnonidle) | confirmed (automatic healing) |

No feature has been tested in multiplayer yet.

### ignoreRegistryPath

```
ignoreRegistryPath
```

- **Effect:** the game uses its current working directory as the install folder instead of the
  path stored in the registry. Stock already falls back to the working directory when the
  registry value cannot be read; this makes it unconditional.
- **Your mod:** start the game with the mod folder as the working directory
  ([section 2](#2-mod-folder-layout)).
- **Check:** your mod's changed data is used. On the test bed, the edited `protoy.xml.XMB` of the
  copy was loaded instead of the Steam one.
- **Simulation:** no.
- **Status:** confirmed.

### deckCardCount

```
deckCardCount <N>        N from 20 to 10000
```

- **How decks are limited in stock:** the maximum deck size of a home city is the
  `<maxdecksize>` of its level in `homecitylevels.xml`, clamped to 20..25. A home city whose
  level is past the end of that table gets 25. The stock table has 132 levels: 20 cards at level
  0, one more every 10 levels, 25 from level 50.
- **Effect:** the upper clamp becomes N instead of 25, and levels past the table get N.
- **Your mod:** to reach N cards at normal levels, also raise `<maxdecksize>` in
  `homecitylevels.xml`. That file is only in the archives: extract it with `tools/bar.py`, read
  it with `tools/xmbedit.py to-xml` ([section 6](#6-editing-the-game-data)). Without that change,
  only home cities above the last level of the table get N cards.
- **Log:** `deckCardCount: limit N`; `deckCardCount: expected an integer from 20 to 10000`;
  `hook reached: deckCardCount (0x7EF026)`.
- **Simulation:** decks are part of the game setup; give every player the same value.
- **Status:** confirmed with 40 cards for a Japanese home city of level 9999 (past the table).
  A raised `<maxdecksize>` has not been tested.

### basePop and extraPop

```
basePop <N>              N from 0 to 10000, stock 200
extraPop <N>             N from 0 to 10000, stock 50
```

- **How population is capped in stock:** the cap is what the player's buildings provide (houses,
  Town Centers, …), limited to 200 plus the extra population granted by techs and cards, which
  is itself limited to 50. It is also limited by a world-level value that stock sets to 200,
  then a player bonus is added, and the result never exceeds 250.
- **Effect:** the 200 becomes `basePop`, the 50 becomes `extraPop`, and the world-level clamp and
  the 250 cap are removed. Either key alone keeps the other at its stock value.
- **Your mod:** buildings must still provide the population. To actually reach 300, the player
  needs enough houses: raise the house `BuildLimit` or `PopulationCapAddition` in `protoy.xml`
  if needed.
- **Not changed:** the shared team population mode keeps its stock limit of 200 per player.
- **Log:** `basePop/extraPop: base X, extra Y (…)`;
  `basePop/extraPop: expected integers from 0 to 10000`;
  `hook reached: basePop/extraPop (0x4581F3)`.
- **Simulation:** yes.
- **Status:** partly confirmed. A skirmish went past 200 with `basePop 300`; the limit reached was
  the number of houses that could be built.
- **Fixed from UHC 1.10:** upstream missed the path taken when the extra population is negative,
  where the stock 200/250 limits stayed active.

### noAILimit

```
noAILimit
```

- **Effect:** the AI personality list in game setup shows every `AI3\*.personality` file of the
  game folder, sorted by file name (case-insensitive). Stock shows a built-in list of 11
  personalities, 14 with TAD content. The folder name and the extension are read from the exe,
  so an exe patched to another folder (Wars of Liberty uses `AI4\`) works too.
- **Your mod:** add personality files. For example, a copy of `AI3\elizabeth.personality` saved as
  `AI3\mymod.personality`, with its fields changed:

  ```xml
  <AI>
     <version>2</version>
     <script>aiLoaderStandard</script>
     <nameID>33260</nameID>
     <tooltipID>41717</tooltipID>
     <forcedciv>japanese</forcedciv>
     <rushboom>-1</rushboom>
     <icon>ui\\singleplayer\\cpai_avatar_british</icon>
     <chatset>elizabeth</chatset>
     <playerNames>
        <nameID>33260<civ>Japanese</civ></nameID>
     </playerNames>
  </AI>
  ```

  `nameID` and `tooltipID` are string table IDs. Give each personality its own strings in your
  string table.
- **Log:** `noAILimit: N personalities from <folder>\AI3\*.personality`;
  `noAILimit: no personality files match …; keeping the stock list`;
  `hook reached: noAILimit (0x603B0B)`.
- **Simulation:** the list feeds game setup; every player needs the same personality files.
- **Status:** confirmed: an added personality appeared in game setup and played.
- **Fixed from UHC 1.10:** upstream leaves two of the function's variables uninitialized.

### customRevolutionBanners

```
customRevolutionBanners
```

- **Effect:** every revolution tech named `XPRevolution<Name>` shows the banner texture
  `ui\ingame\politicians\REV_banner_<Name>`. Stock shows a banner only for
  `XPRevolutionOHiggins` (`REV_banner_chile`), and that one is kept.
- **Your mod:** provide `art\ui\ingame\politicians\REV_banner_<Name>.ddt` for each revolution.
  The stock revolution techs are `XPRevolutionBolivar`, `…Bonifacio`, `…Hidalgo`,
  `…Louverture`, `…OHiggins`, `…SanMartin`, `…Santander` and `…Washington`. The stock art
  (`art\Art4.bar`, `Art5.bar`) has banners named after countries: `argentina`, `brazil`,
  `chile`, `colombia`, `haiti`, `mexico`, `peru`. To reuse one, extract it and save it under
  the tech's name, e.g. `REV_banner_mexico.ddt` as `REV_banner_Hidalgo.ddt`:

  ```
  python -I tools/bar.py "<game>\art\Art4.bar" rev_banner_mexico --extract <work folder>
  ```

  Loose files in `art\` are the usual way to add art to a mod. Whether loose files override the
  archives was not verified in this project's tests.
- **Log:** `hook reached: customRevolutionBanners (0x81A7CC)`.
- **Simulation:** no (interface only).
- **Status:** partly confirmed: the hook runs and the O'Higgins banner still shows. Banners for
  other revolutions were not tested.
- **Fixed from UHC 1.10:** the banner path is bounded; upstream overflows its buffer on long tech
  names.

### removeFameRestriction

```
removeFameRestriction
```

Three changes:
1. **Politician (age-up) screens** list the Fame, XP and shipment costs of a choice. The second
   politician screen also lists the export resource. Stock shows only food, wood, gold and, on
   the first screen, export.
2. **Home city cards** that cost Fame or XP show an icon for those resources.
3. **"Fame trickle":** the built-in abstract unit type `FavoriteUnit` is renamed `Fame` (same
   ID). The original UnHardcoded project applies this change under that name; how it enables a
   Fame trickle was not traced. Stock data does not use `FavoriteUnit`.

- **Your mod:** provide the icons `art\ui\home_city\xp_hc_icon.ddt` and
  `art\ui\home_city\fame_hc_icon.ddt` (the names upstream uses). Without them, those cards show
  no icon, as in stock.
- **Log:** `removeFameRestriction: icons need …`;
  `hook reached: removeFameRestriction costs #1 (0x80E490)` (also `#2`, `icon load`,
  `fame icon case`, `XP icon case`).
- **Simulation:** the unit type rename changes game data; give every player the same setting.
- **Status:** not tested in game.
- **Fixed from UHC 1.10:** on the second politician screen, upstream passes the wrong object
  as the owner of each cost line.

### removeConversionRestriction

```
removeConversionRestriction
```

- **Effect:** the `ConvertGuardian` action, which converts treasure guardians, may target any
  unit. Stock checks a unit flag that only treasure guardians have.
- **Who has the action:** explorers, war chiefs and some cavalry list it in their tactics, and a
  tech enables it (for example the `HCXPMorningStar` card).
- **Simulation:** yes.
- **Status:** not confirmed: one test with the Sioux war chief was inconclusive.

### hcShipmentPointFallback

```
hcShipmentPointFallback <Proto> [<Proto> ...]     1 to 64 proto unit names
```

- **How stock behaves:** home city shipments arrive at the player's shipment point, a building
  (usually the Town Center). When that building is destroyed or deleted, the game moves the
  point to the first alive building it finds among a fixed list: Town Center, FortFrontier,
  WarHut, Blockhouse, NoblesHut, and three types not resolved yet. If none of those is left,
  there is no valid shipment point.
- **Effect:** after that stock list, the listed protos are tried in cfg order. The first alive
  building of the player that passes the same checks as stock becomes the point. When there are
  several of one proto, the stock unit query order decides, so every machine picks the same one.
- **Your mod:** list proto names exactly as in `protoy.xml`, e.g.
  `hcShipmentPointFallback Barracks Stable ArtilleryDepot Market Church`.
- **Log:** `hcShipmentPointFallback: N extra types after the stock list (multiplayer unverified)`;
  then, the first time the point must move in a game, `hcShipmentPointFallback: <Name> -> proto
  <ID>` for each name, or `(unknown proto; skipped)`;
  `hook reached: hcShipmentPointFallback (0x669E2E)`.
- **Simulation:** yes.
- **Status:** confirmed: after deleting the Town Center, the point moved to a listed building and
  shipments arrived there. Water shipment points were not tested.
- **New in this DLL:** not in UHC 1.10.

### healNonIdle

```
healNonIdle [<UnitType>]      default AbstractHealNonIdle
```

- **How stock behaves:** a healer only picks targets that are idle. It also stops healing as soon
  as its target moves or fights.
- **Effect:** healers whose proto is of `<UnitType>` also pick targets that are moving or
  fighting, and keep healing them. All the other stock checks still apply: the target must be
  damaged, a valid heal target for that healer, and reachable. Any other healer behaves as in
  stock.
- **The marker type:** in TAD, abstract unit types are a fixed list compiled into the exe, and
  any other `<UnitType>` in `protoy.xml` is silently dropped. So this DLL **registers
  `<UnitType>` as a new abstract type** when the data does not define it. You can then list it on
  any healer:

  ```xml
  <Unit id ='424' name ='Surgeon'>
      ...
      <UnitType>LogicalTypeHealed</UnitType>
      <UnitType>AbstractHealNonIdle</UnitType>
  ```

  Edit both `data\protoy.xml` and `data\protoy.xml.XMB` ([section 6](#6-editing-the-game-data)):

  ```
  python -I tools/xmbedit.py add-unittype protoy.xml.XMB protoy.xml.XMB.new Surgeon AbstractHealNonIdle
  ```

  An existing type or proto name works too, with no data change: `healNonIdle AbstractMonk`
  applies the feature to every monk, `healNonIdle Surgeon` to surgeons only. This uses the same
  code path but was not tested in game.
- **Monks and other fighting healers** may still choose to attack instead of heal: that is the
  unit's own behavior and is not changed. Pure healers such as the Surgeon show the feature best.
- **Log:** `healNonIdle: healers of unittype X heal busy targets (multiplayer unverified)`; when
  the data loads, `hook reached: abstract unit types (0x51BA31)` and
  `unit types: X -> <ID> (bit B of N), added` (or `already defined`); in a game,
  `hook reached: healNonIdle auto-search (0x9CD9C7)` and `hook reached: healNonIdle (0x9E0C79)`.
- **Check the data:** with the game running, `python -I tools/re/inspect_unittypes.py
  AbstractHealNonIdle` lists the protos that carry the type.
- **Simulation:** yes. It also adds a unit type, which changes the unit type count.
- **Status:** confirmed: British surgeons marked with the type healed their explorer during a
  fight through their automatic search. A direct order (right-click) on a fighting unit was not
  verified.
- **New in this DLL:** not in UHC 1.10.

## 6. Editing the game data

Work on a copy of the game. Never edit the Steam install.

- **Where data lives:**
  - loose files in `data\`: `protoy.xml`, `techtreey.xml`, `stringtabley.xml` and others,
    usually with a compiled `.XMB` twin next to them;
  - everything else is in archives: `data\Data*.bar` (tactics, home city files,
    `homecitylevels.xml`, …) and `art\Art*.bar` (textures).
- **protoy: edit both files.** `data\` holds both `protoy.xml` (plain text) and
  `protoy.xml.XMB` (compiled). Which one the game prefers was not established, so keep both in
  step.
- **List and extract archive files** with `tools/bar.py`:

  ```
  python -I tools/bar.py "<game>\data\Data3.bar" tactics/explorer
  python -I tools/bar.py "<game>\data\Data3.bar" homecitylevels --extract <work folder>
  ```

- **Read and edit XMB files** with `tools/xmbedit.py`. It confirms that it can re-encode a file
  byte for byte before it changes anything:

  ```
  python -I tools/xmbedit.py check protoy.xml.XMB
  python -I tools/xmbedit.py to-xml homecitylevels.xml.xmb homecitylevels.xml
  python -I tools/xmbedit.py add-unittype protoy.xml.XMB protoy.xml.XMB.new Surgeon AbstractHealNonIdle ypMonkIndian AbstractHealNonIdle
  ```

  `add-unittype` warns about unit names it cannot find; check the spelling against `protoy.xml`.
  Rename the `.new` file over the original once it is right.

More about the tools: [tools/README.md](../tools/README.md).

## 7. Multiplayer, saved games and replays

- Every player needs the same `UHC.dll`, the same `uhc.cfg` and the same data.
- The keys that change the simulation are `deckCardCount`, `basePop`, `extraPop`, `noAILimit` (game
  setup), `removeFameRestriction`, `removeConversionRestriction`, `hcShipmentPointFallback` and
  `healNonIdle`. A difference in any of them between players can desynchronize the game.
- `healNonIdle` and `removeFameRestriction` change the unit type table. Load saved games and
  replays with the same DLL and cfg they were made with.
- None of this has been tested yet: multiplayer, saved games and replays are all unverified.
- No feature sends network commands of its own: they all act inside the normal simulation, on
  every machine, in the same deterministic order.

## 8. Keys from UHC 1.10 that are not implemented

These upstream keys are recognized by name only: the log reports `not implemented yet; ignored`
and nothing changes.

`enableAllTeams`, `customSyscalls`, `customCheats` (and `.upl` plugins), `enableFarmAnim`,
`enableRectFarmAnim`, `farmingRadius`, `marketUnits`, `tacticSwitching`, `attackTypeIcons`,
`explorerUnits`, `asianCivs`, `nativeCivs`, `bigButtonCivs`, `noBigButtonBlds`, `twoScoutCivs`.

Their patch sites are verified against the stock exe in
[uhc-address-map.md](uhc-address-map.md), with the upstream defects to avoid.

## 9. Troubleshooting

- **No `UHC.log` at all:** the exe does not have the loader, or the game was started from
  another folder. The log is always written next to the exe that loaded the DLL.
- **`does not hold the stock bytes`:** the exe is not the stock Steam build, or another tool
  patched the same place. Start again from a copy of the stock exe.
- **A feature is `applied` but nothing changes:** look for its `hook reached` line after playing.
  If it is missing, the game never ran that code; check the feature's data requirements above.
- **Data changes are ignored:** the game is probably reading the Steam folder. Add
  `ignoreRegistryPath` and set the shortcut's "Start in" folder.
- **The resolution reset to 800x600** after starting a copy: the copy shares your user profile
  (`Documents\My Games\Age of Empires 3\Users3\<profile>.xml`) with the normal game. Set it back
  in the options.
