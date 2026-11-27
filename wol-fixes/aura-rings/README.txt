Aura rings from the Indian aura (requests #92/#93 round, 2026-11-22)
=====================================================================

What it is
- The aura rings of tools\rings drawn with the game's own ring instead: the ring Karni Mata puts around the Indian
  villagers (effects\ypack_auras\aura_econ), its texture recoloured in each ring colour (shape and alpha kept), and
  for each colour a copy of its mesh at each ring size, naming its own texture. No <replacetexture>: that fell back
  to the stock green and gold whenever a Town Center was in the scene; here a Town Center changes nothing (tested).
- Private: the files derive from the game's art, so they are not in the public release. tools\rings stays the
  public set (flat particle rings drawn from scratch).
- These rings are the defaults. A civ with an aura model of its own (a unique attachment) keeps it; these serve
  every case with nothing of more personality.

Colours (the same names and paths as tools\rings, so data does not change)
  ring_wood      dark copper   gathering wood
  ring_food      red           gathering food
  ring_gold      orange-gold   gathering gold
  ring_work      cyan          work rate: builds, trains or researches faster
  ring_export    lime          export (Trade)
  ring_xp        violet        experience
  ring_oil       black         oil (Fame)
  ring_damage    magenta       damage
  ring_rof       lemon         rate of fire
  ring_hp        rose          maximum hit points
  ring_heal      white         healing over time
  ring_speed     blue          speed
Anti-rings, for an aura whose effect is negative: the same colour with teeth pointing inward from the band:
  ring_damage_neg, ring_rof_neg, ring_hp_neg, ring_heal_neg, ring_speed_neg
  e.g. <modelattachment>effects\uhc_rings\ring_damage_neg.xml</modelattachment>
The markers aura_<name>.xml (gold, wood, food, hunt, berry, farm, fish, export, xp, oil, work) use these rings
with tools\rings' floating icons.

Sizes: 2.2 m on a unit (the size the rings already had; the stock Karni Mata ring is 2.8 m), 4.6 m on cavalry and
artillery, 9 m on a House, 16 m on another building, 20 m on a Town Center. The mesh lies 0.5 m over the unit's
feet, as the stock ring does, so a building hides the part of its ring behind it.

Install
1. Copy tools\rings\* to <Wars of Liberty>\art\effects\uhc_rings\ (the icons, the range rings and the rest).
2. Copy files\art\effects\uhc_rings\* over it (it replaces ring_*.xml and aura_*.xml and adds auraring_*).
Uninstall: copy tools\rings\* again (the auraring_* files can stay; nothing names them then).

Rebuild
  aoe3-blender-tools, from a game copy (its art is only read; its granny2.dll uncompresses the mesh):
  venv\Scripts\python -I tools\make_aura_rings.py --game <copy> --out files\art\effects\uhc_rings --folder uhc_rings --compress
  (--anti teeth is the default; dash and hatch are the other variants that were reviewed.)

Tested in WoL (2026-11-22, copy 6): every ring in its colour with a Town Center in the scene, on infantry, cavalry,
a Town Center, a Barracks and a House; the two anti-rings on infantry; the markers on a Sawmill's auras.
Videos: docs\media\auraRings-pack-wol.mp4 (with the pack), -units, and -control (tools\rings, no pack).
