# Home-city models moved into art\WoL\homecity, building textures re-encoded

Every WoL home city's own models, their textures and their animation files move into
`art\WoL\homecity\<Civ>\`. Models that several civs' home cities share go to
`art\WoL\homecity\_shared\`. Every reference to a moved file is updated, and each texture carries
its `(X,X,X,X)` header suffix where the decisions below allow it.

New in this version: **the home-city building textures are re-encoded** for older graphics cards.
Each one gets the format its header and pixels call for, a size no larger than twice the average of
TAD's own home-city building textures, and a full mip chain. The suffix states the new header. The
pack was rebuilt from WoL's original files: it replaces the previous `homecity-models` pack, and it
is not a patch on top of it.

Before and after, all 22 home cities with own models were opened in game from the same six views
each: the hub, and the five building views of "View All Cards". Every building stands as it did. The re-encoded textures cannot be told apart at the game's distance, and the moving things (people, animals, fire, smoke, flags, water) account for the rest of the pixel difference. Each view above 1 level (out of 255) was checked by eye (22 home cities, see "Per home city" and "Media").

## What is in it

| File | What it is |
|---|---|
| `WoL-homecity-models-fix.zip` | The new and edited files, in the game's folder layout (537 files, 116.0 MB unpacked) |
| `WoL-homecity-models-originals.zip` | WoL's originals of every file this replaces or moves (537 files), to undo it |
| `moved-files.txt` | The list of moved files: `old path -> new path`, 500 lines |
| `media\` | Before/after pictures of every home city and the texture comparison sheets (see "Media") |

In all:
- 161 models (`.gr2`), 240 textures (`.ddt`) and 99 animation files move;
- 37 files are edited where they are: the `data\homecity*.xml` files and the animation files that
  name a moved file;
- 7 building textures are re-encoded, all of them among the moved textures (see
  "A finding" for those that stay where they are).

**Models:**
- Only their stored texture paths change: they follow the moved `.ddt`, and they gain the suffix
  where it applies. Nothing else in them is touched: no geometry, no bones, no size.
- They are compressed again with Oodle1, as WoL's are.
- 18 of them stay uncompressed (see "Known issues").
- After writing, each model was opened through the game's own Granny runtime (163 of
  163), and every texture path it stores was checked to reach its `.ddt`.

## Building textures

**Which textures.** Only the textures of home-city *buildings*: a texture counts when it is
reached from a building's `<visual>` in a `homecity*.xml`, through its animation files and models.
These are left untouched:
- backgrounds, skies, water, the hub scene and props;
- people and animals: several WoL home cities put an ambassador or a chief in a building's place,
  and an animation file with a rigged model counts as a person;
- a texture a building shares with any of those, with a unit or building of the game, or with a
  model outside the home cities;
- TAD's own textures, used from the game's archives.

Each one is listed at the end with its reason.

**The rules.** The header's alpha value always stays as it is:
- bump map (usage 4): **DXT5**;
- alpha 0: **DXT1**, half the size of DXT3. When its alpha channel is not opaque everywhere,
  something may still use it, so it gets DXT3;
- alpha 1 (player colour), 4 (transparent) or 8 (blend): **DXT3**, as TAD does (TAD has no DXT1
  with alpha);
- uncompressed (BGRA): the same rule.

**Size.** The limit is twice the average size of TAD's own home-city building textures. A texture
over the limit on a side is halved, both sides at once, until both fit, by area averaging. A bump
map's normals are made unit length again after halving. In practice this means 512 per side at
most: 1024 x 1024 becomes 512 x 512, and 256 x 1024 becomes 128 x 512.

**Mips.** A full chain down to 4 px on the short side, TAD's convention: 512 x 512 has 8 levels and
512 x 256 has 7. A texture with a single level gets the full chain. That is about a third more
memory, but less shimmer and faster drawing when it is seen small.

**Nothing is re-encoded that does not need it.** A level that keeps its size keeps its blocks:
- DXT3 to DXT1 copies the colour blocks so they decode to exactly the same pixels;
- a halved texture takes the original's own smaller level when that is closer.

Everything else is encoded with a least-squares DXT encoder.

**The check.** Every new texture was decoded and compared with the original. When it was halved,
the comparison is with the original area-averaged to the new size. Two numbers are measured:
- the mean difference per channel, which must be at most **6** levels out of 255;
- the mean of the worst 4 x 4 block, which must be at most **32**.

Over either limit, the texture would stay as it was. A sound DXT1 encoding of a detailed texture
(roof tiles, thatch, stone) measured 2 to 6 and up to 21. All re-encoded textures passed, and
their sheets were looked at by eye.

- **TAD's own home-city building textures, measured** (`reencode_textures.py tad`, from the game's `.bar` files: every `<building><visual>` of the stock home cities, its anim files and models, the textures they store; people standing in for a building left out): 215 textures of 98 models, mean **454 x 395**. None is above 512 on a side. So the limit is **908 x 790**.
- **WoL's home-city building textures:** 56 textures that only WoL's own home-city buildings use (21.0 MB). Of these, **7 are re-encoded** (4 of them halved) and the other 49 are left as they are: 38 already follow the rules, 1 is also used by a building in the game, 8 stay in their folders and are not re-encoded there, and 2 have sides that are not powers of two (both: see "A finding").
- **Size:** 21.05 MB -> 16.42 MB on disk; estimated video memory (every mip level as the card holds it) 21.04 MB -> 16.42 MB. For a DXT texture the two are nearly the same: the file is the levels plus a header of a few bytes.
- **Alpha declared but not used:** 27 of these textures declare alpha 1, 4 or 8, but their alpha channel is opaque everywhere (8.8 MB). By the rule they stay DXT3 and keep their header. If their header said alpha 0, they could be DXT1, which would halve them. That is your call: say the word and we switch them.

**A finding: textures re-encoded where they are.** Ten building textures do not move with their
models, so they would have been re-encoded in place, under the same name:
- 2 in `Homecity\WOTTA\LA buildings`, shared by three home cities;
- 8 of the Italian obelisk, named by an animation file.

In game, with them re-encoded, home cities opened later in the same session lost their
`<replacetexture>` swaps, in scenes that never draw those textures:
- Bucharest's room lost its Romanian wallpaper and floor;
- Guatemala's market lost its roof tiles, and its grass turned to snow;
- Asunción showed the Spanish sky.

The same cities drew right when opened first in a fresh session, and each group alone passed a
short sequence. With all ten left as they were, all 22 home cities opened one after the other in
one session and drew as before. Why this happens is not known yet, so those ten stay as they
were. Two of them (133 x 108 and 166 x 357) also have sides that are not powers of two. TAD has no
such texture, so the tool now leaves those alone in any case. Only textures that move with their
models, under a new name, ship re-encoded.

### Every building texture

"Mean" and "Worst block" are the check above (0 = the same pixels).

| Home city | Texture (where it ends up, below `art`) | Before | Size | KB | After | Size | KB | Mean | Worst block | Result |
|---|---|---|---|---:|---|---|---:|---:|---:|---|
| Afghans | `WoL\homecity\Afghans\textures\BalaHissarBuildings.(1,1,8,8).ddt` | (1,1,8,6) | 1024x1024 | 1365 | (1,1,8,8) | 512x512 | 341 | 2.6 | 14.5 | re-encoded (moved) |
| Afghans | `WoL\homecity\Afghans\textures\BalaHissarBuildings_b.(6,0,9,8).ddt` | (6,0,9,1) | 1024x1024 | 1024 | (6,0,9,8) | 512x512 | 341 | 0.9 | 4.9 | re-encoded (moved) |
| Argentineans | `WoL\homecity\Argentineans\Aduana\ARG_Aduana_1_A.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Aduana\ARG_Aduana_1_B.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Aduana\ARG_Aduana_2_A.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Aduana\ARG_Aduana_2_B.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Aduana\ARG_Aduana_3_A.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Aduana\ARG_Aduana_3_B.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Aduana\ARG_Aduana_4_A.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Aduana\ARG_Aduana_4_B.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Aduana\ARG_Aduana_5_A.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Aduana\ARG_Aduana_5_B.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Casa_Rosada\ARG_CasaRosada_Part_1.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Casa_Rosada\ARG_CasaRosada_Part_1_b.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Catedral\ARG_Catedral Bs As_1.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Catedral\ARG_Catedral Bs As_2.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Catedral\ARG_Catedral Bs As_3.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Catedral\ARG_Catedral Bs As_4.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Mercado_de_Abastos\ARG_Mercado_de_Abastos_1.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Argentineans | `WoL\homecity\Argentineans\Mercado_de_Abastos\ARG_Mercado_de_Abastos_3.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `NOW\Buildingset\Age2\MiningCamp\MiningCamp_age2.ddt` | (0,1,1,1) | 256x256 | 256 | (0,1,1,1) | 256x256 | 256 |  |  | kept: a unit or building of the game uses it too (WolMiningcamp) |
| Bolivians | `WoL\homecity\Bolivians\Convento_San_Felipe\BOL_Convento_San_Felipe_Neri_Lv1.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `WoL\homecity\Bolivians\Convento_San_Felipe\BOL_Convento_San_Felipe_Neri_Lv1_b.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `WoL\homecity\Bolivians\Convento_San_Felipe\BOL_Convento_San_Felipe_Neri_Lv2.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `WoL\homecity\Bolivians\Convento_San_Felipe\BOL_Convento_San_Felipe_Neri_Lv2_b.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `WoL\homecity\Bolivians\Convento_San_Felipe\BOL_Convento_San_Felipe_Neri_Lv3.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `WoL\homecity\Bolivians\Convento_San_Felipe\BOL_Convento_San_Felipe_Neri_Lv3_b.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `WoL\homecity\Bolivians\Convento_San_Felipe\BOL_Convento_San_Felipe_Neri_Lv4.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `WoL\homecity\Bolivians\Correos_De_Bolivia\Correos_De_Bolivia.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `WoL\homecity\Bolivians\Correos_De_Bolivia\props_colony_BOL_Correos.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `WoL\homecity\Bolivians\Palacio_Nacional\Palacio_Nacional_1.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `WoL\homecity\Bolivians\Palacio_Nacional\Palacio_Nacional_2.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `WoL\homecity\Bolivians\Palacio_Nacional\Palacio_Nacional_3.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Bolivians | `WoL\homecity\Bolivians\Palacio_Nacional\Palacio_Nacional_4.(0,4,8,8).ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Centralamericans | `WoL\homecity\Centralamericans\CEN_academy.ddt` | (0,1,8,8) | 512x512 | 341 | (0,1,8,8) | 512x512 | 341 |  |  | unchanged |
| Centralamericans | `WoL\homecity\Centralamericans\CEN_academy_PII.ddt` | (0,1,8,8) | 512x512 | 341 | (0,1,8,8) | 512x512 | 341 |  |  | unchanged |
| Centralamericans | `WoL\homecity\Centralamericans\CEN_harbor.ddt` | (0,4,8,8) | 512x512 | 341 | (0,4,8,8) | 512x512 | 341 |  |  | unchanged |
| Centralamericans | `WoL\homecity\Centralamericans\CEN_manufacturing.ddt` | (0,1,8,8) | 512x512 | 341 | (0,1,8,8) | 512x512 | 341 |  |  | unchanged |
| Centralamericans | `WoL\homecity\Centralamericans\Toldo.ddt` | (0,1,8,1) | 512x256 | 128 | (0,1,8,7) | 512x256 | 170 | 0.0 | 0.0 | re-encoded (moved) |
| Centralamericans | `WoL\homecity\Centralamericans\tradecenter.ddt` | (0,1,8,8) | 512x512 | 341 | (0,1,8,8) | 512x512 | 341 |  |  | unchanged |
| Centralamericans, Haitians, Paraguayans | `Homecity\WOTTA\LA buildings\4d36ac85.ddt` | (0,0,4,8) | 256x1024 | 170 | (0,0,4,8) | 256x1024 | 170 |  |  | kept: it stays in its folder, where re-encoding was left out (see "A finding") |
| Centralamericans, Haitians, Paraguayans | `Homecity\WOTTA\LA buildings\52bac0e2.ddt` | (0,0,4,10) | 1024x1024 | 682 | (0,0,4,10) | 1024x1024 | 682 |  |  | kept: it stays in its folder, where re-encoding was left out (see "A finding") |
| Chileans | `WoL\homecity\Chileans\EqBas\RepChile\FuerteEsmeralda1.(0,8,8,9).ddt` | (0,8,1,9) | 512x512 | 1365 | (0,8,8,9) | 512x512 | 341 | 1.6 | 11.7 | re-encoded (moved) |
| Chileans | `WoL\homecity\Chileans\EqBas\RepChile\IglesiaDeLaMatriz.(0,8,8,9).ddt` | (0,8,1,9) | 512x512 | 1365 | (0,8,8,9) | 512x512 | 341 | 1.2 | 11.6 | re-encoded (moved) |
| Haitians | `WoL\homecity\Haitians\haitian_hc_iron_market.ddt` | (0,0,8,9) | 512x512 | 341 | (0,0,8,9) | 512x512 | 341 |  |  | unchanged |
| Italians | `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_access_skin.ddt` | (1,1,1,1) | 133x108 | 56 | (1,1,1,1) | 133x108 | 56 |  |  | kept: 133x108: sides that are not powers of two are left as they are (DXT and mips need them) |
| Italians | `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_cilinder_skin.ddt` | (1,1,1,1) | 166x357 | 231 | (1,1,1,1) | 166x357 | 231 |  |  | kept: 166x357: sides that are not powers of two are left as they are (DXT and mips need them) |
| Italians | `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_floor2_skin.ddt` | (1,1,1,1) | 256x256 | 256 | (1,1,1,1) | 256x256 | 256 |  |  | kept: it stays in its folder, where re-encoding was left out (see "A finding") |
| Italians | `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_floor3_skin.ddt` | (1,1,1,1) | 64x16 | 4 | (1,1,1,1) | 64x16 | 4 |  |  | kept: it stays in its folder, where re-encoding was left out (see "A finding") |
| Italians | `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_floor4_skin.ddt` | (1,1,1,1) | 64x8 | 2 | (1,1,1,1) | 64x8 | 2 |  |  | kept: it stays in its folder, where re-encoding was left out (see "A finding") |
| Italians | `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_pilar1_skin.ddt` | (1,1,1,1) | 256x256 | 256 | (1,1,1,1) | 256x256 | 256 |  |  | kept: it stays in its folder, where re-encoding was left out (see "A finding") |
| Italians | `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_pilar2_skin.ddt` | (1,1,1,1) | 256x128 | 128 | (1,1,1,1) | 256x128 | 128 |  |  | kept: it stays in its folder, where re-encoding was left out (see "A finding") |
| Italians | `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_pilar3_skin.ddt` | (1,1,1,1) | 256x256 | 256 | (1,1,1,1) | 256x256 | 256 |  |  | kept: it stays in its folder, where re-encoding was left out (see "A finding") |
| Paraguayans | `War of the Triple Alliance\Buntings\bunting_paraguay.ddt` | (0,0,4,5) | 128x64 | 5 | (0,0,4,5) | 128x64 | 5 |  |  | unchanged |
| Swedish | `WoL\homecity\Swedish\3d_models\cathedral\cathedral_a.(0,0,4,8).ddt` | (0,0,4,10) | 1024x1024 | 682 | (0,0,4,8) | 512x512 | 170 | 4.1 | 17.0 | re-encoded (moved) |
| Swedish | `WoL\homecity\Swedish\3d_models\cathedral\cathedral_b.(0,0,4,8).ddt` | (0,0,4,10) | 1024x1024 | 682 | (0,0,4,8) | 512x512 | 170 | 4.3 | 12.6 | re-encoded (moved) |

## The suffix

A texture whose models store it as `.tga`, `.png` or `.jpg` is renamed on disk to
`<name>.(u,a,f,m).ddt`. The models then store `<name>.(u,a,f,m).tga`. The digits are the header
the file ships with: its own header, or the new one for the 6 re-encoded textures
that carry a suffix. Re-encoding comes before the suffix, so no name states an old header (all
119 suffixes were checked against their file).

The game drops only the last extension of a stored name, so `<name>.(u,a,f,m).tga` reaches
`<name>.(u,a,f,m).ddt`. This was tested in game:
- a suffix in the stored name with the `.ddt` not renamed draws the model black;
- with both renamed, the model draws as before.

119 textures got the suffix, and 168 stored names were rewritten with it. 121 moved textures keep
their name, by the rules:
- 42 are stored by a model as `.ddt`, and `.ddt` names stay as they are;
- 79 are named by an animation file (`<replacetexture>`, decals, ground textures) and by no model.
  The anim files name them without an extension, so they keep their name.

The headers vary a lot: (0,4,8,8), (0,1,8,8), (0,0,4,9), (0,8,8,9), (1,1,8,7) and more. So
0188/6098 were never assumed.

## Per home city

"Diff" is the largest mean pixel difference over the six views, before against after, in levels
out of 255. People, horses, fire, smoke, flags, particles and water move between two shots, so
they make up most of it. Each view above 1 was checked by eye. "Re-encoded" counts the home city's
building textures that changed format, size or mips.

| Home city (saved city tested) | Models | Textures (suffixed) | Anim files | Re-encoded | Diff | Notes |
|---|---:|---:|---:|---:|---:|---|
| Afghans (Kabul) | 24 | 17 (10) | 7 | 2 | 1.4 | bone ×100 left as is (decision 1); [before/after](media/hub_Kabul.jpg) |
| Argentineans (Buenos Aires) | 32 | 45 (41) | 7 |  | 1.0 | 4 shared with Bolivia go to `_shared`; market fix below; [before/after](media/hub_Buenos_Aires.jpg) |
| Bolivians (Sucre) | 20 | 37 (37) | 7 |  | 0.3 | the shared plaza props are in `_shared`; [before/after](media/hub_Sucre.jpg) |
| Bulgarians (Sofia) | 24 | 4 (4) | 7 |  | 2.3 | the Balkan room set (shared with Greeks, Romanians, Serbians) goes to `_shared`; [before/after](media/hub_Sofia.jpg) |
| Centralamericans (Guatemala) | 1 | 15 (0) | 6 | 1 | 4.2 | `PY church` shared with Haitians, Paraguayans; [before/after](media/hub_Guatemala.jpg) |
| Chileans (Valparaiso) | 12 | 17 (2) | 2 | 2 | 2.3 | 10 models uncompressed (see "Known issues"); [before/after](media/hub_Valparaiso.jpg) |
| Egyptians (Cairo) | 5 | 10 (6) | 7 |  | 6.6 | the ambassador hats shared with Saudis go to `_shared`; diff from the fez and a flag's shadow; [before/after](media/hub_Cairo.jpg) |
| Ethiopians (Addis Ababa) | 0 | 6 (0) | 5 |  | 2.6 | before: shots of the same original files from earlier that day (see "How it was checked"); [before/after](media/hub_Addis_Ababa.jpg) |
| Greeks (Athens) | 2 | 3 (1) | 3 |  | 1.8 | [before/after](media/hub_Athens.jpg) |
| Haitians (Port-au-Prince) | 4 | 15 (0) | 3 |  | 2.2 | 4 models uncompressed; [before/after](media/hub_Port-au-Prince.jpg) |
| Italians (Rome) | 10 | 4 (0) | 2 |  | 1.0 | [before/after](media/hub_Rome.jpg) |
| Maori (Parihaka) | 0 | 13 (0) | 9 |  | 3.3 | its models are also used outside the home cities and stay; [before/after](media/hub_Parihaka.jpg) |
| Paraguayans (Asunción) | 0 | 10 (0) | 4 |  | 1.4 | [before/after](media/hub_Asuncion.jpg) |
| Persians (Tehran) | 1 | 1 (1) | 0 |  | 0.0 | [before/after](media/hub_Tehran.jpg) |
| Romanians (Bucharest) | 0 | 0 (0) | 1 |  | 1.9 | everything was already moved as shared; [before/after](media/hub_Bucharest.jpg) |
| Saudis (Riyadh) | 1 | 1 (1) | 0 |  | 0.0 | [before/after](media/hub_Riyadh.jpg) |
| Serbians (Belgrade) | 1 | 0 (0) | 1 |  | 1.8 | [before/after](media/hub_Belgrade.jpg) |
| Swedish (Stockholm) | 1 | 6 (2) | 5 | 2 | 2.3 | the cathedral's newer plain file moves; its older compiled twin stays (see "Known issues"); [before/after](media/hub_Stockholm.jpg) |
| Tupinamba (Aracoara) | 1 | 14 (3) | 8 |  | 4.2 | [before/after](media/hub_Aracoara.jpg) |
| Uzbeks (Bukhara) | 1 | 1 (1) | 0 |  | 0.0 | [before/after](media/hub_Bukhara.jpg) |
| WallMapu (Perquenco) | 4 | 9 (0) | 8 |  | 3.2 | 4 models uncompressed; [before/after](media/hub_Perquenco.jpg) |
| Zulu (Bulawayo) | 10 | 12 (10) | 7 |  | 2.5 | [before/after](media/hub_Bulawayo.jpg) |
| The shared props and proto-unit tables | 7 | 0 | 0 |  |  | the African slaves and `gold_Model` go to `_shared` |

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

## Media

Everything here is in `media\`. The hub pictures are the home city's main view, before (left) and after (right), from the same save; people, animals, smoke, flags and water move between two shots.

| Home city | Hub before / after |
|---|---|
| Addis Ababa | [hub_Addis_Ababa.jpg](media/hub_Addis_Ababa.jpg) |
| Aracoara | [hub_Aracoara.jpg](media/hub_Aracoara.jpg) |
| Asuncion | [hub_Asuncion.jpg](media/hub_Asuncion.jpg) |
| Athens | [hub_Athens.jpg](media/hub_Athens.jpg) |
| Belgrade | [hub_Belgrade.jpg](media/hub_Belgrade.jpg) |
| Bucharest | [hub_Bucharest.jpg](media/hub_Bucharest.jpg) |
| Buenos Aires | [hub_Buenos_Aires.jpg](media/hub_Buenos_Aires.jpg) |
| Bukhara | [hub_Bukhara.jpg](media/hub_Bukhara.jpg) |
| Bulawayo | [hub_Bulawayo.jpg](media/hub_Bulawayo.jpg) |
| Cairo | [hub_Cairo.jpg](media/hub_Cairo.jpg) |
| Guatemala | [hub_Guatemala.jpg](media/hub_Guatemala.jpg) |
| Kabul | [hub_Kabul.jpg](media/hub_Kabul.jpg) |
| Parihaka | [hub_Parihaka.jpg](media/hub_Parihaka.jpg) |
| Perquenco | [hub_Perquenco.jpg](media/hub_Perquenco.jpg) |
| Port-au-Prince | [hub_Port-au-Prince.jpg](media/hub_Port-au-Prince.jpg) |
| Riyadh | [hub_Riyadh.jpg](media/hub_Riyadh.jpg) |
| Rome | [hub_Rome.jpg](media/hub_Rome.jpg) |
| Sofia | [hub_Sofia.jpg](media/hub_Sofia.jpg) |
| Stockholm | [hub_Stockholm.jpg](media/hub_Stockholm.jpg) |
| Sucre | [hub_Sucre.jpg](media/hub_Sucre.jpg) |
| Tehran | [hub_Tehran.jpg](media/hub_Tehran.jpg) |
| Valparaiso | [hub_Valparaiso.jpg](media/hub_Valparaiso.jpg) |

Bala Hissar (Kabul), whose two textures were halved from 1024 to 512, seen from its building view before and after: [building_Kabul_BalaHissar.jpg](media/building_Kabul_BalaHissar.jpg).

The comparison sheets of the re-encoded textures: the original's top level, the new top level, and their difference x4, each at 100 % (a second row shows the alpha channels).

- [sheet_BalaHissarBuildings.jpg](media/sheet_BalaHissarBuildings.jpg)
- [sheet_BalaHissarBuildings_b.jpg](media/sheet_BalaHissarBuildings_b.jpg)
- [sheet_FuerteEsmeralda1.jpg](media/sheet_FuerteEsmeralda1.jpg)
- [sheet_IglesiaDeLaMatriz.jpg](media/sheet_IglesiaDeLaMatriz.jpg)
- [sheet_Toldo.jpg](media/sheet_Toldo.jpg)
- [sheet_cathedral_a.jpg](media/sheet_cathedral_a.jpg)
- [sheet_cathedral_b.jpg](media/sheet_cathedral_b.jpg)

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
- **Textures that are not WoL's building textures are not re-encoded:** backgrounds, skies, water,
  people, props, and anything shared with them or with the game (the lists at the end).
- **The header's alpha value is never changed.** 27 building textures declare alpha 1, 4 or 8 but
  their alpha channel is opaque everywhere (8.8 MB). With alpha 0 they could be DXT1, half the size.
  That is your call.
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
- Each texture was re-encoded by `tools/reencode_textures.py` (aoe3-blender-tools) and checked
  against its original (see "The check"); the move and the suffix were written by `hc_move.py`.
- Each home city was opened from Skirmish > Manage Home Cities > Select. Each view was shot at
  1920×1080 before and after.
- **One session, many home cities.** After many home cities in one game session, the game can draw a
  home city with some `<replacetexture>` swaps missing, with WoL's own files too: Addis Ababa, opened as
  the 24th home city of one session, drew other windows and walls than when opened first. The after
  pass opened all 22 home cities in one session, as the before pass did, and none showed it; Addis
  Ababa's before shots are those of a shorter session on the same original files.
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

### Building textures not touched

Textures that a building's `<visual>` reaches, but that do not belong to WoL's buildings alone.

<details><summary>People and animals standing in for a building (100)</summary>

- `homecity\homecity_units\HC_Indian_Soldier\Homecity_soldier_BumpSpec.ddt` (Ethiopians)
- `homecity\homecity_units\HC_Indian_Soldier\Homecity_soldier_Colour.ddt` (Ethiopians)
- `Homecity\NOW\Argentina\Plaza_De_Mayo\ARG_Plaza_de_Mayo_2.ddt` (Argentineans)
- `Homecity\NOW\Argentina\Plaza_De_Mayo\Banco.ddt` (Argentineans, Bolivians)
- `Homecity\NOW\Argentina\Plaza_De_Mayo\Caballo.ddt` (Argentineans, Bolivians)
- `Homecity\NOW\Argentina\Plaza_De_Mayo\Cantero.ddt` (Argentineans, Bolivians)
- `Homecity\NOW\Argentina\Plaza_De_Mayo\Flor.ddt` (Argentineans, Bolivians)
- `Homecity\NOW\Argentina\Plaza_De_Mayo\Hierba.ddt` (Argentineans)
- `Homecity\NOW\Argentina\Plaza_De_Mayo\Jinete.ddt` (Argentineans, Bolivians)
- `Homecity\NOW\Bolivia\Feria_Artesanal\Feria_Artesanal_base.ddt` (Bolivians)
- `Homecity\NOW\Bolivia\Feria_Artesanal\Feria_Artesanal_base_2.ddt` (Bolivians)
- `Homecity\NOW\Bolivia\Feria_Artesanal\Feria_Artesanal_Caseta.ddt` (Bolivians)
- `Homecity\NOW\Bolivia\Feria_Artesanal\Feria_Artesanal_commodity.ddt` (Bolivians)
- `Homecity\NOW\Bolivia\Plaza_De_Sucre\BOL_Plaza_de_Sucre_1.ddt` (Bolivians)
- `Homecity\NOW\Bolivia\Plaza_De_Sucre\BOL_Plaza_de_Sucre_1_b.ddt` (Bolivians)
- `Homecity\polynesians\maori\maori_woman.ddt` (Maori)
- `Homecity\polynesians\maori\mau_rakau_gear.ddt` (Maori)
- `Homecity\polynesians\maori\mau_rakau_head.ddt` (Maori)
- `Homecity\polynesians\maori\missionary.ddt` (Maori)
- `Homecity\polynesians\maori\rangatira.ddt` (Maori)
- `Homecity\polynesians\maori\tohunga.ddt` (Maori)
- `Homecity\polynesians\maori\tohunga_gear.ddt` (Maori)
- `Homecity\WOTTA\Ambassadors\belgiandress.ddt` (Zulu)
- `Homecity\WOTTA\Ambassadors\belgianribbon.ddt` (Zulu)
- `Homecity\WOTTA\Ambassadors\dutchbutton.ddt` (Zulu)
- `Homecity\WOTTA\Ambassadors\dutchcollar.ddt` (Zulu)
- `Homecity\WOTTA\Ambassadors\dutchhat.ddt` (Zulu)
- `Homecity\WOTTA\Ambassadors\egyptianhat.ddt` (Egyptians, Saudis)
- `Homecity\WOTTA\Ambassadors\ethiopian.ddt` (Ethiopians)
- `Homecity\WOTTA\Ambassadors\ethiopian_b.ddt` (Ethiopians)
- `Homecity\WOTTA\Ambassadors\feather.ddt` (Egyptians, Saudis, Zulu)
- `Homecity\WOTTA\Ambassadors\frenchhat.ddt` (Egyptians, Saudis)
- `Homecity\WOTTA\Ambassadors\jewels.ddt` (Zulu)
- `Homecity\WOTTA\Ambassadors\portuguese_hat.ddt` (Bulgarians, Ethiopians, Greeks, Romanians, Serbians)
- `Homecity\WOTTA\Ambassadors\zulufeathers.ddt` (Zulu)
- `Homecity\WOTTA\Ambassadors\zuluhat.ddt` (Zulu)
- `Homecity\WOTTA\balkanpoliticians\greek\academy.ddt` (Greeks, Romanians)
- `Homecity\WOTTA\balkanpoliticians\greek\academy_b.ddt` (Greeks, Romanians)
- `Homecity\WOTTA\balkanpoliticians\greek\de_Gaullle_NONSHADER.ddt` (Greeks, Romanians)
- `Homecity\WOTTA\balkanpoliticians\greek\factory.ddt` (Bulgarians, Greeks, Romanians, Serbians)
- `Homecity\WOTTA\balkanpoliticians\greek\factory_b.ddt` (Bulgarians, Greeks, Romanians, Serbians)
- `Homecity\WOTTA\balkanpoliticians\greek\market hat.ddt` (Bulgarians, Greeks, Romanians, Serbians)
- `Homecity\WOTTA\balkanpoliticians\greek\market.ddt` (Bulgarians, Greeks, Romanians, Serbians)
- `Homecity\WOTTA\balkanpoliticians\greek\market_b.ddt` (Bulgarians, Greeks, Romanians, Serbians)
- `Homecity\WOTTA\balkanpoliticians\romanian\Charlemagne_DIFF.ddt` (Bulgarians, Romanians)
- `Homecity\WOTTA\balkanpoliticians\romanian\fur.ddt` (Bulgarians, Romanians)
- `Homecity\WOTTA\ChieftainMa.ddt` (WallMapu)
- `Homecity\WOTTA\MapucheWarrior.ddt` (WallMapu)
- `Homecity\WOTTA\Shaman_Mapuche.ddt` (WallMapu)
- `Homecity\WOTTA\Tupi\chief_gear.ddt` (Tupinamba)
- `Homecity\WOTTA\Tupi\chief_head.ddt` (Tupinamba)
- `Homecity\WOTTA\Tupi\hair-feathers.ddt` (Tupinamba)
- `Homecity\WOTTA\Tupi\shaman_gear.ddt` (Tupinamba)
- `Homecity\WOTTA\Tupi\shaman_head.ddt` (Tupinamba)
- `Homecity\WOTTA\Tupi\war_leader_head.ddt` (Tupinamba)
- `Homecity\WOTTA\Tupi\wise_woman_gear.ddt` (Tupinamba)
- `Homecity\WOTTA\Tupi\wise_woman_head.ddt` (Tupinamba)
- `Homecity\WOTTA\wise_woman_gearMA.ddt` (WallMapu)
- `Homecity\WOTTA\wise_womanMA.ddt` (WallMapu)
- `Homecity\WOTTA\zulushield.ddt` (Zulu)
- `shadows_selections\selection_circle_32x32.ddt` (Bolivians, British (homecityRevolution), British, Bulgarians, Colombians, Ethiopians, Greeks, Indians, Indians, Maori, Mexicans, Peruvians, Romanians, SPCChinese, SPCChinese, SPCIndians, SPCIndians, Serbians, Tawantinsuyu, Tupinamba, UnitedStates, WallMapu, XPAztec, XPAztec, XPSPC, XPSPC, Zulu, protounits)
- `shadows_selections\shadow_circle_32x32.ddt` (Bolivians, British (homecityRevolution), British, Bulgarians, Colombians, Ethiopians, Greeks, Indians, Indians, Maori, Mexicans, Peruvians, Romanians, SPCChinese, SPCChinese, SPCIndians, SPCIndians, Serbians, Tawantinsuyu, Tupinamba, UnitedStates, XPAztec, XPAztec, XPSPC, XPSPC, Zulu, protounits)
- `units\HC_politicians\Iroquois\common\hair-feathers.DDT` (Tupinamba, WallMapu)
- `units\HC_politicians\Iroquois\common\hair-feathers_b.DDT` (WallMapu)
- `units\HC_politicians\Iroquois\Messenger\messenger.DDT` (WallMapu)
- `units\HC_politicians\Iroquois\Messenger\messenger_b.DDT` (WallMapu)
- `units\HC_politicians\Iroquois\Messenger\messenger_gear.DDT` (WallMapu)
- `units\HC_politicians\Iroquois\Messenger\messenger_gear_b.DDT` (WallMapu)
- `units\HC_politicians\Iroquois\shaman\shaman.ddt` (Maori)
- `units\HC_politicians\Iroquois\shaman\shaman_gear.ddt` (Maori)
- `units\HC_politicians\Iroquois\war_leader\war_leader.ddt` (Maori, Tupinamba)
- `units\HC_politicians\Iroquois\war_leader\war_leader_gear.ddt` (Maori)
- `units\HC_politicians\Iroquois\Wise_woman\wise_woman.DDT` (Tupinamba)
- `units\HC_politicians\Iroquois\Wise_woman\wise_woman_b.DDT` (WallMapu)
- `units\HC_politicians\Iroquois\Wise_woman\wise_woman_gear.DDT` (Tupinamba)
- `units\HC_politicians\Iroquois\Wise_woman\wise_woman_gear_b.DDT` (WallMapu)
- `units\HC_politicians\Sioux\chief\sioux_chief_body.DDT` (Tupinamba)
- `units\HC_politicians\Sioux\chief\sioux_chief_gear.DDT` (Tupinamba)
- `units\HC_politicians\Sioux\shaman\shaman_body.DDT` (Tupinamba)
- `units\HC_politicians\Sioux\shaman\shaman_gear.DDT` (Tupinamba)
- `units\natives\lakota\club_warrior\lakota_club_warrior1.ddt` (Maori)
- `units\polynesia\maori\mere.ddt` (Maori)
- `units\spc\bolivar\bolivar_igc.ddt` (Greeks, Romanians)
- `units\spc\bolivar\bolivar_igc_bumpmap.ddt` (Greeks, Romanians)
- `units\spc\chayton\chayton.ddt` (Maori)
- `units\spc\custer\custer.ddt` (Argentineans, Bolivians)
- `units\spc\custer\horse_custer.ddt` (Argentineans, Bolivians)
- `units\spc\john_black\john_black.ddt` (Maori)
- `units\spc\kanyenke_old\igc_kanyenke_old_b.ddt` (WallMapu)
- `units\spc\major_cooper\igc_major_cooper.ddt` (Bulgarians, Greeks, Romanians, Serbians)
- `units\spc\major_cooper\igc_major_cooper_b.ddt` (Bulgarians, Greeks, Romanians, Serbians)
- `units\spc\nate_black\nate_black_duster_n.DDT` (WallMapu)
- `units\spc\nate_black\nate_black_weapons.DDT` (WallMapu)
- `units\spc\nate_black\nate_black_weapons_b.DDT` (WallMapu)
- `units\spc\nonahkee\nonahkee_normal.DDT` (WallMapu)
- `units\spc\nonahkee_x\igc_nonahkee.ddt` (Maori)
- `units\spc\stuart_black\stuart_black_igc.ddt` (Bulgarians, Greeks, Romanians, Serbians)
- `units\spc\stuart_black\stuart_black_igc_bumpmap.ddt` (Bulgarians, Greeks, Romanians, Serbians)
- `War of the Triple Alliance\Units\Delta\equipment\ethiopianshield3.ddt` (Ethiopians)
- `War of the Triple Alliance\Units\Delta\Zulu\assegai\redhat.ddt` (Egyptians, Saudis)

</details>

<details><summary>Shared with a scene, background, water, path or prop (18)</summary>

- `buildings\asian_civs\town_center\indian_accessories01.ddt` (Afghans): shared with a scene, background, water, path or prop
- `buildings\flags\pendent.ddt` (Argentineans, Bolivians, Maori, Mexicans, WallMapu): shared with a scene, background, water, path or prop
- `buildings\flags\pendent01.ddt` (Bolivians, Maori, Mexicans, WallMapu): shared with a scene, background, water, path or prop
- `buildings\flags\pendent_blue.ddt` (Italians, Mexicans, Portuguese, Portuguese, props): shared with a scene, background, water, path or prop
- `buildings\flags\pendent_red.ddt` (Ottomans, Ottomans, Uruguayans, props): shared with a scene, background, water, path or prop
- `buildings\flags\pendent_yellow.ddt` (Brazilians, Colombians, Paraguayans, Spanish, Spanish, props): shared with a scene, background, water, path or prop
- `buildings\native_civs\props_colony\native_colony_props.ddt` (Ethiopians, Haitians, Maori): shared with a scene, background, water, path or prop
- `Homecity\afghan\textures\BaburGarden.ddt` (Afghans): shared with a scene, background, water, path or prop
- `Homecity\afghan\textures\BaburGarden_b.ddt` (Afghans): shared with a scene, background, water, path or prop
- `homecity\aztec\aztec_thatch.ddt` (Centralamericans, Peruvians): shared with a scene, background, water, path or prop
- `homecity\buildings_med\med_harbor_a_colormap.ddt` (Italians, Ottomans, Ottomans, Paraguayans, SPCAct1, SPCAct1, Spanish, Spanish): shared with a scene, background, water, path or prop
- `homecity\buildings_med\med_harbor_a_greengold.ddt` (Italians, Ottomans, Ottomans, Paraguayans, SPCAct1, SPCAct1, Spanish, Spanish): shared with a scene, background, water, path or prop
- `homecity\buildings_med\med_harbor_b_colormap.ddt` (Italians, Ottomans, Ottomans, Paraguayans, SPCAct1, SPCAct1, Spanish, Spanish): shared with a scene, background, water, path or prop
- `homecity\buildings_med\med_harbor_b_greengold.ddt` (Italians, Ottomans, Ottomans, Paraguayans, SPCAct1, SPCAct1, Spanish, Spanish): shared with a scene, background, water, path or prop
- `Homecity\NOW\Argentina\Sky\House_Homecity_ARG\Argentina_Props.ddt` (Argentineans): shared with a scene, background, water, path or prop
- `shadows_selections\selection_square_128x128.ddt` (Italians, Maori): shared with a scene, background, water, path or prop
- `shadows_selections\shadow_circle_128x128.ddt` (Bolivians, Italians, protounits): shared with a scene, background, water, path or prop
- `War of the Triple Alliance\Delta\AURs\Buildings\s_mosque_diff_1.ddt` (Afghans): shared with a scene, background, water, path or prop

</details>

<details><summary>Named by an anim file no home city reaches (they stay where they are) (49)</summary>

- `buildings\asian_civs\town_center\indian_accessories01_bump.ddt` (Afghans): an anim file outside the home cities names it: war of the triple alliance\buildingsets\market.xml
- `buildings\modern\obelisk_roman\image_2d_0004_0003.ddt` (Italians): an anim file outside the home cities names it: war of the triple alliance\buildings\obelisk_roman\obelisk_roman_wotta.xml
- `buildings\modern\obelisk_roman\image_2d_0006_0005.ddt` (Italians): an anim file outside the home cities names it: war of the triple alliance\buildings\obelisk_roman\obelisk_roman_wotta.xml
- `buildings\modern\obelisk_roman\image_2d_0008_0006.ddt` (Italians): an anim file outside the home cities names it: war of the triple alliance\buildings\obelisk_roman\obelisk_roman_wotta.xml
- `buildings\modern\obelisk_roman\image_2d_0010_0007.ddt` (Italians): an anim file outside the home cities names it: war of the triple alliance\buildings\obelisk_roman\obelisk_roman_wotta.xml
- `buildings\modern\obelisk_roman\image_2d_0016_0004.ddt` (Italians): an anim file outside the home cities names it: war of the triple alliance\buildings\obelisk_roman\obelisk_roman_wotta.xml
- `buildings\modern\obelisk_roman\image_2d_0018_0010.ddt` (Italians): an anim file outside the home cities names it: war of the triple alliance\buildings\obelisk_roman\obelisk_roman_wotta.xml
- `buildings\modern\obelisk_roman\image_2d_0020_0011.ddt` (Italians): an anim file outside the home cities names it: war of the triple alliance\buildings\obelisk_roman\obelisk_roman_wotta.xml
- `buildings\modern\obelisk_roman\shared_acc_1.ddt` (Italians): an anim file outside the home cities names it: war of the triple alliance\buildings\obelisk_roman\obelisk_roman_wotta.xml
- `homecity\buildings_east\ee_tradiing_company_a_blck.ddt` (Austrohungarians, Brazilians, British (homecityRevolution), British, Germans, Germans, SPCAct3, SPCAct3, UnitedStates, Uruguayans): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_east\ee_tradiing_company_a_br.ddt` (Austrohungarians, Brazilians, British (homecityRevolution), British, Germans, Germans, Paraguayans, SPCAct3, SPCAct3, UnitedStates, Uruguayans): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_east\ee_tradiing_company_a_colormap.ddt` (Austrohungarians, Brazilians, British (homecityRevolution), British, Germans, Germans, Paraguayans, SPCAct3, SPCAct3, UnitedStates, Uruguayans): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_east\ee_tradiing_company_a_red.ddt` (Austrohungarians, Brazilians, British (homecityRevolution), British, Germans, Germans, SPCAct3, SPCAct3, UnitedStates, Uruguayans): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_east\ee_tradiing_company_a_snow.ddt` (Russians, Russians): an anim file outside the home cities names it: homecity\wotta\la buildings\secret_tradecenter.xml.xmb
- `homecity\buildings_east\ee_tradiing_company_a_snow_gk.ddt` (Russians, Russians): an anim file outside the home cities names it: homecity\wotta\la buildings\secret_tradecenter.xml.xmb
- `homecity\buildings_east\ee_tradiing_company_b_snow_gk.ddt` (Russians, Russians): an anim file outside the home cities names it: homecity\wotta\la buildings\secret_tradecenter.xml.xmb
- `homecity\buildings_east\ee_trading_company_b_snow.ddt` (Russians, Russians): an anim file outside the home cities names it: homecity\wotta\la buildings\secret_tradecenter.xml.xmb
- `homecity\buildings_east\ee_trading_company_bw1.ddt` (Austrohungarians, Brazilians, British (homecityRevolution), British, Germans, Germans, SPCAct3, SPCAct3, UnitedStates, Uruguayans): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_east\german_cathedral_blue_white1.ddt` (Austrohungarians, Belgians, Germans, Germans, SPCAct2, Swedish): an anim file outside the home cities names it: homecity\wotta\la buildings\secret_cathedral.xml.xmb
- `homecity\buildings_east\german_cathedral_blue_white2.ddt` (Austrohungarians, Belgians, Germans, Germans, SPCAct2, Swedish): an anim file outside the home cities names it: homecity\wotta\la buildings\secret_cathedral.xml.xmb
- `homecity\buildings_east\german_cathedral_colormap1.ddt` (Austrohungarians, Belgians, Germans, Germans, SPCAct2, Swedish): an anim file outside the home cities names it: homecity\wotta\la buildings\secret_cathedral.xml.xmb
- `homecity\buildings_east\german_cathedral_colormap2.ddt` (Austrohungarians, Belgians, Germans, Germans, SPCAct2, Swedish): an anim file outside the home cities names it: homecity\wotta\la buildings\secret_cathedral.xml.xmb
- `homecity\buildings_med\med_church_a_colormap.ddt` (Brazilians, Colombians, Italians, Mexicans, Peruvians, Portuguese, Portuguese, SPCAct1, SPCAct1, Spanish, Spanish, Uruguayans): an anim file outside the home cities names it: homecity\omega\centralamerica\cen_cathedral.xml
- `homecity\buildings_med\med_church_b_colormap.ddt` (Brazilians, Colombians, Italians, Mexicans, Peruvians, Portuguese, Portuguese, SPCAct1, SPCAct1, Spanish, Spanish, Uruguayans): an anim file outside the home cities names it: homecity\omega\centralamerica\cen_cathedral.xml
- `homecity\buildings_med\med_factory_blue1.ddt` (Brazilians, Colombians, Italians, Mexicans, Ottomans, Ottomans, Paraguayans, Portuguese, Portuguese, SPCAct1, Spanish, Spanish, Uruguayans): an anim file outside the home cities names it: homecity\wol\bolivia\manufacturing_plant_and_ground.xml
- `homecity\buildings_med\med_factory_blue2.ddt` (Brazilians, Colombians, Italians, Mexicans, Ottomans, Ottomans, Paraguayans, Portuguese, Portuguese, SPCAct1, Spanish, Spanish, Uruguayans): an anim file outside the home cities names it: homecity\wol\bolivia\manufacturing_plant_and_ground.xml
- `homecity\buildings_med\med_factory_colormap1.ddt` (Brazilians, Colombians, Italians, Mexicans, Ottomans, Ottomans, Paraguayans, Portuguese, Portuguese, SPCAct1, Spanish, Spanish, Uruguayans): an anim file outside the home cities names it: homecity\wol\bolivia\manufacturing_plant_and_ground.xml
- `homecity\buildings_med\med_factory_colormap2.ddt` (Brazilians, Colombians, Italians, Mexicans, Ottomans, Ottomans, Paraguayans, Portuguese, Portuguese, SPCAct1, Spanish, Spanish, Uruguayans): an anim file outside the home cities names it: homecity\wol\bolivia\manufacturing_plant_and_ground.xml
- `homecity\buildings_med\med_factory_orange1.ddt` (Brazilians, Colombians, Italians, Mexicans, Ottomans, Ottomans, Paraguayans, Portuguese, Portuguese, SPCAct1, Spanish, Spanish, Uruguayans): an anim file outside the home cities names it: homecity\wol\bolivia\manufacturing_plant_and_ground.xml
- `homecity\buildings_med\med_factory_orange2.ddt` (Brazilians, Colombians, Italians, Mexicans, Ottomans, Ottomans, Paraguayans, Portuguese, Portuguese, SPCAct1, Spanish, Spanish, Uruguayans): an anim file outside the home cities names it: homecity\wol\bolivia\manufacturing_plant_and_ground.xml
- `homecity\buildings_med\med_factory_yellow1.ddt` (Brazilians, Colombians, Italians, Mexicans, Ottomans, Ottomans, Paraguayans, Portuguese, Portuguese, SPCAct1, Spanish, Spanish, Uruguayans): an anim file outside the home cities names it: homecity\wol\bolivia\manufacturing_plant_and_ground.xml
- `homecity\buildings_med\med_factory_yellow2.ddt` (Brazilians, Colombians, Italians, Mexicans, Ottomans, Ottomans, Paraguayans, Portuguese, Portuguese, SPCAct1, Spanish, Spanish, Uruguayans): an anim file outside the home cities names it: homecity\wol\bolivia\manufacturing_plant_and_ground.xml
- `homecity\buildings_west\estate_b_blue_white1.ddt` (Australians, Brazilians, British (homecityRevolution), British, Canadians, Danish, Dutch, Dutch, French, French, Haitians, Peruvians, SPCAct2, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_west\estate_b_blue_white2.ddt` (Australians, Brazilians, British (homecityRevolution), British, Canadians, Danish, Dutch, Dutch, French, French, Haitians, Peruvians, SPCAct2, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_west\estate_b_colormap1.ddt` (Brazilians, British (homecityRevolution), British, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_west\estate_b_colormap2.ddt` (Brazilians, British (homecityRevolution), British, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_west\estate_b_dutch_brn_goldl1.ddt` (Brazilians, British (homecityRevolution), British, Danish, Dutch, Dutch, Peruvians, SPCAct2, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_west\estate_b_dutch_cream_blue1.ddt` (Brazilians, British (homecityRevolution), British, Danish, Dutch, Dutch, Peruvians, SPCAct2, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_west\estate_b_dutch_original2.ddt` (Brazilians, British (homecityRevolution), British, Danish, Dutch, Dutch, Peruvians, SPCAct2, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_west\estate_b_grey_blue1.ddt` (Australians, Brazilians, British (homecityRevolution), British, Canadians, Centralamericans, French, French, Haitians, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_west\estate_b_grey_blue2.ddt` (Australians, Brazilians, British (homecityRevolution), British, Canadians, Centralamericans, French, French, Haitians, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_west\estate_b_red_gold1.ddt` (Australians, Brazilians, British (homecityRevolution), British, Canadians, French, French, Haitians, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_west\estate_b_red_gold2.ddt` (Australians, Brazilians, British (homecityRevolution), British, Canadians, French, French, Haitians, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_west\estate_b_red_green1.ddt` (Australians, Brazilians, British (homecityRevolution), British, Canadians, Centralamericans, French, French, Haitians, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\buildings_west\estate_b_red_green2.ddt` (Australians, Brazilians, British (homecityRevolution), British, Canadians, Centralamericans, French, French, Haitians, SPCAct3, SPCAct3, UnitedStates): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\revolution\bunting_mexico.ddt` (British (homecityRevolution), British): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `homecity\revolution\bunting_usa.ddt` (British (homecityRevolution), British, Paraguayans): an anim file outside the home cities names it: homecity\wotta\hall.xml
- `objects\flags\china.ddt` (Chinese): an anim file outside the home cities names it: war of the triple alliance\units\javanese\javanese.xml
- `units\wotta_animals\penguin\Image_2D_0002_0002.ddt` (Italians): an anim file outside the home cities names it: units\wotta_animals\penguin\penguin.xml

</details>

<details><summary>Other (2)</summary>

- `homecity\revolution\bunting_0.ddt` (British (homecityRevolution), British): missing file (not the mod's own loose file)
- `objects\flags\japan.ddt` (Japanese, Japanese, Koreans, SPCJapanese, SPCJapanese): override file (not the mod's own loose file)

</details>

And 213 of TAD's own textures, which WoL's buildings use from the game's archives: they are not WoL's files, so they are not touched.

Building textures that the rules leave as they are:

- `NOW\Buildingset\Age2\MiningCamp\MiningCamp_age2.ddt`: a unit or building of the game uses it too (WolMiningcamp)
- `Homecity\WOTTA\LA buildings\4d36ac85.ddt`: it stays in its folder, where re-encoding was left out (see "A finding")
- `Homecity\WOTTA\LA buildings\52bac0e2.ddt`: it stays in its folder, where re-encoding was left out (see "A finding")
- `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_access_skin.ddt`: 133x108: sides that are not powers of two are left as they are (DXT and mips need them)
- `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_cilinder_skin.ddt`: 166x357: sides that are not powers of two are left as they are (DXT and mips need them)
- `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_floor2_skin.ddt`: it stays in its folder, where re-encoding was left out (see "A finding")
- `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_floor3_skin.ddt`: it stays in its folder, where re-encoding was left out (see "A finding")
- `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_floor4_skin.ddt`: it stays in its folder, where re-encoding was left out (see "A finding")
- `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_pilar1_skin.ddt`: it stays in its folder, where re-encoding was left out (see "A finding")
- `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_pilar2_skin.ddt`: it stays in its folder, where re-encoding was left out (see "A finding")
- `War of the Triple Alliance\Delta\modern\obelisk_roman\obelisk_roman_base_pilar3_skin.ddt`: it stays in its folder, where re-encoding was left out (see "A finding")

