Final check of the 2026-11-25 round (joint smoke test, agent J)
==============================================================

Branch claude/r1125-smoke = claude/editor-menu-20261125 (1c2c3235: displayedRange live menu switch, editorSearch
trigger list + taller lists, editorAutosave, selectFattened, nurseryFactor with the shared AutoGather rate hook,
QUICK-ARRIVAL caps, oil panel --rates spacing) + merge of claude/wol-feedback-20261124 (58a11908: gatling camel
rounds 4/5, turretArc), then two fixes found by this test (below).

Build: Release Win32, 0 errors; 3 warnings, all old (minuistats.cpp C4456 x2 and a C4244 from <xutility>, the same
on origin/main; minuistats.cpp is unchanged by this round). src/generated/sites.h regenerated: unchanged (942 sites,
the merge had already joined both SITES lists). Porting pages regenerated; guide_dates, export_public --check pass.
Tested UHC.dll: commit 1660a475, sha256 5feec5e23f05d51bc7d0f6940085a003d94e5044af2e4b4ae1912d70a5619f8b.

Merge of claude/wol-feedback-20261124 (how the camel PR will merge after the editor/menu PR)
--------------------------------------------------------------------------------------------
Three conflicts, all text; the code (src/, CMakeLists.txt, gen_sites.py, features.h, sites.h, CLAUDE.md,
uhc.cfg, package_release.py, porting_code.py) merged on its own:
- docs/modding-guide.md, "Latest changes": both sides added rows at the top. Kept every row by time (turretArc
  11-25 08:53 first, then nurseryFactor, selectFattened, editorAutosave, editorSearch, displayedRange 11-25 07:55)
  and dropped the camel branch's older displayedRange row (11-24 09:53): one row per key.
- docs/wol-requests.md rows #102 and #103: #102 from the camel branch (it adds rounds 3-5 and the status
  "confirmed in WoL (2026-11-25"); #103 from editor-menu (it adds agent U's themed-UI cost note).
- tools/gifs.txt: both lists of cuts kept (editorAutosave/selectFattened and turretArc-wol-control).
Checked after the merge: turretArc's sites (0x48AA9F, 0x4995D5) and the Granny IAT slot 0xB847AC are written by no
other key; kFeatures and kHandledKeys have turretArc once.

Bed and cfg
-----------
C:\AoE3-UHC-WoLReal5 (its own profile), English tables, single player, no other age3y.exe running during any test
(tasklist / testbed game_processes checked).
wol.cfg (this folder): the bed's wol.cfg (WoL keys) after the packs, plus every key line of examples/Startup/uhc.cfg:
163 keys, 175 lines. Left out: faithResource (optional), preloadDll and lanAutoStart (other builds), firstTC (alias
of civFirstTC). Set for this check: multipleInstances background, veterancyBonus notext, ageUpBuildings Market,
displayedRange log, incomeRates log, nurseryFactor log, editorSearch log, editorAutosave 5 keep 3 log, menuOptions
displayedRange, techGadgets log + the 12 GreatWarizeALL lines of the oil panel, turretArc with the camel pack's two
aim files + log. Packs applied: oil-panel --rates, select-fattened, options-menu, editor, gatling-camel, min-ui;
tools\rings in art\effects\uhc_rings; AI: wolOtto only (ai_personality.py).

Result table
------------
Check                                   Result
--------------------------------------  -----------------------------------------------------------------------------
1. Keys                                 PASS after two fixes: "UHCMain: 146 applied, 0 failed" (163 keys; the 6 WoL
                                        keys "not implemented yet; ignored" as before) in every launch.
                                        First launch, with the merge as it was: "145 applied, 1 failed":
                                          tech subtypes: no room for FreeHomeCityUnitByNurseryFactor
                                          nurseryFactor: FAILED
                                        Cause: the shared tech subtype table (src/techsubtypes.cpp) held 32; with
                                        every key on, 33 names register, and nurseryFactor's fifth was the 33rd.
                                        Fix 38ff4e38: kMaxSubtypes 64 (IDs are 0x100 + index, the hooks check only
                                        the lower bound). Note: Add() has no rollback, so a key that fails half way
                                        leaves its first subtypes registered (nurseryFactor's four, here).
                                        Also, not a FAILED but a silent downgrade: "selectFattened: too many
                                        Direct3D observers" (src/d3d9hooks.cpp held 4; seven keys observe the
                                        device), so its button was set only from the world update. Fix 1660a475:
                                        kMaxObservers 8. After both: no "too many" / "no room" line.
                                        Hooks reached in these scenes (UHC.log, UHC-hotkey.log; 185 distinct):
                                        "AutoGather rate filters (0x49EBE4)" (the new shared hook), "turretArc
                                        facing (0x48AA9F)" and "turretArc launch (0x4995D5)" (skirmish units),
                                        "displayedRange: proto flag parser's last compare (0x5F726F)", "editorSearch:
                                        allowed units entry (0x9991D0)", "incomeRates add (0x49A98A)", "selectFattened
                                        uhcSelectFattened (player 1: 5 fattened)", "betterfreedynamicunit (0x8D8C88)",
                                        "shipmentCounts (0x8584FF)", "tech subtype on a player (0x8D843E)".
                                        Not exercised by these scenes (no data or no screen for them): nurseryFactor's
                                        own rows and ticks (no NurseryFactor* proto), editorAutosave (editor open
                                        < 5 min), the options menu, turretArc's Granny observer (no camel on the
                                        map), the displayedRange rings.
2. AI plays                             PASS. Skirmish, Greeks (sp_Athens) against wolOtto (Germans), background,
                                        425 s of game time: player 2 had 17 Settlers + TC + Manor at 218 s and
                                        19 Settlers, 4 Peasants, 3 Manors, TC, Explorer at 425 s; no "XS: Error",
                                        no "Error 0003" (xsErrorLog on: only its own two lines). No crash; the
                                        game closed by testbed close ("perfStats: exit").   s1-skirmish-greeks-425s.jpg
3. autoGatherScaleByContained           PASS. Now a filter on the shared AutoGather rate hook (autogatherrate.*).
   regression                           Scene (scenario uhcj25, Ethiopian player 1): the guide's test data, an
                                        AutoGather of 0.25 gold with <scalebycontainedunits>1 on the Blockhouse
                                        (data\tactics\blockhouse.tactics, removed after); 2 Settlers garrisoned
                                        at 10 s, 2 more at 70 s, 2 more at 130 s, all ejected at 190 s (Unit
                                        Immediate Garrison / Ungarrison triggers). Gold read from the game every
                                        5 s (gold-*.txt), rate per phase:
                                          inside   key on, cap 3   key on, no cap   key off (nurseryFactor on)
                                          2        0.492/s         0.497/s          0.251/s
                                          4        0.754/s (cap)   0.995/s          0.254/s
                                          6        0.746/s (cap)   1.516/s          0.252/s
                                          0        0.000/s         0.000/s          0.252/s
                                        The guide's numbers: 0.50/s with 2, 1/s with 4, 0.75/s with 6 and a cap of
                                        3, nothing empty; 0.25/s always without the key: all match (within the
                                        5 s sampling). With the key off and nurseryFactor on, the shared hook gives
                                        the stock rate. incomeRates' log counted the Blockhouse as AutoGather
                                        (42.4 gold in a 60 s window, stockpile +42.4).        s2-autogather-key-off.jpg
4. shipmentCounts vs                    No FAILED: both "applied". shipmentCounts comes first in kFeatures (it
   betterfreedynamicunit (0x8D8C62)     verifies FreeHomeCityUnitCase 0x8D8C62..0x8D8D23 while it is stock), then
                                        betterfreedynamicunit writes its jmp at 0x8D8C88 (53 B, inside that range;
                                        0x8D8C6F is where WoL's own DLL patches the same computation). In the
                                        skirmish both ran in the same case: "tech subtype on a player (0x8D843E)",
                                        "betterfreedynamicunit (0x8D8C88)", "amount -0.800 at 3.42 steps of 2 min
                                        -> 2.734". So the conflict is latent: it bites (shipmentCounts FAILED,
                                        "site FreeHomeCityUnitCase at 0x008D8C62 does not hold the stock bytes")
                                        (a) if betterfreedynamicunit is ever moved before shipmentCounts in
                                        kFeatures, and (b) already today with our dinput8.dll beside WoL's DLL,
                                        which patches 0x8D8C6F (the guide's shipmentCounts section notes it).
                                        shipmentCounts is the key that loses. Fix (not made): verify only what it
                                        needs, i.e. split the site into the case head 0x8D8C62..0x8D8C6E and the
                                        tail from 0x8D8CBD to the spawn call, leaving the dynamic-amount
                                        computation 0x8D8C6F..0x8D8CBC to whoever patches it (it runs only for a
                                        negative amount); at least, an order rule in CLAUDE.md.
5. Games closing on their own           None. Every game ran until testbed close (7 launches, 09:04-09:27; each
                                        "perfStats: exit" follows a close of ours). No other copy was running.
6. selectFattened hotkey (real input)   PASS. No other age3y.exe running (tasklist, game_processes = []), so the
                                        game ran in the foreground with "multipleInstances" (no background) and
                                        "selectFattened log". Scenario: 5 ypGoatFat (Fattened Goat) and 3 Sheep of
                                        player 1, 3 ypGoatFat of player 2. The button showed 5. testbed rkey
                                        shift+ctrl+f: "player 1, 5 fattened, 5 selected (limit 75), selection now
                                        5"; the panel shows Fattened Goat, Player 1. Then a click on empty ground
                                        (selection cleared) and a click on the button: the same line, 5 selected.
                                        The Sheep and player 2's goats were not selected.  s3-fattened-before-hotkey.png,
                                                                                            s4-fattened-after-shift-ctrl-f.png
7. Restore                              PASS, see below

Restore
-------
- Packs --restore (min-ui, gatling-camel, editor, options-menu, oil-panel, select-fattened); rings, the
  blockhouse.tactics test lines, the RM4 test maps uhcj25/uhcj25k and the scenarios removed; AI personalities back
  (51); UHC.dll (sha256 0f6acd0a...), Startup\*, UHC.log, Users3 and Savegame put back from the backup.
- Pack order: select-fattened README says to restore the oil pack first when both are applied; done that way after
  applying oil first, select-fattened's backup (taken with oil applied) put the oil versions of data\uimainnew.xml
  and the three stringtabley.xml back. Fixed by hand: uimainnew.xml from C:\AoE3-UHC-WoLReal (same sha256 as this
  bed's original), and the five oil strings 1010111-1010116 removed from the three tables, written only when the
  result matched the original sha256. Rule that works: restore in the reverse order of applying. (The README line
  holds when select-fattened was applied first.)
- A SHA-256 snapshot of data, Startup, translations, art\ui, art\WoL\ui, art\WoL\units\cavalry_ranged, art\effects,
  AI4, RM4, trigger3, uhc.dll, wol.dll and the profile's Users3, Savegame and Scenario, plus a size listing of the
  whole bed (72,210 lines), is identical before and after.
- Video settings 1920 x 1080, windowed, AA 2, shadows 3; LastSelectedSPHC sp_Perquenco as before; optionminimizedui
  true. Steam WoL exe and uhc.dll: the known builds.
- Not restored: the game's own Age3Log.txt, RecentFilesy.xml and similar files in the bed's My Games folder.

Files
-----
wol.cfg                                   the cfg of the tests (the control run had autoGatherScaleByContained
                                          commented; the hotkey run had multipleInstances without background and
                                          selectFattened log)
UHC.log                                   four launches with the final build: skirmish, scenario key on (cap 3), key off, key on (no cap)
UHC-hotkey.log                            the foreground hotkey run
UHC-before-fix-nurseryFactor-FAILED.log   the first launch, before the subtype fix
gold-key-on-cap3.txt, gold-key-off.txt, gold-key-on-nocap.txt   the gold samples of check 3
