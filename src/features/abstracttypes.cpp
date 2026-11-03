// customAbstractTypes [file]: registers every name of an abstract-types file as an extra abstract
// unit type (unittypes.h), so protoy.xml, techtrees, auras and XS (cUnitType<Name>) can use it
// like a built-in type. Stock drops any <UnitType> that is not on its compiled-in list.
//
// File format (default data\uhc\customabstracttypes.xml, relative to the exe's folder):
//   <AbstractTypes>
//     <AbstractType stringId="430103">AbstractWoLCavalry</AbstractType>  <!-- comment -->
//     <AbstractType>AbstractTrainLimitOne</AbstractType>
//   </AbstractTypes>
// Names are registered in file order, before the types other features request, so their IDs do
// not depend on which other keys are set. stringId (a display name) is read and logged but not
// used yet.
#include <windows.h>

#include <cctype>
#include <cstdint>
#include <deque>
#include <set>
#include <string>

#include "../features.h"
#include "../log.h"
#include "../unittypes.h"
#include "../xmllist.h"

namespace uhc {
namespace {

// RequestAbstractUnitType keeps a pointer to each ID: a deque never moves its elements.
std::deque<std::int32_t> g_ids;

}  // namespace

Outcome ApplyCustomAbstractTypes(const Config& config) {
  const Config::Args* args = config.First("customAbstractTypes");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::wstring path;
  std::string text;
  if (!ReadDataListFile(args->empty() ? std::string() : args->front(), L"data\\uhc\\customabstracttypes.xml", &path,
                        &text)) {
    Log(L"customAbstractTypes: cannot read %ls (error %lu)", path.c_str(), GetLastError());
    return Outcome::kFailed;
  }
  int bad = 0;
  const std::deque<XmlListEntry> entries = ParseXmlList(text, "abstracttype", &bad);
  if (entries.empty()) {
    Log(L"customAbstractTypes: no <AbstractType> name in %ls", path.c_str());
    return Outcome::kFailed;
  }
  std::set<std::string> seen;
  int withString = 0;
  for (const XmlListEntry& entry : entries) {
    std::string key = entry.name;
    for (char& c : key) {
      c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    if (!seen.insert(key).second) {
      Log(L"customAbstractTypes: %hs is listed twice; the second is ignored", entry.name.c_str());
      continue;
    }
    g_ids.push_back(-1);
    if (!RequestAbstractUnitType(entry.name.c_str(), &g_ids.back())) {
      return Outcome::kFailed;
    }
    withString += entry.stringId >= 0 ? 1 : 0;
  }
  if (bad > 0) {
    Log(L"customAbstractTypes: %d entr%ls with an empty or invalid name (letters, digits, _) ignored", bad,
        bad == 1 ? L"y" : L"ies");
  }
  Log(L"customAbstractTypes: %zu abstract types from %ls (%d with a stringId, not used yet); IDs are "
      L"logged as `unit types:` on each data load",
      g_ids.size(), path.c_str(), withString);
  return Outcome::kApplied;
}

}  // namespace uhc
