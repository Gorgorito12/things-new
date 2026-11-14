#include "xmllist.h"

#include <windows.h>

#include <cctype>
#include <cstdlib>

#include "hostfiles.h"

namespace uhc {
namespace {

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

bool ReadWholeFile(const std::wstring& path, std::string* out) {
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

bool IsNameChar(char c) { return std::isalnum(static_cast<unsigned char>(c)) || c == '_'; }

}  // namespace

bool ReadDataListFile(const std::string& arg, const wchar_t* defaultName, std::wstring* path, std::string* text) {
  *path = arg.empty() ? std::wstring(kDataFolder) + defaultName : std::wstring(arg.begin(), arg.end());
  const bool absolute = path->size() > 1 && ((*path)[1] == L':' || (*path)[0] == L'\\');
  if (!absolute) {
    *path = ExeDirectory() + *path;
  }
  return ReadWholeFile(*path, text);
}

std::deque<XmlListEntry> ParseXmlList(const std::string& text, const std::string& tag, int* bad) {
  std::string lower = text;
  for (char& c : lower) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  const std::string openTag = "<" + tag;
  const std::string closeTag = "</" + tag;
  std::deque<XmlListEntry> entries;
  size_t pos = 0;
  while (pos < lower.size()) {
    const size_t comment = lower.find("<!--", pos);
    const size_t open = lower.find(openTag, pos);
    if (open == std::string::npos) {
      break;
    }
    if (comment != std::string::npos && comment < open) {
      const size_t end = lower.find("-->", comment + 4);
      pos = end == std::string::npos ? lower.size() : end + 3;
      continue;
    }
    const size_t after = open + openTag.size();
    // A longer tag that starts with this one (the root <AbstractTypes>) is not an entry.
    if (after < lower.size() && IsNameChar(lower[after])) {
      pos = after;
      continue;
    }
    const size_t tagEnd = lower.find('>', after);
    const size_t close = tagEnd == std::string::npos ? std::string::npos : lower.find(closeTag, tagEnd);
    if (close == std::string::npos) {
      ++*bad;
      break;
    }
    XmlListEntry entry;
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
    pos = close + closeTag.size();
  }
  return entries;
}

}  // namespace uhc
