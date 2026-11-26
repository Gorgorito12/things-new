// retargetInAction [log]: an attack with <RetargetInAction>1</RetargetInAction> whose target dies (or goes away) while
// the unit still has shots of the current attack to fire keeps firing them, at a new target the attack could take.
//
// Stock: an attack unit action (vtable 0xB96278) fires a shot at each Attack tag of its attack animation while it is in
// state 1 (the event handler 0x48CED0, event 5 -> 0x48F739: the shot needs state 1 or tactic flag 4), so an animation
// with six Attack tags (a machine gun's) fires six shots a cycle. Its update FUN_0048A330 checks the target [ua+14h]
// first: no unit, not alive (vtable +A4h) or inside another unit (0x48A3F9) sends it to 0x487838, which in state 1 or
// 15h sets state 19h (the wait after the cycle, where Attack tags fire nothing; the update itself does nothing in 19h,
// 0x48A413), so the tags left in the animation are lost, and in other states ends the attack (setState 0Ah). Once the
// wait is over, the unit takes its next target (the same unit action, reset: [ua+14h] -1 and [ua+68h] 0 from
// 0x4719F3 and 0x472CE8, traced) and starts a new cycle from the start of its animation.
//
// The hook (hooks/retarget_hooks.asm, at 0x487838) asks UhcRetargetAction for a tagged action in state 1, the attack
// animation (Attack tags still to come, or a numberOfShots burst's quick shot, whose "hold" pose keeps the unit in its
// attack animation until the next shot): it looks for a new target with the tests the update itself makes on a target
// at every update, and writes its ID to [ua+14h]; the update then starts again at its target read 0x48A359 and goes on
// with it. The unit action stays the same: its shot count [ua+68h], its cycle and its animation go on, so the next
// Attack tag (or the burst's next shot) fires at the new target, and the projectiles launched from then on fly to it.
// With no target, and in any other state (a target lost during the reload wait), the stock code runs.
//
// The search, made only when a target is lost: the units within the action's range [ua+24h] plus kSearchSlack of the
// unit (the world's spatial query 0x4A1C55), each one alive, not inside another unit, one the unit's current tactic
// would use this very attack on (0x489ECC, with the update's own arguments: enemies only, the action's targets and
// types), in range (the unit's vtable +CCh with [ua+24h], as 0x48A5C8) and seen by the unit's player (0x48A9EF, as
// 0x48A605), and of the tactic's <autoattacktype> [tactic+174h] when it has one (0x44D7FA, as the automatic search's
// test 0x4A1A0E). The nearest wins (the unit's vtable +BCh, as 0x48A59B), then the lowest ID.
//
// An attack launched by a power (its power use [ua+6Ch] not 0, as an explorer's sharpshooter ability) is not the
// attack the tactic would pick for its targets (a guardian gets the normal ranged attack), and the update does not ask
// the tactic for it (0x48A4C2 -> 0x4F6F61 -> 0x48A58D). For such an attack a candidate is taken by the action's own
// rates instead of 0x489ECC and the <autoattacktype>: a rate above 0 for it (the lookup 0x487C45, its <rate type>s),
// not an ally of the unit's player (0x484E01) and, unless the action's flag 0Dh is set, an enemy (the diplomacy
// [player+1D4h+4*ID] = 2), as 0x489ECC tests the relation; then in range and seen as above.
#include <windows.h>

#include <compare>
#include <cstdint>
#include <cstdio>
#include <cwchar>
#include <map>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../rofreads.h"
#include "../unittypes.h"

extern "C" {
void UhcRetargetHook();  // hooks/retarget_hooks.asm
// Above 0 while some attack action carries <RetargetInAction>: the hook asks UhcRetargetAction only then.
std::int32_t g_uhcRetargetOn = 0;
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr float kSearchSlack = 12.0f;              // metres added to the search radius: the largest target's half size
constexpr std::uint8_t kStateFiring = 0x01;        // the attack animation: its Attack tags fire
constexpr std::int32_t kFlagNoRelation = 0x0D;     // unit action flag the update tests before 0x489ECC (0x48A4D9)
constexpr unsigned kMaxLogLines = 300;
constexpr unsigned kMaxShotLines = 200;

struct IdList {
  std::int32_t* data;
  std::int32_t count;
  std::int32_t capacity;
};

using UnitsNearFn = std::int32_t(__thiscall*)(const char* world, const float* point, float radius, char precise,
                                             IdList* out);
using AttackForFn = std::int32_t(__thiscall*)(const char* tactic, const char* attacker, const char* target,
                                              std::int32_t a3, std::int32_t a4, std::int32_t a5, std::int32_t a6,
                                              float range);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
using RateForFn = float(__thiscall*)(const char* action, const char* target);
using IsAllyFn = bool(__thiscall*)(const char* player, std::int32_t otherPlayer);
using SeeableFn = bool(__thiscall*)(const char* unit, std::int32_t player);
using AliveFn = bool(__thiscall*)(const char* unit);
using InRangeFn = bool(__thiscall*)(const char* unit, const char* target, float range);
using DistanceFn = float(__thiscall*)(const char* unit, const char* target);

const auto kUnitsNear = reinterpret_cast<UnitsNearFn>(0x004A1C55);
const auto kAttackFor = reinterpret_cast<AttackForFn>(0x00489ECC);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);
const auto kIsSeeable = reinterpret_cast<SeeableFn>(0x0048A9EF);
const auto kRateFor = reinterpret_cast<RateForFn>(0x00487C45);
const auto kIsAlly = reinterpret_cast<IsAllyFn>(0x00484E01);

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* World() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

const char* Database() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

std::int32_t Now(const char* world) { return world == nullptr ? 0 : Field<std::int32_t>(world, 0x108); }

const wchar_t* ActionName(std::int32_t index) {
  const char* database = Database();
  if (database == nullptr || index < 0 || index >= Field<std::int32_t>(database, 0x1FDC)) {
    return L"?";
  }
  const wchar_t* name = Field<const wchar_t* const*>(database, 0x1FD8)[index];
  return name != nullptr ? name : L"?";
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name != nullptr ? name : "?";
}

const char* UnitById(const char* world, std::int32_t id) {
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

template <typename Fn>
Fn Virtual(const char* object, std::uint32_t slot) {
  return reinterpret_cast<Fn>(Field<const void* const*>(object, 0)[slot / 4]);
}

bool Alive(const char* unit) { return Virtual<AliveFn>(unit, 0xA4)(unit); }

// 0x48A3F9: the unit's current action [[unit+58h]+24h] is of type 2Bh (inside another unit).
bool Inside(const char* unit) {
  const char* manager = Field<const char*>(unit, 0x58);
  const char* current = manager == nullptr ? nullptr : Field<const char*>(manager, 0x24);
  return current != nullptr && Field<std::uint8_t>(current, 0x60) == 0x2B;
}

// A unit action's flag bit (the bitset [ua+30h], its bit count [ua+34h]).
bool FlagBit(const char* unitAction, std::int32_t bit) {
  if (Field<std::uint32_t>(unitAction, 0x34) <= static_cast<std::uint32_t>(bit)) {
    return false;
  }
  return (Field<const std::uint8_t*>(unitAction, 0x30)[bit >> 3] & (1u << (bit & 7))) != 0;
}

// The unit's current tactic: [[unit+5Ch]+44h] holds the proto's tactics (+10h the list, +14h the count), the action
// manager [unit+58h] the index +0A8h (as 0x48A533..0x48A56E read it).
const char* CurrentTactic(const char* unit) {
  const char* manager = Field<const char*>(unit, 0x58);
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* tactics = proto == nullptr ? nullptr : Field<const char*>(proto, 0x44);
  if (manager == nullptr || tactics == nullptr) {
    return nullptr;
  }
  const std::int32_t index = Field<std::int32_t>(manager, 0xA8);
  if (index < 0 || index >= Field<std::int32_t>(tactics, 0x14)) {
    return nullptr;
  }
  return Field<const char* const*>(tactics, 0x10)[index];
}

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

// Filled while the data loads (a later tag of the same action wins); true retargets, false only logs (a control).
std::map<ActionKey, bool> g_entries;
IdList g_found = {nullptr, 0, 0};  // FUN_004A1C55's output, reused
// One retarget per action per update call: the update goes again from its target read after one.
const char* g_lastAction = nullptr;
std::int32_t g_lastTime = -1;
bool g_log = false;
unsigned g_logLines = 0;
unsigned g_shotLines = 0;
unsigned g_tagLines = 0;
unsigned g_invalidLines = 0;
std::uint32_t g_retargets = 0;
std::uint32_t g_misses = 0;

std::int32_t __stdcall RetargetShotLog(const char* unitAction, std::int32_t rof, uhc::RofRead read);

void SyncGates() {
  bool on = false;
  for (const auto& [key, enabled] : g_entries) {
    on = on || enabled || g_log;
  }
  g_uhcRetargetOn = on ? 1 : 0;
  if (g_log) {
    uhc::SetRofGate(&RetargetShotLog, !g_entries.empty());
  }
}

void ResetForDataLoad(char*) {
  g_entries.clear();
  g_lastAction = nullptr;
  g_lastTime = -1;
  g_logLines = 0;
  g_shotLines = 0;
  g_tagLines = 0;
  g_invalidLines = 0;
  SyncGates();
}

const bool* Find(const char* unitAction) {
  const char* action = Field<const char*>(unitAction, 0x04);
  const char* unit = Field<const char*>(unitAction, 0x10);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (action == nullptr || proto == nullptr) {
    return nullptr;
  }
  const auto found = g_entries.find(ActionKey{Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)});
  return found == g_entries.end() ? nullptr : &found->second;
}

// "log": each shot of a tagged action (the after-shot ROF read), with its target, so a test shows where the shots went.
std::int32_t __stdcall RetargetShotLog(const char* unitAction, std::int32_t rof, uhc::RofRead read) {
  if ((read != uhc::RofRead::kAfterShot && read != uhc::RofRead::kAttackStart) || g_shotLines >= kMaxShotLines ||
      Find(unitAction) == nullptr) {
    return rof;
  }
  ++g_shotLines;
  const char* world = World();
  const char* unit = Field<const char*>(unitAction, 0x10);
  const std::int32_t targetId = Field<std::int32_t>(unitAction, 0x14);
  const char* target = UnitById(world, targetId);
  if (read == uhc::RofRead::kAttackStart) {
    uhc::Log(L"retargetInAction: %d ms, unit %d: an attack cycle begins (action %p, target %d)", Now(world),
             Field<std::int32_t>(unit, 0x10), unitAction, targetId);
  } else {
    uhc::Log(L"retargetInAction: %d ms, unit %d shot %d of action %p at %d (%hs, %ls, %.0f HP), state %02Xh",
             Now(world), Field<std::int32_t>(unit, 0x10), Field<std::int32_t>(unitAction, 0x68), unitAction, targetId,
             target == nullptr ? "gone" : ProtoName(Field<const char*>(target, 0x5C)),
             target == nullptr ? L"-" : (Alive(target) ? L"alive" : L"dead"),
             target == nullptr ? 0.0 : static_cast<double>(Field<float>(target, 0x64)),
             Field<std::uint8_t>(unitAction, 0x61));
  }
  return rof;
}

// "log": why the candidates of the last search were refused.
struct Why {
  std::int32_t dead = 0;
  std::int32_t type = 0;
  std::int32_t action = 0;
  std::int32_t range = 0;
  std::int32_t unseen = 0;
  std::int32_t lastFit = 0;
  bool power = false;
  float range0 = 0.0f;
} g_why;

// A power-launched attack's test of a candidate: the action's own rates and the relation (see the head comment).
bool PowerFits(const char* action, const char* player, const char* other, std::int32_t relation) {
  const char* otherPlayer = Field<const char*>(other, 0x44);
  if (otherPlayer == nullptr) {
    return false;
  }
  const std::int32_t otherId = Field<std::int32_t>(otherPlayer, 0x00);
  if (kIsAlly(player, otherId)) {
    return false;
  }
  if (relation == 1 && (otherId < 0 || otherId >= 16 || Field<std::int32_t>(player, 0x1D4 + 4 * otherId) != 2)) {
    return false;
  }
  return kRateFor(action, other) > 0.0f;
}

// The new target, or -1.
std::int32_t Search(const char* world, const char* unitAction, const char* unit, std::int32_t lostId, float* distanceOut) {
  const char* tactic = CurrentTactic(unit);
  const char* action = Field<const char*>(unitAction, 0x04);
  const char* player = Field<const char*>(unit, 0x44);
  if (tactic == nullptr || action == nullptr || player == nullptr) {
    return -1;
  }
  const float range = Field<float>(unitAction, 0x24);
  const std::int32_t actionId = Field<std::int32_t>(action, 0x00);
  const std::int32_t playerId = Field<std::int32_t>(player, 0x00);
  const std::int32_t relation = FlagBit(unitAction, kFlagNoRelation) ? 0 : 1;
  const auto inRange = Virtual<InRangeFn>(unit, 0xCC);
  const auto distanceTo = Virtual<DistanceFn>(unit, 0xBC);
  const std::int32_t selfId = Field<std::int32_t>(unit, 0x10);
  const bool power = Field<const char*>(unitAction, 0x6C) != nullptr;  // launched by a power
  const std::int32_t autoType = power ? -1 : Field<std::int32_t>(tactic, 0x174);  // <autoattacktype>, -1 none
  g_why = Why{};
  g_why.range0 = range;
  g_why.power = power;
  g_found.count = 0;
  kUnitsNear(world, reinterpret_cast<const float*>(unit + 0x14), (range > 0.0f ? range : 0.0f) + kSearchSlack, 1,
             &g_found);
  std::int32_t best = -1;
  float bestDistance = 0.0f;
  for (std::int32_t i = 0; g_found.data != nullptr && i < g_found.count; ++i) {
    const std::int32_t id = g_found.data[i];
    if (id == selfId || id == lostId) {
      continue;
    }
    const char* other = UnitById(world, id);
    const char* proto = other == nullptr ? nullptr : Field<const char*>(other, 0x5C);
    if (proto == nullptr || !Alive(other) || Inside(other)) {
      ++g_why.dead;
      continue;
    }
    if (autoType >= 0 && !kProtoIsType(proto, autoType)) {
      ++g_why.type;
      continue;
    }
    if (power) {
      if (!PowerFits(action, player, other, relation)) {
        ++g_why.action;
        continue;
      }
    } else {
      const std::int32_t fits = kAttackFor(tactic, unit, other, 1, relation, 0, 0, range);
      if (fits != actionId) {
        ++g_why.action;
        g_why.lastFit = fits;
        continue;
      }
    }
    if (!inRange(unit, other, range)) {
      ++g_why.range;
      continue;
    }
    if (!kIsSeeable(other, playerId)) {
      ++g_why.unseen;
      continue;
    }
    const float distance = distanceTo(unit, other);
    if (best < 0 || distance < bestDistance || (distance == bestDistance && id < best)) {
      best = id;
      bestDistance = distance;
    }
  }
  *distanceOut = bestDistance;
  return best;
}

}  // namespace

extern "C" {

// From the hook at 0x487838 (the update found no live target), while some action has the tag: 1 when a new target
// was written to [ua+14h].
std::int32_t __stdcall UhcRetargetAction(const char* unitAction) {
  const char* unit = unitAction == nullptr ? nullptr : Field<const char*>(unitAction, 0x10);
  const bool* enabled = unit == nullptr ? nullptr : Find(unitAction);
  const char* world = World();
  if (enabled == nullptr || world == nullptr) {
    return 0;
  }
  const std::int32_t now = Now(world);
  const std::uint8_t state = Field<std::uint8_t>(unitAction, 0x61);
  const std::int32_t lostId = Field<std::int32_t>(unitAction, 0x14);
  const std::int32_t unitId = Field<std::int32_t>(unit, 0x10);
  if (lostId < 0 || state != kStateFiring) {
    return 0;  // a point attack, or not in the attack animation: the stock code
  }
  if (!*enabled) {
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"retargetInAction: %d ms, unit %d (%hs/%ls) lost its target %d in state %02Xh after %d shots: "
               L"<RetargetInAction>0, the stock code", now, unitId, ProtoName(Field<const char*>(unit, 0x5C)),
               ActionName(Field<std::int32_t>(Field<const char*>(unitAction, 0x04), 0x04)), lostId, state,
               Field<std::int32_t>(unitAction, 0x68));
    }
    return 0;
  }
  if (unitAction == g_lastAction && now == g_lastTime) {
    return 0;  // already retargeted in this update: the update's own tests refused the new target
  }
  float distance = 0.0f;
  const std::int32_t found = Search(world, unitAction, unit, lostId, &distance);
  if (found < 0) {
    ++g_misses;
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      wchar_t why[96];
      if (g_why.power) {
        std::swprintf(why, 96, L"without a rate of this power's attack or not an enemy");
      } else {
        std::swprintf(why, 96, L"for another attack (%d)", g_why.lastFit);
      }
      uhc::Log(L"retargetInAction: %d ms, unit %d (%hs) lost its target %d in state %02Xh after %d shots: no other "
               L"target in range, the stock code (%d units around: %d dead or inside, %d not of the auto-attack type, %d "
               L"%ls, %d out of range %.1f, %d unseen)", now, unitId,
               ProtoName(Field<const char*>(unit, 0x5C)), lostId, state, Field<std::int32_t>(unitAction, 0x68),
               g_found.count, g_why.dead, g_why.type, g_why.action, why, g_why.range,
               static_cast<double>(g_why.range0), g_why.unseen);
    }
    return 0;
  }
  *reinterpret_cast<std::int32_t*>(const_cast<char*>(unitAction) + 0x14) = found;
  g_lastAction = unitAction;
  g_lastTime = now;
  ++g_retargets;
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    const char* target = UnitById(world, found);
    uhc::Log(L"retargetInAction: %d ms, unit %d (%hs) lost its target %d in state %02Xh after %d shots: new target %d "
             L"(%hs, %.0f HP) at %.1f m (%u retargets, %u without a target so far)",
             now, unitId, ProtoName(Field<const char*>(unit, 0x5C)), lostId, state,
             Field<std::int32_t>(unitAction, 0x68), found, ProtoName(Field<const char*>(target, 0x5C)),
             static_cast<double>(Field<float>(target, 0x64)), static_cast<double>(distance), g_retargets, g_misses);
  }
  return 1;
}

}  // extern "C"

namespace {

bool ParseSwitch(const wchar_t* text, bool* out) {
  if (text == nullptr) {
    return false;
  }
  while (*text == L' ' || *text == L'\t' || *text == L'\r' || *text == L'\n') {
    ++text;
  }
  wchar_t* end = nullptr;
  const long value = std::wcstol(text, &end, 10);
  while (end != nullptr && (*end == L' ' || *end == L'\t' || *end == L'\r' || *end == L'\n')) {
    ++end;
  }
  if (end == text || end == nullptr || *end != L'\0' || (value != 0 && value != 1)) {
    return false;
  }
  *out = value == 1;
  return true;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  if (_wcsicmp(tag.name, L"RetargetInAction") != 0) {
    return;
  }
  const wchar_t* source = tag.source == uhc::ActionSource::kTactics ? L"tactics" : L"protoy";
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  const ActionKey key{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)};
  bool value = false;
  if (key.name < 0 || !ParseSwitch(text, &value)) {
    if (g_invalidLines < 50) {
      ++g_invalidLines;
      uhc::Log(key.name < 0 ? L"retargetInAction: %hs (%ls): <RetargetInAction> before the action's <name>; ignored"
                            : L"retargetInAction: %hs (%ls): <RetargetInAction>%ls</RetargetInAction> is not 0 or 1; "
                              L"ignored",
               ProtoName(tag.proto), source, text);
    }
    return;
  }
  g_entries[key] = value;
  SyncGates();
  if (g_log && g_tagLines < 200) {
    ++g_tagLines;
    uhc::Log(L"retargetInAction: %hs/%ls (%ls): RetargetInAction %d", ProtoName(tag.proto), ActionName(key.name),
             source, value ? 1 : 0);
  }
}

}  // namespace

namespace uhc {

Outcome ApplyRetargetInAction(const Config& config) {
  const Config::Args* args = config.First("retargetInAction");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"retargetInAction: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("retargetInAction", {&sites::kRetargetNoTarget, &sites::kRetargetUpdateTarget,
                                        &sites::kUnitsNearPoint, &sites::kUnitIsSeeable, &sites::kRateLookupHead,
                                        &sites::kPlayerIsAlly}) ||
      !OnDatabaseLoad(&ResetForDataLoad) || !AddActionTagHandler(&ActionTagRead) ||
      (g_log && !AddRofFilter(&RetargetShotLog, "retargetInAction"))) {
    return Outcome::kFailed;
  }
  // mov al,[esi+61h] / cmp al,19h (5 B) at 0x487838, the attack update's branch for a target that is gone.
  if (!WriteJmp(sites::kRetargetNoTarget.va, reinterpret_cast<const void*>(&UhcRetargetHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"retargetInAction: an attack with <RetargetInAction>1 whose target is lost during its attack animation fires "
      L"the rest of its shots at a new target in range%ls (multiplayer unverified)",
      g_log ? L"; tags, shots and retargets logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
