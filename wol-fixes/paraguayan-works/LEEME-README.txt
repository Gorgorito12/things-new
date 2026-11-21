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
     they give the arsenal's tall white plume. Since 2026-11-21 each chimney puffs and pauses at
     random, out of step with the others: see "Smoke on and off" below.
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
    works_smoke.particle, works_smoke.particle.xmb   NEW: the arsenal's smoke, each chimney
                                                      puffing and pausing at random
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

Smoke on and off (2026-11-21)
  JTMaston asked: "Paraguayan bases often become giant industrial silos. Is it possible to make
  the works' flues alternate at random intervals between puffing and not puffing smoke?" Yes, in
  works_smoke.particle alone (the anim files are unchanged). It now has, the rest as before:
    initialdormancy 8.0,  initialdormancyvar 1.0     first wait  0 to 16 s
    emissiontime    14.0, emissiontimevar    0.43    each puff   8 to 20 s
    dormanttime     18.5, dormanttimevar     0.35    each pause 12 to 25 s
  Kept: loop 1, alwaysactive 1, initialupdate 20 and the smoke's look. The smoke lives 8 to 12 s
  (particlelife 10, var 0.2), so a pause is never shorter than the longest-lived puff: the old
  column has risen and faded before that chimney puffs again.
  How the game reads these values (checked in the game's code):
  - A "var" is a share of the value: 14 with var 0.43 is 14 x (1 - 0.43) to 14 x (1 + 0.43), any
    value in between.
  - Each chimney is its own emitter. It draws its first wait once, then a new length at every puff
    and at every pause, so no two chimneys share a cycle and no chimney repeats its own.
  - With loop 1 the emitter goes on alternating; with emissiontime 0 (the file before this change)
    it never stops.
  - initialupdate 20 runs a new building's smoke 20 s ahead, cycle included: when a works appears,
    its chimneys are already at random points of their cycles.
  Tested in WoL (single player, 2026-11-21): six works in a row (Food, Wood, Gold, twice) and an
  arsenal, one row per age, about 4 minutes of game time per age, filmed at 2 frames a second and
  measured from the pictures. For the measurement only, the smoke was drawn small, opaque and
  without wind (blue in ages 2 and 3), so that each chimney could be told apart; the timing values
  were the ones above. Results:
  - Age 1, two chimneys per works, ten chimneys measured one by one: every chimney stopped and
    started again 5 to 8 times. The clearest ones puffed 9 to 22 s and paused 10 to 23 s (the
    measure adds or takes 1 to 2 s at each end). No two chimneys were in step, the two of one works
    neither, nor two works of the same kind: any two chimneys were in the same state 34 % to 74 %
    of the time (50 % = unrelated, 100 % = in step). At every moment at least one chimney of the
    row was smoking, 4.9 of 10 on average.
  - Age 2, two chimneys, measured per works: each works went fully quiet (both chimneys off) 6 or
    7 times, 9 to 25 s each time, and smoked 10 to 26 s at a stretch. The row was never without
    smoke for more than 4 s. Two works were in the same state 32 % to 68 % of the time.
  - Age 3, three chimneys, measured per works: at least one of the three is smoking about 80 % of
    the time (81 % expected), but each works still went fully quiet 4 to 7 times, 3 to 20 s each.
    The row was never without smoke for more than 1 s.
  - One emitter per chimney: the anim files hang the smoke on each bone twice (on the model and on
    its Idle anim), but the pauses above would be filled in by a second emitter, and the share of
    time a works smokes matches one emitter per bone.
  Question for the team: are these times right, or should the smoke be lighter or heavier? Each
  chimney now smokes about 43 % of the time (14 s in every 32.5 s on average); a works with two
  chimneys has at least one smoking about two thirds of the time, an age 3 works about four
  fifths. Longer pauses (dormanttime) or shorter puffs (emissiontime) make it lighter; the other
  way round, heavier.

Low model detail (checked in game, 2026-11-20)
  The works have no <lowpoly> branch; the arsenal has one (its own simpler lp_ models). This needs
  no change. Tested with "High Poly Models" off (Options, Detail Settings; optiongrfxhighmodels in
  the profile), a Paraguayan player, the three works and a European Arsenal side by side in each
  age, rows at 50 % HP, one row destroyed in age 1 and one in age 3, with WoL's files and with the
  fix, then the same at high detail:
  - The works never vanish and never look wrong. With no <lowpoly> branch the game draws the
    normal model, so the works look the same at low and high detail; only the arsenal changes to
    its lp_ model.
  - Smoke: the same at both details; with the fix, the arsenal's white plume at low detail too.
  - Damage: at 50 % HP the works look the same at both details.
  - Collapse: at low detail no building plays the falling-pieces collapse, the arsenal included:
    it stands upright and fades out over its rubble, in every age, with WoL's files and with the
    fix alike. So the age 3 bug fixed here (pieces turned) shows only at high detail.
  A <lowpoly> branch would only make the works cheaper to draw at low detail, and it needs simpler
  models of the works, which do not exist: the arsenal's lp_ models would show an arsenal.

Not changed, and why
  - No <lowpoly> branch was added: none is needed (see "Low model detail" above).
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
     minuto entero en nuestra prueba; con alwaysactive 1 dan la columna blanca alta del arsenal.
     Desde el 2026-11-21 cada chimenea echa humo y descansa al azar, sin ir al paso de las otras:
     vea "Humo intermitente" más abajo.
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
    works_smoke.particle, works_smoke.particle.xmb   NUEVO: el humo del arsenal, cada chimenea
                                                      echando humo y descansando al azar
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

Humo intermitente (2026-11-21)
  JTMaston preguntó si las chimeneas de las fábricas podían alternar a intervalos al azar entre
  echar humo y no echarlo, porque las bases paraguayas parecen grandes silos industriales. Sí, solo
  en works_smoke.particle (los archivos de animación no cambian). Ahora tiene, lo demás igual:
    initialdormancy 8.0,  initialdormancyvar 1.0     primera espera 0 a 16 s
    emissiontime    14.0, emissiontimevar    0.43    cada bocanada   8 a 20 s
    dormanttime     18.5, dormanttimevar     0.35    cada pausa     12 a 25 s
  Se conservan loop 1, alwaysactive 1, initialupdate 20 y el aspecto del humo. El humo vive de 8 a
  12 s, así que una pausa nunca es más corta que la bocanada que más dura: la columna anterior ya
  subió y se desvaneció antes de que esa chimenea vuelva a echar humo.
  Cómo lee el juego estos valores (comprobado en el código del juego): un "var" es una fracción del
  valor (14 con var 0.43 es cualquier valor entre 14 x 0,57 y 14 x 1,43). Cada chimenea es su propio
  emisor: sortea su primera espera una vez, y luego una duración nueva en cada bocanada y en cada
  pausa, así que dos chimeneas nunca comparten ciclo y ninguna repite el suyo. initialupdate 20
  adelanta 20 s el humo de un edificio nuevo, ciclo incluido: al aparecer, sus chimeneas ya están en
  puntos al azar de sus ciclos.
  Probado en WoL (un jugador, 2026-11-21): seis fábricas en fila (Food, Wood, Gold, dos veces) y un
  arsenal, una fila por edad, unos 4 minutos de juego por edad, medido sobre las imágenes:
  - Edad 1 (dos chimeneas, diez medidas una a una): cada chimenea paró y volvió a echar humo de 5 a
    8 veces; las más claras, bocanadas de 9 a 22 s y pausas de 10 a 23 s. Ninguna iba al paso de
    otra, tampoco las dos de una fábrica ni dos fábricas del mismo tipo. Siempre había al menos una
    chimenea de la fila echando humo.
  - Edad 2 (medido por fábrica): cada fábrica quedó del todo sin humo 6 o 7 veces, de 9 a 25 s cada
    vez. La fila nunca estuvo sin humo más de 4 s.
  - Edad 3 (tres chimeneas): al menos una echa humo cerca del 80 % del tiempo, pero cada fábrica
    quedó sin humo de 4 a 7 veces, de 3 a 20 s. La fila nunca estuvo sin humo más de 1 s.
  Pregunta para el equipo: ¿están bien estos tiempos, o el humo debería ser más ligero o más denso?
  Cada chimenea echa humo cerca del 43 % del tiempo. Pausas más largas (dormanttime) o bocanadas
  más cortas (emissiontime) lo hacen más ligero; al revés, más denso.

Detalle de modelos bajo (comprobado en el juego, 2026-11-20)
  Las fábricas no tienen rama <lowpoly>; el arsenal sí (sus propios modelos lp_, más simples). No
  hace falta cambiar nada. Probado con "Modelos de alta poligonalidad" (High Poly Models)
  desactivado (Opciones, Configuración de detalles; optiongrfxhighmodels en el perfil), un
  jugador paraguayo, las tres fábricas y un Arsenal europeo lado a lado en cada edad, filas al
  50 % de vida, una fila destruida en la edad 1 y otra en la edad 3, con los archivos de WoL y con
  el arreglo, y luego lo mismo con detalle alto:
  - Las fábricas nunca desaparecen ni se ven mal. Sin rama <lowpoly> el juego dibuja el modelo
    normal, así que las fábricas se ven igual con detalle bajo y alto; solo el arsenal pasa a su
    modelo lp_.
  - Humo: igual con los dos detalles; con el arreglo, la columna blanca del arsenal también con
    detalle bajo.
  - Daños: al 50 % de vida las fábricas se ven igual con los dos detalles.
  - Derrumbe: con detalle bajo ningún edificio hace el derrumbe con piezas que caen, tampoco el
    arsenal: queda en pie y se desvanece sobre sus escombros, en cada edad, igual con los archivos
    de WoL que con el arreglo. Por eso el fallo de la edad 3 corregido aquí (piezas giradas) solo se
    ve con detalle alto.
  Una rama <lowpoly> solo haría más barato dibujar las fábricas con detalle bajo, y necesita
  modelos más simples de las fábricas, que no existen: los modelos lp_ del arsenal mostrarían un
  arsenal.

No cambiado, y por qué
  - No se añadió una rama <lowpoly>: no hace falta (vea "Detalle de modelos bajo" arriba).
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

  paraguayanWorks-smoke-wol.gif / .mp4           NOW (2026-11-21), smoke on and off: two works per
      age (front Food age 1, middle Gold age 2, back Wood age 3, with a European arsenal between
      the two Wood works), 90 s of video, the GIF 7 times faster. Each chimney puffs and stops on
      its own; the two works of each age are never in step.
  paraguayanWorks-smoke-wol-steady.gif / .mp4    the same scene with the previous works_smoke
      (2026-11-20, always on): every chimney smokes all the time.
      In both of these films the two age 1 Food works at the front gave no smoke for their first
      one to two minutes of game time, with either file; later they smoke like the others (in
      the measured rows above, age 1 works smoked from the start). Not caused by this change.
  smoke-cycle.jpg, smoke-steady.jpg              four moments of each (video 10, 30, 50, 70 s).
  paraguayanWorks-smoke-wol-control.gif / .mp4   BEFORE any fix (WoL's files, 2026-11-20): three
      works, one per age (Food age 1, Gold age 2 in the middle, Wood age 3) and a European arsenal:
      thin grey wisps from the pipes.
  smoke-control.jpg, smoke-fixed.jpg             one frame of WoL's files and one of the always-on
      smoke of 2026-11-20 in that scene.
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

  Low model detail ("High Poly Models" off), a Paraguayan player, no AI; each row of buildings is
  Food, Wood and Gold works and a European Arsenal. Left: WoL's files; right: with the fix.
  lowdetail-ages.jpg       ages 1, 2 and 3 (from age 2 on, one row is at 50 % HP).
  lowdetail-damaged.jpg    age 1, two rows at 50 % HP.
  lowdetail-collapse.jpg   a row destroyed in age 1 (1.5 s after) and in age 3 (0.6 s and 3.5 s
      after): standing and fading out, the arsenal too.
  lowdetail-vs-high.jpg    left LOW, right HIGH detail: the fix in age 3 standing and 0.6 s into
      the collapse, then WoL's files 0.6 s into the collapse.
  Detalle de modelos bajo: a la izquierda los archivos de WoL, a la derecha con el arreglo (en
  lowdetail-vs-high.jpg, a la izquierda detalle bajo y a la derecha alto).
