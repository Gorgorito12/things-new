Dismount: the Chasseur a Cheval fights on foot (request #84)
================================================================

ENGLISH
-------

What it does
- The Chasseur a Cheval gets two buttons on its command row: Dismount and Mount.
- Dismount: the rider gets off on the horse's left side (a 2.5 s animation), then fights on foot with the
  infantry's own animations: volley fire and reload, bayonet, the torch against buildings, idle, walk, run, death.
- The horse, per unit (the --horse option, or the recipe of another unit):
  - hide (the default): the horse is there while the rider gets off and on, and is not drawn while he is on foot.
    The dismount (3.5 s) ends with the horse gone and the rider stepping from its side to the unit's centre, where
    he stands on foot, on the selection circle and under the hit point bar; the mount (3.5 s) starts with the step
    back, then the horse is there again and he climbs on;
  - keep: the horse stays beside him and walks with him (the pack before 2026-11-22).
- Mount: he climbs back on (2.5 s) and the unit is cavalry again, in the Stagger stance.
- On foot the unit is slower (speed x0.67, the line infantry's 4.0 instead of 6.0). Its attacks keep the numbers
  of the mounted attacks (DefendRangedAttack, MeleeHandAttack, BuildingAttack), and every tech effect on those
  reaches the attacks on foot too. Its unit types, hit points, armour and obstruction do not change: a stance
  cannot change them (see "What a stance cannot do" below).
- Nothing in the DLL: tactics, anim files and data only. The two buttons need the DLL key customProtoUnitCommands
  (already in Wars of Liberty's cfg), like every command type WoL adds.

Install
    python apply_fix.py "<Wars of Liberty folder>"                (horse hidden on foot; backup in
                                                                   <folder>\dismount-backup)
    python apply_fix.py "<Wars of Liberty folder>" --horse keep   (the horse stays beside him)
    python apply_fix.py "<Wars of Liberty folder>" --restore      (everything back as it was)
    python apply_fix.py "<Wars of Liberty folder>" --check        (what is applied, which horse choice)
The script refuses a folder under steamapps unless --force is given. The docstring of apply_fix.py lists every
file it changes.

TEST ONLY: --test also adds ChasseuraChevalDismountTest, a copy of the Chasseur that builds and heals on foot (the
tactics file's own Build and Heal actions, made active and kept in the stance on foot; the ProtoActions Build and
Heal, the flag CanAutoHeal, a House in its build list) and the animations Heal and Build, to see a construction and
a heal on foot in a test copy of the game. It is not WoL's Chasseur, which builds and heals nothing; do not ship it.

How it is built (the recipe for another unit)
1. Tactics. A copy of the unit's tactics file. Three new actions, copies of the mounted ranged, hand and building
   attacks with other animation names (Dismounted_Attack, Dismounted_Reload, Dismounted_Melee, Dismounted_Idle,
   Dismounted_Raze_attack, Dismounted_Raze_idle). A new
   tactic "Dismounted" with those actions, <speedmodifier>, its own idle/bored/walk/jog/run/death animations, and
   one <transition> back to each mounted tactic (<action>Limber</action>, <anim>Mount</anim>, <length>2.5</length>
   with the horse kept, 3.5 hidden: as long as the animations, <exit>1</exit>). Every mounted tactic gets a <transition> to "Dismounted" (<anim>Dismount</anim>). This is how
   the artillery's Limber/Bombard works (falconet.tactics). <exit>1 is what lets a button's tactic change use the
   transition; <action>Limber</action> is the built-in transition action every stock artillery transition names.
   No <automatic>: with it the unit would switch on its own to reach an action of the other stance.
2. Proto (protoy.xml). The unit points at the new tactics file and gets <ProtoAction>s for the three new actions
   (copies of the mounted ones: damage, range, ROF, bonuses).
3. Techs (techtreey.xml). An action name is what a tech effect targets, so every effect on the mounted actions
   gets a twin on the new ones (the script does it: 313 effects in WoL today). Mind the effects written as
   `</Effect></Effects>` on one line: a twin must end at its own </Effect>. A first version ran on to the next
   line's and copied seven whole techs; the AI then stopped compiling ('cTechypConsulateBritishBrigade' is not a
   valid operator). The script now refuses an edit that changes the number of techs.
4. Buttons. Two protounitcommands, unitSetTactic("Dismounted") and unitSetTactic("Stagger"), on the unit's command
   row (page 10), their names in data\uhc\customprotounitcommands.xml, tooltips 690911 and 690912. (A squad mode in
   battle.xml, CavalryDismounted, is added too, so that the stance has its entry like the other stances.)
5. Animations. The horse is the unit's model and the rider an attachment on its "bone attachpoint" with
   syncanims="1": each animation name is played by the horse (its anim file, which also carries the tags: attack,
   sound, muzzle particle) and by the rider (his anim file). So every new animation name goes in both files. The
   rider's files are new Granny animations made by aoe3-blender-tools' tools/make_dismount.py:
   - on foot: a stock infantry animation (animation_library\range\...) posed on the infantry skeleton, put on the
     rider's bones by place (the rider's skeleton has another hierarchy, so the stock files cannot be played on him
     as they are), moved to the ground beside the horse, and expressed in the frame of the horse bone he hangs on
     at every moment of the horse animation played with it: he stands still on the ground while the horse breathes
     or walks;
   - the two transitions: key poses (in the saddle, up in the stirrups, the right leg over the croup, against the
     saddle facing the horse, slid down, standing), slerped bone by bone, the weapon kept in the right hand.
   Where the rider's animation is not as long as the horse's (attack, reload, melee, the transitions, the loops that
   do not divide evenly), the tool also writes a horse clip of the same length, so both stay in step. In the attack
   clip the horse's bone_launchpoint follows the rider's muzzle, so the shot and its flash leave his musket.
   For another unit: a recipe JSON with its models (rider, horse, an infantry model of the same rig), the side, the
   mounted idle and the infantry animations to use. Do not add the new names to data\animtypes.xml: tried, the
   unit then played its mounted attack while on foot; `--overview` draws every animation in one sheet first.
   A written animation keeps its tracks sorted by name, as the stock files do: the game looks a bone's track up by
   binary search, and an unsorted file moves only some bones.
   An animation's own <attach> lines go in the rider's block: the torch of the attack on buildings hangs on his
   left hand (as the stock musketeer holds it), from the "torch" attachment his anim file already defines.
6. The horse kept or hidden, per unit. The recipe's "horse": "keep" or "hide" (make_dismount.py --horse); this
   pack's --horse. Hidden, the horse's animations on foot are clips of their own (chasseur_horse_hidden_<name>.gr2)
   that put every bone the horse's mesh is skinned to 30 m under the ground and keep the bones nothing is skinned
   to where they were: the root, "bone attachpoint" (the rider), "bone hitpointbar" and "bone_launchpoint". The
   horse is not seen. The rider's animations on foot are files of their own (chasseur_hidden_<name>.gr2) that put
   him on the unit's centre (recipe "centre", default 0, 0), where the selection circle and the hit point bar are.
   The dismount is the kept one (2.5 s) followed, once the horse is under the ground, by a 1 s step from the
   horse's side to the centre (the idle turning into the walk and back); the mount starts with the step back, and
   the horse comes up when he stands beside it; so a hidden transition lasts 3.5 s, and the tactics' <length> says
   3.5. So a modder chooses per unit: a unit of the recipe with "hide", another with "keep".
   Tried first and dropped: a second <component> in the horse's anim file (the way the stock cannons show a
   stripped model in their Bombard animations), named by the animations on foot, with a horse model that draws
   nothing. In game the rider hung on it vanished too (or only his hats showed, on the ground).
   Limits: the horse disappears and appears at once (no fade), after the dismount's last move and before the
   mount's first; the unit keeps the horse's size and obstruction. With the horse kept, the rider stands 0.85 m
   left of the unit's centre, beside the horse, which fills the centre.
   A heal and a construction play the anim names Heal and Build (and BuildLifting, BuildSaw, BuildStaking), not
   the name an action's <anim> gives (measured with the test unit: with Dismounted_Heal it healed in its idle).
7. The stance holds in a fight. Measured: four dismounted chasseurs kept the stance (tactic index 3) through a
   skirmish fight until the Mount command; the engine only leaves a tactic on its own through a transition marked
   <automatic> (or <commandautomatic> for a command).

What a stance cannot do (a question for the team)
A tactic changes the actions, the animations and the speed. It does not change unit types, armour, hit points,
the obstruction radius or <PhysicsInfo>. On foot the Chasseur still counts as cavalry: lancers' and pikemen's
bonuses against cavalry still hit it, and it keeps its cavalry size. If the dismounted unit must count as infantry,
the alternative is a transform: a second proto (e.g. ChasseuraChevalDismounted, infantry types and armour) and a
button that turns one into the other with uiTransformSelectedUnit, gated by the DLL key transformChecks (already
built). The dismount animation would then be played by the mounted unit before the transform, and the horse would
disappear with it. Cost: a second proto, its techs (every upgrade twice), and the transform's rules (hit points,
experience, queued orders). We recommend the stance unless the infantry types matter for balance.

Tested (single player)
2026-11-21, with the horse kept: in a copy of Wars of Liberty, French skirmish against a German AI (crossbowmen)
and test scenarios. The stance switch by the two buttons (posted clicks) and by console, the dismount and mount
transitions, standing, walking and firing on foot beside the horse, the stance kept through the fight (read from
the game every 0.25 s), mounting again, a game saved while dismounted and loaded (stance kept), the AI scripts
compiling with the pack applied. Not tested: multiplayer.
2026-11-22, the horse hidden, the rider on the unit's centre (copy of Wars of Liberty, test scenarios, the stance
set by console): the dismount (the horse there through it, gone after it, the step to the centre) and the mount
(the step back, the horse there again); on foot each rider stands on the middle of his selection circle with the
hit point bar right above him (screenshots of one chasseur mounted and on foot, within a few pixels); standing and
walking on foot with no horse; the torch thrown at an enemy House (its hit points 1042 to 646 in 22 s); fire and
bayonet against four Jaegers, and deaths on foot; the test unit healing a Line Infantry from 36 to 165 hit points
and placing and building a House, with the Heal and Build animations; a game saved dismounted and loaded (still on
foot on the centre, horse hidden), then mounted again; the same fight with --horse keep (horses beside the riders,
dying with them); the AI scripts compiling in a French skirmish against a German AI (11 compiles, 0 errors; it
trained settlers and built a Manor).

ESPAÑOL
-------

Qué hace
- El Chasseur a Cheval tiene dos botones en su fila de comandos: Desmontar y Montar.
- Desmontar: el jinete baja por el lado izquierdo del caballo (animación de 2,5 s) y pelea a pie con las
  animaciones de la infantería (fuego y recarga, bayoneta, la antorcha contra edificios, reposo, marcha, muerte).
- El caballo, por unidad (opción --horse, o la receta de otra unidad): hide (por defecto) lo muestra mientras baja
  y sube y no lo dibuja a pie, como el armón de los cañones al desenganchar; keep lo deja a su lado y camina con él.
- Montar: vuelve a subir (2,5 s) y la unidad es caballería otra vez, en la postura Stagger.
- A pie es más lenta (velocidad x0,67: 4,0 en vez de 6,0). Sus ataques conservan los valores de los ataques montados
  (DefendRangedAttack, MeleeHandAttack) y todo efecto de técnica sobre ellos llega también a los de a pie. Sus tipos,
  puntos de vida, armadura y obstrucción no cambian: una postura no puede cambiarlos (ver abajo).
- Nada en la DLL: solo tácticas, anim files y datos. Los dos botones usan la clave customProtoUnitCommands (ya está
  en el cfg de Wars of Liberty), como todos los comandos que WoL añade.

Instalar
    python apply_fix.py "<carpeta de Wars of Liberty>"                (caballo oculto a pie; copia en <carpeta>\dismount-backup)
    python apply_fix.py "<carpeta de Wars of Liberty>" --horse keep   (el caballo se queda a su lado)
    python apply_fix.py "<carpeta de Wars of Liberty>" --restore      (todo como estaba)
    python apply_fix.py "<carpeta de Wars of Liberty>" --check
Rechaza una carpeta dentro de steamapps salvo con --force. El docstring de apply_fix.py lista cada archivo que toca.
SOLO PRUEBAS: --test añade ChasseuraChevalDismountTest, una copia del Chasseur con construir y curar a pie, para ver
esas animaciones en una copia de prueba; no es el Chasseur de WoL y no se distribuye.

Cómo está hecho (la receta para otra unidad)
1. Tácticas: una copia del archivo de tácticas de la unidad, con dos acciones nuevas (copias de los ataques a
   distancia y cuerpo a cuerpo con otros nombres de animación), una táctica "Dismounted" con esas acciones,
   <speedmodifier>, sus animaciones propias y una <transition> de vuelta a cada táctica montada (<action>Limber</action>,
   <anim>Mount</anim>, <exit>1</exit>; sin <automatic>, para que no cambie sola de postura);
   cada táctica montada lleva una <transition> a "Dismounted" (<anim>Dismount</anim>). Igual que Limber/Bombard de
   la artillería (falconet.tactics).
2. Proto: la unidad apunta al nuevo archivo y recibe <ProtoAction> para las dos acciones nuevas.
3. Técnicas: cada efecto sobre las acciones montadas recibe un gemelo sobre las nuevas (el script lo hace).
4. Botones: dos protounitcommands con unitSetTactic, en la fila de comandos (página 10), sus nombres en
   data\uhc\customprotounitcommands.xml, textos 690911 y 690912.
5. Animaciones: el caballo es el modelo de la unidad y el jinete un adjunto con syncanims="1", así que cada nombre de
   animación va en los dos anim files (el del caballo lleva las etiquetas: ataque, sonido, partícula). Las del jinete
   las hace tools/make_dismount.py de aoe3-blender-tools: a pie, una animación de infantería de la biblioteca
   puesta sobre los huesos del jinete por posición (su esqueleto tiene otra jerarquía), en el suelo junto al
   caballo y compensando el movimiento del hueso del caballo del que cuelga; las transiciones, con poses clave
   interpoladas hueso a hueso. Donde la animación del jinete no dura lo mismo que la del caballo, escribe también un
   clip del caballo de esa duración; en el de ataque, el hueso bone_launchpoint sigue la boca del mosquete.
   Para otra unidad: un JSON de receta con sus modelos, el lado y las animaciones; --sheets dibuja cada animación.
   Una animación escrita guarda sus pistas ordenadas por
   nombre, como las del juego: si no, el juego solo mueve algunos huesos.
6. El caballo, por unidad: con "hide" los clips del caballo a pie (chasseur_horse_hidden_*) dejan bajo tierra (30 m)
   cada hueso con malla y dejan en su sitio la raíz, el hueso del jinete, la barra de vida y el punto de disparo. A
   pie el jinete está en el centro de la unidad (sobre el círculo de selección, bajo la barra de vida): al desmontar,
   ya sin caballo, da unos pasos desde el costado al centro, y al montar vuelve al costado antes de que aparezca el
   caballo (cada transición dura 3,5 s, y el <length> de las tácticas también). Límites: el caballo desaparece y
   aparece de golpe. Con el caballo a la vista (keep), el jinete sigue a 0,85 m del centro, junto al caballo.
   Curar y construir usan las animaciones Heal y Build (y BuildLifting, BuildSaw, BuildStaking), no el <anim> de la
   acción.
7. La postura se mantiene en combate: medido, cuatro chasseurs desmontados siguieron a pie toda la pelea.

Probado (un jugador): escaramuza francesa contra una IA alemana y escenarios de prueba, cambio de postura por
consola (el mismo comando que envían los botones), las transiciones, de pie, caminando y disparando junto al
caballo, montar de nuevo, los dos botones (clics), guardar y cargar desmontado (la postura se conserva) y la IA
compila. 2026-11-22, con el caballo oculto: transiciones, a pie sin caballo, antorcha contra una casa, fuego y
bayoneta contra cuatro Jaegers y muertes a pie, el jinete a pie en el centro del círculo de selección y bajo la barra de vida (medido en capturas), la unidad de
prueba curando (36 a 165) y construyendo una casa,
guardar y cargar desmontado, montar de nuevo, el control con --horse keep y la IA compilando (11 compilaciones,
0 errores). Sin probar: multijugador.

Lo que una postura no puede hacer (pregunta para el equipo)
Una táctica cambia acciones, animaciones y velocidad, no tipos de unidad, armadura, vida, radio de obstrucción ni
<PhysicsInfo>. A pie sigue contando como caballería. Si debe contar como infantería, la alternativa es una
transformación (un segundo proto y un botón con uiTransformSelectedUnit, con la clave transformChecks); el caballo
desaparecería. Recomendamos la postura salvo que los tipos de infantería importen para el balance.
