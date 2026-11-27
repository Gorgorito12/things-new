// perCivEffects: onlyciv="<civ>" on any tech <Effect> makes that effect work only for a receiving player whose
// civilization is that one. For shared cards, shared techs and team techs: in a team tech each ally is checked on
// its own.
//
// - The effect parse FUN_00620572 is the only maker of tech effects (from the <Effect> handler 0x620472, which
//   appends the effect to the tech's [def+24h]); its success tail 0x6205EF has the effect and its node, for every
//   effect type. The key reads onlyciv there (0x598F37 / 0x402733, as multiarmor reads damagetype) into a table
//   effect -> civ name; an effect parsed again at the same address without it loses its entry.
// - Every tech effect is applied through the dispatcher 0x7F7E97 and removed through 0x7F8168, once per receiving
//   player (applyEffects 0x94DBE6, also for a team; the pass after a load 0x94DF10; removeEffects 0x94DDC8). Their
//   heads skip a listed effect when the player's first civ ([player+20h], uhc::FirstCivOfPlayer) is not the named
//   one. The decision is made on the receiving player only, never on the local player, so every machine agrees.
// - A player's civ can change in a game (the player Data subtype SetCivilization, 0x8D88CF -> 0x8D53EE), so the
//   decision taken at an apply is kept per effect and player, and the removal follows it: what was skipped is not
//   removed, what was applied is.
// - A civ name that is not in civs.xml: one log line with the tech, and the effect works for no one.
#include <windows.h>

#include <cstdint>
#include <cstring>
#include <map>
#include <mutex>
#include <string>
#include <unordered_map>
#include <utility>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../namelists.h"
#include "../patch.h"

extern "C" {
void UhcPerCivParseHook();
void UhcPerCivApplyHook();
void UhcPerCivRemoveHook();
std::uint32_t g_uhcPerCivCount = 0;  // entries in g_effects, read by the hooks without the lock
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
constexpr std::uint32_t kHandlerReturn = 0x006204BB;
constexpr int kMaxLogLines = 300;

using XmlAttribute = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlText = const char*(__thiscall*)(const void* text);
using CivIdByName = std::int32_t(__thiscall*)(char* database, const char* name);
const auto kXmlAttribute = reinterpret_cast<XmlAttribute>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlText>(0x00402733);
const auto kCivIdByName = reinterpret_cast<CivIdByName>(0x0058E71F);

struct Entry {
  std::string civ;            // as written in the data
  std::int32_t tech = -1;     // the tech's ID, for the log (-1: not known)
  const char* database = nullptr;  // the database civ was resolved against
  std::int32_t civCount = -1;
  std::int32_t civId = -1;    // -1: not a civ
  bool warned = false;
};

std::mutex g_lock;
std::unordered_map<const void*, Entry> g_effects;
std::map<std::pair<const void*, std::int32_t>, bool> g_applied;  // (effect, player ID) -> applied at the last apply
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

char* Database() {
  char* game = *reinterpret_cast<char**>(kGameGlobal);
  return game == nullptr ? nullptr : Field<char*>(game, 0x140);
}

const wchar_t* TechName(std::int32_t id) {
  const char* database = Database();
  if (database == nullptr || id < 0) {
    return L"?";
  }
  const wchar_t* const* names = Field<const wchar_t* const*>(database, 0x3824);
  if (names == nullptr || id >= Field<std::int32_t>(database, 0x3828) || names[id] == nullptr) {
    return L"?";
  }
  return names[id];
}

// The civ ID the entry names, resolved against the current civs.xml (again when it is read again). -1 before
// civs.xml is read, or for a name that is not a civ (logged once, with the tech).
std::int32_t CivId(Entry& entry) {
  char* database = Database();
  const std::int32_t count = database == nullptr ? 0 : Field<std::int32_t>(database, 0x28);
  if (count <= 0) {
    return -1;
  }
  if (database != entry.database || count != entry.civCount) {
    entry.database = database;
    entry.civCount = count;
    const std::int32_t id = kCivIdByName(database, entry.civ.c_str());
    entry.civId = id >= 0 && id < count ? id : -1;
    if (entry.civId < 0 && !entry.warned) {
      entry.warned = true;
      uhc::Log(L"perCivEffects: tech %d (%ls): onlyciv \"%hs\" is not a civ in civs.xml; the effect works for no one",
               entry.tech, TechName(entry.tech), entry.civ.c_str());
    }
  }
  return entry.civId;
}

void Note(const wchar_t* what, const Entry& entry, std::int32_t player, std::int32_t civ) {
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"perCivEffects: %ls tech %d (%ls), onlyciv %hs, player %d (civ %d)", what, entry.tech,
             TechName(entry.tech), entry.civ.c_str(), player, civ);
  }
}

}  // namespace

extern "C" {

// From the parse hook: the effect, its node, the return address of the parse and the slot that holds the tech's
// definition when that return address is the <Effect> handler's.
void __cdecl UhcPerCivParsed(const void* effect, const void* node, std::uint32_t ret, const void* def) {
  const void* text = nullptr;
  const char* name = nullptr;
  if (node != nullptr && kXmlAttribute(node, "onlyciv", &text) && text != nullptr) {
    name = kXmlText(text);
  }
  std::lock_guard<std::mutex> guard(g_lock);
  if (name == nullptr || *name == 0) {
    if (g_effects.erase(effect) != 0) {
      g_uhcPerCivCount = static_cast<std::uint32_t>(g_effects.size());
    }
    return;
  }
  Entry entry;
  entry.civ = name;
  if (ret == kHandlerReturn && def != nullptr) {
    entry.tech = Field<std::int32_t>(def, 0);
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"perCivEffects: tech %d: an effect for %hs only", entry.tech, name);
  }
  g_effects[effect] = std::move(entry);
  g_uhcPerCivCount = static_cast<std::uint32_t>(g_effects.size());
}

// From the apply head: false skips the effect for this player.
bool __cdecl UhcPerCivAllowApply(const void* effect, const char* player, std::int32_t techId) {
  std::lock_guard<std::mutex> guard(g_lock);
  const auto found = g_effects.find(effect);
  if (found == g_effects.end() || player == nullptr) {
    return true;
  }
  Entry& entry = found->second;
  if (entry.tech < 0) {
    entry.tech = techId;
  }
  const std::int32_t want = CivId(entry);
  const std::int32_t civ = uhc::FirstCivOfPlayer(player);
  const bool apply = want >= 0 && civ == want;
  const std::int32_t playerId = Field<std::int32_t>(player, 0);
  g_applied[{effect, playerId}] = apply;
  Note(apply ? L"apply" : L"skip", entry, playerId, civ);
  return apply;
}

// From the removal head: removes what the last apply to this player applied; with no apply seen (none in this
// session), decides by the player's civ now.
bool __cdecl UhcPerCivAllowRemove(const void* effect, const char* player) {
  std::lock_guard<std::mutex> guard(g_lock);
  const auto found = g_effects.find(effect);
  if (found == g_effects.end() || player == nullptr) {
    return true;
  }
  Entry& entry = found->second;
  const std::int32_t playerId = Field<std::int32_t>(player, 0);
  const std::int32_t civ = uhc::FirstCivOfPlayer(player);
  bool remove;
  const auto seen = g_applied.find({effect, playerId});
  if (seen != g_applied.end()) {
    remove = seen->second;
    g_applied.erase(seen);
  } else {
    const std::int32_t want = CivId(entry);
    remove = want >= 0 && civ == want;
  }
  Note(remove ? L"remove" : L"keep skipped", entry, playerId, civ);
  return remove;
}

}  // extern "C"

namespace uhc {

Outcome ApplyPerCivEffects(const Config& config) {
  const Config::Args* args = config.First("perCivEffects");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"perCivEffects: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("perCivEffects", {&sites::kPerCivEffectParsed, &sites::kPerCivEffectCaller,
                                   &sites::kPerCivApplyHead, &sites::kPerCivRemoveHead}) ||
      !WriteJmp(sites::kPerCivEffectParsed.va, reinterpret_cast<const void*>(&UhcPerCivParseHook), 5) ||
      !WriteJmp(sites::kPerCivApplyHead.va, reinterpret_cast<const void*>(&UhcPerCivApplyHook), 6) ||
      !WriteJmp(sites::kPerCivRemoveHead.va, reinterpret_cast<const void*>(&UhcPerCivRemoveHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"perCivEffects: the Effect attribute onlyciv is on (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
