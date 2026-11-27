// The head of the tech flag reader 0x620C2F jumps to UhcTechFlagHook (hooks/techflags_hooks.asm), which asks
// UhcTechFlagDispatch; a flag no key takes goes on to the stock reader.
#include "techflags.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcTechFlagHook();

namespace {

constexpr std::size_t kMaxHandlers = 8;
constexpr std::uint32_t kFlagHead = 0x00620C2F;  // push esi / mov esi,[esp+8]

uhc::TechFlagHandler g_handlers[kMaxHandlers] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

// From the hook: true when a key took the flag.
extern "C" bool __stdcall UhcTechFlagDispatch(char* record, const char* name) {
  if (record == nullptr || name == nullptr) {
    return false;
  }
  for (std::size_t i = 0; i < g_count; ++i) {
    if (g_handlers[i](record, name)) {
      return true;
    }
  }
  return false;
}

namespace uhc {

bool AddTechFlagHandler(const char* feature, TechFlagHandler handler) {
  if (g_count == kMaxHandlers) {
    Log(L"%hs: no room for another tech flag handler", feature);
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll(feature, {&sites::kTechFlagHead}) ||
        !WriteJmp(kFlagHead, reinterpret_cast<const void*>(&UhcTechFlagHook), 5)) {
      return false;
    }
    g_installed = true;
  }
  g_handlers[g_count++] = handler;
  return true;
}

}  // namespace uhc
