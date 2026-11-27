// herdWalkAwayFix: a herdable that walks away from its pen or magnet once fattened stays where it walked to.
//
// When a herdable that gathers into its own inventory is full and its target is a LivestockPen, the paddy or a unit
// of the abstract type AbstractTypeHerdableMagnet, the gather tick's cold path (0x6A8C47..0x6A8CA8) moves it away from
// the target: 0x4E3A37(mgr, targetId, 6.0f, 0), the flee move, called at 0x6A8C9C. Its action manager's leash anchor
// [mgr+7Ch] (x, y, z) is not touched there, and the manager's leash (0x489B15) walks an idle unit back to it. The
// anchor of a herdable the stock search pulled in (0x4C31EE) is where it stood before, so with a target that moves (a
// nomad), a fattened herdable walks back across the map to where the herd once was.
//
// The call at 0x6A8C9C is redirected to a wrapper that makes the stock call, then puts the anchor on the line from the
// target through the herdable, 6 m further out than the herdable stands: about where the flee takes it (its point
// carries a synced random part, so not exactly). Simulation state only; the same on every machine.
#include <cmath>
#include <cstdint>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr float kWalkAway = 6.0f;

using FleeFn = bool(__thiscall*)(char* mgr, std::int32_t target, float distance, std::int32_t flag);
const auto kFlee = reinterpret_cast<FleeFn>(0x004E3A37);

bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

const char* UnitById(std::int32_t id) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

// thiscall(mgr, target, distance, flag), ret 0Ch: __fastcall with an unused EDX has the same frame.
bool __fastcall WalkAway(char* mgr, void* /*edx*/, std::int32_t target, float distance, std::int32_t flag) {
  const bool moved = kFlee(mgr, target, distance, flag);
  const char* unit = mgr == nullptr ? nullptr : Field<const char*>(mgr, 0x04);
  const char* from = UnitById(target);
  if (unit == nullptr || from == nullptr) {
    return moved;
  }
  const float ux = Field<float>(unit, 0x14), uz = Field<float>(unit, 0x1C);
  const float tx = Field<float>(from, 0x14), tz = Field<float>(from, 0x1C);
  const float dx = ux - tx, dz = uz - tz;
  const float length = std::sqrt(dx * dx + dz * dz);
  float* anchor = reinterpret_cast<float*>(mgr + 0x7C);
  if (length > 0.01f) {
    anchor[0] = ux + dx / length * kWalkAway;
    anchor[2] = uz + dz / length * kWalkAway;
  } else {
    anchor[0] = ux;
    anchor[2] = uz;
  }
  anchor[1] = Field<float>(unit, 0x18);
  if (g_log && g_logLines < 200) {
    ++g_logLines;
    uhc::Log(L"herdWalkAwayFix: unit %d walks away from unit %d at (%.1f, %.1f): anchor (%.1f, %.1f)",
             Field<std::int32_t>(unit, 0x10), target, static_cast<double>(ux), static_cast<double>(uz),
             static_cast<double>(anchor[0]), static_cast<double>(anchor[2]));
  }
  return moved;
}

}  // namespace

namespace uhc {

Outcome ApplyHerdWalkAwayFix(const Config& config) {
  const Config::Args* args = config.First("herdWalkAwayFix");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    Log(L"herdWalkAwayFix: bad argument %hs (expected [log]); feature not applied", arg.c_str());
    return Outcome::kFailed;
  }
  if (!VerifyAll("herdWalkAwayFix", {&sites::kHerdWalkAwayCall, &sites::kHerdFleeHead}) ||
      !WriteCall(sites::kHerdWalkAwayCall.va + 8, reinterpret_cast<const void*>(&WalkAway))) {
    return Outcome::kFailed;
  }
  Log(L"herdWalkAwayFix: a herdable walked away from its pen or magnet keeps its leash anchor there");
  return Outcome::kApplied;
}

}  // namespace uhc
