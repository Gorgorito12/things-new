// lifespanAfterConstruction: a building's <Lifespan> counts from the end of its construction,
// not from the moment its foundation is placed.
//
// Stock arms a unit's lifespan once, when the unit is created: unit init FUN_00498274 calls
// setLifespan 0x48DCB9 with [proto+ACh]. A foundation is created when it is placed, so its
// countdown [[unit+B4h]+1Ch] runs during construction, and with AlphaFadeLifespan so does its
// fade-out timer [[unit+B4h]+88h], whose end kills the unit by itself. Completion
// (FUN_006A1F82) touches neither. For a unit whose proto has a marker unittype (default
// AbstractLifespanAfterConstruction), that is alive (state bit 11 clear) and not fully built,
// two hooks skip the store that advances each timer: both keep their full value until the
// percent reaches 100 %, then run as in stock. A destroyed or deleted foundation is never held,
// so its corpse fades and leaves as in stock. The hooks are in hooks/lifespan_hooks.asm.
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <set>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unitpanel.h"
#include "../unittypes.h"

extern "C" {
std::int32_t g_uhcLifespanType = -1;      // marker unittype ID, set on each database load
std::int32_t g_uhcLifespanLog = 0;        // "lifespanAfterConstruction ... log"
std::int32_t g_uhcLifespanHeldCount = 0;  // logged held units whose countdown has not run again yet

void UhcLifespanTickHook();
void UhcLifespanFadeHook();
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world

using IsBuiltFn = bool(__thiscall*)(const char* unit);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kIsBuilt = reinterpret_cast<IsBuiltFn>(0x0044DDB4);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// The unit panel's row: the seconds left of a marked unit's lifespan, and a held foundation's whole lifespan.
bool __stdcall UhcLifespanRow(const char* panel, const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* record = Field<const char*>(unit, 0xB4);
  if (proto == nullptr || record == nullptr || g_uhcLifespanType < 0 || !kProtoIsType(proto, g_uhcLifespanType)) {
    return false;
  }
  const float left = Field<float>(record, 0x1C);
  if (!(left > 0.0f)) {
    return false;
  }
  wchar_t value[32];
  swprintf_s(value, kIsBuilt(unit) ? L"%.0f s" : L"%.0f s once built", static_cast<double>(left));
  return uhc::SetUnitPanelRow(panel, L"Lifespan", value);
}

const char* MainWorld() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

// Game time in ms, [world+108h].
std::uint32_t GameTime() {
  const char* world = MainWorld();
  return world == nullptr ? 0 : Field<std::uint32_t>(world, 0x108);
}

const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

// The unit's sub-object [unit+B4h] holds the countdown (+1Ch), the fade duration (+84h) and the
// time left before the fade starts (+88h); the stock tick reads it without a null check.
float SubFloat(const char* unit, std::uint32_t offset) { return Field<float>(Field<const char*>(unit, 0xB4), offset); }

// Build percent [[unit+68h]+8], 0..1; a unit without BuildInfo counts as built.
float BuiltPercent(const char* unit) {
  const char* build = Field<const char*>(unit, 0x68);
  return build == nullptr ? 100.0f : Field<float>(build, 0x08) * 100.0f;
}

// State bit 11 of the bitset [unit+4] (bit count [unit+8]): set by the kill handler, so the
// lifespan expiry only removes the corpse.
bool Dying(const char* unit) {
  return Field<std::uint32_t>(unit, 0x08) > 11 && (Field<const std::uint8_t*>(unit, 0x04)[1] & 0x08) != 0;
}

// Unit IDs whose held countdown / fade-out was logged. A countdown leaves g_held when it runs
// again, so each hold and each start is one line.
std::set<std::int32_t> g_held;
std::set<std::int32_t> g_fadeHeld;
const char* g_logWorld = nullptr;
std::uint32_t g_logStep = 0;

void Forget() {
  g_held.clear();
  g_fadeHeld.clear();
  g_uhcLifespanHeldCount = 0;
}

// Unit IDs start again in every game: forget the logged units when another main world runs, or
// when its step count [world+F8h] (raised by 1 per step at 0x481A87) goes back.
void SyncGame() {
  const char* world = MainWorld();
  const std::uint32_t step = world == nullptr ? 0 : Field<std::uint32_t>(world, 0xF8);
  if (world != g_logWorld || step < g_logStep) {
    Forget();
  }
  g_logWorld = world;
  g_logStep = step;
}

// From the database load hook (unittypes.h): the data of another game is being loaded.
void ForgetOnDataLoad(char*) {
  Forget();
  g_logWorld = nullptr;
}

}  // namespace

extern "C" {

// From the tick hook, only with "log": the countdown of a held unit did not advance this step.
void __stdcall UhcLifespanHeld(const char* unit) {
  SyncGame();
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (g_held.insert(id).second) {
    g_uhcLifespanHeldCount = static_cast<std::int32_t>(g_held.size());
    uhc::Log(L"lifespanAfterConstruction: unit %d (%hs) is %.0f %% built; its lifespan (%.2f s left) waits for "
             L"the construction (game time %u ms)",
             id, ProtoName(unit), BuiltPercent(unit), SubFloat(unit, 0x1C), GameTime());
  }
}

// From the tick hook, only with "log" and while g_held is not empty: a countdown runs this step.
// For a unit that was held, logs why it runs again.
void __stdcall UhcLifespanTicking(const char* unit) {
  SyncGame();
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (g_held.erase(id) == 0) {
    return;
  }
  g_uhcLifespanHeldCount = static_cast<std::int32_t>(g_held.size());
  const char* proto = Field<const char*>(unit, 0x5C);
  const wchar_t* why = L"is no longer held; its lifespan runs";
  if (Dying(unit)) {
    why = L"is dying; its lifespan runs as in stock";
  } else if (kIsBuilt(unit)) {
    why = L"is built; its lifespan starts";
  } else if (proto != nullptr && !kProtoIsType(proto, g_uhcLifespanType)) {
    why = L"lost the marker unittype; its lifespan runs";
  }
  uhc::Log(L"lifespanAfterConstruction: unit %d (%hs) %ls with %.2f s left (game time %u ms)", id, ProtoName(unit),
           why, SubFloat(unit, 0x1C), GameTime());
}

// From the fade hook, only with "log": the lifespan fade-out of a held unit did not advance.
void __stdcall UhcLifespanFadeHeld(const char* unit) {
  SyncGame();
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (g_fadeHeld.insert(id).second) {
    uhc::Log(L"lifespanAfterConstruction: unit %d (%hs) is %.0f %% built; its fade-out (due in %.2f s, %.2f s "
             L"long) waits for the construction (game time %u ms)",
             id, ProtoName(unit), BuiltPercent(unit), SubFloat(unit, 0x88), SubFloat(unit, 0x84), GameTime());
  }
}

}  // extern "C"

namespace uhc {

Outcome ApplyLifespanAfterConstruction(const Config& config) {
  const Config::Args* args = config.First("lifespanAfterConstruction");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::string typeName = "AbstractLifespanAfterConstruction";
  bool typeGiven = false;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (!typeGiven) {
      typeName = arg;
      typeGiven = true;
    } else {
      Log(L"lifespanAfterConstruction: unexpected argument %hs (expected: [UnitType] [log]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("lifespanAfterConstruction",
                 {&sites::kLifespanTickHead, &sites::kLifespanTick, &sites::kLifespanTickReturn,
                  &sites::kFadeUpdateHead, &sites::kFadeTimerCommit, &sites::kFadeDispatch,
                  &sites::kFadeOutTimerTest, &sites::kIsBuilt, &sites::kIsBuiltFalse, &sites::kIsA,
                  &sites::kIsATrue})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(typeName.c_str(), &g_uhcLifespanType) ||
      (log && !OnDatabaseLoad(&ForgetOnDataLoad))) {
    return Outcome::kFailed;
  }
  g_uhcLifespanLog = log ? 1 : 0;
  if (!WriteJmp(sites::kLifespanTick.va, reinterpret_cast<const void*>(&UhcLifespanTickHook), 10)) {
    return Outcome::kFailed;
  }
  // The tick hook alone would let an AlphaFadeLifespan foundation fade out and then hold it at
  // 2e-6 s until completion: put the stock bytes back rather than run half the feature.
  if (!WriteJmp(sites::kFadeTimerCommit.va, reinterpret_cast<const void*>(&UhcLifespanFadeHook), 6)) {
    WriteBytes(sites::kLifespanTick.va, sites::kLifespanTick.bytes, 10);
    return Outcome::kFailed;
  }
  if (!AddUnitPanelRow(&UhcLifespanRow)) {
    Log(L"lifespanAfterConstruction: no countdown in the unit panel");
  }
  Log(L"lifespanAfterConstruction: units of unittype %hs keep their Lifespan and its fade-out until their "
      L"construction is finished%ls (multiplayer unverified)",
      typeName.c_str(), log ? L", every hold and start logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
