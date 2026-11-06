#include "techsubtypes.h"

#include <cstddef>
#include <cstring>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" {
void UhcTechSubtypeAttrHook();     // hooks/techsubtype_hooks.asm
void UhcTechSubtypeLookupHook();
void UhcTechSubtypeLookupStock();
void UhcTechSubtypeApplyHook();
void UhcTechSubtypeUnapplyHook();
char* g_uhcSubtypeEffect = nullptr;       // the effect whose subtype is being read, and its XML node
const char* g_uhcSubtypeNode = nullptr;
}

namespace {

constexpr std::size_t kMaxSubtypes = 32;
constexpr std::int32_t kFirstId = 0x100;  // above every stock subtype; the stock switches stop at 63h
constexpr std::uint32_t kNameLookupHead = 0x0061FF5D;  // the lookup
constexpr std::uint32_t kAttributeCall = 0x006206B2;   // setData's read of the attribute subtype
constexpr std::uint32_t kOtherCaller = 0x00621C2E;     // the lookup's other caller, which tests for one stock ID
constexpr std::uint32_t kApplySwitch = 0x008F978D;     // cmp eax,63h / ja (9 B)
constexpr std::uint32_t kUnapplySwitch = 0x008FB051;   // cmp eax,5Eh / ja (9 B)
constexpr std::size_t kEffectAction = 0x10;            // BDataEffect: the action's ID, -1 for allactions
constexpr std::size_t kEffectFlags = 9;                // bit 40h: allactions="1", read before the subtype
constexpr std::uint8_t kEffectAfterLoad = 0x20;         // in those flags
constexpr std::size_t kProtoActions = 0x44;            // the action set
constexpr std::size_t kActionList = 0x1C;              // in the set: the array of actions, and its count at +20h
constexpr std::size_t kActionId = 4;                   // in an action
constexpr std::size_t kTypeNames = 0x190;              // in the database: the unit type name table
constexpr std::size_t kFirstAbstract = 0x19B0;         // in the database: the first abstract type's ID

using NameLookupFn = std::int32_t(__thiscall*)(void* db, const char* name);
const auto kNameLookup = reinterpret_cast<NameLookupFn>(&UhcTechSubtypeLookupStock);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using ActionIdByNameFn = std::int32_t(__thiscall*)(void* db, const void* attribute);
const auto kActionIdByName = reinterpret_cast<ActionIdByNameFn>(0x005E0C64);
using ActionByIdFn = char*(__thiscall*)(const void* set, std::int32_t id);
const auto kActionById = reinterpret_cast<ActionByIdFn>(0x0048D22E);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
using NameBucketFn = std::int32_t(__thiscall*)(const void* table, const char* name);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
using NameFindFn = bool(__thiscall*)(const void* table, const char* name, std::int32_t bucket, std::int32_t* id);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);

struct Subtype {
  const char* name;
  uhc::TechSubtypeHandler handler;              // on a proto
  uhc::TechActionSubtypeHandler actionHandler;  // or on its actions
  uhc::TechTypeSubtypeHandler typeHandler;      // or with a unit type
};

Subtype g_subtypes[kMaxSubtypes] = {};
std::size_t g_count = 0;
bool g_installed = false;
uhc::UnknownTechSubtype g_unknown = nullptr;

// What stock does in setData for TrackRating: only the subtypes it knows read the attribute.
bool ReadAction(void* db, const char* name, char* effect, const char* node) {
  auto* action = reinterpret_cast<std::int32_t*>(effect + kEffectAction);
  if ((static_cast<std::uint8_t>(effect[kEffectFlags]) & 0x40) != 0) {
    *action = -1;
    return true;
  }
  const void* attribute = nullptr;
  if (!kXmlAttribute(node, "action", &attribute) || attribute == nullptr) {
    uhc::Log(L"tech subtypes: a %hs effect names no action and has no allactions='1'; effect dropped", name);
    return false;
  }
  *action = kActionIdByName(db, attribute);
  if (*action == -1) {
    uhc::Log(L"tech subtypes: a %hs effect names an unknown action; effect dropped", name);
    return false;
  }
  return true;
}

// The attribute unittype, into the field the action's ID uses.
bool ReadType(void* db, const char* name, char* effect, const char* node) {
  const void* attribute = nullptr;
  if (!kXmlAttribute(node, "unittype", &attribute) || attribute == nullptr) {
    uhc::Log(L"tech subtypes: a %hs effect names no unittype; effect dropped", name);
    return false;
  }
  const char* text = kXmlText(attribute);
  const char* table = static_cast<const char*>(db) + kTypeNames;
  std::int32_t id = -1;
  if (text == nullptr || !kNameFind(table, text, kNameBucket(table, text), &id) || id < 0) {
    uhc::Log(L"tech subtypes: a %hs effect names the unknown unit type %hs; effect dropped", name,
             text == nullptr ? "" : text);
    return false;
  }
  if (id < *reinterpret_cast<const std::int32_t*>(static_cast<const char*>(db) + kFirstAbstract)) {
    uhc::Log(L"tech subtypes: a %hs effect names %hs, a proto and not an abstract type; effect dropped", name, text);
    return false;
  }
  *reinterpret_cast<std::int32_t*>(effect + kEffectAction) = id;
  // A proto's types are not in a saved game: the pass after a load, 0x94DDEA, runs the effects with this flag again.
  effect[kEffectFlags] = static_cast<char>(effect[kEffectFlags] | kEffectAfterLoad);
  return true;
}

bool RunOnActions(const Subtype& subtype, char* proto, const char* base, float amount, std::uint8_t relativity,
                  bool unapply, std::int32_t actionId, bool allActions) {
  const char* set = *reinterpret_cast<char* const*>(proto + kProtoActions);
  const char* baseSet = *reinterpret_cast<char* const*>(base + kProtoActions);
  if (set == nullptr || baseSet == nullptr) {
    return false;
  }
  if (!allActions) {
    if (char* action = kActionById(set, actionId)) {
      subtype.actionHandler(action, kActionById(baseSet, actionId), proto, amount, relativity, unapply);
    }
    return true;
  }
  char* const* actions = *reinterpret_cast<char* const* const*>(set + kActionList);
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(set + kActionList + 4);
  for (std::int32_t i = 0; i < count; ++i) {
    const std::int32_t id = *reinterpret_cast<const std::int32_t*>(actions[i] + kActionId);
    subtype.actionHandler(actions[i], kActionById(baseSet, id), proto, amount, relativity, unapply);
  }
  return true;
}

bool Install() {
  if (!g_installed) {
    if (!uhc::VerifyAll("tech subtypes", {&uhc::sites::kDataSubtypeLookupHead, &uhc::sites::kDataSubtypeAttrCall,
                                          &uhc::sites::kDataApplySwitch, &uhc::sites::kDataUnapplySwitch,
                                          &uhc::sites::kDataActionAttribute, &uhc::sites::kDataAllActionsApply,
                                          &uhc::sites::kDataAllActionsUnapply}) ||
        !uhc::WriteJmp(kNameLookupHead, reinterpret_cast<const void*>(&UhcTechSubtypeLookupHook), 5) ||
        !uhc::WriteCall(kAttributeCall, reinterpret_cast<const void*>(&UhcTechSubtypeAttrHook)) ||
        !uhc::WriteJmp(kApplySwitch, reinterpret_cast<const void*>(&UhcTechSubtypeApplyHook), 9) ||
        !uhc::WriteJmp(kUnapplySwitch, reinterpret_cast<const void*>(&UhcTechSubtypeUnapplyHook), 9)) {
      return false;
    }
    g_installed = true;
  }
  return true;
}

bool Add(const Subtype& subtype) {
  if (g_count == kMaxSubtypes) {
    uhc::Log(L"tech subtypes: no room for %hs", subtype.name);
    return false;
  }
  if (!Install()) {
    return false;
  }
  g_subtypes[g_count++] = subtype;
  return true;
}


}  // namespace

// The head of the lookup. Its head, not the call in setData: another DLL may replace that call, and what
// it does not know still ends here.
extern "C" std::int32_t __stdcall UhcTechSubtypeLookup(void* db, const char* name, std::uint32_t returnAddress) {
  const std::int32_t stock = kNameLookup(db, name);
  if (stock != -1 || name == nullptr || returnAddress == kOtherCaller) {
    return stock;
  }
  for (std::size_t i = 0; i < g_count; ++i) {
    if (_stricmp(name, g_subtypes[i].name) != 0) {
      continue;
    }
    if (g_subtypes[i].actionHandler != nullptr && !ReadAction(db, name, g_uhcSubtypeEffect, g_uhcSubtypeNode)) {
      return -1;
    }
    if (g_subtypes[i].typeHandler != nullptr && !ReadType(db, name, g_uhcSubtypeEffect, g_uhcSubtypeNode)) {
      return -1;
    }
    return kFirstId + static_cast<std::int32_t>(i);
  }
  if (g_unknown != nullptr) {
    g_unknown(name);
  }
  return -1;
}

// From the two switch hooks, for a subtype at or above kFirstId. False: stock's failure exit.
extern "C" bool __stdcall UhcTechSubtypeRun(std::int32_t id, char* proto, const char* base, float amount,
                                            std::uint32_t relativity, std::uint32_t unapply, std::int32_t actionId,
                                            std::uint32_t allActions) {
  const std::size_t index = static_cast<std::size_t>(id - kFirstId);
  if (index >= g_count) {
    return false;
  }
  const Subtype& subtype = g_subtypes[index];
  if (subtype.typeHandler != nullptr) {
    subtype.typeHandler(proto, base, actionId, unapply != 0);
    return true;
  }
  if (subtype.actionHandler != nullptr) {
    return RunOnActions(subtype, proto, base, amount, static_cast<std::uint8_t>(relativity), unapply != 0, actionId,
                        allActions != 0);
  }
  subtype.handler(proto, base, amount, static_cast<std::uint8_t>(relativity), unapply != 0);
  return true;
}

namespace uhc {

bool AddTechSubtype(const char* name, TechSubtypeHandler handler) { return Add({name, handler, nullptr, nullptr}); }

bool AddTechActionSubtype(const char* name, TechActionSubtypeHandler handler) {
  return Add({name, nullptr, handler, nullptr});
}

bool AddTechTypeSubtype(const char* name, TechTypeSubtypeHandler handler) {
  return Add({name, nullptr, nullptr, handler});
}

bool OnUnknownTechSubtype(UnknownTechSubtype callback) {
  if (!Install()) {
    return false;
  }
  g_unknown = callback;
  return true;
}

}  // namespace uhc
