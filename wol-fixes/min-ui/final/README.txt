Minimized unit panel (minUIStats): version 4, for review
=======================================================

All screenshots: English (the spanish-* ones in WoL's Spanish table), 1920x1080 (the r1024-* ones at
1024x768), native pixels, minimized UI, health bar included. Start with 00-overview.jpg. What changed and
why: ..\note-for-team-v4.txt. The full layout map: ..\README.txt. Version 3's pictures are in ..\media\.

Taken on 2026-11-18 in a copy of WoL with our UHC.dll (the build of this commit) and the pack as shipped
(proposed-uiunitselectionmin.xml, minuirows.xml, art\ui\ingame\*.ddt): scenario players (Ethiopians), units
selected by console, the panel cropped from the window at native pixels. Other games ran beside it.

What changed in version 4
-------------------------
- The drawn icons are redrawn like WoL's own (32x32 uncompressed, hard edges, black outline): stopwatch,
  hourglass, eye, winged boot, shield. New: the revolver cylinder (projectiles).
- Hit points: the word "Hitpoints" from the string table (68852), in the labels' yellow; no heart.
- Population: the game's house (ui\ingame\stat_icon_building, WoL's copy).
- Each attack that fires more than one projectile before its reload shows that number after its rate of fire.
- Four costs take both lines over the portrait, two and two.

Pass / fail
-----------
"Pass" = the item shows as intended, no text over another text or gadget, nothing cut, nothing in the
portrait band, the health bar shown, the two blocks on the same baselines.

    Check                                                     Picture (minUIStats-v4-...)        Result
    Icons: hard edges, solid, black outline, same weight as   icons-x4.png (x4 crops from the     pass
      WoL's range/attack icons, at 1920x1080 and 1024x768       game; v3 above v4), minui-icons.png
    The eye reads as an eye at the panel's size               icons-x4.png                        pass (the
                                                                                                   first bold
                                                                                                   eye read as
                                                                                                   a ring: drawn
                                                                                                   flatter)
    Hitpoints as a word, label yellow, value white, at the    1type, keyoff-vs-on.jpg             pass
      place of WoL's own "Hitpoints:" label
    Spanish: "Puntos de Vida: 5000/5000" (largest HP tested)  spanish-hitpoints, spanish-*        pass (ends
                                                                                                   at x ~300 of
                                                                                                   the column)
    Overheal colour still on the value                        overheal ("150/100", "+50")         pass
    The game's house for population                           popicon-unit, -group, -building     pass (a
                                                                                                   building has
                                                                                                   no population
                                                                                                   row, as v3)
    Projectiles: Escopetero volley 4 (tactics: 4)             projectiles-escopetero              pass
    Projectiles: Schwarzlose 12 (Bombard tactic)              projectiles-schwarzlose             pass
    Projectiles: Bacamarteer 6                                projectiles-bacamarteer             pass
    Projectiles: explorer Sharpshooter 3 (right column,       projectiles-explorer, explorer,     pass
      short form keeps ROF and projectiles)                     allkeys-presidial (full row)
    Projectiles: floating battery long-range 5                projectiles-floatingbattery         pass
    No number when 1 projectile (Musketeer, ships' ranged)    1type, ship-*                       pass
    3 costs: Mehal Sefari 50/50/50                            cost3-mehal                         pass
    3 costs: Mamluk 100/200/100, Sebastopol 200/600/600       cost3-mamluk, cost3-sebastopol      pass
    3 costs: Carretero 110 food / 10 wood / 10 gold           cost3-carretero                     pass
    3 costs of 4 digits: Fort Wagon 1000/1000/1000            cost3-fortwagon                     pass (one
                                                                                                   line)
    4 costs: Palace Caravan 600/600/200/200                   cost4-caravan                       pass (two
                                                                                                   and two;
                                                                                                   version 3
                                                                                                   lost the 4th)
    Marechaussee                                              cost3-marechaussee                  pass: 150
                                                                                                   wood only,
                                                                                                   as WoL's data
                                                                                                   (food and gold
                                                                                                   commented out)
    1, 2, 5, 9 unit types: the band holds only portraits      1type, 2types, 5types, 9types       pass
    Buildings: Barracks, Factory (trickle row), Bank          building, factory, bank             pass
    Long rows: Villero (5 multipliers + ROF + projectiles)    villero, allkeys-villero            pass at
                                                                                                   1920 (ends 4
                                                                                                   units before
                                                                                                   the panel's
                                                                                                   edge); see
                                                                                                   1024 below
    Long names, ability filter, Chief before/after card       longname, presidial,                pass
                                                                cartographer-before/-after
    3 armors (multiarmor), Grognard, Settler                  wachtmeester, grenadier, settler    pass
    Poison (damageOverTime), auras (unitResourceAuras)        poison, aura-sawmill, aura-tree     pass
    Ships: Caravel, Galleon, Frigate (2 armors, garrison)     ship-caravel, -galleon, -frigate    pass
    Every key of the cfg template on: 114 applied, 0 failed,  allkeys-presidial, -villero,        pass
      124 hooks reached (numberOfShots on, without             -escopetero
      "projectiles": the panel shows the data's 4)
    Key off, this layout (WoL's panel as it is)               keyoff-1type, -wachtmeester,        pass
                                                                -villero, -escopetero
    WoL's uhc.dll (c070d138) + our dinput8.dll: applied and   woluhcdll-escopetero, -factory,     pass (see
      reached (engine-ext.log: "hook reached: action tag        -wachtmeester, -1type, -explorer    below)
      (0x5FA11E)"), the Escopetero's 4 shown; resists by
      WoL's DLL (no building armor, no "(null)")
    1024x768: icons, costs two and two, HP row                r1024-1type, -escopetero,           pass
                                                                -explorer, -caravan
    1024x768: the Villero's long ranged row                   r1024-villero                       limit: cut
                                                                                                   at the panel's
                                                                                                   edge (below)
    Building under construction, its builder                  (not retaken)                       not run:
                                                                                                   the skirmish
                                                                                                   start failed;
                                                                                                   v3's pictures
                                                                                                   are in media\
    Side by side with WoL's current panel                     vs-wol-units, -groups, -more        -
    Population icon, version 3 against version 4              popicon-vs-old                      -

Notes
-----
- At 1024x768 the font is relatively wider than at 1920x1080 (it follows the screen's height), and the
  Villero's ranged row (five multipliers) is cut at the panel's edge. Measured in r1024-villero: the parts
  version 4 adds (ROF and projectiles, about 33 pixels) are smaller than what is cut (about 45 pixels), so
  WoL's own row is already wider than the panel at that resolution.
- The projectile number is what the tactics ask for: neither the game nor WoL's current uhc.dll reads
  numberprojectiles, so these attacks fire one projectile per shot unless our DLL's
  "numberOfShots projectiles" is on (note-for-team-v4.txt).
- Performance (perfprobe.py, 45 s, an Escopetero selected, other games running beside it): key on
  333-388 fps, update 0.17 ms, render 2.4-2.8 ms; key off with this layout 353 fps, 0.19 ms, 2.6 ms, no frame
  over 50 ms in any run: noise.

Files
-----
    00-overview.jpg                    the main scenes with captions
    minUIStats-v4-*.jpg                one scene each (table above)
    minUIStats-v4-icons-x4.png         the icons enlarged 4 times from the game: v3, v4, and v4 at 1024x768
    minUIStats-v4-vs-wol-*.jpg         WoL's current panel (key off) | version 4
    minUIStats-v4-popicon-vs-old.jpg   version 3's drawn house | version 4's (the game's) house
    minUIStats-v4-keyoff-vs-on.jpg     this layout key off | key on
    minui-icons.png                    every icon at 1x, 4x and at the panel's size, with its source, and two of
                                       WoL's icons for comparison
    minui-preview-proposed.png, minui-preview-wol.png   the layouts' rectangles (unchanged since version 3)
