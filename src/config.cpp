#include "config.h"

#include <windows.h>

#include <cctype>
#include <charconv>

namespace uhc {
namespace {

std::string Lower(std::string s) {
  for (char& c : s) {
    c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  }
  return s;
}

bool IsSpace(char c) { return c == ' ' || c == '\t' || c == '\r'; }

}  // namespace

bool Config::Load(const std::wstring& path) {
  entries_.clear();
  HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
                            FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }
  std::string text;
  LARGE_INTEGER size{};
  if (GetFileSizeEx(file, &size) && size.QuadPart > 0 && size.QuadPart < (1 << 24)) {
    text.resize(static_cast<size_t>(size.QuadPart));
    DWORD read = 0;
    if (!ReadFile(file, text.data(), static_cast<DWORD>(text.size()), &read, nullptr)) {
      read = 0;
    }
    text.resize(read);
  }
  CloseHandle(file);

  size_t pos = 0;
  while (pos < text.size()) {
    size_t end = text.find('\n', pos);
    if (end == std::string::npos) {
      end = text.size();
    }
    Args words;
    size_t i = pos;
    while (i < end) {
      while (i < end && IsSpace(text[i])) {
        ++i;
      }
      const size_t start = i;
      while (i < end && !IsSpace(text[i])) {
        ++i;
      }
      if (i > start) {
        words.emplace_back(text, start, i - start);
      }
    }
    pos = end + 1;
    if (words.empty() || words.front().front() == '#') {
      continue;
    }
    std::string key = Lower(words.front());
    words.erase(words.begin());
    entries_[key].push_back(std::move(words));
  }
  return true;
}

bool Config::Has(const std::string& key) const { return entries_.count(Lower(key)) != 0; }

const Config::Args* Config::First(const std::string& key) const {
  const auto* all = All(key);
  return all == nullptr ? nullptr : &all->front();
}

const std::vector<Config::Args>* Config::All(const std::string& key) const {
  const auto it = entries_.find(Lower(key));
  return it == entries_.end() ? nullptr : &it->second;
}

std::optional<int> Config::Int(const std::string& key) const {
  const Args* args = First(key);
  if (args == nullptr || args->empty()) {
    return std::nullopt;
  }
  const std::string& s = args->front();
  int value = 0;
  const auto [end, ec] = std::from_chars(s.data(), s.data() + s.size(), value);
  if (ec != std::errc() || end != s.data() + s.size()) {
    return std::nullopt;
  }
  return value;
}

}  // namespace uhc
