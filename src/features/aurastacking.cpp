// auraStacking: <ForbidUnitType> on an AutoRangedModify action, for any aura.
//
// In the aura update FUN_009D033E, a unit in range that the action does not hold yet goes through the
// filter 0x9D0238, once (call 0x9D0633), and gets its modifier from 0x4DD22D. The key wraps that call:
// <ForbidUnitType> (or <ForbidAbstractType>) refuses a target of the type. A refused target stays out of
// [action+68h], so each update asks again, and a target that changes type is judged again.
//
// That several carriers of one aura do not multiply is the stock tag <ModifyExclusive>: action flag 21h,
// passed to 0x4DD22D and kept as the modifier's state bit 16h, after which the stat sum 0x4B3C7D stops. The
// key's old <NoStack> did the same and is retired: it is logged and ignored.
//
// unitResourceAuras makes no modifier and its take does not go through the filter: AuraClaim gives each
// target one payer per aura when the aura has <ModifyExclusive>, with this key on or off. That state is not
// saved, and a load only makes a carrier take the claim again.
//
// The second applier FUN_009D7328, for actions with no range, has no filter and is not covered.
#include "../aurastacking.h"

#include <compare>
#include <cstdint>
#include <cwchar>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
void UhcAuraFilterHook();
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint32_t kActionModifyExclusive = 0x21;  // <ModifyExclusive>: bit of the flag set [action+64h]
constexpr std::uint32_t kClaimExpiryMs = 7000;     // the take comes back at most every few seconds
constexpr std::size_t kMaxClaims = 4096;           // beyond it, the old ones are swept
constexpr int kMaxRefusalLines = 20;               // they repeat at every update
constexpr int kMaxRetiredLines = 20;

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
  std::vector<Forbidden> forbidden;
};

struct Claim {
  std::int32_t owner;
  std::uint32_t time;
};

std::map<ActionKey, Aura> g_auras;  // filled while the data loads, read-only after, but for the IDs
std::unordered_map<std::uint64_t, Claim> g_claims;
const char* g_claimWorld = nullptr;
bool g_log = false;
int g_refusalLines = 0;
int g_retiredLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// A bitset {bytes at +0, bit count at +4} at `offset` in an object.
bool Bit(const char* object, std::uint32_t offset, std::uint32_t bit) {
  if (Field<std::uint32_t>(object, offset + 4) <= bit) {
    return false;
  }
  const auto* bytes = Field<const std::uint8_t*>(object, offset);
  return bytes != nullptr && (bytes[bit >> 3] & (1u << (bit & 7))) != 0;
}

void NewDatabase(char*) {
  g_auras.clear();
  g_claims.clear();
  g_refusalLines = 0;
  g_retiredLines = 0;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  if (_wcsicmp(tag.name, L"NoStack") == 0) {
    if (g_retiredLines < kMaxRetiredLines) {
      ++g_retiredLines;
      uhc::Log(L"auraStacking: proto %hs: <NoStack> is retired, use <ModifyExclusive>1</ModifyExclusive>; ignored",
               Field<const char*>(tag.proto, 0x10));
    }
    return;
  }
  if (_wcsicmp(tag.name, L"ForbidUnitType") != 0 && _wcsicmp(tag.name, L"ForbidAbstractType") != 0) {
    return;
  }
  const std::int32_t name = Field<std::int32_t>(tag.action, 0x04);
  if (name < 0) {
    uhc::Log(L"auraStacking: proto %hs: <%ls> goes after the action's <Name>; ignored",
             Field<const char*>(tag.proto, 0x10), tag.name);
    return;
  }
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  Forbidden entry;
  for (const wchar_t* c = text; *c != L'\0'; ++c) {
    entry.name.push_back(static_cast<char>(*c));
  }
  if (entry.name.empty()) {
    uhc::Log(L"auraStacking: proto %hs: an empty <%ls>; ignored", Field<const char*>(tag.proto, 0x10), tag.name);
    return;
  }
  g_auras[{Field<std::int32_t>(tag.proto, 0x04), name}].forbidden.push_back(entry);
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

Aura* AuraOf(const char* action) {
  const char* tactics = Field<const char*>(action, 0x04);
  const char* owner = Field<const char*>(action, 0x10);
  const char* proto = owner == nullptr ? nullptr : Field<const char*>(owner, 0x5C);
  if (tactics == nullptr || proto == nullptr) {
    return nullptr;
  }
  const auto found = g_auras.find({Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(tactics, 0x04)});
  return found == g_auras.end() ? nullptr : &found->second;
}

}  // namespace

extern "C" {

// Instead of the filter 0x9D0238, at its one call 0x9D0633.
bool __stdcall UhcAuraFilter(const char* action, const char* target) {
  if (!kFilter(action, target)) {
    return false;
  }
  Aura* aura = AuraOf(action);
  if (aura == nullptr) {
    return true;
  }
  const char* proto = Field<const char*>(target, 0x5C);
  for (Forbidden& entry : aura->forbidden) {
    const std::int32_t type = ForbiddenType(entry);
    if (type >= 0 && proto != nullptr && kProtoIsType(proto, type)) {
      if (g_log && g_refusalLines < kMaxRefusalLines) {
        ++g_refusalLines;
        uhc::Log(L"auraStacking: unit %d leaves unit %d alone: a forbidden type (%hs)",
                 Field<std::int32_t>(Field<const char*>(action, 0x10), 0x10), Field<std::int32_t>(target, 0x10),
                 entry.name.c_str());
      }
      return false;
    }
  }
  return true;
}
}

namespace uhc {

bool AuraClaim(const char* world, const char* tactics, std::int32_t proto, std::int32_t owner, std::int32_t target,
               std::uint32_t now) {
  if (tactics == nullptr || !Bit(tactics, 0x64, kActionModifyExclusive)) {
    return true;
  }
  if (world != g_claimWorld) {
    g_claimWorld = world;
    g_claims.clear();
  }
  const std::int32_t name = Field<std::int32_t>(tactics, 0x04);
  // Above 0 for every proto, so that the key never holds a zero.
  const auto aura = static_cast<std::uint32_t>(((proto + 1) << 14) | (name & 0x3FFF));
  const std::uint64_t id = (static_cast<std::uint64_t>(aura) << 32) | static_cast<std::uint32_t>(target);
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
    if (g_log && g_refusalLines < kMaxRefusalLines) {
      ++g_refusalLines;
      uhc::Log(L"auraStacking: unit %d leaves unit %d to unit %d: <ModifyExclusive>", owner, target, claim->second.owner);
    }
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
  if (!VerifyAll("auraStacking", {&sites::kAuraFilterCall, &sites::kAuraFilter}) ||
      !AddActionTagHandler(&ActionTagRead) || !OnDatabaseLoad(&NewDatabase) ||
      !WriteCall(sites::kAuraFilterCall.va, reinterpret_cast<const void*>(&UhcAuraFilterHook))) {
    return Outcome::kFailed;
  }
  Log(L"auraStacking: auras read <ForbidUnitType> and <ForbidAbstractType> (changes the simulation); <NoStack> is "
      L"retired, <ModifyExclusive> does it");
  return Outcome::kApplied;
}

}  // namespace uhc
