Minimized UI with all the information (WoL request #67)
=======================================================

What it does
------------
With the DLL key minUIStats, the minimized in-game UI (optionminimizedui) shows what the big UI shows,
and more:

- Train Points, LOS, Garrison and the live Speed (with techs, snares and auras) in rows of their own;
- the rows of the big UI the minimized one had no room for: the 4th attack and the next ones, Gatherers,
  Group Health;
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
    seven new gadgets at the top level of unitselectionpanel-unit:
      unitselectionpanel-uhcTrainPoints   above the portrait
      unitselectionpanel-uhcCostPop       Cost and Pop, above the unit's name (right of its icon)
      unitselectionpanel-uhcRow1          ROF and Range, under it
      unitselectionpanel-uhcRow0          LOS, Speed and Garrison, under the player's name
      unitselectionpanel-uhcRow2          Done in, Builds, Regen, Overheal, Poison and Aura, left of
                                          the name (two lines)
      unitselectionpanel-uhcRow3, -uhcRow4   the big UI's extra rows (more attacks, Gatherers)
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
- uhcRow3 and uhcRow4 are as wide as the original attack rows, so a hero's "Sharpshooter ATK: 750 ...
  16 (range)" fits. Add uhcRow5, uhcRow6 ... (consecutive numbers) for more rows.
- With WoL.dll's forceMinUI the profile option does not matter: whenever the minimized layout is loaded,
  the panel is filled as with the option on. The big UI (uiunitselection.xml) is left alone.
- Tested on 2026-11-17 in single player: a Musketeer, a Bunker (armor 0.3), Menelik II (5 attacks), a
  Grognard, a Dragoon, a Settler gathering, four Musketeers, a berry bush, a Caravel and a Galleon,
  compared row by row with the big UI; also beside WoL.dll (forceMinUI, trickleDisplay), with the
  profile option on and off, and the big UI with the option off.
