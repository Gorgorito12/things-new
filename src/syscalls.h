// Extra XS syscalls. The game builds eight syscall modules (AI, HC, KB, RM, TR, UI, UI2, XS),
// each in one function that registers its stock syscalls; a hook on the first registration of
// each module adds the syscalls registered here, with the engine's own register functions
// (0x624F52, the parameter setters, the comment and 0x6250B0). Plugins (.upl files, see
// features/plugins.cpp) and features both register through AddSyscall.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace uhc {

enum class SyscallGroup : std::uint32_t { kAi = 0, kHc, kKb, kRm, kTr, kUi, kUi2, kXs, kCount };

// XS value types, as the engine encodes them.
enum SyscallType : std::uint32_t {
  kSyscallVoid = 1,
  kSyscallInt = 2,
  kSyscallFloat = 4,
  kSyscallBool = 8,
  kSyscallString = 16,
  kSyscallVector = 32,
};

struct SyscallParam {
  std::uint32_t type = 0;
  std::int32_t intValue = 0;  // int and bool defaults
  float floatValue = 0;
  float vectorValue[3] = {};
  std::string stringValue;
};

// One syscall to add. `fn` is a cdecl function taking the XS arguments in order (a vector
// result comes through a hidden first argument).
struct SyscallDef {
  SyscallGroup group = SyscallGroup::kXs;
  std::uint32_t retType = kSyscallVoid;
  std::string name;
  const void* fn = nullptr;
  std::string comment;
  std::vector<SyscallParam> params;
  std::string source;  // who added it, for the log
};

bool IsSyscallType(std::uint32_t type, bool allowVoid);

// Queues a syscall; returns a stable pointer (it never moves), so its parameters can be filled
// later. The group hooks must be installed (InstallSyscallHooks) for it to reach the game.
SyscallDef* AddSyscall(SyscallDef def);

// Verifies and installs the eight group hooks, once. `feature` names the caller in the log.
bool InstallSyscallHooks(const char* feature);

std::size_t SyscallCount();

}  // namespace uhc
