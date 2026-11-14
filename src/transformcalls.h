// The seven calls of the in-place transform 0x9C754C, shared by every key that acts around it. A key
// never writes one of those calls: it adds an observer here, and calls TransformUnit instead of 0x9C754C.
#pragma once

#include <cstdint>

namespace uhc {

// `before` runs ahead of the transform and returns what `after` gets, for the state the transform
// erases, like the unit's modifiers.
struct TransformObserver {
  float (*before)(const char* unit);
  void (*after)(char* unit, float saved);
};

// Writes the calls the first time, after checking the stock bytes.
bool AddTransformObserver(const TransformObserver& observer);

// Takes the call of the TransformUnit effect's apply, 0x7FBC79: `wrapper` runs instead, and has to call
// TransformUnit itself. One key at most.
using TransformEffectWrapper = void (*)(char* unit, std::int32_t proto);
bool SetTransformEffectWrapper(TransformEffectWrapper wrapper);

// Keys that read an attribute of a TransformUnit effect. The first call takes the effect's SetData and Apply
// slots, after checking them. `read` runs when the effect's XML was read and is good; `before` and `after`
// run around each apply. Any of them may be null.
struct TransformEffectReader {
  void (*read)(void* effect, const void* node);
  void (*before)(void* effect);
  void (*after)(void* effect);
};
bool AddTransformEffectReader(const TransformEffectReader& reader);

// 0x9C754C with the observers around it. Every key's own transform goes through here.
std::int32_t TransformUnit(char* unit, std::int32_t proto);

}  // namespace uhc
