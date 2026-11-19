# King of the Hill on every random map that has room for it

Request (JTMaston): *"there is a code that makes a map able to work in koth mode. Not all maps have that
code at the moment. We'd like to add it to all maps where possible. The position of the kings hill doesn't
necessarily need to be the center of the map but the closest choke point to all players and wherever there
is space to place it and battle around. If a map doesn't have space to allocate a king's hill, it should be
skipped and its description should state that it doesn't work in koth mode."*

Of WoL's 208 random maps, 87 already had King of the Hill. Of the other 121, **113 now have it** and
**8 are skipped** because their players start on land masses that do not touch (list below).

WOLsahara was added on 2026-11-18, after the first pack: its script included `ypKOTHInclude.xs` and kept
objects 8 m away from a `ypKingsHill`, so a search for the hill's name counted it as a map that had King of
the Hill, but it never placed one. A second scan of all 208 maps now checks that `main` (or a function it
calls) holds both `rmGetIsKOTH()` and the hill's placement; apart from the 8 skipped maps, all of them do.

## Status (2026-11-18): tests complete

- Hill placed in every one of its 7 test games: 110 of 113 maps.
- Hill missing in some test games (3): WOLAlps, WOLcongo, WOLnlnz.
- Team ratio above 1.5 in some test game (5): dansil_greatbarrierreef, WOLAlps, WolGujarat, WOLIberianPeninsula, WOLnzwc.
- Reach test done: 113 maps; failed or by ship only (9): amazonia, caribbean, dansil92Kwadacha, DansilLCongo, great lakes, WOLEcruteak, WOLsocotra, WoLverdongorge, Yungas; pending (0).
- Normal-map test done: 113 maps; differs (3): DansilCristalMonts, rockies, unknown; pending (0).

Known limits (details in the table):
- **By ship, by design:** amazonia (TAD's mid-river islet), caribbean and great lakes in summer (TAD's
  island), DansilLCongo and WOLEcruteak (the hill is on the land between the rivers / the centre island).
  Every team needs boats to reach it, so it is even, but the reach test (walking) fails there.
- **Uneven in some layouts:** 8-player WOLnzwc and dansil_greatbarrierreef (players start along a strip,
  so one team is always nearer), 2-player WolGujarat and WOLIberianPeninsula in one seed each. Free-for-all
  is uneven on many maps: with four rivals in a line or in two groups, no spot is equally far from all.
- **Reach test:** in dansil92Kwadacha and WoLverdongorge one player's units did not get there within the 120 s
  (the other three did); in WOLsocotra and Yungas every player got within 18 to 23 m but not within our 15 m
  mark (the hill sits beside rough ground).
- **Hill missing in one of seven test games:** WOLAlps (8 players, both seeds), WOLcongo (4-player
  free-for-all), WOLnlnz (one 4-player seed). Their other games are fine.
- **Normal map:** identical on every map except DansilCristalMonts (the fix below, on purpose), rockies
  and unknown (one or two decorative underbrush bushes placed differently in one seed: the game's own
  randomness, the code that runs in a normal game is the same).
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
   **Cliffs:** on three maps the middle has a plateau or mesa with no ramp (Barrier Ridge TWC, DansilAlaska,
   WOLsocotra), so the block keeps the hill 20 m from it. Two maps start from a hand-picked point:
   DansilChupat (south of the river bend; inside the bend cannot be reached on foot) and dansil Rio De Plata
   (the river delta inland of the estuary). If the line between the teams has no room, the block falls back
   to the open land nearest to the middle.
   **Where the block sits:** at the very end of `main`, after cliffs, lakes, forests and resources (placed
   earlier, a hill could be removed by a cliff or lake built over it: seen on Central America, Finland and
   others). On a few large maps a hill placed at the end did not appear with 8 players (the cause was not found), so there the block sits right after the Town Centers instead; the table says "after the Town Centers".
3. **The map's own code, repaired** (DansilCristalMonts).

Choke point: on these maps the players start around the edge, so the middle of the start positions is the
ground everybody has to cross to reach the others. Where the middle is water (a lake, a fjord, a river
junction), the hill goes to the nearest bank, or onto a patch of land laid there.

What does not work in this engine (tested, so nobody has to try again): a type-distance constraint longer
than some 40 to 100 m (for example "100 m from every Town Center", or "3000 m from any other hill") never
lets anything be placed.
## Bugs fixed

- **DansilCristalMonts: this fix changes the normal map.** Its King of the Hill block was never closed:
  the closing brace sat after the "decorative centre section", so the centre cliffs were built **only in
  King of the Hill games**, and after the hill, on top of it. The block is now closed and moved after the
  cliffs, so **normal games now get the centre cliffs too**, as the comment "decorative centre section"
  intends. If you prefer the normal map as it was, delete the block under `//=====decorative centre section==========` in our copy.
- **WOLAlps, WolGreenland:** `include "ypKOTHInclude.xs";` was commented out. The include is back and the maps
  have a hill. (WOLFjord had it commented out too, plus an "avoid KOTH" constraint but no hill: it is
  skipped, see below.)
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
| WOLbalkans | the peninsulas and islands split the players: no spot is reachable on foot by both teams at a fair distance (tested: some players cannot walk to it, team distances up to 6 to 1) |
| WOLbritishislands | players start on two islands (Ireland and Britain) with no land between them |
| WOLFjord | the fjords split the land: no spot is fair to both teams and reachable on foot by all of them (tested); its King of the Hill include was commented out, and stays so |

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
- A real game started from the setup screen could not be run unattended: the shared test profile now opens
  a "Skirmish Nickname" dialog first. The editor test sets the game's own King of the Hill setting, which is
  what `rmGetIsKOTH()` reads in a setup-screen game too.

The test tool is `tools/kothcheck.py` in our repository; the test copies of the maps (with the reach
trigger) are never shipped.

## Per-map table

"Hill position" is where the hill landed over the test runs, as fractions of the map (0.5, 0.5 = centre).

| Map | How | Hill position (fraction of the map, all runs) | Why there | Hill placed | Team ratio (max) | FFA ratio | Units reach it (4 players) | Normal map unchanged | Picture |
|---|---|---|---|---|---|---|---|---|---|
| amazonia | TAD's own code | x 0.24-0.78, z 0.25-0.74 | TAD's own King of the Hill code: a landfill islet in the middle of the river (reached by ship); the fill was made bigger and the hill kept on it, since WoL's islands lie farther apart | 7/7 | 1.46 | 3.95 | no: far:p1,p2 (p1:66m(HomeCityWaterSpawnFlag,7 moved) p2:68m(HomeCityWater | yes | [jpg](media/amazonia.jpg) |
| andes | TAD's own code | x 0.09-0.95, z 0.41-0.59 | TAD's own King of the Hill code: east or west edge, away from the mountains | 7/7 | 1.19 | 1.51 | yes | yes | [jpg](media/andes.jpg) |
| appalachians | nearest open spot to the middle; end of the script | x 0.48-0.52, z 0.47-0.53 | the middle of all start positions (the map centre), on open land | 7/7 | 1.17 | 1.08 | yes | yes | [jpg](media/appalachians.jpg) |
| araucania | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.40-0.62, z 0.45-0.51 | centre, between the two sides (TAD's spot at x 0.5 / 0.8 favoured one team on WoL's map) | 7/7 | 1.26 | 2.23 | yes | yes | [jpg](media/araucania.jpg) |
| atacama | between the teams; end of the script | x 0.33-0.56, z 0.12-0.79 | the middle is the salt lake; first open land on the line that splits the teams (its shore) | 7/7 | 1.11 | 2.25 | yes | yes | [jpg](media/atacama.jpg) |
| Baja California TWC 01 | nearest open spot to the middle; end of the script | x 0.47-0.54, z 0.46-0.54 | centre of the land strip, between the two sides | 7/7 | 1.41 | 1.77 | yes | yes | [jpg](media/Baja_California_TWC_01.jpg) |
| Barrier Ridge TWC | between the teams; end of the script | x 0.35-0.51, z 0.42-0.64 | the middle of all start positions (the map centre), on open land | 7/7 | 1.49 | 2.29 | yes | yes | [jpg](media/Barrier_Ridge_TWC.jpg) |
| bayou | between the teams; end of the script (TAD's own block was uneven on WoL's map) | x 0.28-0.65, z 0.35-0.57 | the middle is swamp water; first open land on the line that splits the teams | 7/7 | 1.14 | 2.15 | yes | yes | [jpg](media/bayou.jpg) |
| california | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.50-0.72, z 0.46-0.54 | centre, between the two sides (TAD's spot at x 0.35 / 0.65 favoured one team on WoL's map) | 7/7 | 1.41 | 1.83 | yes | yes | [jpg](media/california.jpg) |
| caribbean | TAD's own code | x 0.13-0.21, z 0.12-0.81 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.41 | 2.16 | no: far:p1,p2,p3,p4 (p1:200m(AFRICANmenelik,7 moved) p2:205m(AFRICANalipas | yes | [jpg](media/caribbean.jpg) |
| carolina | TAD's own code | x 0.47-0.56, z 0.44-0.57 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.36 | 1.16 | yes | yes | [jpg](media/carolina.jpg) |
| carolinaLarge | TAD's own code | x 0.43-0.57, z 0.43-0.57 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.37 | 1.20 | yes | yes | [jpg](media/carolinaLarge.jpg) |
| Central America+TWC | nearest open spot to the middle; end of the script | x 0.46-0.52, z 0.45-0.52 | the middle of all start positions (the map centre), on open land | 7/7 | 1.38 | 1.43 | yes | yes | [jpg](media/Central_America+TWC.jpg) |
| Christmas | own code (TAD's Great Lakes pattern) | x 0.48-0.53, z 0.48-0.54 | centre of the lake, as TAD's Great Lakes does: in winter on a patch of land laid on the ice (the ice counts as water), in summer on the island in the middle (reached by ship) | 7/7 | 1.13 | 1.14 | yes | yes | [jpg](media/Christmas.jpg) |
| Dakota Badlands V | nearest open spot to the middle; end of the script | x 0.47-0.79, z 0.47-0.55 | centre of the badlands, inside the ring of start positions | 7/7 | 1.13 | 1.12 | yes | yes | [jpg](media/Dakota_Badlands_V.jpg) |
| dansil Manicouagan Basin | nearest open spot to the middle; end of the script | x 0.50-0.59, z 0.47-0.55 | the land farthest from every Town Center around the crater lake | 7/7 | 1.17 | 1.29 | yes | yes | [jpg](media/dansil_Manicouagan_Basin.jpg) |
| dansil Rio De Plata | nearest open spot to the middle; end of the script | x 0.37-0.62, z 0.73-0.85 | the river delta inland of the estuary, on the line halfway between the two banks where the teams start (the middle is the estuary) | 7/7 | 1.38 | 3.94 | yes | yes | [jpg](media/dansil_Rio_De_Plata.jpg) |
| dansil92 Manitoba | between the teams; end of the script | x 0.37-0.73, z 0.51-0.78 | the middle is on the lake shore; first open land on the line that splits the teams | 7/7 | 1.14 | 1.87 | yes | yes | [jpg](media/dansil92_Manitoba.jpg) |
| dansil92Kwadacha | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.47-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.24 | 1.36 | no: far:p2 (p1:6m(AFRICANmenelik,6 moved) p3:6m(AFRICANvillager,8 moved) p | yes | [jpg](media/dansil92Kwadacha.jpg) |
| dansil_greatbarrierreef | between the teams; end of the script | x 0.42-0.77, z 0.34-0.51 | the middle is the reef; first open land on the line that splits the teams (the mainland) | 7/7 | 2.20 | 2.96 | yes | yes | [jpg](media/dansil_greatbarrierreef.jpg) |
| dansil_Outback | between the teams; end of the script | x 0.38-0.51, z 0.29-0.71 | the middle of all start positions (the map centre), on open land | 7/7 | 1.15 | 2.23 | yes | yes | [jpg](media/dansil_Outback.jpg) |
| dansil_Owikeno | between the teams; end of the script | x 0.25-0.68, z 0.34-0.70 | the land farthest from every Town Center around Owikeno lake | 7/7 | 1.23 | 3.31 | yes | yes | [jpg](media/dansil_Owikeno.jpg) |
| dansil_Westernterritory | between the teams; end of the script | x 0.43-0.76, z 0.47-0.58 | the middle of all start positions (the map centre), on open land | 7/7 | 1.17 | 3.44 | yes | yes | [jpg](media/dansil_Westernterritory.jpg) |
| DansilAlaska | between the teams; end of the script | x 0.38-0.78, z 0.45-0.52 | middle of the land strip, between the two sides | 7/7 | 1.09 | 3.70 | yes | yes | [jpg](media/DansilAlaska.jpg) |
| DansilCerroAcahay | nearest open spot to the middle; end of the script | x 0.47-0.54, z 0.49-0.52 | the middle of all start positions (the map centre), on open land | 7/7 | 1.27 | 1.21 | yes | yes | [jpg](media/DansilCerroAcahay.jpg) |
| DansilChupat | nearest open spot to the middle; end of the script | x 0.34-0.40, z 0.34-0.42 | the open land just south of the river bend, on the line halfway between the two sides (the middle, inside the bend, cannot be reached on foot) | 7/7 | 1.19 | 2.05 | yes | yes | [jpg](media/DansilChupat.jpg) |
| DansilCristalMonts | map's own code, repaired | x 0.47-0.52, z 0.47-0.53 | centre, in the sunken middle of the map (the map's own King of the Hill code, repaired) | 7/7 | 1.23 | 1.18 | yes | NO: 3650 units; 1085 units differ: orig AURbuildings p0 21.0,225.0; orig AURbuilding; 6712 units; 2027 units differ: orig AURbuildings p0 43.0,415.0; orig AURbuilding | [jpg](media/DansilCristalMonts.jpg) |
| dansilFiji | nearest open spot to the middle; end of the script | x 0.47-0.54, z 0.47-0.53 | centre of the island, inside the ring of start positions | 7/7 | 1.43 | 1.19 | yes | yes | [jpg](media/dansilFiji.jpg) |
| DansilIrrawaddyRiver | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.47-0.51 | centre, on the bank of the river crossing | 7/7 | 1.28 | 1.15 | yes | yes | [jpg](media/DansilIrrawaddyRiver.jpg) |
| DansilJarrah | nearest open spot to the middle; end of the script | x 0.46-0.59, z 0.47-0.59 | the middle of all start positions (the map centre), on open land | 7/7 | 1.32 | 1.08 | yes | yes | [jpg](media/DansilJarrah.jpg) |
| DansilLCongo | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.43-0.56 | centre, on the river bank between the two sides | 7/7 | 1.31 | 1.29 | no: far:p1,p2,p3,p4 (p1:87m(AFRICANmenelik,17 moved) p2:70m(HomeCityWaterS | yes | [jpg](media/DansilLCongo.jpg) |
| DansilNahanni | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.47-0.54 | centre, on land among the central ponds | 7/7 | 1.16 | 1.24 | yes | yes | [jpg](media/DansilNahanni.jpg) |
| dansilRed Beach | nearest open spot to the middle; end of the script | x 0.48-0.54, z 0.48-0.52 | centre of the marsh, beside the native villages | 7/7 | 1.24 | 1.10 | yes | yes | [jpg](media/dansilRed_Beach.jpg) |
| dansilRedRiver | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.48-0.54 | centre, on land between the rivers | 7/7 | 1.26 | 1.32 | yes | yes | [jpg](media/dansilRedRiver.jpg) |
| DansilYalu_River | nearest open spot to the middle; end of the script | x 0.50-0.55, z 0.14-0.26 | centre, on the river bank between the two sides | 7/7 | 1.43 | 3.74 | yes | yes | [jpg](media/DansilYalu_River.jpg) |
| DansilZavkhan | nearest open spot to the middle; end of the script | x 0.45-0.56, z 0.45-0.55 | the middle of all start positions (the map centre), on open land | 7/7 | 1.25 | 1.75 | yes | yes | [jpg](media/DansilZavkhan.jpg) |
| Delta TWC | landfill at the middle; end of the script | x 0.47-0.53, z 0.26-0.33 | the middle of the start positions is on the river: a patch of land is laid across it there (as TAD's Acre and Orinoco do), so the hill sits on a crossing | 7/7 | 1.22 | 1.82 | yes | yes | [jpg](media/Delta_TWC.jpg) |
| dunas | nearest open spot to the middle; end of the script | x 0.44-0.55, z 0.47-0.55 | centre, on the dunes between the lagoons | 7/7 | 1.40 | 1.67 | yes | yes | [jpg](media/dunas.jpg) |
| Finger Lake-V | nearest open spot to the middle; end of the script | x 0.30-0.63, z 0.39-0.56 | the shore halfway along the lake, farthest from every Town Center | 7/7 | 1.45 | 1.49 | yes | yes | [jpg](media/Finger_Lake-V.jpg) |
| Finland | between the teams; after the Town Centers | x 0.39-0.51, z 0.46-0.51 | centre, on land between the lakes | 7/7 | 1.14 | 2.11 | yes | yes | [jpg](media/Finland.jpg) |
| GANVolta | nearest open spot to the middle; end of the script | x 0.41-0.61, z 0.45-0.57 | centre, on the shore of the central lake | 7/7 | 1.34 | 1.31 | yes | yes | [jpg](media/GANVolta.jpg) |
| GANWakhan | nearest open spot to the middle; after the Town Centers | x 0.46-0.54, z 0.47-0.53 | the middle of all start positions (the map centre), on open land | 7/7 | 1.17 | 1.26 | yes | yes | [jpg](media/GANWakhan.jpg) |
| Glacier TWC | nearest open spot to the middle; end of the script | x 0.46-0.57, z 0.46-0.66 | the middle of all start positions (the map centre), on open land | 7/7 | 1.47 | 1.46 | yes | yes | [jpg](media/Glacier_TWC.jpg) |
| Gold Coast | nearest open spot to the middle; end of the script | x 0.59-0.74, z 0.61-0.75 | the middle of all start positions (the map centre), on open land | 7/7 | 1.31 | 2.34 | yes | yes | [jpg](media/Gold_Coast.jpg) |
| great lakes | TAD's own code | x 0.47-0.51, z 0.47-0.52 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.32 | 1.16 | no: far:p1,p2,p3,p4 (p1:62m(AFRICANmenelik,1 moved) p2:58m(AFRICANalipasha | yes | [jpg](media/great_lakes.jpg) |
| great plains | TAD's own code | x 0.44-0.57, z 0.45-0.56 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.32 | 1.23 | yes | yes | [jpg](media/great_plains.jpg) |
| great plainsLarge | TAD's own code | x 0.44-0.57, z 0.43-0.56 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.35 | 1.33 | yes | yes | [jpg](media/great_plainsLarge.jpg) |
| Hispaniola | TAD's own code | x 0.45-0.53, z 0.24-0.55 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.49 | 1.17 | yes | yes | [jpg](media/Hispaniola.jpg) |
| hollows | nearest open spot to the middle; end of the script | x 0.46-0.52, z 0.48-0.53 | the middle of all start positions (the map centre), on open land | 7/7 | 1.12 | 1.24 | yes | yes | [jpg](media/hollows.jpg) |
| marajo | nearest open spot to the middle; end of the script | x 0.46-0.52, z 0.45-0.61 | centre of the island, inside the ring of start positions | 7/7 | 1.33 | 1.23 | yes | yes | [jpg](media/marajo.jpg) |
| new england | TAD's own code | x 0.43-0.57, z 0.29-0.93 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.27 | 1.32 | yes | yes | [jpg](media/new_england.jpg) |
| NEWBahia | nearest open spot to the middle; end of the script | x 0.39-0.51, z 0.46-0.57 | the middle of all start positions (the map centre), on open land | 7/7 | 1.24 | 1.59 | yes | yes | [jpg](media/NEWBahia.jpg) |
| NEWBarbary | nearest open spot to the middle; end of the script | x 0.40-0.51, z 0.39-0.50 | the middle of all start positions (the map centre), on open land | 7/7 | 1.31 | 1.30 | yes | yes | [jpg](media/NEWBarbary.jpg) |
| NEWFerghana | nearest open spot to the middle; end of the script | x 0.46-0.50, z 0.45-0.55 | the middle of all start positions (the map centre), on open land | 7/7 | 1.26 | 1.29 | yes | yes | [jpg](media/NEWFerghana.jpg) |
| NEWGuajira | nearest open spot to the middle; end of the script | x 0.45-0.50, z 0.47-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.25 | 1.50 | yes | yes | [jpg](media/NEWGuajira.jpg) |
| NEWHinduKush | nearest open spot to the middle; end of the script | x 0.46-0.57, z 0.46-0.54 | centre, beside the central native village | 7/7 | 1.46 | 1.31 | yes | yes | [jpg](media/NEWHinduKush.jpg) |
| NEWKhorezm | nearest open spot to the middle; end of the script | x 0.45-0.53, z 0.27-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.35 | 1.24 | yes | yes | [jpg](media/NEWKhorezm.jpg) |
| NEWLevant | nearest open spot to the middle; end of the script | x 0.33-0.55, z 0.44-0.68 | the middle of all start positions (the map centre), on open land | 7/7 | 1.30 | 1.40 | yes | yes (only carts or trade units that move differ) | [jpg](media/NEWLevant.jpg) |
| NEWParamo | between the teams; end of the script | x 0.30-0.75, z 0.14-0.71 | the middle is the central lake; first open land on the line that splits the teams (its shore) | 7/7 | 1.14 | 3.39 | yes | yes | [jpg](media/NEWParamo.jpg) |
| NEWSerradoMar | nearest open spot to the middle; after the Town Centers | x 0.47-0.55, z 0.57-0.76 | the middle of all start positions (the map centre), on open land | 7/7 | 1.24 | 2.31 | yes | yes | [jpg](media/NEWSerradoMar.jpg) |
| NEWTiticaca | between the teams; end of the script | x 0.20-0.76, z 0.48-0.75 | the middle is Lake Titicaca; first open land on the line that splits the teams (its shore) | 7/7 | 1.08 | 3.89 | yes | yes | [jpg](media/NEWTiticaca.jpg) |
| NEWwetChaco | nearest open spot to the middle; end of the script | x 0.41-0.64, z 0.30-0.63 | the middle of all start positions (the map centre), on open land | 7/7 | 1.49 | 2.41 | yes | yes | [jpg](media/NEWwetChaco.jpg) |
| NEWZagros | nearest open spot to the middle; end of the script | x 0.47-0.55, z 0.47-0.53 | the middle of all start positions (the map centre), on open land | 7/7 | 1.26 | 1.14 | yes | yes | [jpg](media/NEWZagros.jpg) |
| Orinoco | TAD's own code | x 0.76-0.83, z 0.75-0.84 | TAD's own King of the Hill code: a landfill at one end of the river | 7/7 | 1.32 | 4.02 | yes | yes | [jpg](media/Orinoco.jpg) |
| ozarks | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.46-0.60, z 0.50-0.56 | centre of the hills (TAD's block walked too far from the centre on WoL's map) | 7/7 | 1.47 | 1.47 | yes | yes | [jpg](media/ozarks.jpg) |
| painted desert | between the teams; end of the script (TAD's own block was uneven on WoL's map) | x 0.49-0.68, z 0.21-0.69 | the middle is canyon; first open land on the line that splits the teams | 7/7 | 1.23 | 2.53 | yes | yes | [jpg](media/painted_desert.jpg) |
| pampas | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.46-0.59, z 0.30-0.55 | centre of the plain (TAD's block favoured one team on WoL's map) | 7/7 | 1.45 | 1.25 | yes | yes | [jpg](media/pampas.jpg) |
| patagonia | TAD's own code | x 0.45-0.56, z 0.47-0.56 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.47 | 1.35 | yes | yes | [jpg](media/patagonia.jpg) |
| plymouth | TAD's own code | x 0.46-0.58, z 0.27-0.86 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.18 | 1.31 | yes | yes | [jpg](media/plymouth.jpg) |
| Prairie TWC | nearest open spot to the middle; end of the script | x 0.47-0.65, z 0.46-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.16 | 1.41 | yes | yes | [jpg](media/Prairie_TWC.jpg) |
| rockies | TAD's own code | x 0.46-0.56, z 0.44-0.58 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.23 | 1.46 | yes | NO: 2040 units; 2 units differ: new UnderbrushRockies p0 241.0,351.0; new Underbrush | [jpg](media/rockies.jpg) |
| saguenay | TAD's own code | x 0.46-0.55, z 0.47-0.53 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.15 | 1.19 | yes | yes | [jpg](media/saguenay.jpg) |
| saguenayLarge | TAD's own code | x 0.46-0.55, z 0.45-0.55 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.30 | 1.06 | yes | yes | [jpg](media/saguenayLarge.jpg) |
| sonora | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.39-0.53, z 0.45-0.55 | centre, beside the central mine (TAD's block found no room in some tests) | 7/7 | 1.20 | 1.32 | yes | yes | [jpg](media/sonora.jpg) |
| sonoraLarge | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.43-0.54, z 0.46-0.51 | centre, beside the central mine (TAD's block found no room in some tests) | 7/7 | 1.14 | 1.19 | yes | yes | [jpg](media/sonoraLarge.jpg) |
| texas | nearest open spot to the middle; end of the script (TAD's own block was uneven on WoL's map) | x 0.48-0.56, z 0.46-0.56 | centre of the plain (TAD's block favoured one team on WoL's map) | 7/7 | 1.47 | 1.27 | yes | yes | [jpg](media/texas.jpg) |
| texasLarge | TAD's own code | x 0.45-0.55, z 0.48-0.55 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.47 | 1.17 | yes | yes | [jpg](media/texasLarge.jpg) |
| Thanksgiving III | between the teams; end of the script | x 0.45-0.71, z 0.37-0.68 | the middle is on the river; first open land on the line that splits the teams (a bank or a ford) | 7/7 | 1.46 | 1.82 | yes | yes | [jpg](media/Thanksgiving_III.jpg) |
| unknown | between the teams; end of the script (TAD's own block was uneven on WoL's map) | x 0.40-0.56, z 0.38-0.59 | the middle varies with the map's random layout; first open land on the line that splits the teams | 7/7 | 1.41 | 1.98 | yes | NO: 4106 units; 1 units differ: orig UnderbrushPampas p0 110.6,468.2 | [jpg](media/unknown.jpg) |
| WOLAlps | between the teams; after the Town Centers | x 0.13-0.20, z 0.13-0.20 | the middle is on the mountain rivers; first open land on the line that splits the teams | 5/7 | 1.52 |  | yes | yes | [jpg](media/WOLAlps.jpg) |
| WOLasuncion | nearest open spot to the middle; end of the script | x 0.31-0.55, z 0.50-0.67 | the middle of all start positions (the map centre), on open land | 7/7 | 1.44 | 1.06 | yes | yes | [jpg](media/WOLasuncion.jpg) |
| WOLblackforest | between the teams; end of the script | x 0.41-0.58, z 0.47-0.66 | the middle of all start positions (the map centre), on open land | 7/7 | 1.16 | 1.67 | yes | yes | [jpg](media/WOLblackforest.jpg) |
| WOLcentralplateau | nearest open spot to the middle; end of the script | x 0.48-0.55, z 0.48-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.27 | 1.40 | yes | yes | [jpg](media/WOLcentralplateau.jpg) |
| WOLcerrado | between the teams; end of the script | x 0.29-0.52, z 0.36-0.56 | the middle is crowded (trade routes, natives); first open land on the line that splits the teams | 7/7 | 1.28 | 2.16 | yes | yes | [jpg](media/WOLcerrado.jpg) |
| WOLcongo | between the teams; after the Town Centers | x 0.48-0.55, z 0.50-0.57 | the middle of all start positions (the map centre), on open land | 6/7 | 1.24 |  | yes | yes | [jpg](media/WOLcongo.jpg) |
| WOLdallol | nearest open spot to the middle; end of the script | x 0.47-0.54, z 0.46-0.53 | centre, on the salt flat between all start positions | 7/7 | 1.21 | 1.27 | yes | yes | [jpg](media/WOLdallol.jpg) |
| WOLeasterisland | nearest open spot to the middle; end of the script | x 0.48-0.60, z 0.33-0.51 | the open land of the island farthest from every Town Center (the centre favours some starts) | 7/7 | 1.26 | 1.95 | yes | yes | [jpg](media/WOLeasterisland.jpg) |
| WOLEcruteak | nearest open spot to the middle; end of the script | x 0.47-0.55, z 0.47-0.54 | the land farthest from every Town Center (the centre button of the map is an island) | 7/7 | 1.11 | 1.33 | no: far:p1,p2,p3,p4 (p1:129m(AFRICANmenelik,7 moved) p2:132m(AFRICANalipas | yes | [jpg](media/WOLEcruteak.jpg) |
| WOLGibraltar | nearest open spot to the middle; end of the script | x 0.29-0.43, z 0.28-0.41 | centre of the southern land, where every player starts | 7/7 | 1.28 | 2.20 | yes | yes | [jpg](media/WOLGibraltar.jpg) |
| WolGreenland | between the teams; end of the script | x 0.20-0.62, z 0.15-0.42 | the middle is at the head of the fjord; first open land on the line that splits the teams | 7/7 | 1.06 | 1.77 | yes | yes | [jpg](media/WolGreenland.jpg) |
| WolGujarat | between the teams; end of the script | x 0.42-0.65, z 0.37-0.95 | the middle is the gulf; first open land on the line that splits the teams | 7/7 | 2.37 | 4.00 | yes | yes | [jpg](media/WolGujarat.jpg) |
| WOLIberianPeninsula | between the teams; end of the script | x 0.35-0.57, z 0.46-0.62 | the middle is on the inner river; first open land on the line that splits the teams | 7/7 | 1.60 | 1.87 | yes | yes | [jpg](media/WOLIberianPeninsula.jpg) |
| WOLlakerose | between the teams; end of the script | x 0.40-0.59, z 0.29-0.73 | the middle is the central lake; first open land on the line that splits the teams (its shore) | 7/7 | 1.11 | 2.44 | yes | yes | [jpg](media/WOLlakerose.jpg) |
| WolLualaba | nearest open spot to the middle; end of the script | x 0.50-0.62, z 0.39-0.47 | centre, between the river branches | 7/7 | 1.16 | 3.29 | yes | yes | [jpg](media/WolLualaba.jpg) |
| WOLmadagascar | nearest open spot to the middle; end of the script | x 0.45-0.73, z 0.46-0.69 | centre of the island, where every player starts | 7/7 | 1.32 | 3.30 | yes | yes | [jpg](media/WOLmadagascar.jpg) |
| WOLmoon | between the teams; end of the script | x 0.48-0.56, z 0.48-0.57 | the middle is cratered; first open land on the line that splits the teams | 7/7 | 1.42 | 1.93 | yes | yes | [jpg](media/WOLmoon.jpg) |
| WOLnlnz | between the teams; after the Town Centers | x 0.49-0.56, z 0.63-0.77 | the middle is water; first open land on the line that splits the teams | 6/7 | 1.14 | 2.64 | yes | yes | [jpg](media/WOLnlnz.jpg) |
| WOLnzwc | between the teams; end of the script | x 0.46-0.52, z 0.48-0.71 | a long strip; first open land on the line that splits the teams | 7/7 | 2.18 | 2.10 | yes | yes | [jpg](media/WOLnzwc.jpg) |
| WOLsahara | nearest open spot to the middle; end of the script | x 0.44-0.54, z 0.47-0.55 | the middle of the start positions (the map centre), on open sand away from the cliffs; the map only included the King of the Hill library and kept objects away from a hill it never placed | 7/7 | 1.24 | 1.19 | yes | yes | [jpg](media/WOLsahara.jpg) |
| WOLsahel | nearest open spot to the middle; end of the script | x 0.30-0.48, z 0.26-0.48 | centre, beside the central trade route | 7/7 | 1.43 | 2.19 | yes | yes (only carts or trade units that move differ) | [jpg](media/WOLsahel.jpg) |
| WOLsavannah | nearest open spot to the middle; end of the script | x 0.47-0.53, z 0.42-0.66 | the middle of all start positions (the map centre), on open land | 7/7 | 1.27 | 1.28 | yes | yes | [jpg](media/WOLsavannah.jpg) |
| WOLScandinavia | nearest open spot to the middle; end of the script | x 0.46-0.51, z 0.46-0.53 | the middle of all start positions (the map centre), on open land | 7/7 | 1.11 | 1.23 | yes | yes | [jpg](media/WOLScandinavia.jpg) |
| WOLsocotra | between the teams; end of the script | x 0.40-0.80, z 0.37-0.50 | the open land around the middle of the island, off the central mesa (its cliffs have no ramp) | 7/7 | 1.22 | 2.72 | no: far:p1,p2,p3,p4 (p1:23m(AFRICANvillager,6 moved) p2:22m(AFRICANalipash | yes | [jpg](media/WOLsocotra.jpg) |
| WolTahiti | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.45-0.55 | centre, on the land between the two parts of the island | 7/7 | 1.34 | 3.03 | yes | yes | [jpg](media/WolTahiti.jpg) |
| WOLtuscany | nearest open spot to the middle; end of the script | x 0.46-0.54, z 0.48-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.47 | 1.26 | yes | yes | [jpg](media/WOLtuscany.jpg) |
| WOLvalleyofkings | nearest open spot to the middle; end of the script | x 0.47-0.57, z 0.45-0.57 | the middle of all start positions (the map centre), on open land | 7/7 | 1.36 | 1.14 | yes | yes | [jpg](media/WOLvalleyofkings.jpg) |
| WoLverdongorge | between the teams; end of the script | x 0.27-0.69, z 0.33-0.65 | the middle is the gorge's lake; first open land on the line that splits the teams (the gorge's banks) | 7/7 | 1.34 | 2.03 | no: far:p3 (p1:6m(AFRICANvillager,7 moved) p2:7m(AFRICANalipasha,1 moved)  | yes | [jpg](media/WoLverdongorge.jpg) |
| WOLwateringhole | nearest open spot to the middle; end of the script | x 0.46-0.56, z 0.46-0.53 | the middle of all start positions (the map centre), on open land | 7/7 | 1.11 | 1.26 | yes | yes | [jpg](media/WOLwateringhole.jpg) |
| WOLwetlands | nearest open spot to the middle; end of the script | x 0.42-0.63, z 0.37-0.58 | the central island of the marsh | 7/7 | 1.35 | 1.65 | yes | yes | [jpg](media/WOLwetlands.jpg) |
| WOLzimbabwe | nearest open spot to the middle; end of the script | x 0.47-0.54, z 0.45-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.29 | 1.37 | yes | yes | [jpg](media/WOLzimbabwe.jpg) |
| yucatan | TAD's own code | x 0.46-0.55, z 0.46-0.54 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.42 | 1.36 | yes | yes | [jpg](media/yucatan.jpg) |
| yukon | TAD's own code | x 0.45-0.56, z 0.46-0.54 | TAD's own King of the Hill code for this map, ported to WoL's version | 7/7 | 1.27 | 1.21 | yes | yes | [jpg](media/yukon.jpg) |
| Yungas | nearest open spot to the middle; after the Town Centers | x 0.47-0.53, z 0.47-0.54 | the middle of all start positions (the map centre), on open land | 7/7 | 1.22 | 1.07 | no: far:p1,p2,p3,p4 (p1:18m(AFRICANvillager,6 moved) p2:22m(AFRICANalipash | yes | [jpg](media/Yungas.jpg) |

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
- [WOLblackforest](media/WOLblackforest.jpg)
- [WOLcentralplateau](media/WOLcentralplateau.jpg)
- [WOLcerrado](media/WOLcerrado.jpg)
- [WOLcongo](media/WOLcongo.jpg)
- [WOLdallol](media/WOLdallol.jpg)
- [WOLeasterisland](media/WOLeasterisland.jpg)
- [WOLEcruteak](media/WOLEcruteak.jpg)
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
- [WOLsahara](media/WOLsahara.jpg)
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
