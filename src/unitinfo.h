// What other keys know about a unit, as text for the unit panels (minUIStats). Each function reads its key's own
// state and writes nothing; it returns false when its key is not applied or has nothing for the unit.
#pragma once

#include <string>

namespace uhc::unitinfo {

bool Veterancy(const char* unit, std::wstring* out);       // veterancy.cpp: "Rank 2 (5 kills)"
bool Poison(const char* unit, std::wstring* out);          // damageovertime.cpp: "2 stacks, 6 s"
bool RandomCost(const char* unit, std::wstring* out);      // randomcost.cpp: the price ranges of its proto
bool ShipmentCounts(const char* unit, std::wstring* out);  // shipmentcounts.cpp: its owner's cards per age
bool GatherRate(const char* unit, std::wstring* out);      // gatherrate.cpp: "Food 0.67/s"
bool OverhealOn(const char* proto);                         // overheal.cpp: the key is on and marks this proto
// overheal.cpp: the minimized panel's hit points text as that key makes it ("%d/%d" with its max, coloured above
// 100 %); false when the key is off.
bool HitpointsText(const char* unit, std::wstring* out);
// multiarmor.cpp: the proto's armors above 0, the stock one first, as damage type indices and values (at most max);
// 0 when the key is off.
int Armors(const char* proto, unsigned char* types, float* values, int max);

// shots.cpp: an attack's shots before its reload and projectiles a shot as combat fires them: <NumberOfShots> while
// numberOfShots is on, <NumberProjectiles> (or <NumberOfProjectiles>) while it is on with "projectiles" (1 without
// it); false when the key is off or the action has neither tag. asData: the tags as written, whatever the key does
// (a modder's view of the data, not of the game). Keyed by the proto ID [proto+4] and the action's name index
// [action+4], so any player's copy of both finds them. RequestShotTags registers the reader (once, on the shared action
// tag hook, actiontags.h) without any effect on combat, for asData with the key off; numberOfShots registers it too.
// Call it while the keys are applied, before the data loads.
bool RequestShotTags();
bool Shots(const char* proto, const char* action, int* shots, int* projectiles, bool asData = false);

// decimalpop.cpp: K, the factor decimalPopulation stores population quantities with ([proto+0D8h] too); 1 without it.
int PopulationScale();

// Our aura keys, as they act on the unit now (the game's own auras are not told apart: their effect is already in
// the live values). Each returns false when its key is off or nothing of it reaches the unit.
float BuildWorkFactor(const char* worker);                  // bwrauras.cpp: the factor its build-tick call applies
bool WorkAura(const char* unit, std::wstring* out);         // bwrauras.cpp: "+20% work"
bool GatherAura(const char* unit, std::wstring* out);       // gatherauras.cpp: "+20% gold"
bool ResourceAura(const char* unit, std::wstring* out);     // unitresource.cpp: "pays 0.10 <wood>/s", "-0.05 <wood>/s"

}  // namespace uhc::unitinfo
