WoL campaign: the missions load again, and the menu shows only WoL's campaign
==============================================================================

ESPAÑOL

Qué arregla
  Las tres misiones de la campaña "Wars of Liberty" (Barbary Coast 1801, Laguna 1840,
  Hakodate 1869) no cargan: "Scenario: wonders\first barbary war failed to load." Cada
  escenario guarda una tabla con las civilizaciones que existían al guardarlo, y dos de ellas
  ya no están en data\civs.xml (Habsburgs y XPAztec). El juego rechaza el escenario entero
  cuando falta una. Aquí esas dos entradas se renombran a civilizaciones que sí existen
  (TheCircle y Afghans), y cada jugador vuelve a la civilización de su ciudad natal (el juego
  guarda la civilización del jugador como un número, y WoL añadió civilizaciones desde 2022,
  así que hoy cada jugador tenía otra: por ejemplo, el Ejército Imperial de Hakodate jugaba
  como Chile).
  El menú: se oculta "Aprender a jugar" (el tutorial de TAD). La campaña de WoL sigue en
  Un jugador -> Escenarios históricos.

  Laguna, además:
  - Sus unidades Carabinero, Bacamartero y RegimentalLancer ya no existen en protoy.xml.
    Carabinero pasa a Jinete; Bacamartero a Jagunço (WolJagunco); el RegimentalLancer de los
    rebeldes de Garibaldi (los Farrapos) a Lancero, como los Lanceiros Negros, y el del
    Imperio (São José do Norte) a Escolta, un lancero de línea.
  - Nota sobre el Jagunço: el arma coincide (bacamarte), pero el "jagunço" es un pistolero a
    sueldo del Nordeste de finales del siglo XIX: un anacronismo en el sur de Brasil en 1839,
    y además es una unidad forajida de población 4. WoL no tiene infantería regular con
    bacamarte, por eso se queda.
  - El Centro Urbano de Laguna (el objetivo final) aparecía con 0 de vida y moría al empezar,
    con lo que la misión se ganaba sola. La causa está en data\techtreey.xml: al cargar un
    escenario, el jugador 2 empieza un instante como egipcio (la civilización número 2 de
    civs.xml), y Age0Egyptian deja la vida del TownCenter en 0 con "Assign", que no se deshace
    al cambiarle la civilización. Afecta a cualquier escenario en que el jugador 2 tenga un
    Centro Urbano. Se cambia solo ese efecto a "BasePercent" (sigue en 0 mientras la técnica
    está activa, y vuelve a su valor al quitarla). Ahora el Centro Urbano tiene 6500 de vida.
  - Tres mejoras borradas pasan a VeteranMusketeers, GuardMusketeers y VeteranPikemen.
  - Los jugadores de Laguna son Brasileños (sus unidades y edificios lo son).

Notas históricas (para el equipo de WoL)
  - Barbary Coast: los piratas deberían ser Otomanos. Trípoli, Argel y Túnez eran regencias
    otomanas (Trípoli bajo los Karamanli). Siguen siendo Indios solo porque su base está hecha
    con edificios indios; arreglarlo es rehacer la base. Es lo primero que conviene revisar.
  - Laguna: la misión dice 1840, pero Laguna fue tomada (República Juliana) en julio de 1839 y
    recuperada por el Imperio en noviembre de 1839; el ataque a São José do Norte fue en julio
    de 1840. La misión junta los dos hechos.
  - Hakodate 1869: coincide con la historia.

Lo que falta (para el equipo de WoL)
  Los objetivos no se jugaron hasta el final (cada misión se ganó con la consola para probar la
  victoria y el paso a la siguiente). Conviene abrir cada misión en el editor, revisar las
  civilizaciones y las unidades cambiadas, y guardarla. No se probó un jugador egipcio que
  empiece con Centro Urbano después del cambio de Age0Egyptian.

Cómo aplicarlo
  1. HAGA COPIA PRIMERO. WoL-campaign-originals.zip trae los originales de estos 5 archivos.
  2. Descomprima WoL-campaign-fix.zip en la carpeta de WoL (la de age3y.exe) y deje que
     reemplace los archivos.
  Si su data\techtreey.xml es más nuevo que el de este paquete, no lo reemplace: en la técnica
  Age0Egyptian, en el efecto Hitpoints sobre TownCenter, cambie relativity ='Assign' por
  relativity ='BasePercent'.
  Para deshacer: descomprima WoL-campaign-originals.zip igual.

ENGLISH

What this fixes
  The three missions of the "Wars of Liberty" campaign (Barbary Coast 1801, Laguna 1840,
  Hakodate 1869) do not load: "Scenario: wonders\first barbary war failed to load." Each
  scenario keeps a table of the civs the game had when it was saved, and two of them are no
  longer in data\civs.xml (Habsburgs and XPAztec). The game refuses the whole scenario when one
  is missing. Here those two entries are renamed to civs that exist (TheCircle and Afghans), and
  each player is set back to the civ of its home city (the game stores a player's civ as a
  number, and WoL has added civs since 2022, so every player had another civ: Hakodate's
  Imperial Army, for one, played as Chile).
  The menu: "Learn to Play" (TAD's tutorial) is hidden. WoL's campaign stays under
  Single Player -> Historical Scenarios.

  Laguna, also:
  - Its Carabinero, Bacamartero and RegimentalLancer units no longer exist in protoy.xml.
    Carabinero becomes Jinete; Bacamartero becomes Jagunço (WolJagunco); the RegimentalLancer
    of Garibaldi's rebels (the Farrapos) becomes Lancero, like the Lanceiros Negros, and the
    Empire's one (São José do Norte) becomes Escolta, a line lancer.
  - About the Jagunço: the weapon matches (bacamarte), but a "jagunço" is a hired gunman of
    the Northeast in the late 19th century: an anachronism in southern Brazil in 1839, and an
    outlaw unit with pop 4. WoL has no regular blunderbuss infantry, so it stays.
  - Laguna's Town Center (the last objective) loaded with 0 hit points and died at once, so the
    mission won itself. The cause is in data\techtreey.xml: when a scenario loads, player 2 is
    briefly Egyptian (civ number 2 in civs.xml), and Age0Egyptian sets TownCenter hit points to
    0 with "Assign", which is not undone when the civ changes. It affects any scenario where
    player 2 has a Town Center. Only that effect becomes "BasePercent" (still 0 while the tech
    is active, back to normal when it is removed). The Town Center now has 6,500 hit points.
  - Three removed upgrades become VeteranMusketeers, GuardMusketeers and VeteranPikemen.
  - Laguna's players are Brazilians (their units and buildings are).

Historical notes (for the WoL team)
  - Barbary Coast: the pirates should be Ottomans. Tripoli, Algiers and Tunis were Ottoman
    regencies (Tripoli under the Karamanli). They stay Indians only because their base is built
    from Indian buildings; fixing it means rebuilding the base. This is the first thing to
    review.
  - Laguna: the mission says 1840, but Laguna was taken (the Juliana Republic) in July 1839 and
    retaken by the Empire in November 1839; the attack on São José do Norte was in July 1840.
    The mission merges the two.
  - Hakodate 1869: consistent with history.

What is left (for the WoL team)
  The objectives were not played to their end (each mission was won from the console, to test
  the victory and the move to the next mission). Best: open each mission in the editor, check
  the civs and the replaced units, and save it. An Egyptian player starting with a Town Center
  was not tested after the Age0Egyptian change.

Tested
  The campaign from the menu, on Easy: Barbary Coast, Laguna and Hakodate start, run with no
  script error, and each victory leads to the next mission; after Hakodate the campaign screen
  lists all three. Hakodate was also run with WoL's own DLL. With the final files Laguna ran 3
  minutes with its Town Center at 6,500 hit points and no instant win or loss.

What is in it
  Campaign\Wonders\first_barbary_war.age3Yscn, laguna.age3Yscn, battle_of_hakodate.age3Yscn
  data\techtreey.xml (WoL's current file with the one Age0Egyptian change)
  data\uipregamenew.xml
  Campaign\chinaindiajapan.xml (outside Wonders) is an unused old copy; it can be deleted.

How to apply
  1. BACK UP FIRST. WoL-campaign-originals.zip holds WoL's originals of these 5 files.
  2. Unzip WoL-campaign-fix.zip into the WoL folder (the one with age3y.exe), replacing files.
  If your data\techtreey.xml is newer than the one in this package, do not replace it: in the
  Age0Egyptian tech, in the Hitpoints effect on TownCenter, change relativity ='Assign' to
  relativity ='BasePercent'.
  To undo: unzip WoL-campaign-originals.zip the same way.
