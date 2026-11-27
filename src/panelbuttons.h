// One hook on each button the command panel lays out (FUN_0046188E at 0x462317, before the button's
// state and commands are applied), shared by every key that changes a button there (nativePreview,
// transformChecks): a single jmp, whichever of those keys are on. Interface only: nothing here reaches
// the simulation.
#pragma once

#include <cstdint>

namespace uhc {

// The refresh's frame at 0x462317 (its ESP there). The fields a filter may read and write.
struct PanelButton {
  char* frame;

  std::int32_t Column() const { return *reinterpret_cast<const std::int32_t*>(frame + 0x1C); }
  // 0 enabled, 1 disabled (grey), 2 red, 3.
  std::int32_t& State() const { return *reinterpret_cast<std::int32_t*>(frame + 0x24); }
  // The console commands of a click and of a shift-click (256-byte narrow buffers).
  char* Click() const { return frame + 0x1C0; }
  char* ShiftClick() const { return frame + 0x3C0; }
  // The text on the button (256-byte narrow buffer, the Buy buttons' price).
  char* Overlay() const { return frame + 0x2C0; }
  // The rollover, a BString (its first dword the wide text).
  void* Rollover() const { return frame + 0x18; }
};

using PanelButtonFilter = void (*)(const PanelButton& button);

// Writes the jmp the first time (after checking the stock bytes) and adds the filter; filters run in the
// order they were added.
bool AddPanelButtonFilter(PanelButtonFilter filter);

}  // namespace uhc
