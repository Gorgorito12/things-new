The new gatling camel (request #102)
====================================

ENGLISH
-------

What it is
- Wars of Liberty's new gatling camel. It replaces the current one (a camel with a static gun, a wood frame
  and a gunner on foot that never moves). The body is the zamburak's camel with its own swivel gun cut out; on
  its back sits the stock Gatling gun's barrel cluster, casing with its trunnion, crank and magazine, at 0.55
  of the Gatling's size. A rider cranks it: the barrels spin and the crank turns while it fires, the shots
  and the muzzle flashes leave from the muzzle, and he swaps the magazine on reload.
- Two units:
  - GatlingCamel (the existing unit): fires from the saddle and moves like the zamburak, no deploying. Its
    stats, cost, cards (HCVickersPurchase, HCGatlingCamels1, SaloonGatlingCamel), name and description do not
    change; only its anim file and its tactics do.
  - GatlingCamelDeployed (new): the camel lies down, the gunner gets off step by step and fires on foot; it
    must deploy before it fires, like today's unit. A copy of GatlingCamel (same stats, marked for review);
    nothing trains it yet: a card, a building or a tech has to enable it.
- Made with aoe3-blender-tools' tools/make_gun_camel.py (models, clips, every file checked by the game's
  granny2.dll). The camel lying down plays the game's own lying-down clips of its skeleton (the ones the
  current unit uses), turned upright and laid on the ground.

Files it adds
  art\WoL\units\cavalry_ranged\gatling_camel\
      gatling_camel_camel_nogun.gr2         the zamburak's camel without its swivel gun (its forked post stays as
                                            the gun's mount), with the launch point at the gun's muzzle
      gatling_camel_gun_A55.gr2, _B55.gr2   the gun (B: mirrored, the crank outside, for the gunner on foot)
      gatling_camel_camel_*.gr2, _gun_*.gr2, _rider_*.gr2    the clips of the camel, the gun and the rider
      gatling_camel.xml (+ _gun, _rider)    the anim files of GatlingCamel
      gatling_camel_deployed.xml (+ _gun, _rider)   the anim files of GatlingCamelDeployed
  data\tactics\GatlingCamelSaddle.tactics   zamburakME.tactics with the gatling camel's attack action
  data\tactics\GatlingCamelDeployed.tactics GatlingCamel.tactics with the deploy lasting 5.33 s and the
                                            undeploy 4.17 s (the length of their animations)
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

Tested (2026-11-23, test copy of Wars of Liberty 1.0.15c, single player)
- Both units in a scenario against WoL infantry: idle, walk, the attack (barrels spin, the shots leave from
  the muzzle), reload, deploy and undeploy, deaths (the gun stays on the camel and falls with it), the
  selection circle and the health bar; a game saved and loaded; a skirmish (Saudis) against a German AI with
  the pack applied: the AI plays, no XS error. The current unit filmed as the control.
- Not seen in game: the run (drawn in the previews), multiplayer.

ESPAÑOL
-------

Qué es
- El nuevo camello Gatling de Wars of Liberty. Sustituye al actual (un camello con un arma fija, un armazón de
  madera y un artillero a pie que nunca se mueve). El cuerpo es el camello del zamburak sin su cañón giratorio;
  sobre su lomo van los cañones giratorios, la caja con sus muñones, la manivela y el cargador de la Gatling del
  juego, al 0,55 de su tamaño. Un jinete la acciona: los cañones giran y la manivela da vueltas mientras dispara,
  los disparos y los fogonazos salen de la boca, y en la recarga cambia el cargador.
- Dos unidades:
  - GatlingCamel (la unidad existente): dispara desde la silla y se mueve como el zamburak, sin desplegarse. Sus
    estadísticas, coste, cartas (HCVickersPurchase, HCGatlingCamels1, SaloonGatlingCamel), nombre y descripción
    no cambian; solo su anim file y sus tácticas.
  - GatlingCamelDeployed (nueva): el camello se tumba, el artillero baja paso a paso y dispara a pie; tiene que
    desplegarse antes de disparar, como la unidad actual. Copia de GatlingCamel (mismas estadísticas, a revisar);
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

Probado (2026-11-23, copia de prueba de Wars of Liberty 1.0.15c, un jugador)
- Las dos unidades en un escenario contra infantería de WoL: reposo, caminar, el ataque (los cañones giran, los
  disparos salen de la boca), recarga, desplegar y replegar, muertes (el arma sigue en el camello y cae con él),
  el círculo de selección y la barra de vida; una partida guardada y cargada; una escaramuza (saudíes) contra
  una IA alemana con el paquete aplicado: la IA juega, sin errores XS. La unidad actual grabada como control.
- No visto en el juego: el galope (dibujado en las vistas previas), multijugador.
