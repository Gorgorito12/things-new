// wonderPanelSkipAuras: the wonder power panel (the row of global power buttons, gadget
// uiwonderpowerpanel) shows a wonder's first available ability that is not a passive aura,
// instead of only its first ability.
//
// Stock: for each <Command page='11'>Abilities</Command> of an AbstractWonder the local player
// owns, the panel refresh (a cold chunk of FUN_004586B1) asks the ability manager [world+56Ch]
// for the unit's ability n = 0 only (push 0 / call 6EE5CCh at 0x69EE5B), and adds no button when
// that call fails (the ability's tech is not active, or its age differs) or when the record is
// AlwaysDisabledInGrid (0x69EE80), the flag abilities.xml puts on passive auras. A wonder that
// lists an aura first (Toshogu Shrine, Shogunate, ...) therefore never gets a panel button for a
// global power listed after it, although the command grid of the selected wonder shows both.
//
// The hook replaces that call: it asks for n = 0, 1, ... 7 and returns the first ability that
// exists, is available and is not AlwaysDisabledInGrid, with the outputs of that call. With stock
// data every wonder has a single ability, so the panel is unchanged. The button still runs
// ability(record, unit, true), the UI command a command grid button already sends, so only what
// the panel shows changes (UI only). The hook is in hooks/wonderpanel_hooks.asm.
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* ProtoName(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

// Ability records already logged with "log": the panel asks again on every refresh, so each
// record is logged once. Used only by the hook, on the game thread.
std::vector<std::int32_t> g_loggedRecords;

}  // namespace

extern "C" {
std::int32_t g_uhcWonderPanelLog = 0;

void UhcWonderPanelAbilityHook();

// Called by the hook, with "log", when the panel shows an ability that stock would not (n > 0).
void __stdcall UhcWonderPanelLogAbility(const char* unit, std::int32_t n, std::int32_t record, std::int32_t power) {
  if (std::find(g_loggedRecords.begin(), g_loggedRecords.end(), record) != g_loggedRecords.end()) {
    return;
  }
  g_loggedRecords.push_back(record);
  uhc::Log(L"wonderPanelSkipAuras: unit %d (%hs) shows its ability n=%d in the wonder power panel "
           L"(record %d, power %d)",
           Field<std::int32_t>(unit, 0x10), ProtoName(unit), n, record, power);
}
}

namespace uhc {

Outcome ApplyWonderPanelSkipAuras(const Config& config) {
  const Config::Args* args = config.First("wonderPanelSkipAuras");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"wonderPanelSkipAuras: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("wonderPanelSkipAuras", {&sites::kWonderPanelAbilityArgs, &sites::kWonderPanelAbilityCall,
                                          &sites::kNthVisibleAbility, &sites::kAbilityByIndex})) {
    return Outcome::kFailed;
  }
  g_uhcWonderPanelLog = log ? 1 : 0;
  if (!WriteCall(sites::kWonderPanelAbilityCall.va, reinterpret_cast<const void*>(&UhcWonderPanelAbilityHook))) {
    return Outcome::kFailed;
  }
  Log(L"wonderPanelSkipAuras: the wonder power panel shows a wonder's first available ability that is not a "
      L"passive aura (AlwaysDisabledInGrid)%ls (UI only)",
      log ? L", each ability it shows past the first logged once" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
