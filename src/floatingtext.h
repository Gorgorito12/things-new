// The stock floating text over a unit (the dodge's, string 63950, 0x6A24FC..0x6A2608), for keys
// that show something to the local player: noTrainNearEnemyTC's warning, damageOverTime's ticks.
// Interface only: it reads the local player and writes only the text manager.
#pragma once

#include <cstdint>

namespace uhc {

// Checks the stock code the helper repeats (logged under feature's name).
bool VerifyFloatingText(const char* feature);

// The local player's ID, [[game]+3C0h]; -1 without a game.
std::int32_t LocalPlayer();

// True when the text manager [world+8A8h] exists and unit is visible to the local player
// (0x4818F4), the dodge's conditions for its text.
bool CanShowUnitText(const char* unit);

// Shows text (or, with stringId >= 0, that string table entry) over unit, in colour (ARGB), when
// CanShowUnitText. The text does not rise. Returns the manager's index, or -1 when nothing was
// shown (the engine also refuses an empty text).
std::int32_t ShowUnitText(const char* unit, const wchar_t* text, std::int32_t stringId, std::uint32_t colour);

}  // namespace uhc
