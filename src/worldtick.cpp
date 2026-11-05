#include "worldtick.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

namespace {

constexpr std::size_t kMaxTicks = 8;

using WorldUpdateFn = bool(__fastcall*)(char* world, void* unused, std::int32_t a, std::int32_t deltaMs);

uhc::WorldTick g_ticks[kMaxTicks] = {};
std::size_t g_tickCount = 0;
bool g_installed = false;

}  // namespace

extern "C" {
void UhcWorldUpdateStock();  // hooks/worldtick_hooks.asm: the stolen prologue, then the stock body
void UhcWorldUpdateHook();

// The stock world update, then every tick in order. Same frame as the stock thiscall: ECX = world,
// the two stack arguments, ret 8.
bool __fastcall UhcWorldUpdate(char* world, void*, std::int32_t a, std::int32_t deltaMs) {
  const bool result = reinterpret_cast<WorldUpdateFn>(&UhcWorldUpdateStock)(world, nullptr, a, deltaMs);
  for (std::size_t i = 0; i < g_tickCount; ++i) {
    g_ticks[i](world, deltaMs);
  }
  return result;
}

void* g_uhcWorldUpdate = reinterpret_cast<void*>(&UhcWorldUpdate);
}

namespace uhc {

bool AddWorldTick(WorldTick tick) {
  if (g_tickCount == kMaxTicks) {
    Log(L"world update: more than %u ticks", static_cast<unsigned>(kMaxTicks));
    return false;
  }
  if (!g_installed) {
    // sub esp,0Ch / push ebx / push ebp at 0x481A57; the trampoline re-executes them.
    if (!VerifyAll("world update", {&sites::kDotWorldUpdateEntry}) ||
        !WriteJmp(sites::kDotWorldUpdateEntry.va, reinterpret_cast<const void*>(&UhcWorldUpdateHook), 5)) {
      return false;
    }
    g_installed = true;
  }
  g_ticks[g_tickCount++] = tick;
  return true;
}

}  // namespace uhc
