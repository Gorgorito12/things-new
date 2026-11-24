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
- The gun turns on its post, not the whole camel (with the turretArc key, below): a target within 90 degrees
  of either side of ahead, the camel keeps still and the gun turns to it, the gunner's hands on the grips;
  beyond that, the camel turns to face it as today and the gun comes back to the middle. Each shot leaves
  from the turned muzzle. Without the key the unit plays as before, the gun facing ahead.
- Two units:
  - GatlingCamel (the existing unit): fires from the saddle and moves like the zamburak, no deploying. Its
    stats, cost, cards (HCVickersPurchase, HCGatlingCamels1, SaloonGatlingCamel), name and description do not
    change; only its anim file and its tactics do.
  - GatlingCamelDeployed (new): the camel lies down and the gunner fires from the saddle, the gun turning a
    full 90 degrees each way; it must deploy before it fires, like today's unit. A copy of GatlingCamel (same stats, marked for review);
    nothing trains it yet: a card, a building or a tech has to enable it.
- Made with aoe3-blender-tools' tools/make_gun_camel.py (models, clips, every file checked by the game's
  granny2.dll). The camel lying down plays the game's own lying-down clips of its skeleton (the ones the
  current unit uses), turned upright and laid on the ground.

Files it adds
  art\WoL\units\cavalry_ranged\gatling_camel\
      gatling_camel_camel_nogun.gr2         the zamburak's camel without its swivel gun (its forked post stays as
                                            the gun's mount), with the launch point at the gun's muzzle
      gatling_camel_gun_A55.gr2, _B55.gr2   the gun of each unit (bone_yaw on the post's top turns it)
      gatling_camel_A55.aim, _B55.aim       the turretArc key's aim tables: the gunner's pose for every 15
                                            degrees of the gun's turn, the post's top and the muzzle
      gatling_camel_camel_*.gr2, _gun_*.gr2, _rider_*.gr2    the clips of the camel, the gun and the rider
      gatling_camel_camel_*.gr2.precomp    the tag files of the camel's clips (ATTACHPOINT, HEAD, ...)
      gatling_camel.xml (+ _gun, _rider)    the anim files of GatlingCamel
      gatling_camel_deployed.xml (+ _gun, _rider)   the anim files of GatlingCamelDeployed
  data\tactics\GatlingCamelSaddle.tactics   zamburakME.tactics with the gatling camel's attack action
  data\tactics\GatlingCamelDeployed.tactics GatlingCamel.tactics with the deploy lasting 3.33 s and the
                                            undeploy 2.17 s (the length of their animations)
  Both attacks carry <turret tracking="always" maxTurnAnglePerSecond="240">90</turret>: the arc each side
  and the gun's turn rate on screen. The game reads the tag and ignores it; the turretArc key uses it.
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

The turning gun: the turretArc key of the DLL, one line in Startup\wol.cfg (the pack does not edit the cfg)
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
- El arma gira sobre su poste, no el camello entero (con la clave turretArc, abajo): con un objetivo a menos de
  90 grados a cualquier lado del frente, el camello no se mueve y el arma gira hacia él, las manos del artillero
  en las empuñaduras; más allá, el camello se gira hacia él como hoy y el arma vuelve al centro. Cada disparo
  sale de la boca girada. Sin la clave la unidad juega como antes, el arma mirando al frente.
- Dos unidades:
  - GatlingCamel (la unidad existente): dispara desde la silla y se mueve como el zamburak, sin desplegarse. Sus
    estadísticas, coste, cartas (HCVickersPurchase, HCGatlingCamels1, SaloonGatlingCamel), nombre y descripción
    no cambian; solo su anim file y sus tácticas.
  - GatlingCamelDeployed (nueva): el camello se tumba y el artillero dispara desde la silla, el arma girando 90
    grados a cada lado; tiene que desplegarse antes de disparar, como la unidad actual. Copia de GatlingCamel (mismas estadísticas, a revisar);
    todavía nada la entrena: una carta, un edificio o una tecnología debe habilitarla.
- Hecho con tools/make_gun_camel.py de aoe3-blender-tools (modelos, clips, cada archivo comprobado con el
  granny2.dll del juego). El camello tumbado usa las animaciones de tumbarse del propio juego para su esqueleto
  (las que usa la unidad actual), enderezadas y apoyadas en el suelo.

Archivos que añade y cambia: ver la parte en inglés (los mismos). Los archivos actuales
(art\KingsReturn\Units\Persian\GatlingCamel\, GatlingCamel.tactics) no se tocan.

Instalar
    python apply_fix.py "<carpeta de Wars of Liberty>"              (manifiesto y copia de seguridad en
                                                                     <carpeta>\gatling-camel-backup)
    python apply_fix.py "<carpeta de Wars of Liberty>" --check      (qué está aplicado)
    python apply_fix.py "<carpeta de Wars of Liberty>" --restore    (todo como estaba, byte a byte)
Una carpeta bajo steamapps se rechaza salvo con --force.

El arma que gira: la clave turretArc de la DLL, la línea de la parte en inglés en Startup\wol.cfg (el paquete
no edita el cfg). La clave toma el <turret> del ataque de las tácticas; sin la línea las unidades funcionan,
con el arma mirando al frente.

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
- No visto en el juego: multijugador.
- Corregido el 2026-11-23 tras las primeras grabaciones: las patas izquierdas del camello se veían levantadas
  (las simetrías de las patas de los clips del juego se copiaban en los ejes del propio clip); al morir el arma
  quedaba en el aire y luego giraba sobre sí misma mientras el cadáver se desvanecía. La unidad muerta es ahora
  un modelo propio, el camello con el arma incorporada, que reproduce las muertes de camello del juego: el arma
  cae y se desvanece con el camello, y el jinete cae como el del zamburak.
