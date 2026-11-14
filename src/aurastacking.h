// The part of auraStacking that unitResourceAuras uses: its take runs instead of the stock update, so
// the filter of the aura update never sees it.
#pragma once

#include <cstdint>

namespace uhc {

// True if this owner may take from this target now. With <NoStack> on the aura, one carrier holds each
// target; it keeps it while it comes back within a few seconds and is alive. True for any other aura and
// with the key off.
bool AuraClaim(const char* world, std::int32_t proto, std::int32_t name, std::int32_t owner, std::int32_t target,
               std::uint32_t now);

}  // namespace uhc
