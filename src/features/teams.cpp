// enableAllTeams: the single-player game setup's team list offers Team 3 and Team 4 (stock: Team 1,
// Team 2 and "?"). FUN_007A0628 fills the list as pairs: a string (0x58EA52 into a temporary
// BString at [esp+10h], copied into a BString array at [esp+14h]) and a team value (an int array at
// [esp+20h]): 8D2Dh -> 0, 8D2Eh -> 1, then 8D31h -> -1. The hook, at the "?" entry (0x7A0709, push
// 8D31h), adds 8D2Fh -> 2 and 8D30h -> 3 the same way, destroys the temporary BString after each
// (0x4010CA), and re-executes the push. The multiplayer slot
// (a different class, FUN_00776702) is not changed yet. Hook: hooks/team_hooks.asm.
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcTeamDropdownHook();

// `frame` = ESP at the hooked instruction, in FUN_007A0628's frame.
void __stdcall UhcAddTeamEntries(char* frame) {
  using LoadString = void*(__thiscall*)(void* bstring, int stringId);
  using StringArraySetCount = bool(__thiscall*)(void* array, int count, bool exact);
  using Assign = void(__thiscall*)(void* destination, void* source);
  using Free = void(__thiscall*)(void* bstring);
  using IntArraySetCount = bool(__thiscall*)(void* array, int count, bool exact);
  const auto loadString = reinterpret_cast<LoadString>(0x0058EA52);
  const auto stringSetCount = reinterpret_cast<StringArraySetCount>(0x004676E7);
  const auto assign = reinterpret_cast<Assign>(0x0040196F);
  const auto freeString = reinterpret_cast<Free>(0x004010CA);
  const auto intSetCount = reinterpret_cast<IntArraySetCount>(0x00401113);

  const struct {
    int stringId;
    std::int32_t team;
  } entries[] = {{0x8D2F, 2}, {0x8D30, 3}};
  for (const auto& entry : entries) {
    void* temp = frame + 0x10;
    void* source = loadString(temp, entry.stringId);
    const std::int32_t strings = *reinterpret_cast<std::int32_t*>(frame + 0x18);
    if (stringSetCount(frame + 0x14, strings + 1, false)) {
      assign(*reinterpret_cast<char**>(frame + 0x14) + strings * 4, source);
    }
    freeString(temp);
    const std::int32_t values = *reinterpret_cast<std::int32_t*>(frame + 0x24);
    if (intSetCount(frame + 0x20, values + 1, false)) {
      (*reinterpret_cast<std::int32_t**>(frame + 0x20))[values] = entry.team;
    }
  }
}
}

namespace uhc {

Outcome ApplyEnableAllTeams(const Config& config) {
  if (!config.Has("enableAllTeams")) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("enableAllTeams", {&sites::kTeamDropdownSp, &sites::kTeamDropdownBlock})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kTeamDropdownSp.va, reinterpret_cast<const void*>(&UhcTeamDropdownHook),
                sites::kTeamDropdownSp.size)) {
    return Outcome::kFailed;
  }
  Log(L"enableAllTeams: Team 3 and Team 4 in the single-player setup (multiplayer lobby not changed yet)");
  return Outcome::kApplied;
}

}  // namespace uhc
