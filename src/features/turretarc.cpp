// turretArc <Proto> <aim file> [<Proto> <aim file> ...] [log]: a unit whose attack has a turret turns its gun toward
// what it fires at, on the gun's mount, and keeps its body still while the target is inside the turret's arc; outside
// it, the unit turns as before and the gun comes back to the middle as it does.
//
// The data: the attack action's stock <Turret> tag, which the game parses and never reads (docs/engine-symbols.md,
// "Turrets, facing and the Granny pose"): <Turret tracking="always" maxTurnAnglePerSecond="240">90</Turret>. The
// number is the arc each side of ahead, in degrees ([action+94h]); maxTurnAnglePerSecond, the gun's turn rate on
// screen ([action+98h], radians a second); tracking="always" (bit 25 of the action's flags) is required. The aim file
// (tools: aoe3-blender-tools make_gun_camel.py) names the gun's yaw bone and the model's turret bone, gives the turret's
// pivot in the model's space, and holds the gunner's bones at every yaw for the clips he works the gun in.
//
// The simulation, from game state only (the same on every machine, nothing kept between updates):
// - the facing: the head of FUN_0048AA9F (the unit turns to face a point; the attack update calls it every update):
//   with the turret, a point within the arc of the unit's forward [unit+20h] keeps the body still (the stock function
//   is skipped and returns 1, as it does). The attack never waits for the facing (no tolerance), so it fires as before.
//   An aim file of version 2 gives the gun's rest yaw (where its clips show it, e.g. +90: square to a camel's spine);
//   the arc is then about that yaw, and a point beyond it turns the unit until the point sits at the rest yaw (the
//   stock turn gets the point turned by minus that yaw, while the attack is the unit's current action).
// - the shot's start: FUN_00499422 at 0x4995D5 (every way of placing a shot's start meets there): the start turns about
//   the turret's pivot by the gun's yaw, the angle to the aim point clamped to the arc, so shots leave the turned muzzle.
//
// On screen (grannyhooks.h, after the game samples a model's pose): the gun's yaw bone and the model's turret bone
// (which carries the launch point and the muzzle flash) turn by the shown yaw less the rest yaw (the clips show the rest),
// the shown yaw following the game's yaw at the turn rate and going back to the rest yaw (0 before version 2 of the aim
// file) half a second after the unit last aimed, or as soon as the gun or the gunner plays a clip
// named for a reload, a death or a deploy (the gunner's new magazine comes to where the hopper is at rest, a corpse
// shows the gun at rest, and the gunner holds the reins while the camel lies down or rises); the gunner's bones take
// the aim table's pose for the clip and time the model plays, between the two nearest yaws.
#include <windows.h>

#include <cctype>
#include <cmath>
#include <cstdlib>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../grannyhooks.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
void UhcTurretFaceHook();    // hooks/turretarc_hooks.asm
void UhcTurretLaunchHook();  // hooks/turretarc_hooks.asm
std::int32_t g_uhcTurretOn = 0;
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr std::uint32_t kAttackActionVtable = 0x00B96278;
constexpr float kPi = 3.14159265358979f;
constexpr std::int32_t kAimHoldMs = 500;      // game time a shown yaw is kept after the last aim, then it goes home
constexpr float kDefaultRate = 240.0f;        // degrees a second, when the tag gives none
constexpr int kMaxChain = 16;
constexpr double kSettleSeconds = 0.20;       // a step under way when the gun comes to rest finishes in this time

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

std::int32_t Now(const char* world) { return world == nullptr ? 0 : Field<std::int32_t>(world, 0x108); }

const char* UnitById(const char* world, std::int32_t id) {
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

// ----- the aim files

struct Clip {
  float length = 0.0f;
  int frames = 0;
  std::vector<float> data;  // [frame][yaw][bone][7]: position, rotation (x, y, z, w)
};

struct AimFile {
  std::string proto;
  std::wstring path;
  std::string gunBone, turretBone;
  float pivot[3] = {};
  float muzzle[3] = {};
  float home = 0.0f;        // version 2: the gun's rest yaw, where its clips show it (degrees, the unit's right +)
  std::vector<float> yaws;
  std::vector<std::string> bones;
  std::map<std::string, Clip> clips;
  // optional, after the clips (a gunner on foot): "BAND", the yaw bands in which a foot is in the air (for the log);
  // "SETL", per clip his pose once the step under way has finished, the gun having turned toward a growing yaw [0]
  // or a shrinking one [1]: shown when the gun comes to rest, so no foot is left in the air
  std::vector<std::pair<float, float>> bands;
  std::map<std::string, std::pair<Clip, Clip>> settled;
  // the yaws the aim file covers (degrees): the gun turns no farther than its table goes
  float lowest() const { return yaws.empty() ? 0.0f : yaws.front(); }
  float highest() const { return yaws.empty() ? 0.0f : yaws.back(); }
};

std::vector<AimFile> g_aims;
bool g_log = false;
unsigned g_logLines = 0;
constexpr unsigned kMaxLogLines = 400;

bool ReadAim(AimFile& aim) {
  FILE* f = nullptr;
  if (_wfopen_s(&f, aim.path.c_str(), L"rb") != 0 || f == nullptr) {
    uhc::Log(L"turretArc: cannot open %ls", aim.path.c_str());
    return false;
  }
  std::vector<unsigned char> b;
  unsigned char buf[65536];
  std::size_t n;
  while ((n = std::fread(buf, 1, sizeof buf, f)) > 0) {
    b.insert(b.end(), buf, buf + n);
  }
  std::fclose(f);
  std::size_t at = 0;
  auto need = [&](std::size_t k) { return at + k <= b.size(); };
  auto u32 = [&]() { std::uint32_t v; std::memcpy(&v, &b[at], 4); at += 4; return v; };
  auto f32 = [&]() { float v; std::memcpy(&v, &b[at], 4); at += 4; return v; };
  auto str = [&](std::size_t len) {
    std::string s(reinterpret_cast<const char*>(&b[at]), strnlen(reinterpret_cast<const char*>(&b[at]), len));
    at += len;
    return s;
  };
  if (!need(8 + 64 + 24 + 4) || std::memcmp(b.data(), "UHCA", 4) != 0) {
    uhc::Log(L"turretArc: %ls is not an aim file", aim.path.c_str());
    return false;
  }
  at = 4;
  const std::uint32_t version = u32();
  if (version != 1 && version != 2) {
    uhc::Log(L"turretArc: %ls: unknown version", aim.path.c_str());
    return false;
  }
  aim.gunBone = str(32);
  aim.turretBone = str(32);
  for (float& p : aim.pivot) {
    p = f32();
  }
  for (float& p : aim.muzzle) {
    p = f32();
  }
  if (version >= 2) {
    if (!need(4)) {
      return false;
    }
    aim.home = f32();
  }
  const std::uint32_t nyaw = u32();
  if (nyaw < 2 || nyaw > 64 || !need(4 * nyaw + 4)) {
    return false;
  }
  for (std::uint32_t i = 0; i < nyaw; ++i) {
    aim.yaws.push_back(f32());
  }
  const std::uint32_t nbones = u32();
  if (nbones > 256 || !need(32 * nbones + 4)) {
    return false;
  }
  for (std::uint32_t i = 0; i < nbones; ++i) {
    aim.bones.push_back(str(32));
  }
  auto readClip = [&](Clip& clip) {
    clip.length = f32();
    clip.frames = static_cast<int>(u32());
    const std::size_t floats = static_cast<std::size_t>(clip.frames) * nyaw * nbones * 7;
    if (clip.frames < 2 || clip.frames > 100000 || !need(floats * 4)) {
      return false;
    }
    clip.data.resize(floats);
    std::memcpy(clip.data.data(), &b[at], floats * 4);
    at += floats * 4;
    return true;
  };
  auto copyFrames = [&](Clip& to, const Clip& like) {
    const std::size_t floats = static_cast<std::size_t>(like.frames) * nyaw * nbones * 7;
    if (!need(floats * 4)) {
      return false;
    }
    to.length = like.length;
    to.frames = like.frames;
    to.data.resize(floats);
    std::memcpy(to.data.data(), &b[at], floats * 4);
    at += floats * 4;
    return true;
  };
  if (!need(4)) {
    return false;
  }
  const std::uint32_t nclips = u32();
  for (std::uint32_t c = 0; c < nclips; ++c) {
    if (!need(64 + 8)) {
      return false;
    }
    std::string name = str(64);
    Clip clip;
    if (!readClip(clip)) {
      return false;
    }
    aim.clips[name] = std::move(clip);
  }
  // the optional sections
  while (need(8)) {
    const bool band = std::memcmp(&b[at], "BAND", 4) == 0, setl = std::memcmp(&b[at], "SETL", 4) == 0;
    if (!band && !setl) {
      break;
    }
    at += 4;
    const std::uint32_t count = u32();
    if (count > 256) {
      return false;
    }
    for (std::uint32_t i = 0; i < count; ++i) {
      if (band) {
        if (!need(8)) {
          return false;
        }
        const float lo = f32();
        aim.bands.emplace_back(lo, f32());
        continue;
      }
      if (!need(64 + 8)) {
        return false;
      }
      std::string name = str(64);
      std::pair<Clip, Clip> both;
      if (!readClip(both.first) || !copyFrames(both.second, both.first)) {
        return false;
      }
      aim.settled[name] = std::move(both);
    }
  }
  return true;
}

// ----- the units' protos, their turret and the angles

std::unordered_map<std::int32_t, int> g_protoAim;  // proto ID -> index in g_aims, -1 none

void ResetForDataLoad(char*) { g_protoAim.clear(); }

int AimOf(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (proto == nullptr) {
    return -1;
  }
  const std::int32_t id = Field<std::int32_t>(proto, 0x04);
  const auto found = g_protoAim.find(id);
  if (found != g_protoAim.end()) {
    return found->second;
  }
  const char* name = Field<const char*>(proto, 0x10);
  int index = -1;
  for (std::size_t i = 0; name != nullptr && i < g_aims.size(); ++i) {
    if (_stricmp(g_aims[i].proto.c_str(), name) == 0) {
      index = static_cast<int>(i);
    }
  }
  g_protoAim[id] = index;
  return index;
}

struct Turret {
  const char* unitAction;
  float arc;   // degrees each side of the rest yaw
  float rate;  // degrees a second
};

float HomeOf(int aim) { return aim >= 0 && aim < static_cast<int>(g_aims.size()) ? g_aims[aim].home : 0.0f; }

// The action, or one of its children [action+40h] (the same list layout as the manager's), is `ua`.
bool Holds(const char* action, const char* ua, int depth) {
  if (action == nullptr || depth > 4) {
    return false;
  }
  if (action == ua) {
    return true;
  }
  const char* list = action + 0x40;
  const std::int32_t count = Field<std::int32_t>(list, 0);
  const char* const* actions = Field<const char* const*>(list, 8);
  for (std::int32_t i = 0; actions != nullptr && i < count && i < 64; ++i) {
    if (Holds(actions[i], ua, depth + 1)) {
      return true;
    }
  }
  return false;
}

// The unit's attack action (an action of its manager's list [[unit+58h]+14h] {count +0, data +8} or their children
// [action+40h], as src/modifiers.h walks them) whose tactics action has the turret (bit 25 and an arc). The list,
// not the current action [manager+24h]: the attack faces its target before it becomes the current action.
const char* FindAttack(const char* list, int depth) {
  if (list == nullptr || depth > 4) {
    return nullptr;
  }
  const std::int32_t count = Field<std::int32_t>(list, 0);
  const char* const* actions = Field<const char* const*>(list, 8);
  for (std::int32_t i = 0; actions != nullptr && i < count && i < 64; ++i) {
    const char* a = actions[i];
    if (a == nullptr) {
      continue;
    }
    if (Field<std::uint32_t>(a, 0) == kAttackActionVtable) {
      return a;
    }
    if (const char* inner = FindAttack(a + 0x40, depth + 1)) {
      return inner;
    }
  }
  return nullptr;
}

bool TurretOf(const char* unit, Turret* out) {
  const char* manager = Field<const char*>(unit, 0x58);
  const char* ua = manager == nullptr ? nullptr : FindAttack(manager + 0x14, 0);
  if (ua == nullptr) {
    return false;
  }
  const char* action = Field<const char*>(ua, 0x04);
  if (action == nullptr || Field<std::uint32_t>(action, 0x68) <= 25 ||
      (Field<const std::uint8_t*>(action, 0x64)[3] & 2) == 0) {
    return false;
  }
  const std::int32_t arc = Field<std::int32_t>(action, 0x94);
  if (arc <= 0) {
    return false;
  }
  const float rate = Field<float>(action, 0x98) * 180.0f / kPi;
  *out = Turret{ua, static_cast<float>(arc > 180 ? 180 : arc), rate > 0.0f ? rate : kDefaultRate};
  return true;
}

// The angle from the unit's forward to the point, about its up, degrees: positive toward its right [unit+38h].
float AngleTo(const char* unit, const float* point) {
  const float* pos = reinterpret_cast<const float*>(unit + 0x14);
  const float* fwd = reinterpret_cast<const float*>(unit + 0x20);
  const float* right = reinterpret_cast<const float*>(unit + 0x38);
  const float dx = point[0] - pos[0], dy = point[1] - pos[1], dz = point[2] - pos[2];
  const float f = dx * fwd[0] + dy * fwd[1] + dz * fwd[2];
  const float r = dx * right[0] + dy * right[1] + dz * right[2];
  return std::atan2(r, f) * 180.0f / kPi;
}

float Clamp(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }

// An angle brought into (-180, 180].
float Wrap(float a) {
  while (a > 180.0f) {
    a -= 360.0f;
  }
  while (a <= -180.0f) {
    a += 360.0f;
  }
  return a;
}

// The gun's reach: the tactics' arc each side of the rest yaw (the aim file's home, 0 before version 2), no farther
// than the aim file's table goes (a table from -30 to +90 gives -30..+90 under an arc of 90; one of +30..+150 with
// its rest at +90 gives +30..+150 under 60; a table of -90..+90 keeps the arc symmetric, as before).
void ArcOf(const Turret& turret, int aim, float* lo, float* hi) {
  const float home = HomeOf(aim);
  *lo = home - turret.arc;
  *hi = home + turret.arc;
  if (aim >= 0 && aim < static_cast<int>(g_aims.size())) {
    *lo = std::fmax(*lo, g_aims[aim].lowest());
    *hi = std::fmin(*hi, g_aims[aim].highest());
  }
}

// The aim's yaw for an angle to the target: inside the arc, measured about the rest yaw so an arc that does not hold
// ahead is not cut where the angle wraps.
float AimYaw(float angle, float home, float lo, float hi) {
  return home + Clamp(Wrap(angle - home), lo - home, hi - home);
}

// The model's +z is the unit's forward and +x its right [unit+38h] (seen in game: a turn of +60 about the bones' y
// took the gun to the unit's right), so the aim files' yaw (a turn taking +z toward +x) is the game angle.
constexpr float kModelSense = 1.0f;

// ----- what the screen shows, per unit

struct Shown {
  std::int32_t unitId = -1;
  float gameYaw = 0.0f;        // the last aim (game angle, clamped)
  std::int32_t aimedAt = -1;   // game time of the last aim
  float rate = kDefaultRate;
  float shownYaw = 0.0f;       // what the bones show (game angle)
  LARGE_INTEGER lastReal{};
  int aim = -1;
  bool lastInside = false;     // for the log
  bool home = false;           // the gun or the gunner plays a reload or a death: the gun goes home
  float lastLogged = 0.0f;
  int dir = 0;                 // the way the gun last turned on screen: +1 the yaw growing, -1 shrinking
  float settle = 0.0f;         // 0..1: the gunner's step under way finished (the gun at rest), else stepping
  bool settleLogged = false;   // for the log: this rest's settling already told
};

std::unordered_map<std::int32_t, Shown> g_shown;  // unit ID -> its state

enum class Role { kBody, kGun, kGunner };
struct Instance {
  std::int32_t unitId;
  Role role;
};
std::unordered_map<const void*, Instance> g_instances;  // Granny model instance -> its unit and part

// ----- Granny, through granny2.dll's exports

struct GrannyTransform {
  std::uint32_t flags;
  float position[3];
  float orientation[4];
  float scaleShear[9];
};

using GetSourceModelFn = const char*(__stdcall*)(const void* instance);
using FindBoneFn = int(__stdcall*)(const void* skeleton, const char* name, int* index);
using LocalTransformFn = GrannyTransform*(__stdcall*)(void* pose, int bone);
using ControlsFn = void*(__stdcall*)(const void* instance);
using NextFn = void*(__stdcall*)(void* binding);
using ControlFn = void*(__stdcall*)(void* binding);
using FloatFn = float(__stdcall*)(void* control);
using AnimBindingFn = const char*(__stdcall*)(void* binding);

unsigned g_mapLines = 0;
float g_testYaw = 0.0f;  // "testyaw=<degrees>": every unit served shows this yaw (a check of the bones' sense)
bool g_testYawOn = false;

GetSourceModelFn g_getSourceModel = nullptr;
FindBoneFn g_findBone = nullptr;
LocalTransformFn g_localTransform = nullptr;
ControlsFn g_controlsBegin = nullptr, g_controlsEnd = nullptr;
NextFn g_controlsNext = nullptr;
ControlFn g_controlFromBinding = nullptr;
FloatFn g_rawClock = nullptr, g_weight = nullptr;
AnimBindingFn g_animBinding = nullptr;

bool LoadGranny() {
  const char* who = "turretArc";
  g_getSourceModel = reinterpret_cast<GetSourceModelFn>(uhc::GrannyExport("_GrannyGetSourceModel@4", who));
  g_findBone = reinterpret_cast<FindBoneFn>(uhc::GrannyExport("_GrannyFindBoneByName@12", who));
  g_localTransform = reinterpret_cast<LocalTransformFn>(uhc::GrannyExport("_GrannyGetLocalPoseTransform@8", who));
  g_controlsBegin = reinterpret_cast<ControlsFn>(uhc::GrannyExport("_GrannyModelControlsBegin@4", who));
  g_controlsEnd = reinterpret_cast<ControlsFn>(uhc::GrannyExport("_GrannyModelControlsEnd@4", who));
  g_controlsNext = reinterpret_cast<NextFn>(uhc::GrannyExport("_GrannyModelControlsNext@4", who));
  g_controlFromBinding = reinterpret_cast<ControlFn>(uhc::GrannyExport("_GrannyGetControlFromBinding@4", who));
  g_rawClock = reinterpret_cast<FloatFn>(uhc::GrannyExport("_GrannyGetControlRawLocalClock@4", who));
  g_weight = reinterpret_cast<FloatFn>(uhc::GrannyExport("_GrannyGetControlEffectiveWeight@4", who));
  g_animBinding =
      reinterpret_cast<AnimBindingFn>(uhc::GrannyExport("_GrannyGetAnimationBindingFromControlBinding@4", who));
  return g_getSourceModel && g_findBone && g_localTransform && g_controlsBegin && g_controlsEnd && g_controlsNext &&
         g_controlFromBinding && g_rawClock && g_weight && g_animBinding;
}

// A Granny model: +0 its name, +4 its skeleton.
const void* SkeletonOf(const void* instance) {
  const char* model = g_getSourceModel(instance);
  return model == nullptr ? nullptr : Field<const void*>(model, 4);
}

// A Granny skeleton: +0 its name, +4 the bone count, +8 the bones (156 B each, +0 the name; read in game).
constexpr std::uint32_t kGrannyBoneSize = 156;

int BoneIndex(const void* skeleton, const std::string& name) {
  int index = -1;
  if (skeleton == nullptr || !g_findBone(skeleton, name.c_str(), &index)) {
    return -1;
  }
  // GrannyFindBoneByName also answers for a name it does not hold exactly: check the bone's own name
  const std::int32_t count = Field<std::int32_t>(skeleton, 4);
  const char* bones = Field<const char*>(skeleton, 8);
  if (index < 0 || index >= count || bones == nullptr) {
    return -1;
  }
  const char* own = Field<const char*>(bones, static_cast<std::uint32_t>(index) * kGrannyBoneSize);
  return own != nullptr && _stricmp(own, name.c_str()) == 0 ? index : -1;
}

// Bone indices per skeleton, cached: [aim][skeleton] -> gun bone, turret bone, the gunner's bones.
struct BoneMap {
  int gun = -1;
  int turret = -1;
  std::vector<int> gunner;
};
std::map<std::pair<int, const void*>, BoneMap> g_boneMaps;

const BoneMap& BonesFor(int aim, const void* skeleton) {
  auto key = std::make_pair(aim, skeleton);
  auto found = g_boneMaps.find(key);
  if (found != g_boneMaps.end()) {
    return found->second;
  }
  BoneMap m;
  const AimFile& a = g_aims[aim];
  m.gun = BoneIndex(skeleton, a.gunBone);
  m.turret = BoneIndex(skeleton, a.turretBone);
  bool all = !a.bones.empty();
  for (const std::string& b : a.bones) {
    m.gunner.push_back(BoneIndex(skeleton, b));
    all = all && m.gunner.back() >= 0;
  }
  if (!all) {
    m.gunner.clear();
  }
  return g_boneMaps.emplace(key, std::move(m)).first->second;
}

// The model instances of a unit's visual [unit+60h] and its attachments (MapVisual).
void MapNode(const char* node, std::int32_t id, int aim, int k);
constexpr std::uint32_t kModelNodeVtable = 0x00B964A0;  // a visual's model part (seen in game for all four)

bool Readable(const void* p, std::size_t size) {
  MEMORY_BASIC_INFORMATION mbi;
  if (p == nullptr || VirtualQuery(p, &mbi, sizeof mbi) == 0 || mbi.State != MEM_COMMIT ||
      (mbi.Protect & (PAGE_READONLY | PAGE_READWRITE | PAGE_WRITECOPY | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE)) ==
          0) {
    return false;
  }
  const char* end = static_cast<const char*>(mbi.BaseAddress) + mbi.RegionSize;
  return static_cast<const char*>(p) + size <= end;
}

// The visual (and each attachment, a visual of the same layout): +1Ch its model part (vtable 0xB964A0, its Granny
// model instance at +24h), +24h its attachments (an array of visuals), +28h their count (seen in game: the body's
// visual holds the gunner and the gun; the gunner's, his hat).
void MapVisual(const char* visual, std::int32_t id, int aim, int depth, int* k) {
  if (visual == nullptr || depth > 3 || !Readable(visual, 0x2C)) {
    return;
  }
  MapNode(Field<const char*>(visual, 0x1C), id, aim, (*k)++);
  const char* const* children = Field<const char* const*>(visual, 0x24);
  const std::int32_t count = Field<std::int32_t>(visual, 0x28);
  if (children == nullptr || count <= 0 || count > kMaxChain || !Readable(children, 4 * count)) {
    return;
  }
  for (std::int32_t i = 0; i < count; ++i) {
    MapVisual(children[i], id, aim, depth + 1, k);
  }
}

void MapInstances(const char* unit, int aim) {
  int k = 0;
  MapVisual(Field<const char*>(unit, 0x60), Field<std::int32_t>(unit, 0x10), aim, 0, &k);
}

void MapNode(const char* node, std::int32_t id, int aim, int k) {
  {
    if (!Readable(node, 0x28) || Field<std::uint32_t>(node, 0) != kModelNodeVtable) {
      return;  // not a model part of the kind seen in game (the editor's visuals): nothing to turn there
    }
    const void* instance = Field<const void*>(node, 0x24);
    const void* skeleton = instance == nullptr ? nullptr : SkeletonOf(instance);
    if (skeleton == nullptr) {
      return;
    }
    const BoneMap& m = BonesFor(aim, skeleton);
    const Role role = m.gun >= 0 ? Role::kGun : m.turret >= 0 ? Role::kBody : Role::kGunner;
    if (m.gun < 0 && m.turret < 0 && m.gunner.empty()) {
      return;
    }
    if (g_log && g_mapLines < 24 && g_instances.find(instance) == g_instances.end()) {
      ++g_mapLines;
      uhc::Log(L"turretArc: unit %d part %d %hs: %ls (gun bone %d, turret bone %d, %u gunner bones)", id, k,
               Field<const char*>(g_getSourceModel(instance), 0),
               role == Role::kGun ? L"the gun" : role == Role::kBody ? L"the body" : L"the gunner", m.gun, m.turret,
               static_cast<unsigned>(m.gunner.size()));
    }
    g_instances[instance] = Instance{id, role};
  }
}

// ----- the bones

void QuatMul(const float* a, const float* b, float* out) {  // (x, y, z, w): a then b in a's frame
  const float x = a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1];
  const float y = a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0];
  const float z = a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3];
  const float w = a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2];
  out[0] = x;
  out[1] = y;
  out[2] = z;
  out[3] = w;
}

// The bone turned about its own y by `degrees`.
void TurnBone(void* pose, int bone, float degrees) {
  GrannyTransform* t = g_localTransform(pose, bone);
  if (t == nullptr) {
    return;
  }
  const float h = degrees * kPi / 360.0f;
  const float q[4] = {0.0f, std::sin(h), 0.0f, std::cos(h)};
  float o[4];
  if ((t->flags & 2) == 0) {
    t->orientation[0] = t->orientation[1] = t->orientation[2] = 0.0f;
    t->orientation[3] = 1.0f;
  }
  QuatMul(t->orientation, q, o);
  std::memcpy(t->orientation, o, sizeof o);
  t->flags |= 2;
}

// The clip the instance shows most and its time in it.
const char* PlayingClip(const void* instance, float* clock) {
  void* end = g_controlsEnd(instance);
  const char* best = nullptr;
  float bestWeight = -1.0f;
  int guard = 0;
  for (void* b = g_controlsBegin(instance); b != nullptr && b != end && guard < 16; b = g_controlsNext(b), ++guard) {
    void* control = g_controlFromBinding(b);
    const char* binding = g_animBinding(b);
    const char* animation = binding == nullptr ? nullptr : Field<const char*>(binding, 0);  // ID.Animation
    const char* name = animation == nullptr ? nullptr : Field<const char*>(animation, 0);
    if (control == nullptr || name == nullptr) {
      continue;
    }
    const float w = g_weight(control);
    if (w > bestWeight) {
      bestWeight = w;
      best = name;
      *clock = g_rawClock(control);
    }
  }
  return best;
}

// A clip in which the gun stays home: its name holds "reload", "death" or "deploy" (and so "undeploy"), any case.
bool IsHomeClip(const char* name) {
  if (name == nullptr) {
    return false;
  }
  std::string s(name);
  for (char& ch : s) {
    ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
  }
  return s.find("reload") != std::string::npos || s.find("death") != std::string::npos ||
         s.find("deploy") != std::string::npos;
}

void PoseGunner(void* pose, int count, const AimFile& aim, const BoneMap& m, const char* clipName, float clock,
                float modelYaw, int dir, float settle) {
  const auto found = aim.clips.find(clipName);
  if (found == aim.clips.end()) {
    return;
  }
  const Clip& c = found->second;
  const Clip* settled = nullptr;  // his feet down at rest (the aim file's SETL), blended in by `settle`
  if (settle > 0.0f && dir != 0) {
    const auto s = aim.settled.find(clipName);
    if (s != aim.settled.end() && s->second.first.frames == c.frames) {
      settled = dir > 0 ? &s->second.first : &s->second.second;
    }
  }
  float t = c.length > 0.0f ? std::fmod(clock, c.length) : 0.0f;
  if (t < 0.0f) {
    t += c.length;
  }
  const float fpos = Clamp(t / c.length * static_cast<float>(c.frames - 1), 0.0f, static_cast<float>(c.frames - 1));
  const int f0 = static_cast<int>(fpos);
  const int f1 = f0 + 1 < c.frames ? f0 + 1 : f0;
  const float wf = fpos - static_cast<float>(f0);
  const int ny = static_cast<int>(aim.yaws.size());
  const float y = Clamp(modelYaw, aim.yaws.front(), aim.yaws.back());
  int y0 = 0;
  while (y0 + 1 < ny - 1 && aim.yaws[y0 + 1] <= y) {
    ++y0;
  }
  const int y1 = y0 + 1;
  const float wy = Clamp((y - aim.yaws[y0]) / (aim.yaws[y1] - aim.yaws[y0]), 0.0f, 1.0f);
  const std::size_t nb = aim.bones.size();
  auto at = [&](const Clip& cl, int f, int yy, std::size_t b) {
    return &cl.data[((static_cast<std::size_t>(f) * ny + yy) * nb + b) * 7];
  };
  const float ws = settled != nullptr ? settle : 0.0f;
  for (std::size_t b = 0; b < nb; ++b) {
    const int bone = m.gunner[b];
    if (bone < 0 || bone >= count) {
      continue;
    }
    const float* s[8] = {at(c, f0, y0, b), at(c, f0, y1, b), at(c, f1, y0, b), at(c, f1, y1, b)};
    float w[8] = {(1 - wf) * (1 - wy), (1 - wf) * wy, wf * (1 - wy), wf * wy};
    int n = 4;
    if (ws > 0.0f) {
      for (int k = 0; k < 4; ++k) {
        s[4 + k] = at(*settled, k < 2 ? f0 : f1, (k & 1) ? y1 : y0, b);
        w[4 + k] = w[k] * ws;
        w[k] *= 1.0f - ws;
      }
      n = 8;
    }
    float p[3] = {}, q[4] = {};
    for (int k = 0; k < n; ++k) {
      const float sign = (s[k][3] * s[0][3] + s[k][4] * s[0][4] + s[k][5] * s[0][5] + s[k][6] * s[0][6]) < 0 ? -1.f : 1.f;
      for (int i = 0; i < 3; ++i) {
        p[i] += w[k] * s[k][i];
      }
      for (int i = 0; i < 4; ++i) {
        q[i] += w[k] * sign * s[k][3 + i];
      }
    }
    const float len = std::sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3]);
    GrannyTransform* tr = g_localTransform(pose, bone);
    if (tr == nullptr || len < 1e-6f) {
      continue;
    }
    std::memcpy(tr->position, p, sizeof p);
    for (int i = 0; i < 4; ++i) {
      tr->orientation[i] = q[i] / len;
    }
    tr->flags |= 3;
  }
}

double Seconds(const LARGE_INTEGER& from, const LARGE_INTEGER& to) {
  static LARGE_INTEGER freq{};
  if (freq.QuadPart == 0) {
    QueryPerformanceFrequency(&freq);
  }
  return static_cast<double>(to.QuadPart - from.QuadPart) / static_cast<double>(freq.QuadPart);
}

unsigned g_poseLines = 0;

void AfterSample(void* instance, int first, int count, void* pose) {
  if (g_instances.empty()) {
    return;
  }
  const auto found = g_instances.find(instance);
  if (found == g_instances.end()) {
    return;
  }
  auto s = g_shown.find(found->second.unitId);
  if (s == g_shown.end() || s->second.aim < 0) {
    return;
  }
  Shown& sh = s->second;
  // the shown yaw follows the aim (or goes home after it) at the turn rate, in real time: display only
  const char* world = World();
  // a reload, a death or a (un)deploy clip brings the gun home whatever the aim: the full magazine comes from the
  // gunner's pocket to where the hopper is at yaw 0, and the dead unit's model shows the gun at rest
  if (found->second.role != Role::kBody) {
    float c = 0.0f;
    sh.home = IsHomeClip(PlayingClip(instance, &c));
  }
  const float rest = HomeOf(sh.aim);
  const float target =
      (!sh.home && sh.aimedAt >= 0 && Now(world) - sh.aimedAt <= kAimHoldMs) ? sh.gameYaw : rest;
  LARGE_INTEGER now;
  QueryPerformanceCounter(&now);
  const double dt = sh.lastReal.QuadPart == 0 ? 0.0 : Seconds(sh.lastReal, now);
  sh.lastReal = now;
  const float step = static_cast<float>(sh.rate * (dt > 0.25 ? 0.25 : dt));
  const float before = sh.shownYaw;
  sh.shownYaw = std::fabs(target - sh.shownYaw) <= step ? target : sh.shownYaw + (target > sh.shownYaw ? step : -step);
  // the gunner's feet: while the gun turns he steps with it (the table at the shown yaw); at rest the step under
  // way finishes in kSettleSeconds (the settled table), his hands staying on the grips
  const float settleStep = static_cast<float>((dt > 0.25 ? 0.25 : dt) / kSettleSeconds);
  if (sh.shownYaw != before) {
    sh.dir = sh.shownYaw > before ? 1 : -1;
    sh.settle = std::fmax(0.0f, sh.settle - settleStep);
    sh.settleLogged = false;
  } else {
    sh.settle = std::fmin(1.0f, sh.settle + settleStep);
    static unsigned settleLines = 0;
    if (g_log && sh.settle >= 1.0f && !sh.settleLogged && settleLines < 60 && sh.aim >= 0) {
      sh.settleLogged = true;
      const float y = kModelSense * sh.shownYaw;
      for (const auto& band : g_aims[sh.aim].bands) {
        if (y > band.first && y < band.second) {
          ++settleLines;
          uhc::Log(L"turretArc: unit %d: the gun rests at %.1f degrees, inside the step band %.0f..%.0f: the gunner's "
                   L"step finishes (settled pose, the gun having turned toward %ls yaw)", sh.unitId,
                   static_cast<double>(y), static_cast<double>(band.first), static_cast<double>(band.second),
                   sh.dir > 0 ? L"a growing" : L"a shrinking");
          break;
        }
      }
    }
  }
  const float modelYaw = kModelSense * (g_testYawOn ? g_testYaw : sh.shownYaw);
  // the clips show the gun (and the camel's turret bone) at the rest yaw: the bones turn by the rest of the way
  const float turn = modelYaw - kModelSense * rest;
  const void* skeleton = SkeletonOf(instance);
  const BoneMap& m = BonesFor(sh.aim, skeleton);
  const int end = first + count;
  switch (found->second.role) {
    case Role::kGun:
      if (m.gun >= first && m.gun < end && turn != 0.0f) {
        TurnBone(pose, m.gun, turn);
      }
      break;
    case Role::kBody:
      if (m.turret >= first && m.turret < end && turn != 0.0f) {
        TurnBone(pose, m.turret, turn);
      }
      break;
    case Role::kGunner: {
      float clock = 0.0f;
      const char* clip = PlayingClip(instance, &clock);
      if (clip != nullptr && !m.gunner.empty()) {
        if (g_log && g_poseLines < 40 && turn != 0.0f) {
          ++g_poseLines;
          uhc::Log(L"turretArc: unit %d gunner clip %hs at %.2f s, yaw %.1f", sh.unitId, clip, clock, modelYaw);
        }
        PoseGunner(pose, end, g_aims[sh.aim], m, clip, clock, modelYaw, sh.dir, sh.settle);
      }
      break;
    }
  }
}

// Each world update: the units the key serves keep their instances mapped (a death or a transform changes them);
// a unit gone, or back home and not aiming for a while, leaves.
void Tick(char* world, std::int32_t) {
  g_instances.clear();
  const std::int32_t now = Now(world);
  for (auto it = g_shown.begin(); it != g_shown.end();) {
    const char* unit = UnitById(world, it->first);
    const bool idle = it->second.aimedAt < 0 || now - it->second.aimedAt > 4 * kAimHoldMs;
    if (unit == nullptr || (idle && it->second.shownYaw == HomeOf(it->second.aim))) {
      it = g_shown.erase(it);
      continue;
    }
    MapInstances(unit, it->second.aim);
    ++it;
  }
  g_uhcTurretOn = g_aims.empty() ? 0 : 1;
}

}  // namespace

extern "C" {

float g_uhcTurretPoint[3] = {};  // the point the stock facing gets instead (return 2), so the target ends at the rest yaw

// From the head of FUN_0048AA9F: 1 keeps the unit's facing (the point is inside its turret's arc); 2 runs the stock
// turn toward g_uhcTurretPoint (an arc about a rest yaw that is not ahead: the unit turns until the point sits at the
// rest yaw); 0 runs it as it was.
std::int32_t __stdcall UhcTurretFace(const char* unit, const float* point) {
  if (unit == nullptr || point == nullptr) {
    return 0;
  }
  const int aim = AimOf(unit);
  if (aim < 0) {
    return 0;
  }
  const char* world = World();
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  Turret turret;
  if (!TurretOf(unit, &turret)) {
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"turretArc: %d ms, unit %d faces a point with no turret attack in its action list: the unit turns",
               Now(world), id);
    }
    return 0;
  }
  const float angle = AngleTo(unit, point);
  const float home = HomeOf(aim);
  float lo, hi;
  ArcOf(turret, aim, &lo, &hi);
  const float rel = Wrap(angle - home);
  const bool inside = rel >= lo - home - 0.5f && rel <= hi - home + 0.5f;  // a target on the arc's edge: the gun
  Shown& sh = g_shown[id];
  if (sh.unitId < 0 || sh.aim != aim) {   // new, or the unit changed type (another aim file)
    sh = Shown{};
    sh.unitId = id;
    sh.aim = aim;
    sh.shownYaw = home;
    MapInstances(unit, aim);
  }
  // beyond an arc about a rest yaw that is not ahead, the unit turns until the point sits at that yaw: the stock turn
  // gets the point turned by minus the rest yaw about the unit (its attack must be the current action
  // [[unit+58h]+24h], so no other caller of the turn is redirected)
  bool redirect = false;
  if (!inside && home != 0.0f) {
    const char* manager = Field<const char*>(unit, 0x58);
    redirect = manager != nullptr && Holds(Field<const char*>(manager, 0x24), turret.unitAction, 0);
    if (redirect) {
      const float* pos = reinterpret_cast<const float*>(unit + 0x14);
      const float* fwd = reinterpret_cast<const float*>(unit + 0x20);
      const float* up = reinterpret_cast<const float*>(unit + 0x2C);
      const float* right = reinterpret_cast<const float*>(unit + 0x38);
      const float d[3] = {point[0] - pos[0], point[1] - pos[1], point[2] - pos[2]};
      const float f = d[0] * fwd[0] + d[1] * fwd[1] + d[2] * fwd[2];
      const float r = d[0] * right[0] + d[1] * right[1] + d[2] * right[2];
      const float u = d[0] * up[0] + d[1] * up[1] + d[2] * up[2];
      const float a = -home * kPi / 180.0f;
      const float nf = f * std::cos(a) - r * std::sin(a);
      const float nr = f * std::sin(a) + r * std::cos(a);
      for (int i = 0; i < 3; ++i) {
        g_uhcTurretPoint[i] = pos[i] + nf * fwd[i] + nr * right[i] + u * up[i];
      }
    }
  }
  const bool logIt = g_log && g_logLines < kMaxLogLines &&
                     (sh.aimedAt < 0 || inside != sh.lastInside || std::fabs(angle - sh.lastLogged) > 5.0f);
  sh.gameYaw = AimYaw(angle, home, lo, hi);
  sh.aimedAt = Now(world);
  sh.rate = turret.rate;
  sh.lastInside = inside;
  if (logIt) {
    ++g_logLines;
    sh.lastLogged = angle;
    uhc::Log(L"turretArc: %d ms, unit %d aims at %.1f degrees (arc %+.0f..%+.0f, rest %+.0f): %ls", Now(world), id,
             static_cast<double>(angle), static_cast<double>(lo), static_cast<double>(hi), static_cast<double>(home),
             inside ? L"the gun turns"
                    : redirect ? L"the unit turns until it sits at the rest yaw"
                               : home != 0.0f ? L"the unit turns (its attack is not the current action yet)"
                                              : L"the unit turns");
  }
  return inside ? 1 : (redirect ? 2 : 0);
}

// From 0x4995D5 in the projectile launch: the shot's start (world) turned about the turret's pivot by the gun's yaw.
void __stdcall UhcTurretLaunch(const char* unitAction, const char* unit, float* start, const float* aimPoint) {
  if (unit == nullptr || start == nullptr || aimPoint == nullptr) {
    return;
  }
  const int aim = AimOf(unit);
  Turret turret;
  if (aim < 0 || !TurretOf(unit, &turret) || turret.unitAction != unitAction) {
    return;
  }
  float lo, hi;
  ArcOf(turret, aim, &lo, &hi);
  const float home = HomeOf(aim);
  const float yaw = AimYaw(AngleTo(unit, aimPoint), home, lo, hi);
  const float* pos = reinterpret_cast<const float*>(unit + 0x14);
  const float* fwd = reinterpret_cast<const float*>(unit + 0x20);
  const float* up = reinterpret_cast<const float*>(unit + 0x2C);
  const float* right = reinterpret_cast<const float*>(unit + 0x38);
  const float* pv = g_aims[aim].pivot;
  // the model's +x is the unit's right (kModelSense), +y its up, +z its forward
  float pivot[3];
  for (int i = 0; i < 3; ++i) {
    pivot[i] = pos[i] + kModelSense * pv[0] * right[i] + pv[1] * up[i] + pv[2] * fwd[i];
  }
  // the muzzle (model space, at the rest yaw) turned about the pivot by the rest of the way: the start of the shot
  const float* mz = g_aims[aim].muzzle;
  const float mf = mz[2] - pv[2];
  const float mr = kModelSense * (mz[0] - pv[0]);
  const float mu = mz[1] - pv[1];
  const float a = (yaw - home) * kPi / 180.0f;
  const float nf = mf * std::cos(a) - mr * std::sin(a);
  const float nr = mf * std::sin(a) + mr * std::cos(a);
  static unsigned launchLines = 0;
  if (g_log && launchLines < 80) {
    ++launchLines;
    const float d[3] = {start[0] - pivot[0], start[1] - pivot[1], start[2] - pivot[2]};
    uhc::Log(L"turretArc: unit %d shot, yaw %.1f: the game's start (forward %.2f, right %.2f, up %.2f) from the "
             L"pivot, the turned muzzle's (%.2f, %.2f, %.2f)", Field<std::int32_t>(unit, 0x10),
             static_cast<double>(yaw), static_cast<double>(d[0] * fwd[0] + d[1] * fwd[1] + d[2] * fwd[2]),
             static_cast<double>(d[0] * right[0] + d[1] * right[1] + d[2] * right[2]),
             static_cast<double>(d[0] * up[0] + d[1] * up[1] + d[2] * up[2]), static_cast<double>(nf),
             static_cast<double>(nr), static_cast<double>(mu));
  }
  for (int i = 0; i < 3; ++i) {
    start[i] = pivot[i] + nf * fwd[i] + nr * right[i] + mu * up[i];
  }
}
}  // extern "C"

namespace uhc {

Outcome ApplyTurretArc(const Config& config) {
  const Config::Args* args = config.First("turretArc");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  wchar_t exe[MAX_PATH];
  GetModuleFileNameW(nullptr, exe, MAX_PATH);
  std::wstring dir(exe);
  dir = dir.substr(0, dir.find_last_of(L"\\/") + 1);
  std::vector<std::string> words;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_strnicmp(arg.c_str(), "testyaw=", 8) == 0) {
      g_testYaw = static_cast<float>(std::atof(arg.c_str() + 8));
      g_testYawOn = true;
    } else {
      words.push_back(arg);
    }
  }
  if (words.empty() || words.size() % 2 != 0) {
    Log(L"turretArc: expected <Proto> <aim file> pairs [log]; feature not applied");
    return Outcome::kFailed;
  }
  for (std::size_t i = 0; i < words.size(); i += 2) {
    AimFile aim;
    aim.proto = words[i];
    wchar_t wide[MAX_PATH] = {};
    MultiByteToWideChar(CP_ACP, 0, words[i + 1].c_str(), -1, wide, MAX_PATH);
    const std::wstring path(wide);
    aim.path = (path.size() > 1 && path[1] == L':') ? path : dir + path;
    if (!ReadAim(aim)) {
      Log(L"turretArc: %ls could not be read; feature not applied", aim.path.c_str());
      return Outcome::kFailed;
    }
    Log(L"turretArc: %hs: %ls (gun bone %hs, turret bone %hs, pivot %.2f %.2f %.2f, %u gunner bones, %u clips, "
        L"yaws %.0f..%.0f, rest %.0f, %u step bands, %u settled clips)",
        aim.proto.c_str(), aim.path.c_str(), aim.gunBone.c_str(), aim.turretBone.c_str(),
        static_cast<double>(aim.pivot[0]), static_cast<double>(aim.pivot[1]), static_cast<double>(aim.pivot[2]),
        static_cast<unsigned>(aim.bones.size()), static_cast<unsigned>(aim.clips.size()),
        static_cast<double>(aim.yaws.front()), static_cast<double>(aim.yaws.back()), static_cast<double>(aim.home),
        static_cast<unsigned>(aim.bands.size()), static_cast<unsigned>(aim.settled.size()));
    g_aims.push_back(std::move(aim));
  }
  if (!LoadGranny()) {
    return Outcome::kFailed;
  }
  if (!VerifyAll("turretArc", {&sites::kTurretFaceHead, &sites::kTurretLaunchStart}) ||
      !OnDatabaseLoad(&ResetForDataLoad) || !AddWorldTick(&Tick) ||
      !AddGrannySampleObserver(&AfterSample, "turretArc")) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kTurretFaceHead.va, reinterpret_cast<const void*>(&UhcTurretFaceHook), 6) ||
      !WriteJmp(sites::kTurretLaunchStart.va, reinterpret_cast<const void*>(&UhcTurretLaunchHook), 9)) {
    return Outcome::kFailed;
  }
  g_uhcTurretOn = 1;
  Log(L"turretArc: %u unit type(s): an attack with <Turret tracking=\"always\"> turns the gun, not the unit, toward a "
      L"target inside its arc%ls (multiplayer unverified)", static_cast<unsigned>(g_aims.size()),
      g_log ? L"; aims and shots logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
