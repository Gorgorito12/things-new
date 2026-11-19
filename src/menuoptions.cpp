// The options menu's registry (menuoptions.h). The hooks are in hooks/menuoptions_hooks.asm.
#include "menuoptions.h"

#include <windows.h>

#include <cctype>
#include <cwchar>

#include "generated/sites.h"
#include "hostfiles.h"
#include "log.h"
#include "patch.h"
#include "startup.h"

extern "C" {
void UhcMenuNameHook();
void UhcMenuTypeHook();
void UhcMenuGetHook();
void UhcMenuSetHook();

// Read by the hooks: the number of options, and each one's value (the dropdown's index), by slot. The count is
// raised only once the slot's value is in place.
std::int32_t g_uhcMenuOptionCount = 0;
std::int32_t g_uhcMenuOptionValues[uhc::kMaxMenuOptions] = {};
}

namespace uhc {
namespace {

// The on/off keys that menuOptions may hand to the menu. One line per key: the key, the field's <name> in
// data\options.xml. The stored line is `<key> on|off`. Only keys that change nothing of the simulation belong here,
// since each player chooses alone.
struct MenuSwitch {
  const char* key;
  const wchar_t* name;
};
constexpr MenuSwitch kMenuSwitches[] = {
    {"bufferedFileReads", L"OptionBufferedReads"},
    {"fastVertexFill", L"OptionFastVertexFill"},
    {"fastLastInLine", L"OptionFastLastInLine"},
};

constexpr std::uint32_t kSettingsKind = 0x24;  // [settings+24h]: 1 for the options settings (FUN_00518CC9)

struct Slot {
  MenuOption option;
  bool lookupLogged = false;
};

Slot g_slots[kMaxMenuOptions];
int g_hooks = 0;  // 0 not tried, 1 installed, -1 failed

std::string Lower(std::string s) {
  for (char& c : s) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  return s;
}

std::string ReadText(const std::wstring& path) {
  std::string text;
  HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return text;
  }
  char buffer[4096];
  DWORD read = 0;
  while (ReadFile(file, buffer, sizeof(buffer), &read, nullptr) && read != 0) {
    text.append(buffer, read);
  }
  CloseHandle(file);
  return text;
}

bool WriteText(const std::wstring& path, const std::string& text) {
  const std::wstring temp = path + L".new";
  HANDLE file = CreateFileW(temp.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }
  DWORD written = 0;
  const bool ok = WriteFile(file, text.data(), static_cast<DWORD>(text.size()), &written, nullptr) != 0 &&
                  written == text.size();
  CloseHandle(file);
  return ok && MoveFileExW(temp.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != 0;
}

// Splits the file into lines without their line ends.
std::vector<std::string> Lines(const std::string& text) {
  std::vector<std::string> lines;
  std::size_t pos = 0;
  while (pos < text.size()) {
    std::size_t end = text.find('\n', pos);
    if (end == std::string::npos) {
      end = text.size();
    }
    std::string line = text.substr(pos, end - pos);
    pos = end + 1;
    if (!line.empty() && line.back() == '\r') {
      line.pop_back();
    }
    lines.push_back(std::move(line));
  }
  return lines;
}

// True if the line is the option's: its store key, then a space.
bool IsLineOf(const std::string& line, const MenuOption& option) {
  const std::string prefix = Lower(option.storeKey) + " ";
  return Lower(line).rfind(prefix, 0) == 0;
}

const wchar_t* Label(const MenuOption& option, int value) {
  return value >= 0 && value < static_cast<int>(option.labels.size()) ? option.labels[value] : L"?";
}

bool Store(const MenuOption& option, int value) {
  const std::wstring path = MenuOptionsPath();
  std::string out;
  bool replaced = false;
  const std::string line = std::string(option.storeKey) + " " + option.words[value];
  for (const std::string& old : Lines(ReadText(path))) {
    if (IsLineOf(old, option)) {
      if (!replaced) {
        out += line + "\r\n";
        replaced = true;
      }
      continue;
    }
    out += old + "\r\n";
  }
  if (out.empty()) {
    out = "# The game's options menu writes this file: one option per line, used at the next start.\r\n";
  }
  if (!replaced) {
    out += line + "\r\n";
  }
  if (!WriteText(path, out)) {
    Log(L"%hs: cannot write %ls (error %lu)", option.feature, path.c_str(), GetLastError());
    return false;
  }
  return true;
}

bool InstallHooks() {
  if (g_hooks != 0) {
    return g_hooks > 0;
  }
  g_hooks = -1;
  if (!VerifyAll("menu options", {&sites::kOptionNameLookup, &sites::kOptionTypeGetter, &sites::kOptionTypeRange,
                                  &sites::kOptionIntGetter, &sites::kOptionIntGetRange, &sites::kOptionIntSetter})) {
    return false;
  }
  if (!WriteJmp(sites::kOptionNameLookup.va + 0x3D, reinterpret_cast<const void*>(&UhcMenuNameHook), 5) ||
      !WriteJmp(sites::kOptionTypeRange.va, reinterpret_cast<const void*>(&UhcMenuTypeHook), 5) ||
      !WriteJmp(sites::kOptionIntGetRange.va, reinterpret_cast<const void*>(&UhcMenuGetHook), 5) ||
      !WriteJmp(sites::kOptionIntSetter.va + 0x46, reinterpret_cast<const void*>(&UhcMenuSetHook), 5)) {
    return false;
  }
  g_hooks = 1;
  return true;
}

}  // namespace

std::wstring MenuOptionsPath() { return ExeFolder() + kOptionsFile; }

int AddMenuOption(const MenuOption& option) {
  const int slot = g_uhcMenuOptionCount;
  if (slot >= kMaxMenuOptions) {
    Log(L"%hs: no room for %ls in the options menu (%d options at most)", option.feature, option.name,
        kMaxMenuOptions);
    return -1;
  }
  for (int i = 0; i < slot; ++i) {
    if (_wcsicmp(g_slots[i].option.name, option.name) == 0) {
      Log(L"%hs: the options menu already has %ls (%hs)", option.feature, option.name, g_slots[i].option.feature);
      return -1;
    }
  }
  if (!InstallHooks()) {
    Log(L"%hs: the options menu's sites are not stock; no %ls entry", option.feature, option.name);
    return -1;
  }
  g_slots[slot].option = option;
  g_uhcMenuOptionValues[slot] = 0;
  g_uhcMenuOptionCount = slot + 1;
  return slot;
}

int MenuOptionStored(int slot) {
  const MenuOption& option = g_slots[slot].option;
  for (const std::string& line : Lines(ReadText(MenuOptionsPath()))) {
    if (!IsLineOf(line, option)) {
      continue;
    }
    std::string value = Lower(line.substr(std::char_traits<char>::length(option.storeKey) + 1));
    while (!value.empty() && (value.back() == ' ' || value.back() == '\t')) {
      value.pop_back();
    }
    for (std::size_t i = 0; i < option.words.size(); ++i) {
      if (value == option.words[i]) {
        return static_cast<int>(i);
      }
    }
  }
  return -1;
}

bool SetMenuOptionValue(int slot, int value, bool store) {
  g_uhcMenuOptionValues[slot] = value;
  return !store || Store(g_slots[slot].option, value);
}

extern "C" std::int32_t __stdcall UhcMenuOptionLookup(const wchar_t* name, const std::uint8_t* settings) {
  if (name == nullptr || *reinterpret_cast<const std::uint32_t*>(settings + kSettingsKind) != 1) {
    return -1;
  }
  for (int i = 0; i < g_uhcMenuOptionCount; ++i) {
    Slot& slot = g_slots[i];
    if (_wcsicmp(name, slot.option.name) != 0) {
      continue;
    }
    if (slot.option.log || !slot.lookupLogged) {
      slot.lookupLogged = true;
      Log(L"%hs: options screen field %ls (settings 0x%08X, %u options); shows %ls", slot.option.feature, name,
          static_cast<unsigned>(reinterpret_cast<std::uintptr_t>(settings)),
          *reinterpret_cast<const std::uint32_t*>(settings + 8), Label(slot.option, g_uhcMenuOptionValues[i]));
    }
    return kFirstVirtualId + i;
  }
  return -1;
}

extern "C" void __stdcall UhcMenuOptionSet(std::int32_t index, std::int32_t value) {
  const MenuOption& option = g_slots[index].option;
  if (value < 0 || value >= static_cast<int>(option.words.size())) {
    Log(L"%hs: the menu wrote %d to %ls; ignored (it has %zu entries)", option.feature, value, option.name,
        option.words.size());
    return;
  }
  if (value == g_uhcMenuOptionValues[index]) {
    if (option.log) {
      Log(L"%hs: Apply, still %ls", option.feature, Label(option, value));
    }
    return;
  }
  const bool stored = SetMenuOptionValue(index, value, true);
  Log(L"%hs: %ls chosen in the menu%ls; it takes effect at the next start", option.feature, Label(option, value),
      stored ? L"" : L" (NOT stored)");
}

void ApplyMenuSwitches(Config& config) {
  const std::vector<Config::Args>* lines = config.All("menuOptions");
  if (lines == nullptr) {
    return;
  }
  constexpr std::size_t kCount = sizeof(kMenuSwitches) / sizeof(kMenuSwitches[0]);
  int following = 0;
  bool failed = false;
  bool named[kCount] = {};
  for (const Config::Args& args : *lines) {
    for (const std::string& word : args) {
      bool found = false;
      for (std::size_t i = 0; i < kCount; ++i) {
        if (_stricmp(word.c_str(), kMenuSwitches[i].key) == 0) {
          named[i] = found = true;
        }
      }
      if (!found) {
        std::string known;
        for (const MenuSwitch& menuSwitch : kMenuSwitches) {
          known += known.empty() ? "" : ", ";
          known += menuSwitch.key;
        }
        Log(L"menuOptions: %hs cannot follow the options menu (these can: %hs); ignored", word.c_str(),
            known.c_str());
        failed = true;
      }
    }
  }
  for (std::size_t i = 0; i < kCount; ++i) {
    if (!named[i]) {
      continue;
    }
    const MenuSwitch& menuSwitch = kMenuSwitches[i];
    // Until the player chooses, the key's own line decides: present, on; absent, off.
    const bool inCfg = config.Has(menuSwitch.key);
    const int slot = AddMenuOption({menuSwitch.key, menuSwitch.name, menuSwitch.key, {"off", "on"}, {L"off", L"on"}});
    if (slot < 0) {
      Log(L"menuOptions: %hs: no menu entry; the cfg alone decides", menuSwitch.key);
      failed = true;
      continue;
    }
    ++following;
    const int stored = MenuOptionStored(slot);
    const int value = stored >= 0 ? stored : (inCfg ? 1 : 0);
    SetMenuOptionValue(slot, value, false);
    Log(L"menuOptions: %hs follows %ls: %ls (%ls)", menuSwitch.key, menuSwitch.name, value != 0 ? L"on" : L"off",
        stored >= 0         ? L"the player's choice"
        : inCfg             ? L"no choice stored yet: its cfg line"
                            : L"no choice stored yet: no cfg line");
    if (value == 0 && inCfg) {
      config.Erase(menuSwitch.key);
    } else if (value != 0 && !inCfg) {
      config.Add(menuSwitch.key);  // with its defaults
    }
  }
  Log(L"menuOptions: %hs (%d keys follow the options menu)", failed ? "FAILED" : "applied", following);
}

}  // namespace uhc
