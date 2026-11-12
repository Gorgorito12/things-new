// Options of this DLL in the game's options menu, with nothing added to the game's option table or the profile.
//
// data\options.xml names an option variable per field; the screen resolves the name through 0x932264 on the
// "GameOptions" settings object, then reads the value through 0x553028 (type) and 0x402E6A (int) and writes it on
// Apply through 0x518AE0. That object holds a fixed list of 93 options. A name lookup that finds nothing answers a
// virtual ID for a registered option name (kFirstVirtualId upward, one per option, in the order they are added), and
// the three accessors' out-of-range paths serve those IDs from this module (src/hooks/menuoptions_hooks.asm). Each
// option is an int: the index of the dropdown's entry (0 = the first <value>). The choice is kept in kOptionsFile
// (uhc-options.cfg next to the log), one line `<store key> <value word>` per option, and is used at the next start.
//
// Two kinds of users:
// - a key that owns an option (rendererOption) calls AddMenuOption and reads the value itself;
// - an on/off key of kMenuSwitches (menuoptions.cpp) follows the menu when the cfg names it on a `menuOptions` line:
//   ApplyMenuSwitches decides it before any key applies. A key not named there follows its cfg line alone.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "config.h"

namespace uhc {

// Keep in step with FIRST_VIRTUAL_ID in hooks/menuoptions_hooks.asm.
inline constexpr std::int32_t kFirstVirtualId = 0x55480001;
inline constexpr int kMaxMenuOptions = 16;

struct MenuOption {
  const char* feature;                // the key, for the log
  const wchar_t* name;                // the field's <name> in data\options.xml, e.g. L"OptionRenderer"; any case
  const char* storeKey;               // the first word of its line in uhc-options.cfg, e.g. "renderer"
  std::vector<const char*> words;     // the stored word of each entry, by index (e.g. "dx9", "vulkan")
  std::vector<const wchar_t*> labels; // the same entries for the log (e.g. L"DirectX 9", L"Vulkan")
  bool log = false;                   // log every read and Apply, not only the first read
};

// Registers an option. The first call verifies and hooks the four menu sites. Returns the option's slot, or -1
// (logged) if the sites are not stock, the table is full or the name is taken.
int AddMenuOption(const MenuOption& option);

// The value stored in uhc-options.cfg for this option: an entry's index, or -1 if there is none or it is not one
// of the option's words.
int MenuOptionStored(int slot);

// What the menu shows from now on. With `store`, also writes it to uhc-options.cfg (false if that failed).
bool SetMenuOptionValue(int slot, int value, bool store);

// The full path of uhc-options.cfg.
std::wstring MenuOptionsPath();

// menuOptions <key> [<key> ...], before any key applies: each key named gets an entry, and is kept or added (on) or
// removed (off) in `config` by the player's stored choice. Until the player chooses, its own cfg line decides:
// present, on (with its arguments); absent, off. A chosen "on" without a cfg line applies the key with no arguments.
void ApplyMenuSwitches(Config& config);

}  // namespace uhc
