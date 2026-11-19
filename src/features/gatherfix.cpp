// gatherFix: gatherers collect on a fixed time interval instead of once per animation loop.
//
// Stock: the gather action's update (BUnitGatherAction, the code ending at 0x4EC8FE) adds the
// elapsed time [world+104h] to [action+88h]; doAnimationLooped (0x4ECC88), run each time the
// gather animation loops, adds it again and collects an amount for the animation's length
// (0x4939BD on the unit's visual), through collectStuff 0x9DD7B4 or collectStuff_2 0x4ECD87,
// then clears [action+88h]. So what a gatherer collects follows its animation: an animation that
// loops late, or that is replaced, changes the rate.
//
// With the key the update collects instead: when [action+88h] passes the interval
// [protoAction+78h] (0.5 s if it is not set), it collects that interval through the same two
// functions (chosen as stock does, by bit 22 of the action's flags [+30h]/[+34h]) and clears the
// time; doAnimationLooped no longer collects (jmp over its block at 0x4ECC8E).
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcGatherTimeHook();

namespace {

using Collect = void(__thiscall*)(void* action, float amount);
const auto kCollect = reinterpret_cast<Collect>(0x009DD7B4);
const auto kCollect2 = reinterpret_cast<Collect>(0x004ECD87);
bool g_logged = false;

}  // namespace

extern "C" void __stdcall UhcGatherTick(char* action) {
  const char* game = *reinterpret_cast<char* const*>(0x00C66234);
  const char* world = game == nullptr ? nullptr : *reinterpret_cast<char* const*>(game + 0x13C);
  if (world == nullptr || action == nullptr) {
    return;
  }
  float& time = *reinterpret_cast<float*>(action + 0x88);
  time += *reinterpret_cast<const float*>(world + 0x104);
  const char* protoAction = *reinterpret_cast<char* const*>(action + 4);
  float interval = protoAction == nullptr ? 0.0f : *reinterpret_cast<const float*>(protoAction + 0x78);
  if (!(interval >= 1e-5f)) {
    interval = 0.5f;
  }
  if (!(time > interval)) {
    return;
  }
  const std::uint8_t* flags = *reinterpret_cast<const std::uint8_t* const*>(action + 0x30);
  const std::uint32_t bits = *reinterpret_cast<const std::uint32_t*>(action + 0x34);
  const bool first = flags != nullptr && bits > 0x16 && (flags[2] & 0x40) != 0;
  if (!g_logged) {
    g_logged = true;
    uhc::Log(L"gatherFix: first collection: interval %.3f s (protoAction+78h %.3f), %ls", static_cast<double>(interval),
             protoAction == nullptr ? 0.0 : static_cast<double>(*reinterpret_cast<const float*>(protoAction + 0x78)),
             first ? L"collectStuff" : L"collectStuff_2");
  }
  if (first) {
    kCollect(action, interval);
  } else {
    kCollect2(action, interval);
  }
  time = 0.0f;
}

namespace uhc {

Outcome ApplyGatherFix(const Config& config) {
  if (config.First("gatherFix") == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("gatherFix", {&sites::kGatherTimeAdd, &sites::kGatherAnimLoopCollect, &sites::kGatherCollect,
                              &sites::kGatherCollect2})) {
    return Outcome::kFailed;
  }
  // The block first (a 5-byte jmp over it), so a failure cannot leave the tick collecting on top
  // of the animation loop.
  if (!WriteJmp(sites::kGatherAnimLoopCollect.va, sites::kGatherAnimLoopCollect.va + sites::kGatherAnimLoopCollect.size,
                5) ||
      !WriteJmp(sites::kGatherTimeAdd.va, reinterpret_cast<const void*>(&UhcGatherTimeHook), sites::kGatherTimeAdd.size)) {
    return Outcome::kFailed;
  }
  Log(L"gatherFix: gatherers collect on a fixed interval, not per animation loop");
  return Outcome::kApplied;
}

}  // namespace uhc
