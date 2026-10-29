// customHotkeyContexts: unit hotkeys for buildings (and other trainers) the exe does not know.
//
// Every <keymapdata> of DefaultKeyMapY.xml belongs to a named <context>. Stock knows a fixed list
// of 123 context names (FUN_005D7948; 35 of them are the unit contexts TownCenterAccel ..
// WonderAccel, at layer 5), and FUN_005C16EA drops every keymap entry whose context is not on
// that list. Which context a selected building turns on comes from a hardcoded proto table
// ([proto+178h], written by FUN_005C13C5); the selection code switches off only the 35 stock
// names (FUN_0079EF9C), and a selected non-building with a <Train> list only ever turns on
// BuildAccel (selection chunk 0x649FA4).
//
// With this key, a keymap context named <ProtoName>Accel that the exe does not know is registered
// while the keymap is applied (layer 5, like the stock unit contexts), so its entries are bound
// instead of dropped. Selecting a unit of that proto turns that context on instead of the stock
// one, a non-building trainer of that proto enters it like a building, and the selection code
// switches it off with the stock ones. A stock context is never redirected, so with the stock
// keymap nothing changes. UI only: a hotkey issues the same command as a click. The hooks are in
// hooks/hotkey_hooks.asm.
#include <windows.h>

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

// Engine layout (docs/engine-symbols.md, "Hotkey contexts").
constexpr std::uint32_t kUiGlobal = 0x00C66244;  // [[ui+74h]+34h] = the context manager
constexpr std::int32_t kContextMissing = 3;      // 0x5C16AB: 0 found, 3 unknown name
constexpr std::int32_t kUnitContextLayer = 5;    // the layer of the 35 stock unit contexts
constexpr std::int32_t kContextLimit = 255;      // every context set is 255 bits: IDs 0..254
// Context IDs are dense ([manager+34h] is the next one) and the game registers some at run time
// too (0x5D3B1D, 0x62CB43; how many after the keymap pass is not measured): leave it this many,
// so that ours alone never push one of its IDs past the sets.
constexpr std::int32_t kReservedIds = 32;
constexpr char kSuffix[] = "Accel";
constexpr std::size_t kSuffixLength = sizeof(kSuffix) - 1;

// thiscall functions of the context manager, called as fastcall with an unused EDX.
using FindContextFn = std::int32_t(__fastcall*)(void* manager, void* unusedEdx, const void* name,
                                                std::int32_t* record);
using RegisterContextFn = std::int32_t(__fastcall*)(void* manager, void* unusedEdx, const char* name,
                                                    std::int32_t layer);
using DeactivateByNameFn = std::int32_t(__fastcall*)(void* manager, void* unusedEdx, const char* name,
                                                     std::int32_t flag);
using DeactivateByIdFn = std::int32_t(__fastcall*)(void* manager, void* unusedEdx, std::int32_t id,
                                                   std::int32_t flag);

// Find by BString name: writes {id, layer} to record; 0 found, 3 unknown (ret 8).
const auto kFindContext = reinterpret_cast<FindContextFn>(0x005C16AB);
// Register a name: its ID is [manager+34h]; 0 on success, 2 if the name exists (ret 8).
const auto kRegisterContext = reinterpret_cast<RegisterContextFn>(0x00628FC0);
// Switch a context off, by name or by ID (ret 8).
const auto kDeactivateByName = reinterpret_cast<DeactivateByNameFn>(0x004421F3);
const auto kDeactivateById = reinterpret_cast<DeactivateByIdFn>(0x00AB397F);

struct AddedContext {
  std::string proto;  // the context name without "Accel"
  std::string name;   // the context name as the keymap spells it
  std::int32_t id;
  bool trainerLogged;  // "log": the non-building line was written for this proto
};

// Written only by the keymap hook and read by the selection hooks, all on the game's UI thread;
// reserved when the feature is applied, so a push_back never moves the entries.
std::vector<AddedContext> g_added;
std::vector<std::string> g_refused;  // names already logged as not registered
void* g_manager = nullptr;           // the context manager the IDs in g_added belong to
bool g_log = false;                  // "customHotkeyContexts log": log every switch
std::int32_t g_lastUnit = -1;        // "log": the last unit and context logged
std::int32_t g_lastContext = -1;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

void* ContextManager() {
  const void* ui = *reinterpret_cast<void* const*>(kUiGlobal);
  const void* inner = ui == nullptr ? nullptr : Field<const void*>(ui, 0x74);
  return inner == nullptr ? nullptr : Field<void*>(inner, 0x34);
}

// A keymap entry's context is a BString: its first field is the UTF-16 text. Narrowed with the
// ANSI code page, as the game's own conversion (0x402733) does.
std::string Narrow(const void* name) {
  const wchar_t* text = Field<const wchar_t*>(name, 0);
  if (text == nullptr || *text == L'\0') {
    return {};
  }
  const int size = WideCharToMultiByte(CP_ACP, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) {
    return {};
  }
  std::string narrow(static_cast<std::size_t>(size), '\0');
  if (WideCharToMultiByte(CP_ACP, 0, text, -1, narrow.data(), size, nullptr, nullptr) != size) {
    return {};
  }
  narrow.resize(static_cast<std::size_t>(size - 1));
  return narrow;
}

bool IsProtoContextName(const std::string& name) {
  return name.size() > kSuffixLength && _stricmp(name.c_str() + name.size() - kSuffixLength, kSuffix) == 0;
}

// True the first time a name is refused, so each refusal is logged once.
bool FirstRefusal(const std::string& name) {
  for (const std::string& refused : g_refused) {
    if (_stricmp(refused.c_str(), name.c_str()) == 0) {
      return false;
    }
  }
  g_refused.push_back(name);
  return true;
}

// The added context of a proto (database or player proto: the name is at +10h), or nullptr.
AddedContext* ContextOf(const void* proto) {
  if (proto == nullptr || g_added.empty() || ContextManager() != g_manager) {
    return nullptr;
  }
  const char* name = Field<const char*>(proto, 0x10);
  if (name == nullptr) {
    return nullptr;
  }
  for (AddedContext& added : g_added) {
    if (_stricmp(added.proto.c_str(), name) == 0) {
      return &added;
    }
  }
  return nullptr;
}

}  // namespace

extern "C" {

// Called instead of the find at 0x5C1778, for each keymap entry: the stock find, and, when the
// context is unknown and named <ProtoName>Accel, a registration and a second find, so the entry
// is bound instead of dropped. Same frame as the stock thiscall (ret 8).
std::int32_t __fastcall UhcHotkeyFindContext(void* manager, void*, const void* name, std::int32_t* record) {
  const std::int32_t found = kFindContext(manager, nullptr, name, record);
  if (found != kContextMissing || manager == nullptr || name == nullptr || record == nullptr) {
    return found;
  }
  const std::string context = Narrow(name);
  if (!IsProtoContextName(context)) {
    return found;  // stock: the entry is dropped
  }
  if (manager != g_manager) {
    g_added.clear();
    g_refused.clear();
    g_manager = manager;
  }
  const std::int32_t next = Field<std::int32_t>(manager, 0x34);
  if (next < 0 || next >= kContextLimit - kReservedIds) {
    if (FirstRefusal(context)) {
      uhc::Log(L"customHotkeyContexts: %d contexts are registered; keymap context %hs not registered, its "
               L"entries are dropped (the last %d of the 255 context IDs stay free for the game)",
               next, context.c_str(), kReservedIds);
    }
    return found;
  }
  if (kRegisterContext(manager, nullptr, context.c_str(), kUnitContextLayer) != 0) {
    if (FirstRefusal(context)) {
      uhc::Log(L"customHotkeyContexts: the game refused to register keymap context %hs; its entries are "
               L"dropped",
               context.c_str());
    }
    return found;
  }
  const std::int32_t again = kFindContext(manager, nullptr, name, record);
  if (again != 0 || record[0] != next) {
    uhc::Log(L"customHotkeyContexts: keymap context %hs was registered as %d but found as %d (result %d); "
             L"no unit enters it",
             context.c_str(), next, record[0], again);
    return again;
  }
  g_added.push_back({context.substr(0, context.size() - kSuffixLength), context, next, false});
  uhc::Log(L"customHotkeyContexts: registered keymap context %hs as context %d", context.c_str(), next);
  return again;
}

// Called instead of the last deactivation at 0x79F1A5 (WonderAccel): the stock call, then every
// added context, with the same flag. Same frame as the stock thiscall (ret 8).
std::int32_t __fastcall UhcHotkeyDeactivateAll(void* manager, void*, const char* name, std::int32_t flag) {
  const std::int32_t result = kDeactivateByName(manager, nullptr, name, flag);
  if (manager != nullptr && manager == g_manager) {
    for (const AddedContext& added : g_added) {
      kDeactivateById(manager, nullptr, added.id, flag);
    }
  }
  return result;
}

void* g_uhcHotkeyFindContext = reinterpret_cast<void*>(&UhcHotkeyFindContext);
void* g_uhcHotkeyDeactivateAll = reinterpret_cast<void*>(&UhcHotkeyDeactivateAll);

// From the hook at 0x79F897: the context the selected unit turns on, if its proto has an added
// one; -1 keeps the stock [proto+178h]. proto is the unit's database proto.
std::int32_t __stdcall UhcHotkeyContextFor(const char* proto, const char* unit) {
  const AddedContext* added = ContextOf(proto);
  if (added == nullptr) {
    return -1;
  }
  if (g_log && unit != nullptr) {
    const std::int32_t unitId = Field<std::int32_t>(unit, 0x10);
    if (unitId != g_lastUnit || added->id != g_lastContext) {
      g_lastUnit = unitId;
      g_lastContext = added->id;
      uhc::Log(L"customHotkeyContexts: unit %d (%hs) selected: hotkey context %hs (%d) instead of stock "
               L"context %d",
               unitId, added->proto.c_str(), added->name.c_str(), added->id, Field<std::int32_t>(proto, 0x178));
    }
  }
  return added->id;
}

// From the hook at 0x64A034, for a selected non-building with a <Train> list: true if its proto
// has an added context, so it enters that context like a building.
bool __stdcall UhcHotkeyTrainerHasContext(const char* unit) {
  AddedContext* added = unit == nullptr ? nullptr : ContextOf(Field<const char*>(unit, 0x5C));
  if (added == nullptr) {
    return false;
  }
  if (g_log && !added->trainerLogged) {
    added->trainerLogged = true;
    uhc::Log(L"customHotkeyContexts: unit %d (%hs) is not a building: units of this proto enter hotkey "
             L"context %hs (%d) instead of BuildAccel (logged once per proto)",
             Field<std::int32_t>(unit, 0x10), added->proto.c_str(), added->name.c_str(), added->id);
  }
  return true;
}

void UhcHotkeyFindContextHook();
void UhcHotkeyContextHook();
void UhcHotkeyDeactivateHook();
void UhcHotkeyTrainerHook();
}

namespace uhc {

Outcome ApplyCustomHotkeyContexts(const Config& config) {
  const Config::Args* args = config.First("customHotkeyContexts");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"customHotkeyContexts: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("customHotkeyContexts",
                 {&sites::kHotkeyFindCall, &sites::kHotkeyFindContext, &sites::kHotkeyRegisterContext,
                  &sites::kHotkeyUnitContext, &sites::kHotkeyUnitActivate, &sites::kHotkeyDeactivateLast,
                  &sites::kHotkeyDeactivateById, &sites::kHotkeyTrainerBuildFlag,
                  &sites::kHotkeyTrainerQualified})) {
    return Outcome::kFailed;
  }
  g_log = log;
  g_added.reserve(kContextLimit);
  // Switch-off first and the trainer path last: if a later write failed, what is already written
  // still leaves every context consistent (registered but never on, or on and switched off).
  if (!WriteCall(sites::kHotkeyDeactivateLast.va, reinterpret_cast<const void*>(&UhcHotkeyDeactivateHook)) ||
      !WriteCall(sites::kHotkeyFindCall.va, reinterpret_cast<const void*>(&UhcHotkeyFindContextHook)) ||
      !WriteJmp(sites::kHotkeyUnitContext.va, reinterpret_cast<const void*>(&UhcHotkeyContextHook), 6) ||
      !WriteJmp(sites::kHotkeyTrainerBuildFlag.va, reinterpret_cast<const void*>(&UhcHotkeyTrainerHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"customHotkeyContexts: a keymap context named <ProtoName>Accel that the game does not know becomes "
      L"that proto's hotkey context%ls",
      log ? L", every switch logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
