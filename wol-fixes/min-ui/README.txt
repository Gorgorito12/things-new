Minimized UI with all the information (WoL request #67)
=======================================================

What it does
------------
With the DLL key minUIStats, the minimized in-game UI (optionminimizedui) shows what the big UI shows,
and more, in a symmetric layout that keeps the top band for the unit portraits of the selection:

- over the unit's portrait: its cost (each resource's icon and amount) and its population (a house);
- right of the player's name, the mirror column: the train time (an hourglass) and the garrison;
- under the unit's name: what the unit is doing or what acts on it ("Done in 1:21", "Builds 1.50/s",
  "Regen 1/s", "Overheal +50", a running poison, "Aura +50% work");
- under the player's name: line of sight (an eye) and the live speed (a boot; with techs, snares, auras);
- the hit points and resists labels as icons (a heart, a shield); their values stay the game's;
- every attack row gets its rate of fire right after its damage, with a stopwatch:
  "Ranged ATK:  23 (ranged) 3 (stopwatch) 12 (range), 3x (cavalry)";
- the attack rows the minimized UI had no room for (the 4th attack on, Gatherers, Group Health), and the
  attacks the big UI itself has no room for (it stops at 9 rows);
- only the attacks the unit can use: an ability's attack (Crack Shot, Sharpshooter, Swashbuckler, ...)
  shows only while one of the unit's abilities gives it (abilities.xml: its tech is active and its age is
  the player's). The big UI lists every attack of the tactics file, usable or not; the minimized one with
  the key does not;
- the armor of buildings, in the original resists spot; with the DLL's multiarmor, every armor of the
  unit ("0.30 (hand)  0.20 (ranged)  0.10 (siege)");
- more you can switch on in minuirows.xml (commented rows): minimum range, area, build points and
  limit, bounty, lifespan left, what a mine or animal holds, the gather rate, the random price range,
  the cards sent per age, base speed, armor, veterancy rank;
- 30 texts for any formatText gadget, one per item: {uhcSpeed}, {uhcLOS}, {uhcROF}, {uhcCost}, ...
  (the list is at the top of minuirows.xml).

The big UI does not change. Without the key nothing changes.

The layout (1024 x 768 layout units; the panel is x 342..700, its centre x 521)
----------------------------------------------------------------------------------
    y 631..667   the top band: ONLY the unit portraits of the selection (the game centres them in
                 buttonArea, 369..669, as in WoL's current file). Nothing of the key is in the band.
    y 669..697   left column, over the portrait (342..412):  cost (line 1), population (line 2)
                 right column, the mirror (630..700):        train time (line 1), garrison (line 2)
                 between them: the unit's name (412..516) and the player's name (526..630), the
                 same width either side of the centre
    y 688..702   under the unit's name: uhcRow2 (Done in, Builds, Regen, Overheal, Poison, Aura)
                 under the player's name: uhcRow0 (line of sight, speed), both centred under their name
    y 700..714   (heart) hit points at x 410 | (shield) resists at x 583
    y 714..767   the attack rows, in the panel's own two columns: x 410 (the first three) and x 583
                 (the 4th on: uhcRow5, uhcRow3, uhcRow4, on the same lines as the first three)
    under the portrait: the health bar (green, yellow, red), as in WoL's file.

    Mirrored around x 521: the two columns (342..412 | 630..700), the two names (412..516 | 526..630) and
    the two rows under them. Text in each of these is centred, so both sides balance whatever the length.
    Not mirrored, on purpose: the stats table below keeps the panel's own two columns (x 410 and x 583),
    because the original attack rows start at the portrait's edge and the long ones (a Settler's or a
    Grognard's) reach x ~570; mirroring would put them into the second column. The portraits centre on
    x 519 (WoL's buttonArea), 2 units (4 px at 1920) left of the panel's centre: WoL's own value, kept.

    Pictures: media\minui-preview-proposed.png (every rectangle, the two centre lines drawn),
    media\minui-preview-wol.png (WoL's current file), media\minui-preview-proposed-old.png (the first
    proposal, whose buttonArea put the portraits left of the centre).

Icons (all at the size of the panel's own damage type icons, "(10)"; each row with an icon has a tooltip
with its word)
------------------------------------------------------------------------------------------------------
    rate of fire      a stopwatch      drawn: art\ui\ingame\stat_icon_rof.ddt (in this pack)
    train time        an hourglass     drawn: art\ui\ingame\stat_icon_traintime.ddt (in this pack)
    hit points        a heart          drawn: art\ui\ingame\stat_icon_hitpoints.ddt (in this pack)
    resists           a shield         drawn: art\ui\ingame\stat_icon_armor.ddt (in this pack)
    line of sight     an eye           drawn: art\ui\ingame\stat_icon_los.ddt (in this pack). The game's
                                       spy eye is ui\ingame\stat_icon_informers, but WoL's own copy of
                                       that file is a dove, so the eye is drawn
    population        a house          the game's: ui\ingame\stat_icon_building (WoL's own copy)
    speed             a boot           the game's: ui\ingame\stat_light_infantry (the light infantry boot)
    costs             resource icons   the game's, as the resource bar shows them
    The drawn icons are 16x16 DXT3 stat icons made with aoe3-blender-tools (tools/make_stat_icon.py);
    no pixel comes from another game. Sheet: media\minui-icons.png.

Files
-----
proposed-uiunitselectionmin.xml
    The original minimized selection panel (uiunitselectionmin.xml from Data3.bar) with WoL's values
    for the original gadgets it changed, the changes below, and the key's gadgets at the top level of
    unitselectionpanel-unit (never inside a gadget the game shows or hides):
      unitselectionpanel-uhcCost, -uhcPop                over the portrait
      unitselectionpanel-uhcTrainPoints, -uhcGarrison    right of the player's name
      unitselectionpanel-uhcRow2, -uhcRow0               under the unit's name, under the player's name
      unitselectionpanel-uhcRow3, -uhcRow4, -uhcRow5     the attack rows past the third (x 583)
    It needs the key: the hit points and resists labels are only as wide as their icon. With the key
    off, use your current file.

minuirows.xml
    The data file: which gadget shows which items, with which icons, labels and tooltips, for which
    unit types; the original labels that become icons (<stockLabel>); the attack rows (<bigPanelRows>:
    stockRows="take" writes the original three too, rofIcon adds the ROF). It goes in data\uhc\. The
    comments at its top list every item and option. No new DLL is needed to change any of it.

art\ui\ingame\*.ddt
    The five drawn icons. They go in art\ui\ingame\ of the mod.

note-for-drmaxy.txt
    What was decided and why (for information).

optional\uiunitstatpanel3.xml
    Optional, not needed by the key: the original big-UI stat panel (9 rows), from Data3.bar. WoL's own
    file has the 5-row minimized one, so its big UI shows only one attack row.

Install
-------
1. Copy proposed-uiunitselectionmin.xml to data\uiunitselectionmin.xml (keep a copy of yours).
2. Copy minuirows.xml to data\uhc\minuirows.xml.
3. Copy art\ui\ingame\*.ddt to art\ui\ingame\.
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
                                  show with it. Their "Garrison" texts are left out (the garrison row).
    unitResistsValue              WoL's left edge 620 and textcentervert: changed to 597 (right after
                                  the shield); the right edge 1000 kept.
    unitResistsLabel              583 700 597 714 (only the shield) and textmarkup (an icon needs it).
    unitHitPointsLabel            410 680 424 734 (only the heart), textmarkup, no textwrapon.
    unitHitPointsValue            starts at 424 (right after the heart) instead of 507.
    unitTypeName                  412 650 516 714 (was 348..516): the column over the portrait holds the
                                  cost; the name keeps the width of the player's name.
    unitPlayerName                526 650 630 714 (was 520..700): the mirror of the unit's name; the
                                  right column holds the train time and garrison.
    Nesting                       WoL's file nests most of the panel in unitTypeName (its line 40 has no
                                  "/>"); here every original gadget has the original parent.
    WoL's own gadgets             TrainTimeinfo (an empty text with a "TrainTime:" tooltip),
                                  unitanything (empty), SettlerCountDialog-pop-icon (LOS), TrainTime
                                  (Train Points), unitSpeedValue (Speed, inside the resists value, so
                                  hidden with it), unitResourceValue2 (empty) and the three "Garrison"
                                  texts: left out, the key's rows show each of these.
    Every other original gadget (the portrait, the resource and rate rows, StackLabel0..2, the portrait
    count, the stack buttons) is the same in both files.

Notes
-----
- A row is hidden when its item does not apply to the selected unit (no garrison, speed 0, a unit type
  filter in the data file).
- With several units selected the rows describe the first one, as the game's own panel does.
- Mixed groups: the game shows one portrait per unit type in the top band, centred, at most nine (a 10th
  type gets no portrait). Nothing of the key is in that band, so no row moves or hides for the
  portraits. A click on a portrait makes that type the one the panel and the rows describe. (The rule
  "a row a portrait covers is hidden" is still in the DLL for layouts that put rows in the band.)
- Many attacks: the original three rows, then uhcRow3, uhcRow4 and uhcRow5 (next to them, x 583). When
  there are more rows than gadgets, the last one shows the rest in short form, name and damage, then
  "+2 more"; its tooltip lists them all. With the ability filter this did not happen in the tests: the
  8-attack explorers of the first proposal show 3 or 4 rows, the attacks they can really use.
- uhcRow5 shares its line with the resource held and the AutoGather rate (a villager carrying food, a
  factory, a bank): while either shows, uhcRow5 stays empty (minuirows.xml, the two <avoid> lines).
- With WoL's own uhc.dll (its multiarmor writes the resists text) the key leaves the building armor to
  it: a building shows no resists row, as without the key (the first version showed "Resists: 0 (null)"
  on a Factory there). Units show WoL's text ("0.30, 0.20, 0.10").

Tested on 2026-11-17 (single player, WoL in English, 1920 x 1080, the panel at native pixels)
-----------------------------------------------------------------------------------------------
Each scene: (a) the rectangles in media\minui-preview-proposed.png, (b) the screenshot. "Fine" = no text
over another text, nothing cut, nothing in the portrait band, the health bar shown.

    Scene                                           Picture (media\)                          Result
    One Musketeer (cost, house, hourglass, ROF)     minUIStats-v3-1type.jpg                   fine
    A Barracks (building)                           minUIStats-v3-building.jpg                fine
    A Factory (the trickle row "Coin 4.50/s")       minUIStats-v3-factory.jpg                 fine
    A Bank                                          minUIStats-v3-bank.jpg                    fine
    2, 5 and 9 unit types                           minUIStats-v3-2types/5types/9types.jpg    fine
    Menelik II, damaged ("Regen 1/s"); of its 5     minUIStats-v3-explorer.jpg                fine
      ability attacks only Sharpshooter is usable
    A Presidial explorer (Sharpshooter only; no     minUIStats-v3-presidial.jpg               fine
      Crack Shot, as JTMaston said)
    The Chief (WOLcartographer) before / after      minUIStats-v3-cartographer-before.jpg,    fine
      HCSteelCrown: Anti-artillery Crackshot only     -after.jpg
      after the card
    Wachtmeester with 3 armors (test data: two      minUIStats-v3-wachtmeester.jpg            fine
      <Armor> lines added; the DLL's multiarmor)
    A Grognard, 5 attacks (long grenade row)        minUIStats-v3-grenadier.jpg               fine (ends
                                                                                              x ~557)
    A Settler, 4 attacks, 4 multipliers on one row  minUIStats-v3-settler.jpg                 fine (ends
                                                                                              x ~568)
    A long name ("Husar de la Muerte")              minUIStats-v3-longname.jpg                fine
    Overheal ("Overheal +50", HP 150/100; test data minUIStats-v3-overheal.jpg                fine
      InitialHitpoints 100, overhealHitpointBars)
    Every key of the cfg template on (114 applied,  minUIStats-v3-allkeys-presidial.jpg,      fine
      0 failed)                                       -allkeys-settler.jpg
    WoL's uhc.dll (multiarmor) + our dinput8.dll    minUIStats-v3-woluhcdll-factory.jpg,      fine (no
      (the key from engine-ext.cfg): a Factory, a     -woluhcdll-wachtmeester.jpg              "(null)")
      Wachtmeester
    WoL's current file, key off (the reference)     minUIStats-wolcurrent-*.jpg               reference
    Side by side, WoL's current | proposed          minUIStats-v3-vs-wol-units.jpg,           -
                                                    -vs-wol-groups.jpg, -vs-wol-more.jpg
    Not filmed this time: a villager gathering, a building going up ("Done in", "Builds"), a running
    poison, an aura, a ship (the test scenario cannot give orders or make water; these texts are in
    uhcRow2 and uhcRow0, the rows "Regen" and "Overheal" use, filmed above), WoL.dll's trickleDisplay
    row (the stock rate row, filmed on the Factory), Spanish strings (WoL ships them as .es-la; the
    names and labels come from the game's string table, the rows' own words are English).
    Performance (perfprobe.py, 45 s, a Presidial selected, other games running on the PC): key on 387
    fps, update 0.20 ms, render 2.38 ms; WoL's file with the key off 349 fps, 0.19 ms, 2.66 ms: noise.

Media
-----
In media\ (JPG pictures of the panel at native pixels, with the health bar; PNG previews).
    minUIStats-v3-*.jpg               the proposed layout, key on (the table above)
    minUIStats-wolcurrent-*.jpg       WoL's current file, key off, the same scenes
    minUIStats-v3-vs-wol-*.jpg        both side by side
    minui-icons.png                   the icons and where each comes from
    minui-preview-proposed.png        the proposed layout's rectangles, new ones in yellow, the centre lines
    minui-preview-wol.png             WoL's current file's rectangles
    minui-preview-proposed-old.png    the first proposal's rectangles (portraits left of the centre)
    minui-preview-stock.png           the original minimized layout's rectangles
    minui-shot-min-*.png, minui-shot-big-*.png   WoL's UI before the key: a unit, a building, a villager
    minUIStats-test-hero-big.png      Menelik II in the big UI (it lists every attack, usable or not)
Videos of the first proposal (2026-11-17 morning, its layout, before this one): minUIStats-wol,
minUIStats-building-wol, minUIStats-batch2-wol, minUIStats-batch3-wol (.gif / .mp4), each with a
-control twin (key off).
