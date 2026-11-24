// incomeRates: what a key's own payment to a player adds to that player's income rate. The key counts the game's
// income at the add 0x49A98A by its callers (the gather tick, unit AutoGather, the global trickle); a key that pays
// a player through the same add from the DLL (unitResourceAuras, resourceBounty / killBountyTechs, pillageGold)
// calls this after the add, with the same player, resource and amount. Nothing when the key is off, for an amount
// of 0 or less, or out of range.
#pragma once

#include <cstdint>

namespace uhc {

void CountIncome(const char* player, std::int32_t resource, float amount);

}  // namespace uhc
