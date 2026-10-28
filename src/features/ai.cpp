// noAILimit: the AI personality list comes from every personality file in the exe's AI folder
// instead of the stock table of 11 (or 14 with TAD content). The hook is in hooks/ai_hooks.asm.
#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <cwchar>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
std::int32_t g_uhcPersonalityCount = 0;
const wchar_t* const* g_uhcPersonalities = nullptr;

void UhcAiLimitHook();
}

namespace uhc {
namespace {

// Read from the exe rather than hard-coded, so builds patched to another folder (WoL's AI4\)
// keep working.
const auto kAiFolder = reinterpret_cast<const wchar_t*>(0x00BE3A98);        // L"AI3\"
const auto kPersonalityExt = reinterpret_cast<const wchar_t*>(0x00C0B39C);  // L".personality"
constexpr size_t kMaxExeString = 32;

// Filled once; the game keeps the table pointer, so neither vector may change afterwards.
std::vector<std::wstring> g_names;
std::vector<const wchar_t*> g_table;

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

bool EndsWithNoCase(const std::wstring& s, const std::wstring& suffix) {
  return s.size() > suffix.size() &&
         _wcsicmp(s.c_str() + (s.size() - suffix.size()), suffix.c_str()) == 0;
}

}  // namespace

Outcome ApplyNoAiLimit(const Config& config) {
  if (!config.Has("noAILimit")) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("noAILimit", {&sites::kAiLimit})) {
    return Outcome::kFailed;
  }
  const std::wstring folder(kAiFolder, wcsnlen_s(kAiFolder, kMaxExeString));
  const std::wstring ext(kPersonalityExt, wcsnlen_s(kPersonalityExt, kMaxExeString));
  const std::wstring pattern = ExeDirectory() + folder + L"*" + ext;

  WIN32_FIND_DATAW found;
  HANDLE search = FindFirstFileW(pattern.c_str(), &found);
  if (search != INVALID_HANDLE_VALUE) {
    do {
      std::wstring name = found.cFileName;
      // The wildcard also matches longer extensions through 8.3 names; keep exact ones only.
      if ((found.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0 && EndsWithNoCase(name, ext)) {
        name.resize(name.size() - ext.size());
        g_names.push_back(std::move(name));
      }
    } while (FindNextFileW(search, &found));
    FindClose(search);
  }
  if (g_names.empty()) {
    Log(L"noAILimit: no personality files match %ls; keeping the stock list", pattern.c_str());
    return Outcome::kFailed;
  }
  // Directory order differs between file systems; sort so every machine gets the same list.
  std::sort(g_names.begin(), g_names.end(),
            [](const std::wstring& a, const std::wstring& b) { return _wcsicmp(a.c_str(), b.c_str()) < 0; });
  g_table.reserve(g_names.size());
  for (const std::wstring& name : g_names) {
    g_table.push_back(name.c_str());
  }
  g_uhcPersonalities = g_table.data();
  g_uhcPersonalityCount = static_cast<std::int32_t>(g_table.size());

  if (!WriteJmp(sites::kAiLimit.va, reinterpret_cast<const void*>(&UhcAiLimitHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"noAILimit: %d personalities from %ls", g_uhcPersonalityCount, pattern.c_str());
  return Outcome::kApplied;
}

}  // namespace uhc
