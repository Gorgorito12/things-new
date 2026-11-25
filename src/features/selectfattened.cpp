// selectFattened [gadget <name>]... [log]: a button and a hotkey that select the local player's fattened herdables.
//
// - The UI syscall `uhcSelectFattened()` (a button's or a keymap entry's <command>) selects, on the whole map, the
//   herdables (abstract index 37h, 0x44CAC4) of the local player ([game+3C0h]) whose inventory is full: the engine's
//   own test 0x4DC520 (a resource held at or above its carry capacity), the "full" a fattened herdable stops at. It
//   repeats what the stock UI command uiFindAllOfType (0x7E7AB9) does: the selection 0x4051B6, emptied with 0x9301D3
//   (from 0), and per unit the same tests (state byte [unit+88h] from 8, the unit's vtable +0A4h, not inside another
//   unit: [unit+6Ch] < 0), then the add, the selection's vtable +4 (FUN_0079F534, checked before the call) with a
//   handle {0B9E444h, 0, unit ID}; it refuses a unit past the selection limit (the getter 0x4E0BEE, which
//   selectionLimit rewrites) or already in. Over that limit the key adds the herdables nearest the camera's line
//   of sight first (the screen centre: [game+148h], position +4, forward +10h). With none, the selection stays.
// - {uhcFattened}: their number, a text data ref (datarefs.h) for the button's label.
// - The count runs in the world update (worldtick.h) every 100 ms of game time, never per frame. The gadgets named on
//   the cfg line (default uhcFattened) are shown while it is above 0 and hidden at 0, from Direct3D's Present like
//   techGadgets (uigadgets.h), or from the world update without the Present observer.
// Interface only: the selection is the local player's, as a click; nothing goes to the network or the simulation.
#include <windows.h>

#include <algorithm>
#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

#include "../d3d9hooks.h"
#include "../datarefs.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../syscalls.h"
#include "../uigadgets.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +148h camera, +3C0h the local player
constexpr std::uint32_t kHandleVtable = 0x00B9E444;
constexpr std::uint32_t kSelectionAdd = 0x0079F534;  // the selection's vtable +4 (vtable 0xB9F8C4)
constexpr std::uint32_t kSelectionCapGetter = 0x004E0BEE;  // mov eax,32h / ret (selectionLimit writes the imm32)
constexpr std::int32_t kHerdableIndex = 0x37;
constexpr std::int32_t kStockCap = 50;
constexpr std::int32_t kTickMs = 100;
constexpr std::int32_t kMaxUnits = 100000;  // sanity bound on the player's unit list
constexpr DWORD kRetryMs = 2000;
constexpr int kMaxLogLines = 300;

using SelectionOfGameFn = char*(__thiscall*)(const char* game);
using SelectionClearFn = void(__thiscall*)(char* selection, std::int32_t from);
using SelectionAddFn = void(__thiscall*)(char* selection, const void* handle);  // vtable +4, ret 4
using SelectableFn = bool(__thiscall*)(const char* unit);                      // the unit's vtable +0A4h
using UnitByIdFn = char*(__thiscall*)(const void* world, std::int32_t id);
using PlayerByIdFn = char*(__thiscall*)(const void* world, std::int32_t id);
using IsAbstractIndexFn = bool(__thiscall*)(const void* proto, std::int32_t index);
using IsFullFn = bool(__thiscall*)(const void* inventory);
using BStringAssignFn = void(__thiscall*)(wchar_t** self, const void* source, std::int32_t, std::int32_t);
const auto kSelectionOfGame = reinterpret_cast<SelectionOfGameFn>(0x004051B6);
const auto kSelectionClear = reinterpret_cast<SelectionClearFn>(0x009301D3);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kIsAbstractIndex = reinterpret_cast<IsAbstractIndexFn>(0x0044CAC4);
const auto kIsFull = reinterpret_cast<IsFullFn>(0x004DC520);
const auto kBStringAssign = reinterpret_cast<BStringAssignFn>(0x00443BB8);

// The stack handle the stock command passes to the selection's add.
struct UnitHandle {
  std::uint32_t vtable;
  std::int32_t zero;
  std::int32_t id;
};

struct BString {
  const wchar_t* text;
};

struct Slot {
  std::string name;
  std::int32_t handle = 0;
  DWORD lastLookup = 0;
  bool looked = false;
  bool missingLogged = false;
};

std::vector<Slot> g_slots;
bool g_log = false;
int g_logLines = 0;
bool g_present = false;
const char* g_world = nullptr;  // the world g_count belongs to
std::int32_t g_player = -1;
std::int32_t g_count = -1;  // -1: not counted yet in this world
std::int32_t g_elapsed = kTickMs;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* World(const char* game) { return game == nullptr ? nullptr : Field<const char*>(game, 0x13C); }

void LogLine(const wchar_t* format, ...) {
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

// The tests of uiFindAllOfType's loop, then a herdable with a full inventory.
bool Fattened(const char* unit) {
  if (unit == nullptr || Field<std::uint8_t>(unit, 0x88) < 8 || Field<std::int32_t>(unit, 0x6C) >= 0) {
    return false;
  }
  const void* proto = Field<const void*>(unit, 0x5C);
  if (proto == nullptr || !kIsAbstractIndex(proto, kHerdableIndex)) {
    return false;
  }
  const char* data = Field<const char*>(unit, 0xB4);
  const void* inventory = data == nullptr ? nullptr : Field<const void*>(data, 0x94);
  if (inventory == nullptr || !kIsFull(inventory)) {
    return false;
  }
  const auto selectable = reinterpret_cast<SelectableFn>(Field<const void* const*>(unit, 0)[0xA4 / 4]);
  return selectable(unit);
}

// The local player's fattened herdables, by unit pointer.
void Collect(const char* game, std::vector<const char*>* out) {
  const char* world = World(game);
  if (world == nullptr) {
    return;
  }
  const std::int32_t playerId = Field<std::int32_t>(game, 0x3C0);
  const char* player = playerId < 0 ? nullptr : kPlayerById(world, playerId);
  if (player == nullptr) {
    return;
  }
  const std::int32_t* ids = Field<const std::int32_t*>(player, 0xF8);
  const std::int32_t count = Field<std::int32_t>(player, 0xFC);
  if (ids == nullptr || count <= 0 || count > kMaxUnits) {
    return;
  }
  for (std::int32_t i = 0; i < count; ++i) {
    const char* unit = ids[i] < 0 ? nullptr : kUnitById(world, ids[i]);
    if (Fattened(unit)) {
      out->push_back(unit);
    }
  }
}

std::int32_t SelectionCap() {
  const auto* code = reinterpret_cast<const std::uint8_t*>(kSelectionCapGetter);
  if (code[0] != 0xB8 || code[5] != 0xC3) {
    return kStockCap;
  }
  const std::int32_t cap = *reinterpret_cast<const std::int32_t*>(code + 1);
  return cap > 0 ? cap : kStockCap;
}

// Squared distance from the unit to the camera's line of sight, or 0 without a camera.
float AxisDistance2(const char* camera, const char* unit) {
  if (camera == nullptr) {
    return 0.0f;
  }
  const float* eye = reinterpret_cast<const float*>(camera + 0x04);
  const float* forward = reinterpret_cast<const float*>(camera + 0x10);
  const float* at = reinterpret_cast<const float*>(unit + 0x14);
  const float v[3] = {at[0] - eye[0], at[1] - eye[1], at[2] - eye[2]};
  const float ff = forward[0] * forward[0] + forward[1] * forward[1] + forward[2] * forward[2];
  if (!(ff > 1e-6f)) {
    return 0.0f;
  }
  const float t = (v[0] * forward[0] + v[1] * forward[1] + v[2] * forward[2]) / ff;
  const float d[3] = {v[0] - t * forward[0], v[1] - t * forward[1], v[2] - t * forward[2]};
  return d[0] * d[0] + d[1] * d[1] + d[2] * d[2];
}

void __cdecl UhcSelectFattened() {
  static bool reached = false;
  const char* game = Game();
  char* selection = game == nullptr || World(game) == nullptr ? nullptr : kSelectionOfGame(game);
  if (selection == nullptr) {
    return;
  }
  std::vector<const char*> units;
  Collect(game, &units);
  const std::int32_t cap = SelectionCap();
  if (!reached) {
    reached = true;
    uhc::Log(L"hook reached: selectFattened uhcSelectFattened (player %d: %u fattened)",
             Field<std::int32_t>(game, 0x3C0), static_cast<unsigned>(units.size()));
  }
  if (units.empty()) {
    LogLine(L"selectFattened: no fattened herdable; the selection is left as it was");
    return;
  }
  const char* camera = Field<const char*>(game, 0x148);
  const auto found = static_cast<std::int32_t>(units.size());
  if (found > cap) {
    std::vector<std::pair<float, const char*>> byDistance;
    byDistance.reserve(units.size());
    for (const char* unit : units) {
      byDistance.emplace_back(AxisDistance2(camera, unit), unit);
    }
    std::stable_sort(byDistance.begin(), byDistance.end(),
                     [](const auto& a, const auto& b) { return a.first < b.first; });
    units.clear();
    for (std::int32_t i = 0; i < cap; ++i) {
      units.push_back(byDistance[static_cast<std::size_t>(i)].second);
    }
    LogLine(L"selectFattened: over the limit: the farthest kept is %.1f m from the screen centre's line, the nearest "
            L"left out %.1f m",
            std::sqrt(static_cast<double>(byDistance[static_cast<std::size_t>(cap) - 1].first)),
            std::sqrt(static_cast<double>(byDistance[static_cast<std::size_t>(cap)].first)));
  }
  const void* addSlot = Field<const void* const*>(selection, 0)[1];
  if (addSlot != reinterpret_cast<const void*>(kSelectionAdd)) {
    static bool warned = false;
    if (!warned) {
      warned = true;
      uhc::Log(L"selectFattened: the selection's add is 0x%08X, not the stock 0x%08X; nothing selected",
               reinterpret_cast<std::uint32_t>(addSlot), kSelectionAdd);
    }
    return;
  }
  kSelectionClear(selection, 0);
  const auto add = reinterpret_cast<SelectionAddFn>(addSlot);
  for (const char* unit : units) {
    const UnitHandle handle{kHandleVtable, 0, Field<std::int32_t>(unit, 0x10)};
    add(selection, &handle);
  }
  if (g_log && g_logLines < kMaxLogLines) {
    const float* eye = camera == nullptr ? nullptr : reinterpret_cast<const float*>(camera + 0x04);
    const float* forward = camera == nullptr ? nullptr : reinterpret_cast<const float*>(camera + 0x10);
    LogLine(L"selectFattened: player %d, %d fattened, %u selected (limit %d), selection now %d; camera (%.1f, %.1f, "
            L"%.1f) looking (%.2f, %.2f, %.2f)",
            Field<std::int32_t>(game, 0x3C0), found, static_cast<unsigned>(units.size()), cap,
            Field<std::int32_t>(selection, 0x08), eye ? eye[0] : 0.0f, eye ? eye[1] : 0.0f, eye ? eye[2] : 0.0f,
            forward ? forward[0] : 0.0f, forward ? forward[1] : 0.0f, forward ? forward[2] : 0.0f);
  }
}

// {uhcFattened}: the last count, as text.
bool __stdcall FattenedRef(uhc::DataRefValue* value) {
  if (value == nullptr || value->type != uhc::kDataRefString) {
    return false;
  }
  const char* world = World(Game());
  if (world == nullptr || world != g_world || g_count < 0) {
    return false;
  }
  wchar_t text[16];
  swprintf_s(text, L"%d", g_count);
  const BString source{text};
  kBStringAssign(&value->text, &source, -1, -1);
  return true;
}

std::int32_t Resolve(Slot& slot) {
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
  if (slot.handle == 0 && !slot.missingLogged) {
    slot.missingLogged = true;
    LogLine(L"selectFattened: no gadget named %hs yet (looked up again every 2 s)", slot.name.c_str());
  } else if (slot.handle != 0) {
    slot.missingLogged = false;
    LogLine(L"selectFattened: gadget %hs found", slot.name.c_str());
  }
  return slot.handle;
}

void ApplyGadgets() {
  const char* world = World(Game());
  if (world == nullptr || world != g_world || g_count < 0 || uhc::ui::Manager() == nullptr) {
    return;
  }
  const bool visible = g_count > 0;
  for (Slot& slot : g_slots) {
    const std::int32_t handle = Resolve(slot);
    if (handle != 0 && uhc::ui::ShownState(handle) != (visible ? 1 : 0)) {
      uhc::ui::Show(handle, visible);
    }
  }
}

void BeforePresent() { ApplyGadgets(); }

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
  g_world = world;
  g_player = player;
  LARGE_INTEGER t0{}, t1{};
  if (g_log) {
    QueryPerformanceCounter(&t0);
  }
  std::vector<const char*> units;
  Collect(game, &units);
  const auto count = static_cast<std::int32_t>(units.size());
  if (g_log) {  // the count's cost, logged every 600 counts (a minute of game time)
    static LARGE_INTEGER frequency{};
    static double total = 0.0, worst = 0.0;
    static int counts = 0;
    QueryPerformanceCounter(&t1);
    if (frequency.QuadPart == 0) {
      QueryPerformanceFrequency(&frequency);
    }
    const double us = static_cast<double>(t1.QuadPart - t0.QuadPart) * 1e6 / static_cast<double>(frequency.QuadPart);
    total += us;
    worst = us > worst ? us : worst;
    if (++counts == 600) {
      const char* p = kPlayerById(world, player);
      LogLine(L"selectFattened: count over %d units: %.1f us on average, %.1f us at most (600 counts)",
              p == nullptr ? 0 : Field<std::int32_t>(p, 0xFC), total / counts, worst);
      total = worst = 0.0;
      counts = 0;
    }
  }
  if (count != g_count) {
    static bool first = true;
    if (first) {
      first = false;
      uhc::Log(L"selectFattened: first count (player %d: %d fattened)", player, count);
    }
    LogLine(L"selectFattened: player %d has %d fattened herdable(s)", player, count);
    g_count = count;
  }
  if (!g_present) {
    ApplyGadgets();
  }
}

}  // namespace

namespace uhc {

Outcome ApplySelectFattened(const Config& config) {
  const Config::Args* args = config.First("selectFattened");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (std::size_t i = 0; i < args->size(); ++i) {
    const std::string& arg = (*args)[i];
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "gadget") == 0 && i + 1 < args->size()) {
      Slot slot;
      slot.name = (*args)[++i];
      g_slots.push_back(slot);
    } else {
      Log(L"selectFattened: bad argument %hs (expected [gadget <name>]... [log]); not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (g_slots.empty()) {
    Slot slot;
    slot.name = "uhcFattened";
    g_slots.push_back(slot);
  }
  if (!ui::VerifyUiGadgets("selectFattened") || !ui::VerifyUiShow("selectFattened") ||
      !VerifyAll("selectFattened", {&sites::kSelectionOfGame, &sites::kSelectionClear, &sites::kFindAllOfTypeLoop,
                                    &sites::kSelectionAdd, &sites::kSelectionAddCapped, &sites::kUnitById, &sites::kPlayerById, &sites::kIsAbstractIndex,
                                    &sites::kInventoryIsFull, &sites::kBStringAssign, &sites::kUiFindAnywhere})) {
    return Outcome::kFailed;
  }
  if (!InstallSyscallHooks("selectFattened")) {
    return Outcome::kFailed;
  }
  SyscallDef def;
  def.group = SyscallGroup::kUi;
  def.retType = kSyscallVoid;
  def.name = "uhcSelectFattened";
  def.fn = reinterpret_cast<const void*>(&UhcSelectFattened);
  def.comment = "Selects the local player's herdables that are fully fattened.";
  def.source = "selectFattened";
  AddSyscall(std::move(def));
  if (!AddDataRef(L"uhcFattened", kDataRefString, &FattenedRef) || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  g_present = AddD3D9Observer({nullptr, nullptr, &BeforePresent, nullptr}, "selectFattened");
  std::string names;
  for (const Slot& slot : g_slots) {
    names += (names.empty() ? "" : ", ") + slot.name;
  }
  Log(L"selectFattened: UI syscall uhcSelectFattened() and {uhcFattened} added; gadget(s) %hs shown while the "
      L"local player has a fattened herdable%ls%ls (interface only)",
      names.c_str(), g_present ? L"" : L" (set from the world update: no Present observer)",
      g_log ? L"; presses and counts logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
