Final check of the 2026-11-27 round (joint smoke test, agent J)
================================================================

Branch claude/round-20261127 = origin/main 8b851208 + claude/r1127-C (culture UI feasibility, docs), -H (powerShots,
retargetInAction on powers, the hammer-fanning pack, WoL #111), -N3 (nurseryFactor v3: t follows the factor,
pop-capped buttons greyed, pie B, art/ui/uhc/pie in the release) and -GC2 (garrisonConvert v2: eject, population
pause, round robin, from, tech subtypes through the new shared AddTechProtoSubtype; marker 'GCRR').
One code change in this check: nurseryFactor keeps g_shipments across a data load (below, check 2).

Build: Release Win32, 0 errors; warnings all old (minuistats.cpp C4456 x2, LNK4104 x4 on engineext.def).
_UHCMain@0 exported. src/generated/sites.h regenerated: unchanged (967 sites). Porting pages regenerated.
guide_dates, export_public --check (366 files) and make_gifs --check (395 GIFs) pass.
Tested UHC.dll sha256: 77de7543d6e76202f534712c80a0bb8a31cdfdf8c5c028788a2479b8ed09d257 (with the nurseryFactor fix).

Beds (WoLReal4 is another session's and was not touched; no other copy used)
-------------------------------------------------------------------------------
- C:\AoE3-UHC-WoLReal6 (own profile, multipleInstances background): the nurseryFactor save/load test. Bed cfg +
  "nurseryFactor log". Test data (j27data.py load): the Bank as a nursery every 20 s (b 2, cap 10), techs J27Base
  (NurseryFactorGrowthBase Assign 3), J27Max (NurseryFactorMax Absolute +10), N3TestShip2
  (FreeHomeCityUnitByNurseryFactor CrateofCoin, consume 2). Scenario uhcj27n: a Bank, a TownCenter, J27Base and J27Max
  at the start, N3TestShip2 by a trigger at 120 s.
- C:\AoE3-UHC-WoLReal5 (own profile, multipleInstances background): every pack applied in this order: oil-panel
  --rates, select-fattened --hotkey-only, options-menu, editor, gatling-camel, zamburak, trigger-names, observer maps,
  observer UI, hammer-fanning. Then the test data (j27data.py smoke: N3's Bank with three buttons, the Blockhouse
  with two GarrisonConvertTo tags from="Settler" delay="3" eject="true", Pikeman then Musketeer; art\ui\uhc\pie in
  the bed) and the cfg of this folder (wol.cfg: 2026-11-26's, every key line of examples/Startup/uhc.cfg, with
  "retargetInAction log" and the new "powerShots log"; 165 keys). Human Portuguese (sp_Lisbon), AI wolOscar
  (Swedes, the only personality left); the scenario route gives player 1 the Ethiopians.

Result table
------------
Check                                   Result
--------------------------------------  ----------------------------------------------------------------------------
1. Keys, every pack applied             PASS. "UHCMain: 148 applied, 0 failed" (165 keys; the 6 WoL keys "not
   (WoLReal5)                           implemented yet; ignored" as before) in each of the 3 launches. Last round:
                                        147; +1 = powerShots. 189 distinct "hook reached" lines over the runs; the
                                        new and changed ones: powerShots (0x4B7766), retargetInAction (0x487838),
                                        garrison entries (0x9C26E1), command panel button (0x462317), unit panel
                                        row (0x699456) and tail (0x4C8281), nurseryFactor command (0x7D64F7), the
                                        tech subtype lookup / apply / unapply / player sites.
2. nurseryFactor after a load           FIXED. Before the fix (UHC-nursery-load-before-fix.log): the load applied
   (WoLReal6)                           the techs again (GrowthBase 2 -> 3, Max 10 -> 20, so the per-copy values
                                        survive), but the shipment researched after the load logged nothing and
                                        took nothing. Without a load (UHC-nursery-control-no-load.log) the same
                                        shipment took 2 (20 -> 18) and shipped 2 units of proto 426. Cause: the
                                        data-load callback cleared g_shipments, and a load reads the protos again
                                        but not the techtree, so the effect's index pointed nowhere. Fix: the list
                                        is kept, as garrisonConvert's g_effects. After it (UHC-nursery-load-after-
                                        fix.log): saved at 39.8 s (4/20), loaded, both techs applied again, the Bank
                                        grew +9 to 13/20 and +27 to 20/20 (b 3, cap 20), the shipment at 120 s took
                                        2 (20 -> 18, 2 units shipped, the control's lines) and the Bank grew back
                                        to 20/20 at 140 s. (In both runs no crate showed on the map: the stock
                                        FreeHomeCityUnit outside a card; the log is the evidence.)
3. AI alive (skirmish, WoLReal5)        PASS. The profile's map, Portuguese (idle) against wolOscar (Swedes),
                                        431 s of game time. Player 2 units: 14 at 1 min, 15, 19, 21, 24, 27, 29 at
                                        7 min; Settlers 7 -> 21; 3 houses. No "XS" error in UHC.log (xsErrorLog on),
                                        no "Error 0003"; trace_xs.py (pinned to this game's pid, since WoLReal4's
                                        game ran beside it) logged 11 compiles, 0 errors. No crash.     s04
4a. Hammer fanning (WoLReal5,           PASS. An Explorer (invulnerable by a trigger) and 6 OutlawPistol guardians
    scenario uhcj27a)                   (Gaia, 270 HP). One use of Hammer Fanning (ability(99, 0, true), a click on
                                        a guardian): 6 shots from 181765 to 183166 ms, about 280 ms apart, each after
                                        retargetInAction found the next guardian (5.9 to 14.4 m); powerShots logged
                                        "Attack tag after N of 6 shots ... fires" for shots 2 to 6; all six guardians
                                        dead. Then "no other target in range".
4b. garrisonConvert round robin +       PASS. 4 Settlers garrisoned by a trigger: Pikeman (tag 1), Musketeer (tag 2),
    eject (WoLReal5)                    Pikeman, Musketeer, one every 3 s, each put out of the Blockhouse (both
                                        scenarios). With the Blockhouse selected during a conversion, the blue pie
                                        is over its portrait (Garrison 1/20), gone when the last one is done. s01
4c. nurseryFactor pie B and the         PASS. The Bank selected after a sale: "6/10 minks" with the small pie right
    pop-capped button (WoLReal5)        after the text (pie B; art\ui\uhc\pie in the bed).                      s02
                                        At 4/5 population and no house, the 3-Settlers button was darkened (the buy
                                        button too: the Bank was full); after the House a trigger made at 70 s it was
                                        normal again (its stock rollover).                                       s03
5. Games closing on their own           None.

Not tested here: the "Population cap reached" text in the greyed button's rollover (the button was already back
when the cursor reached it; N3 has it in its own test), garrisonConvert's population pause and its tech subtypes
(GC2's tests), multiplayer.

Restore
-------
- WoLReal6: test data back (*.j27bak), the test map removed, uhc.dll, Startup, UHC.log and the game's own files in
  its My Games folder (Age3Log.txt, RecentFilesy.xml, Trigger3\trigtemp.xs; Age3RMuhcj27n.dmp.txt removed) put back.
  A SHA-256 listing of every file of the bed and its My Games folder (65,751 files), taken before the first change,
  is identical after.
- WoLReal5: test data back, packs restored in the reverse order, AI personalities back (51), uhc.dll and the rest
  put back; SHA-256 listing before and after: see the line at the end.

Files
-----
wol.cfg                              the cfg of WoLReal5 (all keys, all packs)
j27data.py                           the test data (apply smoke | load, restore)
UHC-all-runs.log                     WoLReal5: scenario uhcj27a (fanning, garrisonConvert, nursery), uhcj27b
                                     (garrisonConvert's pie), the skirmish
UHC-nursery-load-before-fix.log, UHC-nursery-control-no-load.log, UHC-nursery-load-after-fix.log   WoLReal6
skirmish.txt, trace_xs-skirmish.log  the skirmish, minute by minute, and the XS tracer
s01-s04 *.jpg                        pictures named in the table
