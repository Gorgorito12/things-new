// Every death of a unit, shared by the keys that act on it (detonationDeath, annexFacing). The kill queue's
// drain 0x493D46 calls the kill handler 0x4B4F70 for each unit asked to die (TakeDamage, a lifespan, a delete, a
// trigger's kill and the rest ask 0x4B4DC2), from a single call, 0x493D8F. One call is written there, whichever
// keys are on, and it runs every observer before the stock handler.
#pragma once

#include <cstdint>

namespace uhc {

// Called with the unit and the handler's three flags, before the stock handler, while the unit is whole. The
// handler returns at once for a unit whose state bit 11 is set, so an observer that needs a real death checks it.
// A kill asked from an observer joins the queue, and the drain reads its count again: the unit dies in the same
// drain, after this one, with no recursion.
using DeathObserver = void (*)(char* unit, std::uint32_t a, std::uint32_t b, std::uint32_t c);

// Writes the call the first time (after checking the site's stock bytes) and adds the observer, in the order the
// keys add them (their kFeatures order, the same on every machine).
bool AddDeathObserver(DeathObserver observer);

// The trigger effect Destroy (the syscall trUnitDestroy, 0x98282F) removes each selected unit at once through
// the world's unit removal 0x4726B2(id, 0, 1), from its single call 0x9828E7, and never reaches the kill queue.
// An observer added here is called there, with the flags 0 0 0, before the removal and only for a unit that is
// alive and not dead (state bit 11 clear). It is a separate list: a key that should act on Destroy adds its
// observer to both. The removal's 62 other callers (a corpse's end, a transform's old unit, a game's end, the
// editor) are not observed.
bool AddDestroyObserver(DeathObserver observer);

}  // namespace uhc
