Final check of the 2026-11-26 round (joint smoke test, agent J2)
================================================================

Branch claude/r1126-smoke = claude/round-20261126 (8f0f81ce: the observer's 36 maps, layouts and presets, the
trigger-names pack, gatling camel round 6 (turretArc aim file v2), the progress pie, garrisonConvert, select-fattened
--hotkey-only, nurseryFactor v2 (stat panel rows, garrison rule, command buttons), the zamburak pack with turretArc on
MEZamburak). No code change was needed.

Build: Release Win32, 0 errors; warnings all old (minuistats.cpp C4456 x2, a C4244 from <xutility>, LNK4104 x4 on
engineext.def). src/generated/sites.h regenerated: unchanged (955 sites). Porting pages regenerated: unchanged
(line endings only). guide_dates "nothing to change", export_public --check OK (364 files).
Tested UHC.dll / dinput8.dll: this build, UHC.dll sha256 b7d56332deb48e0718a8088eec10dbef8ab0f223a174736f884df07eca13a4f9.

Beds (several at once, as asked; never more than two or three games together, 12-14 GB free before each launch;
WoLReal, WoLReal2, 3 and 4 not touched)
--------------------------------------------------------------------------------------------------------------------
- C:\AoE3-UHC-WoLReal5 (own profile, English, our UHC.dll): every pack of the round applied in this order: oil-panel
  --rates, select-fattened --hotkey-only, options-menu, editor, gatling-camel, zamburak, trigger-names, observer maps
  (observer_maps.py apply), observer UI (observer_ui.py apply --from ui). Then the cfg of this folder (wol.cfg: the bed's
  wol.cfg after the packs + every key line of examples/Startup/uhc.cfg, 164 keys, 178 lines; left out as before:
  faithResource, preloadDll, lanAutoStart, firstTC). Set for this check: overhealHitpointBars AbstractOverheal segment
  stat log, garrisonConvert log, nurseryFactor log, turretArc with three pairs (GatlingCamel A55, GatlingCamelDeployed
  B55, MEZamburak zamburak_cannon.aim) + log, multipleInstances background (no background for check 3).
  Test data (removed after): a Bank as a nursery (exponential, base 2, every 8 s, cap 10, ypGoat taken for 3, a
  SellMinks command: -4 minks, 2 CrateofCoin), the Blockhouse with <GarrisonConvertTo delay="5">Pikeman, the Musketeer
  marked AbstractOverheal with MaxHitpoints 180 (AbstractOverheal added to data\uhc\customabstracttypes.xml).
  Profile: optionminimizedui false for the stat panel rows (put back after).
- C:\AoE3-UHC-WoLReal6 (own profile, English, our UHC.dll): the autoGatherScaleByContained regression. cfg = the same
  key list without the pack-dependent lines (turretArc, the GreatWarizeALL techGadgets lines).
- C:\AoE3-UHC-WoLReal7 (own profile, our UHC.dll, bed cfg + xsErrorLog): Spanish (translations\ES-LA\stringtabley.xml
  in data\) + the trigger-names pack.
- C:\AoE3-UHC-WoLReal8 (own profile): turned for the observer check into WoL's own setup: WoL's uhc.dll (c070d138, from
  C:\WoL-Test), our dinput8.dll with engine-ext\engine-ext.cfg (perfExecFile, multipleInstances background,
  xsErrorLog, perfStats), the observer maps with --emulate-observer (test only) and the rebuilt observer UI, and the
  1920x1080 observer layout + the 7 observer panels copied over the normal names (what WoL's DLL does for a local
  observer). rmIsObserverMode is WoL's DLL's syscall (docs/wol-uhc-map.md); our UHC.dll does not register it, so the
  repaired maps need WoL's DLL, as the observer README says.

Result table
------------
Check                                   Result
--------------------------------------  ----------------------------------------------------------------------------
1. Keys, every pack applied             PASS. "UHCMain: 147 applied, 0 failed" (164 keys; the 6 WoL keys "not
   (WoLReal5)                           implemented yet; ignored" as before) in each of the 5 launches. Last round:
                                        146; +1 = garrisonConvert. No "too many" / "no room" line.
                                        Hooks reached (151 distinct in the two scenario logs), the new ones each in a
                                        scene that uses it:
                                          garrison entries (0x9C26E1): 3 Settlers ordered into the Blockhouse became
                                            Pikemen one every 5 s (10998, 15998, 20998 ms); 2 goats into the Bank were
                                            taken (3 -> 6 -> 9/10);
                                          stat panel rows (0x4D76DB): normal interface, the Bank shows "10/10 minks"
                                            right under Hitpoints (s03), the Musketeer "Overheal 0/30" (s04);
                                          nurseryFactor command (0x7D64F7): nurseryFactorCommand("SellMinks") from the
                                            console with the Bank selected: "10 -> 6/10, 2 unit(s) of proto 426 made",
                                            two crates of coin beside the Bank (s02);
                                          unit panel tail (0x4C8281) + the progress pie: the blue pie over the Bank's
                                            portrait while it grows again after the sale (s02);
                                          turretArc facing (0x48AA9F) and launch (0x4995D5), on both units: the
                                            gatling camels (units 8, 9: "aims at ... the gun turns", shots at yaw -87 to
                                            -90) and, in a second scene, the two MEZamburak (units 0, 1: Granny parts
                                            found, "shot, yaw 84.0 / 86.3 / 94.6") and GatlingCamelDeployed (unit 2,
                                            shots at yaw 85-97) (s05);
                                          AutoGather rate filters (0x49EBE4), resourceDebt AutoGather gate/rate.
                                        Note: the console call worked only from a second exec after the selection: in
                                        the same exec batch as uiLookAtAndSelectUnit the selection was still empty
                                        (nothing logged, nothing sent). The buttons are the normal way; not a bug.
2. AI alive, zamburak pack applied      PASS. Skirmish on Acre (the bed profile's map), human Uzbeks (sp_Bukhara: a
   (WoLReal5, all packs)                civ with MEZamburak, so its new tactics file was loaded), AI wolNapoleon
                                        (French, the only personality left), background, 428 s of game time. Player 2:
                                        14 units at 1 min, 18 at 3, 23 at 4, 26 at 5, 29 at 6 and 7; WOLPiedNoir
                                        villagers 9 at 3 min, 16 at 7 min, houses 2 -> 3. UHC.log with xsErrorLog: no
                                        "XS" line (only its own two lines), no "Error 0003"; trace_xs.py over the last
                                        2 minutes: 0 lines. zamburakCannon.tactics in the bed: 92 CRLF, 0 bare LF
                                        (GatlingCamel.tactics 63 / 0). No crash. (The AI did not grow past 29 units
                                        between minutes 6 and 7; it was still alive and building.)   s06
3. Zamburak: real right click           PASS. Alone (tasklist: no other age3y.exe), cfg "multipleInstances" without
   (WoLReal5, foreground)               background. Scenario: one MEZamburak (limbered, as trained) and an enemy House
                                        at 10 m. With the zamburak selected, a real right click (testbed rclick ...
                                        right) on the House: the tactic switched to Bombard (the unlimber button now
                                        ticked), the artillerist got off and stood at the breech, turretArc logged
                                        "the unit turns until it sits at the rest yaw", and it fired: House 1200 ->
                                        1095 HP in 15 s.   s09 (before), s10 (15 s after)
                                        The same with a trigger's work order (trUnitDoWorkOnUnit) in the turretArc
                                        scene: both zamburaks unlimbered and fired. An attack-move (the map's go1)
                                        did NOT unlimber them: they stayed limbered and idle beside the Houses (the
                                        stock field-gun pattern; to note for WoL's team, not a regression).
4a. autoGatherScaleByContained          PASS. Same method as 2026-11-25 (scenario uhcj26g, Ethiopians: a Blockhouse
    (WoLReal6)                          with the guide's AutoGather of 0.25 gold and <scalebycontainedunits>1, no
                                        cap; 2 Settlers in at 10 s, 2 more at 70 s, 2 more at 130 s, all out at 190 s;
                                        gold read every 5 s):
                                          inside   key on     key off (nurseryFactor on)
                                          2        0.498/s    0.246/s
                                          4        1.002/s    0.246/s
                                          6        1.534/s    0.255/s
                                          0        0.000/s    0.249/s
                                        The guide's 0.50, 1, 1.5 and 0 with the key, 0.25 without.   gold-key-*.txt, s07
                                        In this bed "techGadgets: FAILED" (142 applied, 1 failed): a cfg artifact,
                                        "techGadgets log" was left with no rule after the oil-panel lines were taken
                                        out ("no rule; not applied"). Not a code fault.
4b. overheal stat row, normal UI        PASS. Musketeer (AbstractOverheal, 150/180): "Hitpoints 150/150",
                                        "Overheal 0/30" right below, in the normal interface's stat panel; log
                                        "overhealHitpointBars: stat row 2 of unit 7 (Musketeer): overheal 0/30". It
                                        shares the stat panel hook with nurseryFactor's row (s03 / s04).
4c. Observer map, observer mode,        PASS. ESOC_Arizona, 2v2 + 2 observers (--team-list 1,1,2,2,3,3,
    new layouts (WoLReal8)              gamecampaignshownhcnote=true), AIs wolOtto, wolVictoria, wolCarlos, wolIsabel,
                                        wolWilliam, 1920x1080, twice (90 s and 150 s): "ok", 0 XS errors (xsErrorLog
                                        in engine-ext.log), every real player 14-15 units, each observer only its bat
                                        (p5:1 p6:1). The panel deployed on the rebuilt layout: WoL's flags (French,
                                        Dutch, British, Portuguese), the economic population bar by type, the player
                                        rows with WoL's units.   s08
4d. Spanish + accented AI name,         PASS. WoLReal7 in Spanish, 3 players (WallMapu human, wolCarlos = "Carlos el
    trigger-names pack (WoLReal7)       Diplomático", Portuguese, and wolOtto), mapsweep skirmish route, 60 s each:
                                        ESOC_Adirondacks ok, Arabia ok, 0 XS errors; each trigtemp.xs has the 6
                                        messages as ""+kbGetPlayerName(N)+" has ..." and no literal name.
                                        trigger-names-es.csv
5. Games closing on their own           None. Every game ended by testbed close or mapsweep (WoLReal5: 5 launches,
                                        WoLReal6: 2, WoLReal7: 2, WoLReal8: 2).

Problems found
--------------
- None in the code. Two notes for the docs or WoL's team:
  - an attack-move does not unlimber the zamburak (or a GatlingCamelDeployed left limbered); a right click or a work
    order does;
  - the observer maps call rmIsObserverMode(), which only WoL's own uhc.dll registers; with our UHC.dll in its place
    (as in our WoLReal beds) those 36 maps would not compile (the observer README already says the switch is WoL's).

Restore
-------
- WoLReal5: test data back (j2-orig files), the RM4 test maps removed, packs restored in the reverse order of
  applying (observer UI, observer maps, trigger-names, zamburak, gatling-camel, editor, options-menu,
  select-fattened, oil-panel), AI personalities back (51), Startup\wol.cfg, Users3 and the game's own files in its
  My Games folder put back (the RM dumps of the test maps removed).
- WoLReal6: test data back, the map removed, uhc.dll, Startup, UHC.log and the game's own files in its My Games
  folder (Age3Log.txt, RecentFilesy.xml, trigtemp.xs; the new Age3RMuhcj26g.dmp.txt removed) put back.
- WoLReal7: the string table, the trigger-names pack, uhc.dll, Startup, UHC.log, and the game's own files put back.
- WoLReal8: the swap, the observer UI and maps reverted, engine-ext\ and dinput8.dll removed, its own uhc.dll,
  Startup, UHC.log and the game's own files put back; the AI memory file wolIsabel.personality the run created removed.
- A SHA-256 listing of every file of each bed and of its own My Games folder (65,732-65,747 files each, profiles,
  home cities and video settings included), taken before the first change, is identical after for WoLReal6, 7 and 8,
  and for WoLReal5 except two files:
  - uhc.dll: the bed held a dev build left by an earlier test (sha256 305f70a7..., 1,574,400 B). My backup of the bed
    was taken after the first `testbed deploy`, so it held this round's build, and no copy of 305f70a7 exists on the
    PC (every UHC.dll of that size searched). The bed now has its documented baseline 0f6acd0a (the WoLReal5 backups
    of 2026-11-22 and the 2026-11-25 check), not the byte-for-byte previous file. Any later deploy replaces it.
  - UHC.log: that earlier test's runtime log (14:24) is gone: testbed deploy deletes the log before launch.
- Steam: the stock age3y.exe is the stock build (testbed safety check).

Files
-----
wol.cfg                                      the cfg of WoLReal5 (all keys, all packs)
UHC-scenario-nursery-garrison-overheal.log   WoLReal5, first scenario (147 applied)
UHC-scenario-turretarc.log                   WoLReal5, the zamburak / GatlingCamelDeployed scene
UHC-skirmish.log                             WoLReal5, the 428 s skirmish against the French AI
UHC-rightclick.log                           WoLReal5, the foreground right-click test
UHC-autogather-on.log, -off.log, gold-key-on.txt, gold-key-off.txt   WoLReal6
UHC-trigger-names-es.log, trigger-names-es.csv                       WoLReal7 (log of the last run, Arabia)
engine-ext-observer.log, observer-shot.csv                           WoLReal8
s01-s10 *.jpg                                pictures named in the table
