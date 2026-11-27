// bigButtonCivs Civ ... / noBigButtonBlds Proto ...: the command panel's big button (FUN_0046188E,
// 0x461BD8) goes to native civs in stock; the listed civs get it too, and neither gets it on a
// building of a listed proto.
// nativeCivs Civ ...: the listed civs count as native civs: the civ flag the civs.xml loader sets
// for the native civs ([civ+10h]), the native civ tests (0x51271F, isNativeCiv 0x453D5E, 0x67B0A5,
// 0x8D52AF), the fire pit dances (through danceBonusCivs' gates) and the council age-up list
// (0x81ADEB: the options whose civ name is the cfg name).
// twoScoutCivs Civ ...: the listed civs get the hero UI of the two-hero civs (Japanese, Indians).
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
uhc::CivIdList g_twoScoutCivs;
uhc::CivIdList g_nativeCivs;
std::vector<std::string> g_nativeNames;
std::vector<std::wstring> g_nativeWide;
bool g_nativeMarked = false;
uhc::CivIdList g_bigButtonCivs;
uhc::ProtoIdList g_noBigButtonBlds;

}  // namespace

extern "C" {
void UhcAsianCivCheckHook();
void UhcAsianCivBranchHook();
void UhcWonderAgeUpHook();
void UhcTwoScout1Hook();
void UhcTwoScout2Hook();
void UhcTwoScout3Hook();
void UhcTwoScout4Hook();

void UhcNativeCivMarkHook();
void UhcNativeCivTest2Hook();
void UhcNativeCivTest4Hook();
void UhcNativeCivTest7Hook();
void UhcNativeCivTest9Hook();
void UhcNativeCouncilHook();

bool __stdcall UhcIsNativeCiv(std::int32_t civ) { return g_nativeCivs.IndexOf(civ) >= 0; }

// From the end of the civs.xml loader (0x52B581): the loader sets [civ+10h] = EBX for the stock
// native civs; do the same for the listed ones. 0x52D6FF: civ object by name, thiscall(database).
void __stdcall UhcMarkNativeCivs(char* database, std::int32_t value) {
  using CivByName = char*(__thiscall*)(char* database, const char* name);
  const auto civByName = reinterpret_cast<CivByName>(0x0052D6FF);
  int marked = 0;
  for (const std::string& name : g_nativeNames) {
    char* civ = civByName(database, name.c_str());
    if (civ != nullptr) {
      *reinterpret_cast<std::int32_t*>(civ + 0x10) = value;
      ++marked;
    }
  }
  if (!g_nativeMarked) {
    g_nativeMarked = true;
    uhc::Log(L"nativeCivs: %d of %zu civ(s) marked native in civs.xml", marked, g_nativeNames.size());
  }
}

// The council age-up list: true if `civ` is listed and the option's civ name is its cfg name.
bool __stdcall UhcNativeCouncilOption(std::int32_t civ, void* optionCiv) {
  const int index = g_nativeCivs.IndexOf(civ);
  if (index < 0 || optionCiv == nullptr) {
    return false;
  }
  using Compare = int(__thiscall*)(void*, const wchar_t*, int, int);
  return reinterpret_cast<Compare>(0x00443C10)(optionCiv, g_nativeWide[index].c_str(), 0, -1) == 0;
}

void UhcBigButtonHook();

// 1: take the native civs' big-button path (0x695955), 0: no big button (0x461BDE).
// native = AL of isNativeCiv(player, true); unit = the selected unit object ([unit+5Ch] its proto).
std::int32_t __stdcall UhcBigButtonPath(std::int32_t native, const char* player, const char* unit) {
  if ((native & 0xFF) == 0 && g_bigButtonCivs.IndexOf(uhc::FirstCivOfPlayer(player)) < 0) {
    return 0;
  }
  const char* proto = unit == nullptr ? nullptr : *reinterpret_cast<const char* const*>(unit + 0x5C);
  if (proto != nullptr && !g_noBigButtonBlds.empty() &&
      g_noBigButtonBlds.IndexOf(*reinterpret_cast<const std::int32_t*>(proto + 8)) >= 0) {
    return 0;
  }
  return 1;
}

bool __stdcall UhcIsTwoScoutCiv(std::int32_t civ) { return g_twoScoutCivs.IndexOf(civ) >= 0; }

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

Outcome ApplyNativeCivs(const Config& config) {
  const Config::Args* args = config.First("nativeCivs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (args->empty()) {
    Log(L"nativeCivs: no civ listed");
    return Outcome::kFailed;
  }
  const Site* const own[] = {&sites::kNativeCivMark, &sites::kNativeCivTest2, &sites::kNativeCivTest4,
                             &sites::kNativeCivTest7, &sites::kNativeCivTest9, &sites::kNativeCouncil};
  if (!VerifyAll("nativeCivs", {own[0], own[1], own[2], own[3], own[4], own[5], &sites::kCivIdByName,
                                &sites::kModifyTypeNameCompare})) {
    return Outcome::kFailed;
  }
  g_nativeNames = *args;
  for (const std::string& n : g_nativeNames) {
    g_nativeWide.emplace_back(n.begin(), n.end());
  }
  g_nativeCivs.Set("nativeCivs", g_nativeNames);
  void (*const hooks[])() = {&UhcNativeCivMarkHook, &UhcNativeCivTest2Hook, &UhcNativeCivTest4Hook,
                             &UhcNativeCivTest7Hook, &UhcNativeCivTest9Hook, &UhcNativeCouncilHook};
  for (int i = 0; i < 6; ++i) {
    if (!WriteJmp(own[i]->va, reinterpret_cast<const void*>(hooks[i]), own[i]->size)) {
      return Outcome::kFailed;
    }
  }
  if (!AddDanceCivs(g_nativeNames, "nativeCivs")) {
    return Outcome::kFailed;
  }
  Log(L"nativeCivs: %zu civ(s) count as native civs (fire pit dances through the shared dance gates)",
      g_nativeNames.size());
  return Outcome::kApplied;
}

Outcome ApplyBigButton(const Config& config) {
  const Config::Args* civs = config.First("bigButtonCivs");
  const Config::Args* blds = config.First("noBigButtonBlds");
  if (civs == nullptr && blds == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("bigButtonCivs", {&sites::kBigButton, &sites::kCivIdByName, &sites::kProtoByName})) {
    return Outcome::kFailed;
  }
  g_bigButtonCivs.Set("bigButtonCivs", civs != nullptr ? *civs : std::vector<std::string>{});
  g_noBigButtonBlds.Set("noBigButtonBlds", blds != nullptr ? *blds : std::vector<std::string>{});
  if (!WriteJmp(sites::kBigButton.va, reinterpret_cast<const void*>(&UhcBigButtonHook), sites::kBigButton.size)) {
    return Outcome::kFailed;
  }
  Log(L"bigButtonCivs/noBigButtonBlds: %zu civ(s) get the native big button, %zu building proto(s) never show it",
      civs != nullptr ? civs->size() : 0, blds != nullptr ? blds->size() : 0);
  return Outcome::kApplied;
}

Outcome ApplyTwoScoutCivs(const Config& config) {
  const Config::Args* args = config.First("twoScoutCivs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (args->empty()) {
    Log(L"twoScoutCivs: no civ listed");
    return Outcome::kFailed;
  }
  if (!VerifyAll("twoScoutCivs", {&sites::kTwoScout1, &sites::kTwoScout2, &sites::kTwoScout3, &sites::kTwoScout4,
                                  &sites::kCivIdByName})) {
    return Outcome::kFailed;
  }
  g_twoScoutCivs.Set("twoScoutCivs", *args);
  const struct {
    const Site* site;
    void (*hook)();
  } hooks[] = {{&sites::kTwoScout1, &UhcTwoScout1Hook},
               {&sites::kTwoScout2, &UhcTwoScout2Hook},
               {&sites::kTwoScout3, &UhcTwoScout3Hook},
               {&sites::kTwoScout4, &UhcTwoScout4Hook}};
  for (const auto& h : hooks) {
    if (!WriteJmp(h.site->va, reinterpret_cast<const void*>(h.hook), h.site->size)) {
      return Outcome::kFailed;
    }
  }
  Log(L"twoScoutCivs: %zu civ(s) get the two-hero UI; civ IDs are logged when civs.xml is read", args->size());
  return Outcome::kApplied;
}

}  // namespace uhc
