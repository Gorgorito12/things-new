// explorerUnits Proto Type StringID ...: listed protos are heroes for the hero name (FUN_004702DC
// at 0x6A012A: Type 1 the home city's explorer name, 0 the stock path for other units, any other
// value the first of the home city's hero names) and their knockout message is StringID (0x50B01F).
// marketUnits Proto ...: owning a unit of a listed proto counts as owning a Market for the market
// trade test (FUN at 0x7DEF70 checks the player's count of the Market proto [db+5E30h], then of
// [db+5E60h], with 0x4C846D before buying or selling). Hook: hooks/unitlist_hooks.asm; names
// resolve lazily (namelists.h).
#include <cstdint>
#include <cstdlib>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../namelists.h"
#include "../patch.h"

namespace {

uhc::ProtoIdList g_marketUnits;
uhc::ProtoIdList g_explorerUnits;
std::vector<std::int32_t> g_explorerType;    // per cfg triple
std::vector<std::int32_t> g_explorerString;  // per cfg triple

}  // namespace

extern "C" {
void UhcMarketUnitsHook();
void UhcExplorerNameHook();
void UhcExplorerKnockoutHook();

// The Type of a listed proto, or -1.
std::int32_t __stdcall UhcExplorerType(std::int32_t proto) {
  const int i = g_explorerUnits.IndexOf(proto);
  return i < 0 ? -1 : g_explorerType[static_cast<std::size_t>(i)];
}

// The knockout string ID of a listed proto, or -1.
std::int32_t __stdcall UhcExplorerString(std::int32_t proto) {
  const int i = g_explorerUnits.IndexOf(proto);
  return i < 0 ? -1 : g_explorerString[static_cast<std::size_t>(i)];
}

// kb = the player's kb object ([player+80h]), player = the player ID. 0x4C846D: int
// thiscall(kb, player, protoId, 2, 0), the count of that player's units of the proto.
bool __stdcall UhcHasMarketUnit(void* kb, std::int32_t player) {
  using UnitCount = std::int32_t(__thiscall*)(void* kb, std::int32_t player, std::int32_t proto, std::int32_t,
                                             std::int32_t);
  const auto unitCount = reinterpret_cast<UnitCount>(0x004C846D);
  if (kb == nullptr) {
    return false;
  }
  for (const std::int32_t proto : g_marketUnits.Ids()) {
    if (unitCount(kb, player, proto, 2, 0) > 0) {
      return true;
    }
  }
  return false;
}
}

namespace uhc {

Outcome ApplyMarketUnits(const Config& config) {
  const Config::Args* args = config.First("marketUnits");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (args->empty()) {
    Log(L"marketUnits: no proto listed");
    return Outcome::kFailed;
  }
  if (!VerifyAll("marketUnits", {&sites::kMarketUnits, &sites::kProtoByName})) {
    return Outcome::kFailed;
  }
  g_marketUnits.Set("marketUnits", *args);
  if (!WriteJmp(sites::kMarketUnits.va, reinterpret_cast<const void*>(&UhcMarketUnitsHook),
                sites::kMarketUnits.size)) {
    return Outcome::kFailed;
  }
  Log(L"marketUnits: %zu proto(s) count as a Market for trading; resolved when protoy.xml is read",
      args->size());
  return Outcome::kApplied;
}

Outcome ApplyExplorerUnits(const Config& config) {
  const Config::Args* args = config.First("explorerUnits");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (args->empty() || args->size() % 3 != 0) {
    Log(L"explorerUnits: needs triples <Proto> <Type> <StringID> (%zu values given)", args->size());
    return Outcome::kFailed;
  }
  std::vector<std::string> names;
  for (std::size_t i = 0; i < args->size(); i += 3) {
    char* end = nullptr;
    const long type = std::strtol((*args)[i + 1].c_str(), &end, 10);
    const bool typeOk = end != nullptr && *end == '\0';
    const long id = std::strtol((*args)[i + 2].c_str(), &end, 10);
    if (!typeOk || *end != '\0' || type < 0 || id <= 0) {
      Log(L"explorerUnits: bad triple %hs %hs %hs (Type 0 or more, StringID above 0)", (*args)[i].c_str(),
          (*args)[i + 1].c_str(), (*args)[i + 2].c_str());
      return Outcome::kFailed;
    }
    names.push_back((*args)[i]);
    g_explorerType.push_back(static_cast<std::int32_t>(type));
    g_explorerString.push_back(static_cast<std::int32_t>(id));
  }
  if (!VerifyAll("explorerUnits", {&sites::kExplorerName, &sites::kExplorerKnockout, &sites::kProtoByName})) {
    return Outcome::kFailed;
  }
  g_explorerUnits.Set("explorerUnits", names);
  if (!WriteJmp(sites::kExplorerName.va, reinterpret_cast<const void*>(&UhcExplorerNameHook),
                sites::kExplorerName.size) ||
      !WriteJmp(sites::kExplorerKnockout.va, reinterpret_cast<const void*>(&UhcExplorerKnockoutHook),
                sites::kExplorerKnockout.size)) {
    return Outcome::kFailed;
  }
  Log(L"explorerUnits: %zu hero proto(s); resolved when protoy.xml is read", names.size());
  return Outcome::kApplied;
}

}  // namespace uhc
