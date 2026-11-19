// nativePreview [tagged] [log] [<BuildingProto>]: selecting an empty native socket shows the command
// panel its Trading Post would have there: the native's units and techs, as disabled buttons with
// their normal rollovers. A click on one does nothing.
//
// Stock, for a selected native socket: the bottom panel chooser (FUN_00454270 and its chunks)
// hides the command panel ([ui+78h]) and shows the native's settlement panel instead; and the
// command panel refresh FUN_0046188E, when it runs, leaves at once (0x46194D) unless the
// selection's player [sel+0Ch] is the local player. Its entries come from the selected unit's
// proto ([proto+0E8h], 6-byte records {word id, kind 0 Train / 1 Tech / 2 Command, page,
// column}); a socket proto has none. The Trading Post has one list for every native, and the
// panel shows what the player's alliances made available.
//
// The hooks (hooks/nativepreview_hooks.asm). In the chooser:
// - 0x645FE7, where a selected Socket would get the settlement panel, and 0x646124, where a
//   socket with a <SubCiv> hides the command panel: a socket that gets a preview goes on as any
//   other unit, so the chooser shows the command panel.
// In the command panel refresh:
// - 0x46193E, the gate: the refresh goes on as for the local player's own unit, and the preview is
//   on for this refresh;
// - 0x461BBD: the entries are the local player's copy of the building (TradingPost by default);
// - 0x4C58AD: of those, only the Train entries of units the native's age techs enable (Data effect
//   Enable) and the Tech entries they make obtainable (TechStatus) are collected; the stock
//   availability tests, which would drop all of them, are skipped;
// - 0x4620B9: a tech skips the "can research here" and status tests but keeps the stock
//   prerequisite test (0x4C7330, 0x4C5DDA): one waiting for another tech stays hidden, and one
//   waiting for an age gets its age mark, as on a real Trading Post;
// - 0x462317: every button of the preview is disabled and gets no command.
//
// A socket gets a preview when its proto carries NativeSocket (and, with "tagged", the tag
// <NativePreview/>), names a <SubCiv>, and no building of its socket type stands on it (0xA01A20,
// the occupant lookup of trPlayerControlsSocket). The native's sets come from the civ's age techs
// ([civ+50h]): their effects are read once per civ and database. Nothing here writes game state;
// the panel is the local player's own view, so nothing reaches the other machines.
#include <cstdint>
#include <cstring>
#include <map>
#include <set>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../unittypes.h"

extern "C" {
std::int32_t g_uhcNpActive = 0;        // 1 while the current refresh builds a preview
const char* g_uhcNpEntries = nullptr;  // the building's entries, &[proto+0E8h]
void UhcNpSocketPanelHook();
void UhcNpSubCivHook();
void UhcNpGateHook();
void UhcNpProtoHook();
void UhcNpCollectHook();
void UhcNpTechLayoutHook();
void UhcNpButtonHook();
}

namespace {

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

using IsAFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using PlayerProtoFn = char*(__thiscall*)(const char* player, std::int32_t protoId);
using ProtoByNameFn = std::int32_t(__thiscall*)(const char* database, const char* name);
using SocketOccupantFn = std::int32_t(__thiscall*)(const char* world, const float* position, const char* socketProto);
const auto kIsA = reinterpret_cast<IsAFn>(0x0044D7FA);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kProtoByName = reinterpret_cast<ProtoByNameFn>(0x005A2346);
const auto kSocketOccupant = reinterpret_cast<SocketOccupantFn>(0x00A01A20);

constexpr std::uint32_t kTechStatusVtable = 0x00B969B0;  // BEffect TechStatus (ctor 0x620B4D)
constexpr std::uint32_t kDataVtable = 0x00B9E5A8;        // BEffect Data (ctor 0x620BAC)
constexpr std::int32_t kSubtypeEnable = 0x10;            // registered at 0x524F2B
constexpr int kMaxDepth = 4;                              // "active" techs followed this deep

bool g_tagged = false;
bool g_log = false;
std::string g_buildingName = "TradingPost";
std::int32_t g_nativeSocketType = -1;  // set on each database load

std::set<std::int32_t> g_taggedProtos;  // protos with <NativePreview/>, by ID

struct NativeSets {
  std::set<std::int32_t> units;
  std::set<std::int32_t> techs;
};
std::map<std::int32_t, NativeSets> g_sets;  // by civ ID, for the database below
const char* g_setsDatabase = nullptr;
std::int32_t g_buildingId = -2;  // -2: not looked up for this database
const NativeSets* g_current = nullptr;

std::int32_t g_loggedSocket = -1;  // the socket last logged with "log"
const char* g_logWorld = nullptr;

void ForgetData(char*) {
  g_taggedProtos.clear();
  g_sets.clear();
  g_setsDatabase = nullptr;
  g_buildingId = -2;
  g_current = nullptr;
}

bool __cdecl ReadTag(void*, const char*, char* proto) {
  g_taggedProtos.insert(Field<std::int32_t>(proto, 0x04));
  return true;
}

void AddTechEffects(const char* database, std::int32_t techId, NativeSets& sets, int depth) {
  const char* tree = Field<const char*>(database, 0x5D9C);
  if (tree == nullptr || techId < 0 || techId >= Field<std::int32_t>(tree, 0x10)) {
    return;
  }
  const char* node = Field<const char*>(Field<const char*>(tree, 0x0C) + 0x24 * techId, 0);
  if (node == nullptr) {
    return;
  }
  const char* const* effects = Field<const char* const*>(node, 0x24);
  const std::int32_t count = Field<std::int32_t>(node, 0x28);
  for (std::int32_t i = 0; effects != nullptr && i < count; ++i) {
    const char* effect = effects[i];
    if (effect == nullptr) {
      continue;
    }
    const std::uint32_t vtable = Field<std::uint32_t>(effect, 0);
    if (vtable == kTechStatusVtable) {
      const std::int32_t target = Field<std::int32_t>(effect, 0x0C);
      const std::uint8_t status = Field<std::uint8_t>(effect, 0x10);  // 0 unobtainable, 1 obtainable, 2 active
      if (target >= 0 && (status == 1 || status == 2) && sets.techs.insert(target).second && status == 2 &&
          depth < kMaxDepth) {
        AddTechEffects(database, target, sets, depth + 1);
      }
    } else if (vtable == kDataVtable) {
      const std::int32_t target = Field<std::int32_t>(effect, 0x04);
      if (Field<std::int32_t>(effect, 0x0C) == kSubtypeEnable && Field<float>(effect, 0x18) > 0.0f && target >= 0) {
        sets.units.insert(target);
      }
    }
  }
}

const NativeSets& SetsOf(const char* database, std::int32_t civId) {
  if (database != g_setsDatabase) {
    g_sets.clear();
    g_setsDatabase = database;
    g_buildingId = -2;
  }
  auto found = g_sets.find(civId);
  if (found != g_sets.end()) {
    return found->second;
  }
  NativeSets& sets = g_sets[civId];
  const char* civ = Field<const char* const*>(database, 0x24)[civId];
  const char* ages = civ == nullptr ? nullptr : Field<const char*>(civ, 0x50);
  const std::int32_t ageCount = civ == nullptr ? 0 : Field<std::int32_t>(civ, 0x54);
  for (std::int32_t age = 0; ages != nullptr && age < ageCount; ++age) {
    AddTechEffects(database, Field<std::int32_t>(ages, 8 * age), sets, 0);
  }
  return sets;
}

const char* UnitById(const char* world, std::int32_t id) {
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

// Techs the layout would put in one of its four big-button slots instead of the grid (tech flags
// 27, 36, 37, 39, tested before 0x696652): that path skips the button hook, so they are left out of
// a preview. No native tech of the data tested has them.
bool BigButtonTech(const char* database, std::int32_t techId) {
  const char* tree = Field<const char*>(database, 0x5D9C);
  if (tree == nullptr || techId < 0 || techId >= Field<std::int32_t>(tree, 0x10)) {
    return true;
  }
  const char* record = Field<const char*>(tree, 0x0C) + 0x24 * techId;
  const std::uint8_t* bits = Field<const std::uint8_t*>(record, 0x04);
  const std::uint32_t bitCount = Field<std::uint32_t>(record, 0x08);
  for (const std::uint32_t bit : {27u, 36u, 37u, 39u}) {
    if (bits != nullptr && bit < bitCount && (bits[bit >> 3] & (1u << (bit & 7))) != 0) {
      return true;
    }
  }
  return false;
}

bool Shown(const std::uint8_t* entry, const NativeSets& sets, const char* database) {
  const std::int32_t id = *reinterpret_cast<const std::uint16_t*>(entry);
  const std::uint8_t kind = entry[2];
  const std::uint8_t page = entry[3];
  if (page == 0xFF || page == 0x0A) {
    return false;
  }
  if (kind == 0) {
    return sets.units.count(id) != 0;
  }
  if (kind == 1) {
    return sets.techs.count(id) != 0 && !BigButtonTech(database, id);
  }
  return false;
}

// The preview a selected unit gets: the building whose entries the panel shows, with the native's
// sets; a null building for a unit that keeps the stock panels.
struct Preview {
  const char* building = nullptr;  // the local player's copy
  const NativeSets* sets = nullptr;
  std::int32_t civId = -1;
};

Preview PreviewOf(const char* unit) {
  const Preview none;
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (world == nullptr || database == nullptr || proto == nullptr || g_nativeSocketType < 0 ||
      !kIsA(proto, g_nativeSocketType)) {
    return none;
  }
  if (g_tagged && g_taggedProtos.count(Field<std::int32_t>(proto, 0x04)) == 0) {
    return none;
  }
  const std::uint8_t civId = Field<std::uint8_t>(proto, 0x1D1);  // <SubCiv>, 0xFF for none
  if (civId == 0xFF || civId >= Field<std::int32_t>(database, 0x28)) {
    return none;
  }
  const std::int32_t local = Field<std::int32_t>(game, 0x3C0);
  if (local < 0 || local >= Field<std::int32_t>(world, 0x5C)) {
    return none;
  }
  const char* player = Field<const char* const*>(world, 0x58)[local];
  if (player == nullptr) {
    return none;
  }
  if (kSocketOccupant(world, reinterpret_cast<const float*>(unit + 0x14), proto) >= 0) {
    return none;  // a building stands on it: its own panel, as in stock
  }
  const NativeSets& sets = SetsOf(database, civId);
  if (g_buildingId == -2) {
    g_buildingId = kProtoByName(database, g_buildingName.c_str());
    if (g_buildingId < 0) {
      uhc::Log(L"nativePreview: no proto %hs in this data; no preview", g_buildingName.c_str());
    }
  }
  if (g_buildingId < 0) {
    return none;
  }
  const char* building = kPlayerProto(player, g_buildingId);
  if (building == nullptr || Field<std::int32_t>(building, 0xEC) <= 0) {
    return none;
  }
  Preview preview;
  preview.building = building;
  preview.sets = &sets;
  preview.civId = civId;
  return preview;
}

void LogPreview(const char* unit, const Preview& preview, const char* database, const char* world) {
  if (world != g_logWorld) {
    g_loggedSocket = -1;
    g_logWorld = world;
  }
  const std::int32_t socketId = Field<std::int32_t>(unit, 0x10);
  if (socketId == g_loggedSocket) {
    return;
  }
  g_loggedSocket = socketId;
  const char* entries = Field<const char*>(preview.building, 0xE8);
  const std::int32_t count = Field<std::int32_t>(preview.building, 0xEC);
  int units = 0;
  int techs = 0;
  for (std::int32_t i = 0; entries != nullptr && i < count; ++i) {
    const auto* entry = reinterpret_cast<const std::uint8_t*>(entries + 6 * i);
    if (Shown(entry, *preview.sets, database)) {
      ++(entry[2] == 0 ? units : techs);
    }
  }
  const char* civ = Field<const char* const*>(database, 0x24)[preview.civId];
  const char* civName = civ == nullptr ? nullptr : Field<const char*>(civ, 0x04);
  const char* socketName = Field<const char*>(Field<const char*>(unit, 0x5C), 0x10);
  uhc::Log(L"nativePreview: socket %d (%hs, %hs): %d unit(s) and %d tech(s) of %hs, read-only", socketId,
           socketName == nullptr ? "?" : socketName, civName == nullptr ? "?" : civName, units, techs,
           g_buildingName.c_str());
}

}  // namespace

extern "C" {

// From the two chooser hooks: true for a unit that gets a preview, so the chooser treats it as any
// other unit and shows the command panel. The chooser runs hundreds of times a second while a socket
// is selected, so the answer is kept for one simulation step ([world+F8h]) of one unit.
bool __stdcall UhcNpChooserPreview(const char* unit) {
  static const char* cachedUnit = nullptr;
  static std::int32_t cachedId = -1;
  static std::uint32_t cachedStep = 0;
  static const char* cachedWorld = nullptr;
  static bool cached = false;
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (unit == nullptr || world == nullptr) {
    return false;
  }
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (unit != cachedUnit || id != cachedId || step != cachedStep || world != cachedWorld) {
    cached = PreviewOf(unit).building != nullptr;
    cachedUnit = unit;
    cachedId = id;
    cachedStep = step;
    cachedWorld = world;
  }
  return cached;
}

// From the gate hook, on every refresh that reaches it. Returns the player the refresh compares with
// the local one: the selection's, or the local player's for a socket that gets a preview.
std::int32_t __stdcall UhcNpGate(const char* selection) {
  g_uhcNpActive = 0;
  g_current = nullptr;
  const std::int32_t owner = Field<std::int32_t>(selection, 0x0C);
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  if (game == nullptr || Field<std::int32_t>(selection, 0x14) != 1 || owner == Field<std::int32_t>(game, 0x3C0)) {
    return owner;
  }
  const char* world = Field<const char*>(game, 0x13C);
  const char* unit = UnitById(world, Field<const std::int32_t*>(selection, 0x10)[0]);
  const Preview preview = PreviewOf(unit);
  if (preview.building == nullptr) {
    return owner;
  }
  g_uhcNpEntries = preview.building + 0xE8;
  g_current = preview.sets;
  g_uhcNpActive = 1;
  if (g_log) {
    LogPreview(unit, preview, Field<const char*>(game, 0x140), world);
  }
  return Field<std::int32_t>(game, 0x3C0);
}

// From the collection hook in a preview: true to show this entry of the building.
bool __stdcall UhcNpTakeEntry(const std::uint8_t* entry) {
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  return g_current != nullptr && database != nullptr && Shown(entry, *g_current, database);
}

}  // extern "C"

namespace uhc {

Outcome ApplyNativePreview(const Config& config) {
  const Config::Args* args = config.First("nativePreview");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool named = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "tagged") == 0) {
      g_tagged = true;
    } else if (!named) {
      g_buildingName = arg;
      named = true;
    } else {
      Log(L"nativePreview: unexpected argument %hs (expected: [tagged] [log] [BuildingProto]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("nativePreview",
                 {&sites::kNpSocketPanel, &sites::kNpSocketPanelSkip, &sites::kNpSubCiv, &sites::kNpSubCivSkip,
                  &sites::kNpGate, &sites::kNpProto, &sites::kNpCollect, &sites::kNpCollectAppend,
                  &sites::kNpCollectSkip, &sites::kNpTechLayout, &sites::kNpTechBuild, &sites::kNpLayoutNext,
                  &sites::kNpTechNoPrereq, &sites::kNpTechPrereqAge, &sites::kNpButton,
                  &sites::kSocketOccupant, &sites::kIsA, &sites::kPlayerProtoEntry, &sites::kProtoByName})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType("NativeSocket", &g_nativeSocketType) || !OnDatabaseLoad(&ForgetData) ||
      !AddProtoTagHandler("NativePreview", &ReadTag)) {
    return Outcome::kFailed;
  }
  struct Jump {
    const Site& site;
    void (*hook)();
    std::size_t size;
  };
  const Jump jumps[] = {
      {sites::kNpSocketPanel, &UhcNpSocketPanelHook, 12}, {sites::kNpSubCiv, &UhcNpSubCivHook, 7},
      {sites::kNpGate, &UhcNpGateHook, 9},                {sites::kNpProto, &UhcNpProtoHook, 9},
      {sites::kNpCollect, &UhcNpCollectHook, 6},          {sites::kNpTechLayout, &UhcNpTechLayoutHook, 7},
      {sites::kNpButton, &UhcNpButtonHook, 7},
  };
  for (const Jump& jump : jumps) {
    if (!WriteJmp(jump.site.va, reinterpret_cast<const void*>(jump.hook), jump.size)) {
      return Outcome::kFailed;
    }
  }
  Log(L"nativePreview: an empty native socket%ls shows the panel of %hs for its native, read-only%ls",
      g_tagged ? L" with <NativePreview/>" : L"", g_buildingName.c_str(), g_log ? L", previews logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
