// pillageGold: a unit of the abstract type AbstractCanPillage steals gold with each hit of an action
// that has <PillageAmount>, normally its BuildingAttack, from the owner of the building it hits.
// CoverBuildingAttack is the same torch in another stance: with no tag of its own it uses BuildingAttack's.
//
// Stock has no such thing. TakeDamage FUN_0049B3D9 calls 0x49BD52 on every hit that has an attacking
// player (0x49B73C), and that call has all the key needs in its frame. The key replaces the call: it
// runs the steal, then the stock function. Only gold, resource 0, and a real transfer: the attacker
// gets what the victim loses, with no gather multiplier. If the victim has less than the amount, the
// hit takes what there is; if it has none, nothing. The victim's stockpile is read before the add
// 0x49A98A, so a victim in debt gives nothing and is never taken below 0. The hook is in
// hooks/pillage_hooks.asm.
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" void UhcPillageHook();

namespace {

constexpr std::uint32_t kHitCall = 0x0049B73C;  // call 0x49BD52 in TakeDamage
constexpr std::int32_t kGold = 0;
constexpr std::int32_t kEnemy = 2;              // [player+1D4h+4*id], as the diplomacy filter 0x49AEE0 reads it
constexpr float kMinAmount = 1.0e-6f;
constexpr std::size_t kGameGlobal = 0xC66234;
constexpr std::size_t kActionNames = 0x1FD8;  // in the database: the action names, then +4 their count
constexpr int kMaxLogLines = 200;

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using ListGetFn = float(__thiscall*)(const char* list, std::int32_t resource);
using PlayerAddFn = bool(__thiscall*)(char* player, std::int32_t resource, float amount, bool flag);

const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kListGet = reinterpret_cast<ListGetFn>(0x0044EFFF);
const auto kPlayerAdd = reinterpret_cast<PlayerAddFn>(0x0049A98A);

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

std::map<ActionKey, float> g_amounts;  // filled while the data loads, read-only after
std::int32_t g_canPillage = -1;
std::int32_t g_building = -1;
std::int32_t g_coverName = -2;     // name indices of the two actions; -2: not looked up yet
std::int32_t g_buildingName = -1;
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

void NewDatabase(char*) {
  g_amounts.clear();
  g_coverName = -2;
  g_buildingName = -1;
  g_logLines = 0;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  if (_wcsicmp(tag.name, L"PillageAmount") != 0) {
    return;
  }
  const float amount = tag.text == nullptr ? 0.0f : std::wcstof(tag.text, nullptr);
  const std::int32_t name = Field<std::int32_t>(tag.action, 0x04);
  if (amount <= kMinAmount || name < 0) {
    uhc::Log(L"pillageGold: proto %hs: <PillageAmount> needs a number above 0, after the action's <Name>; ignored",
             Field<const char*>(tag.proto, 0x10));
    return;
  }
  g_amounts[{Field<std::int32_t>(tag.proto, 0x04), name}] = amount;
  if (g_log) {
    uhc::Log(L"pillageGold: proto %hs, action %d: %g gold a hit", Field<const char*>(tag.proto, 0x10), name,
             static_cast<double>(amount));
  }
}

// The two names, once per database.
void LookUpNames() {
  if (g_coverName != -2) {
    return;
  }
  g_coverName = -1;
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* db = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (db == nullptr) {
    return;
  }
  const auto* names = Field<const wchar_t* const*>(db, kActionNames);
  const std::int32_t count = Field<std::int32_t>(db, kActionNames + 4);
  for (std::int32_t i = 0; i < count; ++i) {
    if (names[i] == nullptr) {
      continue;
    }
    if (_wcsicmp(names[i], L"CoverBuildingAttack") == 0) {
      g_coverName = i;
    } else if (_wcsicmp(names[i], L"BuildingAttack") == 0) {
      g_buildingName = i;
    }
  }
}

}  // namespace

// From the hook, on every hit with an attacking player, before the stock call. The attacker is null
// when it died before its projectile landed.
extern "C" void __stdcall UhcPillageHit(const char* attacker, char* attackerPlayer, const char* action, const char* victim) {
  if (g_amounts.empty() || attacker == nullptr || attackerPlayer == nullptr || action == nullptr) {
    return;
  }
  const char* attackerProto = Field<const char*>(attacker, 0x5C);
  if (attackerProto == nullptr) {
    return;
  }
  const std::int32_t protoId = Field<std::int32_t>(attackerProto, 0x04);
  const std::int32_t actionName = Field<std::int32_t>(action, 0x04);
  auto found = g_amounts.find({protoId, actionName});
  if (found == g_amounts.end()) {
    LookUpNames();
    if (actionName == g_coverName && g_buildingName >= 0) {
      found = g_amounts.find({protoId, g_buildingName});
    }
  }
  if (found == g_amounts.end() || g_canPillage < 0 || !kProtoIsType(attackerProto, g_canPillage)) {
    return;
  }
  const char* victimProto = Field<const char*>(victim, 0x5C);
  char* victimPlayer = Field<char*>(victim, 0x44);
  if (victimProto == nullptr || victimPlayer == nullptr || g_building < 0 || !kProtoIsType(victimProto, g_building)) {
    return;
  }
  const std::int32_t victimId = Field<std::int32_t>(victimPlayer, 0x00);
  if (victimId <= 0 || Field<std::int32_t>(attackerPlayer, 0x1D4 + 4 * victimId) != kEnemy) {
    return;
  }
  const float have = kListGet(victimPlayer + 0x230, kGold);
  const float take = have < found->second ? have : found->second;
  if (take <= kMinAmount) {
    return;
  }
  kPlayerAdd(victimPlayer, kGold, -take, false);
  kPlayerAdd(attackerPlayer, kGold, take, false);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"pillageGold: unit %d of player %d took %g gold from player %d (%hs): %g -> %g, the attacker has %g",
             Field<std::int32_t>(attacker, 0x10), Field<std::int32_t>(attackerPlayer, 0x00), static_cast<double>(take),
             victimId, Field<const char*>(victimProto, 0x10), static_cast<double>(have),
             static_cast<double>(kListGet(victimPlayer + 0x230, kGold)),
             static_cast<double>(kListGet(attackerPlayer + 0x230, kGold)));
  }
}

namespace uhc {

Outcome ApplyPillageGold(const Config& config) {
  const Config::Args* args = config.First("pillageGold");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"pillageGold: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("pillageGold", {&sites::kPillageHitCall, &sites::kPlayerAddResource, &sites::kResListGet}) ||
      !RequestAbstractUnitType("AbstractCanPillage", &g_canPillage) || !RequestAbstractUnitType("Building", &g_building) ||
      !AddActionTagHandler(&ActionTagRead) || !OnDatabaseLoad(&NewDatabase) ||
      !WriteCall(kHitCall, reinterpret_cast<const void*>(&UhcPillageHook))) {
    return Outcome::kFailed;
  }
  Log(L"pillageGold: AbstractCanPillage units steal gold with an action's <PillageAmount>");
  return Outcome::kApplied;
}

}  // namespace uhc
