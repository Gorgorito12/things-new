# WoL random maps: crash hunt (status, 2026-11-17)

Private: not in `tools/export_public.py`'s INCLUDE list. Players report that several WoL random maps crash
the game, e.g. "NEW" Levant (`RM4\NEWLevant.xs`), while the ESOC maps work. This note says what was
tested, what was found and how to resume.

**Summary.** All 208 maps generate, load and run (editor route, 2 players): **no crash, no hang, no
XS error**. One real bug was found, and it is not a crash: **a player name with a non-ASCII letter
(Benito Juárez, Napoleón III, a profile called José…) breaks the trigger script of 193 maps**, so none
of their triggers run. It is confirmed, and a data fix for WoL was tested (below). The note for the WoL
team is `wol-fixes/maps/README.txt`, with the fixed files in `wol-fixes/maps/fixed/`.

Evidence: `rea/evidence/wol-maps-20261111/` (gitignored): `sweep.csv` (all 208 rows), `levant.csv`,
`levant-ourdll.csv`, `runs/` (testbed output, `engine-ext.log` and `Age3Log.txt` lines and the kept
`trigtemp.xs` per run), `shots/`, `rmlint.py` and `rmlint.csv`, the setup screenshots and the backups;
from 2026-11-17 also `maps-wol-test.txt` (the map list), `sweep3-shard0.out` / `sweep3-shard1.out`,
`hashes-before-20261117.txt` / `hashes-after-20261117.txt`, `profile-backup-20261117/`,
`wolreal2-backup-20261117/`, `engine-ext-*-20261117.log`, and `accent/` (the trigger-name tests).

## How it was tested

- **Harness.** WoL's own `uhc.dll` c070d138 (the DLL players have) plus our `dinput8.dll` and
  `engine-ext\engine-ext.cfg` with only `perfExecFile`, `multipleInstances background`, `xsErrorLog` and
  `perfStats`. Beds: `C:\WoL-Test` (Spanish, ReShade), and on 2026-11-17 also `C:\AoE3-UHC-WoLReal2`
  with WoL's DLL and WoL-Test's `Startup\wol.cfg` put in for the sweep (English; its `data` and `RM4`
  are WoL-Test's apart from the string table and our `uhc*` test maps, which `--list` leaves out). The
  bed files (`uhc.dll`, `Startup\wol.cfg`, `age3y.exe`, `d3d9.dll`) had the same hashes before and after.
- **Tools.** `tools/mapsweep.py`, using `testbed.py` (exit codes 3 = died, 4 = hung) and
  `re/debugger.py crash`, attached to every game it starts. Each row of the CSV is one run.
- **Routes.** *Editor:* `startRandomGame2` in the scenario editor, saved and loaded as a scenario,
  players without AI, 30 s of game time. *Skirmish:* the setup screen with AIs, 60–90 s, the map checked
  by the time stamp of `My Games\Wars of Liberty\RM4\Age3RM<file>.dmp.txt` (the game writes it when it
  compiles a map).
- **The editor route names the players "Player 1", "Jugador 1"…**, so it cannot show the trigger-name
  bug below; only a skirmish (AI names, profile name) can.

## Results

| Test | Runs | Result |
|---|---|---|
| All maps, editor, 2 players, seed 1 (2026-11-11: 71; 2026-11-17: 137 in two shards) | 208 | **208 ok**: no crash, hang, timeout, wrong map or XS error; both players got units in every map |
| Levant, editor, 2/4/8 players × seeds 1–3, WoL's DLL | 9 | 9 ok |
| Levant, editor, the same with our DLL (`C:\AoE3-UHC-WoLReal`) | 9 | 9 ok |
| "NEW" Barbary Coast, skirmish, Dutch vs one AI (wolOtto), WoL's DLL | 3 | 3 ok |
| Levant, skirmish, WoL's DLL, European AIs only | 3 | 2 and 4 players ok; 8 players: `xs-error` (the trigger-name bug) |
| Levant, skirmish, our DLL, 2 players | 1 | ok |
| Acre, skirmish, 2 players vs **wolBenito** ("Benito Juárez"), WoL's DLL | 1 | **xs-error**: the trigger-name bug |
| Acre, skirmish, 2 players vs wolOtto ("Otto von Bismarck"), control | 1 | ok |
| Acre, skirmish vs wolBenito, with the proposed fix | 2 | 1 ok; 1 `wrong-map` (the setup played "NEW" Barbary Coast; see "Setup screen" below), re-run ok |

By result over the 208-map sweep: ok 208, crash 0, hang 0, timeout 0, xs-error 0, wrong-map 0. Runs
took 57–96 s each (62 s on average). The crash watch wrote no report.

A few maps gave player 1 far fewer starting units than player 2 (DansilAlaska 4 vs 12, everglades and
WolBioko 5 vs 12, dansil_greatbarrierreef 8 vs 16). They are water or island starts and the editor
route gives the two players different civs, so this is not a failure; it was not looked into.

### Confirmed: a player name with an accent breaks the map triggers

**What happens.** `RM4\triggers\triggerLoader.xs` (its `wotta_triggers()` is called by 193 of the 208
maps) writes the player name into two trigger texts per player, lines 62 and 108:
`rmSetTriggerEffectParam("Text", rmGetPlayerName(i)+" has entered the Great War Age!")` and
`"… has started the Inquisition!"`. The game turns the map's triggers into an XS script,
`My Games\Wars of Liberty\Trigger3\trigtemp.xs`, with the name inside a string literal, as one byte per
letter in the ANSI code page: `trOverlayText("Benito Ju\xE1rez has entered the Great War Age!", …)`.
The XS tokenizer ends a string at a byte above 7Fh, so the line fails:
`Token Error 0008: string not terminated`, `0009: expected '=' after '!'`, `0007: line feed in string`,
then `Error 0049: could not emit quads for 'main' function` and `Error 0003: could not compile file
'trigtemp.xs'`. **None of the map's triggers run then** (culture music, `effectless_tech`, the Great War
alarm, the Inquisition, the espionage triggers…). The game goes on: no crash, no message on screen.

**Evidence (2026-11-17; paths under `rea/evidence/wol-maps-20261111/`, the skirmishes in `accent/`):**
- Acre, skirmish, vs wolBenito, English data: errors at `trigtemp.xs` lines 168 and 208, which are
  player 2's two texts; the kept `trigtemp.xs` holds byte E1h for "á"
  (`accent/runs/acre-p2-s1-skirmish-wolBenito.*`, `accent/accent.csv`).
- The same vs wolOtto: no error (`accent/accent-control.csv`).
- The 2026-11-11 Levant 8-player skirmish failed at lines 583, 623, 666 and 706: an editor-route
  `trigtemp.xs` of Levant with 8 players shows that these are exactly the two texts of players 7 and 8
  (`runs/NEWLevant-p8-s1-scenario-wolreal2.trigtemp.xs`), and that game had two AIs with an accent
  in Spanish (Napoleón III, Carlos el Diplomático).
- The tokenizer rule itself: a test map (`uhcaccent.xs`) with string literals that hold "ó" as ANSI
  (F3h) or as UTF-8 (C3h B3h) fails to compile with the same three token errors, while the ASCII
  ones compile (`runs/uhcaccent-wolreal2.trigtemp.xs` and `engine-ext-WoLReal2-20261117.log`).
- **Not a race:** `trigtemp.xs` is shared by every running copy, but the failing lines matched the
  accented names in each case.

**Who gets it.** Any game where a player name has a letter outside ASCII: AI names (5 of the 49 WoL AI
names in English: Benito Juárez, Ramón Castilla, Simón Bolívar, Bartolomé Mitre, Francisco Morazán;
10 in the Spanish string table, which adds Víctor Manuel II, Francisco José I, Napoleón III, Carlos el
Diplomático and Solano López), and any human profile or multiplayer name with an accent. A quote (`"`)
in a name would break it too. `triggers\greatwar.xs:18` has the same pattern but is not included.

**The fix (tested, data only).** Read the name when the trigger runs instead of writing it into the
script:
1. `trigger3\wotta triggers.xml` gets an effect `Overlay Text Player Name` whose command is
   `trOverlayText(kbGetPlayerName(%PlayerID%)+"%Text%", %Duration%, -1, -1, -1, "None");`
   (WoL's diplomacy triggers in the same file already call `kbGetPlayerName` this way);
2. `triggerLoader.xs` uses it for its two texts, with `rmSetTriggerEffectParamInt("PlayerID", i)` and the
   text without the name.

With both in `C:\AoE3-UHC-WoLReal2` (restored afterwards), Acre vs wolBenito ran with no XS error, the
`trigtemp.xs` reads `trOverlayText(kbGetPlayerName(2)+" has entered the Great War Age!", …)`, and the
editor route compiles the same. That the text then shows "Benito Juárez" on screen was not filmed (the
trigger needs a homing pigeon or 15 Inquisitors). Fixed files: `wol-fixes/maps/fixed/` (made by applying
the two edits to `C:\WoL-Test`'s files).

**A DLL key instead?** One could make the XS tokenizer accept bytes above 7Fh inside strings, which would
also cover other scripts. It needs REA work on the tokenizer (not started) and changes how every XS script
compiles, while the data fix is two small edits in WoL's files. Recommended: the data fix. No key was
built.

### The setup screen falls back to "NEW" Barbary Coast

The skirmish setup restores the profile's map by the name it shows (`gamemapname`). A name that starts
with a quote, like every `"NEW" …` map, never matches, not even the value the game saved itself.
The setup then shows the first map of its list, and `"NEW" Barbary Coast` is first (`"` sorts before
letters). The list opens with the 11 map sets (Mapas acuáticos, …, Mapas terrestres), then the maps by
shown name: `"NEW" Barbary Coast` is entry 11, `"NEW" Levant` entry 19.

So a player who set up Levant last time and starts again without looking gets Barbary. Our first
three "Levant skirmish" runs were Barbary, relabelled in `levant.csv`. `mapsweep.py` now picks a
quoted map in the list by posted clicks (`start_skirmish`) and calls a run `wrong-map` when the dump
of the map it asked for was not rewritten. On 2026-11-17 one Acre run (a name without a quote) also
got Barbary; most likely another session's game rewrote the shared profile between the edit and the
launch. The re-run was fine.

### Static check: names the data does not define (`rmlint.py`)

25 maps (88 lines) use names that the bed's data does not define:

- **Civs:** NEWBahia (Bandeirante); WOLGibraltar (AURloil, Fishing); WOLsavannah (AURCattle).
- **Water:** NEWDinarides (`rmSetSeaType("x")`); ESOC_Wadmalaw (Wadmalaw Water).
- **Protos and types from another game:** NEWHinduKush, WOLblackforest, WOLvalleyofkings, WOLwetlands,
  WOLwateringhole (`animalPredator`, `tower`); dansil_Micronesia (`borneo_underbrush`); dunas (`…W` protos).
- **Groupings:** dunas, everglades, WOLsahel, WOLsavannah.
- **Cliffs:** GANWakhan (`himalayas_a`/`_b`); ESOC_Parallel Rivers (`japan`).
- **Forest:** WOLsahara (`caribbean forest`).
- **False positive:** the XPAztec hits (indochina, saguenay, texas, …) are an error of the civ check.
- **Grouping misses are only leads:** the stock groupings live in Data.bar.

Every one of these maps ran ok in the sweep (2 players, seed 1), so a missing name costs a feature of
the map at most (a missing object, the default water), not a crash. `vividlyKolkata.xs:915` has
`If (PlayerNum > 2)` with a capital I: it compiled with no XS error, so the lead that it cannot compile
is dropped.

## Map descriptions (2026-11-17)

JTMaston asked for map descriptions in one standard format, in the lobby (the minimap rollover) and on
the loading screen: a short description, trade route, natives, huntables, mines, berries, outlaws,
region. Deliverable for WoL: `wol-fixes/map-descriptions/` (README in English). Evidence:
`rea/evidence/map-descriptions-20261117/` (gitignored).

**The facts come from the scripts.** `tools/mapfacts.py` reads every `RM4\*.xs` and writes a row per
map ([tools/README.md](../tools/README.md#mapfactspy)); the table for all 208 maps is
`wol-fixes/map-descriptions/mapfacts.csv`. Notable reads: Atacama's natives are inside a comment (it
has none); Rockies has Cheyenne **or** Comanche, never both; Irrawaddy River's "dry season" branch can
never run (`seasonSwitch` is 1–6 and the dry case is 0), so it always has 3 fords (4 with 6+ players),
whatever its current text says; the file `everglades` is the map Pohnpei.

### In-game validation

`mapsweep.py` (editor route, 2 players, seeds 1 and 2, 3 s of game time) now keeps each run's full
unit list (`units/`), and `mapfacts.py --check` compares it with the script facts. Runs: 416 (two
shards, `C:\WoL-Test` and a hard-link copy `C:\WoL-Sweep1` made for the sweep and deleted after),
`sweep/units.csv`; 414 ok, 2 crashes (below). **163 maps agree on everything, 45 have at least one
difference**, each in the `check` column of `wol-fixes/map-descriptions/mapfacts.csv`: 21 maps whose
natives never appeared (most WoL European maps among them), 17 resources placed only in some setups,
16 gaia units the script does not place (Badger, ypIGCBird…), 4 native mismatches, Hawai'i's water
route without a post site. The tool was fixed on the way for: natives read from the grouping files'
sockets (ESOC Bengal sets Sufi/Udasi but places Bhakti), definitions never placed, missing grouping
files, conditional placements, African trade sites, comments in `civs.xml`/`protoy.xml`.

**Two crashes, not reproduced:** WOLethiopianhighlands seed 1 (EIP 0x5907B6) and WOLFjord seed 2
(0x44824E), both `0xC0000005` while generating the map, within 20 s of each other, after about 80
maps in each game process (16:03). Re-run in fresh games (crash watch attached): both ok
(`sweep/rerun.csv`). Most likely the long session; worth keeping in mind for the players' crash
reports (a long session of rematches?).

### Outlaws: which mapspecifictechs block a map gets

**Rule (REA on the stock exe, confirmed in game).** Each `<map name>` block of
`data\mapspecifictechs.xml` is turned into a **map type ID** when the file loads; the game takes the
**first block in file order** whose type the map has. So:

- `rmSetMapType` decides, not the map's file name. A block named after a file (`DansilChupat`,
  `ESOC_Arizona`, `WOLhawaii`…) is dead unless that name is also a type in `maptypes.xml`: **108 of
  the 157 blocks are never used**. Only `WOLcave` works, because `WolCave` is a map type.
- Names compare without case (the hash upper-cases, 0x5F5412), so the early `Arabia` block (4th)
  shadows the late `arabia` one (154th): Arabia gets Pistolero and Renegado, never the Muharib, Sariq
  and Khali of `arabia`.
- The order of the map's `rmSetMapType` calls does not matter; `default` (the last block) is always
  set, so a map with no matching type gets `default` (Pistolero, Renegado, 3 random).
- An unknown type in `rmSetMapType` is ignored ("'%s' is not a valid map type. Ignoring.").

| Step | Where | Evidence |
|---|---|---|
| Load: per `<map name>`, `entry[0] = FUN_00527A08(name)` (map type ID or -1), then `tech`, `forceTech`, `randomTech` and `randomNumToUse` | FUN_00528587 (`mapspecifictechs.xml`, 0x2C-byte entries at `[db+61CCh]`, count `[db+61D0h]`) | `ev_9def0c58…` |
| Name → map type ID: hash lookup in the table at `[db+60ECh]` | FUN_00527A08 → 0x5F5412 (upper-cases), 0x40295B | `ev_c537c944…`, `ev_e8906a78…`, `ev_354703f2…`, `ev_4d234cd7…` |
| That table is `maptypes.xml` | FUN_005278DA | `ev_c6b7d251…` |
| `rmSetMapType`: lookup in the same table; unknown → "Ignoring."; known → set bit (0xA026AD) in the world's map-type bitset `[world+88Ch]` | handler 0x90F1EC (registered at 0x6142B8) | `ev_4060177c…`, `ev_faab8de0…`, `ev_59df166b…`, `ev_516dfe85…` |
| Pick: the first entry whose ID's bit is set | FUN_00A02DAF (one caller, 0x6AEC02) | `ev_56e9552b…` |
| Random techs of the picked block | FUN_00A02C76 | `ev_445aada2…` |
| `default` set when a game is loaded (`FUN_00527A08("default")` → 0xA026AD) | FUN_00A09B47 | `ev_ac044784…` |

Bundle: `rea/evidence/map-descriptions-20261117/outlaws-rea.json`. Inference, not observed: that a new
game sets `default` the same way as a loaded one (the in-game tests below are consistent with it).

**In game (WoL-Test, editor route, a Saloon added to the script for the test and removed after):**
DansilChupat (types `land grass araucania`; it has a block `DansilChupat` with Pistolero and
Comanchero) trains Hired Proscrito, Hampon and Hired Cuatrero, which is the `araucania` block, plus 3
random (Kolo, Bashi-Bazouk, Maharul); Arabia (type `arabia`) trains Pistolero and Renegado, the
`Arabia` block, plus random ones. Shots: `outlaws/DansilChupat-s1-*.png`, `outlaws/Arabia-s1-*.png`.

### What the lobby and the loading screen show

Tested in WoL-Test (Spanish, 1920 × 1080), skirmish setup with a posted hover on the minimap, and the
loading screen through a DWM thumbnail (the copy's window is kept under the other copies' windows by
`multipleInstances background`, and `PrintWindow` returns black while the game loads):

- **Lobby rollover** = `details` (or `detailsText`); **loading screen** = `loadDetails` (or
  `loadDetailsText`).
- **An ID wins over literal text** when a map has both (`details="ID" detailsText="…"`), in both places.
- Attribute names are **case-insensitive**: `detailstext` and `loadDetailsTEXT` work. The misspellings
  are harmless; the fix writes the standard names anyway.
- **`\n` (backslash, n) breaks the line** in both; a real line break in the XML does not.
- **Markup:** `<color=r,g,b>…</color>` works (r, g, b from 0 to 1); `<icon=(20)(path)>` and `<u>…</u>`
  work (ESOC maps use them); `<b>` is swallowed with no effect.
- **Room:** the rollover is about 450 px wide (about 55 characters per line) and grows downwards; 22
  lines still fit at 1080p. The loading box is about 610 px wide (about 80 characters per line) and
  **shows 15 lines, then cuts the text**; the player list stays below it.

Shots: `template2/` (lobby), `template4/` (loading), `before/` and `after2/` (the pilot; `after/`
is a first take with two errors fixed since). A space right after `</color>` is dropped, so the
labels carry their space inside the tag.

**Capturing the loading screen.** `PrintWindow` gives black frames while the game loads, and the
copy's window cannot be raised (`multipleInstances background` adds `SWP_NOZORDER` to every
`WM_WINDOWPOSCHANGING`, `src/features/instances.cpp`). What works: a topmost, non-activating window
of the test script that shows the game window through a DWM thumbnail (`DwmRegisterThumbnail`),
read from the screen with `BitBlt` every 0.2 s for the few seconds of the load. It covers the other
copies' windows for those seconds only; their `record` uses `PrintWindow`, which it does not
affect. The script is `rea/evidence/map-descriptions-20261117/scripts/desc_test.py` (with `outlaw_test.py`, the saloon test); not a tool yet.

### The pilot (5 maps)

Irrawaddy River (river), Hawai'i (island), Atacama (desert), Rockies (mountain), Alps (no trade route),
English and Spanish, in `wol-fixes/map-descriptions/` (`texts.csv` → `make_descriptions.py` →
`descriptions.csv` → `apply_fix.py`). String IDs 6170000–6170415, two per map for all 208 maps
(`string-ids.csv`), free in every string table of the copy. The game corrected the scripts' facts in
four of the five: Hawai'i's Jesuit and Sufi villages use groupings "1"–"5" that do not exist (its
natives are the Heiau temples) and its water trade route places no post site; Alps' three European
camps use groupings that do not exist (`EURNShunters med`…) and its grapes are never placed;
Irrawaddy's berries are never placed. `mapfacts.py` now reports such cases (`defined_not_placed`,
`missing_groupings`).

**Found on the way, for WoL:** in `data\civs.xml` the `AURCattle` entry opens with `<!-- civ>` and
closes with `</civ>`, so the comment runs on to the next `-->` and swallows 20 AUR civs (AURCocoa …
AURGems). Not settled in game: the AUR trade-site buildings (units `AUR<resource>`, "Socket
<resource>") still appear on Atlas, Niger River, Azores, Bioko…, which place them through groupings;
Blue Nile placed none in 2 games (cause not looked into). `mapfacts.py` counts these
sites as natives ("Cocoa (trade site)").

### The full run (all 208 maps)

- **Texts.** `texts.csv` holds the first line and the 2–3 sentences of every map in English and
  Spanish, written by four parallel writers from the facts, the old texts and the scripts, then
  merged (`merge_texts.py` in the evidence `scripts/`): clean names at the start (no `Lrg`, `"NEW"`,
  `Gran`), author credits from the old texts (80 maps).
- **The game wins.** `mapfacts.py --check` writes `game_*` columns (what the game placed in the two
  sweep games); `make_descriptions.py` uses them, so the 21 maps whose natives never appear say
  "none", Hawai'i says "Trade route: No", and so on. The route's type (`water`) is only its look
  (TAD's Mongolia and Deccan use it on land), so the descriptions no longer say "(water)".
- **The 1024 × 768 loading box** holds about 45 characters × 12 lines (measured; the font keeps its
  size), against 80 × 15 at 1080p. The loading text therefore starts with the story (the box already
  shows the name), uses a compact fact block (lists of 3, King of the Hill only when present) and is
  cut by `fit_loading()` from an estimate of the wrapped lines: credit first (it stays in the lobby),
  then the story's last sentences, then the Sea line. Seven maps got a shorter first sentence by hand
  so that every loading text keeps one.
- **1024 × 768 in game:** the resolution is the shared profile's `optiongrfxres`;
  `res_launch.py` (evidence `scripts/`) sets it under `testbed.py`'s start lock, launches, puts it
  back, and puts it back again after the close (the game rewrites the profile on exit). Click layout
  at 1024 × 768 in `desc_test.py` (`LAYOUT_768`).
- **English shots.** WoL-Test's `data\stringtabley.xml` is the Spanish translation; `lang_mode.py`
  copies the English table (`translations\_originals`) over it for the captures and puts the Spanish
  one back from the backup (checked by hash).
- **The lobby rollover** opens right of the mouse and grows to ~55 characters; hovering the right of
  the minimap the screen edge cut it (Texas, first take). `narrow()` now gives every fact its own line
  and breaks lines at 44 characters, so the box stays narrow.
- **Re-test in game (English, `v2-en`, `v2-en-768`, `v2-es`, `v2-es-768`):** 27 maps at 1080p, 8 at
  1024 × 768, 5 + 2 in Spanish: every rollover and loading text complete (`rollcheck.py` checks that
  each lobby shot shows a rollover; `desc_test.py` retries the hover until it does). Media:
  `wol-fixes/map-descriptions/media/`, English, Spanish only as `-es` extras.
- **Seen, not explained:** on Hawai'i, Atacama, Rockies and Alps the OLD lobby text (a string ID such
  as `details="28829"`) opened no rollover in either language, while old literal texts and our new IDs
  do.
- **King of the Hill** is still the current maps' (`koth` column, PENDING the KOTH pack).
- **Leads for WoL** with file and line: `wol-fixes/map-descriptions/leads.csv` (108 dead and 1
  shadowed `mapspecifictechs.xml` blocks, the `civs.xml` comment, 36 maps with missing grouping files,
  34 resources in 29 maps never placed). A fix of the tool on the way: an empty first value
  (`string a = "";`) no longer counts, which took the "missing groupings" from 49 maps to 36.

## What is left

1. **No crash reproduced.** The players' crash reports remain unexplained. Next: the suspects at more
   players and seeds (the 22 NEW maps, the rmlint maps), editor route at 4 and 8 players × 3 seeds,
   and skirmishes with European AIs, which only one copy can run at a time (the profile is shared).
2. **Ask the reporters** which map, how many players, which AIs, and whether the game closed or froze;
   whether the crash may be the trigger-name bug's consequence was not seen anywhere.
3. For any crash: the EIP, then REA (take `rea.lock`; snapshot `rea/snapshots/age3y-b1a1dab7-rea68.json`).

## Resume

Back up the profile first; the games rewrite it when they exit:

- `My Games\Wars of Liberty\Users3\*.xml` and `*.dat`
- `Savegame\sp_*_homecity.xml` and `LastHomeCityY.xml`
- `AI4\*`

Backups: `profile-backup/` (2026-11-11) and `profile-backup-20261117/`. Other sessions use the same
profile at the same time (on 2026-11-17 the home city agent rewrote `sp_*_homecity.xml` every few
minutes), so do not restore it byte for byte: restore only what the runs changed. For the skirmish
route that is the `RandomMapGameSettings` block of the profile, which
`accent/accent_skirmish.py` (one skirmish through `mapsweep.run_one`) puts back while leaving the rest; `mapsweep.py`'s own
skirmish restore is byte for byte and only safe when nothing else runs. Install the harness:

```
copy build\Release\dinput8.dll C:\WoL-Test\
mkdir C:\WoL-Test\engine-ext
(perfExecFile C:\WoL-Test\uhc-exec.txt, multipleInstances background, xsErrorLog, perfStats, one per line)
  > C:\WoL-Test\engine-ext\engine-ext.cfg
python -I tools/mapsweep.py --bed C:\WoL-Test --csv rea/evidence/wol-maps-20261111/sweep.csv ^
  --list rea/evidence/wol-maps-20261111/maps-wol-test.txt --shard 0/2
python -I tools/mapsweep.py --bed C:\WoL-Test --csv rea/evidence/wol-maps-20261111/second.csv --match "^NEW" ^
  --players 4,8 --seeds 1,2,3
```

**Parallel copies.** A second bed needs WoL's DLL (`uhc.dll.wol-orig` in the WoLReal copies) and
WoL-Test's `Startup\wol.cfg`, our harness, and `--list maps-wol-test.txt`, so its own `uhc*` test maps
are left out. At most 3 games. Expect `trigtemp.xs` races only with AI names that have an accent.

**Afterwards** remove `dinput8.dll` and `engine-ext\`, put back the bed's own DLL and cfg, and compare
the hashes. Delete the `Age3RM*.dmp.txt` files the runs added in `My Games\Wars of Liberty\RM4` (only
those of the swept maps: other sessions write theirs there too), and take the sweep's scenarios out of
`RecentFilesy.xml`; `close` already removes the `uhc-*` scenarios.
