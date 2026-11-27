// impactBoneFix [all] [log]: an impact effect that is a visual (an impacteffect particleSet naming an .xml, as
// cannon.impacteffect's <wood> does) is attached to the dummy bone of the impact point it hit (FUN_004CA908 from
// the impact spawn FUN_0049C1E5), and the visual's attachment update takes the bone's frame from the model
// (FUN_00407272) with its scale. A model exported with its bones scaled by 100 (centimetres, as some mods'
// buildings are) gives the attached effect axes of length 100, and its splinters cover the screen. Particle set
// impacts (<stone>) are placed at the hit point and never read the bone, so only the visual ones break.
//
// The key scales the three axes the getter returns to unit length for the impact dummies (the type the damage
// templates use, [[0D6F678h]]); with "all", for every dummy a visual is attached to. The position is kept.
#include <cmath>
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcImpactBoneFrame1();
extern "C" void UhcImpactBoneFrame2();

namespace {

bool g_allDummies = false;
bool g_log = false;
bool g_loggedScale = false;

constexpr float kTolerance = 0.01f;  // a bone this close to unit length is left as it is

std::int32_t ImpactDummyType() {
  const auto* holder = *reinterpret_cast<const std::int32_t* const*>(0x00D6F678);
  return holder == nullptr ? -1 : *holder;
}

}  // namespace

// Called after a successful FUN_00407272 in the dummy attachment update. frame is ESP after the call; the axes
// are at frame+firstAxis, frame+30h and frame+40h, three floats each.
extern "C" void __stdcall UhcFixDummyAxes(std::int32_t dummyType, char* frame, std::int32_t firstAxis) {
  if (!g_allDummies && dummyType != ImpactDummyType()) {
    return;
  }
  float* axes[3] = {reinterpret_cast<float*>(frame + firstAxis), reinterpret_cast<float*>(frame + 0x30),
                    reinterpret_cast<float*>(frame + 0x40)};
  for (float* axis : axes) {
    const float length = std::sqrt(axis[0] * axis[0] + axis[1] * axis[1] + axis[2] * axis[2]);
    if (!(length > 1e-6f) || std::fabs(length - 1.0f) <= kTolerance) {
      continue;
    }
    if (g_log && !g_loggedScale) {
      g_loggedScale = true;
      uhc::Log(L"impactBoneFix: a dummy bone of type %d had an axis of length %.3f; scaled to 1", dummyType,
               static_cast<double>(length));
    }
    axis[0] /= length;
    axis[1] /= length;
    axis[2] /= length;
  }
}

namespace uhc {

Outcome ApplyImpactBoneFix(const Config& config) {
  const Config::Args* args = config.First("impactBoneFix");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "all") == 0) {
      g_allDummies = true;
    } else if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else {
      Log(L"impactBoneFix: unknown argument '%hs' (expected all, log); not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("impactBoneFix", {&sites::kImpactBoneFrame1, &sites::kImpactBoneFrame2, &sites::kBoneFrameGetter})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kImpactBoneFrame1.va, reinterpret_cast<const void*>(&UhcImpactBoneFrame1), 5) ||
      !WriteJmp(sites::kImpactBoneFrame2.va, reinterpret_cast<const void*>(&UhcImpactBoneFrame2), 5)) {
    return Outcome::kFailed;
  }
  Log(L"impactBoneFix: effects attached to %ls bones get unit-length axes", g_allDummies ? L"any dummy" : L"impact");
  return Outcome::kApplied;
}

}  // namespace uhc
