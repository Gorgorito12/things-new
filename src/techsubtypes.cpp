#include "techsubtypes.h"

#include <cstddef>
#include <cstring>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" {
void UhcTechSubtypeApplyHook();    // hooks/techsubtype_hooks.asm
void UhcTechSubtypeUnapplyHook();
}

namespace {

constexpr std::size_t kMaxSubtypes = 16;
constexpr std::int32_t kFirstId = 0x100;  // above every stock subtype; the stock switches stop at 63h
constexpr std::uint32_t kNameLookupCall = 0x006206D7;  // setData's call of the lookup 0x61FF5D
constexpr std::uint32_t kApplySwitch = 0x008F978D;     // cmp eax,63h / ja (9 B)
constexpr std::uint32_t kUnapplySwitch = 0x008FB051;   // cmp eax,5Eh / ja (9 B)

using NameLookupFn = std::int32_t(__thiscall*)(void* db, const char* name);
const auto kNameLookup = reinterpret_cast<NameLookupFn>(0x0061FF5D);

struct Subtype {
  const char* name;
  uhc::TechSubtypeHandler handler;
};

Subtype g_subtypes[kMaxSubtypes] = {};
std::size_t g_count = 0;
bool g_installed = false;

// Replaces the call of the lookup in BDataEffect::setData.
std::int32_t __fastcall NameLookup(void* db, void*, const char* name) {
  const std::int32_t stock = kNameLookup(db, name);
  if (stock != -1 || name == nullptr) {
    return stock;
  }
  for (std::size_t i = 0; i < g_count; ++i) {
    if (_stricmp(name, g_subtypes[i].name) == 0) {
      return kFirstId + static_cast<std::int32_t>(i);
    }
  }
  return -1;
}

}  // namespace

// From the two switch hooks, for a subtype at or above kFirstId. False: stock's failure exit.
extern "C" bool __stdcall UhcTechSubtypeRun(std::int32_t id, char* proto, const char* base, float amount,
                                            std::uint32_t relativity, std::uint32_t unapply) {
  const std::size_t index = static_cast<std::size_t>(id - kFirstId);
  if (index >= g_count) {
    return false;
  }
  g_subtypes[index].handler(proto, base, amount, static_cast<std::uint8_t>(relativity), unapply != 0);
  return true;
}

namespace uhc {

bool AddTechSubtype(const char* name, TechSubtypeHandler handler) {
  if (g_count == kMaxSubtypes) {
    Log(L"tech subtypes: no room for %hs", name);
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll("tech subtypes",
                   {&sites::kDataSubtypeLookupCall, &sites::kDataApplySwitch, &sites::kDataUnapplySwitch}) ||
        !WriteCall(kNameLookupCall, reinterpret_cast<const void*>(&NameLookup)) ||
        !WriteJmp(kApplySwitch, reinterpret_cast<const void*>(&UhcTechSubtypeApplyHook), 9) ||
        !WriteJmp(kUnapplySwitch, reinterpret_cast<const void*>(&UhcTechSubtypeUnapplyHook), 9)) {
      return false;
    }
    g_installed = true;
  }
  g_subtypes[g_count++] = {name, handler};
  return true;
}

}  // namespace uhc
