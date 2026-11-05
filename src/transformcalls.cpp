#include "transformcalls.h"

#include <cstddef>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

namespace {

constexpr std::size_t kMaxObservers = 4;
constexpr std::uint32_t kEffectCall = 0x007FBC79;  // the TransformUnit effect's apply
constexpr std::uint32_t kOtherCalls[] = {0x007FBEF2, 0x008C2D08, 0x008EB78A, 0x008F05F5, 0x009BB6D5, 0x009C7C16};

using TransformFn = std::int32_t(__thiscall*)(char* unit, std::int32_t proto);
const auto kTransform = reinterpret_cast<TransformFn>(0x009C754C);

uhc::TransformObserver g_observers[kMaxObservers] = {};
std::size_t g_count = 0;
uhc::TransformEffectWrapper g_effectWrapper = nullptr;
bool g_installed = false;

std::int32_t __fastcall OtherCall(char* unit, void*, std::int32_t proto) { return uhc::TransformUnit(unit, proto); }

std::int32_t __fastcall EffectCall(char* unit, void*, std::int32_t proto) {
  if (g_effectWrapper == nullptr) {
    return uhc::TransformUnit(unit, proto);
  }
  g_effectWrapper(unit, proto);
  return 0;
}

bool Install() {
  if (g_installed) {
    return true;
  }
  if (!uhc::VerifyAll("transform calls", {&uhc::sites::kTransformCall1, &uhc::sites::kTransformCall2,
                                          &uhc::sites::kTransformCall3, &uhc::sites::kTransformCall4,
                                          &uhc::sites::kTransformCall5, &uhc::sites::kTransformCall6,
                                          &uhc::sites::kTransformCall7}) ||
      !uhc::WriteCall(kEffectCall, reinterpret_cast<const void*>(&EffectCall))) {
    return false;
  }
  for (const std::uint32_t call : kOtherCalls) {
    if (!uhc::WriteCall(call, reinterpret_cast<const void*>(&OtherCall))) {
      return false;
    }
  }
  g_installed = true;
  return true;
}

}  // namespace

namespace uhc {

bool AddTransformObserver(const TransformObserver& observer) {
  if (g_count == kMaxObservers) {
    Log(L"transform calls: no room for another observer");
    return false;
  }
  if (!Install()) {
    return false;
  }
  g_observers[g_count++] = observer;
  return true;
}

bool SetTransformEffectWrapper(TransformEffectWrapper wrapper) {
  if (g_effectWrapper != nullptr) {
    Log(L"transform calls: the effect's call is taken");
    return false;
  }
  if (!Install()) {
    return false;
  }
  g_effectWrapper = wrapper;
  return true;
}

std::int32_t TransformUnit(char* unit, std::int32_t proto) {
  float saved[kMaxObservers] = {};
  for (std::size_t i = 0; i < g_count; ++i) {
    saved[i] = g_observers[i].before(unit);
  }
  const std::int32_t result = kTransform(unit, proto);
  for (std::size_t i = 0; i < g_count; ++i) {
    g_observers[i].after(unit, saved[i]);
  }
  return result;
}

}  // namespace uhc
