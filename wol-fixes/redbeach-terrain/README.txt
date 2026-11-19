RED BEACH TERRAIN - A RECOLOUR THAT KEEPS PLAYER 2 VISIBLE
==========================================================

Request (JTMaston): "Redbeach terrain has a extremely saturated red colour that interferes with the
player 2 color, can the red land texture be altered in order to improve gameplay while keeping its
identity?"

Short answer: yes. Variant B (maroon / wine, below) is recommended. It is in this folder at its game
paths, ready to copy. Variants A and C are under variants\ for comparison. Loose files only: no .bar
archive is changed.

Start with media\comparison-sheet.jpg (all four, same scene) and media\textures-sheet.jpg (the
textures themselves next to the player colours).


1. THE PROBLEM
--------------

Map: RM4\dansilRed Beach.xs is the only RM4 map that uses this terrain. Its whole land area is the mix
art\terrain\mix\redbeach_grass.xml (rmSetAreaMix, line 124), and its sea is "red beach"
(data\waterBodies.xml, whose banks and bottom use the same textures).

Player colours: WoL uses the stock playercolors.xml.xmb (in data\Data.bar and data\Data2.bar,
identical; there is no loose copy and no WoL override). Player 2 is color1 = 210 40 40 on units and
255 50 50 on the minimap. Note also friendorfoeenemy = 230 40 40: in team-colour mode EVERY enemy is
red, so the red ground hides all enemies there, not only player 2.

What was measured (CIEDE2000, "dE"; about 2 is a just visible difference, above 30 two colours are
clearly apart):
- The mix, weighted as redbeach_grass.xml weights its 6 textures (grass3 x4, grass1 x2, grass2 x2,
  grass3b, grass1b, grass1c x1), has a mean colour of 99 24 25.
- dE from that ground to player 2 is 22.8. Every other player is at least 39.6 away (blue is the
  nearest), and the median of players 1, 3-8 is 65.7.
- 39.9 % of the ground's pixels are within dE 20 of player 2's colour: the bright red grass blades
  (grass1, grass2, grass3) are the same colour as the units' player colour.
- The minimap colour of the terrain (terraintypes.xml, class RedBeach) is 160 015 030: dE 21.7 from
  player 2's minimap red 255 50 50. On the minimap player 2's dots almost disappear (see
  media\original-wide.jpg).
- In game (the shot media\original-wide.jpg, lit by the map's "st_petersburg" lighting) the ground
  reads even redder: dE 27.3 from player 2, and 13.7 % of the ground's pixels within dE 20 of it. The
  red selection rings and HP bars of player 2's own units vanish into it (media\original-close.jpg,
  media\original-buildings.jpg).

About the target "player 2's dE to the ground as large as the median of the other players'": no ground
that still reads as red can reach it. Over every colour with a red-to-crimson hue and enough chroma to
look red at all (OKLCH chroma 0.05 or more), the largest dE to player 2 is about 42 (a near-black
wine), while the median of the other players to such a colour is about 75. The reachable and useful
target is the next one: player 2 no farther from the ground than the nearest other players (blue and
purple, about 38-40). Variant B reaches it.


2. THE THREE VARIANTS
---------------------

Made with tools/recolor_textures.py of the aoe3-blender-tools repository (branch terrain-recolor).
The change is done in OKLCH (a perceptual colour space) on the red hues only (hue 25 +/- 20 degrees,
fading out over 25 more), so the brown soil and the yellow stems of the marsh plant keep their colour.
Each texture keeps its format (DXT1, or BGRA with its alpha for the plant), its size and its 9 (or 7)
mip levels, each level recoloured from the original's own. The 8 bump maps are not touched.

  A - softer crimson   hue -5,  chroma x0.50, lightness x0.88   minimap 110 049 051 (dirt 068 030 033)
  B - maroon / wine    hue -10, chroma x0.80, lightness x0.66   minimap 090 000 026 (dirt 056 000 016)
  C - magenta          hue -38, chroma x0.75, lightness x0.90   minimap 119 035 087 (dirt 073 023 056)

Each variant recolours the 9 diffuse textures of art\terrain\wotta\red beach\ (dirt, grass1,
grass1b-1e, grass2, grass3, grass3b), the marsh plant art\War of the Triple Alliance\Nature\
red_beach_grass.ddt (proto RedBeachGrass, used by MarshPlantsRedBeach), and the mapcolor of the 10
subtypes of the RedBeach class in art\terrain\terraintypes.xml (the minimap colour got the same
transform as the textures). Nothing else in terraintypes.xml changes.


3. dE TABLE
-----------

a) The textures (the mix's weighted mean colour, top mip level; reports\*-terrain.json):

  variant    ground mean   dE to P2   nearest other     median of others   ground pixels within dE 20 of P2
  original   99 24 25      22.8       39.6 (P1 blue)    65.7               39.9 %
  A          69 35 35      29.4       36.5 (P1 blue)    68.5                4.0 %
  B          57  6 16      32.9       38.5 (P1 blue)    75.5                0.2 %
  C          75 28 55      33.3       30.8 (P1 blue)    66.2                0.1 %

  Per player (dE from the ground mean; P2 in brackets):
  original   P1 39.6 [P2 22.8] P3 75.8 P4 39.9 P5 81.7 P6 55.0 P7 82.1 P8 65.7
  A          P1 36.5 [P2 29.4] P3 75.9 P4 38.3 P5 74.1 P6 57.5 P7 81.8 P8 68.5
  B          P1 38.5 [P2 32.9] P3 85.2 P4 40.4 P5 83.8 P6 63.2 P7 96.2 P8 75.5
  C          P1 30.8 [P2 33.3] P3 84.3 P4 32.1 P5 84.0 P6 64.1 P7 83.9 P8 66.2

b) In game (the ground of the wide shots, as drawn with the map's lighting; reports\ingame-shots.json):

  variant    ground drawn   dE to P2   nearest other   median of others   pixels within dE 20 of P2
  original   78 18 21       27.3       39.4            71.8               13.7 %
  A          51 25 29       33.9       36.5            73.5                0.0 %
  B          42  5 13       36.3       38.5            76.6                0.0 %
  C          56 20 47       37.1       31.5            71.7                0.0 %

c) Minimap (terrain mapcolor against the players' minimap colours):

  variant    mapcolor        dE to P2 (255 50 50)   dE to P4 purple (148 0 197)   nearest other
  original   160 015 030     21.7                   35.7                          32.2 (P6 orange)
  A          110 049 051     30.1                   31.0                          31.0 (P4)
  B          090 000 026     36.3                   32.7                          32.7 (P4)
  C          119 035 087     36.5                   19.4                          19.4 (P4)


4. RECOMMENDATION: B (MAROON / WINE)
------------------------------------

- It stays a red beach. The real Red Beach (Panjin, China) is a marsh of Suaeda seepweed that turns
  crimson to maroon; B is that deep wine red, darker than the units' bright red. A turns pinkish
  brown (heather) in game, and C reads as purple.
- Player 2 is no longer the odd one out: in game its dE to the ground goes from 27.3 to 36.3, level
  with the nearest other player (blue, 38.5), and no ground pixel is within dE 20 of it any more
  (13.7 % before). The red selection rings and HP bars show again (media\B-close.jpg,
  media\B-buildings.jpg).
- It creates no new clash. C also moves player 2 away, but it moves the ground towards purple: player
  4 drops to dE 31.5 in game and to 19.4 on the minimap, a new clash as bad as the old one. A is the
  mildest change but leaves player 2 closest (29.4).
- Minimap: player 2's dots go from dE 21.7 to 36.3; purple (player 4) is the nearest at 32.7, which is
  about what blue and orange were before.
- It also helps team-colour mode, where all enemies are red (230 40 40).
Cost: the map is darker overall. Brown and dark units (and black, player 9, not used in 8-player
games) lose a little contrast; blue stays at dE 38.5.


5. HOW TO INSTALL
-----------------

1. Back up these files of the WoL folder (they are replaced):
     art\terrain\terraintypes.xml
     art\terrain\wotta\red beach\dirt.ddt, grass1.ddt, grass1b.ddt, grass1c.ddt, grass1d.ddt,
       grass1e.ddt, grass2.ddt, grass3.ddt, grass3b.ddt
     art\War of the Triple Alliance\Nature\red_beach_grass.ddt
2. Copy the art folder of this folder over the WoL folder (same paths). The *_b.ddt bump maps stay
   as they are.
3. Restart the game: terraintypes.xml and the textures are read at startup.

To try A or C instead, copy variants\<name>\art the same way. To undo, put the backed-up files back.

terraintypes.xml here is WoL's own file (99,843 bytes) with only the 10 mapcolor values of the
RedBeach class changed; if WoL's copy changed since, change those 10 values in it instead:
"160 015 030" -> "090 000 026" (nine lines) and "100 015 025" -> "056 000 016" (the dirt line).

SHA-256 of the recommended files:
  bc7530fb30aaac28f59f4d1628ebc03884f92a421b6710b3c3b400c301d44ba1  art/terrain/wotta/red beach/dirt.ddt
  e091c6979aed67026951a9f65794a36e90bbc37b0d704002981f915ce8025b4c  art/terrain/wotta/red beach/grass1.ddt
  41de291246c755398bbcec4d6226eefbd0bb726874be07f7f6f9e1601303c636  art/terrain/wotta/red beach/grass1b.ddt
  60b6a0697d4b33d5d1106560843971c427f5b478a59d8136d6eb37957c24d45c  art/terrain/wotta/red beach/grass1c.ddt
  170f6f1bc0bf5dcaea032d337e237a4fd6a975155d6064381d2f694c2169a49d  art/terrain/wotta/red beach/grass1d.ddt
  445fa48b2f625647cdb3a08ae9f403248d99d58c0f6f667f67abb6242d3654b8  art/terrain/wotta/red beach/grass1e.ddt
  bf65f32cc5b04afb67c85c03e69cae1ec87d45010f0a02e549059749d5a14722  art/terrain/wotta/red beach/grass2.ddt
  d570e2e27165a05abb9cfda3953a02b832075144947620818aaaa0147db6744d  art/terrain/wotta/red beach/grass3.ddt
  d9798998e3853449d87cc7c06c6765d7bc070ec12b9d3ca5dfeb52749ecabad2  art/terrain/wotta/red beach/grass3b.ddt
  e90426000c0c74082a0a25b67c9c2bb8bdef87131125fb017098fea7219063b3  art/War of the Triple Alliance/Nature/red_beach_grass.ddt
  28d908d134adfedd29dc165327aff626437f5b5d368eb79885b9b28a1479e86c  art/terrain/terraintypes.xml


6. HOW IT WAS TESTED
--------------------

In a test copy of WoL (never the Steam folder), with the original files and each variant in turn,
each in a fresh game. The scene is test\uhcredbeach.xs: the Red Beach sea, lighting and land mix,
player 2 (Egyptians) with 2 houses, a barracks, a stable, 6 settlers, 6 crossbowmen and 4 hussars on
the red ground, and a trigger ("Player Set Active") that makes player 2 the human so its units can be
selected. It was generated in the scenario editor with seed 1 (the same map every time) and played as
a scenario with no AI. Per variant: media\<v>-close.jpg (units of player 2 selected: rings and HP
bars), <v>-buildings.jpg (the buildings selected; the game does not mix units and buildings in one
selection) and <v>-wide.jpg (wider view). The minimap is in every shot. Afterwards the original files
were put back and checked by SHA-256. The game was in English.


7. SIDE FINDINGS (not changed here)
-----------------------------------

- data\forest.xml (UTF-16) names floor mixes that do not exist: "Red Beach Forest" uses
  floormix="red beach_forest" (the mix is redbeach_forest, without the space), and "Red Beach
  Saltmarsh" and the second "Red Beach Forest" use floormix="red_beach_grass2" (no such mix; there
  are redbeach_grass and redbeach_forest only). Two forests are also both called "Red Beach Forest".
- RM4\asianrandom.set, fastrandom.set, landmapsrandom.set, normalrandom.set and RM4\mapsetnames.xml
  still list WOLredbeach, which exists only in RM3 (RM3\WOLredbeach.xs). fastrandom.set even carries
  the comment "WOLredbeach //is this still needed? Now we have dansilRed Beach".
  AI4\aiWoLMain.xs and data\mapspecifictechs.xml also still name WOLredbeach.
- art\terrain\mix\redbeach_forest.xml uses grass1c and grass1b, so the recolour reaches it too.


8. FILES
--------

art\                     the recommended variant B, at its game paths
variants\A-crimson-soft\ variant A, same layout
variants\C-magenta\      variant C, same layout
media\                   comparison-sheet.jpg, textures-sheet.jpg, and the shots per variant
reports\                 the tool's reports (before / after per texture, the mix, the minimap colour),
                         original-measure.json (the original only) and ingame-shots.json
test\                    the test scene (a test map, not a playable map)
