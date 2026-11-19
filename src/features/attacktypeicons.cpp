// attackTypeIcons: a bonus multiplier against an abstract type the panels have no icon for shows in the attack rows.
//
//   attackTypeIcons <UnitType> <StringID> <IconPath> [<UnitType> <StringID> <IconPath> ...]
//
// The attack rows list a DamageBonus only when its type is one of the stock chain's types with an icon (the stat
// panel fill 0x4D7E86.. and its cold part, the minimized block 0x699A95..); any other type is skipped, so an
// Escopetero's "1.5x against AbstractRangedCavalry" is not shown at all. With the key, a listed type gets its row
// part as the stock types do: ", 1.50x <icon>" with the icon at IconPath (a texture path, as ui\ingame\stat_icon_cavalry),
// and the rollover line "1.50X Bonus Damage against <StringID's text> (<icon>)".
// Hooks (hooks/attacktypeicons_hooks.asm) at the chain's test of type +11h, after every stock type but +11h and +54h:
// 0x69B909 (fill, icons "(16)") and 0x699D31 (minimized block, "(10)"). A listed type there writes the icon into the
// row's icon BString through the BString format 0x444EFB and joins the stock path with its string ID (0x4D7F44,
// 0x699DE6); any other type re-executes the test and goes on.
#include <cstdint>
#include <cstdlib>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
void UhcTypeIconStatHook();  // hooks/attacktypeicons_hooks.asm
void UhcTypeIconMinHook();
}

namespace {

struct BString {
  wchar_t* text;
};

using BStringFormatFn = void(__cdecl*)(BString* out, const wchar_t* format, ...);
const auto kBStringFormat = reinterpret_cast<BStringFormatFn>(0x00444EFB);

struct TypeIcon {
  std::string name;
  std::int32_t stringId = -1;
  std::wstring path;
  std::int32_t id = -1;  // the unittype ID, set on each database load (unittypes.h)
};

std::vector<TypeIcon>* g_icons = nullptr;  // never freed: read by the hooks until the process ends
bool g_logged = false;

}  // namespace

extern "C" {

// From the hooks: the icon of `type` into `out` at `size` and its string ID, or -1 for a type the key does not list.
std::int32_t __stdcall UhcAttackTypeIcon(std::int32_t type, BString* out, std::int32_t size) {
  if (g_icons == nullptr || out == nullptr) {
    return -1;
  }
  for (const TypeIcon& icon : *g_icons) {
    if (icon.id >= 0 && icon.id == type) {
      kBStringFormat(out, L"<icon=\"(%d)(%s)\">", size, icon.path.c_str());
      if (!g_logged) {
        g_logged = true;
        uhc::Log(L"attackTypeIcons: first multiplier against %hs shown", icon.name.c_str());
      }
      return icon.stringId;
    }
  }
  return -1;
}

}  // extern "C"

namespace uhc {

Outcome ApplyAttackTypeIcons(const Config& config) {
  const Config::Args* args = config.First("attackTypeIcons");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (args->empty() || args->size() % 3 != 0) {
    Log(L"attackTypeIcons: expected triples <UnitType> <StringID> <IconPath>, got %zu values; feature not applied",
        args->size());
    return Outcome::kFailed;
  }
  auto* icons = new std::vector<TypeIcon>();
  for (size_t i = 0; i + 2 < args->size(); i += 3) {
    char* end = nullptr;
    const long id = std::strtol((*args)[i + 1].c_str(), &end, 10);
    if (end == (*args)[i + 1].c_str() || *end != '\0' || id < 0) {
      Log(L"attackTypeIcons: %hs: string ID %hs is not a number; feature not applied", (*args)[i].c_str(),
          (*args)[i + 1].c_str());
      delete icons;
      return Outcome::kFailed;
    }
    const std::string& path = (*args)[i + 2];
    icons->push_back({(*args)[i], static_cast<std::int32_t>(id), std::wstring(path.begin(), path.end())});
  }
  if (!VerifyAll("attackTypeIcons", {&sites::kTypeIconStatChain, &sites::kTypeIconStatFound, &sites::kTypeIconMinChain,
                                     &sites::kTypeIconMinFound, &sites::kBStringFormat})) {
    delete icons;
    return Outcome::kFailed;
  }
  for (TypeIcon& icon : *icons) {
    if (!RequestAbstractUnitType(icon.name.c_str(), &icon.id)) {
      delete icons;
      return Outcome::kFailed;
    }
  }
  g_icons = icons;  // the vector does not move again: the IDs above are written into it on each database load
  if (!WriteJmp(sites::kTypeIconStatChain.va, reinterpret_cast<const void*>(&UhcTypeIconStatHook), 5) ||
      !WriteJmp(sites::kTypeIconMinChain.va, reinterpret_cast<const void*>(&UhcTypeIconMinHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"attackTypeIcons: %zu unit types get an icon in the attack rows' bonus multipliers", icons->size());
  return Outcome::kApplied;
}

}  // namespace uhc
