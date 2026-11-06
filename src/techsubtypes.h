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

// The same for a subtype on a proto's action: the effect takes action="<Action>" or allactions="1", as
// stock's TrackRating and Damage do. `action` is the player's copy, once for each action the effect
// names, and `baseAction` the action of that name in the base proto, or nullptr if it has none. `proto`
// is the player's copy of the proto ([proto+4] its ID). A proto without the action is left alone.
using TechActionSubtypeHandler = void (*)(char* action, const char* baseAction, const char* proto, float amount,
                                          std::uint8_t relativity, bool unapply);
bool AddTechActionSubtype(const char* name, TechActionSubtypeHandler handler);

// Called for a Data subtype that neither stock nor a key knows, while the data loads, for dataLint. Writes the hooks too.
using UnknownTechSubtype = void (*)(const char* name);
bool OnUnknownTechSubtype(UnknownTechSubtype callback);

}  // namespace uhc
