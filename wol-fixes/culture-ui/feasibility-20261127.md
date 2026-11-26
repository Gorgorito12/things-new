# Culture UI: feasibility of one HUD with its textures swapped per culture (B0, 2026-11-27)

JTMaston's request (2026-11-25, paused: "it is big, it will have to wait"): in-game interface styles by the player's
culture. This is the preparation only (plan Part B, phase B0): no key was built and no game file was changed for good.
Engine facts with their evidence: [docs/engine-symbols.md](../../docs/engine-symbols.md), "UI textures by name: where a
texture swap per culture can go". Textures and gadgets: [inventory.md](inventory.md).

## Verdict

**Feasible**, with a texture redirect by name in the DLL. Measured and read:

1. Every UI texture is resolved by its name through one function, 0x58E3EB (texture manager `[0xC66044]+6A8h`). A
   layout's `background` and `stateEntry`s get there through the UI drawable's texture-by-path (0x638883, its call
   0x6388FE).
2. The HUD is **built at the start of each game**, after the world exists, with the local player and its civ readable
   (trace: the HUD build 0x76166A, then the 0x638823 call of every HUD gadget, then the first lookups of the
   `ui\ingame` atlases, all within 0.3 s).
3. The texture manager **keeps every name and its data for the whole launch**. Seen in game: an atlas replaced on disk
   between two games of the same launch still showed the old art in the second game; after a restart the new art
   showed. So swapping files between games cannot work, but asking for **another name** (`x_<suffix>`) makes its own
   entry and loads its own file. A culture played second in a launch gets its own textures.

The key (B1, provisional name `cultureUI`): at the head of 0x58E3EB, while a game world exists, a path that starts
with `ui\ingame\` becomes `<path>_<suffix>` when that texture exists; the suffix comes from the local player's civ
(a table culture or civ → suffix). No layout changes; both interfaces, every resolution and the observer files at once;
the memory of one style in a game (at most 7.8 MB, only what is drawn), plus earlier styles of the same launch until
exit. A style can start with one texture and grow.

Risks:

- **A hot function.** 0x58E3EB serves every texture of the game (110 callers seen, 30 more unresolved). The filter
  must be a prefix test and a cached decision, and the key needs a `perfprobe.py` A/B. If that costs too much, the
  narrower site is the call 0x6388FE (gadget textures set by path only).
- **Existence test.** The variant must exist or the stock name is kept: either the game's own file test (as 0x469479
  uses, to verify) or a list built at startup from the art folder and archives.
- **Observer and view switch.** WoL's observers are real players with a civ of their own, and their interface uses
  other atlases (`ingame_ui_01x_ypack`, `_01x_asian`, `ingame_ui_05`, `_06`). The key would need "observer → default
  style" or styled observer atlases. A player view switch inside a replay would not change the style (the names are
  fixed at the HUD build); whether it rebuilds the HUD is unknown.
- **Other DLLs.** No known patch of WoL's DLL or the original's at 0x58E3EB's head (the original's `removeFameRestriction`
  and `attackTypeIcons` patch two of its callers, 0x5C1E1F and 0x5C2287, which still reach the head). To verify with
  `VerifyAll` beside WoL's DLL.
- **Menus.** `ui\ingame\` textures are also used by menus and dialogs (options, post-game, politicians): with the
  filter "a game world exists", a dialog opened in a game would take the style too. Wanted or not is a design choice
  (the inventory lists them as out of scope for now).

**Alternative if the redirect cannot be used:** what the 2026-11-25 measurement proposed, one hidden holder per
culture
in `uimainnew.xml` with only its frames, shown with `techGadgets` (one line per culture). It touches the layouts and
does not reach the panels the engine builds from its own files. Setting textures per gadget after the build (0x638823)
is not recommended: it drops the layout's `textureCoords`, which then have to be set again by code for each gadget.

## What was tested in game

`C:\AoE3-UHC-WoLReal6` (its own profile), single player, scenario route, our DLL, a hardware-breakpoint tracer:

- `ingame_ui_small_01_ypack.ddt` (loose) replaced by a recoloured copy during game 1: no change in game 1 or game 2 of
  the same launch; teal after a restart (picture 3 below). The file, the profile and the copy were restored byte for
  byte (`ingame_ui_small_01_ypack.ddt` a955d0b1..., `NewProfile3.xml` dd043afc...); the test map was removed.
- The trace log, the tracer and the captures: `rea/evidence/culture-ui-20261127/` of the main repository (not in git).

## The preview tool

aoe3-blender-tools `tools/ui_preview.py --game <copy> --scene normal|min --size 1920x1080 --culture Eur|Asi|Nat
[--override <folder>] [--suffix S] [--moment ID=on|off]` draws the in-game screen with its textures (no text, nothing
the engine fills), so a style is approved as a picture. `--override` and `--suffix` follow the key's lookup: a folder
of `ui\ingame\x_<suffix>.png` or `.ddt` files is a style. Against a capture of WoL at 1920 x 1080 (minimised interface,
Ethiopians): the panels within 1 px, about 6/255 mean error on their art (picture 1).

## Pictures

`C:\Users\Jeison\Documents\GitHub\_share\maston-20261127\C\`:

1. `01_validation_game_vs_preview.png`: the game's HUD and the preview of the same layouts, one above the other.
2. `02_demo_one_atlas_recoloured.png`: WoL's HUD today and with one atlas (`ingame_ui_small_01_ypack`) recoloured two
   ways with `recolor_textures.py` (OKLCH), drawn by the preview with `--suffix`. It shows what a cheap variation gives:
   the minimap and command panels change, the resource and selection panels do not, because they live in other atlases
   (`asi_ui_max`, `ingame_ui_02x_ypack`). A whole style needs the eight atlases of the inventory.
3. `03_ingame_cache_test.png`: the in-game test above (second game of a launch, then after a restart).

## Questions for JTMaston (English, to send)

1. One style per culture (19 cultures have public civs), or per family (for example European, Asian, Native American,
   Middle Eastern, African)? Families mean five to six sets of eight atlases instead of nineteen.
2. Who draws the art: your artists, or a first set made with our tools (recolouring and local repainting of the current
   atlases) for your artists to finish?
3. Only the minimised interface? You said you want to remove the full one; the minimised one uses about 7 of the 8
   atlases (not `ingame_ui_03x_ypack`).
4. Should the style change at the Great War (a second set per culture or family, switched at that age)? The names are
   fixed when the interface is built, so a change during a game needs more work than a style per game.
5. Observers: the default style, or styled observer screens too (they use four other atlases)?
