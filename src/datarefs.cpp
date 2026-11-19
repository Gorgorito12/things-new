#include "datarefs.h"

#include <cstddef>
#include <cstdint>
#include <cwchar>
#include <string>
#include <vector>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

namespace {

struct BString {
  wchar_t* text;
};

// The table at [parser+0Ch]: {entries, count, capacity}; an entry is {id, type, BString name, provider}.
struct Entry {
  std::int32_t id;
  std::int32_t type;
  BString name;
  void* provider;
};
struct Table {
  Entry* entries;
  std::int32_t count;
  std::int32_t capacity;
};

using RegisterFn = bool(__thiscall*)(char* parser);
using GrowFn = bool(__thiscall*)(Table* table, std::int32_t count, bool keep);
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringSetFn = void(__thiscall*)(BString* self, const BString* source);
using BStringFreeFn = void(__thiscall*)(BString* self);
const auto kRegister = reinterpret_cast<RegisterFn>(0x005CFA7C);
const auto kGrow = reinterpret_cast<GrowFn>(0x005ACE63);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringSet = reinterpret_cast<BStringSetFn>(0x0040196F);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);

struct Added {
  std::wstring name;
  std::int32_t type;
  uhc::DataRefProvider provider;
};
std::vector<Added> g_added;
bool g_installed = false;
bool g_registered = false;  // the game's table was built: later additions would not be seen

}  // namespace

extern "C" void UhcDataRefRegisterHook();  // hooks/datarefs_hooks.asm

// From the hook that replaces the parser constructor's call of the registration (0x5D3229, ECX = the parser); the
// constructor ignores the result (mov eax,esi follows).
extern "C" bool __stdcall UhcRegisterDataRefs(char* parser) {
  const bool stock = kRegister(parser);
  g_registered = true;
  auto* table = reinterpret_cast<Table*>(parser + 0x0C);
  int added = 0;
  for (const Added& ref : g_added) {
    const std::int32_t id = table->count;
    if (!kGrow(table, id + 1, false) || table->count != id + 1) {
      uhc::Log(L"data refs: cannot add {%ls}", ref.name.c_str());
      break;
    }
    Entry& entry = table->entries[id];
    BString name{nullptr};
    kBStringFromWide(&name, ref.name.c_str());
    entry.id = id;
    entry.type = ref.type;
    kBStringSet(&entry.name, &name);
    entry.provider = reinterpret_cast<void*>(ref.provider);
    kBStringFree(&name);
    ++added;
  }
  uhc::Log(L"data refs: %d added after the game's %d", added, table->count - added);
  return stock;
}

namespace uhc {

bool AddDataRef(const wchar_t* name, std::int32_t type, DataRefProvider provider) {
  if (g_registered) {
    Log(L"data refs: {%ls} comes after the game built its table", name);
    return false;
  }
  for (const Added& ref : g_added) {
    if (_wcsicmp(ref.name.c_str(), name) == 0) {
      Log(L"data refs: {%ls} is already added", name);
      return false;
    }
  }
  if (!g_installed) {
    if (!VerifyAll("data refs", {&sites::kDataRefParserCtor, &sites::kDataRefRegister, &sites::kDataRefArrayGrow,
                                 &sites::kDataRefFloatEval, &sites::kBStringFromWide, &sites::kBStringSet,
                                 &sites::kBStringFree}) ||
        !WriteCall(sites::kDataRefParserCtor.va + 0x20, reinterpret_cast<const void*>(&UhcDataRefRegisterHook))) {
      return false;
    }
    g_installed = true;
  }
  g_added.push_back({name, type, provider});
  return true;
}

}  // namespace uhc
