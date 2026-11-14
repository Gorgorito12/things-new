// displayedRange: a selected unit with <DisplayRange>1</DisplayRange> shows a ring of the radius of
// <DisplayedRange>N</DisplayedRange> on the ground, the ring of tools/rings nearest to N.
//
// The ring is a model of the table the tactics parser uses: 0x58F68F gives the ID of a path (0x5FC91C) and
// 0x58E506 the ID of a bone name (0x5FC8EE), and the model goes on the unit as the stock aura update does
// (0x9D054A..0x9D059C). A world tick compares the local selection (0x453B28: IDs [group+10h], count
// [group+14h]) with the units that hold a ring. Display only: a model is a visual of the unit, the selection
// is this machine's, and nothing here reaches the simulation.
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../unitmodels.h"
#include "../unittypes.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kTickMs = 250;
constexpr std::int32_t kRadii[] = {4, 6, 8, 10, 12, 14, 16, 20, 24, 30};  // the sizes aoe3-blender-tools' make_rings.py writes

using SelectionFn = const char*(__cdecl*)();
using UnitByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);

const auto kSelection = reinterpret_cast<SelectionFn>(0x00453B28);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);

struct Range {
  bool show = false;
  float metres = 0.0f;
};

std::unordered_map<std::int32_t, Range> g_protos;  // by proto ID; the load fills it
std::map<std::int32_t, std::int32_t> g_models;     // by radius; -1: not in the game
std::map<std::int32_t, std::int32_t> g_hung;       // by unit ID: the model on it
std::int32_t g_bone = -2;
const char* g_world = nullptr;
std::uint32_t g_nextTick = 0;
bool g_log = false;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const wchar_t* NodeText(const char* node) { return *reinterpret_cast<const wchar_t* const*>(node + 0x14); }

bool __cdecl ReadShow(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  g_protos[Field<std::int32_t>(proto, 0x04)].show = text == nullptr || text[0] == L'\0' || _wtoi(text) != 0;
  return true;
}

bool __cdecl ReadMetres(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  const float metres = text == nullptr ? 0.0f : std::wcstof(text, nullptr);
  if (metres > 0.0f) {
    g_protos[Field<std::int32_t>(proto, 0x04)].metres = metres;
  } else {
    uhc::Log(L"displayedRange: proto %d: <DisplayedRange> needs a number above 0, ignored", Field<std::int32_t>(proto, 0x04));
  }
  return true;
}

void NewDatabase(char*) {
  g_protos.clear();
  g_models.clear();
  g_hung.clear();
  g_bone = -2;
}

std::int32_t ModelFor(float metres) {
  std::int32_t radius = kRadii[0];
  for (const std::int32_t candidate : kRadii) {
    if (std::abs(static_cast<float>(candidate) - metres) < std::abs(static_cast<float>(radius) - metres)) {
      radius = candidate;
    }
  }
  const auto found = g_models.find(radius);
  if (found != g_models.end()) {
    return found->second;
  }
  wchar_t path[64];
  swprintf_s(path, L"effects\\uhc_rings\\range_%d.xml", radius);
  const std::int32_t model = uhc::ModelOfPath(path);
  if (g_log) {
    uhc::Log(L"displayedRange: %ls is model %d", path, model);
  }
  g_models[radius] = model;
  return model;
}

void Release(const char* world, std::int32_t id, std::int32_t model) {
  if (char* unit = const_cast<char*>(kUnitById(world, id))) {
    uhc::RemoveUnitModel(unit, model);
  }
  if (g_log) {
    uhc::Log(L"displayedRange: ring off unit %d", id);
  }
}

void Tick(char* world, std::int32_t) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  if (game == nullptr || world != Field<const char*>(game, 0x13C)) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_world || now < g_nextTick - kTickMs) {
    g_hung.clear();  // another game: its unit IDs are not these
    g_world = world;
    g_nextTick = 0;
  }
  if (now < g_nextTick) {
    return;
  }
  g_nextTick = now + kTickMs;

  std::set<std::int32_t> wanted;
  const char* selection = kSelection();
  const std::int32_t count = selection == nullptr ? 0 : Field<std::int32_t>(selection, 0x14);
  const auto* ids = selection == nullptr ? nullptr : Field<const std::int32_t*>(selection, 0x10);
  for (std::int32_t i = 0; i < count && ids != nullptr; ++i) {
    wanted.insert(ids[i]);
  }
  for (auto it = g_hung.begin(); it != g_hung.end();) {
    if (wanted.count(it->first) != 0) {
      ++it;
      continue;
    }
    Release(world, it->first, it->second);
    it = g_hung.erase(it);
  }
  for (const std::int32_t id : wanted) {
    if (g_hung.count(id) != 0) {
      continue;
    }
    char* unit = const_cast<char*>(kUnitById(world, id));
    const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    if (proto == nullptr) {
      continue;
    }
    const auto found = g_protos.find(Field<std::int32_t>(proto, 0x04));
    if (found == g_protos.end() || !found->second.show || found->second.metres <= 0.0f) {
      continue;
    }
    const std::int32_t model = ModelFor(found->second.metres);
    if (model == -1) {
      continue;
    }
    if (g_bone == -2) {
      g_bone = uhc::NoBone();
    }
    const uhc::ModelHang hang = uhc::HangUnitModel(unit, model, g_bone);
    if (hang == uhc::ModelHang::kHung || hang == uhc::ModelHang::kNotInGame) {
      g_hung[id] = model;
      if (g_log) {
        uhc::Log(L"displayedRange: ring of %.1f m on unit %d (%hs)", static_cast<double>(found->second.metres), id,
                 Field<const char*>(proto, 0x10));
      }
    }
  }
}

}  // namespace

namespace uhc {

Outcome ApplyDisplayedRange(const Config& config) {
  const Config::Args* args = config.First("displayedRange");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"displayedRange: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("displayedRange", {&sites::kCurrentSelectionGroup, &sites::kUnitById}) ||
      !VerifyUnitModels("displayedRange") ||
      !AddProtoTagHandler("DisplayRange", &ReadShow) || !AddProtoTagHandler("DisplayedRange", &ReadMetres) ||
      !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  Log(L"displayedRange: the proto tags DisplayRange and DisplayedRange are on");
  return Outcome::kApplied;
}

}  // namespace uhc
