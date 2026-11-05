#include "civtags.h"

#include <cstddef>
#include <cwchar>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcCivTagsHook();  // hooks/civfirsttc_hooks.asm

namespace {

constexpr std::size_t kMaxTags = 8;
constexpr std::uint32_t kUnknownTag = 0x0052BB07;  // xor edi,edi / cmp dword ptr [ebx+80h],edi (8 B)

struct Tag {
  const char* name;
  uhc::CivTagHandler handler;
};

Tag g_tags[kMaxTags] = {};
std::size_t g_count = 0;
bool g_installed = false;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// name (narrow) == tag (wide), case ignored.
bool SameName(const char* name, const wchar_t* tag) {
  for (;; ++name, ++tag) {
    const wchar_t a = static_cast<wchar_t>(*name >= 'A' && *name <= 'Z' ? *name + 32 : *name);
    const wchar_t b = *tag >= L'A' && *tag <= L'Z' ? *tag + 32 : *tag;
    if (a != b) {
      return false;
    }
    if (a == 0) {
      return true;
    }
  }
}

}  // namespace

// From the hook: true if the node's name is a registered tag (then it is consumed).
extern "C" bool __stdcall UhcCivTagDispatch(const char* node, const char* civ) {
  // The element name, as the parser's compare chain reads it: [[node+4]+18h][[node+18h]].
  const std::int32_t index = Field<std::int32_t>(node, 0x18);
  const char* names = Field<const char*>(node, 0x04);
  if (index < 0 || names == nullptr || index >= Field<std::int32_t>(names, 0x1C)) {
    return false;
  }
  const wchar_t* tag = Field<const wchar_t* const*>(names, 0x18)[index];
  if (tag == nullptr) {
    return false;
  }
  for (std::size_t i = 0; i < g_count; ++i) {
    if (!SameName(g_tags[i].name, tag)) {
      continue;
    }
    const std::int32_t civId = civ == nullptr ? -1 : Field<std::int32_t>(civ, 0x08);
    if (civId >= 0 && civId < 0x10000) {
      g_tags[i].handler(civ, civId, Field<const wchar_t*>(node, 0x14));
    }
    return true;
  }
  return false;
}

namespace uhc {

bool AddCivTagHandler(const char* name, CivTagHandler handler) {
  if (g_count == kMaxTags) {
    Log(L"civ tags: no room for %hs", name);
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("civ tags", {&sites::kCivTagUnknown, &sites::kCivTagNextNode}) ||
        !WriteJmp(kUnknownTag, reinterpret_cast<const void*>(&UhcCivTagsHook), 8)) {
      return false;
    }
    g_installed = true;
  }
  g_tags[g_count++] = {name, handler};
  return true;
}

}  // namespace uhc
