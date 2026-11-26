// politicianEnablesTech [log] [flag <u> <v>]: a politician of the European age-up dialog shows the techs it makes
// available as their own icons and names, each with the tech's research rollover, from
// <PoliticianEnablesTech>TechName</PoliticianEnablesTech> children of its <Tech> (up to four). UI only: the tag enables
// nothing; the politician's own effects still do that.
//
// Data. The tags are read through the shared <Tech> node hook (techtags.h), with the <Icon> of every tech, since the
// tech record keeps only a texture handle ([NodeData+14h], set by 0x621143) and a gadget's texture is set by path. The
// names are resolved to tech IDs on the first dialog after a data load (0x600BE1).
//
// The dialog. The hook of politicianPlacesFix at 0x81A45A (AddPoliticianPlaceObserver) runs for each politician the
// European list builder FUN_0081A2B8 accepts, before it fills place n = [dlg+26Ch]. The builder then sets the
// portrait's texture from the politiciandata record (0x638823) and its texture coordinates to (0, 0, 0.75, 0.7734375)
// (vtable +D8h), and the description to the tech's RolloverTextID through the handle [dlg+210h+4n]; see the sites
// PoliticianPortraitFill and PoliticianDescriptionRead. For a politician with tags this key hides the place's
// Poli%dPortrait and Poli%dDescription and shows its own gadgets instead, which the layout file adds to the place,
// hidden:
//   PoliticianDlg-Poli%dEnablesTechPortrait     the same picture, cut to its top part (`flag`, default 0.75 0.5833:
//                                               a 145 x 231 flag in a 192 x 396 picture);
//   PoliticianDlg-Poli%dEnablesTechDescription  the description, in a box that ends above the techs: the key puts its
//                                               handle in [dlg+210h+4n], so the builder fills it (beside a DLL that
//                                               replaces the text at 0x81A5CB, with that DLL's text);
//   PoliticianDlg-Poli%dEnablesTech%dIcon/Name  one or two techs, one per row;
//   PoliticianDlg-Poli%dEnablesTechGrid%dIcon/Name  three or four techs, two per row.
// A politician without tags gets the stock gadgets back, so it looks as without the key. A layout without these
// gadgets (the stock file, the Asian and native dialogs) is left alone.
#include <windows.h>

#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../techtags.h"
#include "../uigadgets.h"
#include "../unittypes.h"

namespace {

struct BString {
  wchar_t* text;
};

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // +13Ch world, +140h database, +3C0h the local player's ID
constexpr std::uint32_t kNoGadget = 0x00C672C0;    // [..]: the handle of "no gadget"
constexpr std::uint32_t kGadgetTip = 0x68;         // a gadget's help text, a BString
constexpr int kPlaces = 5;
constexpr int kMaxTags = 4;
constexpr int kListRows = 2;  // up to this many techs: one per row; more: two per row

using GadgetByNameFn = std::int32_t*(__thiscall*)(void* panel, std::int32_t* out, BString* name, std::int32_t flag);
using GadgetAnyFn = void*(__cdecl*)(std::int32_t handle);
using GadgetReleaseFn = std::int32_t(__cdecl*)(std::int32_t handle);
using SetTextureFn = void(__thiscall*)(void* gadget, const BString* path);
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t id);
using BStringSetFn = void(__thiscall*)(BString* self, const BString* source);
using BStringFreeFn = void(__thiscall*)(BString* self);
using TechByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using PlayerByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using UnitByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using StatusListFn = const char*(__thiscall*)(const char* statuses, std::int32_t playerId);
using StatusAtFn = const char*(__thiscall*)(const char* list, std::int32_t index);
using RolloverFn = void(__cdecl*)(BString* text, const char* status, const char* player, const char* unit,
                                  std::int32_t a5, const void* costOverride, std::int32_t a7, std::int32_t a8);
const auto kGadgetByName = reinterpret_cast<GadgetByNameFn>(0x00AB7C2F);
const auto kGadgetAny = reinterpret_cast<GadgetAnyFn>(0x00404296);
const auto kGadgetRelease = reinterpret_cast<GadgetReleaseFn>(0x0040431B);
const auto kSetTexture = reinterpret_cast<SetTextureFn>(0x00638823);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringSet = reinterpret_cast<BStringSetFn>(0x0040196F);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kTechByName = reinterpret_cast<TechByNameFn>(0x00600BE1);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kStatusList = reinterpret_cast<StatusListFn>(0x004C5394);
const auto kStatusAt = reinterpret_cast<StatusAtFn>(0x004804B3);
const auto kRollover = reinterpret_cast<RolloverFn>(0x004C737C);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

template <typename Fn>
Fn VirtualAt(const void* object, std::uint32_t offset) {
  return reinterpret_cast<Fn>((*reinterpret_cast<void* const* const*>(object))[offset / 4]);
}

bool g_log = false;
float g_flagU = 0.75f;
float g_flagV = 0.5833f;  // 231 of 396 rows

// Read with the data: each politician's name and tags in file order, and every tech's <Icon>, by lowercase tech name.
struct Politician {
  std::wstring name;
  std::vector<std::wstring> tags;
};
std::map<std::wstring, Politician> g_tagNames;
std::map<std::wstring, std::wstring> g_icons;
// Resolved on the first dialog after a load: politician tech ID -> enabled tech IDs.
std::map<std::int32_t, std::vector<std::int32_t>> g_tags;
std::map<std::int32_t, std::wstring> g_iconById;
bool g_resolved = false;
bool g_loggedLayout = false;

std::wstring Lower(const wchar_t* text) {
  std::wstring out = text == nullptr ? L"" : text;
  for (wchar_t& c : out) {
    c = static_cast<wchar_t>(towlower(c));
  }
  return out;
}

std::wstring Trim(const wchar_t* text) {
  std::wstring out = text == nullptr ? L"" : text;
  const std::size_t first = out.find_first_not_of(L" \t\r\n");
  if (first == std::wstring::npos) {
    return {};
  }
  return out.substr(first, out.find_last_not_of(L" \t\r\n") - first + 1);
}

std::string Narrow(const std::wstring& text) {
  std::string out;
  for (wchar_t c : text) {
    out.push_back(c < 0x80 ? static_cast<char>(c) : '?');
  }
  return out;
}

void NewDatabase(char*) {
  g_tagNames.clear();
  g_icons.clear();
  g_tags.clear();
  g_iconById.clear();
  g_resolved = false;
}

void TagRead(const char*, const wchar_t* techName, const wchar_t* text) {
  const std::wstring name = Trim(text);
  if (name.empty()) {
    uhc::Log(L"politicianEnablesTech: an empty <PoliticianEnablesTech> in tech %ls; ignored", techName);
    return;
  }
  Politician& politician = g_tagNames[Lower(techName)];
  politician.name = techName == nullptr ? L"" : techName;
  politician.tags.push_back(name);
}

void IconRead(const char*, const wchar_t* techName, const wchar_t* text) {
  const std::wstring icon = Trim(text);
  if (!icon.empty()) {
    g_icons[Lower(techName)] = icon;
  }
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

void Resolve() {
  g_resolved = true;
  const char* database = Game() == nullptr ? nullptr : Field<const char*>(Game(), 0x140);
  if (database == nullptr) {
    return;
  }
  int politicians = 0;
  int tags = 0;
  for (const auto& entry : g_tagNames) {
    const std::int32_t politician = kTechByName(database, Narrow(entry.second.name).c_str());
    if (politician < 0) {
      uhc::Log(L"politicianEnablesTech: tech %ls not found by its name; its tags are left out",
               entry.second.name.c_str());
      continue;
    }
    std::vector<std::int32_t>& list = g_tags[politician];
    for (const std::wstring& name : entry.second.tags) {
      const std::int32_t id = kTechByName(database, Narrow(name).c_str());
      if (id < 0) {
        uhc::Log(L"politicianEnablesTech: <PoliticianEnablesTech>%ls</PoliticianEnablesTech> in tech %ls: no such "
                 L"tech; left out",
                 name.c_str(), entry.second.name.c_str());
        continue;
      }
      if (static_cast<int>(list.size()) == kMaxTags) {
        uhc::Log(L"politicianEnablesTech: tech %ls has more than %d <PoliticianEnablesTech>; %ls and any after it are "
                 L"left out",
                 entry.second.name.c_str(), kMaxTags, name.c_str());
        break;
      }
      list.push_back(id);
      const auto icon = g_icons.find(Lower(name.c_str()));
      if (icon != g_icons.end()) {
        g_iconById[id] = icon->second;
      }
      ++tags;
    }
    ++politicians;
  }
  uhc::Log(L"politicianEnablesTech: %d politician(s) with %d <PoliticianEnablesTech> tag(s)", politicians, tags);
}

bool Valid(std::int32_t handle) { return handle != 0 && handle != *reinterpret_cast<const std::int32_t*>(kNoGadget); }

std::int32_t Lookup(void* panel, const wchar_t* format, int a, int b = 0) {
  wchar_t name[96];
  swprintf_s(name, format, a, b);
  BString text{nullptr};
  kBStringFromWide(&text, name);
  std::int32_t handle = 0;
  kGadgetByName(panel, &handle, &text, 1);
  kBStringFree(&text);
  return Valid(handle) ? handle : 0;
}

// The gadget object behind a handle (any type), the reference released at once as the stock code does.
void* Object(std::int32_t handle) {
  if (handle == 0) {
    return nullptr;
  }
  void* object = kGadgetAny(handle);
  if (object != nullptr) {
    kGadgetRelease(handle);
  }
  return object;
}

void Show(std::int32_t handle, bool visible) { uhc::ui::Show(handle, visible); }

void SetText(std::int32_t handle, const BString& text, const BString* tip) {
  void* object = Object(handle);
  if (object == nullptr) {
    return;
  }
  VirtualAt<void(__thiscall*)(void*, const BString*)>(object, 0x80)(object, &text);
  if (tip != nullptr) {
    kBStringSet(reinterpret_cast<BString*>(static_cast<char*>(object) + kGadgetTip), tip);
  }
}

void SetTip(std::int32_t handle, const BString* tip) {
  void* object = Object(handle);
  if (object != nullptr && tip != nullptr) {
    kBStringSet(reinterpret_cast<BString*>(static_cast<char*>(object) + kGadgetTip), tip);
  }
}

// The player's tech status of a tech: the list 0x4C5394 is indexed by tech ID in the games seen; a search otherwise.
const char* StatusOf(const char* world, std::int32_t playerId, std::int32_t techId) {
  const char* statuses = Field<const char*>(world, 0x7C);
  const char* list = statuses == nullptr ? nullptr : kStatusList(statuses, playerId);
  if (list == nullptr) {
    return nullptr;
  }
  const std::int32_t count = Field<std::int32_t>(list, 0x08);
  auto idOf = [](const char* status) {
    const char* data = status == nullptr ? nullptr : Field<const char*>(status, 0);
    return data == nullptr ? -1 : Field<std::int32_t>(data, 0);
  };
  if (techId >= 0 && techId < count && idOf(kStatusAt(list, techId)) == techId) {
    return kStatusAt(list, techId);
  }
  for (std::int32_t i = 0; i < count; ++i) {
    const char* status = kStatusAt(list, i);
    if (idOf(status) == techId) {
      return status;
    }
  }
  return nullptr;
}

struct Place {
  std::int32_t portrait = 0, description = 0;          // the stock gadgets
  std::int32_t myPortrait = 0, myDescription = 0;      // this key's
  std::int32_t icon[kListRows] = {}, name[kListRows] = {};
  std::int32_t gridIcon[kMaxTags] = {}, gridName[kMaxTags] = {};
};

Place PlaceGadgets(const char* dlg, void* panel, int n) {
  Place place;
  place.portrait = Field<std::int32_t>(dlg, 0x1C0 + 4 * n);
  // By name: the dialog's own slot may hold this key's box from an earlier opening.
  place.description = Lookup(panel, L"PoliticianDlg-Poli%dDescription", n);
  if (place.description == 0) {
    place.description = Field<std::int32_t>(dlg, 0x210 + 4 * n);
  }
  place.myPortrait = Lookup(panel, L"PoliticianDlg-Poli%dEnablesTechPortrait", n);
  place.myDescription = Lookup(panel, L"PoliticianDlg-Poli%dEnablesTechDescription", n);
  for (int k = 0; k < kListRows; ++k) {
    place.icon[k] = Lookup(panel, L"PoliticianDlg-Poli%dEnablesTech%dIcon", n, k);
    place.name[k] = Lookup(panel, L"PoliticianDlg-Poli%dEnablesTech%dName", n, k);
  }
  for (int k = 0; k < kMaxTags; ++k) {
    place.gridIcon[k] = Lookup(panel, L"PoliticianDlg-Poli%dEnablesTechGrid%dIcon", n, k);
    place.gridName[k] = Lookup(panel, L"PoliticianDlg-Poli%dEnablesTechGrid%dName", n, k);
  }
  return place;
}

void HideOurs(const Place& place) {
  Show(place.myPortrait, false);
  Show(place.myDescription, false);
  for (int k = 0; k < kListRows; ++k) {
    Show(place.icon[k], false);
    Show(place.name[k], false);
  }
  for (int k = 0; k < kMaxTags; ++k) {
    Show(place.gridIcon[k], false);
    Show(place.gridName[k], false);
  }
}

// The politiciandata record of a tech: [dlg+18Ch] records of 14h bytes, +0 the tech ID, +4 the portrait path, count
// [dlg+190h] (the builder's own match, 0x81A487..0x81A49D).
const BString* PortraitOf(const char* dlg, std::int32_t techId) {
  const char* records = Field<const char*>(dlg, 0x18C);
  const std::int32_t count = Field<std::int32_t>(dlg, 0x190);
  for (std::int32_t i = 0; records != nullptr && i < count; ++i) {
    if (Field<std::int32_t>(records, 0x14 * i) == techId) {
      return reinterpret_cast<const BString*>(records + 0x14 * i + 4);
    }
  }
  return nullptr;
}

void FillTech(std::int32_t iconHandle, std::int32_t nameHandle, std::int32_t techId, const char* world,
              const char* player, std::int32_t playerId, const char* unit) {
  const char* status = StatusOf(world, playerId, techId);
  const char* data = status == nullptr ? nullptr : Field<const char*>(status, 0);
  BString name{nullptr};
  if (data != nullptr) {
    kBStringFromId(&name, Field<std::int32_t>(data, 0x08));
  } else {
    kBStringFromWide(&name, L"?");
  }
  // The tooltip: the tech button's own rollover (the command panel's call 0x4622C5 passes 1, 0, 1, 1). The shared
  // tech rollover (techrollover.h) adds no key line here: it skips a builder called from DLL code.
  BString tip{nullptr};
  kBStringFromWide(&tip, L"");
  if (status != nullptr) {
    kRollover(&tip, status, player, unit, 1, nullptr, 1, 1);
  }
  if (tip.text == nullptr || tip.text[0] == 0) {
    kBStringFree(&tip);
    if (data != nullptr) {
      kBStringFromId(&tip, Field<std::int32_t>(data, 0x0C));
    } else {
      kBStringFromWide(&tip, L"");
    }
  }
  SetText(nameHandle, name, &tip);
  Show(nameHandle, true);
  const auto icon = g_iconById.find(techId);
  void* iconObject = Object(iconHandle);
  if (iconObject != nullptr && icon != g_iconById.end()) {
    BString path{nullptr};
    kBStringFromWide(&path, icon->second.c_str());
    kSetTexture(iconObject, &path);
    kBStringFree(&path);
    SetTip(iconHandle, &tip);
    Show(iconHandle, true);
  } else {
    Show(iconHandle, false);
  }
  if (g_log) {
    uhc::Log(L"politicianEnablesTech: tech %d: '%ls', icon %ls", techId, name.text == nullptr ? L"" : name.text,
             icon == g_iconById.end() ? L"(none)" : icon->second.c_str());
  }
  kBStringFree(&name);
  kBStringFree(&tip);
}

// From politicianPlacesFix's hook: the politician `status` is about to fill place `n` of the European dialog.
void PlaceFilled(char* dlg, const char* techStatus, int n) {
  if (n < 0 || n >= kPlaces || techStatus == nullptr) {
    return;
  }
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr) {
    return;
  }
  const std::int32_t rootHandle = Field<std::int32_t>(dlg, 0x148);
  void* panel = Object(rootHandle);
  if (panel == nullptr) {
    return;
  }
  const Place place = PlaceGadgets(dlg, panel, n);
  const bool layout = place.myPortrait != 0 && place.myDescription != 0 && place.icon[0] != 0 && place.name[0] != 0;
  if (!g_loggedLayout) {
    g_loggedLayout = true;
    uhc::Log(L"politicianEnablesTech: the age-up dialog %ls this key's gadgets", layout ? L"has" : L"does not have");
  }
  if (!layout) {
    return;
  }
  if (!g_resolved) {
    Resolve();
  }
  const char* data = Field<const char*>(techStatus, 0);
  const std::int32_t techId = data == nullptr ? -1 : Field<std::int32_t>(data, 0);
  const auto found = g_tags.find(techId);
  HideOurs(place);
  // The description the builder fills next: [dlg+210h+4n] (read at 0x81A596). A tagged politician's goes to this
  // key's shorter box, so the text is whatever fills it (the RolloverTextID in stock, another DLL's own text beside
  // it); any other politician's goes back to the stock box.
  std::int32_t* descriptionSlot = reinterpret_cast<std::int32_t*>(dlg + 0x210 + 4 * n);
  if (found == g_tags.end() || found->second.empty()) {
    *descriptionSlot = place.description;
    Show(place.portrait, true);
    Show(place.description, true);
    return;
  }
  const std::vector<std::int32_t>& techs = found->second;
  Show(place.portrait, false);
  Show(place.description, false);
  *descriptionSlot = place.myDescription;

  // The portrait's top part, from the picture the builder is about to give the stock portrait.
  if (void* portrait = Object(place.myPortrait)) {
    if (const BString* path = PortraitOf(dlg, techId)) {
      kSetTexture(portrait, path);
      VirtualAt<void(__thiscall*)(void*, float, float, float, float)>(portrait, 0xD8)(portrait, 0.0f, 0.0f, g_flagU,
                                                                                         g_flagV);
    }
    Show(place.myPortrait, true);
  }
  Show(place.myDescription, true);

  const std::int32_t playerId = Field<std::int32_t>(dlg, 0x13C);
  const char* player = kPlayerById(world, playerId);
  const char* unit = kUnitById(world, Field<std::int32_t>(dlg, 0x140));
  const bool list = static_cast<int>(techs.size()) <= kListRows || place.gridIcon[0] == 0;
  const int shown = list ? (static_cast<int>(techs.size()) < kListRows ? static_cast<int>(techs.size()) : kListRows)
                         : static_cast<int>(techs.size());
  for (int k = 0; k < shown; ++k) {
    FillTech(list ? place.icon[k] : place.gridIcon[k], list ? place.name[k] : place.gridName[k], techs[k], world,
             player, playerId, unit);
  }
  if (g_log) {
    uhc::Log(L"politicianEnablesTech: place %d, politician tech %d, %d tech(s) (%ls)", n, techId, shown,
             list ? L"one per row" : L"two per row");
  }
}

}  // namespace

namespace uhc {

Outcome ApplyPoliticianEnablesTech(const Config& config) {
  const Config::Args* args = config.First("politicianEnablesTech");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (std::size_t i = 0; i < args->size(); ++i) {
    const std::string& arg = (*args)[i];
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "flag") == 0 && i + 2 < args->size()) {
      const float u = static_cast<float>(std::atof((*args)[i + 1].c_str()));
      const float v = static_cast<float>(std::atof((*args)[i + 2].c_str()));
      if (u <= 0.0f || u > 1.0f || v <= 0.0f || v > 1.0f) {
        Log(L"politicianEnablesTech: flag %hs %hs: each must be above 0 and at most 1; feature not applied",
            (*args)[i + 1].c_str(), (*args)[i + 2].c_str());
        return Outcome::kFailed;
      }
      g_flagU = u;
      g_flagV = v;
      i += 2;
    } else {
      Log(L"politicianEnablesTech: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("politicianEnablesTech",
                 {&sites::kPoliticianPortraitFill, &sites::kPoliticianDescriptionRead, &sites::kGadgetSetTexture,
                  &sites::kTechStatusList, &sites::kTechStatusAt, &sites::kTechRolloverHead, &sites::kTechByName,
                  &sites::kPlayerById, &sites::kUnitById, &sites::kGadgetByName, &sites::kGadgetLookupAny,
                  &sites::kGadgetRelease, &sites::kGadgetShow, &sites::kGadgetHide, &sites::kBStringFromWide,
                  &sites::kBStringFromId, &sites::kBStringSet, &sites::kBStringFree}) ||
      !OnDatabaseLoad(&NewDatabase) || !AddTechTagHandler("PoliticianEnablesTech", &TagRead) ||
      !AddTechTagHandler("Icon", &IconRead) || !AddPoliticianPlaceObserver(&PlaceFilled, "politicianEnablesTech")) {
    return Outcome::kFailed;
  }
  Log(L"politicianEnablesTech: the European age-up dialog shows each politician's <PoliticianEnablesTech> techs "
      L"(flag %.4f x %.4f)",
      static_cast<double>(g_flagU), static_cast<double>(g_flagV));
  return Outcome::kApplied;
}

}  // namespace uhc
