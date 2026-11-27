POLITICIAN UI FOR WARS OF LIBERTY (request #70)
================================================

What it does
------------
With the DLL key `politicianEnablesTech`, an immigrant politician in the age-up dialog shows its flag apart
from the techs it makes available. Under the flag, each tech has its own icon (its <Icon> in techtreey.xml)
and its name (its DisplayNameID). Resting the cursor on an icon or a name shows the rollover of that tech's
own research button: name, cost, description, and "not available until Age N" in red when that applies.
A click on them selects the politician, as a click anywhere in its place.

The techs come from the data: one line per tech inside the politician's <Tech>, in the order they show:

    <Tech name ='LAItalianII' type ='Normal'>
        ...
        <Icon>War of the Triple Alliance\Icons\age_2</Icon>
        <PoliticianEnablesTech>WOTTAimmigrantIT01</PoliticianEnablesTech>
        <PoliticianEnablesTech>WOTTAimmigrantIT02</PoliticianEnablesTech>

The tag only drives the dialog: it enables nothing. The politician's `TechStatus obtainable` effects still
make the techs available, as today. Up to four techs: one or two show one per row, three or four two per row.
A politician without the tag looks exactly as today. The game ignores a <Tech> child it does not know, so
the lines are harmless without the key.

No new pictures are needed. The flag is the top part of WoL's current pictures (145 x 231 pixels of the
192 x 396 picture): the DLL shows that part and leaves the painted icons out. politiciandata.xml does not
change. If you ever draw flag-only pictures, put the flag in the same top-left 145 x 231 corner, or tell the
key where it is: `politicianEnablesTech flag <width share> <height share>` (default 0.75 0.5833).

Installing
----------
  python apply_fix.py "<WoL folder>"              applies it, with a backup in <WoL folder>\politician-ui-backup
  python apply_fix.py "<WoL folder>" --strings    the same, and also takes the hand-written tech list out of
                                                  the politicians' rollover texts (see below)
  python apply_fix.py "<WoL folder>" --check      says what is applied
  python apply_fix.py "<WoL folder>" --restore    puts everything back

Files it changes:
  data\techtreey.xml                 every politician (a tech with <Flag>AgeUpgrade</Flag>) gets one
                                     <PoliticianEnablesTech> line per `TechStatus obtainable` effect on a tech
                                     whose name holds "immigrant", after its <Icon>. In WoL 1.2.0e: 74
                                     politicians, 148 lines (the Latin American waves of ages II to IV, and the
                                     Colombian politicians that bring immigrants). Age V waves have none.
  data\uipoliticianEuropeandlg.xml   the new gadgets in each place, hidden until the DLL fills them (below).
                                     Also: PoliticianButton3 ends at 481 like the other three buttons (it ended
                                     at 381, so the lower part of the fourth place took no clicks).
  engine-ext\engine-ext.cfg          the line `politicianEnablesTech` when the file has none (our dinput8.dll
                                     beside WoL's own uhc.dll, the usual WoL setup; picked when the folder has an
                                     engine-ext folder), else Startup\wol.cfg (our UHC.dll in place of WoL's).
  with --strings: data\stringtabley.xml and translations\*\stringtabley.xml

The rollover texts (--strings)
------------------------------
The politicians' rollover texts end with the techs written by hand. With the techs on screen that list is a
repetition, so --strings removes it (any language: a "+ ...:" line followed by "- ..." lines). For example,
string 6000090 (First French Wave):

  before: <color=0.0, 1.0, 0.1>Crates of 400 food</color>\n+ 1 French Colony\n+ Technologies:\n- Bakeries: 2 food Works.\n- Nitroglycerine: Artisanal Cannon range and damage.
  after:  <color=0.0, 1.0, 0.1>Crates of 400 food</color>\n+ 1 French Colony

Use --strings only together with the key: without it nothing else names the techs (the painted icons have
no names). Without --strings the dialog works too: the description keeps the list, in a box that ends above
the techs (see final\05).

The dialog file
---------------
proposed-uipoliticianEuropeandlg.xml is WoL's current four-place file with the new gadgets;
proposed-uipoliticianEuropeandlg-5places.xml is the five-place file of request #62 with them. apply_fix.py
writes the same into WoL's own file, so later edits of that file are kept. In each place n:

  PoliticianDlg-Poli{n}EnablesTechPortrait         the flag: the place's portrait, cut at the flag's bottom
  PoliticianDlg-Poli{n}EnablesTechDescription      the description, ending above the techs
  PoliticianDlg-Poli{n}EnablesTech{k}Icon / Name   k = 0, 1: one or two techs, one per row
  PoliticianDlg-Poli{n}EnablesTechGrid{k}Icon / Name   k = 0..3: three or four techs, two per row

All in the 1024 x 768 space, sized from the place's own portrait and description: the flag keeps the size it
has today in the picture, the techs take the band under it (icons 22 x 30, which is square on a 16:9
screen, like WoL's pictures), and the names use the description's font. You may move or resize any of them;
the DLL finds them by name. A layout without them (the stock file) is left as it is.

The Asian and native dialogs are not touched.

Beside WoL's own DLL
--------------------
The key also comes with our dinput8.dll (the line then goes in engine-ext\engine-ext.cfg). Tested beside
WoL's uhc.dll: WoL's DLL writes its own description text, and that text lands in the shorter box.

Questions for the team
----------------------
1. Is the band under the flag where you want the techs, or would you rather have them next to the flag?
2. Four techs at most per politician: enough?
3. Shall --strings be part of the release (it touches every translation)?

Beside WoL's own uhc.dll (tested 2026-11-27)
--------------------------------------------
WoL's uhc.dll (c070d138, WoL.dll loaded by preloadDll), our dinput8.dll 0.6.0, the packs applied with their
apply_fix.py (the scripts that write a key put it in engine-ext\engine-ext.cfg by themselves; the other lines were
added there by hand), at the main menu, engine-ext\engine-ext.log (24 keys applied, 1 FAILED of all the packs'
keys):
  politicianEnablesTech      applied
