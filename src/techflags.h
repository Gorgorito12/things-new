// New <Flag> names of a <Tech> in the techtree: one hook on the head of the flag reader FUN_00620C2F
// (cdecl(record, name), called once per <Flag> at 0x620C23), shared by every key that reads a flag of its own
// (hcTargetTechs' HCTargetEnemy / HCTargetAll, quickArrivalCards' QuickArrival). Stock ignores a name it does not know.
#pragma once

namespace uhc {

// `record` is the tech's template record ([[loader+4]+0Ch] + 24h * id: [record+0] its definition, whose +0 is the
// tech ID); `name` the flag's text. Returns true when the key took the flag: stock then does not read it.
using TechFlagHandler = bool (*)(char* record, const char* name);

// Asks `handler` about every <Flag> of every tech, in the order the keys added them, before stock reads it. Writes
// the hook the first time, after checking the stock bytes of the reader's head.
bool AddTechFlagHandler(const char* feature, TechFlagHandler handler);

}  // namespace uhc
