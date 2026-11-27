The zamburak cannon (request: JTMaston, 2026-11-26)
==================================================

ENGLISH
-------

What it is
- Wars of Liberty's MEZamburak gets a new model and animations.
- The model: the zamburak's camel without its lateral swivel gun. On its withers sits a bronze cannon on a swivel:
  the midfa's barrel cut to 2/3 of its length, at 0.6 of its size. The rider is today's zamburak rider (his model
  and hat by rank, as today). The camel has a dromedary hump under its saddle cloth (the stock camel's back was
  flat), and the rider sits on it.
- One unit with two modes, as the stock field guns (data\tactics\zamburakCannon.tactics):
  - Limber (as trained): it walks, trots and runs with the gun angled down beside the camel's neck, the rider's
    left hand on its cascabel. It cannot fire. An attack order unlimbers it first.
  - Unlimber (6.67 s): the camel lies down, kneeling with its belly on the ground and its legs folded under it,
    and turns its neck aside. The artillerist draws his linstock from its
    holster, swings the gun out over the camel's right side (+90, square to its spine), gets off on the left and
    stands at his station behind the breech.
  - Bombard: it cannot move. To fire (2.0 s) he touches the vent with the hot red tip of his linstock, a short
    plain stick, at 0.70 s. The fuse burns on the vent with sparks and a thread of smoke while he takes the
    stick away and turns his head aside, and the gun fires at 1.40 s. The muzzle jumps 15 degrees and the
    kneeling camel rocks 4 degrees away from the shot; both settle before the reload.
    To reload (3.0 s) he sticks the linstock in the ground and pushes the gun round through its back until the
    muzzle points at him. He loads the charge and the ball by hand from the pouch at his hip, showing the ball
    over the muzzle before he pushes it in. Then he pushes the gun back to its rest and takes the linstock up.
    The kneeling camel is alive meanwhile: it breathes and sways its tail, pins its ears back and flicks its
    tail at the shot, and in the reload chews its cud, flicks its ears and turns its head to watch the gun.
  - Limber (5.5 s): he swings the gun back to its travel pose, puts the linstock in its holster, gets on, and the
    camel rises.
  - Deaths: unlimbered, the camel slumps and he falls back. Limbered, three of today's camel deaths play on a model
    with the cannon built in. The other five drove the cannon into the ground and are not played.
- With the turretArc key, the gun turns on its swivel from +30 to +150 to a target inside that arc; he stays at his
  station and reaches the turned vent. A target outside the arc turns the camel until it sits at +90. Without the
  key the camel turns its right side to the target.
- That turn (2026-11-27, the DLL of that day or later): the camel rises with its rump high (15 degrees), turns on the
  spot in big unhurried steps (both diagonal pairs once every 60 degrees, each hoof lifted 22 cm, the planted hooves
  never sliding) and kneels again; the artillerist turns to face his way, walks round beside it, hands on his hips,
  and takes his station again. 0.45 s up, 90 degrees a second, 0.45 s down: 1.9 s for 90 degrees, 2.9 s for 180.
  It does not fire until it has knelt again. An older DLL turns it at once, lying.
- Made with aoe3-blender-tools tools/make_zamburak.py (models, clips, every file checked by the game's
  granny2.dll). Every clip passed its check_anim.py:
  - the new clips: 0 failures of 1222 checks;
  - the unlimbered death: 0 of 80;
  - the limbered deaths: 0 of 179.
  Those checks include palms not behind the shoulders, the camel's head and neck clear of the barrel, crossed
  feet, the weapon not into the ground at death, prop sizes against the man, and the camel lying in the kush.

A PROPOSAL FOR WARS OF LIBERTY'S TEAM: the ROF
- The pack sets MEZamburak's CannonAttack ROF from 4.0 to 5.0. That is the fire (2.0 s) and the reload (3.0 s) as
  animated.
- Keep 4.0 instead and the game cuts the reload short. Tell us the number you want and we fit the reload to it.

Files it adds
  art\WoL\units\cavalry_ranged\zamburak_cannon\
      zamburak_cannon_camel.gr2        the zamburak's camel without its swivel gun; bone_turret on its withers
                                       carries the launch point and the muzzle
      zamburak_cannon_gun.gr2          the cannon, its swivel and fork, the linstock (bone_match: its tip), the
                                       charge and the ball
      zamburak_cannon_camel_dead.gr2   the camel with the cannon (limbered) built in: the limbered deaths
      zamburak_cannon_camel_*.gr2, _gun_*.gr2, _rider_*.gr2   the clips of the camel, the cannon and the rider
      zamburak_cannon_camel_*.gr2.precomp   the tag files of the camel's clips (ATTACHPOINT, HEAD, ...)
      zamburak_cannon.aim              the turretArc key's aim table (version 2: rest +90, +30..+150 every 2
                                       degrees; the artillerist's arm and head for the idle and the shot; the
                                       turn beyond the arc, TURN and RISE)
      zamburak_cannon.xml (+ _gun, _rider)   the anim files
      fuse_sparks.particle, fuse_smoke.particle   the burning fuse on the vent: the game's grenadier's fuse
                                       sparks and smoke (effects\spc\fusesparks, fusesmoke) timed to the shot
  data\tactics\zamburakCannon.tactics  the two modes; the attack carries
                                       <turret tracking="always" maxTurnAnglePerSecond="100">60</turret>, read by
                                       the turretArc key and ignored by the game
File it changes
  data\protoy.xml                      MEZamburak: <AnimFile>, <Tactics>, CannonAttack <ROF> 4.0 -> 5.0
The current files (art\WoL\units\cavalry_ranged\zamburak\, zamburakME.tactics) are not touched; ypZamburak and
ypZamburakMansabdar are not changed.

Install
    python apply_fix.py "<Wars of Liberty folder>"              (a manifest and a backup in
                                                                 <folder>\zamburak-backup)
    python apply_fix.py "<Wars of Liberty folder>" --check      (what is applied)
    python apply_fix.py "<Wars of Liberty folder>" --restore    (everything back as it was, byte for byte)
A folder under steamapps is refused unless --force is given.

The turning gun: the turretArc key of the DLL, one line in engine-ext\engine-ext.cfg (our dinput8.dll beside WoL's
own uhc.dll, the usual WoL setup), or in Startup\wol.cfg only if our UHC.dll is used in place of WoL's (the pack does
not edit the cfg)
    turretArc MEZamburak art\WoL\units\cavalry_ranged\zamburak_cannon\zamburak_cannon.aim
Version 2 of the aim file needs the DLL of 2026-11-26 or later. With the gatling camel pack too:
    turretArc GatlingCamel ...A55.aim GatlingCamelDeployed ...B55.aim MEZamburak ...zamburak_cannon.aim

Known limits
- The camel's rank skins (Veteran, Guard, Imperial) are not carried over: every rank shows the basic camel. The
  rider keeps his rank models and hats.
- Today's rider carried a carbine on his back in some anims (dragoon_gun); the new anims do not show it.

Also changed in MEZamburak (apply_fix.py): <Flag>RotateInPlace</Flag> (so it turns in place when unlimbered, as the
gatling camel and the falconet do), and the unlimber and limber buttons (Tactic4 and Tactic3 on page 9, as the
falconet has them).

TESTED (2026-11-26, a test copy of Wars of Liberty, single player, the DLL of 2026-11-26)
- Two zamburaks against Houses all round, filmed close and checked frame by frame:
  - the unlimber from the button;
  - shots logged with the gun turned from 60 to 140 degrees, the artillerist's stick on the turned vent;
  - targets at 14 to 29 degrees turning the camel until they sat in the arc;
  - the reload's swing;
  - the limber from the button;
  - both deaths: the corpse with the cannon on it fades with no part left in the air, and the stick lies beside
    him when he dies unlimbered.
  - The same scene filmed with the key off as the control.
  - Again with the hump and the kneeling camel: drawn and shaded as the stock camel beside it; from a side camera
    the limbered barrel points 20 degrees down beside the neck and the unlimbered one is level.
- Fixed in the course of the test:
  - the humped camel edited in the game's packed vertex format was not drawn at all; it is written in the plain
    skinned format of the game's other unit meshes;
  - the rider was missing (his anim file was cut inside an attachment);
  - the cannon stood in the air while an unlimbered corpse faded (now a dead model of its own);
  - apply_fix.py writes the tactics with CRLF whatever the checkout gave (with LF the AI would stop compiling).
- The turn beyond the arc (2026-11-27, approved by the user as a script, a stop-0 sketch and three previews;
  check_anim.py 0 failures for turns of 60, 75, 90 and 180 degrees each way; in game, WoLReal4, the new DLL, single
  player): Houses created and destroyed round it every 20 s, 12 turns of 90 and 180 degrees: the rise, the steps, his
  walk and the settling seen frame by frame, no shot during a turn (logged), and killed mid-turn. Only the aim file
  changed (TURN and RISE appended; every byte before them as before).
- The shot, round 3 (2026-11-26, JTMaston: a slower fuse, more recoil, fuse sparks on the vent; approved by the
  user as a preview; check_anim.py 0 failures; in game, WoLReal8, the DLL of 2026-11-26, single player): the
  sparks seen on the vent from the touch to the shot with the gun at 35 to 150 degrees, off in the reload; the
  first shot 1.40 s after the gun is laid; ROF 5.0 measured (5.00 s between shots); the shot's smoke and flash
  at the muzzle at every yaw (before, they burst at a fixed spot ahead of the camel: the shot's tag file lacked
  LAUNCHPOINT); the ball seen over the muzzle; the camel's tail and head moving.
- Not tested: an attack order (right click) unlimbering it. The bed could not aim a real click; the tactics are the
  stock pattern (GatlingCamel, falconet). Also not tested: multiplayer, and the AI with the pack.
