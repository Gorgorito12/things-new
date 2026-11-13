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
    {L"NumberOfShots", "numberOfShots"},
    {L"ShotInterval", "numberOfShots"},
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
