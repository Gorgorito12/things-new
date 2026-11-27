// editorSearch: search fields in the scenario editor. A textField that the layout adds filters a stock list as
// the player types: the Objects palette (uieditorpalettes.xml, EditorProtoPalette, field EditorProtoPaletteSearch)
// the allowed list of the Forbidden Units/Techs dialog (uiforbiddenunitstechs.xml, field ForbiddenUnitsTechs_Search),
// and the trigger editor's Type list and its unit, unit type and tech parameter lists (uitriggereditor.xml, field
// trEdit-CondEffPanel-search in trEdit-CondEffPanel; there a list where nothing matches keeps all its entries, since
// one field serves them all), and the trigger editor's list of triggers (field trEdit-Trigger-search in trEditor;
// the trigger being edited always stays in it). The match is case-insensitive; every word of the text must appear in
// the text the list shows, or in a proto's internal or display name (techs: their internal name, which the list
// shows). An empty field is the stock list. A layout without the field is the stock dialog.
//
//   editorSearch [log]
//
// How: the fills of both lists add one entry per proto or tech through one call; that call is redirected
// (hooks/editorsearch_hooks.asm) and asks this file whether the entry matches. A typed character changes the text of
// the field's editBox and nothing else, so the text is read once a frame (the Direct3D Present observer: a string
// compare, nothing more unless the text changed) and a change, once the typing pauses for 250 ms, refills the
// list with the stock code: the palette's refresh slot (vtable +20h: it empties the entries, runs the fill
// FUN_007F501E and shows the buttons), and the dialog's fill of its display mode (FUN_0099912F units, FUN_00999493
// techs) followed by the list's layout, as the dialog's own refresh does. The trigger editor's lists are set from
// arrays (0x5BECAA, and 0xAC19D9 for the type list's entry data): those calls get filtered copies, and a change runs
// the panel's own fill FUN_00825757 again. The trigger list's fill FUN_0082481C adds each trigger of the current
// group through one call as well (0x8248C3) and gives each row the trigger's position in the group as its data, which
// is what a click reads (0x825AE8), never the row: a shorter list edits the trigger it shows. A change runs that fill
// again. The editor only: no simulation, nothing saved but the values picked, nothing sent.
#include <windows.h>

#include <algorithm>
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
extern "C" void UhcEditorTriggerAddHook();
extern "C" void UhcEditorTypeFillHook();
extern "C" void UhcEditorParamListHook();

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

// The trigger editor's lists: an array the game builds, {data, count, ...}, read by 0x5BECAA (BString entries) and
// 0xAC19D9 (int entry data).
struct GameArray {
  void* data;
  std::int32_t count;
  std::int32_t capacity;
};

using SetListFn = void(__fastcall*)(void* field, void* edx, const GameArray* names);
using SetDataFn = void(__fastcall*)(void* field, void* edx, const GameArray* data);
const auto kSetList = reinterpret_cast<SetListFn>(0x005BECAA);
const auto kSetData = reinterpret_cast<SetDataFn>(0x00AC19D9);

Search g_trigger{"trigger editor", "trEdit-CondEffPanel-search"};
std::uint32_t g_triggerVtable = 0;  // the editor object's, as its type fill saw it
Search g_triggers{"trigger list", "trEdit-Trigger-search"};
std::uint32_t g_triggersVtable = 0;  // the editor object's, as the trigger list fill saw it

// The indices of the names that hold every word; none when the text is empty or nothing matches, in which case the
// list keeps all its entries: one field serves the type list and the parameter lists, and a word meant for one of
// them must not empty the others.
std::vector<std::int32_t> Matching(const GameArray* names) {
  std::vector<std::int32_t> kept;
  if (g_trigger.words.empty() || names == nullptr || names->data == nullptr) {
    return kept;
  }
  const auto* entries = static_cast<wchar_t* const*>(names->data);
  for (std::int32_t i = 0; i < names->count; ++i) {
    if (Matches(g_trigger.words, entries[i], nullptr)) {
      kept.push_back(i);
    }
  }
  return kept;
}

}  // namespace
}  // namespace uhc

// The trigger list (FUN_0082481C, at 0x8248C3): one call per trigger of the current group, `pos` its position there
// (the data its row gets, what a click reads), `text` its name. The group's current trigger, [group+4] (0x97B7C4),
// always stays, so the list keeps showing the trigger the panels edit.
extern "C" bool UhcEditorTriggerKeep(void* editor, const char* group, std::int32_t pos, const uhc::BString* text) {
  using namespace uhc;
  Seen(g_triggers, ui::HandleOf(editor));
  g_triggersVtable = Read<std::uint32_t>(editor, 0);
  const bool keep = g_triggers.words.empty() || (group != nullptr && pos == Read<std::int32_t>(group, 4)) ||
                    Matches(g_triggers.words, text == nullptr ? nullptr : text->text, nullptr);
  Count(g_triggers, keep);
  return keep;
}

// The condition/effect type list (FUN_00825757, at 0x8258A0): the names and their entry data (the type's index), set
// together, filtered together.
extern "C" void UhcEditorTypeFill(void* editor, void* field, const uhc::GameArray* names,
                                  const uhc::GameArray* data) {
  using namespace uhc;
  Seen(g_trigger, ui::HandleOf(editor));
  g_triggerVtable = Read<std::uint32_t>(editor, 0);
  const std::vector<std::int32_t> kept =
      data != nullptr && names != nullptr && data->count == names->count ? Matching(names) : std::vector<std::int32_t>{};
  if (kept.empty()) {
    kSetList(field, nullptr, names);
    kSetData(field, nullptr, data);
    g_trigger.kept = names == nullptr ? 0 : names->count;
    g_trigger.dropped = 0;
    return;
  }
  std::vector<void*> keptNames;
  std::vector<std::int32_t> keptData;
  for (std::int32_t i : kept) {
    keptNames.push_back(static_cast<void* const*>(names->data)[i]);
    keptData.push_back(static_cast<const std::int32_t*>(data->data)[i]);
  }
  const auto n = static_cast<std::int32_t>(kept.size());
  const GameArray filteredNames{keptNames.data(), n, n};
  const GameArray filteredData{keptData.data(), n, n};
  kSetList(field, nullptr, &filteredNames);
  kSetData(field, nullptr, &filteredData);
  g_trigger.kept = n;
  g_trigger.dropped = names->count - n;
}

// A unit, unit type or tech parameter list (0x828A27, 0x828A4E, 0x8289D5): the array 0x5BECAA gets. The parameter
// takes the text of the entry picked (0x829E29, 0x829F2F), so a shorter list picks the same values. The entry of the
// parameter's current value stays in the list (its first value, [[def+8]], def = [param+13Ch], as 0x992D36(0) reads
// it), so the field keeps showing it.
extern "C" const uhc::GameArray* UhcEditorParamList(void* field, const uhc::GameArray* names, const char* param) {
  using namespace uhc;
  (void)field;
  static std::vector<void*> keptNames;
  static GameArray filtered{};
  std::vector<std::int32_t> kept = Matching(names);
  if (kept.empty()) {
    return names;
  }
  const char* def = param == nullptr ? nullptr : Read<const char*>(param, 0x13C);
  const wchar_t* value = nullptr;
  if (def != nullptr && Read<std::int32_t>(def, 0x0C) > 0 && Read<const wchar_t* const*>(def, 0x08) != nullptr) {
    value = Read<const wchar_t* const*>(def, 0x08)[0];
  }
  const auto* entries = static_cast<wchar_t* const*>(names->data);
  if (value != nullptr && value[0] != 0) {
    for (std::int32_t i = 0; i < names->count; ++i) {
      if (entries[i] != nullptr && _wcsicmp(entries[i], value) == 0) {
        if (std::find(kept.begin(), kept.end(), i) == kept.end()) {
          kept.insert(std::upper_bound(kept.begin(), kept.end(), i), i);
        }
        break;
      }
    }
  }
  keptNames.clear();
  for (std::int32_t i : kept) {
    keptNames.push_back(entries[i]);
  }
  filtered = GameArray{keptNames.data(), static_cast<std::int32_t>(keptNames.size()),
                       static_cast<std::int32_t>(keptNames.size())};
  if (g_log) {
    Log(L"editorSearch: trigger parameter list \"%ls\": %d of %d", g_trigger.raw.c_str(), filtered.count, names->count);
  }
  return &filtered;
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

using TypeFillFn = void(__fastcall*)(void* editor, void* edx);
const auto kTypeFill = reinterpret_cast<TypeFillFn>(0x00825757);

// The trigger editor: a new text runs its own fill of the condition/effect panel again (FUN_00825757, what the
// Triggers / Conditions / Effects buttons run after setting [editor+1C0h]): the type list through the hook above, then
// the list of the trigger's conditions or effects and the selected one's parameters (0x825D8F, or 0x824BDB and
// 0x824E04), whose unit, unit type and tech lists go through the parameter hook.
void PollTrigger() {
  if (g_trigger.owner == 0) {
    return;
  }
  void* editor = ui::Gadget(g_trigger.owner, ui::kAnyGadget);
  if (editor == nullptr || Read<std::uint32_t>(editor, 0) != g_triggerVtable) {
    Seen(g_trigger, 0);
    return;
  }
  if (!ReadyToRefill(g_trigger, editor)) {
    return;
  }
  const std::int32_t mode = Read<std::int32_t>(editor, 0x1C0);  // 1 conditions, 2 effects, 0 triggers
  if (mode != 1 && mode != 2) {
    return;
  }
  LARGE_INTEGER start;
  QueryPerformanceCounter(&start);
  kTypeFill(editor, nullptr);
  LogFill(g_trigger, start);
}

using TriggerListFillFn = void(__fastcall*)(void* editor, void* edx);
const auto kTriggerListFill = reinterpret_cast<TriggerListFillFn>(0x0082481C);

// The trigger list: a new text runs its fill FUN_0082481C again (what the group change, the panel fill and the
// editor's refresh 0x825CE8 run): the list emptied, each trigger of the group through the hook above, the current one
// selected, and its name, priority and Active / Loop / Run Immediately shown again, as they were. In any mode: the
// list shows beside the Triggers, Conditions and Effects panels alike.
void PollTriggerList() {
  if (g_triggers.owner == 0) {
    return;
  }
  void* editor = ui::Gadget(g_triggers.owner, ui::kAnyGadget);
  if (editor == nullptr || Read<std::uint32_t>(editor, 0) != g_triggersVtable) {
    Seen(g_triggers, 0);
    return;
  }
  if (!ReadyToRefill(g_triggers, editor)) {
    return;
  }
  g_triggers.kept = g_triggers.dropped = 0;
  LARGE_INTEGER start;
  QueryPerformanceCounter(&start);
  kTriggerListFill(editor, nullptr);
  LogFill(g_triggers, start);
}

// With `log`, the cost of the per-frame check while the editor's lists exist, every 5000 such frames (refills
// included).
int g_polls = 0;
double g_pollMs = 0;

void BeforePresent() {
  if (!g_log || (g_palette.owner == 0 && g_forbid.owner == 0 && g_trigger.owner == 0 && g_triggers.owner == 0)) {
    PollPalette();
    PollForbid();
    PollTrigger();
    PollTriggerList();
    return;
  }
  LARGE_INTEGER start;
  QueryPerformanceCounter(&start);
  PollPalette();
  PollForbid();
  PollTrigger();
  PollTriggerList();
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
                  &sites::kBStringFromId, &sites::kBStringFree, &sites::kEditorTypeListSet,
                  &sites::kEditorTypeFillHead, &sites::kEditorTypeFillMode, &sites::kEditorParamTechList,
                  &sites::kEditorParamProtoList, &sites::kEditorParamUnitTypeList, &sites::kEditorSetList,
                  &sites::kEditorSetData, &sites::kEditorParamPickText, &sites::kEditorTriggerListFill,
                  &sites::kEditorTriggerListAdd, &sites::kEditorListSetData, &sites::kEditorTriggerListClick,
                  &sites::kEditorTriggerSetCurrent, &sites::kEditorTriggerCurrent})) {
    return Outcome::kFailed;
  }
  if (!AddD3D9Observer({nullptr, nullptr, &BeforePresent, nullptr}, "editorSearch")) {
    return Outcome::kFailed;
  }
  if (!WriteCall(0x007F537D, reinterpret_cast<const void*>(&UhcEditorPaletteAddHook)) ||
      !WriteCall(0x009991D0, reinterpret_cast<const void*>(&UhcEditorForbidUnitHook)) ||
      !WriteCall(0x00999547, reinterpret_cast<const void*>(&UhcEditorForbidTechHook)) ||
      !WriteJmp(0x008258A0, reinterpret_cast<const void*>(&UhcEditorTypeFillHook), 0x18) ||
      !WriteCall(0x008289D5, reinterpret_cast<const void*>(&UhcEditorParamListHook)) ||
      !WriteCall(0x00828A27, reinterpret_cast<const void*>(&UhcEditorParamListHook)) ||
      !WriteCall(0x00828A4E, reinterpret_cast<const void*>(&UhcEditorParamListHook)) ||
      !WriteCall(0x008248C3, reinterpret_cast<const void*>(&UhcEditorTriggerAddHook))) {
    return Outcome::kFailed;
  }
  Log(L"editorSearch: the Objects palette, the Forbidden Units/Techs dialog, the trigger editor and its trigger list "
      L"filter by their search fields (%hs, %hs, %hs, %hs)%ls",
      g_palette.fieldName, g_forbid.fieldName, g_trigger.fieldName, g_triggers.fieldName, g_log ? L"; log on" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
