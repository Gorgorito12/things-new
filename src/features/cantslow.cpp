// cantBeSlowed: a unit whose proto has the abstract type CantBeSlowed ignores <TargetSpeedBoost>.
// (An attacker that should not snare has the snare removed from that attack in its tactics; the key does
// not read a type on the attacker.)
//
// Stock snares a target at one place: 0x4DD1DE tests that it can move, and 0x4DD201 pushes the arguments
// of the modifier's creator 0x4DD22D. The hook leaves through the snare's exit for a marked target.
// damageOverTime's snare asks UhcCantBeSlowed too. The hook is in hooks/cantslow_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" void UhcCantBeSlowedHook();

namespace {

constexpr int kMaxLogLines = 200;

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

bool g_log = false;
int g_logLines = 0;
std::int32_t g_type = -1;

bool HasType(const char* unit, std::int32_t type) {
  if (unit == nullptr || type < 0) {
    return false;
  }
  const char* proto = *reinterpret_cast<const char* const*>(unit + 0x5C);
  return proto != nullptr && kProtoIsType(proto, type);
}

std::int32_t ProtoId(const char* unit) {
  return *reinterpret_cast<const std::int32_t*>(*reinterpret_cast<const char* const*>(unit + 0x5C) + 8);
}

}  // namespace

// From the hook and from damageOverTime, with the target. True: no snare.
extern "C" bool __stdcall UhcCantBeSlowed(const char* unit) {
  if (!HasType(unit, g_type)) {
    return false;
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"cantBeSlowed: proto %d ignores a snare", ProtoId(unit));
  }
  return true;
}

namespace uhc {

Outcome ApplyCantBeSlowed(const Config& config) {
  const Config::Args* args = config.First("cantBeSlowed");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"cantBeSlowed: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("cantBeSlowed", {&sites::kSnareCreate}) || !RequestAbstractUnitType("CantBeSlowed", &g_type) ||
      !WriteJmp(sites::kSnareCreate.va, reinterpret_cast<const void*>(&UhcCantBeSlowedHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"cantBeSlowed: the abstract type CantBeSlowed (on the target) is on");
  return Outcome::kApplied;
}

}  // namespace uhc
