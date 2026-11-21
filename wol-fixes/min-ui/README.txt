Minimized UI with all the information (WoL request #67)
=======================================================

What it does
------------
With the DLL key minUIStats, the minimized in-game UI (optionminimizedui) shows what the big UI shows,
and more, in a symmetric layout that keeps the top band for the unit portraits of the selection:

- over the unit's portrait: its cost (each resource's icon and amount), then its population (the game's
  house); four costs take both lines, two and two (a unit with four costs has no population);
- right of the player's name, the mirror block: line of sight (an eye) and the live speed (a winged
  boot; with techs, snares and auras), then the train time (an hourglass) and the garrison (a door);
- under the unit's name: what the unit is doing or what acts on it ("Done in 0:12", "Builds 1.00/s",
  "Regen 1/s", "Overheal +50", "Poison 3 x 8s", "Aura pays 0.10 (wood)/s");
- hit points as the word ("Hitpoints: 100/100", the word from the string table, so it follows the
  player's language) and resists with a shield, in the original places;
- every attack row gets its rate of fire right after its damage, with a stopwatch, then, when the attack
  fires more than one projectile before its reload (NumberOfShots x numberprojectiles, as the tactics write
  them), that number with a revolver's cylinder:
  "Ranged ATK:  11 (ranged) 3.50 (stopwatch) 4 (cylinder) 1 (area) 14 (range), 1.5x (...), 1.25x (...)";
  the multipliers without the zeros at their end (with the DLL's multiplierDecimals they have two decimals),
  and the tooltip of each attack row: the game's own lines plus "Rate of fire: 3.50s" and
  "4 projectiles" (version 7);
- the attack rows the minimized UI had no room for (the 4th attack on, Gatherers, Group Health), and the
  attacks the big UI itself has no room for (it stops at 9 rows);
- only the attacks the unit can use: an ability's attack (Crack Shot, Sharpshooter, Swashbuckler, ...)
  shows only while one of the unit's abilities gives it (abilities.xml: its tech is active and its age is
  the player's). The big UI lists every attack of the tactics file, usable or not; the minimized one with
  the key does not;
- the armor of buildings; with the DLL's multiarmor, every armor of the unit
  ("30% (hand)  20% (ranged)  10% (siege)"; the armor is a percent stuck to the value since version 7);
- more you can switch on in minuirows.xml (commented rows): minimum range, area, build points and
  limit, bounty, lifespan left, what a mine or animal holds, the gather rate, the random price range,
  the cards sent per age, base speed, armor, veterancy rank;
- 30 texts for any formatText gadget, one per item: {uhcSpeed}, {uhcLOS}, {uhcROF}, {uhcCost}, ...
  (the list is at the top of minuirows.xml).

The big UI does not change. Without the key the proposed file shows WoL's panel as it is today (only the
two names are narrower): media\minUIStats-v3-keyoff-*.jpg.

The layout (1024 x 768 layout units; the panel is x 342..700, its centre x 521)
----------------------------------------------------------------------------------
    y 631..667   the top band: ONLY the unit portraits of the selection (the game centres them in
                 buttonArea, 369..669, as in WoL's current file). Nothing of the key is in the band.
    y 669..697   two mirrored blocks of two lines, on the same baselines, text centred in each:
                   left, over the portrait (344..410):   cost / population
                   right, the mirror (632..698):          line of sight + speed / train time + garrison
                 between them: the unit's name (412..516) and the player's name (526..630), the same
                 width either side of the centre
    y 688..702   under the unit's name: uhcRow2 (Done in, Builds, Regen, Overheal, Poison, Aura). Under the
                 player's name nothing: a long name ("Otto Von Bismarck (Germans)") takes two lines there.
    y 700..714   "Hitpoints:" at x 410 | (shield) resists at x 583: the key's own gadgets over the
                 original ones, which it hides while its own show (<replace> in minuirows.xml)
    y 714..767   the attack rows in the panel's own two columns: x 410 (the original three, written by the
                 key so they get the ROF and the filter) and x 583 (the 4th on: uhcRow5, uhcRow3, uhcRow4,
                 on the same lines and baselines as the first three)
    under the portrait: the health bar (green, yellow, red), as in WoL's file.

    Mirrored around x 521: the two blocks, the two names. Not mirrored, and why:
    - the row under the unit's name has no twin under the player's name: that space is the second line of
      a long player name (seen in game: AI and player names wrap);
    - the stats keep the panel's own two columns (x 410 and x 583): the original attack rows start at the
      portrait's edge, and long ones reach x ~570..600;
    - the portraits centre on x 519 (WoL's buttonArea, kept), 2 units (4 px at 1920) left of the panel's
      centre.

    Long rows: an original attack row too long for its column (a Villero's ranged row with five
    multipliers) runs on into the right column, so the right-column gadget on that line stays empty and
    the rows go on in the next one; a right-column row too long for it (a Spanish "Tirador de elite", the
    "Anti-artillery Crackshot Attack") shows its name and damage, with the whole row in its tooltip.

    Pictures: media\minui-preview-proposed.png (every rectangle, the two centre lines drawn),
    media\minui-preview-wol.png (WoL's current file), media\minui-preview-proposed-old.png (the first
    proposal, whose buttonArea put the portraits left of the centre).

Icons (all at the size of the panel's own damage type icons, "(10)"; each row has a tooltip with its word)
------------------------------------------------------------------------------------------------------------
    rate of fire      a stopwatch      drawn: art\ui\ingame\stat_icon_rof.ddt (in this pack)
    train time        an hourglass     drawn: art\ui\ingame\stat_icon_traintime.ddt
    resists           a shield         drawn: art\ui\ingame\stat_icon_armor.ddt
    line of sight     an eye           drawn: art\ui\ingame\stat_icon_los.ddt. The game's spy eye is
                                       ui\ingame\stat_icon_informers, but WoL's own copy of it is a dove
    speed             a winged boot    drawn: art\ui\ingame\stat_icon_speed.ddt, a riding boot with a
                                       white wing and two motion lines (JTMaston: "a boot with wings")
    projectiles       a revolver's     drawn: art\ui\ingame\stat_icon_projectiles.ddt (2026-11-18), the
                      cylinder         cylinder seen from the chambers' side (JTMaston's idea)
    hit points        the word         "Hitpoints" from the string table (string 68852), in the yellow of
                                       the panel's labels (Dr.Maxy and JTMaston: a word, not a heart)
    population        a house          the game's: ui\ingame\stat_icon_building (WoL's own copy), as
                                       JTMaston asked; our drawn house is no longer in the pack
    garrison          a door, an arrow the game's: ui\cursors\cursor_garrison (the garrison cursor)
    costs             resource icons   the game's, as the resource bar shows them
    The drawn icons (version 4, 2026-11-18) are made like WoL's own stat icons (stat_icon_ranged, _range,
    _attack, _building): 32x32 uncompressed BGRA, one level, solid shapes, hard edges (each pixel fully
    shown or fully transparent), a black line around each part and a 2-pixel black outline; round parts
    are drawn wider than tall, since the panel squeezes icons sideways. Made with aoe3-blender-tools
    (tools/make_stat_icon.py --style bold); no pixel comes from another game. The first set (16x16
    DXT3, 1-pixel strokes, soft edges) came out thin and blurred at the panel's size: final\
    minUIStats-v4-icons-x4.png shows both, enlarged from the game.

Files
-----
proposed-uiunitselectionmin.xml
    The original minimized selection panel (uiunitselectionmin.xml from Data3.bar) with WoL's values
    for the original gadgets it changed, and the key's gadgets at the top level of
    unitselectionpanel-unit (never inside a gadget the game shows or hides):
      unitselectionpanel-uhcCost, -uhcPop                  over the portrait
      unitselectionpanel-uhcSight, -uhcTrainGarrison       right of the player's name
      unitselectionpanel-uhcRow2                           under the unit's name
      unitselectionpanel-uhcHitpoints, -uhcResists         over the original hit points and resists
      unitselectionpanel-uhcRow3, -uhcRow4, -uhcRow5       the attack rows past the third (x 583)

minuirows.xml
    The data file: which gadget shows which items, with which icons, labels and tooltips; which original
    gadgets the key's rows replace (<replace>); the attack rows (<bigPanelRows>: stockRows="take" writes
    the original three too, rofIcon adds the ROF). It goes in data\uhc\. The comments at its top list
    every item and option. No new DLL is needed to change any of it.

art\ui\ingame\*.ddt
    The six drawn icons (stopwatch, hourglass, shield, eye, winged boot, cylinder). They go in
    art\ui\ingame\ of the mod (version 4: stat_icon_hitpoints.ddt and stat_icon_pop.ddt are no longer used;
    delete them if version 3 put them there).

art\ui\ingame\stat_icon_heavy_infantry.ddt, stat_icon_infantry.ddt, art\WoL\ui\ingame\staticons\
stat_icon_standing_unit.ddt and stat_icon_ranged.ddt (version 7)
    Three unit type icons of the multipliers, redrawn at WoL's request, at the paths the panels draw (they replace
    WoL's files; no data changes): Line (AbstractHeavyInfantry), an infantryman in a shako with a blue coat;
    Standing (AbstractInfantry), the same soldier with a red coat (in stat_icon_infantry.ddt, which the panels draw
    for AbstractInfantry, and in the staticons file WoL's attackTypeIcons line names); Maneuver
    (AbstractRangedCavalry), a winged arrow. 32x32 uncompressed BGRA, one level, soft edges and shading as WoL's
    own icons, a thin dark outline; drawn by aoe3-blender-tools' make_type_icon.py (no pixel from another game).
    The other unit type icons stay WoL's own.

review\stat_icon_ranged-winged-bullet.ddt
    The other Maneuver icon drawn in version 7, a winged bullet, not chosen (the arrow reads better at the
    panel's size). To use it, copy it over art\WoL\ui\ingame\staticons\stat_icon_ranged.ddt.
    icons-v7-review.png: the old and new icons side by side, x8 and at real size.

apply_fix.py
    Installs the pack in a WoL folder and keeps the files it replaces (see Install).

note-for-drmaxy.txt
    What was decided and why (for information).

optional\uiunitstatpanel3.xml
    Optional, not needed by the key: the original big-UI stat panel (9 rows), from Data3.bar. WoL's own
    file has the 5-row minimized one, so its big UI shows only one attack row.

Install
-------
    python apply_fix.py <WoL folder>              steps 1 to 4 below; the files it replaces go to
                                                  <WoL folder>\min-ui-backup\ first
    python apply_fix.py <WoL folder> --restore    puts them back and deletes the files it added
    python apply_fix.py <WoL folder> --check      says what is applied
By hand:
1. Copy proposed-uiunitselectionmin.xml to data\uiunitselectionmin.xml (keep a copy of yours).
2. Copy minuirows.xml to data\uhc\minuirows.xml.
3. Copy the art folder's files to the same paths under art\ (keep a copy of your three unit type icons).
4. Add the line   minUIStats   to Startup\wol.cfg.
5. Keep optionminimizedui on (WoL's profile has it on).

The original gadgets: WoL's current file against this one
-----------------------------------------------------------
Compared gadget by gadget (name, parent, every attribute) with C:\WoL-Test\data\uiunitselectionmin.xml:
    showCommands, showStats       WoL's tab texture (foreground, texturecoords): kept.
    buttonArea                    WoL's 369 697 669 666 (the portraits centre on x 519): kept. The first
                                  proposal had the original 369 632 607 666, which put the portraits
                                  left of the centre (Dr.Maxy's "the selection is no longer centred").
    unitHealthBarGreen/Yellow/Red WoL's (342 759 412 766, under the portrait): kept, and inside the unit's
                                  name as in WoL's file. Measured: elsewhere (in the panel, in the
                                  portrait) the minimized panel never shows them; inside the name they
                                  show with it. Their "Garrison" texts are left out (the right block).
    unitHitPointsLabel/Value,     WoL's, unchanged: the key's own gadgets with the icons lie over them
    unitResistsLabel/Value        and the key hides them while its own show.
    unitTypeName                  412 650 516 714 (was 348..516): the column over the portrait holds the
                                  cost; the name keeps the width of the player's name.
    unitPlayerName                526 650 630 714 (was 520..700): the mirror of the unit's name; a long
                                  name takes its second line, under it.
    Nesting                       WoL's file nests most of the panel in unitTypeName (its line 40 has no
                                  "/>"); here every original gadget has the original parent but the bars.
    WoL's own gadgets             TrainTimeinfo (an empty text with a "TrainTime:" tooltip),
                                  unitanything (empty), SettlerCountDialog-pop-icon (LOS), TrainTime
                                  (Train Points), unitSpeedValue (Speed, inside the resists value, so
                                  hidden with it), unitResourceValue2 (empty) and the three "Garrison"
                                  texts: left out, the key's rows show each of these.
    Every other original gadget (the portrait, the resource and rate rows, StackLabel0..2, the portrait
    count, the stack buttons) is the same in both files.

Notes
-----
- A row is hidden when its item does not apply to the selected unit (no garrison, speed 0, no train
  time on a building).
- With several units selected the rows describe the first one, as the game's own panel does.
- Mixed groups: the game shows one portrait per unit type in the top band, centred, at most nine (a 10th
  type gets no portrait). Nothing of the key is in that band, so no row moves or hides for the
  portraits. (The rule "a row a portrait covers is hidden" is still in the DLL for layouts that put rows
  in the band.)
- Many attacks: the original three rows, then uhcRow3, uhcRow4 and uhcRow5 (next to them, x 583). When
  there are more rows than gadgets, the last one shows the rest as names and damage, then "+2 more"; its
  tooltip lists them all. With the ability filter this did not happen in the tests.
- uhcRow5 shares its line with the resource held and the AutoGather rate (a factory, a bank, a sawmill):
  while either shows, uhcRow5 stays empty (minuirows.xml, the two <avoid> lines).
- With WoL's own uhc.dll (its multiarmor writes the resists text) the key leaves the resists to it: the
  original "Resists:" row shows WoL's text, and a building shows none (the first version showed
  "Resists: 0 (null)" on a Factory there).

Tested on 2026-11-17 (single player, WoL, 1920 x 1080, the panel at native pixels with the health bar)
-------------------------------------------------------------------------------------------------------
Version 6 (2026-11-20): the tooltip says "N projectiles", no parentheses around icons (ours and the game's lines), WoL's
own unit type icons: final\README.txt and ..\note-for-team-v6.txt.
Version 5 (2026-11-19): projectiles from the data, two-decimal multipliers, WoL's attackTypeIcons types, tooltips,
1024x768 rows ending in "(+N)", the hit points gadget one line high (it covered the first attack row's tooltip):
final\README.txt and ..\note-for-team-v5.txt.
Version 4 (2026-11-18): every scene below was taken again with the version 4 icons, the word "Hitpoints", the
game's house and the projectiles, plus the new scenes (three and four costs, projectiles, Spanish, 1024x768,
WoL's uhc.dll beside our dinput8.dll): final\README.txt has that pass/fail table and the pictures. The table
below is version 3's, with its pictures in media\.

Each scene: (a) the rectangles in media\minui-preview-proposed.png, (b) the screenshot. "Fine" = no text
over another text, nothing cut, nothing in the portrait band, the health bar shown.

    Scene                                            Picture (media\minUIStats-...)          Result
    One Musketeer                                    v3-1type.jpg                            fine
    A Barracks; a Factory (trickle row); a Bank      v3-building, -factory, -bank            fine
    2, 5 and 9 unit types                            v3-2types, -5types, -9types             fine
    Menelik II, damaged: Regen; of its five ability  v3-explorer                             fine
      attacks only Sharpshooter (no tech needed)
    A Presidial explorer: Sharpshooter (its own      v3-presidial                            fine
      ability), no Crack Shot (JTMaston)
    The Chief (WOLcartographer) before / after       v3-cartographer-before, -after          fine
      HCSteelCrown: Anti-artillery Crackshot only
      after the card (long name: name and damage)
    Wachtmeester with 3 armors (test data)           v3-wachtmeester                         fine
    A Grognard; a Settler; a Villero (long rows:     v3-grenadier, -settler, -villero        fine (the
      the Villero's ranged row runs on, the right                                            right gadget
      gadget of its line stays empty)                                                        on its line
                                                                                             left empty)
    A long unit name (Husar de la Muerte)            v3-longname                             fine
    Overheal (test data: InitialHitpoints 100)       v3-overheal                             fine
    A poisoned Halberdier (damageOverTime, the       v3-poison                               fine
      Aenna's poison arrows of dot_testdata --wol)
    Our aura key (unitResourceAuras): a Sawmill      v3-aura-sawmill, -aura-tree             fine
      "Aura pays 0.10/s" and its "Wood 1.75/s" row;
      a tree "Aura -0.05/s" and its wood held
    A building going up (AI skirmish): "Done in      v3-construction-site, -builder          fine (two-
      0:12"; its builder "Builds 1.00/s"; the AI's                                           line player
      long name "Otto Von Bismarck (Germans)"                                                name; v4:
      (version 4: final\minUIStats-v4-construction-*; the v3 pictures are removed)          retaken)
    Ships: a Caravel, a Frigate (2 armors), with     v3-ship-caravel, -ship-frigate          fine
      the train time and garrison 0 / 50
    WoL.dll v1.33 loaded (preloadDll, its            v3-woldll-factory                       fine
      trickleDisplay patches 0x69920E / 0x699227
      checked in memory): a Factory
    Spanish strings (WoL's ES-LA string table):      v3-spanish-explorer, -villero,          fine (long
      Menelik II, a Villero, the Chief                 -cartographer                         names short)
    Every key of the cfg template on (114 applied,   v3-allkeys-presidial, -allkeys-villero  fine
      0 failed)
    WoL's uhc.dll (multiarmor) + our dinput8.dll:    v3-woluhcdll-factory, -wachtmeester     fine (no
      a Factory, a Wachtmeester                                                             "(null)")
    Key off, this layout                             v3-keyoff-1type, -wachtmeester,         fine (WoL's
                                                       -villero                              panel)
    WoL's current file, key off (the reference)      wolcurrent-*.jpg                        reference
    Side by side, WoL's current | proposed           v3-vs-wol-units, -groups, -more         -
    The drawn population icon (2026-11-18, in        v3-popicon-unit, -building,             fine (the
      C:\WoL-Test with WoL's uhc.dll + our             -group; v3-popicon-vs-old             house reads
      dinput8.dll, English): one Musketeer, a                                                as a house
      Barracks (no population row), six types                                                at 12 px)
    Not filmed: a villager of the player gathering. Console orders (uiWorkAtPointer) only moved the
    villagers, in a scenario and in a skirmish, and the game hides the resource carried by another
    player's villager. The rows a gatherer uses are the stock resource and rate rows (filmed on the
    Factory, the Sawmill, the tree) and the right block (filmed on every unit).
    Performance (perfprobe.py, 45 s, a Presidial selected, other games running): key on 387 fps,
    update 0.21 ms, render 2.36 ms; key off with this layout 393 fps, 0.21 ms, 2.33 ms: noise.

Media
-----
In media\ (JPG pictures of the panel at native pixels, with the health bar; PNG previews).
    minUIStats-v3-*.jpg               the proposed layout (the table above)
    minUIStats-wolcurrent-*.jpg       WoL's current file, key off, the same scenes
    minUIStats-v3-vs-wol-*.jpg        both side by side
    minui-icons.png                   the icons and where each comes from, with the speed variants and
                                      the replaced population icon (each with its look in game)
    minUIStats-v3-popicon-vs-old.jpg  the population icon, before (WoL's stat_icon_building) and now
                                      (stat_icon_pop): one Musketeer, a Barracks, a group of six types
    minUIStats-v3-popicon-*.jpg       the same scenes with the new icon (unit, building, group)
    minui-preview-proposed.png        the proposed layout's rectangles, new ones in yellow, the centre lines
    minui-preview-wol.png             WoL's current file's rectangles
    minui-preview-proposed-old.png    the first proposal's rectangles (portraits left of the centre)
    minui-preview-stock.png           the original minimized layout's rectangles
    minui-shot-min-*.png, minui-shot-big-*.png   WoL's UI before the key: a unit, a building, a villager
    minUIStats-test-hero-big.png      Menelik II in the big UI (it lists every attack, usable or not)
The videos of the first proposal (2026-11-17) were removed on 2026-11-21: they showed a layout that version 7 has
replaced. Version 7's pictures are in final\ (minUIStats-v7-*.jpg).
