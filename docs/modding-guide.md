# Modding guide

How to use `UHC.dll` in an Age of Empires III: The Asian Dynasties mod: what to install, how to
configure each feature, what data or art your mod must provide, and how to check that it works.

For how the features work inside the engine, see [how-it-works.md](how-it-works.md). To build
the DLL or reverse engineer new features, see [developer-guide.md](developer-guide.md).

Contents:
- [Adding UHC.dll to your mod](#adding-uhcdll-to-your-mod): start here
1. [What you need](#1-what-you-need)
2. [Mod folder layout](#2-mod-folder-layout)
3. [The uhc.cfg file](#3-the-uhccfg-file)
4. [Reading UHC.log](#4-reading-uhclog)
5. [Feature reference](#5-feature-reference)
6. [Editing the game data](#6-editing-the-game-data)
7. [Multiplayer, saved games and replays](#7-multiplayer-saved-games-and-replays)
8. [Keys from UHC 1.10 that are not implemented](#8-keys-from-uhc-110-that-are-not-implemented)
9. [Troubleshooting](#9-troubleshooting)

## Adding UHC.dll to your mod

**What you need:**
- **The release zip** `UHC-x.y.z.zip`, from
  [Releases](https://github.com/Gorgorito12/Unharcoded-AOE3--NEW/releases). It contains one folder,
  `UHC-x.y.z\`, which holds:
  - `UHC.dll`;
  - `Startup\uhc.cfg`, with every key commented out;
  - `README.txt` and `LICENSE.txt`.
- **`UHCPatcher.exe`**, from the `Release` folder of
  [AoE3UnHardcoded](https://github.com/danielpereira/AoE3UnHardcoded). You use it once, to add the
  loader to your mod's `age3y.exe`.
- **Python 3 and this repository's `tools/` folder**, only for keys that need data edits: a new
  `healNonIdle` marker, `deckCardCount` at normal levels, or reusing a stock banner for
  `customRevolutionBanners`.
  - Get the tools from the source code: **Code → Download ZIP** on the repository page.
  - Install Python 3 from [python.org](https://www.python.org/downloads/). If `python` does not
    work in a new terminal, type `py` instead.
  - Run the commands in a terminal opened in the unzipped source folder: right-click the folder
    and choose **Open in Terminal**.

You do not need Visual Studio: building the DLL is only for changing it. **Your players need
nothing but your mod.**

**Steps:**
1. **Make your mod folder a complete game folder:** a copy of the game's `bin` folder with your
   mod's files on top.
   - The folder can live anywhere. Next to `bin` inside the game folder is fine, and that is
     where Wars of Liberty and Knights and Barbarians sit.
   - "Never modify the Steam install" means: never change or patch the files in `bin`, above all
     `bin\age3y.exe`.
2. **Patch the mod folder's `age3y.exe` once** with `UHCPatcher.exe`
   ([how](#getting-an-exe-with-the-uhc-loader)). The patcher also writes UHC 1.10's own `UHC.dll`
   and a new `Startup\uhc.cfg` next to the exe, and keeps the original exe as `age3y.backupuhc`.
3. **Copy this release over the patcher's files.** From the zip's `UHC-x.y.z\` folder, copy
   `UHC.dll` next to `age3y.exe` and the `Startup` folder into the mod folder, replacing both
   files. Do not extract the zip itself into the mod folder: its top folder would keep the files
   out of place.
   - If you run the patcher again later, first keep a copy of your own `Startup\uhc.cfg`.
   - Afterwards, copy this release's `UHC.dll` again and put your `uhc.cfg` back.
4. **Enable keys** in `Startup\uhc.cfg` by removing the `# ` in front of them:
   - always `ignoreRegistryPath`, so the game reads your mod folder's data and not the Steam
     install's;
   - then the keys you want. Add the data or art that each one needs
     ([what each key needs](#5-feature-reference)).
5. **Test.** Start the mod's `age3y.exe`, then read `UHC.log` next to it
   ([reading the log](#4-reading-uhclog)):
   - the first lines are `UHC.dll x.y.z` and `UHCMain: working directory <mod folder>`;
   - every key you enabled says `applied`;
   - in game, look for one of your own data changes, which proves the mod's data loaded.
6. **Ship.** On each player's PC, your mod must end up as a complete game folder containing your
   files, the patched `age3y.exe`, `UHC.dll` and `Startup\uhc.cfg`. UHC mods usually ship an
   installer that builds that folder from the player's own game install.
   - **Ship:** your changed files (for example `data\protoy.xml`, `data\protoy.xml.XMB`,
     `data\homecitylevels.xml`), the patched `age3y.exe`, `UHC.dll` and `Startup\uhc.cfg`.
   - **Leave out:** `UHC.log`, `age3y.backupuhc`, your backups and the tools' work folders.
   - **The installer** copies the player's TAD `bin` folder to the mod folder, then lays your
     files on top. If it runs `UHCPatcher.exe` on the player's copy instead of shipping a patched
     exe, it must copy `UHC.dll` and `Startup\uhc.cfg` after the patcher has run.

   Players can then start the mod's `age3y.exe` any way they like: double-click, shortcut or
   launcher. `UHC.dll` makes the exe's folder the working directory, as UHC 1.10 does.

**Notes:**
- **Multiplayer:** every player needs the same files
  ([section 7](#7-multiplayer-saved-games-and-replays)).
- **Home cities are shared.** They are stored in
  `Documents\My Games\Age of Empires 3\Savegame\sp_<City>_homecity.xml`, and the normal game and
  every mod copy use the same files. What the stock game does with a deck of more than 25 cards
  was not tested, so a mod that raises the deck size may want its players to use separate home
  cities for it.
- **If your mod already uses UHC 1.10:**
  - replace its `UHC.dll` with this one, then read `UHC.log`;
  - its `uhc.cfg` keeps working, since the UHC 1.10 syntax (`basePop=500`, `//` comments) is
    accepted;
  - keys that this DLL does not implement yet are reported and ignored
    ([section 8](#8-keys-from-uhc-110-that-are-not-implemented)).

## 1. What you need

- **The Steam version of TAD.** Its `bin\age3y.exe` must be the stock build, SHA-256
  `b1a1dab7264d2db72e8f8ae1df1e419eecc223b40db00c9d1013a3bc77611d9d` (see
  [binaries.md](binaries.md)). Use it only as the source you copy from: never modify the Steam
  install. Check a file's hash in PowerShell with `Get-FileHash age3y.exe`.
- **Your mod folder:** a complete game folder (a copy of the game's `bin` folder, plus your
  files), containing:
  - an `age3y.exe` patched with the **UHC loader** (next section);
  - `UHC.dll`, from the release zip. To change the DLL itself, build it as described in
    [developer-guide.md](developer-guide.md);
  - `Startup\uhc.cfg`, which selects the features.
- **Python 3 and the `tools/` folder** of this repository's source code, only for keys that need
  data edits ([see above](#adding-uhcdll-to-your-mod)). They need no extra packages.

### Getting an exe with the UHC loader

The loader is a small patch to `age3y.exe`. When the game starts, it loads `UHC.dll` from the
exe's folder and calls it before the game's own startup code. Its exact bytes are in
[binaries.md](binaries.md). This project does not ship a patcher; use the one from the original
UnHardcoded project:

1. **Start from an unmodified exe.** Your mod folder's `age3y.exe` must be a copy of the
   unmodified Steam exe: `Get-FileHash age3y.exe` prints `B1A1DAB7…11D9D`.
   - The patcher writes at fixed file offsets.
   - The DLL only detects a different build (from the PE header) or a change at one of its own
     patch sites. Any other change goes unnoticed, so always start from the stock exe.
2. **Get the patcher.** Download `UHCPatcher.exe` from the `Release` folder of
   [danielpereira/AoE3UnHardcoded](https://github.com/danielpereira/AoE3UnHardcoded). Keep it
   **outside** the game folders, for example on the desktop: started from inside a game folder,
   it picks that folder's exe by itself.
3. **Apply the patch.** Drag the mod folder's `age3y.exe` onto `UHCPatcher.exe`. A dialog opens:
   - leave its checkboxes as they are and click **Apply**. They only choose the keys written into
     the `uhc.cfg` that you replace in the next step; the exe patch is the same whatever you
     tick;
   - keep the default config path, `Startup\uhc.cfg`.

   According to its source code (it was not run in this project's tests), the patcher:
   - keeps the original exe as `age3y.backupuhc` next to it;
   - patches the exe in place;
   - writes UHC 1.10's `UHC.dll` next to it and a new `Startup\uhc.cfg`, replacing any existing
     ones.
4. **Install this release.** Copy its `UHC.dll` and `Startup\uhc.cfg` over the patcher's, then
   start the game once. `UHC.log` must start with `UHC.dll x.y.z`,
   `UHCMain: working directory …` and `UHCMain: <path>\Startup\uhc.cfg, N keys`.
5. **Check that the Steam install was not touched:** `Get-FileHash` on the Steam
   `bin\age3y.exe` must still print `B1A1DAB7…11D9D`.

If something goes wrong:
- **`host is not a UHC-patched age3y.exe`:** the exe is not the stock build plus the loader, and
  the DLL does nothing.
- **The loader shows *Failed to load UHC.dll!* and the game exits:** `UHC.dll` is missing.
- **No `UHC.log` at all:** the `UHC.dll` next to the exe is still UHC 1.10's, which writes no
  log.

This DLL was tested with the Knights and Barbarians exe (SHA-256 `d21d0173…`, stock plus the
loader only).

## 2. Mod folder layout

```
<mod folder>\
    age3y.exe            the UHC-patched copy
    age3y.backupuhc      the original exe, kept by the patcher
    UHC.dll              this project
    UHC.log              written by UHC.dll; it grows by one block on every start
    Startup\uhc.cfg      the features to enable
    data\  art\  AI3\    the game files, and your mod's changes to them
```

- **Where the data comes from.** With [`ignoreRegistryPath`](#ignoreregistrypath), the game reads
  its data from the mod folder. Without it, the game reads the install folder stored in the
  registry, which for a Steam install is the Steam folder: the mod would then load the Steam data
  instead of its own.
- **The working directory.** `UHC.dll` makes the exe's folder the working directory at startup,
  as UHC 1.10 does. A double-click, a shortcut and a launcher therefore all start the mod the
  same way.
- **UHC.dll's own files.** It reads `Startup\uhc.cfg` from the exe's folder and writes `UHC.log`
  there.

## 3. The uhc.cfg file

Start from the `Startup\uhc.cfg` in the release zip, which lists every key, commented out. The
repository's [examples/Startup/uhc.cfg](../examples/Startup/uhc.cfg) is the same file with every
key enabled, using the values this project tests with: do not ship it as it is.

- **Syntax:** one key per line, followed by its arguments, separated by spaces or tabs. UHC
  1.10's syntax also works, since its patcher writes it: `basePop=500` (or `basePop = 500`).
- **Case:** keys are case-insensitive (`deckCardCount` = `deckcardcount`). Arguments keep their
  case.
- **Comments:** a line whose first word starts with `#`, and anything after `//` (UHC 1.10
  style), even at the end of a line. A `#` later in a line is **not** a comment: in
  `deckCardCount 40 # more cards`, the words `#`, `more` and `cards` are arguments.
- **One line per key:** a key that takes values reads only its first line. Write
  `hcShipmentPointFallback` once, with all its names.
- **Unknown keys:** a key this DLL does not handle, whether an upstream key or a misspelling, is
  logged in lowercase as `<key>: not implemented yet; ignored`.
- **Absent keys** keep the stock behavior.

## 4. Reading UHC.log

`UHC.log` is appended on every start; delete it before a test to read a single run.

| Line | Meaning |
|---|---|
| `UHC.dll x.y.z` | The version of the DLL that wrote this run. Always the first line of a run. |
| `UHCMain: working directory <folder>` | The DLL made the exe's folder the working directory ([section 2](#2-mod-folder-layout)). |
| `UHCMain: <path>, N keys` | The cfg was read; N distinct keys. |
| `UHCMain: host is not a UHC-patched age3y.exe; doing nothing` | Wrong exe. See [section 1](#getting-an-exe-with-the-uhc-loader). |
| `UHCMain: cannot read <path> (error N); no features applied` | The cfg is missing or unreadable. |
| `<feature>: applied` | The feature patched the game. |
| `<feature>: FAILED` | It did not. The line before says why (bad arguments, or the next row). |
| `<feature>: site <Name> at 0x… does not hold the stock bytes; feature not applied` | The exe differs from the stock build at that address. Nothing was written there. |
| `<key>: not implemented yet; ignored` | A key this DLL does not handle: an upstream key not implemented yet ([section 8](#8-keys-from-uhc-110-that-are-not-implemented)), or a misspelled key. |
| `UHCMain: N applied, M failed` | The summary of this start. |
| `hook reached: <name> (0x…)` | The first time the game ran that patched code. Use it to confirm that a feature is really used in a game. |

Feature-specific lines are listed in each section below.

## 5. Feature reference

Each section gives the syntax, what changes in the game, what your mod must provide, how to
confirm it works, and its test status. "Changes the simulation" means every player in a
multiplayer game needs the same setting (see [section 7](#7-multiplayer-saved-games-and-replays)).

| Key | What it does | Your mod also needs | In-game status |
|---|---|---|---|
| [`ignoreRegistryPath`](#ignoreregistrypath) | Reads the game data from the mod folder (the exe's folder), instead of the install folder in the registry. | Nothing. Enable it in every mod folder that has its own data. | confirmed |
| [`deckCardCount`](#deckcardcount) | Raises the 25-card deck cap. | A `data\homecitylevels.xml` with a higher `<maxdecksize>` per level (stock: 20 to 25). | confirmed above the level table; see the section |
| [`basePop`, `extraPop`](#basepop-and-extrapop) | Raises the population caps (stock 200 and 50) and removes the 250 hard cap. | Enough houses or other population buildings to reach the new cap. | partly confirmed |
| [`noAILimit`](#noailimit) | Shows every `AI3\*.personality` file in game setup, not just the built-in 14. | The personality files. | confirmed |
| [`customRevolutionBanners`](#customrevolutionbanners) | Shows a banner for every `XPRevolution<Name>` tech, not only O'Higgins. | A banner texture per revolution. | partly confirmed |
| [`removeFameRestriction`](#removefamerestriction) | Shows Fame, XP and shipment costs on politician screens, and Fame/XP icons on home city cards. | Two icon textures. | not tested in game |
| [`removeConversionRestriction`](#removeconversionrestriction) | Lets `ConvertGuardian` convert any unit, not only treasure guardians. | Nothing. | not confirmed |
| [`hcShipmentPointFallback`](#hcshipmentpointfallback) | When the building holding the shipment point dies and no stock fallback building (Town Center, fort, …) is left, moves the point to the first alive building of the types you list. | Nothing beyond the proto names in the cfg. | confirmed |
| [`healNonIdle`](#healnonidle) | Lets healers marked with a unit type heal units that are busy (moving, fighting or doing something else). | That unit type on the healers in `protoy`, or the name of an existing type. | confirmed (automatic healing) |

No feature has been tested in multiplayer yet.

### ignoreRegistryPath

```
ignoreRegistryPath
```

- **Effect:** the game uses its current working directory as the install folder instead of the
  path stored in the registry. Stock already falls back to the working directory when the
  registry value cannot be read; this makes it unconditional. Since `UHC.dll` makes the exe's
  folder the working directory at startup, the game reads the mod folder's data however it is
  started.
- **Your mod:** nothing more. Enable this key in every mod folder that has its own data.
- **Check:** your mod's changed data is used. This key writes no `hook reached` line, because it
  only rewrites one branch. On the test bed, the copy's edited `protoy.xml.XMB` was loaded instead
  of the Steam one, also when the game was started from another folder.
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
  `homecitylevels.xml`. The file exists only inside the archives, so take it out once, from a
  terminal opened in the unzipped source code folder:
  1. extract it:
     `python -I tools\bar.py "<mod>\data\Data3.bar" homecitylevels --extract work`. This writes
     `work\Data\homecitylevels.xml.xmb`;
  2. convert it to text:
     `python -I tools\xmbedit.py to-xml work\Data\homecitylevels.xml.xmb homecitylevels.xml`;
  3. in a text editor, set each `<maxdecksize>` you want (for example `40`);
  4. save the result as `<mod>\data\homecitylevels.xml`.

  The game reads that loose file instead of the archive copy: on the test bed, every level read
  back as 40 from the running game. A loose `homecitylevels.xml.xmb` works too. Without this file,
  only home cities above the last level (131) get N cards.
- **Check:**
  - a deck can only hold cards that its home city has unlocked, so a 40-card deck also needs a
    home city with at least 40 unlocked cards, i.e. a high level. The confirmed test used a
    Japanese home city of level 9999;
  - in the deck screen, the deck must accept more than 25 cards;
  - `UHC.log` must show `hook reached: deckCardCount (0x7EF026)`.

  Home cities are shared with the normal game (see the notes under
  [Adding UHC.dll to your mod](#adding-uhcdll-to-your-mod)).
- **Log:** `deckCardCount: limit N`; `deckCardCount: expected an integer from 20 to 10000`;
  `hook reached: deckCardCount (0x7EF026)`.
- **Simulation:** decks are part of the game setup; give every player the same value.
- **Status:**
  - confirmed with 40 cards for a Japanese home city of level 9999 (past the table);
  - with a raised `homecitylevels.xml`, the engine's level table reads 40 at every level, but
    building a 40-card deck at a normal level has not been tried in game yet.

### basePop and extraPop

```
basePop <N>              N from 0 to 10000, stock 200
extraPop <N>             N from 0 to 10000, stock 50
```

- **How population is capped in stock:** the cap is what the player's buildings provide (houses,
  Town Centers, …), limited to 200 plus the extra population granted by techs and cards, which
  is itself limited to 50. It is also limited to that extra population plus a world-level value
  (200 in stock). Then a player bonus is added, and the result never exceeds 250.
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
  (`art\Art4.bar`, `Art5.bar`) has eight banners named after countries: `argentina`, `brazil`,
  `chile`, `colombia`, `haiti`, `mexico`, `peru` and `usa`. To reuse one, extract it and save it
  under the tech's name, e.g. `REV_banner_mexico.ddt` as `REV_banner_Hidalgo.ddt`, or
  `REV_banner_usa.ddt` as `REV_banner_Washington.ddt`:

  ```
  python -I tools\bar.py "<mod>\art\Art4.bar" rev_banner_mexico --extract work
  ```

  This writes `work\Art\ui\ingame\politicians\REV_banner_mexico.ddt`. Rename it to
  `REV_banner_Hidalgo.ddt` and put it in `<mod>\art\ui\ingame\politicians\`.

  Loose files are the usual way to add art to a mod. For data files, a loose file replaces the
  archive copy (verified with `homecitylevels.xml`); for art, this was not tested.
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
- **Check:** this key writes no `hook reached` line, because it only removes one branch. Check it
  in game: a unit with `ConvertGuardian` converts a unit that is not a treasure guardian.
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
- **Log:**
  - at startup, `hcShipmentPointFallback: N extra types after the stock list (multiplayer unverified)`;
  - the first time in a run of the game that no stock fallback building is left,
    `hcShipmentPointFallback: <Name> -> proto <ID>` for each name (or `(unknown proto; skipped)`)
    and `hook reached: hcShipmentPointFallback (0x669E2E)`.

  A move to another stock building, such as a second Town Center, logs nothing.
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
- **Effect:** healers whose proto is of `<UnitType>` also pick targets that are busy (moving,
  fighting or doing something else), and keep healing them while they move or fight. All the
  other stock checks still apply: the target must be damaged, a valid heal target for that
  healer, and reachable. Any other healer behaves as in stock.
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

  Edit both `data\protoy.xml` (plain text, by hand) and `data\protoy.xml.XMB`
  ([section 6](#6-editing-the-game-data)). For the XMB, run this from a terminal opened in the
  unzipped source code folder:

  ```
  python -I tools\xmbedit.py add-unittype "<mod>\data\protoy.xml.XMB" "<mod>\data\protoy.xml.XMB.new" Surgeon AbstractHealNonIdle
  ```

  Check the result with `python -I tools\xmbedit.py check "<mod>\data\protoy.xml.XMB.new"`, then
  rename `protoy.xml.XMB.new` to `protoy.xml.XMB`, keeping the old file as a backup.

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

Work on your mod folder, never on the Steam install. Run the tools from a terminal opened in the
unzipped source code folder, the one that contains `tools\`, and give them full paths to your
mod's files.

- **Where data lives:**
  - loose files in `data\`: `protoy.xml`, `techtreey.xml`, `stringtabley.xml` and others,
    usually with a compiled `.XMB` twin next to them;
  - everything else is in archives: `data\Data*.bar` (tactics, home city files,
    `homecitylevels.xml`, …) and `art\Art*.bar` (textures).
- **A file that is only in an archive:**
  1. extract it;
  2. convert it to XML with `xmbedit.py to-xml`;
  3. edit the XML;
  4. save it loose in `data\` under the stored name without `.xmb`, so
     `Data\homecitylevels.xml.xmb` becomes `data\homecitylevels.xml`.

  The game then reads the loose file instead of the archive copy. This was verified with an
  edited `homecitylevels.xml`, and also with an edited compiled `homecitylevels.xml.xmb`. The
  tools cannot convert XML back to XMB, and do not need to.
- **protoy: edit both files.** `data\` holds both `protoy.xml` (plain text) and
  `protoy.xml.XMB` (compiled). Which one the game prefers was not established, so keep both in
  step.
- **List and extract archive files** with `tools\bar.py`. `--extract` recreates the stored path
  below the folder you give, for example `work\Data\homecitylevels.xml.xmb`:

  ```
  python -I tools\bar.py "<mod>\data\Data3.bar" tactics/explorer
  python -I tools\bar.py "<mod>\data\Data3.bar" homecitylevels --extract work
  ```

- **Read and edit XMB files** with `tools\xmbedit.py`. Every command first confirms that it can
  re-encode the file byte for byte, so an edit cannot change anything else:

  ```
  python -I tools\xmbedit.py check "<mod>\data\protoy.xml.XMB"
  python -I tools\xmbedit.py to-xml work\Data\homecitylevels.xml.xmb homecitylevels.xml
  python -I tools\xmbedit.py add-unittype "<mod>\data\protoy.xml.XMB" "<mod>\data\protoy.xml.XMB.new" Surgeon AbstractHealNonIdle ypMonkIndian AbstractHealNonIdle
  ```

  - `add-unittype` prints what it added, and warns about unit names it cannot find; check the
    spelling against `protoy.xml`.
  - Before you replace the original, run `check` on the `.new` file. Then rename it over
    `protoy.xml.XMB`, keeping the old file as a backup.
  - Once the game has loaded, `python -I tools\re\inspect_unittypes.py AbstractHealNonIdle` shows
    which protos carry the type.

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

This DLL has no code for these upstream keys. Like any key it does not handle, misspellings
included, each one is logged in lowercase as `<key>: not implemented yet; ignored`, and nothing
changes.

`enableAllTeams`, `customSyscalls`, `customCheats` (and `.upl` plugins), `enableFarmAnim`,
`enableRectFarmAnim`, `farmingRadius`, `marketUnits`, `tacticSwitching`, `attackTypeIcons`,
`explorerUnits`, `asianCivs`, `nativeCivs`, `bigButtonCivs`, `noBigButtonBlds`, `twoScoutCivs`.

Their patch sites are verified against the stock exe in
[uhc-address-map.md](uhc-address-map.md), with the upstream defects to avoid.

## 9. Troubleshooting

- **No `UHC.log` at all**, although the game starts. Either the `UHC.dll` next to the exe is still
  UHC 1.10's, which the patcher writes and which writes no log: copy this release's `UHC.dll`
  over it. Or the exe has no loader. The log is always written next to the exe that loaded the
  DLL.
- **`does not hold the stock bytes`:** the exe is not the stock Steam build, or another tool
  patched the same place. Start again from a copy of the stock exe.
- **A key you set is reported as `not implemented yet`:** check its spelling. The log prints keys
  in lowercase.
- **A feature is `applied` but nothing changes:** look for its `hook reached` line after playing.
  If it is missing, the game never ran that code; check the feature's data requirements above.
  `ignoreRegistryPath` and `removeConversionRestriction` write no such line: check them by their
  effect.
- **Data changes are ignored:** the game is probably reading the Steam folder. Enable
  `ignoreRegistryPath`.
- **The resolution reset to 800x600** after starting a copy: the copy shares your user profile
  (`Documents\My Games\Age of Empires 3\Users3\<profile>.xml`) with the normal game. Set it back
  in the options.
