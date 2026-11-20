Veterancy rank marks as soutache knots (WoL request #74)
=======================================================

JTMaston: "use soutaches from Hussar uniforms: Rank1 - one single loop in bronze colour. Rank2 - Triloop in silver
colour. Rank3 - Pointed/spiked triloop in gold colour."

Version 7 (2026-11-20; not yet seen in the game): traced from the approved high-resolution sheet
(reference-approved-hires.webp, 1536 x 1024, transparent background). trace_marks.py cuts each mark by its alpha,
upscales it twice, makes it symmetric about the stem (the mark averaged with its mirror), traces the outline, the metal's
edge and every loop hole as smooth closed curves (traced/rank_N.json), and renders them with the sheet's own colours
(lightly blurred, made symmetric too) under a dark brown border (traced/rank_N.png). aoe3-blender-tools' make_rings.py
--rank-shapes places them in the sprites by the same rules as before (centred on the HP bar, the same bottom for every
rank) in 512-texel textures. Overlap with the sheet (IoU, 1 = identical):
    rank                         1      2      3      4      5
    silhouette               0.985  0.995  0.992  0.995  0.991
    loop holes               0.990  0.983  0.953  0.958  0.968
    (against the sheet made symmetric: silhouette 0.995 to 0.997, holes 0.982 to 0.997)
Left on purpose: rank 1's crossing, where the sheet lays one strand over the other, is drawn symmetric.
compare-reference.png: the sheet (top), ours (middle), ours at 50 % over the sheet (bottom), at the sheet's own scale.

Version 6 (2026-11-20, after the user's review of version 5; not yet seen in the game): ranks 2 and 4 rounder: their top
loop a full round ring, their side loops round-ended ovals, every join and end drawn twice as finely (a point every 0.02
glyph unit); the side loops' upper half fuller and their axis at the sheet's angle, measured on its loop holes (rank 3:
13 to 16 degrees down toward the tip, so the upper edge rises from the stem as on the sheet; ranks 2, 4, 5: 5 to 11); a
stronger light band. Fitted again to the sheet (IoU, rank 1 / 2 / 3 / 4 / 5):
    silhouette   0.938  0.937  0.923  0.936  0.923
    loop holes   0.866  0.719  0.599  0.597  0.455

Version 5 (2026-11-20): still our own drawing (nothing is cut from your sheet), now fitted to it. fit_marks.py cuts each
mark's silhouette out of the sheet as a measuring target only and adjusts our shapes (loop sizes and places, the side loops'
tilt, the stem, the tail bar, the cord's thickness) until they overlap. Overlap (IoU, 1 = identical) per rank, before and
after the fit:
    rank            1      2      3      4      5
    silhouette   0.889  0.545  0.551  0.568  0.577   before
                 0.915  0.911  0.920  0.907  0.927   after
    loop holes   0.806  0.098  0.026  0.032  0.005   before
                 0.854  0.616  0.588  0.454  0.528   after
Then, by eye against the sheet: the side loops 15 % shorter, plumper and tilted a little up from the stem, the tail bar's
ends curving up more, a light band along the top of each strand and its dark side underneath. That costs some overlap
(silhouettes 0.906, 0.820, 0.846, 0.792, 0.832; holes 0.821, 0.295, 0.265, 0.131, 0.108), since the sheet's eye holes are
long thin slits, but it reads closer to the sheet. The cord is smooth (soft edges, no stray light dots), and the textures
keep only their three largest levels so that the mark stays solid in the game. compare-reference.png: your sheet's row
above, ours below, same scale.

Version 4 (2026-11-20, the reference sheet you approved, reference-approved.webp): every mark is redrawn after it.
    rank 1   one tall loop like a cursive "l", the cord crossing itself near the bottom, both tails sweeping out;
             copper-bronze (DA8228, its light and dark tones sampled from the sheet)
    rank 2   a round top loop on a straight central stem, two eye-shaped side loops, and a tail bar under them whose ends
             curve up; silver
    rank 3   the same with a pointed (flame) top loop; gold
    rank 4   the round top loop and four eye-shaped side loops in two tiers on the stem, then the tail bar; gold
    rank 5   the same with the pointed top loop; gold
A thick cord with a dark border, shaded with the sheet's light tone along the top left of each strand and its dark tone
underneath. compare-reference.png: the sheet's row above, ours below, at the same scale. Every mark stays centred on the
HP bar and all five end at the same height. Differences left: our side loops lean a little more and sit closer to the tail
bar, and our shading is simpler than the sheet's painted highlights; at the game's size (marks-ingame.png) they read alike.

Version 2 (2026-11-20, after JTMaston's review): a true bronze, the loops spread apart, rank 3's loops eye-shaped,
ranks 4 and 5 as his sketches, no stars, and a metallic shine.

    rank 1   a single tall loop (like a cursive "l"), its ends crossing under it and running out left and right, bronze
             (B08D57: more yellow-brown, less copper)
    rank 2   three round loops (up, left, right), each with a narrow neck, spread apart, the ends crossing below, silver
    rank 3   the same three loops eye-shaped: each loop is two arcs meeting in a point, gold
    rank 4   five round loops in three tiers (the top loop, a pair, a lower pair), the cord crossing between the tiers,
             gold
    rank 5   the same five loops eye-shaped, gold
             (you did not give colours for 4 and 5: gold for both, since each size goes round, then eye-shaped)

Version 3 (2026-11-20, after the second review): ranks 1, 2 and 4 have the rounder, fuller loops of the first version
again; every loop sits on a short stem, so there is a clear gap between neighbouring loops and down to the crossing, as
between rank 5's tiers. The eye-shaped loops of ranks 3 and 5 are as you approved them.
Every mark is centred on the unit's HP bar (measured in the game within 1 pixel for infantry and cavalry; WoL's elephants carry
their bar toward the head, so theirs can be up to about 13 pixels off at a close camera, depending on where they face).

Every mark is symmetric left to right, with a thin black border, floating over the unit's HP bar. The cord is shaded like
polished metal: lighter on the top-left side of each strand, darker on the bottom-right side, with a thin bright streak,
and the whole mark slightly lighter toward its top left. Every knot ends at the same lowest height (its tails), so all
ranks keep the same gap to the bar; ranks 4 and 5 are drawn larger, so their loops stay readable.

    marks-x4.png                  the five marks enlarged 4 times, on grass and on a dark ground
    marks-ingame.png              the marks in the game at their real size (default camera, 1920 x 1080, pixels 1:1)
    In game (docs, private repo): docs\media\veterancyBonus-icons-wol.mp4 / .gif (2 Hussars against 10 Crossbowmen:
    a Hussar goes from the loop to rank 5, a Crossbowman that kills shows the bronze loop) and the control without the
    key, -control.mp4 / .gif.

Install: the files of art\effects\uhc_rings (in the DLL's release zip) replace the old ones; nothing else changes.
Made with aoe3-blender-tools (tools/make_rings.py).

Question for the team: are gold ranks 4 and 5 right, or should one of them get another colour?
