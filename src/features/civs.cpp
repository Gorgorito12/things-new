// asianCivs Civ ...: the listed civs count as Asian civs (consulate and export, the Asian civs'
// values, the wonder age-up) for the stock tests that compare a player's first civ with the
// cached Asian civ IDs, and in the wonder age-up list a listed civ gets the wonders whose civ name
// is its cfg name. The hooks are in hooks/civ_hooks.asm; names resolve lazily (namelists.h).
#include <cstdint>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../namelists.h"
#include "../patch.h"

namespace {

uhc::CivIdList g_asianCivs;
std::vector<std::wstring> g_asianWide;  // the cfg names, for the wonder option compare
bool g_asianLog = false;
bool g_wonderLogged = false;

}  // namespace

extern "C" {
void UhcAsianCivCheckHook();
void UhcAsianCivBranchHook();
void UhcWonderAgeUpHook();

bool __stdcall UhcIsListedAsianCiv(std::int32_t civ) { return g_asianCivs.IndexOf(civ) >= 0; }

// True if `player`'s first civ is listed and the option's civ name (a BString) is its cfg name.
// 0x443C10: int thiscall(BString*, const wchar_t*, flag 0, -1), 0 = equal ignoring case.
bool __stdcall UhcAsianWonderOption(const char* player, void* optionCiv) {
  const int index = g_asianCivs.IndexOf(uhc::FirstCivOfPlayer(player));
  if (index < 0 || optionCiv == nullptr) {
    return false;
  }
  using Compare = int(__thiscall*)(void*, const wchar_t*, int, int);
  const bool match = reinterpret_cast<Compare>(0x00443C10)(optionCiv, g_asianWide[index].c_str(), 0, -1) == 0;
  if (match && g_asianLog && !g_wonderLogged) {
    g_wonderLogged = true;
    uhc::Log(L"asianCivs: %ls gets its wonders in the age-up list", g_asianWide[index].c_str());
  }
  return match;
}
}

namespace uhc {

Outcome ApplyAsianCivs(const Config& config) {
  const Config::Args* args = config.First("asianCivs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::vector<std::string> names;
  for (const std::string& a : *args) {
    if (a == "log") {
      g_asianLog = true;
    } else {
      names.push_back(a);
    }
  }
  if (names.empty()) {
    Log(L"asianCivs: no civ listed");
    return Outcome::kFailed;
  }
  if (!VerifyAll("asianCivs", {&sites::kAsianCivCheck, &sites::kAsianCivBranch, &sites::kWonderAgeUpCiv,
                               &sites::kCivIdByName, &sites::kModifyTypeNameCompare})) {
    return Outcome::kFailed;
  }
  for (const std::string& n : names) {
    g_asianWide.emplace_back(n.begin(), n.end());
  }
  g_asianCivs.Set("asianCivs", names);
  if (!WriteJmp(sites::kAsianCivCheck.va, reinterpret_cast<const void*>(&UhcAsianCivCheckHook),
                sites::kAsianCivCheck.size) ||
      !WriteJmp(sites::kAsianCivBranch.va, reinterpret_cast<const void*>(&UhcAsianCivBranchHook),
                sites::kAsianCivBranch.size) ||
      !WriteJmp(sites::kWonderAgeUpCiv.va, reinterpret_cast<const void*>(&UhcWonderAgeUpHook),
                sites::kWonderAgeUpCiv.size)) {
    return Outcome::kFailed;
  }
  Log(L"asianCivs: %zu civ(s) count as Asian civs; civ IDs are logged when civs.xml is read", names.size());
  return Outcome::kApplied;
}

}  // namespace uhc
