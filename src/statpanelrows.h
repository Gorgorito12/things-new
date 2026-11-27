// Rows of the normal interface's stat panel (uiunitstatpanel3, StackLabel/StackValue 0..8, filled by FUN_004D70ED),
// right after its HP row: one hook at 0x4D76DB, shared by every key that adds a row there (overhealHitpointBars stat,
// nurseryFactor). With the minimized interface the fill does not run; those keys write the unit panel's row instead
// (unitpanel.h).
#pragma once

#include <cstdint>

namespace uhc {

// Asked for the panel's unit, in the order added, while rows are free: writes row `row` and returns true, or returns
// false to leave it to the next one. Each row written moves the stock rows after it down by one.
using StatPanelRow = bool(__stdcall*)(const char* panel, const char* unit, std::int32_t row);

// Writes the hook the first time (after checking the site's stock bytes) and adds `row`.
bool AddStatPanelRow(StatPanelRow row, const char* feature);

// Writes row `row`'s label and value as the Group Health row does, and sets their help text (`tip` may be null: none).
// False if the panel has no such row.
bool SetStatPanelRow(const char* panel, std::int32_t row, const wchar_t* label, const wchar_t* value,
                     const wchar_t* tip);

}  // namespace uhc
