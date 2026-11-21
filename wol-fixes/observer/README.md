# Observer UI (#81): diagnosis

Request (JTMaston): "the Observer UI broke many versions ago and it doesn't work with all maps". This folder holds the
diagnosis only: nothing here is a fix to install. Tested on 2026-11-21 on one PC, single player.

## In short

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

## How it was tested

- A copy of WoL 1.0.15c (exe `0a277f14`), with WoL's own `uhc.dll` (`c070d138`) and our engine extension beside it
  (only to host the LAN game without clicks and to log XS errors). 1920x1080 windowed, minimized UI.
- A LAN game hosted alone: the host (Dutch, team 1), Henry Parkes (AI, team 2), John MacDonald (AI, team 3), Observer
  mode ticked, map `ESOC_Arizona`. The map was edited in the test copy only; the game files were restored afterwards.
- `test_patch.py` writes the edits for all 36 maps into another folder (it never writes the RM4 folder):
  `python -I test_patch.py "<WoL>\RM4" <out folder>` for the switch and the rename, `--emulate-observer` to also add
  run 4's test line. The patched `ESOC_Arizona.xs` is byte-identical to the one tested.

| Run | Map edits | What happened | Pictures |
|---|---|---|---|
| 1 | switch on | The map generates in observer mode (player 3, the observer, gets only its bat), then the trigger script fails to compile (`kbGetTechID`). The game goes on with no triggers. | 03 |
| 2 | switch + rename | No XS error. The trigger runs: the observer's bat becomes `CinematicBlock` (an AI observer; a human gets `Target`), and player 3 is still alive with it 3 minutes later. The host is a player and sees the normal UI. | 04 |
| 3 | as run 2, and the observer files (the 1920x1080 main layout and the 7 panels) copied over the normal names (what WoL's DLL does for an observer) | The observer panels stay hidden (the map shows them only to an observer). The resource numbers are one row off. | 05, 11 |
| 4 | as run 3, and the test line that makes the host an observer for the map's code | The panel deploys and updates: fog off, minimap revealed, both players' bars and unit rows. The faults are listed below. | 06-09 |
| 5 | as run 4, with the big UI | The normal big unit panel covers the observer's player rows; the player names and the "DO (R)" box are gone. | 10 |

### What is wrong in the panel today (runs 3-5)

- **Resources** (picture 11): WoL's art draws oil, food, wood, coin and villagers; the old file puts the food number on
  the oil row, leaves food empty, and has no villager count. The panel code reads resources 0, 1, 2, 6 and 7, never
  oil. Ages are shown as `score_age_(age+1)`, with no Great War icon.
- **Two panels in one place** (picture 08): WoL's own minimized resource panel is drawn under the observer's player
  rows, and their numbers overlap ("6 / 10" over "6 / 10", "100" over "104").
- **Flags** (picture 09): the Dutch host shows a wrong portrait, and Henry Parkes shows the Dutch flag.
- **Unit counts**: "Economic Unit Population" stays N/A and "Military Unit Population" counts every unit, villagers
  included (6 against 10 after 150 s); the unit rows show the explorer only.
- **Missing WoL UI**: `uimainnew.xml` has 134 gadgets that `uimainnewobserver1920x1080.xml` lacks: the oil display, the
  building search buttons and counters, the colour picker, the extra buttons (fog, blackmap, screenshot, help, hero),
  `mainGameMenuMP-PlayerStatusButton`. The minimized unit selection panel lacks WoL's idle-military buttons.
- **Big UI** (picture 10): observer copies exist only for the minimized panels, so the big panels are drawn over the
  observer layout.
- **Resolutions**: WoL's DLL has observer layouts for 7 resolutions only (1280x720, 1280x768, 1280x800, 1366x768,
  1600x900, 1680x1050, 1920x1080). Any other one (1920x1200, 2560x1440, 3840x2160 ...) gets "Your resolution is not
  supported by the observer interface". This is read from the DLL; it was not seen, since it needs a real observer.

The flags and the unit counts come from the map's tables, written for the stock civs and units of ESOC 1.12.2. This
is inferred, not traced line by line.

### Not tested

- A real human observer (it needs a second game joining the host): WoL's DLL's own observer part (removing the
  observer's units, the file swap, the resolution message) was not run.
- Multiplayer of any kind. The observer box unticked with the switch on (it should behave as today, since the switch
  then reads false; not run).

## Pictures (`media/`)

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

## Two ways forward (nothing built yet)

**(a) Repair WoL's own observer mode (data only).**
- Step 1, small: the two map edits above in the 36 maps. Nothing changes unless the lobby box is ticked, and ESOC's
  panel comes back on those maps as it is (with the faults listed above).
- Step 2, medium: update the panel code inside the maps (the same code in all 36): oil, the Great War age, WoL's civ
  flags, WoL's villager units.
- Step 3, large: rebuild the observer UI files from WoL's current UI, in the 7 resolutions WoL's DLL knows (7 main
  layouts by hand, plus the 7 panels).
- What stays: only those 36 maps, only 7 resolutions and the minimized UI (WoL's DLL picks the files), the observer
  takes a player slot (the last one, teams in order), and it needs WoL's DLL (`rmIsObserverMode`, the file swap and the
  lobby box are WoL's DLL code).

**(b) A new "observer as a player" option in our DLL.**
- A lobby choice marks the observers. At the start every player's game removes the observers' units, keeps them out of
  victory and defeat, and ignores their commands; the observer's own game turns the fog off and shows a panel built from
  the game's data (every map, every resolution, WoL's current UI and resources).
- Large: lobby, simulation and UI work, and the same DLL on every player's PC. The observer still takes a slot and adds
  its lag, and it would sit beside WoL's own observer code (both would read the same lobby box).
- We can show the panel and the fog on one PC with a test switch; a real observer can only be checked by your team in
  your own games.

**Our proposal:** (a) step 1 first, as a small data change, then step 2 or (b) after you have seen pictures 06-10.

## Questions for JTMaston

1. Which observer do your players use today, if any: ESOC's map panel (these 36 maps), or only the replay viewer?
2. Is the panel in pictures 06-09 the one that "broke", or do you remember something else (another layout, other maps)?
3. Should the two map edits (step 1) go into the 36 maps now, knowing the panel still has the faults above?
4. Would you rather keep ESOC's panel (a), or have an observer that works on every map and resolution (b)?
5. Which resolutions do your players use? WoL's DLL has observer layouts for 7 only (no 1920x1200, 2560x1440 or 4K).
6. Does an observer ever play with the big UI, or always the minimized one?
