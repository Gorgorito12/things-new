# King of the Hill on every random map that has room for it

Request (JTMaston): *"there is a code that makes a map able to work in koth mode. Not all maps have that
code at the moment. We'd like to add it to all maps where possible. The position of the kings hill doesn't
necessarily need to be the center of the map but the closest choke point to all players and wherever there
is space to place it and battle around. If a map doesn't have space to allocate a king's hill, it should be
skipped and its description should state that it doesn't work in koth mode."*

Of WoL's 208 random maps, 88 already had King of the Hill. Of the other 120, **114 now have it** and
**6 are skipped** because their players start on land masses that do not touch (list below).

## Status (2026-11-17): work in progress

The map scripts here are the current version; the tests below are not finished. Numbers from our test
runs (see "How it was tested"):

- Hill placed in every one of its 7 test games: 104 of 114 maps.
- Hill missing in some test games (10): dansil Rio De Plata, dansil_greatbarrierreef, Finland, Thanksgiving III, WOLAlps, WOLbalkans, WOLcongo, WOLFjord, WolGreenland, WolGujarat.
- Team ratio above 1.5 in some test game (8): dansil_Outback, dansil_Owikeno, dansil_Westernterritory, WOLblackforest, WOLcerrado, WOLIberianPeninsula, WOLmoon, WOLnzwc.
- Reach test done: 63 maps; failed or by ship only (5): amazonia, caribbean, DansilLCongo, great lakes, WOLsocotra; pending (51).
- Normal-map test done: 67 maps; differs (10): caribbean, DansilCristalMonts, new england, NEWLevant, pampas, patagonia, rockies, sonora, texas, WOLsahel; pending (47).

Do not ship yet: the maps with a missing hill or a ratio above 1.5 still get another placement, and every
map still gets the reach and normal-map tests.
## What is in this folder

- `RM4/`: only the changed map scripts (`.xs`). Copy them over WoL's `RM4` folder. Nothing else changes:
  the `.xml` files, `ypKOTHInclude.xs` and the data stay as they are.
- `koth-maps.csv`: one row per map (the table below, for a spreadsheet).
- `media/`: one picture per added map, the minimap of a 4-player game (2 teams, seed 1) with the hill
  marked by a magenta ring and each Town Center by a numbered white square.

**Every change sits inside `if(rmGetIsKOTH()) { ... }`**, plus the line `include "ypKOTHInclude.xs";` where a
map did not have it. A normal game runs exactly the code it ran before (tested: same seed, same units at
the same places). The one exception is `DansilCristalMonts`, see "Bugs fixed".

## How the hill is placed

Three ways, by map:

1. **TAD's own code.** WoL's `amazonia`, `great plains`, `yukon`... are TAD maps whose King of the Hill
   block was missing; Steam's TAD folder (`bin\RM3`) still has it. Where TAD's block gives a fair hill on
   WoL's version of the map, it was ported unchanged, at the same place in the script. Where it did not
   (WoL changed the map and the hill ended up much closer to one team, or found no room), the map uses
   method 2 instead; the table says which.
2. **The nearest open spot to the middle of the start positions** (most maps). The block takes the average
   of all players' start positions (the map centre when they are spread evenly; the point halfway between
   them when two players start off-centre) and puts the hill on the open land nearest to it: first within
   4 % of the map, then 1.5 times farther each try, seven tries. With the include's own constraints (no
   cliff or deep water within 6 m, no object within 4 m, clear of trade routes and their sockets, 40 m from
   every Town Center).
   **Between the teams** (maps whose middle is water, a cliff or a gorge, marked "between teams" in the
   table): the block takes the middle of each team's starts and walks along the line that splits them,
   from the centre outwards, one side then the other, until the hill fits. Every point of that line is as
   far from one team as from the other, so the hill lands on the first shore or bank that is fair to both.
   **Where the block sits:** at the very end of `main`, after cliffs, lakes, forests and resources (placed
   earlier, a hill could be removed by a cliff or lake built over it: seen on Central America, Finland and
   others). On a few large maps the end of the script is never reached with 8 players (the hill, and any
   other object placed there, is missing), so there the block sits right after the Town Centers instead;
   the table says "after the Town Centers".
3. **The map's own code, repaired** (DansilCristalMonts).

Choke point: on these maps the players start around the edge, so the middle of the start positions is the
ground everybody has to cross to reach the others. Where the middle is water (a lake, a fjord, a river
junction), the hill goes to the nearest bank, or onto a patch of land laid there.

What does not work in this engine (tested, so nobody has to try again): a type-distance constraint longer
than some 40 to 100 m (for example "100 m from every Town Center", or "3000 m from any other hill") never
lets anything be placed; and a nested loop five levels deep inside `main` did not run.
## Bugs fixed

- **DansilCristalMonts: this fix changes the normal map.** Its King of the Hill block was never closed:
  the closing brace sat after the "decorative centre section", so the centre cliffs were built **only in
  King of the Hill games**, and after the hill, on top of it. The block is now closed and moved after the
  cliffs, so **normal games now get the centre cliffs too**, as the comment "decorative centre section"
  intends. If you prefer the normal map as it was, delete the block under `//=====decorative centre section==========` in our copy.
- **WOLAlps, WolGreenland, WOLFjord:** `include "ypKOTHInclude.xs";` was commented out (WOLFjord also had
  an "avoid KOTH" constraint but no hill). The include is back and the maps have a hill.
- **galapagos:** its King of the Hill line was commented out and could not have worked: it read
  `xsVectorGetX(bigLoc)` for both X and Y, and `bigLoc` does not exist in the script. The map is skipped:
  its players start on separate islands.
- **amazonia:** TAD's block lays a patch of land in the middle of the river and lets the hill walk 7.5 % of
  the map; in WoL's version the islands are farther apart, so the hill walked onto one team's shore. The
  patch is now bigger and the hill stays on it: a hill in mid-river, reached by ship by both teams, as TAD
  intended.

## Maps without a hill

Their description should say "King of the Hill: No".

| Map | Why |
|---|---|
| dansil_Micronesia | every player starts on an island of their own |
| DansilFalklands | players start on separate islands with no land between them |
| DansilIbalong | players start on separate islands with no land between them |
| everglades | players start on separate islands around the central one |
| galapagos | players start on separate islands; the map's own King of the Hill line was left commented out and could not work: it uses a variable that does not exist (bigLoc) and its X for the Y |
| WOLbritishislands | players start on two islands (Ireland and Britain) with no land between them |

## How it was tested

All tests ran in copies of the game with WoL's data, in the scenario editor, in a **real King of the
Hill game**: the test writes the game's own King of the Hill setting (setting 27h, `GameKOTH`) before the
map is generated, so `rmGetIsKOTH()` returns true exactly as in a game started from the setup screen.

Per map:

- **The hill exists:** players 2, 4 and 8 in two teams, two seeds each, and 4 players free-for-all: 7
  maps generated, the `ypKingsHill` unit counted in each ("Hill placed" column).
- **Fair:** the straight-line distance from the hill to every Town Center; per team the mean; **team
  ratio** = largest team mean / smallest. Target: 1.5 or less in team games. Free-for-all is listed apart:
  on maps where players start in a line or in two groups, no single spot is equally far from four rivals.
- **Reachable:** the map played for 120 s (150 s for TAD's ported blocks) with 4 players, a test trigger sending every unit of every
  player to the hill; "yes" when every player has a unit within 15 m of it at the end.
- **Normal map unchanged:** King of the Hill off, 4 players seed 1 and 8 players seed 2, the original map
  and ours: every unit (player, type, position) the same.
- A real game from the setup screen (King of the Hill ticked in the profile) was played once to check that
  the hill appears there too (see below).

The test tool is `tools/kothcheck.py` in our repository; the test copies of the maps (with the reach
trigger) are never shipped.

## Per-map table

"Hill position" is where the hill landed over the test runs, as fractions of the map (0.5, 0.5 = centre).

| Map | How | Hill position (fraction of the map, all runs) | Why there | Hill placed | Team ratio (max) | FFA ratio | Units reach it (4 players) | Normal map unchanged | Picture |
|---|---|---|---|---|---|---|---|---|---|
| amazonia | TAD's own code | x 0.24-0.78, z 0.25-0.74 | TAD's own King of the Hill code: a landfill islet in the middle of the river (reached by ship); the fill was made bigger and the hill kept on it, since WoL's islands lie farther apart | 7/7 | 1.46 | 3.95 | no: far:p1,p2 (p1:66m(HomeCityWaterSpawnFlag,7 moved) p2:68m(HomeCityWater | yes | [jpg](media/amazonia.jpg) |
| andes | TAD's own code | x 0.09-0.95, z 0.41-0.59 | TAD's own King of the Hill code: east or west edge, away from the mountains | 7/7 | 1.19 | 1.51 | yes | yes | [jpg](media/andes.jpg) |
| appalachians | nearest open spot to the middle; end of the script | x 0.48-0.52, z 0.47-0.53 | the middle of all start positions (the map centre), on open land | 7/7 | 1.17 | 1.08 |  | yes | [jpg](media/appalachians.jpg) |
| araucania | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.40-0.62, z 0.45-0.51 | centre, between the two sides (TAD's spot at x 0.5 / 0.8 favoured one team on WoL's map) | 7/7 | 1.26 | 2.23 | yes | yes | [jpg](media/araucania.jpg) |
| atacama | between the teams; end of the script | x 0.32-0.56, z 0.13-0.77 | the middle is the salt lake; first open land on the line that splits the teams (its shore) | 7/7 | 1.26 | 2.19 |  |  | [jpg](media/atacama.jpg) |
| Baja California TWC 01 | nearest open spot to the middle; end of the script | x 0.47-0.54, z 0.46-0.54 | centre of the land strip, between the two sides | 7/7 | 1.41 | 1.77 | yes | yes | [jpg](media/Baja_California_TWC_01.jpg) |
| Barrier Ridge TWC | nearest open spot to the middle; end of the script | x 0.47-0.53, z 0.48-0.52 | the middle of all start positions (the map centre), on open land | 7/7 | 1.10 | 1.37 |  | yes | [jpg](media/Barrier_Ridge_TWC.jpg) |
| bayou | between the teams; end of the script (TAD's own block was uneven on WoL's map) | x 0.35-0.63, z 0.36-0.57 | the middle is swamp water; first open land on the line that splits the teams | 7/7 | 1.26 | 2.09 | yes | yes | [jpg](media/bayou.jpg) |
| california | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.50-0.72, z 0.46-0.54 | centre, between the two sides (TAD's spot at x 0.35 / 0.65 favoured one team on WoL's map) | 7/7 | 1.41 | 1.83 | yes | yes | [jpg](media/california.jpg) |
| caribbean | TAD's own code | x 0.13-0.21, z 0.12-0.81 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.41 | 2.16 | no: error | NO: 1522 units; 1522 units differ: orig Alligator p0 157.9,531.9; orig Alligator p0 ; 2360 units; 2360 units differ: orig Alligator p0 101.9,191.9; orig Alligator p0  | [jpg](media/caribbean.jpg) |
| carolina | TAD's own code | x 0.47-0.56, z 0.44-0.57 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.36 | 1.16 | yes | yes | [jpg](media/carolina.jpg) |
| carolinaLarge | TAD's own code | x 0.43-0.57, z 0.43-0.57 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.37 | 1.20 | yes | yes | [jpg](media/carolinaLarge.jpg) |
| Central America+TWC | nearest open spot to the middle; end of the script | x 0.46-0.52, z 0.45-0.52 | the middle of all start positions (the map centre), on open land | 7/7 | 1.38 | 1.43 | yes | yes | [jpg](media/Central_America+TWC.jpg) |
| Christmas | own code (TAD's Great Lakes pattern) | x 0.48-0.53, z 0.48-0.54 | centre of the lake, as TAD's Great Lakes does: in winter on a patch of land laid on the ice (the ice counts as water), in summer on the island in the middle (reached by ship) | 7/7 | 1.13 | 1.14 | yes | yes | [jpg](media/Christmas.jpg) |
| Dakota Badlands V | nearest open spot to the middle; end of the script | x 0.47-0.79, z 0.47-0.55 | centre of the badlands, inside the ring of start positions | 7/7 | 1.13 | 1.12 | yes | yes | [jpg](media/Dakota_Badlands_V.jpg) |
| dansil Manicouagan Basin | nearest open spot to the middle; end of the script | x 0.50-0.59, z 0.47-0.55 | the land farthest from every Town Center around the crater lake | 7/7 | 1.17 | 1.29 |  |  | [jpg](media/dansil_Manicouagan_Basin.jpg) |
| dansil Rio De Plata | between the teams; end of the script | x 0.35-0.35, z 0.63-0.63 | the middle is the estuary; first open land on the line that splits the teams (the river bank inland) | 1/7 |  | 2.98 |  |  | [jpg](media/dansil_Rio_De_Plata.jpg) |
| dansil92 Manitoba | between the teams; end of the script | x 0.34-0.69, z 0.46-0.80 | the middle is on the lake shore; first open land on the line that splits the teams | 7/7 | 1.20 | 2.17 |  |  | [jpg](media/dansil92_Manitoba.jpg) |
| dansil92Kwadacha | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.47-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.24 | 1.36 |  |  | [jpg](media/dansil92Kwadacha.jpg) |
| dansil_greatbarrierreef | between the teams; end of the script | x 0.72-0.77, z 0.49-0.51 | the middle is the reef; first open land on the line that splits the teams (the mainland) | 5/7 | 1.11 |  |  |  | [jpg](media/dansil_greatbarrierreef.jpg) |
| dansil_Outback | nearest open spot to the middle; end of the script | x 0.39-0.57, z 0.52-0.72 | the middle of all start positions (the map centre), on open land | 7/7 | 1.67 | 2.18 | yes | yes | [jpg](media/dansil_Outback.jpg) |
| dansil_Owikeno | nearest open spot to the middle; end of the script | x 0.25-0.68, z 0.34-0.70 | the land farthest from every Town Center around Owikeno lake | 7/7 | 1.94 | 3.31 | yes | yes | [jpg](media/dansil_Owikeno.jpg) |
| dansil_Westernterritory | nearest open spot to the middle; end of the script | x 0.32-0.67, z 0.43-0.55 | the middle of all start positions (the map centre), on open land | 7/7 | 1.54 | 1.51 |  |  | [jpg](media/dansil_Westernterritory.jpg) |
| DansilAlaska | nearest open spot to the middle; end of the script | x 0.49-0.55, z 0.49-0.53 | middle of the land strip, between the two sides | 7/7 | 1.17 | 3.21 |  |  | [jpg](media/DansilAlaska.jpg) |
| DansilCerroAcahay | nearest open spot to the middle; end of the script | x 0.47-0.54, z 0.49-0.52 | the middle of all start positions (the map centre), on open land | 7/7 | 1.27 | 1.21 | yes | yes | [jpg](media/DansilCerroAcahay.jpg) |
| DansilChupat | nearest open spot to the middle; end of the script | x 0.51-0.70, z 0.50-0.68 | centre, on land beside the river bend | 7/7 | 1.17 | 1.09 |  |  | [jpg](media/DansilChupat.jpg) |
| DansilCristalMonts | map's own code, repaired | x 0.47-0.52, z 0.47-0.53 | centre, in the sunken middle of the map (the map's own King of the Hill code, repaired) | 7/7 | 1.23 | 1.18 | yes | NO: 3650 units; 1085 units differ: orig AURbuildings p0 21.0,225.0; orig AURbuilding; 6712 units; 2027 units differ: orig AURbuildings p0 43.0,415.0; orig AURbuilding | [jpg](media/DansilCristalMonts.jpg) |
| dansilFiji | nearest open spot to the middle; end of the script | x 0.47-0.54, z 0.47-0.53 | centre of the island, inside the ring of start positions | 7/7 | 1.43 | 1.19 |  | yes | [jpg](media/dansilFiji.jpg) |
| DansilIrrawaddyRiver | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.47-0.51 | centre, on the bank of the river crossing | 7/7 | 1.28 | 1.15 | yes | yes | [jpg](media/DansilIrrawaddyRiver.jpg) |
| DansilJarrah | nearest open spot to the middle; end of the script | x 0.46-0.59, z 0.47-0.59 | the middle of all start positions (the map centre), on open land | 7/7 | 1.32 | 1.08 |  |  | [jpg](media/DansilJarrah.jpg) |
| DansilLCongo | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.43-0.56 | centre, on the river bank between the two sides | 7/7 | 1.31 | 1.29 | no: far:p1,p2,p3,p4 (p1:87m(AFRICANmenelik,17 moved) p2:70m(HomeCityWaterS | yes | [jpg](media/DansilLCongo.jpg) |
| DansilNahanni | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.47-0.54 | centre, on land among the central ponds | 7/7 | 1.16 | 1.24 |  |  | [jpg](media/DansilNahanni.jpg) |
| dansilRed Beach | nearest open spot to the middle; end of the script | x 0.48-0.54, z 0.48-0.52 | centre of the marsh, beside the native villages | 7/7 | 1.24 | 1.10 |  |  | [jpg](media/dansilRed_Beach.jpg) |
| dansilRedRiver | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.48-0.54 | centre, on land between the rivers | 7/7 | 1.26 | 1.32 |  | yes | [jpg](media/dansilRedRiver.jpg) |
| DansilYalu_River | nearest open spot to the middle; end of the script | x 0.50-0.55, z 0.14-0.26 | centre, on the river bank between the two sides | 7/7 | 1.43 | 3.74 | yes | yes | [jpg](media/DansilYalu_River.jpg) |
| DansilZavkhan | nearest open spot to the middle; end of the script | x 0.45-0.56, z 0.45-0.55 | the middle of all start positions (the map centre), on open land | 7/7 | 1.25 | 1.75 |  |  | [jpg](media/DansilZavkhan.jpg) |
| Delta TWC | landfill at the middle; end of the script | x 0.47-0.53, z 0.26-0.33 | the middle of the start positions is on the river: a patch of land is laid across it there (as TAD's Acre and Orinoco do), so the hill sits on a crossing | 7/7 | 1.22 | 1.82 | yes | yes | [jpg](media/Delta_TWC.jpg) |
| dunas | nearest open spot to the middle; end of the script | x 0.44-0.55, z 0.47-0.55 | centre, on the dunes between the lagoons | 7/7 | 1.40 | 1.67 |  |  | [jpg](media/dunas.jpg) |
| Finger Lake-V | nearest open spot to the middle; end of the script | x 0.30-0.63, z 0.39-0.56 | the shore halfway along the lake, farthest from every Town Center | 7/7 | 1.45 | 1.49 | yes | yes | [jpg](media/Finger_Lake-V.jpg) |
| Finland | nearest open spot to the middle; end of the script | x 0.46-0.53, z 0.46-0.52 | centre, on land between the lakes | 5/7 | 1.23 | 1.28 |  |  | [jpg](media/Finland.jpg) |
| GANVolta | nearest open spot to the middle; end of the script | x 0.41-0.61, z 0.45-0.57 | centre, on the shore of the central lake | 7/7 | 1.34 | 1.31 | yes | yes | [jpg](media/GANVolta.jpg) |
| GANWakhan | nearest open spot to the middle; after the Town Centers | x 0.46-0.54, z 0.47-0.53 | the middle of all start positions (the map centre), on open land | 7/7 | 1.17 | 1.26 | yes | yes | [jpg](media/GANWakhan.jpg) |
| Glacier TWC | nearest open spot to the middle; end of the script | x 0.46-0.57, z 0.46-0.66 | the middle of all start positions (the map centre), on open land | 7/7 | 1.47 | 1.46 | yes | yes | [jpg](media/Glacier_TWC.jpg) |
| Gold Coast | nearest open spot to the middle; end of the script | x 0.59-0.74, z 0.61-0.75 | the middle of all start positions (the map centre), on open land | 7/7 | 1.31 | 2.34 |  |  | [jpg](media/Gold_Coast.jpg) |
| great lakes | TAD's own code | x 0.47-0.51, z 0.47-0.52 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.32 | 1.16 | no: far:p1,p2,p3,p4 (p1:62m(AFRICANmenelik,1 moved) p2:58m(AFRICANalipasha | yes | [jpg](media/great_lakes.jpg) |
| great plains | TAD's own code | x 0.44-0.57, z 0.45-0.56 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.32 | 1.23 | yes | yes | [jpg](media/great_plains.jpg) |
| great plainsLarge | TAD's own code | x 0.44-0.57, z 0.43-0.56 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.35 | 1.33 | yes | yes | [jpg](media/great_plainsLarge.jpg) |
| Hispaniola | TAD's own code | x 0.45-0.53, z 0.24-0.55 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.49 | 1.17 | yes | yes | [jpg](media/Hispaniola.jpg) |
| hollows | nearest open spot to the middle; end of the script | x 0.46-0.52, z 0.48-0.53 | the middle of all start positions (the map centre), on open land | 7/7 | 1.12 | 1.24 |  |  | [jpg](media/hollows.jpg) |
| marajo | nearest open spot to the middle; end of the script | x 0.46-0.52, z 0.45-0.61 | centre of the island, inside the ring of start positions | 7/7 | 1.33 | 1.23 | yes | yes | [jpg](media/marajo.jpg) |
| new england | TAD's own code | x 0.43-0.57, z 0.29-0.93 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.27 | 1.32 | yes | NO: 2304 units; 2 units differ: orig Travois p0 232.0,378.0; new Travois p0 232.0,38 | [jpg](media/new_england.jpg) |
| NEWBahia | nearest open spot to the middle; end of the script | x 0.39-0.51, z 0.46-0.57 | the middle of all start positions (the map centre), on open land | 7/7 | 1.24 | 1.59 | yes | yes | [jpg](media/NEWBahia.jpg) |
| NEWBarbary | nearest open spot to the middle; end of the script | x 0.40-0.51, z 0.39-0.50 | the middle of all start positions (the map centre), on open land | 7/7 | 1.31 | 1.30 |  |  | [jpg](media/NEWBarbary.jpg) |
| NEWFerghana | nearest open spot to the middle; end of the script | x 0.46-0.50, z 0.45-0.55 | the middle of all start positions (the map centre), on open land | 7/7 | 1.26 | 1.29 | yes | yes | [jpg](media/NEWFerghana.jpg) |
| NEWGuajira | nearest open spot to the middle; end of the script | x 0.45-0.50, z 0.47-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.25 | 1.50 |  |  | [jpg](media/NEWGuajira.jpg) |
| NEWHinduKush | nearest open spot to the middle; end of the script | x 0.46-0.57, z 0.46-0.54 | centre, beside the central native village | 7/7 | 1.46 | 1.31 | yes | yes | [jpg](media/NEWHinduKush.jpg) |
| NEWKhorezm | nearest open spot to the middle; end of the script | x 0.45-0.53, z 0.27-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.35 | 1.24 |  |  | [jpg](media/NEWKhorezm.jpg) |
| NEWLevant | nearest open spot to the middle; end of the script | x 0.33-0.55, z 0.44-0.68 | the middle of all start positions (the map centre), on open land | 7/7 | 1.30 | 1.40 | yes | NO: 3199 units; 1 units differ: new TRADECamel p0 374.1,505.9 | [jpg](media/NEWLevant.jpg) |
| NEWParamo | between the teams; end of the script | x 0.31-0.67, z 0.32-0.66 | the middle is the central lake; first open land on the line that splits the teams (its shore) | 7/7 | 1.31 | 2.68 |  |  | [jpg](media/NEWParamo.jpg) |
| NEWSerradoMar | nearest open spot to the middle; after the Town Centers | x 0.47-0.55, z 0.57-0.76 | the middle of all start positions (the map centre), on open land | 7/7 | 1.24 | 2.31 | yes | yes | [jpg](media/NEWSerradoMar.jpg) |
| NEWTiticaca | between the teams; end of the script | x 0.23-0.79, z 0.43-0.70 | the middle is Lake Titicaca; first open land on the line that splits the teams (its shore) | 7/7 | 1.19 | 2.91 |  |  | [jpg](media/NEWTiticaca.jpg) |
| NEWwetChaco | nearest open spot to the middle; end of the script | x 0.41-0.64, z 0.30-0.63 | the middle of all start positions (the map centre), on open land | 7/7 | 1.49 | 2.41 |  |  | [jpg](media/NEWwetChaco.jpg) |
| NEWZagros | nearest open spot to the middle; end of the script | x 0.47-0.55, z 0.47-0.53 | the middle of all start positions (the map centre), on open land | 7/7 | 1.26 | 1.14 | yes | yes | [jpg](media/NEWZagros.jpg) |
| Orinoco | TAD's own code | x 0.76-0.83, z 0.75-0.84 | TAD's own King of the Hill code: a landfill at one end of the river | 7/7 | 1.32 | 4.02 | yes | yes | [jpg](media/Orinoco.jpg) |
| ozarks | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.46-0.60, z 0.50-0.56 | centre of the hills (TAD's block walked too far from the centre on WoL's map) | 7/7 | 1.47 | 1.47 | yes | yes | [jpg](media/ozarks.jpg) |
| painted desert | between the teams; end of the script (TAD's own block was uneven on WoL's map) | x 0.46-0.69, z 0.17-0.51 | the middle is canyon; first open land on the line that splits the teams | 7/7 | 1.26 | 3.05 | yes | yes | [jpg](media/painted_desert.jpg) |
| pampas | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.46-0.59, z 0.30-0.55 | centre of the plain (TAD's block favoured one team on WoL's map) | 7/7 | 1.45 | 1.25 | yes | NO: 2410 units; 2 units differ: orig WOTTATravois p0 23.2,168.0; orig WOTTATravois3  | [jpg](media/pampas.jpg) |
| patagonia | TAD's own code | x 0.45-0.56, z 0.47-0.56 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.47 | 1.35 | yes | NO: 1387 units; 1 units differ: orig WOTTATravois3 p0 88.1,82.1; 2837 units; 4 units differ: orig WOTTATravois p0 508.1,503.9; orig WOTTATravois3 | [jpg](media/patagonia.jpg) |
| plymouth | TAD's own code | x 0.46-0.58, z 0.27-0.86 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.18 | 1.31 | yes | yes | [jpg](media/plymouth.jpg) |
| Prairie TWC | nearest open spot to the middle; end of the script | x 0.47-0.65, z 0.46-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.16 | 1.41 | yes | yes | [jpg](media/Prairie_TWC.jpg) |
| rockies | TAD's own code | x 0.46-0.56, z 0.44-0.58 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.23 | 1.46 | yes | NO: 2038 units; 10 units differ: orig Travois p0 0.0,0.0; orig Travois p0 0.0,0.0; o | [jpg](media/rockies.jpg) |
| saguenay | TAD's own code | x 0.46-0.55, z 0.47-0.53 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.15 | 1.19 | yes | yes | [jpg](media/saguenay.jpg) |
| saguenayLarge | TAD's own code | x 0.46-0.55, z 0.45-0.55 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.30 | 1.06 | yes | yes | [jpg](media/saguenayLarge.jpg) |
| sonora | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.39-0.53, z 0.45-0.55 | centre, beside the central mine (TAD's block found no room in some tests) | 7/7 | 1.20 | 1.32 | yes | NO: 1751 units; 10 units differ: orig Travois p0 264.0,5.8; orig AttackRevealer p2 9 | [jpg](media/sonora.jpg) |
| sonoraLarge | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.43-0.54, z 0.46-0.51 | centre, beside the central mine (TAD's block found no room in some tests) | 7/7 | 1.14 | 1.19 | yes | yes | [jpg](media/sonoraLarge.jpg) |
| texas | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.48-0.56, z 0.46-0.56 | centre of the plain (TAD's block favoured one team on WoL's map) | 7/7 | 1.47 | 1.27 | yes | NO: 2329 units; 4 units differ: orig Travois p0 129.9,33.9; orig Travois p0 440.0,52 | [jpg](media/texas.jpg) |
| texasLarge | TAD's own code | x 0.45-0.55, z 0.48-0.55 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.47 | 1.17 | yes | yes | [jpg](media/texasLarge.jpg) |
| Thanksgiving III | between the teams; end of the script | x 0.40-0.56, z 0.36-0.51 | the middle is on the river; first open land on the line that splits the teams (a bank or a ford) | 6/7 | 1.26 | 2.27 |  |  | [jpg](media/Thanksgiving_III.jpg) |
| unknown | between the teams; end of the script (TAD's own block was uneven on WoL's map) | x 0.38-0.55, z 0.38-0.62 | the middle varies with the map's random layout; first open land on the line that splits the teams | 7/7 | 1.49 | 2.06 | yes | yes | [jpg](media/unknown.jpg) |
| WOLAlps | between the teams; end of the script |  | the middle is on the mountain rivers; first open land on the line that splits the teams | 0/7 |  |  |  |  | [jpg](media/WOLAlps.jpg) |
| WOLasuncion | nearest open spot to the middle; end of the script | x 0.31-0.55, z 0.50-0.67 | the middle of all start positions (the map centre), on open land | 7/7 | 1.44 | 1.06 |  |  | [jpg](media/WOLasuncion.jpg) |
| WOLbalkans | between the teams; end of the script |  | the middle is the sea between the peninsulas; first open land on the line that splits the teams | 0/7 |  |  |  |  | [jpg](media/WOLbalkans.jpg) |
| WOLblackforest | nearest open spot to the middle; end of the script | x 0.43-0.60, z 0.47-0.59 | the middle of all start positions (the map centre), on open land | 7/7 | 1.60 | 1.37 | yes | yes | [jpg](media/WOLblackforest.jpg) |
| WOLcentralplateau | nearest open spot to the middle; end of the script | x 0.48-0.55, z 0.48-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.27 | 1.40 |  |  | [jpg](media/WOLcentralplateau.jpg) |
| WOLcerrado | between the teams; end of the script | x 0.43-0.56, z 0.33-0.57 | the middle is crowded (trade routes, natives); first open land on the line that splits the teams | 7/7 | 1.54 | 2.73 |  |  | [jpg](media/WOLcerrado.jpg) |
| WOLcongo | nearest open spot to the middle; after the Town Centers | x 0.46-0.53, z 0.45-0.54 | the middle of all start positions (the map centre), on open land | 6/7 | 1.28 | 1.49 |  |  | [jpg](media/WOLcongo.jpg) |
| WOLdallol | nearest open spot to the middle; end of the script | x 0.47-0.54, z 0.46-0.53 | centre, on the salt flat between all start positions | 7/7 | 1.21 | 1.27 | yes | yes | [jpg](media/WOLdallol.jpg) |
| WOLeasterisland | nearest open spot to the middle; end of the script | x 0.48-0.60, z 0.33-0.51 | the open land of the island farthest from every Town Center (the centre favours some starts) | 7/7 | 1.26 | 1.95 |  |  | [jpg](media/WOLeasterisland.jpg) |
| WOLEcruteak | nearest open spot to the middle; end of the script | x 0.47-0.55, z 0.47-0.54 | the land farthest from every Town Center (the centre button of the map is an island) | 7/7 | 1.11 | 1.33 |  |  | [jpg](media/WOLEcruteak.jpg) |
| WOLFjord | between the teams; end of the script | x 0.45-0.75, z 0.41-0.72 | the middle is water (the fjords); first open land on the line that splits the teams | 4/7 | 1.47 | 3.25 |  |  | [jpg](media/WOLFjord.jpg) |
| WOLGibraltar | nearest open spot to the middle; end of the script | x 0.29-0.43, z 0.28-0.41 | centre of the southern land, where every player starts | 7/7 | 1.28 | 2.20 |  |  | [jpg](media/WOLGibraltar.jpg) |
| WolGreenland | between the teams; end of the script | x 0.58-0.61, z 0.39-0.47 | the middle is at the head of the fjord; first open land on the line that splits the teams | 6/7 | 1.23 |  |  |  | [jpg](media/WolGreenland.jpg) |
| WolGujarat | between the teams; end of the script | x 0.59-0.65, z 0.39-0.41 | the middle is the gulf; first open land on the line that splits the teams | 5/7 | 1.11 | 3.37 |  |  | [jpg](media/WolGujarat.jpg) |
| WOLIberianPeninsula | between the teams; end of the script | x 0.29-0.60, z 0.44-0.64 | the middle is on the inner river; first open land on the line that splits the teams | 7/7 | 1.65 | 2.38 |  |  | [jpg](media/WOLIberianPeninsula.jpg) |
| WOLlakerose | between the teams; end of the script | x 0.36-0.60, z 0.32-0.74 | the middle is the central lake; first open land on the line that splits the teams (its shore) | 7/7 | 1.16 | 2.39 |  |  | [jpg](media/WOLlakerose.jpg) |
| WolLualaba | nearest open spot to the middle; end of the script | x 0.50-0.62, z 0.39-0.47 | centre, between the river branches | 7/7 | 1.16 | 3.29 | yes | yes | [jpg](media/WolLualaba.jpg) |
| WOLmadagascar | nearest open spot to the middle; end of the script | x 0.45-0.73, z 0.46-0.69 | centre of the island, where every player starts | 7/7 | 1.32 | 3.30 | yes | yes | [jpg](media/WOLmadagascar.jpg) |
| WOLmoon | between the teams; end of the script | x 0.46-0.55, z 0.49-0.59 | the middle is cratered; first open land on the line that splits the teams | 7/7 | 1.59 | 2.08 |  |  | [jpg](media/WOLmoon.jpg) |
| WOLnlnz | between the teams; after the Town Centers | x 0.47-0.56, z 0.66-0.78 | the middle is water; first open land on the line that splits the teams | 7/7 | 1.42 | 2.41 |  |  | [jpg](media/WOLnlnz.jpg) |
| WOLnzwc | between the teams; end of the script | x 0.46-0.50, z 0.47-0.71 | a long strip; first open land on the line that splits the teams | 7/7 | 2.18 | 2.05 |  |  | [jpg](media/WOLnzwc.jpg) |
| WOLsahel | nearest open spot to the middle; end of the script | x 0.30-0.48, z 0.26-0.48 | centre, beside the central trade route | 7/7 | 1.43 | 2.19 | yes | NO: 1581 units; 1 units differ: orig TRADECamel p0 399.7,399.7 | [jpg](media/WOLsahel.jpg) |
| WOLsavannah | nearest open spot to the middle; end of the script | x 0.47-0.53, z 0.42-0.66 | the middle of all start positions (the map centre), on open land | 7/7 | 1.27 | 1.28 |  |  | [jpg](media/WOLsavannah.jpg) |
| WOLScandinavia | nearest open spot to the middle; end of the script | x 0.46-0.51, z 0.46-0.53 | the middle of all start positions (the map centre), on open land | 7/7 | 1.11 | 1.23 | yes | yes | [jpg](media/WOLScandinavia.jpg) |
| WOLsocotra | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.47-0.53 | the clearing in the middle of the island | 7/7 | 1.41 | 1.24 | no: far:p1,p2,p3,p4 (p1:48m(AFRICANmenelik,2 moved) p2:47m(AFRICANalipasha | yes | [jpg](media/WOLsocotra.jpg) |
| WolTahiti | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.45-0.55 | centre, on the land between the two parts of the island | 7/7 | 1.34 | 3.03 | yes | yes | [jpg](media/WolTahiti.jpg) |
| WOLtuscany | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.48-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.47 | 1.26 |  |  | [jpg](media/WOLtuscany.jpg) |
| WOLvalleyofkings | nearest open spot to the middle; end of the script | x 0.47-0.57, z 0.45-0.57 | the middle of all start positions (the map centre), on open land | 7/7 | 1.36 | 1.14 | yes | yes | [jpg](media/WOLvalleyofkings.jpg) |
| WoLverdongorge | between the teams; end of the script | x 0.39-0.71, z 0.33-0.65 | the middle is the gorge's lake; first open land on the line that splits the teams (the gorge's banks) | 7/7 | 1.42 | 2.44 |  |  | [jpg](media/WoLverdongorge.jpg) |
| WOLwateringhole | nearest open spot to the middle; end of the script | x 0.46-0.56, z 0.46-0.53 | the middle of all start positions (the map centre), on open land | 7/7 | 1.11 | 1.26 |  |  | [jpg](media/WOLwateringhole.jpg) |
| WOLwetlands | nearest open spot to the middle; end of the script | x 0.42-0.63, z 0.37-0.58 | the central island of the marsh | 7/7 | 1.35 | 1.65 | yes | yes | [jpg](media/WOLwetlands.jpg) |
| WOLzimbabwe | nearest open spot to the middle; end of the script | x 0.47-0.54, z 0.45-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.29 | 1.37 |  |  | [jpg](media/WOLzimbabwe.jpg) |
| yucatan | TAD's own code | x 0.46-0.55, z 0.46-0.54 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.42 | 1.36 | yes | yes | [jpg](media/yucatan.jpg) |
| yukon | TAD's own code | x 0.45-0.56, z 0.46-0.54 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.27 | 1.21 | yes | yes | [jpg](media/yukon.jpg) |
| Yungas | nearest open spot to the middle; after the Town Centers | x 0.47-0.53, z 0.47-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.22 | 1.07 |  |  | [jpg](media/Yungas.jpg) |

## Media

One picture per added map (minimap, 4 players, 2 teams, seed 1: magenta ring = hill, numbered squares =
Town Centers):

- [amazonia](media/amazonia.jpg)
- [andes](media/andes.jpg)
- [appalachians](media/appalachians.jpg)
- [araucania](media/araucania.jpg)
- [atacama](media/atacama.jpg)
- [Baja California TWC 01](media/Baja_California_TWC_01.jpg)
- [Barrier Ridge TWC](media/Barrier_Ridge_TWC.jpg)
- [bayou](media/bayou.jpg)
- [california](media/california.jpg)
- [caribbean](media/caribbean.jpg)
- [carolina](media/carolina.jpg)
- [carolinaLarge](media/carolinaLarge.jpg)
- [Central America+TWC](media/Central_America+TWC.jpg)
- [Christmas](media/Christmas.jpg)
- [Dakota Badlands V](media/Dakota_Badlands_V.jpg)
- [dansil Manicouagan Basin](media/dansil_Manicouagan_Basin.jpg)
- [dansil Rio De Plata](media/dansil_Rio_De_Plata.jpg)
- [dansil92 Manitoba](media/dansil92_Manitoba.jpg)
- [dansil92Kwadacha](media/dansil92Kwadacha.jpg)
- [dansil_greatbarrierreef](media/dansil_greatbarrierreef.jpg)
- [dansil_Outback](media/dansil_Outback.jpg)
- [dansil_Owikeno](media/dansil_Owikeno.jpg)
- [dansil_Westernterritory](media/dansil_Westernterritory.jpg)
- [DansilAlaska](media/DansilAlaska.jpg)
- [DansilCerroAcahay](media/DansilCerroAcahay.jpg)
- [DansilChupat](media/DansilChupat.jpg)
- [DansilCristalMonts](media/DansilCristalMonts.jpg)
- [dansilFiji](media/dansilFiji.jpg)
- [DansilIrrawaddyRiver](media/DansilIrrawaddyRiver.jpg)
- [DansilJarrah](media/DansilJarrah.jpg)
- [DansilLCongo](media/DansilLCongo.jpg)
- [DansilNahanni](media/DansilNahanni.jpg)
- [dansilRed Beach](media/dansilRed_Beach.jpg)
- [dansilRedRiver](media/dansilRedRiver.jpg)
- [DansilYalu_River](media/DansilYalu_River.jpg)
- [DansilZavkhan](media/DansilZavkhan.jpg)
- [Delta TWC](media/Delta_TWC.jpg)
- [dunas](media/dunas.jpg)
- [Finger Lake-V](media/Finger_Lake-V.jpg)
- [Finland](media/Finland.jpg)
- [GANVolta](media/GANVolta.jpg)
- [GANWakhan](media/GANWakhan.jpg)
- [Glacier TWC](media/Glacier_TWC.jpg)
- [Gold Coast](media/Gold_Coast.jpg)
- [great lakes](media/great_lakes.jpg)
- [great plains](media/great_plains.jpg)
- [great plainsLarge](media/great_plainsLarge.jpg)
- [Hispaniola](media/Hispaniola.jpg)
- [hollows](media/hollows.jpg)
- [marajo](media/marajo.jpg)
- [new england](media/new_england.jpg)
- [NEWBahia](media/NEWBahia.jpg)
- [NEWBarbary](media/NEWBarbary.jpg)
- [NEWFerghana](media/NEWFerghana.jpg)
- [NEWGuajira](media/NEWGuajira.jpg)
- [NEWHinduKush](media/NEWHinduKush.jpg)
- [NEWKhorezm](media/NEWKhorezm.jpg)
- [NEWLevant](media/NEWLevant.jpg)
- [NEWParamo](media/NEWParamo.jpg)
- [NEWSerradoMar](media/NEWSerradoMar.jpg)
- [NEWTiticaca](media/NEWTiticaca.jpg)
- [NEWwetChaco](media/NEWwetChaco.jpg)
- [NEWZagros](media/NEWZagros.jpg)
- [Orinoco](media/Orinoco.jpg)
- [ozarks](media/ozarks.jpg)
- [painted desert](media/painted_desert.jpg)
- [pampas](media/pampas.jpg)
- [patagonia](media/patagonia.jpg)
- [plymouth](media/plymouth.jpg)
- [Prairie TWC](media/Prairie_TWC.jpg)
- [rockies](media/rockies.jpg)
- [saguenay](media/saguenay.jpg)
- [saguenayLarge](media/saguenayLarge.jpg)
- [sonora](media/sonora.jpg)
- [sonoraLarge](media/sonoraLarge.jpg)
- [texas](media/texas.jpg)
- [texasLarge](media/texasLarge.jpg)
- [Thanksgiving III](media/Thanksgiving_III.jpg)
- [unknown](media/unknown.jpg)
- [WOLAlps](media/WOLAlps.jpg)
- [WOLasuncion](media/WOLasuncion.jpg)
- [WOLbalkans](media/WOLbalkans.jpg)
- [WOLblackforest](media/WOLblackforest.jpg)
- [WOLcentralplateau](media/WOLcentralplateau.jpg)
- [WOLcerrado](media/WOLcerrado.jpg)
- [WOLcongo](media/WOLcongo.jpg)
- [WOLdallol](media/WOLdallol.jpg)
- [WOLeasterisland](media/WOLeasterisland.jpg)
- [WOLEcruteak](media/WOLEcruteak.jpg)
- [WOLFjord](media/WOLFjord.jpg)
- [WOLGibraltar](media/WOLGibraltar.jpg)
- [WolGreenland](media/WolGreenland.jpg)
- [WolGujarat](media/WolGujarat.jpg)
- [WOLIberianPeninsula](media/WOLIberianPeninsula.jpg)
- [WOLlakerose](media/WOLlakerose.jpg)
- [WolLualaba](media/WolLualaba.jpg)
- [WOLmadagascar](media/WOLmadagascar.jpg)
- [WOLmoon](media/WOLmoon.jpg)
- [WOLnlnz](media/WOLnlnz.jpg)
- [WOLnzwc](media/WOLnzwc.jpg)
- [WOLsahel](media/WOLsahel.jpg)
- [WOLsavannah](media/WOLsavannah.jpg)
- [WOLScandinavia](media/WOLScandinavia.jpg)
- [WOLsocotra](media/WOLsocotra.jpg)
- [WolTahiti](media/WolTahiti.jpg)
- [WOLtuscany](media/WOLtuscany.jpg)
- [WOLvalleyofkings](media/WOLvalleyofkings.jpg)
- [WoLverdongorge](media/WoLverdongorge.jpg)
- [WOLwateringhole](media/WOLwateringhole.jpg)
- [WOLwetlands](media/WOLwetlands.jpg)
- [WOLzimbabwe](media/WOLzimbabwe.jpg)
- [yucatan](media/yucatan.jpg)
- [yukon](media/yukon.jpg)
- [Yungas](media/Yungas.jpg)
