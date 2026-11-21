// lanAutoStart: takes the game from the main menu to a LAN game with no clicks, for a launcher that has already
// agreed with the other players on who hosts. Either it hosts a game, or it joins the host's game by Direct IP.
//
//   lanAutoStart                 the action comes from the game's command line (below); nothing without one
//   lanAutoStart host [rules=N]  host a LAN game, with that Game Rules entry (0 = the first)
//   lanAutoStart join <address>  join the game hosted at <address> (Direct IP)
//
// On the command line, `+uhcLanHost` hosts and `uhcLanJoin="<address>"` joins, the syntax of the stock
// `OverrideAddress="<address>"`; `uhcLanRules=N` picks the host's Game Rules entry. The command line wins over the cfg's arguments. For a VPN such as Radmin, the
// launcher passes OverrideAddress (the host's VPN address, so the game binds there) and gives the joiners that
// address in uhcLanJoin.
//
// Stock route (docs/how-it-works.md, lanAutoStart): the console command doMPSetup(false) sets the SkirmHomeCity
// screen's next screen to MPLoginScreen and opens it (FUN_006F0BEE); that screen's Play switches to it.
// MPLoginScreen keeps the handle of MPLanBrowserDialog (uimplanip.xml, "LAN / Direct IP") at [screen+54h]. The
// dialog's activation creates the LAN browser [dlg+1ACh]; its click switch calls 0x8BBD88(dlg, 0) for Host and
// 0x8BB710(dlg) for Join IP, which reads the MPLanIP-DirectIPEditBox gadget [dlg+17Ch]. This key does what the
// clicks do: the console command, the screen switch, the edit box's text through the gadget's set-text slot
// (vtable +80h, the call the activation makes for the game name), then the button's routine. It writes nothing
// in the exe; every address it calls is verified first.
#include <windows.h>

#include <cstdint>
#include <cstring>
#include <cwchar>
#include <cwctype>
#include <string>

#include "../d3d9hooks.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace uhc {
namespace {

constexpr std::uint32_t kUiGlobal = 0x00C66244;          // [+44h] gadget manager, [+60h] screen manager
constexpr std::uint32_t kConsoleObject = 0x00C672E4;
constexpr std::uint32_t kLoginScreenVtable = 0x00B95788;  // MPLoginScreen (slot 18: its init 0x8BD408)
constexpr std::uint32_t kLanBrowserVtable = 0x00B8CE10;   // MPLanBrowserDialog
constexpr std::int32_t kSkirmHomeCityScreen = 0x36;
constexpr std::int32_t kEditBoxType = 0x23;              // the type FUN_004420BA asks 0x40423C for
constexpr std::int32_t kDropdownType = 0x0D;             // the type FUN_0046AC10 asks 0x40423C for
// FUN_008BA62E adds exactly entries 0..7 to the Game Rules dropdown (Standard, Classic, four treaties, treaty with
// no blockade, King of the Hill). [dropdown+19Ch] counts per-entry data, which this list does not have.
constexpr std::int32_t kRulesEntries = 8;

struct BString {
  wchar_t* text;
};

using ExecuteCommandFn = int(__fastcall*)(void* console, void* edx, const char* command, const char* source);
using GadgetLookupFn = void*(__fastcall*)(void* manager, void* edx, std::int32_t handle, std::int32_t type);
using SwitchScreenFn = void(__fastcall*)(void* manager, void* edx, std::int32_t id, std::int32_t flag);
using SetTextFn = void(__fastcall*)(void* gadget, void* edx, const BString* text);
using HostFn = void(__fastcall*)(void* dialog, void* edx, std::int32_t flag);
using JoinIpFn = void(__fastcall*)(void* dialog, void* edx);
using BStringFromWideFn = BString*(__fastcall*)(BString* self, void* edx, const wchar_t* text);
using BStringFreeFn = void(__fastcall*)(BString* self, void* edx);
using ScreenResolveFn = void*(__cdecl*)(std::int32_t handle);
using DropdownSelectFn = void(__fastcall*)(void* dropdown, void* edx, std::int32_t index, std::int32_t flag);
using DropdownCurrentFn = std::int32_t(__fastcall*)(void* dropdown, void* edx);
using ClockFn = std::uint32_t(__cdecl*)();

const auto kExecuteCommand = reinterpret_cast<ExecuteCommandFn>(0x00433D0D);
const auto kGadgetLookup = reinterpret_cast<GadgetLookupFn>(0x0040423C);
const auto kHost = reinterpret_cast<HostFn>(0x008BBD88);
const auto kJoinIp = reinterpret_cast<JoinIpFn>(0x008BB710);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kScreenResolve = reinterpret_cast<ScreenResolveFn>(0x0040439A);
const auto kDropdownSelect = reinterpret_cast<DropdownSelectFn>(0x005C36AE);
const auto kDropdownCurrent = reinterpret_cast<DropdownCurrentFn>(0x00AC0D1B);
const auto kGameClock = reinterpret_cast<ClockFn>(0x00402DFF);

enum class Action { kNone, kHost, kJoin };
enum class Step { kWaitMenu, kAfterSetup, kWaitDialog, kSettle, kJoinRetry, kDone };

Action g_action = Action::kNone;
std::wstring g_address;
Step g_step = Step::kWaitMenu;
ULONGLONG g_firstFrame = 0;
ULONGLONG g_stepStart = 0;
int g_attempts = 0;
constexpr int kMaxAttempts = 3;
constexpr ULONGLONG kMenuDelayMs = 3000;      // after the first frame, so the main menu is up
constexpr ULONGLONG kSetupDelayMs = 1500;     // doMPSetup -> the home city screen
constexpr ULONGLONG kDialogTimeoutMs = 15000;
constexpr ULONGLONG kSettleMs = 750;          // the dialog's activation done and drawn once
constexpr ULONGLONG kGiveUpMs = 120000;
// Every copy is launched at once, so a joiner can press Connect before the host's game exists: the stock answer is
// "game not found" and the LAN screen stays. While it stays, Connect is pressed again, never while the game is still
// waiting for an answer to the last one (its countdown), for at most kJoinWindowMs.
constexpr ULONGLONG kJoinRetryMs = 3000;
// A joiner waits this much longer before its first Connect: the host loads the same game and hosts about a second
// after its own dialog opens, so the first Connect then usually finds the game. A Connect that times out shows the
// game's single message dialog ("No game was found"); a later one only rewrites it, it never stacks (0x5183C6).
constexpr ULONGLONG kJoinFirstDelayMs = 5000;
constexpr ULONGLONG kJoinWindowMs = 180000;
int g_joins = 0;
ULONGLONG g_firstJoin = 0;
// The host's Game Rules entry; -1 leaves the game's own choice.
std::int32_t g_rules = -1;

template <typename T>
T Read(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

char* Ui() { return *reinterpret_cast<char* const*>(kUiGlobal); }
void* ScreenManager() { return Ui() == nullptr ? nullptr : Read<void*>(Ui(), 0x60); }
void* GadgetManager() { return Ui() == nullptr ? nullptr : Read<void*>(Ui(), 0x44); }

std::uint32_t Vtable(const void* object) { return object == nullptr ? 0 : Read<std::uint32_t>(object, 0); }

// The screen manager's list, as FUN_0044BEDD walks it (count [+8], array [+4], ID [screen+0Ch]); read here so a
// missing screen is not the lookup's assert path.
void* FindScreen(bool (*match)(void* screen, std::int32_t id), std::int32_t id) {
  void* manager = ScreenManager();
  if (manager == nullptr) {
    return nullptr;
  }
  const std::int32_t count = Read<std::int32_t>(manager, 8);
  void* const* screens = Read<void* const*>(manager, 4);
  if (count <= 0 || count > 512 || screens == nullptr) {
    return nullptr;
  }
  for (std::int32_t i = 0; i < count; ++i) {
    if (screens[i] != nullptr && match(screens[i], id)) {
      return screens[i];
    }
  }
  return nullptr;
}

bool ById(void* screen, std::int32_t id) { return Read<std::int32_t>(screen, 0x0C) == id; }

// The screen doMPSetup(false) makes the home city screen's next one (mov [eax+3Ch],2Eh, site LanDoMpSetupLan).
constexpr std::int32_t kLoginScreen = 0x2E;

// The list holds descriptors; the screen is the handle at [descriptor+4], resolved by 0x40439A.
void* LoginScreen() {
  void* descriptor = FindScreen(&ById, kLoginScreen);
  if (descriptor == nullptr) {
    return nullptr;
  }
  void* screen = kScreenResolve(Read<std::int32_t>(descriptor, 4));
  return Vtable(screen) == kLoginScreenVtable ? screen : nullptr;
}

void LogScreens() {
  void* manager = ScreenManager();
  if (manager == nullptr) {
    return;
  }
  const std::int32_t count = Read<std::int32_t>(manager, 8);
  void* const* screens = Read<void* const*>(manager, 4);
  std::wstring text;
  for (std::int32_t i = 0; i < count && i < 128 && screens != nullptr; ++i) {
    wchar_t item[32];
    swprintf_s(item, L" %d:%08X", screens[i] != nullptr ? Read<std::int32_t>(screens[i], 0x0C) : -1,
               Vtable(screens[i]));
    text += item;
  }
  Log(L"lanAutoStart: %d screens (id:vtable):%ls", count, text.c_str());
}

// MPLanBrowserDialog, recognised. Stock its vtable is 0xB8CE10. A mod's own DLL can replace that pointer with a table of
// its own in which every entry forwards through its code, so a vtable comparison refuses the very dialog the game
// made. The object, its fields and the routines this key calls are still the stock class's, so a dialog with
// another vtable is taken when the gadgets its init bound are where the init put them: the game name and Direct IP
// edit boxes ([+164h], [+17Ch], type 23h) and the Game Type and Game Rules dropdowns ([+168h], [+190h], type 0Dh).
// It is reached from the login screen's own [+54h] (whose vtable is checked), so this is a second check, not the
// only one.
bool IsLanBrowser(void* dialog) {
  if (dialog == nullptr) {
    return false;
  }
  const std::uint32_t vtable = Vtable(dialog);
  if (vtable == kLanBrowserVtable) {
    return true;
  }
  void* gadgets = GadgetManager();
  auto has = [&](std::uint32_t offset, std::int32_t type) {
    return kGadgetLookup(gadgets, nullptr, Read<std::int32_t>(dialog, offset), type) != nullptr;
  };
  const bool shaped = has(0x164, kEditBoxType) && has(0x17C, kEditBoxType) && has(0x168, kDropdownType) &&
                      has(0x190, kDropdownType);
  static std::uint32_t told = 0;
  if (vtable != told) {
    told = vtable;
    Log(shaped ? L"lanAutoStart: the LAN dialog has another DLL's vtable (%08X); recognised by its gadgets"
               : L"lanAutoStart: the LAN dialog's vtable %08X is not the game's and its gadgets do not match; "
                 L"not the dialog",
        vtable);
  }
  return shaped;
}

void* LanBrowser() {
  void* screen = LoginScreen();
  void* gadgets = GadgetManager();
  if (screen == nullptr || gadgets == nullptr) {
    return nullptr;
  }
  void* dialog = kGadgetLookup(gadgets, nullptr, Read<std::int32_t>(screen, 0x54), 0);
  return IsLanBrowser(dialog) ? dialog : nullptr;
}

// The dialog is shown (bit 0 of [gadget+0A4h], the bit the base activation 0x447BBC tests) and its LAN browser
// exists: what its buttons need. [dlg+1ACh] alone is not enough: the deactivation releases the browser and leaves the
// pointer.
bool BrowserReady(void* dialog) {
  return dialog != nullptr && (Read<std::uint8_t>(dialog, 0xA4) & 1) != 0 && Read<void*>(dialog, 0x1AC) != nullptr;
}

void Execute(const char* command) {
  void* console = *reinterpret_cast<void* const*>(kConsoleObject);
  if (console == nullptr) {
    return;
  }
  kExecuteCommand(console, nullptr, command, "console");
}

void SwitchScreen(std::int32_t id) {
  void* manager = ScreenManager();
  const auto vtable = reinterpret_cast<void* const*>(Vtable(manager));
  reinterpret_cast<SwitchScreenFn>(vtable[0x14 / 4])(manager, nullptr, id, 0);
}

void* Dropdown(void* dialog, std::uint32_t offset) {
  return kGadgetLookup(GadgetManager(), nullptr, Read<std::int32_t>(dialog, offset), kDropdownType);
}

// Picks the host's Game Rules the way the dialog's own fill picks its first entry (0x5C36AE(index, 0)). The Game
// Type is left as the game opens it (Supremacy); its Deathmatch would force and hide the rules.
void SelectHostOptions(void* dialog) {
  if (g_rules >= 0) {
    void* rules = Dropdown(dialog, 0x190);
    if (rules == nullptr || g_rules >= kRulesEntries) {
      Log(L"lanAutoStart: Game Rules entry %d does not exist (%d entries); left as it is", g_rules, kRulesEntries);
    } else {
      kDropdownSelect(rules, nullptr, g_rules, 0);
      const std::int32_t now = kDropdownCurrent(rules, nullptr);
      if (now == g_rules) {
        Log(L"lanAutoStart: Game Rules entry %d", now);
      } else {
        Log(L"lanAutoStart: Game Rules entry %d asked, the dropdown shows %d", g_rules, now);
      }
    }
  }
}

// The game is still waiting for the answer to the last Connect: its countdown, [1B4h] + [1B0h] on the game clock.
bool JoinPending(void* dialog) {
  const std::uint32_t timeout = Read<std::uint32_t>(dialog, 0x1B0);
  const std::uint32_t started = Read<std::uint32_t>(dialog, 0x1B4);
  return timeout != 0 && kGameClock() - started < timeout;
}

// What the Host button's click calls: the call at 0x8BC559 (site LanBrowserClickHost). Stock that is 0x8BBD88;
// a mod's own DLL can point it at a wrapper that runs its code and then the stock routine, and calling 0x8BBD88 directly
// would skip it. Read when hosting, since another DLL may patch it after this one applied. Taken only when it is
// executable code of a loaded module; anything else is refused.
HostFn HostRoutine() {
  const auto next = reinterpret_cast<const BYTE*>(0x008BC55E);
  const auto target = reinterpret_cast<std::uintptr_t>(next) + *reinterpret_cast<const std::int32_t*>(0x008BC55A);
  if (target == reinterpret_cast<std::uintptr_t>(kHost)) {
    return kHost;
  }
  MEMORY_BASIC_INFORMATION info{};
  constexpr DWORD kExecutable = PAGE_EXECUTE | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY;
  if (VirtualQuery(reinterpret_cast<const void*>(target), &info, sizeof(info)) != sizeof(info) ||
      info.State != MEM_COMMIT || info.Type != MEM_IMAGE || (info.Protect & kExecutable) == 0) {
    Log(L"lanAutoStart: the Host button calls %08X, which is not code of a loaded module; not hosting",
        static_cast<unsigned>(target));
    return nullptr;
  }
  HMODULE module = nullptr;
  wchar_t path[MAX_PATH] = L"?";
  if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         reinterpret_cast<LPCWSTR>(target), &module)) {
    GetModuleFileNameW(module, path, MAX_PATH);
  }
  const wchar_t* name = wcsrchr(path, L'\\');
  Log(L"lanAutoStart: the Host button calls %ls+%X (another DLL's hook); calling it as the click does",
      name != nullptr ? name + 1 : path,
      static_cast<unsigned>(target - reinterpret_cast<std::uintptr_t>(module)));
  return reinterpret_cast<HostFn>(target);
}

bool Act(void* dialog) {
  if (g_action == Action::kHost) {
    const HostFn host = HostRoutine();
    if (host == nullptr) {
      return false;
    }
    SelectHostOptions(dialog);
    Log(L"lanAutoStart: hosting a LAN game");
    host(dialog, nullptr, 0);
    return true;
  }
  void* box = kGadgetLookup(GadgetManager(), nullptr, Read<std::int32_t>(dialog, 0x17C), kEditBoxType);
  if (box == nullptr) {
    Log(L"lanAutoStart: the Direct IP box was not found; not joining");
    return false;
  }
  BString text{nullptr};
  kBStringFromWide(&text, nullptr, g_address.c_str());
  const auto vtable = reinterpret_cast<void* const*>(Vtable(box));
  reinterpret_cast<SetTextFn>(vtable[0x80 / 4])(box, nullptr, &text);
  kBStringFree(&text, nullptr);
  Log(L"lanAutoStart: joining %ls by Direct IP", g_address.c_str());
  kJoinIp(dialog, nullptr);
  // 0 is the browser refusing at once, with a message box: pressing again would stack them.
  if (Read<std::uint32_t>(dialog, 0x1B0) == 0) {
    Log(L"lanAutoStart: Connect was refused at once; not pressed again");
    return false;
  }
  return true;
}

void Begin(ULONGLONG now) {
  if (++g_attempts > kMaxAttempts) {
    Log(L"lanAutoStart: the LAN screen did not open after %d attempts; stopped", kMaxAttempts);
    g_step = Step::kDone;
    return;
  }
  Log(L"lanAutoStart: attempt %d: doMPSetup(false)", g_attempts);
  Execute("doMPSetup(false)");
  g_step = Step::kAfterSetup;
  g_stepStart = now;
}

void AfterPresent(HRESULT) {
  if (g_step == Step::kDone) {
    return;
  }
  const ULONGLONG now = GetTickCount64();
  if (g_firstFrame == 0) {
    g_firstFrame = now;
    return;
  }
  if (now - g_firstFrame > kGiveUpMs && g_step != Step::kJoinRetry) {
    Log(L"lanAutoStart: gave up %llu s after the first frame", kGiveUpMs / 1000);
    g_step = Step::kDone;
    return;
  }
  void* dialog = LanBrowser();
  switch (g_step) {
    case Step::kWaitMenu:
      if (now - g_firstFrame >= kMenuDelayMs && Ui() != nullptr && ScreenManager() != nullptr &&
          *reinterpret_cast<void* const*>(kConsoleObject) != nullptr) {
        Begin(now);
      }
      break;
    case Step::kAfterSetup:
      if (now - g_stepStart >= kSetupDelayMs) {
        void* homeCity = FindScreen(&ById, kSkirmHomeCityScreen);
        const std::int32_t next = homeCity != nullptr ? Read<std::int32_t>(homeCity, 0x3C) : -1;
        if (next != kLoginScreen) {
          Log(L"lanAutoStart: doMPSetup did not take yet (home city next screen %d); retrying", next);
          --g_attempts;  // the menu was not ready: not a failed attempt
          g_step = Step::kWaitMenu;
          g_firstFrame = now - kMenuDelayMs + 2000;  // the next attempt in 2 s
          break;
        }
        Log(L"lanAutoStart: home city screen -> screen %d", kLoginScreen);
        SwitchScreen(kLoginScreen);
        g_step = Step::kWaitDialog;
        g_stepStart = now;
      }
      break;
    case Step::kWaitDialog:
      if (BrowserReady(dialog)) {
        Log(L"lanAutoStart: the LAN / Direct IP dialog is open");
        g_step = Step::kSettle;
        g_stepStart = now;
      } else if (now - g_stepStart >= kDialogTimeoutMs) {
        void* descriptor = FindScreen(&ById, kLoginScreen);
        const std::int32_t handle = descriptor != nullptr ? Read<std::int32_t>(descriptor, 4) : -1;
        void* screen = descriptor != nullptr ? kScreenResolve(handle) : nullptr;
        void* gadgets = GadgetManager();
        void* browser = screen != nullptr && gadgets != nullptr
                            ? kGadgetLookup(gadgets, nullptr, Read<std::int32_t>(screen, 0x54), 0)
                            : nullptr;
        Log(L"lanAutoStart: the LAN / Direct IP dialog did not open (descriptor %d: %p, handle %d, screen %p vtable "
            L"%08X, [+54h] %d -> %p vtable %08X); retrying",
            kLoginScreen, descriptor, handle, screen, Vtable(screen),
            screen != nullptr ? Read<std::int32_t>(screen, 0x54) : -1, browser, Vtable(browser));
        LogScreens();
        Begin(now);
      }
      break;
    case Step::kSettle:
      if (!BrowserReady(dialog)) {
        g_step = Step::kWaitDialog;
        g_stepStart = now;
      } else if (now - g_stepStart >= kSettleMs + (g_action == Action::kJoin ? kJoinFirstDelayMs : 0)) {
        // Before acting: the routines may show a dialog and present frames.
        g_step = g_action == Action::kJoin ? Step::kJoinRetry : Step::kDone;
        g_stepStart = now;
        g_firstJoin = now;
        ++g_joins;
        if (!Act(dialog)) {
          g_step = Step::kDone;
        }
      }
      break;
    case Step::kJoinRetry:
      if (dialog == nullptr || !BrowserReady(dialog)) {
        Log(L"lanAutoStart: left the LAN screen after %d Connect(s)", g_joins);
        g_step = Step::kDone;
      } else if (JoinPending(dialog)) {
        g_stepStart = now;  // the next press counts from the end of this wait
      } else if (now - g_stepStart >= kJoinRetryMs) {
        if (now - g_firstJoin >= kJoinWindowMs) {
          Log(L"lanAutoStart: still on the LAN screen after %d Connects in %llu s; stopped", g_joins,
              kJoinWindowMs / 1000);
          g_step = Step::kDone;
          break;
        }
        Log(L"lanAutoStart: still on the LAN screen; Connect again");
        g_stepStart = now;
        ++g_joins;
        if (!Act(dialog)) {
          g_step = Step::kDone;
        }
      }
      break;
    case Step::kDone:
      break;
  }
}

bool AddressCharsOk(const std::wstring& address) {
  if (address.empty() || address.size() > 64) {
    return false;
  }
  for (wchar_t c : address) {
    if (!(iswalnum(c) || c == L'.' || c == L'-' || c == L':')) {
      return false;
    }
  }
  return true;
}

// Finds `name` as a whole token of the command line, case-insensitive, optionally after '+'.
std::size_t FindToken(const std::wstring& line, const wchar_t* name) {
  const std::size_t length = wcslen(name);
  for (std::size_t i = 0; i + length <= line.size(); ++i) {
    if (_wcsnicmp(line.c_str() + i, name, length) != 0) {
      continue;
    }
    const bool startOk = i == 0 || line[i - 1] == L' ' || line[i - 1] == L'+' || line[i - 1] == L'\t' ||
                         line[i - 1] == L'"';
    const wchar_t after = i + length < line.size() ? line[i + length] : L'\0';
    const bool endOk = after == L'\0' || after == L' ' || after == L'\t' || after == L'=' || after == L'"';
    if (startOk && endOk) {
      return i + length;
    }
  }
  return std::wstring::npos;
}

// A small entry index, 0..63, or -1 for none or anything else.
std::int32_t ParseIndex(const std::wstring& text) {
  if (text.empty() || text.size() > 2) {
    return -1;
  }
  std::int32_t value = 0;
  for (wchar_t c : text) {
    if (c < L'0' || c > L'9') {
      return -1;
    }
    value = value * 10 + (c - L'0');
  }
  return value <= 63 ? value : -1;
}

// name=N, name="N" or name N on the command line; -1 when absent or not an index (logged).
std::int32_t ReadIndexToken(const std::wstring& line, const wchar_t* name) {
  std::size_t at = FindToken(line, name);
  if (at == std::wstring::npos) {
    return -1;
  }
  while (at < line.size() && (line[at] == L' ' || line[at] == L'=' || line[at] == L'\t' || line[at] == L'"')) {
    ++at;
  }
  std::wstring text;
  while (at < line.size() && line[at] != L'"' && line[at] != L' ' && line[at] != L'\t') {
    text += line[at++];
  }
  const std::int32_t value = ParseIndex(text);
  if (value < 0) {
    Log(L"lanAutoStart: %ls on the command line is not an entry number (0-63); ignored", name);
  }
  return value;
}

// uhcLanJoin="1.2.3.4", uhcLanJoin=1.2.3.4 or uhcLanJoin 1.2.3.4.
bool ReadCommandLine() {
  const std::wstring line = GetCommandLineW();
  g_rules = ReadIndexToken(line, L"uhcLanRules");
  std::size_t at = FindToken(line, L"uhcLanJoin");
  if (at != std::wstring::npos) {
    while (at < line.size() && (line[at] == L' ' || line[at] == L'=' || line[at] == L'\t')) {
      ++at;
    }
    if (at < line.size() && line[at] == L'"') {
      ++at;
    }
    std::wstring address;
    while (at < line.size() && line[at] != L'"' && line[at] != L' ' && line[at] != L'\t') {
      address += line[at++];
    }
    if (!AddressCharsOk(address)) {
      Log(L"lanAutoStart: uhcLanJoin on the command line has no valid address; ignored");
      return false;
    }
    g_action = Action::kJoin;
    g_address = address;
    return true;
  }
  if (FindToken(line, L"uhcLanHost") != std::wstring::npos) {
    g_action = Action::kHost;
    return true;
  }
  return false;
}

}  // namespace

Outcome ApplyLanAutoStart(const Config& config) {
  const auto* args = config.First("lanAutoStart");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!ReadCommandLine() && !args->empty()) {
    if (_stricmp((*args)[0].c_str(), "host") == 0) {
      g_action = Action::kHost;
      for (std::size_t i = 1; i < args->size(); ++i) {
        const std::string& word = (*args)[i];
        const std::wstring value(word.begin() + (word.find('=') == std::string::npos ? word.size() : word.find('=') + 1),
                                 word.end());
        if (_strnicmp(word.c_str(), "rules=", 6) == 0) {
          g_rules = ParseIndex(value);
        } else {
          Log(L"lanAutoStart: unknown host argument \"%hs\"; expected rules=N", word.c_str());
        }
      }
    } else if (_stricmp((*args)[0].c_str(), "join") == 0 && args->size() >= 2) {
      g_address.assign((*args)[1].begin(), (*args)[1].end());
      if (AddressCharsOk(g_address)) {
        g_action = Action::kJoin;
      } else {
        Log(L"lanAutoStart: \"%hs\" is not an address", (*args)[1].c_str());
      }
    } else {
      Log(L"lanAutoStart: unknown arguments; expected host or join <address>");
    }
  }
  if (g_action == Action::kNone) {
    Log(L"lanAutoStart: no action (no +uhcLanHost or uhcLanJoin=\"<address>\" on the command line)");
    return Outcome::kApplied;
  }
  if (!VerifyAll("lanAutoStart",
                 {&sites::kLanConsoleExecute, &sites::kLanDoMpSetupLan, &sites::kLanScreenLookup,
                  &sites::kLanLoginDescriptorHandle, &sites::kLanScreenResolve,
                  &sites::kLanLoginScreenInit, &sites::kLanLoginScreenBrowser, &sites::kLanGadgetLookup,
                  &sites::kLanGadgetShownFlag,
                  &sites::kLanBrowserHostGadget, &sites::kLanBrowserIpGadget, &sites::kLanBrowserSession,
                  &sites::kLanBrowserSetText, &sites::kLanBrowserClickHost, &sites::kLanBrowserClickHostNext,
                  &sites::kLanBrowserClickJoinIp,
                  &sites::kLanBrowserHost, &sites::kLanBrowserJoinIp, &sites::kBStringFromWide,
                  &sites::kBStringFree, &sites::kLanBrowserRulesGadget, &sites::kLanBrowserNameGadget,
                  &sites::kLanBrowserModeGadget, &sites::kLanDropdownSelect,
                  &sites::kLanBrowserRulesFill, &sites::kLanDropdownCurrent, &sites::kLanGameClock,
                  &sites::kLanBrowserJoinRequest, &sites::kLanBrowserJoinStart, &sites::kLanBrowserCountdown})) {
    return Outcome::kFailed;
  }
  if (!AddD3D9Observer({nullptr, nullptr, nullptr, &AfterPresent}, "lanAutoStart")) {
    return Outcome::kFailed;
  }
  Log(L"lanAutoStart: will %ls once the main menu is up", g_action == Action::kHost ? L"host a LAN game"
                                                                                    : (L"join " + g_address).c_str());
  if (g_action == Action::kHost && g_rules >= 0) {
    Log(L"lanAutoStart: Game Rules entry %d", g_rules);
  }
  return Outcome::kApplied;
}

}  // namespace uhc
