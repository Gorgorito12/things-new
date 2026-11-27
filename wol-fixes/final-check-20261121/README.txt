Final check of the 2026-11-21 round (joint smoke test before main)
==================================================================

Build: branch claude/wol-feedback-20261121 at 9e571f0, build\Release\UHC.dll sha256 3c061b06...df028a1.
Bed: C:\AoE3-UHC-WoLReal2 (its own profile), multipleInstances background, English tables (lang en: already the
English originals), single player. Player: Zulu (Bulawayo). AI: wolOtto (Germans), the only personality left.
cfg: the bed's wol.cfg (WoL keys) + every key line of examples/Startup/uhc.cfg, as in final-check-20261120,
with veterancyBonus notext; 143 keys. Packs applied: min-ui (v7), special-transforms (with the kraal dance anims),
paraguayan-works fix zip; tools\rings copied to art\effects\uhc_rings.

Result table
------------
Check                                   Result                                              Files
--------------------------------------  --------------------------------------------------  ----------------------------
Keys                                    PASS: UHCMain: 126 applied, 0 failed (143 keys;     UHC.log
                                        6 WoL keys "not implemented yet; ignored" as before)
veterancyBonus notext                   applied: "rank marks on; no rank text (notext)";     UHC.log
                                        kill observer reached (0x4D4F37). No unit of mine
                                        got a rank in this game: marks not seen here
transformChecks                         applied; command panel hook reached. Youths         s3-youth-transform-button-
                                        (spawnUnits from the TC) far from a kraal: the 4     grey-reason.jpg
                                        maturing buttons grey, tooltip in red "This unit
                                        must be matured near a Gunpowder Kraal."
                                        Cost-only case NOT tested (needs a kraal built)
minUIStats v7 + showGatherRate          PASS: villager on wood: "Wood (icon): 0.50/s",       s1-villager-gathering.jpg,
                                        armor "20%"; Askari: armor "30%", multipliers        s1-...-panel.png,
                                        "2.5x"/"0.75x" with the unit-type icons, ROF 3/1.50, s2-soldier-askari.jpg,
                                        LOS/speed/train time on the right. Askari also       s2-...-panel.png
                                        shows a right-column "Hand ATK 8 / 1.50": its 4th
                                        attack (rifleman.tactics has Volley-, Defend-,
                                        Stagger- and MeleeHandAttack), inferred, not checked
Paraguayan works                        files in place and restored; no works built in this  -
                                        game (smoke only: the game loaded and ran)
AI plays                                PASS: 15 units at 8 s, 24 at 285 s, 26 at 346 s,      s4-late-407s.jpg
                                        30 at 407 s (18 Settlers, 4 Peasants, 3 Manors);
                                        greeted in chat; no XS error (xsErrorLog on)
Crash                                   none: 407 s of game time, clean exit                 UHC.log (perfStats exit line)
Restore                                 PASS, see below

Villager orders: uiLookAtAndSelectUnit(villager), uiLookAtUnit(tree), a posted hover at the view centre, then
uiWorkAtPointer() made it gather (wood rose 500 -> 673). spawnUnits("<proto>", n, <building ID>) made the youths and
the Askari (the console help: "spawnUnits(protoname, count, unitID): Spawn Units from the UnitID building").

Restore
-------
- special-transforms and min-ui: --restore; works: the originals zip unzipped and the two new works_smoke files
  deleted; art\effects\uhc_rings removed; AI personalities: ai_personality.py restore (52 back).
- UHC.dll, Startup\wol.cfg, UHC.log, NewProfile3.xml, LastProfile3.dat, LastHomeCityY.xml and
  sp_Bulawayo_homecity.xml put back from the backup. A SHA-256 snapshot of data\ (+ data\uhc), Startup,
  translations\_originals, art\WoL\buildings\works, art\ui\ingame, art\WoL\ui\ingame\staticons, art\effects, the
  maturing anims, AI4, Users3 and UHC.dll, plus a size listing of the whole bed, is identical before and after.
- Video settings 1920 x 1080, windowed, AA 2, shadows 3; optionminimizedui true; LastSelectedSPHC Perquenco.
- Not restored: the game's own Age3Log.txt, RecentFilesy.xml and similar files in the bed's My Games folder.
