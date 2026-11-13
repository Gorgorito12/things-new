WoL building models with their impact and attach bones fixed
=============================================================

ENGLISH

What this fixes
  On 107 WoL building models (most of them the Middle East buildings) the bones that effects
  hang on (impact points, flags, smoke and launch points) carry a scale of 100, the centimetres
  of the export (75 and 90 on a few). When a cannonball hits one of these buildings on an impact
  point of type "wood", the game draws the wood splinters through that bone, so they come out
  100 times too big: long grey streaks across the whole screen. No shipping .dmg file puts
  "wood" on these buildings today; the streaks appear as soon as one does. In these models those
  bones are brought to scale 1. Their position and direction stay the same and no mesh is
  touched. Tested in game on the Mahalla and the Temple (splinters on the walls instead of
  streaks) and on the Royal Court, Madrasah and Forge (flags and smoke where they were); all of
  them burn and collapse as before. Construction was not tested (no construction model changes).

What is in it
  107 models (.gr2), listed below with the bones changed in each. Nothing else changes: no
  data, no .xml, no .dmg, no texture.

Size
  The files are written uncompressed (WoL's are Oodle-compressed), so they are bigger:
  16.5 MB in all, against 7.0 MB for the originals (+9.6 MB).

How to apply
  1. BACK UP FIRST. These files replace WoL's own files of the same name (they are loose files,
     not inside the .bar archives). Keep WoL-building-bones-originals.zip, which is shipped
     beside this zip and holds WoL's originals of exactly these files, or copy them yourself.
  2. Unzip into the WoL folder (the one with age3y.exe), letting the "art" folder merge and the
     files be replaced.

How to undo
  Unzip WoL-building-bones-originals.zip into the WoL folder the same way. Do not just delete the
  files: WoL needs them.

impactBoneFix
  With these models the impactBoneFix key of the engine-extension DLL is no longer needed for
  them; leaving it on does no harm.

Not changed, and why
  - TOW\buildings\Tower: Tower_Model, TowerDamagedTest_Model (bones at 1/26), and lvl3
    Towerlvl3_Model, lvl3_damaged_Model, also under art\buildings\Tower\lvl3 (1/15);
  - WoL\buildings\immigrants\Croatian and French: colony, colony_damaged (1/39);
  - WoL\buildings\kumara_field and buildings\polynesia\kumara_field: kumara_field_damaged (11).
  These are not the export's x100: their authors may have sized flags and smoke to those bones,
  and they show no streaks (the TOW tower, hit by cannon in game: none). They are left as they are.
  The death models and a few damage models keep a scaled bone that carries debris meshes; the
  tool never changes such a bone.


ESPAÑOL

Qué corrige
  En 107 modelos de edificios de WoL (casi todos los de Oriente Medio) los huesos donde se
  cuelgan los efectos (puntos de impacto, banderas, humo y puntos de disparo) tienen escala 100,
  los centímetros de la exportación (75 y 90 en unos pocos). Cuando una bala de cañón golpea uno
  de esos edificios en un punto de impacto de tipo "wood", el juego dibuja las astillas a través
  de ese hueso y salen 100 veces más grandes: largas rayas grises que cruzan toda la pantalla.
  Hoy ningún .dmg de WoL pone "wood" en estos edificios; las rayas aparecen en cuanto uno lo hace.
  En estos modelos esos huesos quedan con escala 1. Su posición y dirección no cambian y no se
  toca ninguna malla. Probado en el juego con la Mahalla y el Templo (astillas en los muros en
  vez de rayas) y con la Corte Real, la Madrasa y la Forja (banderas y humo en su sitio); todos
  arden y se derrumban igual que antes. No se probó la construcción (ningún modelo de
  construcción cambia).

Qué contiene
  107 modelos (.gr2), listados abajo con los huesos cambiados en cada uno. Nada más cambia:
  ni datos, ni .xml, ni .dmg, ni texturas.

Tamaño
  Los archivos van sin comprimir (los de WoL usan Oodle), así que pesan más: 16.5 MB en total,
  frente a 7.0 MB de los originales (+9.6 MB).

Cómo aplicarlo
  1. HAGA UNA COPIA ANTES. Estos archivos reemplazan archivos de WoL con el mismo nombre (son
     archivos sueltos, no están dentro de los .bar). Guarde WoL-building-bones-originals.zip,
     que va junto a este zip y tiene los originales de WoL de exactamente estos archivos, o
     cópielos usted mismo.
  2. Descomprimir en la carpeta de WoL (la que tiene age3y.exe), dejando que la carpeta "art" se
     combine y los archivos se reemplacen.

Cómo deshacerlo
  Descomprimir WoL-building-bones-originals.zip en la carpeta de WoL de la misma forma. No borre
  los archivos sin más: WoL los necesita.

impactBoneFix
  Con estos modelos la opción impactBoneFix de la DLL de extensiones ya no hace falta para
  ellos; dejarla activada no hace daño.

No cambiados, y por qué
  - TOW\buildings\Tower: Tower_Model, TowerDamagedTest_Model (huesos a 1/26), y lvl3
    Towerlvl3_Model, lvl3_damaged_Model, también en art\buildings\Tower\lvl3 (1/15);
  - WoL\buildings\immigrants\Croatian y French: colony, colony_damaged (1/39);
  - WoL\buildings\kumara_field y buildings\polynesia\kumara_field: kumara_field_damaged (11).
  No son el x100 de la exportación: sus autores pueden haber ajustado banderas y humo a esos
  huesos, y no muestran rayas (la torre TOW, bajo fuego de cañón en el juego: ninguna). Se
  quedan como están. Los modelos de muerte y algunos de daño conservan un hueso escalado que
  lleva mallas de escombros; la herramienta nunca cambia un hueso así.


FILES / ARCHIVOS (bones changed / huesos cambiados)

  art\buildings\modern\british\british_HQ_corps\british_hq_corps_base.GR2
      Flag AE Dummy 01
  art\WoL\buildings\immigrants\Confederate\ConfederateColony_Model.gr2
      BONE_HITPOINTBAR, bone_chimney, bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_launchpoint04, GARRISONFLAG
  art\WoL\buildings\immigrants\Confederate\ConfederateColonyDeath_Model.gr2
      Object01, Object02, Object03, Object04, Object05, Object06, Object07, Object08, Object09, Object10, Object11, Object12, Object13, Object14, Object15, Object16, Object17, Object18, Object19, Object20, Object21, Object22, Object23, Object30, Object31, Object32, Object33, Object34, Object35, Object36, Object37, Object38, Object39, Object40, Object41, Object42, Object43, Object44, Object45
  art\WoL\buildings\immigrants\Confederate\ConfederateColonyDmg_Model.gr2
      bone_hitpointbar, bone_chimney, debris_1a, debris_1b, debris_1c, debris_1d, debris_1e, debris_1f, debris_1g, debris_1h, debris_1i, debris_1j, debris_1k, debris_1l, debris_2a, debris_2c, debris_2d, debris_2b, debris_2e, debris_2f, debris_3a, debris_3b, debris_3c, debris_3d, debris_3f, debris_4a, debris_4b, debris_3g, debris_3e, boneimpact01, boneimpact02, boneimpact03, boneimpact04, GARRISONFLAG
  art\WoL\buildings\immigrants\Croatian\Croat_dmg_Model.gr2
      bone_place00, bone_place01, bone_chimmey, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05
  art\WoL\buildings\immigrants\Croatian\CroatianHouse_dmg_Model.gr2
      bone_chimney, bone_impact01, bone_impact02, bone_impact03
  art\WoL\buildings\immigrants\Croatian\CroatianHouse_Model.gr2
      bone_chimney
  art\WoL\buildings\immigrants\French\FrenchColony_dmg_Model.gr2
      bone_chimney, bone_props01, bone_chimney2, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06
  art\WoL\buildings\immigrants\French\FrenchColony_Model.gr2
      bone_chimney, bone_props01, bone_chimney2
  art\WoL\buildings\immigrants\French\FrenchHouse_dmg_Model.gr2
      bone_chimney, bone_impactpoint01
  art\WoL\buildings\immigrants\French\FrenchHouse_Model.gr2
      bone_chimney
  art\WoL\buildings\immigrants\Polish\PolishColony_Model.gr2
      BONE_HITPOINTBAR, bone_chimney, bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_launchpoint04, GARRISONFLAG
  art\WoL\buildings\immigrants\Polish\PolishColonyDeath_Model.gr2
      Object01, Object02, Object03, Object04, Object05, Object06, Object07, Object08, Object09, Object10, Object11, Object12, Object13, Object14, Object15, Object16, Object17, Object18, Object19, Object20, Object21, Object22, Object23, Object30, Object31, Object32, Object33, Object34, Object35, Object36, Object37, Object38, Object39, Object40, Object41, Object42, Object43, Object44, Object45
  art\WoL\buildings\immigrants\Polish\PolishColonyDmg_Model.gr2
      bone_hitpointbar, bone_chimney, debris_1a, debris_1b, debris_1c, debris_1d, debris_1e, debris_1f, debris_1g, debris_1h, debris_1i, debris_1j, debris_1k, debris_1l, debris_2a, debris_2c, debris_2d, debris_2b, debris_2e, debris_2f, debris_3a, debris_3b, debris_3c, debris_3d, debris_3f, debris_4a, debris_4b, debris_3g, debris_3e, boneimpact01, boneimpact02, boneimpact03, boneimpact04, GARRISONFLAG
  art\WoL\buildings\immigrants\Spanish\SpanishColony_dmg_Model.gr2
      bone_place00, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05
  art\WoL\buildings\immigrants\Spanish\SpanishColony_Model.gr2
      bone_place00
  art\WoL\buildings\immigrants\Spanish\SpanishHouse_dmg_Model.gr2
      bone_impactpoint01, bone_impactpoint02, bone_impactpoint03
  art\WoL\buildings\ME\bazaar\Market1_dmg_Model.gr2
      bone_flag_civ, bone_impactpoint01, bone_impactpoint02
  art\WoL\buildings\ME\bazaar\Market1_lp_Model.gr2
      bone_flag_civ
  art\WoL\buildings\ME\bazaar\Market1_Model.gr2
      bone_flag_civ
  art\WoL\buildings\ME\bazaar\Market2_dmg_Model.gr2
      bone_flag_civ, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06
  art\WoL\buildings\ME\bazaar\Market2_lp_Model.gr2
      bone_main, bone_flag_civ
  art\WoL\buildings\ME\bazaar\Market2_Model.gr2
      bone_flag_civ
  art\WoL\buildings\ME\bazaar\Market4_dmg_Model.gr2
      bone_flag_civ, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06, bone_impactpoint07, bone_impactpoint08, bone_impactpoint09
  art\WoL\buildings\ME\bazaar\Market4_lp_Model.gr2
      bone_flag_civ
  art\WoL\buildings\ME\bazaar\Market4_Model.gr2
      bone_flag_civ
  art\WoL\buildings\ME\caravanserai\Caravanserai_dmg_Model.gr2
      bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_launchpoint04, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05
  art\WoL\buildings\ME\caravanserai\Caravanserai_lp_Model.gr2
      bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_launchpoint04
  art\WoL\buildings\ME\caravanserai\Caravanserai_Model.gr2
      bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_launchpoint04
  art\WoL\buildings\ME\citadel\Citadel1_dmg_Model.gr2
      bone_flag_civ, GARRISONFLAG, bone_launchpoint01, bone_launchpoint04
  art\WoL\buildings\ME\citadel\Citadel4_dmg_Model.gr2
      bone_flag_civ, GARRISONFLAG, bone_launchpoint02, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06, bone_impactpoint07
  art\WoL\buildings\ME\dildo\Tower1_dmg_Model.gr2
      bone_flag_civ, GARRISONFLAG, bone_launchpoint00, bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_impactpoint01
  art\WoL\buildings\ME\dildo\Tower2_dmg_Model.gr2
      bone_flag_civ, GARRISONFLAG, bone_launchpoint00, bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03
  art\WoL\buildings\ME\dildo\Tower4_dmg_Model.gr2
      bone_flag_civ, GARRISONFLAG, bone_launchpoint00, bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03
  art\WoL\buildings\ME\dock\dock1_dmg_Model.gr2
      bone_flag_civ, BONE_HITPOINTBAR, India_Dock_Age01, BONE_GARRISONFLAG, bone_impactpoint1
  art\WoL\buildings\ME\dock\dock1_lp_Model.gr2
      bone_flag_civ, BONE_HITPOINTBAR, India_Dock_Age01, BONE_GARRISONFLAG
  art\WoL\buildings\ME\dock\Dock1_Model.gr2
      bone_flag_civ, BONE_HITPOINTBAR, India_Dock_Age01, BONE_GARRISONFLAG
  art\WoL\buildings\ME\dock\dock2_dmg_Model.gr2
      bone_flag_civ, BONE_HITPOINTBAR, India_Dock_Age02, BONE_GARRISONFLAG, bone_impactpoint1, bone_impactpoint2, bone_impactpoint3
  art\WoL\buildings\ME\dock\dock2_lp_Model.gr2
      bone_flag_civ, BONE_HITPOINTBAR, India_Dock_Age02, BONE_GARRISONFLAG
  art\WoL\buildings\ME\dock\Dock2_Model.gr2
      bone_flag_civ, BONE_HITPOINTBAR, India_Dock_Age02, BONE_GARRISONFLAG
  art\WoL\buildings\ME\dock\dock4_dmg_Model.gr2
      bone_flag_civ, BONE_HITPOINTBAR, India_Dock_Age04, BONE_GARRISONFLAG, bone_impactpoint1, bone_impactpoint2, bone_impactpoint3, bone_impactpoint4, bone_impactpoint5, bone_impactpoint6
  art\WoL\buildings\ME\dock\dock4_lp_Model.gr2
      bone_flag_civ, BONE_HITPOINTBAR, India_Dock_Age04, BONE_GARRISONFLAG
  art\WoL\buildings\ME\dock\Dock4_Model.gr2
      bone_flag_civ, BONE_HITPOINTBAR, India_Dock_Age04, BONE_GARRISONFLAG
  art\WoL\buildings\ME\forge\Forge2_dmg_Model.gr2
      bone_sparks, bone_smoke, bone_flag_civ, bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_launchpoint04, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06
  art\WoL\buildings\ME\forge\Forge4_dmg_Model.gr2
      bone_sparks, bone_smoke, bone_flag_civ, bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_launchpoint04, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06
  art\WoL\buildings\ME\foundry\PersianFoundry2_dmg_Model.gr2
      bone_flag_civ, bone_sparks, bone_smoke, bone_chimney_smoke, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05
  art\WoL\buildings\ME\foundry\PersianFoundry4_dmg_Model.gr2
      bone_flag_civ, bone_sparks, bone_smoke, bone_chimney_smoke, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05
  art\WoL\buildings\ME\gunsmith\Gunsmith2_dmg_Model.gr2
      bone_flag_civ, bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_launchpoint04, bone_smoke, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05
  art\WoL\buildings\ME\gunsmith\Gunsmith4_dmg_Model.gr2
      bone_flag_civ, bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_launchpoint04, bone_smoke, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05
  art\WoL\buildings\ME\madrasah\Madrash2_dmg_Model.gr2
      bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06, bone_impactpoint07, bone_impactpoint08, bone_impactpoint09, bone_impactpoint10
  art\WoL\buildings\ME\madrasah\Madrash4_dmg_Model.gr2
      bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06, bone_impactpoint07, bone_impactpoint08, bone_impactpoint09, bone_impactpoint10, bone_impactpoint11
  art\WoL\buildings\ME\mahalla\Mahala1C_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla1A_dmg_Model.gr2
      bone_launchpoint01, GARRISONFLAG, bone_impactpoint01, bone_impactpoint02, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06
  art\WoL\buildings\ME\mahalla\Mahalla1A_lp_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla1A_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla1B_dmg_Model.gr2
      bone_launchpoint01, GARRISONFLAG, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint05
  art\WoL\buildings\ME\mahalla\Mahalla1B_lp_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla1B_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla1C_dmg_Model.gr2
      bone_launchpoint01, GARRISONFLAG, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06
  art\WoL\buildings\ME\mahalla\Mahalla1C_lp_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla1C_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla2A_dmg_Model.gr2
      bone_launchpoint01, GARRISONFLAG, bone_impactpoint01, bone_impactpoint02, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06
  art\WoL\buildings\ME\mahalla\Mahalla2A_lp_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla2A_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla2B_dmg_Model.gr2
      bone_launchpoint01, GARRISONFLAG, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint05
  art\WoL\buildings\ME\mahalla\Mahalla2B_lp_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla2B_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla2C_dmg_Model.gr2
      bone_launchpoint01, GARRISONFLAG, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06
  art\WoL\buildings\ME\mahalla\Mahalla2C_lp_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla2C_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla4A_dmg_Model.gr2
      bone_launchpoint01, GARRISONFLAG, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06
  art\WoL\buildings\ME\mahalla\Mahalla4A_lp_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla4A_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla4B_dmg_Model.gr2
      bone_launchpoint01, GARRISONFLAG, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05
  art\WoL\buildings\ME\mahalla\Mahalla4B_lp_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla4B_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla4C_dmg_Model.gr2
      bone_launchpoint01, GARRISONFLAG, bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06
  art\WoL\buildings\ME\mahalla\Mahalla4C_lp_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\mahalla\Mahalla4C_Model.gr2
      bone_launchpoint01, GARRISONFLAG
  art\WoL\buildings\ME\oasis\Oasis1_death_Model.gr2
      bone_debris_oasibase_001, bone_debris_oasibase_002
  art\WoL\buildings\ME\oasis\Oasis2_death_Model.gr2
      bone_debris_oasibase_001, bone_debris_oasibase_002, bone_debris_oasibase_003, bone_debris_oasibase_004, bone_debris_oasibase_005, bone_debris_oasibase_021, bone_debris_oasibase_024, bone_debris_oasibase_025, bone_debris_oasibase_026, bone_debris_oasibase_027, bone_debris_oasibase_028, bone_debris_oasibase_029, bone_debris_oasibase_030, bone_debris_oasibase_031, bone_debris_oasibase_032, bone_debris_oasibase_033, bone_debris_oasibase_034, bone_debris_oasibase_036, bone_debris_oasibase_037, bone_debris_oasibase_038, bone_debris_oasibase_039, bone_debris_oasibase_042, bone_debris_oasibase_044, bone_debris_oasibase_046, bone_debris_oasibase_047, bone_debris_oasibase_048, bone_debris_oasibase_049, bone_debris_oasibase_050, bone_debris_oasibase_051, bone_debris_oasibase_052
  art\WoL\buildings\ME\oasis\Oasis4_death_Model.gr2
      bone_debris_oasibase_001, bone_debris_oasibase_002, bone_debris_oasibase_003, bone_debris_oasibase_004, bone_debris_oasibase_005, bone_debris_oasibase_021, bone_debris_oasibase_024, bone_debris_oasibase_025, bone_debris_oasibase_026, bone_debris_oasibase_027, bone_debris_oasibase_028, bone_debris_oasibase_029, bone_debris_oasibase_030, bone_debris_oasibase_031, bone_debris_oasibase_032, bone_debris_oasibase_033, bone_debris_oasibase_034, bone_debris_oasibase_036, bone_debris_oasibase_037, bone_debris_oasibase_038, bone_debris_oasibase_039, bone_debris_oasibase_042, bone_debris_oasibase_044, bone_debris_oasibase_046, bone_debris_oasibase_047, bone_debris_oasibase_048, bone_debris_oasibase_049, bone_debris_oasibase_050, bone_debris_oasibase_051, bone_debris_oasibase_052
  art\WoL\buildings\ME\oasis\Oasis_Model.gr2
      bone_attachpoint01, bone_attachpoint02, bone_attachpoint03, bone_attachpoint04, bone_attachpoint05, bone_attachpoint06, bone_attachpoint07, bone_attachpoint08, bone_attachpoint09, bone_attachpoint10, bone_attachpoint11, bone_attachpoint12, bone_attachpoint13, bone_attachpoint14, bone_attachpoint15, bone_attachpoint16, bone_attachpoint17, bone_attachpoint18, bone_attachpoint19, bone_attachpoint20, bone_attachpoint21, bone_attachpoint22, bone_attachpoint23, bone_attachpoint24, bone_attachpoint25, bone_attachpoint26, bone_attachpoint27
  art\WoL\buildings\ME\props\native\grounds\Grounds_1_Model.gr2
      prop
  art\WoL\buildings\ME\props\native\grounds\Grounds_2_Model.gr2
      prop
  art\WoL\buildings\ME\props\native\grounds\Grounds_3_Model.gr2
      prop
  art\WoL\buildings\ME\props\native\grounds\Grounds_4_Model.gr2
      prop
  art\WoL\buildings\ME\props\native\grounds\Grounds_5_Model.gr2
      prop
  art\WoL\buildings\ME\props\native\grounds\Grounds_6_Model.gr2
      prop
  art\WoL\buildings\ME\royalcourt\RoyalCourt2_dmg_Model.gr2
      bone_flag_civ
  art\WoL\buildings\ME\royalcourt\RoyalCourt2_lp_Model.gr2
      bone_flag_civ
  art\WoL\buildings\ME\royalcourt\RoyalCourt2_Model.gr2
      bone_flag_civ
  art\WoL\buildings\ME\royalcourt\RoyalCourt4_dmg_Model.gr2
      bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05, bone_impactpoint06, bone_impactpoint07
  art\WoL\buildings\ME\royalcourt\RoyalCourt4_lp_Model.gr2
      bone_flag_civ
  art\WoL\buildings\ME\royalcourt\RoyalCourt4_Model.gr2
      bone_flag_civ
  art\WoL\buildings\ME\temple\Temple2_dmg_Model.gr2
      bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05
  art\WoL\buildings\ME\temple\Temple4_dmg_af_Model.gr2
      bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05
  art\WoL\buildings\ME\temple\Temple4_dmg_pe_Model.gr2
      bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05
  art\WoL\buildings\ME\temple\Temple4_dmg_uz_Model.gr2
      bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_impactpoint04, bone_impactpoint05
  art\WoL\buildings\ME\uzbek_settlements\Alaman_dmg_Model.gr2
      boneimpact01, boneimpact02, boneimpact03, bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_launchpoint04
  art\WoL\buildings\ME\uzbek_settlements\Alaman_lp_Model.gr2
      bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_launchpoint04
  art\WoL\buildings\ME\uzbek_settlements\Alaman_Model.gr2
      bone_launchpoint01, bone_launchpoint02, bone_launchpoint03, bone_launchpoint04
  art\WoL\buildings\ME\uzbek_settlements\Kibitka_dmg_Model.gr2
      boneimpact01, boneimpact02, boneimpact03
  art\WoL\buildings\ME\uzbek_settlements\Tam_dmg_Model.gr2
      boneimpactpoint01, boneimpactpoint02, boneimpactpoint03, boneimpactpoint04
  art\WoL\buildings\ME\wall\Corner_dmg_Model.gr2
      bone_impactpoint01, bone_debris_debris_000
  art\WoL\buildings\ME\wall\Wall1x2_dmg_Model.gr2
      bone_impactpoint01, bone_debris_wall12dmg_002
  art\WoL\buildings\ME\wall\Wall1x5_dmg_Model.gr2
      bone_impactpoint01, bone_impactpoint02, bone_impactpoint03, bone_debris_wall15dmg_007
