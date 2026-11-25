// The progress pie: the engine's own pie chart filling, the overlay a train button shows while its unit trains
// (gadget vtable +6Ch, 0x4C51FA, 0xAB5C34, 0xAB5BAA; generated/sites.h, "progresspie"), drawn over the unit
// portrait of the selection panel in both interfaces. A key gives a source; once per panel refresh, while one
// unit is selected, the sources are asked for that unit in the order added, and the first that answers sets the
// pie; when none does, the pie is off. It adds no gadget and no art, and needs no layout change.
//
// Main thread only (the panel fill). No new jmp: it is an observer of the shared panel tail (AddUnitPanelTail).
#pragma once

#include <cstdint>

namespace uhc {

// The train button's colour (0x69D9BC: r 0, g 0, b 1, alpha 0.5), as ARGB. The default of every source.
inline constexpr std::uint32_t kPieTrainBlue = 0x800000FFu;

// Asked for the unit the panel shows (one unit selected). Return true to show the pie with `*fraction` done, 0 to 1
// (clamped; the part not done is covered, as on a train button), and optionally a different `*argb` (preset to
// kPieTrainBlue); false to leave the unit to the next source. Keep it cheap: it runs on every panel refresh.
using ProgressPieSource = bool(__stdcall*)(const char* unit, float* fraction, std::uint32_t* argb);

// Verifies the engine code the pie uses and the panel tail (once), then adds `source`. False, with a log line, when
// a check fails or there are more than 8 sources: the key then shows no pie, and the rest of the key may go on.
bool AddProgressPieSource(ProgressPieSource source);

// True if the engine code the pie uses holds the stock bytes (checked once; `feature` names the caller in the log).
// AddProgressPieSource calls it; a key that only uses the two calls below calls it from its apply function.
bool VerifyProgressPie(const char* feature);

// The same pie on any gadget of a layout, by handle (ui::FindChild / ui::FindAnywhere), for a key that draws it
// somewhere else: Show turns it on with `fraction` done (made on first use), Hide turns it off. Nothing, and false,
// for a stale handle or before VerifyProgressPie passed.
bool ShowGadgetPie(std::int32_t handle, float fraction, std::uint32_t argb);
void HideGadgetPie(std::int32_t handle);

}  // namespace uhc
