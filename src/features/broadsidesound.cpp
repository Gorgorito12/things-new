// broadsideSoundSet [log]: an attack of the broadside class (a tactics <type>BroadsideAttack</type>, ships' cannon
// volleys) plays the sound set its action names in <BroadsideSoundSet> at each shot, in place of "ShipCannonShoot".
//
// Stock: the broadside fire step calls FUN_004CEB37 (its only caller, 0x4CEA02) for the effect of each shot, just before
// the launch 0x4CEA43: the muzzle effect "NavelCannon" (0xBA1D6C) through 0x4828E6, then 0x4AA24C(game, position
// [unit+14h], "ShipCannonShoot" (0xBA1D5C, pushed at 0x4CECBD), extra), which plays a sound set by name. The name is
// the only one pushed there: every broadside shot of every ship sounds the same, whatever its projectile.
//
// The hook (hooks/broadsidesound_hooks.asm) replaces that push: UhcBroadsideSoundName(unit action) finds the tag of
// {[[ua+10h]+5Ch]+4 proto ID, [[ua+4]+4] action name index}, the pair every player's copy keeps, and gives its name,
// or the stock one. A mod's rocket ships can be Frigates whose home city card swaps their broadside actions for
// rocket ones (both of type BroadsideAttack): the action, not the proto, tells them apart, so the tag belongs to the
// action.
#include <windows.h>

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
#include "../unittypes.h"

extern "C" {
void UhcBroadsideSoundHook();  // hooks/broadsidesound_hooks.asm
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
const char* const kStockSound = reinterpret_cast<const char*>(0x00BA1D5C);  // "ShipCannonShoot"
constexpr std::size_t kMaxName = 63;
constexpr unsigned kMaxTagLines = 100;
constexpr unsigned kMaxInvalidLines = 50;
constexpr unsigned kMaxShotLines = 12;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const wchar_t* ActionName(std::int32_t index) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
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

struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

enum class Known { kUnchecked, kYes, kNo };

struct Entry {
  std::string sound;
  Known known = Known::kUnchecked;
  unsigned shotLines = 0;
};

// The sound manager's sets by name, as 0x597C56 (the play by name that 0x4AA24C reaches) looks one up: the manager
// [game+950h], its set table [+4], a BString of the name (0x401ECA, thiscall(this, const char*), ret 4; freed by
// 0x4010CA) and 0x468E7D (thiscall(table, const BString*), ret 4), the set or 0. kUnchecked when there is no table.
struct BString {
  void* text = nullptr;
};
using BStringFromFn = BString*(__thiscall*)(BString* self, const char* text);
using BStringFreeFn = void(__thiscall*)(BString* self);
using SoundSetFindFn = const void*(__thiscall*)(const void* table, const BString* name);
const auto kBStringFrom = reinterpret_cast<BStringFromFn>(0x00401ECA);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kSoundSetFind = reinterpret_cast<SoundSetFindFn>(0x00468E7D);

Known SoundSetKnown(const char* name) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* manager = game == nullptr ? nullptr : Field<const char*>(game, 0x950);
  const char* table = manager == nullptr ? nullptr : Field<const char*>(manager, 0x04);
  if (table == nullptr) {
    return Known::kUnchecked;
  }
  BString text;
  kBStringFrom(&text, name);
  const void* set = kSoundSetFind(table, &text);
  kBStringFree(&text);
  return set != nullptr ? Known::kYes : Known::kNo;
}

// Filled while the data loads (a later tag of the same action wins), read on the game thread at each broadside shot.
// The strings do not move while the game runs: the map only changes during a data load.
std::map<ActionKey, Entry> g_entries;
bool g_log = false;
unsigned g_tagLines = 0;
unsigned g_invalidLines = 0;
unsigned g_shotLines = 0;

void ResetForDataLoad(char*) {
  g_entries.clear();
  g_tagLines = 0;
  g_invalidLines = 0;
  g_shotLines = 0;
}

// A sound set name: printable ASCII, no spaces, as the sound set files write them.
bool ParseName(const wchar_t* text, std::string* out) {
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
  if (word.empty() || word.size() > kMaxName) {
    return false;
  }
  std::string name;
  for (wchar_t c : word) {
    if (c <= L' ' || c > L'~') {
      return false;
    }
    name.push_back(static_cast<char>(c));
  }
  *out = name;
  return true;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  if (_wcsicmp(tag.name, L"BroadsideSoundSet") != 0) {
    return;
  }
  const wchar_t* source = tag.source == uhc::ActionSource::kTactics ? L"tactics" : L"protoy";
  const wchar_t* text = tag.text == nullptr ? L"" : tag.text;
  const ActionKey key{Field<std::int32_t>(tag.proto, 0x04), Field<std::int32_t>(tag.action, 0x04)};
  if (key.name < 0) {
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"broadsideSoundSet: %hs (%ls): <BroadsideSoundSet> before the action's <name>; ignored (put <name> "
               L"first)", ProtoName(tag.proto), source);
    }
    return;
  }
  std::string name;
  if (!ParseName(text, &name)) {
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"broadsideSoundSet: %hs/%ls (%ls): <BroadsideSoundSet>%ls</BroadsideSoundSet> is not a sound set name "
               L"(1 to %u characters, no spaces); ignored", ProtoName(tag.proto), ActionName(key.name), source, text,
               static_cast<unsigned>(kMaxName));
    }
    return;
  }
  g_entries[key].sound = name;
  if (g_log && g_tagLines < kMaxTagLines) {
    ++g_tagLines;
    uhc::Log(L"broadsideSoundSet: %hs/%ls (%ls): %hs", ProtoName(tag.proto), ActionName(key.name), source,
             name.c_str());
  }
}

}  // namespace

extern "C" {

// From the hook at 0x4CECBD: the sound set of this broadside shot.
const char* __stdcall UhcBroadsideSoundName(const char* unitAction) {
  if (unitAction == nullptr || g_entries.empty()) {
    return kStockSound;
  }
  const char* action = Field<const char*>(unitAction, 0x04);
  const char* unit = Field<const char*>(unitAction, 0x10);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (action == nullptr || proto == nullptr) {
    return kStockSound;
  }
  const auto found = g_entries.find(ActionKey{Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)});
  if (found == g_entries.end()) {
    return kStockSound;
  }
  Entry& entry = found->second;
  if (entry.known == Known::kUnchecked) {
    entry.known = SoundSetKnown(entry.sound.c_str());
    if (entry.known == Known::kNo) {
      uhc::Log(L"broadsideSoundSet: %hs/%ls: no sound set is named %hs; its broadsides play ShipCannonShoot",
               ProtoName(proto), ActionName(Field<std::int32_t>(action, 0x04)), entry.sound.c_str());
    }
  }
  if (entry.known == Known::kNo) {
    return kStockSound;
  }
  if (g_log && g_shotLines < kMaxShotLines && entry.shotLines < 3) {
    ++g_shotLines;
    ++entry.shotLines;
    uhc::Log(L"broadsideSoundSet: unit %d (%hs/%ls) fires: sound set %hs", Field<std::int32_t>(unit, 0x10),
             ProtoName(proto), ActionName(Field<std::int32_t>(action, 0x04)), entry.sound.c_str());
  }
  return entry.sound.c_str();
}

}  // extern "C"

namespace uhc {

Outcome ApplyBroadsideSoundSet(const Config& config) {
  const Config::Args* args = config.First("broadsideSoundSet");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"broadsideSoundSet: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("broadsideSoundSet", {&sites::kBroadsideSound, &sites::kBroadsideSoundName}) ||
      !OnDatabaseLoad(&ResetForDataLoad) || !AddActionTagHandler(&ActionTagRead)) {
    return Outcome::kFailed;
  }
  // push 0BA1D5Ch (5 B) at 0x4CECBD, the name of the broadside shot's sound set.
  if (!WriteJmp(sites::kBroadsideSound.va, reinterpret_cast<const void*>(&UhcBroadsideSoundHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"broadsideSoundSet: broadside shots play their action's <BroadsideSoundSet> (default ShipCannonShoot)%ls",
      g_log ? L"; tags and the first shots logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
