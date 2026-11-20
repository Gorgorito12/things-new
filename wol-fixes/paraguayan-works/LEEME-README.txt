Paraguayan works (Food, Wood and Gold works): chimney smoke, damage and collapse fixed
=====================================================================================

ENGLISH

What this fixes
  The three works (FoodFactory, WoodFactory, GoldFactory; WoL\buildings\works) use the models of
  the Mediterranean arsenal, and its damage templates and death animations. Seen in game
  (2026-11-20, a test copy of WoL, the three works in each age, Falconets firing on them):
  1. Smoke. The chimneys used effects\smoke\factory_smoke.particle: puffs a quarter of the size of
     the arsenal's smoke, living half as long. On these tall pipes it shows as a thin grey wisp,
     often hard to see at all. The bones are not the cause: bone_chimney_smoke_A, _B and _A2 are
     the arsenal's, at the same places, at scale 1, on the tops of the pipes. The fix gives the
     works the arsenal's own smoke (white_smoke_b) as a new file, works_smoke.particle, with one
     change: alwaysactive 1, as factory_smoke has. With the arsenal's file as it is (alwaysactive
     0), the age 2 works gave no smoke at all for a whole minute in our test; with alwaysactive 1
     they give the arsenal's tall white plume all the time.
  2. Damage, ages 1 and 2. A damage template finds its debris pieces by mesh name. In the six age 1
     and age 2 damage models (food/wood/gold_works1/2_dmg_Model), 14 of the 35 debris meshes were
     named debris_1a.001, debris_1b.001 ... (the name a 3D tool gives a copy), so the template did
     not find them and those 14 pieces never broke off under fire. They now carry the template's
     names (debris_1a, ...). Also, goldworks.xml named a template that does not exist
     (WoL\buildings\works\med_arsenal_age2.dmg) in ages 1 and 2, so the Gold works lost no piece
     at all; it now names the arsenal's template like the other two works.
  3. Collapse, age 3. The age 3 death models have the arsenal's bones at the same places, but
     exported with another rest orientation. The arsenal's death animation sets each bone as made
     on the arsenal, so on the works every piece was turned about its bone: from the first frame of
     the collapse, pipes lay sideways and walls, crates and roofs floated. The bones of the three
     age 3 death models (and of the three age 3 damage models, which the template's physics uses)
     now have the arsenal's rest frames. The models look exactly the same standing; the building now
     comes down upright, like the arsenal. Ages 1 and 2 already had the arsenal's frames and
     collapsed right.
  All three works were tested in each age (smoke, pieces breaking off under Falconet fire, the
  collapse), before and after. The models were checked by the game's own Granny runtime.

What is in it (WoL-paraguayan-works-fix.zip, WoL's folder layout)
  art\WoL\buildings\works\
    foodworks.xml, woodworks.xml, goldworks.xml      smoke particle (3 lines each); goldworks also
                                                      its template path (2 lines)
    works_smoke.particle, works_smoke.particle.xmb   NEW: the arsenal's smoke, always active
    food/wood/gold_works1_dmg_Model.gr2,
    food/wood/gold_works2_dmg_Model.gr2              14 debris meshes renamed
    food/wood/gold_works3_dmg_Model.gr2,
    food/wood/gold_works3_death_Model.gr2            bones given the arsenal's rest frames
  The models are compressed again (Oodle1, as WoL's), 1.55 MB in all, the size of the originals.
  The anim files keep WoL's line endings (CRLF): an anim file saved with LF line endings made the
  building invisible in our tests (its ground decal stayed). Keep CRLF if you edit them.

How to apply
  1. BACK UP FIRST. These files replace WoL's own loose files of the same name. Keep
     WoL-paraguayan-works-originals.zip, shipped beside this zip: it holds WoL's originals of
     exactly the 15 files replaced.
  2. Unzip into the WoL folder (the one with age3y.exe), letting the "art" folder merge and the
     files be replaced.

How to undo
  Unzip WoL-paraguayan-works-originals.zip into the WoL folder the same way, then delete the two
  new files art\WoL\buildings\works\works_smoke.particle and works_smoke.particle.xmb.

Not changed, and why
  - No <lowpoly> branch was added. The arsenal has one (lp_med_arsenal_*), the works have none.
    Not tested at low model detail: the video settings live in the shared profile, and other test
    games were running. If the works disappear or show wrong at low model detail, say so.
  - No shape= collision attribute (the arsenal's names its own .shp). The works stood, took cannon
    fire and collapsed normally without it.
  - The arsenal's age 2 template puts debris_2i and debris_2j on bone_debris_2h, while both
    models bind those meshes to their own bones: the same in the stock arsenal, left as it is.
  - The flag bone of the age 3 death model stands 0.15 m from the arsenal's: kept where it is.
  - The Heavyworks have their own models: not checked.
  - The works still use the arsenal's ground decal and textures where WoL chose them.


ESPAÑOL

Qué corrige
  Las tres fábricas (FoodFactory, WoodFactory, GoldFactory; WoL\buildings\works) usan los modelos
  del arsenal mediterráneo, y sus plantillas de daños y animaciones de muerte. Visto en el juego
  (2026-11-20, una copia de prueba de WoL, las tres fábricas en cada edad, Falconetes disparándoles):
  1. Humo. Las chimeneas usaban effects\smoke\factory_smoke.particle: bocanadas de un cuarto del
     tamaño del humo del arsenal, que duran la mitad. En estas chimeneas altas se ve como un hilo
     gris, muchas veces casi invisible. Los huesos no son la causa: bone_chimney_smoke_A, _B y _A2
     son los del arsenal, en los mismos sitios, a escala 1, en lo alto de las chimeneas. El arreglo
     da a las fábricas el humo propio del arsenal (white_smoke_b) como un archivo nuevo,
     works_smoke.particle, con un cambio: alwaysactive 1, como factory_smoke. Con el archivo del
     arsenal tal cual (alwaysactive 0), las fábricas de la edad 2 no echaron nada de humo durante un
     minuto entero en nuestra prueba; con alwaysactive 1 dan todo el tiempo la columna blanca alta
     del arsenal.
  2. Daños, edades 1 y 2. Una plantilla de daños encuentra sus escombros por el nombre de la malla.
     En los seis modelos de daño de las edades 1 y 2 (food/wood/gold_works1/2_dmg_Model), 14 de las
     35 mallas de escombros se llamaban debris_1a.001, debris_1b.001 ... (el nombre que un programa
     3D da a una copia), así que la plantilla no las encontraba y esas 14 piezas nunca se
     desprendían bajo el fuego. Ahora llevan los nombres de la plantilla (debris_1a, ...). Además,
     goldworks.xml nombraba en las edades 1 y 2 una plantilla que no existe
     (WoL\buildings\works\med_arsenal_age2.dmg), así que la fábrica de oro no perdía ninguna pieza;
     ahora nombra la plantilla del arsenal, como las otras dos.
  3. Derrumbe, edad 3. Los modelos de muerte de la edad 3 tienen los huesos del arsenal en los
     mismos sitios, pero exportados con otra orientación de reposo. La animación de muerte del
     arsenal coloca cada hueso como se hizo sobre el arsenal, así que en las fábricas cada pieza
     quedaba girada sobre su hueso: desde el primer cuadro del derrumbe, chimeneas tumbadas y muros,
     cajas y tejados flotando. Los huesos de los tres modelos de muerte de la edad 3 (y de los tres
     de daño de la edad 3, que usa la física de la plantilla) tienen ahora los marcos de reposo del
     arsenal. De pie los modelos se ven exactamente igual; ahora el edificio cae recto, como el
     arsenal. Las edades 1 y 2 ya tenían los marcos del arsenal y caían bien.
  Las tres fábricas se probaron en cada edad (humo, piezas que se desprenden bajo el fuego de los
  Falconetes, el derrumbe), antes y después. El runtime Granny del propio juego comprobó los modelos.

Qué contiene (WoL-paraguayan-works-fix.zip, con la estructura de carpetas de WoL)
  art\WoL\buildings\works\
    foodworks.xml, woodworks.xml, goldworks.xml      partícula de humo (3 líneas en cada uno);
                                                      goldworks también la ruta de su plantilla
                                                      (2 líneas)
    works_smoke.particle, works_smoke.particle.xmb   NUEVO: el humo del arsenal, siempre activo
    food/wood/gold_works1_dmg_Model.gr2,
    food/wood/gold_works2_dmg_Model.gr2              14 mallas de escombros renombradas
    food/wood/gold_works3_dmg_Model.gr2,
    food/wood/gold_works3_death_Model.gr2            huesos con los marcos de reposo del arsenal
  Los modelos van comprimidos otra vez (Oodle1, como los de WoL): 1,55 MB en total, lo mismo que los
  originales. Los archivos de animación conservan los finales de línea de WoL (CRLF): un archivo de
  animación guardado con finales LF dejó el edificio invisible en nuestras pruebas (quedaba solo su
  marca en el suelo). Si los edita, mantenga CRLF.

Cómo aplicarlo
  1. HAGA UNA COPIA ANTES. Estos archivos reemplazan archivos sueltos de WoL con el mismo nombre.
     Guarde WoL-paraguayan-works-originals.zip, que va junto a este zip: tiene los originales de WoL
     de exactamente los 15 archivos que se reemplazan.
  2. Descomprimir en la carpeta de WoL (la que tiene age3y.exe), dejando que la carpeta "art" se
     combine y los archivos se reemplacen.

Cómo deshacerlo
  Descomprimir WoL-paraguayan-works-originals.zip en la carpeta de WoL de la misma forma, y borrar
  los dos archivos nuevos art\WoL\buildings\works\works_smoke.particle y works_smoke.particle.xmb.

No cambiado, y por qué
  - No se añadió una rama <lowpoly>. El arsenal tiene una (lp_med_arsenal_*), las fábricas ninguna.
    No se probó con detalle de modelos bajo: los ajustes de vídeo están en el perfil compartido y
    había otras partidas de prueba abiertas. Si las fábricas desaparecen o se ven mal con detalle
    bajo, avísenos.
  - Ningún atributo de colisión shape= (el del arsenal nombra su propio .shp). Las fábricas se
    sostuvieron, recibieron cañonazos y se derrumbaron con normalidad sin él.
  - La plantilla de la edad 2 del arsenal pone debris_2i y debris_2j en bone_debris_2h, mientras
    ambos modelos unen esas mallas a sus propios huesos: igual en el arsenal original, se deja así.
  - El hueso de la bandera del modelo de muerte de la edad 3 está a 0,15 m del del arsenal: se deja
    donde está.
  - Las Heavyworks tienen sus propios modelos: no se revisaron.
  - Las fábricas siguen usando la marca de suelo y las texturas del arsenal donde WoL las eligió.


MEDIA (in the "media" folder beside this README, not inside the zips)

  WoL in game, a scenario with no AI; player 1's works, player 2's Falconets (placed in range, then
  ordered to fire). Each fixed run has a control: the same scene with WoL's own files.

  paraguayanWorks-smoke-wol.gif / .mp4           AFTER: three works, one per age (Food age 1, Gold
      age 2 in the middle, Wood age 3) and a European arsenal: the age 2 Gold works sends up the
      arsenal's tall white plume the whole time.
  paraguayanWorks-smoke-wol-control.gif / .mp4   BEFORE (WoL's files): the same scene, thin grey
      wisps from the same pipes.
  smoke-fixed.jpg, smoke-control.jpg             one frame of each.
  paraguayanWorks-damage-wol.gif / .mp4          AFTER, age 2: Food (left) and Gold (right) works
      under Falconet fire: wall and roof pieces break off both, then both collapse.
  paraguayanWorks-damage-wol-control.gif / .mp4  BEFORE: the same fire; fewer pieces break off the
      Food works, and we saw none come off the Gold works (its template did not exist).
  paraguayanWorks-collapse-wol.gif / .mp4        AFTER, age 3: both works collapse upright,
      slowed down.
  paraguayanWorks-collapse-wol-control.gif / .mp4  BEFORE, age 3: from the first frame every piece
      is turned (pipes sideways, crates and walls in the air).
  collapse-age3-fixed.jpg, collapse-age3-control.jpg   the first frames of each collapse.
  The damage and collapse runs were filmed with the arsenal's smoke file before works_smoke was
  made; their models are the ones in the zip.
