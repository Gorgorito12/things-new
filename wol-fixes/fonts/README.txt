Missing letters in the game fonts (ă ș ț and the rest of Latin Extended-A)
===========================================================================

JTMaston: "The game's current fonts don't support some special characters like ăîâțș. It would be great if
they could be added alongside other special characters from common languages."

This folder adds the missing letters to the game's own fonts, built from each font's own letters and
accents so they look like the rest of the text. Tested in game at 1920x1080 and 1024x768.


Why the letters were missing
----------------------------
The engine itself handles any character. It loads the fonts of FONTS\Fonts.bar, and for every font in
FONTS\fonts3.xml it also makes a fallback font in Arial Unicode MS. For each character it uses the main
font if that font has the letter, otherwise the fallback, and when the fallback lacks it too it draws "?".
The letters were missing from the font files themselves:

- Formal436 BT (most of the interface: menus, buttons, unit names, loading screen text) has only 20
  letters of Latin Extended-A (â, î, ş, č, š, ž, ć, ł, ğ, ı, İ, œ ...). It lacks ă, ș, ț, ţ, ą, ę, ń, ś,
  ź, ż, ő, ű, ď, ě, ň, ř, ť, ů, ľ, ĺ, ŕ, the Baltic letters and more.
- Franklin Gothic Medium (tooltips) and Monotype Corsiva (titles, the loading screen's map name) have
  all of Latin Extended-A, but not the Romanian comma letters Ș ș Ț ț (U+0218 to U+021B).
- The fallback, Arial Unicode MS, lacks Ș ș Ț ț too.

So, before this fix (seen in game, media\diagnosis-*.png, with the Spanish (ES-LA) strings that hold
these letters): ă in Formal436 BT text came from the fallback, in Arial's style, and ș ț were drawn as "?"
in every font. "Sarja Roșior" showed as "Sarja Ro?ior", "Emil Racoviță" as "Emil Racovi?ă".


What was added
--------------
Each new letter is a composite glyph: the font's own base letter plus the font's own accent, placed at the
height and position the font's own accented letters use (learnt from them), with the advance width of the
base letter. Accents a font lacks are made from its own shapes (the comma below from its comma, the
apostrophe caron of ď ť ľ Ľ from its right quote). Nothing that was already in a font changed: every
existing letter, its width and its hinting are kept byte for byte, so normal text keeps its exact width
and place (checked in game, below).

  Formal436 BT  ->  "Formal436 BT WoL", 108 letters:
     Ā ā Ă ă Ą ą Ĉ ĉ Ċ ċ Ď ď Đ Ē ē Ĕ ĕ Ė ė Ę ę Ě ě Ĝ ĝ Ġ ġ Ģ ģ Ĥ ĥ Ħ ħ Ĩ ĩ Ī ī Ĭ ĭ Į į Ĳ ĳ Ĵ ĵ
     Ķ ķ Ĺ ĺ Ļ ļ Ľ ľ Ŀ ŀ Ń ń Ņ ņ Ň ň ŉ Ō ō Ŏ ŏ Ő ő Ŕ ŕ Ŗ ŗ Ř ř Ś ś Ŝ ŝ Ţ ţ Ť ť Ŧ ŧ Ũ ũ Ū ū Ŭ ŭ
     Ů ů Ű ű Ų ų Ŵ ŵ Ŷ ŷ Ź ź Ż ż Ș ș Ț ț
     Not built: ĸ (kra), Ŋ ŋ (eng), ſ (long s): each has a shape of its own that cannot be made from a
     letter and an accent. They are rare (Greenlandic, Sami, old texts) and still show from the fallback.
     Ĥ ĺ Ů: the accent sits a little lower than on the other capitals, to stay inside the font's height
     (Windows cuts anything above it).
  Franklin Gothic Medium  ->  "Franklin Gothic Medium WoL": Ș ș Ț ț. Its Ţ ţ were already drawn with a
     comma below, so Ț ț use those same glyphs.
  Monotype Corsiva  ->  "Monotype Corsiva WoL": Ș ș Ț ț, with the comma of its own Ķ ļ ņ letters.

Ş ş and Ţ ţ (cedilla, U+015E/F and U+0162/3) keep their cedilla where a font draws them that way; Ș ș Ț ț
(U+0218 to U+021B) always have the comma, as Romanian wants. Romanian text should use the comma letters.

The proof sheets (every added letter at 14, 20 and 40 px, drawn from the new fonts) are
media\proof-formal.png, media\proof-franklin.png, media\proof-corsiva.png.

Not changed:
- Arial Unicode MS (the fallback). It would need Ș ș Ț ț only, but the file is 23 MB and every font of
  fonts3.xml now has them itself, so the fallback is no longer asked for them.
- Arial and Courier New in fonts3.xml: they are the Windows fonts, which already have every letter.


How it is installed
-------------------
The new fonts are loose files in FONTS\, next to Fonts.bar, under new family names (so they never clash
with the originals in Fonts.bar or with fonts installed in Windows), and fonts3.xml names them:

    FONTS\TT1141M_WoL.TTF    "Formal436 BT WoL"
    FONTS\framd_WoL.ttf      "Franklin Gothic Medium WoL"
    FONTS\MTCORSVA_WoL.TTF   "Monotype Corsiva WoL"
    FONTS\fonts3.xml         every TypeFace="Formal436 BT" becomes TypeFace="Formal436 BT WoL", and the same
                             for the two others (113 entries today); nothing else in the file changes

The game loads loose .ttf files of FONTS\ the same way as those inside Fonts.bar (tested: the menus,
tooltips and titles were drawn with the new fonts, which are in no archive and not installed in
Windows). Fonts.bar and Fonts3.bar are not touched.

To make the fonts yourself (the pack ships no font file, see the licence notice):

  1. Get aoe3-blender-tools (https://github.com/Gorgorito12/aoe3-blender-tools, the extend_font tool;
     until it is merged it is on the branch font-extend) and install its two optional packages:
         cd aoe3-blender-tools
         python -m pip install -r requirements-fonts.txt        (fontTools and Pillow)
  2. Run, with the game closed:
         python apply_fix.py "<WoL folder>" --tool "<aoe3-blender-tools folder>"
     It reads the three fonts from your own FONTS\Fonts.bar, builds the new ones, writes them to FONTS\,
     and changes fonts3.xml (a copy of the old one goes to <WoL folder>\fonts-fix-backup\, with the proof
     sheets and a report per font). --python <python.exe> names the Python that has fontTools, if it is
     not the one running the script. --out <folder> writes FONTS\ (the fonts and fonts3.xml) to that folder
     instead and changes nothing in the game folder.
  3. To undo: python apply_fix.py "<WoL folder>" --restore  (deletes the three fonts and puts the old
     names back in fonts3.xml).

edit_fonts3.py does step 4 alone, on any fonts3.xml:
    python edit_fonts3.py <fonts3.xml>            only TypeFace values of the three families change, so it
                                                  can be run again after new entries were added (a new
                                                  Formal436 BT entry gets the new name too)
    python edit_fonts3.py <fonts3.xml> --check    lists the TypeFaces, exit code 1 if an old name is left
    python edit_fonts3.py <fonts3.xml> --restore  the old names back
It keeps the file's UTF-16 encoding, its byte order mark and its line ends. If you ship fonts3.xml with
the new names, the three .ttf files must ship with it: a TypeFace Windows cannot find falls back to
another font for all that text.


What was tested (in a copy of WoL 1.2.0e, English, at 1920x1080 and 1024x768)
-------------------------------------------------------------------------------
Test texts were put in the string table (test_strings.py; it restores the table afterwards): the 11 ES-LA
strings that hold ă â î ș ț (83561 "Sarja Roșior", 6000672 "Ataque de Dorobanți y Călărași aumentado.",
6000697 "Emil Racoviță", ...) and a line with every added letter. Screens, before and after
(media\*-1920.png and media\*-1024.png, the "before" half on top, enlarged without smoothing):

  main-menu            main menu buttons                         Formal436 BT
  skirmish-title       the skirmish setup's title                Monotype Corsiva
  map-rollover         the map rollover in the skirmish setup    every added letter
  loading-screen       the loading screen: map name and text     Monotype Corsiva and Formal436 BT
  unit-tooltip         a unit's tooltip, the 11 ES-LA strings    Franklin Gothic Medium
  unit-panel           a unit's name in the selection panel      Formal436 BT (small, not smoothed)
  screen-after-*.jpg   whole screens with the new fonts

Width check: the same screen was taken before and after and compared pixel by pixel. Only the test texts
differ (media\width-check-setup-1920.png and -1024.png: the differing pixels in red). Buttons, labels and
the lines of a tooltip that hold no new letter are identical, at both resolutions. Small sizes stay sharp:
the old letters keep their hinting, and the new ones are made of hinted parts.

The 1024x768 loading screen cuts the test map name "Câmpia Română: Ăă Șș Țț": the name is longer than the
box at that size, not a font problem.


Licence notice
--------------
Formal436 BT is a Bitstream font; Franklin Gothic Medium and Monotype Corsiva are Monotype/ITC fonts. The
fonts came with the game. This pack does not include any font file: apply_fix.py changes the copies you
already have, on your own computer. Whether the changed fonts may be shipped with the mod is the team's
decision under those licences (Formal436 BT's embedding flag is "preview & print"). The new family names
end in "WoL" so they never replace the originals.


Not a font problem: accents inside XS scripts
---------------------------------------------
Text with accents written inside an XS string literal (a random map or AI script) still fails, for a
different reason: the XS tokenizer cuts a string at any byte above 0x7F. Put such text in the string
table and use its ID instead (see the map descriptions pack, wol-fixes\map-descriptions).


Files
-----
  apply_fix.py       builds and installs the fonts from the folder's own Fonts.bar, or --restore
  edit_fonts3.py     points fonts3.xml at the new family names (or back), idempotent
  test_strings.py    puts the test texts into a copy's string table (and --restore); for checking only
  media\             before/after crops, whole screens, the width check, the first diagnosis, proof sheets
