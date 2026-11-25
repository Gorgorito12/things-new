// editorAutosave: the scenario editor saves the open scenario every few minutes to rotating files.
//
//   editorAutosave [minutes] [keep N] [log]
//
// Every `minutes` (default 5, 0.5 to 1440) of real time in the editor, the open scenario is saved as autosave-1,
// autosave-2, ... autosave-N (keep N, default 3, 1 to 20): the first missing one, else the one written longest ago,
// in the folder where the editor saves every scenario (Documents\My Games\<the game's folder>\Scenario).
//
// How (docs/engine-symbols.md, "Scenario editor save"): the save is the game's own, the one the console command
// saveScenario reaches through the game's vtable +0C0h (FUN_00834583, thiscall(game, dir [0xD6FDB4], BString* name,
// char flag)), called from the Direct3D Present observer (after a Present, on the main thread, between two frames).
// The command itself is not used: after the save it puts the name in the editor's recent scenarios list. The save
// makes the name the open scenario's ([game+958h], and the flag [game+95Ch]), so the next File > Save would write
// the autosave: both are put back right after. Overwriting a scenario leaves the old file as .bak; the autosave's
// .bak is deleted, so N autosaves are N files.
//
// When: the editor is open ([game+0B3Ah], the gate of the editor's console commands; 0 in a playtest) and no save is
// running ([game+0AB0h]). Nothing is saved while a mouse button is held (a drag, a brush stroke): it waits. Nothing
// is saved when nothing can have changed since the editor opened or the last autosave: the editor's undo list is the
// same (its manager [game+928h]: the undo count, the last undo entry, the redo count) and the game window got no
// keyboard or mouse input (GetLastInputInfo while it had the focus); then the next try is one interval later.
// The notice: "Autosaved: autosave-K" for 2 s in the editor's own message dialog, the one the save shows while it
// writes (the editor has no chat).
//
// Editor only: nothing runs outside it, nothing reaches a game.
#include <windows.h>
#include <shlobj.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <string>

#include "../d3d9hooks.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../uigadgets.h"

namespace uhc {
namespace {

struct BString {
  wchar_t* text;
};

using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t id);
using BStringSetFn = void(__thiscall*)(BString* self, const BString* source);
using BStringFreeFn = void(__thiscall*)(BString* self);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringSet = reinterpret_cast<BStringSetFn>(0x0040196F);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);

// The game's scenario save (vtable +0C0h, the thunk 0x703ED3 to FUN_00834583); ret 0Ch, true when written.
using SaveScenarioFn = bool(__thiscall*)(char* game, std::int32_t dir, BString* name, std::int32_t flag);
constexpr std::uint32_t kSaveThunk = 0x00703ED3;  // [0xB886E8], the slot +0C0h of the game's vtable 0xB88628
constexpr std::uint32_t kSaveDir = 0x00D6FDB4;  // what 0x517BAA returns: the directory the handler saves to

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kScenarioName = 0x958;   // game: the open scenario's name, a BString
constexpr std::uint32_t kScenarioFlag = 0x95C;   // game: a byte the save sets from its flag
constexpr std::uint32_t kSaving = 0xAB0;         // game: a save is running
constexpr std::uint32_t kEditorGate = 0xB3A;     // game: the editor is open (its commands test it)
constexpr std::uint32_t kUndoManager = 0x928;    // game: the editor's undo manager
constexpr std::int32_t kMyGamesFolderString = 42265;  // "My Games\<folder>": where the profile and Scenario live

// The notice: the editor's own message dialog, the one the save shows while it writes ("Saving '%s' ...",
// 0x83A2B8): its handle [editor+12Ch] (editor = [game+920h]), its text the child ingame-messagedialog3-prompt (set
// through the gadget's vtable +80h), shown and hidden as gadgetReal / gadgetUnreal do (0x838CE8 hides it so).
constexpr std::uint32_t kEditor = 0x920;
constexpr std::uint32_t kEditorMessageDialog = 0x12C;
constexpr char kMessagePrompt[] = "ingame-messagedialog3-prompt";
constexpr ULONGLONG kNoticeMs = 2000;

double g_minutes = 5;
int g_keep = 3;
bool g_log = false;

bool g_open = false;      // the editor was open at the last frame
bool g_busy = false;      // inside a save: the save draws a frame of its own
ULONGLONG g_due = 0;      // GetTickCount64 at which the next save is due
std::wstring g_folder;    // the Scenario folder, with a trailing backslash; empty until found

// The editor's undo list at the last autosave (or when the editor opened).
struct Snapshot {
  const void* undoManager = nullptr;
  std::int32_t undoCount = 0;
  const void* undoTop = nullptr;
  std::int32_t redoCount = 0;
  bool operator==(const Snapshot& o) const {
    return undoManager == o.undoManager && undoCount == o.undoCount && undoTop == o.undoTop &&
           redoCount == o.redoCount;
  }
};
Snapshot g_saved;
DWORD g_lastInput = 0;     // GetLastInputInfo's time as last seen
bool g_inputSince = false;  // keyboard or mouse input while the game had the focus, since the last autosave

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

char* Game() { return *reinterpret_cast<char* const*>(kGameGlobal); }

bool EditorOpen(const char* game) { return game != nullptr && Field<std::uint8_t>(game, kEditorGate) != 0; }

// The undo manager (0x9BE4E2): the undo entries {data [um+0], count [um+4]}, the redo entries {[um+0Ch], [um+10h]}.
Snapshot Take(const char* game) {
  Snapshot now;
  const char* um = Field<const char*>(game, kUndoManager);
  if (um != nullptr) {
    now.undoManager = um;
    now.undoCount = Field<std::int32_t>(um, 0x04);
    const void* const* undo = Field<const void* const*>(um, 0x00);
    if (undo != nullptr && now.undoCount > 0) {
      now.undoTop = undo[now.undoCount - 1];
    }
    now.redoCount = Field<std::int32_t>(um, 0x10);
  }
  return now;
}

// Notes input the game window got: the system's last input changed while a window of this process had the focus.
void WatchInput() {
  LASTINPUTINFO input{sizeof(input), 0};
  if (!GetLastInputInfo(&input) || input.dwTime == g_lastInput) {
    return;
  }
  g_lastInput = input.dwTime;
  DWORD pid = 0;
  const HWND foreground = GetForegroundWindow();
  if (foreground != nullptr && GetWindowThreadProcessId(foreground, &pid) != 0 && pid == GetCurrentProcessId()) {
    g_inputSince = true;
  }
}

// The Scenario folder: Documents\<string 42265>\Scenario\, where the editor writes its scenarios.
const std::wstring& Folder() {
  if (!g_folder.empty()) {
    return g_folder;
  }
  wchar_t documents[MAX_PATH];
  if (FAILED(SHGetFolderPathW(nullptr, CSIDL_PERSONAL, nullptr, SHGFP_TYPE_CURRENT, documents))) {
    return g_folder;
  }
  BString games{nullptr};
  kBStringFromId(&games, kMyGamesFolderString);
  std::wstring sub = games.text == nullptr ? L"" : games.text;
  kBStringFree(&games);
  while (!sub.empty() && (sub.back() == L'\\' || sub.back() == L'/')) {
    sub.pop_back();
  }
  if (!sub.empty()) {
    g_folder = std::wstring(documents) + L"\\" + sub + L"\\Scenario\\";
  }
  return g_folder;
}

std::wstring SlotPath(int slot, const wchar_t* extension) {
  wchar_t name[40];
  swprintf_s(name, L"autosave-%d%ls", slot, extension);
  return Folder() + name;
}

// The slot to write: the first missing one, else the one written longest ago.
int NextSlot() {
  int oldest = 1;
  FILETIME oldestTime{0xFFFFFFFF, 0xFFFFFFFF};
  for (int slot = 1; slot <= g_keep; ++slot) {
    WIN32_FILE_ATTRIBUTE_DATA data;
    if (!GetFileAttributesExW(SlotPath(slot, L".age3Yscn").c_str(), GetFileExInfoStandard, &data)) {
      return slot;
    }
    if (CompareFileTime(&data.ftLastWriteTime, &oldestTime) < 0) {
      oldestTime = data.ftLastWriteTime;
      oldest = slot;
    }
  }
  return oldest;
}

std::int32_t g_noticeDialog = 0;  // the message dialog shown by Notice, hidden at g_noticeEnd
ULONGLONG g_noticeEnd = 0;

// Shows `text` in the editor's message dialog for kNoticeMs.
void Notice(const char* game, const wchar_t* text) {
  const char* editor = Field<const char*>(game, kEditor);
  if (editor == nullptr) {
    return;
  }
  const std::int32_t dialog = Field<std::int32_t>(editor, kEditorMessageDialog);
  void* dialogGadget = ui::Gadget(dialog, ui::kAnyGadget);
  void* prompt = dialogGadget == nullptr ? nullptr : ui::Gadget(ui::FindChild(dialogGadget, kMessagePrompt), ui::kAnyGadget);
  if (prompt == nullptr) {
    return;
  }
  BString line{nullptr};
  kBStringFromWide(&line, text);
  using SetTextFn = void(__thiscall*)(void* gadget, const BString* text);
  reinterpret_cast<SetTextFn>((*reinterpret_cast<void* const* const*>(prompt))[0x80 / 4])(prompt, &line);
  kBStringFree(&line);
  ui::Show(dialog, true);
  g_noticeDialog = dialog;
  g_noticeEnd = GetTickCount64() + kNoticeMs;
}

void HideNotice() {
  if (g_noticeDialog != 0 && GetTickCount64() >= g_noticeEnd) {
    ui::Show(g_noticeDialog, false);  // nothing for a handle gone stale
    g_noticeDialog = 0;
  }
}

double Ms(const LARGE_INTEGER& start) {
  LARGE_INTEGER now, frequency;
  QueryPerformanceCounter(&now);
  QueryPerformanceFrequency(&frequency);
  return 1000.0 * static_cast<double>(now.QuadPart - start.QuadPart) / static_cast<double>(frequency.QuadPart);
}

void Save(char* game) {
  if (Folder().empty()) {
    Log(L"editorAutosave: no Scenario folder (string %d is empty); nothing saved", kMyGamesFolderString);
    return;
  }
  const int slot = NextSlot();
  BString* nameField = reinterpret_cast<BString*>(game + kScenarioName);
  const std::wstring name = nameField->text == nullptr ? L"" : nameField->text;
  const std::uint8_t flag = Field<std::uint8_t>(game, kScenarioFlag);

  wchar_t autosave[40];
  swprintf_s(autosave, L"autosave-%d", slot);
  BString target{nullptr};
  kBStringFromWide(&target, autosave);
  // The game object's own vtable +0C0h, which must be the stock thunk the verified slot holds.
  const auto save = reinterpret_cast<SaveScenarioFn>(Field<void* const*>(game, 0)[0xC0 / 4]);
  if (reinterpret_cast<std::uint32_t>(save) != kSaveThunk) {
    Log(L"editorAutosave: the game's save is not the stock one (0x%08X); nothing saved",
        reinterpret_cast<std::uint32_t>(save));
    kBStringFree(&target);
    return;
  }
  LARGE_INTEGER start;
  QueryPerformanceCounter(&start);
  g_busy = true;
  const bool ok = save(game, *reinterpret_cast<const std::int32_t*>(kSaveDir), &target, 1);
  g_busy = false;
  const double ms = Ms(start);
  kBStringFree(&target);

  // The open scenario keeps its name: File > Save writes the user's file, not the autosave.
  BString restored{nullptr};
  kBStringFromWide(&restored, name.c_str());
  kBStringSet(nameField, &restored);
  kBStringFree(&restored);
  *reinterpret_cast<std::uint8_t*>(game + kScenarioFlag) = flag;

  DeleteFileW(SlotPath(slot, L".bak").c_str());
  WIN32_FILE_ATTRIBUTE_DATA data{};
  const bool written =
      ok && GetFileAttributesExW(SlotPath(slot, L".age3Yscn").c_str(), GetFileExInfoStandard, &data) != 0;
  if (written) {
    wchar_t text[80];
    swprintf_s(text, L"Autosaved: %ls", autosave);
    Notice(game, text);
  }
  if (g_log || !written) {
    Log(L"editorAutosave: %ls %ls (%.0f ms%ls); the open scenario keeps its name \"%ls\"",
        written ? L"saved" : L"FAILED to save", autosave, ms,
        written ? (L", " + std::to_wstring(data.nFileSizeLow) + L" bytes").c_str() : L"", name.c_str());
  }
}

ULONGLONG IntervalMs() { return static_cast<ULONGLONG>(g_minutes * 60000.0); }

void AfterPresent(HRESULT) {
  if (g_busy) {
    return;  // the save's own frame
  }
  HideNotice();
  char* game = Game();
  if (!EditorOpen(game)) {
    if (g_open && g_log) {
      Log(L"editorAutosave: the editor closed");
    }
    g_open = false;
    return;
  }
  const ULONGLONG now = GetTickCount64();
  WatchInput();
  if (!g_open) {
    g_open = true;
    g_due = now + IntervalMs();  // the clock starts when the editor opens
    g_saved = Take(game);
    g_inputSince = false;
    if (g_log) {
      Log(L"editorAutosave: the editor is open; the first autosave in %.1f min", g_minutes);
    }
    return;
  }
  if (now < g_due) {
    return;
  }
  if (Field<std::uint8_t>(game, kSaving) != 0 ||
      ((GetAsyncKeyState(VK_LBUTTON) | GetAsyncKeyState(VK_RBUTTON) | GetAsyncKeyState(VK_MBUTTON)) & 0x8000) != 0) {
    return;  // a save of the game's own, or a mouse button held: tried again next frame
  }
  const Snapshot current = Take(game);
  g_due = now + IntervalMs();
  if (current == g_saved && !g_inputSince) {
    if (g_log) {
      Log(L"editorAutosave: nothing changed since the last autosave; skipped");
    }
    return;
  }
  Save(game);
  g_saved = Take(game);
  g_inputSince = false;
}

}  // namespace

Outcome ApplyEditorAutosave(const Config& config) {
  const auto* args = config.First("editorAutosave");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (std::size_t i = 0; i < args->size(); ++i) {
    const std::string& word = (*args)[i];
    char* end = nullptr;
    if (_stricmp(word.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(word.c_str(), "keep") == 0 && i + 1 < args->size()) {
      const std::string& value = (*args)[++i];
      const long keep = std::strtol(value.c_str(), &end, 10);
      if (end == value.c_str() || *end != 0 || keep < 1 || keep > 20) {
        Log(L"editorAutosave: keep \"%hs\" ignored (1 to 20)", value.c_str());
      } else {
        g_keep = static_cast<int>(keep);
      }
    } else if (const double minutes = std::strtod(word.c_str(), &end); end != word.c_str() && *end == 0) {
      if (minutes < 0.5 || minutes > 1440) {
        Log(L"editorAutosave: %hs minutes ignored (0.5 to 1440)", word.c_str());
      } else {
        g_minutes = minutes;
      }
    } else {
      Log(L"editorAutosave: unknown argument \"%hs\" ignored (expected minutes, keep N, log)", word.c_str());
    }
  }
  if (!ui::VerifyUiGadgets("editorAutosave") || !ui::VerifyUiShow("editorAutosave") ||
      !VerifyAll("editorAutosave",
                 {&sites::kBStringFromWide, &sites::kBStringFromId, &sites::kBStringSet, &sites::kBStringFree,
                  &sites::kEditorGate, &sites::kEditorUndoManager, &sites::kEditorUndoCounts, &sites::kEditorSaveCall,
                  &sites::kEditorSaveSlot, &sites::kEditorSaveThunk, &sites::kEditorSaveHead,
                  &sites::kEditorSaveSetsName, &sites::kEditorSaveDir, &sites::kEditorMessageHide,
                  &sites::kEditorMessagePromptName})) {
    return Outcome::kFailed;
  }
  if (!AddD3D9Observer({nullptr, nullptr, nullptr, &AfterPresent}, "editorAutosave")) {
    return Outcome::kFailed;
  }
  Log(L"editorAutosave: every %.1f min in the editor, to autosave-1 ... autosave-%d%ls", g_minutes, g_keep,
      g_log ? L"; log on" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
