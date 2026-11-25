#include "progresspie.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"
#include "uigadgets.h"
#include "unitpanel.h"

namespace {

constexpr std::size_t kMaxSources = 8;

constexpr std::uint32_t kPanelPortrait = 0x2E4;  // [panel+2E4h] the unitselectionpanel-unitPortrait handle (0x9BAE85)
constexpr std::uint32_t kGroupCount = 0x14;      // the selection group's unit count
constexpr std::uint32_t kGadgetMaterial = 0x12C; // the filling's material, made by 0xAB5BAA
constexpr std::uint32_t kGadgetPie = 0x130;      // the 20h-byte pie chart filling, made by vtable +6Ch
constexpr std::uint32_t kPieColour = 0x04;       // ARGB, as 0x404DF6 packs it
constexpr std::uint32_t kPieOn = 0x1E;           // byte, what 0x4C51FA writes
constexpr std::uint32_t kFillSlot = 0x6C;        // every gadget vtable: 0xAB6C63

using FillFn = void(__thiscall*)(void* gadget, float fraction);
using EnableFn = void(__thiscall*)(void* gadget, bool on);
using ColourFn = void(__thiscall*)(void* gadget, float r, float g, float b, float a);
using MaterialFn = void(__thiscall*)(void* gadget);
const auto kFill = reinterpret_cast<FillFn>(0x00AB6C63);
const auto kEnable = reinterpret_cast<EnableFn>(0x004C51FA);
const auto kColour = reinterpret_cast<ColourFn>(0x00AB5C34);
const auto kMaterial = reinterpret_cast<MaterialFn>(0x00AB5BAA);

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

uhc::ProgressPieSource g_sources[kMaxSources] = {};
std::size_t g_sourceCount = 0;
bool g_tailAdded = false;
int g_verified = -1;  // -1 not checked, 0 failed, 1 passed
bool g_slotWarned = false;

// The gadget's fill slot must be the base one, which makes the filling this file reads.
bool HasBaseFill(const void* gadget) {
  const auto vtable = Field<const std::uintptr_t*>(gadget, 0);
  if (vtable != nullptr && vtable[kFillSlot / 4] == reinterpret_cast<std::uintptr_t>(kFill)) {
    return true;
  }
  if (!g_slotWarned) {
    g_slotWarned = true;
    uhc::Log(L"progress pie: a gadget's fill slot is not 0xAB6C63; no pie on it");
  }
  return false;
}

bool Show(void* gadget, float fraction, std::uint32_t argb) {
  if (!HasBaseFill(gadget)) {
    return false;
  }
  kFill(gadget, fraction);  // makes the filling on first use, clamps to [0, 1]
  const char* pie = Field<const char*>(gadget, kGadgetPie);
  if (pie == nullptr) {
    return false;
  }
  if (Field<void*>(gadget, kGadgetMaterial) == nullptr) {
    kMaterial(gadget);  // as the unit stack buttons do (0x9B8AD1)
  }
  if (Field<std::uint32_t>(pie, kPieColour) != argb) {
    kColour(gadget, ((argb >> 16) & 0xFF) / 255.0f, ((argb >> 8) & 0xFF) / 255.0f, (argb & 0xFF) / 255.0f,
            ((argb >> 24) & 0xFF) / 255.0f);
  }
  if (Field<std::uint8_t>(pie, kPieOn) == 0) {
    kEnable(gadget, true);
  }
  return true;
}

void Hide(void* gadget) {
  const char* pie = Field<const char*>(gadget, kGadgetPie);
  if (pie != nullptr && Field<std::uint8_t>(pie, kPieOn) != 0) {
    kEnable(gadget, false);
  }
}

void __stdcall PortraitPie(char* panel, const char* selection, const char* unit, bool) {
  void* portrait = uhc::ui::Gadget(Field<std::int32_t>(panel, kPanelPortrait), uhc::ui::kAnyGadget);
  if (portrait == nullptr) {
    return;
  }
  if (unit != nullptr && selection != nullptr && Field<std::int32_t>(selection, kGroupCount) == 1) {
    for (std::size_t i = 0; i < g_sourceCount; ++i) {
      float fraction = 0.0f;
      std::uint32_t argb = uhc::kPieTrainBlue;
      if (g_sources[i](unit, &fraction, &argb)) {
        if (Show(portrait, fraction, argb)) {
          return;
        }
        break;
      }
    }
  }
  Hide(portrait);
}

}  // namespace

namespace uhc {

bool VerifyProgressPie(const char* feature) {
  if (g_verified < 0) {
    g_verified = VerifyAll(feature, {&sites::kPieFillSlot, &sites::kPieEnable, &sites::kPieEnableCold,
                                     &sites::kPieColour, &sites::kPieMaterial, &sites::kPiePortraitBind,
                                     &sites::kGadgetLookup})
                     ? 1
                     : 0;
  }
  return g_verified == 1;
}

bool AddProgressPieSource(ProgressPieSource source) {
  if (source == nullptr || !VerifyProgressPie("progress pie")) {
    return false;
  }
  if (g_sourceCount == kMaxSources) {
    Log(L"progress pie: more than %u sources", static_cast<unsigned>(kMaxSources));
    return false;
  }
  if (!g_tailAdded) {
    if (!AddUnitPanelTail(&PortraitPie)) {
      return false;
    }
    g_tailAdded = true;
  }
  g_sources[g_sourceCount++] = source;
  return true;
}

bool ShowGadgetPie(std::int32_t handle, float fraction, std::uint32_t argb) {
  if (g_verified != 1) {
    return false;
  }
  void* gadget = ui::Gadget(handle, ui::kAnyGadget);
  return gadget != nullptr && Show(gadget, fraction, argb);
}

void HideGadgetPie(std::int32_t handle) {
  if (g_verified != 1) {
    return;
  }
  if (void* gadget = ui::Gadget(handle, ui::kAnyGadget)) {
    Hide(gadget);
  }
}

}  // namespace uhc
