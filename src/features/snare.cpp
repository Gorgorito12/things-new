// snareOnlyHitUnit: a snared unit no longer slows the group it moves with.
//
// Stock: an attack whose tactics action has <TargetSpeedBoost> gives its target a velocity
// modifier (0x48FA07 -> 0x4DD1DE -> 0x4DD22D -> 0x4B3D9E): a unit action of type 2Ch that
// multiplies the velocity by 0.65 for 3000 ms and is exclusive. The target's max velocity (unit
// vtable slot 34h, 0x487E27) drops to 0.65x. A unit in a group does not set its own speed:
// 0x49F3D0 only marks the group dirty, and the group recompute FUN_004FD289 sets the group's pace
// [group+7Ch] to the slowest member's velocity, the snared one included. The group, and every
// member with it, then moves at 0.65x for 3 s. A member that falls more than 2.0 behind its
// formation slot also sets group bit 7 (0x4FA17D; 0x6AA514 and 0x6AA56A for a member with its own
// path), and the group then moves at 0.8333x its pace (0x4FAAA5) until the member is back.
//
// snareOnlyHitUnit: in the group recompute, a member with an active snare counts with its
// velocity without the snare (the stock modifier sum replayed with the snares left out); and
// while the snare lasts, the member does not set bit 7. The snared unit keeps its own 0.65x: a
// member never walks faster than its own velocity (0x4F9BCB). When the snare ends, the stock rule
// applies again: a unit still more than 2.0 behind its slot makes the group wait for it at
// 0.8333x. The hooks are in hooks/snare_hooks.asm.
#include <cstdint>
#include <cstring>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifiers.h"
#include "../patch.h"

namespace {

using uhc::modifiers::ModifierList;
using uhc::modifiers::Walk;
using uhc::modifiers::WalkModifiers;

// Engine layout (docs/engine-symbols.md, "Snare and group movement").
constexpr std::uint32_t kGameGlobal = 0x00C66234;      // game; +13Ch world
constexpr std::uint32_t kMovementModIdPtr = 0x00CEFFA0;  // -> the ID of the cfg float MovementMod
constexpr std::uint32_t kGameConfig = 0x00C66500;       // the game's cfg values

constexpr std::int32_t kStatVelocity = 0;
constexpr std::int32_t kOpSet = 0;
constexpr std::int32_t kOpAdd = 1;
constexpr std::int32_t kOpMultiply = 2;
constexpr std::uint32_t kFlagTimed = 0x15;      // the modifier has a duration (0x4B3D6D)
constexpr std::uint32_t kFlagExclusive = 0x16;  // the modifier sum stops after it (0x4B3CDA)
constexpr std::uint32_t kTacticModifyExclusive = 33;  // the same, from <ModifyExclusive> (0x6A88D6)
constexpr float kNoVelocityRecord = -1.0e-6f;   // 0xB9FB60: the per-unit velocity is unset

using GetVelocityFn = float(__thiscall*)(const char* unit);
using CfgFloatFn = bool(__thiscall*)(void* config, std::int32_t id, float* value);
const auto kCfgFloat = reinterpret_cast<CfgFloatFn>(0x0044734C);

bool g_log = false;  // "snareOnlyHitUnit log": log each snared member once per snare
// Unit ID -> the snare last logged for it, one map per log line.
std::unordered_map<std::int32_t, const char*> g_loggedPace;
std::unordered_map<std::int32_t, const char*> g_loggedWait;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// A bitset {bytes at +0, bit count at +4} at `offset` in an object, read like 0x4B3CDA does.
bool Bit(const char* object, std::uint32_t offset, std::uint32_t bit) {
  if (Field<std::uint32_t>(object, offset + 4) <= bit) {
    return false;
  }
  const auto* bytes = Field<const std::uint8_t*>(object, offset);
  return bytes != nullptr && (bytes[bit >> 3] & (1u << (bit & 7))) != 0;
}

// The snare of 0x4DD1DE: a velocity modifier that multiplies, has a duration and is exclusive.
// The only other timed creator, <SpeedBoost> (0x4B3E31), is not exclusive; the untimed ones
// (auras, <ModifyExclusive> auras included) have no duration flag.
bool IsSnare(const char* action) {
  return Field<std::int32_t>(action, 0x64) == kStatVelocity && Field<std::int32_t>(action, 0x78) == kOpMultiply &&
         Bit(action, 0x30, kFlagTimed) && Bit(action, 0x30, kFlagExclusive);
}

// The first active snare on the unit, or nullptr. A tree deeper than modifiers::kMaxDepth counts
// as "not snared", which runs the stock code.
const char* FindSnare(const char* unit) {
  const char* list = unit == nullptr ? nullptr : ModifierList(unit);
  if (list == nullptr || Field<const char*>(unit, 0x5C) == nullptr) {
    return nullptr;
  }
  const char* snare = nullptr;
  auto visit = [&snare](const char* action) {
    if (IsSnare(action)) {
      snare = action;
      return false;
    }
    return true;
  };
  return WalkModifiers(list, visit, 0) == Walk::kStopped ? snare : nullptr;
}

// The unit's max velocity as 0x487E27 returns it, with the snares left out of the modifier sum
// 0x4B3C48 / 0x4B3C7D. False if the action tree is deeper than modifiers::kMaxDepth.
bool VelocityWithoutSnares(const char* unit, float* velocity) {
  const float base = Field<float>(Field<const char*>(unit, 0x5C), 0x80);  // proto MaxVelocity
  float sum = base;
  bool matched = false;
  auto visit = [&sum, &matched](const char* action) {
    if (Field<std::int32_t>(action, 0x64) != kStatVelocity || IsSnare(action)) {
      return true;
    }
    matched = true;
    const float value = Field<float>(action, 0x68);
    switch (Field<std::int32_t>(action, 0x78)) {
      case kOpSet:
        sum = value;
        break;
      case kOpAdd:
        sum = value + sum;
        break;
      case kOpMultiply:
        sum = value * sum;
        break;
      default:  // 0x4E2AA2: any other operation is ignored
        break;
    }
    if (Bit(action, 0x30, kFlagExclusive)) {
      return false;
    }
    const char* tactic = Field<const char*>(action, 0x04);
    return tactic == nullptr || !Bit(tactic, 0x64, kTacticModifyExclusive);
  };
  if (WalkModifiers(ModifierList(unit), visit, 0) == Walk::kTooDeep) {
    return false;
  }
  // 0x4B3C48 stores the sum in the unit's record [[unit+B4h]+C8h] only when a modifier matched;
  // 0x487E27 reads the record when it is above -1e-6, the proto's MaxVelocity otherwise, and
  // multiplies by the cfg float MovementMod (1.0 when it is not set).
  const char* ext = Field<const char*>(unit, 0xB4);
  const bool hasRecord = ext != nullptr && Field<const char*>(ext, 0xC8) != nullptr;
  const float own = hasRecord && matched && sum > kNoVelocityRecord ? sum : base;
  float movementMod = 1.0f;
  kCfgFloat(reinterpret_cast<void*>(kGameConfig), **reinterpret_cast<const std::int32_t* const*>(kMovementModIdPtr),
            &movementMod);
  *velocity = movementMod * own;
  return true;
}

float StockVelocity(const char* unit) {
  return (*reinterpret_cast<GetVelocityFn* const*>(unit))[0x34 / 4](unit);
}

std::int32_t UnitId(const char* unit) { return Field<std::int32_t>(unit, 0x10); }

// A unit's proto is at [unit+5Ch]; its name, for the log, at [proto+10h].
const char* ProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

// True the first time this snare is seen for this unit.
bool FirstForSnare(std::unordered_map<std::int32_t, const char*>* seen, const char* unit, const char* snare) {
  auto [it, inserted] = seen->try_emplace(UnitId(unit), snare);
  if (!inserted && it->second == snare) {
    return false;
  }
  it->second = snare;
  return true;
}

// Units by ID: [world+0Ch] array, [world+10h] count; the low 18 bits index the array and
// [unit+10h] must equal the full ID (the lookup at 0x4F9EB7).
const char* UnitById(std::int32_t id) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && UnitId(unit) == id ? unit : nullptr;
}

// "log": a unit seen without a snare forgets the one it had, so a later snare is logged even when
// the engine allocates it at the same address.
void ForgetSnare(const char* unit) {
  g_loggedPace.erase(UnitId(unit));
  g_loggedWait.erase(UnitId(unit));
}

bool SkipsWait(const char* member, std::uint32_t site) {
  const char* snare = FindSnare(member);
  if (snare == nullptr) {
    if (g_log) {
      ForgetSnare(member);
    }
    return false;
  }
  if (g_log && FirstForSnare(&g_loggedWait, member, snare)) {
    uhc::Log(L"snareOnlyHitUnit: unit %d (%hs) is snared and lags behind its formation slot; its group does not "
             L"wait for it (0x%06X)",
             UnitId(member), ProtoName(member), site);
  }
  return true;
}

}  // namespace

// For snareValues: a modifier that is a snare, by the same test.
extern "C" bool __stdcall UhcIsSnareModifier(const char* action) { return IsSnare(action); }

extern "C" {
void UhcSnareGroupPaceHook();
void UhcSnareSlotWaitHook();
void UhcSnarePathWaitHook();
void UhcSnarePathCheckHook();

// Group recompute (0x4FD3FD): for a member with an active snare, lowers the group's pace
// [group+7Ch] to the member's velocity without the snare, as the stock code does with its
// velocity, and returns true. False: the hook runs the stock compare.
bool __stdcall UhcSnareGroupPace(const char* member, char* group) {
  const char* snare = FindSnare(member);
  float velocity = 0.0f;
  if (snare == nullptr && g_log) {
    ForgetSnare(member);
  }
  if (snare == nullptr || !VelocityWithoutSnares(member, &velocity)) {
    return false;
  }
  // A float compare of the rounded value gives the stock result (an extended-precision fcomp,
  // then fstp): the same decision and the same stored float.
  float* pace = reinterpret_cast<float*>(group + 0x7C);
  if (velocity < *pace) {
    *pace = velocity;
  }
  if (g_log && FirstForSnare(&g_loggedPace, member, snare)) {
    uhc::Log(L"snareOnlyHitUnit: unit %d (%hs) is snared; it counts %.3f instead of %.3f toward its group's pace",
             UnitId(member), ProtoName(member), velocity, StockVelocity(member));
  }
  return true;
}

// Straggler checks 0x4FA17D and 0x6AA514: true if the member is snared, so the group must not
// wait for it.
bool __stdcall UhcSnareSkipsWait(const char* member, std::uint32_t site) { return SkipsWait(member, site); }

// Straggler check 0x6AA56A, where only the member's ID is left in a register.
bool __stdcall UhcSnareSkipsWaitById(std::int32_t memberId) {
  const char* member = UnitById(memberId);
  return member != nullptr && SkipsWait(member, 0x6AA56A);
}
}

namespace uhc {

Outcome ApplySnareOnlyHitUnit(const Config& config) {
  const Config::Args* args = config.First("snareOnlyHitUnit");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"snareOnlyHitUnit: unknown argument %hs (expected: log); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  // The hook sites and their continuations, then the stock code the helpers mirror.
  if (!VerifyAll("snareOnlyHitUnit",
                 {&sites::kSnareGroupPace, &sites::kSnareGroupPaceStore, &sites::kSnareSlotWait,
                  &sites::kSnarePathWait, &sites::kSnarePathCheck, &sites::kSnareCreate, &sites::kSnareModifierInit,
                  &sites::kSnareCollector, &sites::kSnareModifierSum, &sites::kSnareModifierSumEnd,
                  &sites::kSnareModifierSumTactic, &sites::kSnareVelocityGetter, &sites::kSnareVelocityRecord,
                  &sites::kSnareUnitById})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kSnareGroupPace.va, reinterpret_cast<const void*>(&UhcSnareGroupPaceHook), 0x1A) ||
      !WriteJmp(0x004FA17D, reinterpret_cast<const void*>(&UhcSnareSlotWaitHook), 6) ||
      !WriteJmp(0x006AA514, reinterpret_cast<const void*>(&UhcSnarePathWaitHook), 6) ||
      !WriteJmp(0x006AA56A, reinterpret_cast<const void*>(&UhcSnarePathCheckHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"snareOnlyHitUnit: a snared unit (TargetSpeedBoost) no longer slows its group; the group neither paces at "
      L"nor waits for it while the snare lasts%ls (multiplayer unverified)",
      g_log ? L", every snared member logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
