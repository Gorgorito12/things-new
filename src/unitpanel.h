// One hook after the unit panel's own AutoGather rate (0x699456), shared by every key that writes in
// that row of the minimized interface (showGatherRate, overhealHitpointBars stat): with
// optionminimizedui the exe skips the stat panel fill, and these two gadgets are the row it has left.
#pragma once

namespace uhc {

// Called while one unit is selected, for that unit. Writes the row and returns true, or returns
// false to leave it to the next key. The last key added is asked first.
using UnitPanelRow = bool(__stdcall*)(const char* panel, const char* unit);

// The row's text, in the style of the stock AutoGather row; false if this interface has no such gadgets.
bool SetUnitPanelRow(const char* panel, const wchar_t* label, const wchar_t* value);

// Writes the hook the first time (after checking the site's stock bytes) and adds row.
bool AddUnitPanelRow(UnitPanelRow row);

// One key may also write the row for a selection of several units: `row` gets the panel and the
// selection group (IDs [group+10h], count [group+14h]). The single-unit rows do not run for a group.
using UnitPanelGroupRow = bool(__stdcall*)(const char* panel, const char* selection);
void SetUnitPanelGroupRow(UnitPanelGroupRow row);

}  // namespace uhc
