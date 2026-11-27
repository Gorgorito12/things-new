Final check of the 2026-11-24 round (joint smoke test before main, agent J)
=========================================================================

Build: branch claude/wol-feedback-20261124 at 2188b2d, build\Release\UHC.dll sha256 a20f7c27...6b56715 (not rebuilt).
Bed: C:\AoE3-UHC-WoLReal5 (its own profile), English tables (already the English originals), single player.
cfg: the bed's wol.cfg (WoL keys) + every key line of examples/Startup/uhc.cfg, 159 keys. Left out: faithResource
(faith is a separate optional feature), preloadDll and lanAutoStart (not for UHC.dll), firstTC (alias of civFirstTC,
which is in). Lines set for this check: veterancyBonus notext; ageUpBuildings Market; displayedRange log;
incomeRates log; techGadgets log + the 12 GreatWarizeALL lines of the oil panel pack; turretArc with the gatling camel
pack's line + log. Packs applied: min-ui (v9), oil-panel --rates (no faith), gatling-camel (round 3); tools\rings
copied to art\effects\uhc_rings. Test data: <AlwaysDisplayRange>1</AlwaysDisplayRange> on FortFrontier and Outpost
in data\protoy.xml (removed after).

Three games, each a fresh launch:
1. Skirmish on Acre, Saudis (Riyadh) against wolOtto (Germans, the only personality left), multipleInstances
   background, 494 s of game time.
2. Scenarios (editor route, no AI), background: uhcfc24 (Ethiopians: Town Center, 4 Settlers on berries, Fort,
   Outpost; a trigger sets GreatWarButton at 90 s), then a saved and loaded game, then uhcfc24b/c (GatlingCamel and
   GatlingCamelDeployed made by Unit Create facing north, Houses of player 2 north-east and north-west of them).
3. Scenario uhcfc24t in the FOREGROUND (multipleInstances without background; no other game running, tasklist
   checked), only to hover the resource panel for its tooltip. About 3 minutes.

Result table
------------
Check                                   Result                                              Files
--------------------------------------  --------------------------------------------------  ----------------------------
1. Keys                                 PASS: "UHCMain: 142 applied, 0 failed" (159 keys)   UHC.log
                                        in each launch; 6 WoL keys "not implemented yet;
                                        ignored" as before. 126 on 2026-11-21 + 16: this
                                        round's techGadgets, incomeRates, turretArc and 13
                                        template keys the 11-21 cfg did not have yet
                                        (ageFiveShipments, resendableCards,
                                        quickArrivalCards, retargetInAction, scenarioCivs,
                                        deadReplacementAtZeroInventory, modelCacheLimit,
                                        dmgPartBoneFix, editorSearch, broadsideSoundSet,
                                        autoGatherFrom, buildingGather, herdWalkAwayFix).
                                        Reached: "incomeRates add (0x49A98A)", "turretArc
                                        facing (0x48AA9F)", "turretArc launch (0x4995D5)",
                                        "displayedRange: proto flag parser's last compare
                                        (0x5F726F)" + its ring lines. techGadgets has no
                                        hook of its own: "first tech check (player 1)",
                                        all 24 gadgets found, the change lines below
2. #103 oil panel                       PASS. Before the Great War no oil row: Saudi panel  s1-skirmish-saudis-pregw-
                                        (skirmish) food/wood/gold/villagers; Ethiopian      income-panel.png,
                                        (Asian) panel export/food/wood/gold/villagers.      s2-oil-before-gw-panel.png,
                                        GreatWarButton by trigger at 90 s: log "player 1,   s3-oil-after-gw-panel.png,
                                        GreatWarizeALL active: ...-postGW shown, hidden:    s4-oil-after-save-load-
                                        ...-preGW" for the 12 variants; the oil row on top. panel.png
                                        Saved (saveGame) and loaded (loadGame) after it:
                                        oil row still shown
                                        (In the skirmish the console cannot get the Great
                                        War: researchByID(GreatWarButton) does nothing
                                        before Imperialize, so it was tested in the
                                        scenario.)
3. #105 income rates                    PASS. Green "+N.N" under each amount: skirmish      s1-...-panel.png,
                                        food +2.5, gold +1.8, matching the key's log        s5-income-tooltip.png
                                        (food 2.52/s, gold 1.80/s; counted = stockpile
                                        change over 60 s). Tooltip, foreground, cursor on
                                        the food icon: "Food Gatherers: 5 / Income: +3.4
                                        per second" (panel +3.3/+3.4, 5 Settlers on berries)
4. #92 displayedRange                   PASS. Fort selected: filled 33 m ring and dashed    s6-fort-ring.jpg,
                                        47 m (anti-ship) ring, far from the walls (the TC   s7-outpost-ring.jpg
                                        38 m away sits just outside the 33 m ring);
                                        Outpost: 27 m filled, 43 m dashed. Log: "ring of
                                        33 m on unit 8 (FortFrontier)", "ring of 27 m on
                                        unit 9 (Outpost)"
5. #102 turretArc + gatling camel       PASS. Log: "unit 18 aims at 27.3 / 49.6 / -55.6    s8-camel-gun-turned.png,
                                        degrees (arc 90): the gun turns" (GatlingCamel),    s9-deployed-camel-gun-
                                        "unit 19 aims at -55.6 / 27.3 ... the gun turns"    turned.png,
                                        (GatlingCamelDeployed); a target behind (-152.7)    s10-camel-reload-frames.jpg,
                                        "the unit turns". In the frames the camel's head     s11-camel-death-frames.jpg
                                        points one way and the barrels and muzzle flash
                                        toward the House; the deployed camel lies low with
                                        the gun turned to its left. Reload (s10, 0.1 s a
                                        frame): the gunner's arm up, the gun back to the
                                        middle, then firing again; gun on its post, legs on
                                        the ground. At this zoom (normalZoom 32) the small
                                        magazine thrown away and the one drawn from the
                                        pocket cannot be told apart in the frames: not
                                        checked here (the pack's round 3 checked them
                                        close). Death (deleted): camel, gun and rider
                                        lie on the ground together and fade; nothing floats.
                                        Ammo box: none comes from the camel. A wooden crate
                                        and a grey block seen on the ground next to it fly
                                        in from the House under fire (s10, frames n16-n23)
                                        and fade: the House's debris
6. AI plays                             PASS: player 2's objects 15 at 3 s, 24 at 293 s,    s12-skirmish-late-494s.jpg
                                        26 at 374 s, 29 at 455 s (17 Settlers, 4 Peasants,
                                        3 Manors, TC, Explorer); no XS error, no "Error
                                        0003" (xsErrorLog on)
7. No crash                             PASS: each game closed cleanly ("perfStats: exit"   UHC.log
                                        lines; 494 s skirmish, the scenarios, the
                                        foreground game)
8. Restore                              PASS, see below

Notes (not failures of the keys)
--------------------------------
- GatlingCamelDeployed did not fire on its own at a House 10 m away (the first scenario): it fired once ordered
  (uiWorkAtPointer on the House), then took the next target by itself. Not checked whether that is the deploy rule.
- Saudi Settlers sent to a tree brought in gold, not wood (gold +1.8, wood +0.0; the log counts it as gathered gold
  and it matches the stockpile): WoL's Saudi data, not this round's keys. Not checked further.
- testbed `map`: the Houses of player 2 placed with p2=House did not appear in the scenario; Unit Create triggers
  made them.
- Not tested: multiplayer is not tested (single player only). Switching full/minimized interface in a game.

Restore
-------
- protoy.xml test lines removed; gatling-camel, oil-panel and min-ui: --restore; art\effects\uhc_rings removed;
  AI personalities: ai_personality.py restore (51 back); the RM4 test maps and their dumps, the scenarios
  (testbed close) and the save game deleted.
- UHC.dll (sha256 0f6acd0a...), Startup\wol.cfg and uhc.cfg, UHC.log, Users3 (NewProfile3.xml, LastProfile3.dat and
  its backups) and Savegame\LastHomeCityY.xml, sp_Perquenco and sp_Riyadh put back from the backup. A SHA-256
  snapshot of data, Startup, translations, art\ui, art\WoL\ui, art\WoL\units\cavalry_ranged, art\effects, AI4, RM4,
  uhc.dll, wol.dll and Users3, plus a size listing of the whole bed (72,134 lines), is identical before and after.
- Video settings 1920 x 1080, windowed, AA 2, shadows 3 (testbed profile video, exit 0); optionminimizedui true;
  LastSelectedSPHC sp_Perquenco_homecity.xml as before. Steam WoL exe and uhc.dll: the known builds.
- Not restored: the game's own Age3Log.txt, RecentFilesy.xml and similar files in the bed's My Games folder.
