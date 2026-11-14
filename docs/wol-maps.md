# WoL random maps: crash hunt (status, 2026-11-11)

Private: not in `tools/export_public.py`'s INCLUDE list. Players report that several WoL random maps crash
the game, e.g. "NEW" Levant (`RM4\NEWLevant.xs`), while the ESOC maps work. This note says what was
tested, what was found and how to resume. **No crash has been reproduced yet.** Evidence:
`rea/evidence/wol-maps-20261111/` (gitignored): `sweep.csv`, `levant.csv`, `levant-ourdll.csv`, `runs/`
(testbed output, `engine-ext.log` and `Age3Log.txt` lines per run), `shots/`, `crash-*.jsonl`, `rmlint.py` and
`rmlint.csv`, the setup screenshots and the backups.

## How it was tested

- **Harness.** `C:\WoL-Test` (WoL's own `uhc.dll` c070d138, the DLL players have) plus our `dinput8.dll` and
  `engine-ext\engine-ext.cfg` with only `perfExecFile`, `multipleInstances background`, `xsErrorLog` and
  `perfStats`. All four bed files (`uhc.dll`, `Startup\wol.cfg`, `age3y.exe`, ReShade's `d3d9.dll`) had
  the same hashes before and after (`hashes-before.txt`).
- **Tools.** `tools/mapsweep.py`, using `testbed.py` (exit codes 3 = died, 4 = hung) and
  `re/debugger.py crash`, attached to every game it starts. Each row of the CSV is one run.
- **Routes.** *Editor:* `startRandomGame2` in the scenario editor, saved and loaded as a scenario,
  players without AI, 30 s of game time. *Skirmish:* the setup screen with AIs, 90 s, the map checked by
  the time stamp of `My Games\Wars of Liberty\RM4\Age3RM<file>.dmp.txt` (the game writes it when it
  compiles a map).

## Results so far

| Test | Runs | Result |
|---|---|---|
| Levant, editor, 2/4/8 players × seeds 1–3, WoL's DLL | 9 | 9 ok |
| Levant, editor, the same with our DLL (`C:\AoE3-UHC-WoLReal`) | 9 | 9 ok |
| "NEW" Barbary Coast, skirmish, Dutch vs one AI (wolOtto), WoL's DLL | 3 | 3 ok |
| Levant, skirmish, WoL's DLL, European AIs only | 3 | 2 and 4 players ok; 8 players: no crash, but `xs-error` (below) |
| Levant, skirmish, our DLL, 2 players | 1 | ok |
| All maps, editor, 2 players, seed 1 (sweep, stopped) | 71 of 208 | 71 ok: Arabia … ESOC_*, Dansil*, most NEW maps (list in `sweep.csv`) |

### The setup screen falls back to "NEW" Barbary Coast

The skirmish setup restores the profile's map by the name it shows (`gamemapname`). A name that starts
with a quote, like every `"NEW" …` map, never matches, not even the value the game saved itself.
The setup then shows the first map of its list, and `"NEW" Barbary Coast` is first (`"` sorts before
letters). The list opens with the 11 map sets (Mapas acuáticos, …, Mapas terrestres), then the maps by
shown name: `"NEW" Barbary Coast` is entry 11, `"NEW" Levant` entry 19.

So a player who set up Levant last time and starts again without looking gets Barbary. Our first
three "Levant skirmish" runs were Barbary, relabelled in `levant.csv`. `mapsweep.py` now picks a
quoted map in the list by posted clicks (`start_skirmish`) and calls a run `wrong-map` when the dump
of the map it asked for was not rewritten.

### Lead: the map triggers fail to compile with 8 players

Levant, skirmish, 8 players (Dutch + 7 European AIs), WoL's DLL. The game kept running for 90 s, but
`xsErrorLog` logged that `My Games\Wars of Liberty\Trigger3\trigtemp.xs` does not compile:
`Token Error 0008: string not terminated`, `0009: expected '=' after '!'` and `0007: line feed in
string` at lines 583, 623, 666 and 706, then `Error 0003: could not compile file 'trigtemp.xs'`. When
that happens, none of the map's triggers run.

- **Inference, not confirmed.** `RM4\triggers\triggerLoader.xs` (called by `wotta_triggers()` in 193
  maps) puts the player name into a trigger string literal, in two triggers per player:
  `rmGetPlayerName(i)+" has entered the Great War Age!"` (line 62) and `"… has started the
  Inquisition!"` (line 108).
- Four errors fit two players × two triggers. Two of the seven AI names have a non-ASCII letter:
  "Napoleón III" and "Carlos el Diplomático". So a name with an accent or a quote would break the
  generated script.
- **Not ruled out.** `trigtemp.xs` is one file shared by every running copy of the mod, and two sweep
  copies were writing theirs at the same time. The script itself was not kept: `mapsweep.py` now keeps
  it per run.
- **To confirm:** one copy alone, Levant 2 players, once with only `wolNapoleon` and once with only
  `wolOtto`.
- **If it holds:** it is a map-script bug, so the fix is a copy of `triggerLoader.xs` that writes
  `"Player "+i` instead of the name (XS has no way to escape the name). Whether a broken trigger script
  can crash later in a game is not known.

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

Separately, `vividlyKolkata.xs:915` has `If (PlayerNum > 2)`: XS keywords are case-sensitive, so this
should not compile. Of these maps, NEWHinduKush ran 2 players ok; the others were not reached by the
sweep or were reached without an error.

## What is left

1. Finish the sweep: 137 runs left.
2. Confirm or drop the trigger-name lead (above).
3. Second pass on the suspects: the 21 NEW maps, the rmlint maps and vividlyKolkata. Editor at 4 and 8
   players × 3 seeds, and a skirmish with European AIs.
4. For any crash: the EIP, then REA (take `rea.lock`; snapshot
   `rea/snapshots/age3y-b1a1dab7-rea68.json`). Then a fixed map copy under
   `rea/evidence/wol-maps-20261111/fixed/` with a diff for WoL's developer, or a DLL key / `dataLint`
   proposal for the user.

## Resume

Back up the profile first; the games rewrite it when they exit:

- `My Games\Wars of Liberty\Users3\*.xml` and `*.dat`
- `Savegame\sp_*_homecity.xml` and `LastHomeCityY.xml`
- `AI4\*`

One backup is in `profile-backup/`. Install the harness in `C:\WoL-Test`:

```
copy build\Release\dinput8.dll C:\WoL-Test\
mkdir C:\WoL-Test\engine-ext
(perfExecFile C:\WoL-Test\uhc-exec.txt, multipleInstances background, xsErrorLog, perfStats, one per line)
  > C:\WoL-Test\engine-ext\engine-ext.cfg
python -I tools/mapsweep.py --bed C:\WoL-Test --csv rea/evidence/wol-maps-20261111/sweep.csv
python -I tools/mapsweep.py --bed C:\WoL-Test --csv rea/evidence/wol-maps-20261111/levant.csv --maps NEWLevant ^
  --players 2 --seeds 9 --route skirmish --seconds 90 --ai wolNapoleon
python -I tools/mapsweep.py --bed C:\WoL-Test --csv rea/evidence/wol-maps-20261111/second.csv --match "^NEW" ^
  --players 4,8 --seeds 1,2,3
```

**Parallel copies.** To go faster, use full copies of `C:\WoL-Test` with their own `perfExecFile` path
and `--shard K/N`, with at most 3 games. Expect `trigtemp.xs` races: re-run any `xs-error` alone.

**The skirmish route** edits the shared profile, so run one at a time. Afterwards, remove `dinput8.dll`
and `engine-ext\`, then compare the four hashes. Delete the `Age3RM*.dmp.txt` files the runs added in
`My Games\Wars of Liberty\RM4`; `close` already removes the `uhc-*` scenarios.

**State when stopped.** `C:\WoL-Sweep1` and `C:\WoL-Sweep2`, two full copies of `C:\WoL-Test` (about
11.8 GB each), were left on disk: the agent's removal was refused by a safety check. They hold no
unique data; delete them by hand.
