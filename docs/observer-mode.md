# Observer mode: legacy, WoL's DLL and DE

Read on 2026-11-06, with the goal of a better observer mode for multiplayer in legacy. Nothing here has been run in a
multiplayer game. [O] is observed, [I] is inferred, [?] is unknown.

Evidence: `rea/evidence/wol-uhc-c070d138/observer-20261106.json`, `rea/evidence/age3y-b1a1dab7/observer-20261106.json`
(gitignored).

## Stock legacy

- [O] `age3y.exe` has no observer mode: "observ", "spectat", "referee" and "watcher" appear nowhere in it, as ASCII or
  UTF-16.
- [O] It has a replay system. `BRecordGame` plays a `BGameStream`, and each update holds the camera, the update time, the
  commands, the selected units and the sync data (`getUpdate` 0x838171, tag `SG`).
- [O] The replay panel (0x75E9A7) has the player, fog, view lock, fast play, pause, progress bar and bookmarks: most of
  what an observer needs.
- [O] `startUpdatePlayback` (0x91046E) has a state for waiting for data: "isBuffered && !buffering". The check 0x90FA57
  compares two positions of the stream with a threshold at `[this+40h]`.
- [I] So playback was built to wait for data that is still arriving. [?] Whether a stream fed live works.
- [O] A record file is `l33t`, the uncompressed size, then one zlib stream.
- [I] The size in the header suggests that the file is finished at the end of the game. [?] Not confirmed: in a skirmish
  `config("RecordGame")` wrote no file at all, so that test says nothing.

## WoL's DLL (c070d138)

- [O] Active when a lookup by name of `StartInsertion` (the exe's 0x90DFB0) finds something (0x1005BA00). The maps create
  a trigger of that name.
- [O] `rmIsObserverMode` reads `GameSettings` index 0x37, the lobby's `mpsetup-ObserverModeCheckButton`.
- [O] The first observer's ID comes from where the team changes: 3, 5 or 7, or the number of players (0x1005B710). So
  observers are real players in the last slots, and the teams must be in order.
- [O] `trClearObserverOwnedObjects` (0x100409F0) goes through those players and removes every unit that is not a `Target`.
- [O] With a supported resolution, a local observer gets 12 replaced UI files, for 7 resolutions (0x10040C50). Others get
  the message "Your resolution is not supported".
- [O] The maps do the rest: 36 of the 213 maps in `RM4` have about 9,000 lines of observer UI, written as trigger code by
  the map, with a bat per observer so the player stays alive.
- [O] All 36 say `if (false == true)` where the flag is set, and `StartInsertion` is created inside that branch. No map
  calls `rmIsObserverMode`, and the DLL has no text that rewrites it.
- [O] So in this install the observer mode does not switch on: run in game on 2026-11-21, below.
- [I] Such an observer is a full peer of the game: a slot, its own simulation, and its share of the lag. No code was found
  that takes it out of the sync.

## DE

REA has not read this part: its analysis of the exe does not finish (`docs/de-parity.md`), and most of the simulation is
encrypted on disk. This rests on strings and on `tools/re/pe64.py`.

- [O] Lobby: `allowSpectators`, `observerDelay`, `observerPassword`, `MPESOGameList_ObserveButton`. Server:
  `/game/advertisement/startObserving`.
- [O] In the game: `observingCycleCurrentPlayer`, `observingToggleFogOfWar` ("without effecting simulation"),
  `mainGameMenuMP-ObserverSpeedPause`, `-RealTime` and `-Unlimited`.
- [O] `Session::`: "observer can't send data message", and the same for sync and checksum messages to the relay.
- [O] Those `Session::` strings and the two console names have no code reference in the file. `observerDelay` has one, in
  fn 0x1727330, not read.
- [I] Observers stand outside the lockstep, take the game from a relay server with a delay, and send nothing.

## WoL's observer files against WoL's current UI (2026-11-21, #81)

JTMaston: "broke many versions ago and it doesnt work with all maps". Read from `C:\AoE3-UHC-WoLReal12\data`
(WoL 1.0.15c, the same files as the Steam install):

- [O] WoL's DLL swaps 12 file names when the local player is an observer (its strings at 0xE6EF4-0xE76B8):
  `uimainnew.xml` for `uimainnewobserver<res>.xml` in 7 resolutions (1280x720, 1280x768, 1280x800, 1366x768,
  1600x900, 1680x1050, 1920x1080, each with a `jp` twin), and the **minimized** panels `uicommandpanelnewmin`,
  `uiminimappanelnewmin`, `uinativecommandpanel2min`, `uiunitselectionmin`, `uiunitstatpanel3min`, plus
  `uihomecitycommandpanel` and `uihomecitytransportpanelheader`, for their `...observer.xml` copies. Any other
  resolution gets "Your resolution is not supported by the observer interface. Adjust your resolution and restart
  the match to gain full observer functionality."
- [O] The observer files are older than the UI around them. `uimainnew.xml` has 134 gadget names that
  `uimainnewobserver1920x1080.xml` lacks, among them the whole oil display (`minimapPanel-fame`,
  `SettlerCountDialog-fame`, `-fameLabel`: oil is WoL's fourth resource), the building search buttons
  (`search*Button`, `count*Field`), the colour picker (`farbSetz*`, `color0`-`color26`), `extraButton*` and
  `mainGameMenuMP-PlayerStatusButton`. The minimized unit selection panel has WoL's idle-military buttons
  (`Inf-/Cav-/Artillery-idle-button`, `IconALL` ...), which `uiunitselectionminobserver.xml` lacks.
- [O] The maps' observer UI (Aizamk's ESOC code, about 9,000 lines in each of the 36 maps) reads resources 0, 1,
  2, 6 and 7 (`kbResourceGet`), never oil, and shows ages with `score_age_(age+1)`, which has no WoL Great War
  icon.
- [I] So the observer files were made from an earlier WoL UI and only exist for the minimized panels; with the
  big UI (`optionminimizedui` off) an observer would get the observer main layout with the normal big panels
  (seen in game below).
- [O] The lobby box's tooltip (string 1001474) already says "Observer mode. Only functionable with ESOC UI2.2 maps for
  now!". That is what "does not work with all maps" means: the panel is trigger code inside each map, and 36 of the
  213 `RM4` maps carry it (30 `ESOC_*`, `NEWMagdalena`, five `vividly*`), in two template versions (3,158 and 3,173
  `cEf` lines). Every other map ignores the box.

## In game (2026-11-21, #81)

Bed `C:\AoE3-UHC-WoLReal10` (own profile, 1920x1080 windowed, minimized UI): WoL's exe 0a277f14 and WoL's `uhc.dll`
c070d138, our `dinput8.dll` beside it (`engine-ext.cfg`: `perfExecFile`, `multipleInstances background`,
`xsErrorLog`, `perfStats`, `lanAutoStart host`). A LAN game hosted alone, 3 players: the host (Dutch, team 1),
Henry Parkes (team 2) and John MacDonald (team 3) as AIs, Observer mode ticked, `ESOC_Arizona` patched in the copy
only. Screenshots and the patch script: `wol-fixes/observer/`.

- [O] **The host cannot be the observer on one PC.** The host is always slot 1. Posted drags, a real drag (the one real
  input of the test, about 10 s), clicks and right-clicks on the open slot, and the whole AI list (it ends with "Random
  Personality") did not move the host. In the stock lobby the slot keeps the `-xfer` gadget at index 5 (`[slot+34h]`,
  setter 0x777B20, bound at 0x8B88C1), but no code was found that reads it: the slot's event handler (vtable 0xB93014,
  entry +38h = 0x776702) handles the team, civ, AI, ready and kick gadgets only, and the page's handler 0x8B9846 has no
  slot move (REA `rea/evidence/age3y-b1a1dab7/r1121-f-lobby-slots.json` plus capstone; a bounded search, and WoL's DLL
  replaces `MPGameSetupPage` / `MPPlayerSlot` with its own classes). [I] So an observer is a second player who joins
  and takes the last slot, which needs a second game: multiplayer, not tested here. The AI in slot 3 was the observer
  instead.
- [O] **Run 1, the switch alone** (`if (rmIsObserverMode() == true)`): the map compiles, the observer branch runs (player
  3 gets only its `Bat`), and then the trigger script fails: `trigtemp.xs(736): Error 0034: 'kbGetTechID' is already
  defined and cannot be a function name`, `Error 0003: could not compile file 'trigtemp.xs'`. The map's panel code
  defines a helper `kbGetTechID`, and `wolai.upl` (WoL's `customSyscalls` plugin) now registers a syscall of that name.
  It is the only clash: the 209 functions the trigger code defines were checked against the names in `wolai.upl`,
  `wolPlugin.upl`, `uhc.dll` and the exe. All 36 maps define it. [I] This is "broke many versions ago": the day the
  syscall was added, every observer map lost all its triggers, `StartInsertion` included.
- [O] **Run 2, + the helper renamed** (`obsGetTechID`, 7 places): no XS error; the trigger runs, and player 3's bat
  becomes `CinematicBlock` (an AI observer; a human gets `Target`). Player 3 was still alive with it 3 minutes later.
  The host (a player) sees WoL's normal UI.
- [O] **Run 3, + the observer files copied over the normal names** (the 1920x1080 main layout and the 7 panels) (what WoL's DLL does for a local observer, shown
  to the host): the observer panels stay hidden (the map shows them only when `trCurrentPlayer()` is an observer), and
  the resource column is one row off: WoL's art draws oil, food, wood, coin and villagers, the old file puts the food
  number on the oil row, leaves food empty and has no villager count.
- [O] **Run 4, + the map told that the local player is an observer** (`FP=trCurrentPlayer()+2`, test only): the panel
  deploys with no XS error and updates (fog off, minimap revealed, the two players' bars and unit rows), with these
  faults: the top bar shows a wrong portrait for the Dutch host and the Dutch flag for Henry Parkes; "Economic Unit
  Population" says N/A while "Military Unit Population" counts every unit (villagers included: 6 vs 10 after 150 s);
  the unit rows show the explorer only; WoL's own resource panel is drawn under the observer's player rows, and their
  numbers overlap ("6 / 10" over "6 / 10", "100" over "104").
- [O] **Run 5, run 4 with the big UI**: the normal big unit panel (the curtains and the Age of Empires logo) covers the
  middle of the observer's player rows; the player names and the right "DO (R)" box are gone.
- [I] The flags and the unit counts come from the map's tables, written for the stock civs and units of ESOC 1.12.2:
  WoL's civs and villager units do not match them. [?] Not traced line by line.
- [?] Not seen: a real local observer (it needs a second game), so WoL's DLL's own part (`trClearObserverOwnedObjects`,
  the file swap, the "Your resolution is not supported" message at another resolution) was not run; a resolution test
  needs that observer too.

## What can be done in legacy

**1. Observer as a peer, from the DLL.** Same model as WoL's, without the map. A lobby choice marks the observers; at the
start of a game every peer removes their units, keeps them out of victory and drops their commands; the observer's own
game turns the fog off locally and shows a panel. It works on any map and any resolution, and it needs the same DLL on
every peer. It still takes a slot and adds that peer's lag.

**2. Observer outside the game, from the replay.** DE's model without its server. One player's DLL taps each `BGameStream`
update and sends it to the observers over its own socket, with a delay; the observer's game plays them with `BRecordGame`
and the stock panel. It takes no slot, adds no lag to the players, has a delay against cheating, and needs no map or team
order. [?] What must be proved first: that playback accepts a stream fed live, what the stream needs at its start, and how
an observer reaches a player behind a router.

### Phase 2 for WoL: the two options (for the user's decision; nothing built)

**(a) Data pack: repair WoL's own observer mode.** Two edits per map make it run again (both tested on
`ESOC_Arizona`, `wol-fixes/observer/test_patch.py` writes them for all 36): the switch (`if (false == true)` →
`if (rmIsObserverMode() == true)`, so nothing changes unless the lobby box is ticked) and the helper rename
(`kbGetTechID` → `obsGetTechID`). Then the content: oil, the Great War age, WoL's civ flags and its villager units in
the map's panel code (the same code in the 36 maps, so one change copied 36 times), and the swapped files
(`uimainnewobserver<res>` in 7 resolutions plus the 7 panels) rebuilt on WoL's current `uimainnew.xml` and
minimized panels. What it takes: S for the two edits (done as a script), M for the panel code (find the civ and
unit tables, add oil and the age), L for the UI files (7 hand-placed main layouts). Limits that stay: only those 36
maps (the UI lives in the map), only 7 resolutions and the minimized UI (WoL's DLL picks the files), the observer
is a full peer in the last slot (so it needs a second player's game: multiplayer), and the teams must be in order.
It needs WoL's DLL: `rmIsObserverMode`, the file swap and the lobby box are its code, not ours.

**(b) Our key, "observer as a player" (option 1 above).** A lobby choice marks the observers; at the start of a
game every peer removes their units, keeps them out of victory and drops their commands; the observer's own game
turns the fog off locally and shows a panel built from data refs (every resolution, every map, the current UI).
What it takes: L (the lobby flag, the unit removal and victory exclusion in the simulation, a local fog-off, and
the panel; REA work on the defeat check and the command path). It needs the same DLL on every peer, it still
takes a slot and that peer's lag, and it would have to coexist with WoL's own observer code (both read the same
lobby box). Multiplayer is not tested in this project, so its sync could only be argued, not shown. Like (a), an
observer is a second human in the game, so it cannot be shown on one PC either; what one PC can show is the panel
and the local fog-off, with a test switch that makes the host an observer, as run 4 did for the map's panel.

**Proposed default (2026-11-21):** (a)'s two edits first, since they are small, change nothing with the box unticked,
and bring back what ESOC built on the 36 maps; then decide on the content and the UI files, or on (b), after
JTMaston has seen run 4's screenshots.

**Testing:** no key of this project has been tested in multiplayer, and this project does not test multiplayer (the
user's decision of 2026-11-13). A real observer, in either option, is checked by WoL's team in their own games.
