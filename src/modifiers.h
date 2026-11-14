// Stat modifiers on units, read-only (docs/engine-symbols.md, "Snare and group movement"). A
// modifier is a unit action of type 2Ch in the unit's action lists, created by 0x4DD22D ->
// 0x4B3D9E (snares, auras, powers) or by the tactics-driven class 0xB97C78, which carries the same
// type: stat [+64h], value [+68h], operation [+78h] (0 set, 1 add, 2 multiply), flags
// {[+30h] bytes, [+34h] count}. Shared by snareOnlyHitUnit and buildingWorkRateAuras.
#pragma once

#include <cstdint>

namespace uhc::modifiers {

constexpr std::uint8_t kModifierAction = 0x2C;  // unit action type of a stat modifier (0x4B3D9E)
constexpr int kMaxDepth = 16;                   // nested actions; a deeper tree is not walked

enum class Walk { kDone, kStopped, kTooDeep };

namespace detail {

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

}  // namespace detail

// Calls visit(action) for each modifier action in an action list {count +0, data +8} and, depth
// first, in each action's children ([action+40h]): the order of the stock collector
// 0x49F1A0 / 0x49F34B. visit returns false to stop the walk.
template <typename Visit>
Walk WalkModifiers(const char* list, Visit& visit, int depth) {
  if (depth > kMaxDepth) {
    return Walk::kTooDeep;
  }
  const std::int32_t count = detail::Field<std::int32_t>(list, 0);
  const char* const* actions = detail::Field<const char* const*>(list, 8);
  for (std::int32_t i = 0; i < count; ++i) {
    const char* action = actions[i];
    if (action == nullptr) {
      continue;
    }
    if (detail::Field<std::uint8_t>(action, 0x60) == kModifierAction && !visit(action)) {
      return Walk::kStopped;
    }
    const Walk inner = WalkModifiers(action + 0x40, visit, depth + 1);
    if (inner != Walk::kDone) {
      return inner;
    }
  }
  return Walk::kDone;
}

// The unit's modifier actions: the list at [actionManager+14h], as FUN_0049F1BA collects them.
inline const char* ModifierList(const char* unit) {
  const char* manager = detail::Field<const char*>(unit, 0x58);
  return manager == nullptr ? nullptr : manager + 0x14;
}

}  // namespace uhc::modifiers
