Slinger animations on other models (request #100)
==================================================

ENGLISH
-------

What it is
- The Aztec Macehualtin's slinger animations (35 clips: idle, bored, walk, jog, run, the sling attack and its
  reload, two hand attacks, the torch, cheers, recoils, seven deaths) made to play on any standard infantry
  body, so a new slinger unit can use its own model.
- Why they only worked on the Macehualtin: the game plays an animation on a model only if the animation has a track
  group named after that model. The Macehualtin's model and clips are named "bone_master"; every standard infantry
  model (WoL's skirmisher, the native rifleman, ...) is named "Bip01". On such a body the original clips do nothing
  and the unit stays in its bind pose. The skeletons are otherwise the same biped.
- The fix is in the art: the clips retargeted onto the Bip01 skeleton by aoe3-blender-tools' tools/retarget_anims.py,
  each with its tag file (.gr2.precomp; the stone's launch point is kept). No DLL key.
- The sling is the Macehualtin's own attachment (units\natives\aztec\macehuatlin\macehuatlin_sling01.xml): it plays
  on any body and needs no change.

What the pack adds (nothing of the mod is changed)
- art\WoL\units\infantry_ranged\slinger\anims_skirmisher\*.gr2 and *.gr2.precomp: made on
  WoL\units\infantry_ranged\skirmisher\skirmisher_age2 (a European-style body);
- art\WoL\units\infantry_ranged\slinger\anims_native\*.gr2 and *.gr2.precomp: made on units\natives\rifleman.
  Any Bip01 body of the standard proportions can use either set (they differ by 1.6 cm at the hips).
- files\skirmisher-anims.xml and files\native-anims.xml (not copied): the blocks to paste into a unit's anim file:
  1. the definebone lines, 2. the sling and torch attachments, 3. the <attach a="sling" ... tobone="PROP1"
  syncanims="1"/> line for the model's component, 4. every <anim> of the Macehualtin pointed at the new clips, with
  its tags (attack, sound, footsteps).

Install
    python apply_fix.py "<Wars of Liberty folder>"              (adds the clips; a manifest in
                                                                 <folder>\slinger-anims-backup)
    python apply_fix.py "<Wars of Liberty folder>" --test       (also three TEST units, see below)
    python apply_fix.py "<Wars of Liberty folder>" --check      (what is applied)
    python apply_fix.py "<Wars of Liberty folder>" --restore    (everything back as it was, byte for byte)
A folder under steamapps is refused unless --force is given.

Making a slinger unit
- Copy the slinger proto (POLYMarauder, or your own) and give it an anim file with your model, the blocks of
  files\skirmisher-anims.xml (or native-anims.xml) and the sling's <attach> line in the model's component (in each
  LowPoly branch if it has them). The anim names are the Macehualtin's, which musketBayonet.tactics uses.
- The projectile is the proto's <ProjectileProtoUnit> (POLYMarauder and the Macehualtin use Arrow).
- A model with other proportions or other bone names: run tools/retarget_anims.py with a recipe for it
  (aoe3-blender-tools, tools/README.md).

Test units (--test, not for a release)
- SlingerTestSkirmisher: the skirmisher model with the retargeted clips and the sling;
- SlingerTestNative: the native rifleman with the retargeted clips and the sling;
- SlingerTestControl: the skirmisher model with the Macehualtin's own clips: it stays in its bind pose.
They are copies of POLYMarauder (same stats, tactics and name in game), with anim files in
art\WoL\units\infantry_ranged\slinger\test\.

Tested (2026-11-23, a test copy of Wars of Liberty)
- idle, walk, the sling attack (in step with POLYMarauder beside them), the hand attack, deaths; the control in its
  bind pose; a game saved and loaded; a skirmish against a German AI with the pack applied (no XS error).
- Not seen in game: the run animation and the torch (drawn in the review sheets).

ESPAÑOL
-------

Qué es
- Las animaciones de hondero del Macehualtin azteca (35 clips: reposo, aburrido, caminar, trotar, correr, el ataque
  de honda y su recarga, dos ataques cuerpo a cuerpo, la antorcha, vítores, retrocesos, siete muertes) para que se
  reproduzcan en cualquier cuerpo de infantería estándar, y una nueva unidad de hondero pueda usar su propio modelo.
- Por qué solo funcionaban en el Macehualtin: el juego reproduce una animación en un modelo solo si la animación
  tiene un grupo de pistas con el nombre de ese modelo. El modelo y los clips del Macehualtin se llaman "bone_master";
  todos los modelos de infantería estándar (el escaramuzador de WoL, el fusilero nativo, ...) se llaman "Bip01". En
  esos cuerpos los clips originales no hacen nada y la unidad queda en su pose de enlace. Por lo demás los esqueletos
  son el mismo bípedo.
- El arreglo está en el arte: los clips reorientados al esqueleto Bip01 con tools/retarget_anims.py de
  aoe3-blender-tools, cada uno con su archivo de etiquetas (.gr2.precomp; se conserva el punto de lanzamiento de la
  piedra). Sin clave de la DLL.
- La honda es el accesorio del propio Macehualtin (units\natives\aztec\macehuatlin\macehuatlin_sling01.xml): funciona
  en cualquier cuerpo y no necesita cambios.

Qué añade el paquete (no cambia nada del mod)
- art\WoL\units\infantry_ranged\slinger\anims_skirmisher\*.gr2 y *.gr2.precomp: hechos sobre
  WoL\units\infantry_ranged\skirmisher\skirmisher_age2 (un cuerpo de estilo europeo);
- art\WoL\units\infantry_ranged\slinger\anims_native\*.gr2 y *.gr2.precomp: hechos sobre units\natives\rifleman.
  Cualquier cuerpo Bip01 de proporciones estándar puede usar cualquiera de los dos (difieren 1,6 cm en la cadera).
- files\skirmisher-anims.xml y files\native-anims.xml (no se copian): los bloques para pegar en el anim file de una
  unidad: 1. las líneas definebone, 2. los accesorios de honda y antorcha, 3. la línea <attach a="sling" ...
  tobone="PROP1" syncanims="1"/> para el componente del modelo, 4. cada <anim> del Macehualtin apuntando a los clips
  nuevos, con sus etiquetas (ataque, sonido, pasos).

Instalar
    python apply_fix.py "<carpeta de Wars of Liberty>"              (añade los clips; un manifiesto en
                                                                     <carpeta>\slinger-anims-backup)
    python apply_fix.py "<carpeta de Wars of Liberty>" --test       (además tres unidades de PRUEBA, ver abajo)
    python apply_fix.py "<carpeta de Wars of Liberty>" --check      (qué está aplicado)
    python apply_fix.py "<carpeta de Wars of Liberty>" --restore    (todo como estaba, byte a byte)
Una carpeta bajo steamapps se rechaza salvo con --force.

Hacer una unidad de hondero
- Copia el proto del hondero (POLYMarauder, o el tuyo) y dale un anim file con tu modelo, los bloques de
  files\skirmisher-anims.xml (o native-anims.xml) y la línea <attach> de la honda en el componente del modelo (en
  cada rama LowPoly si las tiene). Los nombres de animación son los del Macehualtin, que usa musketBayonet.tactics.
- El proyectil es el <ProjectileProtoUnit> del proto (POLYMarauder y el Macehualtin usan Arrow).
- Un modelo con otras proporciones u otros nombres de huesos: ejecuta tools/retarget_anims.py con una receta para él
  (aoe3-blender-tools, tools/README.md).

Unidades de prueba (--test, no para una versión publicada)
- SlingerTestSkirmisher: el modelo del escaramuzador con los clips reorientados y la honda;
- SlingerTestNative: el fusilero nativo con los clips reorientados y la honda;
- SlingerTestControl: el modelo del escaramuzador con los clips propios del Macehualtin: queda en su pose de enlace.
Son copias de POLYMarauder (mismas estadísticas, tácticas y nombre en el juego), con anim files en
art\WoL\units\infantry_ranged\slinger\test\.

Probado (2026-11-23, una copia de prueba de Wars of Liberty)
- reposo, caminar, el ataque de honda (al mismo ritmo que POLYMarauder a su lado), el cuerpo a cuerpo, muertes; el
  control en su pose de enlace; una partida guardada y cargada; una escaramuza contra una IA alemana con el paquete
  aplicado (sin errores XS).
- No visto en el juego: la animación de correr y la antorcha (dibujadas en las hojas de revisión).
