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
//
// A turn beyond the arc (an arc about a rest yaw that is not ahead): the simulation turns the unit at its TurnRate (at
// once for a camel), but the model shows the turn at the aim file's pace (its TURN section, else 0.3 s to rise, 90
// degrees a second, 0.3 s to settle): the model's root bone is turned back by the difference, and the TURN section's
// poses lift the body and step its feet round (the planted feet turned back by the angle turned in the step, in the
// model's space), the gunner stepping with it; the gun rests meanwhile. The attack is held until the turn has settled:
// at the attack update's state switch 0x48A65A, in state 1, the update leaves through the stock wait of a slow turner
// (0x48BFC7: back to state 0). The turn is simulation state (unit ID, game time, the facing's numbers), the same on every
// machine; a saved game does not keep a turn under way.
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
void UhcTurretStateHook();   // hooks/turretarc_hooks.asm
std::int32_t g_uhcTurretOn = 0;
std::int32_t g_uhcTurnCount = 0;  // turns beyond the arc under way: the attack state hook calls in only above 0
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
  // optional, "TURN": the body's turn beyond the arc on the spot (the deployed camel rises, steps round and settles):
  // its pace, and per part (the body's model, the gunner's) the bones' local poses risen and stepping, for a turn
  // toward a growing heading [0] or a shrinking one [1], at `phases` points of one step (the planted feet turned
  // back in the model's space by the step's angle, so they stay put while the model turns on)
  struct TurnPart {
    std::vector<std::string> bones;
    std::vector<float> data;  // [dir 2][phase][bone][7]
    std::vector<float> rise;  // optional "RISE" after TURN: [dir 2][k][bone][7], the pose at lift (k + 1) / riseSteps
  };
  int riseSteps = 0;          // 0: the rise and the settling blend the clip's pose straight to the step's
  bool hasTurn = false;
  float turnStep = 30.0f;     // degrees of turn per step (a step: both diagonal pairs once)
  float turnRise = 0.3f;      // seconds
  float turnSettle = 0.3f;    // seconds
  float turnRate = 90.0f;     // degrees a second
  int turnPhases = 0;
  TurnPart turnBody, turnGunner;
  // optional, "WALK" (after TURN and RISE): the deployed unit walking slowly (its tactic's speed). While the unit moves
  // the body rises through the part's rise poses and steps by the way gone (a point every stride / points of it), the
  // gunner walks beside it and the gun's parts (the zamburak's linstock in his hand) follow; when it stops they settle.
  // Shown only while one of `walkClips` plays (the deployed idle, the shot, the reload).
  struct WalkPart {
    std::vector<std::string> bones;
    std::vector<float> data;  // [point][bone][7]
    std::vector<float> rise;  // [k][bone][7]: the pose at lift (k + 1) / walkK
  };
  bool hasWalk = false;
  float walkStride = 1.4f;    // model units the ground runs back in one cycle
  float walkRise = 0.45f;     // seconds
  float walkSettle = 0.45f;   // seconds
  float walkRate = 120.0f;    // degrees a second the shown heading follows a new course while deployed
  float walkFrom = 0.6f;      // rising, the step shows from this lift on (the legs unfold first)
  int walkPoints = 0;
  int walkK = 0;
  std::vector<std::string> walkClips;  // lower case
  WalkPart walkBody, walkGunner, walkGun;
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
    if (std::memcmp(&b[at], "TURN", 4) == 0) {
      at += 4;
      if (!need(24) || u32() != 1) {
        return false;
      }
      aim.turnStep = f32();
      aim.turnRise = f32();
      aim.turnSettle = f32();
      aim.turnRate = f32();
      const std::uint32_t phases = u32();
      if (phases < 2 || phases > 256 || !(aim.turnStep > 0.0f) || !(aim.turnRate > 0.0f) || aim.turnRise < 0.0f ||
          aim.turnSettle < 0.0f || aim.turnRise > 5.0f || aim.turnSettle > 5.0f) {
        return false;
      }
      aim.turnPhases = static_cast<int>(phases);
      for (AimFile::TurnPart* part : {&aim.turnBody, &aim.turnGunner}) {
        if (!need(4)) {
          return false;
        }
        const std::uint32_t nb = u32();
        if (nb > 256 || !need(32 * nb)) {
          return false;
        }
        for (std::uint32_t i = 0; i < nb; ++i) {
          part->bones.push_back(str(32));
        }
        const std::size_t floats = 2u * phases * nb * 7u;
        if (!need(floats * 4)) {
          return false;
        }
        part->data.resize(floats);
        std::memcpy(part->data.data(), &b[at], floats * 4);
        at += floats * 4;
      }
      aim.hasTurn = true;
      continue;
    }
    if (std::memcmp(&b[at], "RISE", 4) == 0) {
      at += 4;
      if (!aim.hasTurn || !need(8) || u32() != 2) {  // version 2: a table per way (the gunner faces his path)
        return false;
      }
      const std::uint32_t k = u32();
      if (k < 1 || k > 256) {
        return false;
      }
      for (AimFile::TurnPart* part : {&aim.turnBody, &aim.turnGunner}) {
        const std::size_t floats = 2u * static_cast<std::size_t>(k) * part->bones.size() * 7u;
        if (!need(floats * 4)) {
          return false;
        }
        part->rise.resize(floats);
        std::memcpy(part->rise.data(), &b[at], floats * 4);
        at += floats * 4;
      }
      aim.riseSteps = static_cast<int>(k);
      continue;
    }
    if (std::memcmp(&b[at], "WALK", 4) == 0) {
      at += 4;
      if (!need(36) || u32() != 1) {
        return false;
      }
      aim.walkStride = f32();
      aim.walkRise = f32();
      aim.walkSettle = f32();
      aim.walkRate = f32();
      aim.walkFrom = f32();
      const std::uint32_t points = u32(), k = u32(), nwalk = u32();
      if (points < 2 || points > 256 || k < 1 || k > 256 || nwalk > 64 || !(aim.walkStride > 0.0f) ||
          !(aim.walkRate > 0.0f) || aim.walkRise < 0.0f || aim.walkSettle < 0.0f || aim.walkRise > 5.0f ||
          aim.walkSettle > 5.0f || !(aim.walkFrom >= 0.0f && aim.walkFrom < 1.0f) || !need(64 * nwalk)) {
        return false;
      }
      for (std::uint32_t i = 0; i < nwalk; ++i) {
        std::string c = str(64);
        for (char& ch : c) {
          ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
        }
        aim.walkClips.push_back(std::move(c));
      }
      for (AimFile::WalkPart* part : {&aim.walkBody, &aim.walkGunner, &aim.walkGun}) {
        if (!need(4)) {
          return false;
        }
        const std::uint32_t nb = u32();
        if (nb > 256 || !need(32 * nb)) {
          return false;
        }
        for (std::uint32_t i = 0; i < nb; ++i) {
          part->bones.push_back(str(32));
        }
        const std::size_t floats = static_cast<std::size_t>(points) * nb * 7u, rf = static_cast<std::size_t>(k) * nb * 7u;
        if (!need((floats + rf) * 4)) {
          return false;
        }
        part->data.resize(floats);
        std::memcpy(part->data.data(), &b[at], floats * 4);
        at += floats * 4;
        part->rise.resize(rf);
        std::memcpy(part->rise.data(), &b[at], rf * 4);
        at += rf * 4;
      }
      aim.walkPoints = static_cast<int>(points);
      aim.walkK = static_cast<int>(k);
      aim.hasWalk = true;
      continue;
    }
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

// A turn of the body beyond the arc, shown at its own pace in game time (the simulation turns at the proto's
// TurnRate, at once for a camel): the model is turned back by the difference, so it rises, turns and settles, and the
// attack is held meanwhile. Simulation state: written by the facing and read by the attack update, both of which run
// the same on every machine; the screen only reads it. Not kept in a saved game (a turn under way then shows none).
struct Turn {
  std::int32_t start = -1;     // game ms, -1 none
  std::int32_t ms = 0;         // its length: the rise, the turn and the settling
  std::int32_t rise = 0;       // ms
  std::int32_t settle = 0;     // ms
  float from = 0.0f;           // the heading it starts from (degrees, atan2 of the forward's x and z)
  float by = 0.0f;             // the turn, signed (positive toward the unit's right)
  float step = 30.0f;          // degrees of turn per step: the planted feet are baked for exactly this
  int steps = 1;               // for the log: about how many steps (it may end mid-step; the settling puts it down)
};
std::map<std::int32_t, Turn> g_turns;  // unit ID -> its turn

// The pace of a turn: the aim file's TURN section, else a rise and a settling of 0.3 s and 90 degrees a second.
Turn TurnFor(int aim, float from, float by, std::int32_t now) {
  const bool own = aim >= 0 && aim < static_cast<int>(g_aims.size()) && g_aims[aim].hasTurn;
  const float rise = own ? g_aims[aim].turnRise : 0.3f, settle = own ? g_aims[aim].turnSettle : 0.3f;
  const float rate = own ? g_aims[aim].turnRate : 90.0f, step = own ? g_aims[aim].turnStep : 30.0f;
  Turn t;
  t.start = now;
  t.from = from;
  t.by = by;
  t.rise = static_cast<std::int32_t>(rise * 1000.0f + 0.5f);
  t.settle = static_cast<std::int32_t>(settle * 1000.0f + 0.5f);
  t.ms = t.rise + t.settle + static_cast<std::int32_t>(std::fabs(by) * 1000.0f / rate + 0.5f);
  t.step = step;
  t.steps = static_cast<int>(std::fabs(by) / step + 0.5f);
  if (t.steps < 1) {
    t.steps = 1;
  }
  return t;
}

bool Turning(const Turn& sh, std::int32_t now) {
  return sh.start >= 0 && now >= sh.start && now < sh.start + sh.ms;
}

const Turn* TurnOf(std::int32_t id) {
  const auto it = g_turns.find(id);
  return it == g_turns.end() ? nullptr : &it->second;
}

float Smooth(float x) { return x <= 0.0f ? 0.0f : x >= 1.0f ? 1.0f : x * x * (3.0f - 2.0f * x); }

// The heading the model shows at game time `now`; how far it is risen (0 lying, 1 risen, eased) and where it is in
// its step (0..1, 0 with every foot down): the angle turned so far over the step's, so a planted foot stays put
// whatever the turn (a turn that ends mid-step puts the lifted feet down as it settles).
float ShownHeading(const Turn& sh, std::int32_t now, float* lift, float* phase = nullptr) {
  const std::int32_t t = now - sh.start;
  const std::int32_t middle = sh.ms - sh.rise - sh.settle;
  float l = 0.0f, k = 0.0f;
  if (sh.start < 0 || t >= sh.ms || t < 0) {
    k = sh.start < 0 ? 0.0f : 1.0f;
  } else if (t < sh.rise) {
    l = Smooth(static_cast<float>(t) / static_cast<float>(sh.rise));
  } else if (t < sh.rise + middle) {
    l = 1.0f;
    k = middle > 0 ? static_cast<float>(t - sh.rise) / static_cast<float>(middle) : 1.0f;
  } else {
    l = sh.settle > 0 ? 1.0f - Smooth(static_cast<float>(t - sh.rise - middle) / static_cast<float>(sh.settle)) : 0.0f;
    k = 1.0f;
  }
  if (lift != nullptr) {
    *lift = l;
  }
  if (phase != nullptr) {
    const float s = std::fabs(sh.by) * k / sh.step;
    *phase = s - std::floor(s);
  }
  return sh.from + sh.by * k;
}

// A deployed unit walking (the aim file's WALK): display state only, kept per unit in game time by the world tick from
// the unit's position (the simulation moves it at its tactic's speed); the screen reads it.
struct Walk {
  int aim = -1;
  bool placed = false;          // x, z hold a position
  float x = 0.0f, z = 0.0f;     // the unit's position at the last tick
  std::int32_t lastMs = -1;     // game time of the last tick
  bool moving = false;          // it moved since the last tick
  float ramp = 0.0f;            // 0 kneeling .. 1 risen, in time (the shown lift is its smoothstep)
  float dist = 0.0f;            // the way gone since its step began (model units)
  float shown = 0.0f;           // the heading the model shows while deployed (degrees)
  bool shownSet = false;
  bool deployed = false;        // the body last sampled one of the walk's clips
  bool logged = false;          // for the log: this walk's start told
};
std::unordered_map<std::int32_t, Walk> g_walks;  // unit ID -> its walk (the units of a type with a WALK section)
std::int32_t g_walkScanMs = -1000000;

float WalkLift(const Walk& w) {
  const float x = w.ramp <= 0.0f ? 0.0f : w.ramp >= 1.0f ? 1.0f : w.ramp;
  return x * x * (3.0f - 2.0f * x);
}

const Walk* WalkOf(std::int32_t id) {
  const auto it = g_walks.find(id);
  return it == g_walks.end() ? nullptr : &it->second;
}

float WalkPhase(const Walk& w, const AimFile& aim) {
  const float s = w.dist / aim.walkStride;
  return s - std::floor(s);
}

// The walk may show on this clip (the deployed idle, the shot, the reload of the part).
bool IsWalkClip(const AimFile& aim, const char* name) {
  if (name == nullptr || !aim.hasWalk) {
    return false;
  }
  std::string s(name);
  for (char& ch : s) {
    ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
  }
  for (const std::string& c : aim.walkClips) {
    if (c == s) {
      return true;
    }
  }
  return false;
}

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
  int root = -1;  // the skeleton's first bone with no parent (a Granny bone: +4 its parent index)
  std::vector<int> gunner;
  std::vector<int> turnBody, turnGunner;  // the aim file's TURN bones in this skeleton (-1 where it lacks one)
  bool anyTurnBody = false, anyTurnGunner = false;
  std::vector<int> walkBody, walkGunner, walkGun;  // the WALK parts' bones in this skeleton (-1 where it lacks one)
  bool anyWalkGunner = false;
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
  if (skeleton != nullptr) {
    const std::int32_t count = Field<std::int32_t>(skeleton, 4);
    const char* bones = Field<const char*>(skeleton, 8);
    for (std::int32_t i = 0; bones != nullptr && i < count && i < 512; ++i) {
      if (Field<std::int32_t>(bones, static_cast<std::uint32_t>(i) * kGrannyBoneSize + 4) == -1) {
        m.root = i;
        break;
      }
    }
  }
  bool all = !a.bones.empty();
  for (const std::string& b : a.bones) {
    m.gunner.push_back(BoneIndex(skeleton, b));
    all = all && m.gunner.back() >= 0;
  }
  if (!all) {
    m.gunner.clear();
  }
  for (const std::string& b : a.turnBody.bones) {
    m.turnBody.push_back(BoneIndex(skeleton, b));
    m.anyTurnBody = m.anyTurnBody || m.turnBody.back() >= 0;
  }
  for (const std::string& b : a.turnGunner.bones) {
    m.turnGunner.push_back(BoneIndex(skeleton, b));
    m.anyTurnGunner = m.anyTurnGunner || m.turnGunner.back() >= 0;
  }
  for (const std::string& b : a.walkBody.bones) {
    m.walkBody.push_back(BoneIndex(skeleton, b));
  }
  for (const std::string& b : a.walkGunner.bones) {
    m.walkGunner.push_back(BoneIndex(skeleton, b));
    m.anyWalkGunner = m.anyWalkGunner || m.walkGunner.back() >= 0;
  }
  for (const std::string& b : a.walkGun.bones) {
    m.walkGun.push_back(BoneIndex(skeleton, b));
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
    if (m.gun < 0 && m.turret < 0 && m.gunner.empty() && !m.anyTurnGunner && !m.anyWalkGunner) {
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

// A root bone turned about the model's up (y) by `degrees` (+ toward the unit's right), about the model's origin: the
// rotation comes first in the parent's (the model's) frame, and the bone's position turns with it.
void TurnRoot(void* pose, int bone, float degrees) {
  GrannyTransform* t = g_localTransform(pose, bone);
  if (t == nullptr) {
    return;
  }
  const float h = degrees * kPi / 360.0f;
  const float q[4] = {0.0f, std::sin(h), 0.0f, std::cos(h)};
  if ((t->flags & 2) == 0) {
    t->orientation[0] = t->orientation[1] = t->orientation[2] = 0.0f;
    t->orientation[3] = 1.0f;
  }
  float o[4];
  QuatMul(q, t->orientation, o);
  std::memcpy(t->orientation, o, sizeof o);
  if ((t->flags & 1) != 0) {
    const float a = degrees * kPi / 180.0f;
    const float x = t->position[0], z = t->position[2];
    t->position[0] = x * std::cos(a) + z * std::sin(a);
    t->position[2] = -x * std::sin(a) + z * std::cos(a);
  }
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

bool IsDeathClip(const char* name) {
  if (name == nullptr) {
    return false;
  }
  std::string s(name);
  for (char& ch : s) {
    ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
  }
  return s.find("death") != std::string::npos;
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

// The aim file's TURN pose of one part at `phase` of a step, toward a growing heading (dir 0) or a shrinking one (1),
// shown `lift` of the way from the pose sampled so far (the clip's, 0) to the step's (1): the rise and the settling.
// With a RISE table the way runs through its poses (so the folded legs unfold as the body rises, not through the
// ground), each taking `lift` of the step point's offset from the step's first (a turn may settle mid-step); without
// one it is a straight blend.
void Nlerp(const float* a, const float* b, float w, float* out) {
  const float s = (a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]) < 0 ? -1.0f : 1.0f;
  float len = 0.0f;
  for (int i = 0; i < 4; ++i) {
    out[i] = a[i] + w * (s * b[i] - a[i]);
    len += out[i] * out[i];
  }
  len = std::sqrt(len);
  for (int i = 0; i < 4; ++i) {
    out[i] = len > 1e-6f ? out[i] / len : (i == 3 ? 1.0f : 0.0f);
  }
}

void PoseTurnPart(void* pose, int first, int end, const AimFile& aim, const AimFile::TurnPart& part,
                  const std::vector<int>& bones, int dir, float phase, float lift) {
  const int np = aim.turnPhases;
  const std::size_t nb = part.bones.size();
  if (np < 2 || nb == 0 || bones.size() != nb || lift <= 0.0f) {
    return;
  }
  const float fp = phase * static_cast<float>(np);
  int p0 = static_cast<int>(fp);
  const float w = fp - static_cast<float>(p0);
  p0 %= np;
  const int p1 = (p0 + 1) % np;  // a step's last point runs into its first
  auto at = [&](int ph, std::size_t b) { return &part.data[((static_cast<std::size_t>(dir) * np + ph) * nb + b) * 7]; };
  const int K = aim.riseSteps;
  const bool table = K > 0 && part.rise.size() == 2u * static_cast<std::size_t>(K) * nb * 7 && lift < 1.0f;
  auto riseAt = [&](int kk, std::size_t b) {
    return &part.rise[((static_cast<std::size_t>(dir) * K + kk) * nb + b) * 7];
  };
  const float x = lift * static_cast<float>(K);
  int k = table ? static_cast<int>(x) : 0;
  if (k > K - 1) {
    k = K - 1;
  }
  const float wk = table ? x - static_cast<float>(k) : 0.0f;
  for (std::size_t b = 0; b < nb; ++b) {
    const int bone = bones[b];
    if (bone < first || bone >= end) {
      continue;
    }
    GrannyTransform* tr = g_localTransform(pose, bone);
    if (tr == nullptr) {
      continue;
    }
    // the step's pose at the phase, between its two nearest points
    const float* a = at(p0, b);
    const float* c = at(p1, b);
    float sp[3], sq[4];
    for (int i = 0; i < 3; ++i) {
      sp[i] = a[i] + w * (c[i] - a[i]);
    }
    Nlerp(a + 3, c + 3, w, sq);
    // what the clip has
    float cur[4] = {0.0f, 0.0f, 0.0f, 1.0f};
    if ((tr->flags & 2) != 0) {
      std::memcpy(cur, tr->orientation, sizeof cur);
    }
    float curp[3] = {0.0f, 0.0f, 0.0f};
    if ((tr->flags & 1) != 0) {
      std::memcpy(curp, tr->position, sizeof curp);
    }
    float op[3], oq[4];
    if (!table) {
      for (int i = 0; i < 3; ++i) {
        op[i] = curp[i] + lift * (sp[i] - curp[i]);
      }
      Nlerp(cur, sq, lift, oq);
    } else {
      const float* from = k == 0 ? nullptr : riseAt(k - 1, b);
      const float* to = riseAt(k, b);
      const float* fp3 = from == nullptr ? curp : from;
      const float* fq = from == nullptr ? cur : from + 3;
      float bp[3], bq[4];
      for (int i = 0; i < 3; ++i) {
        bp[i] = fp3[i] + wk * (to[i] - fp3[i]);
      }
      Nlerp(fq, to + 3, wk, bq);
      // and `lift` of the step point's offset from the step's first
      const float* z = at(0, b);
      for (int i = 0; i < 3; ++i) {
        op[i] = bp[i] + lift * (sp[i] - z[i]);
      }
      const float zc[4] = {-z[3], -z[4], -z[5], z[6]};
      float d[4], id[4] = {0.0f, 0.0f, 0.0f, 1.0f}, dl[4];
      QuatMul(sq, zc, d);
      Nlerp(id, d, lift, dl);
      QuatMul(dl, bq, oq);
      const float len = std::sqrt(oq[0] * oq[0] + oq[1] * oq[1] + oq[2] * oq[2] + oq[3] * oq[3]);
      for (int i = 0; i < 4 && len > 1e-6f; ++i) {
        oq[i] /= len;
      }
    }
    std::memcpy(tr->position, op, sizeof op);
    std::memcpy(tr->orientation, oq, sizeof oq);
    tr->flags |= 3;
  }
}

// The aim file's WALK pose of one part at `phase` of a cycle and `lift`: risen, the point at the phase; rising or
// settling, the part's rise poses (from the clip's) and a share of the point's offset from point 0 (rising: none until
// walkFrom, all at 1, so the legs unfold before they step; settling: the lift's, so the stride folds over the settle).
void PoseWalkPart(void* pose, int first, int end, const AimFile& aim, const AimFile::WalkPart& part,
                  const std::vector<int>& bones, float phase, float lift, bool settling) {
  const int np = aim.walkPoints, K = aim.walkK;
  const std::size_t nb = part.bones.size();
  if (np < 2 || K < 1 || nb == 0 || bones.size() != nb || lift <= 0.0f ||
      part.data.size() != static_cast<std::size_t>(np) * nb * 7 || part.rise.size() != static_cast<std::size_t>(K) * nb * 7) {
    return;
  }
  const float fp = phase * static_cast<float>(np);
  int p0 = static_cast<int>(fp);
  const float w = fp - static_cast<float>(p0);
  p0 = ((p0 % np) + np) % np;
  const int p1 = (p0 + 1) % np;
  auto at = [&](int ph, std::size_t b) { return &part.data[(static_cast<std::size_t>(ph) * nb + b) * 7]; };
  auto riseAt = [&](int kk, std::size_t b) { return &part.rise[(static_cast<std::size_t>(kk) * nb + b) * 7]; };
  const bool risen = lift >= 1.0f;
  const float x = lift * static_cast<float>(K);
  int k = static_cast<int>(x);
  if (k > K - 1) {
    k = K - 1;
  }
  const float wk = x - static_cast<float>(k);
  const float ow = risen ? 1.0f : settling ? lift : Smooth((lift - aim.walkFrom) / (1.0f - aim.walkFrom));
  for (std::size_t b = 0; b < nb; ++b) {
    const int bone = bones[b];
    if (bone < first || bone >= end) {
      continue;
    }
    GrannyTransform* tr = g_localTransform(pose, bone);
    if (tr == nullptr) {
      continue;
    }
    const float* a = at(p0, b);
    const float* c = at(p1, b);
    float sp[3], sq[4];
    for (int i = 0; i < 3; ++i) {
      sp[i] = a[i] + w * (c[i] - a[i]);
    }
    Nlerp(a + 3, c + 3, w, sq);
    float op[3], oq[4];
    if (risen) {
      std::memcpy(op, sp, sizeof op);
      std::memcpy(oq, sq, sizeof oq);
    } else {
      float cur[4] = {0.0f, 0.0f, 0.0f, 1.0f}, curp[3] = {0.0f, 0.0f, 0.0f};
      if ((tr->flags & 2) != 0) {
        std::memcpy(cur, tr->orientation, sizeof cur);
      }
      if ((tr->flags & 1) != 0) {
        std::memcpy(curp, tr->position, sizeof curp);
      }
      const float* from = k == 0 ? nullptr : riseAt(k - 1, b);
      const float* to = riseAt(k, b);
      const float* fp3 = from == nullptr ? curp : from;
      const float* fq = from == nullptr ? cur : from + 3;
      float bp[3], bq[4];
      for (int i = 0; i < 3; ++i) {
        bp[i] = fp3[i] + wk * (to[i] - fp3[i]);
      }
      Nlerp(fq, to + 3, wk, bq);
      const float* z = at(0, b);
      for (int i = 0; i < 3; ++i) {
        op[i] = bp[i] + ow * (sp[i] - z[i]);
      }
      const float zc[4] = {-z[3], -z[4], -z[5], z[6]};
      float d[4], id[4] = {0.0f, 0.0f, 0.0f, 1.0f}, dl[4];
      QuatMul(sq, zc, d);
      Nlerp(id, d, ow, dl);
      QuatMul(dl, bq, oq);
      const float len = std::sqrt(oq[0] * oq[0] + oq[1] * oq[1] + oq[2] * oq[2] + oq[3] * oq[3]);
      for (int i = 0; i < 4 && len > 1e-6f; ++i) {
        oq[i] /= len;
      }
    }
    std::memcpy(tr->position, op, sizeof op);
    std::memcpy(tr->orientation, oq, sizeof oq);
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

// A forward's heading: degrees about the vertical, 0 along +z, growing toward +x (the unit's right).
float HeadingOf(const float* v) { return std::atan2(v[0], v[2]) * 180.0f / kPi; }

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
  const std::int32_t gameNow = Now(world);
  const Turn* bodyTurn = TurnOf(sh.unitId);
  const bool turning = bodyTurn != nullptr && Turning(*bodyTurn, gameNow);  // the body turns on screen: the gun rests
  const float target =
      (!turning && !sh.home && sh.aimedAt >= 0 && gameNow - sh.aimedAt <= kAimHoldMs) ? sh.gameYaw : rest;
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
    case Role::kGun: {
      if (m.gun >= first && m.gun < end && turn != 0.0f) {
        TurnBone(pose, m.gun, turn);
      }
      const Walk* wk = WalkOf(sh.unitId);
      float clock = 0.0f;
      if (wk != nullptr && !turning && !m.walkGun.empty() && IsWalkClip(g_aims[sh.aim], PlayingClip(instance, &clock))) {
        PoseWalkPart(pose, first, end, g_aims[sh.aim], g_aims[sh.aim].walkGun, m.walkGun,
                     WalkPhase(*wk, g_aims[sh.aim]), WalkLift(*wk), !wk->moving);
      }
      break;
    }
    case Role::kBody: {
      // the turn beyond the arc: the model shows the heading of the shown turn, the simulation's being ahead of it
      const char* unit = turning ? UnitById(world, sh.unitId) : nullptr;
      if (unit != nullptr) {
        float lift = 0.0f, phase = 0.0f;
        const float shown = ShownHeading(*bodyTurn, gameNow, &lift, &phase);
        float bodyClock = 0.0f;
        if (IsDeathClip(PlayingClip(instance, &bodyClock))) {
          lift = 0.0f;  // killed while it turns: its death plays as it is, only the heading still eases round
        }
        PoseTurnPart(pose, first, end, g_aims[sh.aim], g_aims[sh.aim].turnBody, m.turnBody, bodyTurn->by < 0.0f,
                     phase, lift);
        if (m.root >= first && m.root < end) {
          const float sim = HeadingOf(reinterpret_cast<const float*>(unit + 0x20));
          const float fix = Wrap(shown - sim);
          if (fix != 0.0f) {
            TurnRoot(pose, m.root, kModelSense * fix);
          }
        }
      }
      // the deployed walk: the body rises and steps by the way gone while the unit moves, and the model's heading
      // follows a new course at the walk's rate
      if (unit == nullptr) {
        auto w = g_walks.find(sh.unitId);
        float clock = 0.0f;
        const bool on = w != g_walks.end() && IsWalkClip(g_aims[sh.aim], PlayingClip(instance, &clock));
        if (w != g_walks.end()) {
          w->second.deployed = on;
        }
        if (on) {
          const Walk& wk = w->second;
          PoseWalkPart(pose, first, end, g_aims[sh.aim], g_aims[sh.aim].walkBody, m.walkBody,
                       WalkPhase(wk, g_aims[sh.aim]), WalkLift(wk), !wk.moving);
          const char* u = UnitById(world, sh.unitId);
          if (u != nullptr && wk.shownSet && m.root >= first && m.root < end) {
            const float fix = Wrap(wk.shown - HeadingOf(reinterpret_cast<const float*>(u + 0x20)));
            if (fix != 0.0f) {
              TurnRoot(pose, m.root, kModelSense * fix);
            }
          }
        }
      }
      if (m.turret >= first && m.turret < end && turn != 0.0f) {
        TurnBone(pose, m.turret, turn);
      }
      break;
    }
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
      const Walk* wk = WalkOf(sh.unitId);
      if (wk != nullptr && !turning && IsWalkClip(g_aims[sh.aim], clip)) {  // he walks beside it, pushing
        PoseWalkPart(pose, first, end, g_aims[sh.aim], g_aims[sh.aim].walkGunner, m.walkGunner,
                     WalkPhase(*wk, g_aims[sh.aim]), WalkLift(*wk), !wk->moving);
      }
      if (turning && !IsDeathClip(clip)) {  // he steps round with the body
        float lift = 0.0f, phase = 0.0f;
        ShownHeading(*bodyTurn, gameNow, &lift, &phase);
        PoseTurnPart(pose, first, end, g_aims[sh.aim], g_aims[sh.aim].turnGunner, m.turnGunner, bodyTurn->by < 0.0f,
                     phase, lift);
      }
      break;
    }
  }
}

// A turn beyond the arc begins (from the facing, in the simulation: the same on every machine): the body is shown
// rising, turning at its pace and settling, and the attack is held meanwhile (UhcTurretHold). A call during the same
// turn (the same heading wanted) changes nothing; a new target during the shown turn turns on from the shown heading.
void StartTurn(const char* unit, std::int32_t id, int aim, float by) {
  const std::int32_t now = Now(World());
  const float heading = HeadingOf(reinterpret_cast<const float*>(unit + 0x20));
  const float to = heading + by;
  Turn& sh = g_turns[id];
  const bool under = Turning(sh, now);
  if (under && std::fabs(Wrap(to - (sh.from + sh.by))) < 3.0f) {
    return;
  }
  const float from = under ? ShownHeading(sh, now, nullptr) : heading;
  sh = TurnFor(aim, from, Wrap(to - from), now);
  g_uhcTurnCount = static_cast<std::int32_t>(g_turns.size());
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"turretArc: %d ms, unit %d turns its body %+.1f degrees (from %.1f, %d steps): shown in %d ms, its "
             L"attack held until %d ms", now, id, static_cast<double>(sh.by), static_cast<double>(from), sh.steps,
             sh.ms, now + sh.ms);
  }
}

// The deployed walk's state of each unit of a type with a WALK section, from its position (display only).
constexpr std::int32_t kWalkScanMs = 1000;  // new units of those types are found this often (game time)

void TickWalks(char* world, std::int32_t now) {
  bool any = false;
  for (const AimFile& a : g_aims) {
    any = any || a.hasWalk;
  }
  if (!any || world == nullptr) {
    return;
  }
  if (now < g_walkScanMs || now - g_walkScanMs >= kWalkScanMs) {  // find them (a new game restarts the clock)
    g_walkScanMs = now;
    const std::int32_t count = Field<std::int32_t>(world, 0x10);
    const char* const* units = Field<const char* const*>(world, 0x0C);
    for (std::int32_t i = 0; units != nullptr && i < count && i < 0x40000; ++i) {
      const char* unit = units[i];
      if (unit == nullptr) {
        continue;
      }
      const int aim = AimOf(unit);
      if (aim >= 0 && g_aims[aim].hasWalk) {
        Walk& w = g_walks[Field<std::int32_t>(unit, 0x10)];
        if (w.aim != aim) {
          w = Walk{};
          w.aim = aim;
        }
      }
    }
  }
  for (auto it = g_walks.begin(); it != g_walks.end();) {
    const char* unit = UnitById(world, it->first);
    Walk& w = it->second;
    if (unit == nullptr || AimOf(unit) != w.aim || (w.lastMs >= 0 && now < w.lastMs)) {
      it = g_walks.erase(it);
      continue;
    }
    const AimFile& a = g_aims[w.aim];
    const float* pos = reinterpret_cast<const float*>(unit + 0x14);
    const float dt = w.lastMs < 0 ? 0.0f : static_cast<float>(now - w.lastMs) / 1000.0f;
    const float d = w.placed ? std::hypot(pos[0] - w.x, pos[2] - w.z) : 0.0f;
    const float course = w.placed && d > 1e-4f ? std::atan2(pos[0] - w.x, pos[2] - w.z) * 180.0f / kPi : 0.0f;
    w.lastMs = now;
    w.x = pos[0];
    w.z = pos[2];
    w.placed = true;
    if (dt <= 0.0f) {
      ++it;
      continue;
    }
    w.moving = d > 1e-4f && d < 5.0f && w.deployed;  // a jump (a teleport) is not a walk
    if (w.moving) {
      w.ramp = a.walkRise > 0.0f ? std::fmin(1.0f, w.ramp + dt / a.walkRise) : 1.0f;
      if (WalkLift(w) >= a.walkFrom) {
        w.dist += d;   // the step counts the way gone once the legs have unfolded
      }
    } else {
      w.ramp = a.walkSettle > 0.0f ? std::fmax(0.0f, w.ramp - dt / a.walkSettle) : 0.0f;
      if (w.ramp <= 0.0f) {
        w.dist = 0.0f;
      }
    }
    // the shown heading: the turn's while it turns; deployed, it follows the simulation's at the walk's rate
    const float sim = HeadingOf(reinterpret_cast<const float*>(unit + 0x20));
    const Turn* turn = TurnOf(it->first);
    if (turn != nullptr && Turning(*turn, now)) {
      w.shown = ShownHeading(*turn, now, nullptr);
      w.shownSet = true;
    } else if (!w.shownSet || !w.deployed) {
      w.shown = sim;
      w.shownSet = true;
    } else {
      const float diff = Wrap(sim - w.shown), step = a.walkRate * dt;
      w.shown = std::fabs(diff) <= step ? sim : Wrap(w.shown + (diff > 0.0f ? step : -step));
    }
    static unsigned walkLines = 0;
    if (g_log && w.moving && walkLines < 120 && (now / 500) != ((now - static_cast<std::int32_t>(dt * 1000.0f)) / 500)) {
      ++walkLines;
      uhc::Log(L"turretArc: %d ms, unit %d walking: %.3f this tick along %.1f, heading %.1f (shown %.1f), lift %.2f, phase %.2f",
               now, it->first, static_cast<double>(d), static_cast<double>(course), static_cast<double>(sim), static_cast<double>(w.shown),
               static_cast<double>(WalkLift(w)), static_cast<double>(WalkPhase(w, a)));
    }
    const bool active = w.ramp > 0.0f || std::fabs(Wrap(w.shown - sim)) > 0.01f || w.moving;
    // the unit's parts are posed only while it has a display state (as an aiming unit has); a deployed unit keeps one
    // so its body's clip is seen (w.deployed)
    Shown& sh = g_shown[it->first];
    if (sh.unitId < 0 || sh.aim != w.aim) {
      sh = Shown{};
      sh.unitId = it->first;
      sh.aim = w.aim;
      sh.shownYaw = HomeOf(w.aim);
    }
    if (active) {
      if (g_log && !w.logged && w.moving && g_logLines < kMaxLogLines) {
        ++g_logLines;
        w.logged = true;
        uhc::Log(L"turretArc: %d ms, unit %d walks deployed: it rises in %.2f s and steps %.2f a cycle", now,
                 it->first, static_cast<double>(a.walkRise), static_cast<double>(a.walkStride));
      }
    } else {
      w.logged = false;
    }
    ++it;
  }
}

// Each world update: the units the key serves keep their instances mapped (a death or a transform changes them);
// a unit gone, or back home and not aiming for a while, leaves.
void Tick(char* world, std::int32_t) {
  g_instances.clear();
  const std::int32_t now = Now(world);
  TickWalks(world, now);
  for (auto it = g_shown.begin(); it != g_shown.end();) {
    const char* unit = UnitById(world, it->first);
    const bool idle = it->second.aimedAt < 0 || now - it->second.aimedAt > 4 * kAimHoldMs;
    const Turn* turn = TurnOf(it->first);
    const bool walker = WalkOf(it->first) != nullptr;  // a unit of a walking type keeps its state (its walk shows)
    if (unit == nullptr || (idle && !walker && it->second.shownYaw == HomeOf(it->second.aim) &&
                            (turn == nullptr || !Turning(*turn, now)))) {
      it = g_shown.erase(it);
      continue;
    }
    MapInstances(unit, it->second.aim);
    ++it;
  }
  for (auto it = g_turns.begin(); it != g_turns.end();) {  // simulation state: by game time and unit only
    // ended, the unit gone, or from another game (a game time before its start)
    it = (now >= it->second.start + it->second.ms || now < it->second.start || UnitById(world, it->first) == nullptr)
             ? g_turns.erase(it)
             : std::next(it);
  }
  g_uhcTurnCount = static_cast<std::int32_t>(g_turns.size());
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
      StartTurn(unit, id, aim, Wrap(angle - home));
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

// From the attack update's state switch 0x48A65A, in state 1 (firing): 1 holds the attack (the stock wait of a slow
// turner, back to state 0) while the unit's body turns beyond its turret's arc on screen.
std::int32_t __stdcall UhcTurretHold(const char* unitAction) {
  const char* unit = unitAction == nullptr ? nullptr : Field<const char*>(unitAction, 0x10);
  if (unit == nullptr) {
    return 0;
  }
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const Turn* turn = TurnOf(id);
  const std::int32_t now = Now(World());
  if (turn == nullptr || !Turning(*turn, now)) {
    return 0;
  }
  static std::int32_t loggedStart = -1;
  if (g_log && g_logLines < kMaxLogLines && loggedStart != turn->start) {
    ++g_logLines;
    loggedStart = turn->start;
    uhc::Log(L"turretArc: %d ms, unit %d: its attack waits for its turn (until %d ms)", now, id,
             turn->start + turn->ms);
  }
  return 1;
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
  if (g_log && launchLines < 400) {
    ++launchLines;
    const float d[3] = {start[0] - pivot[0], start[1] - pivot[1], start[2] - pivot[2]};
    uhc::Log(L"turretArc: %d ms, unit %d shot, yaw %.1f: the game's start (forward %.2f, right %.2f, up %.2f) from "
             L"the pivot, the turned muzzle's (%.2f, %.2f, %.2f)", Now(World()), Field<std::int32_t>(unit, 0x10),
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
    if (aim.hasTurn) {
      Log(L"turretArc: %hs: a turn beyond the arc rises in %.2f s, turns %.0f degrees a second in steps of %.0f "
          L"degrees (%d points a step; %u body bones, %u gunner bones) and settles in %.2f s",
          aim.proto.c_str(), static_cast<double>(aim.turnRise), static_cast<double>(aim.turnRate),
          static_cast<double>(aim.turnStep), aim.turnPhases, static_cast<unsigned>(aim.turnBody.bones.size()),
          static_cast<unsigned>(aim.turnGunner.bones.size()), static_cast<double>(aim.turnSettle));
      if (aim.riseSteps > 0) {
        Log(L"turretArc: %hs: it rises and settles through %d poses", aim.proto.c_str(), aim.riseSteps);
      }
    }
    if (aim.hasWalk) {
      Log(L"turretArc: %hs: deployed, it walks: rises in %.2f s, steps %.2f a cycle (%d points; %u body, %u gunner, %u "
          L"gun bones), its heading follows %.0f degrees a second, settles in %.2f s, on %u clips",
          aim.proto.c_str(), static_cast<double>(aim.walkRise), static_cast<double>(aim.walkStride), aim.walkPoints,
          static_cast<unsigned>(aim.walkBody.bones.size()), static_cast<unsigned>(aim.walkGunner.bones.size()),
          static_cast<unsigned>(aim.walkGun.bones.size()), static_cast<double>(aim.walkRate),
          static_cast<double>(aim.walkSettle), static_cast<unsigned>(aim.walkClips.size()));
    }
    g_aims.push_back(std::move(aim));
  }
  if (!LoadGranny()) {
    return Outcome::kFailed;
  }
  if (!VerifyAll("turretArc", {&sites::kTurretFaceHead, &sites::kTurretLaunchStart, &sites::kTurretAttackState,
                               &sites::kTurretAttackWait}) ||
      !OnDatabaseLoad(&ResetForDataLoad) || !AddWorldTick(&Tick) ||
      !AddGrannySampleObserver(&AfterSample, "turretArc")) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kTurretFaceHead.va, reinterpret_cast<const void*>(&UhcTurretFaceHook), 6) ||
      !WriteJmp(sites::kTurretLaunchStart.va, reinterpret_cast<const void*>(&UhcTurretLaunchHook), 9) ||
      !WriteJmp(sites::kTurretAttackState.va, reinterpret_cast<const void*>(&UhcTurretStateHook), 7)) {
    return Outcome::kFailed;
  }
  g_uhcTurretOn = 1;
  Log(L"turretArc: %u unit type(s): an attack with <Turret tracking=\"always\"> turns the gun, not the unit, toward a "
      L"target inside its arc%ls (multiplayer unverified)", static_cast<unsigned>(g_aims.size()),
      g_log ? L"; aims and shots logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
