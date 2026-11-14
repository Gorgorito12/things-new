#include "syscalls.h"

#include <deque>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

namespace {

// A deque never moves its elements: callers keep SyscallDef pointers, and the engine may keep
// the name and comment pointers.
std::deque<uhc::SyscallDef> g_syscalls;
bool g_hooked = false;
bool g_logged[static_cast<int>(uhc::SyscallGroup::kCount)] = {};

const char* const kGroupNames[] = {"AI", "HC", "KB", "RM", "TR", "UI", "UI2", "XS"};

}  // namespace

extern "C" {
void UhcSyscallAiHook();
void UhcSyscallHcHook();
void UhcSyscallKbHook();
void UhcSyscallRmHook();
void UhcSyscallTrHook();
void UhcSyscallUiHook();
void UhcSyscallUi2Hook();
void UhcSyscallXsHook();

// Called by each group hook (hooks/syscall_hooks.asm) with the module being built, before its
// first stock syscall. Registration follows the engine's own sequence: register (0x624F52),
// one setter per parameter, the comment (0x624E56), end (0x6250B0). A syscall the engine
// refuses (a name it already has, a bad type) is logged and skipped; the others still register.
void __stdcall UhcRegisterSyscallGroup(std::uint32_t group, void* module) {
  using Register = bool(__thiscall*)(void*, const char* name, const void* fn, std::uint32_t retType);
  using SetInt = bool(__thiscall*)(void*, std::int32_t);
  using SetFloat = bool(__thiscall*)(void*, float);
  using SetString = bool(__thiscall*)(void*, const char*);
  using SetVector = bool(__thiscall*)(void*, const float*);
  using End = bool(__thiscall*)(void*);
  using Free = void(__thiscall*)(void*);
  const auto registerSyscall = reinterpret_cast<Register>(0x00624F52);
  const auto setInt = reinterpret_cast<SetInt>(0x0062505B);
  const auto setFloat = reinterpret_cast<SetFloat>(0x00625079);
  const auto setBool = reinterpret_cast<SetInt>(0x0062506A);
  const auto setString = reinterpret_cast<SetString>(0x00624E3F);
  const auto setVector = reinterpret_cast<SetVector>(0x0062734A);
  const auto comment = reinterpret_cast<SetString>(0x00624E56);
  const auto end = reinterpret_cast<End>(0x006250B0);
  const auto discard = reinterpret_cast<Free>(0x00A44C0B);

  if (module == nullptr || group >= static_cast<std::uint32_t>(uhc::SyscallGroup::kCount)) {
    return;
  }
  int added = 0;
  int failed = 0;
  for (const uhc::SyscallDef& def : g_syscalls) {
    if (static_cast<std::uint32_t>(def.group) != group) {
      continue;
    }
    if (!registerSyscall(module, def.name.c_str(), def.fn, def.retType)) {
      // Nothing is pending after a refused registration (0x624F52 creates the entry last).
      ++failed;
      if (!g_logged[group]) {
        uhc::Log(L"syscalls: %hs refused %hs (%hs): a name it already has, or a bad return type",
                 kGroupNames[group], def.name.c_str(), def.source.c_str());
      }
      continue;
    }
    bool ok = true;
    for (const uhc::SyscallParam& p : def.params) {
      switch (p.type) {
        case uhc::kSyscallInt:
          ok = setInt(module, p.intValue);
          break;
        case uhc::kSyscallFloat:
          ok = setFloat(module, p.floatValue);
          break;
        case uhc::kSyscallBool:
          ok = setBool(module, p.intValue != 0 ? 1 : 0);
          break;
        case uhc::kSyscallString:
          ok = setString(module, p.stringValue.c_str());
          break;
        case uhc::kSyscallVector:
          ok = setVector(module, p.vectorValue);
          break;
        default:
          ok = false;
      }
      if (!ok) {
        break;
      }
    }
    ok = ok && comment(module, def.comment.empty() ? def.name.c_str() : def.comment.c_str()) && end(module);
    if (!ok) {
      discard(module);  // drops the pending entry, as the stock error paths do
      ++failed;
      if (!g_logged[group]) {
        uhc::Log(L"syscalls: %hs: %hs (%hs) failed while adding its parameters; skipped", kGroupNames[group],
                 def.name.c_str(), def.source.c_str());
      }
      continue;
    }
    ++added;
  }
  if (!g_logged[group] && added + failed > 0) {
    g_logged[group] = true;
    uhc::Log(L"syscalls: group %hs: %d added, %d refused", kGroupNames[group], added, failed);
  }
}
}

namespace uhc {

bool IsSyscallType(std::uint32_t type, bool allowVoid) {
  switch (type) {
    case kSyscallVoid:
      return allowVoid;
    case kSyscallInt:
    case kSyscallFloat:
    case kSyscallBool:
    case kSyscallString:
    case kSyscallVector:
      return true;
    default:
      return false;
  }
}

SyscallDef* AddSyscall(SyscallDef def) {
  g_syscalls.push_back(std::move(def));
  return &g_syscalls.back();
}

std::size_t SyscallCount() { return g_syscalls.size(); }

bool InstallSyscallHooks(const char* feature) {
  if (g_hooked) {
    return true;
  }
  if (!VerifyAll(feature, {&sites::kSyscallAi, &sites::kSyscallHc, &sites::kSyscallKb, &sites::kSyscallRm,
                           &sites::kSyscallTr, &sites::kSyscallUi, &sites::kSyscallUi2, &sites::kSyscallXs})) {
    return false;
  }
  const struct {
    const Site* site;
    void (*hook)();
  } hooks[] = {
      {&sites::kSyscallAi, &UhcSyscallAiHook},   {&sites::kSyscallHc, &UhcSyscallHcHook},
      {&sites::kSyscallKb, &UhcSyscallKbHook},   {&sites::kSyscallRm, &UhcSyscallRmHook},
      {&sites::kSyscallTr, &UhcSyscallTrHook},   {&sites::kSyscallUi, &UhcSyscallUiHook},
      {&sites::kSyscallUi2, &UhcSyscallUi2Hook}, {&sites::kSyscallXs, &UhcSyscallXsHook},
  };
  for (const auto& h : hooks) {
    if (!WriteJmp(h.site->va, reinterpret_cast<const void*>(h.hook), h.site->size)) {
      return false;
    }
  }
  g_hooked = true;
  return true;
}

}  // namespace uhc
