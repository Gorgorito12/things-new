// fastVertexFill [log] [verify]: the cloth flags' vertices are built without reading the locked vertex buffer.
//
// The cloth flag draw 0x40D25B (flag manager [0xC67364], called by the world draw at 0x450684 and by 0x42922A at
// 0x429429) takes, per flag, a piece of the renderer's shared dynamic vertex buffer ([renderer+660h]: created at
// 0x5AE7D5 with usage DYNAMIC | WRITEONLY in the default pool, locked by 0x40A5B1 with NOOVERWRITE or DISCARD) and
// fills it with two copies of the flag's grid of 32-byte vertices: the front side, and the back side with the normal
// times -1.0. The stock loops write a front vertex from the simulated cloth and then build the back vertex from the
// front one they have just written: eight reads of the locked buffer per vertex. That memory is write-combined; a read
// from it is not cached and costs far more than the rest of the loop (99 % of the function's samples sit on those
// eight instructions).
//
// The key replaces the loops with a routine that reads only the source vertex and writes the same bytes
// (src/hooks/clothfill_hooks.asm). Display only: the routine writes vertex data and nothing else, takes no clock and
// no random number, and the bytes it writes are the stock ones, so players may set it differently.
//
// `verify` keeps the stock loops on the locked buffer and checks the routine against them: before the stock loops run
// it fills a buffer of the DLL from the same arguments, and before the Unlock it compares the two, byte for byte.
// `log` writes the session's counts to the log at exit.
#include <windows.h>

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcClothFillHook();
void UhcClothFillVerifyHook();
void UhcClothFillUnlockHook();
void __stdcall UhcClothFillRecords(void* front, void* back, const void* src, std::int32_t pitch, std::int32_t w,
                                   std::int32_t h, const float* uv, std::uint32_t oneSided);

// Counted by the hook, once per lock.
std::uint32_t g_uhcClothFills = 0;
std::uint32_t g_uhcClothVertices = 0;  // per side
}

namespace {

constexpr std::size_t kVertex = 32;
constexpr std::int32_t kMaxSide = 4096;           // far above any flag grid; a sanity limit for `verify`
constexpr std::size_t kGuard = 64;
constexpr std::uint8_t kUnwritten = 0xCD;
constexpr int kMaxMismatchLines = 10;
constexpr std::uint32_t kRenderer = 0x00C66044;   // renderer; +660h the dynamic vertex buffer's record {buffer, size, used}
constexpr DWORD kWindowMs = 10000;                // `verify` logs its counts this often

bool g_log = false;
bool g_verify = false;

// What UhcClothFillShadow filled and UhcClothFillCompare checks.
struct Pending {
  bool active = false;
  const std::uint8_t* front = nullptr;
  std::size_t backOffset = 0;
  std::size_t side = 0;  // bytes of one side
  bool both = false;
  std::int32_t w = 0;
  std::int32_t h = 0;
};
Pending g_pending;
std::vector<std::uint8_t>* g_shadow = nullptr;
std::uint64_t g_checkedFills = 0;
std::uint64_t g_checkedVertices = 0;
std::uint64_t g_mismatchedVertices = 0;
std::uint64_t g_overruns = 0;
std::uint64_t g_skipped = 0;
int g_mismatchLines = 0;
DWORD g_windowStart = 0;
std::uint32_t g_windowFills = 0;
std::uint64_t g_windowVertices = 0;

// Usage, pool and size of a vertex buffer, as Direct3D reports them (IDirect3DVertexBuffer9::GetDesc, slot 13).
struct BufferDesc {
  std::uint32_t format, type, usage, pool, size, fvf;
};

// `verify`, once: where the lock points and what the buffer is, for the log.
void LogBuffer(const std::uint8_t* front) {
  MEMORY_BASIC_INFORMATION info{};
  const bool queried = VirtualQuery(front, &info, sizeof(info)) != 0;
  BufferDesc desc{};
  long hr = -1;
  const char* renderer = *reinterpret_cast<const char* const*>(kRenderer);
  void** record = renderer == nullptr ? nullptr : *reinterpret_cast<void** const*>(renderer + 0x660);
  void* buffer = record == nullptr ? nullptr : record[0];
  if (buffer != nullptr) {
    using GetDescFn = long(__stdcall*)(void* self, BufferDesc* out);
    hr = (*reinterpret_cast<GetDescFn**>(buffer))[13](buffer, &desc);
  }
  uhc::Log(L"fastVertexFill verify: the lock points at 0x%08X: protection 0x%X (0x400 = write-combined), type 0x%X, "
           L"allocation base 0x%08X, region %u KB; the buffer (GetDesc hr 0x%08X): usage 0x%X (0x200 dynamic, 0x8 "
           L"write-only), pool %u, %u bytes",
           static_cast<unsigned>(reinterpret_cast<std::uintptr_t>(front)), queried ? info.Protect : 0u,
           queried ? info.Type : 0u,
           static_cast<unsigned>(reinterpret_cast<std::uintptr_t>(queried ? info.AllocationBase : nullptr)),
           queried ? static_cast<unsigned>(info.RegionSize / 1024) : 0u, static_cast<unsigned>(hr), desc.usage,
           desc.pool, desc.size);
}

void LogVertex(const wchar_t* which, std::size_t index, const std::uint8_t* stock, const std::uint8_t* ours) {
  std::uint32_t a[8];
  std::uint32_t b[8];
  std::memcpy(a, stock, sizeof(a));
  std::memcpy(b, ours, sizeof(b));
  uhc::Log(L"fastVertexFill verify: MISMATCH, %ls vertex %u: stock %08X %08X %08X %08X %08X %08X %08X %08X, "
           L"ours %08X %08X %08X %08X %08X %08X %08X %08X",
           which, static_cast<unsigned>(index), a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], b[0], b[1], b[2],
           b[3], b[4], b[5], b[6], b[7]);
}

// Compares `bytes` of the locked buffer with the shadow, vertex by vertex.
void CompareSide(const wchar_t* which, const std::uint8_t* stock, const std::uint8_t* ours, std::size_t bytes) {
  if (std::memcmp(stock, ours, bytes) == 0) {
    return;
  }
  for (std::size_t i = 0; i < bytes; i += kVertex) {
    if (std::memcmp(stock + i, ours + i, kVertex) != 0) {
      ++g_mismatchedVertices;
      if (g_mismatchLines < kMaxMismatchLines) {
        ++g_mismatchLines;
        LogVertex(which, i / kVertex, stock + i, ours + i);
      }
    }
  }
}

void AtExit() {
  if (g_verify) {
    uhc::Log(L"fastVertexFill verify: %llu fills checked against the stock loops (%llu vertices), %llu mismatches, "
             L"%llu writes outside the vertices, %llu fills skipped",
             g_checkedFills, g_checkedVertices, g_mismatchedVertices, g_overruns, g_skipped);
  } else if (g_log) {
    uhc::Log(L"fastVertexFill: %u fills, %u vertices per side", g_uhcClothFills, g_uhcClothVertices);
  }
}

}  // namespace

// `verify`, before the stock loops: runs the routine on a buffer of the DLL laid out as the lock is.
extern "C" void __stdcall UhcClothFillShadow(std::uint8_t* front, std::uint8_t* back, const void* src,
                                             std::int32_t pitch, std::int32_t w, std::int32_t h, const float* uv,
                                             std::uint32_t oneSided) {
  g_pending.active = false;
  if (w <= 0 || h <= 0 || w > kMaxSide || h > kMaxSide || back < front || src == nullptr) {
    ++g_skipped;
    return;
  }
  const std::size_t side = static_cast<std::size_t>(w) * static_cast<std::size_t>(h) * kVertex;
  const std::size_t backOffset = static_cast<std::size_t>(back - front);
  const bool both = oneSided == 0;
  if (both && backOffset < side) {  // the two sides would overlap: not what 0x40D506 computes
    ++g_skipped;
    return;
  }
  const std::size_t total = both ? backOffset + side : side;
  if (g_shadow == nullptr) {
    g_shadow = new std::vector<std::uint8_t>();
  }
  g_shadow->assign(total + kGuard, kUnwritten);
  UhcClothFillRecords(g_shadow->data(), g_shadow->data() + backOffset, src, pitch, w, h, uv, oneSided);
  g_pending = {true, front, backOffset, side, both, w, h};
}

// `verify`, before the Unlock: the stock loops have filled the locked buffer.
extern "C" void __stdcall UhcClothFillCompare() {
  if (!g_pending.active) {
    return;
  }
  g_pending.active = false;
  const std::uint8_t* ours = g_shadow->data();
  const std::uint64_t before = g_mismatchedVertices;
  CompareSide(L"front", g_pending.front, ours, g_pending.side);
  if (g_pending.both) {
    CompareSide(L"back", g_pending.front + g_pending.backOffset, ours + g_pending.backOffset, g_pending.side);
  }
  // Nothing but the vertices may have been written: the gap between the sides and the guard keep their fill.
  const std::size_t end = g_shadow->size();
  const std::size_t gapEnd = g_pending.both ? g_pending.backOffset : g_pending.side;
  const std::size_t tail = g_pending.both ? g_pending.backOffset + g_pending.side : g_pending.side;
  bool overrun = false;
  for (std::size_t i = g_pending.side; i < gapEnd && !overrun; ++i) {
    overrun = ours[i] != kUnwritten;
  }
  for (std::size_t i = tail; i < end && !overrun; ++i) {
    overrun = ours[i] != kUnwritten;
  }
  if (overrun) {
    ++g_overruns;
    if (g_mismatchLines < kMaxMismatchLines) {
      ++g_mismatchLines;
      uhc::Log(L"fastVertexFill verify: the routine wrote outside its vertices (%d x %d, %ls)", g_pending.w,
               g_pending.h, g_pending.both ? L"two sides" : L"one side");
    }
  }
  const std::uint64_t vertices =
      static_cast<std::uint64_t>(g_pending.w) * static_cast<std::uint64_t>(g_pending.h) * (g_pending.both ? 2 : 1);
  if (g_checkedFills == 0) {
    LogBuffer(g_pending.front);
    uhc::Log(L"fastVertexFill verify: first fill checked, %d x %d vertices, %ls: %llu mismatches", g_pending.w,
             g_pending.h, g_pending.both ? L"two sides" : L"one side", g_mismatchedVertices - before);
  }
  ++g_checkedFills;
  g_checkedVertices += vertices;
  const DWORD now = GetTickCount();
  if (g_windowStart == 0) {
    g_windowStart = now;
  }
  ++g_windowFills;
  g_windowVertices += vertices;
  if (now - g_windowStart >= kWindowMs) {
    uhc::Log(L"fastVertexFill verify: %u fills and %llu vertices in %.1f s; %llu mismatches so far", g_windowFills,
             g_windowVertices, (now - g_windowStart) / 1000.0, g_mismatchedVertices);
    g_windowStart = now;
    g_windowFills = 0;
    g_windowVertices = 0;
  }
}

namespace uhc {

Outcome ApplyFastVertexFill(const Config& config) {
  const auto* args = config.First("fastVertexFill");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "verify") == 0) {
      g_verify = true;
    } else {
      Log(L"fastVertexFill: unknown argument '%hs' (expected: [log] [verify]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("fastVertexFill", {&sites::kClothFillSetup, &sites::kClothFillLoop, &sites::kClothFillUnlock,
                                       &sites::kClothFillBackScale})) {
    return Outcome::kFailed;
  }
  if (g_verify) {
    // The compare goes in first, so the first shadow fill already has it.
    if (!WriteJmp(sites::kClothFillUnlock.va, reinterpret_cast<const void*>(&UhcClothFillUnlockHook), 6) ||
        !WriteJmp(sites::kClothFillLoop.va, reinterpret_cast<const void*>(&UhcClothFillVerifyHook), 8)) {
      return Outcome::kFailed;
    }
    Log(L"fastVertexFill: verify mode: the stock loops fill the cloth flags, and every fill is compared with the "
        L"routine's (display only)");
  } else {
    if (!WriteJmp(sites::kClothFillLoop.va, reinterpret_cast<const void*>(&UhcClothFillHook), 8)) {
      return Outcome::kFailed;
    }
    Log(L"fastVertexFill: the cloth flags' vertices are built without reading the locked vertex buffer%ls (display "
        L"only: same bytes)",
        g_log ? L", log" : L"");
  }
  if (g_log || g_verify) {
    std::atexit(AtExit);
  }
  return Outcome::kApplied;
}

}  // namespace uhc
