// A patch site in the stock age3y.exe: its address and the bytes expected there.
#pragma once

#include <cstddef>
#include <cstdint>

namespace uhc {

struct Site {
  const char* name;
  std::uint32_t va;
  const std::uint8_t* bytes;
  std::size_t size;
};

}  // namespace uhc
