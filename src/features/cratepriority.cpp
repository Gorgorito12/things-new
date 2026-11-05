// cratePriority: the order in which a civ's units gather crates, from uhc.cfg.
//
// Stock has it in two places, both by civ name. The gather target search adds 1000 x the rank of a
// crate's resource to its score (the only call 0x49A03C of FUN_004DBF40): Dutch Gold, Wood, Food;
// Ottomans and Indians Wood, Food, Gold; the rest Food, Wood, Gold. And when a unit runs out of crates of
// one kind FUN_00501786 (the only call 0x50170B) names the next one, in the same order, the large crate of
// a resource before the small one.
//
// Both calls go through a wrapper. For a civ with an order in the cfg the wrapper answers from that
// order; for any other civ the answer is stock's. The next crate still starts with the stock call, which
// checks the proto is a crate of the six and tells the wrapper whether to answer.
#include <cstdint>
#include <cstdlib>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr std::uint32_t kRankCall = 0x0049A03C;
constexpr std::uint32_t kNextCall = 0x0050170B;
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
constexpr int kMaxLogLines = 200;
constexpr std::int32_t kResources = 3;  // 0 Gold, 1 Wood, 2 Food, as the two functions number them

using RankFn = std::int32_t(__thiscall*)(void* database, std::int32_t resource, std::int32_t civ);
const auto kRank = reinterpret_cast<RankFn>(0x004DBF40);
using NextFn = bool(__thiscall*)(void* player, std::int32_t proto, std::int32_t* next, std::int32_t* resource);
const auto kNext = reinterpret_cast<NextFn>(0x00501786);
using CivIdByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
const auto kCivIdByName = reinterpret_cast<CivIdByNameFn>(0x0058E71F);

struct Order {
  std::string civ;  // as written in the cfg; "all" for every civ that has no line of its own
  std::int32_t civId = -1;
  std::int32_t resources[kResources] = {};  // first = gathered first
};

std::vector<Order> g_orders;
const Order* g_all = nullptr;
const char* g_resolvedDatabase = nullptr;  // civs.xml is read again when a game starts
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Database() { return Field<const char*>(*reinterpret_cast<const char**>(kGameGlobal), 0x140); }

void Resolve() {
  const char* database = Database();
  if (database == g_resolvedDatabase) {
    return;
  }
  g_resolvedDatabase = database;
  for (Order& order : g_orders) {
    if (&order == g_all) {
      continue;
    }
    order.civId = kCivIdByName(database, order.civ.c_str());
    uhc::Log(L"cratePriority: %hs -> civ %d", order.civ.c_str(), order.civId);
  }
}

const Order* Find(std::int32_t civ) {
  Resolve();
  for (const Order& order : g_orders) {
    if (order.civId == civ && &order != g_all) {
      return &order;
    }
  }
  return g_all;
}

void LogLine(const wchar_t* text, std::int32_t a, std::int32_t b, std::int32_t c) {
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(text, a, b, c);
  }
}

// Replaces the call at 0x49A03C: the higher the rank, the sooner.
std::int32_t __fastcall Rank(void* database, void*, std::int32_t resource, std::int32_t civ) {
  const Order* order = Find(civ);
  if (order == nullptr) {
    return kRank(database, resource, civ);
  }
  for (std::int32_t i = 0; i < kResources; ++i) {
    if (order->resources[i] == resource) {
      LogLine(L"cratePriority: civ %d, resource %d: rank %d", civ, resource, kResources - i);
      return kResources - i;
    }
  }
  return 0;  // what stock answers for any other resource
}

// [player+4] is the civ list's owner: [[player+4]+44h], with the array at +20h and the count at +24h.
std::int32_t CivOf(const char* player) {
  const char* list = Field<const char*>(Field<const char*>(player, 4), 0x44);
  return Field<std::int32_t>(list, 0x24) > 0 ? *Field<const std::int32_t*>(list, 0x20) : -1;
}

// Replaces the call at 0x50170B: proto is the crate just searched for, *next the one to look for now.
bool __fastcall Next(char* player, void*, std::int32_t proto, std::int32_t* next, std::int32_t* resource) {
  if (!kNext(player, proto, next, resource)) {
    return false;
  }
  const Order* order = Find(CivOf(player));
  if (order == nullptr) {
    return true;
  }
  const char* database = Database();
  std::int32_t cycle[kResources * 2];  // large and small of each resource, in the civ's order
  for (std::int32_t i = 0; i < kResources; ++i) {
    // Gold: 5E48h, 5E3Ch. Wood: 5E44h, 5E38h. Food: 5E40h, 5E34h.
    const std::uint32_t small = 0x5E3C - order->resources[i] * 4;
    cycle[i * 2] = Field<std::int32_t>(database, small + 0x0C);
    cycle[i * 2 + 1] = Field<std::int32_t>(database, small);
  }
  for (std::int32_t i = 0; i < kResources * 2; ++i) {
    if (cycle[i] == proto) {
      const std::int32_t after = (i + 1) % (kResources * 2);
      *next = cycle[after];
      *resource = order->resources[after / 2];
      LogLine(L"cratePriority: civ %d, after proto %d look for proto %d", CivOf(player), proto, *next);
      return true;
    }
  }
  return true;  // stock knew the proto and we did not: keep its answer
}

bool ParseResource(const std::string& text, std::int32_t* out) {
  const struct {
    const char* name;
    std::int32_t index;
  } names[] = {{"Gold", 0}, {"Coin", 0}, {"Wood", 1}, {"Food", 2}};
  for (const auto& name : names) {
    if (_stricmp(text.c_str(), name.name) == 0) {
      *out = name.index;
      return true;
    }
  }
  return false;
}

}  // namespace

namespace uhc {

Outcome ApplyCratePriority(const Config& config) {
  const std::vector<Config::Args>* lines = config.All("cratePriority");
  if (lines == nullptr) {
    return Outcome::kNotConfigured;
  }
  g_orders.reserve(lines->size());
  for (const Config::Args& line : *lines) {
    if (line.size() == 1 && _stricmp(line[0].c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    Order order;
    bool seen[kResources] = {};
    if (line.size() != 1 + kResources) {
      Log(L"cratePriority: a line needs a civ (or all) and the three resources, or log; feature not applied");
      return Outcome::kFailed;
    }
    order.civ = line[0];
    for (std::int32_t i = 0; i < kResources; ++i) {
      if (!ParseResource(line[1 + i], &order.resources[i]) || seen[order.resources[i]]) {
        Log(L"cratePriority: %hs: expected Gold, Wood and Food, each once; feature not applied", line[0].c_str());
        return Outcome::kFailed;
      }
      seen[order.resources[i]] = true;
    }
    g_orders.push_back(order);
    if (_stricmp(line[0].c_str(), "all") == 0) {
      g_all = &g_orders.back();
    }
  }
  if (g_orders.empty()) {
    Log(L"cratePriority: no civ listed; feature not applied");
    return Outcome::kFailed;
  }
  if (!VerifyAll("cratePriority", {&sites::kCrateRankCall, &sites::kCrateNextCall, &sites::kCrateNextCivRead}) ||
      !WriteCall(kRankCall, reinterpret_cast<const void*>(&Rank)) ||
      !WriteCall(kNextCall, reinterpret_cast<const void*>(&Next))) {
    return Outcome::kFailed;
  }
  Log(L"cratePriority: %u lines", static_cast<unsigned>(g_orders.size()));
  return Outcome::kApplied;
}

}  // namespace uhc
