// The rollover of a tech, shared by every key that adds to it (researchGrants' price, shipTechLimit's count): one
// hook at the only exit of the rollover builder 0x4C737C (0x4C78F3), so every screen that builds a tech's rollover
// gets the lines: the command panel FUN_0046188E (normal and minimised UI), the native command panel FUN_009ACAF4 and
// the trade route panel FUN_009B687E. Display only: nothing here reaches the simulation.
#pragma once

namespace uhc {

// Called once the stock rollover is built, in the order the keys added them. `entry` is the player's status entry
// of the tech, `player` the player, `unit` the selected unit (either may be null: 0x703F99 builds a rollover with
// neither), `rollover` the rollover text (a BString: AppendTechRollover adds to it) and `overlay` the button's
// overlay text (the panel's buffer, 256 chars, empty for a tech; researchGrants writes its price there), or null
// for a caller that has none.
using TechRolloverLine = void (*)(const char* entry, const char* player, const char* unit, void* rollover,
                                  char* overlay);

// Writes the hook the first time, after checking the stock bytes of the builder's exit and head.
bool AddTechRolloverLine(const char* feature, TechRolloverLine line);

// Appends text (game markup such as <color=1, 0.4, 0.4> allowed) to a rollover handed to a TechRolloverLine.
void AppendTechRollover(void* rollover, const wchar_t* text);

}  // namespace uhc
