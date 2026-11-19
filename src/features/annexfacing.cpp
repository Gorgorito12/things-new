// annexFacing: an annex faces the building it belongs to, in steps of 90 degrees, and falls with it.
//
//   <AnnexOf>Barracks</AnnexOf>     a unit type or a proto, in the annex's proto; repeatable, and a unit of any of
//                                   them can be the parent
//   <AnnexRange>12</AnnexRange>     metres from the parent's footprint to the annex's centre, default 12
//
// The build command (type 3) carries the forward direction of the placed building to every machine; its executor
// computes the right vector from it at 0x7D7CF1, tests the placement with both (PLACE, 0x7D7EC7) and creates the
// foundation with it (0x7D80CF). For a tagged proto the hook at 0x7D7CF1 replaces that forward, before all three: the
// parent is the nearest unit of the command (its builders) of the type, of the same player, in range, or else the
// nearest such unit of the player in range; the forward becomes the axis of the parent (its forward, its right, or
// their opposites) that points most toward the parent. So the annex faces the parent and lines up with it, whatever
// the parent's own angle. Every machine runs the same command on the same state, so all get the same forward.
//
// The placement ghost turns the same way before the click (the hook at 0x96E4E7, before the ghost's placement test
// in 0x96E062): only the local player's view and its green or red test change, never the game.
//
// The AI chooses a spot with the world's axes, in two tests: the scan of candidate spots (the hook at 0x87DB9F,
// before its PLACE at 0x87DBA5) and a build plan's own test FUN_0073D62B (the hook at 0x73D7D2, before PLACE at
// 0x73D7E3), whose forward the plan's build command carries. Both face the annex by the same rule, writing only the
// caller's forward and right, so the scan keeps only spots where the turned annex fits. They run where the AI runs;
// the executor still turns the annex on every machine.
//
// The link: the creation call is wrapped, and the new unit's ID is kept with its parent's (by unit ID, the same on
// every machine). When a unit dies (the shared death observer, AddDeathObserver) or a trigger's Destroy removes it
// (AddDestroyObserver: trUnitDestroy's call 0x9828E7 of the unit removal 0x4726B2, which never reaches the kill
// queue), every annex linked to it, or found by the same rule when no link was kept (a saved game: links are not
// saved), is killed at once through the kill queue, as a trigger's kill. The rule for an annex without a link: the
// units of its parent type, of its player, in range, that it faces (its forward is one of their axes and points to
// their side); the nearest of them.
#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>

#include "../deathobservers.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
void UhcAnnexForwardHook();  // hooks/annexfacing_hooks.asm
void UhcAnnexGhostHook();
void UhcAnnexAiPlaceHook();
void UhcAnnexAiScanHook();
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kUiGlobal = 0x00C67300;  // the UI object of the placement ghost
constexpr std::uint32_t kCreateCall = 0x007D80CF;
constexpr float kDefaultRange = 12.0f;
constexpr float kAligned = 0.999f;  // |cos| between an annex's forward and a parent's axis
constexpr int kMaxLogLines = 200;

struct IdList {  // the engine's dynamic array {data, count, capacity}
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using UnitsNearFn = std::int32_t(__thiscall*)(char* world, const float* point, float radius, char precise, IdList* out);
using UnitByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
using UnitTestFn = bool(__thiscall*)(const char* unit);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using DistanceFn = float(__thiscall*)(const char* unit, const float* point);
using KillAskFn = void(__thiscall*)(char* unit, std::int32_t a, std::int32_t b, std::int32_t c);
using CreateFn = char*(__thiscall*)(char* world, std::int32_t proto, std::int32_t player, const float* position,
                                    const float* forward, std::int32_t a, std::int32_t b, std::int32_t c, std::int32_t d);
using NameBucketFn = std::int32_t(__thiscall*)(const char* table, const char* name);
using NameFindFn = bool(__thiscall*)(const char* table, const char* name, std::int32_t bucket, std::int32_t* id);

const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);
const auto kUnitById = reinterpret_cast<UnitByIdFn>(0x0044CC6D);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kKillAsk = reinterpret_cast<KillAskFn>(0x004B4DC2);
const auto kCreate = reinterpret_cast<CreateFn>(0x00498ACC);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);

struct Annex {
  std::vector<std::string> names;    // the <AnnexOf> lines: any of them is a parent
  std::vector<std::int32_t> types;   // their IDs, once looked up
  bool resolved = false;
  float range = kDefaultRange;
};

struct Pending {  // the command whose forward the hook set, until its unit is created
  const char* command = nullptr;
  std::int32_t parent = -1;
};

std::unordered_map<std::int32_t, Annex> g_protos;  // by proto ID; the load fills it
std::map<std::int32_t, std::int32_t> g_links;      // annex unit ID -> parent unit ID
Pending g_pending;
IdList g_found = {};
const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Game() { return *reinterpret_cast<char* const*>(kGameGlobal); }

char* World() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<char*>(game, 0x13C);
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<UnitTestFn const* const*>(unit))[0xA4 / 4](unit); }

bool IsDead(const char* unit) {  // state bit 11: the kill handler returns at once
  const auto* bits = Field<const std::uint8_t*>(unit, 4);
  return bits != nullptr && Field<std::uint32_t>(unit, 8) > 11 && (bits[1] & 0x08) != 0;
}

float DistanceTo(const char* unit, const float* point) {  // to the footprint of a building
  return (*reinterpret_cast<DistanceFn const* const*>(unit))[0xB8 / 4](unit, point);
}

std::int32_t PlayerOf(const char* unit) {
  const char* owner = Field<const char*>(unit, 0x44);
  return owner == nullptr ? -1 : Field<std::int32_t>(owner, 0);
}

std::int32_t ProtoIdOf(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  return proto == nullptr ? -1 : Field<std::int32_t>(proto, 0x04);
}

void LogLine(const wchar_t* format, ...) {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return;
  }
  ++g_logLines;
  wchar_t text[400];
  va_list args;
  va_start(args, format);
  std::vswprintf(text, sizeof(text) / sizeof(text[0]), format, args);
  va_end(args);
  uhc::Log(L"%ls", text);
}

const wchar_t* NodeText(const char* node) { return *reinterpret_cast<const wchar_t* const*>(node + 0x14); }

bool __cdecl ReadAnnexOf(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  const std::int32_t id = Field<std::int32_t>(proto, 0x04);
  if (text == nullptr || text[0] == L'\0') {
    uhc::Log(L"annexFacing: proto %d: <AnnexOf> names no unit type, ignored", id);
    return true;
  }
  Annex& annex = g_protos[id];
  std::string name;
  for (const wchar_t* c = text; *c != 0; ++c) {
    name.push_back(static_cast<char>(*c));
  }
  annex.names.push_back(name);
  annex.resolved = false;
  if (g_log) {
    uhc::Log(L"annexFacing: proto %d is an annex of %ls", id, text);
  }
  return true;
}

bool __cdecl ReadRange(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  const std::int32_t id = Field<std::int32_t>(proto, 0x04);
  wchar_t* end = nullptr;
  const double value = text == nullptr ? 0.0 : std::wcstod(text, &end);
  if (text == nullptr || end == text || !(value > 0.0) || value > 1000.0) {
    uhc::Log(L"annexFacing: proto %d: <AnnexRange> needs a number above 0, ignored", id);
    return true;
  }
  g_protos[id].range = static_cast<float>(value);
  return true;
}

void NewDatabase(char*) {
  g_protos.clear();
  g_links.clear();
  g_pending = {};
  g_logLines = 0;
}

// Looks the parent types up once; 0 when the annex has one at least, -1 when none of its names is known.
std::int32_t TypeOf(Annex& annex) {
  if (!annex.resolved) {
    const char* game = Game();
    const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
    if (database == nullptr) {
      return -1;
    }
    annex.resolved = true;
    annex.types.clear();
    const char* table = database + 0x190;
    for (const std::string& name : annex.names) {
      std::int32_t id = -1;
      const std::int32_t bucket = kNameBucket(table, name.c_str());
      if (kNameFind(table, name.c_str(), bucket, &id)) {
        annex.types.push_back(id);
      } else {
        uhc::Log(L"annexFacing: <AnnexOf>%hs names no unit type or proto; ignored", name.c_str());
      }
    }
  }
  return annex.types.empty() ? -1 : 0;
}

bool IsParentProto(const char* proto, const Annex& annex) {
  for (const std::int32_t type : annex.types) {
    if (kProtoIsType(proto, type)) {
      return true;
    }
  }
  return false;
}

std::string NamesOf(const Annex& annex) {
  std::string text;
  for (const std::string& name : annex.names) {
    text += (text.empty() ? "" : "/") + name;
  }
  return text;
}

const Annex* AnnexOf(std::int32_t protoId) {
  const auto found = g_protos.find(protoId);
  return found == g_protos.end() ? nullptr : &found->second;
}

// A unit that can be the parent of `annex`, owned by `player`.
bool CanBeParent(const char* unit, const Annex& annex, std::int32_t player) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  return proto != nullptr && PlayerOf(unit) == player && IsParentProto(proto, annex) && IsAlive(unit) && !IsDead(unit);
}

// The nearest parent around `point`, by distance to its footprint, then by the lower unit ID.
std::int32_t NearestParent(char* world, const float* point, const Annex& annex, std::int32_t player, float range,
                           std::int32_t skip) {
  g_found.count = 0;
  kUnitsNear(world, point, range, 1, &g_found);
  std::int32_t best = -1;
  float bestDistance = 0.0f;
  for (std::int32_t i = 0; i < g_found.count; ++i) {
    const std::int32_t id = g_found.data[i];
    const char* unit = kUnitById(world, id);
    if (id == skip || !CanBeParent(unit, annex, player)) {
      continue;
    }
    const float distance = DistanceTo(unit, point);
    if (distance <= range && (best < 0 || distance < bestDistance || (distance == bestDistance && id < best))) {
      best = id;
      bestDistance = distance;
    }
  }
  return best;
}

// The parent's axis (forward, right or their opposites, in x and z) that points most from `point` to it.
bool FacingAxis(const char* parent, const float* point, float* x, float* z) {
  const float dx = Field<float>(parent, 0x14) - point[0];
  const float dz = Field<float>(parent, 0x1C) - point[2];
  const float axes[2][2] = {{Field<float>(parent, 0x20), Field<float>(parent, 0x28)},
                            {Field<float>(parent, 0x38), Field<float>(parent, 0x40)}};
  float best = -1.0e30f;
  for (const auto& axis : axes) {
    const float length = std::sqrt(axis[0] * axis[0] + axis[1] * axis[1]);
    if (!(length > 1.0e-4f)) {
      continue;
    }
    for (const float sign : {1.0f, -1.0f}) {
      const float ax = sign * axis[0] / length;
      const float az = sign * axis[1] / length;
      const float dot = ax * dx + az * dz;
      if (dot > best) {
        best = dot;
        *x = ax;
        *z = az;
      }
    }
  }
  return best > -1.0e30f && (dx != 0.0f || dz != 0.0f);
}

// The rule for an annex with no kept link: the parents in range it faces, the nearest.
std::int32_t ParentByRule(char* world, const char* annexUnit, const Annex& annex) {
  const auto* point = reinterpret_cast<const float*>(annexUnit + 0x14);
  const float fx = Field<float>(annexUnit, 0x20);
  const float fz = Field<float>(annexUnit, 0x28);
  const std::int32_t player = PlayerOf(annexUnit);
  const std::int32_t self = Field<std::int32_t>(annexUnit, 0x10);
  g_found.count = 0;
  kUnitsNear(world, point, annex.range, 1, &g_found);
  std::vector<std::int32_t> ids(g_found.data, g_found.data + g_found.count);
  std::int32_t best = -1;
  float bestDistance = 0.0f;
  for (const std::int32_t id : ids) {
    const char* unit = kUnitById(world, id);
    if (id == self || !CanBeParent(unit, annex, player)) {
      continue;
    }
    const float distance = DistanceTo(unit, point);
    const float px = Field<float>(unit, 0x20);
    const float pz = Field<float>(unit, 0x28);
    const float rx = Field<float>(unit, 0x38);
    const float rz = Field<float>(unit, 0x40);
    const float pl = std::sqrt(px * px + pz * pz);
    const float rl = std::sqrt(rx * rx + rz * rz);
    const float fl = std::sqrt(fx * fx + fz * fz);
    if (!(pl > 1.0e-4f) || !(rl > 1.0e-4f) || !(fl > 1.0e-4f)) {
      continue;
    }
    const float alignF = std::fabs(fx * px + fz * pz) / (fl * pl);
    const float alignR = std::fabs(fx * rx + fz * rz) / (fl * rl);
    const float front = fx * (Field<float>(unit, 0x14) - point[0]) + fz * (Field<float>(unit, 0x1C) - point[2]);
    if (distance > annex.range || (alignF < kAligned && alignR < kAligned) || !(front > 0.0f)) {
      continue;
    }
    if (best < 0 || distance < bestDistance || (distance == bestDistance && id < best)) {
      best = id;
      bestDistance = distance;
    }
  }
  return best;
}

// Forget the links of another game: a new world, time back, or steps missing.
void CheckGame(const char* world) {
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  if (world != g_world || now < g_lastTime || step - g_lastStep > 1) {
    g_links.clear();
    g_pending = {};
    g_world = world;
  }
  g_lastTime = now;
  g_lastStep = step;
}

void Tick(char* world, std::int32_t) {
  if (world == World()) {
    CheckGame(world);
  }
}

// The creation call of the build executor: thiscall(world, proto, player, position, forward, 0, -1, 0, -1), ret 20h.
char* __fastcall Create(char* world, void*, std::int32_t proto, std::int32_t player, const float* position,
                        const float* forward, std::int32_t a, std::int32_t b, std::int32_t c, std::int32_t d) {
  char* unit = kCreate(world, proto, player, position, forward, a, b, c, d);
  if (g_pending.command != nullptr && forward == reinterpret_cast<const float*>(g_pending.command + 0xA8)) {
    if (unit != nullptr) {
      g_links[Field<std::int32_t>(unit, 0x10)] = g_pending.parent;
      LogLine(L"annexFacing: unit %d (proto %d) is the annex of unit %d", Field<std::int32_t>(unit, 0x10), proto,
              g_pending.parent);
    }
    g_pending = {};
  }
  return unit;
}

void OnDeath(char* unit, std::uint32_t, std::uint32_t, std::uint32_t) {
  if (g_protos.empty() || IsDead(unit)) {
    return;
  }
  char* world = World();
  if (world == nullptr) {
    return;
  }
  CheckGame(world);
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  g_links.erase(id);  // an annex that dies
  const char* proto = Field<const char*>(unit, 0x5C);
  if (proto == nullptr) {
    return;
  }
  const std::int32_t player = PlayerOf(unit);
  // The annexes this unit can be the parent of: every tagged proto whose type it is.
  float reach = 0.0f;
  for (auto& [protoId, annex] : g_protos) {
    if (TypeOf(annex) >= 0 && IsParentProto(proto, annex) && annex.range > reach) {
      reach = annex.range;
    }
  }
  if (!(reach > 0.0f)) {
    return;
  }
  // Annexes stand within their range of the parent's footprint: search that far beyond its obstruction.
  const float radius = reach + 2.0f * std::fmax(Field<float>(proto, 0x88), Field<float>(proto, 0x8C)) + 8.0f;
  const auto* point = reinterpret_cast<const float*>(unit + 0x14);
  g_found.count = 0;
  kUnitsNear(world, point, radius, 0, &g_found);
  std::vector<std::int32_t> near(g_found.data, g_found.data + g_found.count);
  std::vector<char*> doomed;
  for (const std::int32_t annexId : near) {
    char* annexUnit = kUnitById(world, annexId);
    if (annexUnit == nullptr || annexId == id || PlayerOf(annexUnit) != player || !IsAlive(annexUnit) ||
        IsDead(annexUnit)) {
      continue;
    }
    const auto tagged = g_protos.find(ProtoIdOf(annexUnit));
    if (tagged == g_protos.end()) {
      continue;
    }
    if (TypeOf(tagged->second) < 0 || !IsParentProto(proto, tagged->second)) {
      continue;
    }
    const auto link = g_links.find(annexId);
    const std::int32_t parent = link != g_links.end() ? link->second : ParentByRule(world, annexUnit, tagged->second);
    if (parent == id) {
      doomed.push_back(annexUnit);
      LogLine(L"annexFacing: unit %d died: its annex %d falls with it (%ls)", id, annexId,
              link != g_links.end() ? L"linked at placement" : L"found by the rule");
    }
  }
  for (char* annexUnit : doomed) {
    g_links.erase(Field<std::int32_t>(annexUnit, 0x10));
    kKillAsk(annexUnit, 0, 0, 0);
  }
}

}  // namespace

extern "C" {

// From the hook at 0x7D7CF1: the build command's executor, before it computes the right vector from the forward.
void __stdcall UhcAnnexForward(char* command, const char* proto, const char* player) {
  if (g_protos.empty() || command == nullptr || proto == nullptr || player == nullptr) {
    return;
  }
  const std::int32_t protoId = Field<std::int32_t>(proto, 0x04);
  const auto tagged = g_protos.find(protoId);
  if (tagged == g_protos.end()) {
    return;
  }
  char* world = World();
  const std::int32_t type = TypeOf(tagged->second);
  if (world == nullptr || type < 0) {
    return;
  }
  CheckGame(world);
  const std::int32_t playerId = Field<std::int32_t>(player, 0);
  const auto* point = reinterpret_cast<const float*>(command + 0x90);
  auto* forward = reinterpret_cast<float*>(command + 0xA8);
  const auto* ids = Field<const std::int32_t*>(command, 0x40);
  const std::int32_t count = Field<std::int32_t>(command, 0x44);
  std::int32_t parent = -1;
  float bestDistance = 0.0f;
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    const char* unit = kUnitById(world, ids[i]);
    if (!CanBeParent(unit, tagged->second, playerId)) {
      continue;
    }
    const float distance = DistanceTo(unit, point);
    if (distance <= tagged->second.range &&
        (parent < 0 || distance < bestDistance || (distance == bestDistance && ids[i] < parent))) {
      parent = ids[i];
      bestDistance = distance;
    }
  }
  const bool builder = parent >= 0;
  if (!builder) {
    parent = NearestParent(world, point, tagged->second, playerId, tagged->second.range, -1);
  }
  const char* parentUnit = parent < 0 ? nullptr : kUnitById(world, parent);
  float x = 0.0f;
  float z = 0.0f;
  if (parentUnit == nullptr || !FacingAxis(parentUnit, point, &x, &z)) {
    LogLine(L"annexFacing: proto %d at %.1f, %.1f: no %hs of player %d in %.1f m, stock forward", protoId,
            static_cast<double>(point[0]), static_cast<double>(point[2]), NamesOf(tagged->second).c_str(), playerId,
            static_cast<double>(tagged->second.range));
    return;
  }
  LogLine(L"annexFacing: proto %d at %.1f, %.1f, player %d: faces unit %d (%ls), forward %.3f, %.3f -> %.3f, %.3f",
          protoId, static_cast<double>(point[0]), static_cast<double>(point[2]), playerId, parent,
          builder ? L"its builder" : L"the nearest", static_cast<double>(forward[0]), static_cast<double>(forward[2]),
          static_cast<double>(x), static_cast<double>(z));
  forward[0] = x;
  forward[1] = 0.0f;
  forward[2] = z;
  g_pending = {command, parent};
}

// From the hook at 0x96E4E7: the placement ghost's update, before its placement test. ESI = the ghost's visual, whose
// axes start at +4: position, forward +10h, up +1Ch, right +28h; +7Dh marks them changed. The local view only.
void __stdcall UhcAnnexGhost(char* visual) {
  const char* ui = *reinterpret_cast<char* const*>(kUiGlobal);
  if (g_protos.empty() || ui == nullptr || visual == nullptr || Field<char*>(ui, 0x200) != visual) {
    return;
  }
  const auto tagged = g_protos.find(Field<std::int32_t>(ui, 0x1FC));
  const char* game = Game();
  char* world = World();
  if (tagged == g_protos.end() || game == nullptr || world == nullptr) {
    return;
  }
  const std::int32_t type = TypeOf(tagged->second);
  if (type < 0) {
    return;
  }
  const auto* point = reinterpret_cast<const float*>(visual + 4);
  const std::int32_t parent =
      NearestParent(world, point, tagged->second, Field<std::int32_t>(game, 0x3C0), tagged->second.range, -1);
  const char* parentUnit = parent < 0 ? nullptr : kUnitById(world, parent);
  float x = 0.0f;
  float z = 0.0f;
  if (parentUnit == nullptr || !FacingAxis(parentUnit, point, &x, &z)) {
    return;
  }
  auto* forward = reinterpret_cast<float*>(visual + 0x10);
  const auto* up = reinterpret_cast<const float*>(visual + 0x1C);
  auto* right = reinterpret_cast<float*>(visual + 0x28);
  forward[0] = x;
  forward[1] = 0.0f;
  forward[2] = z;
  right[0] = up[1] * z - up[2] * 0.0f;  // up x forward, as the executor's 0x423792 does with the world's up
  right[1] = up[2] * x - up[0] * z;
  right[2] = up[0] * 0.0f - up[1] * x;
  visual[0x7D] = 1;
}

// From the hook at 0x73D7D2: an AI build plan's placement test (FUN_0073D62B), before PLACE at 0x73D7E3 with the
// plan's position `[plan+50h]`, the proto `[plan+ACh]` and the player. The test and the build command the plan sends
// after it (0x73DA17, from the same locals) then use the faced axes, so the plan keeps only spots where the turned
// annex fits, which the executor's own turn then accepts. The plan runs on the machine that hosts the AI; the
// executor turns the annex the same way on every machine whatever forward the command carries.
// Faces `forward` and `right` (the caller's buffers) for a tagged proto at `point`; false when it changed nothing.
bool FaceForPlacement(float* forward, float* right, const float* point, std::int32_t protoId, std::int32_t player,
                      std::int32_t* parentOut) {
  if (g_protos.empty() || forward == nullptr || right == nullptr || point == nullptr) {
    return false;
  }
  const auto inImage = [](const void* p) {
    const auto a = reinterpret_cast<std::uintptr_t>(p);
    return a >= 0x00400000 && a < 0x00F22000;
  };
  const auto tagged = g_protos.find(protoId);
  char* world = World();
  if (tagged == g_protos.end() || world == nullptr || TypeOf(tagged->second) < 0 || inImage(forward) || inImage(right)) {
    return false;
  }
  const std::int32_t parent = NearestParent(world, point, tagged->second, player, tagged->second.range, -1);
  const char* parentUnit = parent < 0 ? nullptr : kUnitById(world, parent);
  float x = 0.0f;
  float z = 0.0f;
  if (parentUnit == nullptr || !FacingAxis(parentUnit, point, &x, &z)) {
    return false;
  }
  forward[0] = x;
  forward[1] = 0.0f;
  forward[2] = z;
  right[0] = z;  // the world's up x forward, as the executor's 0x423792
  right[1] = 0.0f;
  right[2] = -x;
  *parentOut = parent;
  return true;
}

void __stdcall UhcAnnexAiPlace(float* forward, float* right, const float* point, std::int32_t protoId,
                               std::int32_t player) {
  std::int32_t parent = -1;
  static float lastX = -1.0f;
  static float lastZ = -1.0f;
  if (FaceForPlacement(forward, right, point, protoId, player, &parent) && (point[0] != lastX || point[2] != lastZ)) {
    lastX = point[0];
    lastZ = point[2];
    LogLine(L"annexFacing: AI plan, player %d, proto %d at %.1f, %.1f: tested facing unit %d, forward %.3f, %.3f", player,
            protoId, static_cast<double>(point[0]), static_cast<double>(point[2]), parent,
            static_cast<double>(forward[0]), static_cast<double>(forward[2]));
  }
}

// From the hook at 0x87DB9F: the AI's scan of candidate spots for a build plan (PLACE at 0x87DBA5 with the world's
// axes); the spots it keeps are those where the faced annex fits. No log: it runs for every candidate.
void __stdcall UhcAnnexAiScan(float* forward, float* right, const float* point, std::int32_t protoId,
                              std::int32_t player) {
  std::int32_t parent = -1;
  FaceForPlacement(forward, right, point, protoId, player, &parent);
}

}  // extern "C"

namespace uhc {

Outcome ApplyAnnexFacing(const Config& config) {
  const Config::Args* args = config.First("annexFacing");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"annexFacing: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("annexFacing", {&sites::kAnnexForwardSite, &sites::kAnnexCreateCall, &sites::kAnnexGhostSite,
                                 &sites::kUnitCreate, &sites::kUnitsNearPoint, &sites::kUnitById, &sites::kIsA,
                                 &sites::kKillQueueAsk, &sites::kUnitAliveSlot, &sites::kAnnexAiPlaceSite,
                                 &sites::kAnnexAiScanSite}) ||
      !AddProtoTagHandler("AnnexOf", &ReadAnnexOf) || !AddProtoTagHandler("AnnexRange", &ReadRange) ||
      !OnDatabaseLoad(&NewDatabase) || !AddWorldTick(&Tick) || !AddDeathObserver(&OnDeath) ||
      !AddDestroyObserver(&OnDeath) ||
      !WriteJmp(sites::kAnnexAiPlaceSite.va, reinterpret_cast<const void*>(&UhcAnnexAiPlaceHook), 5) ||
      !WriteJmp(sites::kAnnexAiScanSite.va, reinterpret_cast<const void*>(&UhcAnnexAiScanHook), 6) ||
      !WriteJmp(sites::kAnnexForwardSite.va, reinterpret_cast<const void*>(&UhcAnnexForwardHook), 6) ||
      !WriteCall(kCreateCall, reinterpret_cast<const void*>(&Create)) ||
      !WriteJmp(sites::kAnnexGhostSite.va, reinterpret_cast<const void*>(&UhcAnnexGhostHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"annexFacing: the proto tags AnnexOf and AnnexRange are on (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
