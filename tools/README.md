# Tools

Python 3 scripts, with no third-party packages except where noted. Run them with `python -I`
(isolated mode) from the repository root.

| Tool | What it does |
|---|---|
| [`gen_sites.py`](#gen_sitespy) | Writes `src/generated/sites.h` from the stock exe. |
| [`package_release.py`](#package_releasepy) | Builds the release zip that modders download. |
| [`bar.py`](#barpy) | Lists and extracts files from the game's `.bar` archives. |
| [`xmbedit.py`](#xmbeditpy) | Checks, converts, compiles and edits compiled XML (`.xmb`). |
| [`dot_testdata.py`](#dot_testdatapy) | Writes the `damageOverTime` test data into a test copy of the game. |
| [`pop_testdata.py`](#pop_testdatapy) | Writes the `decimalPopulation` test data into a test copy of the game. |
| [`protoy_testdata.py`](#protoy_testdatapy) | Edits protos in a test copy's `protoy.xml` and its XMB: marker unit types, flags, extra elements. |
| `guide_dates.py` | Writes the day, date and time of every feature, and the "Latest changes" table, into `docs/modding-guide.md` from git; run it before the commit of a new key or test video. | <!-- private -->
| `porting_code.py` | Writes `docs/porting-code/*.md`, the code of the features in pages by theme, from `src/`. `--check` fails when a page differs. |
| `make_gifs.py` | Makes every test GIF to one standard (800 px, 8 fps, 12 s, 4 MB) from the masters in `rea/media-masters`, with the cuts in `gifs.txt`. `--check` fails on one out of it. |
| `make_rings.py` | Draws the coloured aura rings in `tools/rings/`: for each, an `.xml`, its particles and textures by size, for `art/effects/uhc_rings/`. Also `aura_<resource>.xml`, the ring with a floating icon, and `range_<metres>.xml` for `displayedRange`, and `rank_<1-5>.xml`, the chevrons (and stars) of `veterancyBonus`. `--check` compares them. |
| `make_bar.py` | Draws `tools/bars/health_overheal.ddt`, the orange end of the portrait HP bar for `overhealHitpointBars segment` (16×8 DXT1, the layout of the game's own health bars, shaded from `FF8C00`), for `art/ui/uhc/`. `--colour RRGGBB --out <file>` makes one in another colour, to name with `bar=`; `--check` compares it. |
| `sharedlimit_testdata.py` | `<bed> [--restore]`: a real `OutpostWagon` at the Town Center and a team's `ypGoat` limit in a WoL bed, for `sharedBuildLimit`. |
| `monastery_testdata.py` | `<bed> [--model\|--ai\|--restore]`: `UhcMonastery` and `UhcSmallMine` in a WoL bed, for `linkedResource`; buildable with a monastery's model, and an AI rule that builds one. |
| `torp_testdata.py` | `<bed> [--restore]`: the Torp's auras on `WOLSawmill` in a WoL bed, a panel row and two test techs, for `unitResourceAuras`. |
| `grant_testdata.py` | `<bed> [--restore]`: grant tags on the `Market` in a WoL bed (interval 20, cap 3, cost 0, scope `self`) and four test techs of 300 wood on its buttons, for `researchGrants`. |
| [`testbed.py`](#testbedpy) | Plays a feature test in a test copy with no clicks: test map, timed trigger effects, console commands, units, log, screenshots, videos. |
| [`re/trace_writes.py`](#retrace_writespy) | Logs the code that writes or reads a field in the running game. |
| [`re/trace_exec.py`](#retrace_execpy) | Logs who runs a code address in the running game. |
| [`re/trace_xs.py`](#retrace_xspy) | Logs the XS compiler's errors, which the game hides behind `Error 0003`. |
| [`mapsweep.py`](#mapsweeppy) | Plays every random map of a test copy for 30 s of game time and writes a CSV row per run: ok, crash (code, EIP, module), hang, XS error or timeout. Resumable; shards for parallel copies. |
| `ai_personality.py` | Leaves one AI personality in a test copy, so a skirmish's AI has that civ. |
| [`re/inspect_unittypes.py`](#reinspect_unittypespy) | Shows a unit type's ID and the protos that carry it. |
| `re/debugger.py` | The shared debugger and game-memory helpers the `re/` scripts use. `crash` mode: see [re/debugger.py crash](#redebuggerpy-crash). |
| `perfprobe.py`, `set_laa.py` | Part of the performance work in progress; see [docs/performance.md](../docs/performance.md) and each script's docstring. |
| `re/pe64.py` | Static helper for a large 64-bit exe (AoE3 DE): strings, RIP-relative xrefs, functions from `.pdata`, callers, thread-creation sites. Listings need capstone. See its docstring and [docs/de-architecture.md](../docs/de-architecture.md). |
| `threadprobe.py` | Per-thread CPU, thread names and start addresses of any running process. By default it does not suspend the process or read its memory; `--sample-hz` briefly suspends the busiest threads to read their instruction pointer. |
| `legacybench.py` | Unattended late-game benchmark in a test copy (default `C:\AoE3-UHC-Perf`): loads a save through `perfExecFile`, records with `perfprobe.py` (and `threadprobe.py`), closes the game. It sends no input and never activates the window. The game allows only one running copy per machine, so it refuses to start while another `age3y.exe` runs, unless the copy's cfg (`uhc.cfg`, or `wol.cfg` in a WoL copy) has `multipleInstances background`; it takes `testbed.py`'s launch lock while the game starts. It prints the load time (to the end of the last frame over 50 ms after `loadGame`, from perfStats' slow-frame ring), and `--load-probe <s>` also profiles the load itself. |
| `gameui.py` | Drives a game window for unattended tests: screenshots, clicks, keys. Select the window with `--process` (age3y.exe or AoE3DE_s.exe). It moves the real cursor, so use it only with the machine owner's permission. |

Never point a tool that writes at the Steam install. The data tools write only the output file
you name, `dot_testdata.py` and `pop_testdata.py` write only into the test copy you name, and `gen_sites.py` only
reads the exe.

## gen_sites.py

```
python -I tools/gen_sites.py "<Steam>\steamapps\common\Age Of Empires 3\bin\age3y.exe" [out.h]
```

Reads the bytes of every patch site in its `SITES` list from the stock exe and writes them, as C++
arrays, to `src/generated/sites.h` (or `out.h`). The DLL compares live memory with them before
patching. It refuses any exe whose SHA-256 is not the stock build's. To add a site, see
[developer-guide.md, section 3](../docs/developer-guide.md#3-adding-a-feature-step-by-step).

## package_release.py

```
python -I tools/package_release.py [--force]
```

Checks `build\Release\UHC.dll` and stops if it fails any check:
- it must be a 32-bit DLL that exports `_UHCMain@0`;
- it must carry the version in `CMakeLists.txt`;
- it must be newer than `CMakeLists.txt` and every file in `src/`.

It then writes `dist\UHC-x.y.z.zip` with `UHC.dll`, `Startup\uhc.cfg` (the example with every key
commented out), `README.txt` and `LICENSE.txt`, and prints the SHA-256 of the zip and of the DLL.
An existing zip is kept unless `--force` is given. The procedure around it is in
[developer-guide.md, section 7](../docs/developer-guide.md#7-making-a-release).

The zip also holds `beside-another-dll/`: `dinput8.dll` and `engine-ext/engine-ext.cfg`, for a game that keeps another
`UHC.dll`. The script stops if `dinput8.dll` is missing, is not this version, or lacks `DirectInput8Create`, and
prints its SHA-256 too. The aura rings of `tools/rings` go in `art/effects/uhc_rings/`, for a game's `art` folder.

## bar.py

```
python -I tools/bar.py <archive.bar> [filter]
python -I tools/bar.py <archive.bar> [filter] --extract <output folder>
```

Reads the legacy archives (`data\Data*.bar`, `art\Art*.bar`, header `ESPN`). The filter is a
case-insensitive part of the stored path; `/` and `\` both work.

```
python -I tools/bar.py "<game>\data\Data3.bar" tactics/explorer
python -I tools/bar.py "<game>\art\Art4.bar" rev_banner --extract work
```

Files are written exactly as stored. Compiled XML usually starts with `l33t`: read it with
`xmbedit.py`. Stored paths that would leave the output folder are refused.

## xmbedit.py

```
python -I tools/xmbedit.py check <file.xmb>
python -I tools/xmbedit.py to-xml <file.xmb> <out.xml>
python -I tools/xmbedit.py from-xml <in.xml> <out.xmb> [--compress]
python -I tools/xmbedit.py add-unittype <in.xmb> <out.xmb> <Unit> <UnitType> [<Unit> <UnitType> ...]
```

- `check` decodes and re-encodes the file and confirms the result is byte-identical. `to-xml` and
  `add-unittype` do this first, so an edit cannot change anything else. `from-xml` reads no XMB:
  it builds the whole document from the XML and only checks that its output decodes to itself.
- `to-xml` writes readable XML, with element names as stored (lowercase).
- `from-xml` compiles an XML file the way the stock files are stored: element and attribute
  names in lowercase, numbered in order of first use; text trimmed, whitespace-only text dropped;
  the XML's line numbers kept. `--compress` writes the `l33t` form of the stock
  `protoy.xml.XMB`; without it the file is plain `X1`, like the stock `.tactics.xmb` files.
  Compiling the stock `protoy.xml` gives the stock `protoy.xml.XMB` document byte for byte once
  decompressed; the compressed bytes differ, because zlib settings differ. The game
  loads an XMB instead of its XML unless the XML is newer
  ([modding guide, section 6](../docs/modding-guide.md#6-editing-the-game-data)).
- `add-unittype` adds `<unittype>` entries to units of a `protoy.xml.XMB`. It warns about unit
  names it cannot find, and keeps the input's compression.

It handles compressed (`l33t` + zlib) and uncompressed (`X1`) files, version 8, the format of
the TAD data.

## pop_testdata.py

```
python -I tools/pop_testdata.py <test folder> [--restore]
```

Writes the data the `decimalPopulation` tests use into a **test copy** of the game. It refuses
any folder inside a Steam library. The tables at the top of the script list the cases:
- `data\protoy.xml`: `<PopulationCount>` 1.5 on `Settler`, `Crossbowman` and `Hussar`, 0.5 on
  `Pikeman`, and `<PopulationCapAddition>` 7.5 on `Manor`;
- `data\techtreey.xml`: four techs appended (UNOBTAINABLE; turn them on with a trigger, e.g.
  `"at35=Set Tech Status;PlayerID=1;TechID=tech:UHCPopCountTest;Status=2"` in a `testbed.py`
  map): `UHCPopCountTest` (Crossbowman +0.5 `Absolute`, Musketeer = 0.5 `Assign`, Town Center
  `PopulationCapAddition` +2.5), `UHCPopCapTest` (the player's `PopulationCap` +2.5),
  `UHCPopCapBig` (+300, to reach the limits) and `UHCPopPercentTest` (`BasePercent`: Hussar × 0.6,
  Pikeman × 3);
- `data\protoy.xml.XMB` and `data\techtreey.xml.XMB`: compiled from that XML with `xmbedit.py`.

The first run keeps the four files as `*.pop-before`; every run starts again from the
`.xml.pop-before` files, and `--restore` puts the four back. The tests of 2026-10-29 used it on
`C:\AoE3-UHC-WoL` ([modding guide](../docs/modding-guide.md#decimalpopulation)).

## dot_testdata.py

```
python -I tools/dot_testdata.py <test folder> [--ai | --bad | --wol | --restore]
```

`--wol` writes only the Iroquois Aenna's poison arrows (`UHCPoisonArrowWoL`, 4 Ranged a second for
8 s, up to 3 stacks, green tick text) into a copy of a mod that reads its data loose: only
`protoy.xml` (kept first as `protoy.xml.dot-orig`) and the tactics file, no XMB and no techs.
`--restore` copies every `*.dot-orig` back and removes the tactics files.

Writes the data the `damageOverTime` tests use into a **test copy** of the game. It refuses any
folder inside a Steam library. The tables at the top of the script list the cases:
- `data\protoy.xml`: one attachment proto per weapon, each attached to that weapon's attacks:
  - the Explorer (`HandAttack`, `VolleyRangedAttack`): `UHCPoisonTest`, 20 Ranged every second
    for 10 s, Gaia and enemies;
  - the Grenadier (an area attack, a flying grenade): `UHCPoisonGrenade`, 10 Siege for 6 s,
    enemies only (a unit converted to the attacker's side is excluded);
  - the Crossbowman (a flying arrow): `UHCPoisonArrow`, 6 Hand for 8 s, triple against
    `AbstractCavalry`;
  - the Falconet (a cannon ball): `UHCPoisonCannon`, 15 Siege for 9 s;
  - the Longbowman: `UHCPoisonStack`, 5 Siege for 6 s, with `<AttachMaxStacks>3`,
    `<AttachSnare>0.5` and `<AttachTickText>40FF40` on its attacks;
  - with `--ai`, also the Musketeer, Skirmisher, Pikeman and Hussar: `UHCPoisonLong`, 1 Siege for
    120 s, so that two AI players poison each other's armies and the poisons outlive their
    attackers;
  - with `--bad`, invalid `<AttachMaxStacks>`, `<AttachSnare>` and `<AttachTickText>` values on the
    Musketeer's three ranged attacks (and an empty `<AttachTickText>`), and `<AttachMaxStacks>`
    without `<AttachProtoUnit>` on the Skirmisher, to check the load-time messages.
- `data\techtreey.xml`: the tech `UHCPoisonArrowUpgrade` (UNOBTAINABLE; doubles
  `UHCPoisonArrow`'s `Attaching` damage), for a trigger to turn on (`tech:UHCPoisonArrowUpgrade`
  in a `testbed.py` map).
- `data\protoy.xml.XMB` and `data\techtreey.xml.XMB`: compiled from that XML with `xmbedit.py`.
- `data\tactics\uhcpoisontest.tactics` and its `.xmb`: the `Attaching` action. The XML keeps the
  tactic name and its first child on one line, so it also works without the `.xmb`
  ([modding guide, "Tactics files"](../docs/modding-guide.md#tactics-files)).

The first run keeps the folder's protoy and techtreey files as `*.dot-orig`. Every run starts
again from the `.xml.dot-orig` files and compiles the XMB from the result, so it can be repeated;
the `.XMB.dot-orig` files are only backups. Then enable `damageOverTime log` in the copy's cfg
and let the Explorer hit something (for an unattended run, see the developer guide, "Driving
the game unattended").

## protoy_testdata.py

```
python -I tools/protoy_testdata.py <test folder> <verb> <edit> [...] [<verb> <edit> [...]] ...
python -I tools/protoy_testdata.py <test folder> reset
```

Edits the named `<Unit>`s of the copy's `data\protoy.xml`, then compiles `data\protoy.xml.XMB`
from that XML, so the game sees the edits whichever file it loads. Verbs, combinable in one run:
- `unittype <Proto>=<UnitType>` adds a unit type, e.g. `Explorer=AbstractDodge` for
  `dodgeAnyUnit`;
- `flag <Proto>=+<Flag>` adds a flag, `flag <Proto>=-<Flag>` removes one, e.g.
  `Deer=+Doppled Deer=-VisibleUnderFogOnlyAfterSeen`;
- `line <Proto>=<xml>` inserts one element before `</Unit>`, e.g. `"House=<Lifespan>20</Lifespan>"`.

The first run keeps the two files as `*.testdata-orig`; each run starts again from those (so give
all of a test's edits in one run), and `reset` puts them back. It refuses any folder inside a
Steam library.

## testbed.py

```
python -I tools/testbed.py [--bed <folder>] <command> ...
```

Drives the game of a test copy (default `C:\AoE3-UHC-Test`, or the `UHC_TESTBED` variable) with
no clicks. Commands: `deploy`, `launch`, `close`, `exec`, `map`, `scenario`, `wait`, `state`,
`units`, `shot`, `record`, `click`/`rclick`, `drag`, `wheel`, `front`, `key`/`rkey`, `type`, `log`, `safety`; the
docstring lists their arguments.

A command that waits on the game ends with exit code 3 when the game dies meanwhile (the message gives
the process's exit code, `0xc0000005` for an access violation), and 4 when it hangs: the window does
not respond when the wait times out, or, in `wait`, the world clock stands still for `--hang` seconds
(`UHC_HANG_SECONDS`, 60 by default; a paused or ended game stops the clock too). A plain timeout
keeps exit code 1.

Paths come from the copy's own exe and data (`profile` prints them): the cfg the loader reads
(VA 0xC65083: `Startup\uhc.cfg`, or `Startup\wol.cfg` in a Wars of Liberty copy), the AI and
random-map folders (`AI3`/`RM3`, or `AI4`/`RM4`), and the `My Games` folder (string 42265 of the
copy's `stringtabley.xml`). `deploy` writes the cfg there, `map` writes into that map folder and
`scenario` saves into that `My Games` folder. `profile backup` copies the player profiles
(`Users3\*.xml`, UTF-16) to `.bak-uhc-<date>` before a first run. `safety record|check wol`
checks the Steam Wars of Liberty folder (exe, `uhc.dll`, top level, `Startup`, `data`, `AI4`,
`RM4`) the same way `safety` checks Steam's `bin`.

`record <out.mp4> [seconds] [fps] [width]` films the window to an MP4 in real time, with ffmpeg
(`UHC_FFMPEG`, `PATH`, or `C:\Tools\ffmpeg\ffmpeg.exe`). It first brings the game window to the
front, since the game stops drawing while another window has the foreground. Options that draw
live text on every frame:
- `--watch <IDs or proto names>` (comma-separated): the game time and the live HP and line of
  sight of those units, matched again every second, so new units appear and dead ones go (more
  than 6 units are counted per proto and player instead);
- `--log <regex>`: the latest `UHC.log` lines of the current game that match, e.g. a feature's own
  `log` output;
- `--frame <ID>`: centers the camera on that unit once, at the start, and leaves it still: the
  default for a scene where the units stay in place;
- `--follow <ID>`: follows a unit that travels: the camera re-centers (a `uiLookAtUnit` through
  `perfExecFile`) only once the unit has walked 10 m from the last center, so the picture does
  not jump every few seconds. If the unit dies it goes on with another `--select` unit, or stops.
- `--select <IDs or proto names>`: keeps those units (player 1's) selected for the whole video,
  so the game draws their HP bars and the selection panel; they are selected again when a new
  matching unit appears (a dead one leaves the selection by itself). The game selects one unit
  per `uiLookAtAndSelectUnit`, so the selection is collected in number group 9.
- `--close <Z>`: brings the camera to height Z by console (`normalZoom`; the game's default is 65,
  and 27 frames a small group). The camera eases there only while the window is active, so for a
  copy in the background set it before the game loads:
  `exec 'configSetFloat("minZoom", 15)' 'configSetFloat("normalZoom", 27)'`, then `scenario`.
- `--crop <W>x<H>[@cx,cy]`: films that many window pixels around `cx,cy` (window fractions, default
  `0.49,0.47`, where `uiLookAtUnit` puts a unit) one to one, never enlarged: the only way to keep the game's own sharpness. Give a
  panel its own centre (`--crop 960x640@0.72,0.8`). The overlay is drawn after the crop.
- `--master <out.mkv>`: also writes a lossless copy, the source for GIFs. Unchanged frames stay
  identical in it, so a still camera costs little; an MP4 as source smears colour and text, and
  its noise makes the GIF grow.
- `--log-top`: draws the `--log` lines above the game's bottom panel, for a feature that shows in it.
- `--gold 1,2`: a line with those players' gold, read from the game, for a test of resources where the second player's
  stockpile shows nowhere on screen.
- `--background`: leaves the focus alone. For a copy with `multipleInstances background`: it needs
  no window in front, so a test can run while somebody uses the PC.
- `--hover <x>,<y>`: rests the cursor on a client point (a command panel button), so the button's
  rollover stays on screen. It is the only `record` option that moves the cursor.
- The cursor: `record` sets `cameraMovementLock`, so a cursor at a screen edge no longer scrolls
  the camera (`uiLookAtUnit` still moves it). It never moves the mouse, except for `--hover`.
- `--perf`: the performance numbers, once a second, at the top: fps, the longest frame of the
  second, frames over 50 ms since the start, simulation speed (game seconds per real second), the
  main thread's CPU, the game's own update and render times and the working set. They are read
  from outside the game with `perfprobe.py`'s readers; fps and frame times need `perfStats` in the
  cfg. It clears perfStats' per-second longest frame, so do not run `perfprobe.py` at the same
  time. `--perf-csv <out.csv>` also saves one row per second (it implies `--perf`); a summary
  line is printed at the end.

It needs `perfExecFile <bed>\uhc-exec.txt` in the copy's cfg (`deploy` adds
it). The method and its pitfalls are in
[developer-guide.md, "Driving the game unattended"](../docs/developer-guide.md#driving-the-game-unattended).

**Which game the tracers attach to.** The `re/` tracers and `inspect_unittypes.py` attach to the `age3y.exe` whose exe is in `UHC_GAME_DIR` (or `UHC_TESTBED`); with no folder set and more than one copy running they stop with an error instead of picking one, since other sessions may run games beside yours (2026-11-03: a tracer attached to another session's game this way). Example: `set UHC_GAME_DIR=C:\AoE3-UHC-WoLReal`.

**A bed with an `engine-ext` folder** runs our `dinput8.dll` beside the bed's own `UHC.dll`: `deploy` copies `dinput8.dll` and
`engine-ext\engine-ext.cfg` and leaves `UHC.dll` and the bed's cfg alone, and `log` reads `engine-ext\engine-ext.log`.

## re/trace_writes.py

```
python -I tools/re/trace_writes.py <log> TARGET [TARGET ...] [--rw] [--minutes N] [--max-per-chain N]
```

Hardware breakpoints on up to four 4-byte fields. `TARGET` is one of:
- `0xADDRESS`, a fixed address;
- `hc:PLAYER+OFFSET`, a field of a player's home city object, e.g. `hc:1+0x18C` (the land
  shipment point);
- `unit:PROTO[:PLAYER]+OFFSET`, a field of the first unit of `PLAYER` (default 1) with that
  proto, e.g. `unit:Explorer+0x64` (hit points). When the unit dies, it moves on to the next one.

`--rw` also stops on reads.

For every distinct writer and call chain, it logs the first hits, with the value before and after
(as an integer and as a float) and the registers. A summary is written when it detaches.

## re/trace_exec.py

```
python -I tools/re/trace_exec.py <log> SPEC [SPEC ...] [--minutes N] [--max-per-chain N]
```

`SPEC` is `ADDRESS[=LABEL][@UNIT]`, for example `0x9E0B53=heal-tick@[ecx+0x10]`. `UNIT`, when
given, names a register or a `[register+offset]` slot that holds a unit pointer; the log then
shows that unit's proto, owner and hit points. Each hit logs the registers and the call chain.

## mapsweep.py

```
python -I tools/mapsweep.py --bed <copy> --csv <out.csv> [--maps A,B | --list FILE | --match RE]
       [--players 2,4,8] [--seeds 1,2,3] [--seconds 30] [--route scenario|skirmish] [--ai wolOtto]
       [--shard K/N] [--evidence DIR] [--no-debugger] [--dry-run]
```

Plays each map of the copy's map folder (every `.xs` with an `.xml`; the include libraries are
skipped) through `testbed.py scenario` (the editor's `startRandomGame2`, saved and loaded as a
scenario, players without AI) or, with `--route skirmish`, through the profile's skirmish with AIs,
lets `--seconds` of game time pass, and appends one CSV row per run: `ok`, `crash` (exception code,
EIP, module, call chain), `hang` (window not responding, or the world clock still for 60 s),
`xs-error` (new `xsErrorLog` lines in the log), `timeout` or `launch-failed`, plus the units per
player, the last log lines of the run and of `Age3Log.txt`. A row already in the CSV is skipped,
so a stopped sweep starts again where it was. Per run it keeps the testbed output and both logs in
`<evidence>/runs/`, a quarter-size shot in `<evidence>/shots/`, and the crash reports of
`re/debugger.py crash` (attached to every game it starts) in `<evidence>/crash-*.jsonl`. Without
the crash watch (`--no-debugger`), a crash's code and offset come from the Windows Application log
(event 1000, "Application Error"; EIP = offset + 0x400000 for age3y.exe).

The copy needs `perfExecFile`, `multipleInstances background` and `xsErrorLog` in the cfg its exe
reads (`engine-ext\engine-ext.cfg` beside another `UHC.dll`). It refuses to start while a game
runs in the copy, kills only games it started (after a hang or a timeout), and waits for 6 GB of
free memory before each run (`UHC_SWEEP_MIN_FREE_GB`). Several copies can sweep at once with
`--shard 0/3`, `1/3`, `2/3` and one CSV; `testbed.py`'s start lock staggers their launches, and the
scenario names (`uhc-<map>`) differ because each map belongs to one shard. The skirmish route
edits the shared profile, so it runs alone: it backs up the profile, the home cities and the AI
memory files and restores them byte for byte at the end, and leaves `--ai` personalities in the
copy (`ai_personality.py`, restored at the end).

## re/debugger.py crash

```
set UHC_GAME_DIR=C:\WoL-Test
python -I tools/re/debugger.py crash [--out crash.jsonl] [--log crash.log] [--seconds N]
```

Attaches to the running game without setting a breakpoint and waits until it exits. An unhandled
(second-chance) exception is written as one JSON line: code, EIP and the module plus offset, the
access (read, write, execute) and its address, the registers, `call_chain` (the return addresses
on the stack, innermost first) and the first stack words; then it is passed on, so the game ends as
it would have. Attached, Windows skips its error dialog, so the process ends at once instead of
waiting on the dialog. The first 20 first-chance exceptions that are not routine (C++ throws,
thread names, debug prints) are logged too, in case the game's own handler ends it. Killing it is
safe: it sets no breakpoint.

## re/trace_xs.py

```
python -I tools/re/trace_xs.py <log> [--minutes N]
```

When an XS script fails to compile, the game shows only its last message, for example
`XS: Error 0003: could not compile file 'aiLoaderStandard.xs'.`, and the AI players do nothing.
This tracer logs every parser error with its argument, and each compile with the number of
errors it starts with. Start it, then start the game that fails:

```
error: "Error 0014: '%s' is already defined." with 'cTacticNormal' (chain [...])
compile: 1 error(s) before it (chain [...])
message: "Error 0003: could not compile file '%S'." 'aiLoaderStandard.xs' (chain [...])
```

`1 error(s) before it` means the error came from the game's own declarations, which it compiles
before the script, not from the script. The example is the tactics problem in the
[modding guide, "Tactics files"](../docs/modding-guide.md#tactics-files).

## re/inspect_unittypes.py

```
python -I tools/re/inspect_unittypes.py <Name> [<Name> ...] [--max N]
python -I tools/re/inspect_unittypes.py --list-abstract
```

Reads the running game's unit type table without attaching a debugger. It prints a name's ID,
whether it is a proto or an abstract type, and the protos that carry an abstract type. Use it to
confirm that a `<UnitType>` you added to `protoy.xml`, or one that the DLL registers, really
loaded.

```
> python -I tools/re/inspect_unittypes.py AbstractHealNonIdle
1667 unittype names: 1463 protos, 204 abstract types
AbstractHealNonIdle: abstract type ID 1666, bit 203; carried by 3 protos
    Surgeon
    ypMonkIndian
    ypMonkIndian2
```

## Using the tracers safely

- **Start a tracer before or while the game runs.** It waits up to `--minutes` for
  `age3y.exe`, attaches, and detaches when the game exits or the time runs out. The game keeps
  running.
- **Stop it with Ctrl+C, never by killing its process.** A hardware breakpoint left in the game
  after the debugger is gone crashes the game.
- **Only one debugger at a time.** `inspect_unittypes.py` does not attach, so it can run next to
  a tracer.
- **Hot addresses slow the game.** A breakpoint on code that runs thousands of times per second
  slows the game down while the tracer is attached.
- **The tracers only work with the stock build.** Their engine offsets come from
  [docs/engine-symbols.md](../docs/engine-symbols.md) and are valid only there (or for a
  UHC-patched copy of it).
