Damage templates whose "part" bones crash the game (#78, 2026-11-23)
====================================================================

ENGLISH
-------

A damage template (.dmg) lists "parts" (debris, a broken trunk) by the bone of the model they hang on. The
game looks each bone up by its name, which an anim file must define with <definebone>, and through each
model's own map of those names, built when the model is loaded. When a part names a bone that model's map
lacks, the game writes "Invalid bone name ... in part declaration for model ..., this probably means the bone
was not defined in the unit's anim XML" and, if the name was new in that session, loads the model again while
units still draw it: the old model is freed under them and the game can crash in its next draw. It happens once
per bone name per game, the first time a model with such a template is used (a building damaged or built, a
tree that falls).

Two cases (lists made with aoe3-blender-tools' tools/dmg_bones.py, which reads the loose files over the
art\*.bar archives, and the compressed models through the game's granny2.dll):
- "not defined": the model HAS the bone, but the anim file does not define it. Fixed here: the <definebone>
  lines are added. WoL 1.0.15c had 253 such model and template pairs; after this pack, 0.
- "missing bones": the model does NOT have the bone (a template made for another model). A line cannot fix
  it: the model needs its own template, or none. WoL had 182 such pairs; the cypress trees are fixed here (their
  three damagetemplate="terrain\trees\Damage\tree_oak_a.dmg" removed), so 179 remain. They are listed by template
  in missing-bones-by-template.txt for a later decision (101 templates; the most common:
  buildings\house\house_generic_a.dmg and buildings\native_civs\corral\nat_corral_age2_damaged.dmg, 11 models
  each, terrain\trees\damage\tree_madrone_a.dmg 9, the Japanese Town Center age 2 template 8, the Chinese Town
  Center age 4 template 7).
The original game has the same fault (19 "missing bones" and 40 "not defined" pairs, dmg-bones-stock.csv).
Our DLL's key dmgPartBoneFix stops the reload in every case (WoL's, the original game's and future art): the
part is then left out for that model instead of the model being reloaded.

What the pack changes (WoL-dmg-bones-fix.zip, laid out like the game folder; 132 files):
- 110 anim files replaced: 109 with <definebone> lines added (nothing else changed: the encoding, line ends and
  indentation are kept, and each new line copies the definebone line it follows, in name order where the file
  is in name order), and cypress.xml without the oak's template. This includes market.xml: besides
  bone_debris_2Q to 2U of the West market, it now also defines the bones of the other markets' templates
  (bone_debris_1p, 1q, 5h to 5k, 6a to 6c).
- 22 files added: anim files that are only in the art\*.bar archives (Art1, Art4, Art5) get a loose .xml.xmb
  copy of the archive's file with the definebone nodes added (everything else the same), which the game reads
  before the archive.
- 1533 <definebone> lines in all. The list: dmg-bones-wol-fixes.csv (file, where it came from, the bones added).
- The 7 anim files of art\War of the Triple Alliance\Buildingsets that have both a .xml and an older .xml.xmb
  (academia, artillery_depot, dock, hall, market, plantation, saloon): only the .xml is edited. The game reads the
  .xml when it is newer than the .xmb (it compares the file times), which it is after the edit; the old .xmb
  files are left as they are.

How to apply it to a copy of WoL (never the Steam folder):
    python apply_fix.py <WoL folder> --check      what is applied (original, fixed, missing, other)
    python apply_fix.py <WoL folder>              apply; a backup goes to <WoL folder>\dmg-bones-backup
    python apply_fix.py <WoL folder> --restore    put back the exact original bytes, delete the added files
apply_fix.py checks every file against manifest.json first (WoL 1.0.15c's SHA-256): if one differs, nothing
is written. Or unzip WoL-dmg-bones-fix.zip over the game folder.

Tested (2026-11-23, a copy of WoL 1.0.15c with our UHC.dll): after applying, dmg_bones.py reports 0 "not
defined" pairs (179 "missing bones", the 182 less the cypress); --check, --restore and a second --check gave
the original bytes back; with the pack applied the game started with no new line in Age3Log.txt, and a 6-player
"NEW" Levant skirmish (European AIs, tools/clicksweep.py, 6.5 minutes) ran with no crash and no "Invalid bone
name" part at all (traced with tools/re/trace_frees.py --parts). Without the pack, a 14-minute game on the same
map met 7 such parts (the West market's bone_debris_2q to 2u, and a cypress's "oak a death").

The other files:
- dmg-bones-wol.csv: WoL 1.0.15c as shipped (182 and 253 pairs); dmg-bones-wol-after.csv: after this pack.
- dmg-bones-stock.csv: the original game (19 and 40).
- missing-bones-by-template.txt: the 179 pairs left, by template.
- manifest.json: the original and fixed SHA-256 of every file; WoL-dmg-bones-fix.zip: the files.


ESPAÑOL
-------

Una plantilla de daño (.dmg) lista "partes" (escombros, un tronco roto) por el hueso del modelo del que cuelgan.
El juego busca cada hueso por su nombre, que un archivo anim debe definir con <definebone>, y en el mapa de
nombres propio de cada modelo, que se arma al cargar el modelo. Cuando una parte nombra un hueso que ese mapa no
tiene, el juego escribe "Invalid bone name ... in part declaration for model ..." y, si el nombre era nuevo en
la partida, vuelve a cargar el modelo mientras las unidades lo dibujan: el modelo viejo se libera debajo de
ellas y el juego puede caerse en el siguiente dibujo. Pasa una vez por nombre de hueso por partida, la primera
vez que se usa un modelo con esa plantilla (un edificio dañado o construido, un árbol que cae).

Dos casos (listas de tools/dmg_bones.py de aoe3-blender-tools):
- "not defined": el modelo TIENE el hueso pero el archivo anim no lo define. Se arregla aquí con las líneas
  <definebone>. WoL 1.0.15c tenía 253 pares modelo-plantilla así; con este paquete, 0.
- "missing bones": el modelo NO tiene el hueso (una plantilla hecha para otro modelo). Una línea no lo arregla:
  el modelo necesita su propia plantilla, o ninguna. WoL tenía 182; los cipreses se arreglan aquí (se quitan sus
  tres damagetemplate del roble), quedan 179, listados por plantilla en missing-bones-by-template.txt para
  decidir después.
El juego original tiene el mismo fallo (19 y 40, dmg-bones-stock.csv). La clave dmgPartBoneFix de nuestra DLL
evita la recarga en todos los casos: esa parte queda sin dibujar en ese modelo en vez de recargar el modelo.

Qué cambia (WoL-dmg-bones-fix.zip, con la estructura de la carpeta del juego; 132 archivos): 110 archivos anim
reemplazados (109 con líneas <definebone> añadidas, sin ningún otro cambio, y cypress.xml sin la plantilla del
roble; market.xml define ahora también los huesos de los otros mercados) y 22 añadidos (copias sueltas .xml.xmb
de archivos que solo están en los .bar, con los nodos añadidos). 1533 líneas en total; la lista está en
dmg-bones-wol-fixes.csv. De los 7 archivos de Buildingsets que tienen .xml y un .xml.xmb más viejo, solo se
edita el .xml (el juego lee el .xml si es más nuevo que el .xmb).

Cómo aplicarlo a una copia de WoL (nunca a la carpeta de Steam): `python apply_fix.py <carpeta> --check`, luego
`python apply_fix.py <carpeta>` (copia de seguridad en <carpeta>\dmg-bones-backup) y `--restore` para volver a
los bytes originales exactos. O descomprimir WoL-dmg-bones-fix.zip sobre la carpeta del juego.
