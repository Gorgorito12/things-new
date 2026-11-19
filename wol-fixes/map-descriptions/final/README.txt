Map descriptions v2: final screenshots, for review
==================================================

These are the screenshots of the v2 map descriptions, taken in game with the pack installed. All 208
random maps have a v2 text in English and Spanish (..\descriptions.csv, ..\strings-en.xml,
..\strings-es.xml). This folder shows 36 of them. Start with the overview sheets 00-overview-1.jpg to
00-overview-9.jpg: each one shows up to 6 maps, with the lobby rollover on the left and the loading text on
the right.

Taken on 2026-11-18 in Wars of Liberty with the minimized UI on, 2 players (the second an AI with a
European civ).


What v2 is, and which request each change answers
-------------------------------------------------
JTMaston reviewed the first version (v1) and asked for these changes. His points are quoted as they
were passed on to us:

1. "The +X random are mercenaries, not outlaws: remove that string."
   Done. The Outlaws line now lists only the map's fixed outlaws. These are the outlaws of the
   mapspecifictechs.xml block that the game really uses. The random draws are gone. 9 maps have no
   fixed outlaws, and their line says "Outlaws: none" (Hawai'i and Tahiti in these shots).
2. "Keep the relevant data of the original descriptions."
   Done. Every fact of the old texts is listed in ..\kept-from-original.csv. The new description keeps
   the gameplay rules and the variants, for example: the number of trade routes, the terrain
   patterns or skins drawn each game, what replaces a missing resource, and what a native site gives.
3. "A horizontal line between outlaws and hunts, between the description and the region, and before
   the map size and the creator."
   Done, in both places. It is a thin 1-pixel line that costs about a third of a text row.
4. "Colour the keys: hunts reddish or brown, mines gold, berries a green that is not too saturated,
   the rest whiter than the text and never yellow; bold if possible."
   Done. All keys are bold. Hunts are reddish brown, Mines gold, Berries soft green, and all other
   keys white. The yellow of v1 is gone.
5. "Keys in the plural, except Region, Trade route and King of the Hill."
   Done: Hunts, Herds, Mines, Berries, Fish. Fish was "Sea" in v1. In Spanish: Animales de caza,
   Rebaños, Minas, Bayas, Peces.
6. "The map size after the resources."
   Done. The Map size line gives metres per side for 2, 4 and 8 players. It reads "X x Z" on a
   rectangular map and "a-b" where the script picks the size at random. The sizes were checked in
   game on 3 maps.
7. "The creator, if any, always at the bottom."
   Done. The creator is the last line, after its own horizontal line, and is never cut. Maps without a
   known creator have no creator line, so Map size is their last line (Acre, Hawai'i, The Moon, ...).
   Maps with more than one creator show "Creators: A, B" (Black Forest, ESOC Fertile Crescent, Blue Nile).

These changes make the loading text taller, so the pack also makes the loading screen's text box
taller (data\uirmsetup.xml) and moves the player list below it. With 8 players, the list still fits
below the box, at 1920x1080 and at 1024x768 (acre-loading-8players*.jpg).


How to install
--------------
    python apply_fix.py "<Wars of Liberty folder>"            (backs up every file it changes first)
    python apply_fix.py "<Wars of Liberty folder>" --restore  (puts the backups back)

The script is in the folder above this one. It writes:
- the strings into the three string tables;
- details / loadDetails into the 208 RM4\*.xml files;
- the two font entries MapDescTipKey and MapDescRule 4 into FONTS\fonts3.xml;
- data\uirmsetup.xml, the taller loading box.
The game reads the string tables only when it starts. Details are in ..\README.txt ("Applying it").


The files
---------
  <map>-lobby.jpg, <map>-loading.jpg            English, 1920x1080
  <map>-lobby-768.jpg, <map>-loading-768.jpg    English, 1024x768 (the smallest loading box)
  <map>-lobby-es.jpg, <map>-loading-es.jpg      Spanish (the ES-LA table), 1920x1080
  <map>-lobby-768-es.jpg, -loading-768-es.jpg   Spanish, 1024x768 (Transcontinental, the longest
                                                Spanish text)
  acre-loading-8players.jpg, acre-loading-8players-768.jpg
                                                8 players: the player list below the taller box
  00-overview-1.jpg ... 00-overview-6.jpg       the 36 maps in English at 1920x1080
  00-overview-7.jpg, 00-overview-8.jpg          the 10 maps at 1024x768
  00-overview-9.jpg                             the Spanish captures
The lobby picture is the right-hand side of the skirmish setup, with the mouse on the minimap. The
loading picture is the whole screen while the map loads.


What was checked on every capture
---------------------------------
Each capture was cropped and checked by eye, the lobby rollover and the loading text alike:
  lines      the three horizontal lines are continuous;
  keys       the keys are bold and coloured (Hunts reddish brown, Mines gold, Berries green, the
             other keys white);
  whole      nothing is cut off: the last line shows in full, inside the rollover or the box;
  creator    the creator is the last line ("n/a": the map has no known creator, so the map size is
             the last line);
  no random  no "+X random" text after the outlaws.

Result: every capture passed every check, and nothing in the pack had to be changed.

Three captures did not work on the first try, and the capture script took them again by itself.
Each time, the game did not start the selected map, or the rollover did not open:
  Hawai'i and Barrier Ridge at 1920x1080, Archipelago at 1024x768.
The second try of each is the one shown here.

What we saw that is not a fault:
- At 1024x768 the first fact row of the loading text ("Region: ... | Trade route: ... | King of the
  Hill: ...") wraps when the region name is long. On many maps it breaks inside the key, as "King of
  the" / "Hill: Yes". Everything still shows, and the box keeps room to spare.
  To avoid the break, King of the Hill could go on a row of its own, at the cost of one row. We did
  not join the key's words with no-break spaces: in the loading font a no-break space is wider than a
  space, so the key would look spaced out.
- The 1920x1080 lobby rollover is taller than v1's. On the longest texts it covers the Game Speed
  buttons while the mouse is on the minimap. It closes when the mouse leaves.

  map                       set      screen   lines  keys   whole  creator  no random
  acre                      EN 1920  both     pass   pass   pass   n/a      pass
  appalachians              EN 1920  both     pass   pass   pass   pass     pass
  dansilRed Beach           EN 1920  both     pass   pass   pass   pass     pass
  ESOC_Adirondacks          EN 1920  both     pass   pass   pass   pass     pass
  DansilAlaska              EN 1920  both     pass   pass   pass   pass     pass
  WOLhawaii                 EN 1920  both     pass   pass   pass   n/a      pass
  Baja California TWC 01    EN 1920  both     pass   pass   pass   pass     pass
  Barrier Ridge TWC         EN 1920  both     pass   pass   pass   pass     pass
  Team Archipelago Asian    EN 1920  both     pass   pass   pass   pass     pass
  Shangra La                EN 1920  both     pass   pass   pass   pass     pass
  GANWakhan                 EN 1920  both     pass   pass   pass   pass     pass
  WOLvandiemansland         EN 1920  both     pass   pass   pass   pass     pass
  dansil_Westernterritory   EN 1920  both     pass   pass   pass   pass     pass
  ESOC_Thar Desert          EN 1920  both     pass   pass   pass   pass     pass
  amazonia                  EN 1920  both     pass   pass   pass   n/a      pass
  Orinoco                   EN 1920  both     pass   pass   pass   n/a      pass
  sertao                    EN 1920  both     pass   pass   pass   n/a      pass
  texas                     EN 1920  both     pass   pass   pass   n/a      pass
  WOLcongo                  EN 1920  both     pass   pass   pass   pass     pass
  WOLScandinavia            EN 1920  both     pass   pass   pass   n/a      pass
  WOLnzwc                   EN 1920  both     pass   pass   pass   n/a      pass
  WolTahiti                 EN 1920  both     pass   pass   pass   n/a      pass
  WOLblackforest            EN 1920  both     pass   pass   pass   pass     pass
  ESOC_Fertile Crescent     EN 1920  both     pass   pass   pass   pass     pass
  Desert Flood              EN 1920  both     pass   pass   pass   pass     pass
  galapagos                 EN 1920  both     pass   pass   pass   n/a      pass
  WOLmoon                   EN 1920  both     pass   pass   pass   n/a      pass
  Transcontinental TAD      EN 1920  both     pass   pass   pass   pass     pass
  Delta TWC                 EN 1920  both     pass   pass   pass   pass     pass
  GANNiger                  EN 1920  both     pass   pass   pass   pass     pass
  dansil Manicouagan Basin  EN 1920  both     pass   pass   pass   pass     pass
  WOLsahara                 EN 1920  both     pass   pass   pass   n/a      pass
  Arabia                    EN 1920  both     pass   pass   pass   pass     pass
  Ceylon                    EN 1920  both     pass   pass   pass   n/a      pass
  WOLAlps                   EN 1920  both     pass   pass   pass   n/a      pass
  honshu                    EN 1920  both     pass   pass   pass   n/a      pass
  Baja California TWC 01    EN 1024  both     pass   pass   pass   pass     pass
  Barrier Ridge TWC         EN 1024  both     pass   pass   pass   pass     pass
  Team Archipelago Asian    EN 1024  both     pass   pass   pass   pass     pass
  Shangra La                EN 1024  both     pass   pass   pass   pass     pass
  GANWakhan                 EN 1024  both     pass   pass   pass   pass     pass
  WOLvandiemansland         EN 1024  both     pass   pass   pass   pass     pass
  dansil_Westernterritory   EN 1024  both     pass   pass   pass   pass     pass
  ESOC_Thar Desert          EN 1024  both     pass   pass   pass   pass     pass
  acre                      EN 1024  both     pass   pass   pass   n/a      pass
  texas                     EN 1024  both     pass   pass   pass   n/a      pass
  Transcontinental TAD      ES 1920  both     pass   pass   pass   pass     pass
  Baja California TWC 01    ES 1920  both     pass   pass   pass   pass     pass
  WOLhawaii                 ES 1920  both     pass   pass   pass   n/a      pass
  Transcontinental TAD      ES 1024  both     pass   pass   pass   pass     pass
  acre, 8 players           EN 1920  loading  pass   pass   pass   n/a      pass
  acre, 8 players           EN 1024  loading  pass   pass   pass   n/a      pass


The maps shown (36)
-------------------
Why each map was picked:
- pilot: one of the 6 maps of the v2 pilot;
- tightest fit: one of the longest loading texts;
- facts changed: the v2 text corrects a fact of the v1 text.
Every region has at least 2 maps, except Space, which has only one map (The Moon).

  file name                  name in game             region               why
  acre                       Acre                     South America        pilot  [also 1024]
  appalachians               Appalachians             North America        pilot
  dansilRed Beach            Red Beach                Asia                 pilot
  ESOC_Adirondacks           ESOC Adirondacks         North America        pilot
  DansilAlaska               Alaska                   North America        pilot; rectangular
  WOLhawaii                  Hawai'i                  Oceania              pilot  [also ES]
  Baja California TWC 01     Lrg Cabos                North America        tightest fit; rectangular  [also 1024, ES]
  Barrier Ridge TWC          Barrier Ridge            Other                tightest fit; rectangular  [also 1024]
  Team Archipelago Asian     Archipelago              Asia                 tightest fit; rectangular  [also 1024]
  Shangra La                 Shangri-La               Asia                 tightest fit; rectangular  [also 1024]
  GANWakhan                  Lrg Wakhan               Asia                 tightest fit  [also 1024]
  WOLvandiemansland          Lrg Van Diemen's Land    Oceania              tightest fit  [also 1024]
  dansil_Westernterritory    Western Territory        Oceania              tightest fit; rectangular  [also 1024]
  ESOC_Thar Desert           ESOC Thar Desert         Indian Subcontinent  tightest fit  [also 1024]
  amazonia                   Amazonia                 South America        facts changed
  Orinoco                    Orinoco                  South America        facts changed
  sertao                     Sertao                   South America        facts changed
  texas                      Texas                    North America        facts changed  [also 1024]
  WOLcongo                   Lrg Congo                Africa               facts changed
  WOLScandinavia             Lrg Scandinavia          Europe               facts changed
  WOLnzwc                    Te Tai Poutini           Oceania              facts changed; rectangular
  WolTahiti                  Tahiti                   Oceania              facts changed; rectangular
  WOLblackforest             Black Forest             Europe               two creators
  ESOC_Fertile Crescent      ESOC Fertile Crescent    Middle East          two creators
  Desert Flood               Blue Nile                Africa               two creators; rectangular
  galapagos                  Galapagos                South America        no King of the Hill
  WOLmoon                    The Moon                 Space                Space
  Transcontinental TAD       Transcontinental         Other                long text; rectangular  [also ES]
  Delta TWC                  Lrg Delta                Other                long text
  GANNiger                   Lrg Niger River          Africa               long text; rectangular
  dansil Manicouagan Basin   Manicouagan Basin        North America        long text
  WOLsahara                  Lrg Sahara               Africa               King of the Hill added
  Arabia                     Arabia                   Middle East          creator from the .xs only
  Ceylon                     Ceylon                   Indian Subcontinent  region
  WOLAlps                    Lrg Alps                 Europe               region
  honshu                     Honshu                   Asia                 region

"[also 1024, ES]": that map is also shown at 1024x768 or in Spanish. Transcontinental is also shown in
Spanish at 1024x768.

The v1 screenshots that were in this folder are gone, replaced by this set. The v1 media, with the
old texts (before) and the v1 Spanish checks, stay in ..\media\, where ..\README.txt lists them.
