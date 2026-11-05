// killBountyTechs: a tech effect type="Data" subtype="KillBounty" (or "Bounty") changes a proto's
// <Bounty>, the XP its killer gets. teamKillBounty: that XP goes to the killer's whole team when the
// victim's proto has the abstract type TeamKillBounty.
//
// Stock keeps the tag in the proto's [+168h]. The value function 0x4D4DC5 reads it from the victim's
// proto, the copy of the victim's owner, at the kill. No Data subtype reaches the field, so the effect
// is a new one (techsubtypes.h), applied through the stock value function 0x7F892A, which gives it
// every relativity and its removal.
//
// The kill reaches FUN_0049BD52 (killer's player), which calls the team's XP routine 0x49BDC0 with the
// killer's ID. That routine pays every member the whole amount when the ID is below 0, so the hook
// passes -1 for a marked victim.
//
// resourceBounty: <Bounty resourcetype="Gold">N</Bounty> pays that resource at the kill. The stock handler
// 0x5F5D79 ignores the attribute and takes the number as XP. A tag cannot be registered twice, so the key
// changes the handler the builder registers, which keeps the stock one for a <Bounty> without the
// attribute. The payment is a hook on the kill branch of TakeDamage (0x4D4E0C), which runs for any bounty
// or none. A TeamKillBounty victim pays the team here too. The hooks are in hooks/bounty_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

extern "C" void UhcTeamBountyHook();
extern "C" void UhcResourceBountyHook();

namespace {

constexpr std::size_t kBounty = 0x168;
constexpr std::size_t kUnitProto = 0x5C;
constexpr int kMaxLogLines = 200;

using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
using ResourceByNameFn = std::int32_t(__thiscall*)(void* context, const char* name);
const auto kResourceByName = reinterpret_cast<ResourceByNameFn>(0x0044709C);
using PlayerAddFn = bool(__thiscall*)(char* player, std::int32_t resource, float amount, bool flag);
const auto kPlayerAdd = reinterpret_cast<PlayerAddFn>(0x0049A98A);
using PlayerByIdFn = char*(__thiscall*)(char* world, std::int32_t id);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
using BountyHandlerFn = bool(__cdecl*)(void* context, const char* node, char* proto);
const auto kStockBountyTag = reinterpret_cast<BountyHandlerFn>(0x005F5D79);

struct ResourceBounty {
  std::int32_t resource;
  float amount;
};

// By proto ID. Written while protos load and read at a kill, on the same thread.
std::unordered_map<std::int32_t, std::vector<ResourceBounty>> g_resourceBounties;
bool g_logResource = false;
int g_resourceLines = 0;

bool g_logTech = false;
bool g_logTeam = false;
int g_techLines = 0;
int g_teamLines = 0;
std::int32_t g_teamType = -1;

void ChangeBounty(char* proto, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  auto* value = reinterpret_cast<float*>(proto + kBounty);
  const float before = *value;
  kEffectValue(relativity, value, *reinterpret_cast<const float*>(base + kBounty), amount, unapply);
  if (g_logTech && g_techLines < kMaxLogLines) {
    ++g_techLines;
    uhc::Log(L"killBountyTechs: proto %d, relativity %u, amount %g%ls: %g -> %g",
             *reinterpret_cast<const std::int32_t*>(proto + 8), relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", static_cast<double>(before), static_cast<double>(*value));
  }
}

void ForgetResourceBounties(char*) { g_resourceBounties.clear(); }

// Replaces the handler of <Bounty> in the tag table.
bool __cdecl ReadBounty(void* context, const char* node, char* proto) {
  const void* text = nullptr;
  if (!kXmlAttribute(node, "resourcetype", &text) || text == nullptr) {
    return kStockBountyTag(context, node, proto);
  }
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 8);
  const char* name = kXmlText(text);
  const std::int32_t resource = name != nullptr ? kResourceByName(context, name) : -1;
  const wchar_t* value = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  const float amount = value != nullptr ? static_cast<float>(_wtof(value)) : 0.0f;
  if (resource < 0 || amount <= 0.0f) {
    uhc::Log(L"resourceBounty: proto %d: <Bounty resourcetype=\"%hs\"> needs a resource and a number above 0, ignored", id,
             name != nullptr ? name : "");
    return true;
  }
  g_resourceBounties[id].push_back({resource, amount});
  if (g_logResource) {
    uhc::Log(L"resourceBounty: proto %d pays %g of resource %d", id, static_cast<double>(amount), resource);
  }
  return true;
}

bool LogOption(const uhc::Config::Args& args, const char* key, bool* log) {
  for (const std::string& arg : args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      uhc::Log(L"%hs: unknown option %hs; feature not applied", key, arg.c_str());
      return false;
    }
    *log = true;
  }
  return true;
}

}  // namespace

// From the hook, with the victim. True: the whole team gets the XP.
extern "C" bool __stdcall UhcIsTeamBounty(const char* victim, float amount) {
  if (victim == nullptr || g_teamType < 0) {
    return false;
  }
  const char* proto = *reinterpret_cast<const char* const*>(victim + kUnitProto);
  if (proto == nullptr || !kProtoIsType(proto, g_teamType)) {
    return false;
  }
  if (g_logTeam && g_teamLines < kMaxLogLines) {
    ++g_teamLines;
    uhc::Log(L"teamKillBounty: proto %d: %g XP to the killer's whole team", *reinterpret_cast<const std::int32_t*>(proto + 8),
             static_cast<double>(amount));
  }
  return true;
}

// From the hook on the kill branch, with the victim and the killer's player, which can be null.
extern "C" void __stdcall UhcPayResourceBounty(const char* victim, char* killer) {
  if (victim == nullptr || killer == nullptr) {
    return;
  }
  const char* proto = *reinterpret_cast<const char* const*>(victim + kUnitProto);
  if (proto == nullptr) {
    return;
  }
  const auto found = g_resourceBounties.find(*reinterpret_cast<const std::int32_t*>(proto + 8));
  if (found == g_resourceBounties.end() || killer == *reinterpret_cast<char* const*>(victim + 0x44)) {
    return;
  }
  char* world = *reinterpret_cast<char**>(*reinterpret_cast<char**>(0x00C66234) + 0x13C);
  const bool team = g_teamType >= 0 && kProtoIsType(proto, g_teamType);
  for (const ResourceBounty& bounty : found->second) {
    int paid = 1;
    if (team) {
      paid = 0;
      const std::int32_t teamId = *reinterpret_cast<const std::int32_t*>(killer + 0x10);
      const auto teams = *reinterpret_cast<char* const* const*>(world + 0x188);
      const char* members = teamId >= 0 && teamId < *reinterpret_cast<const std::int32_t*>(world + 0x18C) ? teams[teamId] : nullptr;
      if (members != nullptr) {
        const auto* ids = *reinterpret_cast<const std::int32_t* const*>(members + 8);
        const std::int32_t count = *reinterpret_cast<const std::int32_t*>(members + 0xC);
        for (std::int32_t i = 0; i < count; ++i) {
          if (char* player = kPlayerById(world, ids[i])) {
            kPlayerAdd(player, bounty.resource, bounty.amount, false);
            ++paid;
          }
        }
      }
    } else {
      kPlayerAdd(killer, bounty.resource, bounty.amount, false);
    }
    if (g_logResource && g_resourceLines < kMaxLogLines) {
      ++g_resourceLines;
      uhc::Log(L"resourceBounty: proto %d killed: %g of resource %d to %d player(s)",
               *reinterpret_cast<const std::int32_t*>(proto + 8), static_cast<double>(bounty.amount), bounty.resource, paid);
    }
  }
}

namespace uhc {

Outcome ApplyKillBountyTechs(const Config& config) {
  const Config::Args* args = config.First("killBountyTechs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!LogOption(*args, "killBountyTechs", &g_logTech) || !AddTechSubtype("KillBounty", &ChangeBounty) ||
      !AddTechSubtype("Bounty", &ChangeBounty)) {
    return Outcome::kFailed;
  }
  Log(L"killBountyTechs: the Data subtypes KillBounty and Bounty are on");
  return Outcome::kApplied;
}

Outcome ApplyResourceBounty(const Config& config) {
  const Config::Args* args = config.First("resourceBounty");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!LogOption(*args, "resourceBounty", &g_logResource) ||
      !VerifyAll("resourceBounty", {&sites::kBountyTagHandler, &sites::kBountyKillBranch}) ||
      !OnDatabaseLoad(&ForgetResourceBounties) ||
      !WriteDword(sites::kBountyTagHandler.va, static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(&ReadBounty))) ||
      !WriteJmp(sites::kBountyKillBranch.va, reinterpret_cast<const void*>(&UhcResourceBountyHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"resourceBounty: <Bounty resourcetype> is on");
  return Outcome::kApplied;
}

Outcome ApplyTeamKillBounty(const Config& config) {
  const Config::Args* args = config.First("teamKillBounty");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!LogOption(*args, "teamKillBounty", &g_logTeam) || !VerifyAll("teamKillBounty", {&sites::kTeamBountyPay}) ||
      !RequestAbstractUnitType("TeamKillBounty", &g_teamType) ||
      !WriteJmp(sites::kTeamBountyPay.va, reinterpret_cast<const void*>(&UhcTeamBountyHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"teamKillBounty: the abstract type TeamKillBounty is on");
  return Outcome::kApplied;
}

}  // namespace uhc
