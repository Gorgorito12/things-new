// One wrapper around the world update FUN_00481A57 (thiscall(world, int, deltaMs), ret 8), shared
// by every key that needs a per-step tick (damageOverTime, overhealDecay): a single jmp at its
// entry, whichever of those keys are on.
#pragma once

#include <cstdint>

namespace uhc {

// Called after each stock world update with the world and the update's deltaMs, in the order the
// keys added them (their kFeatures order, the same on every machine).
using WorldTick = void (*)(char* world, std::int32_t deltaMs);

// Writes the wrapper's jmp the first time (after checking the site's stock bytes) and adds tick.
bool AddWorldTick(WorldTick tick);

}  // namespace uhc
