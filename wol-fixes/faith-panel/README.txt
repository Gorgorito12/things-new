FAITH ROW IN THE RESOURCE PANEL (request #101, layout A)
========================================================
(Español más abajo.)

AN OPTIONAL PACK. Nothing changes until apply_fix.py is run. It is the panel half of the faith resource and goes
with the faith pack (wol-fixes\faith) and the DLL key faithResource; it is delivered on its own, apart from the
other rounds. Its panel fixes that have nothing to do with faith can be installed alone: --no-faith, below.

What it does
------------
Faith gets its own row in the resource panel, directly under oil, in all 12 variants of WoL's panel
(SettlerCountDialog in data\uimainnew.xml: default and advanced, European / Asian / Native, big and minimized UI):

- the icon: praying hands on a blue painted backdrop, painted into the panel backgrounds like the oil, food, wood
  and gold icons (the hands are a placeholder: replacing them is one step, below);
- the value: {resource(skillpoints)}, the engine's resource 4, which the faith pack makes faith;
- the tooltip: "Faith Gatherers: N" (string 1010101; Spanish "Recolectores de fe: N");
- a click on the row selects the villagers gathering faith, like the food, wood and gold rows
  (uiFindResourceGatherers("skillpoints"));
- the number of villagers gathering faith on the left in every Asian and Native variant and in the advanced
  European ones (the variants that show it for food). The default European panels show no counts, as today.

The other rows move a little closer to make room: the European full panel now has the Asian panel's 7-row
spacing (rows of 39 texels), the Asian and Native panels have 8 rows (33 texels; their icons are 0.86 of their
size, not squashed). Every row of the background is moved from WoL's own texture; nothing is redrawn but the
faith row. Every number is centred in its row (WoL's export row sat low; with closer rows that would show).

Also fixed on the way:
- Asian minimized panel: the population sat on the oil row, next to the oil drop, and the oil amount never
  showed. The population is now in the header above the rows, and the oil row has its count, value and click.
- Native minimized panel: its background was a part of nat_ui_max with no panel in it (no icons, an empty top,
  Q's picture of the Mapuche). It now uses the native minimized panel WoL already has, unused, in
  ingame_ui_small_01_ypack (oil, fire, food, wood, gold, villagers), with the faith row, and the gadgets of the
  Native full panel; the population in its header.
- European minimized panel: its population header is shorter (39 texels instead of 77), so its 6 rows keep the
  39-texel spacing.
- Four gadgets that show oil were named minimapPanel-trade; they are named minimapPanel-fame now (nothing else
  uses those names: not the game, WoL's DLL, our DLL, any data file or the AI).

Installing
----------
    python apply_fix.py "<WoL folder>"              apply (each file it changes is copied first to
                                                     <WoL folder>\faith-panel-backup\)
    python apply_fix.py "<WoL folder>" --check      what is applied (exit code 0 only when all is)
    python apply_fix.py "<WoL folder>" --restore    the backed-up files back, byte for byte
    python apply_fix.py "<WoL folder>" --no-faith   ONLY the fixes that do not need faith, on WoL's own rows and
                                                     backgrounds: the Asian minimized panel's oil amount and
                                                     population, the Native minimized panel's icons, the renamed oil
                                                     gadgets and the numbers centred in their rows. It changes
                                                     data\uimainnew.xml only (layout\settlercount-nofaith.xml); no
                                                     texture, no string. --check and --restore work the same with it.

It refuses files that are neither WoL 1.0.15c's nor this pack's (--force applies anyway; the panel block of a
newer uimainnew.xml would need make_layout.py run again). To switch between the two modes, --restore first.

Files it changes:
    art\ui\ingame\eur_max_ui.ddt                  European full panel (and the advanced European ones)
    art\ui\ingame\ASI_UI_MAX.ddt                  Asian full panel (and the advanced Asian ones)
    art\ui\ingame\nat_ui_max.ddt                  Native full panel (and the advanced Native ones)
    art\ui\ingame\ingame_ui_small_01_asian.ddt    Asian minimized panel
    art\ui\ingame\ingame_ui_small_01_ypack.ddt    European and Native minimized panels
    data\uimainnew.xml                            the SettlerCountDialog block only; the rest byte for byte
    translations\_originals\stringtabley.xml      string 1010101 in English
    translations\ES-LA\stringtabley.xml           string 1010101 in Spanish
    data\stringtabley.xml                         string 1010101 in the language that file holds
In each texture only the panel's part changes (the 4 x 4 blocks of the panel are encoded again; every other
block keeps WoL's bytes): the minimap frame, the command panel and the unit panel that share these textures
are untouched.

With the faith pack (wol-fixes\faith)
-------------------------------------
This pack is the panel; wol-fixes\faith (the DLL key faithResource, the data, the praying animations) is the
resource. They change different files except the string tables, where each adds its own strings (faith pack:
1010001 and the name of resource 4, 28530; this pack: 1010101), so they can be applied in any order. Restore
them in the reverse order of applying them (each backup holds the string tables as they were before it).
Without the faith pack the row shows resource 4 as the game keeps it today: the home city's unspent skill
points (9 for London, 1 for the Mapuche at the start of a game).

The min UI pack (wol-fixes\min-ui) changes the unit panel, not this one: no order between them.

Replacing the icon
------------------
The icon is one picture, art\faith-icon.png (RGBA, any size, square). To use another (for example WoL's old
praying hands, if someone has them):
    1. put the new PNG in art\faith-icon.png;
    2. rebuild the five backgrounds from WoL's originals (aoe3-blender-tools, tools/panel_rows.py):
       python -I tools/panel_rows.py --spec <this folder>\art\panel-spec.json --in "<WoL folder>"
              --out <this folder>\files --positions <this folder>\art\rows.json
       (--in must be a WoL folder with WoL's own textures, not one this pack was applied to);
    3. apply the pack again.
The layout does not change with the icon. art\panel-spec.json also sets the icon's height in its row (0.92) and
the backdrop's colour. The hands were drawn by aoe3-blender-tools tools/draw_praying_hands.py.

How it is made (to redo it)
---------------------------
    art\panel-spec.json   where each panel's rows are in its texture, and the new order (faith after oil)
    art\rows.json         the new rows, written by panel_rows.py --positions
    make_layout.py        the new SettlerCountDialog block (layout\settlercount.xml) from WoL's uimainnew.xml
                          and art\rows.json: every gadget moved with its row, the faith gadgets copied from
                          the food row, the fixes above
    preview.py            the review sheet: every variant as the game draws it at a resolution, today and new
    layout\settlercount.xml, files\art\ui\ingame\*.ddt   what apply_fix.py installs

The rows (texture rows, top of each rope bar):
    European full     house 740 | oil 784 | faith 823 | food 862 | wood 901 | gold 940 | villagers 979 | 1018
    European min      header 745 | oil 784 | faith 823 | food 862 | wood 901 | gold 940 | villagers 979 | 1018
    Asian full        house 740 | oil 784 | faith 817 | export 851 | food 884 | wood 918 | gold 951 | vill. 985 | 1018
    Asian min         header 453 | oil 490 | faith 523 | export 557 | food 590 | wood 624 | gold 657 | vill. 691 | 724
    Native full       as Asian full, fire in place of export
    Native min        as Asian min, fire in place of export (ingame_ui_small_01_ypack)

Tested (Wars of Liberty 1.0.15c copy, single player, 2026-11-24)
----------------------------------------------------------------
British, Chinese and Mapuche (WallMapu); big and minimized UI; 1024x768, 1600x900, 1920x1080 and 2560x1440.
The pictures are in media\ (see media\README.md for the list).
- Every row lines up with its icon, at every resolution; the numbers stay inside their rows.
- The faith value rises while villagers gather faith (a temporary test: the start food crates and one kind of
  tree held faith, restored after); the count on the left shows them (3); the tooltip reads
  "Faith Gatherers: 3"; a click on the row selects one of them and moves the camera to it, as food does.
- The oil row of the Asian minimized panel shows its amount; the Native minimized panel shows its icons.
- The advanced variants are hidden in WoL's file; they were checked in the preview sheet and in game with a
  test copy of the layout that showed them in place of the default ones.
- --no-faith: the Asian minimized panel shows the oil amount and the population in its header, the Native
  minimized panel its icons, on WoL's own rows (media\nofaith-*.jpg).
- Seen again while testing (agent Q found it first): without the faith key, the faith a player gathers is added
  to the home city's skill points when the game ends (London went from 9 to 1144 skill points over the test
  games). The faith pack's key faithResource stops that; never ship faith data without it. The test copy's home
  cities were put back afterwards.
Not changed: the observer layouts (data\uimainnewobserver*.xml): old copies of the main layout without the oil
row, used only in observer mode, which has its own rebuild plan (#81).

Questions for the team
----------------------
1. Do you have WoL's old praying hands icon (or a screenshot of it)? It replaces ours in one step.
2. The faith count shows on the left in the Asian and Native panels (as food there) and not in the default
   European ones (as food there). Should the European ones show it too?


FILA DE FE EN EL PANEL DE RECURSOS (pedido #101, diseño A)
=========================================================

UN PAQUETE OPCIONAL. No cambia nada hasta que se ejecuta apply_fix.py. Es la mitad del panel del recurso fe y va
con el paquete de fe (wol-fixes\faith) y la clave faithResource de la DLL; se entrega aparte de las demás rondas.
Sus arreglos del panel que no tienen que ver con la fe se pueden instalar solos: --no-faith (abajo).

Qué hace
--------
La fe tiene su propia fila en el panel de recursos, justo debajo del petróleo, en las 12 variantes del panel de
WoL (SettlerCountDialog en data\uimainnew.xml: normal y avanzado, europeo / asiático / nativo, interfaz grande y
minimizada):

- el icono: manos rezando sobre un fondo pintado azul, pintado en los fondos del panel como los iconos de
  petróleo, comida, madera y oro (las manos son provisionales: cambiarlas es un paso, abajo);
- el valor: {resource(skillpoints)}, el recurso 4 del motor, que el paquete de fe convierte en fe;
- el texto emergente: "Recolectores de fe: N" (cadena 1010101; en inglés "Faith Gatherers: N");
- un clic en la fila selecciona a los aldeanos que recolectan fe, como las filas de comida, madera y oro;
- el número de aldeanos que recolectan fe a la izquierda en todas las variantes asiáticas y nativas y en las
  europeas avanzadas (las que lo muestran para la comida). Las europeas normales no muestran números, como hoy.

Las demás filas se acercan un poco: el panel europeo grande tiene ahora el espaciado de 7 filas del asiático
(filas de 39 téxeles); el asiático y el nativo tienen 8 filas (33 téxeles; sus iconos quedan a 0,86 de su
tamaño, sin aplastarse). Cada fila del fondo se mueve desde la textura original de WoL; solo se dibuja la fila
de fe. Cada número queda centrado en su fila.

Arreglado de paso:
- Panel asiático minimizado: la población estaba sobre la fila del petróleo y la cantidad de petróleo nunca se
  veía. Ahora la población está en la cabecera y la fila del petróleo tiene su número, su valor y su clic.
- Panel nativo minimizado: su fondo era una parte de nat_ui_max sin panel (sin iconos). Ahora usa el panel
  nativo minimizado que WoL ya tiene, sin usar, en ingame_ui_small_01_ypack, con la fila de fe y los elementos
  del panel nativo grande; la población en su cabecera.
- Panel europeo minimizado: la cabecera de la población es más baja (39 téxeles en vez de 77), así sus 6 filas
  mantienen el espaciado de 39.
- Cuatro elementos que muestran el petróleo se llamaban minimapPanel-trade; ahora se llaman minimapPanel-fame
  (nada más usa esos nombres).

Instalar
--------
    python apply_fix.py "<carpeta de WoL>"              aplicar (copia antes cada archivo a faith-panel-backup\)
    python apply_fix.py "<carpeta de WoL>" --check      qué está aplicado
    python apply_fix.py "<carpeta de WoL>" --restore    devuelve los archivos originales, byte por byte
    python apply_fix.py "<carpeta de WoL>" --no-faith   SOLO los arreglos que no necesitan la fe (petróleo y
                                                         población del panel asiático minimizado, iconos del nativo
                                                         minimizado, elementos del petróleo renombrados, números
                                                         centrados), con las filas y fondos de WoL: cambia solo
                                                         data\uimainnew.xml. Para cambiar de modo, --restore antes.

Con el paquete de fe (wol-fixes\faith): cambian archivos distintos salvo las tablas de cadenas, donde cada uno
añade las suyas, así que se aplican en cualquier orden; se restauran en el orden inverso. Sin el paquete de fe la
fila muestra el recurso 4 como el juego lo guarda hoy: los puntos de habilidad sin gastar de la metrópoli.

Cambiar el icono: poner el PNG nuevo en art\faith-icon.png, reconstruir los cinco fondos con
tools/panel_rows.py de aoe3-blender-tools (orden de arriba, en la sección en inglés) y aplicar otra vez.

Probado con británicos, chinos y mapuches; interfaz grande y minimizada; 1024x768, 1600x900, 1920x1080 y
2560x1440. Las imágenes están en media\.
