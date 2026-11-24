// techGadgets <tech> <gadgetAfter> [<gadgetBefore>] (repeatable), and techGadgets log: ties interface gadgets to a
// tech of the player the interface shows ([game+3C0h], the player {resource()} reads): once the tech is active
// (0x94AF27, thiscall([world+7Ch], player, tech)) gadgetAfter is shown and gadgetBefore hidden; before, the reverse.
// Nothing is written while there is no game; with the key off the layout's own defaults stay.
// - The tech state is read in the world update (worldtick.h), every 100 ms of game time, by tech ID (0x600BE1 on
//   the database [game+140h], again after each data load), and kept per rule with the world it belongs to.
// - The gadgets are set from Direct3D's Present (d3d9hooks.h), every frame: each is found by name in any panel
//   (0x433A2C, what gadgetReal / gadgetUnreal use), its handle kept until it goes stale (the handles carry a
//   generation, so a rebuilt interface resolves to no gadget and the name is looked up again, at most every 2 s
//   while missing). A gadget is shown or hidden (0x447F7B / 0x448F13) only when its flags [gadget+0A4h] say it is
//   in the other state, so an interface rebuilt while the game is paused, or a gadget the engine shows again, is
//   corrected on the next frame; with `log`, the latter is logged. Without the Present observer (another DLL took
//   the Direct3D import) the gadgets are set from the world update instead.
#include <windows.h>

#include <cstdint>
#include <string>
#include <vector>

#include "../d3d9hooks.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../uigadgets.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace {

using TechByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using TechActiveFn = bool(__thiscall*)(const char* techStatus, std::int32_t playerId, std::int32_t techId);
const auto kTechByName = reinterpret_cast<TechByNameFn>(0x00600BE1);
const auto kTechActive = reinterpret_cast<TechActiveFn>(0x0094AF27);
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database, +3C0h the shown player
constexpr std::int32_t kTickMs = 100;
constexpr DWORD kRetryMs = 2000;
constexpr int kMaxLogLines = 300;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Slot {
  std::string name;  // empty: none
  std::int32_t handle = 0;
  DWORD lastLookup = 0;
  bool looked = false;
  bool missingLogged = false;
  int setTo = -1;  // what the key last set: 1 shown, 0 hidden, -1 nothing yet
};

struct Rule {
  std::string tech;
  std::int32_t techId = -1;
  int generation = -1;
  Slot after;
  Slot before;
  int active = -1;  // -1 unknown (no game yet), 0 before the tech, 1 after
};

std::vector<Rule> g_rules;
int g_generation = 0;
bool g_log = false;
int g_logLines = 0;
bool g_present = false;
const char* g_world = nullptr;  // the world the rules' states belong to
std::int32_t g_player = -1;
std::int32_t g_elapsed = kTickMs;

void LogLine(const wchar_t* format, const char* a, const char* b = "") {
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(format, a, b);
  }
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* CurrentWorld() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

void NewDatabase(char*) { ++g_generation; }

// The gadget's handle, looked up again when it went stale (at most every 2 s while missing); 0 if none.
std::int32_t Resolve(Slot& slot) {
  if (slot.name.empty()) {
    return 0;
  }
  if (slot.handle != 0 && uhc::ui::Gadget(slot.handle, uhc::ui::kAnyGadget) != nullptr) {
    return slot.handle;
  }
  const DWORD now = GetTickCount();
  if (slot.looked && slot.handle == 0 && now - slot.lastLookup < kRetryMs) {
    return 0;
  }
  slot.looked = true;
  slot.lastLookup = now;
  slot.handle = uhc::ui::FindAnywhere(slot.name.c_str());
  slot.setTo = -1;
  if (slot.handle == 0 && !slot.missingLogged) {
    slot.missingLogged = true;
    LogLine(L"techGadgets: no gadget named %hs yet (looked up again every 2 s)%hs", slot.name.c_str());
  } else if (slot.handle != 0) {
    slot.missingLogged = false;
    LogLine(L"techGadgets: gadget %hs found%hs", slot.name.c_str());
  }
  return slot.handle;
}

void Apply(Slot& slot, bool visible) {
  const std::int32_t handle = Resolve(slot);
  if (handle == 0) {
    return;
  }
  const int state = uhc::ui::ShownState(handle);
  const int want = visible ? 1 : 0;
  if (state == want) {
    slot.setTo = want;
    return;
  }
  if (slot.setTo == want) {
    LogLine(L"techGadgets: %hs was %hs by the game; set again", slot.name.c_str(), visible ? "hidden" : "shown");
  }
  uhc::ui::Show(handle, visible);
  slot.setTo = want;
}

// Sets every rule's gadgets from its last tech state, when that state belongs to the current world.
void ApplyAll() {
  const char* world = CurrentWorld();
  if (world == nullptr || world != g_world || uhc::ui::Manager() == nullptr) {
    return;
  }
  for (Rule& rule : g_rules) {
    if (rule.active < 0) {
      continue;
    }
    Apply(rule.after, rule.active == 1);
    Apply(rule.before, rule.active == 0);
  }
}

void BeforePresent() { ApplyAll(); }

// The world update: the tech states every 100 ms of game time, at once in a new world or for another player.
void Tick(char* world, std::int32_t deltaMs) {
  const char* game = Game();
  if (game == nullptr || world == nullptr) {
    return;
  }
  const std::int32_t player = Field<std::int32_t>(game, 0x3C0);
  const bool fresh = world != g_world || player != g_player;
  g_elapsed += deltaMs;
  if (!fresh && g_elapsed < kTickMs) {
    return;
  }
  g_elapsed = 0;
  if (fresh) {
    static bool reached = false;
    if (!reached) {
      reached = true;
      uhc::Log(L"techGadgets: first tech check (player %d)", player);
    }
    for (Rule& rule : g_rules) {
      rule.active = -1;
    }
    g_world = world;
    g_player = player;
  }
  const char* database = Field<const char*>(game, 0x140);
  const char* techStatus = Field<const char*>(world, 0x7C);
  if (database == nullptr || techStatus == nullptr || player < 0) {
    return;
  }
  for (Rule& rule : g_rules) {
    if (rule.generation != g_generation) {
      rule.generation = g_generation;
      rule.techId = kTechByName(database, rule.tech.c_str());
      if (rule.techId < 0) {
        uhc::Log(L"techGadgets: no tech named %hs; its gadgets are left as they are", rule.tech.c_str());
      }
    }
    if (rule.techId < 0) {
      continue;
    }
    const int active = kTechActive(techStatus, player, rule.techId) ? 1 : 0;
    if (active != rule.active) {
      if (g_log && g_logLines < kMaxLogLines) {
        ++g_logLines;
        uhc::Log(L"techGadgets: player %d, %hs %hs: %hs shown%hs%hs", player, rule.tech.c_str(),
                 active ? "active" : "not active", active ? rule.after.name.c_str() : rule.before.name.c_str(),
                 (active ? rule.before.name : rule.after.name).empty() ? "" : ", hidden: ",
                 active ? rule.before.name.c_str() : rule.after.name.c_str());
      }
      rule.active = active;
    }
  }
  if (!g_present) {
    ApplyAll();
  }
}

}  // namespace

namespace uhc {

Outcome ApplyTechGadgets(const Config& config) {
  const auto* lines = config.All("techGadgets");
  if (lines == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const Config::Args& args : *lines) {
    if (args.size() == 1 && _stricmp(args[0].c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    if (args.size() < 2 || args.size() > 3) {
      Log(L"techGadgets: a line needs <tech> <gadget shown after it> [<gadget shown before it>] (or log); "
          L"line with %u argument(s) ignored",
          static_cast<unsigned>(args.size()));
      continue;
    }
    Rule rule;
    rule.tech = args[0];
    rule.after.name = args[1];
    if (args.size() == 3) {
      rule.before.name = args[2];
    }
    g_rules.push_back(rule);
  }
  if (g_rules.empty()) {
    Log(L"techGadgets: no rule; not applied");
    return Outcome::kFailed;
  }
  if (!ui::VerifyUiGadgets("techGadgets") || !ui::VerifyUiShow("techGadgets") ||
      !VerifyAll("techGadgets", {&sites::kUiFindAnywhere, &sites::kTechActive, &sites::kTechByName})) {
    return Outcome::kFailed;
  }
  if (!OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  g_present = AddD3D9Observer({nullptr, nullptr, &BeforePresent, nullptr}, "techGadgets");
  if (!g_present) {
    Log(L"techGadgets: no Present observer; the gadgets are set from the world update (not while paused)");
  }
  for (const Rule& rule : g_rules) {
    Log(L"techGadgets: with %hs active for the shown player: %hs shown%hs%hs", rule.tech.c_str(),
        rule.after.name.c_str(), rule.before.name.empty() ? "" : ", before it: ", rule.before.name.c_str());
  }
  Log(L"techGadgets: %u rule(s)%ls (interface only)", static_cast<unsigned>(g_rules.size()),
      g_log ? L", changes logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
