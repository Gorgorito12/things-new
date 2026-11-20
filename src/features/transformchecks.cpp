// transformChecks [log]: transform buttons (uiTransformSelectedUnit) grey out with the reason when no selected unit
// can transform, and a transform respects the target's build limit.
//
// Stock: uiTransformSelectedUnit("Proto") (0x7E7193) sends a network command (type 17h) for the selection. Every
// machine runs its per-unit execute FUN_007D64F7 for each selected unit on its own: the player's copy of the target
// proto and its cost (0x480B1E); the unit alive and its owner the command's player; the world placement check PLACE
// (world vtable +14h, FUN_0050703D) with the target proto at the unit's position, which applies the target's
// PlacementFile rules (a distanceatmostfromtype from a kraal too) and its AllowedAge; the payment 0x8D946A (or the
// "not enough resources" message); the new unit, built, at the unit's place; the old unit removed. Nothing tests the
// target's BuildLimit, and a refused unit gives no sign: the button is always enabled, and a click that fails does
// nothing.
//
// The key:
// - in the simulation (hooks/transformchecks_hooks.asm, at 0x7D65E3 after PLACE succeeded): a target whose limit
//   (0x4C7B5F on the player's copy) the player's living units of that proto already reach is refused as PLACE
//   refuses it (0x7D6762), before the payment. The count walks the player's unit list [player+F8h] (count +FCh): the
//   same on every machine, and units transformed earlier in the same command count, since each is created at once;
// - in the command panel (the shared button hook, panelbuttons.h): a button whose command is
//   uiTransformSelectedUnit("Proto") (its click, or the record's command for a click commandResearch(ID, unit), the
//   form a command with an <associatedtech> takes) asks, for each of the local player's selected units, the checks
//   the command makes (the cost of that many units and its affordability 0x8D6BAE / 0x8D6C1B, the build limit,
//   PLACE with the same arguments). With no
//   unit that passes, the button is disabled, its click and shift-click emptied, and its rollover gets the reason in
//   red: the failing placement rule's error string when PLACE gives one, else "Other objects prevent you..." (25528),
//   "Not enough resources" (41543) or the build limit (36198). With some that pass, the rollover says how many. The
//   answer is kept 250 ms per button (real time): the panel is interface only, so nothing here reaches the game.
#include <windows.h>

#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <map>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../panelbuttons.h"
#include "../patch.h"

extern "C" void UhcXformPlaceHook();

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database, +3C0h the local player
constexpr DWORD kCacheMs = 250;
constexpr int kMaxLogLines = 200;

using PlayerByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using UnitByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using PlayerProtoFn = char*(__thiscall*)(const char* player, std::int32_t protoId);
using ProtoByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using BuildLimitFn = std::int32_t(__thiscall*)(const char* player, const char* proto);
using CostListFn = void(__thiscall*)(void* list);
using CostGetFn = bool(__thiscall*)(const char* player, std::int32_t protoId, void* cost, std::int32_t count);
using AffordFn = bool(__thiscall*)(const char* player, const void* cost);
using SelectionFn = const char*(__cdecl*)();
using AliveFn = bool(__thiscall*)(const char* unit);
using PlaceFn = bool(__thiscall*)(const char* world, std::int32_t protoId, std::int32_t playerId, const float* pos,
                                  const float* forward, const float* right, std::int32_t a5, std::int32_t flags,
                                  std::int32_t* reason, std::int32_t a8, std::int32_t a9, std::int32_t a10);
using BStringFromIdFn = void*(__thiscall*)(void* text, std::int32_t id);
using BStringFreeFn = void(__thiscall*)(void* text);
using AppendFn = void(__thiscall*)(void* text, const wchar_t* more, std::int32_t length, std::int32_t start);

const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kProtoByName = reinterpret_cast<ProtoByNameFn>(0x005A2346);
const auto kBuildLimit = reinterpret_cast<BuildLimitFn>(0x004C7B5F);
const auto kCostCtor = reinterpret_cast<CostListFn>(0x0044717F);
const auto kCostDtor = reinterpret_cast<CostListFn>(0x0044C817);
const auto kCostGet = reinterpret_cast<CostGetFn>(0x00480B1E);
const auto kAfford = reinterpret_cast<AffordFn>(0x008D6BAE);
const auto kSharedAfford = reinterpret_cast<AffordFn>(0x008D6C1B);
const auto kSelection = reinterpret_cast<SelectionFn>(0x00453B28);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kAppend = reinterpret_cast<AppendFn>(0x00443960);

constexpr std::int32_t kStringObjects = 25528;      // "Other objects prevent you from placing this here."
constexpr std::int32_t kStringResources = 41543;    // "Not enough resources"
constexpr std::int32_t kStringBuildLimit = 36198;   // "You are at the build limit for the %s."
constexpr std::uint32_t kProtoDisplayName = 0x140;  // the proto's DisplayNameID (read in game)

bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

bool Alive(const char* unit) {
  const auto alive = reinterpret_cast<AliveFn>(Field<const void* const*>(unit, 0)[0xA4 / 4]);
  return alive(unit);
}

void Note(const wchar_t* format, ...) {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return;
  }
  ++g_logLines;
  wchar_t text[512];
  va_list args;
  va_start(args, format);
  _vsnwprintf_s(text, _TRUNCATE, format, args);
  va_end(args);
  uhc::Log(L"%ls", text);
}

// The player's living units of a proto ID: its unit list [player+F8h] (IDs, count +FCh).
std::int32_t CountLiving(const char* world, const char* player, std::int32_t protoId) {
  const auto* ids = Field<const std::int32_t*>(player, 0xF8);
  const std::int32_t count = Field<std::int32_t>(player, 0xFC);
  std::int32_t living = 0;
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    const char* unit = kUnitById(world, ids[i]);
    const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    if (proto != nullptr && Field<std::int32_t>(proto, 8) == protoId && Alive(unit)) {
      ++living;
    }
  }
  return living;
}

// The limit left for the player's copy of a proto: -1 when it has none.
std::int32_t LimitLeft(const char* world, const char* player, const char* playerProto) {
  const std::int32_t limit = kBuildLimit(player, playerProto);
  if (limit < 0) {
    return -1;
  }
  const std::int32_t left = limit - CountLiving(world, player, Field<std::int32_t>(playerProto, 8));
  return left < 0 ? 0 : left;
}

std::wstring StringById(std::int32_t id) {
  struct BString {
    const wchar_t* text;
  } text{nullptr};
  kBStringFromId(&text, id);
  std::wstring copy = text.text == nullptr ? L"" : text.text;
  kBStringFree(&text);
  return copy;
}

// ---- The command panel --------------------------------------------------------------------------------------------

struct Verdict {
  std::int32_t total = 0;  // the local player's selected units
  std::int32_t pass = 0;   // those that would transform
  std::wstring reason;     // why the first refused one is refused
};

struct Cached {
  DWORD at = 0;
  std::string selection;  // the selection's player and IDs when it was asked
  Verdict verdict;
};
std::map<std::string, Cached> g_cache;  // by target name

std::string SelectionKey(const char* selection) {
  std::string key;
  if (selection == nullptr) {
    return key;
  }
  const std::int32_t count = Field<std::int32_t>(selection, 0x14);
  const auto* ids = Field<const std::int32_t*>(selection, 0x10);
  key.append(reinterpret_cast<const char*>(selection + 0x0C), 4);
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    key.append(reinterpret_cast<const char*>(&ids[i]), 4);
  }
  return key;
}

Verdict Judge(const std::string& name) {
  Verdict verdict;
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* db = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  const char* selection = kSelection();
  if (world == nullptr || db == nullptr || selection == nullptr) {
    return verdict;
  }
  const std::int32_t local = Field<std::int32_t>(game, 0x3C0);
  if (Field<std::int32_t>(selection, 0x0C) != local) {
    return verdict;
  }
  const char* player = kPlayerById(world, local);
  const std::int32_t protoId = kProtoByName(db, name.c_str());
  const char* playerProto = player == nullptr || protoId < 0 ? nullptr : kPlayerProto(player, protoId);
  if (playerProto == nullptr) {
    return verdict;
  }

  // The cost of one more unit: the units accepted so far pay first, as the command pays them in turn.
  const auto affordable = [&](std::int32_t units) {
    std::uint32_t cost[4] = {};
    kCostCtor(cost);
    bool ok = kCostGet(player, protoId, cost, units);
    if (ok) {
      ok = Field<std::uint8_t>(world, 0x6912) != 0 ? kSharedAfford(player, cost) : kAfford(player, cost);
    }
    kCostDtor(cost);
    return ok;
  };
  std::int32_t left = LimitLeft(world, player, playerProto);

  const std::int32_t count = Field<std::int32_t>(selection, 0x14);
  const auto* ids = Field<const std::int32_t*>(selection, 0x10);
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    const char* unit = kUnitById(world, ids[i]);
    const char* owner = unit == nullptr ? nullptr : Field<const char*>(unit, 0x44);
    if (owner == nullptr || Field<std::int32_t>(owner, 0) != local || !Alive(unit)) {
      continue;
    }
    ++verdict.total;
    std::int32_t reasonId = -1;
    if (!affordable(verdict.pass + 1)) {
      reasonId = kStringResources;
    } else if (left == 0) {
      reasonId = kStringBuildLimit;
    } else {
      std::int32_t placeReason = -1;
      const auto place = reinterpret_cast<PlaceFn>(Field<const void* const*>(world, 0)[0x14 / 4]);
      if (!place(world, protoId, local, reinterpret_cast<const float*>(unit + 0x14),
                 reinterpret_cast<const float*>(unit + 0x20), reinterpret_cast<const float*>(unit + 0x38), 0, 2,
                 &placeReason, 0, 0, 0)) {
        reasonId = placeReason > 0 ? placeReason : kStringObjects;
      }
    }
    if (reasonId < 0) {
      ++verdict.pass;
      if (left > 0) {
        --left;
      }
      continue;
    }
    if (verdict.reason.empty()) {
      verdict.reason = StringById(reasonId);
      if (reasonId == kStringBuildLimit) {
        wchar_t text[256];
        const std::wstring display = StringById(Field<std::int32_t>(playerProto, kProtoDisplayName));
        swprintf_s(text, verdict.reason.c_str(), display.c_str());
        verdict.reason = text;
      }
      if (verdict.reason.empty()) {
        verdict.reason = StringById(kStringObjects);
      }
    }
  }
  return verdict;
}

// "uiTransformSelectedUnit("Name")" -> Name; false for any other command.
bool TargetName(const std::string& command, std::string* name) {
  const char* click = command.c_str();
  static const char kPrefix[] = "uiTransformSelectedUnit(";
  if (_strnicmp(click, kPrefix, sizeof(kPrefix) - 1) != 0) {
    return false;
  }
  const char* open = std::strchr(click + sizeof(kPrefix) - 1, '"');
  const char* close = open == nullptr ? nullptr : std::strchr(open + 1, '"');
  if (close == nullptr || close == open + 1) {
    return false;
  }
  name->assign(open + 1, close);
  return true;
}

// The command a button runs: its click, or, for a command with an <associatedtech> (whose click is
// "commandResearch(<command ID>, <unit ID>)"), the <command> of its record in [db+2968h] (4Ch B each, count +296Ch;
// the record's first dword the wide text).
std::string ButtonCommand(const char* click) {
  static const char kPrefix[] = "commandResearch(";
  if (_strnicmp(click, kPrefix, sizeof(kPrefix) - 1) != 0) {
    return click;
  }
  const std::int32_t id = std::atoi(click + sizeof(kPrefix) - 1);
  const char* game = Game();
  const char* db = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  const char* records = db == nullptr ? nullptr : Field<const char*>(db, 0x2968);
  if (records == nullptr || id < 0 || id >= Field<std::int32_t>(db, 0x296C)) {
    return "";
  }
  const wchar_t* text = Field<const wchar_t*>(records + 0x4C * id, 0);
  std::string narrow;
  for (; text != nullptr && *text != 0 && narrow.size() < 256; ++text) {
    narrow.push_back(*text < 0x80 ? static_cast<char>(*text) : '?');
  }
  return narrow;
}

void TransformButton(const uhc::PanelButton& button) {
  std::string name;
  if (!TargetName(ButtonCommand(button.Click()), &name)) {
    return;
  }
  const DWORD now = GetTickCount();
  const std::string key = SelectionKey(kSelection());
  Cached& cached = g_cache[name];
  if (cached.at == 0 || now - cached.at >= kCacheMs || cached.selection != key) {
    Verdict fresh = Judge(name);
    if (fresh.pass != cached.verdict.pass || fresh.total != cached.verdict.total ||
        fresh.reason != cached.verdict.reason) {
      Note(L"transformChecks: button %hs: %d of %d selected unit(s) can transform%ls%ls", name.c_str(), fresh.pass,
           fresh.total, fresh.reason.empty() ? L"" : L"; ", fresh.reason.c_str());
    }
    cached.verdict = fresh;
    cached.at = now == 0 ? 1 : now;
    cached.selection = key;
  }
  const Verdict& verdict = cached.verdict;
  if (verdict.total == 0 || verdict.pass == verdict.total) {
    return;
  }
  std::wstring line;
  if (verdict.pass == 0) {
    button.State() = 1;
    button.Click()[0] = 0;
    button.ShiftClick()[0] = 0;
    line = L"\n<color=1, 0.35, 0.35>" + verdict.reason + L"</color>";
  } else {
    wchar_t text[96];
    swprintf_s(text, L"\n<color=1, 0.8, 0.3>%d / %d: </color>", verdict.pass, verdict.total);
    line = text + verdict.reason;
  }
  kAppend(button.Rollover(), line.c_str(), -1, -1);
}

}  // namespace

extern "C" {

// From the hook at 0x7D65E3, after PLACE accepted the target at the unit's place: false refuses the transform as
// PLACE does. Simulation code: the same answer on every machine.
bool __stdcall UhcXformAllowed(const char* player, const char* playerProto, const char* unit) {
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr || player == nullptr || playerProto == nullptr) {
    return true;
  }
  const char* name = Field<const char*>(playerProto, 0x10);
  const std::int32_t unitId = unit == nullptr ? -1 : Field<std::int32_t>(unit, 0x10);
  if (LimitLeft(world, player, playerProto) != 0) {
    return true;
  }
  Note(L"transformChecks: unit %d of player %d refused: at the build limit of %hs (%d)", unitId,
       Field<std::int32_t>(player, 0), name == nullptr ? "?" : name, kBuildLimit(player, playerProto));
  return false;
}

}  // extern "C"

namespace uhc {

Outcome ApplyTransformChecks(const Config& config) {
  const Config::Args* args = config.First("transformChecks");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"transformChecks: unknown argument %hs (expected: log); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("transformChecks",
                 {&sites::kXformExecBody, &sites::kXformPlaceTest, &sites::kXformRefuse, &sites::kCostListCtor,
                  &sites::kCostListDtor, &sites::kPlayerById, &sites::kUnitById, &sites::kPlayerProtoEntry,
                  &sites::kProtoByName, &sites::kBuildLimitEntry, &sites::kPayAffordCheck,
                  &sites::kPaySharedAffordCheck, &sites::kCurrentSelectionGroup, &sites::kBStringFromId,
                  &sites::kBStringAppend})) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!WriteJmp(sites::kXformPlaceTest.va, reinterpret_cast<const void*>(&UhcXformPlaceHook), 8)) {
    return Outcome::kFailed;
  }
  if (!AddPanelButtonFilter(&TransformButton)) {
    Log(L"transformChecks: the command panel's buttons are taken; the build limit applies, the buttons stay as they "
        L"are");
  }
  Log(L"transformChecks: uiTransformSelectedUnit buttons grey out with the reason, and a transform respects the "
      L"target's build limit%ls (multiplayer unverified)",
      log ? L", refusals logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
