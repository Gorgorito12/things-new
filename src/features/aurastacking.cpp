// auraStacking: <NoStack> and <ForbidUnitType> on an AutoRangedModify action, for any aura.
//
// In the aura update FUN_009D033E, a unit in range that the action does not hold yet goes through the
// filter 0x9D0238, once (call 0x9D0633), and gets its modifier from 0x4DD22D. The key wraps that call.
//   <ForbidUnitType> refuses a target of the type.
//   <NoStack> refuses a target that holds a modifier of the same aura, from another carrier.
// A modifier does not say which aura made it: [modifier+4] is null on this path, so nothing links it to
// the action. So the key marks it: right after the apply (0x9D0675) it writes the aura's mark in
// [modifier+84h], a field that stock saves and loads and nothing reads (0x9E34E8, 0x9E366C). The mark is
// in the game state, so the key keeps no list, a saved game needs nothing, and every machine sees the
// same thing. A refused target stays out of [action+68h], so each update of each carrier asks again: when
// the holder dies or the target leaves its range, its modifier goes and the next carrier to update takes it.
//
// unitResourceAuras makes no modifier and its take does not go through the filter: AuraClaim holds a
// target per aura for it. That state is not saved, and a load only makes a carrier take the claim again.
//
// The second applier FUN_009D7328, for actions with no range, has no filter and is not covered.
#include "../aurastacking.h"

#include <compare>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifiers.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
void UhcAuraFilterHook();
void UhcAuraAppliedHook();
std::uint32_t g_uhcAuraAppliedNext = 0x009D067A;
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint32_t kModifierMark = 0x84;      // saved, and read by nothing else
constexpr std::uint32_t kClaimExpiryMs = 7000;     // the take comes back at most every few seconds
constexpr std::size_t kMaxClaims = 4096;           // beyond it, the old ones are swept
constexpr int kMaxLogLines = 200;
constexpr int kMaxRefusalLines = 20;               // they repeat at every update

using FilterFn = bool(__thiscall*)(const char* action, const char* target);
using UnitByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);

const auto kFilter = reinterpret_cast<FilterFn>(0x009D0238);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Forbidden {
  std::string name;
  std::int32_t id = -2;  // -2: not looked up yet, -1: unknown
};

struct Aura {
  bool noStack = false;
  std::vector<Forbidden> forbidden;
};

struct Claim {
  std::int32_t owner;
  std::uint32_t time;
};

std::map<ActionKey, Aura> g_auras;  // filled while the data loads, read-only after, but for the IDs
std::unordered_map<std::uint64_t, Claim> g_claims;
const char* g_claimWorld = nullptr;
bool g_on = false;
bool g_log = false;
int g_logLines = 0;
int g_refusalLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// Above 0, so that no field that was never set is a mark.
std::int32_t MarkOf(std::int32_t proto, std::int32_t name) { return ((proto + 1) << 14) | (name & 0x3FFF); }

void NewDatabase(char*) {
  g_auras.clear();
  g_claims.clear();
  g_logLines = 0;
  g_refusalLines = 0;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  const bool noStack = _wcsicmp(tag.name, L"NoStack") == 0;
  const bool forbid = _wcsicmp(tag.name, L"ForbidUnitType") == 0 || _wcsicmp(tag.name, L"ForbidAbstractType") == 0;
  if (!noStack && !forbid) {
    return;
  }
  const std::int32_t name = Field<std::int32_t>(tag.action, 0x04);
  if (name < 0) {
    uhc::Log(L"auraStacking: proto %hs: <%ls> goes after the action's <Name>; ignored",
             Field<const char*>(tag.proto, 0x10), tag.name);
    return;
  }
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  Aura& aura = g_auras[{Field<std::int32_t>(tag.proto, 0x04), name}];
  if (noStack) {
    aura.noStack = text[0] == L'\0' || std::wcstol(text, nullptr, 10) != 0;
  } else {
    Forbidden entry;
    for (const wchar_t* c = text; *c != L'\0'; ++c) {
      entry.name.push_back(static_cast<char>(*c));
    }
    if (entry.name.empty()) {
      uhc::Log(L"auraStacking: proto %hs: an empty <%ls>; ignored", Field<const char*>(tag.proto, 0x10), tag.name);
      return;
    }
    aura.forbidden.push_back(entry);
  }
  if (g_log) {
    uhc::Log(L"auraStacking: proto %hs, action %d: %ls %ls", Field<const char*>(tag.proto, 0x10), name, tag.name, text);
  }
}

// By the table <UnitType> reads, on the first update: every name is known by then.
std::int32_t ForbiddenType(Forbidden& entry) {
  if (entry.id != -2) {
    return entry.id;
  }
  entry.id = -1;
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (database == nullptr) {
    return -1;
  }
  const char* table = database + 0x190;
  std::int32_t id = -1;
  const std::int32_t bucket = kNameBucket(table, entry.name.c_str());
  if (kNameFind(table, entry.name.c_str(), bucket, &id)) {
    entry.id = id;
  } else {
    uhc::Log(L"auraStacking: <ForbidUnitType>%hs names no unit type or proto; ignored", entry.name.c_str());
  }
  return entry.id;
}

// The target holds a modifier with this mark.
bool HoldsMark(const char* target, std::int32_t mark) {
  const char* list = uhc::modifiers::ModifierList(target);
  if (list == nullptr) {
    return false;
  }
  auto different = [mark](const char* modifier) { return Field<std::int32_t>(modifier, kModifierMark) != mark; };
  return uhc::modifiers::WalkModifiers(list, different, 0) == uhc::modifiers::Walk::kStopped;
}

Aura* AuraOf(const char* action, ActionKey* key) {
  const char* tactics = Field<const char*>(action, 0x04);
  const char* owner = Field<const char*>(action, 0x10);
  const char* proto = owner == nullptr ? nullptr : Field<const char*>(owner, 0x5C);
  if (tactics == nullptr || proto == nullptr) {
    return nullptr;
  }
  *key = {Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(tactics, 0x04)};
  const auto found = g_auras.find(*key);
  return found == g_auras.end() ? nullptr : &found->second;
}

void LogRefusal(const char* action, const char* target, const wchar_t* why) {
  if (g_log && g_refusalLines < kMaxRefusalLines) {
    ++g_refusalLines;
    uhc::Log(L"auraStacking: unit %d leaves unit %d alone: %ls", Field<std::int32_t>(Field<const char*>(action, 0x10), 0x10),
             Field<std::int32_t>(target, 0x10), why);
  }
}

}  // namespace

extern "C" {

// Instead of the filter 0x9D0238, at its one call 0x9D0633.
bool __stdcall UhcAuraFilter(const char* action, const char* target) {
  if (!kFilter(action, target)) {
    return false;
  }
  ActionKey key{};
  Aura* aura = AuraOf(action, &key);
  if (aura == nullptr) {
    return true;
  }
  const char* proto = Field<const char*>(target, 0x5C);
  for (Forbidden& entry : aura->forbidden) {
    const std::int32_t type = ForbiddenType(entry);
    if (type >= 0 && proto != nullptr && kProtoIsType(proto, type)) {
      LogRefusal(action, target, L"a forbidden type");
      return false;
    }
  }
  if (aura->noStack && HoldsMark(target, MarkOf(key.proto, key.name))) {
    LogRefusal(action, target, L"it holds this aura");
    return false;
  }
  return true;
}

// After the apply: EAX of 0x4DD22D, the ID of the new modifier.
void __stdcall UhcAuraApplied(const char* action, char* target, std::int32_t modifier) {
  if (modifier == -1) {
    return;
  }
  ActionKey key{};
  const Aura* aura = AuraOf(action, &key);
  if (aura == nullptr || !aura->noStack) {
    return;
  }
  const char* list = uhc::modifiers::ModifierList(target);
  if (list == nullptr) {
    return;
  }
  const std::int32_t mark = MarkOf(key.proto, key.name);
  auto write = [modifier, mark](const char* action2) {
    if (Field<std::int32_t>(action2, 0x08) != modifier) {
      return true;
    }
    *reinterpret_cast<std::int32_t*>(const_cast<char*>(action2) + kModifierMark) = mark;
    return false;
  };
  if (uhc::modifiers::WalkModifiers(list, write, 0) != uhc::modifiers::Walk::kStopped) {
    uhc::Log(L"auraStacking: the modifier %d of unit %d was not found", modifier, Field<std::int32_t>(target, 0x10));
  } else if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"auraStacking: unit %d holds unit %d", Field<std::int32_t>(Field<const char*>(action, 0x10), 0x10),
             Field<std::int32_t>(target, 0x10));
  }
}
}

namespace uhc {

bool AuraClaim(const char* world, std::int32_t proto, std::int32_t name, std::int32_t owner, std::int32_t target,
               std::uint32_t now) {
  if (!g_on) {
    return true;
  }
  const auto aura = g_auras.find({proto, name});
  if (aura == g_auras.end() || !aura->second.noStack) {
    return true;
  }
  if (world != g_claimWorld) {
    g_claimWorld = world;
    g_claims.clear();
  }
  const std::uint64_t id = (static_cast<std::uint64_t>(static_cast<std::uint32_t>(MarkOf(proto, name))) << 32) |
                           static_cast<std::uint32_t>(target);
  if (g_claims.size() > kMaxClaims) {
    std::erase_if(g_claims, [now](const auto& claim) { return now - claim.second.time > kClaimExpiryMs; });
  }
  const auto [claim, isNew] = g_claims.try_emplace(id, Claim{owner, now});
  if (isNew || claim->second.owner == owner) {
    claim->second.time = now;
    return true;
  }
  if (now - claim->second.time <= kClaimExpiryMs && now >= claim->second.time &&
      kUnitById(world, claim->second.owner) != nullptr) {
    return false;
  }
  claim->second = {owner, now};
  return true;
}

Outcome ApplyAuraStacking(const Config& config) {
  const Config::Args* args = config.First("auraStacking");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"auraStacking: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("auraStacking", {&sites::kAuraFilterCall, &sites::kAuraAppliedNext, &sites::kAuraFilter}) ||
      !AddActionTagHandler(&ActionTagRead) || !OnDatabaseLoad(&NewDatabase) ||
      !WriteCall(sites::kAuraFilterCall.va, reinterpret_cast<const void*>(&UhcAuraFilterHook)) ||
      !WriteJmp(sites::kAuraAppliedNext.va, reinterpret_cast<const void*>(&UhcAuraAppliedHook), 5)) {
    return Outcome::kFailed;
  }
  g_on = true;
  Log(L"auraStacking: auras read <NoStack> and <ForbidUnitType> (changes the simulation)");
  return Outcome::kApplied;
}

}  // namespace uhc
