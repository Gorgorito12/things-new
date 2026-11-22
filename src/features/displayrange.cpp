// displayedRange: a selected unit shows its range on the ground while Alt is held, one ring per ranged attack.
//
// Proto data:
//   <DisplayRange>1</DisplayRange>              the unit shows its rings when it is selected and Alt is held;
//   <AlwaysDisplayRange>1</AlwaysDisplayRange>  (or <Flag>AlwaysDisplayRange</Flag>) it shows them whenever it is
//                                               selected, without Alt;
//   <DisplayedRange>N</DisplayedRange>          a fixed radius instead of the attacks', repeatable.
// With no <DisplayedRange>, the radii are the MaxRange (0x4946D6 with key -1, as the stat panel reads it) of each
// active action of the unit's current tactic with the ranged flag 0Ah (<RangedLogic>), read from the player's copy,
// so range techs show at once. Each radius is drawn as the ring of tools/rings nearest to it; two attacks on one
// ring share it.
//
// Alt is the game's own query, the one the HP bar chunk makes (0x452EA0..0x452EB3: [[[0C66244h]+74h]+2Ch], vtable
// +34h with 2). The ring is a model of the table the tactics parser uses (0x58F68F, 0x58E506), hung on the unit as
// the stock aura update does. A world tick every 100 ms compares the local selection (0x453B28: IDs [group+10h],
// count [group+14h]) and the Alt state with the rings the units hold. Display only: a model is a visual of the unit,
// the selection and the keyboard are this machine's, and nothing here reaches the simulation.
//
// Placement: while a building is being placed, its ghost shows the rings of its proto's ranged attacks (every tactic's,
// from the local player's copy) or its <DisplayedRange>, with no tag needed (option noPlacement turns it off). The
// shared ghost update (ghostobservers.h, 0x96E4E7) hangs them on the ghost's model [[[0xC67300]+200h]+34h], of a unit
// visual's class, through the stock model functions, which read only a unit's visual (unitmodels.h); a new proto or a
// new model starts again, and the model takes its rings with it when the placement ends.
//
// Player colour (option playerColor): the ring is range_<N>_p<k>.xml, its particle tinted (<color>) with player k's
// colour, k the owner's player ID (the local player's for a ghost). A particle has no player colour of its own (its
// colour fields are UsePalette, NumPaletteColors, PaletteColors, ColorStages and the fixed Color), so make_rings.py
// writes one tinted copy per player of the colour table.
//
// <Flag>: the proto flag parser 0x5F640A (stdcall(proto, name)) compares the name with each flag it knows and
// returns with nothing for any other name. Its last compare, the call 0x5F726F of the string compare 0x4028B4, is
// redirected: the compare runs, and a name it does not match is offered to this key.
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../ghostobservers.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../unitmodels.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
void UhcProtoFlagCompareHook();
std::uint32_t g_uhcStringCompare = 0x004028B4;
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kUiGlobal = 0x00C67300;     // the placement ghost: +1FCh the proto ID, +200h its visual
constexpr std::uint32_t kInputGlobal = 0x00C66244;  // [[+74h]+2Ch]: the object the Alt query asks
constexpr std::uint32_t kTickMs = 100;
constexpr std::uint32_t kRangedFlag = 0x0A;  // <RangedLogic> (0x5FAC6D), the bit the stat panel tests for a range
// Measured (perfprobe, 2026-11-21, 50 selected units on screen, render time a frame): 100 rings 6.6 ms against 6.0
// with the key off, 200 rings 8.0 against 7.6, inside the noise of the runs (0.6 ms). The caps keep a big selection
// readable: at most 4 rings a unit and 60 in all, the units with the longest ranges first.
constexpr std::size_t kMaxRingsPerUnit = 4;
constexpr std::size_t kMaxRings = 60;
constexpr std::int32_t kMaxPlayerColour = 9;  // the colour table's players 0 to 9 (make_rings.py, RANGE_PLAYERS)
// The sizes aoe3-blender-tools' make_rings.py writes (RANGES).
constexpr std::int32_t kRadii[] = {4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 36, 40, 45, 50, 60, 70, 80, 100};

using SelectionFn = const char*(__cdecl*)();
using UnitByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);
using RangeFn = float(__thiscall*)(const char* action, std::int32_t key);
using KeyQueryFn = bool(__thiscall*)(void* input, std::int32_t key);
using PlayerByIdFn = const char*(__thiscall*)(const char* world, std::int32_t id);
using PlayerProtoFn = const char*(__thiscall*)(const char* player, std::int32_t id);

const auto kSelection = reinterpret_cast<SelectionFn>(0x00453B28);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kRange = reinterpret_cast<RangeFn>(0x004946D6);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);

struct Range {
  bool show = false;    // <DisplayRange>
  bool always = false;  // <AlwaysDisplayRange>
  std::vector<float> fixed;  // <DisplayedRange>, each
};

std::unordered_map<std::int32_t, Range> g_protos;  // by proto ID; the load fills it
std::map<std::int32_t, std::int32_t> g_models;     // by radius x 16 + colour (15: none)
std::map<std::int32_t, std::vector<std::int32_t>> g_hung;  // by unit ID: the models on it
std::int32_t g_bone = -2;
const char* g_world = nullptr;
std::uint32_t g_nextTick = 0;
bool g_lastAlt = false;
bool g_log = false;
bool g_placement = true;      // the ghost's rings (option noPlacement: off)
bool g_playerColour = false;  // option playerColor

struct Ghost {
  char* visual = nullptr;
  std::int32_t proto = -2;
  std::vector<std::int32_t> models;  // what the observer hung on this visual
};
Ghost g_ghost;
int g_logLines = 0;
constexpr int kMaxLogLines = 200;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

bool Bit(const char* object, std::uint32_t offset, std::uint32_t bit) {
  if (Field<std::uint32_t>(object, offset + 4) <= bit) {
    return false;
  }
  const auto* bytes = Field<const std::uint8_t*>(object, offset);
  return bytes != nullptr && (bytes[bit >> 3] & (1u << (bit & 7))) != 0;
}

const wchar_t* NodeText(const char* node) { return *reinterpret_cast<const wchar_t* const*>(node + 0x14); }

bool On(const wchar_t* text) { return text == nullptr || text[0] == L'\0' || _wtoi(text) != 0; }

bool __cdecl ReadShow(void*, const char* node, char* proto) {
  g_protos[Field<std::int32_t>(proto, 0x04)].show = On(NodeText(node));
  return true;
}

bool __cdecl ReadAlways(void*, const char* node, char* proto) {
  g_protos[Field<std::int32_t>(proto, 0x04)].always = On(NodeText(node));
  return true;
}

bool __cdecl ReadMetres(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  const float metres = text == nullptr ? 0.0f : std::wcstof(text, nullptr);
  if (metres > 0.0f) {
    g_protos[Field<std::int32_t>(proto, 0x04)].fixed.push_back(metres);
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
  g_logLines = 0;
  g_ghost = Ghost{};
}

bool AltHeld() {
  const char* root = *reinterpret_cast<const char* const*>(kInputGlobal);
  const char* inner = root == nullptr ? nullptr : Field<const char*>(root, 0x74);
  char* input = inner == nullptr ? nullptr : Field<char*>(inner, 0x2C);
  if (input == nullptr || Field<const void*>(input, 0) == nullptr) {
    return false;
  }
  const auto query = Field<KeyQueryFn>(Field<const char*>(input, 0), 0x34);
  return query(input, 2);
}

std::int32_t RingRadius(float metres) {
  std::int32_t radius = kRadii[0];
  for (const std::int32_t candidate : kRadii) {
    if (std::abs(static_cast<float>(candidate) - metres) < std::abs(static_cast<float>(radius) - metres)) {
      radius = candidate;
    }
  }
  return radius;
}

// The model of a ring: range_<N>.xml, or with playerColor range_<N>_p<k>.xml for player `player`.
std::int32_t ModelFor(std::int32_t radius, std::int32_t player) {
  const std::int32_t colour = g_playerColour && player >= 0 && player <= kMaxPlayerColour ? player : 15;
  const std::int32_t key = radius * 16 + colour;
  const auto found = g_models.find(key);
  if (found != g_models.end()) {
    return found->second;
  }
  wchar_t path[64];
  if (colour == 15) {
    swprintf_s(path, L"effects\\uhc_rings\\range_%d.xml", radius);
  } else {
    swprintf_s(path, L"effects\\uhc_rings\\range_%d_p%d.xml", radius, colour);
  }
  const std::int32_t model = uhc::ModelOfPath(path);
  if (g_log) {
    uhc::Log(L"displayedRange: %ls is model %d", path, model);
  }
  if (model != -1) {  // -1: the table does not exist yet
    g_models[key] = model;
  }
  return model;
}

// The ranged attacks of one tactic, as the attack list 0x487EEE reads them: 12-byte entries at [tactic+44h] (count
// +48h), +4 the index of the action in the set [tactic+0] (actions [set+1Ch], count +20h); an action counts when it is
// active (bit 0 of [action+64h]), has the ranged flag and a range entry.
void TacticRadii(const char* tactic, std::vector<std::int32_t>& radii) {
  const char* owner = Field<const char*>(tactic, 0x00);
  const char* entries = Field<const char*>(tactic, 0x44);
  const std::int32_t count = Field<std::int32_t>(tactic, 0x48);
  const auto* actions = owner == nullptr ? nullptr : Field<const char* const*>(owner, 0x1C);
  const std::int32_t actionCount = owner == nullptr ? 0 : Field<std::int32_t>(owner, 0x20);
  for (std::int32_t i = 0; i < count && entries != nullptr && actions != nullptr; ++i) {
    const std::int32_t which = Field<std::int32_t>(entries, 12 * i + 4);
    if (which < 0 || which >= actionCount) {
      continue;
    }
    const char* action = actions[which];
    if (action == nullptr || !Bit(action, 0x64, 0) || !Bit(action, 0x64, kRangedFlag) ||
        Field<std::int32_t>(action, 0x1C) <= 0) {
      continue;
    }
    const float metres = kRange(action, -1);
    if (metres > 0.5f) {
      radii.push_back(RingRadius(metres));
    }
  }
}

// The rings the unit wants, largest first, at most kMaxRingsPerUnit: the fixed <DisplayedRange> values, or the ranged
// attacks of its current tactic ([mgr+0A8h], an index into the player's proto's tactics [[proto+44h]+10h], count
// +14h); a tactic with none (an artillery piece limbered to move) takes those of all its tactics, the attacks it
// unlimbers to.
// Largest first, each size once, at most kMaxRingsPerUnit.
void Trim(std::vector<std::int32_t>& radii) {
  std::sort(radii.begin(), radii.end(), [](std::int32_t a, std::int32_t b) { return a > b; });
  radii.erase(std::unique(radii.begin(), radii.end()), radii.end());
  if (radii.size() > kMaxRingsPerUnit) {
    radii.resize(kMaxRingsPerUnit);
  }
}

std::vector<std::int32_t> WantedRadii(const char* unit, const Range& range) {
  std::vector<std::int32_t> radii;
  if (!range.fixed.empty()) {
    for (const float metres : range.fixed) {
      radii.push_back(RingRadius(metres));
    }
  } else {
    const char* proto = Field<const char*>(unit, 0x5C);
    const char* manager = Field<const char*>(unit, 0x58);
    const char* set = proto == nullptr ? nullptr : Field<const char*>(proto, 0x44);
    const auto* tactics = set == nullptr ? nullptr : Field<const char* const*>(set, 0x10);
    const std::int32_t count = set == nullptr ? 0 : Field<std::int32_t>(set, 0x14);
    if (manager != nullptr && tactics != nullptr) {
      const std::int32_t index = Field<std::int32_t>(manager, 0xA8);
      if (index >= 0 && index < count && tactics[index] != nullptr) {
        TacticRadii(tactics[index], radii);
      }
      for (std::int32_t i = 0; radii.empty() && i < count; ++i) {
        if (tactics[i] != nullptr) {
          TacticRadii(tactics[i], radii);
        }
      }
    }
  }
  Trim(radii);
  return radii;
}

// The rings of a proto with no unit (the placement ghost): its <DisplayedRange> values, or the ranged attacks of every
// tactic of the player's copy (a building has no current tactic before it stands).
std::vector<std::int32_t> ProtoRadii(const char* proto, const Range* range) {
  std::vector<std::int32_t> radii;
  if (range != nullptr && !range->fixed.empty()) {
    for (const float metres : range->fixed) {
      radii.push_back(RingRadius(metres));
    }
  } else {
    const char* set = Field<const char*>(proto, 0x44);
    const auto* tactics = set == nullptr ? nullptr : Field<const char* const*>(set, 0x10);
    const std::int32_t count = set == nullptr ? 0 : Field<std::int32_t>(set, 0x14);
    for (std::int32_t i = 0; tactics != nullptr && i < count; ++i) {
      if (tactics[i] != nullptr) {
        TacticRadii(tactics[i], radii);
      }
    }
  }
  Trim(radii);
  return radii;
}

std::int32_t OwnerId(const char* unit) {
  const char* owner = Field<const char*>(unit, 0x44);
  return owner == nullptr ? -1 : Field<std::int32_t>(owner, 0);
}

void Release(const char* world, std::int32_t id, const std::vector<std::int32_t>& models) {
  if (char* unit = const_cast<char*>(kUnitById(world, id))) {
    for (const std::int32_t model : models) {
      uhc::RemoveUnitModel(unit, model);
    }
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"displayedRange: rings off unit %d", id);
  }
}

struct Want {
  std::int32_t id;
  char* unit;
  std::vector<std::int32_t> models;
  std::vector<std::int32_t> radii;  // each model's
  std::int32_t largest;
};

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
  const bool alt = AltHeld();
  if (g_log && alt != g_lastAlt && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"displayedRange: Alt %ls", alt ? L"held" : L"released");
  }
  g_lastAlt = alt;

  std::vector<Want> wants;
  const char* selection = kSelection();
  const std::int32_t count = selection == nullptr ? 0 : Field<std::int32_t>(selection, 0x14);
  const auto* ids = selection == nullptr ? nullptr : Field<const std::int32_t*>(selection, 0x10);
  for (std::int32_t i = 0; i < count && ids != nullptr; ++i) {
    char* unit = const_cast<char*>(kUnitById(world, ids[i]));
    const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
    if (proto == nullptr) {
      continue;
    }
    const auto found = g_protos.find(Field<std::int32_t>(proto, 0x04));
    if (found == g_protos.end() || !(found->second.always || (found->second.show && alt))) {
      continue;
    }
    Want want{ids[i], unit, {}, {}, 0};
    for (const std::int32_t radius : WantedRadii(unit, found->second)) {
      const std::int32_t model = ModelFor(radius, OwnerId(unit));
      if (model != -1) {
        want.models.push_back(model);
        want.radii.push_back(radius);
        want.largest = std::max(want.largest, radius);
      }
    }
    if (!want.models.empty()) {
      wants.push_back(std::move(want));
    }
  }
  std::stable_sort(wants.begin(), wants.end(), [](const Want& a, const Want& b) { return a.largest > b.largest; });
  std::size_t budget = kMaxRings;
  for (Want& want : wants) {  // each unit's rings are largest first
    const std::size_t keep = std::min(budget, want.models.size());
    want.models.resize(keep);
    want.radii.resize(keep);
    budget -= keep;
  }
  std::erase_if(wants, [](const Want& want) { return want.models.empty(); });

  std::map<std::int32_t, const Want*> byId;
  for (const Want& want : wants) {
    byId[want.id] = &want;
  }
  for (auto it = g_hung.begin(); it != g_hung.end();) {
    const auto wanted = byId.find(it->first);
    if (wanted == byId.end()) {
      Release(world, it->first, it->second);
      it = g_hung.erase(it);
      continue;
    }
    // Rings the unit no longer wants (a tactic or a tech changed its attacks).
    std::vector<std::int32_t> keep;
    char* unit = wanted->second->unit;
    for (const std::int32_t model : it->second) {
      if (std::find(wanted->second->models.begin(), wanted->second->models.end(), model) !=
          wanted->second->models.end()) {
        keep.push_back(model);
      } else {
        uhc::RemoveUnitModel(unit, model);
      }
    }
    it->second = std::move(keep);
    ++it;
  }
  if (g_bone == -2 && !wants.empty()) {
    g_bone = uhc::NoBone();
  }
  for (const Want& want : wants) {
    std::vector<std::int32_t>& hung = g_hung[want.id];
    for (std::size_t k = 0; k < want.models.size(); ++k) {
      const std::int32_t model = want.models[k];
      if (std::find(hung.begin(), hung.end(), model) != hung.end()) {
        continue;
      }
      const uhc::ModelHang hang = uhc::HangUnitModel(want.unit, model, g_bone);
      if (hang == uhc::ModelHang::kHung || hang == uhc::ModelHang::kNotInGame) {
        hung.push_back(model);
        if (g_log && g_logLines < kMaxLogLines) {
          ++g_logLines;
          uhc::Log(L"displayedRange: ring of %d m on unit %d (%hs)%ls", want.radii[k], want.id,
                   Field<const char*>(Field<const char*>(want.unit, 0x5C), 0x10), alt ? L", Alt held" : L"");
        }
      }
    }
  }
}

// From the shared ghost update (ghostobservers.h), each frame while a building is placed: the rings of its proto on
// the ghost's model. The ghost object [[0xC67300]+200h] holds its transform; the model drawn is [ghost+34h], an object
// of the class of a unit's visual [unit+60h] (in game both start with the same word, and the ghost's code calls three
// of that class's functions on it: 0x40431B, 0xA3FEF8, 0xADA24B), so the stock model functions take it.
void __stdcall OnGhost(char* ghost) {
  const char* ui = *reinterpret_cast<const char* const*>(kUiGlobal);
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  if (ui == nullptr || game == nullptr || ghost == nullptr || Field<char*>(ui, 0x200) != ghost) {
    return;
  }
  char* visual = Field<char*>(ghost, 0x34);
  if (visual == nullptr || Field<const char*>(visual, 0xA8) == nullptr) {  // the model functions read its +0A8h
    return;
  }
  const std::int32_t protoId = Field<std::int32_t>(ui, 0x1FC);
  if (visual != g_ghost.visual) {
    g_ghost = Ghost{visual};  // another visual: what was hung on the old one went with it
  }
  if (protoId != g_ghost.proto) {
    for (const std::int32_t model : g_ghost.models) {
      uhc::RemoveVisualModel(visual, model);
    }
    g_ghost.models.clear();
    g_ghost.proto = protoId;
    const char* world = Field<const char*>(game, 0x13C);
    const std::int32_t playerId = Field<std::int32_t>(game, 0x3C0);
    const char* player = world == nullptr || protoId < 0 ? nullptr : kPlayerById(world, playerId);
    const char* proto = player == nullptr ? nullptr : kPlayerProto(player, protoId);
    if (proto != nullptr) {
      const auto found = g_protos.find(Field<std::int32_t>(proto, 0x04));
      for (const std::int32_t radius : ProtoRadii(proto, found == g_protos.end() ? nullptr : &found->second)) {
        const std::int32_t model = ModelFor(radius, playerId);
        if (model != -1) {
          g_ghost.models.push_back(model);
          if (g_log && g_logLines < kMaxLogLines) {
            ++g_logLines;
            uhc::Log(L"displayedRange: ring of %d m on the placement ghost (%hs)", radius,
                     Field<const char*>(proto, 0x10));
          }
        }
      }
    }
  }
  if (g_ghost.models.empty()) {
    return;
  }
  if (g_bone == -2) {
    g_bone = uhc::NoBone();
  }
  for (const std::int32_t model : g_ghost.models) {
    if (!uhc::VisualHasModel(visual, model)) {
      uhc::HangVisualModel(visual, model, g_bone);
    }
  }
}

}  // namespace

extern "C" {

// From the flag parser's last compare: a name no stock flag matched.
void __stdcall UhcUnknownProtoFlag(const char* proto, const char* name) {
  if (proto == nullptr || name == nullptr || _stricmp(name, "AlwaysDisplayRange") != 0) {
    return;
  }
  g_protos[Field<std::int32_t>(proto, 0x04)].always = true;
  if (g_log) {
    uhc::Log(L"displayedRange: proto %hs: <Flag>AlwaysDisplayRange</Flag>", Field<const char*>(proto, 0x10));
  }
}
}

namespace uhc {

Outcome ApplyDisplayedRange(const Config& config) {
  const Config::Args* args = config.First("displayedRange");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "noPlacement") == 0) {
      g_placement = false;
    } else if (_stricmp(arg.c_str(), "playerColor") == 0) {
      g_playerColour = true;
    } else {
      Log(L"displayedRange: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("displayedRange", {&sites::kCurrentSelectionGroup, &sites::kUnitById, &sites::kAltQuery,
                                    &sites::kActionRangeByKey, &sites::kProtoFlagLastCompare, &sites::kPlayerById,
                                    &sites::kPlayerProtoEntry}) ||
      (g_placement && !AddGhostObserver(&OnGhost)) ||
      !VerifyUnitModels("displayedRange") || !AddProtoTagHandler("DisplayRange", &ReadShow) ||
      !AddProtoTagHandler("DisplayedRange", &ReadMetres) || !AddProtoTagHandler("AlwaysDisplayRange", &ReadAlways) ||
      !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&Tick) ||
      !WriteCall(sites::kProtoFlagLastCompare.va + 6, reinterpret_cast<const void*>(&UhcProtoFlagCompareHook))) {
    return Outcome::kFailed;
  }
  Log(L"displayedRange: rings while Alt is held (<DisplayRange>) or always (<AlwaysDisplayRange>), one per ranged "
      L"attack or <DisplayedRange>%ls%ls", g_placement ? L"; on the placement ghost of a ranged building" : L"",
      g_playerColour ? L"; in the owner's colour" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
