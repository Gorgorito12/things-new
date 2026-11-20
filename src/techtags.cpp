#include "techtags.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcTechNodeHook();  // hooks/techtags_hooks.asm

namespace {

constexpr std::size_t kMaxObservers = 8;
constexpr std::size_t kMaxTags = 16;
constexpr std::uint32_t kTechNode = 0x0061FDB8;  // mov esi,eax / mov ecx,esi / mov edx,[ecx+18h] (7 B)

using XmlAttributeFn = bool(__thiscall*)(const char* node, const char* name, void** value);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);

struct Tag {
  const char* name;
  uhc::TechTagHandler handler;
};

uhc::TechNodeObserver g_observers[kMaxObservers] = {};
std::size_t g_observerCount = 0;
Tag g_tags[kMaxTags] = {};
std::size_t g_tagCount = 0;
bool g_installed = false;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// The element's name, as the parser's compare chain reads it: [[node+4]+18h][[node+18h]]; null for a node without one.
const wchar_t* NodeName(const char* node) {
  const std::int32_t index = Field<std::int32_t>(node, 0x18);
  const char* names = Field<const char*>(node, 0x04);
  if (index < 0 || names == nullptr || index >= Field<std::int32_t>(names, 0x1C)) {
    return nullptr;
  }
  return Field<const wchar_t* const*>(names, 0x18)[index];
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

// The <Tech>'s name attribute: 0x598F37 hands back the attribute's string object, whose first field is its UTF-16
// text.
const wchar_t* TechName(const char* node) {
  void* value = nullptr;
  if (!kXmlAttribute(node, "name", &value) || value == nullptr) {
    return L"";
  }
  const wchar_t* text = *static_cast<const wchar_t* const*>(value);
  return text == nullptr ? L"" : text;
}

bool Install() {
  if (g_installed) {
    return true;
  }
  if (!uhc::VerifyAll("tech tags", {&uhc::sites::kTechTagsNode}) ||
      !uhc::WriteJmp(kTechNode, reinterpret_cast<const void*>(&UhcTechNodeHook), 7)) {
    return false;
  }
  g_installed = true;
  return true;
}

}  // namespace

// From the hook, for each node of the techtree's root, before the parser reads it.
extern "C" void __stdcall UhcTechNodeDispatch(const char* node) {
  if (node == nullptr) {
    return;
  }
  for (std::size_t i = 0; i < g_observerCount; ++i) {
    g_observers[i](node);
  }
  if (g_tagCount == 0) {
    return;
  }
  const wchar_t* name = NodeName(node);
  if (name == nullptr || !SameName("tech", name)) {
    return;
  }
  // The children: [node+8] an array of nodes, [node+0Ch] their count (as the effect parse reads a <Target>).
  const std::int32_t count = Field<std::int32_t>(node, 0x0C);
  const char* const* children = Field<const char* const*>(node, 0x08);
  const wchar_t* techName = nullptr;
  for (std::int32_t c = 0; children != nullptr && c < count; ++c) {
    const char* child = children[c];
    const wchar_t* childName = child == nullptr ? nullptr : NodeName(child);
    if (childName == nullptr) {
      continue;
    }
    for (std::size_t t = 0; t < g_tagCount; ++t) {
      if (SameName(g_tags[t].name, childName)) {
        if (techName == nullptr) {
          techName = TechName(node);
        }
        g_tags[t].handler(node, techName, Field<const wchar_t*>(child, 0x14));
        break;
      }
    }
  }
}

namespace uhc {

bool OnTechNode(TechNodeObserver observer) {
  if (g_observerCount == kMaxObservers) {
    Log(L"tech tags: no room for another observer");
    return false;
  }
  if (!Install()) {
    return false;
  }
  g_observers[g_observerCount++] = observer;
  return true;
}

bool AddTechTagHandler(const char* name, TechTagHandler handler) {
  if (g_tagCount == kMaxTags) {
    Log(L"tech tags: no room for %hs", name);
    return false;
  }
  if (!Install()) {
    return false;
  }
  g_tags[g_tagCount++] = {name, handler};
  return true;
}

}  // namespace uhc
