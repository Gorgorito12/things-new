// The can-research test 0x4C6968, shared by every key that refuses a tech there (shipTechLimit, homeCityTechsInUnits):
// one jmp at its head, whichever of those keys are on.
//
// 0x4C6968 is `bool thiscall(status, unit)`, ret 4: the player's status entry of a tech and the unit that would
// research it (null for some callers, such as the home city's). Every research asks it: the command panel (0x4620C0,
// whose false shows the button greyed or hides it), the research start 0x9E670B (the command's execution, on every
// machine: false refuses the research before its payment), the AI, researchByID and the politician lists.
#pragma once

namespace uhc {

// Asked before the stock test, in the order the keys added them (their kFeatures order). Return true to refuse
// the tech for that unit: the test answers false and the stock checks do not run. Runs often (the panel asks each
// tech button every refresh): keep it cheap for a tech the key does not care about.
using CanResearchFilter = bool (*)(const char* status, const char* unit);

// Writes the hook the first time, after checking the stock bytes of the head.
bool AddCanResearchFilter(const char* feature, CanResearchFilter refuse);

}  // namespace uhc
