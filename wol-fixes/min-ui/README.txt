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
- nine texts for any formatText gadget: {uhcHitpoints}, {uhcSpeed}, {uhcBaseSpeed}, {uhcLOS},
  {uhcArmor}, {uhcArmorValue}, {uhcGarrison}, {uhcTrainPoints}, {uhcBuildPoints}.

The big UI does not change. Without the key nothing changes.

Files
-----
proposed-uiunitselectionmin.xml
    The original minimized selection panel (uiunitselectionmin.xml from Data3.bar), unchanged, plus
    six new gadgets at the top level of unitselectionpanel-unit:
      unitselectionpanel-uhcTrainPoints   above the portrait
      unitselectionpanel-uhcRow0          LOS
      unitselectionpanel-uhcRow1          Garrison
      unitselectionpanel-uhcRow2          Speed
      unitselectionpanel-uhcRow3, -uhcRow4   the big UI's extra rows (more attacks, Gatherers)
    None of them is inside a gadget the game shows or hides, so no row depends on another.
    The places follow WoL's current panel; move them as you like.

minuirows.xml
    The data file: which gadget shows which item, with which label, for which unit types. It goes in
    data\uhc\minuirows.xml. The comments at its top list every item and option. To add a row, add a
    formatText gadget to the layout and a <row> line here; no new DLL is needed.

questions-for-drmaxy.txt
    The decisions taken and two questions about WoL's current files.

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
- uhcRow3 and uhcRow4 are narrow: a long attack row is cut at the gadget's edge. Make them wider, or
  add uhcRow5, uhcRow6 ... (consecutive numbers) for more rows.
- With WoL.dll's forceMinUI and the profile option off, the game loads the minimized layout but skips
  its own rows (hit points, attacks); the big UI's rows then go to the uhcRow gadgets of the
  bigPanelRows line only. Keep the option on, or give that line more gadgets.
- Tested on 2026-11-17 in single player: a Musketeer, a Bunker (armor 0.3), Menelik II (5 attacks), a
  Grognard, a Dragoon, a Settler gathering, four Musketeers, a berry bush, a Caravel and a Galleon,
  compared row by row with the big UI; also beside WoL.dll (forceMinUI, trickleDisplay).
