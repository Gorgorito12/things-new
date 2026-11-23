Damage templates whose "part" bones crash the game (#78, 2026-11-23)
====================================================================

A damage template (.dmg) lists "parts" (debris, a broken trunk) by the bone of the model they hang on. The
game looks each bone up by its name, which an anim file must define with <definebone>. When no anim file
loaded so far defined that name, the game writes "Invalid bone name ... in part declaration for model ...,
this probably means the bone was not defined in the unit's anim XML" and loads the model again while units
still draw it: the old model is freed under them and the game can crash in its next draw. It happens once per
bone name per game, when a building or tree with such a template is damaged or dies.

Fixed files (same paths as in the game folder):
- art\War of the Triple Alliance\DLC\Other\new trees\cypress.xml: the three
  damagetemplate="terrain\trees\Damage\tree_oak_a.dmg" removed. The cypress models (cypressA/B/C) have no
  bone "oak a death": with the key on, a 8-player game crashed 12 s after a cypress fell.
- art\War of the Triple Alliance\Buildingsets\market.xml: <definebone>bone_debris_2Q</definebone> to 2U added
  after bone_debris_2P. The West market's damaged model has these bones; the game reloaded it in every game.

The rest:
- dmg-bones-wol.csv: every anim file of WoL 1.0.15c (loose files over the art\*.bar archives) with a model and
  template pair at fault. "missing bones": bones the model lacks (fix: a template made for the model, or no
  template); "not defined": bones the model has but the anim file does not define (fix: <definebone> lines).
  182 and 253 pairs. A bone that another anim file defines is listed too: it is safe only when that file was
  loaded first in the game.
- dmg-bones-stock.csv: the same for the original game (19 and 40): the game has the fault itself.
Made with aoe3-blender-tools' tools/dmg_bones.py (models read by the game's own granny2.dll).
