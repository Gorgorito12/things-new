// overhealHitpointBars [UnitType ...] [log]: the HP bars and HP texts of marked units take
// InitialHitpoints as 100 %, not MaxHitpoints.
//
// A unit is created with its proto's InitialHitpoints ([proto+9Ch], 0x498390 in FUN_00498274)
// and is healed up to MaxHitpoints ([proto+98h]); a Hitpoints tech adds the same amount to both
// (0x8F97DD). Every HP display reads the max: the floating bars (0x45FAAF) and the selection
// group bar and 'Group Health' (0x4C5014) take the health ratio FUN_0045F295, HP / max clamped to
// 1; the three HP texts print 'HP/max' with the max from FUN_00480408 (or a copy of it inlined in
// the stat row, 0x4D7575), and '%d/%d (%d+%d)' when that max is above the database proto's
// MaxHitpoints. WoL gives infantry and cavalry MaxHitpoints = 1.1 x InitialHitpoints, so a fresh
// unit shows a 91 % bar and '150/165'.
//
// For a unit whose proto has a marker type (default AbstractOverheal; a stock type or a proto
// name works too, several may be listed) and 1e-6 < InitialHitpoints < MaxHitpoints, the hooks in
// hooks/overheal_hooks.asm replace that max by a reference: InitialHitpoints itself, or
// max x InitialHitpoints / MaxHitpoints when an aura or modifier changed the unit's max (the
// stock rescale 0x9C738B keeps HP / max through such a change, so a full unit stays full). A fresh
// unit then shows a full bar and '150/150', an overhealed one a full bar and '165/150'. The base
// of the '(%d+%d)' split becomes the database proto's InitialHitpoints.
//
// Display only: 0x45F295 and 0x480408 themselves stay stock, so the heal search, transforms,
// modifiers, AI queries and triggers still use the max, and nothing depends on the local player.
// The floating bar is not drawn past 100 %, and the group average stays clamped at 1.
#include <cstdint>
#include <cstring>
#include <set>
#include <string>
#include <string_view>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::size_t kMaxTypes = 8;  // the size of g_uhcOverhealTypes

// Proto names already logged with "log"; only the game thread touches it.
std::set<std::string, std::less<>> g_loggedProtos;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Hook {
  std::uint32_t va;
  std::size_t length;  // the stolen instruction: a call (5) or an fld / mov (6)
  void (*target)();
};

}  // namespace

extern "C" {
// Marker unittype IDs, set on each database load (-1 before); the hooks read the first
// g_uhcOverhealTypeCount of them.
std::int32_t g_uhcOverhealTypes[kMaxTypes] = {-1, -1, -1, -1, -1, -1, -1, -1};
std::int32_t g_uhcOverhealTypeCount = 0;
std::int32_t g_uhcOverhealLog = 0;  // 1 with "overhealHitpointBars ... log"

void UhcOverhealBarHook();
void UhcOverhealGroupHook();
void UhcOverhealPanelMaxHook();
void UhcOverhealStatMaxHook();
void UhcOverhealStatBaseHook();
void UhcOverhealInfoBaseHook();
void UhcOverhealInfoMaxHook();

// Called by the hooks (only with "log") each time a unit's reference differs from its max; logs
// the first such unit of each proto name.
void __stdcall UhcOverhealLogReference(const char* unit, float reference, float maxHp) {
  const char* proto = Field<const char*>(unit, 0x5C);  // not null: the hooks checked it
  const char* name = Field<const char*>(proto, 0x10);
  const std::string_view key = name == nullptr ? "?" : name;
  if (g_loggedProtos.find(key) != g_loggedProtos.end()) {
    return;
  }
  g_loggedProtos.emplace(key);
  uhc::Log(L"overhealHitpointBars: unit %d (%hs) HP %.1f is shown against %.1f instead of its max %.1f "
           L"(InitialHitpoints %.1f, MaxHitpoints %.1f); logged once per proto",
           Field<std::int32_t>(unit, 0x10), key.data(), static_cast<double>(Field<float>(unit, 0x64)),
           static_cast<double>(reference), static_cast<double>(maxHp), static_cast<double>(Field<float>(proto, 0x9C)),
           static_cast<double>(Field<float>(proto, 0x98)));
}
}

namespace uhc {

Outcome ApplyOverhealHitpointBars(const Config& config) {
  const Config::Args* args = config.First("overhealHitpointBars");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }

  std::vector<std::string> typeNames;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (typeNames.size() == kMaxTypes) {
      Log(L"overhealHitpointBars: more than %u unit types (expected: [UnitType ...] [log]); feature not applied",
          static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      typeNames.push_back(arg);
    }
  }
  if (typeNames.empty()) {
    typeNames.push_back("AbstractOverheal");
  }

  if (!VerifyAll("overhealHitpointBars",
                 {&sites::kOverhealBarRatio, &sites::kOverhealGroupRatio, &sites::kOverhealPanelMax,
                  &sites::kOverhealStatMax, &sites::kOverhealStatBase, &sites::kOverhealInfoProto,
                  &sites::kOverhealInfoBase, &sites::kOverhealInfoMax, &sites::kMaxHitpointsGetter,
                  &sites::kHealthRatio, &sites::kInitialHitpointsTag, &sites::kMaxHitpointsTag, &sites::kIsA,
                  &sites::kIsATrue})) {
    return Outcome::kFailed;
  }
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    if (!RequestAbstractUnitType(typeNames[i].c_str(), &g_uhcOverhealTypes[i])) {
      return Outcome::kFailed;
    }
  }
  g_uhcOverhealTypeCount = static_cast<std::int32_t>(typeNames.size());
  g_uhcOverhealLog = log ? 1 : 0;

  // Each hook re-does the stolen instruction with the reference in place of the max, then jumps
  // to the instruction after it.
  const Hook hooks[] = {
      {0x0045FAAF, 5, &UhcOverhealBarHook},       // call 45F295h: the floating bar's fill
      {0x004C5014, 5, &UhcOverhealGroupHook},     // call 45F295h: the selection group's average
      {0x00698B35, 5, &UhcOverhealPanelMaxHook},  // call 480408h: unitHitPointsValue's max
      {0x004D7575, 6, &UhcOverhealStatMaxHook},   // mov eax,[ecx+0B4h]: the stat row's inlined max
      {0x004D7615, 6, &UhcOverhealStatBaseHook},  // fld [eax+98h]: the stat row's base
      {0x009AFA2A, 6, &UhcOverhealInfoBaseHook},  // fld [ecx+98h]: ObjectInfo's base
      {0x009AFA4E, 5, &UhcOverhealInfoMaxHook},   // call 480408h: ObjectInfo's max
  };
  for (const Hook& hook : hooks) {
    if (!WriteJmp(hook.va, reinterpret_cast<const void*>(hook.target), hook.length)) {
      return Outcome::kFailed;
    }
  }

  std::string names;
  for (const std::string& name : typeNames) {
    names += names.empty() ? name : ", " + name;
  }
  Log(L"overhealHitpointBars: HP bars and HP texts of units of unittype %hs take InitialHitpoints as 100 %%%ls "
      L"(display only)",
      names.c_str(), log ? L", the first unit of each proto logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
