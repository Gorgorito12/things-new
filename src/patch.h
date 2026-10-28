// In-process patching of the game image. Every write is preceded by a check that the bytes at
// each site are the stock bytes (src/generated/sites.h), so a wrong build is never patched.
#pragma once

#include <cstddef>
#include <cstdint>
#include <initializer_list>

#include "site.h"

namespace uhc {

// True if live memory at the site equals its expected stock bytes.
bool Matches(const Site& site);

// Checks every site; logs and returns false on the first mismatch.
bool VerifyAll(const char* feature, std::initializer_list<const Site*> sites);

bool WriteBytes(std::uint32_t va, const void* data, std::size_t size);
bool WriteDword(std::uint32_t va, std::uint32_t value);
// Writes `jmp rel32` to target at va and NOP-fills the rest of `length` (>= 5) bytes.
bool WriteJmp(std::uint32_t va, const void* target, std::size_t length);
bool WriteJmp(std::uint32_t va, std::uint32_t target, std::size_t length);

}  // namespace uhc
