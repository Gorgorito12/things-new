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
- [I] So in this install the observer mode does not switch on. [?] Not run in game.
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

**Testing:** no key of this project has been tested in multiplayer. [?] Whether two copies on this PC can play a LAN game
is the first thing to check.
