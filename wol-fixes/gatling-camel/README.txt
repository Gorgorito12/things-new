The new gatling camel (request #102)
====================================

ENGLISH
-------

What it is
- Wars of Liberty's new gatling camel. It replaces the current one (a camel with a static gun, a wood frame
  and a gunner on foot that never moves). The body is the zamburak's camel with its own swivel gun cut out; on
  its back sits the stock Gatling gun's barrel cluster, casing with its trunnion, crank and magazine, at 0.55
  of the Gatling's size. A rider cranks it: the barrels spin and the crank turns while it fires, the shots
  and the muzzle flashes leave from the muzzle. On reload he lifts the empty magazine off, throws it aside
  (it falls and sinks out of sight), pulls a full one from the pocket at his left hip and seats it.
- The gun turns on its post, not the whole camel (with the turretArc key, below): a target within its arc
  (GatlingCamel: 90 degrees either side of ahead; GatlingCamelDeployed: from +30 to +150, 60 degrees either
  side of its rest at +90, pointing out over the camel's right side, square to its spine), the camel keeps still
  and the gun turns to it, the gunner's hands on the grips; beyond that, the camel turns until the target sits
  at the gun's rest (GatlingCamel: ahead, as today; GatlingCamelDeployed: +90, its right side to the target).
  Each shot leaves from the turned muzzle. Without the key GatlingCamel plays as before, the gun facing ahead;
  GatlingCamelDeployed needs the key (without it the camel faces its target with the gun to its side).
- GatlingCamelDeployed's turn beyond the arc (2026-11-27, the DLL of that day or later): the camel rises with its
  rump high (15 degrees), turns on the spot in big unhurried steps (both diagonal pairs once every 60 degrees, each
  hoof lifted 22 cm, the planted hooves never sliding), and kneels again; the gunner lets go of the handles, turns to
  face his way, walks round beside it and takes the handles again. 0.45 s up, 90 degrees a second, 0.45 s down: 1.9 s
  for 90 degrees, 2.9 s for 180. It does not fire until it has knelt again. An older DLL turns it at once, lying.
- Two units:
  - GatlingCamel (the existing unit): fires from the saddle and moves like the zamburak, no deploying. Its
    stats, cost, cards (HCVickersPurchase, HCGatlingCamels1, SaloonGatlingCamel), name and description do not
    change; only its anim file and its tactics do.
  - GatlingCamelDeployed (new): the camel lies down (turning its neck aside), the gunner gets off on its left,
    takes the gun's two long handles (a drop crank for his left hand, a traverse bar for his right, both in front
    of his chest) and swings the gun out over the camel's right side. The gun turns 100 degrees a second, from
    +30 to +150, and he steps round the post with it on the camel's left; when it stops, the step under way
    finishes, so no foot is left in the air. To reload he walks in to the breech and back. Killed deployed, the
    camel slumps and lays its head down, and he falls backward, away from it. It must deploy before it fires,
    like today's unit (5.33 s; 4.17 s to swing the gun back, get on and rise). A copy of
    GatlingCamel (same stats, marked for review); nothing trains it yet: a card, a building or a tech has to
    enable it.
- Made with aoe3-blender-tools' tools/make_gun_camel.py (models, clips, every file checked by the game's
  granny2.dll). The camel lying down plays the game's own lying-down clips of its skeleton (the ones the
  current unit uses), turned upright, and ends kneeling in the kush: its belly on the ground, its legs folded
  under it, its body level. The camel has a dromedary hump under the saddle cloth (round 7), and the gun's
  post rises from the front of the saddle over the withers, on the camel's spine.

Files it adds
  art\WoL\units\cavalry_ranged\gatling_camel\
      gatling_camel_camel_nogun.gr2         the zamburak's camel without its swivel gun and its forked post (the
                                            gun's own iron post is part of the gun model), with a hump, the launch
                                            point at the gun's muzzle
      gatling_camel_gun_A55.gr2, _B55.gr2   the gun of each unit (bone_yaw on the post's top turns it)
      gatling_camel_A55.aim, _B55.aim       the turretArc key's aim tables: the gunner's pose for every 15
                                            degrees of the gun's turn (A, -90..+90) or every 2 (B, -30..+90,
                                            with his steps and his feet settled at rest), the post's top and
                                            the muzzle; B also the turn beyond the arc (TURN and RISE: the
                                            camel's and the gunner's poses, step and pace)
      gatling_camel_camel_*.gr2, _gun_*.gr2, _rider_*.gr2    the clips of the camel, the gun and the rider
      gatling_camel_camel_*.gr2.precomp    the tag files of the camel's clips (ATTACHPOINT, HEAD, ...)
      gatling_camel.xml (+ _gun, _rider)    the anim files of GatlingCamel
      gatling_camel_deployed.xml (+ _gun, _rider)   the anim files of GatlingCamelDeployed
  data\tactics\GatlingCamelSaddle.tactics   zamburakME.tactics with the gatling camel's attack action
  data\tactics\GatlingCamelDeployed.tactics GatlingCamel.tactics with the deploy lasting 5.33 s and the
                                            undeploy 4.17 s (the length of their animations)
  The attacks carry <turret tracking="always" maxTurnAnglePerSecond="...">: the arc each side of the gun's
  rest (90 from the saddle, 60 on foot) and the gun's turn rate on screen (240 from the saddle, 100 on foot so
  his steps keep pace). The game reads the tag and ignores it; the turretArc key uses it, and keeps the gun
  inside the yaws of the unit's aim table (B: +30 to +150, resting at +90; the aim file's version 2, which
  needs the DLL of 2026-11-26 or later: an older one refuses it and logs "unknown version").
Files it changes
  data\protoy.xml                           GatlingCamel: <AnimFile> and <Tactics>; GatlingCamelDeployed added after it
  data\stringtabley.xml and translations\*\stringtabley.xml
                                            690950 "Deployed Gatling Camel", 690951 (editor name), 690952 (rollover)
The current files (art\KingsReturn\Units\Persian\GatlingCamel\, GatlingCamel.tactics) are not touched.

Install
    python apply_fix.py "<Wars of Liberty folder>"              (a manifest and a backup in
                                                                 <folder>\gatling-camel-backup)
    python apply_fix.py "<Wars of Liberty folder>" --check      (what is applied)
    python apply_fix.py "<Wars of Liberty folder>" --restore    (everything back as it was, byte for byte)
A folder under steamapps is refused unless --force is given.

The turning gun: the turretArc key of the DLL, one line in engine-ext\engine-ext.cfg (our dinput8.dll beside WoL's
own uhc.dll, the usual WoL setup), or in Startup\wol.cfg only if our UHC.dll is used in place of WoL's (the pack does
not edit the cfg)
    turretArc GatlingCamel art\WoL\units\cavalry_ranged\gatling_camel\gatling_camel_A55.aim GatlingCamelDeployed art\WoL\units\cavalry_ranged\gatling_camel\gatling_camel_B55.aim
The key takes the attack's <turret> from the tactics above; without the line the units work, the gun facing
ahead.

Tested (2026-11-23, test copy of Wars of Liberty 1.0.15c, single player)
- Both units in a scenario against WoL infantry: idle, walk, the attack (barrels spin, the shots leave from
  the muzzle), reload, deploy and undeploy, deaths (the gun stays on the camel and falls with it), the
  selection circle and the health bar; a game saved and loaded; a skirmish (Saudis) against a German AI with
  the pack applied: the AI plays, no XS error. The current unit filmed as the control.
- Second round (2026-11-23, filmed close and checked frame by frame): walk, jog and run of both units
  mounted (legs on the ground, the rider's hands on the reins at the run, the gun at 0.55), the deploy, the
  undeploy and remount, the deaths and the corpse fading out.
- Third round (2026-11-24, with the turretArc key): GatlingCamelDeployed now keeps its gunner in the saddle
  (the user's choice), the camel lying down in 3.33 s and rising in 2.17 s. The new reload (the empty magazine
  thrown away, a full one from the pocket at his hip), checked frame by frame in the tool and in game: the full
  one never shows before he draws it, the empty one never comes back to the gun. With the key: targets at
  -90 to +90 degrees on both sides (the camel keeps still, the gun turns), behind (the camel turns), new
  targets one after another, deploy and undeploy while aiming, a game saved and loaded while aiming (the gun
  takes the aim again), deaths while aiming (the corpse shows the gun at rest), 30 camels firing (no cost
  measured: 383 fps with the key, 379 without), a skirmish against an Ottoman AI (the AI plays). Filmed with
  the key off as the control.
- Rounds 4 and 5 (2026-11-25, approved by the user as stills and then as clips; this pack now has their art, which
  replaces every art file of rounds 2 and 3): both units' arms no longer turn over and the gun stays on its post in
  every clip; GatlingCamelDeployed's gunner works the gun on foot from behind the turret with the long handles.
  Every clip passed aoe3-blender-tools' check_anim.py (A 0 failures of 362 checks, B 0 of 552, B's death 0 of 31),
  with a rule that keeps his palms at least 10 cm in front of his chest. In game (test copy, the new DLL, single
  player), filmed close and checked frame by frame: the deploy (the camel lies down, he gets off, side-steps back
  and takes the handles), firing at Houses all round (the gun turns from -30 to +90, a target beyond turns the
  camel until it is inside the arc), the reload (he walks in to the breech and back), a gun at rest inside a step
  band (logged: his step finishes, both feet down), the undeploy and remount, deaths mounted and deployed (the
  camel rolls over with the gun on it, he falls beside it, nothing left floating), and GatlingCamel firing,
  reloading and dying. The AI skirmish was not repeated this round (only art and this unit's tactics changed).
- Round 6 (2026-11-26, JTMaston: "the arc's bisector perpendicular to the camel's spine"; approved by the user as a
  script with stills and as a preview; this pack has its art for GatlingCamelDeployed's deployed clips, its dead
  model and its aim file; GatlingCamel's files are unchanged, byte for byte): the deployed gun rests at +90 and
  turns from +30 to +150; check_anim.py: B 0 failures of 561 checks, its death 0 of 31. In game (test copy, the new
  DLL, single player), checked frame by frame in close films: the deploy with the swing out to +90, targets behind
  and ahead turning the camel until they sit at +90 (logged), the gun turning to targets inside its arc while he
  steps round the post, the reload walk, the undeploy with the swing back, the deployed death (the camel slumps,
  the gun across it, he falls backward away from it) and the mounted death; GatlingCamel firing and dying as
  before with the same DLL.
- Round 7 (2026-11-26, the user; every art file of both units replaced): the lying camel kneels in the kush (it
  was propped 0.32 m up on its folded legs), the gun's post is centred over the spine at the front of the saddle
  (the zamburak camel's own post stood 0.24 m to the left), and the camel has a hump (the rider sits 0.19 m
  higher). check_anim.py: A 0 failures of 368 checks, B 0 of 595, its death 0 of 37. In game (test copy, single
  player): both units drawn, idle, walk, firing (A from the saddle with the centred gun, B on foot), the deploy
  and the undeploy, both deaths, from the game's camera and from a side camera.
- The turn beyond the arc (2026-11-27, approved by the user as a script, a stop-0 sketch and three previews;
  check_anim.py 0 failures for turns of 60, 75, 90 and 180 degrees each way; in game, WoLReal4, the new DLL, single
  player): Houses created and destroyed round it every 20 s, 12 turns of 90 and 180 degrees: the rise, the steps, his
  walk and the settling seen frame by frame, no shot during a turn (logged), and killed mid-turn (the deployed death
  plays, nothing left in the air). Only the aim file B55 changed (the TURN and RISE sections appended; every byte
  before them as in round 7).
- Round 8 (2026-11-26, the user: the kneeling camel should not look like an inert mass; approved as a list and a
  preview; check_anim.py B 0 failures of 595 checks, its death 0 of 37): GatlingCamelDeployed's lying camel breathes
  and sways its tail; in the burst it pins its ears back, flicks its tail at the first shot and shudders a little at
  each shot; in the reload it chews its cud, flicks its ears and turns its head toward the gunner. Only B's three
  lying camel clips and their tag files, B's fire clips of the gun and the gunner, and the aim file B55's fire table
  change; GatlingCamel's files and B55's TURN and RISE sections are unchanged. In game (test copy, single player): the tail
  flicking and swaying, the head turning in the reload, the bursts every 4 s and the muzzle flash at the barrels' end.
- Not seen in game: multiplayer.
- Fixed on 2026-11-23 after the first films: the camel's left legs were drawn lifted (the stock clips' leg
  mirrors were copied in the clips' own axes); on death the gun stayed in the air, then turned on itself
  while the corpse faded out. The dead unit is now a model of its own, the camel with the gun built into
  it, which plays the game's camel deaths: the gun falls and fades with the camel, and the rider falls off
  as the zamburak's does.

ESPAÑOL
-------

Qué es
- El nuevo camello Gatling de Wars of Liberty. Sustituye al actual (un camello con un arma fija, un armazón de
  madera y un artillero a pie que nunca se mueve). El cuerpo es el camello del zamburak sin su cañón giratorio;
  sobre su lomo van los cañones giratorios, la caja con sus muñones, la manivela y el cargador de la Gatling del
  juego, al 0,55 de su tamaño. Un jinete la acciona: los cañones giran y la manivela da vueltas mientras dispara,
  los disparos y los fogonazos salen de la boca. En la recarga saca el cargador vacío, lo tira a un lado (cae y
  se hunde fuera de la vista), saca uno lleno del bolsillo de su cadera izquierda y lo coloca.
- El arma gira sobre su poste, no el camello entero (con la clave turretArc, abajo): con un objetivo dentro de su
  arco (GatlingCamel: 90 grados a cada lado del frente; GatlingCamelDeployed: de +30 a +150, 60 grados a cada lado
  de su reposo en +90, apuntando por el costado derecho del camello, perpendicular a su lomo), el camello no se
  mueve y el arma gira hacia él, las manos del artillero en las empuñaduras; más allá, el camello gira hasta que el
  objetivo queda en el reposo del arma (GatlingCamel: al frente, como hoy; GatlingCamelDeployed: en +90, su costado
  derecho hacia el objetivo). Cada disparo sale de la boca girada. Sin la clave GatlingCamel juega como antes, el
  arma al frente; GatlingCamelDeployed necesita la clave (sin ella el camello encara al objetivo con el arma de lado).
- El giro de GatlingCamelDeployed fuera del arco (2026-11-27, con la DLL de ese día o posterior): el camello se alza
  con la grupa alta (15 grados), gira sobre sí mismo con pasos grandes y pausados (los dos pares en diagonal una vez
  cada 60 grados, cada pezuña alzada 22 cm, sin que resbalen las apoyadas) y vuelve a echarse; el artillero suelta
  los mangos, se gira hacia donde va, camina alrededor y los retoma. 0,45 s para alzarse, 90 grados por segundo,
  0,45 s para echarse: 1,9 s para 90 grados, 2,9 s para 180. No dispara hasta haberse echado. Una DLL anterior lo
  gira de golpe, echado.
- Dos unidades:
  - GatlingCamel (la unidad existente): dispara desde la silla y se mueve como el zamburak, sin desplegarse. Sus
    estadísticas, coste, cartas (HCVickersPurchase, HCGatlingCamels1, SaloonGatlingCamel), nombre y descripción
    no cambian; solo su anim file y sus tácticas.
  - GatlingCamelDeployed (nueva): el camello se tumba (girando el cuello a un lado), el artillero baja por su
    izquierda, toma las dos manijas largas del arma (una manivela baja para la izquierda, una barra de giro para
    la derecha, las dos delante del pecho) y gira el arma hacia el costado derecho del camello. El arma gira 100
    grados por segundo, de +30 a +150, y él rodea el poste dando pasos con ella por el lado izquierdo del camello;
    cuando se para, el paso en curso termina, así que ningún pie queda en el aire. Para recargar se acerca a la
    recámara y vuelve. Si muere desplegado, el camello se desploma y apoya la cabeza, y él cae hacia atrás, lejos
    de él. Tiene que desplegarse antes de disparar, como la unidad actual (5,33 s; 4,17 s para devolver el arma al
    frente, subir y levantarse). Copia de GatlingCamel (mismas estadísticas, a revisar); todavía nada la entrena: una
    carta, un edificio o una tecnología debe habilitarla.
- Hecho con tools/make_gun_camel.py de aoe3-blender-tools (modelos, clips, cada archivo comprobado con el
  granny2.dll del juego). El camello tumbado usa las animaciones de tumbarse del propio juego para su esqueleto
  (las que usa la unidad actual), enderezadas, y termina arrodillado: el vientre en el suelo, las patas plegadas
  debajo y el cuerpo nivelado. El camello tiene una joroba bajo la manta de la silla (ronda 7) y el poste del arma
  sale del frente de la silla sobre la cruz, sobre el lomo.

Archivos que añade y cambia: ver la parte en inglés (los mismos). Los archivos actuales
(art\KingsReturn\Units\Persian\GatlingCamel\, GatlingCamel.tactics) no se tocan.

Instalar
    python apply_fix.py "<carpeta de Wars of Liberty>"              (manifiesto y copia de seguridad en
                                                                     <carpeta>\gatling-camel-backup)
    python apply_fix.py "<carpeta de Wars of Liberty>" --check      (qué está aplicado)
    python apply_fix.py "<carpeta de Wars of Liberty>" --restore    (todo como estaba, byte a byte)
Una carpeta bajo steamapps se rechaza salvo con --force.

El arma que gira: la clave turretArc de la DLL, la línea de la parte en inglés en engine-ext\engine-ext.cfg (nuestro
dinput8.dll junto al uhc.dll de WoL, lo normal en WoL), o en Startup\wol.cfg solo si se usa nuestro UHC.dll en lugar
del de WoL (el paquete no edita el cfg). La clave toma el <turret> del ataque de las tácticas (el arco a cada lado del reposo del arma:
90 desde la silla, 60 a pie) y el archivo de puntería de cada unidad (el de GatlingCamelDeployed es de la versión 2,
con su reposo en +90: necesita la DLL del 2026-11-26 o posterior). Sin la línea GatlingCamel funciona con el arma
mirando al frente; GatlingCamelDeployed la necesita.

Probado (2026-11-23, copia de prueba de Wars of Liberty 1.0.15c, un jugador)
- Las dos unidades en un escenario contra infantería de WoL: reposo, caminar, el ataque (los cañones giran, los
  disparos salen de la boca), recarga, desplegar y replegar, muertes (el arma sigue en el camello y cae con él),
  el círculo de selección y la barra de vida; una partida guardada y cargada; una escaramuza (saudíes) contra
  una IA alemana con el paquete aplicado: la IA juega, sin errores XS. La unidad actual grabada como control.
- Segunda ronda (2026-11-23, grabado de cerca y revisado fotograma a fotograma): paso, trote y galope de las
  dos unidades montadas (patas en el suelo, las manos del jinete en las riendas al galope, el arma al 0,55),
  el despliegue, el repliegue y la subida, las muertes y el cadáver desvaneciéndose.
- Tercera ronda (2026-11-24, con la clave turretArc): GatlingCamelDeployed mantiene al artillero en la silla
  (elección del usuario), el camello se tumba en 3,33 s y se levanta en 2,17 s. La nueva recarga (el cargador
  vacío tirado, uno lleno del bolsillo de la cadera), revisada fotograma a fotograma en la herramienta y en el
  juego: el lleno nunca se ve antes de sacarlo, el vacío nunca vuelve al arma. Con la clave: objetivos de -90 a
  +90 grados a los dos lados (el camello quieto, el arma gira), detrás (el camello gira), objetivos nuevos uno
  tras otro, desplegar y replegar apuntando, una partida guardada y cargada apuntando (el arma vuelve a
  apuntar), muertes apuntando (el cadáver muestra el arma en reposo), 30 camellos disparando (sin coste medido:
  383 fps con la clave, 379 sin ella), una escaramuza contra una IA otomana (la IA juega). Grabado con la clave
  apagada como control.
- Rondas 4 y 5 (2026-11-25, aprobadas por el usuario como imágenes y después como animaciones; este paquete ya trae su
  arte, que sustituye todos los archivos de arte de las rondas 2 y 3): los brazos de las dos unidades ya no giran
  sobre sí mismos y el arma se queda en su poste en todas las animaciones; el artillero de GatlingCamelDeployed
  maneja el arma a pie desde detrás de la torreta con las manijas largas. Todas las animaciones pasaron
  check_anim.py de aoe3-blender-tools (A 0 fallos de 362 comprobaciones, B 0 de 552, la muerte de B 0 de 31), con
  una regla que mantiene sus palmas al menos 10 cm delante del pecho. En el juego (copia de prueba, la DLL nueva, un
  jugador), grabado de cerca y revisado fotograma a fotograma: el despliegue (el camello se tumba, él baja,
  retrocede de lado y toma las manijas), disparos contra casas alrededor (el arma gira de -30 a +90, un objetivo
  más allá hace girar al camello hasta que entra en el arco), la recarga (se acerca a la recámara y vuelve), el
  arma parada dentro de una banda de paso (en el registro: su paso termina, los dos pies en el suelo), el repliegue
  y la subida, las muertes montado y desplegado (el camello rueda con el arma encima, él cae a su lado, nada queda
  flotando), y GatlingCamel disparando, recargando y muriendo. La escaramuza contra la IA no se repitió en esta
  ronda (solo cambian el arte y las tácticas de esta unidad).
- Ronda 6 (2026-11-26, JTMaston: "la bisectriz del arco perpendicular al lomo del camello"; aprobada por el usuario
  como guion con imágenes y como vista previa; este paquete trae su arte para las animaciones de GatlingCamelDeployed
  desplegado, su modelo muerto y su archivo de puntería; los archivos de GatlingCamel no cambian, byte a byte): el arma
  desplegada reposa en +90 y gira de +30 a +150; check_anim.py: B 0 fallos de 561, su muerte 0 de 31. En el juego
  (copia de prueba, la DLL nueva, un jugador), revisado fotograma a fotograma en grabaciones de cerca: el despliegue
  con el giro del arma hasta +90, objetivos detrás y delante que hacen girar al camello hasta quedar en +90
  (registrado), el arma girando hacia objetivos dentro de su arco mientras él rodea el poste, la recarga, el repliegue
  con el giro de vuelta, la muerte desplegado (el camello se desploma con el arma encima, él cae hacia atrás) y la
  muerte montado; GatlingCamel dispara y muere como antes con la misma DLL.
- El giro fuera del arco (2026-11-27, aprobado por el usuario como guion, boceto y tres vistas previas;
  check_anim.py 0 fallos en giros de 60, 75, 90 y 180 grados a cada lado; en el juego, WoLReal4, la DLL nueva, un
  jugador): casas creadas y destruidas a su alrededor cada 20 s, 12 giros de 90 y 180 grados: el alzarse, los pasos,
  su caminar y el asentarse revisados fotograma a fotograma, ningún disparo durante un giro (registrado), y muerto a
  mitad de giro (su muerte desplegado se ve, nada queda en el aire). Solo cambia el archivo de puntería B55 (las
  secciones TURN y RISE añadidas; todos los bytes anteriores como en la ronda 7).
- Ronda 8 (2026-11-26, el usuario: que el camello echado no parezca una masa inerte; aprobada como lista y como
  vista previa; check_anim.py B 0 fallos en 595 comprobaciones, su muerte 0 en 37): el camello echado de
  GatlingCamelDeployed respira y mueve la cola; en la ráfaga pega las orejas atrás, sacude la cola con el primer
  disparo y tiembla un poco con cada disparo; en la recarga rumia, mueve las orejas y gira la cabeza hacia el
  artillero. Solo cambian los tres clips del camello echado de B y sus archivos de etiquetas, los clips de disparo
  del arma y del artillero de B, y la tabla de disparo del archivo de puntería B55; los archivos de GatlingCamel y las
  secciones TURN y RISE de B55 no cambian. En el juego (copia de prueba, un jugador): la cola
  que se sacude y se balancea, la cabeza que gira en la recarga, las ráfagas cada 4 s y el fogonazo en la punta de los
  cañones.
- No visto en el juego: multijugador.
- Corregido el 2026-11-23 tras las primeras grabaciones: las patas izquierdas del camello se veían levantadas
  (las simetrías de las patas de los clips del juego se copiaban en los ejes del propio clip); al morir el arma
  quedaba en el aire y luego giraba sobre sí misma mientras el cadáver se desvanecía. La unidad muerta es ahora
  un modelo propio, el camello con el arma incorporada, que reproduce las muertes de camello del juego: el arma
  cae y se desvanece con el camello, y el jinete cae como el del zamburak.
