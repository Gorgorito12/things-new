# Developer guide

How to build `UHC.dll`, test it safely, add a feature, and reverse engineer `age3y.exe` the way
this project did. For using the DLL in a mod, see [modding-guide.md](modding-guide.md); for the
internals of each feature, [how-it-works.md](how-it-works.md).

## 1. Build

**Requirements:**
- Windows, with Visual Studio's "Desktop development with C++" workload: MSVC x86 tools and
  MASM (`ml.exe`). This project uses Visual Studio 2026; 2022 should work but was not tested.
- CMake 3.25 or later. The copy bundled with Visual Studio works:
  `<VS>\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe`.
- Python 3, for the tools. The capstone checks in [section 6](#6-reverse-engineering-workflow)
  also need `pip install capstone pefile`, preferably in a virtual environment.

**Commands**, from an "x86 Native Tools Command Prompt" or with full paths:

```
cmake -S . -B build -G "Visual Studio 18 2026" -A Win32
cmake --build build --config Release
dumpbin /exports build\Release\UHC.dll
```

- The game is 32-bit, so configure with `-A Win32`; `CMakeLists.txt` stops an x64 configure on
  purpose. For Visual Studio 2022 the generator is `"Visual Studio 17 2022"`.
- The output is `build\Release\UHC.dll`, linked with the static C runtime, so it needs no
  redistributable.
- `dumpbin /exports` must list `_UHCMain@0`, the exact name the loader asks for.

**Layout:**

| Path | What |
|---|---|
| `src/dllmain.cpp` | Host guard, cfg load, the feature loop. |
| `src/config.*` | The `uhc.cfg` parser. |
| `src/patch.*`, `src/site.h` | Verify-then-patch helpers. |
| `src/features.h` | The feature registry (`kFeatures`) and the handled keys (`kHandledKeys`). |
| `src/features/*.cpp` | One apply function per key or key group. |
| `src/hooks/*.asm` | The MASM hooks; `common.inc` holds `TRACE_ONCE`. |
| `src/unittypes.*` | Extra abstract unit types requested by features. |
| `src/generated/sites.h` | Expected stock bytes, written by `tools/gen_sites.py`. Do not edit it. |
| `tools/` | `gen_sites.py`, the data tools and `re/` (tracers); see [tools/README.md](../tools/README.md). |
| `docs/` | This guide, the [modding guide](modding-guide.md) and the research notes. |
| `examples/` | A complete `Startup\uhc.cfg`. |

## 2. A safe test bed

Never modify the Steam install. Work on a copy:

1. **Copy the game folder**, e.g.
   `robocopy "<Steam>\steamapps\common\Age Of Empires 3\bin" C:\AoE3-UHC-Test /E`.
2. **Replace the copy's `age3y.exe`** with a UHC-patched exe
   ([modding guide, section 1](modding-guide.md#getting-an-exe-with-the-uhc-loader)).
3. **Copy `build\Release\UHC.dll`** next to it, and `examples\Startup\uhc.cfg` into its
   `Startup\` folder.
4. **Start it** any way you like: a double-click, or from PowerShell:

   ```powershell
   Start-Process -FilePath C:\AoE3-UHC-Test\age3y.exe
   ```

   `UHC.dll` makes the exe's folder the working directory, and the log's second line,
   `UHCMain: working directory …`, confirms it.

5. **Read `UHC.log`** next to the exe. Delete it before each run: it is appended.

**One copy per test, when several people or sessions test at once.** A copy is about 3.8 GB and
takes seconds to make: `robocopy C:\AoE3-UHC-Test C:\AoE3-UHC-Poison /E /XF UHC.log`. Give it its own
cfg and data. The `damageOverTime` test copy gets its data from `tools/dot_testdata.py`. Only one
`age3y.exe` should run at a time, so check `Get-Process age3y` before starting one.

**Shared profile.** The copy uses your normal user profile
(`Documents\My Games\Age of Empires 3\Users3\<profile>.xml`, a UTF-16 file). A first run of a
copy may reset the resolution there (`optiongrfxres`). Back the profile up before testing.

**Safety checks**, before and after a session:

```powershell
$root = "<Steam>\steamapps\common\Age Of Empires 3\bin"
function Listing { Get-ChildItem -LiteralPath $root -Recurse -File |
    ForEach-Object { "{0}`t{1}`t{2}" -f $_.FullName.Substring($root.Length), $_.Length, $_.LastWriteTimeUtc.ToString("o") } }
Listing | Set-Content steam-before.tsv                        # once, before working
Compare-Object (Get-Content steam-before.tsv) (Listing)       # later: must print nothing
(Get-FileHash "$root\age3y.exe" -Algorithm SHA256).Hash       # must be B1A1DAB7…11D9D
```

Use the same `Get-ChildItem` options both times: `-Force` adds hidden files and makes the two
listings differ. `python -I tools/testbed.py safety record` / `safety check` does the same.

### Driving the game unattended

`tools/testbed.py` plays a test with no clicks: it starts the copy, builds a small map with the
units you name, loads it as a game, lets them fight, and reads the result from `UHC.log` and
from memory. Every feature test of `dodgeAnyUnit` was run this way. A full cycle:

```
python -I tools/testbed.py deploy test.cfg      # UHC.dll + Startup\uhc.cfg (adds perfExecFile)
python -I tools/testbed.py map uhcdodge p1=Explorer*1@0.45,0.48 p2=Musketeer*4@0.55,0.51 tech1=YPDodge
python -I tools/testbed.py launch               # +noIntroCinematics, waits for the main menu
python -I tools/testbed.py scenario uhcdodge    # generate, save, reload as a game, unpause
python -I tools/testbed.py wait 30              # 30 s of game time
python -I tools/testbed.py log --grep dodged
python -I tools/testbed.py units                # ID, player, proto, HP, position of every unit
python -I tools/testbed.py shot out.png 2       # works while the window is covered
python -I tools/testbed.py close                # also deletes the uhc-* scenarios it saved
```

`launch` to a running fight takes about three minutes. How it works, and what it took to get
there:
- **Commands reach the game only through `perfExecFile`** (`src/features/perf.cpp`): every 30
  frames the DLL runs each line of `<bed>\uhc-exec.txt` as a console command and deletes the
  file. Posted key presses never reach the console. `deploy` adds the key to the cfg.
- **The map** is a random map script written to the copy's `RM3` folder. `p<N>=Proto*count@x,z`
  places units of player N (x, z are fractions of the map side); `tech<N>=Name` adds a trigger
  that makes a tech active for player N. A trigger's tech parameter is the tech's **index in
  `techtreey.xml`**, which `map` looks up: a name such as `cTechYPDodge` compiles to tech 0 with
  no error. The game writes what the triggers compiled to in
  `Documents\My Games\Age of Empires 3\Trigger3\trigtemp.xs`, and a dump of the map script in
  `…\RM3\Age3RM<name>.dmp.txt`.
- **What a scenario's triggers can and cannot do** (checked 2026-10-29): Change Unit Type, Kill,
  Damage Unit, Unit Create, Set Tech Status, Grant Resources and Move From Area (`go<N>=`) work;
  the unit-order effects `Unit Work` and `Unit Build Building` do nothing. Give such orders with
  the real mouse: `exec 'uiLookAtAndSelectUnit(<id>)' 'uiLookAtUnit(<target id>)'`, then
  `rclick 1277 757 right` (the looked-at unit is at the centre of the view); to build, select the
  builder, `exec 'tis("<Proto>")'`, then `rclick <x> <y>`. The first real click after the window
  takes the focus is often lost: repeat it. Synthetic key presses (`rkey`) do not reach the
  game's hotkeys, not even the stock Delete.
- **The editor route finishes buildings:** a `PlaceAsFoundation` proto placed by the map is a
  complete building once the scenario is reloaded, so place a foundation in game (see above).
  Scenario players lack their civ's start techs: add `tech1=Age0British` (or the civ's own Age0
  tech) when a building is "not enabled". In these tests player 1 was Spanish and player 2 British.
- **Placement:** big buildings (BloodFactory) or tight clusters (`House*8`) may not be placed by
  the map at all; create them with `"at1=Unit Create;…;Location=pt:<x>,<z>"`. `p0=` places Gaia
  units (hunts), `sea=<SeaType>` makes a water map, `units --los` shows each unit's line of sight.
- **Timed events:** `"at<seconds>=<Effect>;<Param>=<value>;…"` runs any trigger effect listed in
  `trigger3\typetest.xml` once, that many seconds into the game, for example
  `"at20=Change Unit Type;SrcObject=g0;ProtoUnit=Grenadier"` (transform),
  `"at5=Set Tech Status;PlayerID=1;TechID=tech:YPDodge;Status=2"`, `Kill`, `Convert`,
  `Damage Unit`, `Unit Create`. `g<i>` stands for every unit of the i-th `p<N>=` group (counted
  from 0), `g<i>.<k>` for one of them, `tech:<Name>` for a tech's index, `pt:<x>,<z>` for a point.
- **The scenario route**, found during the performance work (performance.md, §8):
  `startRandomGame(true)` opens the editor, `startRandomGame2("<map>", 2, seed, "", false, 2, 1,
  0, false)` generates the map in it (two teams, so the players are enemies),
  `saveScenario("uhc-<map>")` writes `Documents\My Games\Age of Empires 3\Scenario\…`,
  `leaveGame()` returns to the menu and `loadScenario` plays it. The players have no AI, which
  keeps a test deterministic: units still attack enemies in range on their own.
- **The game pauses when it loses focus** unless `config("DontPauseWhenLosingFocus")` is set;
  `launch` and `scenario` send it, and `scenario` sends `pause(0)` after loading.
- **Signals, most reliable first:** a feature's own `log` option; `hook reached` lines; memory
  (`units`, or `tools/re/debugger.py`); screenshots. The game's own log is
  `Documents\My Games\Age of Empires 3\Age3Log.txt`.
- **Video:** once a feature works, `record <out.mp4> [seconds] [fps] [width]` films the window
  in real time (default 30 s, 10 fps, 1280 px wide), with the same PrintWindow capture as `shot`,
  so it works while the window is covered. It encodes H.264 with ffmpeg: `UHC_FFMPEG`, `PATH`, or
  the static build in `C:\Tools\ffmpeg\ffmpeg.exe` (taken from the PyPI package
  `imageio-ffmpeg`). Center the camera first, e.g. `exec 'uiFindType("Explorer")'`.
  Make the numbers visible: `--watch <IDs or proto names>` draws the game time and the live HP of
  those units on every frame, `--log <regex>` the latest matching `UHC.log` lines (the feature's
  own `log` output); select the key unit (`exec 'uiLookAtAndSelectUnit(<id>)'`) so its stat panel
  shows too. `scenario` sets `flashHitpointBarsOnDamage`, so damaged units show their HP bar.
- **Black screenshots and videos** mean the game stopped drawing: it does so while another window
  has the foreground (`record` and real clicks bring it to the front; `focus()` falls back to a
  click on the title bar, since Windows refuses `SetForegroundWindow` to a background process) and
  when the monitor turns off from inactivity, after which its graphics device stays lost until
  the game restarts. For a long unattended session keep the display on first, e.g. a background
  `python -I -c "import ctypes,time; ctypes.windll.kernel32.SetThreadExecutionState(0x80000003);
  time.sleep(10800)"`, and restart the game if the frames are already black. A window covering the
  game on its monitor (a terminal) has the same effect, and `focus()`'s title-bar click then lands
  on that window: run `front` after `launch` (it keeps the game above every window and focuses
  it). Do not move the game to a monitor with another DPI scale: its HUD still draws, but the 3D
  view stays black.
- **Camera, selection and bars:** in the scenario route `uiLookAtUnit` and
  `uiLookAtAndSelectUnit` select but may leave the camera off the map (a black world, the
  minimap frame at the edge); a real click on the minimap (`rclick` on the island) moves it, and
  `wheel <x> <y> <steps>` zooms (positive steps zoom in). Floating HP bars show only for selected
  or damaged units: `drag <x1> <y1> <x2> <y2>` box-selects. To read small bars, record at width
  2560 and crop in ffmpeg. A Surgeon heals idle damaged units nearby on its own, about 75 HP in
  10 s, so put damage triggers after the recording starts.
- **Test data:** `tools/protoy_testdata.py <bed> unittype Proto=Type …` adds marker types to the
  copy's `protoy.xml` and compiles the XMB from it; `reset` restores the files.
- **One game at a time.** Other sessions may be testing in their own copies (for example
  `C:\AoE3-UHC-Poison`) and may drive their game with real mouse input. `testbed.py` finds the
  process and window by the copy's exe path, never by title, and `launch` refuses while any
  `age3y.exe` runs. Ask before starting a game when another session says it is testing. The
  game itself refuses a second instance, even from another folder: it stops at a dialog ("Only
  one copy of the game can run at a time"), so sessions take turns.
- **Running beside another session's game** is possible with `multipleInstances background` in
  your copy's cfg ([modding guide](modding-guide.md#multipleinstances)):
  - the semaphore check no longer collides with copies in other folders;
  - your windows are created behind every other window, stay there and are never focused, so
    another session's real clicks and keys cannot reach your game.

  A copy without `background` does take the focus and can cover other windows when it starts, even
  when it is launched with `SW_SHOWNOACTIVATE`. `tools/legacybench.py` starts beside another game
  only when its copy's cfg has the key; `testbed.py launch` still refuses. Ask the other session
  first anyway: both games share the CPU and the `My Games` folder.
- **Closing:** `close` sends WM_CLOSE and kills the process after 30 s. Killing is safe unless a
  `tools/re` tracer is attached ([rule 2 below](#dynamic-analysis-hardware-breakpoint-tracers)).
- **Data is parsed once, at startup.** The editor route does not reload `protoy.xml` (a skirmish
  start does), so after a data edit run `close` and `launch` again. A skirmish start compiles the
  AI scripts before it reloads the data, so its AI sees the data of the previous load.
- **A skirmish against the AI** needs real clicks (`rclick`, client coordinates for a 2560×1600
  client area): main menu "Single player" (341, 1191), "Skirmish" (921, 1191), home city "Play"
  (239, 1527), setup "Play" (635, 1451). Wait about 5 s between the menu clicks and 8–12 s
  before each "Play". After a game, the home city screen sometimes ignores the first click on
  "Play": take a small screenshot (`shot out.png 4`) and click again. With a 2560×1440 client
  (`shot` prints the size) the same buttons are at (340, 1068), (920, 1068), (240, 1372) and
  (640, 1304) (2026-10-30). `startRandomGame2` does
  nothing from the main menu; it works only inside the editor.
- **A skirmish between two AIs** (for AI-only cases, such as `damageOverTime`'s army units): on
  the setup screen the player count list is at client (2317, 131) and "3 players" at (1911, 267);
  "No teams" (1935, 1459), speed "Fast" (2253, 1325). A player's portrait button opens the AI
  personality list (player 2's at (1003, 385), player 3's at (1003, 537)); `wheel 1677 695 30`
  scrolls it to the European leaders, the first row is at (1797, 575), the second at
  (1797, 695), and "Accept" at (1577, 931). Two Hard AIs had military from about minute 5.
- **Kill or Destroy.** The trigger `Kill` leaves a body that still answers to the unit's ID for a
  while; `Destroy` removes the unit at once. Use `Destroy` when a test needs the unit gone.
- **Scenario armies are not AI armies.** `Army Deploy` (`trArmyDispatch`) creates the units but
  does not put them in an engine army (no army flag 37h).
- **Reading a player's resources:** they are a resource list embedded at `[player+230h]`
  ([engine-symbols.md](engine-symbols.md), "Player resources"); entry 5 is XP, which also rises
  by a steady trickle, so compare a kill against that rhythm.
- **Zooming for a video:** `exec "uiLookAtUnit(ID)"`, then `wheel 1280 700 8`, then `record …
  --follow ID`.
- **Shipments need a skirmish and real clicks.** Scenario players have no home city, so a test of
  shipments (`hcShipmentPointFallback`) runs in a skirmish. Send a card by clicking the home city
  flag (client 667, 1217 on a 2560×1600 client), then a card in its panel. The console cannot set
  a tech in a skirmish either: `trTechSetStatus` is a trigger syscall, and `editorSetTechStatus`
  needs the editor.
- **An error dialog outlives the game.** A game dialog, such as an XS error at game start, stays
  on screen through `leaveGame()` and the menus and eats the clicks meant for them. Click its
  button first (client 1282, 809 for the centered dialog).
- **Check that the AI plays** in any test of data or hooks that the AI could reach. Signs that it
  does: it gathers its starting crates (`units --player 2` shrinks) and it may greet in the chat.
  `XS: Error 0003: could not compile file 'aiLoaderStandard.xs'` at game start means it does
  not; `tools/re/trace_xs.py` logs the error behind it
  ([modding guide, "Tactics files"](modding-guide.md#tactics-files) has the case found so far).
- **Shared files it touches:** the scenarios (`close` removes the ones this copy saved, listed in
  `<bed>\uhc-scenarios.txt`, never another session's), `RecentFilesy.xml`,
  `Trigger3\trigtemp.xs` and the `RM3\*.dmp.txt` dumps in the user's `My Games` folder, and the
  profile (back it up first, see above).

## 3. Adding a feature, step by step

The worked example is `healNonIdle` (`src/features/heal.cpp`, `src/hooks/heal_hooks.asm`).

1. **Find the code.**
   - Start from strings and cross-references, then decompile ([section 6](#6-reverse-engineering-workflow)).
   - When static reading is not enough, trace the running game. For `healNonIdle`:
     - the hit points field (`unit+64h`) came from a write breakpoint while a monk healed;
     - its writer's call chain led to the heal tick FUN_009E0B53 and its "target busy" check at
       `0x9E0C79`;
     - the first in-game test showed that the tick hook never ran. An execute-breakpoint trace
       then found the automatic target search FUN_009CD865 and its idle test.
2. **Choose the site and check it.** It must be an instruction boundary, no branch may land
   inside the bytes you overwrite, and you must know what is live at the continuation
   ([section 6](#byte-level-checks-with-capstone)).
3. **Add the site** to `SITES` in `tools/gen_sites.py`, with a comment saying what the bytes
   are. Make the range cover the overwritten bytes and the continuation. Regenerate:

   ```
   python -I tools/gen_sites.py "<Steam>\steamapps\common\Age Of Empires 3\bin\age3y.exe"
   ```

   It only reads the exe, and refuses any exe that is not the stock build.
4. **Write the hook** in `src/hooks/<area>_hooks.asm`, following
   [how-it-works.md, section 3](how-it-works.md#3-hook-conventions):
   - `TRACE_ONCE` first;
   - continuations as data dwords;
   - a comment stating the registers on entry and what the hook may clobber.
5. **Write the feature** in `src/features/<area>.cpp`:
   - parse its arguments;
   - `VerifyAll(feature, {&sites::kYourSite, …})`, then `WriteJmp`;
   - log what it did, including `(multiplayer unverified)` for simulation changes.

   Share values with the hook through `extern "C"` globals.
6. **Register it** in `src/features.h`: declare `Apply…`, then add it to `kFeatures` and its
   lowercase key to `kHandledKeys`.
7. **Add the files** to `CMakeLists.txt`. Give the `.asm` a base name that no `.cpp` uses
   (`heal_hooks.asm`, not `heal.asm`): otherwise MASM fails with error A1000.
8. **Build and test:**
   1. check the hook's bytes in the built DLL, with `dumpbin /disasm` or capstone;
   2. smoke test: `UHC.log` says `applied`;
   3. in-game test: the `hook reached` lines appear and the behavior changes;
   4. control test: without the key, the game behaves as in stock.
9. **Document it:**
   - a row in [uhc-address-map.md](uhc-address-map.md), "Beyond upstream";
   - the engine functions in [engine-symbols.md](engine-symbols.md);
   - a section in [modding-guide.md](modding-guide.md);
   - a line in [examples/Startup/uhc.cfg](../examples/Startup/uhc.cfg).

Test data goes in the test copy only. For example, add a marker unit type with
`tools/xmbedit.py add-unittype`.

## 4. Definition of done

Every new or changed feature meets this list before it is reported as done. Each item links to
where it is explained; the rules written nowhere else are spelled out here.

**Analysis**
- [ ] **Every reader and writer** of the value the feature changes (HP, speed, a flag…) is listed,
  from REA cross-references ([static analysis](#static-analysis-rea-and-ghidra)) or a write
  breakpoint ([tracers](#dynamic-analysis-hardware-breakpoint-tracers)), with a decision for each:
  does the feature affect it? `healNonIdle`'s first hook did nothing because the automatic target
  search was a second path ([section 3](#3-adding-a-feature-step-by-step), step 1).
- [ ] **Every caller of a hooked function** is known (AI, triggers, UI, other players' units),
  with what each one expects from it.
- [ ] **What is live after each continuation** (registers, flags, x87 stack) is checked
  ([hook conventions](how-it-works.md#3-hook-conventions),
  [byte-level checks](#byte-level-checks-with-capstone)) and written in the feature's "Why it is
  safe" in [how-it-works.md](how-it-works.md#4-the-features).
- [ ] **Per-player copies:** protos, actions and techs exist per player; the code reads the right
  copy (the player's proto, FUN_0045311B, in
  [engine-symbols.md](engine-symbols.md#damage-and-poison-2026-10-28-for-damageovertime)).

**Tests** ([driving the game unattended](#driving-the-game-unattended))
- [ ] **Minimum matrix:**
  - the key absent: stock behaviour;
  - each argument;
  - an unmarked control unit;
  - bad arguments (an unknown type or tech, 0, negative or huge values): logged, the feature not
    applied, never a crash.
- [ ] **Combinations** with every key that shares a site, a pointer or a wrapper, for example
  `g_uhcBwrTrainGetter` ([buildingWorkRateAuras](how-it-works.md#buildingworkrateauras) and
  `noTrainNearEnemyTC`) or the world update wrapper of
  [damageOverTime](how-it-works.md#damageovertime).
- [ ] **Lifecycle:** a new game, a loaded game, a scenario, a data reload. The DLL's state is
  cleared ([data-load callbacks](how-it-works.md#3-hook-conventions)) and never leaks from one
  game into the next; what saved games do not keep is documented
  ([modding guide, section 7](modding-guide.md#7-multiplayer-saved-games-and-replays)).
- [ ] **Performance:** a hook on a hot path (per unit, per tick) is O(1) or close: no allocation
  per tick, no walk over every unit of the world. Measured with `perfStats` on a large game, before
  and after ([performance.md](performance.md#benchmark-harness)).
- [ ] **Regression:** after a change to a shared hook, the neighbouring features still log
  `applied` and their `hook reached` lines.
- [ ] **Unit tests:** there is no test target yet. Once there is one, pure C++ logic (cfg and
  argument parsing, calculations) gets unit tests that run without the game.
- [ ] **The AI still plays** after data or combat changes ([CLAUDE.md](../CLAUDE.md#commands),
  "Check the AI after data or combat changes").

**Multiplayer**, for every key that changes the simulation (details in
[how-it-works.md, section 5](how-it-works.md#5-rules-that-keep-multiplayer-deterministic)):
- [ ] no decision depends on the local player;
- [ ] no real clock: game time `[world+108h]` or the step count `[world+F8h]`;
- [ ] no randomness but the game's synced RNG;
- [ ] ordered containers (keyed by unit ID, never by pointer or hash order);
- [ ] logs never feed back into the game.

**Process**
- [ ] **Scope:** if a part turns out much more expensive than planned, deliver what works and
  document the rest as pending instead of stretching the task.
- [ ] **One commit per key;** each commit builds and exports `_UHCMain@0` ([section 1](#1-build)).
- [ ] **Test data backed up** before any edit, with an `*.orig`-style suffix as the existing test
  copies do (`protoy.xml.uhc-orig`, `*.wol-orig`; [test data](#driving-the-game-unattended)).
- [ ] **Docs updated:** [section 3](#3-adding-a-feature-step-by-step), step 9, and the doc list in
  [CLAUDE.md](../CLAUDE.md#layout).
- [ ] **Status words** as already defined: `unverified` / `confirmed` / `mismatch`
  ([conventions](#5-conventions)), and in the feature tables `confirmed (single player)` and the
  like ([README](../README.md)).
- [ ] **The final report** always has the same shape:
  1. what works;
  2. what was tested in game, and how;
  3. what was not tested;
  4. what is inferred without being observed.

## 5. Conventions

- **English** for code, comments and documentation.
- **No code from other projects in `src/`:**
  - the original UnHardcoded project has no license;
  - the Wars of Liberty DLL is closed.

  Use them for addresses and behavior only, and verify every address against the stock exe.
- **Opt-in:** every feature is off unless its key is in `uhc.cfg`.
- **Honest status:** each finding in the research docs carries a status (`unverified`,
  `confirmed`, `mismatch`) and its evidence. Observations, inferences and unknowns are kept
  apart.
- **Copies only:** never modify the Steam install.

## 6. Reverse-engineering workflow

### Static analysis: REA and Ghidra

This project used [REA](https://github.com/morluto/rea) (npm package `rea-agents`, 6.7.0) as an
MCP server, with Ghidra as its provider. Any disassembler or decompiler works the same way on
these addresses.

**Setup:**
- Ghidra 12.1.x. REA 6.7 accepts only 12.1; do not upgrade to 12.2.
- JDK 21. On Windows, REA finds Java only through `JAVA_HOME`.
- Environment for the REA server: `GHIDRA_INSTALL_DIR`, `JAVA_HOME`,
  `REA_ANALYSIS_PROVIDER=ghidra`, a long startup timeout (`REA_GHIDRA_STARTUP_TIMEOUT_MS`) and
  enough memory (`GHIDRA_HEADLESS_MAXMEM=8G`).

**Using it:**
- The first analysis of the 11.6 MB exe takes 15 to 30 minutes. Do not cancel it: cancelling
  discards the database.
- On Windows the Ghidra mode is read-only: functions cannot be renamed, so record names in the
  docs.
- Useful operations: string search, cross-references, `resolve_containing_procedure`,
  pseudocode, assembly, batch decompile.
- Large results are saved to a file instead of being shown.
- Export evidence bundles and a snapshot before closing a session; a snapshot replays cached
  queries later.

**Reading the exe:**
- ImageBase is `0x400000`, with no ASLR, so the VAs in the docs are the runtime addresses.
- For `.text`, `.rdata` and `.data`, file offset = VA − `0x400000`.
- Ghidra's pseudocode is analysis output, not source. Check anything important in the assembly.

### Byte-level checks with capstone

Two checks back every patch site in this project. A short script with capstone and the file
bytes does both:
- **Instruction boundary:** decode from each of `site−1` … `site−48`. A correct site is where
  those decodes resynchronize.
- **No branch into the overwritten bytes:** scan the whole `.text` section for `E8`/`E9`/`0F 8x`
  (rel32) and `EB`/`7x` (rel8) branches whose target falls inside `[site, site+length)`.

```python
import struct, capstone
exe = open(r"<Steam>\...\bin\age3y.exe", "rb").read()
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
def code(va, n):                       # .text/.rdata/.data: file offset = VA - 0x400000
    return exe[va - 0x400000: va - 0x400000 + n]
site, length = 0x9CD9C7, 5
for back in (16, 24, 32):              # boundary: these decodes should all land on the site
    print(back, any(i.address == site for i in md.disasm(code(site - back, back + 8), site - back)))
for o in range(0x1000, 0x784000 - 6):  # .text is file 0x1000..0x784000
    va, b = o + 0x400000, exe[o]
    if b in (0xE8, 0xE9):                                   # call / jmp rel32
        target = va + 5 + struct.unpack_from("<i", exe, o + 1)[0]
    elif b == 0x0F and 0x80 <= exe[o + 1] <= 0x8F:          # jcc rel32
        target = va + 6 + struct.unpack_from("<i", exe, o + 2)[0]
    elif b == 0xEB or 0x70 <= b <= 0x7F:                    # jmp / jcc rel8
        target = va + 2 + struct.unpack_from("<b", exe, o + 1)[0]
    else:
        continue
    if site < target < site + length:  # a candidate: confirm it is real code in a disassembly
        print("branch into the site from", hex(va))
```

### Dynamic analysis: hardware-breakpoint tracers

`tools/re/` holds a small debugger, Python with ctypes and no packages. It attaches to the
running game, sets up to four hardware breakpoints and logs who hits them:
- `trace_writes.py`: who writes (or reads) a field;
- `trace_exec.py`: who runs an address, with the registers and a call chain;
- `trace_xs.py`: the XS compiler's errors, which the game hides behind `Error 0003`.

Usage is in [tools/README.md](../tools/README.md). The traces behind this project's features:

| Question | Command |
|---|---|
| What moves the shipment point when a Town Center dies? | `trace_writes.py gather.txt hc:1+0x18C hc:1+0x190 --rw` |
| Which code changes a unit's hit points? | `trace_writes.py hp.txt unit:Explorer+0x64` |
| What starts a heal, and does the command predicate run? | `trace_exec.py heal.txt 0x4C6D91=pred-0x41@esi 0x4C6DDD=pred-0x42@esi 0x9E0B53=heal-tick@[ecx+0x10]` |
| Why does the AI fail to compile after the `damageOverTime` test data loads? | `trace_xs.py xs.txt` (it was `Error 0014: 'cTacticNormal' is already defined.`) |

**Rules:**
1. Start the tracer, then start (or switch to) the game, then play the scenario.
2. Stop a tracer with **Ctrl+C**, or let it run out of time. **Never kill its process:** a
   hardware breakpoint left behind raises an exception nobody handles, and the game crashes.
   This happened once during testing.
3. Only one debugger can attach at a time.
4. A breakpoint on code that runs very often slows the game down while it is attached.
5. A data breakpoint stops after the access, so the logged `after=` address is the
   instruction that follows the writer.
6. The call chain is a heuristic, built from the return addresses found on the stack. Stale
   entries can appear.
7. The tracer reports second-chance exceptions, so a game crash is never mistaken for a normal
   exit.

### Reading game memory

`tools/re/debugger.py` also reads game objects without attaching, which is safe to do next to a
tracer:

```python
import sys; sys.path.insert(0, "tools/re")
import debugger as D
proc = D.Process(D.find_pid())
db = D.database(proc)                                    # [[0xC66234]+0x140]
levels, count = proc.u32(db + 0x60D0), proc.u32(db + 0x60D4)
print([proc.i32(levels + 12 * i + 4) for i in range(count)][:12])   # maxdecksize per HC level
```

`tools/re/inspect_unittypes.py` is a complete example: it walks the unit type table and the
proto bitsets.

**Finding an unknown field.** The hit points field was found by polling the memory of the units
while they fought and were healed, looking for a float that dropped when hit and rose in small
steps while the unit stood still. It was then confirmed with a write breakpoint on that offset.
The same method works for any field whose value you can make change in game.

### Recording evidence

The research notes cite their evidence:
- `ev_…` IDs are REA records, stored locally under `rea/` (not in the repository);
- `cs` means a capstone check on the file bytes;
- traces name the tool and the scenario.

Each entry gives the address, the function and the method, so anyone can rerun it with the
stock exe.

## 7. Making a release

Modders download a zip, so they never need a compiler. The version has a single source,
`project(UHC VERSION x.y.z)` in `CMakeLists.txt`. CMake writes it into `version.h`, which
`src/dllmain.cpp` and `src/version.rc` include. It appears as:
- the first line of `UHC.log`, `UHC.dll x.y.z`;
- the file's Properties → Details.

1. **Bump the version** in `CMakeLists.txt`:
   - the third number for fixes;
   - the second for new features;
   - the first for changes that break existing `uhc.cfg` files or data.
2. **Build:** `cmake --build build --config Release`. Then check the DLL:
   - `dumpbin /exports` lists `_UHCMain@0`;
   - `(Get-Item build\Release\UHC.dll).VersionInfo` shows the new version.
3. **Package:** `python -I tools/package_release.py`. Before writing anything, it checks the DLL:
   - it is 32-bit;
   - it exports `_UHCMain@0`;
   - it carries the version in `CMakeLists.txt`;
   - it is newer than `CMakeLists.txt` and every file in `src/`.

   It then writes `dist\UHC-x.y.z.zip`:

   ```
   UHC-x.y.z\
       UHC.dll
       Startup\uhc.cfg     examples/Startup/uhc.cfg with every key commented out
       README.txt          the modder's quick start
       LICENSE.txt
   ```

   It prints the SHA-256 of the zip and of the DLL, and refuses to replace an existing zip
   unless given `--force`. The game exe is never included: it is Microsoft's binary, and each
   modder patches their own copy.
4. **Test the zip as a modder would:**
   1. unzip it somewhere, then copy the **contents** of its `UHC-x.y.z\` folder into a test copy
      that has a patched exe, replacing its `UHC.dll` and `Startup\uhc.cfg` (the zip's top
      folder is not a game folder);
   2. delete the old `UHC.log`, since the log is appended;
   3. enable a few keys;
   4. start the game, from any folder;
   5. check the log: its first line shows the new version, the next one is
      `UHCMain: working directory <the copy>`, and every enabled key says `applied`.
5. **Publish it by hand** on the repository's GitHub Releases page:
   - a tag `vx.y.z`;
   - the zip as the release asset;
   - notes listing the new and changed keys, with the in-game status column of the README;
   - the two SHA-256 values.

When a key is added, update the release material too:
- `examples/Startup/uhc.cfg`: the template in the zip comes from it;
- the key list in `README.txt`, inside `tools/package_release.py`.
