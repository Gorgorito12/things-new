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

// decimalpop.cpp: K, the factor decimalPopulation stores population quantities with ([proto+0D8h] too); 1 without it.
int PopulationScale();

// Our aura keys, as they act on the unit now (the game's own auras are not told apart: their effect is already in
// the live values). Each returns false when its key is off or nothing of it reaches the unit.
float BuildWorkFactor(const char* worker);                  // bwrauras.cpp: the factor its build-tick call applies
bool WorkAura(const char* unit, std::wstring* out);         // bwrauras.cpp: "+20% work"
bool GatherAura(const char* unit, std::wstring* out);       // gatherauras.cpp: "+20% gold"
bool ResourceAura(const char* unit, std::wstring* out);     // unitresource.cpp: "pays 0.10 <wood>/s", "-0.05 <wood>/s"

}  // namespace uhc::unitinfo
