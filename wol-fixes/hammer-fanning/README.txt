Hammer fanning for the European explorers (WoL #111)

    python apply_fix.py <WoL folder>              apply (backups in <WoL folder>\hammer-fanning-backup\)
    python apply_fix.py <WoL folder> --check      say what is applied
    python apply_fix.py <WoL folder> --restore    put everything back as it was

What it does
- The explorers' two pistol abilities, "Hammer Fanning" (PowerRevolverSharpshooter) and "Slip Hammering"
  (PowerRevolverCrackshot), get an animation of their own: the pistol at the hip, held by its grip, the left palm
  sweeping back over the hammer at each of six shots, 0.28 s apart.
- Every shot hits: until now only the first did (the ability's recharge starts with it, and the next Attack tags of
  its animation fired nothing). Each shot goes to the next target when one falls.

What it changes
- art\WoL\units\explorers\europeans\explorer.xml (the Explorer's anim file, used by its 14 models):
  - RangedAttackSharpshoot: the new clip explorer_fanning_attack and its six Attack tags, each with the shot's sound
    and its muzzle flash (the particle set fanningshot, below). It REPLACES the outlaw's clip
    nuggets\outlaw_kidnap\outlaw_pistol_attackA, for the Explorer only: that file stays in the game for anything else
    that uses it.
  - SharpshootIdle (new): explorer.tactics names it for the two attacks, but it was never defined. It is never seen
    in game: a power's attack ends with its animation and the unit goes back to its normal idle (seen 2026-11-26).
    It is kept, harmless, for a tactics change that would play it.
  - ReloadSharpshoot is not changed.
- art\effects\particlesets_wol.xml: the particle set fanningshot is added before </particlesetdef>: the stock
  musketshot's four musket particles, drawn on the bone Prop2. musketshot draws them on R Hand, so with the new clip
  the flash showed at the hand, beside the grip (JTMaston, 2026-11-26). The new clips key Bip01 Prop2 (a bone of the
  left hand that every explorer model has, with nothing skinned to it or hung on it in these animations) on the
  pistol's muzzle, so the flash leaves the barrel's tip. In game (British and Danish Explorers, both abilities): every
  flash starts ahead of the muzzle on the line of the shot, never at the hand (c1-ingame-flash.jpg).
- art\WoL\units\explorers\europeans\fanning\ (new): the two clips and their tag files (.gr2.precomp).
- data\protoy.xml: the Explorer's ProtoActions SharpshooterAttack and CrackshotAttack get
  <RetargetInAction>1</RetargetInAction> and <PowerShots>6</PowerShots>. They go in the ProtoActions, not in
  explorer.tactics, which ten other units share.
- Startup\wol.cfg: the two DLL keys, unless the file has them already:
      retargetInAction
      powerShots
  Both need the UHC.dll that has them; without the keys the tags do nothing and each use fires one shot again.

Made with aoe3-blender-tools' tools/make_fanning.py (the clips, their tag files, the anim blocks), and checked with
its tools/check_anim.py (0 failures): the grip in the palm, the left palm on the hammer at each shot, the forearms
clear of the body, the feet planted, the loop of the idle, and the flash's bone on the muzzle at each Particles tag
(0.0 cm on the 11 WoL explorer models; the Danish and Swedish models have the same bone chains).

Balance: every shot does the action's full damage (750 for Hammer Fanning, 1000 for Slip Hammering), so a use can
now deal six times that. See reply-to-maston-20261127-H.txt for the questions.

Evidence of the tests: a0-findings.txt, a1-results.txt, a0-traces.txt, a0-uhc-log.txt and the videos in this folder;
the guide's sections powerShots and retargetInAction.
