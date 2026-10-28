// Single-site patches: removeConversionRestriction, ignoreRegistryPath, customRevolutionBanners.
#include <windows.h>

#include <cstdio>
#include <cstring>

#include "../features.h"
#include "../generated/sites.h"
#include "../patch.h"

extern "C" {
void UhcRevBannerHook();

// Called from UhcRevBannerHook with a revolution tech name. Returns the banner texture path
// for "XPRevolution<Name>" (ui\ingame\politicians\REV_banner_<Name>, the upstream convention),
// or null for any other tech. Only the UI thread calls this, so a static buffer is enough.
const wchar_t* __stdcall UhcRevBannerPath(const char* techName) {
  static wchar_t path[MAX_PATH];
  constexpr char kPrefix[] = "XPRevolution";
  constexpr size_t kPrefixLen = sizeof(kPrefix) - 1;
  if (techName == nullptr || std::strncmp(techName, kPrefix, kPrefixLen) != 0 ||
      techName[kPrefixLen] == '\0') {
    return nullptr;
  }
  // The precision bounds the copy; upstream overflows a MAX_PATH buffer on long names.
  if (swprintf_s(path, L"ui\\ingame\\politicians\\REV_banner_%.200hs", techName + kPrefixLen) < 0) {
    return nullptr;
  }
  return path;
}
}

namespace uhc {

// 0x9D5B6C: `je 9D5BADh` after the unit-flag test that limits ConvertGuardian to treasure
// guardians. NOPing it lets the power target any unit.
Outcome ApplyRemoveConversionRestriction(const Config& config) {
  if (!config.Has("removeConversionRestriction")) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("removeConversionRestriction", {&sites::kConversionRestriction})) {
    return Outcome::kFailed;
  }
  const std::uint8_t nops[] = {0x90, 0x90};
  return WriteBytes(sites::kConversionRestriction.va, nops, sizeof(nops)) ? Outcome::kApplied
                                                                          : Outcome::kFailed;
}

// 0x57CB54: `jl 6420A1h` taken when reading the install path from the registry fails. Making it
// unconditional always uses the current directory (GetCurrentDirectoryW at 0x6420AB).
Outcome ApplyIgnoreRegistryPath(const Config& config) {
  if (!config.Has("ignoreRegistryPath")) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("ignoreRegistryPath", {&sites::kRegistryPath, &sites::kRegistryPathTarget})) {
    return Outcome::kFailed;
  }
  return WriteJmp(sites::kRegistryPath.va, sites::kRegistryPathTarget.va, sites::kRegistryPath.size)
             ? Outcome::kApplied
             : Outcome::kFailed;
}

// 0x81A7CC: stock shows a revolution banner only for XPRevolutionOHiggins. The hook gives every
// XPRevolution<Name> tech the banner ui\ingame\politicians\REV_banner_<Name>.
Outcome ApplyCustomRevolutionBanners(const Config& config) {
  if (!config.Has("customRevolutionBanners")) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("customRevolutionBanners", {&sites::kRevBanner})) {
    return Outcome::kFailed;
  }
  return WriteJmp(sites::kRevBanner.va, reinterpret_cast<const void*>(&UhcRevBannerHook), 5)
             ? Outcome::kApplied
             : Outcome::kFailed;
}

}  // namespace uhc
