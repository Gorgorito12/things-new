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

}  // namespace uhc::unitinfo
