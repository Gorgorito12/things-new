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

  Laguna, además: sus unidades Carabinero, Bacamartero y RegimentalLancer ya no existen en
  protoy.xml; pasan a Jinete, Jagunço (WolJagunco) y Lancero, las más cercanas del ejército
  brasileño. El Centro Urbano de Laguna (el objetivo final) aparecía con 0 de vida y moría al
  empezar, con lo que la misión se ganaba sola: ahora es un IGCTownCenter (mismo modelo,
  12 000 de vida). Tres mejoras borradas pasan a VeteranMusketeers, GuardMusketeers y
  VeteranPikemen. Los jugadores de Laguna son Brasileños (sus unidades y edificios lo son).

Lo que falta (para el equipo de WoL)
  Los objetivos no se jugaron hasta el final (cada misión se ganó con la consola para probar la
  victoria y el paso a la siguiente). Conviene abrir cada misión en el editor, revisar las
  civilizaciones y las unidades cambiadas, y guardarla.

Cómo aplicarlo
  1. HAGA COPIA PRIMERO. WoL-campaign-originals.zip trae los originales de estos 4 archivos.
  2. Descomprima WoL-campaign-fix.zip en la carpeta de WoL (la de age3y.exe) y deje que
     reemplace los archivos.
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

  Laguna, also: its Carabinero, Bacamartero and RegimentalLancer units no longer exist in
  protoy.xml; they become Jinete, Jagunço (WolJagunco) and Lancero, the closest units of the
  Brazilian roster. Laguna's Town Center (the last objective) loaded with 0 hit points and died
  at once, so the mission won itself: it is now an IGCTownCenter (same model, 12,000 hit
  points). Three removed upgrades become VeteranMusketeers, GuardMusketeers and VeteranPikemen.
  Laguna's players are Brazilians (their units and buildings are).

What is left (for the WoL team)
  The objectives were not played to their end (each mission was won from the console, to test
  the victory and the move to the next mission). Best: open each mission in the editor, check
  the civs and the replaced units, and save it.

Tested
  The campaign from the menu, on Easy: Barbary Coast, Laguna and Hakodate start, run with no
  script error, and each victory leads to the next mission; after Hakodate the campaign screen
  lists all three. Hakodate was also run with WoL's own DLL.

What is in it
  Campaign\Wonders\first_barbary_war.age3Yscn, laguna.age3Yscn, battle_of_hakodate.age3Yscn
  data\uipregamenew.xml
  Campaign\chinaindiajapan.xml (outside Wonders) is an unused old copy; it can be deleted.

How to apply
  1. BACK UP FIRST. WoL-campaign-originals.zip holds WoL's originals of these 4 files.
  2. Unzip WoL-campaign-fix.zip into the WoL folder (the one with age3y.exe), replacing files.
  To undo: unzip WoL-campaign-originals.zip the same way.
