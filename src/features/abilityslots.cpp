// abilitySlots <N> [log]: how many abilities (abilities.xml) the command panel asks for per unit.
//
// A proto's <Command page='11'>Abilities</Command> is the Abilities page of the command panel
// (commandpanel2, FUN_0046188E). On each refresh the panel appends that command entry 6 times:
// once at 0x4C5ACA, then 5 more in the do-while at 0x695BB6 (mov edi,5 at 0x695BD2). Each copy
// asks AbilityMgr::GetNth (0x6EE5CC) for the unit's next ability, n = 0, 1, ... 5. GetNth counts
// the unit's records that are not NeverShowInGrid, so an ability at position 7 or later never
// gets a button, even when the first 6 are disabled by their <Tech> or <Age>: a disabled one
// takes no column but still uses up one n. abilitySlots writes N-1 over the 5, so the panel asks
// for n = 0..N-1. GetNth returns false past the end of a unit's list, so a unit with 6 abilities
// or fewer looks the same. The extra buttons wrap to the next row of the 6x6 grid like any page
// wider than 6 columns, and the grid still stops at row 6.
//
// Only the local panel changes: a click runs the same ability(record, unit) UI command as stock,
// and the hotkey route doAbilityInSelected already reaches abilities past the 6th.
//
// log: the call at 0x696C70, on the path GetNth's "true" takes, goes through
// hooks/abilityslot_hooks.asm, which logs every button at n >= 6 once per unit and record.
#include <cstdint>
#include <cstring>
#include <set>
#include <string>
#include <utility>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr int kStockSlots = 6;  // 1 entry at 0x4C5ACA + 5 copies
constexpr int kMaxSlots = 36;   // the 6x6 button grid at [commandpanel2+1B4h]

// (unit ID, record index) pairs already logged; the panel refreshes many times a second.
// Read and written only from the game thread, by the hook. Unit IDs start again in every game: a
// new world, or a step count [world+F8h] that went back, clears it.
std::set<std::pair<std::int32_t, std::int32_t>> g_logged;
const char* g_logWorld = nullptr;
std::uint32_t g_logStep = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

void ForgetOtherGames() {
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const std::uint32_t step = world == nullptr ? 0 : Field<std::uint32_t>(world, 0xF8);
  if (world != g_logWorld || step < g_logStep) {
    g_logged.clear();
  }
  g_logWorld = world;
  g_logStep = step;
}

const char* ProtoName(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

}  // namespace

extern "C" {
void UhcAbilityButtonHook();

// Called by the hook when GetNth returned true for n >= 6: the unit gets a button that stock
// never asks for. `enabled` is GetNth's out byte (0 for AlwaysDisabledInGrid; a recharging one was not checked).
void __stdcall UhcAbilitySlotsLogButton(const char* unit, std::int32_t n, std::int32_t record, std::int32_t power,
                                        std::int32_t enabled) {
  ForgetOtherGames();
  const std::int32_t id = unit == nullptr ? -1 : Field<std::int32_t>(unit, 0x10);
  if (!g_logged.insert({id, record}).second) {
    return;
  }
  uhc::Log(L"abilitySlots: unit %d (%hs) shows ability %d of its list (record %d, power %d, %ls), past the stock 6",
           id, ProtoName(unit), n + 1, record, power, enabled != 0 ? L"enabled" : L"greyed");
}
}

namespace uhc {

Outcome ApplyAbilitySlots(const Config& config) {
  const Config::Args* args = config.First("abilitySlots");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  const auto slots = config.Int("abilitySlots");
  if (!slots || *slots < kStockSlots || *slots > kMaxSlots) {
    Log(L"abilitySlots: expected an integer from %d to %d, then optionally log; feature not applied", kStockSlots,
        kMaxSlots);
    return Outcome::kFailed;
  }
  bool log = false;
  for (std::size_t i = 1; i < args->size(); ++i) {
    const std::string& arg = (*args)[i];
    if (_stricmp(arg.c_str(), "log") == 0 && !log) {
      log = true;
    } else {
      Log(L"abilitySlots: unexpected argument %hs (expected: <N> [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("abilitySlots", {&sites::kAbilitySlotCopies, &sites::kAbilityPage11Branch, &sites::kAbilityNthCall,
                                  &sites::kAbilityButtonCost})) {
    return Outcome::kFailed;
  }
  // mov edi,5 at 0x695BD2, the do-while's count: the imm32 starts one byte in. N-1 >= 5, so the
  // loop's sub edi,1 / je never starts from 0.
  if (!WriteDword(sites::kAbilitySlotCopies.va + 0x1D, static_cast<std::uint32_t>(*slots - 1))) {
    return Outcome::kFailed;
  }
  if (log && !WriteJmp(sites::kAbilityButtonCost.va, reinterpret_cast<const void*>(&UhcAbilityButtonHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"abilitySlots: the command panel asks for %d abilities per unit (stock %d)%ls", *slots, kStockSlots,
      log ? L", every button past the 6th logged once per unit" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
