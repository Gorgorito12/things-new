// containedUnitsROF: <ScaleByContainedUnits target="ROF"> makes an attack fire faster with the units inside.
//
// Stock: the tactics tag ScaleByContainedUnits (handler 0x5FEDFC, bit 18 of the action's flag bytes) multiplies
// an attack's DAMAGE by the unit's contained count [unit+74h], at most DamageFactorCap [action+48h] when that is
// above 0 (the projectile launch, 0x4996C7). Its text is read as an integer and only 1 sets the bit: an empty tag
// clears it. The XML attribute "target" is not read.
//
// With this key, the handler reads the attribute. target="ROF" (any case): the action's interval is divided by
// the units inside, at most DamageFactorCap when the action has one; the damage is the stock one (bit 18 is
// cleared), and the action is active only with someone inside (bit 17, ActiveIfContainsUnits, is set), so an
// empty building does not fire. An empty tag with the attribute turns it on; a text of 0 turns it off. No
// attribute, or target="Damage": stock. Gather actions are autoGatherScaleByContained's.
//
// The interval: every attack action (HandAttack, RangedAttack and the other types of the class, vtable 0xB96278)
// waits through 0x48FA69(action manager, ms), which also applies ROF modifiers. Five reads of the tactics ROF
// [action+34h] feed it or the attack's animation rate; the hooks in hooks/containedrof_hooks.asm pass each one
// through UhcContainedRofScale. An override ROF ([unitAction+6Ch]+28h, set by something other than the tactics)
// is not scaled.
#include <windows.h>

#include <compare>
#include <cstdint>
#include <cstring>
#include <cwctype>
#include <map>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
void UhcContainedRofTagHook();
void UhcContainedRofWaitAHook();
void UhcContainedRofWaitBHook();
void UhcContainedRofWaitCHook();
void UhcContainedRofShotHook();
void UhcContainedRofAnimHook();
}

// Entries in the table, read by the hooks to skip the call when no action has the attribute.
extern "C" std::int32_t g_uhcContainedRofCount = 0;

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
constexpr std::uint32_t kFromProtoAction = 0x005FA213;
constexpr unsigned kMaxTagLines = 200;
constexpr unsigned kMaxInvalidLines = 50;
constexpr unsigned kMaxIntervalLines = 100;

// Flag bits of an action, in its bytes [+64h] (count of bits [+68h]).
constexpr std::int32_t kActiveIfContains = 17;  // <ActiveIfContainsUnits>, set at 0x5FEDD3
constexpr std::int32_t kScaleByContained = 18;  // <ScaleByContainedUnits>, set at 0x5FEE1A

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);

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

bool FlagBit(const char* action, std::int32_t bit) {
  if (Field<std::int32_t>(action, 0x68) <= bit) {
    return false;
  }
  const auto* bytes = Field<const std::uint8_t*>(action, 0x64);
  return (bytes[bit >> 3] & (1u << (bit & 7))) != 0;
}

void SetFlagBit(const char* action, std::int32_t bit, bool on) {
  auto* bytes = Field<std::uint8_t*>(action, 0x64);
  if (on) {
    bytes[bit >> 3] = static_cast<std::uint8_t>(bytes[bit >> 3] | (1u << (bit & 7)));
  } else {
    bytes[bit >> 3] = static_cast<std::uint8_t>(bytes[bit >> 3] & ~(1u << (bit & 7)));
  }
}

// Every player's copy of a proto and of its actions keeps the proto ID [proto+4] and the action's name index
// [action+4] (as for spreadAnyAccuracy), so the key finds the entry from the copy a unit attacks with.
struct ActionKey {
  std::int32_t proto;
  std::int32_t name;
  auto operator<=>(const ActionKey&) const = default;
};

struct Entry {
  bool setActive = false;  // bit 17 was clear and this key set it
  std::int32_t lastInterval = -1;  // "log": the last interval logged; only a change is logged
};

// Filled while the data loads and read on the game thread at each attack; cleared on every data load.
std::map<ActionKey, Entry> g_entries;
bool g_log = false;
unsigned g_tagLines = 0;
unsigned g_invalidLines = 0;
unsigned g_intervalLines = 0;

void SyncCount() { g_uhcContainedRofCount = static_cast<std::int32_t>(g_entries.size()); }

// A ROF entry of this action is dropped by a later tag of the same action (a protoy <ProtoAction> after its
// tactics <action>): the last tag wins, as for the stock bit.
void Drop(const ActionKey& key, const char* action) {
  const auto found = g_entries.find(key);
  if (found == g_entries.end()) {
    return;
  }
  if (found->second.setActive) {
    SetFlagBit(action, kActiveIfContains, false);
  }
  g_entries.erase(found);
  SyncCount();
}

bool IsBlank(const wchar_t* text) {
  if (text == nullptr) {
    return true;
  }
  while (*text != L'\0') {
    if (!std::iswspace(*text)) {
      return false;
    }
    ++text;
  }
  return true;
}

// The attribute's value, or nullptr without one. The name is tried as written in the request and capitalised.
const char* TargetAttribute(const char* node) {
  for (const char* name : {"target", "Target", "TARGET"}) {
    const void* text = nullptr;
    if (kXmlAttribute(node, name, &text) && text != nullptr) {
      const char* value = kXmlText(text);
      return value != nullptr ? value : "";
    }
  }
  return nullptr;
}

void ResetForDataLoad(char*) {
  g_entries.clear();
  SyncCount();
  g_tagLines = 0;
  g_invalidLines = 0;
  g_intervalLines = 0;
}

}  // namespace

extern "C" {

// From the hook in the ScaleByContainedUnits handler (0x5FEE0C), after the stock read of the text into value
// (0 when it is not a number). node is the tag, proto and action the parser's arguments, returnAddress the
// parser's caller. Returns 1 when the tag is handled here (the hook goes on to the next child), 0 for the stock
// code (bit 18 from value).
std::int32_t __stdcall UhcContainedRofTag(const char* node, const char* proto, char* action, std::int32_t value,
                                          std::uint32_t returnAddress) {
  if (node == nullptr || proto == nullptr || action == nullptr) {
    return 0;
  }
  const ActionKey key{Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)};
  const wchar_t* source = returnAddress == kFromProtoAction ? L"protoy" : L"tactics";
  const char* target = TargetAttribute(node);
  if (target == nullptr || _stricmp(target, "Damage") == 0) {
    Drop(key, action);
    return 0;
  }
  if (_stricmp(target, "ROF") != 0) {
    Drop(key, action);
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"containedUnitsROF: %hs/%ls (%ls): target=\"%hs\" is neither ROF nor Damage; the stock tag",
               ProtoName(proto), ActionName(key.name), source, target);
    }
    return 0;
  }
  if (Field<std::int32_t>(action, 0x68) <= kScaleByContained) {
    return 0;  // not an action's flag set: never seen
  }
  const wchar_t* text = Field<const wchar_t*>(node, 0x14);
  const bool on = IsBlank(text) || value == 1;
  if (!on) {
    Drop(key, action);
    SetFlagBit(action, kScaleByContained, false);
    return 1;
  }
  if (key.name < 0) {
    // Only possible in a tactics <action> whose <name> comes later.
    if (g_invalidLines < kMaxInvalidLines) {
      ++g_invalidLines;
      uhc::Log(L"containedUnitsROF: %hs (%ls): <ScaleByContainedUnits target=\"ROF\"> before the action's <name>; "
               L"the stock tag (put <name> first)",
               ProtoName(proto), source);
    }
    return 0;
  }
  SetFlagBit(action, kScaleByContained, false);
  auto [entry, added] = g_entries.try_emplace(key);
  if (added) {
    entry->second.setActive = !FlagBit(action, kActiveIfContains);
    SyncCount();
  }
  SetFlagBit(action, kActiveIfContains, true);
  if (g_log && g_tagLines < kMaxTagLines) {
    ++g_tagLines;
    uhc::Log(L"containedUnitsROF: %hs/%ls (%ls): the interval is divided by the units inside", ProtoName(proto),
             ActionName(key.name), source);
  }
  return 1;
}

// From the five ROF reads: unitAction is the attack's unit action ([+4] its tactics action, [+10h] its unit),
// rof the tactics ROF in ms (above 0). Returns the interval to use.
std::int32_t __stdcall UhcContainedRofScale(const char* unitAction, std::int32_t rof) {
  if (unitAction == nullptr || rof <= 0) {
    return rof;
  }
  const char* action = Field<const char*>(unitAction, 0x04);
  const char* unit = Field<const char*>(unitAction, 0x10);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (action == nullptr || proto == nullptr) {
    return rof;
  }
  const auto found = g_entries.find(ActionKey{Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)});
  if (found == g_entries.end()) {
    return rof;
  }
  // The stock damage factor's rule (0x4996C7..0x49970A): the count, or the cap when the count is above it and
  // the cap is above 0. Nobody inside: the action is inactive (bit 17), unless a later <ActiveIfContainsUnits>0
  // cleared it; then the stock interval.
  const std::int32_t inside = Field<std::int32_t>(unit, 0x74);
  const float cap = Field<float>(action, 0x48);
  double factor = static_cast<double>(inside);
  if (cap > 0.0f && factor > static_cast<double>(cap)) {
    factor = static_cast<double>(cap);
  }
  if (!(factor > 0.0)) {
    return rof;
  }
  double scaled = static_cast<double>(rof) / factor;
  if (scaled > 2.0e9) {
    scaled = 2.0e9;
  }
  std::int32_t interval = static_cast<std::int32_t>(scaled);
  if (interval < 1) {
    interval = 1;
  }
  if (g_log && found->second.lastInterval != interval && g_intervalLines < kMaxIntervalLines) {
    found->second.lastInterval = interval;
    ++g_intervalLines;
    uhc::Log(L"containedUnitsROF: %hs/%ls (unit %d, player %d): %d inside, cap %.2f, ROF %d -> %d ms",
             ProtoName(proto), ActionName(Field<std::int32_t>(action, 0x04)), Field<std::int32_t>(unit, 0x10),
             Field<std::int32_t>(Field<const char*>(unit, 0x44), 0), inside, static_cast<double>(cap), rof, interval);
  }
  return interval;
}
}

namespace uhc {

Outcome ApplyContainedUnitsROF(const Config& config) {
  const Config::Args* args = config.First("containedUnitsROF");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"containedUnitsROF: unexpected argument %hs (only \"log\"); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("containedUnitsROF",
                 {&sites::kRofScaleTag, &sites::kRofNextChild, &sites::kDotProtoActionCall, &sites::kTacticsActionCall,
                  &sites::kXmlAttribute, &sites::kXmlText, &sites::kRofWaitA, &sites::kRofWaitB, &sites::kRofWaitC,
                  &sites::kRofShot, &sites::kRofAnim, &sites::kRofDelay}) ||
      !OnDatabaseLoad(&ResetForDataLoad)) {
    return Outcome::kFailed;
  }
  // cmp dword ptr [esp+10h],1 / mov eax,[ebp+64h] at 0x5FEE0C (8 B); the hook re-executes them for the stock tag.
  // The ROF reads: mov r,[r+34h] / test r,r (5 B) at 0x48A821, 0x48A99A and 0x48EA0C; mov eax,[eax+34h] /
  // cmp eax,ebx (5 B) at 0x48F8B5; mov ebx,[eax+34h] / mov eax,[esi+6Ch] (6 B) at 0x4A1189.
  if (!WriteJmp(0x005FEE0C, reinterpret_cast<const void*>(&UhcContainedRofTagHook), 8) ||
      !WriteJmp(0x0048A821, reinterpret_cast<const void*>(&UhcContainedRofWaitAHook), 5) ||
      !WriteJmp(0x0048A99A, reinterpret_cast<const void*>(&UhcContainedRofWaitBHook), 5) ||
      !WriteJmp(0x0048EA0C, reinterpret_cast<const void*>(&UhcContainedRofWaitCHook), 5) ||
      !WriteJmp(0x0048F8B5, reinterpret_cast<const void*>(&UhcContainedRofShotHook), 5) ||
      !WriteJmp(0x004A1189, reinterpret_cast<const void*>(&UhcContainedRofAnimHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"containedUnitsROF: attacks with <ScaleByContainedUnits target=\"ROF\"> fire faster with the units inside "
      L"(multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
