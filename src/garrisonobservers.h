// Every unit that enters another (a building's garrison, a ship, a wagon), shared by the keys that act on it
// (garrisonConvert, nurseryFactor). The load of a unit into another, FUN_009C24B5 bool thiscall(container, unitId,
// flag), ret 8, has eleven direct callers (the garrison and load actions, triggers, the random map placement, the
// scenario load); one jmp at its success tail 0x9C26E1, whichever keys are on, runs every observer there.
#pragma once

namespace uhc {

// Called once per successful entry, inside the load: [unit+6Ch] is already the container's ID and the unit is the
// last ID of [container+70h] (count [container+74h]). The load has not returned yet, and its caller may still read
// the unit: an observer must not transform, kill, eject or move it there. It queues the unit's ID and acts after
// the world update (worldtick.h), checking again that the unit is still inside.
using GarrisonObserver = void (*)(char* container, char* unit);

// Writes the jmp the first time (after checking the site's stock bytes and the function's head) and adds the
// observer, in the order the keys add them (their kFeatures order, the same on every machine). `key` names the
// caller in the log.
bool AddGarrisonObserver(GarrisonObserver observer, const char* key);

}  // namespace uhc
