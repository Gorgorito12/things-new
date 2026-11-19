// Great War Triggers
// Imported for false Age6

// include "triggers\africanexplorer.xs";
// include "triggers\aussies.xs";
include "triggers\culture_music.xs";
//include "triggers\greatwar.xs";
//include "triggers\traits.xs";

void wotta_triggers(void)
{
// aussies();
//traits();
// africanexplorer();
culture_music();
//greatwar();

/*rmCreateTrigger("TrigDebug");
rmSwitchToTrigger(rmTriggerID("TrigDebug"));

rmSetTriggerActive(true);
rmAddTriggerEffect("Send Chat");
rmSetTriggerEffectParamInt("PlayerID", 0);
rmSetTriggerEffectParam("Message", "Trigger Debug; Status: Working.");*/

// The effectless tech trigger ensures that some tech conditions are re-evaluated constantly.

rmCreateTrigger("effectless_tech");
rmSwitchToTrigger(rmTriggerID("effectless_tech"));

rmSetTriggerActive(true);
rmSetTriggerLoop(true);

rmAddTriggerCondition("Timer ms");
rmSetTriggerConditionParamInt("param1", 1250);

rmAddTriggerEffect("Set Tech Status by Name");
rmSetTriggerEffectParamInt("PlayerID", 0);
rmSetTriggerEffectParam("Tech", "NoEffect");

// A few alternate victory conditions.

for (i=1;<cNumberPlayers){
	rmCreateTrigger("espionage"+i);
	
	// GreatWarAlarm: 1 homing pigeon

	rmCreateTrigger("GWAlarm"+i);

	rmSwitchToTrigger(rmTriggerID("GWAlarm"+i));
	rmSetTriggerActive(true);
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID", i);
	rmSetTriggerConditionParam("ProtoUnit", "gwHomingPigeon");
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamInt("Count", 1);
	// rmAddTriggerEffect("Music Filename"); 
	// rmSetTriggerEffectParam("Music", "Wotta\Music\Modes\GreatWar.mp3"); //Music
	rmAddTriggerEffect("Sound Filename");
	rmSetTriggerEffectParam("Sound", "Wotta\StrategyWarning.wav"); //Age-Up Sound
	rmAddTriggerEffect("Overlay Text Player Name");
	rmSetTriggerEffectParamInt("PlayerID", i);
	rmSetTriggerEffectParam("Text", " has entered the Great War Age!");
	rmSetTriggerEffectParamFloat("Duration", 10.0);
	rmAddTriggerEffect("Set Lighting");
	rmSetTriggerEffectParam("SetName", "st_petersburg");
    rmSetTriggerEffectParamInt("FadeTime", 180);

    // Espionage Alarm: Own 15 or more Spies.
    
	rmSwitchToTrigger(rmTriggerID("espionage"+i));
	rmSetTriggerActive(true);
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID", i);
	rmSetTriggerConditionParam("ProtoUnit", "xpSpy");
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamInt("Count", 15);
	rmAddTriggerEffect("Music Filename"); 
	rmSetTriggerEffectParam("Music", "Wotta\Music\Modes\TheWatch.mp3"); //Music
	rmAddTriggerEffect("Sound Filename");
	rmSetTriggerEffectParam("Sound", "Wotta\StrategyWarning.wav"); //Age-Up Sound

    // Religious Alarm: Own 15 or more priests.

	rmCreateTrigger("religiousalarm"+i);

	rmSwitchToTrigger(rmTriggerID("religiousalarm"+i));
	rmSetTriggerActive(true);
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID", i);
	rmSetTriggerConditionParam("ProtoUnit", "Priest");
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamInt("Count", 15);
	rmAddTriggerEffect("Music Filename"); 
	rmSetTriggerEffectParam("Music", "Wotta\Music\Modes\Gregorian.mp3"); //Music
	rmAddTriggerEffect("Sound Filename");
	rmSetTriggerEffectParam("Sound", "Wotta\StrategyWarning.wav"); //Age-Up Sound

    // Religious Victory: Own 15 or more Inquisitors
    
	rmCreateTrigger("religiousvictory"+i);

	rmSwitchToTrigger(rmTriggerID("religiousvictory"+i));
	rmSetTriggerActive(true);
	rmAddTriggerCondition("Player Unit Count");
	rmSetTriggerConditionParamInt("PlayerID", i);
	rmSetTriggerConditionParam("ProtoUnit", "Inquisitor");
	rmAddTriggerEffect("Overlay Text Player Name");
	rmSetTriggerEffectParamInt("PlayerID", i);
	rmSetTriggerEffectParam("Text", " has started the Inquisition!");
	rmSetTriggerEffectParamFloat("Duration", 10.0);
	rmSetTriggerConditionParam("Op", ">=");
	rmSetTriggerConditionParamInt("Count", 15);
	rmAddTriggerEffect("Set Lighting");
	rmSetTriggerEffectParam("SetName", "310b_brunswickdestroyed");
        rmSetTriggerEffectParamInt("FadeTime", 60);
	rmAddTriggerEffect("Music Filename"); 
	rmSetTriggerEffectParam("Music", "Wotta\Music\Modes\DeathTheme.mp3"); //Music
	rmAddTriggerEffect("Sound Filename");
	rmSetTriggerEffectParam("Sound", "Wotta\StrategyWarning.wav"); //Age-Up Sound



}
}