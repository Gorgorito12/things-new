// scenarioCivs [log]: a second civ file for the civs of scenarios and campaigns. After the game reads
// data\civs.xml, it reads data\scenariocivs.xml (the same format: a <civs> root with <civ> elements) and appends
// its civs at the end of the same list, so every civ of civs.xml keeps its ID. The civs of that file are hidden
// from the skirmish and lobby civ lists and shown in the scenario editor's: each gets <visible>0 and
// <visibleineditor>1, whatever the file says. No file: nothing happens.
//
// The civs.xml loader FUN_0052A590 loads the file into an XML reader on its stack ([esp+100h], FUN_00599A7D with
// the directory [0D6F510h] and L"civs.xml"), then walks the root's elements; each <civ> becomes a civ object
// appended by FUN_0052A4DB to the database's list [db+24h] (count [db+28h]), its ID the position. The hook
// (hooks/scenariocivs_hooks.asm) sits where that walk ends (0x52B485). There this file loads the second document
// into the same reader (FUN_00599A7D releases the first) and the hook runs the stock walk again from 0x52A62B,
// so a scenario civ is read by exactly the code that reads a civs.xml civ, unknown-tag handlers (civtags.h)
// included. When the second walk ends at the same place, the new civs get their two flags, and the loader goes
// on as stock: the native civ marks, then the reader's destructor.
//
// The document is checked before the second walk, since the stock walk cannot skip an element: the root must be
// <civs>, every element under it a <civ>, and each civ's <name> new (XS gets a constant cCiv<name> for every
// civ, and two of one name stop the AI scripts from compiling) and made of letters, digits and underscores. A
// file that fails a check is not used at all, with the reason in the log.
#include <windows.h>

#include <cstdint>
#include <cwchar>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcScenarioCivsHook();  // hooks/scenariocivs_hooks.asm

namespace {

constexpr wchar_t kFileName[] = L"scenariocivs.xml";
constexpr std::uint32_t kXmlDirectory = 0x00D6F510;  // the directory ID the loader passes for civs.xml
constexpr std::uint32_t kEndSite = 0x0052B485;       // push 0BCEE80h (5 bytes), after the walk of the root

// bool thiscall(reader, directory, const wchar_t* file, int, int), ret 10h; the loader passes 0 and 1.
using XmlLoadFn = bool(__thiscall*)(void* reader, std::int32_t directory, const wchar_t* file, std::int32_t,
                                    std::int32_t);
const auto kXmlLoad = reinterpret_cast<XmlLoadFn>(0x00599A7D);

bool g_log = false;
bool g_second = false;     // the walk running now is the one over scenariocivs.xml
std::int32_t g_first = 0;  // the first scenario civ's ID (the civ count after civs.xml)

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

// An XML node's element name, as the loader reads it: [[node+4]+18h][[node+18h]] (wide). Null if none.
const wchar_t* NodeName(const char* node) {
  const std::int32_t index = Field<std::int32_t>(node, 0x18);
  const char* names = Field<const char*>(node, 0x04);
  if (index < 0 || names == nullptr || index >= Field<std::int32_t>(names, 0x1C)) {
    return nullptr;
  }
  return Field<const wchar_t* const*>(names, 0x18)[index];
}

// A node's children: [node+8], count [node+0Ch] (the loader's loops, 0x52A692 and 0x52A72E).
std::int32_t ChildCount(const char* node) { return Field<std::int32_t>(node, 0x0C); }
const char* Child(const char* node, std::int32_t i) { return Field<const char* const*>(node, 0x08)[i]; }

bool SameText(const wchar_t* a, const wchar_t* b) { return a != nullptr && b != nullptr && _wcsicmp(a, b) == 0; }

// A node's text, [node+14h] (wide), without the spaces around it.
std::wstring NodeText(const char* node) {
  const wchar_t* text = Field<const wchar_t*>(node, 0x14);
  std::wstring s = text == nullptr ? L"" : text;
  const std::size_t begin = s.find_first_not_of(L" \t\r\n");
  if (begin == std::wstring::npos) {
    return L"";
  }
  return s.substr(begin, s.find_last_not_of(L" \t\r\n") - begin + 1);
}

bool IsIdentifier(const std::wstring& name) {
  if (name.empty()) {
    return false;
  }
  for (const wchar_t c : name) {
    if (!((c >= L'a' && c <= L'z') || (c >= L'A' && c <= L'Z') || (c >= L'0' && c <= L'9') || c == L'_')) {
      return false;
    }
  }
  return true;
}

// The civ list of the database: [db+24h], count [db+28h]; a civ's name is [civ+4] (char*).
bool CivNameTaken(const char* database, const std::wstring& name) {
  const std::int32_t count = Field<std::int32_t>(database, 0x28);
  const char* const* civs = Field<const char* const*>(database, 0x24);
  for (std::int32_t i = 0; i < count; ++i) {
    const char* civName = civs[i] == nullptr ? nullptr : Field<const char*>(civs[i], 0x04);
    if (civName == nullptr) {
      continue;
    }
    std::wstring wide;
    for (const char* p = civName; *p != 0; ++p) {
      wide.push_back(static_cast<unsigned char>(*p));
    }
    if (_wcsicmp(wide.c_str(), name.c_str()) == 0) {
      return true;
    }
  }
  return false;
}

// The checks of the class comment; true if the stock walk may run over this document.
bool CheckDocument(const char* root, const char* database, std::vector<std::wstring>* names) {
  if (root == nullptr || !SameText(NodeName(root), L"civs")) {
    uhc::Log(L"scenarioCivs: %ls: the root element is not <civs>; file not used", kFileName);
    return false;
  }
  for (std::int32_t i = 0; i < ChildCount(root); ++i) {
    const char* civ = Child(root, i);
    if (civ == nullptr) {
      continue;
    }
    const wchar_t* tag = NodeName(civ);
    if (!SameText(tag, L"civ")) {
      // civs.xml's other top-level elements (<subcivalliancecost> ...) would be read again and replace its values.
      uhc::Log(L"scenarioCivs: %ls: <%ls> is not a <civ> (only <civ> elements may stand under <civs>); file not used",
               kFileName, tag == nullptr ? L"?" : tag);
      return false;
    }
    std::wstring name;
    for (std::int32_t k = 0; k < ChildCount(civ); ++k) {
      const char* child = Child(civ, k);
      if (child != nullptr && SameText(NodeName(child), L"name")) {
        name = NodeText(child);
        break;
      }
    }
    if (!IsIdentifier(name)) {
      uhc::Log(L"scenarioCivs: %ls: civ %d has the name '%ls' (letters, digits and _ only, since XS makes cCiv<name> "
               L"of it); file not used", kFileName, static_cast<int>(names->size()) + 1, name.c_str());
      return false;
    }
    bool repeated = CivNameTaken(database, name);
    for (const std::wstring& other : *names) {
      repeated = repeated || _wcsicmp(other.c_str(), name.c_str()) == 0;
    }
    if (repeated) {
      uhc::Log(L"scenarioCivs: %ls: a civ named %ls already exists (two civs of one name stop the AI scripts from "
               L"compiling); file not used", kFileName, name.c_str());
      return false;
    }
    names->push_back(name);
  }
  if (names->empty()) {
    uhc::Log(L"scenarioCivs: %ls has no <civ>; nothing added", kFileName);
    return false;
  }
  return true;
}

// After the second walk: the civs it appended get <visible>0 and <visibleineditor>1. The flags are the bitset at
// [civ+128h], bit 0 Visible and bit 1 VisibleInEditor (the tag handlers at 0x52D302 and 0x52BE78).
void MarkScenarioCivs(const char* database) {
  const std::int32_t count = Field<std::int32_t>(database, 0x28);
  const char* const* civs = Field<const char* const*>(database, 0x24);
  for (std::int32_t id = g_first; id < count; ++id) {
    const char* civ = civs[id];
    if (civ == nullptr) {
      continue;
    }
    auto* bits = Field<std::uint8_t*>(civ, 0x128);
    if (bits != nullptr) {
      *bits = static_cast<std::uint8_t>((*bits & ~1u) | 2u);
    }
    if (g_log) {
      const char* name = Field<const char*>(civ, 0x04);
      uhc::Log(L"scenarioCivs: civ %d %hs (from %ls; hidden from the skirmish list, shown in the editor)", id,
               name == nullptr ? "?" : name, kFileName);
    }
  }
  uhc::Log(L"scenarioCivs: %d civ(s) added from %ls as IDs %d to %d (civs.xml ends at %d)", count - g_first,
           kFileName, g_first, count - 1, g_first - 1);
}

bool FileExists(const wchar_t* path) { return GetFileAttributesW(path) != INVALID_FILE_ATTRIBUTES; }

}  // namespace

// From the hook at the end of the loader's walk. True: scenariocivs.xml is loaded into the reader, walk it.
extern "C" bool __stdcall UhcScenarioCivsNext(void* reader, const char* database) {
  const std::int32_t count = Field<std::int32_t>(database, 0x28);
  if (g_second) {
    g_second = false;
    // A walk that stopped half-way (a broken civ) never came back here, so the next load's end would land in this
    // branch with nothing new: treat that one as the end of civs.xml.
    if (count > g_first) {
      MarkScenarioCivs(database);
      return false;
    }
  }
  // The end of the walk over civs.xml. The game finds the file in data\ (loose) as XML or XMB.
  if (!FileExists(L"data\\scenariocivs.xml") && !FileExists(L"data\\scenariocivs.xml.xmb")) {
    if (g_log) {
      uhc::Log(L"scenarioCivs: no data\\%ls; the civs end at ID %d, the last of civs.xml", kFileName, count - 1);
    }
    return false;
  }
  if (!kXmlLoad(reader, *reinterpret_cast<const std::int32_t*>(kXmlDirectory), kFileName, 0, 1)) {
    uhc::Log(L"scenarioCivs: data\\%ls could not be read (not well-formed XML?); file not used", kFileName);
    return false;
  }
  std::vector<std::wstring> names;
  if (!CheckDocument(Field<const char*>(reader, 0x08), database, &names)) {
    return false;  // the reader holds that document, but the loader does not read it again before its destructor
  }
  g_first = count;
  g_second = true;
  return true;
}

namespace uhc {

Outcome ApplyScenarioCivs(const Config& config) {
  const Config::Args* args = config.First("scenarioCivs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"scenarioCivs: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("scenarioCivs", {&sites::kScenarioCivsLoad, &sites::kScenarioCivsEnd, &sites::kScenarioCivsAppend,
                                  &sites::kCivFlagVisible, &sites::kCivFlagEditor, &sites::kXmlReaderLoad})) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!WriteJmp(kEndSite, reinterpret_cast<const void*>(&UhcScenarioCivsHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"scenarioCivs: data\\%ls is read after civs.xml, its civs appended and kept out of the skirmish list",
      kFileName);
  return Outcome::kApplied;
}

}  // namespace uhc
