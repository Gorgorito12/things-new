Map descriptions in one standard format (all 208 random maps)
=============================================================

JTMaston asked for map descriptions in a standard format, shown in the lobby (when you hover the
minimap) and on the loading screen. This folder holds new descriptions for all 208 random maps in
English and Spanish, the facts behind them (read from the map scripts and checked in game), a script
that installs them, screenshots, and the problems we found in the maps' data on the way.

Status: all 208 maps written. The "King of the Hill" line follows the maps as they are now; another
change adds King of the Hill to more maps, and the column will be refreshed when it lands (PENDING).


What the game shows (tested in game)
------------------------------------
- Lobby rollover: the map's "details" (string ID) or "detailsText" (literal text).
  Loading screen: "loadDetails" (string ID) or "loadDetailsText".
- When a map has both an ID and literal text, the ID wins, in both places.
- Attribute names do not care about case: "detailstext" and "loadDetailsTEXT" work. The fix writes the
  standard names anyway.
- "\n" (a backslash and an n) starts a new line, in both places. A real line break in the XML does not.
- Markup that works: <color=r,g,b>text</color> (r, g, b from 0 to 1), <icon=(20)(path)>, <u>text</u>.
  <b> does nothing. A space right after </color> is dropped, so a label keeps its space inside the tag.
- Room in the lobby: the rollover grows with the text; at 1920x1080 it is about 55 characters wide
  (22 lines still fit), at 1024x768 the font is smaller and it is wider in characters. No limit was hit.
- Room on the loading screen: the box keeps the font size and shrinks with the screen.
    1920x1080: about 80 characters per line, 15 lines
    1024x768:  about 45 characters per line, 12 lines
  Anything after the last line is cut off. Every loading text here fits the 1024x768 box.


The format
----------
Lobby (one fact per line, every line at most 44 characters):
    <Name>: <one line: the landscape and what it rewards>
    Region: ...
    Trade route: Yes/No
    King of the Hill: Yes/No
    Natives: ...
    Outlaws: ...
    Hunt: ...
    Herd: ...
    Mines: ...
    Berries: ...
    Sea: ...                      (only on maps with fish or whales)
    Map by <author>               (when the old text credited one)
The rollover opens to the right of the mouse and grows up to about 55 characters; hovering the right
half of the minimap, the screen edge then cuts long lines. With 44-character lines the box stays
narrow enough for most of the minimap.

Loading screen (the map's name is already shown above the box):
    <2-3 sentences: the landscape, the chokepoints, what the map rewards> [Map by <author>.]
    Region: ... | Trade route: ... | King of the Hill: Yes   (only when the map has it)
    Natives: ...
    Outlaws: ...
    Hunt: ... | Herd: ...
    Mines: ... | Berries: ...
    Sea: ...
with lists of at most 3.

To fit the 1024x768 box, make_descriptions.py drops, in this order and only as far as needed: the
author credit (it stays in the lobby), the story's last sentences (one sentence is always kept),
and on a few maps the "Sea" line. The facts always stay. At 1920x1080 the box would hold more, but
one text has to serve both.

The labels are drawn in gold with <color=0.95,0.78,0.42>.
Regions: North America, South America, Europe, Africa, Middle East, Asia, Oceania, Indian
Subcontinent, Space, Other.
"Outlaws" lists the fixed outlaws of the map plus how many are drawn at random each game.
Lists longer than 5 (3 on the loading screen) end in "…". Where the natives change from game to game
the line says "A, B or C (varies)". WoL's African trade sites (the AUR<resource> buildings) are listed
as "African trade sites: Cocoa, Salt, ...".

The facts follow the GAME, not only the script: every map was generated twice in game and the
descriptions use what the game really placed (see "Checked in game").

Every text is a string ID, so it can be translated. The IDs are 6170000-6170415, two per map (lobby,
loading), listed in string-ids.csv. This range is free in data\stringtabley.xml,
translations\_originals\stringtabley.xml, translations\ES-LA\stringtabley.xml,
randommapstringsy.xml and unithelpstringsy.xml.


Leads for the WoL team (facts and suggestions)
-----------------------------------------------
Every item with its file and line is in leads.csv (kind, file, line, name, detail).

1. mapspecifictechs.xml: 108 dead blocks.
   Fact (game code and in game): the game takes the FIRST <map name="..."> block, in file order, whose
   name is one of the map's types (rmSetMapType); "default" (the last block) counts for every map. A
   name that is not a <type> in data\maptypes.xml becomes "no type", and that block is never used.
   108 of the 157 blocks are named after map FILES (DansilChupat, ESOC_Arizona, WOLhawaii, ...) and
   do nothing; only WOLcave works, because WolCave is a map type.
   Tested in game: DansilChupat has its own block (Pistolero, Comanchero), but its type is
   "araucania", so its saloon trains Hired Proscrito, Hampon and Hired Cuatrero (+3 random).
   Suggestion: to give a map its own outlaws, add a <type> to maptypes.xml, call rmSetMapType with it
   in the map, and name the block after that type.

2. mapspecifictechs.xml: "Arabia" (line 214) hides "arabia" (line 10514).
   Fact: names ignore upper and lower case, so every map of type "arabia" gets the first block,
   "Arabia" (Pistolero, Renegado); the "arabia" block (Muharib, Sariq, Khali) is never used.
   Tested in game: Arabia's saloon trains Pistolero and Renegado.
   Suggestion: rename one of the two (and its map type), or merge them.

3. data\civs.xml, line 14772: a comment that never closes.
   Fact: the AURCattle entry opens with "<!-- civ>" and ends with "</civ>", not "</civ -->", so the
   comment runs on to the next "-->" at line 15128 and holds 20 more entries: AURCocoa, AURManioc,
   AURSalt, AURCoffee, AURVanilla, AURTimber, AURRubber, AURIvory, AURTextiles, AURPalmOil, AURGold,
   AURDiamonds, AURTreasures, AUROil, AURFigurines, AURLiterature, AURSlaves, AURIncense, AURSilk,
   AURGems. For an XML reader these civs do not exist. In game the trade-site buildings still appear
   on maps that place them through groupings (Atlas, Niger River, Azores, Bioko, ...), so we could not
   tell what the game does with these entries. Blue Nile (file "Desert Flood") placed no trade site in
   2 games.
   Suggestion: close the AURCattle comment with "</civ -->" (or remove the comment), then check that
   an African trade site can be allied in game.

4. 36 maps ask for grouping files that do not exist (no RM4\groupings\<name>.xml).
   Fact: nothing is placed for them, with no error. Examples: Hawai'i's Jesuit and Sufi villages use
   groupings named "1" to "5"; Alps' three European camps use "EURNShunters med",
   "EURNSlumberjacks med" and "EURNSstonemasons east" (the files are named "european fur trappers
   med", ...). All 36 maps, with the missing names and the lines of the calls, are in leads.csv and in
   the column missing_groupings of mapfacts.csv.
   Suggestion: fix the names, or remove the calls.

5. 29 maps define resources they never place (34 cases).
   Fact: rmAddObjectDefItem adds a resource to an object definition, but the line that would place it
   is commented out or missing. Examples: Irrawaddy River's starting berry bushes, Alps' grape vines.
   Listed in leads.csv (with lines) and in the column defined_not_placed.
   Suggestion: place them, or remove the definitions.

6. Hawai'i (RM4\WOLhawaii.xs, lines 313-387): the trade route places no trading post.
   Fact: the script builds a "water" trade route with SocketTradeRoute sites, but no site appeared in
   2 games (2 players). The description says "Trade route: No".
   Suggestion: check the route in game; place its sockets on land.

7. 21 maps whose natives never appeared in 2 games: Blue Nile (Desert Flood), Dunas, ESOC Kamchatka,
   Pohnpei (everglades), "NEW" Dinarides, "NEW" Ferghana, "NEW" Iranian Plateau, Alps, Aegean
   (WOLbalkans), British Isles, Cave, Ecruteak, Fjord, Hawai'i, Iberian Peninsula, Iceland, The Moon,
   Scandinavia, Socotra, Tuscany, Verdon Gorge. Their descriptions say "Natives: none". Several of
   them are explained by item 4.


The outlaw rule in more detail
------------------------------
We checked it in the game's code (the loader of mapspecifictechs.xml, the name lookup in the map-type
table built from maptypes.xml, the rmSetMapType command, and the function that picks the block) and in
game with two maps. The order of a map's rmSetMapType calls does not matter; an unknown type in
rmSetMapType is ignored with the message "'...' is not a valid map type. Ignoring.".


Current texts that were broken or missing
-----------------------------------------
- No lobby text: saskatchewan, whiteshell, WOLFjord. No text at all: WOLGibraltar.
- WOLsocotra put its text in "details" and "loadDetails", which expect a string ID.
- mongolia: loadDetails="70027 " (a space after the ID).
- Misspelt names (they still worked, as names ignore case): detailstext in ESOC_Herald Island,
  ESOC_Malaysia and ESOC_Thar Desert; loadDetailsTexT in ESOC_Manchac; loadDetailsTEXT in
  WOLblackforest.
The new .xml files (RM4\) replace all of these with string IDs.


Files
-----
  README.txt              this file
  descriptions.csv        the finished texts, all 208 maps (what goes into the string tables)
  strings-en.xml          the new English <String> lines, to paste by hand if you prefer
  strings-es.xml          the same in Spanish
  RM4\*.xml               the 208 maps' .xml files after the change (details / loadDetails IDs)
  apply_fix.py            installs everything into a WoL folder (see below)
  texts.csv               the written sentences per map (English, Spanish), the author credit, and
                          a column per fact where a fact needed a hand correction
  make_descriptions.py    rebuilds descriptions.csv and strings-*.xml from texts.csv and mapfacts
  mapfacts.csv            the facts of all 208 maps (see "The facts table"); mapfacts.json is the
                          same for make_descriptions.py
  string-ids.csv          the two string IDs of every map
  leads.csv               the problems found in the data, with file and line
  media\                  screenshots (see "Media")


The facts table (mapfacts.csv)
------------------------------
One row per map, read from the map's .xs (without comments) and the game data, then compared with
what the game placed. Main columns:
  name_en / name_es          the name the game shows
  region, region_note        region; a note where another region could also fit
  trade_route                Yes / No / "Yes (...)" when the script builds it only in some setups
                             (trade_route_conditions has the script's conditions)
  koth                       Yes when the map has a King of the Hill placement (PENDING refresh)
  natives, natives_source    the natives of the script: from the villages' grouping files, or from
                             rmSetSubCiv; natives_varies when they change from game to game
  hunt, herd, mine, berry,   resources the script places, by unit type; "(varies)" = in some games
  fish, whale                only; *_en and *_es are the names the game shows
  outlaws                    the fixed outlaws of the block the game really uses (+N random)
  outlaw_block               that block and why; dead_block_for_file = a block written for this map
                             that the game never uses
  unresolved, defined_not_placed, missing_groupings
                             names the data does not define, resources never placed, grouping
                             files that do not exist
  lobby_en / loading_en      the old texts
  seen_*, game_*             what the game placed in 2 games (game_* is what the descriptions use)
  check                      where script and game disagree; empty = they agree


Checked in game
---------------
Facts: every one of the 208 maps was generated twice (2 players, seeds 1 and 2), and the units on the
map at the start were listed and compared with the script facts.

  maps where script and game agree on everything      163
  maps with at least one difference (column "check")   45

The differences, by kind (a map can have several):
  21  natives in the script, no village in either game (lead 7).
  17  a fish, whale, hunt, herd or berry the script places that neither game showed: mostly placed
      only with more players, or in water a 2-player map does not have.
  16  a gaia animal or plant seen that the script does not place (Badger, ypIGCBird, Hen, Cow, ...):
      spawned by something else (triggers, treasures).
   4  natives: one nation of several missing in both games, or a village the tool could not read.
   1  Hawai'i's trade route without a trading post (lead 6).
The descriptions follow the game in all of these.

Two runs crashed (WOLethiopianhighlands seed 1, WOLFjord seed 2), both while generating the map,
after about 80 maps in the same game process. Run again in a fresh game, both were fine: we think
the long session, not the maps, caused them.

Texts: installed with apply_fix.py in a test copy and shown in game, English table, for 27 maps
across all regions and kinds (the 5 pilot maps and 22 more: river, island, desert, mountain, water,
no trade route, King of the Hill, the Moon, a random-terrain map). In every one the lobby rollover
and the loading text showed in full, with the colours and line breaks. At 1024x768, 8 maps with the
longest loading texts (Transcontinental, Archipelago, Silk Road, Marajo, New Zealand, Anatolia,
Hispaniola, Deccan): all fit the 12-line box. In Spanish, 5 maps at 1920x1080 and 2 at 1024x768: the
same. Of the 208 loading texts in English, 82 keep one sentence of the story, 89 two and 37 three;
54 lose the author credit (it stays in the lobby) and 3 the "Sea" line.

Seen on the way: on 4 of the 5 pilot maps (Hawai'i, Atacama, Rockies, Alps) the OLD lobby text, a
string ID such as details="28829", did not open any rollover in our tests (both languages), while the
old literal texts and all the new IDs did. We did not look into why.


Media
-----
All in English unless the name ends in "-es" (Spanish, as a check). The lobby is the skirmish setup
with the mouse on the minimap; the loading screen is the screen while the map loads.

The pilot, before and after (1920x1080):
  Irrawaddy River (DansilIrrawaddyRiver):
      DansilIrrawaddyRiver-lobby-before.jpg
      DansilIrrawaddyRiver-lobby-after.jpg
      DansilIrrawaddyRiver-loading-before.jpg
      DansilIrrawaddyRiver-loading-after.jpg
  Hawai'i (WOLhawaii):
      WOLhawaii-lobby-before.jpg
      WOLhawaii-lobby-after.jpg
      WOLhawaii-loading-before.jpg
      WOLhawaii-loading-after.jpg
  Atacama (atacama):
      atacama-lobby-before.jpg
      atacama-lobby-after.jpg
      atacama-loading-before.jpg
      atacama-loading-after.jpg
  Rockies (rockies):
      rockies-lobby-before.jpg
      rockies-lobby-after.jpg
      rockies-loading-before.jpg
      rockies-loading-after.jpg
  Lrg Alps (WOLAlps):
      WOLAlps-lobby-before.jpg
      WOLAlps-lobby-after.jpg
      WOLAlps-loading-before.jpg
      WOLAlps-loading-after.jpg

The re-test sample after the change (1920x1080), across regions and map types:
  Amazonia (amazonia):
      amazonia-lobby-after.jpg
      amazonia-loading-after.jpg
  Anatolia (anatolia):
      anatolia-lobby-after.jpg
      anatolia-loading-after.jpg
  Arabia (Arabia):
      Arabia-lobby-after.jpg
      Arabia-loading-after.jpg
  Ceylon (Ceylon):
      Ceylon-lobby-after.jpg
      Ceylon-loading-after.jpg
  Deccan (deccan):
      deccan-lobby-after.jpg
      deccan-loading-after.jpg
  Gold Coast (Gold Coast):
      Gold Coast-lobby-after.jpg
      Gold Coast-loading-after.jpg
  Great Lakes (great lakes):
      great lakes-lobby-after.jpg
      great lakes-loading-after.jpg
  Hispaniola (Hispaniola):
      Hispaniola-lobby-after.jpg
      Hispaniola-loading-after.jpg
  Honshu (honshu):
      honshu-lobby-after.jpg
      honshu-loading-after.jpg
  Mongolia (mongolia):
      mongolia-lobby-after.jpg
      mongolia-loading-after.jpg
  Pampas (pampas):
      pampas-lobby-after.jpg
      pampas-loading-after.jpg
  Texas (texas):
      texas-lobby-after.jpg
      texas-loading-after.jpg
  Transcontinental (Transcontinental TAD):
      Transcontinental TAD-lobby-after.jpg
      Transcontinental TAD-loading-after.jpg
  Lrg Australia (WOLaustralia):
      WOLaustralia-lobby-after.jpg
      WOLaustralia-loading-after.jpg
  British Isles (WOLbritishislands):
      WOLbritishislands-lobby-after.jpg
      WOLbritishislands-loading-after.jpg
  Lrg Congo (WOLcongo):
      WOLcongo-lobby-after.jpg
      WOLcongo-loading-after.jpg
  The Moon (WOLmoon):
      WOLmoon-lobby-after.jpg
      WOLmoon-loading-after.jpg
  Lrg Sahara (WOLsahara):
      WOLsahara-lobby-after.jpg
      WOLsahara-loading-after.jpg
  Tahiti (WolTahiti):
      WolTahiti-lobby-after.jpg
      WolTahiti-loading-after.jpg
  Tuscany (WOLtuscany):
      WOLtuscany-lobby-after.jpg
      WOLtuscany-loading-after.jpg
  Yukon (yukon):
      yukon-lobby-after.jpg
      yukon-loading-after.jpg
  Yungas (Yungas):
      Yungas-lobby-after.jpg
      Yungas-loading-after.jpg

At 1024x768 (the smallest loading box):
  Anatolia (anatolia):
      anatolia-lobby-after-768.jpg
      anatolia-loading-after-768.jpg
  Deccan (deccan):
      deccan-lobby-after-768.jpg
      deccan-loading-after-768.jpg
  Hispaniola (Hispaniola):
      Hispaniola-lobby-after-768.jpg
      Hispaniola-loading-after-768.jpg
  Lrg Marajo (marajo):
      marajo-lobby-after-768.jpg
      marajo-loading-after-768.jpg
  Lrg Silk Road (silkRoadLarge):
      silkRoadLarge-lobby-after-768.jpg
      silkRoadLarge-loading-after-768.jpg
  Archipelago (Team Archipelago Asian):
      Team Archipelago Asian-lobby-after-768.jpg
      Team Archipelago Asian-loading-after-768.jpg
  Transcontinental (Transcontinental TAD):
      Transcontinental TAD-lobby-after-768.jpg
      Transcontinental TAD-loading-after-768.jpg
  New Zealand (WOLnewzealand):
      WOLnewzealand-lobby-after-768.jpg
      WOLnewzealand-loading-after-768.jpg

Spanish checks:
  Anatolia (anatolia):
      anatolia-lobby-after-es.jpg
      anatolia-loading-after-es.jpg
  Honshu (honshu):
      honshu-lobby-after-es.jpg
      honshu-loading-after-es.jpg
  Rockies (rockies):
      rockies-lobby-after-es.jpg
      rockies-loading-after-es.jpg
  Lrg Congo (WOLcongo):
      WOLcongo-lobby-after-es.jpg
      WOLcongo-loading-after-es.jpg
  Tahiti (WolTahiti):
      WolTahiti-lobby-after-es.jpg
      WolTahiti-loading-after-es.jpg
  Lrg Marajo (marajo):
      marajo-lobby-after-768-es.jpg
      marajo-loading-after-768-es.jpg
  Lrg Silk Road (silkRoadLarge):
      silkRoadLarge-lobby-after-768-es.jpg
      silkRoadLarge-loading-after-768-es.jpg
  The pilot's old texts in Spanish: atacama-lobby-before-es.jpg / -loading-before-es.jpg, DansilIrrawaddyRiver-lobby-before-es.jpg / -loading-before-es.jpg, rockies-lobby-before-es.jpg / -loading-before-es.jpg, WOLAlps-lobby-before-es.jpg / -loading-before-es.jpg, WOLhawaii-lobby-before-es.jpg / -loading-before-es.jpg

Also: format-test-lobby.jpg (colour tag, line breaks, long text in the rollover) and
format-test-loading.jpg (the loading box cuts the text after 15 lines at 1920x1080).


Applying it
-----------
    python apply_fix.py "<WoL folder>"            (backs up every file it changes first)
    python apply_fix.py "<WoL folder>" --restore  (puts the backups back)
    python apply_fix.py "<WoL folder>" --out <folder>   (writes the changed files there instead)

It adds or replaces the strings in translations\_originals\stringtabley.xml (English),
translations\ES-LA\stringtabley.xml (Spanish) and data\stringtabley.xml (in whichever language that
file holds), and sets details="<ID>" and loadDetails="<ID>" in every map's .xml, removing its literal
detailsText / loadDetailsText (also the misspelt ones). The RM4\ folder here holds the same .xml files
already changed, if you prefer to copy them.

To change a text: edit texts.csv (or add a correction column such as natives_en), then run
    python make_descriptions.py
and apply again.
