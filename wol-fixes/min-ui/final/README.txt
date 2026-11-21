Minimized unit panel (minUIStats): version 7, for review
=======================================================

Version 7 (2026-11-21), after JTMaston's review of version 6: ..\note-for-team-v7.txt
-------------------------------------------------------------------------------------
- Seconds stuck to the number ("Rate of fire: 3.50s", "40s", "3 x 8s"); the tooltip line reads "Rate of fire".
- The armor as a percent stuck to the value ("20%", "75%"), in our row and in the panel's original resists value.
- The speed follows the tactic: the Falconet shows 4 in Limber and 1.60 in Bombard (4 x 0.4), in both UIs.
- showGatherRate: wood rates now show (they did not); the optional "Holds:" item fixed for the Mill and placed mines.
- New unit type icons (Line, Standing, Maneuver): drawn, under internal review; not in this pack.

    Check (2026-11-21, our UHC.dll unless said; minUIStats, multiplierDecimals,     Picture (minUIStats-v7-...)      Result
    showGatherRate, WoL's wol.cfg lines; scenario players, 1920x1080)
    Tooltip "Rate of fire: 3.50s" / "3s", resists "20%"                         tip-escopetero-ranged, -siege    pass
    Falconet: Limber 4, Bombard 1.60, both UIs; after a move order: Limber, 4     falconet-limber, -bombard,       pass
                                                                                   -after-move, bigui-falconet-*
    Gather rate, minimized vs big UI: berries 0.67, Mine 0.60, Mill 0.50          gather-food, -gold,              pass (same
                                                                                   -mill-settler, mill, bigui-*     values)
    The same with resourceGatherAuras and resourceDebt on (40 applied, 0          allkeys-gather-*                 pass
      failed), trees 0.50 after the fix, the optional Gathers/Holds rows on
    WoL's uhc.dll + our dinput8.dll: 5 applied, 0 failed, the same rates;         woluhcdll-*                      pass (armor
      resists in that DLL's text                                                                                   as WoL's)

Version 6 follows.

Version 6 (2026-11-20), after JTMaston's review of version 5: ..\note-for-team-v6.txt
-------------------------------------------------------------------------------------
- The tooltip's projectile line reads "4 projectiles" (projectilesTip="%s projectiles").
- No parentheses around icons: our lines end with the icon; the game's lines lose the parentheses around an icon and
  around the name after one ("11 (icon) Ranged Damage", "1.5X Bonus Damage against (icon) Maneuver Unit");
  tipParentheses="keep" keeps them. The edited strings for WoL's tables are in the note.
- The unit type icons are WoL's own (a redrawn set was tried and not kept). WoL's staticons\stat_icon_hand_cavalry.ddt
  is an empty 24-byte file, so Hand Cavalry shows no icon.
- Machine guns and the Chu Ko Nu: their burst comes from the attack anim's Attack tags (traced: the Gatling launches
  6 bullets per cycle, the Chu Ko Nu 3 arrows, one per tag), not from numberprojectiles; the note has the table.

    Check (2026-11-20, WoLReal3: our UHC.dll, minUIStats + multiplierDecimals,   Picture (minUIStats-v6-...)     Result
    WoL's wol.cfg lines, scenario players, 1920x1080 unless said)
    Tooltip: "4 projectiles", no parentheses, WoL's icons                      tip-escopetero-ranged           pass
    The panel                                                                   escopetero                      pass
    Chu Ko Nu: no projectile number (data 1)                                    chukonu, tip-chukonu-ranged     pass
    Gatling Gun in Bombard: no number (data 1)                                  tip-gatling-bombard             pass
    Schwarzlose in Bombard: "12 projectiles"                                   tip-schwarzlose-bombard         pass
    Spanish table: "Dano de 11 (icon) A distancia", "... contra (icon) Unidad   spanish-tip-escopetero          pass (our
      de Maniobra"                                                                                              two lines
                                                                                                                English)
    1024x768: the tooltip, the row ending in "(+2)"                             r1024-tip-escopetero            pass
    Combat count (trace of the launch 0x499422 and the shot 0x48F8B5, no        (no picture)                    Gatling 6
      projectile key): launches per ROF cycle                                                                   per cycle,
                                                                                                                Chu Ko Nu 3

Version 5 follows; its pictures that version 6 did not retake are kept.

All screenshots: English (the spanish-* ones in WoL's Spanish table, translations\ES-LA), 1920x1080 (the r1024-*
ones at 1024x768), native pixels, minimized UI, health bar included. Start with 00-overview.jpg. What changed and
why: ..\note-for-team-v5.txt (version 4: ..\note-for-team-v4.txt). The full layout map: ..\README.txt.

Taken on 2026-11-19 in copies of WoL: with our UHC.dll in place of WoL's (the build of this commit, keys
minUIStats and multiplierDecimals, WoL's own wol.cfg lines, attackTypeIcons among them), with WoL's own uhc.dll
alone (the wolmin-*, wolbig-* and wol-volley-count pictures), and with WoL's uhc.dll plus our dinput8.dll (the
woluhcdll-* pictures). Scenario players (Ethiopians), units selected by console, the pointer rested on a row by
posted mouse moves for the tooltips. Other games ran beside it. Version 4 pictures that version 5 did not change are
kept (minUIStats-v4-*).

What changed in version 5
-------------------------
- The projectile number is the data's (NumberOfShots x numberprojectiles), with any DLL: Escopetero 4, Bacamarteer
  6, explorers' Sharpshooter 3. projectiles="combat" in minuirows.xml shows what combat fires instead.
- Multipliers with two decimals (new key multiplierDecimals, as WoL's uhc.dll does), in the rows and, unlike WoL's
  DLL, in the tooltips too; the rows drop the zeros at the end (1.5x, 1.25x, 0.75x).
- The multipliers against WoL's own unit types show with our DLL too (attackTypeIcons, WoL's wol.cfg line).
- Tooltips: the game's own, plus "Attacks every N s" and "N projectiles before the reload"; short rows keep the
  full tooltip; the first attack row's tooltip is no longer covered by the hit points gadget.
- At 1024x768 a row too long for the panel ends with "(+N)" instead of running past the edge.

Pass / fail
-----------
"Pass" = the item shows as intended, no text over another text or gadget, nothing cut, nothing in the
portrait band, the health bar shown.

    Check                                                     Picture (minUIStats-v5-...)          Result
    Projectiles from the data, no numberOfShots key:          escopetero, bacamarteer, explorer    pass
      Escopetero 4, Bacamarteer 6, Sharpshooter 3             (presidial, cartographer)
    No number when 1 projectile (Musketeer)                   1type                                pass
    Schwarzlose in its Bombard tactic (its attacks show only  schwarzlose, tip-schwarzlose-        pass
      there; unitSetTactic("Bombard") by console): 12           bombard
    Floating battery, long-range attack: 5 (its ranged        floatingbattery, tip-floating-       pass
      attack fires 1: no number)                                battery-longrange
    <bigPanelRows projectiles="combat">, numberOfShots off:   combat-escopetero, combat-tip-       pass
      no projectile number for the Escopetero, in the row or     escopetero
      the tooltip (combat fires 1 without the key)
    The "1" next to the red target is the area (DamageArea    wolmin-escopetero (WoL today),       kept (the
      1), written by the game in both panels                    tip-escopetero-ranged ("with 1     game's own,
                                                                Area")                             the data's)
    WoL today fires 1 projectile per Escopetero volley        wol-volley-count                     traced: 4 shots,
      (its uhc.dll c070d138, none of our keys)                                                     4 launches;
                                                                                                   114 / 114
    Multipliers 1.25x / 0.75x, our UHC.dll alone              escopetero, villero                  pass
    Key off: 1.3x / 0.8x (the control)                        keyoff-escopetero, keyoff-tip-...    pass
    multiplierDecimals alone (minUIStats off): 1.50x 1.25x    decimalsonly-escopetero, -tip-...    pass
      0.75x in WoL's own rows and 1.25X in the tooltip
    Trailing zeros dropped in our rows (1.5x, 0.5x)           escopetero, villero                  pass
    Three multipliers for the Escopetero (1.5x Maneuver)      escopetero, keyoff-escopetero        pass
      with our DLL (attackTypeIcons)                            (attackTypeIcons on, decimals off)
    Tooltips, version 5: game's lines + ROF + projectiles     tip-escopetero-ranged, -hand,        pass
                                                                tip-villero-ranged, -right,
                                                                tip-explorer-ranged
    Tooltip of a short row (Sharpshooter): the full one       tip-explorer-sharpshooter            pass
    Tooltips, WoL today: minimized and big panel              wolmin-tip-*, wolbig-tip-*           reference
                                                                                                   (rows 1.25x,
                                                                                                   tooltips 1.3X)
    First attack row's tooltip over its whole width           tip-escopetero-ranged (pointer at    pass (was
                                                                its left part)                     "Hitpoints")
    Every key of the cfg template on: 119 applied, 0 failed   allkeys-escopetero, -villero,        pass
                                                                -presidial, -explorer
    Spanish table: "1.25X de dano adicional contra",          spanish-escopetero, -villero,        pass (the two
      long names                                                -1type, -explorer, -cartographer,  new lines are
                                                                -tip-escopetero                    English:
                                                                                                   rofTip,
                                                                                                   projectilesTip)
    1024x768: rows end at the panel's edge with "(+N)"        r1024-escopetero, -villero,          pass
                                                                -1type, -explorer, -r1024-tip-*
    WoL's uhc.dll + our dinput8.dll (minUIStats,              woluhcdll-escopetero, -villero,      pass
      multiplierDecimals): 4 applied, 0 failed;                 -explorer, -bacamarteer,
      "already has 2 decimals; not written"; projectiles        -tip-escopetero
      from the data (action tag hook 0x5FA11E reached);
      tooltips 1.25X
    AI skirmish with every v5 key and xsErrorLog: no XS       (no picture)                         pass
      error, the AI plays
    The merged DLL (minimized UI v5 + autoScout + map         merged-allkeys-skirmish              pass
      descriptions), every key of the cfg template on, the
      auto-scout pack: Romanians (two ravens, an Escopetero
      placed by the map) against a German AI, Great Lakes,
      4 minutes: 120 applied, 0 failed; 84 % explored; the
      Escopetero 4 projectiles, 1.5x / 1.25x / 0.75x
    The same beside WoL's uhc.dll (our dinput8.dll, every     merged-woluhcdll-skirmish            pass (the 35
      key of the template in engine-ext.cfg): 85 applied,                                          failed are
      35 failed; 82 % explored; the same panel                                                     WoL's sites)
    Performance (perfprobe.py, 45 s, an Escopetero            (no picture)                         noise
      selected, other games beside it): keys on 913 fps,
      update 0.1 ms, render 1.0 ms; off 906 fps, 0.2 ms

Unchanged since version 4 (pictures minUIStats-v4-*)
----------------------------------------------------
Icons (icons-x4.png), hit points as a word, the game's house, three and four costs (cost3-*, cost4-caravan),
1/2/5/9 unit types, buildings (building, factory, bank), long names, the Chief before/after (cartographer-*),
three armors (wachtmeester), Grognard, Settler, poison, auras, ships, construction, r1024-caravan, spanish-hitpoints,
the projectile scenes with "numberOfShots projectiles" (projectiles-escopetero-volley, -schwarzlose,
-floatingbattery: combat fires those numbers with that key), and the side-by-side sheets (vs-wol-*, popicon-*).
The Schwarzlose and the floating battery were taken again in version 5 (minUIStats-v5-schwarzlose, -floatingbattery).

Files
-----
    00-overview.jpg                       the main version 5 scenes with captions
    minUIStats-v5-*.jpg                   version 5 (table above)
    minUIStats-v5-wol-volley-count.jpg    WoL's uhc.dll today: one projectile per Escopetero volley, traced
    minUIStats-v5-merged-*.jpg            the merged DLL's smoke test (whole screen: minimap and panel), 2026-11-19
    minUIStats-v4-*.jpg                   version 4 scenes that did not change
    minui-icons.png, minui-preview-*.png  the icons and the layouts' rectangles (unchanged since version 3/4)
