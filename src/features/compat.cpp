// compatMode: every 32-bit display mode the adapter reports is also offered as a 16-bit mode.
//
// The renderer builds its list of display modes from the adapter's modes: FUN_0054D663 calls
// 0x54D605 (thiscall(renderer, const Mode* mode), ret 4) for each one, at 0x54D6D1. A mode is
// 16 bytes, its Direct3D format at +0Ch (0x545A10 gives the bit depth: 16h X8R8G8B8 = 32,
// 17h R5G6B5 = 16, ...). Current drivers report only 32-bit modes, so the list has no 16-bit
// entry. The key redirects that call to a wrapper that adds the mode and, for an X8R8G8B8 mode,
// adds it again as R5G6B5.
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

using AddMode = void(__thiscall*)(void* renderer, std::uint32_t* mode);
const auto kAddMode = reinterpret_cast<AddMode>(0x0054D605);

constexpr std::uint32_t kX8R8G8B8 = 0x16;
constexpr std::uint32_t kR5G6B5 = 0x17;
int g_added = 0;
bool g_logged = false;

// The call site is thiscall (ECX = renderer, one stack argument); __fastcall with an unused EDX
// has the same frame.
void __fastcall AddModeWrapper(void* renderer, void* /*edx*/, std::uint32_t* mode) {
  kAddMode(renderer, mode);
  if (mode != nullptr && mode[3] == kX8R8G8B8) {
    mode[3] = kR5G6B5;
    kAddMode(renderer, mode);
    mode[3] = kX8R8G8B8;
    ++g_added;
    if (!g_logged) {
      g_logged = true;
      uhc::Log(L"hook reached: compatMode (0x54D6D1): %ux%u also offered at 16 bits", mode[0], mode[1]);
    }
  }
}

}  // namespace

namespace uhc {

Outcome ApplyCompatMode(const Config& config) {
  if (config.First("compatMode") == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("compatMode", {&sites::kDisplayModeAddCall, &sites::kDisplayModeAdd})) {
    return Outcome::kFailed;
  }
  if (!WriteCall(sites::kDisplayModeAddCall.va, reinterpret_cast<const void*>(&AddModeWrapper))) {
    return Outcome::kFailed;
  }
  Log(L"compatMode: 32-bit display modes are also offered at 16 bits");
  return Outcome::kApplied;
}

}  // namespace uhc
