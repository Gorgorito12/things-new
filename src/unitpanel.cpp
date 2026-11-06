#include "unitpanel.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

namespace {

constexpr std::size_t kMaxRows = 8;

// [panel+33Ch] unitResourceRateLabel, [panel+340h] unitResourceRateValue, and the styles of the
// stock row (vtable +84h), then the text (+80h) and the refresh (+54h).
constexpr std::uint32_t kPanelRateLabel = 0x33C;
constexpr std::uint32_t kPanelRateValue = 0x340;
constexpr std::uint32_t kLabelStyle = 0x00D6F5D0;
constexpr std::uint32_t kValueStyle = 0x00C6657C;

struct BString {
  wchar_t* text;
};

using GadgetRefFn = std::int32_t*(__thiscall*)(std::int32_t* ref, std::int32_t handle);  // ref: handle, gadget
using GadgetReleaseFn = std::int32_t(__cdecl*)(std::int32_t handle);
using GadgetStyleFn = void(__thiscall*)(void* gadget, std::uint32_t style);
using GadgetTextFn = void(__thiscall*)(void* gadget, const BString* text);
using GadgetUpdateFn = void(__thiscall*)(void* gadget);
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringFreeFn = void(__thiscall*)(BString* self);
using CurrentSelectionFn = const char*(__cdecl*)();  // reads globals only; the stock callers' ECX is unused
const auto kGadgetRef = reinterpret_cast<GadgetRefFn>(0x004C519C);
const auto kGadgetRelease = reinterpret_cast<GadgetReleaseFn>(0x0040431B);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kCurrentSelection = reinterpret_cast<CurrentSelectionFn>(0x00453B28);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

template <typename Fn>
Fn VirtualAt(void* object, std::uint32_t offset) {
  return *reinterpret_cast<Fn*>(*reinterpret_cast<char**>(object) + offset);
}

// The gadget behind a handle; the reference is released at once, as stock does.
void* PanelGadget(const char* panel, std::uint32_t field) {
  std::int32_t ref[2] = {0, 0};
  std::int32_t* result = kGadgetRef(ref, Field<std::int32_t>(panel, field));
  void* gadget = reinterpret_cast<void*>(static_cast<std::intptr_t>(result[1]));
  if (gadget != nullptr) {
    kGadgetRelease(result[0]);
  }
  return gadget;
}

void SetGadget(void* gadget, std::uint32_t style, const wchar_t* text) {
  BString value{nullptr};
  kBStringFromWide(&value, text);
  VirtualAt<GadgetStyleFn>(gadget, 0x84)(gadget, style);
  VirtualAt<GadgetTextFn>(gadget, 0x80)(gadget, &value);
  VirtualAt<GadgetUpdateFn>(gadget, 0x54)(gadget);
  kBStringFree(&value);
}

uhc::UnitPanelRow g_rows[kMaxRows] = {};
std::size_t g_rowCount = 0;
bool g_installed = false;

}  // namespace

extern "C" {
void UhcUnitPanelHook();  // hooks/unitpanelrow_hooks.asm

// From the hook at 0x699456. One unit selected, as the stat panel's rows ask: with a group the panel
// shows the first unit, and its numbers would read as the group's.
void __stdcall UhcUnitPanelRows(const char* panel, const char* unit) {
  if (panel == nullptr || unit == nullptr) {
    return;
  }
  const char* selection = kCurrentSelection();
  if (selection == nullptr || Field<std::int32_t>(selection, 0x14) != 1 || Field<std::uint8_t>(selection, 0x21) != 0) {
    return;
  }
  for (std::size_t i = g_rowCount; i > 0; --i) {
    if (g_rows[i - 1](panel, unit)) {
      return;
    }
  }
}
}

namespace uhc {

bool SetUnitPanelRow(const char* panel, const wchar_t* label, const wchar_t* value) {
  void* labelGadget = PanelGadget(panel, kPanelRateLabel);
  void* valueGadget = PanelGadget(panel, kPanelRateValue);
  if (labelGadget == nullptr || valueGadget == nullptr) {
    return false;
  }
  SetGadget(labelGadget, kLabelStyle, label);
  SetGadget(valueGadget, kValueStyle, value);
  return true;
}

bool AddUnitPanelRow(UnitPanelRow row) {
  if (g_rowCount == kMaxRows) {
    Log(L"unit panel: more than %u rows", static_cast<unsigned>(kMaxRows));
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("unit panel", {&sites::kUnitPanelRateRow, &sites::kUnitPanelAfterRate, &sites::kCurrentSelectionGroup,
                                  &sites::kGadgetRef, &sites::kGadgetRelease, &sites::kBStringFromWide,
                                  &sites::kBStringFree}) ||
        !WriteJmp(sites::kUnitPanelAfterRate.va, reinterpret_cast<const void*>(&UhcUnitPanelHook), 6)) {
      return false;
    }
    g_installed = true;
  }
  g_rows[g_rowCount++] = row;
  return true;
}

}  // namespace uhc
