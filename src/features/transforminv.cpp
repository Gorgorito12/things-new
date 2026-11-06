// transformInventory: a unit that changes proto in place takes the resource inventory of its new
// proto, as if it had been created as that proto.
//
// Each unit with resources has its own inventory at [[unit+B4h]+94h], a pool object: +0 the unit
// ID, +4 a resource list, +0Ch and +10h -1 (+10h forces the type a gatherer takes). Unit creation
// seeds it from the proto's resource object [proto+E0h], whose InitialResource list is at +0
// (0x67DE0D: FUN_009BFE5A makes a fresh inventory, 0x480A73 copies the list). Gathering, the AI
// knowledge bases and the DieAtZeroResources check all read the inventory, never the proto.
// FUN_009C754C changes a live unit into another proto (TransformUnit tech effects, the
// revolution, construction-object transforms) but never touches the inventory: the unit keeps
// its old proto's resource types and amounts, or has none at all. A coin crate turned into an
// XP crate still pays gold; a unit with no inventory turned into a crate cannot be gathered. A
// later conversion makes it worse: the owner change 0x514358 rescales each amount by
// newInit[r] / oldInit[r] of the same proto, and zeroes every type its InitialResource lacks.
//
// The hook (hooks/transforminv_hooks.asm) runs at 0x9C7625, after the other players' knowledge
// bases have dropped the unit and before they take it back, and before setHP's checkState. A unit
// whose old and new protos list the same resource types keeps its inventory (a fattened sheep
// turned into a cow keeps its food), unless "all" is given. Any other unit gets the new proto's
// InitialResource: an existing inventory is reused (no gatherer keeps a dangling pointer) with
// its +0Ch/+10h reset to -1, a missing one is made with FUN_009BFE5A. "scale" keeps the fraction
// not yet gathered. A new proto with no resource object leaves the unit as in stock; with "all"
// its inventory is freed, as trUnitChangeProtoUnit does (0x4729D0). Units already gathering the
// target keep their old resource type, so after a cross-type rebuild they stop at their next
// gather tick and must be re-tasked.
//
// inventory='keep', 'rebuild' or 'scale' on a TransformUnit effect decides for that effect, over the
// cfg: keep leaves the inventory as stock does, rebuild is "all", and scale is "all scale". A transform
// that no effect runs, as a revolution or a turn back, follows the cfg.
#include <bit>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../transformcalls.h"
#include "../unittypes.h"

namespace {

// A resource list is 8 bytes: +0 an array of [kResourceCount] floats, entry r XORed with the dword
// at kEntryKeys + 4r; +4 their total, XORed with [kTotalKey] (ResList total recompute 0x58EF02).
constexpr std::uint32_t kTotalKey = 0x00C6DF10;
constexpr std::uint32_t kEntryKeys = 0x00C6DF14;
constexpr std::uint32_t kResourceCount = 0x00C6DF38;
constexpr std::int32_t kMaxResources = 64;  // a larger count means the globals are not what we expect
constexpr float kEpsilon = 1e-6f;           // the engine's "holds this resource" threshold (0xBA1388)

using RecreateInventoryFn = char*(__thiscall*)(char* unit);
using ResListCopyFn = void*(__thiscall*)(char* dst, const char* src);
using ResListScaleFn = void(__thiscall*)(char* list, float factor);
using FreeInventoryFn = void(__cdecl*)(char* inventory);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kRecreateInventory = reinterpret_cast<RecreateInventoryFn>(0x009BFE5A);
const auto kResListCopy = reinterpret_cast<ResListCopyFn>(0x00480A73);
const auto kResListScale = reinterpret_cast<ResListScaleFn>(0x00480B94);
const auto kFreeInventory = reinterpret_cast<FreeInventoryFn>(0x004BA757);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);

enum class Mode { kCfg, kKeep, kRebuild, kScale };
std::unordered_map<void*, Mode> g_modes;  // by effect, from inventory='...'
Mode g_running = Mode::kCfg;              // of the effect that is applying

bool g_all = false;          // "all": rebuild same-type inventories too, free them when the new proto has none
bool g_scale = false;        // "scale": keep the fraction of the old InitialResource not yet gathered
bool g_log = false;          // "log": one line per unit whose inventory the hook looks at
bool g_typeGiven = false;    // "[UnitType]": only transforms into protos of this unit type
std::int32_t g_type = -1;    // its ID, set on each database load

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

template <typename T>
void SetField(char* base, std::uint32_t offset, T value) {
  *reinterpret_cast<T*>(base + offset) = value;
}

std::uint32_t Global(std::uint32_t va) {
  return *reinterpret_cast<const std::uint32_t*>(static_cast<std::uintptr_t>(va));
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

// Entry r of a resource list, decoded as ResList get 0x44EFFF does; 0 if the list has no array.
// Only raw dwords and float compares: no float arithmetic touches the simulation here.
float Amount(const char* list, std::int32_t r) {
  const auto* entries = Field<const std::uint32_t*>(list, 0);
  if (entries == nullptr) {
    return 0.0f;
  }
  return std::bit_cast<float>(entries[r] ^ Global(kEntryKeys + 4u * static_cast<std::uint32_t>(r)));
}

float Total(const char* list) {
  return std::bit_cast<float>(Field<std::uint32_t>(list, 4) ^ Global(kTotalKey));
}

// True if both lists hold the same resource types (an amount above the engine's threshold).
bool SameTypes(const char* a, const char* b, std::int32_t count) {
  for (std::int32_t r = 0; r < count; ++r) {
    if ((Amount(a, r) > kEpsilon) != (Amount(b, r) > kEpsilon)) {
      return false;
    }
  }
  return true;
}

// "{0: 100, 2: 50}": the resource IDs and amounts a list holds; "none" for no inventory.
std::wstring Describe(const char* list, std::int32_t count) {
  if (list == nullptr) {
    return L"none";
  }
  std::wstring text = L"{";
  for (std::int32_t r = 0; r < count; ++r) {
    const float amount = Amount(list, r);
    if (amount > kEpsilon || amount < -kEpsilon) {
      wchar_t item[48];
      std::swprintf(item, 48, L"%ls%d: %.6g", text.size() > 1 ? L", " : L"", r, static_cast<double>(amount));
      text += item;
    }
  }
  return text + L"}";
}

}  // namespace

extern "C" {
void UhcTransformInventoryHook();

// Called by the hook at 0x9C7625 with the unit and the proto setProto is about to install (the
// player's copy); [unit+5Ch] is still the old proto.
void __stdcall UhcTransformInventory(char* unit, const char* newProto) {
  char* block = Field<char*>(unit, 0xB4);
  if (block == nullptr || newProto == nullptr) {
    return;
  }
  if (g_running == Mode::kKeep) {
    return;
  }
  const bool all = g_all || g_running == Mode::kRebuild || g_running == Mode::kScale;
  const bool scale = g_running == Mode::kScale || (g_running == Mode::kCfg && g_scale);
  if (g_running == Mode::kCfg && g_typeGiven && (g_type < 0 || !kProtoIsType(newProto, g_type))) {
    return;
  }
  const auto count = static_cast<std::int32_t>(Global(kResourceCount));
  if (count < 0 || count > kMaxResources) {
    return;
  }
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  const char* oldProto = Field<const char*>(unit, 0x5C);
  const char* oldRes = oldProto == nullptr ? nullptr : Field<const char*>(oldProto, 0xE0);
  const char* newRes = Field<const char*>(newProto, 0xE0);
  char* inventory = Field<char*>(block, 0x94);

  if (newRes == nullptr) {
    if (inventory == nullptr) {
      return;  // no resources before or after: nothing to do
    }
    if (!all) {
      if (g_log) {
        uhc::Log(L"transformInventory: unit %d (%hs -> %hs) keeps its inventory %ls (the new proto has no "
                 L"resources; \"all\" frees it)",
                 id, ProtoName(oldProto), ProtoName(newProto), Describe(inventory + 4, count).c_str());
      }
      return;
    }
    const std::wstring before = g_log ? Describe(inventory + 4, count) : std::wstring();
    kFreeInventory(inventory);  // as 0x4BA74C / 0x4BA7A7 do for trUnitChangeProtoUnit
    SetField<char*>(block, 0x94, nullptr);
    if (g_log) {
      uhc::Log(L"transformInventory: unit %d (%hs -> %hs) inventory freed: %ls -> none", id, ProtoName(oldProto),
               ProtoName(newProto), before.c_str());
    }
    return;
  }

  if (!all && inventory != nullptr && oldRes != nullptr && SameTypes(oldRes, newRes, count)) {
    if (g_log) {
      uhc::Log(L"transformInventory: unit %d (%hs -> %hs) keeps its inventory %ls (same resource types)", id,
               ProtoName(oldProto), ProtoName(newProto), Describe(inventory + 4, count).c_str());
    }
    return;
  }

  // The fraction of the old InitialResource still in the inventory, read before the copy. Single
  // precision division of two game values: the same result on every machine with this build.
  float factor = 1.0f;
  if (scale && inventory != nullptr && oldRes != nullptr) {
    const float oldTotal = Total(oldRes);
    if (oldTotal > kEpsilon) {
      factor = Total(inventory + 4) / oldTotal;
      if (!(factor >= 0.0f)) {
        factor = 0.0f;
      } else if (factor > 1.0f) {
        factor = 1.0f;
      }
    }
  }

  const bool created = inventory == nullptr;
  const std::wstring before = g_log && !created ? Describe(inventory + 4, count) : std::wstring(L"none");
  if (created) {
    inventory = kRecreateInventory(unit);  // as unit creation does at 0x67DE0F
    if (inventory == nullptr) {
      if (g_log) {
        uhc::Log(L"transformInventory: unit %d (%hs -> %hs) got no inventory (pool exhausted)", id,
                 ProtoName(oldProto), ProtoName(newProto));
      }
      return;
    }
  } else {
    SetField<std::int32_t>(inventory, 0x0C, -1);  // as a fresh inventory from 0x86A865
    SetField<std::int32_t>(inventory, 0x10, -1);
  }
  kResListCopy(inventory + 4, newRes);  // raw encoded entries and the total, as at 0x67DE26
  if (factor < 1.0f) {
    kResListScale(inventory + 4, factor);
  }
  if (g_log) {
    wchar_t scaled[48] = L"";
    if (factor < 1.0f) {
      std::swprintf(scaled, 48, L" (scaled by %.6g)", static_cast<double>(factor));
    }
    uhc::Log(L"transformInventory: unit %d (%hs -> %hs) inventory %ls: %ls -> %ls%ls", id, ProtoName(oldProto),
             ProtoName(newProto), created ? L"created" : L"rebuilt", before.c_str(),
             Describe(inventory + 4, count).c_str(), scaled);
  }
}
}

namespace {

void ReadEffect(void* effect, const void* node) {
  const void* text = nullptr;
  if (!kXmlAttribute(node, "inventory", &text) || text == nullptr) {
    return;
  }
  const char* value = kXmlText(text);
  if (_stricmp(value, "keep") == 0) {
    g_modes[effect] = Mode::kKeep;
  } else if (_stricmp(value, "rebuild") == 0) {
    g_modes[effect] = Mode::kRebuild;
  } else if (_stricmp(value, "scale") == 0) {
    g_modes[effect] = Mode::kScale;
  } else {
    uhc::Log(L"transformInventory: inventory='%hs' is not keep, rebuild or scale; ignored", value);
    return;
  }
  if (g_log) {
    uhc::Log(L"transformInventory: an effect has inventory='%hs'", value);
  }
}

void BeforeApply(void* effect) {
  const auto found = g_modes.find(effect);
  g_running = found == g_modes.end() ? Mode::kCfg : found->second;
}

void AfterApply(void*) { g_running = Mode::kCfg; }

void NewDatabase(char*) { g_modes.clear(); }

}  // namespace

namespace uhc {

Outcome ApplyTransformInventory(const Config& config) {
  const Config::Args* args = config.First("transformInventory");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool all = false;
  bool scale = false;
  bool log = false;
  std::string typeName;
  bool typeGiven = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "all") == 0) {
      all = true;
    } else if (_stricmp(arg.c_str(), "scale") == 0) {
      scale = true;
    } else if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (!typeGiven) {
      typeName = arg;
      typeGiven = true;
    } else {
      Log(L"transformInventory: unexpected argument %hs (expected: [all] [scale] [UnitType] [log]); feature not "
          L"applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }

  // Not kTransformSetProto: transformUpdatesLOS writes its jmp there.
  if (!VerifyAll("transformInventory",
                 {&sites::kTransformInvHook, &sites::kTransformProtoLookup, &sites::kTransformKbRemove,
                  &sites::kTransformPushProto, &sites::kTransformKbReAdd, &sites::kInventorySeed,
                  &sites::kInventoryRecreate, &sites::kInventoryFree, &sites::kResListCopy, &sites::kResListScale,
                  &sites::kResListTotal, &sites::kIsA, &sites::kXmlAttribute, &sites::kXmlText})) {
    return Outcome::kFailed;
  }
  if (typeGiven && !RequestAbstractUnitType(typeName.c_str(), &g_type)) {
    return Outcome::kFailed;
  }
  g_all = all;
  g_scale = scale;
  g_log = log;
  g_typeGiven = typeGiven;
  if (!WriteJmp(sites::kTransformInvHook.va, reinterpret_cast<const void*>(&UhcTransformInventoryHook), 7)) {
    return Outcome::kFailed;
  }
  if (!OnDatabaseLoad(&NewDatabase) || !AddTransformEffectReader({&ReadEffect, &BeforeApply, &AfterApply})) {
    Log(L"transformInventory: no inventory= on effects; the key works from the cfg");
  }
  Log(L"transformInventory: units transformed in place (TransformUnit, revolution)%hs%hs take their new proto's "
      L"InitialResource %ls%ls%ls (multiplayer unverified)",
      typeGiven ? " into protos of unittype " : "", typeGiven ? typeName.c_str() : "",
      all ? L"always, and lose their inventory when it has none" : L"when the resource types differ",
      scale ? L", scaled by the fraction left" : L"", log ? L", every transform logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
