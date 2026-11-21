Dismount: the Chasseur a Cheval fights on foot (request #84)
================================================================

ENGLISH
-------

What it does
- The Chasseur a Cheval gets two buttons on its command row: Dismount and Mount.
- Dismount: the rider gets off on the horse's left side (a 2 s animation), then stands beside his horse and
  fights with the infantry's own animations (volley fire and reload, bayonet, idle, walk, death). The horse stays
  beside him and walks with him.
- Mount: he climbs back on (2 s) and the unit is cavalry again, in the Stagger stance.
- On foot the unit is slower (speed x0.67, the line infantry's 4.0 instead of 6.0). Its attacks keep the numbers
  of the mounted attacks (DefendRangedAttack, MeleeHandAttack), and every tech effect on those reaches the attacks
  on foot too. Its unit types, hit points, armour and obstruction do not change: a stance cannot change them
  (see "What a stance cannot do" below).
- Nothing in the DLL: tactics, anim files and data only. The two buttons need the DLL key customProtoUnitCommands
  (already in Wars of Liberty's cfg), like every command type WoL adds.

Install
    python apply_fix.py "<Wars of Liberty folder>"            (backup in <folder>\dismount-backup)
    python apply_fix.py "<Wars of Liberty folder>" --restore  (everything back as it was)
    python apply_fix.py "<Wars of Liberty folder>" --check
The script refuses a folder under steamapps unless --force is given. The docstring of apply_fix.py lists every
file it changes.

How it is built (the recipe for another unit)
1. Tactics. A copy of the unit's tactics file. Two new actions, copies of the mounted ranged and hand attacks with
   other animation names (Dismounted_Attack, Dismounted_Reload, Dismounted_Melee, Dismounted_Idle). A new
   tactic "Dismounted" with those actions, <speedmodifier>, its own idle/bored/walk/jog/run/death animations, and
   one <transition> back to each mounted tactic (<action>Limber</action>, <anim>Mount</anim>, <length>2</length>,
   <exit>1</exit>). Every mounted tactic gets a <transition> to "Dismounted" (<anim>Dismount</anim>). This is how
   the artillery's Limber/Bombard works (falconet.tactics). <exit>1 is what lets a button's tactic change use the
   transition; <action>Limber</action> is the built-in transition action every stock artillery transition names.
   No <automatic>: with it the unit would switch on its own to reach an action of the other stance.
2. Proto (protoy.xml). The unit points at the new tactics file and gets <ProtoAction>s for the two new actions
   (copies of the mounted ones: damage, range, ROF, bonuses).
3. Techs (techtreey.xml). An action name is what a tech effect targets, so every effect on the mounted actions
   gets a twin on the new ones (the script does it: 207 effects in WoL today).
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
   unit then played its mounted attack while on foot; `--sheets` draws every animation as a contact sheet first.
   A written animation keeps its tracks sorted by name, as the stock files do: the game looks a bone's track up by
   binary search, and an unsorted file moves only some bones.
6. The stance holds in a fight. Measured: four dismounted chasseurs kept the stance (tactic index 3) through a
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
In a copy of Wars of Liberty: French skirmish against a German AI (crossbowmen) and test scenarios. The stance
switch by console (unitSetTactic, the command the buttons send), the dismount and mount transitions, standing,
walking and firing on foot beside the horse, the stance kept through the fight (read from the game every 0.25 s),
mounting again. Not tested: the two buttons clicked by hand, death on foot filmed, a saved game, multiplayer.

ESPAÑOL
-------

Qué hace
- El Chasseur a Cheval tiene dos botones en su fila de comandos: Desmontar y Montar.
- Desmontar: el jinete baja por el lado izquierdo del caballo (animación de 2 s), se queda de pie junto a él y
  pelea con las animaciones de la infantería (fuego y recarga, bayoneta, reposo, marcha, muerte). El caballo se
  queda a su lado y camina con él.
- Montar: vuelve a subir (2 s) y la unidad es caballería otra vez, en la postura Stagger.
- A pie es más lenta (velocidad x0,67: 4,0 en vez de 6,0). Sus ataques conservan los valores de los ataques montados
  (DefendRangedAttack, MeleeHandAttack) y todo efecto de técnica sobre ellos llega también a los de a pie. Sus tipos,
  puntos de vida, armadura y obstrucción no cambian: una postura no puede cambiarlos (ver abajo).
- Nada en la DLL: solo tácticas, anim files y datos. Los dos botones usan la clave customProtoUnitCommands (ya está
  en el cfg de Wars of Liberty), como todos los comandos que WoL añade.

Instalar
    python apply_fix.py "<carpeta de Wars of Liberty>"            (copia de seguridad en <carpeta>\dismount-backup)
    python apply_fix.py "<carpeta de Wars of Liberty>" --restore  (todo como estaba)
    python apply_fix.py "<carpeta de Wars of Liberty>" --check
Rechaza una carpeta dentro de steamapps salvo con --force. El docstring de apply_fix.py lista cada archivo que toca.

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
6. La postura se mantiene en combate: medido, cuatro chasseurs desmontados siguieron a pie toda la pelea.

Probado (un jugador): escaramuza francesa contra una IA alemana y escenarios de prueba, cambio de postura por
consola (el mismo comando que envían los botones), las transiciones, de pie, caminando y disparando junto al
caballo, y montar de nuevo. Sin probar: los botones con clic real, una partida guardada, multijugador.

Lo que una postura no puede hacer (pregunta para el equipo)
Una táctica cambia acciones, animaciones y velocidad, no tipos de unidad, armadura, vida, radio de obstrucción ni
<PhysicsInfo>. A pie sigue contando como caballería. Si debe contar como infantería, la alternativa es una
transformación (un segundo proto y un botón con uiTransformSelectedUnit, con la clave transformChecks); el caballo
desaparecería. Recomendamos la postura salvo que los tipos de infantería importen para el balance.
