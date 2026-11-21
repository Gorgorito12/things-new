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

template <typename T>
T Read(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

bool g_verified = false;

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

const wchar_t* FieldText(const void* field) {
  const void* edit = field == nullptr ? nullptr : Gadget(Read<std::int32_t>(field, 0x160), kEditBox);
  const wchar_t* text = edit == nullptr ? nullptr : Read<const wchar_t*>(edit, 0x170);
  return text == nullptr ? L"" : text;
}

}  // namespace uhc::ui
