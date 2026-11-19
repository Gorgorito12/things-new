Minimized unit panel (minUIStats): version 4, for review
=======================================================

All screenshots: English (the spanish-* ones in WoL's Spanish table), 1920x1080 (the r1024-* ones at
1024x768), native pixels, minimized UI, health bar included. Start with 00-overview.jpg. What changed and
why: ..\note-for-team-v4.txt. The full layout map: ..\README.txt. Version 3's pictures are in ..\media\.

Taken on 2026-11-18 in a copy of WoL with our UHC.dll (the build of this commit) and the pack as shipped. The
scenes with projectile numbers were taken again with "numberOfShots projectiles" on (the projectile rule
changed the same day, below); the allkeys-*, spanish-* and r1024-* scenes were taken with the first rule (the tags
as written, now projectiles="data"), so their numbers show in game only with that key
(proposed-uiunitselectionmin.xml, minuirows.xml, art\ui\ingame\*.ddt): scenario players (Ethiopians), units
selected by console, the panel cropped from the window at native pixels. Other games ran beside it.

What changed in version 4
-------------------------
- The drawn icons are redrawn like WoL's own (32x32 uncompressed, hard edges, black outline): stopwatch,
  hourglass, eye, winged boot, shield. New: the revolver cylinder (projectiles).
- Hit points: the word "Hitpoints" from the string table (68852), in the labels' yellow; no heart.
- Population: the game's house (ui\ingame\stat_icon_building, WoL's copy).
- Each attack that fires more than one projectile before its reload shows that number after its rate of fire,
  as combat fires them: only with our DLL's numberOfShots key (shots), and its "projectiles" option (WoL's
  numberprojectiles, which nothing else reads). Without the key: no number, one projectile.
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
    With "numberOfShots projectiles" on:
    Projectiles: Escopetero volley 4, and combat fires 4      projectiles-escopetero,             pass (log:
                                                                projectiles-escopetero-volley.jpg   "launches 4
                                                                (four tracers at 20.6 s)            projectiles
                                                                                                    for one shot")
    Projectiles: Schwarzlose 12 (Bombard tactic)              projectiles-schwarzlose             pass
    Projectiles: Bacamarteer 6, Villero 4                     projectiles-bacamarteer, villero    pass
    Projectiles: explorer Sharpshooter 3 (right column,       projectiles-explorer, explorer,     pass
      short form keeps ROF and projectiles)                     presidial (full row)
    Projectiles: floating battery long-range 5                projectiles-floatingbattery         pass
    No number when 1 projectile (Musketeer, ships' ranged)    1type, ship-*                       pass
    numberOfShots off (minUIStats on): no number; the         projectiles-keyoff-escopetero,      pass
      Escopetero fires 1 projectile                             projectiles-vs-key.jpg
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
      "projectiles", first rule: the data's 4 shown; with
      the current rule that run shows no projectile number)
    Key off, this layout (WoL's panel as it is)               keyoff-1type, -wachtmeester,        pass
                                                                -villero, -escopetero
    WoL's uhc.dll (c070d138) + our dinput8.dll with           woluhcdll-escopetero, -explorer,    pass
      numberOfShots projectiles: 4 applied, 0 failed; hooks     -1type, -factory, -wachtmeester
      reached: action tag (0x5FA11E), numberOfShots
      projectiles (0x48F88D); the Escopetero launched 4 a
      shot and shows 4; resists by WoL's DLL (no building
      armor, no "(null)")
    1024x768: icons, costs two and two, HP row                r1024-1type, -escopetero,           pass
                                                                -explorer, -caravan
    1024x768: the Villero's long ranged row                   r1024-villero                       limit: cut
                                                                                                   at the panel's
                                                                                                   edge (below)
    A Town Center going up: "Done in 0:43"; its builder       construction-site,                  pass
      "Builds 1.00/s" (scenario, the settler's own build          construction-builder
      button and a placement click posted to the window)
    Side by side with WoL's current panel                     vs-wol-units, -groups, -more        -
    Population icon, version 3 against version 4              popicon-vs-old                      -

Notes
-----
- At 1024x768 the font is relatively wider than at 1920x1080 (it follows the screen's height), and the
  Villero's ranged row (five multipliers) is cut at the panel's edge. Measured in r1024-villero: the parts
  version 4 adds (ROF and projectiles, about 33 pixels) are smaller than what is cut (about 45 pixels), so
  WoL's own row is already wider than the panel at that resolution.
- The projectile number is what combat fires: neither the game nor WoL's DLLs read numberprojectiles, so it
  shows only with our DLL's "numberOfShots projectiles" (note-for-team-v4.txt). projectiles="data" on
  <bigPanelRows> shows the tags as written instead (a modder's check; off by default).
- The 1type, popicon-* and vs-wol-* pictures show a Musketeer with 150/150: the last run had no overheal test
  data (it gave Musketeers InitialHitpoints 100 in the first runs); overheal and wachtmeester keep their pictures
  from the runs with that test data.
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
    minUIStats-v4-projectiles-vs-key.jpg   numberOfShots off (no number) | numberOfShots projectiles (4)
    minUIStats-v4-projectiles-escopetero-volley.jpg   the Escopetero's volley in game: four tracers
    minui-icons.png                    every icon at 1x, 4x and at the panel's size, with its source, and two of
                                       WoL's icons for comparison
    minui-preview-proposed.png, minui-preview-wol.png   the layouts' rectangles (unchanged since version 3)
