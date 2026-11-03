// enableFarmAnim Proto ... / enableRectFarmAnim Proto ... / farmingRadius Index X Z ...:
// listed buildings work like a Mill (enableFarmAnim) or a Rice Paddy (enableRectFarmAnim) for the
// gather code that compares a target's proto with the cached Mill ([db+5E58h]) and Rice Paddy
// ([db+607Ch]) IDs: gatherer placement, the gather action and its animation. farmingRadius sets,
// per enableFarmAnim entry (1-based), the area its gatherers spread over (stock 4.5 x 4.5).
// Each hook takes the branch stock takes for a Mill or a Rice Paddy, with the registers that
// branch has; hooks/farm_hooks.asm. Names resolve lazily (namelists.h).
#include <cstdint>
#include <cstdlib>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../namelists.h"
#include "../patch.h"

namespace {

uhc::ProtoIdList g_farms;
uhc::ProtoIdList g_rectFarms;
struct Radius {
  float x = 0;
  float z = 0;
  bool set = false;
};
std::vector<Radius> g_radius;  // per enableFarmAnim entry
bool g_farmHooks = false;

}  // namespace

extern "C" {
std::int32_t g_uhcFarmKind = 0;  // the last answer of UhcFarmKind, read by the hooks

void UhcFarm1Hook();
void UhcFarm2Hook();
void UhcFarm3Hook();
void UhcFarm4Hook();
void UhcFarm5Hook();
void UhcFarm6Hook();
void UhcFarm7Hook();
void UhcFarm8Hook();
void UhcRectFarm1Hook();
void UhcRectFarm2Hook();
void UhcRectFarm3Hook();
void UhcRectFarm4Hook();
void UhcFarmRadiusHook();

// 1 = a listed farm (Mill-like), 2 = a listed rect farm (Rice Paddy-like), 0 = neither. Also
// stored in g_uhcFarmKind for hooks that call it inside pushad.
std::int32_t __stdcall UhcFarmKind(std::int32_t proto) {
  std::int32_t kind = 0;
  if (proto >= 0) {
    if (!g_farms.empty() && g_farms.IndexOf(proto) >= 0) {
      kind = 1;
    } else if (!g_rectFarms.empty() && g_rectFarms.IndexOf(proto) >= 0) {
      kind = 2;
    }
  }
  g_uhcFarmKind = kind;
  return kind;
}

// The {X, Z} spread of a listed farm proto, or null for the stock 4.5 x 4.5.
const float* __stdcall UhcFarmRadius(std::int32_t proto) {
  const int i = g_farms.IndexOf(proto);
  if (i < 0 || static_cast<std::size_t>(i) >= g_radius.size() || !g_radius[i].set) {
    return nullptr;
  }
  return &g_radius[i].x;
}
}

namespace uhc {
namespace {

bool InstallFarmHooks(const char* feature) {
  if (g_farmHooks) {
    return true;
  }
  const Site* const sites[] = {&sites::kFarmAnim1, &sites::kFarmAnim2, &sites::kFarmAnim3, &sites::kFarmAnim4,
                               &sites::kFarmAnim5, &sites::kFarmAnim6, &sites::kFarmAnim7, &sites::kFarmAnim8,
                               &sites::kRectFarm1, &sites::kRectFarm2, &sites::kRectFarm3, &sites::kRectFarm4};
  void (*const hooks[])() = {&UhcFarm1Hook,     &UhcFarm2Hook,     &UhcFarm3Hook,     &UhcFarm4Hook,
                             &UhcFarm5Hook,     &UhcFarm6Hook,     &UhcFarm7Hook,     &UhcFarm8Hook,
                             &UhcRectFarm1Hook, &UhcRectFarm2Hook, &UhcRectFarm3Hook, &UhcRectFarm4Hook};
  if (!VerifyAll(feature, {sites[0], sites[1], sites[2], sites[3], sites[4], sites[5], sites[6], sites[7], sites[8],
                           sites[9], sites[10], sites[11], &sites::kProtoByName})) {
    return false;
  }
  for (int i = 0; i < 12; ++i) {
    if (!WriteJmp(sites[i]->va, reinterpret_cast<const void*>(hooks[i]), sites[i]->size)) {
      return false;
    }
  }
  g_farmHooks = true;
  return true;
}

}  // namespace

Outcome ApplyFarmAnim(const Config& config) {
  const Config::Args* farms = config.First("enableFarmAnim");
  const Config::Args* rects = config.First("enableRectFarmAnim");
  if (farms == nullptr && rects == nullptr) {
    return Outcome::kNotConfigured;
  }
  if ((farms != nullptr && farms->empty()) || (rects != nullptr && rects->empty())) {
    Log(L"enableFarmAnim/enableRectFarmAnim: a line lists no proto");
    return Outcome::kFailed;
  }
  g_farms.Set("enableFarmAnim", farms != nullptr ? *farms : std::vector<std::string>{});
  g_rectFarms.Set("enableRectFarmAnim", rects != nullptr ? *rects : std::vector<std::string>{});
  g_radius.assign(farms != nullptr ? farms->size() : 0, Radius{});
  if (!InstallFarmHooks("enableFarmAnim")) {
    return Outcome::kFailed;
  }
  Log(L"enableFarmAnim/enableRectFarmAnim: %zu proto(s) work like a Mill, %zu like a Rice Paddy; resolved when "
      L"protoy.xml is read",
      farms != nullptr ? farms->size() : 0, rects != nullptr ? rects->size() : 0);
  return Outcome::kApplied;
}

Outcome ApplyFarmingRadius(const Config& config) {
  const Config::Args* args = config.First("farmingRadius");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!g_farmHooks || g_radius.empty()) {
    Log(L"farmingRadius: needs enableFarmAnim (its entries are what the indices count)");
    return Outcome::kFailed;
  }
  if (args->empty() || args->size() % 3 != 0) {
    Log(L"farmingRadius: needs triples <Index> <X> <Z> (%zu values given)", args->size());
    return Outcome::kFailed;
  }
  std::vector<Radius> radius = g_radius;
  for (std::size_t i = 0; i < args->size(); i += 3) {
    char* end = nullptr;
    const long index = std::strtol((*args)[i].c_str(), &end, 10);
    const bool indexOk = *end == '\0';
    const float x = std::strtof((*args)[i + 1].c_str(), &end);
    const bool xOk = *end == '\0';
    const float z = std::strtof((*args)[i + 2].c_str(), &end);
    if (!indexOk || !xOk || *end != '\0' || index < 1 || static_cast<std::size_t>(index) > radius.size() ||
        !(x > 0 && x <= 100) || !(z > 0 && z <= 100)) {
      Log(L"farmingRadius: bad triple %hs %hs %hs (Index 1..%zu of enableFarmAnim, X and Z above 0, at most 100)",
          (*args)[i].c_str(), (*args)[i + 1].c_str(), (*args)[i + 2].c_str(), radius.size());
      return Outcome::kFailed;
    }
    radius[index - 1] = Radius{x, z, true};
  }
  if (!VerifyAll("farmingRadius", {&sites::kFarmRadius})) {
    return Outcome::kFailed;
  }
  g_radius = radius;
  if (!WriteJmp(sites::kFarmRadius.va, reinterpret_cast<const void*>(&UhcFarmRadiusHook), sites::kFarmRadius.size)) {
    return Outcome::kFailed;
  }
  Log(L"farmingRadius: %zu farm proto(s) get their own gather area (stock 4.5 x 4.5)", args->size() / 3);
  return Outcome::kApplied;
}

// nowalkfarm: gatherers stay on the spot they get when they start working a farm. Stock moves them
// to a new spot around the farm from time to time (call 9DDADEh at 0x6A9067, when the game time
// passes the action's [+A0h]); the key removes that call. The first spot is still chosen by the
// other callers.
Outcome ApplyNoWalkFarm(const Config& config) {
  if (config.First("nowalkfarm") == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (!VerifyAll("nowalkfarm", {&sites::kFarmWalkCall})) {
    return Outcome::kFailed;
  }
  const std::uint8_t nops[5] = {0x90, 0x90, 0x90, 0x90, 0x90};
  if (!WriteBytes(sites::kFarmWalkCall.va, nops, sizeof nops)) {
    return Outcome::kFailed;
  }
  Log(L"nowalkfarm: farm gatherers keep their first spot");
  return Outcome::kApplied;
}

}  // namespace uhc
