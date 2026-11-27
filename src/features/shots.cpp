// numberOfShots [projectiles] [log]: an attack fires a burst of <NumberOfShots> shots, <ShotInterval> seconds
// apart, before its reload (its ROF); with "projectiles", each shot launches <NumberProjectiles> projectiles.
//
// Stock: an attack (vtable 0xB96278: HandAttack, RangedAttack and the other types of the class) fires one shot per
// cycle. A cycle begins at 0x4A1185 ([unitAction+78h] = now, the animation's rate [unit+0B0h] from the ROF), the
// shot is the launch 0x499422 (or 0x4DCFE2 without a projectile), [unitAction+68h] counts the shots, and the wait
// after it is the ROF minus the time since the cycle began (0x48F8B5..0x48F8E9). <NumberProjectiles>, which
// some mods' tactics carry from Age of Mythology, is not a tag of this exe: no string, no handler.
//
// The burst: the shared ROF reads (rofreads.h) see the shot count. A cycle whose shot is not the burst's last
// (count mod N < N - 1) begins with the interval in place of the ROF, so its animation plays at that pace; after a
// shot that does not end the burst (count mod N != 0) the wait is the interval. The last shot plays the stock
// animation and waits the ROF: N - 1 quick shots, then a normal one and its reload. The count belongs to the unit
// action, which a new target replaces, so a new target starts a new burst.
//
// Between the burst's shots (<BurstPose>, per action): an attack with a <reloadanim> plays its attack animation, then the
// reload animation (started by FUN_004976CB once the attack animation has played), the two together paced to last the
// cycle (0x4A11C2..0x4A120A adds the reload's length), and the next cycle begins when that animation ends.
// - "hold" (the default): at a quick shot (the after-shot ROF read, the attack animation's Attack tag) the rest of the
//   attack animation is slowed so that it ends kHoldLeadMs before the cycle's wait; then the reload hook
//   (hooks/shots_hooks.asm, 0x4976CB) runs that function on the attack animation itself, which is still shown, so it
//   is not restarted and only paced over the lead, and marks [ua+70h] as no longer shown, as after a stock reload start.
//   The unit keeps the attack animation's last pose, its aim, until its next shot.
// - "idle": the reload hook runs the function on the action's idle animation instead (2026-11-21).
// - "reload": the stock reload, squeezed into the interval.
// The shot times stay the stock ones within a few ms: the animations still end where the waits do. Only the burst's last
// shot reloads, and an attack without a reload animation is left alone (the stock idle state between its shots).
//
// The projectiles: a jmp over the launch call at 0x48F88D (hooks/shots_hooks.asm) calls the launch N times with
// the same four arguments; each projectile rolls its own accuracy and spread and deals the action's damage.
//
// minUIStats shows what combat does in an attack row (unitinfo.h, Shots): the shots while this key is on, the
// projectiles while it is on with "projectiles", nothing without it. Its data view (projectiles="data" on its
// <bigPanelRows>, for modders) registers the reader even when this key is off and shows the tags as written; the
// tags read that way change nothing in combat (no ROF filter gate, no launch hook).
#include <windows.h>

#include <cmath>
#include <compare>
#include <cstdint>
#include <cwchar>
#include <map>
#include <string>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../rofreads.h"
#include "../unitinfo.h"
#include "../unittypes.h"

extern "C" {
void UhcShotsLaunchHook();  // hooks/shots_hooks.asm
void UhcShotsReloadHook();
// Above 0 while some action has more than one projectile: the launch hook asks UhcShotsProjectiles only then.
std::int32_t g_uhcShotsProjectiles = 0;
// Above 0 while some action has a burst: the reload hook asks UhcShotsSkipReload only then.
std::int32_t g_uhcShotsBurst = 0;
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
constexpr std::int32_t kMaxShots = 50;
constexpr std::int32_t kMaxProjectiles = 32;
constexpr double kMaxInterval = 60.0;          // seconds
constexpr std::int32_t kDefaultIntervalMs = 250;
constexpr unsigned kMaxTagLines = 200;
constexpr unsigned kMaxInvalidLines = 50;
constexpr unsigned kMaxShotLines = 60;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Database() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

// ProtoAction names: [database+1FD8h] holds one UTF-16 string per name index, [+1FDCh] the count.
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

// Every player's copy of a proto and of its actions keeps the proto ID [proto+4] and the action's name index
// [action+4], so the key finds the entry from the copy a unit attacks with.
struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

// What the unit shows between two shots of a burst (<BurstPose>); the values are what the reload hook expects.
enum class Pose : std::int32_t { kReload = 0, kIdle = 1, kHold = 2 };

struct Entry {
  std::int32_t shots = 1;
  std::int32_t intervalMs = kDefaultIntervalMs;
  std::int32_t projectiles = 1;
  Pose pose = Pose::kHold;
  unsigned shotLines = 0;  // "log": shots logged for this action
};

// Filled while the data loads (a later tag of the same action wins) and read on the game thread at each attack.
std::map<ActionKey, Entry> g_entries;
bool g_projectiles = false;  // "projectiles": <NumberProjectiles> fires that many projectiles a shot
bool g_combat = false;       // numberOfShots is applied: the bursts (and with "projectiles" the projectiles) fire
bool g_reading = false;      // the tag reader is registered (numberOfShots, or minUIStats for its attack rows)
bool g_log = false;
unsigned g_tagLines = 0;
unsigned g_invalidLines = 0;
unsigned g_shotLines = 0;
unsigned g_reloadLines = 0;
constexpr unsigned kMaxReloadLines = 6;
unsigned g_holdLines = 0;  // "log": the first hold lines

std::int32_t __stdcall ShotsRof(const char* unitAction, std::int32_t rof, uhc::RofRead read);

// The gates: the ROF filter while some action has a burst, the launch hook while some action has projectiles; both
// only when numberOfShots is applied (the tags read for minUIStats alone change nothing in combat).
void SyncGates() {
  if (!g_combat) {
    return;
  }
  bool burst = false;
  bool projectiles = false;
  for (const auto& [key, entry] : g_entries) {
    burst = burst || entry.shots > 1;
    projectiles = projectiles || entry.projectiles > 1;
  }
  uhc::SetRofGate(&ShotsRof, burst);
  g_uhcShotsBurst = burst ? 1 : 0;
  g_uhcShotsProjectiles = g_projectiles && projectiles ? 1 : 0;
}

void ResetForDataLoad(char*) {
  g_entries.clear();
  SyncGates();
  g_tagLines = 0;
  g_invalidLines = 0;
  g_shotLines = 0;
  g_reloadLines = 0;
  g_holdLines = 0;
}

const Entry* Find(const char* unitAction, const char** unitOut) {
  const char* action = Field<const char*>(unitAction, 0x04);
  const char* unit = Field<const char*>(unitAction, 0x10);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (action == nullptr || proto == nullptr) {
    return nullptr;
  }
  const auto found = g_entries.find(ActionKey{Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)});
  if (found == g_entries.end()) {
    return nullptr;
  }
  if (unitOut != nullptr) {
    *unitOut = unit;
  }
  return &found->second;
}

using AnimLengthFn = float(__thiscall*)(const char* unit);  // 0x4939BD: the length of the unit's current animation, s
const auto kAnimLength = reinterpret_cast<AnimLengthFn>(0x004939BD);
constexpr std::int32_t kHoldLeadMs = 30;  // the attack's tail ends this long before the wait
constexpr std::int32_t kMinLeadMs = 10;   // the reload start's animation ends at least this soon

// "hold", at a quick shot (the attack animation's Attack tag): the rest of the attack animation is slowed so that it
// ends kHoldLeadMs before the cycle's wait does, instead of ending early in the cycle and leaving the unit to the
// reload slot's animation for the rest of it. The unit keeps the attack animation's tail, its firing pose.
void StretchTail(const char* unitAction, const char* unit, std::int32_t intervalMs) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  const char* visual = unit == nullptr ? nullptr : Field<const char*>(unit, 0x60);
  const char* playing = visual == nullptr ? nullptr : Field<const char*>(visual, 0x00);
  // Only an attack with a reload animation ([ua+84h], whose start the reload hook handles), while the unit shows its
  // attack animation ([[unit+60h]]+14h, as 0x482771 reads it, against [ua+7Ch]).
  if (world == nullptr || playing == nullptr || Field<std::int32_t>(unitAction, 0x84) < 0 ||
      Field<std::int32_t>(playing, 0x14) != Field<std::int32_t>(unitAction, 0x7C)) {
    return;
  }
  const std::int32_t now = Field<std::int32_t>(world, 0x108);
  const std::int32_t elapsed = now - Field<std::int32_t>(unitAction, 0x78);
  const float rate = Field<float>(unit, 0xB0);
  const float lengthMs = kAnimLength(unit) * 1000.0f;
  const float left = lengthMs - static_cast<float>(elapsed) * rate;
  const std::int32_t target = intervalMs - kHoldLeadMs - elapsed;
  if (!(rate > 0.0f) || !(left > 0.0f) || target <= 0) {
    return;
  }
  const float slow = left / static_cast<float>(target);
  if (slow < rate) {
    *reinterpret_cast<float*>(const_cast<char*>(unit) + 0xB0) = slow;
  }
  if (g_log && g_holdLines < 12) {
    ++g_holdLines;
    uhc::Log(L"numberOfShots: hold, unit %d at %d ms: %d ms into the cycle, animation %.0f ms at rate %.3f, %.0f ms "
             L"left -> rate %.3f over %d ms",
             Field<std::int32_t>(unit, 0x10), now, elapsed, lengthMs, rate, left, slow, target);
  }
}

// From the shared ROF reads: the attack-start and after-shot reads of an action with a burst.
std::int32_t __stdcall ShotsRof(const char* unitAction, std::int32_t rof, uhc::RofRead read) {
  if (read != uhc::RofRead::kAttackStart && read != uhc::RofRead::kAfterShot) {
    return rof;
  }
  const char* unit = nullptr;
  const Entry* entry = Find(unitAction, &unit);
  if (entry == nullptr || entry->shots <= 1) {
    return rof;
  }
  const std::int32_t count = Field<std::int32_t>(unitAction, 0x68);
  const std::int32_t inBurst = count < 0 ? 0 : count % entry->shots;
  const bool quick = read == uhc::RofRead::kAttackStart ? inBurst < entry->shots - 1 : inBurst != 0;
  const std::int32_t result = quick ? entry->intervalMs : rof;
  if (quick && read == uhc::RofRead::kAfterShot && entry->pose == Pose::kHold) {
    StretchTail(unitAction, unit, result);
  }
  if (g_log && read == uhc::RofRead::kAfterShot && g_shotLines < kMaxShotLines &&
      entry->shotLines < 4u * static_cast<unsigned>(entry->shots)) {
    ++g_shotLines;
    const_cast<Entry*>(entry)->shotLines += 1;
    const char* action = Field<const char*>(unitAction, 0x04);
    const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
    const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
    uhc::Log(L"numberOfShots: %u ms, unit %d (%hs/%ls) shot %d of its burst of %d (shots so far %d): wait %d ms%ls",
             world == nullptr ? 0u : Field<std::uint32_t>(world, 0x108), Field<std::int32_t>(unit, 0x10),
             ProtoName(Field<const char*>(unit, 0x5C)), ActionName(Field<std::int32_t>(action, 0x04)),
             inBurst == 0 ? entry->shots : inBurst, entry->shots, count, result,
             quick ? L" (the interval)" : L" (the ROF: reload)");
  }
  return result;
}

bool ParseInt(const wchar_t* text, std::int32_t low, std::int32_t high, std::int32_t* out) {
  if (text == nullptr) {
    return false;
  }
  wchar_t* end = nullptr;
  const long value = std::wcstol(text, &end, 10);
  while (end != nullptr && (*end == L' ' || *end == L'\t' || *end == L'\r' || *end == L'\n')) {
    ++end;
  }
  if (end == text || end == nullptr || *end != L'\0' || value < low || value > high) {
    return false;
  }
  *out = static_cast<std::int32_t>(value);
  return true;
}

bool ParseSeconds(const wchar_t* text, std::int32_t* outMs) {
  if (text == nullptr) {
    return false;
  }
  wchar_t* end = nullptr;
  const double value = std::wcstod(text, &end);
  while (end != nullptr && (*end == L' ' || *end == L'\t' || *end == L'\r' || *end == L'\n')) {
    ++end;
  }
  if (end == text || end == nullptr || *end != L'\0' || !(value > 0.0) || value > kMaxInterval) {
    return false;
  }
  const auto ms = static_cast<std::int32_t>(std::floor(value * 1000.0 + 0.5));
  *outMs = ms < 1 ? 1 : ms;
  return true;
}

bool ParsePose(const wchar_t* text, std::int32_t* out) {
  if (text == nullptr) {
    return false;
  }
  while (*text == L' ' || *text == L'\t' || *text == L'\r' || *text == L'\n') {
    ++text;
  }
  std::wstring word(text);
  while (!word.empty() && (word.back() == L' ' || word.back() == L'\t' || word.back() == L'\r' || word.back() == L'\n')) {
    word.pop_back();
  }
  if (_wcsicmp(word.c_str(), L"hold") == 0) {
    *out = static_cast<std::int32_t>(Pose::kHold);
  } else if (_wcsicmp(word.c_str(), L"idle") == 0) {
    *out = static_cast<std::int32_t>(Pose::kIdle);
  } else if (_wcsicmp(word.c_str(), L"reload") == 0) {
    *out = static_cast<std::int32_t>(Pose::kReload);
  } else {
    return false;
  }
  return true;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  enum class Kind { kShots, kInterval, kProjectiles, kPose } kind;
  if (_wcsicmp(tag.name, L"NumberOfShots") == 0) {
    kind = Kind::kShots;
  } else if (_wcsicmp(tag.name, L"BurstPose") == 0) {
    kind = Kind::kPose;
  } else if (_wcsicmp(tag.name, L"ShotInterval") == 0) {
    kind = Kind::kInterval;
  } else if (_wcsicmp(tag.name, L"NumberProjectiles") == 0 || _wcsicmp(tag.name, L"NumberOfProjectiles") == 0) {
    kind = Kind::kProjectiles;
  } else {
    return;
  }
  const wchar_t* source = tag.source == uhc::ActionSource::kTactics ? L"tactics" : L"protoy";
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  const ActionKey key{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)};
  if (key.name < 0) {
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"numberOfShots: %hs (%ls): <%ls> before the action's <name>; ignored (put <name> first)",
               ProtoName(tag.proto), source, tag.name);
    }
    return;
  }
  std::int32_t value = 0;
  bool valid = false;
  switch (kind) {
    case Kind::kShots:
      valid = ParseInt(text, 1, kMaxShots, &value);
      break;
    case Kind::kInterval:
      valid = ParseSeconds(text, &value);
      break;
    case Kind::kProjectiles:
      valid = ParseInt(text, 1, kMaxProjectiles, &value);
      break;
    case Kind::kPose:
      valid = ParsePose(text, &value);
      break;
  }
  if (!valid) {
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"numberOfShots: %hs/%ls (%ls): <%ls>%ls</%ls> is not %ls; ignored", ProtoName(tag.proto),
               ActionName(key.name), source, tag.name, text, tag.name,
               kind == Kind::kInterval      ? L"a number of seconds above 0 and at most 60"
               : kind == Kind::kShots       ? L"a whole number from 1 to 50"
               : kind == Kind::kPose        ? L"hold, idle or reload"
                                            : L"a whole number from 1 to 32");
    }
    return;
  }
  Entry& entry = g_entries[key];
  switch (kind) {
    case Kind::kShots:
      entry.shots = value;
      break;
    case Kind::kInterval:
      entry.intervalMs = value;
      break;
    case Kind::kProjectiles:
      entry.projectiles = value;
      break;
    case Kind::kPose:
      entry.pose = static_cast<Pose>(value);
      break;
  }
  SyncGates();
  if (g_log && g_tagLines < kMaxTagLines) {
    ++g_tagLines;
    uhc::Log(L"numberOfShots: %hs/%ls (%ls): %ls %ls", ProtoName(tag.proto), ActionName(key.name), source, tag.name,
             text);
  }
}

// The tag reader, registered once for numberOfShots and minUIStats alike.
bool EnsureReader() {
  if (g_reading) {
    return true;
  }
  if (!uhc::OnDatabaseLoad(&ResetForDataLoad) || !uhc::AddActionTagHandler(&ActionTagRead)) {
    return false;
  }
  g_reading = true;
  return true;
}

}  // namespace

extern "C" {

// From the reload hook (0x4976CB), while some action has a burst: after a shot that does not end its burst (the same
// test as the after-shot ROF read), the action's <BurstPose> (2 hold: the attack animation stays, 1 idle: the idle
// animation, 0 reload: the stock reload); 0 after any other shot.
std::int32_t __stdcall UhcShotsBurstPose(const char* unitAction) {
  const char* unit = nullptr;
  const Entry* entry = unitAction == nullptr ? nullptr : Find(unitAction, &unit);
  if (entry == nullptr || entry->shots <= 1) {
    return 0;
  }
  const std::int32_t count = Field<std::int32_t>(unitAction, 0x68);
  if ((count < 0 ? 0 : count % entry->shots) == 0) {
    return 0;
  }
  if (g_log && g_reloadLines < kMaxReloadLines) {
    ++g_reloadLines;  // its own budget, so the shots' lines still show whole bursts
    uhc::Log(L"numberOfShots: unit %d (%hs) shot %d of its burst of %d: %ls",
             Field<std::int32_t>(unit, 0x10), ProtoName(Field<const char*>(unit, 0x5C)), count % entry->shots, entry->shots,
             entry->pose == Pose::kHold   ? L"holds its firing pose, no reload"
             : entry->pose == Pose::kIdle ? L"the idle animation, no reload"
                                          : L"the reload animation (BurstPose reload)");
  }
  return static_cast<std::int32_t>(entry->pose);
}

// From the reload hook with "hold", after the stock reload start ran in the lead the attack's tail left it: when the
// unit reached that point late (the lead gone or nearly), the stock start paces the reload animation over a wait of 0
// (rate 1, the whole animation) or a negative one (read unsigned: it never ends), and the next cycle waits for it.
// Then the rate that ends it within kMinLeadMs.
void __stdcall UhcShotsHoldLead(const char* unitAction) {
  const char* unit = unitAction == nullptr ? nullptr : Field<const char*>(unitAction, 0x10);
  const char* timer = unit == nullptr ? nullptr : Field<const char*>(unit, 0x58);
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (timer == nullptr || world == nullptr || Field<const char*>(unit, 0x60) == nullptr) {
    return;
  }
  const std::int32_t left = Field<std::int32_t>(timer, 0xB8) + Field<std::int32_t>(timer, 0xBC) -
                            Field<std::int32_t>(world, 0x108);
  if (left >= kMinLeadMs) {
    return;
  }
  const float lengthMs = kAnimLength(unit) * 1000.0f;
  if (lengthMs > 0.0f) {
    *reinterpret_cast<float*>(const_cast<char*>(unit) + 0xB0) = lengthMs / static_cast<float>(kMinLeadMs);
  }
  if (g_log && g_holdLines < 24) {
    ++g_holdLines;
    uhc::Log(L"numberOfShots: hold, unit %d: the reload start came %d ms before the wait's end; its animation ends "
             L"within %d ms", Field<std::int32_t>(unit, 0x10), left, kMinLeadMs);
  }
}

// From the launch hook (0x48F88D), while some action has projectiles: how many times to call the launch for this
// shot (at least 1).
std::int32_t __stdcall UhcShotsProjectiles(const char* unitAction) {
  if (unitAction == nullptr) {
    return 1;
  }
  const char* unit = nullptr;
  const Entry* entry = Find(unitAction, &unit);
  if (!g_projectiles || entry == nullptr || entry->projectiles <= 1) {
    return 1;
  }
  if (g_log && g_shotLines < kMaxShotLines && entry->shotLines < 8) {
    ++g_shotLines;
    const_cast<Entry*>(entry)->shotLines += 1;
    const char* action = Field<const char*>(unitAction, 0x04);
    uhc::Log(L"numberOfShots: unit %d (%hs/%ls) launches %d projectiles for one shot", Field<std::int32_t>(unit, 0x10),
             ProtoName(Field<const char*>(unit, 0x5C)), ActionName(Field<std::int32_t>(action, 0x04)),
             entry->projectiles);
  }
  return entry->projectiles;
}

}  // extern "C"

namespace uhc {

namespace unitinfo {

bool RequestShotTags() { return EnsureReader(); }

bool Shots(const char* proto, const char* action, int* shots, int* projectiles, bool asData) {
  if (!g_reading || proto == nullptr || action == nullptr || (!asData && !g_combat)) {
    return false;
  }
  const auto found = g_entries.find(ActionKey{Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)});
  if (found == g_entries.end()) {
    return false;
  }
  *shots = found->second.shots;
  // Without "projectiles" a shot launches one projectile, whatever the tag says.
  *projectiles = asData || g_projectiles ? found->second.projectiles : 1;
  return true;
}

}  // namespace unitinfo

Outcome ApplyNumberOfShots(const Config& config) {
  const Config::Args* args = config.First("numberOfShots");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "projectiles") == 0) {
      g_projectiles = true;
    } else {
      Log(L"numberOfShots: unexpected argument %hs (expected: [projectiles] [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("numberOfShots", {&sites::kShotsLaunchCall, &sites::kShotsLaunch, &sites::kShotsLaunchRet,
                                     &sites::kShotsReloadAnim, &sites::kShotsAnimVariant}) ||
      !EnsureReader() || !AddRofFilter(&ShotsRof, "numberOfShots")) {
    return Outcome::kFailed;
  }
  // sub esp,8 / push esi / mov esi,ecx (6 B) at the head of the reload animation's start 0x4976CB.
  if (!WriteJmp(sites::kShotsReloadAnim.va, reinterpret_cast<const void*>(&UhcShotsReloadHook), 6)) {
    return Outcome::kFailed;
  }
  // call 499422h (5 B) at 0x48F88D, the launch of the attack step's shot.
  if (g_projectiles && !WriteJmp(0x0048F88D, reinterpret_cast<const void*>(&UhcShotsLaunchHook), 5)) {
    return Outcome::kFailed;
  }
  g_combat = true;  // before the data loads, which runs after every key is applied
  Log(L"numberOfShots: attacks read <NumberOfShots>, <ShotInterval> (default %.2f s) and <BurstPose> (default hold: "
      L"the firing pose between a burst's shots)%ls%ls (multiplayer unverified)",
      kDefaultIntervalMs / 1000.0,
      g_projectiles ? L", and <NumberProjectiles> projectiles per shot" : L"",
      g_log ? L"; tags and the first shots logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
