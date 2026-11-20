// The panel's call of the tech rollover builder at 0x4622C5 goes to UhcTechRolloverHook
// (hooks/techrollover_hooks.asm): it calls the builder with the same arguments, then UhcTechRolloverLines, which
// calls each key's line in order.
#include "techrollover.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcTechRolloverHook();

namespace {

constexpr std::size_t kMaxLines = 4;
constexpr std::uint32_t kRolloverCall = 0x004622C5;  // kTechButtonRollover + 10h

using AppendFn = void(__thiscall*)(void* text, const wchar_t* more, std::int32_t length, std::int32_t start);
const auto kAppend = reinterpret_cast<AppendFn>(0x00443960);  // BString append; -1, -1: all of it, at the end

uhc::TechRolloverLine g_lines[kMaxLines] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

extern "C" void __stdcall UhcTechRolloverLines(const char* entry, const char* player, const char* unit, void* rollover,
                                               char* overlay) {
  if (entry == nullptr) {
    return;
  }
  for (std::size_t i = 0; i < g_count; ++i) {
    g_lines[i](entry, player, unit, rollover, overlay);
  }
}

namespace uhc {

bool AddTechRolloverLine(const char* feature, TechRolloverLine line) {
  if (g_count == kMaxLines) {
    Log(L"tech rollover: more than %u keys", static_cast<unsigned>(kMaxLines));
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll(feature, {&sites::kTechButtonRollover, &sites::kButtonOverlayReset, &sites::kButtonOverlayRead,
                             &sites::kTechRolloverHead, &sites::kBStringAppend}) ||
        !WriteCall(kRolloverCall, reinterpret_cast<const void*>(&UhcTechRolloverHook))) {
      return false;
    }
    g_installed = true;
  }
  g_lines[g_count++] = line;
  return true;
}

void AppendTechRollover(void* rollover, const wchar_t* text) {
  if (rollover != nullptr && *static_cast<void**>(rollover) != nullptr && text != nullptr) {
    kAppend(rollover, text, -1, -1);
  }
}

}  // namespace uhc
