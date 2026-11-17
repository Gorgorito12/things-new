# Home-city models moved into art\WoL\homecity

Every WoL home city's own models, their textures and their animation files move into
`art\WoL\homecity\<Civ>\`. Models that several civs' home cities share go to
`art\WoL\homecity\_shared\`. Every reference to a moved file is updated, and each texture carries
its `(X,X,X,X)` header suffix where the decisions below allow it. This pack replaces the earlier
Argentina pilot (`argentineans\`): the same move, now with the suffix.

Before and after, all 22 home cities with own models were opened in game from the same six views
each: the hub, and the five building views of "View All Cards". In those views, everything that
stands still is unchanged. Pixel differences above about 0.6 levels (out of 255) are all on
moving things: people, animals, fire, smoke, flags, particles and water. Each such view was
checked by eye against a mask of the changed pixels (see "How it was checked").

## What is in it

| File | What it is |
|---|---|
| `WoL-homecity-models-fix.zip` | The new and edited files, in the game's folder layout (537 files, 126.5 MB unpacked) |
| `WoL-homecity-models-originals.zip` | WoL's originals of every file this replaces or moves (537 files), to undo it |
| `moved-files.txt` | The list of moved files: `old path -> new path`, 500 lines |

In all:
- 161 models (`.gr2`), 240 textures (`.ddt`) and 99 animation files move;
- 37 files are edited where they are: the `data\homecity*.xml` files and the animation files that
  name a moved file.

**Models:**
- Only their stored texture paths change: they follow the moved `.ddt`, and they gain the suffix
  where it applies. Nothing else in them is touched: no geometry, no bones, no size.
- They are compressed again with Oodle1, as WoL's are: 15.5 MB against 13.6 MB.
- 18 of them stay uncompressed (see "Known issues").
- After writing, each model was opened through the game's own Granny runtime, and every texture
  path it stores was checked to reach its `.ddt`.

## The suffix

A texture whose models store it as `.tga`, `.png` or `.jpg` is renamed on disk to
`<name>.(u,a,f,m).ddt`. The digits are its own header (usage, alpha, format, mips), and the file
itself is not re-encoded. The models then store `<name>.(u,a,f,m).tga`.

The game drops only the last extension of a stored name, so `<name>.(u,a,f,m).tga` reaches
`<name>.(u,a,f,m).ddt`. This was tested in game:
- a suffix in the stored name with the `.ddt` not renamed draws the model black;
- with both renamed, the model draws as before.

119 textures got the suffix, and 168 stored names were rewritten with it. 121 moved textures keep
their name, by the rules:
- 42 are stored by a model as `.ddt`, and `.ddt` names stay as they are;
- 79 are named by an animation file (`<replacetexture>`, decals, ground textures) and by no model.
  The anim files name them without an extension, so they keep their name.

The real headers vary a lot: (0,4,8,8), (0,1,8,8), (0,0,4,10), (0,8,1,9), (1,1,8,7) and more. So
0188/6098 were never assumed.

## Per home city

"Diff" is the largest mean pixel difference over the six views, before against after, in levels
out of 255. Above 0.6 it comes from animation (people, horses, fire, smoke, flags, particles,
water); each such view was checked by eye.

| Home city (saved city tested) | Models | Textures (suffixed) | Anim files | Diff | Notes |
|---|---:|---:|---:|---:|---|
| Afghans (Kabul) | 24 | 17 (10) | 7 | 0.1 | bone ×100 left as is (decision 1) |
| Argentineans (Buenos Aires) | 32 | 45 (41) | 7 | 0.8 | 4 shared with Bolivia go to `_shared`; market fix below |
| Bolivians (Sucre) | 20 | 37 (37) | 7 | 0.4 | the shared plaza props are in `_shared` |
| Bulgarians (Sofia) | 24 | 4 (4) | 7 | 2.5 | the Balkan room set (shared with Greeks, Romanians, Serbians) goes to `_shared` |
| Centralamericans (Guatemala) | 1 | 15 (0) | 6 | 3.7 | `PY church` shared with Haitians, Paraguayans |
| Chileans (Valparaiso) | 12 | 17 (2) | 2 | 2.1 | 10 models uncompressed (see "Known issues") |
| Egyptians (Cairo) | 5 | 10 (6) | 7 | 7.6 | the ambassador hats shared with Saudis go to `_shared`; diff from the fez and a flag's shadow |
| Ethiopians (Addis Ababa) | 0 | 6 (0) | 5 | 2.2 | |
| Greeks (Athens) | 2 | 3 (1) | 3 | 3.8 | |
| Haitians (Port-au-Prince) | 4 | 15 (0) | 3 | 2.0 | 4 models uncompressed |
| Italians (Rome) | 10 | 4 (0) | 2 | 1.5 | |
| Maori (Parihaka) | 0 | 13 (0) | 9 | 3.9 | its models are also used outside the home cities and stay; one before-shot (a building view) came out black and is left out |
| Paraguayans (Asunción) | 0 | 10 (0) | 4 | 1.5 | |
| Persians (Tehran) | 1 | 1 (1) | 0 | 0.0 | |
| Romanians (Bucharest) | 0 | 0 (0) | 1 | 3.0 | everything was already moved as shared |
| Saudis (Riyadh) | 1 | 1 (1) | 0 | 0.0 | |
| Serbians (Belgrade) | 1 | 0 (0) | 1 | 3.6 | |
| Swedish (Stockholm) | 1 | 6 (2) | 5 | 1.2 | the cathedral's newer plain file moves; its older compiled twin stays (see "Known issues") |
| Tupinamba (Aracoara) | 1 | 14 (3) | 8 | 5.0 | |
| Uzbeks (Bukhara) | 1 | 1 (1) | 0 | 0.0 | |
| WallMapu (Perquenco) | 4 | 9 (0) | 8 | 3.6 | 4 models uncompressed |
| Zulu (Bulawayo) | 10 | 12 (10) | 7 | 3.6 | |
| The shared props and proto-unit tables | 7 | 0 | 0 | | the African slaves and `gold_Model` go to `_shared` |

Australians, British and the campaigns have no model to move: their only own models are the
frigates, which replace stock models and stay.

## Argentina's market

`ARG_Mercado_de_Abastos_4_A` and `_4_B` named a texture `ARG_Mercado_de_Abastos_4.jpg` that has no
`.ddt`. They have the same UV layout as levels 1 and 3, and the unused
`ARG_Mercado_de_Abastos_2.ddt` fits them. This was seen in game from the market's building view:
- the "Mercado de Abastos" sign, the windows and the roof line up;
- the building reads as an upgraded market, with a stone front and a slate roof.

So that texture now moves next to them as `ARG_Mercado_de_Abastos_2.(0,4,8,8).ddt`, and both models
use it. The models `ARG_Mercado_de_Abastos_2_A` and `_2_B`, which `Mercado_de_Abastos.xml` names,
still do not exist. That is left as it is.

## How to apply

1. **Back up first.** Keep `WoL-homecity-models-originals.zip`: it holds WoL's own copy of every
   file this touches.
2. Unzip `WoL-homecity-models-fix.zip` into the WoL folder (the one with `age3y.exe`). Let the
   `art` and `data` folders merge and the edited files be replaced.
3. Delete the old copies: every file on the left side of `moved-files.txt`. If they are left, they
   are no longer used, but the move is not done until they are gone.

**To undo:**
1. Delete `art\WoL\homecity`.
2. Unzip `WoL-homecity-models-originals.zip` into the WoL folder.

## Not changed (decisions)

- **Size and basis.** No model's size or basis changes. That covers the raw 3ds Max exports, the
  Afghan, Persian, Saudi and Uzbek models whose bone is scaled ×100, and the Balkan room's models
  declared at 1000 units per metre. The game draws them right today. An automatic conversion into the
  stock basis was tested and does not keep the scene: the converted buildings and background
  were drawn misplaced, or stretched into broken polygons.
- **Unused files are not deleted.** The files listed at the end were left where they are: nothing
  reaches them.
- **Models that stay where they are:**
  - the frigates (`Homecity\british\frigate.gr2`, `frigate01.gr2`), which replace stock models;
  - every model that something outside the home cities also uses;
  - path data (`AfghanPathableArea_Model.gr2`).

  The full list is below.

## Known issues

- **18 models ship uncompressed.** They are the 10 Chilean, 4 Haitian and 4 WallMapu models
  listed below. All 18 are older Granny files (type tag 0x80000010).
  - Their copies compressed again pass the CRC check, but the Granny runtime cannot open them, and
    the game closed at its main menu when the last-viewed home city was Chilean.
  - Uncompressed, they load and draw as before.
- **Swedish cathedral:** `art\Homecity\WOTTA\LA buildings\secret_cathedral.xml` has a compiled twin,
  `secret_cathedral.xml.xmb`, of 2015.
  - The game reads the newer of the two, so it showed the plain file of 2019, and only that one
    moves.
  - The old twin stays in place, listed with the unused files. If it were moved too, it could
    become the newer one and replace the cathedral.

## How it was checked

- The tests ran on a copy of WoL (not the Steam install), backed up first and restored after,
  checked by SHA-256 over every loose file of `art`, `data` and `Campaign`.
- Each home city was opened from Skirmish > Manage Home Cities > Select. Each view was shot at
  1920×1080 before and after.
- The difference is the mean of the absolute difference over the 3D area. Masks of the pixels
  that changed by more than 48 were checked by eye wherever the mean was above 0.6.

## Lists

### Models that stay where they are

- `Homecity\british\frigate.gr2`, `frigate01.gr2`: replace stock models
- `3d_models\German\backpack.GR2`: used outside the home cities: now\units\artillery\daza\daza_grenadier.xml, replace_texture\centralamericans_rt_anim.xml, war of the triple alliance\dlc\fenriz\units\brenero\brenero.xml
- `3d_models\Weapons\carbine.GR2`: used outside the home cities: war of the triple alliance\dlc\ivan monteiro\units\bamum guard\bamum_guard_rider.xml, war of the triple alliance\units\consulate\consulate_kommando_rider.xml, war of the triple alliance\units\kommando\rider.xml
- `3d_models\Weapons\pandour_musket.GR2`: used outside the home cities: war of the triple alliance\dlc\fenriz\units\rabona\rabona.xml, war of the triple alliance\immigrants\units\ukrainian\serduk\serduk.xml, war of the triple alliance\natives\cangaceiro.xml
- `3d_models\Weapons\sword.GR2`: used outside the home cities: war of the triple alliance\units\americans\furtrader.xml, war of the triple alliance\units\americans\sthfurtrader.xml, war of the triple alliance\units\chapelgorris\chapelgorris.xml
- `3d_models\turk_muskets\rich_turk_musket.GR2`: used outside the home cities: war of the triple alliance\units\delta\modernization\nizam\nizam.xml, war of the triple alliance\units\delta\modernization\tufekci\tufekci.xml, war of the triple alliance\units\zeibek\zeibek.xml
- `Homecity\afghan\AfghanPathableArea_Model.gr2`: path data
- `War of the Triple Alliance\Buildingsets\Delta\Statues\settlement.GR2`: used outside the home cities: buildings\polynesia\pa\pa_center.xml, war of the triple alliance\buildingsets\delta\statues\settlement.xml, war of the triple alliance\buildingsets\town_center.xml
- `War of the Triple Alliance\Buildingsets\Delta\Statues\tupistatue.GR2`: used outside the home cities: war of the triple alliance\buildingsets\firepit.xml, war of the triple alliance\buildingsets\monument.xml
- `War of the Triple Alliance\Delta\AURs\New Buildings\workshop.gr2`: used outside the home cities: buildings\polynesia\sandalwood\sandalwood_grove.xml, war of the triple alliance\delta\aurs\animfiles\timbuktu.xml
- `War of the Triple Alliance\Delta\AURs\Resources\palmoil.GR2`: used outside the home cities: war of the triple alliance\delta\aurs\resources\palmoil(2).xml, war of the triple alliance\delta\aurs\resources\palmoil.xml
- `War of the Triple Alliance\Delta\African Animals\bases\150.GR2`: used outside the home cities: units\polynesia\maori\waka_hull_base.xml, units\polynesia\sandalwood\sandalwood_4.xml, war of the triple alliance\delta\nature\tree_acacia_base.xml
- `War of the Triple Alliance\Delta\African Animals\bases\200.GR2`: used outside the home cities: war of the triple alliance\units\animals\coconut crab\coconut_crab_base.xml
- `War of the Triple Alliance\Delta\African Animals\bases\50.GR2`: used outside the home cities: units\polynesia\maori\archer_base.xml, units\polynesia\maori\double_rowers_base.xml, units\polynesia\maori\hunter_base.xml
- `War of the Triple Alliance\Delta\African Animals\bases\60.GR2`: used outside the home cities: units\polynesia\canoe_base.xml, units\polynesia\maori\bowman_base.xml, units\polynesia\maori\canoe_base.xml
- `War of the Triple Alliance\Delta\asuncionbuildings\brewery.GR2`: used outside the home cities: war of the triple alliance\delta\asuncionbuildings\abandonedbuilding.xml
- `War of the Triple Alliance\Delta\asuncionbuildings\foodplant.GR2`: used outside the home cities: war of the triple alliance\delta\asuncionbuildings\abandonedbuilding.xml
- `War of the Triple Alliance\Delta\theroom\piano.GR2`: used outside the home cities: nuggets\european_nuggets\nuggetpiano.xml, war of the triple alliance\delta\aurs\resources\ebony.xml
- `War of the Triple Alliance\Units\Delta\equipment\ethiopianshield3.GR2`: used outside the home cities: war of the triple alliance\units\delta\equipment\ethiopianshield.xml
- `War of the Triple Alliance\Units\Delta\modernization\nizam\nizamhat.GR2`: used outside the home cities: replace_texture\ottomans_rt_anim.xml, replace_texture\persians_rt_anim.xml, war of the triple alliance\units\delta\modernization\nizam\nizam.xml
- `War of the Triple Alliance\test\coconut.GR2`: used outside the home cities: war of the triple alliance\test\coconut.xml
- `WoL\interns\zupay\units\villagers\Mitayo\Mitayo_FI.gr2`: used outside the home cities: wol\interns\zupay\units\villagers\mitayo\mitayo.xml, wol\interns\zupay\units\villagers\mitayo\mitayohurt.xml
- `WoL\interns\zupay\units\villagers\Mitayo\Mitayo_MII.gr2`: used outside the home cities: wol\interns\zupay\units\villagers\mitayo\mitayo.xml, wol\interns\zupay\units\villagers\mitayo\mitayohurt.xml
- `WoL\units\dog\saluki\saluki_1.gr2`: used outside the home cities: wol\units\dog\saluki\saluki.xml
- `WoL\units\dog\saluki\saluki_2.gr2`: used outside the home cities: wol\units\dog\saluki\saluki.xml

### Models shipped uncompressed

- `Homecity\WoL\Chileans\Chileans_background.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\Chileans\Chileans_generic_02.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\Chileans\Chileans_homecity.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\Chileans\Chileans_house_background.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\Chileans\Chileans_house_background_02.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\Chileans\Chileans_house_background_03.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\Chileans\Chileans_house_background_04.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\Chileans\Chileans_house_background_05.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\Chileans\Chileans_house_background_06.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\Chileans\generic01_Chileans.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\haitian\haitian_background.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\haitian\haitian_hc_dock.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\haitian\haitian_hc_iron_market.gr2` (moved; see `moved-files.txt`)
- `Homecity\WoL\haitian\haitian_homecity.gr2` (moved; see `moved-files.txt`)
- `Homecity\WOTTA\chieftainma.gr2` (moved; see `moved-files.txt`)
- `Homecity\WOTTA\mapuchewarrior.gr2` (moved; see `moved-files.txt`)
- `Homecity\WOTTA\shaman_mapuche.gr2` (moved; see `moved-files.txt`)
- `Homecity\WOTTA\wise_womanMA.gr2` (moved; see `moved-files.txt`)

### Textures that keep their name

- `Homecity\NOW\Argentina\Ground\Argentina_Ground_1.ddt`: no model stores its name (an anim file names it)
- `Homecity\NOW\Argentina\Plaza_De_Mayo\Caballo.ddt`: no model stores its name (an anim file names it)
- `Homecity\NOW\Argentina\Plaza_De_Mayo\Jinete.ddt`: no model stores its name (an anim file names it)
- `Homecity\NOW\Argentina\Sky\House_Homecity_ARG\Arbusto.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\CEN_academy.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\CEN_academy_PII.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\CEN_harbor.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\CEN_manufacturing.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\CENwalk.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\Toldo.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\house.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\ottoman_cobbles.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\russian_hc_ground.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\sky1.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\sky2.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\sky3.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\sky4.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\sky5.ddt`: no model stores its name (an anim file names it)
- `Homecity\Omega\Centralamerica\tradecenter.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\Ambassadors\ethiopian.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\Ambassadors\ethiopian_b.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\ChieftainMa.ddt`: a model stores it as .ddt
- `Homecity\WOTTA\MapucheWarrior.ddt`: a model stores it as .ddt
- `Homecity\WOTTA\Shaman_Mapuche.ddt`: a model stores it as .ddt
- `Homecity\WOTTA\Tupi\chief_gear.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\Tupi\chief_head.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\Tupi\hair-feathers.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\Tupi\shaman_gear.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\Tupi\shaman_head.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\Tupi\war_leader_head.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\Tupi\wise_woman_gear.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\Tupi\wise_woman_head.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\balkanpoliticians\greek\academy.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\balkanpoliticians\greek\academy_b.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\bark_shingle.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\iro_grass_edging.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\mapuche_sky_A.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\mapuche_sky_B.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\mapuche_sky_C.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\mapuche_sky_D.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\roof_shingle.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\secret\german_ground_colormap_A.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\secret\german_ground_colormap_B.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\secret\german_ground_colormap_C.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\secret\german_ground_colormap_D.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\skyA.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\skyB.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\skyC.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\skyD.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\skyE.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\skyF.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\skyG.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\skyH.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\sky\abyss_sky_A.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\sky\abyss_sky_b.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\sky\abyss_sky_c.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\sky\abyss_sky_d.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\sky\egypt_sky_A.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\sky\egypt_sky_B.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\sky\egypt_sky_C.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\sky\egypt_sky_d.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\sky\rome_sky_A.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\sky\rome_sky_B.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\sky\rome_sky_C.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\sky\rome_sky_D.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\spn_sidewalk_dirt.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\spn_sidewalk_normal.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\tupi_backdrop.ddt`: no model stores its name (an anim file names it)
- `Homecity\WOTTA\wise_womanMA.ddt`: a model stores it as .ddt
- `Homecity\WOTTA\wise_woman_gearMA.ddt`: a model stores it as .ddt
- `Homecity\WOTTA\zulu_backdrop.ddt`: no model stores its name (an anim file names it)
- `Homecity\WoL\Chileans\Chileans_generic_02_colormap_01.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_generic_02_colormap_02.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_ground_colormap_A_1.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_ground_colormap_B_1.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_ground_colormap_C_1.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_ground_colormap_D_1.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_hc_dock_bumpspec.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_hc_dock_colormap.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_house_background.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_house_background_B.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_morning_A.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_morning_B.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_morning_C.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\Chileans_morning_D.ddt`: a model stores it as .ddt
- `Homecity\WoL\Chileans\generic01_Chileans.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_background_1.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_background_2.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_background_3.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_background_4.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_background_5.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_dock.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_ground_a.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_ground_a_normal.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_ground_b.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_ground_b_normal.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_ground_c.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_ground_c_normal.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_ground_d.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_ground_d_normal.ddt`: a model stores it as .ddt
- `Homecity\WoL\haitian\haitian_hc_iron_market.ddt`: a model stores it as .ddt
- `Homecity\afghan\textures\afghan_pavement2.ddt`: a model stores it as .ddt
- `Homecity\afghan\textures\afghan_sky_A.ddt`: a model stores it as .ddt
- `Homecity\afghan\textures\afghan_sky_B.ddt`: a model stores it as .ddt
- `Homecity\afghan\textures\afghan_sky_C.ddt`: a model stores it as .ddt
- `Homecity\afghan\textures\afghan_sky_D.ddt`: a model stores it as .ddt
- `Homecity\afghan\textures\city_borders.ddt`: a model stores it as .ddt
- `Homecity\afghan\textures\city_borders_b.ddt`: a model stores it as .ddt
- `Homecity\polynesians\maori\maori_woman.ddt`: no model stores its name (an anim file names it)
- `Homecity\polynesians\maori\mau_rakau_gear.ddt`: no model stores its name (an anim file names it)
- `Homecity\polynesians\maori\mau_rakau_head.ddt`: no model stores its name (an anim file names it)
- `Homecity\polynesians\maori\missionary.ddt`: no model stores its name (an anim file names it)
- `Homecity\polynesians\maori\native_embassy.ddt`: no model stores its name (an anim file names it)
- `Homecity\polynesians\maori\parihaka_house.ddt`: no model stores its name (an anim file names it)
- `Homecity\polynesians\maori\parihaka_sky_A.ddt`: no model stores its name (an anim file names it)
- `Homecity\polynesians\maori\parihaka_sky_B.ddt`: no model stores its name (an anim file names it)
- `Homecity\polynesians\maori\parihaka_sky_C.ddt`: no model stores its name (an anim file names it)
- `Homecity\polynesians\maori\parihaka_sky_D.ddt`: no model stores its name (an anim file names it)
- `Homecity\polynesians\maori\rangatira.ddt`: no model stores its name (an anim file names it)
- `Homecity\polynesians\maori\tohunga.ddt`: no model stores its name (an anim file names it)
- `Homecity\polynesians\maori\tohunga_gear.ddt`: no model stores its name (an anim file names it)

### Unused files left in place (129)

Nothing reaches these: no home city, model or animation file. They are listed, not deleted.

- `art\Homecity\afghan\afghan_estate.xml`
- `art\Homecity\afghan\afghan_small_temple.xml`
- `art\Homecity\afghan\textures\BalaHissarGround.ddt`
- `art\Homecity\afghan\textures\BalaHissarGround_b.ddt`
- `art\Homecity\NOW\Argentina\Ground\Argentina_generic_colormap.ddt`
- `art\Homecity\NOW\Argentina\Ground\Argentina_generic_colormap01.ddt`
- `art\Homecity\NOW\Argentina\Ground\Argentina_generic_colormap02.ddt`
- `art\Homecity\NOW\Argentina\Ground\Argentina_Ground.ddt`
- `art\Homecity\NOW\Argentina\Ground\SSS.ddt`
- `art\Homecity\NOW\Argentina\Homecity_Buildings\Cuadra_1.xml`
- `art\Homecity\NOW\Argentina\Sky\Argentina_Ground.ddt`
- `art\Homecity\NOW\Argentina\Sky\House_Homecity_ARG\Argentina_Props.xml`
- `art\Homecity\NOW\Bolivia\Bolivia_background.xml`
- `art\Homecity\NOW\Bolivia\flags.xml`
- `art\Homecity\NOW\Bolivia\home_city_props\Bolivian_church01.xml`
- `art\Homecity\NOW\Bolivia\Palacio_Nacional\Palacio_Nacional.ddt`
- `art\Homecity\NOW\Bolivia\Palacio_Nacional\Palacio_Nacional.GR2`
- `art\Homecity\NOW\Bolivia\Palacio_Nacional\Palacio_Nacional_2_A(1).GR2`
- `art\Homecity\NOW\Bolivia\Plaza_De_Sucre\Cantero.ddt`
- `art\Homecity\NOW\Bolivia\Props_Tent.ddt`
- `art\Homecity\NOW\Bolivia\Sky\House_Homecity_BOL\casa1.ddt`
- `art\Homecity\Omega\Centralamerica\CEN_cathedral.xml`
- `art\Homecity\Omega\Centralamerica\ground6_bay.ddt`
- `art\Homecity\Omega\Centralamerica\groundforest_bay.ddt`
- `art\Homecity\Omega\Centralamerica\hc_fountain.ddt`
- `art\Homecity\polynesians\maori\HCwharenui.xml`
- `art\Homecity\WoL\haitian\haitian_hc_dock_bump.ddt`
- `art\Homecity\WoL\haitian\haitian_hc_ground_a_spec.ddt`
- `art\Homecity\WoL\haitian\haitian_hc_ground_b_spec.ddt`
- `art\Homecity\WoL\haitian\haitian_hc_ground_c_spec.ddt`
- `art\Homecity\WoL\haitian\haitian_hc_ground_d_spec.ddt`
- `art\Homecity\WoL\haitian\haitian_hc_ground_diffuse.ddt`
- `art\Homecity\WoL\haitian\haitian_hc_ground_spec_color.ddt`
- `art\Homecity\WOTTA\2THEROOM_homecity.xml`
- `art\Homecity\WOTTA\a2.ddt`
- `art\Homecity\WOTTA\a3.ddt`
- `art\Homecity\WOTTA\Ambassadors\belgian.ddt`
- `art\Homecity\WOTTA\Ambassadors\britishhat.GR2`
- `art\Homecity\WOTTA\Ambassadors\zulu.ddt`
- `art\Homecity\WOTTA\americans_homecity.xml`
- `art\Homecity\WOTTA\b2.ddt`
- `art\Homecity\WOTTA\b3.ddt`
- `art\Homecity\WOTTA\balkanpoliticians\greek\harbor.xml`
- `art\Homecity\WOTTA\balkanpoliticians\romanian\academy.xml`
- `art\Homecity\WOTTA\balkanpoliticians\romanian\factory.xml`
- `art\Homecity\WOTTA\balkanpoliticians\romanian\harbor.xml`
- `art\Homecity\WOTTA\balkanpoliticians\romanian\Justinian_DIFF.ddt`
- `art\Homecity\WOTTA\balkanpoliticians\romanian\market.xml`
- `art\Homecity\WOTTA\balkanpoliticians\romanian\red_hat.GR2`
- `art\Homecity\WOTTA\balkanpoliticians\serbianhat1.ddt`
- `art\Homecity\WOTTA\balkanpoliticians\serbianhat1.GR2`
- `art\Homecity\WOTTA\belgian_cathedral.xml`
- `art\Homecity\WOTTA\belgian_plant.xml`
- `art\Homecity\WOTTA\bolivar.xml`
- `art\Homecity\WOTTA\c2.ddt`
- `art\Homecity\WOTTA\c3.ddt`
- `art\Homecity\WOTTA\cathedral_chiesa.xml`
- `art\Homecity\WOTTA\city_ground.ddt`
- `art\Homecity\WOTTA\colombia.xml`
- `art\Homecity\WOTTA\colombia_background.xml`
- `art\Homecity\WOTTA\d2.ddt`
- `art\Homecity\WOTTA\d3.ddt`
- `art\Homecity\WOTTA\danish_homecity.xml`
- `art\Homecity\WOTTA\ee_trading_company_b_bumpspec.ddt`
- `art\Homecity\WOTTA\hall.xml`
- `art\Homecity\WOTTA\homecity_grass_nearshore.ddt`
- `art\Homecity\WOTTA\korea\aztec_academy.xml`
- `art\Homecity\WOTTA\korea\aztec_academy.xml.xmb`
- `art\Homecity\WOTTA\korea\aztec_backdrop.gr2`
- `art\Homecity\WOTTA\korea\aztec_backdrop.gr2.precomp`
- `art\Homecity\WOTTA\korea\aztec_background.xml`
- `art\Homecity\WOTTA\korea\aztec_background.xml.precomp`
- `art\Homecity\WOTTA\korea\aztec_cathedral.xml`
- `art\Homecity\WOTTA\korea\aztec_cathedral.xml.xmb`
- `art\Homecity\WOTTA\korea\aztec_dock.xml`
- `art\Homecity\WOTTA\korea\aztec_dock.xml.xmb`
- `art\Homecity\WOTTA\korea\aztec_estate.xml`
- `art\Homecity\WOTTA\korea\aztec_estate.xml.xmb`
- `art\Homecity\WOTTA\korea\aztec_homecity (2).xml`
- `art\Homecity\WOTTA\korea\aztec_homecity.xml`
- `art\Homecity\WOTTA\korea\aztec_homecity_cathedral_camera.cam`
- `art\Homecity\WOTTA\korea\aztec_homecity_water.xml`
- `art\Homecity\WOTTA\korea\aztec_homecity_water.xml.xmb`
- `art\Homecity\WOTTA\korea\aztec_manufacturingplant.xml`
- `art\Homecity\WOTTA\korea\aztec_manufacturingplant.xml.xmb`
- `art\Homecity\WOTTA\korea\aztec_sky_A.ddt`
- `art\Homecity\WOTTA\korea\aztec_sky_B.ddt`
- `art\Homecity\WOTTA\korea\aztec_sky_C.ddt`
- `art\Homecity\WOTTA\korea\aztec_sky_D.ddt`
- `art\Homecity\WOTTA\korea\aztec_tradecenter.xml`
- `art\Homecity\WOTTA\korea\aztec_tradecenter.xml.xmb`
- `art\Homecity\WOTTA\korea\aztecroof.ddt`
- `art\Homecity\WOTTA\korea\court.xml`
- `art\Homecity\WOTTA\korea\court.xml.xmb`
- `art\Homecity\WOTTA\korea\courtbuilding.ddt`
- `art\Homecity\WOTTA\korea\flag.xml`
- `art\Homecity\WOTTA\korea\flag.xml.xmb`
- `art\Homecity\WOTTA\korea\waterbuilding01_bump.ddt`
- `art\Homecity\WOTTA\korea_homecity.xml`
- `art\Homecity\WOTTA\LA buildings\house7.ddt`
- `art\Homecity\WOTTA\LA buildings\PY church BIG.GR2`
- `art\Homecity\WOTTA\LA buildings\PY house.GR2`
- `art\Homecity\WOTTA\LA buildings\secret_cathedral.xml.xmb`
- `art\Homecity\WOTTA\LA buildings\secret_tradecenter.xml.xmb`
- `art\Homecity\WOTTA\NAmilitia.xml`
- `art\Homecity\WOTTA\persian_background.xml`
- `art\Homecity\WOTTA\persian_homecity.xml`
- `art\Homecity\WOTTA\PY church BIG.xml`
- `art\Homecity\WOTTA\revolution_homecity.xml`
- `art\Homecity\WOTTA\sanmartin.ddt`
- `art\Homecity\WOTTA\santacruz.ddt`
- `art\Homecity\WOTTA\santacruzhat.ddt`
- `art\Homecity\WOTTA\santander.ddt`
- `art\Homecity\WOTTA\ScoutMA.xml`
- `art\Homecity\WOTTA\sky\brazil_background.xml`
- `art\Homecity\WOTTA\sky\chile_background.xml`
- `art\Homecity\WOTTA\sky\danish_background2.xml`
- `art\Homecity\WOTTA\sky\greek_background2.xml`
- `art\Homecity\WOTTA\sky\greek_sky_e.ddt`
- `art\Homecity\WOTTA\sucre.ddt`
- `art\Homecity\WOTTA\Tupi\war_leader_gear.ddt`
- `art\Homecity\WOTTA\washingtonmonument.ddt`
- `art\Homecity\WOTTA\washingtonmonument.GR2`
- `art\Homecity\WOTTA\whitehouse.ddt`
- `art\Homecity\WOTTA\whitehouse.GR2`
- `art\Homecity\WOTTA\whitehouse.xml`
- `art\Homecity\WOTTA\whitehouse2.ddt`
- `art\Homecity\WOTTA\zulu\walls.ddt`
- `art\Homecity\WOTTA\Zupay\Peru_Casa3a.ddt`
