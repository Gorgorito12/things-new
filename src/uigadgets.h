// UI gadgets: the engine's gadget calls, in one place for every key that reads or changes the interface. Handles
// are the engine's: an int whose low 18 bits index the gadget manager's table, the rest a generation, so a stale
// handle resolves to no gadget (0x40423C returns null), never to another gadget.
//
// The addresses are verified once by VerifyUiGadgets (each key that uses this module calls it from its apply
// function and refuses to apply when it fails). Not thread-safe: the game's main thread only.
#pragma once

#include <cstdint>

namespace uhc::ui {

// Gadget type masks for Gadget(): what 0x40423C asks the gadget's virtual +0CCh.
enum GadgetType : std::int32_t {
  kAnyGadget = 0,
  kList = 0x07,       // type="list" (vtable 0xB92378)
  kTextField = 0x0D,  // type="textField": an editable field with an optional dropdown (vtable 0xB91D60)
  kPalette = 0x18,    // type="palette" (vtable 0xB92768)
  kEditBox = 0x23,    // type="editBox", and the one a textField makes for its typed text (vtable 0xB91A38)
};

// True if the addresses below hold the stock code. `feature` names the caller in the log.
bool VerifyUiGadgets(const char* feature);

// The gadget manager [[0C66244h]+44h], or null before the UI exists.
void* Manager();

// The gadget of a handle when its type matches, else null (0 or a stale handle included). Takes no reference.
void* Gadget(std::int32_t handle, std::int32_t type);

// A gadget's own handle, [gadget+0Ch].
std::int32_t HandleOf(const void* gadget);

// The handle of a gadget named `name` among `parent`'s descendants (0x433812), or 0 if none.
std::int32_t FindChild(void* parent, const char* name);

// The text typed in a textField: the editBox it makes for it ([field+160h], 0x62BDD5) keeps it at [edit+170h], a
// BString (its set-text slot 0x5C2C20 and typing write it there). Empty when it has none. The pointer lives until
// the text changes; copy it.
const wchar_t* FieldText(const void* field);

// The handle of the first gadget named `name` in any of the manager's panels (0x433A2C, what the UI commands
// gadgetReal and gadgetUnreal use), or 0 if none or before the UI exists. Walks every panel: cache the handle.
std::int32_t FindAnywhere(const char* name);

// True if the show / hide addresses below hold the stock code (0x447F7B, 0x448F13 and the flags their bases test).
bool VerifyUiShow(const char* feature);

// Shows or hides a gadget (0x447F7B / 0x448F13, thiscall([[0C66244h]+44h], handle), what gadgetReal and
// gadgetUnreal run). Nothing for handle 0 or before the UI exists. Showing a hidden gadget puts it above its
// siblings; showing a shown one, or hiding a hidden one, does nothing.
void Show(std::int32_t handle, bool visible);

// The state the base show and hide test, from the flags [gadget+0A4h]: 1 shown (bits 0 and 1 set, bit 7 clear),
// 0 hidden (none of bits 0, 1, 7), -1 for anything in between or no gadget.
int ShownState(std::int32_t handle);

}  // namespace uhc::ui
