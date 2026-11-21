// The part of auraStacking that unitResourceAuras uses: its take runs instead of the stock update, so
// the filter of the aura update never sees it.
#pragma once

#include <cstdint>

namespace uhc {

// True if this owner may take from this target now. tactics is the aura's action (the player's copy of the
// tactics action, flags at [+64h], name at [+4]), proto the carrier's proto ID. With <ModifyExclusive> on the
// aura, one carrier holds each target, as the stock stat sum counts one exclusive modifier; it keeps it while it
// comes back within a few seconds and is alive. True for any other aura. It does not depend on the auraStacking
// key: <ModifyExclusive> is a stock tag.
bool AuraClaim(const char* world, const char* tactics, std::int32_t proto, std::int32_t owner, std::int32_t target,
               std::uint32_t now);

}  // namespace uhc
