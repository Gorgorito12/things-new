// repairWallGlobal: adds the UI syscall `void repairWallGlobal()`, which orders the repair of every
// wall of the local player, so a command button (`<command>repairWallGlobal</command>` in a
// protounitcommands entry) can repair all walls at once.
//
// Stock repairs one selected wall (the code at 0x7DED97..0x7DEDC3) through
// BGame::commandAutoRepair 0x830AC4 (thiscall(game, int player, int unitId), ret 8; it sends a
// game command, so every machine runs it). The syscall makes the same call for each live unit of
// the local player ([game+3C0h]) whose proto has abstract index 36h (the walls).
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../syscalls.h"

namespace {

using AutoRepair = bool(__thiscall*)(void* game, std::int32_t player, std::int32_t unitId);
using IsAbstractIndex = bool(__thiscall*)(const void* proto, std::int32_t index);
const auto kAutoRepair = reinterpret_cast<AutoRepair>(0x00830AC4);
const auto kIsAbstractIndex = reinterpret_cast<IsAbstractIndex>(0x0044CAC4);

constexpr std::int32_t kWallIndex = 0x36;
bool g_logged = false;

void __cdecl RepairWallGlobal() {
  char* game = *reinterpret_cast<char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : *reinterpret_cast<char* const*>(game + 0x13C);
  if (world == nullptr) {
    return;
  }
  const std::int32_t player = *reinterpret_cast<const std::int32_t*>(game + 0x3C0);
  const char* const* units = *reinterpret_cast<const char* const* const*>(world + 0x0C);
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(world + 0x10);
  if (units == nullptr || count <= 0) {
    return;
  }
  int ordered = 0;
  for (std::int32_t i = 0; i < count; ++i) {
    const char* unit = units[i];
    if (unit == nullptr) {
      continue;
    }
    const std::int32_t* owner = *reinterpret_cast<const std::int32_t* const*>(unit + 0x44);
    const void* proto = *reinterpret_cast<const void* const*>(unit + 0x5C);
    if (owner == nullptr || *owner != player || proto == nullptr || !kIsAbstractIndex(proto, kWallIndex)) {
      continue;
    }
    kAutoRepair(game, player, *reinterpret_cast<const std::int32_t*>(unit + 0x10));
    ++ordered;
  }
  if (!g_logged) {
    g_logged = true;
    uhc::Log(L"hook reached: repairWallGlobal (player %d: %d wall(s) ordered to repair)", player, ordered);
  }
}

}  // namespace

namespace uhc {

Outcome ApplyRepairWallGlobal(const Config& config) {
  if (config.First("repairWallGlobal") == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("repairWallGlobal", {&sites::kCommandAutoRepair, &sites::kIsAbstractIndex})) {
    return Outcome::kFailed;
  }
  if (!InstallSyscallHooks("repairWallGlobal")) {
    return Outcome::kFailed;
  }
  SyscallDef def;
  def.group = SyscallGroup::kUi;
  def.retType = kSyscallVoid;
  def.name = "repairWallGlobal";
  def.fn = reinterpret_cast<const void*>(&RepairWallGlobal);
  def.comment = "Orders the repair of every wall of the local player.";
  def.source = "repairWallGlobal";
  AddSyscall(std::move(def));
  Log(L"repairWallGlobal: UI syscall repairWallGlobal() added");
  return Outcome::kApplied;
}

}  // namespace uhc
