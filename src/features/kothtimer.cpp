// kothTimer: the King of the Hill victory time from a table by the number of players or of teams.
//
// When a team takes the hill (ypKingsHill), FUN_00948F32 (thiscall on the team) starts its timer: the time is
// FUN_009F02DD() - [team+84h], in seconds, and 0x948A1F sets the end at now + 1000 x that. FUN_009F02DD, on the
// victory settings of DefaultVP.xml ([world+0A8h]), computes KOTHVictoryTime (+104h) + (players - 1) x
// KOTHVictoryTimePerPlayer (+108h, when above 0) - (teams - AdjustKOTHTotalTimeByTeams (+10Ch)) x
// AdjustKOTHTotalTimeByTeamsFactor (+110h), with players = [world+5Ch] (Gaia included) and teams = [world+18Ch].
// Its only caller is 0x948F95.
//
// The key jumps at its head (hooks/kothtimer_hooks.asm) and answers from the cfg's table: the time of the largest
// count listed that is not above the game's count (or of the smallest listed). Players are the players without Gaia,
// teams the distinct teams of those players.
#include <windows.h>

#include <charconv>
#include <climits>
#include <cstdint>
#include <cstring>
#include <iterator>
#include <map>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr int kMaxCount = 16;
constexpr int kMaxSeconds = 86400;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

bool g_teams = false;               // count teams, not players
std::map<int, int> g_seconds;       // count -> seconds

bool ParseInt(const std::string& text, int low, int high, int* value) {
  const char* first = text.data();
  const char* last = first + text.size();
  const auto [end, error] = std::from_chars(first, last, *value);
  return error == std::errc() && end == last && *value >= low && *value <= high;
}

// The stock time, as FUN_009F02DD computes it, for the log.
int StockSeconds(const char* vp, const char* world) {
  int time = Field<std::int32_t>(vp, 0x104);
  const int perPlayer = Field<std::int32_t>(vp, 0x108);
  if (perPlayer > 0) {
    time += (Field<std::int32_t>(world, 0x5C) - 1) * perPlayer;
  }
  return time - (Field<std::int32_t>(world, 0x18C) - Field<std::int32_t>(vp, 0x10C)) * Field<std::int32_t>(vp, 0x110);
}

}  // namespace

extern "C" {

void UhcKothTimeHook();  // hooks/kothtimer_hooks.asm

// From the head of FUN_009F02DD: the victory settings in ECX. INT_MIN lets the stock code compute the time.
std::int32_t __stdcall UhcKothTime(const char* vp) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (vp == nullptr || world == nullptr || g_seconds.empty()) {
    return INT_MIN;
  }
  const std::int32_t slots = Field<std::int32_t>(world, 0x5C);
  const char* const* players = Field<const char* const*>(world, 0x58);
  int playerCount = 0;
  std::uint32_t teamMask = 0;
  int teamCount = 0;
  for (std::int32_t id = 1; players != nullptr && id < slots && id < 32; ++id) {
    const char* player = players[id];
    if (player == nullptr) {
      continue;
    }
    ++playerCount;
    const std::int32_t team = Field<std::int32_t>(player, 0x10);
    if (team >= 0 && team < 32 && (teamMask & (1u << team)) == 0) {
      teamMask |= 1u << team;
      ++teamCount;
    }
  }
  const int count = g_teams ? teamCount : playerCount;
  auto entry = g_seconds.upper_bound(count);
  entry = entry == g_seconds.begin() ? entry : std::prev(entry);
  const int seconds = entry->second;
  uhc::Log(L"kothTimer: %d player(s) in %d team(s): the hill holds for %d s (the %ls %d entry; stock %d s, its counts "
           L"%d slot(s), %d team(s))",
           playerCount, teamCount, seconds, g_teams ? L"teams" : L"players", entry->first, StockSeconds(vp, world),
           slots, Field<std::int32_t>(world, 0x18C));
  return seconds;
}
}

namespace uhc {

Outcome ApplyKothTimer(const Config& config) {
  const Config::Args* args = config.First("kothTimer");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::map<int, int> seconds;
  bool teams = false;
  bool modeGiven = false;
  for (const std::string& arg : *args) {
    const std::size_t equals = arg.find('=');
    int count = 0;
    int value = 0;
    if (!modeGiven && seconds.empty() &&
               (_stricmp(arg.c_str(), "players") == 0 || _stricmp(arg.c_str(), "teams") == 0)) {
      teams = _stricmp(arg.c_str(), "teams") == 0;
      modeGiven = true;
    } else if (equals != std::string::npos && ParseInt(arg.substr(0, equals), 1, kMaxCount, &count) &&
               ParseInt(arg.substr(equals + 1), 1, kMaxSeconds, &value) && seconds.count(count) == 0) {
      seconds[count] = value;
    } else {
      Log(L"kothTimer: unexpected argument %hs (expected: [players | teams] N=seconds ..., N from 1 to %d, "
          L"seconds from 1 to %d, each N once); feature not applied",
          arg.c_str(), kMaxCount, kMaxSeconds);
      return Outcome::kFailed;
    }
  }
  if (seconds.empty()) {
    Log(L"kothTimer: no N=seconds entry; feature not applied");
    return Outcome::kFailed;
  }
  if (!VerifyAll("kothTimer", {&sites::kKothTotalTime, &sites::kKothStartCall, &sites::kKothSetEnd})) {
    return Outcome::kFailed;
  }
  g_teams = teams;
  g_seconds = seconds;
  if (!WriteJmp(sites::kKothTotalTime.va, reinterpret_cast<const void*>(&UhcKothTimeHook), 5)) {
    return Outcome::kFailed;
  }
  std::wstring table;
  for (const auto& [count, value] : seconds) {
    table += L" " + std::to_wstring(count) + L"=" + std::to_wstring(value);
  }
  Log(L"kothTimer: the King of the Hill time by the number of %ls:%ls s (multiplayer unverified)",
      teams ? L"teams" : L"players", table.c_str());
  return Outcome::kApplied;
}

}  // namespace uhc
