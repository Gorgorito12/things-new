Final check of the 2026-11-28 round (joint smoke test, agent J)
================================================================

Branch claude/round-20261128 = origin/main 538eefe7 (release 0.6.0) + claude/r1128-R (UI coverage rules, review of
researchGrants / shipTechLimit, AddTechRolloverLine moved to the builder's exit 0x4C78F3), -K (the cultureUI key, its
pack and test-style script, WoL #112), -H (hammer fanning: the muzzle flash at the barrel's tip, particle set
fanningshot, powerShots-wol filmed again) and -T (the Photoshop templates zip, its README and reference sheet).
No code change in this check.

Build: Release Win32, 0 errors. Warnings: the old ones (minuistats.cpp C4456 x2 and C4244, LNK4104 x4 on
engineext.def) and one new C4244 in cultureui.cpp line 387 (a wide suffix narrowed for a log message; the suffixes are
ASCII: harmless). _UHCMain@0 exported. src/generated/sites.h regenerated from the stock exe: identical to the merged
file (984 sites). Porting pages regenerated (no content change). guide_dates, export_public --check (368 files) and
make_gifs --check (400 GIFs) pass.
Tested UHC.dll sha256: fdf97fbe64ddf2e10b498cc8643e61fdac49b23fe517ab6b3063173f1e560252

Bed
---
C:\AoE3-UHC-WoLReal5 (own profile, multipleInstances background, posted input only; another session's game ran in
WoLReal8 beside it and was not touched). Packs, in this order: wol-fixes/hammer-fanning, then wol-fixes/culture-ui
with --styles: make_test_styles.py's provisional recolours (as, as_gw, me, me_gw) plus, for this test only, the me
and me_gw files copied as eu and eu_gw, so that a European civ shows a style (turquoise; the Great War look khaki).
cfg (wol.cfg here): the bed's own lines, the packs' lines (retargetInAction log, powerShots log, cultureUI), and every
key line of examples/Startup/uhc.cfg as in 2026-11-27's check, without the lines that need packs not applied this time
(turretArc and the twelve techGadgets GreatWarizeALL rules of the oil-panel pack), plus selectFattened,
displayedRange, editorSearch; 164 keys. AI: wolOtto (Germans) the only personality left. Human: British
(sp_London).

Result table
------------
Check                                   Result
--------------------------------------  ----------------------------------------------------------------------------
1. Keys (skirmish launch)               "UHCMain: 147 applied, 1 failed": the failure is techGadgets, "no rule; not
                                        applied" (only "techGadgets log" was left once the oil-panel rules were
                                        taken out: a cfg artifact, not a regression). The 6 WoL keys "not
                                        implemented yet; ignored" as before.
   (scenario launch, that line          "UHCMain: 147 applied, 0 failed".
   commented out)
2. Hooks reached                        201 distinct "hook reached" lines over the two runs. This round's:
                                        cultureUI HUD build (0x76166A), cultureUI texture bind (0x407D27), tech
                                        rollover (0x4C78F3) with "tech rollover: first rollover built for the
                                        command panel (0x4622C5)", researchGrants tech rollover cost (0x4C73FD),
                                        powerShots (0x4B7766), retargetInAction (0x487838).
3. cultureUI                            PASS. "style eu (10 texture(s))" for the British; the minimised HUD drawn
                                        with the eu test textures from the first frame (resource panel, minimap
                                        frame, command and unit panels), the resource icons kept.           s01
4. Tech rollover at the new exit hook   PASS. Town Center selected, a posted hover on its Age II button: the
                                        rollover "Advance to the National Age, 800 food" (red, not affordable),
                                        drawn whole over the styled HUD. No key had data for a line of its own
                                        here (no <ShipTechLimit>, no grant building), so the frame shows the
                                        stock text; R's tests have the lines.                                s02
5. AI alive (skirmish)                  PASS. British (idle) against wolOtto (Germans), 474 s of game time. Player
                                        2 units at 170 s 18, then 23, 25, 26, 27, 28 at 474 s; Settlers 12 -> 19;
                                        3 Manors, a Mill. No XS line in UHC.log (xsErrorLog on), no "Error 0003".
                                        No crash.                                                            s03
6. powerShots + retargetInAction with   PASS. Test map uhcj28a (scenario route): an Explorer and 6 Gaia
   the hammer-fanning pack (scenario)   OutlawPistol guardians (270 HP). One use of Hammer Fanning
                                        (ability(99, 0, true), a posted click on a guardian): 6 shots from 20318 to
                                        21717 ms (about 280 ms apart), each after retargetInAction found the next
                                        guardian (7.2 to 13.4 m); powerShots logged "Attack tag after N of 6 shots
                                        ... fires" for shots 2 to 6; all six guardians dead, the Explorer at
                                        400/400 HP. Then "no other target in range".
7. Games closing on their own           None.

Not tested here: the Great War switch of cultureUI (K's tests), the native and trade route panels (R's tests),
multiplayer. The flash's place was checked by H in game (c1-ingame-flash.jpg), not again here.

aoe3-blender-tools (branch claude/round-20261128 = origin/main 69adddb + claude/r1128-T + claude/r1128-H, merged
with no conflict): tests/run_tests.py "all tests passed", and each of the 62 tests/test_*.py exits 0.

Restore
-------
Packs restored in the reverse order (culture-ui, then hammer-fanning), AI personalities back (51), the test map
(RM4\uhcj28a.xs/.xml) removed, the scenario removed by testbed close, Startup\ and uhc.dll put back from a copy taken
before, UHC.log and uhc-exec.txt removed (the bed had neither), the My Games folder (profile, home city choice, logs)
put back from a copy taken before. A SHA-256 listing of every file of the bed and its My Games folder, taken before
the first change, is identical after (see the line below).
Result: the bed's 65,253 files identical (the only extra file after the packs' restore, UHC.log, removed); the My
Games folder's 488 files identical after putting back the seven files the games rewrote (Age3Log.txt,
RecentFilesy.xml, RM4\Age3RMacre.dmp.txt, Savegame\LastHomeCityY.xml and sp_London_homecity.xml, Trigger3\
trigtemp.xs, Users3\NewProfile3.xml) and removing RM4\Age3RMuhcj28a.dmp.txt. Video settings: 1920 x 1080, windowed,
AA 2, shadows 3.

Files
-----
wol.cfg                 the cfg of the skirmish (the scenario had "techGadgets log" commented out)
UHC-both-runs.log       the skirmish's UHC.log, then the scenario's
skirmish.txt            the skirmish, minute by minute
s01-s03 *.jpg           pictures named in the table
