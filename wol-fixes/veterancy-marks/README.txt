Veterancy rank marks (WoL request #74): the soutache knots of your approved sheet
=================================================================================

The marks over a unit with a veterancy rank are the five soutache knots of the sheet you approved
(reference-approved-hires.webp), traced from it:

    rank 1   copper   one tall loop like a cursive "l", its cord crossing near the bottom, both tails sweeping out
                      (the crossing is drawn symmetric, as approved)
    rank 2   silver   a round top loop on a stem, two eye-shaped side loops, a tail bar curving up at its ends
    rank 3   gold     the same with a pointed top loop
    rank 4   gold     a round top loop and two tiers of eye-shaped side loops
    rank 5   gold     a pointed top loop and two tiers
    No stars. A rank above the fifth keeps rank 5's mark.

Every mark is centred on the unit's HP bar and all five end at the same height above it. Measured in the game, default
camera, a Crossbowman and a Hussar at the screen's centre: see marks-ingame.png (the offset under each cut).

Files
-----
    reference-approved-hires.webp   your sheet (1536 x 1024, transparent background)
    compare-reference.png           your sheet (top), ours (middle), ours at 50 % over it (bottom), same scale
    marks-x4.png                    the five marks as the game's textures hold them, enlarged
    marks-ingame.png                the marks in the game at their real size, each cut around its HP bar, enlarged 3 times
    trace_marks.py                  the tracing: each mark cut by its alpha, made symmetric about its stem, its outline,
                                    metal edge and loop holes traced as smooth closed curves (traced\rank_N.json) and
                                    rendered with your sheet's colours under a dark border (traced\rank_N.png)
    traced\                         those curves and images, and shapes.json (pixels per glyph unit)

Overlap with your sheet (IoU, 1 = identical):
    rank                 1      2      3      4      5
    silhouette       0.985  0.995  0.992  0.995  0.991
    loop holes       0.990  0.983  0.953  0.958  0.968

How the files are made: python -I wol-fixes\veterancy-marks\trace_marks.py (needs numpy and Pillow), then
aoe3-blender-tools' tools\make_rings.py --out tools\rings --folder uhc_rings --rank-shapes wol-fixes\veterancy-marks\traced
writes the textures and particles of art\effects\uhc_rings (in the DLL's release zip). Nothing else changes.
