// The rollover of a tech button in the command panel, shared by every key that adds to it (researchGrants' price,
// shipTechLimit's count): one replaced call, 0x4622C5, the panel's call of the rollover builder 0x4C737C in the
// command panel refresh FUN_0046188E. Display only: nothing here reaches the simulation.
#pragma once

namespace uhc {

// Called once the stock rollover is built, in the order the keys added them. `entry` is the player's status entry
// of the tech, `player` the local player, `unit` the selected unit, `rollover` the rollover text (a BString:
// AppendTechRollover adds to it) and `overlay` the button's overlay text (the panel's buffer, 256 chars, empty for a
// tech; researchGrants writes its price there).
using TechRolloverLine = void (*)(const char* entry, const char* player, const char* unit, void* rollover,
                                  char* overlay);

// Writes the hook the first time, after checking the stock bytes of the call and of the buffers it relies on.
bool AddTechRolloverLine(const char* feature, TechRolloverLine line);

// Appends text (game markup such as <color=1, 0.4, 0.4> allowed) to a rollover handed to a TechRolloverLine.
void AppendTechRollover(void* rollover, const wchar_t* text);

}  // namespace uhc
