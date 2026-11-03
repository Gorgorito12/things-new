// Small fixes that change a few bytes of stock code, one key each:
//
// rofFix: ordering a unit to use an ability or command (FUN_009CEB5C) clears the unit AI's
//   [+B8h] at 0x9CECB4 before issuing the order, which lets a unit reset its timer by giving
//   orders. The key removes that store.
// stunMovingTargetFix: a stun action (BUnitStunAction's update, state 8) ends when its target
//   check fails (jne at 0x9E909E skips setState(0Ah) only on success), so a target that moves
//   escapes the stun. The key makes that jne a jmp, so the action goes on.
// noDamageOnUnbuiltFoundations: the damage function (FUN_0049B3D9) gives no damage to a unit
//   whose proto has flag 9Ch (Invulnerable), tested at 0x49B3F3. The key also gives none to a
//   building (abstract index 2) whose construction [[unit+68h]+8] has not started (at most
//   1e-6), unless the attacking player's byte [+505h] is set (an effect at 0x7FB85B sets it while
//   it changes that player's diplomacy with every other player).
#include <cstdint>
#include <cstring>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcInvulnerableTestHook();

namespace {

using IsAbstractIndex = bool(__thiscall*)(const void* proto, std::int32_t index);
using PlayerById = char*(__thiscall*)(void* world, std::int32_t id);
const auto kIsAbstractIndex = reinterpret_cast<IsAbstractIndex>(0x0044CAC4);
const auto kPlayerById = reinterpret_cast<PlayerById>(0x0044CB21);
bool g_loggedFoundation = false;

}  // namespace

extern "C" bool __stdcall UhcTakesNoDamage(const char* unit, std::int32_t attacker) {
  const char* proto = *reinterpret_cast<char* const*>(unit + 0x5C);
  const std::uint8_t* flags = *reinterpret_cast<const std::uint8_t* const*>(proto + 0x50);
  const std::uint32_t bits = *reinterpret_cast<const std::uint32_t*>(proto + 0x54);
  if (bits > 0x9C && flags != nullptr && (flags[0x13] & 0x10) != 0) {
    return true;  // stock: Invulnerable
  }
  if (!kIsAbstractIndex(proto, 2)) {
    return false;
  }
  const char* game = *reinterpret_cast<char* const*>(0x00C66234);
  void* world = game == nullptr ? nullptr : *reinterpret_cast<void* const*>(game + 0x13C);
  const char* player = world == nullptr ? nullptr : kPlayerById(world, attacker);
  const char* building = *reinterpret_cast<char* const*>(unit + 0x68);
  if (player == nullptr || player[0x505] != 0 || building == nullptr ||
      !(*reinterpret_cast<const float*>(building + 8) <= 1e-6f)) {
    return false;
  }
  if (!g_loggedFoundation) {
    g_loggedFoundation = true;
    uhc::Log(L"noDamageOnUnbuiltFoundations: %hs (an unbuilt foundation) took no damage from player %d",
             *reinterpret_cast<char* const*>(proto + 0x10), attacker);
  }
  return true;
}

namespace uhc {

Outcome ApplyNoDamageOnUnbuiltFoundations(const Config& config) {
  if (config.First("noDamageOnUnbuiltFoundations") == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("noDamageOnUnbuiltFoundations",
                 {&sites::kDamageInvulnerableTest, &sites::kIsAbstractIndex, &sites::kPlayerById})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kDamageInvulnerableTest.va, reinterpret_cast<const void*>(&UhcInvulnerableTestHook),
                sites::kDamageInvulnerableTest.size)) {
    return Outcome::kFailed;
  }
  Log(L"noDamageOnUnbuiltFoundations: foundations whose construction has not started take no damage");
  return Outcome::kApplied;
}

Outcome ApplyRofFix(const Config& config) {
  if (config.First("rofFix") == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("rofFix", {&sites::kRofTimerReset})) {
    return Outcome::kFailed;
  }
  std::uint8_t nops[10];
  std::memset(nops, 0x90, sizeof nops);
  if (!WriteBytes(sites::kRofTimerReset.va, nops, sizeof nops)) {
    return Outcome::kFailed;
  }
  Log(L"rofFix: giving an order no longer clears the unit's timer");
  return Outcome::kApplied;
}

Outcome ApplyStunMovingTargetFix(const Config& config) {
  if (config.First("stunMovingTargetFix") == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("stunMovingTargetFix", {&sites::kStunTargetCheck})) {
    return Outcome::kFailed;
  }
  const std::uint8_t jmp = 0xEB;  // jne rel8 -> jmp rel8, same target
  if (!WriteBytes(sites::kStunTargetCheck.va, &jmp, 1)) {
    return Outcome::kFailed;
  }
  Log(L"stunMovingTargetFix: a stun action no longer ends when its target check fails");
  return Outcome::kApplied;
}

}  // namespace uhc
