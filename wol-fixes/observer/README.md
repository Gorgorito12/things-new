# Observer UI (#81)

Request (JTMaston): "the Observer UI broke many versions ago and it doesn't work with all maps". Round 1 (2026-11-21)
was the diagnosis; round 2 (2026-11-22) follows his answers and adds the repair of the 36 maps (`observer_maps.py`),
the cause of the wrong icons, a single-player way to test observer mode, and the design for every map. Everything
was tested on one PC, single player.

## Round 2 (2026-11-22)

JTMaston's answers to round 1's six questions: players would like to reuse ESOC's observer, on every map, with a
simple way to put it in future maps; what broke is mostly what we saw, and he remembers "unit and tech icons not
correlating with the actual units/techs"; yes to the two map edits if they make it better; (b) if possible, but
(b) "would affect the map generation and resource distribution"; resolutions from 720p to 4K; always the
minimized UI (the big UI will be disabled).

### In short

1. **`observer_maps.py` repairs the 36 maps** in place (originals kept, `revert` puts them back): the switch now reads
   the lobby box, the name clash is gone, and the panel's tables are rewritten by name so that every unit and tech
   row points at WoL's own unit or tech. In game: the panel shows the right icons for researched techs and counts
   villagers as economic units (pictures 12 and 13); still missing is the content for WoL (oil, the Great War age,
   flags, WoL's own units such as `DutchSettler` in the unit rows).
2. **Why the icons did not match:** ESOC wrote the panel's tables with the numeric IDs of the stock game (ESOC 1.12.2
   numbers its techs and units exactly as the stock TAD data does). WoL's data has its own numbering, so every row
   pointed at another tech or unit. Details below.
3. **Observer mode can be tested in a single-player skirmish:** WoL's DLL reads the lobby's Observer box from game
   setting 37h, which is `gamecampaignshownhcnote` in the profile's skirmish settings; set to true, a skirmish
   generates in observer mode: with 3 players in Free for All, player 3 (an AI) is the observer, the map is sized
   and filled for the two real players, and the panel's trigger script compiles. The human is still a player (slot
   1), so seeing the panel on one PC still needs the test line of round 1.
4. **Every map without changing its generation:** the ESOC maps already do this themselves (they size and place the
   map for the real players only); for the other 177 maps it needs either the same few lines in each map, or a DLL
   change in how the game builds the random map's player list. Design below; nothing built for it.
5. **Resolutions 720p to 4K, always minimized:** the list of UI files is below (not built this round).

### How to install the repair

```
python -I observer_maps.py apply  "<WoL folder>" --stock "<Age of Empires III TAD bin folder>"
python -I observer_maps.py check  "<WoL folder>"
python -I observer_maps.py revert "<WoL folder>"
```

`<WoL folder>` holds `RM4\` and `data\`. `--stock` is any stock Age of Empires III: The Asian Dynasties `bin` folder
(its `data\techtreey.xml` and `data\protoy.xml` are only read; they give the stock names of ESOC's numbers, so no
stock data is copied into the maps). `--switch-only` writes step 1 only; `--out <folder>` writes the maps elsewhere.
Run it again after each WoL release that changes `techtreey.xml` (it starts again from the kept originals). With the
lobby box unticked, a repaired map generates and plays as before (the observer code is skipped).

What it changes in each of the 36 maps (the same in all 36, which share the panel code):

| Change | Rows per map | Why |
|---|---|---|
| `if (false == true)` → `if (rmIsObserverMode() == true)` | 1 | The switch was hard off. |
| The map's own `kbGetTechID` helper removed | 1 block (6 lines) | `wolai.upl` registers `int kbGetTechID(string techName)`: the clash stopped the whole trigger script. The map's calls now reach the syscall, which knows all 10,542 WoL techs (the helper only searched the first 2,550). |
| Unit rows `AEU/AMU/AWU/ARU(284,"Settler",…)` → `(-1,"Settler",…)` | 460 | The map's own code then asks `kbGetProtoUnitID("Settler")` when the game starts. |
| Tech rows `ITT/ITS(260,…)` → `ITT/ITS(-1,…,"Gangsaw")` | 2,065 | The tech by name, through `kbGetTechID`. |
| Tracked techs `ATT/ATTR(type,tech)` → `ATTW/ATTRW` | 1,551 | The tech by name; a unit type that is a proto by name too (passed as 100000 + its ID, which `UTcorrect` now decodes); abstract types keep ESOC's numbers, which the panel's `UTcorrect` already shifts and which match WoL's list. The 21 rows ESOC gave by type name are marked the same way, since `UTcorrect` shifted their runtime ID a second time. |
| Shipment checksums (`CKSUM` and the written-out lines) | 102 | The tech by name. |
| `cNumAllTechs` 2550 → 11542 | 1 | The size of the panel's tech arrays and of its research scan: WoL's 10,542 techs plus room. |
| Rows whose stock tech WoL no longer has | 162 commented out | 102 tech rows (for example `ImperialJanissaries`, the German `HCShip...` cards), 49 tracked techs, 11 removals. |

### Why the unit and tech icons do not match (#81, question 2)

- ESOC's tables are calls like `ITT(260,11070,"ui\techs\gang_saw\gang_saw_64x64")` (tech 260, its name string, its
  icon) and `AEU(284,"Settler",22806,"units/villagers/villager_portrait")` (proto 284). The numbers are the stock
  game's: 2,056 of the 2,065 tech rows carry the name string of the stock tech at that index (the other 9 are the
  consulate rows, labelled on purpose with the intervention string), and all 460 unit rows carry the stock proto of
  their name.
- WoL's data numbers them otherwise: 10,542 techs and 3,634 protos against the stock 2,549 and 1,463, and **none** of
  the 2,065 tech rows has the same index in WoL. Tech 260 is `Gangsaw` in the stock game and `ypPostImperialIndian`
  in WoL; proto 284 is `Settler` in the stock game and `ypSMJesuitPeasants` in WoL. So when a WoL player researched
  a tech, the panel showed the icon and name of whatever ESOC tech had that number, and the unit rows counted other
  units (round 1's "villagers counted as military", "unit rows show the explorer only").
- The panel also sized its tech arrays and its research scan to 2,550 techs, so no WoL tech above index 2,549 was
  ever seen.
- What was already right: the abstract unit types (Hero, AbstractVillager, Military, Huntable, Gold, Wood ...).
  ESOC shifts them at run time by the position of `Unit` (`UTcorrect`), and WoL's list keeps the stock order after
  its 3,634 protos (checked in the running game: 1480 → Hero, 1485 → AbstractVillager, 1509 → All, 1594 → Wood,
  1618 → ValidIdleVillager ...).
- Still with fixed numbers after the repair (ranges of stock IDs, which have no single name; listed for step 2):
  the revolution techs (`InI(i,1531,1538)` → `handleRevolt`), two other `InI` ranges, the consulate techs cleared
  after an intervention (`k=196..203`, `2451`), and the icons ESOC drew itself (`spec\techs\TK_<stock number>`, used
  when a row has no icon). Also left: the round-1 content faults (oil, the Great War age, civ flags), and WoL's own
  units (`DutchSettler`, `JavaneseLabourer` ...), which are in no table, so the unit rows skip them.

Also converted, because they gave the same symptoms: the population bar counted villagers by stock proto IDs
(`kbUnitCount(player,284,2)` for `Settler` and so on), none of which is a WoL villager, so every villager went to
"Military Unit Population"; it now counts the abstract types `AbstractVillager` and `AbstractFishingBoat`. The other
numbers written in the trigger code for units (`kbUnitCount`, `kbProtoUnitIsType`, `kbUnitQuerySetUnitType`) and for
techs (`kbGetTechPercentComplete`, `i==<tech>`) are looked up by name too. One more limit found on the way: the XS
compiler refuses a string literal of 128 characters or more, so a line the repair makes longer is cut into several
`cEf` calls (the code written is the same).

### Observer mode in a single-player skirmish (#81, step 1 test)

- **How.** WoL's DLL reads the lobby box from game setting 37h. In the profile's skirmish settings that setting is
  `gamecampaignshownhcnote` (the settings are numbered in file order: `gamerandomseed` 13h and `gamekoth` 27h, which
  `tools/kothcheck.py` uses, match). Set to true before a skirmish (`tools/mapsweep.py ... --set
  gamecampaignshownhcnote=true`), the map's `rmIsObserverMode()` returns true. The observers are the last slots
  (with 3 players in Free for All the map plays 1v1 and player 3 observes). The human is always player 1, so the
  human is a player in such a test.
- **Bed.** A copy of WoL 1.0.15c with WoL's own `uhc.dll` (`c070d138`) and our `dinput8.dll` beside it (console
  commands, `xsErrorLog`), 1920x1080 windowed, minimized UI, its own profile. Dutch (player 1) against Otto von
  Bismarck or Queen Victoria (Hard AI), player 3 the observer.

| Run | Maps | Observer box | Result |
|---|---|---|---|
| 1 | `ESOC_Arizona`, repaired (first version) | on | The map did not compile: the repair had made 4 strings longer than 127 characters (`Token Error 0006: string is too long`). Fixed in `observer_maps.py`. |
| 2 | `ESOC_Arizona`, repaired | on | No XS error. Players 1 and 2 got their 14 starting units, player 3 only its bat, which the trigger turned into `CinematicBlock` (an AI observer); the Town Centers stand where a 2-player map puts them. The trigger script (718 KB) calls WoL's `kbGetTechID` 3,556 times. |
| 3 | `ESOC_Arizona`, repaired, plus the test line (the host sees the panel) and WoL's observer UI files over the normal names (what WoL's DLL does for an observer) | on | The panel deploys (picture 14). Player 1 researched Hunting Dogs and Gang Saw from the console (`researchByID`): "Techs Completed" shows a dog and a saw at 0:48 and 1:18 (picture 12, bottom). Villagers are counted as economic units, 6 against 12 (picture 13, bottom). |
| 4 | the same with step 1 only (`--switch-only`): the IDs as ESOC wrote them | on | The same two researches show two other techs' icons (picture 12, top), and villagers fill "Military Unit Population" (picture 13, top): JTMaston's "icons not correlating". |
| 5 | `ESOC_Bengal`, `NEWMagdalena`, `vividlyKashmir`, repaired | on | No XS error on any; on each, players 1 and 2 got their start (14 to 17 units) and player 3 only its bat. |
| 6 | `ESOC_Arizona`, repaired | off | No XS error; all three players got their start (15, 15 and 14 units): with the box unticked the map is an ordinary 3-player map, as before the repair. |

Not covered: a human observer (it needs a second game joining a LAN host: multiplayer), WoL's DLL's own observer
part (the file swap, the resolution message, removing the observer's units), saved games.

### Every map, without changing its generation (#81, question 4)

**What the ESOC maps do already.** In observer mode an ESOC map takes the observers out of its own generation: it
counts the real players from the teams (`PlayerNum` 2, 4 or 6, with `rmGetIsFFA()` as 1v1), sizes the map with that
count (`size = 2*sqrt(PlayerNum*playerTiles)`), places only teams 0 and 1 (`rmSetPlacementTeam`), and gives each
observer a bat. So in these maps an observer does not change the map or its resources (JTMaston's concern with (b)).
The cost is that each map is written for it, and the panel supports 1v1, 2v2 and 3v3 with the observers in the last
slots and the teams in order (WoL's DLL picks the first observer the same way: where the team changes).

**The other maps** (177 of the 213) use `cNumberNonGaiaPlayers` everywhere (208 of the 209 maps with an `.xml`), so
an observer slot would make the map bigger, add a start, mines and hunts for it, and change every per-player
constraint. Two ways to keep their generation as it is:

1. **Data only, map by map.** The four lines ESOC uses at the top of `main()` (count the real players, use that count
   for size and placement) plus the panel in an include file. A map author writes
   `int PlayerNum = obsRealPlayers();` instead of `cNumberNonGaiaPlayers` and calls `obsPanel();` at the end of
   `main()`. That is the "simple way to inject it in future maps". 193 of the 209 maps already call
   `wotta_triggers()` from `RM4\triggers\triggerLoader.xs` (WoL's own include), so the panel's include can be added
   there once; the per-map part is the player count, which only the map can change.
2. **The DLL hides the observers from the map script.** The random map generator would see only the real players
   (its player count, `cNumberNonGaiaPlayers`, `cNumberPlayers`, the placement functions), and the observers would be
   added to the world afterwards, with no units. That works on every map with no edit. What we found in the game's
   code: the game writes `cNumberPlayers` and `cNumberNonGaiaPlayers` into the map script from the world's player
   count, and `cNumberTeams` from the generator's teams; `rmPlacePlayersCircular` places only the players that have no
   location yet. So a DLL can write the two counts without the observers and give each observer a location before
   the map script runs: the circle is then shared by the real players only, and the observers get nothing from the
   map (its loops end before them), except the unit that keeps them in the game. Not yet read: `cNumberTeams` and
   the team functions, line placement, player areas, and what the game does with a player the map gave nothing. It is the most work of the options, and the
   same DLL would be needed by every player in the game (it decides what the map generates).

**The panel on every map.** The panel is trigger code (about 9,000 lines) that the map writes at generation. To run
it on maps that do not carry it, either the include of way 1, or a DLL that adds the trigger code itself to every
map (the same text, from one file); both reuse ESOC's panel as JTMaston asked. Its fixed layout (1v1 to 3v3, team
order) stays in either case.

### Resolutions 720p to 4K, always minimized (#81, questions 5 and 6): the files

WoL's DLL swaps 12 file names for a local observer and knows 7 resolutions (1280x720, 1280x768, 1280x800, 1366x768,
1600x900, 1680x1050, 1920x1080). Each observer main layout is WoL's `uimainnew.xml` (434 gadgets) plus ESOC's panel
gadgets placed in pixels for that resolution (`uimainnewobserver1920x1080.xml` has 1,245 gadgets, 892 of them the
panel's: `Spec_*`, `RTD*`; the 1280x720 one 856), and the map's panel code has one `loadWxH()` preset per resolution
(spacings), picked by a `Spec_PresetConfig-WxH-1` gadget of the layout. With the big UI gone, these are needed:

| File | Per resolution? | Status |
|---|---|---|
| `uimainnewobserver<W>x<H>.xml` (and its `jp` twin) | yes | Rebuild the 7 from WoL's current `uimainnew.xml` (they lack 134 gadgets: oil, search buttons, colour picker ...) and add 1920x1200, 2560x1080, 2560x1440, 3440x1440 and 3840x2160 (and 1440x900, 1600x1200 if wanted). |
| `loadWxH()` preset in the panel code | yes | One per new resolution, in the shared panel code (or the include). |
| `uicommandpanelnewminobserver.xml`, `uiminimappanelnewminobserver.xml`, `uinativecommandpanel2minobserver.xml`, `uiunitselectionminobserver.xml`, `uiunitstatpanel3minobserver.xml` | no | Rebuild once from WoL's current minimized panels (the unit selection one lacks WoL's idle-military buttons). |
| `uihomecitycommandpanelobserver.xml`, `uihomecitytransportpanelheaderobserver.xml` | no | Check against WoL's current home city panels. |
| Big-UI observer copies | | Not needed (the big UI goes away). |
| The resolution list in WoL's DLL | | The 5 new resolutions must be added to WoL's DLL (its list of 7 is in its code), or the file swap done by another DLL. |

The skirmishes lasted 2 to 7 minutes; the 36 maps share the same panel code, and the repair counts were the same in
all 36 (460 unit rows, 2,065 tech rows, 1,551 tracked techs, 102 checksums, 162 rows WoL no longer has).

### Questions for JTMaston (round 2)

1. Shall the repaired 36 maps go into your next patch? (They behave as today with the box unticked. The script must be
   run again whenever `techtreey.xml` changes, or we can run it for you.)
2. Step 2, the content: which WoL units should the unit rows show per group (villagers, military, ships)? We would
   add WoL's own units to the tables, plus oil and the Great War age. Is the ESOC panel's use in every WoL map fine
   with its authors (Aizamk / ESOC)?
3. For the other 177 maps: way 1 (each map counts only the real players; we can write that change by script for all
   maps, as a data change you can read) or way 2 (a DLL; every player in a game needs it, and WoL ships its own
   `uhc.dll`)?
4. ESOC's panel supports 1v1, 2v2 and 3v3 with the observers in the last slots and the teams in order. Is that
   enough, or do you need Free for All with more than two players, or 4v4 (which leaves no slot for an observer)?
5. The resolutions: is this list right: 1280x720, 1366x768, 1600x900, 1920x1080, 1920x1200, 2560x1080, 2560x1440,
   3440x1440, 3840x2160? The new ones also have to be added to the list in WoL's `uhc.dll`: can you do that, or
   should the file swap move to another DLL?

## Round 1 (2026-11-21): diagnosis

### In short

1. **It does not work with all maps because it lives inside the maps.** The whole observer panel is trigger code that
   36 of the 213 RM4 maps carry (30 `ESOC_*`, `NEWMagdalena` and five `vividly*` maps). The lobby box already says so:
   "Observer mode. Only functionable with ESOC UI2.2 maps for now!" (string 1001474, picture 02).
2. **It broke because it is switched off, and because of a name clash.**
   - In all 36 maps the line that should read the lobby box says `if (false == true)`, so the observer branch never
     runs. No map calls `rmIsObserverMode()`.
   - With the switch turned on, the map's trigger script no longer compiles: `trigtemp.xs(736): Error 0034:
     'kbGetTechID' is already defined and cannot be a function name`. The panel code defines its own helper
     `kbGetTechID`, and `wolai.upl` now registers a syscall with the same name. Every trigger of the map is lost,
     `StartInsertion` included (WoL's DLL looks for that trigger to start its observer code). All 36 maps define that
     helper. It is the only clash (209 functions checked against `wolai.upl`, `wolPlugin.upl`, `uhc.dll` and the exe).
3. **With those two lines fixed, the panel runs again, but it was made for an older WoL UI.** The resource numbers are
   one row off (no oil), WoL's own resource panel is drawn under it, the flags are wrong for WoL's civs, villagers are
   counted as military, the unit rows show only the explorer, and with the big UI the normal unit panel covers it.
4. **The observer must be a second player.** The lobby host is always slot 1 and could not be moved to the last slot,
   so an observer is someone who joins the game. That is multiplayer, which we do not test; the AI in the last slot was
   the observer in these tests, and a test switch let the host see the panel (run 4).

### How it was tested

- A copy of WoL 1.0.15c (exe `0a277f14`), with WoL's own `uhc.dll` (`c070d138`) and our engine extension beside it
  (only to host the LAN game without clicks and to log XS errors). 1920x1080 windowed, minimized UI.
- A LAN game hosted alone: the host (Dutch, team 1), Henry Parkes (AI, team 2), John MacDonald (AI, team 3), Observer
  mode ticked, map `ESOC_Arizona`. The map was edited in the test copy only; the game files were restored afterwards.
- `test_patch.py` (round 1's script, kept for the record; `observer_maps.py` replaces it) writes the switch and a
  rename of the helper for all 36 maps into another folder.

| Run | Map edits | What happened | Pictures |
|---|---|---|---|
| 1 | switch on | The map generates in observer mode (player 3, the observer, gets only its bat), then the trigger script fails to compile (`kbGetTechID`). The game goes on with no triggers. | 03 |
| 2 | switch + rename | No XS error. The trigger runs: the observer's bat becomes `CinematicBlock` (an AI observer; a human gets `Target`), and player 3 is still alive with it 3 minutes later. The host is a player and sees the normal UI. | 04 |
| 3 | as run 2, and the observer files (the 1920x1080 main layout and the 7 panels) copied over the normal names (what WoL's DLL does for an observer) | The observer panels stay hidden (the map shows them only to an observer). The resource numbers are one row off. | 05, 11 |
| 4 | as run 3, and the test line that makes the host an observer for the map's code | The panel deploys and updates: fog off, minimap revealed, both players' bars and unit rows. The faults are listed below. | 06-09 |
| 5 | as run 4, with the big UI | The normal big unit panel covers the observer's player rows; the player names and the "DO (R)" box are gone. | 10 |

### What is wrong in the panel (runs 3-5)

- **Resources** (picture 11): WoL's art draws oil, food, wood, coin and villagers; the old file puts the food number on
  the oil row, leaves food empty, and has no villager count. The panel code reads resources 0, 1, 2, 6 and 7, never
  oil. Ages are shown as `score_age_(age+1)`, with no Great War icon.
- **Two panels in one place** (picture 08): WoL's own minimized resource panel is drawn under the observer's player
  rows, and their numbers overlap ("6 / 10" over "6 / 10", "100" over "104").
- **Flags** (picture 09): the Dutch host shows a wrong portrait, and Henry Parkes shows the Dutch flag.
- **Unit counts**: "Economic Unit Population" stays N/A and "Military Unit Population" counts every unit, villagers
  included (6 against 10 after 150 s); the unit rows show the explorer only. Round 2 found the cause: the tables'
  stock IDs (above).
- **Missing WoL UI**: `uimainnew.xml` has 134 gadgets that `uimainnewobserver1920x1080.xml` lacks: the oil display, the
  building search buttons and counters, the colour picker, the extra buttons (fog, blackmap, screenshot, help, hero),
  `mainGameMenuMP-PlayerStatusButton`. The minimized unit selection panel lacks WoL's idle-military buttons.
- **Big UI** (picture 10): observer copies exist only for the minimized panels, so the big panels are drawn over the
  observer layout.
- **Resolutions**: WoL's DLL has observer layouts for 7 resolutions only. Any other one (1920x1200, 2560x1440,
  3840x2160 ...) gets "Your resolution is not supported by the observer interface". This is read from the DLL; it was
  not seen, since it needs a real observer.

### Pictures (`media/`)

| # | File | What it shows |
|---|---|---|
| 01 | `01-lobby-observer-box.jpg` | The test lobby: three players, Observer mode ticked, ESOC Arizona |
| 02 | `02-lobby-observer-tooltip.jpg` | The box's tooltip: "Only functionable with ESOC UI2.2 maps for now!" |
| 03 | `03-run1-trigger-compile-error-player-view.jpg` | Run 1: the game runs with no triggers (the XS error is in the log) |
| 04 | `04-run2-fixed-map-player-view.jpg` | Run 2: the host's normal view, triggers working |
| 05 | `05-run3-observer-files-as-player-ui.jpg` | Run 3: the observer layout files loaded, panels hidden |
| 06 | `06-run4-observer-ui-emulated.jpg` | Run 4: the observer panel at the start |
| 07 | `07-run4-observer-ui-emulated-150s.jpg` | Run 4 after 150 s |
| 08 | `08-run4-crop-player-rows.jpg` | Run 4: the player rows over WoL's resource panel |
| 09 | `09-run4-crop-top-bar.jpg` | Run 4: the top bar, wrong portrait and flag, economic population N/A |
| 10 | `10-run5-observer-ui-big-ui.jpg` | Run 5: the big UI covering the observer rows |
| 11 | `11-resource-panel-current-vs-observer-file.jpg` | Left: WoL's current resource panel. Right: the observer file, one row off |
| 12 | `12-tech-icons-before-after.jpg` | Round 2: "Techs Completed" after Hunting Dogs and Gang Saw; top before the repair, bottom after |
| 13 | `13-population-bar-before-after.jpg` | Round 2: the population bars; top before (villagers as military), bottom after |
| 14 | `14-repaired-panel-1920x1080.jpg` | Round 2: the repaired map's panel, 150 s into a skirmish (test line on, the host shown as observer) |
