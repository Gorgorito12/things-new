OIL ONLY AFTER THE GREAT WAR (request #103)
==========================================
(Español más abajo.)

AN OPTIONAL PACK. Nothing changes until apply_fix.py is run. STATUS: preview, waiting for approval; not yet
tested in game.

What it does
------------
Before the Great War the resource panel has no oil row: the other rows spread over its space. After it (the tech
GreatWarizeALL, which every Great War path researches) the panel is today's, with oil. In all 12 variants of WoL's
panel (SettlerCountDialog in data\uimainnew.xml: default and advanced, European / Asian / Native, big and minimized).

How: each variant, SettlerCountDialog-<variant> (its name, place and visibility unchanged: the engine still picks the
variant), holds two full panels, each with its own background and gadgets:
    SettlerCountDialog-<variant>-postGW   today's panel, with oil. Shown.
    SettlerCountDialog-<variant>-preGW    no oil row (backgrounds *_pregw.ddt). Hidden.
The DLL key techGadgets swaps them, with these cfg lines. Without the key (or with this pack not applied) the
panel is today's.

    techGadgets GreatWarizeALL SettlerCountDialog-<variant>-postGW SettlerCountDialog-<variant>-preGW
    (12 lines, one per variant)

The postGW panels are those of wol-fixes\faith-panel: its --no-faith fixes (the Asian minimized panel shows the oil
amount and the population in its header, the Native minimized panel its icons, the numbers centred in their rows),
or with --faith its faith row. Faith is NOT needed: the default mode has no faith row.

Installing
----------
    python apply_fix.py "<WoL folder>"              apply (backup in <WoL folder>\oil-panel-backup\)
    python apply_fix.py "<WoL folder>" --faith      the same with the faith row in both panels (includes the
                                                     faith panel pack: the faith-panel folder must sit next to this one)
    python apply_fix.py "<WoL folder>" --check      what is applied (exit code 0 only when all is)
    python apply_fix.py "<WoL folder>" --restore    the backed-up files back, byte for byte; the added files deleted
If wol-fixes\faith-panel is applied, restore it first (--faith includes it). To switch modes, --restore first.

Files: adds art\ui\ingame\{eur_max_ui,ASI_UI_MAX,nat_ui_max,ingame_ui_small_01_asian,ingame_ui_small_01_ypack}_pregw.ddt;
changes the SettlerCountDialog block of data\uimainnew.xml (the rest byte for byte); with --faith also the faith
panel pack's five textures and string 1010101.

How it is made (to redo it)
---------------------------
    art\panel-spec-pregw.json, art\panel-spec-pregw-faith.json   the panels without the oil row (aoe3-blender-tools
        tools/panel_rows.py: the oil row left out of "order"; keep_bars keeps the rope bars 9 texels high;
        icon_scale_max 1.1 keeps the icons from growing into the numbers when the rows get taller)
        python -I tools/panel_rows.py --spec <this folder>\art\panel-spec-pregw.json --in "<WoL folder>"
               --out <this folder>\files\nofaith --positions <this folder>\art\rows-pregw.json
        (and -faith: --out files\faith --positions art\rows-pregw-faith.json)
    ..\faith-panel\make_layout.py --oil-gw                       the two-panel block:
        python -I ..\faith-panel\make_layout.py "<WoL folder>" --no-faith --oil-gw art\rows-pregw.json --out layout\settlercount-gw.xml
        python -I ..\faith-panel\make_layout.py "<WoL folder>" --oil-gw art\rows-pregw-faith.json --out layout\settlercount-gw-faith.xml
    preview.py                                                   the review sheets (WoL today, before, after, with faith)

The rows (texture rows, top of each rope bar), before the Great War:
    European full     house 740 | food 784 | wood 842 | gold 901 | villagers 960 | 1018
    European min      header 745 | food 822 | wood 871 | gold 920 | villagers 969 | 1018
    Asian full        house 740 | export 784 | food 831 | wood 878 | gold 924 | villagers 971 | 1018
    Asian min         header 453 | export 490 | food 537 | wood 584 | gold 630 | villagers 677 | 724
    Native full / min as Asian, fire in place of export
With faith: faith takes the first row (European full and min 47 texels a row, Asian and Native 39).


PETRÓLEO SOLO TRAS LA GRAN GUERRA (pedido #103)
===============================================
PAQUETE OPCIONAL. Estado: vista previa, esperando aprobación; aún sin probar en el juego.

Antes de la Gran Guerra el panel de recursos no tiene la fila del petróleo y las demás filas ocupan su espacio;
después (tecnología GreatWarizeALL) el panel es el de hoy. Cada una de las 12 variantes guarda dos paneles,
<variante>-preGW (sin petróleo, oculto) y <variante>-postGW (el de hoy, visible); la clave techGadgets de la DLL
los intercambia. Sin la clave el panel queda como hoy. No necesita la fe; --faith añade la fila de fe.

    python apply_fix.py "<carpeta de WoL>"              aplicar
    python apply_fix.py "<carpeta de WoL>" --faith      con la fila de fe (incluye el paquete faith-panel)
    python apply_fix.py "<carpeta de WoL>" --check      qué está aplicado
    python apply_fix.py "<carpeta de WoL>" --restore    deja los archivos como estaban y borra los añadidos
