# Argentineans home city: models moved into art\WoL\homecity\Argentineans

A pilot of the home-city clean-up. It applies only the folder rule: the Argentine home city's own
models, their textures and their animation files move from `art\Homecity\NOW\Argentina\` to
`art\WoL\homecity\Argentineans\`. The four models it shares with Bolivia go to
`art\WoL\homecity\_shared\`. Every reference to them is updated.

Before and after, the Buenos Aires and Sucre home cities look the same in game: the hub view and
the five building views of each. Measured on screenshots taken from the same views, the average
difference is 0.0 to 0.6 levels out of 255, which is people walking.

## What is in it

| File | What it is |
|---|---|
| `WoL-homecity-argentineans-fix.zip` | The new and edited files, in the game's folder layout (87 files, 15.4 MB unpacked) |
| `WoL-homecity-argentineans-originals.zip` | WoL's originals of every file this replaces or moves (87 files), to undo it |
| `moved-files.txt` | The list of moved files: `old path -> new path`, 83 lines |

**Moved (83 files):**
- 32 models (`.gr2`): 28 to `Argentineans\` and 4 to `_shared\` (`Banco_1`, `Banco_2`, `Cantero`, `Flor`).
- 44 textures (`.ddt`): those used only by the moved models or named by the moved animation files. 5 of
  them go to `_shared\`: `Banco`, `Cantero` and `Flor`, plus `Caballo` and `Jinete`, which
  Bolivia's square also uses.
- The 7 animation files of the home city (`argentine_homecity.xml`, `Sky\Argentina_background.xml`,
  `Aduana.xml`, `Casa_Rosada.xml`, `Catedral_Metropolitana.xml`, `Mercado_de_Abastos.xml` and
  `Plaza_de_Mayo.xml`).

Each path below the old folder stays the same below the new one. For example,
`Aduana\ARG_Aduana_1_A.GR2` becomes `art\WoL\homecity\Argentineans\Aduana\ARG_Aduana_1_A.GR2`.

**Edited where they are (4 files):**
- `data\homecityargentineans.xml`, 7 lines:
  - the city visual: `..\WoL\homecity\Argentineans\argentine_homecity.xml`;
  - the background visual;
  - the five building visuals.
  The `..\` is needed because these paths start in `art\homecity\`. The game loads it: tested.
- `art\Homecity\NOW\Bolivia\Plaza_De_Sucre\BOL_Plaza_De_Sucre_Lv1.xml` and
  `art\Homecity\NOW\Bolivia\Sky\Bolivia_background_people.xml`: they now name the shared models
  and textures in `_shared\`.
- `art\Homecity\NOW\Argentina\Sky\House_Homecity_ARG\Argentina_Props.xml`: it names a moved
  model. No home city uses this file. It was updated anyway, so that nothing points at a missing
  file.

**The models themselves:**
- Only the texture paths stored inside each model changed: they now point at the moved `.ddt`
  files, and nothing else in them changed.
- The models were rewritten by the game's own Granny runtime, then compressed again with Oodle1:
  2,226,841 bytes for the 32 models, against 2,226,406 for WoL's originals.
- 4 of them keep exactly the section formats of WoL's originals. In the other 28 a longer texture
  path made a section grow, so every section that gets smaller is Oodle1 (as in WoL's originals).
- Each model was read back after writing: its CRC is valid, and its texture paths all resolve in
  the new layout.

## How to apply

1. **Back up first.** Keep `WoL-homecity-argentineans-originals.zip`: it holds WoL's own copy of
   every file this touches.
2. Unzip `WoL-homecity-argentineans-fix.zip` into the WoL folder (the one with `age3y.exe`). Let
   the `art` and `data` folders merge and the four edited files be replaced.
3. Delete the old copies: every file on the left side of `moved-files.txt`. They are no longer
   used. Left in place they do no harm, but the move is not done until they are gone.

**To undo:**
1. Delete the new folders `art\WoL\homecity\Argentineans` and `art\WoL\homecity\_shared`.
2. Unzip `WoL-homecity-argentineans-originals.zip` into the WoL folder.

## Not changed

**Files left in the old folder.** Nothing reaches these 9 files: no home city, no model and no
animation file. They are listed here and not deleted, for you to decide:
- `Ground\Argentina_generic_colormap.ddt`, `Ground\Argentina_generic_colormap01.ddt` and
  `Ground\Argentina_generic_colormap02.ddt`;
- `Ground\Argentina_Ground.ddt`, `Ground\SSS.ddt` and `Sky\Argentina_Ground.ddt`;
- `Mercado_de_Abastos\ARG_Mercado_de_Abastos_2.ddt`;
- `Homecity_Buildings\Cuadra_1.xml`;
- `Sky\House_Homecity_ARG\Argentina_Props.xml` (edited, see above).

**Bugs that were already there, left as they are:**
- `ARG_Mercado_de_Abastos_4_A` and `_4_B` name a texture `ARG_Mercado_de_Abastos_4.jpg` that has
  no `.ddt`.
- `Mercado_de_Abastos.xml` names `ARG_Mercado_de_Abastos_2_A` and `_2_B`, which do not exist.
- `Plaza_de_Mayo.xml` names `ARG_Plaza_de_Mayo_1`, which does not exist.

## Not done, and why

Two of the requested fixes were built and tested in game on this home city. Neither kept the city
as it was, so neither is in this pack.

**The (X,X,X,X) suffix in the texture names stored inside the models.**
- Written as `ARG_Aduana_1_A.(0,4,8,8).tga`, the model drew black.
- The game drops only the last extension of a stored name. It then looks for
  `ARG_Aduana_1_A.(0,4,8,8).ddt`.
- With copies of the textures under those suffixed names, the models drew correctly again.
- So the suffix works inside a model only if the `.ddt` file carries it too. It belongs on the
  source `.tga` files, where the texture converter reads it.
- The real headers of these textures vary: (0,4,8,8) for most buildings (DXT3, transparent
  alpha), (0,1,8,8) for the city blocks, (0,1,8,7) and (1,1,8,7) for some props, (0,5,8,8) for
  one. So the usual 0188 would be wrong for most of them.

**Converting the raw 3ds Max exports into the stock basis.** This is the "world too big" fix.
- All 32 of these models are raw 3ds Max exports: inches, Z up.
- Converted offline with the Granny runtime's own basis conversion, each one passed its checks:
  every box scaled by exactly 1/64, and the CRC valid.
- But in the home city the converted buildings and background were drawn in the wrong place and
  at the wrong scale, and the camera showed the wrong scene.
- The same models, moved without conversion, look exactly as before. Whatever the game does with
  these files, it does not read them through their declared basis alone, so the conversion stays
  out until that is understood.
