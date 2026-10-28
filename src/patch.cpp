#include "patch.h"

#include <windows.h>

#include <cstring>

#include "log.h"

namespace uhc {
namespace {

void* Ptr(std::uint32_t va) { return reinterpret_cast<void*>(static_cast<std::uintptr_t>(va)); }

}  // namespace

bool Matches(const Site& site) { return std::memcmp(Ptr(site.va), site.bytes, site.size) == 0; }

bool VerifyAll(const char* feature, std::initializer_list<const Site*> sites) {
  for (const Site* site : sites) {
    if (!Matches(*site)) {
      Log(L"%hs: site %hs at 0x%08X does not hold the stock bytes; feature not applied", feature,
          site->name, site->va);
      return false;
    }
  }
  return true;
}

bool WriteBytes(std::uint32_t va, const void* data, std::size_t size) {
  DWORD old = 0;
  if (!VirtualProtect(Ptr(va), size, PAGE_EXECUTE_READWRITE, &old)) {
    Log(L"VirtualProtect failed at 0x%08X (error %lu)", va, GetLastError());
    return false;
  }
  std::memcpy(Ptr(va), data, size);
  VirtualProtect(Ptr(va), size, old, &old);
  FlushInstructionCache(GetCurrentProcess(), Ptr(va), size);
  return true;
}

bool WriteDword(std::uint32_t va, std::uint32_t value) { return WriteBytes(va, &value, sizeof(value)); }

bool WriteJmp(std::uint32_t va, std::uint32_t target, std::size_t length) {
  if (length < 5 || length > 64) {
    return false;
  }
  std::uint8_t code[64];
  std::memset(code, 0x90, length);
  code[0] = 0xE9;
  const std::uint32_t rel = target - (va + 5);
  std::memcpy(code + 1, &rel, sizeof(rel));
  return WriteBytes(va, code, length);
}

bool WriteJmp(std::uint32_t va, const void* target, std::size_t length) {
  return WriteJmp(va, static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(target)), length);
}

}  // namespace uhc
