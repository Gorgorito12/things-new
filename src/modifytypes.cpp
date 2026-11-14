#include "modifytypes.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcModifyTypeHook();  // hooks/modifytype_hooks.asm

namespace {

constexpr std::size_t kMaxTypes = 16;
constexpr std::uint32_t kNameTailHook = 0x005FE6D7;  // neg eax / sbb eax,eax / and al,0F1h (6 B)
constexpr std::int32_t kTailAdds = 0x0E;             // the tail adds 0Eh to what the hook leaves in EAX
constexpr std::uint32_t kFromActionParser = 0x005FC8B7;  // the action parser's call of the name parser

using CompareFn = std::int32_t(__thiscall*)(const void* name, const wchar_t* text, std::int32_t flag, std::int32_t n);
const auto kCompare = reinterpret_cast<CompareFn>(0x00443C10);

struct ModifyType {
  const wchar_t* name;
  std::int32_t stat;
};

ModifyType g_types[kMaxTypes] = {};
std::size_t g_count = 0;
bool g_installed = false;
uhc::UnknownModifyType g_unknown = nullptr;

bool Install() {
  if (g_installed) {
    return true;
  }
  if (!uhc::VerifyAll("modify types", {&uhc::sites::kModifyTypeNameTail, &uhc::sites::kModifyTypeNameCompare}) ||
      !uhc::WriteJmp(kNameTailHook, reinterpret_cast<const void*>(&UhcModifyTypeHook), 6)) {
    return false;
  }
  g_installed = true;
  return true;
}

}  // namespace

// From the hook, for a name that is none of the stock ones. The tail returns EAX + 0Eh. For the action parser's call,
// `proto` is its argument; for the other caller that slot means nothing.
extern "C" std::int32_t __stdcall UhcModifyTypeByName(const void* name, std::uint32_t returnAddress, const char* proto) {
  for (std::size_t i = 0; i < g_count; ++i) {
    if (kCompare(name, g_types[i].name, 0, -1) == 0) {
      return g_types[i].stat - kTailAdds;
    }
  }
  if (g_unknown != nullptr) {
    g_unknown(*static_cast<const wchar_t* const*>(name), returnAddress == kFromActionParser ? proto : nullptr);
  }
  return -1 - kTailAdds;
}

namespace uhc {

bool AddModifyType(const wchar_t* name, std::int32_t stat) {
  if (g_count == kMaxTypes) {
    Log(L"modify types: no room for %ls", name);
    return false;
  }
  if (!Install()) {
    return false;
  }
  g_types[g_count++] = {name, stat};
  return true;
}

bool OnUnknownModifyType(UnknownModifyType callback) {
  if (!Install()) {
    return false;
  }
  g_unknown = callback;
  return true;
}

}  // namespace uhc
