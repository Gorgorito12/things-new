Map descriptions in one standard format (pilot: 5 maps)
=======================================================

JTMaston asked for map descriptions in a standard format, shown in the lobby (when you hover the
minimap) and on the loading screen. This folder holds the format, the facts of all 208 random maps
(read from their scripts and checked in game), and five maps done as a pilot, in English and Spanish.


What the game shows (tested in game)
------------------------------------
- Lobby rollover: the map's "details" (string ID) or "detailsText" (literal text).
  Loading screen: "loadDetails" (string ID) or "loadDetailsText".
- When a map has both an ID and literal text, the ID wins, in both places.
- Attribute names do not care about case: "detailstext" and "loadDetailsTEXT" work. The fix writes the
  standard names anyway.
- "\n" (a backslash and an n) starts a new line, in both places. A real line break in the XML does not.
- Markup that works: <color=r,g,b>text</color> (r, g, b from 0 to 1), <icon=(20)(path)>, <u>text</u>.
  <b> does nothing.
- Room: the lobby rollover is about 55 characters wide and grows downwards (22 lines still fit at
  1920x1080). The loading screen box is about 80 characters wide and shows 15 lines; anything after
  the 15th line is cut off. The standard text below uses 9 to 12 lines.


The format
----------
Lobby (short):
    <Name>: <one line: the landscape and what it rewards>
    Region: ... | Trade route: Yes/No | King of the Hill: Yes/No
    Natives: ...
    Outlaws: ...
    Hunt: ... | Herd: ...
    Mines: ... | Berries: ...
    Sea: ...                      (only on maps with fish or whales)

Loading screen: the same, with 2-3 sentences after the first line about the landscape, the
chokepoints and what the map rewards.

The labels (Region:, Trade route:, ...) are drawn in gold with <color=0.95,0.78,0.42>.
Regions: North America, South America, Europe, Africa, Middle East, Asia, Oceania, Indian
Subcontinent, Space, Other.
"Outlaws" lists the fixed outlaws of the map plus how many are drawn at random each game.

Every text is a string ID, so it can be translated. The IDs are 6170000-6170415, two per map (lobby,
loading), listed in string-ids.csv for all 208 maps. This range is free in data\stringtabley.xml,
translations\_originals\stringtabley.xml, translations\ES-LA\stringtabley.xml,
randommapstringsy.xml and unithelpstringsy.xml.


How outlaws are picked (important for mapspecifictechs.xml)
------------------------------------------------------------
We checked this in the game's code and in game:

- The game takes the FIRST <map name="..."> block, in file order, whose name is one of the map's types
  (rmSetMapType). "default" counts as a type of every map; it is the last block, so it is the
  fallback.
- A block named after a map FILE is never used, unless that name is also a type in maptypes.xml.
  108 of the 157 blocks in mapspecifictechs.xml are such blocks (DansilChupat, ESOC_Arizona,
  WOLhawaii, ...): they do nothing. Only WOLcave works, because WolCave is a map type.
  Example tested in game: DansilChupat has its own block (Pistolero, Comanchero) but its type is
  "araucania", so its saloon trains Hired Proscrito, Hampon and Hired Cuatrero (+3 random).
- Upper and lower case do not matter, so the "Arabia" block (4th in the file) is used for every map
  of type "arabia", and the "arabia" block near the end (Muharib, Sariq, Khali) is never used.
  Tested in game: Arabia's saloon trains Pistolero and Renegado.
- To give one map its own outlaws, give it its own map type (add a <type> to maptypes.xml, call
  rmSetMapType with it in the map, and name the block after that type).
The descriptions list the outlaws the game really gives, not the dead blocks.


The pilot
---------
Five maps, one of each kind: a river map (Irrawaddy River), an island map (Hawai'i), a desert map
(Atacama), a mountain map (Rockies) and a map without a trade route (Alps). The facts come from the
scripts and were checked in game (2 games each); where the game disagreed with the script, the text
follows the game:

- Irrawaddy River: the script's "dry river" branch can never run (seasonSwitch is 1 to 6, the dry case
  is 0), so the river always has 3 fords (4 with 6 or more players); the old text said it may be dry.
  The starting berry bushes are defined but their placement is commented out: no berries.
- Hawai'i: the Jesuit and Sufi villages use groupings "1" to "5", which do not exist, so they never
  appear; the natives are the Heiau temples. The water trade route places no trading post site in
  our games (2 players, 2 seeds), so the text says "Trade route: No". Please check this one.
- Atacama: the natives block is inside a comment: no natives, as the old text says.
- Rockies: one native nation per game, Cheyenne OR Comanche.
- Alps: the three European camps use groupings ("EURNShunters med", "EURNSlumberjacks med",
  "EURNSstonemasons east") that do not exist in RM4\groupings, so no camp appears; the grape vines
  are defined but never placed. The text says no natives and no berries.


Other things found on the way
-----------------------------
- data\civs.xml: the AURCattle entry starts with "<!-- civ>" but ends with "</civ>", so the comment
  runs on to the next "-->", 20 entries later: AURCocoa, AURManioc, AURSalt, AURCoffee, AURVanilla,
  AURTimber, AURRubber, AURIvory, AURTextiles, AURPalmOil, AURGold, AURDiamonds, AURTreasures,
  AUROil, AURFigurines, AURLiterature, AURSlaves, AURIncense, AURSilk and AURGems are all inside it.
  For an XML reader these civs do not exist. In game, the African trade sites (the AUR<resource>
  "Socket" buildings) still appear on the maps that place them through groupings (Atlas, Niger
  River, Azores, Bioko, ...), so we could not tell whether the game reads these entries; please
  check that such a site can be used in game, and fix the comment either way. Blue Nile (file
  "Desert Flood") placed no trade site in 2 games; we did not look into why.
- 49 maps create groupings whose file does not exist (column missing_groupings), and 29 maps define
  resources they never place (column defined_not_placed). Neither crashes the game; the objects are
  just missing.
- See "How outlaws are picked" above: 108 blocks of mapspecifictechs.xml are never used.


Current texts that are broken or missing
----------------------------------------
- No lobby text: saskatchewan, whiteshell, WOLFjord. No text at all: WOLGibraltar.
- WOLsocotra puts its text in "details" and "loadDetails", which expect a string ID.
- mongolia: loadDetails="70027 " (a space after the ID).
- Misspelt names (they still work, as names ignore case): detailstext in ESOC_Herald Island,
  ESOC_Malaysia and ESOC_Thar Desert; loadDetailsTexT in ESOC_Manchac; loadDetailsTEXT in
  WOLblackforest.
The full run rewrites all of these with string IDs.


Files
-----
  README.txt              this file
  mapfacts.csv            the facts of all 208 maps (see "The facts table" below); mapfacts.json
                          is the same for make_descriptions.py
  string-ids.csv          the two string IDs of every map
  texts.csv               the hand-written sentences of the pilot maps (English, Spanish) and the
                          facts corrected by hand
  descriptions.csv        the finished pilot texts (what goes into the string tables)
  strings-en.xml          the new English <String> lines, to paste by hand if you prefer
  strings-es.xml          the same in Spanish
  RM4\*.xml               the five pilot maps' .xml files after the change
  apply_fix.py            applies everything to a WoL folder (see below)
  make_descriptions.py    rebuilds descriptions.csv from mapfacts.csv/json and texts.csv
  media\                  screenshots, before and after (see "Media")


The facts table (mapfacts.csv)
------------------------------
One row per map, read from the map's .xs (without comments) and the game data. Main columns:
  name_en / name_es          the name the game shows
  region, region_note        region; a note where another region could also fit
  trade_route                Yes / No; "(water)" for a water route; "depends on teams/players",
                             "not in KOTH", "varies" when the script builds it only in some cases
                             (trade_route_conditions has the script's conditions)
  koth                       Yes when the map has a King of the Hill placement
  natives, natives_varies    native civs (rmSetSubCiv); natives_slots shows which civs a slot can take
  hunt, herd, mine, berry,   resources placed by the script, by unit type; "(varies)" = picked at
  fish, whale                random; *_en and *_es are the names the game shows
  outlaws                    the fixed outlaws of the block the game really uses (+N random)
  outlaw_block               that block and why; dead_block_for_file = a block written for this map
                             that the game never uses
  unresolved, defined_not_placed, missing_groupings
                             names the data does not define, resources never placed, grouping
                             files that do not exist
  lobby_en / loading_en      the current texts
  seen_*                     what the game really placed (2 games per map, see below)
  check                      where script and game disagree; empty = they agree
The descriptions use the "seen" facts where they differ from the script.


Checked in game
---------------
Every one of the 208 maps was generated twice (2 players, seeds 1 and 2, the editor route), and the
units on the map at the start were listed and compared with the script facts.

  maps where script and game agree on everything      162
  maps with at least one difference (column "check")   46

The differences, by kind (a map can have several):
  21  natives in the script, no village in either game: Blue Nile (Desert Flood), Dunas,
      ESOC Kamchatka, Pohnpei (everglades), "NEW" Dinarides, "NEW" Ferghana, "NEW" Iranian Plateau,
      Alps, Aegean (WOLbalkans), British Isles, Cave, Ecruteak, Fjord, Hawai'i, Iberian Peninsula,
      Iceland, The Moon, Scandinavia, Socotra, Tuscany, Verdon Gorge. Several use grouping files
      that do not exist (missing_groupings); the European camps of the WoL European maps never
      appeared. These are the most useful leads for the WoL team.
  17  a fish, whale, hunt, herd or berry the script places that neither game showed: mostly placed
      only with more players or in water a 2-player map does not have.
  16  a gaia animal or plant seen that the script does not place (Badger, ypIGCBird, Hen, Cow,
      Treerubber, ...): spawned by something else than the map script (triggers, nuggets, civs).
   5  one native nation of several missing in both games (ESOC Arkansas, Deccan Large, Owikeno), or
      African trade sites seen that the tool could not read from the script (Congo, Sahara: their
      names are built in a way the tool does not follow).
   1  Hawai'i's water trade route placed no trading post site.
Each difference is in the "check" column of that map, so a description can follow the game.

Two runs crashed (WOLethiopianhighlands seed 1, WOLFjord seed 2), both while generating the map,
after about 80 maps in the same game process. Run again in a fresh game, both were fine: we think
the long session, not the maps, caused them.


Media
-----
Screenshots from the game (Spanish copy, 1920x1080), before and after the change, for each pilot map:
the lobby (skirmish setup, mouse on the minimap) and the loading screen.

  map                    lobby before / after                     loading screen before / after
  Irrawaddy River        media\DansilIrrawaddyRiver-lobby-before.jpg / -after.jpg
                                                                   media\DansilIrrawaddyRiver-loading-before.jpg / -after.jpg
  Hawai'i                media\WOLhawaii-lobby-before.jpg / -after.jpg
                                                                   media\WOLhawaii-loading-before.jpg / -after.jpg
  Atacama                media\atacama-lobby-before.jpg / -after.jpg
                                                                   media\atacama-loading-before.jpg / -after.jpg
  Rockies                media\rockies-lobby-before.jpg / -after.jpg
                                                                   media\rockies-loading-before.jpg / -after.jpg
  Alps                   media\WOLAlps-lobby-before.jpg / -after.jpg
                                                                   media\WOLAlps-loading-before.jpg / -after.jpg

Also: media\format-test-lobby.jpg (colour tag, line breaks, long text in the rollover) and
media\format-test-loading.jpg (the loading box cuts the text after 15 lines).


Next: the other 203 maps
------------------------
The pilot shows the format; tell us what to change before we write the rest. For each map we then
write the first line and the 2-3 sentences (from the script and the current text) in English and
Spanish, take the facts from mapfacts.csv, follow the game where the "check" column says it differs,
and test a sample in game again. King of the Hill is being added to more maps at the same time; the
"koth" column is refreshed from the scripts before the texts are made.


Applying it
-----------
    python apply_fix.py "<WoL folder>"            (backs up every file it changes first)
    python apply_fix.py "<WoL folder>" --restore  (puts the backups back)
    python apply_fix.py "<WoL folder>" --out <folder>   (writes the changed files there instead)

It adds or replaces the strings in translations\_originals\stringtabley.xml (English),
translations\ES-LA\stringtabley.xml (Spanish) and data\stringtabley.xml (in whichever language that
file holds), and sets details="<ID>" and loadDetails="<ID>" in each pilot map's .xml, removing its
literal detailsText / loadDetailsText (also the misspelt ones).
