Faith: villagers pray at their church or mosque (request #101)
================================================================

ENGLISH
-------

An OPTIONAL feature. Nothing changes unless you turn on both parts:
1. the DLL key `faithResource` in engine-ext\engine-ext.cfg (our dinput8.dll beside WoL's own uhc.dll, the usual
   WoL setup), or in Startup\wol.cfg if our UHC.dll is used in place of WoL's (it is off unless the line is there), and
2. this data and animation pack (apply_fix.py). The pack changes nothing until it is applied, and --restore takes
   every file back byte for byte.
No other pack depends on it. The resource panel's faith row is a separate pack, wol-fixes/faith-panel/, made to go
with this one.

What it does
- Faith is its own resource: the engine's resource 4 ("SkillPoints"), unused by WoL's data. Oil stays where it is
  (resource 3, "Fame").
- Villagers of the Christian and Islamic civs pray at their worship building (Church, the Greek Temple, the Egyptian
  Temple Caravan, the Saudi Temple Caravan) and gather faith: 0.25 per second each (the Maypole's rate), up to 10 at
  one building. Right-click the building with villagers, as for any resource.
- Christian villagers kneel with their hands together; Islamic villagers kneel, sit back and bow to the ground.
  Each civ's villagers use their own models, hats and clothes (the animation plays on the model they already have).
- The new resource is gathered, counted, saved and loaded like food or gold: costs, tributes, the AI's
  kbResourceGet(cResourceSkillPoints), {resource(skillpoints)} and {numGatherers(skillpoints)} in the interface,
  uiFindResourceGatherers("skillpoints"). Its name in the game is "Faith" (string 28530).

Why the DLL key is needed (in the engine, resource 4 is the home city's skill points)
- Every read of resource 4 adds the home city's unspent skill points: without the key, the faith counter starts at
  the player's skill points (9 with the Istanbul home city of the test) and shows them all game.
- At the end of a game the engine adds resource 4 to the home city's skill points: without the key, the faith
  gathered in a game would become free home city skill points in the player's profile.
- The engine never plays a Gather action's own animation (it picks one from the target: mine, tree, farm, hunt,
  fish, crate; anything else dances like the Maypole). The key plays the action's <anim> when the gathered resource
  is faith and the villager's model has that animation.
The key removes those three and changes nothing else (an AI still starts with resource 4 = its home city level
+ 15, its budget for the home city cards it buys at the start; what it does not spend stays as faith): oil, XP and its banking into the home city, the home city's
skill points and the other gather animations stay as they are.

Install
    1. engine-ext\engine-ext.cfg (or Startup\wol.cfg with our UHC.dll in place of WoL's): add the line
           faithResource
       (or "faithResource log" to log, at the end of each game, the faith that was not banked).
    2. python apply_fix.py "<Wars of Liberty folder>"              (backup in <folder>\faith-backup)
       python apply_fix.py "<Wars of Liberty folder>" --no-ai      (the same without the AI script change)
       python apply_fix.py "<Wars of Liberty folder>" --check      (what is applied)
       python apply_fix.py "<Wars of Liberty folder>" --restore    (everything back as it was)
    The script refuses a folder under steamapps unless --force is given.

What the pack changes (the docstring of apply_fix.py lists it in full)
- data\protoy.xml: the four worship buildings hold faith (<InitialResource> and <CarryCapacity> of SkillPoints,
  <ResourceSubType>Fame, <GathererLimit>10, UnlimitedSupply, the Resource type); 22 villager protos get a
  <ProtoAction> Pray with 0.25 on each building.
- data\tactics\ (settler, coureur, convictLabourer, jornalero, roto, juana, wolVillagerKoygua, peasant, romaSlave):
  a Gather action Pray (<anim>Pray</anim>, the four buildings), listed after Gather in each tactic.
- data\techtreey.xml: Age0zulu turns Pray off for AFRICANvillager (the Zulu share the Ethiopians' villager).
- 20 villager anim files: PrayIn, Pray and PrayOut after each praying model's Idle (a copy of that Idle with its
  models and hats, without tools or guns in the hands).
- art\WoL\units\villagers\settler\pray\: 12 new clips, made by aoe3-blender-tools' tools/make_pray.py (design 1,
  kneel, and design 3, bow; male and female; entry, loop, exit) on the villager's own skeleton.
- data\stringtabley.xml and translations\*\stringtabley.xml: string 28530 "Faith" (it was "Home City Upgrades
  Available"), 1010001 "Pray", and in the English tables one line at the end of the four buildings' rollovers.
- AI4\aiWoLMain.xs, rule buyCards (unless --no-ai): it reads its card budget through
  kbResourceGet(cResourceSkillPoints), which the engine gave as resource 4 plus the home city's unspent skill points.
  With the key it is resource 4 alone, so every such read in the rule becomes
  (kbResourceGet(cResourceSkillPoints) + kbGetHCLevel(cMyID) - 1): the AI buys the same cards as before (14 in the
  test, with and without the key).

Which civs pray (decided from WoL's data: each civ's villagers, its worship building, its history)
- Christian (kneel), at the Church unless noted: British, French (WOLPiedNoir), Dutch (DutchSettler,
  AfricanSlaveBrit), Germans, Austro-Hungarians, Belgians, Danes, Swedes, Russians, Portuguese, Spanish, Italians
  (Merchant; WoL gives them no Church today), United States and Canadians (WOLPioneer), Australians
  (ConvictLabourer), Bulgarians, Romanians (Peasant, RomaSlave) and Serbians (Peasant), Greeks (Peasant, at the Greek
  Temple), Ethiopians (AFRICANvillager), Bolivians (Mitayo), Brazilians (AfricanSlave), Central Americans
  (WOLJornalero), Chileans (Roto), Colombians (WoLJuana), Haitians (WOLSevite), Mexicans (Tlaquehual), Paraguayans
  (Villero), Peruvians (WOLCholo), Uruguayans (WoLBaqueano).
- Islamic (bow): Ottomans (Settler, the Ottoman models; at the Church, which they see as a mosque), Persians, Afghans
  and Uzbeks (SettlerME, at the Church), Saudis (SettlerME, at the Temple Caravan), Egyptians (EGYPTIANvillager, at
  the Temple Caravan).
- Not yet (questions below): the Asian civs (Chinese, Japanese, Koreans, Indians), the natives (Iroquois, Sioux,
  Mapuche), the Maori, the Zulu; and among the civs above, the Argentines (their only villager rides a horse), the
  Dutch JavaneseLabourer, the Central American WOLCarretero (a cart driver) and the Haitian WOLZombi.

Limits
- The engine plays only the loop (Pray). PrayIn and PrayOut are in the anim files, but a Gather action has no entry
  or exit animation: a villager kneels at once when it starts and stands at once when given another order.
- WOLPiedNoir's anim file has no Idle: its Pray copies the Cheer without the musket, with the male clips for both
  of its models.
- The female villagers' skirt hem goes under the ground when they kneel (the cloth follows the calves).

Tested (2026-11-23/24, our UHC.dll in a Wars of Liberty 1.0.15c copy, single player): see the modding guide,
section faithResource.

ESPAÑOL
-------

Una función OPCIONAL. Nada cambia si no se activan las dos partes:
1. la clave del DLL `faithResource` en engine-ext\engine-ext.cfg (nuestro dinput8.dll junto al uhc.dll de WoL, lo
   normal en WoL), o en Startup\wol.cfg si se usa nuestro UHC.dll en lugar del de WoL (está apagada si la línea no
   está), y
2. este paquete de datos y animaciones (apply_fix.py). El paquete no cambia nada hasta aplicarlo, y --restore
   devuelve cada archivo byte por byte.
Ningún otro paquete depende de este. La fila de fe del panel de recursos es otro paquete, wol-fixes/faith-panel/,
hecho para ir con este.

Qué hace
- La fe es un recurso propio: el recurso 4 del motor ("SkillPoints"), que los datos de WoL no usan. El petróleo
  sigue donde está (recurso 3, "Fame").
- Los aldeanos de las civilizaciones cristianas e islámicas rezan en su edificio de culto (la Iglesia, el Templo
  griego, la Caravana del Templo egipcia y la saudí) y recolectan fe: 0,25 por segundo cada uno (la tasa del Maypole),
  hasta 10 por edificio. Clic derecho en el edificio con aldeanos, como cualquier recurso.
- Los aldeanos cristianos se arrodillan con las manos juntas; los islámicos se arrodillan, se sientan sobre los
  talones y se postran hasta el suelo. Cada civilización usa sus propios modelos, sombreros y ropa.
- El recurso nuevo se recolecta, cuenta, guarda y carga como la comida o el oro. En el juego se llama "Faith".

Por qué hace falta la clave del DLL (en el motor, el recurso 4 son los puntos de habilidad de la metrópoli)
- Cada lectura del recurso 4 suma los puntos sin gastar de la metrópoli: sin la clave, el contador de fe empieza en
  esos puntos (9 con la metrópoli de Estambul de la prueba).
- Al terminar una partida el motor suma el recurso 4 a los puntos de la metrópoli: sin la clave, la fe se convertiría
  en puntos de metrópoli gratis en el perfil del jugador.
- El motor nunca reproduce la animación propia de una acción Gather (elige una según el objetivo; lo demás baila
  como en el Maypole). La clave reproduce el <anim> de la acción cuando el recurso es la fe y el modelo la tiene.
La clave quita esas tres cosas y no cambia nada más (la IA sigue empezando con el recurso 4 = nivel + 15, su
presupuesto para las cartas de metrópoli; lo que no gasta queda como fe): el petróleo, la XP y su paso a la metrópoli, los puntos de la
metrópoli y las demás animaciones de recolección siguen igual.

Instalación: la línea `faithResource` en engine-ext\engine-ext.cfg (o en Startup\wol.cfg con nuestro UHC.dll en
lugar del de WoL), y luego
    python apply_fix.py "<carpeta de Wars of Liberty>"             (copia de seguridad en <carpeta>\faith-backup)
    python apply_fix.py "<carpeta de Wars of Liberty>" --no-ai     (sin el cambio del script de la IA)
    python apply_fix.py "<carpeta de Wars of Liberty>" --check     (qué está aplicado)
    python apply_fix.py "<carpeta de Wars of Liberty>" --restore   (todo como estaba)

Qué civilizaciones rezan, y los límites: ver la parte en inglés.

Beside WoL's own uhc.dll (tested 2026-11-27)
--------------------------------------------
WoL's uhc.dll (c070d138, WoL.dll loaded by preloadDll), our dinput8.dll 0.6.0, the packs applied with their
apply_fix.py (the scripts that write a key put it in engine-ext\engine-ext.cfg by themselves; the other lines were
added there by hand), at the main menu, engine-ext\engine-ext.log (24 keys applied, 1 FAILED of all the packs'
keys):
  faithResource              applied

Junto al uhc.dll de WoL (probado el 2026-11-27, nuestro dinput8.dll, la línea en engine-ext\engine-ext.cfg): faithResource se aplica (applied).
