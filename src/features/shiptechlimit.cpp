// shipTechLimit [notext] [log]: a civ tag <ShipTechLimit>N</ShipTechLimit> in civs.xml caps how many "shipment techs"
// a player of that civ researches in a game. A shipment tech is one whose cost has the Ships resource (index 6) above
// 0, as a mod's council techs that cost one Ship: researched on a unit or a building, never a home city card (a card is
// sent by the home city, not researched, and never reaches the research payment).
//
// A repeatable tech (the flag YPInfiniteTech, status bit 29) is outside the rule: it does not count, it is not
// refused at the limit and its rollover has no line.
//
// The count of a player: the shipment techs whose research he paid, minus those cancelled with a refund. It counts
// on payment, so a queued research counts. A research that ends without a refund (its unit dies) keeps its count, as
// the ship it cost is not given back.
// - Payment: the shared research payment (researchpay.h) reports every research once its action is set up (a payer
//   that claims nothing): [action+64h] the player ID, [action+68h] the tech ID.
// - Refund: the shared refund observer (0x8D7004 at 0x9E6167 and 0x9D56B5, the cancel of a Research and of a
//   CommandResearch).
// - Refusal: the shared can-research test (canresearch.h, the head of 0x4C6968): at the limit, a shipment tech is
//   refused for a unit of that player. The research start asks it at 0x9E670B, inside the research command's
//   execution, so the research does not start on any machine; the command panel asks it for each button, so the
//   button shows greyed. Callers that pass no unit (the home city) are not refused.
// - The reason: a line in the tech's rollover (techrollover.h), "Shipment techs: n/N", red at the limit.
//
// Saved games: the counts are saved markers (savedmarkers.h, stat 69h) on one living unit of each player, written by
// a world tick when they change and moved when that unit dies. A game that starts or loads reads them back (one walk
// over the units); a player with none gets the activations of his shipment techs (the count byte [status+21h]) as
// a fallback, for a game saved before the key was on. Older builds counted the repeatable techs too, in a marker of
// kind 1 (this build writes kind 2): on load such a count loses the activations of the player's repeatable shipment
// techs and the marker becomes kind 2 (a repeatable research paid and still queued at the save stays counted).
#include <windows.h>

#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <map>
#include <string>

#include "../canresearch.h"
#include "../civtags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../researchpay.h"
#include "../savedmarkers.h"
#include "../techrollover.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr int kPlayers = 16;
constexpr std::int32_t kShips = 6;               // the resource index of Ships
constexpr std::int32_t kStat = 0x69;             // savedmarkers.h
constexpr std::uint32_t kTag = 0x53540000;       // 'ST' << 16 | player << 8 | kind
constexpr std::uint32_t kTagMask = 0xFFFF0000;
constexpr std::uint32_t kKindOld = 1;            // older builds: the count holds the repeatable techs
constexpr std::uint32_t kKindNow = 2;            // the count without them
constexpr std::uint32_t kInfiniteBit = 29;       // YPInfiniteTech
constexpr int kMaxLines = 200;

using ResGetFn = float(__thiscall*)(const void* list, std::int32_t r);
const auto kResGet = reinterpret_cast<ResGetFn>(0x0044EFFF);
using EntryFn = const char*(__thiscall*)(const void* root, std::int32_t player, std::int32_t tech);
const auto kEntry = reinterpret_cast<EntryFn>(0x0094ADAA);
using UnitTestFn = bool(__thiscall*)(const char* unit);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

std::map<std::int32_t, std::int32_t> g_limit;  // civ ID -> N, from civs.xml
bool g_text = true;
bool g_log = false;
int g_lines = 0;

std::int32_t g_count[kPlayers] = {};
bool g_dirty[kPlayers] = {};
std::int32_t g_carrier[kPlayers];  // the unit that holds the player's marker, -1 none
const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;

void Line(const wchar_t* format, ...) {
  if (!g_log || g_lines >= kMaxLines) {
    return;
  }
  wchar_t text[512];
  va_list args;
  va_start(args, format);
  _vsnwprintf_s(text, _TRUNCATE, format, args);
  va_end(args);
  ++g_lines;
  uhc::Log(L"shipTechLimit: %ls%ls", text, g_lines == kMaxLines ? L" (no more lines are logged)" : L"");
}

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

const char* PlayerById(const char* world, std::int32_t id) {
  if (world == nullptr || id < 0 || id >= Field<std::int32_t>(world, 0x5C)) {
    return nullptr;
  }
  return Field<const char* const*>(world, 0x58)[id];
}

// A player's civ ID (0x4539D3): [[player+20h]] when [player+24h] > 0, else -1.
std::int32_t CivIdOf(const char* player) {
  return Field<std::int32_t>(player, 0x24) > 0 ? *Field<const std::int32_t*>(player, 0x20) : -1;
}

// The limit of a player's civ, or -1.
std::int32_t LimitOf(const char* player) {
  if (player == nullptr || g_limit.empty()) {
    return -1;
  }
  const auto found = g_limit.find(CivIdOf(player));
  return found == g_limit.end() ? -1 : found->second;
}

bool HasBit(const char* status, std::uint32_t bit) {
  if (bit >= Field<std::uint32_t>(status, 8)) {
    return false;
  }
  return (Field<const std::uint8_t*>(status, 4)[bit / 8] >> (bit % 8) & 1) != 0;
}

// The tech's cost for this player (the status's own list at +10h) has Ships.
bool CostsShips(const char* status) { return status != nullptr && kResGet(status + 0x10, kShips) > 0.0f; }

bool IsInfinite(const char* status) { return HasBit(status, kInfiniteBit); }

// A shipment tech under the rule: it costs Ships and is not repeatable.
bool IsShipTech(const char* status) { return CostsShips(status) && !IsInfinite(status); }

std::int32_t TechIdOf(const char* status) {
  const char* def = Field<const char*>(status, 0);
  return def == nullptr ? -1 : Field<std::int32_t>(def, 0);
}

const char* StatusOf(const char* world, std::int32_t player, std::int32_t tech) {
  const char* root = world == nullptr ? nullptr : Field<const char*>(world, 0x7C);
  return root == nullptr ? nullptr : kEntry(root, player, tech);
}

// --- Saved markers ------------------------------------------------------------------------------------------

char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<UnitTestFn const* const*>(unit))[0xA4 / 4](unit); }

bool IsDead(const char* unit) {  // state bit 11: the kill handler returns at once
  const auto* bits = Field<const std::uint8_t*>(unit, 4);
  return bits != nullptr && Field<std::uint32_t>(unit, 8) > 11 && (bits[1] & 0x08) != 0;
}

std::int32_t OwnerOf(const char* unit) {
  const char* owner = Field<const char*>(unit, 0x44);
  return owner == nullptr ? -1 : Field<std::int32_t>(owner, 0);
}

std::uint32_t MarkerWord(std::int32_t player, std::uint32_t kind = kKindNow) {
  return kTag | (static_cast<std::uint32_t>(player) << 8) | kind;
}

bool Living(const char* unit) { return unit != nullptr && IsAlive(unit) && !IsDead(unit); }

void FreeMarker(const char* world, std::int32_t player) {
  char* unit = UnitById(world, g_carrier[player]);
  if (unit != nullptr) {
    if (char* marker = uhc::markers::Find(unit, kStat, MarkerWord(player))) {
      uhc::markers::Free(marker);
    }
  }
  g_carrier[player] = -1;
}

// Writes the player's count on his carrier, a new one if it is gone. False: no unit took it (try again later).
bool WriteMarker(const char* world, std::int32_t player) {
  char* unit = UnitById(world, g_carrier[player]);
  if (!Living(unit)) {
    FreeMarker(world, player);
    unit = nullptr;
    const std::int32_t count = Field<std::int32_t>(world, 0x10);
    char* const* table = Field<char* const*>(world, 0x0C);
    for (std::int32_t i = 0; table != nullptr && i < count && unit == nullptr; ++i) {
      char* candidate = table[i];
      if (candidate != nullptr && OwnerOf(candidate) == player && Living(candidate) &&
          uhc::markers::Take(candidate, kStat) != nullptr) {
        unit = candidate;
      }
    }
    if (unit == nullptr) {
      return false;
    }
  }
  char* marker = uhc::markers::Find(unit, kStat, MarkerWord(player));
  if (marker == nullptr) {
    marker = uhc::markers::Take(unit, kStat);
  }
  if (marker == nullptr) {
    return false;
  }
  uhc::markers::Word(marker, 0) = MarkerWord(player);
  uhc::markers::Word(marker, 1) = static_cast<std::uint32_t>(g_count[player]);
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (id != g_carrier[player]) {
    Line(L"player %d's count is kept on unit %d", player, id);
  }
  g_carrier[player] = id;
  return true;
}

// The activations of the player's shipment techs (repeatable ones: `infinite`): the fallback count of a game whose
// markers hold none, and what an older build's count held of the repeatable ones.
std::int32_t CountFromStatuses(const char* world, std::int32_t player, bool infinite = false) {
  const char* root = Field<const char*>(world, 0x7C);
  // The per-player tables are an array at the root (0x94ADAA: [root + 4 * player]).
  const char* table = root == nullptr ? nullptr : Field<const char*>(root, 4 * static_cast<std::uint32_t>(player));
  if (table == nullptr) {
    return 0;
  }
  const char* const* entries = Field<const char* const*>(table, 4);
  const std::int32_t count = Field<std::int32_t>(table, 8);
  std::int32_t total = 0;
  for (std::int32_t i = 0; entries != nullptr && i < count; ++i) {
    const char* status = entries[i];
    if (status != nullptr && CostsShips(status) && IsInfinite(status) == infinite) {
      total += Field<std::uint8_t>(status, 0x21);
    }
  }
  return total;
}

// A game that just started or loaded: the counts its markers keep. One walk over the units.
void Rebuild(const char* world) {
  bool found[kPlayers] = {};
  bool corrected[kPlayers] = {};
  for (int p = 0; p < kPlayers; ++p) {
    g_count[p] = 0;
    g_dirty[p] = false;
    g_carrier[p] = -1;
  }
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
    char* unit = table[i];
    if (unit == nullptr) {
      continue;
    }
    uhc::markers::ForEach(unit, kStat, [&](char* marker) {
      const std::uint32_t word0 = uhc::markers::Word(marker, 0);
      if ((word0 & kTagMask) != kTag) {
        return true;
      }
      const int player = static_cast<int>((word0 >> 8) & 0xFF);
      const std::uint32_t kind = word0 & 0xFF;
      if (player >= kPlayers || found[player] || (kind != kKindNow && kind != kKindOld)) {
        uhc::markers::Free(marker);  // a second copy: keep the first
        return true;
      }
      found[player] = true;
      g_count[player] = static_cast<std::int32_t>(uhc::markers::Word(marker, 1));
      if (kind == kKindOld) {
        // An older build's count, with the repeatable techs: without their activations, kept as kind 2 at once.
        const std::int32_t old = g_count[player];
        g_count[player] -= CountFromStatuses(world, player, true);
        if (g_count[player] < 0) {
          g_count[player] = 0;
        }
        uhc::markers::Word(marker, 0) = MarkerWord(player);
        uhc::markers::Word(marker, 1) = static_cast<std::uint32_t>(g_count[player]);
        corrected[player] = old != g_count[player];
        uhc::Log(L"shipTechLimit: player %d's count from an older build (%d) held repeatable techs: now %d", player,
                 old, g_count[player]);
      }
      g_carrier[player] = Field<std::int32_t>(unit, 0x10);
      return true;
    });
  }
  for (int p = 0; p < kPlayers; ++p) {
    const char* player = PlayerById(world, p);
    if (LimitOf(player) < 0) {
      continue;
    }
    if (!found[p]) {
      g_count[p] = CountFromStatuses(world, p);
      g_dirty[p] = g_count[p] != 0;
    }
    Line(L"game start or load: player %d has %d of %d shipment techs%ls", p, g_count[p], LimitOf(player),
         !found[p] ? L" (no saved count: from the techs he has)"
                   : (corrected[p] ? L" (an older build's count, without the repeatable techs)" : L""));
  }
}

void Sync() {
  const char* world = World();
  if (world == nullptr) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const bool sameGame = world == g_world && now >= g_lastTime && step - g_lastStep <= 1;
  if (!sameGame) {
    g_world = world;
    Rebuild(world);
  }
  g_lastTime = now;
  g_lastStep = step;
}

void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  Sync();
  for (int p = 0; p < kPlayers; ++p) {
    if (g_dirty[p] || (g_carrier[p] >= 0 && !Living(UnitById(world, g_carrier[p])))) {
      g_dirty[p] = !WriteMarker(world, p);
    }
  }
}

// --- The rule -----------------------------------------------------------------------------------------------

// The count of a player in this game, or -1 for a player without a limit.
std::int32_t CountOf(const char* player, std::int32_t* limit) {
  *limit = LimitOf(player);
  if (*limit < 0) {
    return -1;
  }
  const std::int32_t id = Field<std::int32_t>(player, 0);
  if (id < 0 || id >= kPlayers) {
    return -1;
  }
  Sync();
  return g_count[id];
}

void Change(const char* action, int delta, const wchar_t* what) {
  const char* world = World();
  const std::int32_t id = Field<std::int32_t>(action, 0x64);
  const std::int32_t tech = Field<std::int32_t>(action, 0x68);
  const char* player = PlayerById(world, id);
  if (id < 0 || id >= kPlayers || LimitOf(player) < 0 || !IsShipTech(StatusOf(world, id, tech))) {
    return;
  }
  Sync();
  g_count[id] += delta;
  if (g_count[id] < 0) {
    g_count[id] = 0;
  }
  g_dirty[id] = true;
  Line(L"player %d %ls tech %d: %d of %d (game time %u ms)", id, what, tech, g_count[id], LimitOf(player),
       Field<std::uint32_t>(world, 0x108));
}

bool Claim(const char*, const char*, const char*, float*, bool) { return false; }

void Started(char* action, float, bool) { Change(action, 1, L"paid shipment"); }

void Refunded(const char* action) { Change(action, -1, L"cancelled shipment"); }

bool Refuse(const char* status, const char* unit) {
  if (unit == nullptr || g_limit.empty()) {
    return false;
  }
  const char* player = Field<const char*>(unit, 0x44);
  std::int32_t limit = -1;
  if (player == nullptr || LimitOf(player) < 0 || !IsShipTech(status)) {
    return false;
  }
  return CountOf(player, &limit) >= limit;
}

void RolloverLine(const char* entry, const char* player, const char*, void* rollover, char* overlay) {
  std::int32_t limit = -1;
  if (player == nullptr || !IsShipTech(entry)) {
    return;
  }
  const std::int32_t count = CountOf(player, &limit);
  if (count < 0) {
    return;
  }
  wchar_t line[160];
  if (count >= limit) {
    swprintf_s(line, L"\n<color=1, 0.35, 0.35>Shipment techs: %d/%d, the limit is reached</color>", count, limit);
    if (overlay != nullptr && overlay[0] == '\0') {
      sprintf_s(overlay, 256, "%d/%d", count, limit);  // over the button, as researchGrants' price
    }
  } else {
    swprintf_s(line, L"\n<color=0.4, 1, 0.4>Shipment techs: %d/%d</color>", count, limit);
  }
  uhc::AppendTechRollover(rollover, line);
}

std::string Narrow(const wchar_t* text) {
  std::string out;
  for (; text != nullptr && *text != L'\0'; ++text) {
    out += *text < 0x80 ? static_cast<char>(*text) : '?';
  }
  return out;
}

void ReadLimit(const char* civ, std::int32_t civId, const wchar_t* text) {
  const std::string number = Narrow(text);
  char* end = nullptr;
  const long value = std::strtol(number.c_str(), &end, 10);
  while (end != nullptr && (*end == ' ' || *end == '\t' || *end == '\r' || *end == '\n')) {
    ++end;
  }
  const char* name = civ == nullptr ? nullptr : Field<const char*>(civ, 0x04);
  if (number.empty() || end == nullptr || *end != '\0' || value < 0 || value > 100000) {
    uhc::Log(L"shipTechLimit: civ %d (%hs): <ShipTechLimit> \"%hs\" is not a number from 0 to 100000; ignored", civId,
             name == nullptr ? "?" : name, number.c_str());
    return;
  }
  g_limit[civId] = static_cast<std::int32_t>(value);
  uhc::Log(L"shipTechLimit: civ %d (%hs): at most %ld shipment techs per game", civId, name == nullptr ? "?" : name,
           value);
}

}  // namespace

namespace uhc {

Outcome ApplyShipTechLimit(const Config& config) {
  const Config::Args* args = config.First("shipTechLimit");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "notext") == 0) {
      g_text = false;
    } else {
      Log(L"shipTechLimit: unknown option %hs (expected: [notext] [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  for (int p = 0; p < kPlayers; ++p) {
    g_carrier[p] = -1;
  }
  if (!VerifyAll("shipTechLimit", {&sites::kResListGet, &sites::kTechEntryLookup, &sites::kUnitAliveSlot}) ||
      !AddCivTagHandler("ShipTechLimit", &ReadLimit) || !AddResearchPayer("shipTechLimit", &Claim, &Started) ||
      !AddResearchRefundObserver("shipTechLimit", &Refunded) || !AddCanResearchFilter("shipTechLimit", &Refuse) ||
      !AddWorldTick(&Tick) || (g_text && !AddTechRolloverLine("shipTechLimit", &RolloverLine))) {
    return Outcome::kFailed;
  }
  Log(L"shipTechLimit: the civ tag <ShipTechLimit> is on%ls%ls (multiplayer unverified)",
      g_text ? L"; the tech rollover shows the count" : L"", g_log ? L"; logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
