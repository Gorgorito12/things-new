Minimized UI with all the information (WoL request #67)
=======================================================

What it does
------------
With the DLL key minUIStats, the minimized in-game UI (optionminimizedui) shows what the big UI shows,
and more:

- Train Points, LOS, Garrison and the live Speed (with techs, snares and auras) in rows of their own;
- the rows of the big UI the minimized one had no room for: the 4th attack and the next ones, Gatherers,
  Group Health; and the attacks the big UI itself has no room for (it stops at 9 rows: Menelik II has 8
  attacks, the big UI shows 5);
- the armor of buildings, in the original "Resists" spot, with the same look as for units;
- ROF and range per attack, cost and population, above the unit's name;
- with our other keys on: the overheal (overhealHitpointBars) and a running poison (damageOverTime);
- a building under construction: the time left ("Done in 1:21"); a villager building: its points per
  second ("Builds 1.50/s"); a unit that regenerates: "Regen 1/s"; what our aura keys do to the unit
  ("Aura +50% work", "+25% gold", "pays 0.10 (wood)/s"; the game's own auras show in the numbers);
- more you can switch on in minuirows.xml (commented rows): minimum range, area, build points and
  limit, bounty, lifespan left, what a mine or animal holds, the gather rate, the random price range,
  the cards sent per age, base speed, armor, veterancy rank;
- 30 texts for any formatText gadget, one per item: {uhcSpeed}, {uhcLOS}, {uhcROF}, {uhcRange},
  {uhcCost}, {uhcPopulation}, ... (the list is at the top of minuirows.xml).

The big UI does not change. Without the key nothing changes.

Files
-----
proposed-uiunitselectionmin.xml
    The original minimized selection panel (uiunitselectionmin.xml from Data3.bar), unchanged, plus
    eight new gadgets at the top level of unitselectionpanel-unit:
      unitselectionpanel-uhcTrainPoints   above the portrait
      unitselectionpanel-uhcCostPop       Cost and Pop, above the unit's name (right of its icon)
      unitselectionpanel-uhcRow1          ROF and Range, under it
      unitselectionpanel-uhcRow0          LOS, Speed and Garrison, under the player's name
      unitselectionpanel-uhcRow2          Done in, Builds, Regen, Overheal, Poison and Aura, left of
                                          the name (two lines)
      unitselectionpanel-uhcRow3, -uhcRow4
                                          the big UI's extra rows (the 4th and 5th attack,
                                          Gatherers), right of the 2nd and 3rd original attack rows
      unitselectionpanel-uhcRow5          the next ones (6th attack and on), right of the 1st
                                          attack row
    None of them is inside a gadget the game shows or hides, so no row depends on another.
    The places follow WoL's current panel; move them as you like.

minuirows.xml
    The data file: which gadget shows which items, with which labels, for which unit types. A row can
    join several items: text="ROF: {rof}|Range: {range}" (each part shows only when it has a value). It goes in
    data\uhc\minuirows.xml. The comments at its top list every item and option. To add a row, add a
    formatText gadget to the layout and a <row> line here; no new DLL is needed.

note-for-drmaxy.txt
    What was decided, and two things noticed in WoL's current files (for information).

optional\uiunitstatpanel3.xml
    Optional, not needed by the key: the original big-UI stat panel (9 rows), from Data3.bar. WoL's own
    file has the 5-row minimized one, so its big UI shows only one attack row.

Install
-------
1. Copy proposed-uiunitselectionmin.xml to data\uiunitselectionmin.xml (keep a copy of yours).
2. Copy minuirows.xml to data\uhc\minuirows.xml.
3. Add the line   minUIStats   to Startup\wol.cfg.
4. Keep optionminimizedui on (WoL's profile has it on).

Notes
-----
- A row is hidden when its item does not apply to the selected unit (no garrison, speed 0, a unit type
  filter in the data file).
- With several units selected the rows describe the first one, as the game's own panel does.
- Mixed groups: with several unit types selected, the game shows one portrait per type in the top band
  of the panel, centred, at most nine (a 10th type gets no portrait, there is no second page). A row
  that a portrait covers is hidden until the portraits leave room again: with this layout, Cost/Pop
  and ROF/Range from two types on, Train Points at nine types (and, by the spacing, from six). One type
  changes nothing. A click on a portrait makes that type the one the panel and the rows describe.
  In minuirows.xml, overlap="show" on a row keeps it shown anyway, and <avoid gadget="..."/> makes the
  rows give way to an original gadget while it is shown. The default file avoids the resource held and
  the AutoGather rate, which share their line with uhcRow5: while either shows, uhcRow5 stays empty.
- Many attacks: uhcRow3, uhcRow4 and uhcRow5 take the attacks after the original three, then Gatherers
  and the like. When there are more rows than gadgets, uhcRow5 shows the rest in short form (name and
  damage, as many as fit, then "+2"), and its tooltip lists them all. The attacks past the big UI's
  9th row are written by the DLL in the same format, without the bonus multipliers ("3x" vs cavalry).
  Add uhcRow6 ... (consecutive numbers) for more full rows.
- uhcRow3, uhcRow4 and uhcRow5 end where the original attack rows end, so a hero's "Sharpshooter ATK:
  750 ... 16 (range)" fits. The original attack rows are left-aligned: the longest seen (a Grognard's
  grenade row) ends before uhcRow3..5 start.
- With WoL.dll's forceMinUI the profile option does not matter: whenever the minimized layout is loaded,
  the panel is filled as with the option on. The big UI (uiunitselection.xml) is left alone.
- Tested on 2026-11-17 in single player: a Musketeer, a Bunker (armor 0.3), Menelik II (5 attacks), a
  Grognard, a Dragoon, a Settler gathering, four Musketeers, a berry bush, a Caravel and a Galleon,
  compared row by row with the big UI; also beside WoL.dll (forceMinUI, trickleDisplay), with the
  profile option on and off, and the big UI with the option off.
- Tested again on 2026-11-17 (mixed groups and many attacks): 1, 2, 5, 9, 10 and 12 unit types, a click
  on a portrait, Menelik II and Manuel Mondragon (8 attacks each), a Grognard, a Barracks, with the key
  off, with WoL.upl (forceMinUI, trickleDisplay, ...) and with every key of the DLL on: pictures below.

Media
-----
In media\ (JPG and PNG pictures, GIF and MP4 videos). "Key on" = minUIStats with this pack's files.

Mixed groups and many attacks (2026-11-17, screenshots of the panel at 1920 x 1080, native pixels):
  minUIStats-mixed-1type.jpg              one Musketeer: as before (key on)
  minUIStats-mixed-1type-control.jpg      the same, key off
  minUIStats-mixed-2types.jpg             two types: Cost/Pop and ROF/Range give way (key on)
  minUIStats-mixed-5types.jpg             five types (key on)
  minUIStats-mixed-5types-control.jpg     five types, key off
  minUIStats-mixed-5types-woldll.jpg      five types, key on, with WoL.upl loaded
  minUIStats-mixed-5types-allkeys.jpg     five types, key on, with every key of the DLL on
  minUIStats-mixed-9types.jpg             nine types: Train Points gives way too (key on)
  minUIStats-mixed-9types-control.jpg     nine types, key off
  minUIStats-mixed-10types.jpg            ten types: nine portraits, no 10th (key on)
  minUIStats-mixed-12types.jpg            twelve types: nine portraits (key on)
  minUIStats-mixed-12types-clicked.jpg    twelve types, the first portrait clicked: Menelik II described
  minUIStats-mixed-building.jpg           a Barracks (key on)
  minUIStats-attacks-explorer.jpg         Menelik II, 8 attacks: 3 original rows, 2 extra, the last 3 in
                                          short form "... +2" (key on)
  minUIStats-attacks-explorer-control.jpg Menelik II, key off: 3 attacks
  minUIStats-attacks-explorer-woldll.jpg  Menelik II, key on, with WoL.upl loaded
  minUIStats-attacks-explorer-allkeys.jpg Menelik II, key on, with every key of the DLL on
  minUIStats-attacks-presidial.jpg        Manuel Mondragon (WoLPresidial), 8 attacks (key on)
  minUIStats-attacks-grenadier.jpg        a Grognard, 5 attacks: uhcRow5 stays empty (key on)
  minUIStats-avoid-test.jpg               a test data file that avoids the hit points label: the LOS /
                                          Speed row under it gives way (key on, test only)
  minui-preview-proposed.png              the proposed layout: every gadget's rectangle, new rows in yellow

Earlier batches (same day):
  minUIStats-wol.gif / .mp4               Menelik II: Train Points, LOS, Speed, 4th and 5th attacks (key on)
  minUIStats-wol-control.gif / .mp4       the same scene, key off
  minUIStats-building-wol.gif / .mp4      a Bunker: armor and garrison (key on)
  minUIStats-building-wol-control.gif / .mp4   the same, key off
  minUIStats-batch2-wol.gif / .mp4        a veteran Musketeer: Cost, Pop, ROF, Range (key on)
  minUIStats-batch2-wol-control.gif / .mp4     the same, key off
  minUIStats-batch3-wol.gif / .mp4        a Town Center going up: "Done in 1:25" (key on)
  minUIStats-batch3-wol-control.gif / .mp4     the same, key off
  minUIStats-test-hero-min.png            Menelik II in the minimized UI (key on)
  minUIStats-test-hero-big.png            Menelik II in the big UI, for comparison
  minUIStats-test-ship-min.png            a ship in the minimized UI (key on)
  minUIStats-test-forcemin.png            WoL.dll's forceMinUI with the profile option off (key on)
  minui-shot-min-unit.png, minui-shot-big-unit.png             a unit, minimized and big UI (key off)
  minui-shot-min-building.png, minui-shot-big-building.png     a building, the same
  minui-shot-min-villager.png, minui-shot-big-villager.png     a villager, the same
  minui-preview-stock.png                 the original minimized layout's rectangles
  minui-preview-wol.png                   WoL's current minimized layout's rectangles
