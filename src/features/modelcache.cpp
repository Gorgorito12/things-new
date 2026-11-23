// modelCacheLimit [MB] [log]: the model cache's memory budget (stock 30,000,000 bytes). Every frame FUN_0041CA8F
// unloads the least recently used model (FUN_00AD9FD8 -> FUN_0046C210 -> GrannyFreeFile) while the cache holds
// more than the budget ([mgr+306Ch], mgr = [0xC66240]+60A0h); a unit that still draws or animates with an
// unloaded model then reads freed Granny data and the game crashes (0x40C07C, 0x40CC7B, granny2.dll+0x3A02A).
// The budget is the imm32 of two compares, `cmp dword [esi+306Ch],1C9C380h` at 0x46C03D (then ja) and 0x6E0174
// (then jbe), the only two in the exe; each is rewritten, no hook. With no number, or 0, no model is ever
// unloaded for the budget. With `log`, a world tick writes the cache's size each time it passes a new 50 MB step.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../worldtick.h"

namespace uhc {
namespace {

constexpr std::uint32_t kGraphicsRoot = 0x00C66240;  // its +60A0h is the model manager FUN_0041CA8F runs on
constexpr std::uint32_t kCacheBytes = 0x60A0 + 0x306C;
constexpr std::uint32_t kLogStep = 50u * 1000000u;
constexpr long kMaxMegabytes = 4000;

std::uint32_t g_nextLogged = kLogStep;

void Tick(char* world, std::int32_t) {
  const auto root = *reinterpret_cast<char* const*>(kGraphicsRoot);
  if (root == nullptr) {
    return;
  }
  const std::uint32_t bytes = *reinterpret_cast<const std::uint32_t*>(root + kCacheBytes);
  if (bytes < g_nextLogged) {
    return;
  }
  const std::uint32_t ms = world != nullptr ? *reinterpret_cast<const std::uint32_t*>(world + 0x108) : 0;
  Log(L"modelCacheLimit: the model cache holds %u MB (game time %u:%02u)", bytes / 1000000u, ms / 60000u,
      ms / 1000u % 60u);
  g_nextLogged = (bytes / kLogStep + 1) * kLogStep;
}

}  // namespace

Outcome ApplyModelCacheLimit(const Config& config) {
  if (!config.Has("modelCacheLimit")) {
    return Outcome::kNotConfigured;
  }
  long megabytes = 0;
  bool log = false;
  bool number = false;
  for (const std::string& arg : *config.First("modelCacheLimit")) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
      continue;
    }
    char* end = nullptr;
    const long value = std::strtol(arg.c_str(), &end, 10);
    if (number || arg.empty() || *end != '\0' || value < 0 || value > kMaxMegabytes ||
        (value > 0 && value < 30)) {
      Log(L"modelCacheLimit: %hs is not a number of megabytes from 30 to %ld, 0 (no limit) or log; "
          L"feature not applied", arg.c_str(), kMaxMegabytes);
      return Outcome::kFailed;
    }
    number = true;
    megabytes = value;
  }
  if (!VerifyAll("modelCacheLimit", {&sites::kModelCacheBudget1, &sites::kModelCacheBudget2})) {
    return Outcome::kFailed;
  }
  // The compares are unsigned (ja / jbe), so 0xFFFFFFFF is never exceeded.
  const std::uint32_t budget = megabytes > 0 ? static_cast<std::uint32_t>(megabytes) * 1000000u : 0xFFFFFFFFu;
  // `81 BE 6C 30 00 00 imm32`: the immediate is the instruction's last four bytes.
  if (!WriteDword(sites::kModelCacheBudget1.va + 6, budget) ||
      !WriteDword(sites::kModelCacheBudget2.va + 6, budget)) {
    return Outcome::kFailed;
  }
  if (megabytes > 0) {
    Log(L"modelCacheLimit: models are unloaded above %ld MB of loaded models (stock 30 MB)", megabytes);
  } else {
    Log(L"modelCacheLimit: models are never unloaded for the cache budget (stock: above 30 MB)");
  }
  if (log && !AddWorldTick(&Tick)) {
    Log(L"modelCacheLimit: log: the world update hook could not be added; the limit stays applied");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
