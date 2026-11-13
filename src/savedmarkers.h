// State that must survive a saved game, kept on the unit itself. A marker is a stat modifier of a stat no code
// reads, with no time limit, created by 0x4DD22D. The modifier's save (slot 5Ch of vtable 0xB97C08, 0x9E3423) and
// load (0x9E355E) copy its fields as raw dwords, so four of them hold a key's words: the value [+68h] and the three
// floats of [+6Ch], which no code reads on these actions. A marker is written in place, and is reused when free,
// so a unit keeps at most as many as it ever needed at once. A transform in place (0x9C754C) ends the unit's
// modifiers, markers too: a key writes its state again at its next change.
//
// Stats: 60h and 61h transformSpan, 62h veterancyBonus, 63h and 64h damageOverTime, 65h overhealDecay, 66h
// researchGrants (two kinds, told apart by word 0), 67h shipmentCounts (per-player state on one carrier unit).
#pragma once

#include <cstdint>

#include "modifiers.h"

namespace uhc::markers {

constexpr std::uint32_t kFree = 0x3F800000;  // word 0 of a free marker: the 1.0f it is created with
constexpr int kWords = 4;

using ModifierFn = std::int32_t(__thiscall*)(char* unit, std::int32_t stat, float value, float, float, std::int32_t,
                                             std::int32_t operation, std::int32_t ms, std::int32_t, std::int32_t,
                                             std::int32_t exclusive);

inline std::uint32_t& Word(char* marker, int word) {
  constexpr std::uint32_t kOffsets[kWords] = {0x68, 0x6C, 0x70, 0x74};
  return *reinterpret_cast<std::uint32_t*>(marker + kOffsets[word]);
}

// Calls visit(marker) for each marker of the stat on the unit; visit returns false to stop.
template <typename Visit>
void ForEach(const char* unit, std::int32_t stat, Visit visit) {
  const char* list = modifiers::ModifierList(unit);
  if (list == nullptr) {
    return;
  }
  auto filter = [&](const char* action) {
    if (*reinterpret_cast<const std::int32_t*>(action + 0x64) != stat) {
      return true;
    }
    return visit(const_cast<char*>(action));
  };
  modifiers::WalkModifiers(list, filter, 0);
}

// The first marker of the stat whose word 0 is that, or nullptr.
inline char* Find(const char* unit, std::int32_t stat, std::uint32_t word0) {
  char* found = nullptr;
  ForEach(unit, stat, [&](char* marker) {
    if (Word(marker, 0) != word0) {
      return true;
    }
    found = marker;
    return false;
  });
  return found;
}

// A free marker of the stat, made if there is none; nullptr for a unit with no action manager. Its words 1 to 3
// are 0.
inline char* Take(char* unit, std::int32_t stat) {
  if (char* marker = Find(unit, stat, kFree)) {
    return marker;
  }
  const auto modifier = reinterpret_cast<ModifierFn>(0x004DD22D);
  if (modifier(unit, stat, 1.0f, -1.0f, -1.0f, 0, 0, 0, -1, -1, 0) == -1) {
    return nullptr;
  }
  return Find(unit, stat, kFree);
}

inline void Free(char* marker) {
  Word(marker, 0) = kFree;
  Word(marker, 1) = 0;
  Word(marker, 2) = 0;
  Word(marker, 3) = 0;
}

}  // namespace uhc::markers
