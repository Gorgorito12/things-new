OIL ONLY AFTER THE GREAT WAR (request #103), AND THE INCOME RATES (request #105)
==============================================================================
(Español más abajo.)

AN OPTIONAL PACK. Nothing changes until apply_fix.py is run. It needs the DLL key techGadgets (and, for --rates,
incomeRates).

What it does
------------
Before the Great War the resource panel has no oil row: the other rows spread over its space. After it (the tech
GreatWarizeALL, which every Great War path researches) the panel is today's, with oil. In all 12 variants of WoL's
panel (SettlerCountDialog in data\uimainnew.xml: default and advanced, European / Asian / Native, big and minimized).

How: each variant, SettlerCountDialog-<variant> (its name, place and visibility unchanged: the engine still picks the
variant), holds two full panels, each with its own background and gadgets:
    SettlerCountDialog-<variant>-postGW   today's panel, with oil. Shown.
    SettlerCountDialog-<variant>-preGW    no oil row (backgrounds *_pregw.ddt). Hidden.
The DLL key techGadgets swaps them, with these cfg lines (12, one per variant), in engine-ext\engine-ext.cfg (our
dinput8.dll beside WoL's own uhc.dll, the usual WoL setup), or in Startup\wol.cfg only if our UHC.dll is used in place
of WoL's; the incomeRates line of --rates goes in the same file:

    techGadgets GreatWarizeALL SettlerCountDialog-<variant>-postGW SettlerCountDialog-<variant>-preGW

<variant> is defaultPanelEurMax, defaultPanelEurMin, defaultPanelAsiMax, defaultPanelAsiMin, defaultPanelNatMax,
defaultPanelNatMin and the same six with advancedPanel. Without the key (or with this pack not applied) the panel
is today's: postGW shown, preGW hidden.

The postGW panels are those of wol-fixes\faith-panel: its --no-faith fixes (the Asian minimized panel shows the oil
amount and the population in its header, the Native minimized panel its icons, the numbers centred in their rows),
or with --faith its faith row. Faith is NOT needed: the default mode has no faith row.

--rates (#105) adds, under each resource amount, the player's income per second of that resource, in green and
smaller ("+2.0"), and a second line to the row's tooltip ("Income: +2.0 per second"; Spanish "Ingresos: +2.0 por
segundo"). It needs the DLL key incomeRates (per second is its default). A panel whose every row has room for two
lines puts the income under the amount; the 7-row Asian and Native panels with faith (and WoL's advanced Native
panel, whose rows are lower) put it right of the amount, slightly lower and set to the panel's right edge, with the
amounts a little closer to their icons (2026-11-25, #105): an amount of 8 digits keeps clear of the rate.

Installing
----------
    python apply_fix.py "<WoL folder>"              apply (backup in <WoL folder>\oil-panel-backup\)
    python apply_fix.py "<WoL folder>" --faith      the same with the faith row in both panels (includes the
                                                     faith panel pack: the faith-panel folder must sit next to this one)
    python apply_fix.py "<WoL folder>" --rates      with either mode: the income rates (#105)
    python apply_fix.py "<WoL folder>" --check      what is applied (exit code 0 only when all is; give the same mode)
    python apply_fix.py "<WoL folder>" --restore    the backed-up files back, byte for byte; the added files deleted
If wol-fixes\faith-panel is applied, restore it first (--faith includes it). To switch modes, --restore first.

Files: adds art\ui\ingame\{eur_max_ui,ASI_UI_MAX,nat_ui_max,ingame_ui_small_01_asian,ingame_ui_small_01_ypack}_pregw.ddt;
changes the SettlerCountDialog block of data\uimainnew.xml (the rest byte for byte); with --faith also the faith
panel pack's five textures and string 1010101; with --rates the strings 1010111 to 1010116 (the rows' tooltips) in
translations\_originals, translations\ES-LA and data\stringtabley.xml.

Tested (Wars of Liberty 1.0.15c copy, single player, 1920x1080, 2026-11-24)
-------------------------------------------------------------------------
With the DLL keys techGadgets and incomeRates (agent K's build of that day). The Great War came from a trigger
(Set Tech Status GreatWarizeALL) at a set time; ten villagers gathered berries and wood.
- All 12 variants at once, before and after the Great War, with and without faith: a test copy of the layout put
  the 12 panels side by side on the screen (renamed, so the engine leaves them visible). Before: no oil row, the
  other rows spread; after: the oil row back, every value in its row (media\ingame-*.jpg).
- The panel the engine picks: Ethiopian (an Asian panel in WoL), minimized UI and big UI; it swaps within 0.2 s
  when the tech becomes active (media\oil-panel-gw.mp4; the control with the key off, media\oil-panel-gw-control.mp4,
  shows oil all along).
- Saved and loaded after the Great War: the panel comes back with oil.
- The engine never showed a hidden panel again (the key logs it when it has to set one again: no such line).
- --rates: the income matches the key's own log (food +2.0 for 3 gatherers, +120.6 a minute; wood +3.0, 179/min).
  The tooltip has its second line (seen with an earlier build, whose value was empty; the build tested shows the
  value in the panel).
- --rates with big stocks (2026-11-25): all 24 panels of each mode side by side, every resource at 99,999,992 (the
  game keeps resources as 32-bit floats: 99,999,999 cannot be shown, the nearest values are 99,999,992 and
  100,000,000) and gold at 100,000,1xx: nothing overlaps or is cut; before the change, the amount ran into the rate
  in the 9 panels with the rate beside the amount (seen with 8 and 9 digits). Estimated from the digit widths, not
  seen: 9 digits beside a rate of two digits before the point (+12.5) would touch.
ingame-loaded-after.jpg was taken with an earlier --rates layout (some amounts in NumbersFont 11, a thinner face; now
always 12), ingame-12-nofaith-before.jpg with the income 1 unit closer to the amount than now; ingame-12-*-after.jpg
were taken again on 2026-11-25 with the rate set to the right edge (Ethiopians, a test map, 3 villagers on berries
and 5 on wood); the other pictures and the videos show the layouts as they are.
Not changed: the observer layouts (data\uimainnew*observer*.xml), which never showed oil.

How it is made (to redo it)
---------------------------
    art\panel-spec-pregw.json, art\panel-spec-pregw-faith.json   the panels without the oil row (aoe3-blender-tools
        tools/panel_rows.py: the oil row left out of "order"; keep_bars keeps the rope bars 9 texels high;
        icon_scale_max 1.1 keeps the icons from growing into the numbers when the rows get taller)
        python -I tools/panel_rows.py --spec <this folder>\art\panel-spec-pregw.json --in "<WoL folder>"
               --out <this folder>\files\nofaith --positions <this folder>\art\rows-pregw.json
        (and -faith: --out files\faith --positions art\rows-pregw-faith.json)
    ..\faith-panel\make_layout.py --oil-gw [--rates]             the two-panel block:
        python -I ..\faith-panel\make_layout.py "<WoL folder>" --no-faith --oil-gw art\rows-pregw.json --out layout\settlercount-gw.xml
        python -I ..\faith-panel\make_layout.py "<WoL folder>" --oil-gw art\rows-pregw-faith.json --out layout\settlercount-gw-faith.xml
        (and --rates, to layout\settlercount-gw[-faith]-rates.xml)
    preview.py [--rates]                                         the review sheets (WoL today, before, after, with faith)

The rows (texture rows, top of each rope bar), before the Great War:
    European full     house 740 | food 784 | wood 842 | gold 901 | villagers 960 | 1018
    European min      header 745 | food 822 | wood 871 | gold 920 | villagers 969 | 1018
    Asian full        house 740 | export 784 | food 831 | wood 878 | gold 924 | villagers 971 | 1018
    Asian min         header 453 | export 490 | food 537 | wood 584 | gold 630 | villagers 677 | 724
    Native full / min as Asian, fire in place of export
With faith: faith takes the first row (European full and min 47 texels a row, Asian and Native 39).


PETRÓLEO SOLO TRAS LA GRAN GUERRA (pedido #103) Y TASAS DE INGRESOS (pedido #105)
================================================================================
PAQUETE OPCIONAL. Necesita la clave techGadgets de la DLL (y, para --rates, incomeRates).

Antes de la Gran Guerra el panel de recursos no tiene la fila del petróleo y las demás filas ocupan su espacio;
después (tecnología GreatWarizeALL) el panel es el de hoy. Cada una de las 12 variantes guarda dos paneles,
<variante>-preGW (sin petróleo, oculto) y <variante>-postGW (el de hoy, visible); la clave techGadgets de la DLL
los intercambia (12 líneas, arriba, en engine-ext\engine-ext.cfg con nuestro dinput8.dll junto al uhc.dll de WoL, o
en Startup\wol.cfg solo si se usa nuestro UHC.dll en lugar del de WoL). Sin la clave el panel queda como hoy. No necesita la fe; --faith añade la fila
de fe. --rates pone bajo cada cantidad el ingreso por segundo del jugador ("+2.0", en verde) y una segunda línea en
el texto emergente de la fila ("Ingresos: +2.0 por segundo").

    python apply_fix.py "<carpeta de WoL>"              aplicar
    python apply_fix.py "<carpeta de WoL>" --faith      con la fila de fe (incluye el paquete faith-panel)
    python apply_fix.py "<carpeta de WoL>" --rates      con las tasas de ingresos (en cualquiera de los dos modos)
    python apply_fix.py "<carpeta de WoL>" --check      qué está aplicado
    python apply_fix.py "<carpeta de WoL>" --restore    deja los archivos como estaban y borra los añadidos

Probado en una copia de WoL 1.0.15c: las 12 variantes antes y después de la Gran Guerra, con y sin fe, la interfaz
grande y la minimizada, guardar y cargar tras la Gran Guerra; el motor nunca volvió a mostrar un panel oculto.

Beside WoL's own uhc.dll (tested 2026-11-27)
--------------------------------------------
WoL's uhc.dll (c070d138, WoL.dll loaded by preloadDll), our dinput8.dll 0.6.0, the packs applied with their
apply_fix.py (the scripts that write a key put it in engine-ext\engine-ext.cfg by themselves; the other lines were
added there by hand), at the main menu, engine-ext\engine-ext.log (24 keys applied, 1 FAILED of all the packs'
keys):
  techGadgets                applied (one line of the twelve, the European big panel)
  incomeRates                applied; in a scenario, hook reached: incomeRates add (0x49A98A)

Junto al uhc.dll de WoL (probado el 2026-11-27, nuestro dinput8.dll, la línea en engine-ext\engine-ext.cfg): techGadgets e incomeRates se aplican (applied).
