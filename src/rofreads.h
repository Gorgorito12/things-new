// The five reads of an attack's tactics ROF [action+34h] that set its wait or its animation rate, shared by every
// key that changes an attack's interval (containedUnitsROF, numberOfShots): one jmp per site, whichever of those
// keys are on (hooks/rofreads_hooks.asm).
#pragma once

#include <cstdint>

namespace uhc {

enum class RofRead : std::int32_t {
  kNoShotA = 0,     // 0x48A821: the attack update, after an attack that did not fire
  kNoShotB = 1,     // 0x48A99A: the same, its other branch
  kNoShotC = 2,     // 0x48EA0C: the attack step, the same case
  kAfterShot = 3,   // 0x48F8B5: after a shot (ranged and melee); [unitAction+68h] already counts it
  kAttackStart = 4  // 0x4A1189: an attack cycle begins ([unitAction+78h] = now) and sets its animation rate
};

// Gets the attack's unit action ([+4] its tactics action, [+10h] its unit), the value so far in ms (above 0) and
// the read; returns the value to use (at least 1). Filters run in the order the keys added them, each on the
// previous one's result.
using RofFilter = std::int32_t(__stdcall*)(const char* unitAction, std::int32_t rof, RofRead read);

// Writes the five hooks the first time (after checking the sites' stock bytes) and adds filter. A filter only
// runs while some key has set its gate (SetRofGate); with every gate at 0 the hooks only re-do the stock code.
bool AddRofFilter(RofFilter filter, const char* feature);

// Each key keeps one gate: true when its data has something to change (a table entry, a tag).
void SetRofGate(RofFilter filter, bool on);

}  // namespace uhc
