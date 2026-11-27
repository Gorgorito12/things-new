#include "uigadgets.h"

#include "generated/sites.h"
#include "patch.h"

namespace uhc::ui {
namespace {

constexpr std::uint32_t kUiGlobal = 0x00C66244;  // [+44h] the gadget manager
constexpr std::uint32_t kNoGadget = 0x00C672C0;  // [..] the handle of "no gadget"

using LookupFn = void*(__fastcall*)(void* manager, void* edx, std::int32_t handle, std::int32_t type);
using FindChildFn = std::int32_t*(__fastcall*)(void* parent, void* edx, std::int32_t* out, const char* name,
                                               std::int32_t flag);

const auto kLookup = reinterpret_cast<LookupFn>(0x0040423C);
const auto kFindChild = reinterpret_cast<FindChildFn>(0x00433812);

using FindAnywhereFn = std::int32_t*(__fastcall*)(void* manager, void* edx, std::int32_t* out, const char* name);
using ShowFn = void(__fastcall*)(void* manager, void* edx, std::int32_t handle);
const auto kFindAnywhere = reinterpret_cast<FindAnywhereFn>(0x00433A2C);
const auto kShow = reinterpret_cast<ShowFn>(0x00447F7B);
const auto kHide = reinterpret_cast<ShowFn>(0x00448F13);

template <typename T>
T Read(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

bool g_verified = false;
bool g_showVerified = false;

}  // namespace

bool VerifyUiGadgets(const char* feature) {
  if (!g_verified) {
    g_verified = VerifyAll(feature, {&sites::kGadgetLookup, &sites::kUiFindChild, &sites::kUiFieldEditBox,
                                     &sites::kUiEditBoxText});
  }
  return g_verified;
}

void* Manager() {
  const char* ui = *reinterpret_cast<const char* const*>(kUiGlobal);
  return ui == nullptr ? nullptr : Read<void*>(ui, 0x44);
}

void* Gadget(std::int32_t handle, std::int32_t type) {
  void* manager = Manager();
  if (manager == nullptr || handle == 0 || handle == *reinterpret_cast<const std::int32_t*>(kNoGadget)) {
    return nullptr;
  }
  return kLookup(manager, nullptr, handle, type);
}

std::int32_t HandleOf(const void* gadget) { return gadget == nullptr ? 0 : Read<std::int32_t>(gadget, 0x0C); }

std::int32_t FindChild(void* parent, const char* name) {
  if (parent == nullptr) {
    return 0;
  }
  std::int32_t handle = 0;
  kFindChild(parent, nullptr, &handle, name, 1);
  return handle == *reinterpret_cast<const std::int32_t*>(kNoGadget) ? 0 : handle;
}

std::int32_t FindAnywhere(const char* name) {
  void* manager = Manager();
  if (manager == nullptr || name == nullptr) {
    return 0;
  }
  std::int32_t handle = 0;
  kFindAnywhere(manager, nullptr, &handle, name);
  return handle == *reinterpret_cast<const std::int32_t*>(kNoGadget) ? 0 : handle;
}

bool VerifyUiShow(const char* feature) {
  if (!g_showVerified) {
    g_showVerified = VerifyAll(feature, {&sites::kGadgetLookup, &sites::kGadgetShow, &sites::kGadgetHide,
                                         &sites::kUiGadgetShowFlags, &sites::kUiGadgetHideFlags});
  }
  return g_showVerified;
}

void Show(std::int32_t handle, bool visible) {
  void* manager = Manager();
  if (manager != nullptr && handle != 0) {
    (visible ? kShow : kHide)(manager, nullptr, handle);
  }
}

int ShownState(std::int32_t handle) {
  const void* gadget = Gadget(handle, kAnyGadget);
  if (gadget == nullptr) {
    return -1;
  }
  const std::uint8_t flags = Read<std::uint8_t>(gadget, 0xA4);
  if ((flags & 0x03) == 0x03 && (flags & 0x80) == 0) {
    return 1;
  }
  return (flags & 0x83) == 0 ? 0 : -1;
}

const wchar_t* FieldText(const void* field) {
  const void* edit = field == nullptr ? nullptr : Gadget(Read<std::int32_t>(field, 0x160), kEditBox);
  const wchar_t* text = edit == nullptr ? nullptr : Read<const wchar_t*>(edit, 0x170);
  return text == nullptr ? L"" : text;
}

}  // namespace uhc::ui
