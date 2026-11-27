Final check of the 2026-11-20 round (agent F)
============================================

Bed: C:\AoE3-UHC-WoLReal (our UHC.dll) and C:\WoL-Test (WoL's uhc.dll c070d138 + our dinput8.dll), single player,
1920 x 1080 windowed, English tables. Player: WallMapu (Perquenco). AI: wolOtto (Germans, moderate), map Acre.
Tasks 3 (Paraguayan works at low model detail) and 4 (politicians in Argentine/Mexican games) were moved to
other agents by the lead and are not in this folder.

Result table
------------
Test                                                        Result                                   Pictures / logs
----------------------------------------------------------  ---------------------------------------  ------------------------------------
1. testbed.py skirmish: each screen checked before a click   PASS: 4 of 4 runs reached the game      t1-1..t1-5
   (3 in WoLReal, 1 in WoL-Test), other copies starting at   (menu -> submenu -> home city ->
   the same time                                              setup -> game), no blind click
2a. Every key of the template + the bed's WoL keys, all      125 applied, 1 FAILED (transformChecks)  t2-UHC-allkeys.log
    packs applied, first build (642a78b)
    -> transformChecks FAILED: "site BuildLimitEntry at 0x004C7B5F does not hold the stock bytes":
       sharedBuildLimit hooks that site first. Fixed by the lead in 9ed3895.
2b. Same, rebuilt with fa6e3a6                               PASS: 126 applied, 0 failed              t2c-UHC-rebuilt.log,
                                                                                                      t2-rebuilt-0failed.jpg
2c. The AI plays                                             PASS: 39 units at 573 s game time; 17    t2-skirmish-late.jpg
                                                             at 188 s (rebuilt); no XS error
                                                             (xsErrorLog on)
2d. hook reached, new keys                                   autoScout, homeCityTechsInUnits (2),     the logs
                                                             researchOnTheMove (0x487E1B),
                                                             shipTechLimit (can-research, payment,
                                                             rollover), minUIStats (2),
                                                             veterancyBonus (kill observer)
                                                             NOT exercised: politicianEnablesTech
                                                             (WallMapu has no European age-up),
                                                             truckAttackResourceFix (no truck),
                                                             transformChecks (no transform button)
2e. shipTechLimit n/N                                        PASS: "Shipment techs: 0/10" (green)     t2-hcnativelore-tooltip.jpg
                                                             below the limit; with --limit 1, after   t2-shiptechlimit-at-limit.jpg
                                                             HCNativeLore: "1/1" on every council
                                                             button and the red line "the limit is
                                                             reached"
2f. HCNativeLore on a council unit                           PASS: paid "1 of 10", the button went    t2-wisewoman-panel.jpg,
                                                             away. With 0 ships it is refused (the    t2-wisewoman-after-hcnativelore.jpg,
                                                             button stays, count stays 0)             t2-72b-wisewoman-after.jpg
2g. Question 72b (deck card after HCNativeLore)              OPEN, see below                          t2-deck-empty-perquenco.jpg,
                                                                                                      t2-72b-deck-before/after.jpg
2h. Beside WoL's uhc.dll (dinput8.dll, every template key)   91 applied, 27 FAILED (WoL's sites);     t2d-engine-ext-beside-wol.log,
                                                             every new key applied; AI 21 units at    t2-beside-wol-uhcdll.jpg
                                                             212 s, no XS error
5. Restore                                                   PASS (see below)

FAILED beside WoL's uhc.dll (27)
--------------------------------
customAbstractTypes, removeConversionRestriction, ignoreRegistryPath, noAILimit/noAILimitV2, customRevolutionBanners,
removeFameRestriction, shipmentCounts, orPrereqsQty, techRenameEffect, farmingRadius, trainSingleAbstractType,
kbUnitSyscalls, customProtoUnitCommands, multiarmor, betterfreedynamicunit, nowalkfarm, repairWallGlobal, compatMode,
gatherFix, rofFix, stunMovingTargetFix, noDamageOnUnbuiltFoundations, fallenHeroTacticsFix, selectionLimit,
enableAllTeams, attackTypeIcons, customSyscalls/customCheats.
minUIStats applied but logs that WoL holds 0x698BFC (MinResistsArmorTest): no building armor row.

Question 72b
------------
- In WoL's data HCNativeLore is not a card of homecitymapuche.xml (the Mapuche home city has 6 cards), so no WallMapu
  deck can hold it, and the profile's Perquenco deck is empty (0/25).
- Test with the card added by hand (HCNativeLore and a control, HCShipWoodCrates1, in homecitymapuche.xml and in the
  Perquenco deck): the in-game deck panel said "Cards in Deck: 2/25" but drew no card in any age row, before and after
  the research, with 0 or 1 shipment. So the panel could not show it either way: probably my hand-made card entries
  were incomplete. The question stays open; it needs the team's own deck with the card.

Restore
-------
- Every pack --restore in both beds. WoLReal's data then matches C:\WoL-Test by hash (techtreey, protoy, civs,
  uipoliticianEuropeandlg, homecitymapuche, uiunitselectionmin, the works models and xml). The full file listings
  (size, time) of both beds match those taken before, except the bed's UHC.log, which was put back as found, and WoL-Test's
  ReShade.ini/.log (rewritten by ReShade on each start, same size).
- WoL-Test's data\stringtabley.xml: the packs write tooltips into the string table, and `lang en` ran after them, so
  `lang restore` put back the pack-edited Spanish file. It was replaced by the untouched original
  (C:\AoE3-UHC-WoLReal\data\stringtabley.xml.es-la, same size and date, 589C3AAE). Lesson: run `lang en` before
  any apply_fix.py.
- The UHC.dll and wol.cfg of WoLReal, the AI personalities of both beds, the dinput8.dll and engine-ext folder of WoL-Test:
  as before.
- Profile NewProfile3.xml byte-identical (66DCB4B7...), LastProfile3.dat, sp_Perquenco_homecity.xml and
  LastHomeCityY.xml put back; video settings 1920 x 1080, windowed, AA 2, shadows 3, optionminimizedui true.
- Not restored: Startup\persistenty.cfg in My Games (the game rewrites it; 3 lines), the RM4 *.dmp.txt dumps.
