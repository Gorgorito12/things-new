// incomeRates [<seconds>] [perMinute] [log]: the income rate of each resource, for the interface, as the
// formatText refs {uhcIncome(<resource>)}: what the player's gatherers, its units' AutoGather and its trickles
// brought in over the last <seconds> of game time (default 20, 1 to 60), per second with one decimal ("2.4"), or
// with perMinute per minute, whole ("144"). Gross income: costs, upkeep (a negative trickle), tributes, trades, shipments and treasures are
// not in it.
// - Counted at the single add 0x49A98A (hooks/incomerates_hooks.asm): its head reads the return address, and only
//   the global trickle (0x4E0CFE), unit AutoGather (0x4C379D) and the gather tick (0x4ED1F3) are counted, with a
//   positive amount (handicap included, as the add gets it). The keys that pay from the DLL through the same add
//   count their payments with CountIncome (income.h).
// - Kept per player and resource in buckets of one second of game time (the world update, worldtick.h); a new
//   world clears them, so after a load the rate builds up again over <seconds>.
// - The ref reads its argument as {resource()} does: a resource name (0x44709C), for the player the interface
//   shows ([game+3C0h]). With shared resources ([world+6912h]) {resource()} shows the team's total, so the rate is
//   the team's: every player the shown one counts as itself or an ally (0x4707EC).
#include <windows.h>

#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>

#include "../datarefs.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../income.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
void UhcIncomeAddHook();
// Every add that passes the hook (the asm increments it), for `log`'s cost line.
std::uint32_t g_uhcIncomeAdds = 0;
}

namespace {

struct BString {
  wchar_t* text;
};

using ResourceByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using PlayerByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using AllyOrSelfFn = bool(__thiscall*)(const char* player, std::int32_t id);
using BStringAssignFn = void(__thiscall*)(wchar_t** self, const BString* source, std::int32_t, std::int32_t);
const auto kResourceByName = reinterpret_cast<ResourceByNameFn>(0x0044709C);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kAllyOrSelf = reinterpret_cast<AllyOrSelfFn>(0x004707EC);
const auto kBStringAssign = reinterpret_cast<BStringAssignFn>(0x00443BB8);
using StockpileFn = float(__thiscall*)(const char* stockpiles, std::int32_t resource);
const auto kStockpile = reinterpret_cast<StockpileFn>(0x0044EFFF);  // [player+230h], the stockpile list
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database, +3C0h the shown player
constexpr std::uint32_t kRefArgument = 0x00C6DF7C;  // the BString* of {name(arg)} during a ref's call

constexpr int kPlayers = 16;
constexpr int kResources = 16;
constexpr int kMaxWindow = 60;
constexpr int kBuckets = kMaxWindow + 1;
constexpr std::int32_t kBucketMs = 1000;
constexpr int kMaxLogLines = 200;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

bool g_on = false;
bool g_perSecond = true;
bool g_log = false;
int g_logLines = 0;
int g_window = 20;

// g_amount[b][player][resource]: what came in during bucket b. g_current is being filled (g_currentMs of it
// elapsed); g_full counts the complete buckets behind it, up to g_window.
float g_amount[kBuckets][kPlayers][kResources] = {};
int g_current = 0;
std::int32_t g_currentMs = 0;
int g_full = 0;
const char* g_world = nullptr;
std::int32_t g_logMs = 0;

int g_generation = 0;
int g_namesGeneration = -1;
std::map<std::wstring, std::int32_t> g_names;  // lowercase resource name -> index, -1 if unknown

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

void Clear() {
  for (auto& bucket : g_amount) {
    for (auto& player : bucket) {
      for (float& amount : player) {
        amount = 0.0f;
      }
    }
  }
  g_current = 0;
  g_currentMs = 0;
  g_full = 0;
}

// Every game start and every load reads the data again: a new game may get the old world's address, so the
// buckets are emptied here too.
void NewDatabase(char*) {
  ++g_generation;
  Clear();
  g_world = nullptr;
}

// The player's income of a resource per second over the window.
float Rate(int player, int resource) {
  const float seconds = static_cast<float>(g_full) + static_cast<float>(g_currentMs) / kBucketMs;
  if (seconds < 0.5f) {
    return 0.0f;
  }
  float sum = 0.0f;
  for (int i = 0; i <= g_full; ++i) {
    sum += g_amount[(g_current - i + kBuckets) % kBuckets][player][resource];
  }
  return sum / seconds;
}

// With `log`: the shown player's income since the last log line, by source, and its stockpiles then.
enum Source { kGather, kAutoGather, kTrickle, kDll, kSources };
float g_source[kSources][kResources] = {};
float g_stock[kResources] = {};
bool g_haveStock = false;
constexpr int kLoggedResources = 6;  // gold, wood, food, fame, skill points, XP

void Count(std::int32_t player, std::int32_t resource, float amount, Source source) {
  if (player >= 0 && player < kPlayers && resource >= 0 && resource < kResources && amount > 0.0f) {
    g_amount[g_current][player][resource] += amount;
    if (g_log) {
      const char* game = Game();
      if (game != nullptr && Field<std::int32_t>(game, 0x3C0) == player) {
        g_source[source][resource] += amount;
      }
    }
  }
}

// With `log`: what the counting cost since the last line (the time inside UhcIncomeCount, by the performance counter).
std::uint32_t g_counted = 0;
std::int64_t g_countTicks = 0;
std::uint32_t g_addsBefore = 0;

void LogCost() {
  if (g_logLines >= kMaxLogLines) {
    return;
  }
  LARGE_INTEGER frequency;
  QueryPerformanceFrequency(&frequency);
  ++g_logLines;
  uhc::Log(L"incomeRates: last 60 s of game time: %u adds through the hook, %u counted, %.0f us inside the count",
           g_uhcIncomeAdds - g_addsBefore, g_counted, 1e6 * static_cast<double>(g_countTicks) / frequency.QuadPart);
  g_addsBefore = g_uhcIncomeAdds;
  g_counted = 0;
  g_countTicks = 0;
}

// Every 60 s of game time: per resource, what was counted by source, the stockpile's change, and the rate shown.
void LogPeriod(const char* world) {
  const char* game = Game();
  const std::int32_t shown = game == nullptr ? -1 : Field<std::int32_t>(game, 0x3C0);
  const char* player = shown < 0 ? nullptr : kPlayerById(world, shown);
  if (player == nullptr || shown >= kPlayers) {
    return;
  }
  for (int r = 0; r < kLoggedResources && g_logLines < kMaxLogLines; ++r) {
    const float stock = kStockpile(player + 0x230, r);
    const float counted = g_source[kGather][r] + g_source[kAutoGather][r] + g_source[kTrickle][r] + g_source[kDll][r];
    if (g_haveStock && (counted > 0.0f || stock != g_stock[r])) {
      ++g_logLines;
      uhc::Log(L"incomeRates: player %d, resource %d, last 60 s: counted %.1f (gather %.1f, AutoGather %.1f, "
               L"trickle %.1f, DLL %.1f), stockpile %+.1f (%.1f -> %.1f); rate %.2f/s, %.1f/min",
               shown, r, counted, g_source[kGather][r], g_source[kAutoGather][r], g_source[kTrickle][r],
               g_source[kDll][r], stock - g_stock[r], g_stock[r], stock, static_cast<double>(Rate(shown, r)),
               60.0 * Rate(shown, r));
    }
    g_stock[r] = stock;
  }
  g_haveStock = true;
  for (auto& source : g_source) {
    for (float& amount : source) {
      amount = 0.0f;
    }
  }
}

void Tick(char* world, std::int32_t deltaMs) {
  if (world != g_world) {
    Clear();
    g_world = world;
    g_logMs = 0;
    g_haveStock = false;
  }
  g_currentMs += deltaMs;
  while (g_currentMs >= kBucketMs) {
    g_currentMs -= kBucketMs;
    g_current = (g_current + 1) % kBuckets;
    for (auto& player : g_amount[g_current]) {
      for (float& amount : player) {
        amount = 0.0f;
      }
    }
    if (g_full < g_window) {
      ++g_full;
    }
  }
  if (!g_log || g_logLines >= kMaxLogLines) {
    return;
  }
  // Logged on a bucket boundary, so with a 60 s window the rate shown covers the same 60 s as the counts.
  g_logMs += deltaMs;
  if (g_logMs >= 60000 && g_currentMs < deltaMs) {
    g_logMs = 0;
    LogPeriod(world);
    LogCost();
  }
}

// The resource index of the ref's argument, or -1.
std::int32_t ArgumentResource(const char* database) {
  const auto* arg = *reinterpret_cast<const BString* const*>(kRefArgument);
  if (arg == nullptr || arg->text == nullptr || arg->text[0] == L'\0') {
    return -1;
  }
  if (g_namesGeneration != g_generation) {
    g_namesGeneration = g_generation;
    g_names.clear();
  }
  // The argument holds the whole token, "{uhcincome(food)}": the name is what is between the first "(" and the next
  // ")", as the stock providers read it (0x453F8F).
  std::wstring key = arg->text;
  const std::size_t open = key.find(L'(');
  if (open != std::wstring::npos) {
    const std::size_t close = key.find(L')', open);
    key = key.substr(open + 1, close == std::wstring::npos ? std::wstring::npos : close - open - 1);
  }
  for (wchar_t& c : key) {
    c = static_cast<wchar_t>(towlower(c));
  }
  const auto found = g_names.find(key);
  if (found != g_names.end()) {
    return found->second;
  }
  std::string narrow;
  for (wchar_t c : key) {
    narrow.push_back(c < 0x80 ? static_cast<char>(c) : '?');
  }
  const std::int32_t index = kResourceByName(database, narrow.c_str());
  g_names[key] = index;
  if (index < 0) {
    uhc::Log(L"incomeRates: {uhcIncome(%ls)}: no resource of that name", key.c_str());
  }
  return index;
}

}  // namespace

// From the hook, with the add's return address: one of the three income callers.
extern "C" void __stdcall UhcIncomeCount(const char* player, std::int32_t resource, float amount,
                                         std::uint32_t caller) {
  if (player == nullptr) {
    return;
  }
  const Source source = caller == 0x004ED1F3 ? kGather : caller == 0x004C379D ? kAutoGather : kTrickle;
  if (!g_log) {
    Count(Field<std::int32_t>(player, 0), resource, amount, source);
    return;
  }
  LARGE_INTEGER start;
  LARGE_INTEGER end;
  QueryPerformanceCounter(&start);
  Count(Field<std::int32_t>(player, 0), resource, amount, source);
  QueryPerformanceCounter(&end);
  ++g_counted;
  g_countTicks += end.QuadPart - start.QuadPart;
}

namespace {

// {uhcIncome(<resource>)}, a string: the shown player's rate (its team's with shared resources).
bool __stdcall IncomeRef(uhc::DataRefValue* value) {
  if (value == nullptr || value->type != uhc::kDataRefString) {
    return false;
  }
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (world == nullptr || database == nullptr) {
    return false;
  }
  if (world != g_world) {  // a game loaded and still paused: nothing counted yet in this world
    Clear();
    g_world = world;
    g_logMs = 0;
    g_haveStock = false;
  }
  const std::int32_t resource = ArgumentResource(database);
  const std::int32_t shown = Field<std::int32_t>(game, 0x3C0);
  if (resource < 0 || resource >= kResources || shown < 0 || shown >= kPlayers) {
    return false;
  }
  float rate = 0.0f;
  if (Field<std::uint8_t>(world, 0x6912) != 0) {
    const char* self = kPlayerById(world, shown);
    const std::int32_t count = Field<std::int32_t>(world, 0x5C);
    for (std::int32_t i = 0; self != nullptr && i < count && i < kPlayers; ++i) {
      if (kAllyOrSelf(self, i)) {
        rate += Rate(i, resource);
      }
    }
  } else {
    rate = Rate(shown, resource);
  }
  wchar_t text[32];
  if (g_perSecond) {
    swprintf_s(text, L"%.1f", static_cast<double>(rate));
  } else {
    swprintf_s(text, L"%d", static_cast<int>(std::lround(rate * 60.0f)));
  }
  const BString source{text};
  kBStringAssign(&value->text, &source, -1, -1);
  return true;
}

}  // namespace

namespace uhc {

void CountIncome(const char* player, std::int32_t resource, float amount) {
  if (g_on && player != nullptr) {
    Count(Field<std::int32_t>(player, 0), resource, amount, kDll);
  }
}

Outcome ApplyIncomeRates(const Config& config) {
  const Config::Args* args = config.First("incomeRates");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "perMinute") == 0) {
      g_perSecond = false;
    } else if (_stricmp(arg.c_str(), "perSecond") == 0) {
      g_perSecond = true;
    } else if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      char* end = nullptr;
      const long seconds = std::strtol(arg.c_str(), &end, 10);
      if (end == arg.c_str() || *end != '\0' || seconds < 1 || seconds > kMaxWindow) {
        Log(L"incomeRates: unknown argument '%hs' (expected seconds 1 to %d, perMinute, log); not applied",
            arg.c_str(), kMaxWindow);
        return Outcome::kFailed;
      }
      g_window = static_cast<int>(seconds);
    }
  }
  if (!VerifyAll("incomeRates", {&sites::kPlayerAddResource, &sites::kIncomeTrickleCall,
                                 &sites::kIncomeAutoGatherCall, &sites::kGatherTickAddResource,
                                 &sites::kResourceByName, &sites::kPlayerIsAllyOrSelf, &sites::kBStringAssign})) {
    return Outcome::kFailed;
  }
  if (!AddDataRef(L"uhcIncome", kDataRefString, &IncomeRef) || !OnDatabaseLoad(&NewDatabase) ||
      !AddWorldTick(&Tick) ||
      !WriteJmp(sites::kPlayerAddResource.va, reinterpret_cast<const void*>(&UhcIncomeAddHook), 6)) {
    return Outcome::kFailed;
  }
  g_on = true;
  Log(L"incomeRates: {uhcIncome(<resource>)} = income %ls over the last %d s of game time (gathering, AutoGather, "
      L"trickles)%ls",
      g_perSecond ? L"per second" : L"per minute", g_window, g_log ? L", the shown player's logged every 60 s" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
