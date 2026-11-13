# Code for WoL: Data and scripting

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

Contents:
- [dataLint](#datalint)
- [customHotkeyContexts](#customhotkeycontexts)
- [techRenameEffect](#techrenameeffect)

## dataLint

Contract: [dataLint](../porting-to-another-dll.md#datalint).

Besides the core helpers, it needs: [`actiontags.h`](helpers.md#action-tags), [`modifytypes.h`](helpers.md#modify-types), [`techsubtypes.h`](helpers.md#tech-subtypes), [`unittypes.h`](helpers.md#extra-abstract-unit-types).

Sites: `LintProtoTagMiss` `0x5F62A2` (8 B), `LintProtoActionMiss` `0x5FA202` (6 B), `LintUnitTypeMiss` `0x5FCB61` (5 B), `LintTechNode` `0x61FDB8` (7 B), `LintTechLoadCall` `0x61FE4A` (5 B), `LintEffectDrop` `0x6205E9` (6 B), `LintEffectType` `0x65BC56` (5 B).

### src/features/datalint.cpp

```cpp
// dataLint [log] [file]: says what the data asks for and the game drops, while the data loads. Stock skips all of it
// without a word: a <UnitType> or a proto tag it does not know, an action tag, a Data subtype, a <ModifyType> with no
// stat, a <ProtoAction> whose action is not in the unit's tactics.
//
// Nothing here changes what the game does. The sources are the shared hooks (actiontags, modifytypes, techsubtypes)
// and three reads at the exe's own failure exits. Each name is kept once, with how many times it came and the first
// place, and all of it is written when the load ends: at most kMaxLines per kind in the log, or all of it with `log`,
// and with `file` the whole report in dataLint.txt, next to the log, with every deleted effect. After the load nothing
// runs, since the hooks are on code that only runs while the data loads.
//
// A new tag read by a key goes in kKnownTags too, or the key's own tag is reported as unknown.
#include <windows.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <string>
#include <vector>

#include "../actiontags.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../hostfiles.h"
#include "../log.h"
#include "../modifytypes.h"
#include "../patch.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

extern "C" {
void UhcLintUnitTypeHook();     // hooks/datalint_hooks.asm
void UhcLintProtoTagHook();
void UhcLintProtoActionHook();
void UhcLintDoneHook();
void UhcLintTechHook();
void UhcLintEffectHook();
void UhcLintEffectTypeHook();
const char* g_uhcLintTech = nullptr;  // the <Tech> node being read
extern const char* g_uhcSubtypeNode;  // techsubtypes.cpp: the <Effect> node of the last subtype read
}

namespace {

constexpr std::uint32_t kUnitTypeMiss = 0x005FCB61;    // the <UnitType> handler's failure: push 0EB4h
constexpr std::uint32_t kProtoTagMiss = 0x005F62A2;    // after the tag table's find: test al,al / je / mov edx
constexpr std::uint32_t kProtoActionMiss = 0x005FA202;  // je 5FC891h: no such action in the proto's set
constexpr std::uint32_t kTechLoadCall = 0x0061FE4A;    // the call of the tech parser, the last thing the data load reads
constexpr std::uint32_t kTechNode = 0x0061FDB8;        // the tech parser's loop over the <Tech> nodes
constexpr std::uint32_t kEffectDrop = 0x006205E9;      // je 621ECAh: setData was false
constexpr std::uint32_t kEffectType = 0x0065BC56;      // push 512h: no such effect type
constexpr int kMaxLines = 40;

enum Kind {
  kUnitType,
  kProtoTag,
  kActionTag,
  kSubtype,
  kEffect,
  kModifyType,
  kProtoAction,
  kKinds,
};

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using XmlTextFn = const char*(__thiscall*)(const void* attribute);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);

constexpr const wchar_t* kKindText[kKinds] = {
    L"unknown <UnitType>",         L"unknown proto tag",
    L"unknown action tag",         L"unknown Data subtype",
    L"<Effect> the game deletes",  L"<ModifyType> with no stat",
    L"<ProtoAction> not in the tactics",
};

struct Seen {
  int count = 0;
  std::wstring first;
};

// What the keys read: with such a key on the tag is not a mistake, and with it off the line says so.
struct KnownTag {
  const wchar_t* name;
  const char* key;
};

constexpr KnownTag kKnownTags[] = {
    {L"NoStack", "auraStacking"},
    {L"NativePreview", "nativePreview"},
    {L"SnareFactor", "snareValues"},
    {L"SnareDuration", "snareValues"},
    {L"ForbidAbstractType", "auraStacking"},
    {L"AttachProtoUnit", "damageOverTime"},
    {L"AttachMaxStacks", "damageOverTime"},
    {L"AttachSnare", "damageOverTime"},
    {L"AttachTickText", "damageOverTime"},
    {L"MaxSpread", "spreadAnyAccuracy"},
    {L"DirectionalAttack", "directionalAttack"},
    {L"DirectionalFiringRange", "directionalAttack"},
    {L"DirectionalWidth", "directionalAttack"},
    {L"DirectionalDamageFactor", "directionalAttack"},
    {L"SpreadFactor", "spreadAnyAccuracy"},
    {L"ModifyAmount", "unitResourceAuras"},
    {L"ModifyTargetLimit", "unitResourceAuras"},
    {L"TargetGaia", "unitResourceAuras"},
    {L"IncludeGaia", "unitResourceAuras"},
    {L"SingleUnit", "unitResourceAuras"},
    {L"DoNotIgnoreDead", "unitResourceAuras"},
    {L"DeadExclusive", "unitResourceAuras"},
    {L"ForbidUnitType", "unitResourceAuras"},
    {L"ForceUpdateMode", "unitResourceAuras"},
    {L"ShowUnitResourceActionRates", "unitResourceAuras"},
    {L"PillageAmount", "pillageGold"},
    {L"GatherLinkedResource", "linkedResource"},
    {L"LinkedResourceType", "linkedResource"},
    {L"LinkedResourceRange", "linkedResource"},
    {L"DetonationProtoAction", "detonationDeath"},
    {L"DetonationCommand", "detonationDeath"},
    {L"DetonationHitpointThreshold", "detonationDeath"},
    {L"DetonationHitpointDecay", "detonationDeath"},
    {L"DisplayRange", "displayedRange"},
    {L"DisplayedRange", "displayedRange"},
    {L"CanDodgeAttacks", "dodgeAnyUnit"},
    {L"DodgeChance", "dodgeAnyUnit"},
    {L"DoNotQueue", "doNotQueue"},
    {L"UseSharedBuildLimit", "sharedBuildLimit"},
    {L"SharedBuildLimitUnit", "sharedBuildLimit"},
    {L"SharedBuildLimitUnitType", "sharedBuildLimit"},
    {L"SharedBuildLimitUnitTypes", "sharedBuildLimit"},
    {L"SettlerBuildLimit", "sharedBuildLimit"},
    {L"AnnexOf", "annexFacing"},
    {L"AnnexRange", "annexFacing"},
    {L"TeamBuildLimit", "sharedBuildLimit"},
    {L"TrainBatchSize", "trainBatchSize"},
    {L"DontTrainInBatches", "trainBatchSize"},
    {L"ForceBatchTrain", "trainBatchSize"},
    {L"VeterancyBonus", "veterancyBonus"},
    {L"ResearchGrantInterval", "researchGrants"},
    {L"ResearchGrantMax", "researchGrants"},
    {L"ResearchGrantCost", "researchGrants"},
    {L"ResearchGrantTime", "researchGrants"},
    {L"ResearchGrantScope", "researchGrants"},
    {L"ResearchGrantMinCost", "researchGrants"},
    {L"WallPiece", "customWalls"},
};

std::map<std::wstring, Seen> g_seen[kKinds];
std::vector<std::wstring> g_deleted;  // with `file`: each deleted effect, with its tech and what it names
bool g_on[sizeof(kKnownTags) / sizeof(kKnownTags[0])] = {};
bool g_done = false;  // the load ended: what comes now is written at once
const char* g_lastSubtypeNode = nullptr;  // an effect already named as an unknown subtype
bool g_all = false;
bool g_file = false;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

std::wstring Wide(const char* text) {
  std::wstring out;
  for (; text != nullptr && *text != 0; ++text) {
    out.push_back(static_cast<wchar_t>(static_cast<unsigned char>(*text)));
  }
  return out;
}

std::wstring ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? std::wstring() : L"proto " + Wide(name);
}

std::wstring Attribute(const char* node, const char* name) {
  const void* value = nullptr;
  if (node == nullptr || !kXmlAttribute(node, name, &value) || value == nullptr) {
    return {};
  }
  return Wide(kXmlText(value));
}

// What an effect names: its text, as a TechStatus's, or its first child's, as a <Target>.
std::wstring EffectTarget(const char* node) {
  const wchar_t* text = node == nullptr ? nullptr : Field<const wchar_t*>(node, 0x14);
  if ((text == nullptr || *text == 0) && node != nullptr && Field<std::int32_t>(node, 0x0C) > 0) {
    const char* child = Field<const char* const*>(node, 0x08)[0];
    text = child == nullptr ? nullptr : Field<const wchar_t*>(child, 0x14);
  }
  return text == nullptr ? std::wstring() : std::wstring(text);
}

std::wstring TechName() {
  const std::wstring name = Attribute(g_uhcLintTech, "name");
  return name.empty() ? std::wstring() : L"tech " + name;
}

const KnownTag* Known(const wchar_t* name, bool* on) {
  for (std::size_t i = 0; i < sizeof(kKnownTags) / sizeof(kKnownTags[0]); ++i) {
    if (_wcsicmp(name, kKnownTags[i].name) == 0) {
      *on = g_on[i];
      return &kKnownTags[i];
    }
  }
  *on = false;
  return nullptr;
}

std::wstring Line(int kind, const std::wstring& name, const Seen& seen) {
  std::wstring line = L"dataLint: ";
  line += kKindText[kind];
  line += L" ";
  line += name;
  bool on = false;
  if (const KnownTag* known = (kind == kProtoTag || kind == kActionTag) ? Known(name.c_str(), &on) : nullptr) {
    line += L" (read by the key ";
    line += Wide(known->key);
    line += L", which is off)";
  }
  line += L": " + std::to_wstring(seen.count) + (seen.count == 1 ? L" time" : L" times");
  if (!seen.first.empty()) {
    line += L", first in " + seen.first;
  }
  return line;
}

void Note(Kind kind, const std::wstring& name, const std::wstring& where) {
  if (name.empty() || name[0] == L'#') {
    return;  // a comment node
  }
  Seen& seen = g_seen[kind][name];
  if (++seen.count == 1) {
    seen.first = where;
    if (g_done) {
      uhc::Log(L"%ls", Line(kind, name, seen).c_str());
    }
  }
}

std::wstring ReportPath() {
  wchar_t path[MAX_PATH];
  const DWORD len = GetModuleFileNameW(nullptr, path, MAX_PATH);
  if (len == 0 || len == MAX_PATH) {
    return {};
  }
  std::wstring out(path);
  out.resize(out.rfind(L'\\') + 1);
  out += uhc::kLogFile;
  const std::size_t slash = out.rfind(L'\\');
  out.resize(slash + 1);
  return out + L"dataLint.txt";
}

void WriteReport() {
  FILE* file = nullptr;
  const std::wstring path = ReportPath();
  if (path.empty() || _wfopen_s(&file, path.c_str(), L"w, ccs=UTF-8") != 0 || file == nullptr) {
    uhc::Log(L"dataLint: cannot write %ls", path.c_str());
    return;
  }
  for (int kind = 0; kind < kKinds; ++kind) {
    for (const auto& entry : g_seen[kind]) {
      std::fwprintf(file, L"%ls\n", Line(kind, entry.first, entry.second).c_str());
    }
  }
  for (const std::wstring& line : g_deleted) {
    std::fwprintf(file, L"dataLint: deleted effect %ls\n", line.c_str());
  }
  std::fclose(file);
  uhc::Log(L"dataLint: the whole report is in %ls", path.c_str());
}

void NewDatabase(char*) {
  for (auto& kind : g_seen) {
    kind.clear();
  }
  g_deleted.clear();
  g_done = false;
}

void ActionTagRead(const uhc::ActionTag& tag) {
  bool on = false;
  Known(tag.name, &on);
  if (!on) {
    Note(kActionTag, tag.name, ProtoName(tag.proto));
  }
}

void ModifyTypeRead(const wchar_t* name, const char* proto) { Note(kModifyType, name, ProtoName(proto)); }

void SubtypeRead(const char* name) {
  g_lastSubtypeNode = g_uhcSubtypeNode;
  Note(kSubtype, Wide(name), TechName());
}

}  // namespace

extern "C" {

void __stdcall UhcLintUnitType(const char* name, const char* proto) {
  Note(kUnitType, Wide(name), ProtoName(proto));
}

// An effect the game deletes. One already named by its unknown subtype is left out.
void __stdcall UhcLintEffect(const char* node) {
  if (node == g_lastSubtypeNode) {
    return;
  }
  std::wstring name = L"type=" + Attribute(node, "type");
  const std::wstring subtype = Attribute(node, "subtype");
  if (!subtype.empty()) {
    name += L" subtype=" + subtype;
  }
  std::wstring where = TechName();
  const std::wstring target = EffectTarget(node);
  if (!target.empty()) {
    where += L", which names " + target;
  }
  if (g_file) {
    g_deleted.push_back(name + L" in " + where);
  }
  Note(kEffect, name, where);
}

void __stdcall UhcLintProtoTag(const char* name, const char* proto) { Note(kProtoTag, Wide(name), ProtoName(proto)); }

// `name` is the node's <Name> text, a BString.
void __stdcall UhcLintProtoAction(const wchar_t* const* name, const char* proto) {
  Note(kProtoAction, name == nullptr || *name == nullptr ? L"" : *name, ProtoName(proto));
}

// The load ended.
void __stdcall UhcLintDone() {
  if (g_done) {
    return;
  }
  g_done = true;
  std::wstring totals;
  int all = 0;
  for (int kind = 0; kind < kKinds; ++kind) {
    int line = 0;
    for (const auto& entry : g_seen[kind]) {
      if (g_all || line < kMaxLines) {
        uhc::Log(L"%ls", Line(kind, entry.first, entry.second).c_str());
      }
      ++line;
    }
    if (!g_all && line > kMaxLines) {
      uhc::Log(L"dataLint: %d more of %ls (`dataLint file` lists them)", line - kMaxLines, kKindText[kind]);
    }
    all += line;
    totals += L", " + std::to_wstring(line) + L" " + kKindText[kind];
  }
  uhc::Log(L"dataLint: the data load ended with %d names the game drops%ls", all, totals.c_str());
  if (g_file) {
    WriteReport();
  }
}
}

namespace uhc {

Outcome ApplyDataLint(const Config& config) {
  const Config::Args* args = config.First("dataLint");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_all = true;
    } else if (_stricmp(arg.c_str(), "file") == 0) {
      g_file = true;
    } else {
      Log(L"dataLint: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  for (std::size_t i = 0; i < sizeof(kKnownTags) / sizeof(kKnownTags[0]); ++i) {
    g_on[i] = config.First(kKnownTags[i].key) != nullptr;
  }
  if (!VerifyAll("dataLint", {&sites::kLintUnitTypeMiss, &sites::kLintProtoTagMiss, &sites::kLintProtoActionMiss,
                              &sites::kLintTechLoadCall, &sites::kLintTechNode, &sites::kLintEffectDrop,
                              &sites::kLintEffectType}) ||
      !OnDatabaseLoad(&NewDatabase) || !WriteCall(kTechLoadCall, reinterpret_cast<const void*>(&UhcLintDoneHook)) ||
      !WriteJmp(kTechNode, reinterpret_cast<const void*>(&UhcLintTechHook), 7) ||
      !WriteJmp(kEffectDrop, reinterpret_cast<const void*>(&UhcLintEffectHook), 6) ||
      !WriteJmp(kEffectType, reinterpret_cast<const void*>(&UhcLintEffectTypeHook), 5) ||
      !WriteJmp(kUnitTypeMiss, reinterpret_cast<const void*>(&UhcLintUnitTypeHook), 5) ||
      !WriteJmp(kProtoTagMiss, reinterpret_cast<const void*>(&UhcLintProtoTagHook), 8) ||
      !WriteJmp(kProtoActionMiss, reinterpret_cast<const void*>(&UhcLintProtoActionHook), 6)) {
    return Outcome::kFailed;
  }
  // Each of these can fail beside another DLL that took its site, and the rest still works.
  int sources = 3;
  if (!AddActionTagHandler(&ActionTagRead)) {
    Log(L"dataLint: no action tags");
    --sources;
  }
  if (!OnUnknownModifyType(&ModifyTypeRead)) {
    Log(L"dataLint: no <ModifyType> names");
    --sources;
  }
  if (!OnUnknownTechSubtype(&SubtypeRead)) {
    Log(L"dataLint: no Data subtypes");
    --sources;
  }
  Log(L"dataLint: warns of what the data asks and the game drops, %d of 3 shared sources%ls", sources,
      g_all ? L", every name in the log" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/datalint_hooks.asm

```asm
; The hooks of dataLint (src/features/datalint.cpp). Each one reads a failure exit of the data load, does what the
; stock code there does, and leaves through an explicit jmp to a verified continuation.
.686
.model flat, c
option casemap :none

include common.inc

UhcLintUnitType PROTO STDCALL :DWORD, :DWORD
UhcLintProtoTag PROTO STDCALL :DWORD, :DWORD
UhcLintProtoAction PROTO STDCALL :DWORD, :DWORD
UhcLintDone PROTO STDCALL
UhcLintEffect PROTO STDCALL :DWORD
EXTERN g_uhcLintTech:DWORD

.data
unitTypeNext    dd 005FCB66h    ; mov ecx,0D5E620h: the handler's error, then its failure return
protoTagNext    dd 005F62AAh    ; mov eax,[edx+4]: the found handler's call
protoTagSkip    dd 005F62BCh    ; add ebp,1: the next child
protoActionNext dd 005FA208h    ; mov ecx,[edi+44h]: the action exists
protoActionMiss dd 005FC891h    ; the handler's failure
techLoad        dd 0061FD02h    ; the tech parser
techNodeNext    dd 0061FDBFh    ; cmp edx,-1: the tech's name
effectNext      dd 006205EFh    ; mov eax,esi: the effect is good
effectDelete    dd 00621ECAh    ; setData was false: the effect is deleted
effectTypeNext  dd 0065BC5Bh    ; mov ecx,0D5E620h: the type's error
loadReturn      dd 0            ; where the database load's call goes back to

.code

; Replaces push 0EB4h at 0x5FCB61, the failure of the <UnitType> handler 0x5F62D4, cdecl(database, node, proto).
; EDI = the name, 0 for an empty node. [esp] and [esp+4] = the saved EDI and ESI, [esp+14h] = proto. Only EAX, ECX and
; EDX change, and the stock code overwrites them here.
UhcLintUnitTypeHook PROC
    TRACE_ONCE "dataLint unit type (0x5FCB61)"
    invoke UhcLintUnitType, edi, dword ptr [esp+14h]
    push 0EB4h
    jmp unitTypeNext
UhcLintUnitTypeHook ENDP

; Replaces test al,al / je 5F62BCh / mov edx,[esp+14h] at 0x5F62A2, after the find in the proto tag table, in the proto
; parser 0x5F611D. ESI = the child's name, EBX = the proto.
UhcLintProtoTagHook PROC
    test al, al
    jne found
    TRACE_ONCE "dataLint proto tag (0x5F62A2)"
    invoke UhcLintProtoTag, esi, ebx
    jmp protoTagSkip
found:
    mov edx, dword ptr [esp+14h]
    jmp protoTagNext
UhcLintProtoTagHook ENDP

; Replaces je 5FC891h at 0x5FA202 in the <ProtoAction> handler, after the look-up of the action by name. The flags are
; those of test eax,eax. ESI = the address of the <Name> text's BString, EDI = the proto. On the failure path the handler
; reads no register the call changes.
UhcLintProtoActionHook PROC
    jne found
    TRACE_ONCE "dataLint proto action (0x5FA202)"
    invoke UhcLintProtoAction, esi, edi
    jmp protoActionMiss
found:
    jmp protoActionNext
UhcLintProtoActionHook ENDP

; The call of the tech parser 0x61FD02 at 0x61FE4A, the last thing the data load reads. Its arguments stay on the
; stack, and it pops whatever it pops, so only the return address is swapped.
UhcLintDoneHook PROC
    TRACE_ONCE "dataLint load end (0x61FE4A)"
    pop loadReturn
    call techLoad
    push eax
    call UhcLintDone
    pop eax
    jmp loadReturn
UhcLintDoneHook ENDP

; Replaces mov esi,eax / mov ecx,esi / mov edx,[ecx+18h] at 0x61FDB8, the loop over the tree's nodes: EAX = node.
UhcLintTechHook PROC
    mov g_uhcLintTech, eax
    mov esi, eax
    mov ecx, esi
    mov edx, dword ptr [ecx+18h]
    jmp techNodeNext
UhcLintTechHook ENDP

; Replaces je 621ECAh at 0x6205E9 in the effect parse 0x620572. The flags are those of test al,al. EDI = the node.
UhcLintEffectHook PROC
    jne good
    TRACE_ONCE "dataLint effect (0x6205E9)"
    invoke UhcLintEffect, edi
    jmp effectDelete
good:
    jmp effectNext
UhcLintEffectHook ENDP

; Replaces push 512h at 0x65BC56, the effect type's failure. EDI = the node.
UhcLintEffectTypeHook PROC
    TRACE_ONCE "dataLint effect type (0x65BC56)"
    invoke UhcLintEffect, edi
    push 512h
    jmp effectTypeNext
UhcLintEffectTypeHook ENDP

END
```

## customHotkeyContexts

Contract: [customHotkeyContexts](../porting-to-another-dll.md#customhotkeycontexts).

Sites: `HotkeyTipStringFree` `0x4010CA` (6 B), `HotkeyTipStringNew` `0x401A12` (6 B), `HotkeyTipStringNarrow` `0x402733` (6 B), `HotkeyTipListAdd` `0x467722` (6 B), `HotkeyFindContext` `0x5C16AB` (63 B), `HotkeyFindCall` `0x5C1778` (10 B), `HotkeyRegisterContext` `0x628FC0` (47 B), `HotkeyTrainerBuildFlag` `0x64A034` (7 B), `HotkeyTrainerQualified` `0x64A05A` (4 B), `HotkeyDeactivateLast` `0x79F1A5` (7 B), `HotkeyUnitContext` `0x79F897` (14 B), `HotkeyUnitActivate` `0x79F9BF` (38 B), `HotkeyTipBuildMiss` `0x8F90FC` (6 B), `HotkeyTipListDone` `0x8F9696` (6 B), `HotkeyDeactivateById` `0xAB397F` (14 B), `HotkeyTipLookup` `0xAB481D` (6 B).

### src/features/hotkeys.cpp

```cpp
// customHotkeyContexts: unit hotkeys for buildings (and other trainers) the exe does not know.
//
// Every <keymapdata> of DefaultKeyMapY.xml belongs to a named <context>. Stock knows a fixed list
// of 123 context names (FUN_005D7948; 35 of them are the unit contexts TownCenterAccel ..
// WonderAccel, at layer 5), and FUN_005C16EA drops every keymap entry whose context is not on
// that list. Which context a selected building turns on comes from a hardcoded proto table
// ([proto+178h], written by FUN_005C13C5); the selection code switches off only the 35 stock
// names (FUN_0079EF9C), and a selected non-building with a <Train> list only ever turns on
// BuildAccel (selection chunk 0x649FA4).
//
// With this key, a keymap context named <ProtoName>Accel that the exe does not know is registered
// while the keymap is applied (layer 5, like the stock unit contexts), so its entries are bound
// instead of dropped. Selecting a unit of that proto turns that context on instead of the stock
// one when the unit enters a hotkey context at all: a building with a <Train> list, a fire pit,
// a unit with the EnterHotkeyContext flag, or (through the hook at 0x64A034) a non-building with
// a <Train> list. Other units (a soldier, a hero) never enter one, so their context, although
// registered, stays off; give them EnterHotkeyContext. The selection code
// switches it off with the stock ones. A stock context is never redirected, so with the stock
// keymap nothing changes. UI only: a hotkey issues the same command as a click.
//
// The letter in a button's tooltip comes from FUN_008F8F5E, which looks tis("Proto") up in a list of
// names written in the exe (the 36 unit contexts and BuildAccel), and a building's trainInSelected or
// tis in BuildAccel only. An added context is on neither, so its entries worked with no letter
// showing. The two hooks there add them to the search. The hooks are in hooks/hotkey_hooks.asm.
#include <windows.h>

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

// Engine layout (docs/engine-symbols.md, "Hotkey contexts").
constexpr std::uint32_t kUiGlobal = 0x00C66244;  // [[ui+74h]+34h] = the context manager
constexpr std::int32_t kContextMissing = 3;      // 0x5C16AB: 0 found, 3 unknown name
constexpr std::int32_t kUnitContextLayer = 5;    // the layer of the 35 stock unit contexts
constexpr std::int32_t kContextLimit = 255;      // every context set is 255 bits: IDs 0..254
// Context IDs are dense ([manager+34h] is the next one) and the game registers some at run time
// too (0x5D3B1D, 0x62CB43; how many after the keymap pass is not measured): leave it this many,
// so that ours alone never push one of its IDs past the sets.
constexpr std::int32_t kReservedIds = 32;
constexpr char kSuffix[] = "Accel";
constexpr std::size_t kSuffixLength = sizeof(kSuffix) - 1;

// thiscall functions of the context manager, called as fastcall with an unused EDX.
using FindContextFn = std::int32_t(__fastcall*)(void* manager, void* unusedEdx, const void* name,
                                                std::int32_t* record);
using RegisterContextFn = std::int32_t(__fastcall*)(void* manager, void* unusedEdx, const char* name,
                                                    std::int32_t layer);
using DeactivateByNameFn = std::int32_t(__fastcall*)(void* manager, void* unusedEdx, const char* name,
                                                     std::int32_t flag);
using DeactivateByIdFn = std::int32_t(__fastcall*)(void* manager, void* unusedEdx, std::int32_t id,
                                                   std::int32_t flag);

// Find by BString name: writes {id, layer} to record; 0 found, 3 unknown (ret 8).
const auto kFindContext = reinterpret_cast<FindContextFn>(0x005C16AB);
// Register a name: its ID is [manager+34h]; 0 on success, 2 if the name exists (ret 8).
const auto kRegisterContext = reinterpret_cast<RegisterContextFn>(0x00628FC0);
// Switch a context off, by name or by ID (ret 8).
const auto kDeactivateByName = reinterpret_cast<DeactivateByNameFn>(0x004421F3);
const auto kDeactivateById = reinterpret_cast<DeactivateByIdFn>(0x00AB397F);

// The hotkey text of a tooltip: the two commands of a building, kept as BStrings by FUN_008F8F5E.
constexpr std::uint32_t kTipTrainCommand = 0x00D986C0;  // trainInSelected("Proto")
constexpr std::uint32_t kTipTisCommand = 0x00D986BC;    // tis("Proto")
constexpr std::uint32_t kTipKeys = 0x00D986C4;          // the list of keys found

using TipLookupFn = std::int32_t(__fastcall*)(void* manager, void* unusedEdx, const char* command,
                                              const char* context, void* keys, bool firstOnly);
using ListAddFn = std::int32_t(__fastcall*)(void* list, void* unusedEdx, const void* text);
using StringNewFn = void*(__fastcall*)(void* text, void* unusedEdx, const wchar_t* wide);
using StringFreeFn = void(__fastcall*)(void* text);
using StringNarrowFn = const char*(__fastcall*)(const void* text);
const auto kTipLookup = reinterpret_cast<TipLookupFn>(0x00AB481D);
const auto kListAdd = reinterpret_cast<ListAddFn>(0x00467722);
const auto kStringNew = reinterpret_cast<StringNewFn>(0x00401A12);
const auto kStringFree = reinterpret_cast<StringFreeFn>(0x004010CA);
const auto kStringNarrow = reinterpret_cast<StringNarrowFn>(0x00402733);

struct AddedContext {
  std::string proto;  // the context name without "Accel"
  std::string name;   // the context name as the keymap spells it
  std::wstring wide;  // the same, for the game's strings
  std::int32_t id;
  bool trainerLogged;  // "log": the non-building line was written for this proto
};

// Written only by the keymap hook and read by the selection hooks, all on the game's UI thread;
// reserved when the feature is applied, so a push_back never moves the entries.
std::vector<AddedContext> g_added;
std::vector<std::string> g_refused;  // names already logged as not registered
void* g_manager = nullptr;           // the context manager the IDs in g_added belong to
bool g_log = false;                  // "customHotkeyContexts log": log every switch
std::int32_t g_lastUnit = -1;        // "log": the last unit and context logged
std::int32_t g_lastContext = -1;
const void* g_lastWorld = nullptr;   // "log": the game those two belong to
std::uint32_t g_lastStep = 0;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

void* ContextManager() {
  const void* ui = *reinterpret_cast<void* const*>(kUiGlobal);
  const void* inner = ui == nullptr ? nullptr : Field<const void*>(ui, 0x74);
  return inner == nullptr ? nullptr : Field<void*>(inner, 0x34);
}

// A keymap entry's context is a BString: its first field is the UTF-16 text. Narrowed with the
// ANSI code page, as the game's own conversion (0x402733) does.
std::string Narrow(const void* name) {
  const wchar_t* text = Field<const wchar_t*>(name, 0);
  if (text == nullptr || *text == L'\0') {
    return {};
  }
  const int size = WideCharToMultiByte(CP_ACP, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) {
    return {};
  }
  std::string narrow(static_cast<std::size_t>(size), '\0');
  if (WideCharToMultiByte(CP_ACP, 0, text, -1, narrow.data(), size, nullptr, nullptr) != size) {
    return {};
  }
  narrow.resize(static_cast<std::size_t>(size - 1));
  return narrow;
}

bool IsProtoContextName(const std::string& name) {
  return name.size() > kSuffixLength && _stricmp(name.c_str() + name.size() - kSuffixLength, kSuffix) == 0;
}

// True the first time a name is refused, so each refusal is logged once.
bool FirstRefusal(const std::string& name) {
  for (const std::string& refused : g_refused) {
    if (_stricmp(refused.c_str(), name.c_str()) == 0) {
      return false;
    }
  }
  g_refused.push_back(name);
  return true;
}

// The added context of a proto (database or player proto: the name is at +10h), or nullptr.
AddedContext* ContextOf(const void* proto) {
  if (proto == nullptr || g_added.empty() || ContextManager() != g_manager) {
    return nullptr;
  }
  const char* name = Field<const char*>(proto, 0x10);
  if (name == nullptr) {
    return nullptr;
  }
  for (AddedContext& added : g_added) {
    if (_stricmp(added.proto.c_str(), name) == 0) {
      return &added;
    }
  }
  return nullptr;
}

}  // namespace

extern "C" {

// Called instead of the find at 0x5C1778, for each keymap entry: the stock find, and, when the
// context is unknown and named <ProtoName>Accel, a registration and a second find, so the entry
// is bound instead of dropped. Same frame as the stock thiscall (ret 8).
std::int32_t __fastcall UhcHotkeyFindContext(void* manager, void*, const void* name, std::int32_t* record) {
  const std::int32_t found = kFindContext(manager, nullptr, name, record);
  if (found != kContextMissing || manager == nullptr || name == nullptr || record == nullptr) {
    return found;
  }
  const std::string context = Narrow(name);
  if (!IsProtoContextName(context)) {
    return found;  // stock: the entry is dropped
  }
  if (manager != g_manager) {
    g_added.clear();
    g_refused.clear();
    g_manager = manager;
  }
  const std::int32_t next = Field<std::int32_t>(manager, 0x34);
  if (next < 0 || next >= kContextLimit - kReservedIds) {
    if (FirstRefusal(context)) {
      uhc::Log(L"customHotkeyContexts: %d contexts are registered; keymap context %hs not registered, its "
               L"entries are dropped (the last %d of the 255 context IDs stay free for the game)",
               next, context.c_str(), kReservedIds);
    }
    return found;
  }
  if (kRegisterContext(manager, nullptr, context.c_str(), kUnitContextLayer) != 0) {
    if (FirstRefusal(context)) {
      uhc::Log(L"customHotkeyContexts: the game refused to register keymap context %hs; its entries are "
               L"dropped",
               context.c_str());
    }
    return found;
  }
  const std::int32_t again = kFindContext(manager, nullptr, name, record);
  if (again != 0 || record[0] != next) {
    uhc::Log(L"customHotkeyContexts: keymap context %hs was registered as %d but found as %d (result %d); "
             L"no unit enters it",
             context.c_str(), next, record[0], again);
    return again;
  }
  g_added.push_back({context.substr(0, context.size() - kSuffixLength), context,
                     std::wstring(Field<const wchar_t*>(name, 0)), next, false});
  uhc::Log(L"customHotkeyContexts: registered keymap context %hs as context %d", context.c_str(), next);
  return again;
}

// Called instead of the last deactivation at 0x79F1A5 (WonderAccel): the stock call, then every
// added context, with the same flag. Same frame as the stock thiscall (ret 8).
std::int32_t __fastcall UhcHotkeyDeactivateAll(void* manager, void*, const char* name, std::int32_t flag) {
  const std::int32_t result = kDeactivateByName(manager, nullptr, name, flag);
  if (manager != nullptr && manager == g_manager) {
    for (const AddedContext& added : g_added) {
      kDeactivateById(manager, nullptr, added.id, flag);
    }
  }
  return result;
}

// From the hook at 0x8F9696: the added contexts join the names a proto's tooltip key is looked up in.
void __stdcall UhcHotkeyTipAddContexts(void* list) {
  if (ContextManager() != g_manager) {
    return;
  }
  for (const AddedContext& added : g_added) {
    void* text = nullptr;
    kStringNew(&text, nullptr, added.wide.c_str());
    kListAdd(list, nullptr, &text);
    kStringFree(&text);
  }
}

// From the hook at 0x8F90FC, a Building's key not found in BuildAccel: the same two commands in the
// added contexts. Above 0 when one was found, with the key in the list the stock code reads.
std::int32_t __stdcall UhcHotkeyTipFindBuild() {
  void* manager = ContextManager();
  if (manager == nullptr || manager != g_manager) {
    return 0;
  }
  void* keys = reinterpret_cast<void*>(kTipKeys);
  for (const AddedContext& added : g_added) {
    for (const std::uint32_t command : {kTipTrainCommand, kTipTisCommand}) {
      const char* text = kStringNarrow(reinterpret_cast<const void*>(command));
      const std::int32_t found = kTipLookup(manager, nullptr, text, added.name.c_str(), keys, true);
      if (found > 0) {
        return found;
      }
    }
  }
  return 0;
}

void* g_uhcHotkeyFindContext = reinterpret_cast<void*>(&UhcHotkeyFindContext);
void* g_uhcHotkeyDeactivateAll = reinterpret_cast<void*>(&UhcHotkeyDeactivateAll);

// From the hook at 0x79F897: the context the selected unit turns on, if its proto has an added
// one; -1 keeps the stock [proto+178h]. proto is the unit's database proto.
std::int32_t __stdcall UhcHotkeyContextFor(const char* proto, const char* unit) {
  const AddedContext* added = ContextOf(proto);
  if (added == nullptr) {
    return -1;
  }
  if (g_log && unit != nullptr) {
    // Unit IDs start again in every game: a new world, or a step count [world+F8h] that went
    // back, forgets the last line.
    const char* game = *reinterpret_cast<const char* const*>(0x00C66234);
    const void* world = game == nullptr ? nullptr : Field<const void*>(game, 0x13C);
    const std::uint32_t step = world == nullptr ? 0 : Field<std::uint32_t>(world, 0xF8);
    if (world != g_lastWorld || step < g_lastStep) {
      g_lastUnit = -1;
      g_lastContext = -1;
    }
    g_lastWorld = world;
    g_lastStep = step;
    const std::int32_t unitId = Field<std::int32_t>(unit, 0x10);
    if (unitId != g_lastUnit || added->id != g_lastContext) {
      g_lastUnit = unitId;
      g_lastContext = added->id;
      uhc::Log(L"customHotkeyContexts: unit %d (%hs) selected: hotkey context %hs (%d) instead of stock "
               L"context %d",
               unitId, added->proto.c_str(), added->name.c_str(), added->id, Field<std::int32_t>(proto, 0x178));
    }
  }
  return added->id;
}

// From the hook at 0x64A034, for a selected non-building with a <Train> list: true if its proto
// has an added context, so it enters that context like a building.
bool __stdcall UhcHotkeyTrainerHasContext(const char* unit) {
  AddedContext* added = unit == nullptr ? nullptr : ContextOf(Field<const char*>(unit, 0x5C));
  if (added == nullptr) {
    return false;
  }
  if (g_log && !added->trainerLogged) {
    added->trainerLogged = true;
    uhc::Log(L"customHotkeyContexts: unit %d (%hs) is not a building: units of this proto enter hotkey "
             L"context %hs (%d) instead of BuildAccel (logged once per proto)",
             Field<std::int32_t>(unit, 0x10), added->proto.c_str(), added->name.c_str(), added->id);
  }
  return true;
}

void UhcHotkeyFindContextHook();
void UhcHotkeyContextHook();
void UhcHotkeyDeactivateHook();
void UhcHotkeyTrainerHook();
void UhcHotkeyTipListHook();
void UhcHotkeyTipBuildHook();
}

namespace uhc {

Outcome ApplyCustomHotkeyContexts(const Config& config) {
  const Config::Args* args = config.First("customHotkeyContexts");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"customHotkeyContexts: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("customHotkeyContexts",
                 {&sites::kHotkeyFindCall, &sites::kHotkeyFindContext, &sites::kHotkeyRegisterContext,
                  &sites::kHotkeyUnitContext, &sites::kHotkeyUnitActivate, &sites::kHotkeyDeactivateLast,
                  &sites::kHotkeyDeactivateById, &sites::kHotkeyTrainerBuildFlag,
                  &sites::kHotkeyTrainerQualified, &sites::kHotkeyTipListDone, &sites::kHotkeyTipBuildMiss,
                  &sites::kHotkeyTipLookup, &sites::kHotkeyTipListAdd, &sites::kHotkeyTipStringNew,
                  &sites::kHotkeyTipStringFree, &sites::kHotkeyTipStringNarrow})) {
    return Outcome::kFailed;
  }
  g_log = log;
  g_added.reserve(kContextLimit);
  // Switch-off first and the trainer path last: if a later write failed, what is already written
  // still leaves every context consistent (registered but never on, or on and switched off).
  if (!WriteCall(sites::kHotkeyDeactivateLast.va, reinterpret_cast<const void*>(&UhcHotkeyDeactivateHook)) ||
      !WriteCall(sites::kHotkeyFindCall.va, reinterpret_cast<const void*>(&UhcHotkeyFindContextHook)) ||
      !WriteJmp(sites::kHotkeyUnitContext.va, reinterpret_cast<const void*>(&UhcHotkeyContextHook), 6) ||
      !WriteJmp(sites::kHotkeyTrainerBuildFlag.va, reinterpret_cast<const void*>(&UhcHotkeyTrainerHook), 5) ||
      !WriteJmp(sites::kHotkeyTipListDone.va, reinterpret_cast<const void*>(&UhcHotkeyTipListHook), 6) ||
      !WriteJmp(sites::kHotkeyTipBuildMiss.va, reinterpret_cast<const void*>(&UhcHotkeyTipBuildHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"customHotkeyContexts: a keymap context named <ProtoName>Accel that the game does not know becomes "
      L"that proto's hotkey context%ls",
      log ? L", every switch logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/hotkey_hooks.asm

```asm
; Hooks for customHotkeyContexts (features/hotkeys.cpp). Two replace a stock call (written as a
; call to the hook, which returns to the stock return address); two are entered through a jmp and
; leave through an explicit jmp to a verified continuation (docs/engine-symbols.md, "Hotkey
; contexts").
.686
.model flat, c
option casemap :none

include common.inc

UhcHotkeyContextFor PROTO STDCALL dbProto:DWORD, unit:DWORD
UhcHotkeyTrainerHasContext PROTO STDCALL unit:DWORD
UhcHotkeyTipAddContexts PROTO STDCALL list:DWORD
UhcHotkeyTipFindBuild PROTO STDCALL

EXTERNDEF g_uhcHotkeyFindContext:DWORD      ; int fastcall(manager, -, name, record), ret 8
EXTERNDEF g_uhcHotkeyDeactivateAll:DWORD    ; int fastcall(manager, -, name, flag), ret 8

.data
unitContextNext     dd 0079F89Dh    ; test edi,edi / jge 79F9BFh: turn context EDI on
trainerQualified    dd 0064A05Ah    ; mov bl,1 / mov edi,esi: the unit enters its own context
trainerNext         dd 0064A05Ch    ; mov edi,esi: the target of the stock jmp after the stolen mov
tipListNext         dd 008F969Ch    ; mov eax,[edx+74h]: the context list is done
tipBuildFound       dd 008F9102h    ; a key was found: its text goes out
tipBuildMissing     dd 008F96AFh    ; no key: return false

.code

; Called by the call at 0x5C1778 in FUN_005C16EA (applies DefaultKeyMapY.xml), which called
; 0x5C16AB: find the entry's context, thiscall(manager, &entry->Context, &record), ret 8. ECX =
; the manager and the arguments are in place, so the fastcall wrapper takes the frame as its own
; and returns to 0x5C177D (cmp eax,3 / je: 3 drops the entry). EAX, ECX and EDX are not preserved
; by the stock call either.
UhcHotkeyFindContextHook PROC
    TRACE_ONCE "customHotkeyContexts (0x5C1778)"
    jmp g_uhcHotkeyFindContext
UhcHotkeyFindContextHook ENDP

; Called by the call at 0x79F1A5 in FUN_0079EF9C (switches off the 35 stock unit contexts before a
; selection turns one on), which called 0x4421F3 for "WonderAccel": thiscall(manager, name, flag),
; ret 8. As above, the wrapper takes the frame and returns to 0x79F1AA (pop esi / ret); ESI is
; callee-saved in the wrapper.
UhcHotkeyDeactivateHook PROC
    TRACE_ONCE "customHotkeyContexts (0x79F1A5)"
    jmp g_uhcHotkeyDeactivateAll
UhcHotkeyDeactivateHook ENDP

; Replaces mov edi,[esi+178h] at 0x79F897 in FUN_0079F851, which turns on the selected unit's
; context. ESI = the unit's database proto ([proto+178h] = its context from the stock proto table,
; -1 = none), EBP = the unit; EDI was saved by the push just before. A proto with an added
; <ProtoName>Accel context gets that one instead. The continuation sets the flags it reads
; (test edi,edi), and EAX, ECX and EDX are reloaded on both of its paths.
UhcHotkeyContextHook PROC
    TRACE_ONCE "customHotkeyContexts (0x79F897)"
    push ebp
    push esi
    call UhcHotkeyContextFor        ; -> the added context's ID, or -1
    test eax, eax
    jl stock
    mov edi, eax
    jmp unitContextNext
stock:
    mov edi, dword ptr [esi+178h]   ; stolen 0x79F897
    jmp unitContextNext
UhcHotkeyContextHook ENDP

; Replaces mov byte ptr [esp+13h],1 at 0x64A034 in the selection chunk 0x649FA4. A selected unit
; with a <Train> list that is not a Building only sets that byte ("turn BuildAccel on") and never
; enters a context of its own; a Building takes 0x64A05A (BL = 1: call FUN_0079F851 with EDI =
; this unit). ESI = the unit. A unit whose proto has an added context takes the Building path
; (without BuildAccel); any other unit runs the stock code. Also reached from 0x64A027 (no proto),
; where the C++ test is false. EAX, ECX and EDX are reloaded after both continuations, and no flag
; is read before an instruction there sets it.
UhcHotkeyTrainerHook PROC
    TRACE_ONCE "customHotkeyContexts (0x64A034)"
    push esi
    call UhcHotkeyTrainerHasContext ; -> AL = 1 if its proto has an added context
    test al, al
    jne qualifies
    mov byte ptr [esp+13h], 1       ; stolen 0x64A034: turn BuildAccel on
    jmp trainerNext                 ; as the stock jmp 64A05Ch at 0x64A039
qualifies:
    jmp trainerQualified
UhcHotkeyTrainerHook ENDP

; Replaces mov edx,[0C66244h] at 0x8F9696 in FUN_008F8F5E, which writes the hotkey text of a proto's
; tooltip. The function builds a list of the 37 stock context names at [esp+18h] and looks the unit's
; tis("name") up in each. The added contexts join that list here, after the stock names, so a stock
; mapping is found first. EDX is what the stolen read loads, and nothing else is live but the
; callee-saved registers.
UhcHotkeyTipListHook PROC
    TRACE_ONCE "customHotkeyContexts tooltip (0x8F9696)"
    lea eax, [esp+18h]
    push eax
    call UhcHotkeyTipAddContexts
    mov edx, dword ptr ds:[0C66244h]    ; stolen 0x8F9696
    jmp tipListNext
UhcHotkeyTipListHook ENDP

; Replaces jle 8F96AFh at 0x8F90FC. A proto with the Building bit is looked up in BuildAccel only.
; With no key there, the added contexts are tried. The flags are those of the stock test eax,eax.
UhcHotkeyTipBuildHook PROC
    jg found
    TRACE_ONCE "customHotkeyContexts tooltip, building (0x8F90FC)"
    call UhcHotkeyTipFindBuild
    test eax, eax
    jg found
    jmp tipBuildMissing
found:
    jmp tipBuildFound
UhcHotkeyTipBuildHook ENDP

END
```

## techRenameEffect

Contract: [techRenameEffect](../porting-to-another-dll.md#techrenameeffect).

Sites: `TechRenameRegister` `0x524CAA` (28 B), `TechRenameTypeByName` `0x61FF1B` (16 B), `TechRenameFactoryHead` `0x620535` (15 B), `TechRenameEffectParse` `0x6205C7` (45 B), `TechRenameEffectCtor` `0x620B8F` (29 B), `TechRenameFactoryDefault` `0x62146F` (19 B), `TechRenameApplyCall` `0x7F80FD` (23 B), `TechRenameLocalTechNode` `0x8D0005` (39 B), `TechRenameEffectVtable` `0xB965C0` (68 B).

### src/features/techrename.cpp

```cpp
// techRenameEffect (also read as enableTechRenameEffect): the tech effect
// <Effect type='SetTechName' tech='T' newName='ID' newRolloverTextID='ID'
// [newLongRolloverTextID='ID']/> gives the tech T new string IDs for the players the effect
// reaches, and only for them.
//
// Stock keeps one BTechTreeNodeData per tech in the database's tech tree (TT0 = [db+5D9Ch],
// 34h bytes each: +0 tech ID, +8 DisplayNameID, +0Ch RolloverTextID, +10h LongRolloverTextID,
// +14h icon, then the prerequisite and effect arrays). Each player's BTechTreeNode (24h bytes,
// created on first use as a copy of the base node, 0x94CC2B) points at that shared NodeData
// through [node+0]; only status, cost and research points are per player. A global SetTechName
// would write the new IDs into the shared NodeData, so one civ's tech renames the tech for everyone.
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
    key = "enableTechRenameEffect";  // alias key
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
```

### src/hooks/techrename_hooks.asm

```asm
; Hooks for techRenameEffect (features/techrename.cpp). Each is entered through a jmp written over
; the stock code and leaves through an explicit jmp to a verified continuation, or, for a
; SetTechName effect, through the factory's own epilogue (docs/engine-symbols.md, "Tech tree and
; tech effects").
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcTechRenameType:SDWORD    ; SetTechName's effect type ID; -1 until registered

UhcTechRenameRegister PROTO STDCALL :DWORD
UhcTechRenameCreate PROTO STDCALL

.data
registerNext    dd 00524CBCh    ; mov dword ptr [esp+10h],0 / jne 524CDBh (the Data subtypes)
factoryUnknown  dd 00621474h    ; mov ecx,0D5E620h / call 59AD7Ah (error 51Fh) / return 0

.code

; Replaces cmp dword ptr [esi+3504h],0 at 0x524CB5 in FUN_0052277E (database init), right after
; the last stock effect type (Data2, ID 16) is registered. ESI = database. Registers SetTechName,
; then re-executes the cmp last: its flags feed the jne at 0x524CC4, and the mov at 0x524CBC
; between them does not change the flags.
UhcTechRenameRegisterHook PROC
    TRACE_ONCE "techRenameEffect register (0x524CB5)"
    pushad
    push esi
    call UhcTechRenameRegister
    popad
    cmp dword ptr [esi+3504h], 0    ; stolen 0x524CB5
    jmp registerNext
UhcTechRenameRegisterHook ENDP

; Replaces push 51Fh at 0x62146F, the default case of the effect factory FUN_00620535
; (BEffect* cdecl(uchar type)), which the ja at 0x62053E takes for every type above 10h.
; EAX = the type (movzx), [esp] = the ESI the factory pushed. SetTechName's type gets a new
; effect (or 0, which the parse drops at 0x6205D4) and returns like the stock cases, through
; pop esi / ret (0x621480); any other type takes the stock "unknown type" path.
UhcTechRenameFactoryHook PROC
    TRACE_ONCE "techRenameEffect factory (0x62146F)"
    cmp eax, g_uhcTechRenameType
    jne unknownType
    call UhcTechRenameCreate         ; -> the new effect, or 0
    pop esi
    ret
unknownType:
    push 51Fh                        ; stolen 0x62146F
    jmp factoryUnknown
UhcTechRenameFactoryHook ENDP

END
```
