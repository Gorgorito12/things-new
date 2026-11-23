// The home city loader's call of the card append at 0x630017 goes to UhcCardCommitHook (hooks/cardtags_hooks.asm):
// it appends the card as stock does, then UhcCardTagsDispatch walks the card node's children for the keys' tags.
#include "cardtags.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" void UhcCardCommitHook();

namespace {

constexpr std::size_t kMaxTags = 8;
constexpr std::uint32_t kCommitCall = 0x00630017;  // call 62FBC7h
constexpr std::uint32_t kCardArray = 0x204;        // in the home city: {data, count, capacity}
constexpr std::uint32_t kCardSize = 0x28;

struct Tag {
  const char* name;
  uhc::CardTagHandler handler;
};

Tag g_tags[kMaxTags] = {};
std::size_t g_count = 0;
bool g_installed = false;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// The element's name, as the loader's compare chain reads it: [[node+4]+18h][[node+18h]]; null for a node without one.
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

}  // namespace

// From the hook, after the append: `node` is the <card> (EBX in the loader), `array` the home city's card array
// (hc+204h), `index` the new card's index in it.
extern "C" void __stdcall UhcCardTagsDispatch(const char* node, char* array, std::int32_t index) {
  if (node == nullptr || array == nullptr || index < 0 || index >= Field<std::int32_t>(array, 4)) {
    return;
  }
  char* data = Field<char*>(array, 0);
  if (data == nullptr) {
    return;
  }
  char* card = data + static_cast<std::uint32_t>(index) * kCardSize;
  char* hc = array - kCardArray;
  // The children: [node+8] an array of nodes, [node+0Ch] their count (as the loader's loop reads them).
  const std::int32_t count = Field<std::int32_t>(node, 0x0C);
  const char* const* children = Field<const char* const*>(node, 0x08);
  for (std::int32_t c = 0; children != nullptr && c < count; ++c) {
    const char* child = children[c];
    const wchar_t* name = child == nullptr ? nullptr : NodeName(child);
    if (name == nullptr) {
      continue;
    }
    for (std::size_t t = 0; t < g_count; ++t) {
      if (SameName(g_tags[t].name, name)) {
        g_tags[t].handler(hc, card, Field<const wchar_t*>(child, 0x14));
      }
    }
  }
}

namespace uhc {

bool AddCardTagHandler(const char* feature, const char* name, CardTagHandler handler) {
  if (g_count == kMaxTags) {
    Log(L"%hs: no room for the card tag %hs", feature, name);
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll(feature, {&sites::kCardChildLoop, &sites::kCardChildLoopEnd, &sites::kCardCommitPrep,
                             &sites::kCardCommitCall}) ||
        !WriteCall(kCommitCall, reinterpret_cast<const void*>(&UhcCardCommitHook))) {
      return false;
    }
    g_installed = true;
  }
  g_tags[g_count++] = {name, handler};
  return true;
}

}  // namespace uhc
