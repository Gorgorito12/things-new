Special transforms by button (request #73)
==========================================

What it does
------------
The Zulu youth's four kraal maturings (Askari, Escort, Revolving Cannon, Mountain Gun) and the Greek fishing
boat's fireship become command buttons, like the youth's six other transform buttons. Select the units, press the
button: each selected unit that may transform turns into its maturing unit where it stands, and the maturing unit
spawns the final unit as before. No more clicking on the ground or the sea.

How it works (no DLL needed)
----------------------------
The button runs uiTransformSelectedUnit("<maturing proto>"), the same command as TransformBowmanMaturing. The game
sends it to every machine (network command type 17h) and, for each selected unit on its own:
- checks the maturing proto's own placement rules at the unit's position. So "must be matured near a Gunpowder
  Kraal" still comes from maturinggunpowder.xml (distanceatmostfromtype ... distance="20"), and the Horse Kraal
  rule from maturinghorse.xml: the data stays in one place. The target's AllowedAge is checked too;
- charges the maturing proto's <Cost> (or says "not enough resources");
- creates the maturing unit, built, at the unit's place, and removes the unit.
Tested on 2026-11-20 (see final\): a youth 6 m and 18 m from a Gunpowder Kraal became an Askari maturing, ones 28 m
and 32 m away stayed youths; the same for the Horse Kraal (10 m yes, 28 m no); the cost was charged; a group of
fishing boats transformed together. The click goes through the game's own network command, so it is the same on
every machine (multiplayer itself was not tested).

One data change was needed besides the buttons: the five maturing protos get <Flag>NonCollideable</Flag>, as the
six WOL*Maturing protos already have. Without it the unit that transforms stands on the spot where its maturing unit
should appear, and the game refuses the transform (the button does nothing).

Apply
-----
    python apply_fix.py "<WoL folder>"            (backup in <WoL folder>\special-transforms-backup\)
    python apply_fix.py "<WoL folder>" --key      also adds the DLL key transformChecks to Startup\wol.cfg
    python apply_fix.py "<WoL folder>" --restore
    python apply_fix.py "<WoL folder>" --check

Files changed: data\protoy.xml, data\protounitcommands.xml, data\uhc\customprotounitcommands.xml,
data\stringtabley.xml and translations\_originals\stringtabley.xml (English tooltips 690911..690915: name, cost,
the kraal rule, the unit's description, in the style of WoL's string 76575). Translate them in the other tables.

- AFRICANyouth: the four <Train> rows of AFRICAN*MATURING become <Command> rows in the same columns.
- FishingBoat: the <Train> row of PyrpolikoMaturing becomes a <Command> row. The fishing boat is every civ's, so the
  command has <associatedtech>Age0Greeks</associatedtech>: only a player with the Greeks' start tech sees it (tested:
  another civ's boat shows no button). Not WOLColonializeGreeks, the tech WoL's commented-out entry named: a button
  with an <associatedtech> becomes commandResearch(...), which researches that tech while it is obtainable, so the
  fishing boat could have researched the Greek age-up. The game itself does not check, when the command runs, that
  the target is enabled for the player (from the console, a non-Greek boat still transformed).
- The commented-out TransformPyrpolikon entry named PyrpolikonMATURING, a proto that does not exist (the proto
  is PyrpolikoMaturing); the new entry names the right one.

The optional DLL key: transformChecks
-------------------------------------
What the game does not do, the key adds (UHC.dll, or our dinput8.dll beside WoL's DLL):
- the button greys out when none of the selected units can transform, and its tooltip says why in red: the
  placement rule's own error text ("This unit must be matured near a Gunpowder Kraal."), "Not enough resources", or
  "You are at the build limit for the ...". With a mixed group, the tooltip says how many can ("2 / 3: ...");
- the target's <BuildLimit> is enforced: today six fishing boats pressed together made six PyrpolikoMaturing
  although its limit is 5 (and the sixth fireship never came, since Pyrpolikon's own limit is 5: 150 wood lost).

The AI
------
WoL's AI (AI4\aiWoLMain.xs, read only, not changed) builds AFRICANaskariMATURING, AFRICANescortMATURING,
AFRICANrevolvingcannonMATURING and AFRICANmountaingunMATURING with build plans and an AFRICANyouth as builder, as it
does for AFRICANbowmanMATURING and the others, which are in no unit's <Train> list. So removing the four <Train>
rows should not stop it (to be confirmed in a long Zulu AI game). The AI never builds PyrpolikoMaturing.

Questions for the WoL team
--------------------------
1. Keep the maturing period (the maturing unit that spawns the final unit), or transform straight into the final
   unit? Today the button keeps it; the fireship spawns at once anyway.
2. Build limits: PyrpolikoMaturing has 5 and Pyrpolikon 5; a maturing whose final unit is at its limit spawns
   nothing and its cost is lost. Should the check also count the final unit?
3. A refused unit in a group says nothing in game (only the tooltip, with the key). Do you want a chat message?
