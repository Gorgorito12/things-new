// cultureUI [<file>]: the in-game interface takes other textures by the local player's civ, and others again once a
// tech is active (a stage, e.g. the Great War). Only textures change; the layouts stay as they are.
//
// - The data file (data\uhc\cultureui.xml by default, engine-ext\cultureui.xml in the dinput8 build) lists styles:
//   <Style suffix="as" civs="Chinese Indians ..."> with optional <Stage tech="GreatWarizeALL" suffix="as_gw"/>.
//   A style's variant of a texture ui\ingame\X is the loose file art\ui\ingame\X_<suffix>.ddt (or .tga), found once
//   at startup; a stage uses X_<stage suffix>, else the variant of an earlier stage, else the style's, else X.
// - How (docs/engine-symbols.md, "Culture UI: the style switch during a game"): every textured draw binds its texture
//   by handle through 0x407D27. A table handle -> handle, made for one world, replaces the handle there
//   (hooks/cultureui_hooks.asm); with no table it costs that hook one compare. The handles come from the texture
//   manager's lookup by name 0x58E3EB, which makes an entry for a new name without reading its file; the file is
//   read at its first draw, so only the variants drawn take memory.
// - When: at the head of the HUD build 0x76166A (each game start and each load, before any HUD gadget exists), and in
//   the world update every 100 ms of game time (a stage's tech becoming active, the minimised interface switched in
//   the options). The bind hook switches the table off itself once the game's world is another or none.
// - No style for an observer (a mod observer mode: a trigger named StartInsertion exists and the local player's ID is at or
//   above the first observer's, the slot 3, 5 or 7 where the team changes, else past the last player), with the
//   normal (not minimised) interface (option 49h), or for a civ in no style.
#include <windows.h>

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <map>
#include <set>
#include <string>
#include <utility>
#include <vector>

#include "../config.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../hostfiles.h"
#include "../log.h"
#include "../namelists.h"
#include "../patch.h"
#include "../unittypes.h"
#include "../worldtick.h"
#include "../xmllist.h"

extern "C" {
void UhcCultureUiBindHook();
void UhcCultureUiHudHook();
void __stdcall UhcCultureUiHudBuild();
// Read by the bind hook: the table (handle -> handle), its size (0: no style) and the world it was made for.
std::int32_t* g_uhcCultureUiTable = nullptr;
std::uint32_t g_uhcCultureUiCount = 0;
const char* g_uhcCultureUiWorld = nullptr;
}

namespace {

using TextureByNameFn = std::int32_t(__thiscall*)(void* texMgr, const wchar_t* path, int, int, int);
using SettingsByNameFn = void*(__thiscall*)(void* settingsMgr, const wchar_t* name);
using BoolGetFn = bool(__thiscall*)(void* settings, std::int32_t id, bool* out);
using TriggerByNameFn = std::int32_t(__cdecl*)(const char* name);
using PlayerTeamFn = std::int32_t(__cdecl*)(std::int32_t player);
using PlayerByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using TechByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using TechActiveFn = bool(__thiscall*)(const char* techStatus, std::int32_t playerId, std::int32_t techId);

const auto kTextureByName = reinterpret_cast<TextureByNameFn>(0x0058E3EB);
const auto kSettingsByName = reinterpret_cast<SettingsByNameFn>(0x00402C76);
const auto kBoolGet = reinterpret_cast<BoolGetFn>(0x00402CE9);
const auto kTriggerByName = reinterpret_cast<TriggerByNameFn>(0x0090DFB0);
const auto kPlayerTeam = reinterpret_cast<PlayerTeamFn>(0x0088396E);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kTechByName = reinterpret_cast<TechByNameFn>(0x00600BE1);
const auto kTechActive = reinterpret_cast<TechActiveFn>(0x0094AF27);

constexpr std::uint32_t kGameGlobal = 0x00C66234;     // +13Ch world, +140h database, +3C0h local player, +97Ch triggers
constexpr std::uint32_t kGraphicsGlobal = 0x00C66044;  // +6A8h the texture manager
constexpr std::uint32_t kSettingsManager = 0x00C66688;
constexpr std::uint32_t kGameOptionsName = 0x00C672BC;  // -> L"GameOptions"
constexpr std::int32_t kOptionMinimizedUi = 0x49;
constexpr std::int32_t kTickMs = 100;
constexpr const wchar_t* kPrefix = L"ui\\ingame\\";

struct Stage {
  std::string tech;
  std::wstring suffix;
  std::int32_t techId = -1;
};

struct Style {
  std::wstring suffix;
  uhc::CivIdList civs;
  std::vector<Stage> stages;
  // Per level (0 the style, k the k-th stage): (texture, variant) handles, made at the first use.
  std::vector<std::vector<std::pair<std::int32_t, std::int32_t>>> pairs;
  std::vector<bool> made;
  // Per level: (texture, variant) names.
  std::vector<std::vector<std::pair<std::wstring, std::wstring>>> names;
};

std::vector<Style> g_styles;
std::wstring g_dataFile;
int g_generation = 0;       // bumped by each data load: the stage techs are looked up again
int g_techGeneration = -1;  // the generation the tech IDs belong to
std::vector<std::int32_t> g_table;
const char* g_hudWorld = nullptr;  // the world the last HUD build was for
std::int32_t g_elapsed = 0;
int g_style = -1;  // what the table holds now: style index, level (-1: no table)
int g_level = -1;
std::string g_why;  // the last decision without a table, for the log

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

std::wstring Lower(std::wstring text) {
  for (wchar_t& c : text) {
    c = static_cast<wchar_t>(towlower(c));
  }
  return text;
}

std::wstring Widen(const std::string& text) {
  if (text.empty()) {
    return {};
  }
  const int length = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0);
  std::wstring out(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), out.data(), length);
  return out;
}

// ---- The data file ----

std::string Trim(const std::string& text) {
  const size_t begin = text.find_first_not_of(" \t\r\n");
  return begin == std::string::npos ? std::string() : text.substr(begin, text.find_last_not_of(" \t\r\n") - begin + 1);
}

std::string LowerA(std::string text) {
  for (char& c : text) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  return text;
}

// The attribute `name` of the tag text between '<' and '>', or empty.
std::string Attribute(const std::string& tag, const char* name) {
  const std::string lower = LowerA(tag);
  const std::string key = name;
  for (size_t at = lower.find(key); at != std::string::npos; at = lower.find(key, at + 1)) {
    if (at > 0 && !std::isspace(static_cast<unsigned char>(lower[at - 1]))) {
      continue;
    }
    size_t i = at + key.size();
    while (i < tag.size() && std::isspace(static_cast<unsigned char>(tag[i]))) {
      ++i;
    }
    if (i >= tag.size() || tag[i] != '=') {
      continue;
    }
    ++i;
    while (i < tag.size() && std::isspace(static_cast<unsigned char>(tag[i]))) {
      ++i;
    }
    if (i >= tag.size() || (tag[i] != '"' && tag[i] != '\'')) {
      return {};
    }
    const size_t close = tag.find(tag[i], i + 1);
    return close == std::string::npos ? std::string() : tag.substr(i + 1, close - i - 1);
  }
  return {};
}

bool ValidSuffix(const std::string& suffix) {
  return !suffix.empty() && suffix.size() <= 32 &&
         std::all_of(suffix.begin(), suffix.end(),
                     [](char c) { return std::isalnum(static_cast<unsigned char>(c)) || c == '_'; });
}

std::string AsUtf8(const std::string& raw) {
  if (raw.size() >= 2 && static_cast<unsigned char>(raw[0]) == 0xFF && static_cast<unsigned char>(raw[1]) == 0xFE) {
    const wchar_t* wide = reinterpret_cast<const wchar_t*>(raw.data() + 2);
    const int count = static_cast<int>((raw.size() - 2) / 2);
    const int length = WideCharToMultiByte(CP_UTF8, 0, wide, count, nullptr, 0, nullptr, nullptr);
    std::string out(static_cast<size_t>(length), '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide, count, out.data(), length, nullptr, nullptr);
    return out;
  }
  return raw.compare(0, 3, "\xEF\xBB\xBF") == 0 ? raw.substr(3) : raw;
}

// <Style suffix civs> ... <Stage tech suffix/> ... </Style>, comments skipped, tags in any case.
bool ParseData(const std::string& text) {
  Style* open = nullptr;
  size_t pos = 0;
  while ((pos = text.find('<', pos)) != std::string::npos) {
    if (text.compare(pos, 4, "<!--") == 0) {
      const size_t end = text.find("-->", pos + 4);
      if (end == std::string::npos) {
        return false;
      }
      pos = end + 3;
      continue;
    }
    const size_t gt = text.find('>', pos);
    if (gt == std::string::npos) {
      return false;
    }
    const std::string tag = text.substr(pos + 1, gt - pos - 1);
    pos = gt + 1;
    const std::string lower = LowerA(Trim(tag));
    if (lower.rfind("/style", 0) == 0) {
      open = nullptr;
    } else if (lower.rfind("style", 0) == 0 && (lower.size() == 5 || !std::isalnum(static_cast<unsigned char>(lower[5])))) {
      const std::string suffix = Trim(Attribute(tag, "suffix"));
      if (!ValidSuffix(suffix)) {
        uhc::Log(L"cultureUI: %ls: a Style needs a suffix of letters, digits and _ (got \"%hs\"); ignored",
                 g_dataFile.c_str(), suffix.c_str());
        open = nullptr;
        continue;
      }
      Style style;
      style.suffix = Lower(Widen(suffix));
      std::vector<std::string> civs;
      std::string word;
      for (char c : Attribute(tag, "civs") + " ") {
        if (std::isspace(static_cast<unsigned char>(c)) || c == ',') {
          if (!word.empty()) {
            civs.push_back(word);
          }
          word.clear();
        } else {
          word += c;
        }
      }
      if (civs.empty()) {
        uhc::Log(L"cultureUI: %ls: style %hs names no civ; ignored", g_dataFile.c_str(), suffix.c_str());
      }
      style.civs.Set("cultureUI", civs);
      g_styles.push_back(std::move(style));
      open = lower.back() == '/' ? nullptr : &g_styles.back();
    } else if (lower.rfind("stage", 0) == 0) {
      const std::string tech = Trim(Attribute(tag, "tech"));
      const std::string suffix = Trim(Attribute(tag, "suffix"));
      if (open == nullptr || tech.empty() || !ValidSuffix(suffix)) {
        uhc::Log(L"cultureUI: %ls: a Stage needs a tech and a suffix and sits in a Style (tech \"%hs\", suffix "
                 L"\"%hs\"); ignored",
                 g_dataFile.c_str(), tech.c_str(), suffix.c_str());
        continue;
      }
      open->stages.push_back({tech, Lower(Widen(suffix)), -1});
    }
  }
  return true;
}

// ---- The variants on disk ----

// Every loose .ddt or .tga under folder + relative (subfolders too), as its lowercase path from `folder` without the
// extension: "ui\ingame\<name>" for the art folder and relative "ui\ingame\".
void ListFiles(const std::wstring& folder, const std::wstring& relative, std::set<std::wstring>* out) {
  WIN32_FIND_DATAW found;
  HANDLE find = FindFirstFileW((folder + relative + L"*").c_str(), &found);
  if (find == INVALID_HANDLE_VALUE) {
    return;
  }
  do {
    const std::wstring name = found.cFileName;
    if (name == L"." || name == L"..") {
      continue;
    }
    if (found.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
      ListFiles(folder, relative + name + L"\\", out);
      continue;
    }
    const size_t dot = name.find_last_of(L'.');
    if (dot == std::wstring::npos) {
      continue;
    }
    const std::wstring extension = Lower(name.substr(dot));
    if (extension == L".ddt" || extension == L".tga") {
      out->insert(Lower(relative + name.substr(0, dot)));
    }
  } while (FindNextFileW(find, &found));
  FindClose(find);
}

bool EndsWith(const std::wstring& text, const std::wstring& end) {
  return text.size() > end.size() && text.compare(text.size() - end.size(), end.size(), end) == 0;
}

// Per style and level, the textures it replaces and their variants.
void MatchVariants(const std::set<std::wstring>& files) {
  for (Style& style : g_styles) {
    std::vector<std::wstring> suffixes{L"_" + style.suffix};
    for (const Stage& stage : style.stages) {
      suffixes.push_back(L"_" + stage.suffix);
    }
    std::set<std::wstring> bases;
    for (const std::wstring& file : files) {
      for (const std::wstring& suffix : suffixes) {
        if (EndsWith(file, suffix)) {
          bases.insert(file.substr(0, file.size() - suffix.size()));
        }
      }
    }
    style.names.assign(suffixes.size(), {});
    style.pairs.assign(suffixes.size(), {});
    style.made.assign(suffixes.size(), false);
    for (const std::wstring& base : bases) {
      for (size_t level = 0; level < suffixes.size(); ++level) {
        for (size_t k = level + 1; k-- > 0;) {  // this level's variant, else an earlier one's
          if (files.count(base + suffixes[k]) != 0) {
            style.names[level].push_back({base, base + suffixes[k]});
            break;
          }
        }
      }
    }
    std::wstring counts;
    for (size_t level = 1; level < suffixes.size(); ++level) {
      counts += L", stage " + style.stages[level - 1].suffix + L" " + std::to_wstring(style.names[level].size());
    }
    uhc::Log(L"cultureUI: style %ls: %u texture(s) with a variant%ls", style.suffix.c_str(),
             static_cast<unsigned>(style.names[0].size()), counts.c_str());
  }
}

// ---- The decision ----

void* TextureManager() {
  const char* graphics = *reinterpret_cast<const char* const*>(kGraphicsGlobal);
  return graphics == nullptr ? nullptr : const_cast<char*>(graphics) + 0x6A8;
}

bool MinimizedUi() {
  const wchar_t* name = *reinterpret_cast<const wchar_t* const*>(kGameOptionsName);
  void* options = name == nullptr ? nullptr : kSettingsByName(reinterpret_cast<void*>(kSettingsManager), name);
  bool on = false;
  return options != nullptr && kBoolGet(options, kOptionMinimizedUi, &on) && on;
}

// An observer mode of a mod: its maps make a trigger named StartInsertion in observer mode, and the observers take the slots
// after the players, from where the team changes (3, 5 or 7), else past the last player.
bool LocalIsObserver(const char* game, const char* world, std::int32_t local) {
  if (Field<const char*>(game, 0x97C) == nullptr || kTriggerByName("StartInsertion") == -1) {
    return false;
  }
  std::int32_t first = Field<std::int32_t>(world, 0x5C);
  for (std::int32_t player = 1; player <= 3; ++player) {
    if (kPlayerTeam(player + 1) != kPlayerTeam(player)) {
      first = 2 * player + 1;
      break;
    }
  }
  return local >= first;
}

void NewDatabase(char*) { ++g_generation; }

void Deactivate(const char* why) {
  g_uhcCultureUiCount = 0;
  if (g_style != -1 || g_why != why) {
    uhc::Log(L"cultureUI: no style (%hs)", why);
  }
  g_style = -1;
  g_level = -1;
  g_why = why;
}

void Activate(const char* world, int styleIndex, int level) {
  Style& style = g_styles[styleIndex];
  if (!style.made[level]) {
    void* manager = TextureManager();
    if (manager == nullptr) {
      return;
    }
    style.made[level] = true;
    for (const auto& [base, variant] : style.names[level]) {
      const std::int32_t from = kTextureByName(manager, base.c_str(), 0, 0, -1);
      const std::int32_t to = kTextureByName(manager, variant.c_str(), 0, 0, -1);
      if (from >= 0 && to >= 0 && from != to) {
        style.pairs[level].push_back({from, to});
      }
    }
  }
  if (style.pairs[level].empty()) {
    const std::string why = "style " + std::string(style.suffix.begin(), style.suffix.end()) + " has no texture";
    Deactivate(why.c_str());
    g_style = styleIndex;  // decided: asked again only when the style, the stage or the world changes
    g_level = level;
    g_uhcCultureUiWorld = world;
    return;
  }
  std::int32_t size = 0;
  for (const auto& pair : style.pairs[level]) {
    size = std::max(size, pair.first + 1);
  }
  g_uhcCultureUiCount = 0;
  if (static_cast<std::int32_t>(g_table.size()) < size) {
    g_table.resize(static_cast<size_t>(size));
  }
  for (std::int32_t i = 0; i < size; ++i) {
    g_table[static_cast<size_t>(i)] = i;
  }
  for (const auto& [from, to] : style.pairs[level]) {
    g_table[static_cast<size_t>(from)] = to;
  }
  g_uhcCultureUiTable = g_table.data();
  g_uhcCultureUiWorld = world;
  g_uhcCultureUiCount = static_cast<std::uint32_t>(size);
  if (styleIndex != g_style || level != g_level) {
    uhc::Log(L"cultureUI: style %ls%ls%ls (%u texture(s))", style.suffix.c_str(), level == 0 ? L"" : L", stage ",
             level == 0 ? L"" : style.stages[level - 1].suffix.c_str(),
             static_cast<unsigned>(style.pairs[level].size()));
  }
  g_style = styleIndex;
  g_level = level;
  g_why.clear();
}

// Picks the style and stage for the local player of the HUD's world, and makes the table when they change.
void Evaluate() {
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr || world != g_hudWorld) {
    Deactivate("no game interface");
    return;
  }
  if (!MinimizedUi()) {
    Deactivate("the normal interface");
    return;
  }
  const std::int32_t local = Field<std::int32_t>(game, 0x3C0);
  if (local < 1 || local >= Field<std::int32_t>(world, 0x5C)) {
    Deactivate("no local player");
    return;
  }
  if (LocalIsObserver(game, world, local)) {
    Deactivate("observer");
    return;
  }
  const std::int32_t civ = uhc::FirstCivOfPlayer(kPlayerById(world, local));
  int styleIndex = -1;
  for (size_t i = 0; i < g_styles.size() && styleIndex < 0; ++i) {
    if (g_styles[i].civs.IndexOf(civ) >= 0) {
      styleIndex = static_cast<int>(i);
    }
  }
  if (styleIndex < 0) {
    Deactivate("a civ in no style");
    return;
  }
  Style& style = g_styles[static_cast<size_t>(styleIndex)];
  const char* database = Field<const char*>(game, 0x140);
  const char* techStatus = Field<const char*>(world, 0x7C);
  if (g_techGeneration != g_generation && database != nullptr) {
    g_techGeneration = g_generation;
    for (Style& each : g_styles) {
      for (Stage& stage : each.stages) {
        stage.techId = kTechByName(database, stage.tech.c_str());
        if (stage.techId < 0) {
          uhc::Log(L"cultureUI: no tech named %hs; its stage of style %ls is never reached", stage.tech.c_str(),
                   each.suffix.c_str());
        }
      }
    }
  }
  int level = 0;
  for (size_t k = style.stages.size(); k-- > 0 && level == 0;) {
    const std::int32_t tech = style.stages[k].techId;
    if (tech >= 0 && techStatus != nullptr && kTechActive(techStatus, local, tech)) {
      level = static_cast<int>(k) + 1;
    }
  }
  const bool lost = g_uhcCultureUiCount == 0 && !style.pairs[static_cast<size_t>(level)].empty();
  if (styleIndex != g_style || level != g_level || g_uhcCultureUiWorld != world || lost) {
    Activate(world, styleIndex, level);
  }
}

void Tick(char* world, std::int32_t deltaMs) {
  if (world == nullptr || world != g_hudWorld) {
    return;  // the scenario editor's world, or a game whose HUD was not built yet
  }
  g_elapsed += deltaMs;
  if (g_elapsed < kTickMs) {
    return;
  }
  g_elapsed = 0;
  Evaluate();
}

}  // namespace

extern "C" void __stdcall UhcCultureUiHudBuild() {
  const char* game = Game();
  g_hudWorld = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  g_elapsed = 0;
  g_style = -1;
  g_level = -1;
  Evaluate();
}

namespace uhc {

Outcome ApplyCultureUi(const Config& config) {
  const Config::Args* args = config.First("cultureUI");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::string raw;
  if (!ReadDataListFile(args->empty() ? std::string() : args->front(), L"cultureui.xml", &g_dataFile, &raw)) {
    Log(L"cultureUI: cannot read %ls; not applied", g_dataFile.c_str());
    return Outcome::kFailed;
  }
  if (!ParseData(AsUtf8(raw))) {
    Log(L"cultureUI: %ls is not well-formed; not applied", g_dataFile.c_str());
    return Outcome::kFailed;
  }
  if (g_styles.empty()) {
    Log(L"cultureUI: %ls has no style; not applied", g_dataFile.c_str());
    return Outcome::kFailed;
  }
  wchar_t exe[MAX_PATH];
  const DWORD length = GetModuleFileNameW(nullptr, exe, MAX_PATH);
  std::wstring art(exe, length < MAX_PATH ? length : 0);
  art.resize(art.find_last_of(L'\\') + 1);
  art += L"art\\";
  std::set<std::wstring> files;
  ListFiles(art, kPrefix, &files);
  MatchVariants(files);
  if (!VerifyAll("cultureUI", {&sites::kTextureBindHead, &sites::kHudBuildHead, &sites::kTextureByName,
                               &sites::kSettingsByName, &sites::kOptionBoolGetter, &sites::kTriggerByName,
                               &sites::kPlayerTeam, &sites::kPlayerById, &sites::kTechByName, &sites::kTechActive})) {
    return Outcome::kFailed;
  }
  if (!OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&Tick) ||
      !WriteJmp(sites::kTextureBindHead.va, reinterpret_cast<const void*>(&UhcCultureUiBindHook), 8) ||
      !WriteJmp(sites::kHudBuildHead.va, reinterpret_cast<const void*>(&UhcCultureUiHudHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"cultureUI: %u style(s) from %ls; variants read from %lsui\\ingame", static_cast<unsigned>(g_styles.size()),
      g_dataFile.c_str(), art.c_str());
  return Outcome::kApplied;
}

}  // namespace uhc
