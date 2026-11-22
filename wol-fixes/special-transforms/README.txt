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

The dance (2026-11-21)
----------------------
The kraal maturings' anim files (art\War of the Triple Alliance\Buildingsets\Delta\Discovery\maturing\
maturing2.xml, maturing3.xml, maturing4.xml) choose what to show by build progress (<logic type="BuildingCompletion">):
from 1 % to 99 % built, the youth dancing (lvl1..lvl6: the youth model, generic_dance2, the youngzuluchant sound,
fire and light particles; the Askari's youth holds a rifle, the Escort's plays natives\priest\heal2); at 100 %,
"finished", which has only the soil decal. A placed maturing dances while the youth builds it. A transform creates the
maturing unit already built, so it showed "finished" from the first moment: no dancer, no chant. That is why the
dance was missing in our first video.

What we found when we tested it (2026-11-21): in these four protos the final unit does not wait for a maturing
period. Their action (AFRICANaskari, AFRICANescort, ... in data\tactics\AFRICANmaturing.tactics) is a single-use
Spawn, which fires as soon as the maturing unit is complete. In the placed route the youth dances while it builds
(5 s for the Askari, 7 for the Escort, 8 and 20 for the cannons), the unit comes out when the building completes, and
the soil decal stays on the ground for the rest of <Lifespan> (20 to 50 s). With a transform the maturing unit is
complete from the start, so the unit comes out at once and there was nothing left to dance during.

apply_fix.py now gives the "finished" stage of those three files the dancer of the last construction stage (lvl6:
model, dance or heal2, chant, rifle, shockwave), without its Death anim (your own button maturings in
art\WoL\units\maturing\maturing.xml have theirs commented out: the maturing dies when its lifespan ends, and a
youth falling dead then would look wrong). The decal stays. What it looks like (final\15-*.jpg and the video): the
Askari comes out at once, and the youth dances beside it on the maturing ground until the lifespan ends (20 s for
the Askari maturing), then fades out with the decal. The files keep their CRLF line endings, and the originals go to
the backup like the other files (--restore puts them back).
- maturing.xml (the ten other AFRICAN*MATURING protos) is not changed: no button makes those; your six transform
  buttons make WOL*Maturing units, whose maturing.xml dances already.
- maturing4.xml is also the anim file of WOLAfricanUhlanMaturing (the Uhlan maturing the youth places after the home
  city card WOLHCMiscigenation). It now dances too after its construction, beside the new Uhlan, until its lifespan
  ends (tested, final\16-*.jpg).
- A placed maturing (the AI still places these four with build plans) looks the same while it is built; after it
  is built, the youth now keeps dancing beside the new unit until the lifespan ends (before: the empty decal).

Apply
-----
    python apply_fix.py "<WoL folder>"            (backup in <WoL folder>\special-transforms-backup\)
    python apply_fix.py "<WoL folder>" --key      also adds the DLL key transformChecks to Startup\wol.cfg
    python apply_fix.py "<WoL folder>" --keep-train   keeps the youth's four <Train> rows too (see "The AI")
    python apply_fix.py "<WoL folder>" --restore
    python apply_fix.py "<WoL folder>" --check

Files changed: data\protoy.xml, data\protounitcommands.xml, data\uhc\customprotounitcommands.xml,
data\stringtabley.xml and translations\_originals\stringtabley.xml (English tooltips 690911..690915: name, cost,
the kraal rule, the unit's description, in the style of WoL's string 76575). Translate them in the other tables.
The kraal rule line ends with "(within a range of 20)", the distance of the placement rule (2026-11-22, your
feedback: the game has no unit for distances; it said "(within 20 m)" before). A folder where an older version of the
pack is applied keeps the old text: run --restore, then apply again. The pictures in final\ that show the tooltip
(2, 3, 7, 9, 12) were taken again with the new text; picture 8 (beside WoL's DLL) was removed.
Also the three anim files of "The dance" above (art\War of the Triple Alliance\...\maturing\maturing2.xml to 4).

- AFRICANyouth: the four <Train> rows of AFRICAN*MATURING become <Command> rows in the same columns (with
  --keep-train the <Train> rows stay too).
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
  placement rule's own error text ("This unit must be matured near a Gunpowder Kraal.") or "You are at the build
  limit for the ...". With a mixed group, the tooltip says how many can ("2 / 3: ...");
- not enough resources (2026-11-21, your feedback): when the cost is the only reason, the button stays enabled and
  the tooltip ends with "Not enough resources" in red; a click shows the game's own message and sound, the one a
  Train button gives ("55 food, 70 gold required to build another Askari.", "150 wood required to build another
  Pyrpoliko."). When the placement or the build limit fails too, the button stays grey with that reason, since
  resources would not help. A group of three youths without resources gave one message, not three (final\11-*.jpg).
  The fireship button (a command with an <associatedtech>) needed one more step: its click runs the command as a
  one-shot "research" of the boat, and a failed one removed the button from that boat; in that case the key makes
  the click the transform command itself, so the message shows and the button stays;
- the target's <BuildLimit> is enforced: today six fishing boats pressed together made six PyrpolikoMaturing
  although its limit is 5 (and the sixth fireship never came, since Pyrpolikon's own limit is 5: 150 wood lost).

The AI
------
WoL's AI (AI4\aiWoLMain.xs, read only, not changed) builds AFRICANaskariMATURING, AFRICANescortMATURING,
AFRICANrevolvingcannonMATURING and AFRICANmountaingunMATURING with build plans (createSimpleBuildPlan) and an
AFRICANyouth as builder. Our first README said removing the four <Train> rows should not stop it, because
AFRICANbowmanMATURING is in no unit's <Train> list; that was wrong: a tech adds it (AddTrain). Tested on 2026-11-21 with
a trigger's build order (Unit Build Building, the path a unit takes to build): with the pack, the youth refused to
build the Askari and Escort maturings; with the rows kept, it built them. So with the pack as it is, a Zulu AI
probably cannot make Askaris, Escorts or the two cannons any more (not confirmed in a long Zulu AI game).
  python apply_fix.py "<WoL folder>" --keep-train   keeps the youth's four <Train> rows beside the new buttons. The
AI can build again, but the player then sees both buttons for each maturing: the placing one and the transforming
one. We tried to hide the rows on another page: every page shows (page 9 under "Tactics", page 20 under "Improve").
A skirmish with the pack and a German AI (wolOtto) played with no XS error (see "Tested" below). The AI never builds
PyrpolikoMaturing.

Questions for the WoL team
--------------------------
1. The dance after a transform: the final unit comes out at once (Spawn), so today the youth dances beside the new
   unit for the maturing unit's whole lifespan (20 s Askari, 30 s Escort, 40 s Revolving Cannon, 50 s Mountain Gun),
   and the placed maturings (the AI's, the Uhlan) now do the same after they are built. Is that what you want, or
   should the dance last only a part of it? Or should the unit wait until the dance ends, as in the placed route?
   That needs a data change: a delay before the Spawn (or a Maintain, as your WOL*Maturing units use), which would
   also delay the AI's placed maturings unless the buttons get their own maturing protos.
2. Build limits: PyrpolikoMaturing has 5 and Pyrpolikon 5; a maturing whose final unit is at its limit spawns
   nothing and its cost is lost. Should the check also count the final unit?
3. A refused unit in a group says nothing in game (only the tooltip, with the key). Do you want a chat message?
4. The AI (see above): keep the four <Train> rows (--keep-train: the AI builds, the player sees two buttons), or remove
   them (the default: one button, but a Zulu AI cannot build these four)? A third way would be a key of ours that
   hides those placing buttons from the human player only; tell us if you want it.
