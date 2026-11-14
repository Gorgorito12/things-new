// stealthTargeting: a unit in stealth stays hidden from enemies, large units too, and is no target for a
// player that does not see it.
//
// The stock Stealth action (protoaction type 47h, vtable 0xB982A8) sets unit state bit 42h while the unit
// is in its stealth tactic (0x9E8AE5) and clears it when the action ends (0x9E892F); a unit of
// AbstractCanSeeStealth in its LOS forces it out of the tactic (0x9E8C12..0x9E8CC7). The per-unit
// visibility update 0x48679A passes the bit (0x486888) to the per-player visibility 0x486B1A, which writes
// the mask of the players that see the unit, [[unit+B4h]+ACh] (0x486A60). Its small-unit branch skips every
// non-allied player for a stealthed unit (0x486CD0 -> 0x4E0B12). Its footprint branch (0x493040), taken
// when an obstruction radius is over 1.0 (ships, a submarine), never reads the argument: the next
// instruction reuses its stack slot. So every enemy whose LOS covers a large stealthed unit sees it, its
// units attack it on their own, and the AI finds it and sends units.
//
// Two hooks (hooks/stealthtarget_hooks.asm):
// - at 0x493040, a stealthed unit sets the branch's own "only allies see it" byte, so the branch hides it
//   from non-allied players as the small-unit branch does;
// - at the head of 0x489ECC, which the auto-attack search, the unit queries that filter on "attackable"
//   (0x499CE4) and the work orders ask for the attack action an attacker would use on a target, a
//   stealthed target that the attacker's player does not see gets -1, "no attack action". That covers an
//   order on a unit the player saw before it went into stealth (the AI's ships tried it in the test).
// Both read only simulation state (the unit's state bits and the visibility mask), the same on every machine.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcStealthTargetHook();
extern "C" void UhcStealthFootprintHook();

namespace {

constexpr int kMaxLogLines = 200;

bool g_log = false;
int g_logLines = 0;

std::int32_t UnitId(const char* unit) { return *reinterpret_cast<const std::int32_t*>(unit + 0x10); }

std::int32_t PlayerId(const char* unit) {
  const char* player = *reinterpret_cast<const char* const*>(unit + 0x44);
  return player == nullptr ? -1 : *reinterpret_cast<const std::int32_t*>(player);
}

std::int32_t ProtoId(const char* unit) {
  const char* proto = *reinterpret_cast<const char* const*>(unit + 0x5C);
  return proto == nullptr ? -1 : *reinterpret_cast<const std::int32_t*>(proto + 8);
}

}  // namespace

// From the hook, only for a target whose stealth bit is set. True: the attacker's player does not see the
// target, so it gets no attack action.
extern "C" bool __stdcall UhcStealthHidden(const char* attacker, const char* target) {
  if (attacker == nullptr || target == nullptr) {
    return false;
  }
  const std::int32_t player = PlayerId(attacker);
  if (player < 0 || player >= 32 || player == PlayerId(target)) {
    return false;
  }
  const char* visual = *reinterpret_cast<const char* const*>(target + 0xB4);
  if (visual == nullptr) {
    return false;
  }
  const std::uint32_t seenBy = *reinterpret_cast<const std::uint32_t*>(visual + 0xAC);
  if ((seenBy & (1u << player)) != 0) {
    return false;
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"stealthTargeting: unit %d (proto %d, player %d) cannot target stealthed unit %d (proto %d, player %d)",
             UnitId(attacker), ProtoId(attacker), player, UnitId(target), ProtoId(target), PlayerId(target));
  }
  return true;
}

namespace uhc {

Outcome ApplyStealthTargeting(const Config& config) {
  const Config::Args* args = config.First("stealthTargeting");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"stealthTargeting: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("stealthTargeting", {&sites::kAttackActionForTarget, &sites::kAttackActionNone,
                                      &sites::kFootprintVisibility, &sites::kFootprintHiddenTest,
                                      &sites::kFootprintHiddenSkip}) ||
      !WriteJmp(sites::kFootprintVisibility.va, reinterpret_cast<const void*>(&UhcStealthFootprintHook), 8) ||
      !WriteJmp(sites::kAttackActionForTarget.va, reinterpret_cast<const void*>(&UhcStealthTargetHook), 7)) {
    return Outcome::kFailed;
  }
  Log(L"stealthTargeting: stealthed units, large ones too, are hidden from enemies and no target for a player that "
      L"does not see them (multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
