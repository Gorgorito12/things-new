// multiarmor: a proto may carry one armor per damage type, and tech effects may change one of
// them by name.
//
// Stock keeps one armor per proto: the damage type byte [proto+1D3h] and the value [proto+C4h].
// Each <Armor type="..." value="..."/> overwrites them (the handler 0x5F5E62 stores at
// 0x5F5EB7), and the getter 0x49B323 returns the value only for that one damage type. The Data
// effect subtype Armor (5Ch) changes [proto+C4h] whatever damage type the data names: stock
// reads no damagetype attribute.
//
// With the key:
// - every <Armor> of a proto is recorded (by damage type) in a table kept beside the proto; the
//   stock fields still hold the last one, so stock code that reads them sees what it saw;
// - the getter returns, for a damage type other than the stock one, that type's recorded value;
// - an Armor effect with damagetype="<type>" changes that type's value, through the stock value
//   function 0x7F892A with the same relativity and amount; for the stock type (or without the
//   attribute) the stock effect runs unchanged. The effect's type is read in a wrapper of
//   BDataEffect::setData (vtable slot); wrappers of protoUnitApply / Unapply and playerApply /
//   Unapply (the tech path, through 0x8D842B) make it the current type during their call, and
//   hooks on the Armor (5Ch) case of applyData (0x8FAE52) and unapplyData (0x8FC144) apply it;
// - a copied proto (0x67E011, the per-player clone) gets a copy of the table, and a destroyed one
//   (0x58633D) loses it.
// The table is not saved in saved games: a loaded game has each proto's data values again.
#include <windows.h>

#include <cstdint>
#include <cstring>
#include <mutex>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcArmorStoreHook();
void UhcArmorGetterHook();
void UhcProtoDtorHook();
void UhcProtoCopyHook();
void UhcArmorApplyCaseHook();
void UhcArmorUnapplyCaseHook();
}

namespace {

constexpr int kMaxArmors = 8;

struct ArmorSet {
  int count = 0;
  std::uint8_t type[kMaxArmors] = {};
  float value[kMaxArmors] = {};

  float* Find(std::uint8_t t) {
    for (int i = 0; i < count; ++i) {
      if (type[i] == t) {
        return &value[i];
      }
    }
    return nullptr;
  }
  float* FindOrAdd(std::uint8_t t) {
    if (float* v = Find(t)) {
      return v;
    }
    if (count == kMaxArmors) {
      return nullptr;
    }
    type[count] = t;
    value[count] = 0.0f;
    return &value[count++];
  }
};

std::mutex g_lock;
std::unordered_map<const void*, ArmorSet> g_armors;          // by proto
std::unordered_map<const void*, std::uint8_t> g_effectTypes;  // Armor effects with a damagetype
void* g_damageTypeContext = nullptr;  // the parse context that owns the damage type list
bool g_any = false;                   // some proto has a recorded armor besides its stock one

using SetDataFn = bool(__thiscall*)(void* effect, const void* node);
using ProtoApplyFn = void(__thiscall*)(void* effect, void* player, std::int32_t arg, void* proto);
using PlayerApplyFn = bool(__thiscall*)(void* effect, void* player, void* unit, std::int32_t arg);
using PlayerUnapplyFn = void(__thiscall*)(void* effect, void* player, void* unit, std::int32_t arg);
using XmlAttribute = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlText = const char*(__thiscall*)(const void* text);
using DamageTypeLookup = const char*(__thiscall*)(void* ctx, const char* name);
using EffectValueApply = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);

SetDataFn g_setData = nullptr;
ProtoApplyFn g_apply = nullptr;
ProtoApplyFn g_unapply = nullptr;
PlayerApplyFn g_playerApply = nullptr;
PlayerUnapplyFn g_playerUnapply = nullptr;
const auto kXmlAttribute = reinterpret_cast<XmlAttribute>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlText>(0x00402733);
const auto kDamageTypeLookup = reinterpret_cast<DamageTypeLookup>(0x005F55EA);
const auto kEffectValueApply = reinterpret_cast<EffectValueApply>(0x007F892A);

bool g_loggedEffect = false;
bool g_loggedExtra = false;
bool g_loggedTyped = false;

std::uint8_t StockType(const char* proto) { return *reinterpret_cast<const std::uint8_t*>(proto + 0x1D3); }

const char* ProtoName(const char* proto) {
  const char* name = *reinterpret_cast<char* const*>(proto + 0x10);
  return name != nullptr ? name : "?";
}

bool __fastcall SetDataWrapper(char* effect, void* /*edx*/, const void* node) {
  const bool ok = g_setData(effect, node);
  const void* text = nullptr;
  int damageType = -1;
  if (ok && node != nullptr && g_damageTypeContext != nullptr && kXmlAttribute(node, "damagetype", &text) &&
      text != nullptr) {
    const char* name = kXmlText(text);
    const char* entry = name == nullptr ? nullptr : kDamageTypeLookup(g_damageTypeContext, name);
    if (entry != nullptr) {
      damageType = *reinterpret_cast<const std::int32_t*>(entry + 8);
    } else if (name != nullptr) {
      uhc::Log(L"multiarmor: unknown damagetype \"%hs\" in a tech effect; it changes the stock armor", name);
    }
  }
  std::lock_guard<std::mutex> guard(g_lock);
  if (damageType >= 0 && damageType < 256) {
    if (!g_loggedTyped) {
      g_loggedTyped = true;
      uhc::Log(L"hook reached: multiarmor damagetype of a tech effect (BDataEffect::setData)");
    }
    g_effectTypes[effect] = static_cast<std::uint8_t>(damageType);
  } else {
    g_effectTypes.erase(effect);
  }
  return ok;
}

// The damagetype of the effect being applied now (-1: none). The four BDataEffect entry points
// set it around their stock call; the Armor case of applyData / unapplyData reads it. The
// simulation applies effects on one thread, one at a time.
int g_currentType = -1;

int EffectType(const void* effect) {
  std::lock_guard<std::mutex> guard(g_lock);
  const auto it = g_effectTypes.find(effect);
  return it == g_effectTypes.end() ? -1 : it->second;
}

struct CurrentType {
  int saved;
  explicit CurrentType(const void* effect) : saved(g_currentType) { g_currentType = EffectType(effect); }
  ~CurrentType() { g_currentType = saved; }
  CurrentType(const CurrentType&) = delete;
  CurrentType& operator=(const CurrentType&) = delete;
};

void __fastcall ProtoApplyWrapper(char* effect, void* /*edx*/, void* player, std::int32_t arg, void* proto) {
  CurrentType current(effect);
  g_apply(effect, player, arg, proto);
}

void __fastcall ProtoUnapplyWrapper(char* effect, void* /*edx*/, void* player, std::int32_t arg, void* proto) {
  CurrentType current(effect);
  g_unapply(effect, player, arg, proto);
}

bool __fastcall PlayerApplyWrapper(char* effect, void* /*edx*/, void* player, void* unit, std::int32_t arg) {
  CurrentType current(effect);
  return g_playerApply(effect, player, unit, arg);
}

void __fastcall PlayerUnapplyWrapper(char* effect, void* /*edx*/, void* player, void* unit, std::int32_t arg) {
  CurrentType current(effect);
  g_playerUnapply(effect, player, unit, arg);
}

bool ReplaceSlot(const uhc::Site& site, const void* wrapper, void** original) {
  *original = *reinterpret_cast<void* const*>(site.va);
  return uhc::WriteDword(site.va, reinterpret_cast<std::uint32_t>(wrapper));
}

}  // namespace

extern "C" {

void __cdecl UhcArmorRecord(void* ctx, const void* proto, std::uint32_t damageType, std::uint32_t valueBits) {
  float value;
  std::memcpy(&value, &valueBits, sizeof value);
  std::lock_guard<std::mutex> guard(g_lock);
  g_damageTypeContext = ctx;
  ArmorSet& set = g_armors[proto];
  if (float* v = set.FindOrAdd(static_cast<std::uint8_t>(damageType))) {
    *v = value;
  }
  if (set.count > 1) {
    g_any = true;
    if (!g_loggedExtra) {
      g_loggedExtra = true;
      uhc::Log(L"multiarmor: %hs has %d armors", ProtoName(static_cast<const char*>(proto)), set.count);
    }
  }
}

std::uint32_t __stdcall UhcArmorFor(const char* proto, std::uint32_t damageType) {
  float value = 0.0f;
  if (StockType(proto) == static_cast<std::uint8_t>(damageType)) {
    value = *reinterpret_cast<const float*>(proto + 0xC4);
  } else if (g_any) {
    std::lock_guard<std::mutex> guard(g_lock);
    const auto it = g_armors.find(proto);
    if (it != g_armors.end()) {
      if (const float* v = it->second.Find(static_cast<std::uint8_t>(damageType))) {
        value = *v;
      }
    }
  }
  std::uint32_t bits;
  std::memcpy(&bits, &value, sizeof bits);
  return bits;
}

// The Armor case of applyData / unapplyData: true if it changed a recorded armor (the current
// effect names a damage type other than the target's stock one), false to run the stock case.
bool __cdecl UhcArmorTypedEffect(char* target, const char* base, std::uint32_t amountBits, std::uint32_t relativity,
                                 std::uint32_t unapply) {
  const int type = g_currentType;
  if (type < 0 || target == nullptr || static_cast<std::uint8_t>(type) == StockType(target)) {
    return false;
  }
  float amount;
  std::memcpy(&amount, &amountBits, sizeof amount);
  if (base == nullptr) {
    base = target;
  }
  std::lock_guard<std::mutex> guard(g_lock);
  float baseValue = 0.0f;
  if (StockType(base) == static_cast<std::uint8_t>(type)) {
    baseValue = *reinterpret_cast<const float*>(base + 0xC4);
  } else if (const auto b = g_armors.find(base); b != g_armors.end()) {
    if (const float* v = b->second.Find(static_cast<std::uint8_t>(type))) {
      baseValue = *v;
    }
  }
  float* value = g_armors[target].FindOrAdd(static_cast<std::uint8_t>(type));
  g_any = true;
  if (value == nullptr) {
    return true;  // the table is full: drop the change rather than touch the stock armor
  }
  kEffectValueApply(static_cast<std::uint8_t>(relativity), value, baseValue, amount, unapply != 0);
  if (!g_loggedEffect) {
    g_loggedEffect = true;
    uhc::Log(L"multiarmor: an Armor effect changed damage type %d of %hs (now %.3f; stock type %u kept)", type,
             ProtoName(target), static_cast<double>(*value), StockType(target));
  }
  return true;
}

void __cdecl UhcArmorErase(const void* proto) {
  std::lock_guard<std::mutex> guard(g_lock);
  g_armors.erase(proto);
}

void __cdecl UhcArmorCopy(const void* dst, const void* src) {
  if (src == nullptr || dst == src) {
    return;
  }
  std::lock_guard<std::mutex> guard(g_lock);
  const auto it = g_armors.find(src);
  if (it == g_armors.end()) {
    g_armors.erase(dst);
  } else {
    g_armors[dst] = it->second;
  }
}

}  // extern "C"

namespace uhc {

Outcome ApplyMultiArmor(const Config& config) {
  if (config.First("multiarmor") == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("multiarmor",
                 {&sites::kArmorStore, &sites::kArmorGetter, &sites::kProtoDtorHead, &sites::kProtoCopyHead,
                  &sites::kDataEffectSetDataSlot, &sites::kDataEffectApplySlot, &sites::kDataEffectUnapplySlot,
                  &sites::kDataEffectPlayerApplySlot, &sites::kDataEffectPlayerUnapplySlot,
                  &sites::kDataApplyArmorCase, &sites::kDataUnapplyArmorCase, &sites::kEffectValueApply,
                  &sites::kXmlAttribute, &sites::kXmlText, &sites::kDamageTypeLookup})) {
    return Outcome::kFailed;
  }
  void* setData = nullptr;
  void* apply = nullptr;
  void* unapply = nullptr;
  void* playerApply = nullptr;
  void* playerUnapply = nullptr;
  if (!WriteJmp(sites::kArmorStore.va, reinterpret_cast<const void*>(&UhcArmorStoreHook), sites::kArmorStore.size) ||
      !WriteJmp(sites::kArmorGetter.va, reinterpret_cast<const void*>(&UhcArmorGetterHook), sites::kArmorGetter.size) ||
      !WriteJmp(sites::kProtoDtorHead.va, reinterpret_cast<const void*>(&UhcProtoDtorHook), sites::kProtoDtorHead.size) ||
      !WriteJmp(sites::kProtoCopyHead.va, reinterpret_cast<const void*>(&UhcProtoCopyHook), sites::kProtoCopyHead.size) ||
      !WriteJmp(sites::kDataApplyArmorCase.va, reinterpret_cast<const void*>(&UhcArmorApplyCaseHook),
                sites::kDataApplyArmorCase.size) ||
      !WriteJmp(sites::kDataUnapplyArmorCase.va, reinterpret_cast<const void*>(&UhcArmorUnapplyCaseHook),
                sites::kDataUnapplyArmorCase.size) ||
      !ReplaceSlot(sites::kDataEffectSetDataSlot, reinterpret_cast<const void*>(&SetDataWrapper), &setData) ||
      !ReplaceSlot(sites::kDataEffectApplySlot, reinterpret_cast<const void*>(&ProtoApplyWrapper), &apply) ||
      !ReplaceSlot(sites::kDataEffectUnapplySlot, reinterpret_cast<const void*>(&ProtoUnapplyWrapper), &unapply) ||
      !ReplaceSlot(sites::kDataEffectPlayerApplySlot, reinterpret_cast<const void*>(&PlayerApplyWrapper),
                   &playerApply) ||
      !ReplaceSlot(sites::kDataEffectPlayerUnapplySlot, reinterpret_cast<const void*>(&PlayerUnapplyWrapper),
                   &playerUnapply)) {
    return Outcome::kFailed;
  }
  g_setData = reinterpret_cast<SetDataFn>(setData);
  g_apply = reinterpret_cast<ProtoApplyFn>(apply);
  g_unapply = reinterpret_cast<ProtoApplyFn>(unapply);
  g_playerApply = reinterpret_cast<PlayerApplyFn>(playerApply);
  g_playerUnapply = reinterpret_cast<PlayerUnapplyFn>(playerUnapply);
  Log(L"multiarmor: protos keep one armor per damage type; Armor effects follow their damagetype");
  return Outcome::kApplied;
}

}  // namespace uhc
