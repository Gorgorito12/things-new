WoL campaign, historical version: an optional pack on top of the campaign fix
=============================================================================

ESPAÑOL

Qué es
  Un paquete opcional que se instala ENCIMA del arreglo de la campaña (wol-fixes\campaign,
  WoL-campaign-fix.zip) y no lo reemplaza: primero el arreglo, luego este paquete. Cambia las
  tres misiones de la campaña "Wars of Liberty" para que sus bandos, banderas, tropas y textos
  se acerquen a la historia. Los mapas, los disparadores y los objetivos son los mismos.

Las civilizaciones nuevas (ocultas)
  Cinco civilizaciones nuevas, añadidas al FINAL de data\civs.xml en este orden (así ninguna
  civilización existente cambia de número; los escenarios guardan la civilización del jugador
  como un número). Ninguna aparece en la lista de partidas (visible 0); el editor sí las muestra.
    169 HistTripoli        "Regencia de Trípoli": copia de Indios (para que los edificios
                           indios de la base sigan funcionando), con la bandera otomana.
    170 HistUSA            "Estados Unidos": copia de UnitedStates con objects\flags\USA
                           (13 estrellas; la de 1801 tenía 15).
    171 HistSweden         "Suecos": copia de Swedish con objects\flags\swedish (cruz amarilla
                           sobre azul, sin la marca de la unión con Noruega de 1844).
    172 HistFarrapos       "Farrapos": copia de Brasileños con la bandera de la República
                           Riograndense (piratini).
    173 HistImperialJapan  "Japón Imperial": copia de SPCJapanese con una bandera nueva, el
                           Nishiki no mihata (estandarte imperial de brocado rojo con un disco
                           de oro), y la ciudad natal homecitySPC_MJ.xml.
  Si su civs.xml tiene más de 168 civilizaciones (una versión nueva de WoL), los números
  cambian: vea "Versiones nuevas de WoL".

1. Barbary Coast (1801)
  Cambio                                            Por qué
  Jugadores 2 y 3 "Barbary Pirates" -> Regencia de  Trípoli era una regencia otomana (los
  Trípoli, nombre "Tripolitan Corsairs"             Karamanli). La guerra de 1801 fue solo con
                                                    Trípoli. Los edificios indios se quedan: WoL
                                                    no tiene edificios otomanos propios y las
                                                    cúpulas indias se parecen más a Trípoli.
  Recluta (Seimen) -> Jenízaro                      Los mosqueteros de Trípoli eran jenízaros.
  Rodelero, piratas caribeños, Tiger Claw ->        Corsarios berberiscos.
    Corsario berberisco
  Thuggee, Dacoit -> Bashi-bazouk                   Irregulares del mundo otomano.
  Incendiario indio -> Kouloughli                   Mismo papel; los kouloughlis eran parte del
                                                    ejército de Trípoli.
  Akinci -> Sipahi bereber; elefante -> Mameluco    No había elefantes en Libia.
  Cañón de acero y cañón Napoleón -> Falconete      Cañones de la época.
  Capitán pirata (mosquetero del rey de Francia) -> Un rais de Trípoli.
    Corsario berberisco
  Carabelas mercantes -> Jabeques (xebec)           El barco costero del Mediterráneo.
  3 vapores de EE. UU. -> 1 fragata y 2 goletas     No había vapores en 1801 (el primero, 1807).
                                                    Las goletas siguen entrenando marines; si se
                                                    pierden las dos, vuelve el muelle.
  Jugador 4 "Swedish Mining Operation" -> "Swedish  La escuadra de Cederström bloqueó Trípoli en
  Squadron"; su carabela -> fragata                 1802 con fragatas.
  Texto de carga: "argelinos y tripolitanos" ->     Argel no entró en la guerra.
    "corsarios de Trípoli" (cadena 76595)
  Bandera de EE. UU. de 13 estrellas; Suecia con    Las de la época (las de WoL son de 1860).
    cruz sin la unión
  Ficción de WoL que se queda (la mecánica no tiene equivalente): los mineros suecos y el oro que
  dan, el capitán holandés Van Lesen y su rescate, y las chozas de almacén (Ruca mapuche). Los
  prisioneros históricos (la tripulación de la fragata Philadelphia, 1803) no se usan: en la
  misión el único prisionero es Van Lesen.

2. Laguna (1839)
  Cambio                                            Por qué
  Jugadores 1 (Garibaldi) y 5 -> Farrapos, con la   Los rebeldes no llevaban la bandera del
    bandera riograndense                            Imperio. El Imperio sigue siendo Brasileños.
  "Riograndese" -> "Riograndense"                   El nombre correcto.
  Lanceros (ejército 1,11 y unidad 2676) ->         Los Lanceiros Negros de Teixeira Nunes iban
    Lanceiro Negro                                  en la expedición.
  Jagunço -> Bacamarteer                            Mantiene el bacamarte sin el pistolero del
                                                    siglo XIX.
  El samurái Hatamoto suelto -> quitado (bloque     Un resto sin uso.
    invisible)
  Galeones -> goletas; carabelas -> cañoneras       La marina imperial usaba bergantines,
    (también el barco riograndense)                 goletas, patachos y cañoneras.
  Título "Battle of Laguna, 1839"; nodo "Laguna     Laguna se tomó el 22 de julio de 1839.
    (1839)" (cadena 76596)
  Textos de chat de prueba (y uno grosero) y la     Texto de relleno en una campaña publicada.
    descripción del escenario reescritos

3. Hakodate (1869)
  Cambio                                            Por qué
  Jugador 1 -> Japón Imperial con el Nishiki no     El jugador llevaba el emblema Tokugawa, el
    mihata y una ciudad natal de 1869               del enemigo, y envíos de 1600.
    (homecitySPC_MJ.xml: Kihei, Shaguma, Gunto
    Rider, Kanonhou, el mariscal Oyama)
  Arqueros, Yamabushi, Shinobi, ninjas -> Kihei     El ejército de Ezo tenía fusiles y la
                                                    instrucción francesa.
  Ashigaru, Onna-Bushi, Young Garde -> infantería   Infantería de línea.
    de línea
  Sohei -> Shishi (IMShotai)                        Sin monjes guerreros; otra unidad para que
                                                    su bucle de refuerzos cuente solo a ellos.
  Jinetes naginata, Yabusame, gendarmes ->          Caballería japonesa de sable.
    Gunto Rider
  Flechas ardientes -> Kanonhou                     La artillería de Ezo era occidental.
  2 vapores de Ezo sin uso -> Joukisen              Kaiten y Banryu.
  Primera visita a la ciudad natal: ya no dice      Era un texto de la campaña de TAD.
    "Malta, la Metrópoli de Morgan"
  Ezo sigue siendo Japoneses (Hinomaru), como en la historia. El camión monstruo del jugador 1
  es un huevo de pascua de WoL que se destruye al empezar: se deja.
  Ojo: dentro de la campaña el jugador usa la ciudad natal de la campaña (San Luis, desde la
  primera misión), no la del escenario, igual que con el arreglo. La ciudad natal de 1869
  (homecitySPC_MJ.xml) solo cuenta si se juega la misión suelta.

Uniformes históricos (cuatro unidades)
  Cuatro unidades llevan uniformes más cercanos a la historia, SOLO en estas misiones: son
  copias nuevas (protos "Hist...") con texturas y animaciones propias en
  art\WoL\campaign_historical\. Las unidades originales de WoL no cambian en las partidas
  normales. Ningún edificio ni carta las entrena fuera de las misiones.
    Unidad (misión)            Cambio                                       Referencia
    Lanceiro Negro (Laguna)    Se mantiene la coraza de acero; paño y       Juan Manuel Blanes, "Lancero
      HistLanceiroNegro        chiripá rojos, calzoncillo blanco, botas     de la época de Rivera" (s. XIX,
                               de potro, vincha roja y sombrero de gaucho   muestra los años 1830); Debret,
                               (el sombrero es suposición nuestra).         "Gaúcho" (1834-1839).
    Corsario (Costa Berber.)   Camisa blanca, chaleco azul con galón,       Grasset de Saint-Sauveur,
      HistBarbaryCorsair       faja roja y turbante sobre gorro rojo        "Homme des États barbaresques"
                               (en lugar del torso desnudo). Suposición:    (c. 1797). No hay fuente del
                               no hay descripción de los corsarios de       vestido de Trípoli en 1801.
                               Trípoli de 1801.
    Jenízaro (Costa Berber.)   El oro de parada pasa a latón, la seda       Bonnart, "Janissaire d'Alger"
      HistJanissary            blanca a algodón, faja roja, el penacho      (antes de 1718); Duflos (1780).
                               ya no lleva el color del jugador.            Ropa de campaña: suposición.
    Infantería de marina de    Casaca azul (el color del jugador 1),        Donna Neary, "Marines 1798-1804"
    EE. UU. (Costa Berber.)    vueltas rojas, sombrero redondo con borde    (reconstrucción, años 1980);
      HistMarine               amarillo. Edades 1-2: chaleco rojo y         McClellan citado por la USO.
                               pantalón azul (1798-1803). Edades 3-4:       El pantalón blanco de 1804 no
                               casaca de 1804 con galón amarillo y          tiene fuente.
                               pantalón blanco.
  Los marines se entrenan en las goletas del jugador 1, que ahora son una copia
  (HistSchooner) que entrena la copia. Las mejoras de los marines (NAtechUSAmarine01-02, que
  la misión activa al empezar) valen también para la copia: el paquete trae data\techtreey.xml
  (el del arreglo, con cada efecto que nombra a una de las cuatro unidades o a la goleta
  repetido para su copia) y data\protoy.xml (el de WoL con las cinco copias al final).
  Fusileros montados (NAmountedrifle): en esta versión ningún disparador los da ni los
  despliega; solo saldrían de un vapor hecho en el muelle, que vuelve si se pierden las dos
  goletas. Cerrarlo pediría un efecto nuevo en el escenario; se deja así.

Probado (14 de noviembre de 2026)
  Desde el menú de la campaña, en Fácil, con nuestra DLL (inglés) y con la DLL de WoL (español):
  las tres misiones cargan sin errores de script, con sus banderas nuevas (barcos de EE. UU.,
  Centro Urbano de Garibaldi, botón de la ciudad natal de Japón Imperial) y las unidades nuevas
  colocadas y en los ejércitos de los disparadores; ningún objetivo se cumple ni se pierde al
  empezar; cada una corrió de 2 a 9 minutos y la victoria (por consola) lleva a la siguiente, y
  después de Hakodate a la pantalla de la campaña. No se probó: jugar los objetivos hasta el
  final, ver los nombres de las civilizaciones en pantalla (la campaña no los muestra) y la
  primera nota de la ciudad natal (sale una sola vez por perfil).

Versiones nuevas de WoL
  Este paquete trae data\civs.xml, data\buttonsets.xml y las dos tablas de textos completos de
  la versión actual de WoL. Si su WoL es más nuevo, NO los reemplace: añada a mano los trozos de
  la carpeta "fragments" que está junto a este LEEME (no va dentro del zip):
  1. civs-fragment.xml: péguelo justo antes de la última línea </civs> de data\civs.xml. Cuente
     las civilizaciones (<civ> sin comentar): si antes había 168, las nuevas son 169-173 como
     arriba. Si había otro número N, las nuevas son N+1 a N+5 y los escenarios del paquete
     apuntan a números equivocados: hace falta reconstruirlos (tools\scnfix.py player:).
  2. buttonsets-fragment.xml: péguelo en data\buttonsets.xml antes de <set name="JapaneseFlagBtn".
  3. stringtabley-fragment-english.txt (data\stringtabley.xml, inglés) y
     stringtabley-fragment-spanish.txt (data\stringtabley.xml.es-la, español): cambie las dos
     líneas que dice y pegue las tres líneas nuevas antes de </Language>.
  4. protoy-fragment.xml: péguelo justo antes de la última línea </Proto> de data\protoy.xml
     (las cinco unidades "Hist...").
  5. techtreey-fragment.txt: dice, tecnología por tecnología, qué efecto añadir después de cuál
     en data\techtreey.xml (los efectos para las copias).

Idiomas
  WoL tiene la tabla de textos en inglés (stringtabley.xml) y en español latinoamericano
  (stringtabley.xml.es-la, que WoL copia sobre stringtabley.xml al elegir español). El paquete
  trae las dos con los mismos cambios (los textos nuevos en los dos idiomas). Los textos dentro
  de los escenarios (nombres de jugadores, objetivos, chat) están en inglés, como los de WoL.
  Si juega en español: después de instalar, copie data\stringtabley.xml.es-la sobre
  data\stringtabley.xml (o vuelva a elegir el idioma en WoL).

Cómo instalarlo
  1. Instale antes el arreglo de la campaña (WoL-campaign-fix.zip).
  2. HAGA COPIA. WoL-campaign-historical-originals.zip trae lo que este paquete reemplaza (las
     misiones del arreglo y los archivos de WoL).
  3. Descomprima WoL-campaign-historical.zip en la carpeta de WoL (la de age3y.exe) y deje que
     reemplace los archivos.
  Para deshacer: descomprima WoL-campaign-historical-originals.zip igual y borre los archivos
  nuevos: Campaign\Wonders\homecitySPC_MJ.xml y los .ddt "hist_imperial_japan" de
  art\War of the Triple Alliance\Flags y \Buttons, y la carpeta
  art\WoL\campaign_historical. Las misiones vuelven a las del arreglo.

ENGLISH

What it is
  An optional pack installed ON TOP of the campaign fix (wol-fixes\campaign,
  WoL-campaign-fix.zip), which it does not replace: the fix first, then this pack. It changes
  the three missions of the "Wars of Liberty" campaign so that their sides, flags, troops and
  texts come closer to history. The maps, triggers and objectives stay the same.

The new (hidden) civs
  Five new civs, added at the END of data\civs.xml in this order (so no existing civ changes
  number; scenarios store a player's civ as a number). None shows in the game setup lists
  (visible 0); the editor shows them.
    169 HistTripoli        "Regency of Tripoli": a copy of Indians (so the base's Indian
                           buildings keep working), with the Ottoman flag.
    170 HistUSA            "United States": a copy of UnitedStates with objects\flags\USA
                           (13 stars; the 1801 flag had 15).
    171 HistSweden         "Swedes": a copy of Swedish with objects\flags\swedish (yellow cross
                           on blue, without the 1844 union mark with Norway).
    172 HistFarrapos       "Farrapos": a copy of Brazilians with the Riograndense Republic's
                           flag (piratini).
    173 HistImperialJapan  "Imperial Japan": a copy of SPCJapanese with a new flag, the
                           Nishiki no mihata (the imperial red brocade banner with a gold
                           disc), and the home city homecitySPC_MJ.xml.
  If your civs.xml has more than 168 civs (a newer WoL), the numbers change: see "Newer WoL
  versions".

1. Barbary Coast (1801)
  Change                                            Why
  Players 2 and 3 "Barbary Pirates" -> Regency of   Tripoli was an Ottoman regency (the
  Tripoli, named "Tripolitan Corsairs"              Karamanli). The 1801 war was with Tripoli
                                                    alone. The Indian buildings stay: WoL has no
                                                    Ottoman buildings of its own, and the Indian
                                                    domes look closer to Tripoli.
  Recruit (Seimen) -> Janissary                     Tripoli's musketeers were janissaries.
  Rodelero, Caribbean pirates, Tiger Claw ->        Barbary corsairs.
    Barbary Corsair
  Thuggee, Dacoit -> Bashi-bazouk                   Irregulars of the Ottoman world.
  Indian arsonist -> Kouloughli                     Same role; the kouloughlis were part of
                                                    Tripoli's army.
  Akinci -> Berber Sipahi; elephant -> Mamluk       No elephants in Libya.
  Steel gun and Napoleon gun -> Falconet            Guns of the period.
  Pirate captain (a French royal musketeer) ->      A Tripolitan rais.
    Barbary Corsair
  Merchant caravels -> xebecs                       The Mediterranean's coaster.
  3 US steamboats -> 1 frigate and 2 schooners      No steamboats in 1801 (the first, 1807).
                                                    The schooners still train marines; when both
                                                    are lost the dock comes back.
  Player 4 "Swedish Mining Operation" -> "Swedish   Cederström's squadron blockaded Tripoli in
  Squadron"; its caravel -> frigate                 1802 with frigates.
  Load text: "Algerians and Tripolitan pirates" ->  Algiers did not join the war.
    "corsairs of Tripoli" (string 76595)
  13-star US flag; Swedish cross without the union  The flags of the period (WoL's are of the
                                                    1860s).
  WoL's fiction that stays (the mechanic has no historical equivalent): the Swedish miners and
  their gold, the Dutch captain Van Lesen and his rescue, and the storage huts (a Mapuche ruka).
  The historical prisoners (the crew of the frigate Philadelphia, 1803) are not used: in the
  mission the only prisoner is Van Lesen.

2. Laguna (1839)
  Change                                            Why
  Players 1 (Garibaldi) and 5 -> Farrapos, with     The rebels did not fly the Empire's flag.
    the Riograndense flag                           The Empire stays Brazilians.
  "Riograndese" -> "Riograndense"                   The right name.
  Lancers (army 1,11 and unit 2676) -> Lanceiro     Teixeira Nunes's Lanceiros Negros were on
    Negro                                           the expedition.
  Jagunço -> Bacamarteer                            Keeps the blunderbuss without the 19th-century
                                                    gunman.
  The stray Hatamoto samurai -> removed (an         An unused leftover.
    invisible block)
  Galleons -> schooners; caravels -> gunboats       The imperial navy used brigs, schooners,
    (the Riograndense ship too)                     pataches and gunboats.
  Title "Battle of Laguna, 1839"; node "Laguna      Laguna was taken on 22 July 1839.
    (1839)" (string 76596)
  Placeholder chat lines (one of them profane) and  Filler text in a released campaign.
    the scenario description rewritten

3. Hakodate (1869)
  Change                                            Why
  Player 1 -> Imperial Japan with the Nishiki no    The player flew the Tokugawa crest, the
    mihata and an 1869 home city                    enemy's, with shipments of 1600.
    (homecitySPC_MJ.xml: Kihei, Shaguma, Gunto
    Rider, Kanonhou, Marshal Oyama)
  Archers, Yamabushi, Shinobi, ninjas -> Kihei      Ezo's army had rifles and French drill.
  Ashigaru, Onna-Bushi, Young Garde -> Line         Line infantry.
    Infantry
  Sohei -> Shishi (IMShotai)                        No warrior monks; another unit so that their
                                                    reinforcement loop counts only them.
  Naginata riders, Yabusame, gendarmes -> Gunto     Japanese sabre cavalry.
    Rider
  Flaming arrows -> Kanonhou                        Ezo's artillery was Western.
  2 unused Ezo steamboats -> Joukisen               Kaiten and Banryu.
  First home city visit: no longer says "Malta,     It was a text of TAD's campaign.
    Morgan's Home City"
  Ezo stays Japanese (Hinomaru), as in history. Player 1's monster truck is a WoL easter egg
  destroyed at the start: it stays.
  Note: inside the campaign the player uses the campaign's home city (St. Louis, since the first
  mission), not the scenario's, as with the fix. The 1869 home city (homecitySPC_MJ.xml) only
  counts when the mission is played on its own.

Historical uniforms (four units)
  Four units wear uniforms closer to the history, ONLY in these missions: they are new copies
  ("Hist..." protos) with their own textures and anim files in art\WoL\campaign_historical\.
  WoL's own units do not change in normal games. No building or card trains the copies outside
  the missions.
    Unit (mission)             Change                                       Reference
    Lanceiro Negro (Laguna)    The steel cuirass stays; red cloth and       Juan Manuel Blanes, "Lancero
      HistLanceiroNegro        chiripá, white under-drawers, raw-hide       de la época de Rivera" (19th c.,
                               boots, red headband, gaucho hat (the hat     shows the 1830s); Debret,
                               is our inference).                           "Gaúcho" (1834-1839).
    Corsair (Barbary Coast)    White shirt, blue waistcoat with braid,      Grasset de Saint-Sauveur,
      HistBarbaryCorsair       red sash and a turban on a red cap (no       "Homme des États barbaresques"
                               more bare chest). Inference: no source       (c. 1797). No source on
                               describes Tripoli's corsairs of 1801.        Tripoli's dress in 1801.
    Janissary (Barbary Coast)  Parade gold to brass, white silk to          Bonnart, "Janissaire d'Alger"
      HistJanissary            cotton, red sash, the plume no longer in     (before 1718); Duflos (1780).
                               the player colour.                           Campaign dress: inference.
    US Marines                 Blue coat (player 1's colour), red           Donna Neary, "Marines 1798-1804"
    (Barbary Coast)            facings, round hat edged yellow. Ages 1-2:   (1980s reconstruction);
      HistMarine               red waistcoat, blue trousers (1798-1803).    McClellan quoted by the USO.
                               Ages 3-4: the 1804 coatee with yellow tape,  The white trousers of 1804
                               white trousers.                              are not sourced.
  The marines are trained in player 1's schooners, which are now a copy (HistSchooner) that
  trains the copy. The marine upgrades (NAtechUSAmarine01-02, which the mission sets active at
  the start) also reach the copy: the pack ships data\techtreey.xml (the campaign fix's, with
  every effect that names one of the four units or the schooner repeated for its copy) and
  data\protoy.xml (WoL's, with the five copies at the end).
  Mounted riflemen (NAmountedrifle): in this version no trigger gives or deploys them; they could
  only come from a Steamboat built at the dock, which returns when both schooners are lost.
  Closing that would need a new effect in the scenario; left as it is.

Tested (14 November 2026)
  From the campaign menu, on Easy, with our DLL (English) and with WoL's DLL (Spanish): the three
  missions load with no script error, with their new flags (the US ships, Garibaldi's Town
  Center, Imperial Japan's home city button) and the new units, placed and in the trigger
  armies; no objective is won or lost at the start; each ran 2 to 9 minutes, and the victory (by
  console) leads to the next mission, and after Hakodate to the campaign screen. Not tested:
  playing the objectives to their end, seeing the civ names on screen (the campaign does not
  show them) and the first Home City note (shown once per profile).

Newer WoL versions
  This pack carries data\civs.xml, data\buttonsets.xml and both string tables, whole, from the
  current WoL. If your WoL is newer, do NOT replace them: add by hand the pieces of the
  "fragments" folder next to this README (it is not inside the zip):
  1. civs-fragment.xml: paste it right before the last </civs> line of data\civs.xml. Count the
     civs (uncommented <civ>): with 168 before, the new ones are 169-173 as above. With another
     number N, the new ones are N+1 to N+5 and the pack's scenarios point at the wrong numbers:
     they must be rebuilt (tools\scnfix.py player:).
  2. buttonsets-fragment.xml: paste it into data\buttonsets.xml before <set name="JapaneseFlagBtn".
  3. stringtabley-fragment-english.txt (data\stringtabley.xml, English) and
     stringtabley-fragment-spanish.txt (data\stringtabley.xml.es-la, Spanish): change the two
     lines it names and paste the three new lines before </Language>.
  4. protoy-fragment.xml: paste it just before the last line </Proto> of data\protoy.xml (the
     five "Hist..." units).
  5. techtreey-fragment.txt: says, tech by tech, which effect to add after which in
     data\techtreey.xml (the effects for the copies).

Languages
  WoL has its string table in English (stringtabley.xml) and in Latin American Spanish
  (stringtabley.xml.es-la, which WoL copies over stringtabley.xml when Spanish is chosen). The
  pack carries both with the same changes (the new strings in both languages). The texts inside
  the scenarios (player names, objectives, chat) are in English, like WoL's.
  If you play in Spanish: after installing, copy data\stringtabley.xml.es-la over
  data\stringtabley.xml (or choose the language in WoL again).

How to install
  1. Install the campaign fix first (WoL-campaign-fix.zip).
  2. BACK UP. WoL-campaign-historical-originals.zip holds what this pack replaces (the fix's
     missions and WoL's files).
  3. Unzip WoL-campaign-historical.zip into the WoL folder (the one with age3y.exe), replacing
     files.
  To undo: unzip WoL-campaign-historical-originals.zip the same way and delete the new files:
  Campaign\Wonders\homecitySPC_MJ.xml and the "hist_imperial_japan" .ddt files in
  art\War of the Triple Alliance\Flags and \Buttons, and the folder
  art\WoL\campaign_historical. The missions go back to the fix's.
