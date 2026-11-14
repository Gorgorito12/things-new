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

Lo que falta (para el equipo de WoL)
  Laguna carga pero termina enseguida: sus unidades iniciales son Carabinero, Bacamartero y
  RegimentalLancer, que ya no existen en protoy.xml. Hay que decidir qué unidades van y volver
  a guardar la misión en el editor.

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

What is left (for the WoL team)
  Laguna loads but ends at once: its starting units are Carabinero, Bacamartero and
  RegimentalLancer, which protoy.xml no longer has. Someone has to choose the units and save the
  mission again in the editor.

Tested
  Barbary Coast and Hakodate start and play (several minutes, no script error), with the
  engine-extension DLL and with WoL's own DLL.

What is in it
  Campaign\Wonders\first_barbary_war.age3Yscn, laguna.age3Yscn, battle_of_hakodate.age3Yscn
  data\uipregamenew.xml
  Campaign\chinaindiajapan.xml (outside Wonders) is an unused old copy; it can be deleted.

How to apply
  1. BACK UP FIRST. WoL-campaign-originals.zip holds WoL's originals of these 4 files.
  2. Unzip WoL-campaign-fix.zip into the WoL folder (the one with age3y.exe), replacing files.
  To undo: unzip WoL-campaign-originals.zip the same way.
