// steadyHitpointBars [UnitType ...] [log]: the floating HP bars stay still while the unit gallops,
// attacks or works, instead of following its animation.
//
// The unit visual update's bar chunk (0x45FAE2) asks 0x45F22D for the HITPOINTBAR tag of the unit's
// model, in model space, and takes it to the world with the unit's matrix (0x406BDB); the bar is
// queued there (0x45FB71). When the current animation has no such tag, the cold block 0x460633 puts
// the bar at the unit's position plus a height from data instead. The tag's position is not a pose
// of the model: each animation file carries its own sampled track of it (0x45F072 interpolates two
// keys at the visual's clock), so the bar follows the rider through a gallop, and it jumps to the
// other height whenever the unit switches to an animation without the tag. There is no rest position
// to read: an animation is chosen per state and variation, and its track is the only one the game
// keeps.
//
// So the key holds, per unit, what the tag did over the last 3 to 6 seconds of animations that have
// it: the highest height (where the bar is when the unit stands) and the middle of its sideways and
// forward range, and moves the bar toward that by at most 1.5 model units a second. While the
// animation has no tag, the bar stays at that held position instead of the fallback; a unit whose
// tag was never seen keeps the stock fallback. A building's or a static model's tag never moves, so
// its bar stays exactly where it was.
//
// Display only: the hook writes the model-space vector the stock code takes to the world, nothing
// else; the clock is the real one, which only this machine's drawing reads.
#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" void UhcSteadyBarHook();

namespace {

constexpr std::size_t kMaxTypes = 8;
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr DWORD kBucketMs = 3000;                  // the history is two buckets: 3 to 6 s of tag time
constexpr DWORD kStepMs = 100;                     // the most one call counts, for the clock and the rate
constexpr DWORD kForgetMs = 10000;                 // unseen longer: the unit's history is dropped
constexpr DWORD kPurgeMs = 5000;
constexpr float kRate = 1.5f;                      // model units per second

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// What the tag did in one bucket, in model space.
struct Range {
  float lo[3];
  float hi[3];
  void Reset(const float* v) {
    for (int i = 0; i < 3; ++i) {
      lo[i] = hi[i] = v[i];
    }
  }
  void Add(const float* v) {
    for (int i = 0; i < 3; ++i) {
      lo[i] = std::min(lo[i], v[i]);
      hi[i] = std::max(hi[i], v[i]);
    }
  }
};

struct Steady {
  std::int32_t id = -1;           // [unit+10h]: a reused pointer is another unit
  const char* proto = nullptr;    // [unit+5Ch] when `marked` was decided
  bool marked = false;
  bool held = false;              // the tag was seen: `out` is valid
  bool logged = false;
  DWORD seen = 0;                 // the last call, real time
  DWORD clock = 0;                // tag time: what the calls with the tag add up to, kStepMs at most each
  DWORD bucketStart = 0;          // on `clock`
  std::uint32_t calls = 0;
  std::uint32_t missing = 0;      // calls without the tag
  Range current{};
  Range previous{};
  float out[3] = {};              // what the bar uses
};

std::int32_t g_types[kMaxTypes] = {-1, -1, -1, -1, -1, -1, -1, -1};
std::size_t g_typeCount = 0;
bool g_log = false;
std::unordered_map<const char*, Steady> g_units;
const char* g_world = nullptr;
DWORD g_lastPurge = 0;
std::set<std::string> g_loggedProtos;

bool Marked(const char* proto) {
  if (g_typeCount == 0) {
    return true;
  }
  if (proto == nullptr) {
    return false;
  }
  for (std::size_t i = 0; i < g_typeCount; ++i) {
    if (g_types[i] >= 0 && kProtoIsType(proto, g_types[i])) {
      return true;
    }
  }
  return false;
}

void Purge(DWORD now) {
  if (now - g_lastPurge < kPurgeMs) {
    return;
  }
  g_lastPurge = now;
  for (auto it = g_units.begin(); it != g_units.end();) {
    it = now - it->second.seen > kForgetMs ? g_units.erase(it) : std::next(it);
  }
}

void LogOnce(const char* unit, const Steady& s) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  const std::string key = name == nullptr ? "?" : name;
  if (!g_loggedProtos.insert(key).second) {
    return;
  }
  uhc::Log(L"steadyHitpointBars: unit %d (%hs): the bar holds at height %.2f in model space; over 3 s the tag went "
           L"from %.2f to %.2f (sideways %.2f..%.2f, forward %.2f..%.2f), and %u of %u frames had no tag; logged once "
           L"per proto",
           s.id, key.c_str(), static_cast<double>(s.out[1]), static_cast<double>(s.previous.lo[1]),
           static_cast<double>(s.previous.hi[1]), static_cast<double>(s.previous.lo[0]),
           static_cast<double>(s.previous.hi[0]), static_cast<double>(s.previous.lo[2]),
           static_cast<double>(s.previous.hi[2]), s.missing, s.calls);
}

// The held position: the tag's highest height and the middle of its other two ranges, over both buckets.
void Target(const Steady& s, float* target) {
  for (int i = 0; i < 3; ++i) {
    const float lo = std::min(s.current.lo[i], s.previous.lo[i]);
    const float hi = std::max(s.current.hi[i], s.previous.hi[i]);
    target[i] = i == 1 ? hi : (lo + hi) * 0.5f;
  }
}

}  // namespace

// From the bar chunk (0x45FB24). `found`: the current animation has the HITPOINTBAR tag, and
// `local` holds it in model space. True: `local` holds the bar's position (the stock path takes it
// to the world); false: the stock fallback (no tag, and none seen yet for this unit).
extern "C" bool __stdcall UhcSteadyBarLocal(const char* unit, float* local, std::int32_t found) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world != g_world) {  // a new game: no unit of the last one is drawn again
    g_units.clear();
    g_world = world;
  }
  const DWORD now = GetTickCount();
  Purge(now);

  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const char* proto = Field<const char*>(unit, 0x5C);
  Steady& s = g_units[unit];
  if (s.id != id || s.proto != proto) {  // a new unit, or a transform in place: another model
    s = Steady{};
    s.id = id;
    s.proto = proto;
    s.marked = Marked(proto);
    s.seen = now;
  }
  if (!s.marked) {
    s.seen = now;
    return found != 0;
  }
  const DWORD step = std::min<DWORD>(now - s.seen, kStepMs);
  s.seen = now;
  ++s.calls;
  if (found == 0) {
    ++s.missing;
    if (!s.held) {
      return false;
    }
    std::copy(s.out, s.out + 3, local);
    return true;
  }
  if (!s.held) {
    s.held = true;
    s.clock = 0;
    s.bucketStart = 0;
    s.current.Reset(local);
    s.previous.Reset(local);
    std::copy(local, local + 3, s.out);
    return true;
  }

  s.clock += step;
  if (s.clock - s.bucketStart >= kBucketMs) {
    s.previous = s.current;
    s.current.Reset(local);
    s.bucketStart = s.clock;
    if (g_log && !s.logged) {
      s.logged = true;
      LogOnce(unit, s);
    }
  } else {
    s.current.Add(local);
  }

  float target[3];
  Target(s, target);
  const float most = kRate * static_cast<float>(step) / 1000.0f;
  for (int i = 0; i < 3; ++i) {
    const float d = target[i] - s.out[i];
    s.out[i] += d > most ? most : (d < -most ? -most : d);
  }
  std::copy(s.out, s.out + 3, local);
  return true;
}

namespace uhc {

Outcome ApplySteadyHitpointBars(const Config& config) {
  const Config::Args* args = config.First("steadyHitpointBars");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::vector<std::string> typeNames;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (typeNames.size() == kMaxTypes) {
      Log(L"steadyHitpointBars: more than %u unit types (expected: [UnitType ...] [log]); feature not applied",
          static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      typeNames.push_back(arg);
    }
  }
  if (!VerifyAll("steadyHitpointBars", {&sites::kSteadyBarBone, &sites::kSteadyBarFallback, &sites::kBoneLocalPosition,
                                           &sites::kIsA})) {
    return Outcome::kFailed;
  }
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    if (!RequestAbstractUnitType(typeNames[i].c_str(), &g_types[i])) {
      return Outcome::kFailed;
    }
  }
  g_typeCount = typeNames.size();
  g_units.reserve(1024);
  // test al,al / jz 460633h at 0x45FB24 (8 bytes), inside the verified range 0x45FAE2..0x45FB3F
  if (!WriteJmp(0x0045FB24, reinterpret_cast<const void*>(&UhcSteadyBarHook), 8)) {
    return Outcome::kFailed;
  }
  std::string types;
  for (const std::string& name : typeNames) {
    types += (types.empty() ? "" : ", ") + name;
  }
  Log(L"steadyHitpointBars: floating HP bars hold their position (%hs)%ls (display only)",
      types.empty() ? "every unit" : types.c_str(), g_log ? L", log" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
