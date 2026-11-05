// hcTargetTechs: <Flag>HCTargetEnemy</Flag> and <Flag>HCTargetAll</Flag> on a tech send its effects to
// the owner's enemies, or to every player, instead of to the owner.
//
// A team tech keeps its list inside three routines: applyEffects 0x94DAE1, removeEffects 0x94DCB2 and the
// pass after a load 0x94DDEA, each with its own copy of the loop over the team. So the key wraps the
// three: for a marked tech it calls the stock routine once per target, without the team flag. The tech
// stays active in the owner's tree only; a load and a removal go through the owner, and the targets are
// counted again then. The flag's reader is hooked too: the stock chain ignores a name it does not know.
// The hooks are in hooks/hctarget_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcTechFlagHook();
void UhcTechRemoveStock();
void UhcTechLoadStock();
}

namespace {

enum class Target { kEnemies, kAll };

constexpr std::uint32_t kFlagHead = 0x00620C2F;
constexpr std::uint32_t kApplyCall = 0x0094D0AE;
constexpr std::uint32_t kRemoveHead = 0x0094DCB2;
constexpr std::uint32_t kLoadHead = 0x0094DDEA;
constexpr std::size_t kWorld = 0x13C;
constexpr std::size_t kPlayerCount = 0x5C;
constexpr int kMaxLogLines = 200;

using ApplyFn = bool(__thiscall*)(char* tech, char* player, void* unit, std::uint32_t team, std::int32_t a,
                                  std::int32_t b);
const auto kApply = reinterpret_cast<ApplyFn>(0x0094DAE1);
using RemoveFn = bool(__thiscall*)(char* tech, char* player, std::int32_t a, std::uint32_t team);
const auto kRemove = reinterpret_cast<RemoveFn>(&UhcTechRemoveStock);
const auto kLoad = reinterpret_cast<RemoveFn>(&UhcTechLoadStock);
using PlayerByIdFn = char*(__thiscall*)(const char* world, std::int32_t id);
const auto kPlayerById = reinterpret_cast<PlayerByIdFn>(0x0044CB21);
using IsEnemyFn = bool(__thiscall*)(const char* player, std::int32_t other);
const auto kIsEnemy = reinterpret_cast<IsEnemyFn>(0x00484D2D);

std::unordered_map<const void*, Target> g_techs;  // filled while the techs load, read-only after
bool g_log = false;
int g_logLines = 0;

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
  return game == nullptr ? nullptr : *reinterpret_cast<const char* const*>(game + kWorld);
}

template <typename Call>
void ForTargets(Target target, const char* player, Call call) {
  const char* world = World();
  if (world == nullptr) {
    return;
  }
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(world + kPlayerCount);
  for (std::int32_t id = 1; id < count; ++id) {
    char* other = kPlayerById(world, id);
    if (other != nullptr && (target == Target::kAll || kIsEnemy(player, id))) {
      call(other);
    }
  }
}

void Note(const wchar_t* what, const char* tech, const char* player) {
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"hcTargetTechs: %ls tech %d of player %d", what, *reinterpret_cast<const std::int32_t*>(tech),
             *reinterpret_cast<const std::int32_t*>(player));
  }
}

bool __fastcall Apply(char* tech, void*, char* player, void* unit, std::uint32_t team, std::int32_t a, std::int32_t b) {
  const auto found = g_techs.find(tech);
  if (found == g_techs.end()) {
    return kApply(tech, player, unit, team, a, b);
  }
  Note(L"apply", tech, player);
  bool done = true;
  ForTargets(found->second, player, [&](char* other) {
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"hcTargetTechs: effects on player %d", *reinterpret_cast<const std::int32_t*>(other));
    }
    done = kApply(tech, other, nullptr, team & ~0xFFu, a, b) && done;
  });
  return done;
}

}  // namespace

// From the head of the flag reader: true for the two flags of the key, which stock would ignore.
extern "C" bool __stdcall UhcTechFlag(char* entry, const char* name) {
  const bool enemy = name != nullptr && _stricmp(name, "HCTargetEnemy") == 0;
  if (!enemy && (name == nullptr || _stricmp(name, "HCTargetAll") != 0)) {
    return false;
  }
  g_techs[*reinterpret_cast<void* const*>(entry)] = enemy ? Target::kEnemies : Target::kAll;
  if (g_log) {
    uhc::Log(L"hcTargetTechs: %hs read", name);
  }
  return true;
}

// Both replace the head of the routine, through a jmp: same arguments, same ret 0Ch.
extern "C" bool __fastcall UhcTechRemove(char* tech, void*, char* player, std::int32_t a, std::uint32_t team) {
  const auto found = g_techs.find(tech);
  if (found == g_techs.end()) {
    return kRemove(tech, player, a, team);
  }
  Note(L"remove", tech, player);
  bool done = true;
  ForTargets(found->second, player, [&](char* other) { done = kRemove(tech, other, a, team & ~0xFFu) && done; });
  return done;
}

extern "C" bool __fastcall UhcTechLoad(char* tech, void*, char* player, std::int32_t a, std::uint32_t team) {
  const auto found = g_techs.find(tech);
  if (found == g_techs.end()) {
    return kLoad(tech, player, a, team);
  }
  Note(L"load", tech, player);
  bool done = true;
  ForTargets(found->second, player, [&](char* other) { done = kLoad(tech, other, a, team & ~0xFFu) && done; });
  return done;
}

namespace uhc {

Outcome ApplyHcTargetTechs(const Config& config) {
  const Config::Args* args = config.First("hcTargetTechs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"hcTargetTechs: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("hcTargetTechs", {&sites::kTechFlagHead, &sites::kTechApplyCall, &sites::kTechRemoveHead,
                                   &sites::kTechLoadHead, &sites::kIsEnemyHead}) ||
      !WriteJmp(kFlagHead, reinterpret_cast<const void*>(&UhcTechFlagHook), 5) ||
      !WriteCall(kApplyCall, reinterpret_cast<const void*>(&Apply)) ||
      !WriteJmp(kRemoveHead, reinterpret_cast<const void*>(&UhcTechRemove), 6) ||
      !WriteJmp(kLoadHead, reinterpret_cast<const void*>(&UhcTechLoad), 7)) {
    return Outcome::kFailed;
  }
  Log(L"hcTargetTechs: the tech flags HCTargetEnemy and HCTargetAll are on");
  return Outcome::kApplied;
}

}  // namespace uhc
