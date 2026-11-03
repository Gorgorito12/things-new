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

namespace uhc {
namespace {

struct Entry {
  std::string name;
  int stringId = -1;
};

// RequestAbstractUnitType keeps a pointer to each ID: a deque never moves its elements.
std::deque<std::int32_t> g_ids;

std::wstring ExeDirectory() {
  wchar_t exe[MAX_PATH];
  const DWORD len = GetModuleFileNameW(nullptr, exe, MAX_PATH);
  if (len == 0 || len == MAX_PATH) {
    return {};
  }
  std::wstring path(exe, len);
  path.resize(path.find_last_of(L'\\') + 1);
  return path;
}

bool ReadFile(const std::wstring& path, std::string* out) {
  HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
                            FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }
  LARGE_INTEGER size{};
  bool ok = GetFileSizeEx(file, &size) && size.QuadPart < (4 << 20);
  if (ok) {
    out->resize(static_cast<size_t>(size.QuadPart));
    DWORD got = 0;
    ok = out->empty() || (::ReadFile(file, out->data(), static_cast<DWORD>(out->size()), &got, nullptr) &&
                          got == out->size());
  }
  CloseHandle(file);
  return ok;
}

bool ValidName(const std::string& name) {
  if (name.empty() || name.size() > 100) {
    return false;
  }
  for (char c : name) {
    if (!std::isalnum(static_cast<unsigned char>(c)) && c != '_') {
      return false;
    }
  }
  return true;
}

std::string Trim(const std::string& s) {
  const size_t begin = s.find_first_not_of(" \t\r\n");
  if (begin == std::string::npos) {
    return {};
  }
  return s.substr(begin, s.find_last_not_of(" \t\r\n") - begin + 1);
}

// The <AbstractType> elements of `text`, outside comments; tag names in any case.
std::deque<Entry> Parse(const std::string& text, int* bad) {
  std::string lower = text;
  for (char& c : lower) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  std::deque<Entry> entries;
  size_t pos = 0;
  while (pos < lower.size()) {
    const size_t comment = lower.find("<!--", pos);
    const size_t open = lower.find("<abstracttype", pos);
    if (open == std::string::npos) {
      break;
    }
    if (comment != std::string::npos && comment < open) {
      const size_t end = lower.find("-->", comment + 4);
      pos = end == std::string::npos ? lower.size() : end + 3;
      continue;
    }
    const size_t after = open + 13;
    // <AbstractTypes> (the root) is not an entry.
    if (after < lower.size() && (std::isalnum(static_cast<unsigned char>(lower[after])) || lower[after] == '_')) {
      pos = after;
      continue;
    }
    const size_t tagEnd = lower.find('>', after);
    const size_t close = tagEnd == std::string::npos ? std::string::npos : lower.find("</abstracttype", tagEnd);
    if (close == std::string::npos) {
      ++*bad;
      break;
    }
    Entry entry;
    entry.name = Trim(text.substr(tagEnd + 1, close - tagEnd - 1));
    const std::string attributes = lower.substr(after, tagEnd - after);
    const size_t id = attributes.find("stringid");
    if (id != std::string::npos) {
      const size_t quote = attributes.find_first_of("\"'", id);
      if (quote != std::string::npos) {
        entry.stringId = std::atoi(attributes.c_str() + quote + 1);
      }
    }
    if (ValidName(entry.name)) {
      entries.push_back(std::move(entry));
    } else {
      ++*bad;
    }
    pos = close + 14;
  }
  return entries;
}

}  // namespace

Outcome ApplyCustomAbstractTypes(const Config& config) {
  const Config::Args* args = config.First("customAbstractTypes");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::wstring path = args->empty() ? std::wstring(L"data\\uhc\\customabstracttypes.xml")
                                    : std::wstring(args->front().begin(), args->front().end());
  const bool absolute = path.size() > 1 && (path[1] == L':' || path[0] == L'\\');
  if (!absolute) {
    path = ExeDirectory() + path;
  }
  std::string text;
  if (!ReadFile(path, &text)) {
    Log(L"customAbstractTypes: cannot read %ls (error %lu)", path.c_str(), GetLastError());
    return Outcome::kFailed;
  }
  int bad = 0;
  const std::deque<Entry> entries = Parse(text, &bad);
  if (entries.empty()) {
    Log(L"customAbstractTypes: no <AbstractType> name in %ls", path.c_str());
    return Outcome::kFailed;
  }
  std::set<std::string> seen;
  int withString = 0;
  for (const Entry& entry : entries) {
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
