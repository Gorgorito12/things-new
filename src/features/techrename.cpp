// techRenameEffect (also read as WoL's key enableTechRenameEffect): the tech effect
// <Effect type='SetTechName' tech='T' newName='ID' newRolloverTextID='ID'
// [newLongRolloverTextID='ID']/> gives the tech T new string IDs for the players the effect
// reaches, and only for them.
//
// Stock keeps one BTechTreeNodeData per tech in the database's tech tree (TT0 = [db+5D9Ch],
// 34h bytes each: +0 tech ID, +8 DisplayNameID, +0Ch RolloverTextID, +10h LongRolloverTextID,
// +14h icon, then the prerequisite and effect arrays). Each player's BTechTreeNode (24h bytes,
// created on first use as a copy of the base node, 0x94CC2B) points at that shared NodeData
// through [node+0]; only status, cost and research points are per player. WoL's SetTechName
// writes the new IDs into the shared NodeData, so one civ's tech renames the tech for everyone.
//
// Here the effect's apply gives the player a private copy of the NodeData and points that
// player's node at it. The UI reads a tech's texts through the player's node (0x7103CE and its
// siblings), so the rename shows for that player only. The copy is shallow: the prerequisite and
// effect arrays and the icon stay shared, and research behaves as before.
//
// The effect type is registered as the 18th (ID 17) by a hook in the database init, and created
// by a hook in the effect factory's default case; the hooks are in hooks/techrename_hooks.asm.
// Everything else is a C++ BEffect: a DLL vtable whose methods mirror the stock SetName effect.
#include <windows.h>

#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <cwctype>
#include <map>
#include <string>
#include <utility>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

// Engine layout (docs/engine-symbols.md, "Tech tree and tech effects").
constexpr std::uint32_t kGameGlobal = 0x00C66234;      // game; +13Ch world, +140h database
constexpr std::uint32_t kStockEffectVtable = 0x00B965C0;  // BEffect, 17 slots
constexpr std::size_t kVtableSlots = 17;
constexpr std::size_t kNodeDataSize = 0x34;            // BTechTreeNodeData (ctor 0x6236BE)
constexpr std::int32_t kLastStockType = 0x10;          // Data2; the factory switches on 0..10h
const char kEffectName[] = "SetTechName";

// BEffect (0Ch bytes, ctor 0x620B8F) followed by SetTechName's fields.
struct TechRenameEffect {
  const void* vtable;
  std::int32_t base4;         // -1 (BEffect)
  std::uint8_t type;          // the effect type ID
  std::uint8_t flags;         // 28h: kind 8 (a "general" effect) | 20h (re-applied after a load)
  std::uint8_t pad[2];
  std::int32_t tech;          // the tech to rename
  std::int32_t name;          // new DisplayNameID, -1 = unchanged
  std::int32_t rollover;      // new RolloverTextID, -1 = unchanged
  std::int32_t longRollover;  // new LongRolloverTextID, -1 = unchanged
};
static_assert(offsetof(TechRenameEffect, type) == 0x08 && offsetof(TechRenameEffect, tech) == 0x0C &&
              offsetof(TechRenameEffect, longRollover) == 0x18 && sizeof(TechRenameEffect) == 0x1C);

// NodeData fields the effect writes.
constexpr std::uint32_t kDisplayName = 0x08;
constexpr std::uint32_t kRollover = 0x0C;
constexpr std::uint32_t kLongRollover = 0x10;

using NewFn = void*(__cdecl*)(std::size_t size);
using FreeFn = void(__cdecl*)(void* block);
using EffectTypeByNameFn = std::int32_t(__thiscall*)(char* database, const char* name);
using AddNameFn = std::int32_t(__thiscall*)(char* table, const char* name, const std::int32_t* id);
using TechByNameFn = std::int32_t(__thiscall*)(char* database, const char* name);
using EffectCtorFn = TechRenameEffect*(__thiscall*)(TechRenameEffect* effect, std::uint8_t type);
using EffectStreamFn = bool(__thiscall*)(TechRenameEffect* effect, void* stream, std::int32_t version);
using EffectCopyFn = void(__thiscall*)(TechRenameEffect* effect, const TechRenameEffect* other);
using WriteIntFn = std::int32_t(__thiscall*)(void* stream, std::int32_t value);
using ReadIntFn = std::int32_t(__thiscall*)(void* stream, std::int32_t* value);
using XmlAttributeFn = bool(__thiscall*)(const char* node, const char* name, void** value);
using LocalTechNodeFn = char*(__thiscall*)(char* player, std::int32_t techId);

const auto kNew = reinterpret_cast<NewFn>(0x00401398);
const auto kFree = reinterpret_cast<FreeFn>(0x00401548);
const auto kEffectTypeByName = reinterpret_cast<EffectTypeByNameFn>(0x0061FF1B);
const auto kAddName = reinterpret_cast<AddNameFn>(0x005375AC);
const auto kTechByName = reinterpret_cast<TechByNameFn>(0x00600BE1);
const auto kEffectCtor = reinterpret_cast<EffectCtorFn>(0x00620B8F);
const auto kEffectSave = reinterpret_cast<EffectStreamFn>(0x007F7DB3);
const auto kEffectLoad = reinterpret_cast<EffectStreamFn>(0x007F7E09);
const auto kEffectCopyFrom = reinterpret_cast<EffectCopyFn>(0x007F7E5F);
const auto kWriteInt = reinterpret_cast<WriteIntFn>(0x00A3FEB8);
const auto kReadInt = reinterpret_cast<ReadIntFn>(0x00599121);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kLocalTechNode = reinterpret_cast<LocalTechNodeFn>(0x008D0005);

template <typename T>
T& Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<T*>(const_cast<char*>(base) + offset);
}

char* Game() { return *reinterpret_cast<char**>(kGameGlobal); }
char* Database() { return Game() == nullptr ? nullptr : Field<char*>(Game(), 0x140); }

bool g_log = false;  // "techRenameEffect log": one line per effect read and per rename
bool g_loggedNoNode = false;

// SetTechName's vtable: the stock BEffect's, with slots 0-4 and 15 replaced (filled when the
// feature is applied, after the stock vtable is verified). Slot 16, generalUnapply, stays the
// stock no-op, as for the stock SetName: a tech that stops being active keeps its new name.
std::uintptr_t g_vtable[kVtableSlots];

// The tech names the data used, by tech ID, for the log lines.
std::map<std::int32_t, std::string> g_techNames;

// One NodeData copy per (player ID, tech ID). Never freed or moved (std::map keeps its values in
// place): a node of the running game may point at it. Bounded by 16 players x techs x 34h bytes.
struct NodeDataCopy {
  std::uint32_t words[kNodeDataSize / 4];
};
std::map<std::pair<std::int32_t, std::int32_t>, NodeDataCopy> g_copies;

const char* TechName(std::int32_t tech) {
  const auto it = g_techNames.find(tech);
  return it == g_techNames.end() ? "?" : it->second.c_str();
}

std::string Narrow(const wchar_t* text) {
  const int size = WideCharToMultiByte(CP_ACP, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) {
    return {};
  }
  std::string out(static_cast<std::size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_ACP, 0, text, -1, out.data(), size, nullptr, nullptr);
  return out;
}

// The text of an attribute of the <Effect> node: 0x598F37 hands back the attribute's string
// object, whose first field is its UTF-16 text. False if the attribute is absent.
bool ReadAttribute(const char* node, const char* attribute, const wchar_t** text) {
  void* value = nullptr;
  if (!kXmlAttribute(node, attribute, &value) || value == nullptr) {
    return false;
  }
  const wchar_t* chars = *static_cast<const wchar_t* const*>(value);
  *text = chars == nullptr ? L"" : chars;
  return true;
}

// An optional string ID: absent or -1 keeps the current text. Any other negative value is
// refused: the research message code (0x94D14A) skips a tech whose DisplayNameID is negative.
bool ReadStringId(const char* node, const char* attribute, const wchar_t* tech, std::int32_t* id) {
  *id = -1;
  const wchar_t* text = nullptr;
  if (!ReadAttribute(node, attribute, &text)) {
    return true;
  }
  wchar_t* end = nullptr;
  errno = 0;
  const long value = std::wcstol(text, &end, 10);
  while (end != nullptr && std::iswspace(*end)) {
    ++end;
  }
  if (end == text || end == nullptr || *end != L'\0' || errno == ERANGE || value < -1) {
    uhc::Log(L"techRenameEffect: SetTechName on %ls: %hs='%ls' is not a string ID (a number from 0, or -1 to "
             L"keep the text); this effect is dropped",
             tech, attribute, text);
    return false;
  }
  *id = static_cast<std::int32_t>(value);
  return true;
}

// [0] scalar deleting destructor, as the stock BEffect's (0x7F7E78): back to the base vtable,
// and free the block with the engine's allocator when bit 0 is set.
void* __fastcall EffectDtor(TechRenameEffect* self, void*, std::uint32_t flags) {
  self->vtable = reinterpret_cast<const void*>(kStockEffectVtable);
  if (flags & 1) {
    kFree(self);
  }
  return self;
}

// [1] setData(<Effect> node), from the parse 0x620572. False drops the effect without a message
// from the engine (0x621ECA), so every refusal is logged here.
bool __fastcall EffectSetData(TechRenameEffect* self, void*, const char* node) {
  const wchar_t* techText = nullptr;
  if (node == nullptr || !ReadAttribute(node, "tech", &techText) || *techText == L'\0') {
    uhc::Log(L"techRenameEffect: SetTechName without tech='...'; this effect is dropped");
    return false;
  }
  char* database = Database();
  const std::string techName = Narrow(techText);
  self->tech = (database == nullptr || techName.empty()) ? -1 : kTechByName(database, techName.c_str());
  if (self->tech < 0) {
    uhc::Log(L"techRenameEffect: SetTechName: unknown tech '%ls'; this effect is dropped", techText);
    return false;
  }
  if (!ReadStringId(node, "newName", techText, &self->name) ||
      !ReadStringId(node, "newRolloverTextID", techText, &self->rollover) ||
      !ReadStringId(node, "newLongRolloverTextID", techText, &self->longRollover)) {
    return false;
  }
  if (self->name < 0 && self->rollover < 0 && self->longRollover < 0) {
    uhc::Log(L"techRenameEffect: SetTechName on %ls sets none of newName, newRolloverTextID, "
             L"newLongRolloverTextID; this effect is dropped",
             techText);
    return false;
  }
  g_techNames[self->tech] = techName;
  if (g_log) {
    uhc::Log(L"techRenameEffect: read SetTechName on %hs (tech %d): newName %d, newRolloverTextID %d, "
             L"newLongRolloverTextID %d",
             techName.c_str(), self->tech, self->name, self->rollover, self->longRollover);
  }
  return true;
}

// [2] save and [3] load: the BEffect fields (0x7F7DB3 / 0x7F7E09), then ours, as the stock
// SetName does (0x7F8EC5 / 0x7F8F13).
bool __fastcall EffectSave(TechRenameEffect* self, void*, void* stream, std::int32_t version) {
  return kEffectSave(self, stream, version) && kWriteInt(stream, self->tech) != 0 &&
         kWriteInt(stream, self->name) != 0 && kWriteInt(stream, self->rollover) != 0 &&
         kWriteInt(stream, self->longRollover) != 0;
}

bool __fastcall EffectLoad(TechRenameEffect* self, void*, void* stream, std::int32_t version) {
  return kEffectLoad(self, stream, version) && kReadInt(stream, &self->tech) != 0 &&
         kReadInt(stream, &self->name) != 0 && kReadInt(stream, &self->rollover) != 0 &&
         kReadInt(stream, &self->longRollover) != 0;
}

// [4] copyFrom: the BEffect fields (0x7F7E5F), then ours when the source is a SetTechName too.
void __fastcall EffectCopyFrom(TechRenameEffect* self, void*, const TechRenameEffect* other) {
  if (other == nullptr) {
    return;
  }
  kEffectCopyFrom(self, other);
  if (other->vtable == g_vtable) {
    self->tech = other->tech;
    self->name = other->name;
    self->rollover = other->rollover;
    self->longRollover = other->longRollover;
  }
}

// [15] generalApply(player, source tech, unit, flags), from the dispatcher 0x7F7E97 (kind 8,
// call at 0x7F8111): when the source tech becomes active for a player (0x94DBE6, the whole team
// for a team tech) and again after a saved game is loaded (0x94DF10, effects with flag 20h).
// It reads and writes only data of that player's tech tree, so every machine does the same.
void __fastcall EffectApply(TechRenameEffect* self, void*, char* player, std::int32_t sourceTech, char*,
                            std::uint32_t) {
  char* game = Game();
  if (player == nullptr || game == nullptr || Field<char*>(game, 0x13C) == nullptr) {
    return;
  }
  // The player's node of the tech, created from the base node if it does not exist yet, as the
  // stock research code does (0x857801); 0 without a tech manager or for an unknown tech ID.
  char* node = kLocalTechNode(player, self->tech);
  char* const current = node == nullptr ? nullptr : Field<char*>(node, 0x00);
  const std::int32_t playerId = Field<std::int32_t>(player, 0x00);
  if (current == nullptr) {
    if (!g_loggedNoNode) {
      g_loggedNoNode = true;
      uhc::Log(L"techRenameEffect: player %d has no tech node for tech %d (%hs); not renamed", playerId, self->tech,
               TechName(self->tech));
    }
    return;
  }
  char* copy = reinterpret_cast<char*>(g_copies[{playerId, self->tech}].words);
  const std::int32_t oldName = Field<std::int32_t>(current, kDisplayName);
  const std::int32_t oldRollover = Field<std::int32_t>(current, kRollover);
  const std::int32_t oldLongRollover = Field<std::int32_t>(current, kLongRollover);
  // A node that does not point at the copy yet is new (first rename, another game, a loaded
  // game, a data reload): its NodeData is the database's, so the copy is rebuilt from it. This
  // also refreshes the shared array pointers after the tech tree was rebuilt.
  if (current != copy) {
    std::memcpy(copy, current, kNodeDataSize);
  }
  if (self->name >= 0) {
    Field<std::int32_t>(copy, kDisplayName) = self->name;
  }
  if (self->rollover >= 0) {
    Field<std::int32_t>(copy, kRollover) = self->rollover;
  }
  if (self->longRollover >= 0) {
    Field<std::int32_t>(copy, kLongRollover) = self->longRollover;
  }
  Field<char*>(node, 0x00) = copy;  // last, so a reader of the node sees a complete copy
  if (g_log) {
    uhc::Log(L"techRenameEffect: player %d: tech %d (%hs), from tech %d: name %d -> %d, rollover %d -> %d, long "
             L"rollover %d -> %d (node 0x%08X, NodeData 0x%08X -> copy 0x%08X)",
             playerId, self->tech, TechName(self->tech), sourceTech, oldName, Field<std::int32_t>(copy, kDisplayName),
             oldRollover, Field<std::int32_t>(copy, kRollover), oldLongRollover,
             Field<std::int32_t>(copy, kLongRollover), static_cast<unsigned>(reinterpret_cast<std::uintptr_t>(node)),
             static_cast<unsigned>(reinterpret_cast<std::uintptr_t>(current)),
             static_cast<unsigned>(reinterpret_cast<std::uintptr_t>(copy)));
  }
}

}  // namespace

extern "C" {
std::int32_t g_uhcTechRenameType = -1;

void UhcTechRenameRegisterHook();
void UhcTechRenameFactoryHook();

// From the hook in the database init (FUN_0052277E), after the 17 stock effect types (0..16) are
// registered in the name table at [db+335Ch]; [db+3360h], its name count, is the next free ID.
void __stdcall UhcTechRenameRegister(char* database) {
  const std::int32_t existing = kEffectTypeByName(database, kEffectName);
  if (existing >= 0) {
    if (existing != g_uhcTechRenameType) {
      uhc::Log(L"techRenameEffect: the effect type %hs already exists (ID %d, from other code); SetTechName "
               L"effects are left to it",
               kEffectName, existing);
    }
    return;
  }
  std::int32_t id = Field<std::int32_t>(database, 0x3360);
  // The factory takes the type as a byte and handles 0..10h itself; only IDs above reach the
  // default case the factory hook replaces.
  if (id <= kLastStockType || id > 0xFF) {
    uhc::Log(L"techRenameEffect: the next effect type ID would be %d (expected 17); SetTechName not registered", id);
    return;
  }
  kAddName(database + 0x335C, kEffectName, &id);
  if (kEffectTypeByName(database, kEffectName) != id) {
    uhc::Log(L"techRenameEffect: registering the effect type %hs failed; SetTechName effects are dropped",
             kEffectName);
    return;
  }
  g_uhcTechRenameType = id;
  uhc::Log(L"techRenameEffect: effect type %hs -> %d", kEffectName, id);
}

// From the hook in the effect factory's default case, for our type: a new SetTechName effect,
// allocated like every stock effect (operator new 0x401398, freed by the destructor). 0 makes
// the parse drop the effect.
void* __stdcall UhcTechRenameCreate() {
  auto* effect = static_cast<TechRenameEffect*>(kNew(sizeof(TechRenameEffect)));
  if (effect == nullptr) {
    uhc::Log(L"techRenameEffect: out of memory for a SetTechName effect; dropped");
    return nullptr;
  }
  kEffectCtor(effect, static_cast<std::uint8_t>(g_uhcTechRenameType));
  effect->vtable = g_vtable;
  effect->tech = -1;
  effect->name = -1;
  effect->rollover = -1;
  effect->longRollover = -1;
  return effect;
}
}

namespace uhc {

Outcome ApplyTechRenameEffect(const Config& config) {
  const char* key = "techRenameEffect";
  const Config::Args* args = config.First(key);
  if (args == nullptr) {
    key = "enableTechRenameEffect";  // WoL's key for its (global) SetTechName
    args = config.First(key);
  }
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"%hs: unexpected argument %hs (expected: [log]); feature not applied", key, arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("techRenameEffect",
                 {&sites::kTechRenameRegister, &sites::kTechRenameTypeByName, &sites::kTechRenameFactoryHead,
                  &sites::kTechRenameFactoryDefault, &sites::kTechRenameEffectParse, &sites::kTechRenameEffectCtor,
                  &sites::kTechRenameEffectVtable, &sites::kTechRenameApplyCall, &sites::kTechRenameLocalTechNode})) {
    return Outcome::kFailed;
  }

  std::memcpy(g_vtable, reinterpret_cast<const void*>(kStockEffectVtable), sizeof(g_vtable));
  g_vtable[0] = reinterpret_cast<std::uintptr_t>(&EffectDtor);
  g_vtable[1] = reinterpret_cast<std::uintptr_t>(&EffectSetData);
  g_vtable[2] = reinterpret_cast<std::uintptr_t>(&EffectSave);
  g_vtable[3] = reinterpret_cast<std::uintptr_t>(&EffectLoad);
  g_vtable[4] = reinterpret_cast<std::uintptr_t>(&EffectCopyFrom);
  g_vtable[15] = reinterpret_cast<std::uintptr_t>(&EffectApply);

  // 0x524CB5: cmp dword ptr [esi+3504h],0 (7 bytes), after the last stock effect type.
  // 0x62146F: push 51Fh (5 bytes), the factory's default case.
  if (!WriteJmp(0x00524CB5, reinterpret_cast<const void*>(&UhcTechRenameRegisterHook), 7) ||
      !WriteJmp(sites::kTechRenameFactoryDefault.va, reinterpret_cast<const void*>(&UhcTechRenameFactoryHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"%hs: the tech effect SetTechName (tech, newName, newRolloverTextID, newLongRolloverTextID) renames a "
      L"tech for the players it reaches%ls (multiplayer unverified)",
      key, g_log ? L", every rename logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
