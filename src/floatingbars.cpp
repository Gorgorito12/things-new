#include "floatingbars.h"

#include <cstddef>
#include <cstdint>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" {
void UhcFloatingBarQueuedHook();  // hooks/floatingbars_hooks.asm
void UhcFloatingBarFitHook();
void UhcFloatingBarVertexHook();
}

namespace {

constexpr std::size_t kMaxObservers = 4;
constexpr std::size_t kMaxKinds = 4;
constexpr std::uint32_t kGameGlobal = 0x00C66234;    // game; +13Ch world
constexpr std::uint32_t kDeviceGlobal = 0x00C66044;  // render device; +660h its dynamic vertex buffer
constexpr std::uint32_t kVertexBytesPerBar = 6 * sizeof(uhc::FloatingBarVertex);

// FUN_0045FB71: queues a floating HP bar, thiscall(world, pos*, scale, fill, player, colour byte), ret 14h.
using QueueBarFn = bool(__fastcall*)(const char* world, void* unused, const float* pos, float scale, float fill,
                                     std::int32_t player, std::uint32_t colourByte);
const auto kQueueBar = reinterpret_cast<QueueBarFn>(0x0045FB71);

struct Kind {
  std::uint32_t prefix;
  uhc::FloatingBarVertices writer;
};

uhc::FloatingBarQueued g_observers[kMaxObservers] = {};
std::size_t g_observerCount = 0;
Kind g_kinds[kMaxKinds] = {};
std::size_t g_kindCount = 0;
bool g_queueInstalled = false;
bool g_renderInstalled = false;
bool g_loggedDrop = false;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

bool Added(std::int32_t player) { return player < 0; }

}  // namespace

extern "C" {

// From the queue hook (0x45FB6C).
void __stdcall UhcFloatingBarQueued(const char* unit, const float* position, std::int32_t constructing,
                                    std::int32_t altHeld) {
  for (std::size_t i = 0; i < g_observerCount; ++i) {
    g_observers[i](unit, position, constructing != 0, altHeld != 0);
  }
}

// From the renderer hook (0x45C4B9), before the vertex lock: drops the added bars when the queue's six vertices per
// bar would not fit in the dynamic vertex buffer ([vb+4] bytes).
void __stdcall UhcFloatingBarFit(char* world) {
  const std::int32_t count = Field<std::int32_t>(world, 0x8D4);
  const char* device = *reinterpret_cast<const char* const*>(kDeviceGlobal);
  const char* buffer = device == nullptr ? nullptr : Field<const char*>(device, 0x660);
  if (count <= 0 || buffer == nullptr ||
      static_cast<std::uint64_t>(count) * kVertexBytesPerBar <= Field<std::uint32_t>(buffer, 4)) {
    return;
  }
  auto* records = Field<uhc::FloatingBarRecord*>(world, 0x8D0);
  std::int32_t kept = 0;
  for (std::int32_t i = 0; i < count; ++i) {
    if (!Added(records[i].player)) {
      records[kept++] = records[i];
    }
  }
  *reinterpret_cast<std::int32_t*>(world + 0x8D4) = kept;
  if (!g_loggedDrop && kept != count) {
    g_loggedDrop = true;
    uhc::Log(L"floating bars: %d bars do not fit in the vertex buffer (%u bytes): this frame's %d added bars were "
             L"dropped (logged once)",
             count, Field<std::uint32_t>(buffer, 4), count - kept);
  }
}

// From the renderer loop hook (0x45CB72), for a record with a negative player: its six vertices go to its kind.
void __stdcall UhcFloatingBarVertices(const char* world, std::int32_t offset, uhc::FloatingBarVertex* vertices,
                                      const char* camera) {
  const auto* record = reinterpret_cast<const uhc::FloatingBarRecord*>(Field<const char*>(world, 0x8D0) + offset);
  const std::uint32_t prefix = static_cast<std::uint32_t>(record->player) & 0xFFFFFF00u;
  for (std::size_t i = 0; i < g_kindCount; ++i) {
    if (g_kinds[i].prefix == prefix) {
      g_kinds[i].writer(*record, vertices, camera);
      return;
    }
  }
}

}  // extern "C"

namespace uhc {

bool AddFloatingBarQueued(FloatingBarQueued observer, const char* feature) {
  if (g_observerCount == kMaxObservers) {
    Log(L"%hs: more than %u floating bar observers", feature, static_cast<unsigned>(kMaxObservers));
    return false;
  }
  if (!g_queueInstalled) {
    // jmp 4516B3h (5 B) at 0x45FB6C, right after the call of the queue.
    if (!VerifyAll(feature, {&sites::kOverhealSegmentQueue, &sites::kHpBarQueue, &sites::kFloatingBarAlt,
                             &sites::kFloatingBarAltGate}) ||
        !WriteJmp(0x0045FB6C, reinterpret_cast<const void*>(&UhcFloatingBarQueuedHook), 5)) {
      return false;
    }
    g_queueInstalled = true;
  }
  g_observers[g_observerCount++] = observer;
  return true;
}

bool AddFloatingBarKind(std::uint32_t kind, FloatingBarVertices writer, const char* feature) {
  if (g_kindCount == kMaxKinds || (kind & 0x80000000u) == 0) {
    Log(L"%hs: floating bar kind %08X refused (more than %u kinds, or not negative)", feature, kind,
        static_cast<unsigned>(kMaxKinds));
    return false;
  }
  if (!g_renderInstalled) {
    // mov ebx,[ebp+8D4h] (6 B) at 0x45C4B9, the renderer's record count; add eax,1 / add ecx,1Ch (6 B) at 0x45CB72,
    // the end of its per-record loop.
    if (!VerifyAll(feature, {&sites::kHpBarRenderStart, &sites::kHpBarRenderLoop, &sites::kDynamicVbLock,
                             &sites::kDynamicVbFull}) ||
        !WriteJmp(0x0045C4B9, reinterpret_cast<const void*>(&UhcFloatingBarFitHook), 6) ||
        !WriteJmp(0x0045CB72, reinterpret_cast<const void*>(&UhcFloatingBarVertexHook), 6)) {
      return false;
    }
    g_renderInstalled = true;
  }
  g_kinds[g_kindCount++] = Kind{kind & 0xFFFFFF00u, writer};
  return true;
}

void QueueFloatingBar(const float* position, float fill, std::uint32_t player) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr) {
    return;
  }
  kQueueBar(world, nullptr, position, 1.0f, fill, static_cast<std::int32_t>(player), 0xFF);
}

}  // namespace uhc
