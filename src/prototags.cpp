#include "prototags.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcProtoTagsHook();  // hooks/prototag_hooks.asm

namespace {

constexpr std::size_t kMaxTags = 8;
constexpr std::uint32_t kTableTail = 0x0051DB0F;  // pop edi / mov al,1 / pop esi / pop ecx (5 B)

using RegisterFn = void(__thiscall*)(void* table, const char* name, uhc::ProtoTagHandler* handler);
const auto kRegister = reinterpret_cast<RegisterFn>(0x0059B738);

struct Tag {
  const char* name;
  uhc::ProtoTagHandler handler;
};

Tag g_tags[kMaxTags] = {};
std::size_t g_count = 0;
bool g_installed = false;

}  // namespace

// From the hook, with the table the builder just filled.
extern "C" void __stdcall UhcProtoTagsRegister(void* table) {
  for (std::size_t i = 0; i < g_count; ++i) {
    uhc::ProtoTagHandler handler = g_tags[i].handler;
    kRegister(table, g_tags[i].name, &handler);
  }
}

namespace uhc {

bool AddProtoTagHandler(const char* name, ProtoTagHandler handler) {
  if (g_count == kMaxTags) {
    Log(L"proto tags: no room for %hs", name);
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("proto tags", {&sites::kProtoTagsTail}) ||
        !WriteJmp(kTableTail, reinterpret_cast<const void*>(&UhcProtoTagsHook), 5)) {
      return false;
    }
    g_installed = true;
  }
  g_tags[g_count++] = {name, handler};
  return true;
}

}  // namespace uhc
