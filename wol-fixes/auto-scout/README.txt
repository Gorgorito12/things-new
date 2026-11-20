AUTO SCOUT FOR WARS OF LIBERTY (request #68)
=============================================

What it does
------------
With the DLL key `autoScout`, a unit explores the map on its own, as DE's envoys do. It flies, walks or sails
to the nearest ground its player has not explored yet that it can stand on (land for land units, water for
ships, anything for flyers), then on to the next. Once the whole map is explored, it keeps going to the
ground that was seen longest ago. Any move, attack, gather, garrison or Stop order from its owner switches it
off, and it stays where it is.

It keeps away from danger (since 2026-11-20):
  - Enemy buildings that shoot (Town Centers, outposts, towers, forts...): once the player has seen one, the scout
    no longer picks ground within its range plus 12 m, and prefers ground it can reach without crossing that circle.
  - When a scout is hit, it marks the area around its attacker (the nearest enemy that can attack, within 40 m) as
    dangerous for 2 minutes, gives up its current target and moves 24 m away from the attacker, then goes on
    scouting elsewhere. It stays in AutoScout. If the game's own flee or fight has already taken over (a tactic with
    <runaway>1</runaway> flees), that is left alone, and the scout goes on once it is idle.

This pack sets it up in WoL's data:
  - the Romanian raven (WOLraven), the two pet parrots (PetMacaw, PetGreyParrot) and the French balloon
    (WoLHotAirBalloonFrench) scout from birth, and get a "Stop scouting" and a "Start scouting" button;
  - the raven no longer has a WanderDistance;
  - the Dutch envoy (Envoy) gets the two buttons, and starts with scouting off;
  - the European explorers (Explorer, used by the European civs, and WOLcartographer, used by the Greeks, Serbians,
    Bulgarians and Romanians) get the two buttons, and start with scouting off. Their scouting tactic is a copy of
    their "Volley" tactic that attacks nothing on its own, does not answer an attack and runs away when hit, so that
    the explorer scouts instead of fighting; their Stop button puts them back in "Volley" (they have no "Normal").

Why the raven only flew in circles: it is not the animal wander. The raven belongs to no herd, so the game's
animal wander never runs for it. The game walks every unit with no orders back to the place it was last
ordered to when it strays too far (the "leash"). An idle raven drifts, is walked back, drifts again: a circle.
With the key, its moves are marked so the leash leaves them alone, and its leash point follows it.

Measured on Great Lakes, Romanians against a German AI, the rest of the player idle, share of the map
explored:
                      3 minutes   6 minutes
  two stock ravens       9.4 %       9.7 %
  two auto-scout ravens 63.7 %     100   %
  the envoy alone       50.1 %      71.1 %   (scenario, same map)

Installing
----------
  python apply_fix.py "<WoL folder>"             applies it, with a backup in <WoL folder>\auto-scout-backup
  python apply_fix.py "<WoL folder>" --check     says what is applied
  python apply_fix.py "<WoL folder>" --restore   puts everything back

It adds the line `autoScout` to Startup\wol.cfg when the file has none. The key comes with our UHC.dll, or with
our dinput8.dll beside WoL's own DLL (in that case the line goes in engine-ext\engine-ext.cfg instead).

Files it changes or adds:
  data\tactics\wolautoscoutflyer.tactics          new: the raven's tactics, "AutoScout" first, "Normal" second
  data\tactics\wolenvoyautoscout.tactics          new: the envoy's tactics, "Normal" first, "AutoScout" second
  data\tactics\wolexplorerautoscout.tactics       new: made from your explorer.tactics when the pack is applied,
                                                  "AutoScout" right after "Volley"
  data\protoy.xml                                 the seven units: their <Tactics>, two <Command> lines each,
                                                  the raven's <WanderDistance> removed
  data\protounitcommands.xml                      the buttons AutoScoutStart, AutoScoutStop and
                                                  AutoScoutStopExplorer
  data\uhc\customprotounitcommands.xml            the three command names
  data\stringtabley.xml and
  translations\_originals\stringtabley.xml        the two tooltips in English (IDs 690901, 690902)
  art\ui\command\uhc_autoscout_start.ddt
  art\ui\command\uhc_autoscout_stop.ddt          new: the button icons (64x64, WoL's button frame)

The other translations get no tooltip text: add 690901 and 690902 to them.

Adding the mechanic to any unit
-------------------------------
1. In the unit's tactics file, add a tactic named AutoScout. Copy the unit's Normal tactic and rename it. Keep
   the name and the first child on one line, and keep the file's Windows line endings:

       <tactic>AutoScout<action>Move</action>
           ...the same lines as its Normal tactic...
       </tactic>

   - Put it FIRST in the file if the unit should scout from birth (the game starts every unit in its first
     tactic).
   - Put it after Normal if the player should switch it on with a button.
   If several units share the tactics file, give the unit its own copy of the file, or all of them will
   scout.

2. Give the unit the buttons, on the command row (page 10). The game does not show these buttons on the
   tactics page (page 9):

       <Command column="4" page="10">AutoScoutStart</Command>
       <Command column="5" page="10">AutoScoutStop</Command>

   Use free columns. The buttons themselves are defined once, in protounitcommands.xml, and their names are
   listed in data\uhc\customprotounitcommands.xml (this pack does both). The Stop button runs
   unitSetTactic("Normal"), so it needs a tactic named Normal.

3. Ships work too, if their tactics file gets the tactic. A caravel was tested on Great Lakes: it scouted the
   lake and stayed on water.

The key
-------
  autoScout [ScoutTactic [ReturnTactic]] [noAvoid] [noBack] [log]

  ScoutTactic    the tactic name that means "scouting" (default AutoScout)
  ReturnTactic   the tactic an order puts the unit back in (default: the first tactic of its file that is
                 not the scouting one)
  noAvoid        do not keep away from enemy buildings that shoot
  noBack         do not back off when hit
  log            writes each order to the log (UHC.log or engine-ext.log), each enemy building seen, each hit and
                 back-off

Good to know
------------
- The scouting tactic and everything the key does are game state: every player of a game needs the same DLL
  and data. Multiplayer has not been tested.
- A saved game keeps the units' tactics, so a loaded game goes on scouting.
- A scout that cannot reach a place (an island, a cliff) gives it up and goes elsewhere.
- A scout that is attacked flees as usual (or backs off on its own), and goes back to scouting when it is idle
  again, away from where it was hit.
- A scout can still be shot before it sees the building that shoots it: an outpost's range can be longer than a
  scout's line of sight. The back-off then takes it away, and the building is avoided from then on.
- A scout that is AI-controlled scouts too; the AI's own orders switch it off.
