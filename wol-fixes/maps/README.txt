Random maps: test results and one fix
=====================================

What was tested
---------------
Every random map in RM4 that has an .xml (208 maps) was generated, loaded and played for 30 seconds of
game time, with 2 players, using WoL's own uhc.dll. A debugger watched every game for crashes.

  ok            208
  crash           0
  hang            0
  script error    0

No crash could be reproduced. If players still report crashes, please ask them for the map, the number
of players, the AIs, and whether the game closed or froze.

Some maps use names the data does not define (a civ, a water type, a cliff or forest type, a proto).
All of them still ran; at worst a map loses an object or falls back to a default:
  NEWBahia (Bandeirante), WOLGibraltar (AURloil, Fishing), WOLsavannah (AURCattle),
  NEWDinarides (rmSetSeaType("x")), ESOC_Wadmalaw (Wadmalaw Water),
  NEWHinduKush, WOLblackforest, WOLvalleyofkings, WOLwetlands, WOLwateringhole (animalPredator, tower),
  dansil_Micronesia (borneo_underbrush), GANWakhan (himalayas_a / himalayas_b),
  ESOC_Parallel Rivers (japan cliffs), WOLsahara (caribbean forest).


The bug: a player name with an accent turns off the map triggers
----------------------------------------------------------------
Affected maps: the 193 maps that call wotta_triggers() (every map except GANWakhan, NEWFerghana,
NEWHinduKush, vividlyKolkata, WOLAlps, WOLeasterisland, WOLEcruteak, WOLIberianPeninsula, WOLsahara,
WOLScandinavia, WOLtuscany, WOLvalleyofkings, WOLwateringhole, WOLwetlands and Yungas).

When it happens: whenever a player's name has a letter outside plain ASCII (á, é, í, ó, ú, ñ, ...) or a
double quote. AI names that do this: Benito Juárez, Ramón Castilla, Simón Bolívar, Bartolomé Mitre,
Francisco Morazán; in the Spanish text also Napoleón III, Víctor Manuel II, Francisco José I, Carlos el
Diplomático and Solano López. A human profile or online name with an accent does it too.

What happens: no crash and no message. The map's triggers are not run at all for the whole game
(culture music, the effectless_tech trigger, the Great War alarm, the Inquisition, espionage, ...).

Cause: RM4\triggers\triggerLoader.xs, lines 62 and 108, puts the name into the trigger text:

    rmSetTriggerEffectParam("Text", rmGetPlayerName(i)+" has entered the Great War Age!");
    rmSetTriggerEffectParam("Text", rmGetPlayerName(i)+" has started the Inquisition!");

The game turns the triggers into a script (My Games\Wars of Liberty\Trigger3\trigtemp.xs) with the
text inside quotes. The XS compiler cannot read a letter above ASCII inside a string ("string not
terminated"), so the whole trigger script fails to compile ("could not compile file 'trigtemp.xs'").
The same happens with an accent typed directly in any XS string.

Checked: Acre, 2 players, against the AI "Benito Juárez": the trigger script failed on exactly that
player's two lines. Against "Otto von Bismarck": no error. "NEW" Levant with 8 players and two AIs with
accented names: it failed on exactly those two players' lines.

The fix (tested): read the name when the trigger runs, as WoL's diplomacy triggers already do with
kbGetPlayerName, instead of writing it into the script.

1. trigger3\wotta triggers.xml: add this effect before </Effects>:

	<Effect name="Overlay Text Player Name">
	  <Param name="PlayerID" dispName="$$22301$$Player" VarType="player">1</Param>
	  <Param name="Text" dispName="$$22531$$Text" VarType="string"> has entered the Great War Age!</Param>
	  <Param name="Duration" dispName="$$22390$$Fade Duration" varType="float">10.0</Param>
	  <Command>trOverlayText(kbGetPlayerName(%PlayerID%)+"%Text%", %Duration%, -1, -1, -1, "None");</Command>
	</Effect>

2. RM4\triggers\triggerLoader.xs: in both places, replace

	rmAddTriggerEffect("Overlay Text");
	rmSetTriggerEffectParam("Text", rmGetPlayerName(i)+" has entered the Great War Age!");

   with

	rmAddTriggerEffect("Overlay Text Player Name");
	rmSetTriggerEffectParamInt("PlayerID", i);
	rmSetTriggerEffectParam("Text", " has entered the Great War Age!");

   (and the same for " has started the Inquisition!"). The Duration lines stay as they are.

With these two changes, Acre against "Benito Juárez" ran with no script error, and the trigger script
now reads trOverlayText(kbGetPlayerName(2)+" has entered the Great War Age!", ...). The message itself
was not seen on screen in the test (it needs a homing pigeon or 15 Inquisitors).

The two changed files are in the folder "fixed", in the same paths as in the mod:
  fixed\trigger3\wotta triggers.xml
  fixed\RM4\triggers\triggerLoader.xs
They are the current WoL files with only the changes above.

triggers\greatwar.xs, line 18, has the same pattern (rmGetPlayerName(i)+" has started a Great War!").
It is not included by triggerLoader.xs today; if it comes back, give it the same change.


Media
-----
None. The bug has nothing to see on screen (no crash, no message: the map's triggers just do not
run), and the fix was checked in the generated trigger script, not in a picture. The sweep's
screenshots only show each map loaded, so they are not included either.
