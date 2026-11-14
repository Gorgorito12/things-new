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
// The projectiles: a jmp over the launch call at 0x48F88D (hooks/shots_hooks.asm) calls the launch N times with
// the same four arguments; each projectile rolls its own accuracy and spread and deals the action's damage.
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
#include "../unittypes.h"

extern "C" {
void UhcShotsLaunchHook();  // hooks/shots_hooks.asm
// Above 0 while some action has more than one projectile: the launch hook asks UhcShotsProjectiles only then.
std::int32_t g_uhcShotsProjectiles = 0;
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

struct Entry {
  std::int32_t shots = 1;
  std::int32_t intervalMs = kDefaultIntervalMs;
  std::int32_t projectiles = 1;
  unsigned shotLines = 0;  // "log": shots logged for this action
};

// Filled while the data loads (a later tag of the same action wins) and read on the game thread at each attack.
std::map<ActionKey, Entry> g_entries;
bool g_projectiles = false;  // "projectiles": <NumberProjectiles> is read
bool g_log = false;
unsigned g_tagLines = 0;
unsigned g_invalidLines = 0;
unsigned g_shotLines = 0;

std::int32_t __stdcall ShotsRof(const char* unitAction, std::int32_t rof, uhc::RofRead read);

// The gates: the ROF filter while some action has a burst, the launch hook while some action has projectiles.
void SyncGates() {
  bool burst = false;
  bool projectiles = false;
  for (const auto& [key, entry] : g_entries) {
    burst = burst || entry.shots > 1;
    projectiles = projectiles || entry.projectiles > 1;
  }
  uhc::SetRofGate(&ShotsRof, burst);
  g_uhcShotsProjectiles = projectiles ? 1 : 0;
}

void ResetForDataLoad(char*) {
  g_entries.clear();
  SyncGates();
  g_tagLines = 0;
  g_invalidLines = 0;
  g_shotLines = 0;
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

void ActionTagRead(const uhc::ActionTag& tag) {
  enum class Kind { kShots, kInterval, kProjectiles } kind;
  if (_wcsicmp(tag.name, L"NumberOfShots") == 0) {
    kind = Kind::kShots;
  } else if (_wcsicmp(tag.name, L"ShotInterval") == 0) {
    kind = Kind::kInterval;
  } else if (g_projectiles &&
             (_wcsicmp(tag.name, L"NumberProjectiles") == 0 || _wcsicmp(tag.name, L"NumberOfProjectiles") == 0)) {
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
  }
  if (!valid) {
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"numberOfShots: %hs/%ls (%ls): <%ls>%ls</%ls> is not %ls; ignored", ProtoName(tag.proto),
               ActionName(key.name), source, tag.name, text, tag.name,
               kind == Kind::kInterval      ? L"a number of seconds above 0 and at most 60"
               : kind == Kind::kShots       ? L"a whole number from 1 to 50"
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
  }
  SyncGates();
  if (g_log && g_tagLines < kMaxTagLines) {
    ++g_tagLines;
    uhc::Log(L"numberOfShots: %hs/%ls (%ls): %ls %ls", ProtoName(tag.proto), ActionName(key.name), source, tag.name,
             text);
  }
}

}  // namespace

extern "C" {

// From the launch hook (0x48F88D), while some action has projectiles: how many times to call the launch for this
// shot (at least 1).
std::int32_t __stdcall UhcShotsProjectiles(const char* unitAction) {
  if (unitAction == nullptr) {
    return 1;
  }
  const char* unit = nullptr;
  const Entry* entry = Find(unitAction, &unit);
  if (entry == nullptr || entry->projectiles <= 1) {
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
  if (!VerifyAll("numberOfShots", {&sites::kShotsLaunchCall, &sites::kShotsLaunch, &sites::kShotsLaunchRet}) ||
      !OnDatabaseLoad(&ResetForDataLoad) || !AddActionTagHandler(&ActionTagRead) ||
      !AddRofFilter(&ShotsRof, "numberOfShots")) {
    return Outcome::kFailed;
  }
  // call 499422h (5 B) at 0x48F88D, the launch of the attack step's shot.
  if (g_projectiles && !WriteJmp(0x0048F88D, reinterpret_cast<const void*>(&UhcShotsLaunchHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"numberOfShots: attacks read <NumberOfShots> and <ShotInterval> (default %.2f s)%ls%ls (multiplayer "
      L"unverified)",
      kDefaultIntervalMs / 1000.0,
      g_projectiles ? L", and <NumberProjectiles> projectiles per shot" : L"",
      g_log ? L"; tags and the first shots logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
