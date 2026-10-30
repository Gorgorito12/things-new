#include "floatingtext.h"

#include "generated/sites.h"
#include "patch.h"

namespace uhc {
namespace {

// Engine layout (docs/engine-symbols.md, "Training near an enemy Town Center").
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +3C0h local player

// The engine's string: one pointer to a wide, reference-counted buffer.
struct BString {
  wchar_t* text;
};

using VisibleToFn = bool(__thiscall*)(const char* unit, std::int32_t playerId);
using ConfigIntFn = bool(__thiscall*)(void* config, std::int32_t id, std::int32_t* out);
using FloatingTextFn = std::int32_t(__thiscall*)(char* manager, const BString* text, std::int32_t time1Ms,
                                                 std::int32_t time2Ms, std::int32_t unitId, const float* motion,
                                                 std::uint32_t colour, float scale, std::int32_t zero,
                                                 std::int32_t minusOne);
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t stringId);
using BStringFreeFn = void(__thiscall*)(BString* self);

const auto kVisibleTo = reinterpret_cast<VisibleToFn>(0x004818F4);
const auto kConfigInt = reinterpret_cast<ConfigIntFn>(0x0046A144);
const auto kFloatingText = reinterpret_cast<FloatingTextFn>(0x008023AE);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
void* const kConfig = reinterpret_cast<void*>(0x00C66500);
// The config variables the dodge's floating text reads for its two times in ms (pointers to their
// IDs, 0x6A257B..0x6A25A6; 2000 and 1000 in game, as the stock caller 0x9C039E passes).
constexpr std::uint32_t kTextTime1 = 0x00CEFFF8;
constexpr std::uint32_t kTextTime2 = 0x00CF0000;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

char* TextManager() {
  const char* world = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x13C);
  return world == nullptr ? nullptr : Field<char*>(world, 0x8A8);
}

}  // namespace

bool VerifyFloatingText(const char* feature) {
  return VerifyAll(feature, {&sites::kDodgeFloatingText, &sites::kFloatingTextAdd, &sites::kUnitVisibleTo,
                             &sites::kConfigInt, &sites::kBStringFromWide, &sites::kBStringFromId,
                             &sites::kBStringFree});
}

std::int32_t LocalPlayer() { return Game() == nullptr ? -1 : Field<std::int32_t>(Game(), 0x3C0); }

bool CanShowUnitText(const char* unit) {
  return unit != nullptr && TextManager() != nullptr && kVisibleTo(unit, LocalPlayer());
}

std::int32_t ShowUnitText(const char* unit, const wchar_t* text, std::int32_t stringId, std::uint32_t colour) {
  if (!CanShowUnitText(unit)) {
    return -1;
  }
  // Three floats. The stock callers pass {0, 0.1, 0}: the second makes the text rise, and in the
  // test bed it left the screen in about 0.3 s. At 0 it stays over the unit for its whole life.
  const float motion[3] = {0.0f, 0.0f, 0.0f};
  std::int32_t time1 = 1000;
  std::int32_t time2 = 2000;
  kConfigInt(kConfig, **reinterpret_cast<const std::int32_t* const*>(kTextTime1), &time1);
  kConfigInt(kConfig, **reinterpret_cast<const std::int32_t* const*>(kTextTime2), &time2);
  BString string;
  if (stringId >= 0) {
    kBStringFromId(&string, stringId);
  } else {
    kBStringFromWide(&string, text);
  }
  const std::int32_t shown =
      kFloatingText(TextManager(), &string, time1, time2, Field<std::int32_t>(unit, 0x10), motion, colour, 1.0f, 0, -1);
  kBStringFree(&string);
  return shown;
}

}  // namespace uhc
