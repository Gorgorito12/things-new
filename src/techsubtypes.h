// New subtypes of the tech effect type="Data", on ProtoUnit targets: one hook on the name lookup and
// one on each of the two subtype switches, shared by every key that adds a subtype.
#pragma once

#include <cstdint>

namespace uhc {

// `proto` is the player's copy, `base` the proto it was cloned from. `relativity` and `amount` are the
// effect's. `unapply` is set when the effect is removed.
using TechSubtypeHandler = void (*)(char* proto, const char* base, float amount, std::uint8_t relativity,
                                    bool unapply);

// Makes subtype="<name>" (static text; case ignored) reach `handler`. Writes the hooks the first time,
// after checking the stock bytes.
bool AddTechSubtype(const char* name, TechSubtypeHandler handler);

}  // namespace uhc
