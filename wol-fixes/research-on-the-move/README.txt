RESEARCH ON THE MOVE FOR WARS OF LIBERTY (request #71)
=====================================================

What it does
------------
With the DLL key `researchOnTheMove`, a unit whose proto has the abstract type ResearchOnTheMove takes move,
attack, gather and garrison orders while it has research queued, and its research keeps going at the same speed
while it walks or fights. Without it, such a unit ignores every order until its queue is empty or cancelled (the
research still finishes, but the unit stands where it is).

This pack gives the type to the Mapuche council:
  MapucheWarchief, MapucheWiseWoman, MapucheShaman, MapucheWarrior, MapucheMessenger, MapucheToki
and adds the key to the cfg.

Why a type and not a flag: the game drops a <Flag> it does not know when it reads protoy.xml, but the DLL can add
abstract unit types, so <UnitType>ResearchOnTheMove</UnitType> is what the data uses.

Installing
----------
  python apply_fix.py "<WoL folder>"                       applies it, with a backup in
                                                           <WoL folder>\research-on-the-move-backup
  python apply_fix.py "<WoL folder>" --units A,B,C         the same for other protos instead of the council
  python apply_fix.py "<WoL folder>" --check               says what is applied
  python apply_fix.py "<WoL folder>" --restore             puts everything back

Files it changes:
  data\protoy.xml          <UnitType>ResearchOnTheMove</UnitType> after the last <UnitType> of each unit
  engine-ext\engine-ext.cfg   the line `researchOnTheMove` (our dinput8.dll beside WoL's own uhc.dll, the usual
                           WoL setup; picked when the folder has an engine-ext folder), else Startup\wol.cfg (our
                           UHC.dll in place of WoL's)

Adding it to any unit
---------------------
Add one line to the unit in protoy.xml:

    <UnitType>ResearchOnTheMove</UnitType>

Any unit that researches can have it: the Ethiopian caravans (EGYtowncenterCARAVAN and the others), Bedouin and
Rangatira were tested too (a caravan walked 13 m while it researched). Units with or without ForceBuildingData both
work.

What stays as before
--------------------
- A unit that also has units queued for training stands still until they are trained, as today. Only research is
  freed. Tell us if trainers (Daimyo-like units) should move too.
- Cancelling a research from its queue icon gives the cost back.
- When the unit dies or is knocked out, everything queued is refunded, as today.
- Garrisoned (in a Bunker, a ship...), the research pauses and goes on when the unit comes out, as for anything
  inside a building.
- Only the first research of the queue advances; the next starts when it finishes.
- Saved games keep the queue and its progress.

Every player needs the same key and data (it changes the simulation). Not tested in multiplayer.
