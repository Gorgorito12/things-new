// editorSearch: search fields in the scenario editor. A textField that the layout adds filters a stock list as
// the player types: the Objects palette (uieditorpalettes.xml, EditorProtoPalette, field EditorProtoPaletteSearch)
// and the allowed list of the Forbidden Units/Techs dialog (uiforbiddenunitstechs.xml, field
// ForbiddenUnitsTechs_Search). The match is case-insensitive; every word of the text must appear in the text the
// list shows, or in a proto's internal or display name (techs: their internal name, which the list shows). An
// empty field is the stock list. A layout without the field is the stock dialog.
//
//   editorSearch [log]
//
// How: the fills of both lists add one entry per proto or tech through one call; that call is redirected
// (hooks/editorsearch_hooks.asm) and asks this file whether the entry matches. A typed character changes the text of
// the field's editBox and nothing else, so the text is read once a frame (the Direct3D Present observer: a string
// compare, nothing more unless the text changed) and a change, once the typing pauses for 250 ms, refills the
// list with the stock code: the palette's refresh slot (vtable +20h: it empties the entries, runs the fill
// FUN_007F501E and shows the buttons), and the dialog's fill of its display mode (FUN_0099912F units, FUN_00999493
// techs) followed by the list's layout, as the dialog's own refresh does. The editor only: no simulation, nothing saved, nothing sent.
#include <windows.h>

#include <cstdint>
#include <cwctype>
#include <string>
#include <vector>

#include "../d3d9hooks.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../uigadgets.h"

extern "C" void UhcEditorPaletteAddHook();
extern "C" void UhcEditorForbidUnitHook();
extern "C" void UhcEditorForbidTechHook();

namespace uhc {
namespace {

constexpr std::uint32_t kPaletteVtable = 0x00B92768;
constexpr std::uint32_t kPaletteObjectsFill = 0x007F501E;  // [palette+17Ch] of EditorProtoPalette (0x7F5C51)
constexpr std::uint32_t kForbidVtable = 0x00B8D690;       // the Forbidden Units/Techs dialog (ctor 0x9990BE)

struct BString {
  wchar_t* text;
};

using RefreshFn = void(__fastcall*)(void* palette, void* edx);
using FillListFn = bool(__fastcall*)(void* dialog, void* edx, void* list);
using ListLayoutFn = void(__fastcall*)(void* list, void* edx);
using ListSelectFn = void(__fastcall*)(void* list, void* edx, std::int32_t index);

using BStringFromIdFn = BString*(__fastcall*)(BString* self, void* edx, std::int32_t id);
using BStringFreeFn = void(__fastcall*)(BString* self, void* edx);

const auto kListSelect = reinterpret_cast<ListSelectFn>(0x00AC8A43);

const auto kFillAllowedUnits = reinterpret_cast<FillListFn>(0x0099912F);
const auto kFillAllowedTechs = reinterpret_cast<FillListFn>(0x00999493);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);

template <typename T>
T Read(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

// One search field and the list it filters.
struct Search {
  const char* what;       // for the log
  const char* fieldName;  // the textField the layout adds
  std::int32_t owner = 0;     // handle of the palette or the dialog, as the fill last saw it
  std::int32_t field = 0;     // handle of the field, 0 until found
  bool fieldMissing = false;  // looked for once for this owner and not there
  std::wstring raw;           // the field's text as last read
  std::vector<std::wstring> words;  // lower case: what the fills match
  std::vector<std::wstring> next;   // the words of the text typed, waiting for a pause in the typing
  bool pending = false;
  ULONGLONG changedAt = 0;
  int kept = 0, dropped = 0;  // the last fill
};

Search g_palette{"Objects palette", "EditorProtoPaletteSearch"};
Search g_forbid{"Forbidden Units/Techs", "ForbiddenUnitsTechs_Search"};
bool g_log = false;

std::vector<std::wstring> Words(const std::wstring& text) {
  std::vector<std::wstring> words;
  std::wstring word;
  for (wchar_t c : text) {
    if (std::iswspace(c)) {
      if (!word.empty()) {
        words.push_back(word);
        word.clear();
      }
    } else {
      word += static_cast<wchar_t>(std::towlower(c));
    }
  }
  if (!word.empty()) {
    words.push_back(word);
  }
  return words;
}

// Case-insensitive: `word` is lower case already.
template <typename Char>
bool Contains(const Char* text, const std::wstring& word) {
  if (text == nullptr) {
    return false;
  }
  for (const Char* start = text; *start != 0; ++start) {
    std::size_t i = 0;
    while (i < word.size() && start[i] != 0 &&
           static_cast<wchar_t>(std::towlower(static_cast<wchar_t>(static_cast<std::make_unsigned_t<Char>>(start[i])))) ==
               word[i]) {
      ++i;
    }
    if (i == word.size()) {
      return true;
    }
  }
  return false;
}

// A proto's display name ([proto+144h], the string ID FUN_008F7A89 reads), or empty.
std::wstring DisplayName(const char* proto) {
  const std::int32_t id = Read<std::int32_t>(proto, 0x144);
  if (id < 0) {
    return {};
  }
  BString text{nullptr};
  kBStringFromId(&text, nullptr, id);
  std::wstring name = text.text == nullptr ? L"" : text.text;
  kBStringFree(&text, nullptr);
  return name;
}

// Every word in one of the texts; a proto's display name is looked up only when a word is not found otherwise.
bool Matches(const std::vector<std::wstring>& words, const wchar_t* shown, const char* proto) {
  std::wstring display;
  bool displayRead = false;
  for (const std::wstring& word : words) {
    if (Contains(shown, word)) {
      continue;
    }
    if (proto != nullptr) {
      if (Contains(Read<const char*>(proto, 0x10), word)) {
        continue;
      }
      if (!displayRead) {
        display = DisplayName(proto);
        displayRead = true;
      }
      if (Contains(display.c_str(), word)) {
        continue;
      }
    }
    return false;
  }
  return true;
}

// The fill saw this owner: a new one (the editor or the dialog made again) starts with no field and no text.
void Seen(Search& search, std::int32_t owner) {
  if (owner != search.owner) {
    search.owner = owner;
    search.field = 0;
    search.fieldMissing = false;
    search.raw.clear();
    search.words.clear();
    search.next.clear();
    search.pending = false;
  }
}

void Count(Search& search, bool keep) { ++(keep ? search.kept : search.dropped); }

}  // namespace
}  // namespace uhc

// The Objects palette fill: one call per proto it would add.
extern "C" bool UhcEditorPaletteKeep(void* palette, const char* proto) {
  using namespace uhc;
  Seen(g_palette, ui::HandleOf(palette));
  const bool keep = g_palette.words.empty() || proto == nullptr || Matches(g_palette.words, nullptr, proto);
  Count(g_palette, keep);
  return keep;
}

// The allowed list fill of the Forbidden Units/Techs dialog: one call per proto (isTech 0, entry = the proto) or tech
// (isTech 1, entry = its index; its name is the shown text).
extern "C" bool UhcEditorForbidKeep(void* dialog, const uhc::BString* text, std::int32_t entry, std::int32_t isTech) {
  using namespace uhc;
  Seen(g_forbid, ui::HandleOf(dialog));
  const wchar_t* shown = text == nullptr ? nullptr : text->text;
  const char* proto = isTech != 0 ? nullptr : reinterpret_cast<const char*>(entry);
  const bool keep = g_forbid.words.empty() || Matches(g_forbid.words, shown, proto);
  Count(g_forbid, keep);
  return keep;
}

namespace uhc {
namespace {

// Reads the field: a new text sets the words that wait for the next refill.
void ReadField(Search& search, void* owner) {
  void* field = ui::Gadget(search.field, ui::kTextField);
  if (field == nullptr) {
    if (search.fieldMissing) {
      return;
    }
    search.field = ui::FindChild(owner, search.fieldName);
    field = ui::Gadget(search.field, ui::kTextField);
    if (field == nullptr) {
      search.fieldMissing = true;
      if (g_log) {
        Log(L"editorSearch: the %hs has no textField %hs; its list stays stock", search.what, search.fieldName);
      }
      return;
    }
    if (g_log) {
      Log(L"editorSearch: %hs search field found", search.what);
    }
  }
  const wchar_t* text = ui::FieldText(field);
  if (search.raw == text) {
    return;
  }
  search.raw = text;
  search.next = Words(search.raw);
  search.pending = search.next != search.words;  // not when only spaces changed
  search.changedAt = GetTickCount64();
}

// A refill of the palette takes about 0.2 s (the stock fill of some 3,000 protos), so it waits for a pause of
// kSettleMs in the typing: a word typed at speed refills once.
constexpr ULONGLONG kSettleMs = 250;

// Reads the field; true when its words changed and the typing has paused since.
bool ReadyToRefill(Search& search, void* owner) {
  ReadField(search, owner);
  if (!search.pending || GetTickCount64() - search.changedAt < kSettleMs) {
    return false;
  }
  search.pending = false;
  search.words = search.next;
  return true;
}

double Ms(const LARGE_INTEGER& start) {
  LARGE_INTEGER now, frequency;
  QueryPerformanceCounter(&now);
  QueryPerformanceFrequency(&frequency);
  return 1000.0 * static_cast<double>(now.QuadPart - start.QuadPart) / static_cast<double>(frequency.QuadPart);
}

void LogFill(Search& search, const LARGE_INTEGER& start) {
  if (g_log) {
    Log(L"editorSearch: %hs \"%ls\": %d shown, %d hidden (%.1f ms)", search.what, search.raw.c_str(), search.kept,
        search.dropped, Ms(start));
  }
}

void PollPalette() {
  if (g_palette.owner == 0) {
    return;
  }
  void* palette = ui::Gadget(g_palette.owner, ui::kPalette);
  if (palette == nullptr) {
    Seen(g_palette, 0);  // the editor closed
    return;
  }
  if (!ReadyToRefill(g_palette, palette)) {
    return;
  }
  if (Read<std::uint32_t>(palette, 0) != kPaletteVtable || Read<std::uint32_t>(palette, 0x17C) != kPaletteObjectsFill) {
    return;
  }
  g_palette.kept = g_palette.dropped = 0;
  LARGE_INTEGER start;
  QueryPerformanceCounter(&start);
  // The palette's refresh slot (vtable +20h, FUN_00AD01FD, what "refreshonreal" runs when it is shown): it empties
  // the entries (0xAD0189), refills them (vtable +0F0h: the fill FUN_007F501E, through the redirected add), lays the
  // button list out and shows the buttons of the current category [+168h] (FUN_00ACF80E).
  const auto refresh = reinterpret_cast<RefreshFn>(Read<const std::uint32_t*>(palette, 0)[0x20 / 4]);
  refresh(palette, nullptr);
  LogFill(g_palette, start);
}

void PollForbid() {
  if (g_forbid.owner == 0) {
    return;
  }
  void* dialog = ui::Gadget(g_forbid.owner, ui::kAnyGadget);
  if (dialog == nullptr || Read<std::uint32_t>(dialog, 0) != kForbidVtable) {
    Seen(g_forbid, 0);
    return;
  }
  if (!ReadyToRefill(g_forbid, dialog)) {
    return;
  }
  void* list = ui::Gadget(Read<std::int32_t>(dialog, 0x144), ui::kList);
  if (list == nullptr) {
    return;
  }
  g_forbid.kept = g_forbid.dropped = 0;
  LARGE_INTEGER start;
  QueryPerformanceCounter(&start);
  // [dialog+160h]: the display mode the radio buttons set, 0 units, 1 techs (0x9996C6).
  (Read<std::int32_t>(dialog, 0x160) == 0 ? kFillAllowedUnits : kFillAllowedTechs)(dialog, nullptr, list);
  // Then what the dialog's refresh does after a fill (0x9997C8): the list's layout slot (vtable +100h), which shows
  // the new items, and the first item selected (0xAC8A43(0)).
  reinterpret_cast<ListLayoutFn>(Read<const std::uint32_t*>(list, 0)[0x100 / 4])(list, nullptr);
  kListSelect(list, nullptr, 0);
  LogFill(g_forbid, start);
}

// With `log`, the cost of the per-frame check while the editor's lists exist, every 5000 such frames (refills
// included).
int g_polls = 0;
double g_pollMs = 0;

void BeforePresent() {
  if (!g_log || (g_palette.owner == 0 && g_forbid.owner == 0)) {
    PollPalette();
    PollForbid();
    return;
  }
  LARGE_INTEGER start;
  QueryPerformanceCounter(&start);
  PollPalette();
  PollForbid();
  g_pollMs += Ms(start);
  if (++g_polls == 5000) {
    Log(L"editorSearch: the search fields' check took %.2f us a frame (5000 frames, refills included)",
        1000.0 * g_pollMs / g_polls);
    g_polls = 0;
    g_pollMs = 0;
  }
}

}  // namespace

Outcome ApplyEditorSearch(const Config& config) {
  const auto* args = config.First("editorSearch");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& word : *args) {
    if (_stricmp(word.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"editorSearch: unknown argument \"%hs\" ignored (expected log)", word.c_str());
    }
  }
  if (!ui::VerifyUiGadgets("editorSearch") ||
      !VerifyAll("editorSearch",
                 {&sites::kEditorPaletteAddProto, &sites::kEditorPaletteAdd, &sites::kEditorPaletteObjectsFill,
                  &sites::kEditorPaletteVtable, &sites::kEditorPaletteRefreshSlot, &sites::kEditorPaletteRefresh, &sites::kEditorPaletteRefill,
                  &sites::kEditorPaletteLayoutShow,
                  &sites::kEditorForbidVtable, &sites::kEditorForbidBind, &sites::kEditorForbidMode, &sites::kEditorForbidRelayout,
                  &sites::kEditorForbidUnitAdd, &sites::kEditorForbidTechAdd, &sites::kEditorListAdd,
                  &sites::kEditorFillAllowedUnits, &sites::kEditorFillAllowedTechs, &sites::kEditorProtoDisplayName,
                  &sites::kBStringFromId, &sites::kBStringFree})) {
    return Outcome::kFailed;
  }
  if (!AddD3D9Observer({nullptr, nullptr, &BeforePresent, nullptr}, "editorSearch")) {
    return Outcome::kFailed;
  }
  if (!WriteCall(0x007F537D, reinterpret_cast<const void*>(&UhcEditorPaletteAddHook)) ||
      !WriteCall(0x009991D0, reinterpret_cast<const void*>(&UhcEditorForbidUnitHook)) ||
      !WriteCall(0x00999547, reinterpret_cast<const void*>(&UhcEditorForbidTechHook))) {
    return Outcome::kFailed;
  }
  Log(L"editorSearch: the Objects palette and the Forbidden Units/Techs dialog filter by their search fields "
      L"(%hs, %hs)%ls",
      g_palette.fieldName, g_forbid.fieldName, g_log ? L"; log on" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
