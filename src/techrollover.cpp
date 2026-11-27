// The only exit of the tech rollover builder 0x4C737C (pop ebp / pop ebx / add esp,40h at 0x4C78F3) goes to
// UhcTechRolloverExitHook (hooks/techrollover_hooks.asm): it finishes the stock epilogue, then UhcTechRolloverExit
// calls each key's line in order, and the stock ret follows. Every caller of the builder gets the lines; a caller
// whose frame is known also gets its button's overlay text:
//   - 0x4622C5, the command panel FUN_0046188E (normal and minimised UI): overlay [esp+2C0h] there;
//   - 0x9AD7F1, the native command panel FUN_009ACAF4 (a trading post on a native socket): overlay [esp+248h];
//   - 0x9B7637, the trade route panel FUN_009B687E (a trading post on a trade route): overlay [esp+230h].
// Each of the three pushes the 8 arguments and calls (0x20 bytes) right where its overlay is at [esp+X], so at the
// return address the overlay is X plus that depth. The other callers: 0x703F99 (no player, no unit: the keys add
// nothing) and DLL code (politicianEnablesTech's age-up dialog), which is skipped, as before the hook moved here.
#include "techrollover.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcTechRolloverExitHook();

namespace {

constexpr std::size_t kMaxLines = 4;
constexpr std::uint32_t kExit = 0x004C78F3;
constexpr std::uint32_t kTextEnd = 0x00B836BE;  // the end of the exe's .text: a return address beyond is DLL code

using AppendFn = void(__thiscall*)(void* text, const wchar_t* more, std::int32_t length, std::int32_t start);
const auto kAppend = reinterpret_cast<AppendFn>(0x00443960);  // BString append; -1, -1: all of it, at the end

// A caller whose overlay buffer is known: its return address, the overlay's offset from the return address's slot,
// the sites that tie the frame to that buffer (its call, the reset per button, the read before the gadget's text).
struct Caller {
  std::uint32_t returnTo;
  std::uint32_t overlay;
  const wchar_t* name;
  const uhc::Site* call;
  const uhc::Site* reset;
  const uhc::Site* read;
  bool ok;
  bool seen;
};

Caller g_callers[] = {
    {0x004622CA, 0x24 + 0x2C0, L"the command panel (0x4622C5)", &uhc::sites::kTechButtonRollover,
     &uhc::sites::kButtonOverlayReset, &uhc::sites::kButtonOverlayRead, false, false},
    {0x009AD7F6, 0x3C + 0x248, L"the native command panel (0x9AD7F1)", &uhc::sites::kNativeTechRollover,
     &uhc::sites::kNativeOverlayReset, &uhc::sites::kNativeOverlayRead, false, false},
    {0x009B763C, 0x3C + 0x230, L"the trade route panel (0x9B7637)", &uhc::sites::kTradeRouteTechRollover,
     &uhc::sites::kTradeRouteOverlayReset, &uhc::sites::kTradeRouteOverlayRead, false, false},
};

uhc::TechRolloverLine g_lines[kMaxLines] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

// frame[0] the return address, frame[1..4] the rollover, the tech entry, the player, the unit.
extern "C" void __stdcall UhcTechRolloverExit(std::uint32_t* frame) {
  const char* entry = reinterpret_cast<const char*>(frame[2]);
  if (entry == nullptr || frame[0] >= kTextEnd) {
    return;  // a rollover built by DLL code (politicianEnablesTech's age-up dialog) is no research button
  }
  char* overlay = nullptr;
  for (Caller& caller : g_callers) {
    if (caller.returnTo == frame[0]) {
      if (caller.ok) {
        overlay = reinterpret_cast<char*>(frame) + caller.overlay;
      }
      if (!caller.seen) {
        caller.seen = true;
        uhc::Log(L"tech rollover: first rollover built for %ls", caller.name);
      }
      break;
    }
  }
  const auto* player = reinterpret_cast<const char*>(frame[3]);
  const auto* unit = reinterpret_cast<const char*>(frame[4]);
  auto* rollover = reinterpret_cast<void*>(frame[1]);
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
    if (!VerifyAll(feature, {&sites::kTechRolloverExit, &sites::kTechRolloverHead, &sites::kBStringAppend})) {
      return false;
    }
    // A panel whose frame is not the stock one (another DLL changed it) still gets the lines, without the word on
    // its buttons.
    for (Caller& caller : g_callers) {
      caller.ok = Matches(*caller.call) && Matches(*caller.reset) && Matches(*caller.read);
      if (!caller.ok) {
        Log(L"tech rollover: %ls is not the stock code; its buttons get no overlay text", caller.name);
      }
    }
    if (!WriteJmp(kExit, reinterpret_cast<const void*>(&UhcTechRolloverExitHook), 5)) {
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
