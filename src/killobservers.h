// Every killing blow of TakeDamage, shared by the keys that act on the killer (veterancyBonus, killSpawn). TakeDamage
// marks the blow that takes a unit from alive to no hit points in [esp+1Fh] (0x4D484B), and the je at 0x49B746 goes to
// its cold kill path 0x4D4F37 for it alone. One jmp is written there, whichever keys are on, and it calls every
// observer before the stock code goes on. A death that does not come from TakeDamage (a lifespan, a delete, a
// trigger's kill) does not come here: deathobservers.h sees those.
#pragma once

#include <cstdint>

namespace uhc {

// `attacker` is the attacking unit, null when it is gone (a shot of a unit that has died since); `attackerPlayer` the
// attacking player object, null without one; `attackerProto` the attacker's proto ID as TakeDamage got it (its
// player's copy through 0x45311B), -1 without one; `victim` the unit killed, still whole: its position, owner and
// proto are as they were at the blow.
using KillObserver = void (*)(char* attacker, char* attackerPlayer, std::int32_t attackerProto, char* victim);

// Writes the jmp the first time (after checking the site's stock bytes) and adds the observer, in the order the keys
// add them (their kFeatures order, the same on every machine).
bool AddKillObserver(KillObserver observer);

}  // namespace uhc
