#include "statpanelrows.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcStatPanelRowsHook();

namespace {

constexpr std::size_t kMaxRows = 4;
constexpr std::int32_t kStatPanelRows = 9;           // StackLabel/StackValue 0..8 (0x9BBAD1)
constexpr std::uint32_t kLabelHandles = 0x174;       // the panel's 9 label handles, then (+198h) its 9 value handles
constexpr std::uint32_t kValueHandles = 0x198;
constexpr std::uint32_t kLabelStyle = 0x00D6F5D0;    // the Group Health row's label style (vtable +84h)
constexpr std::uint32_t kValueStyle = 0x00C6657C;    // its value style

struct BString {
  wchar_t* text;
};

using GadgetRefFn = std::int32_t*(__thiscall*)(std::int32_t* ref, std::int32_t handle);  // ref: handle, gadget
using GadgetReleaseFn = std::int32_t(__cdecl*)(std::int32_t handle);
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringSetFn = BString*(__thiscall*)(BString* self, const BString* source);
using BStringFreeFn = void(__thiscall*)(BString* self);
using GadgetStyleFn = void(__thiscall*)(char* gadget, const void* style);
using GadgetTextFn = void(__thiscall*)(char* gadget, const BString* text);
using GadgetUpdateFn = void(__thiscall*)(char* gadget);
const auto kGadgetRef = reinterpret_cast<GadgetRefFn>(0x004C519C);
const auto kGadgetRelease = reinterpret_cast<GadgetReleaseFn>(0x0040431B);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringSet = reinterpret_cast<BStringSetFn>(0x0040196F);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);

template <typename Fn>
Fn VirtualAt(const char* object, std::uint32_t offset) {
  return *reinterpret_cast<const Fn*>(*reinterpret_cast<const char* const*>(object) + offset);
}

uhc::StatPanelRow g_rows[kMaxRows] = {};
std::size_t g_count = 0;
bool g_installed = false;

// A row gadget from its handle, as 0x69A9D3 gets it (the reference is released at once; the panel keeps the gadget).
char* RowGadget(std::int32_t handle) {
  std::int32_t ref[2] = {0, 0};
  std::int32_t* result = kGadgetRef(ref, handle);
  char* gadget = reinterpret_cast<char*>(static_cast<std::uintptr_t>(static_cast<std::uint32_t>(result[1])));
  if (result[1] != 0) {
    kGadgetRelease(result[0]);
  }
  return gadget;
}

// The style, the text, the update (vtable +84h, +80h, +54h), then the help text [gadget+68h].
void SetRowText(char* gadget, const void* style, const wchar_t* text, const wchar_t* tip) {
  BString value;
  kBStringFromWide(&value, text != nullptr ? text : L"");
  VirtualAt<GadgetStyleFn>(gadget, 0x84)(gadget, style);
  VirtualAt<GadgetTextFn>(gadget, 0x80)(gadget, &value);
  VirtualAt<GadgetUpdateFn>(gadget, 0x54)(gadget);
  kBStringFree(&value);
  BString help;
  kBStringFromWide(&help, tip != nullptr ? tip : L"");
  kBStringSet(reinterpret_cast<BString*>(gadget + 0x68), &help);
  kBStringFree(&help);
}

}  // namespace

// From the hook at 0x4D76DB: the rows written from `row` on (each key at most one), for the panel's unit.
extern "C" std::int32_t __stdcall UhcStatPanelRows(const char* panel, const char* unit, std::int32_t row) {
  if (panel == nullptr || unit == nullptr) {
    return 0;
  }
  std::int32_t written = 0;
  for (std::size_t i = 0; i < g_count && row + written < kStatPanelRows; ++i) {
    if (g_rows[i](panel, unit, row + written)) {
      ++written;
    }
  }
  return written;
}

namespace uhc {

bool AddStatPanelRow(StatPanelRow row, const char* feature) {
  if (g_count == kMaxRows) {
    Log(L"stat panel rows: more than %u keys (%hs)", static_cast<unsigned>(kMaxRows), feature);
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("stat panel rows", {&sites::kOverhealStatRow, &sites::kGroupHealthRow, &sites::kGadgetRef,
                                       &sites::kGadgetRelease, &sites::kBStringFromWide, &sites::kBStringSet,
                                       &sites::kBStringFree}) ||
        !WriteJmp(sites::kOverhealStatRow.va, reinterpret_cast<const void*>(&UhcStatPanelRowsHook), 9)) {
      return false;
    }
    g_installed = true;
  }
  g_rows[g_count++] = row;
  return true;
}

bool SetStatPanelRow(const char* panel, std::int32_t row, const wchar_t* label, const wchar_t* value,
                     const wchar_t* tip) {
  if (panel == nullptr || row < 0 || row >= kStatPanelRows) {
    return false;
  }
  char* labelGadget = RowGadget(*reinterpret_cast<const std::int32_t*>(panel + kLabelHandles + row * 4));
  char* valueGadget = RowGadget(*reinterpret_cast<const std::int32_t*>(panel + kValueHandles + row * 4));
  if (labelGadget == nullptr || valueGadget == nullptr) {
    return false;
  }
  SetRowText(labelGadget, reinterpret_cast<const void*>(kLabelStyle), label, tip);
  SetRowText(valueGadget, reinterpret_cast<const void*>(kValueStyle), value, tip);
  return true;
}

}  // namespace uhc
