// homeCityTechsInUnits [nogathercheck] [log]: a tech with the HomeCity flag (a home city card) listed in a proto's
// <Tech> rows is researched there as a normal tech: it pays its own cost, takes its ResearchPoints, and its effects
// apply when it is done. One status with the card: the research activates the same tech the card would.
//
// Stock, the research start 0x9E667A refuses a HomeCity tech silently at 0x9E67CE, after the can-research test and
// before the payment, so its button shows (when the tech is obtainable) but a click does nothing. The hook lets it
// through when the researching unit's proto lists the tech in its command entries ([proto+0E8h], 6-byte records,
// kind 1 a tech, count [proto+0ECh]); any other HomeCity research is still refused.
//
// A researched HomeCity tech: the can-research test (canresearch.h) refuses it for a unit whose proto lists it once
// it is active (bit 1), since that test skips its "already active" check for HomeCity techs.
//
// The gather point: a HomeCity tech researched this way is cancelled with a refund while its player has a home city
// and no land gather point, as a tech with CheckLandHCGatherPoint (0x9E6553 in the Research update), so the units of
// a FreeHomeCityUnit card are not lost. `nogathercheck` leaves that to the tech's own flags; a tech with
// CheckWaterHCGatherPoint keeps the stock water check.
#include <cstdint>
#include <string>

#include "../canresearch.h"
#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
std::int32_t g_uhcHcGatherCheck = 1;
void UhcHcTechStartHook();
void UhcHcTechGatherHook();
}

namespace {

constexpr int kMaxLines = 200;
bool g_log = false;
int g_lines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

bool HasBit(const char* status, std::uint32_t bit) {
  if (bit >= Field<std::uint32_t>(status, 8)) {
    return false;
  }
  return (Field<const std::uint8_t*>(status, 4)[bit / 8] >> (bit % 8) & 1) != 0;
}

std::int32_t TechIdOf(const char* status) {
  const char* def = Field<const char*>(status, 0);
  return def == nullptr ? -1 : Field<std::int32_t>(def, 0);
}

// The unit's proto lists the tech among its command entries.
bool ProtoLists(const char* unit, std::int32_t tech) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (proto == nullptr || tech < 0) {
    return false;
  }
  const auto* entries = Field<const std::uint8_t*>(proto, 0xE8);
  const std::int32_t count = Field<std::int32_t>(proto, 0xEC);
  for (std::int32_t i = 0; entries != nullptr && i < count; ++i) {
    const std::uint8_t* entry = entries + 6 * i;
    if (entry[2] == 1 && *reinterpret_cast<const std::uint16_t*>(entry) == static_cast<std::uint16_t>(tech)) {
      return true;
    }
  }
  return false;
}

bool RefuseActive(const char* status, const char* unit) {
  return unit != nullptr && HasBit(status, 18) && HasBit(status, 1) && ProtoLists(unit, TechIdOf(status));
}

}  // namespace

// From the start hook, for a HomeCity tech: true lets the research go on.
extern "C" bool __stdcall UhcHcTechAllowed(const char* action, const char* status) {
  const char* unit = Field<const char*>(action, 0x10);
  const std::int32_t tech = TechIdOf(status);
  const bool allowed = ProtoLists(unit, tech);
  if (g_log && g_lines < kMaxLines) {
    ++g_lines;
    uhc::Log(L"homeCityTechsInUnits: HomeCity tech %d in unit %d: %ls", tech,
             unit == nullptr ? -1 : Field<std::int32_t>(unit, 0x10),
             allowed ? L"researched (its proto lists it)" : L"refused as in stock (its proto does not list it)");
  }
  return allowed;
}

namespace uhc {

Outcome ApplyHomeCityTechsInUnits(const Config& config) {
  const Config::Args* args = config.First("homeCityTechsInUnits");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "nogathercheck") == 0) {
      g_uhcHcGatherCheck = 0;
    } else {
      Log(L"homeCityTechsInUnits: unknown option %hs (expected: [nogathercheck] [log]); feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("homeCityTechsInUnits", {&sites::kHcTechResearchRefusal, &sites::kResearchGatherFlagTest}) ||
      !AddCanResearchFilter("homeCityTechsInUnits", &RefuseActive) ||
      !WriteJmp(sites::kHcTechResearchRefusal.va, reinterpret_cast<const void*>(&UhcHcTechStartHook), 13) ||
      !WriteJmp(sites::kResearchGatherFlagTest.va, reinterpret_cast<const void*>(&UhcHcTechGatherHook), 9)) {
    return Outcome::kFailed;
  }
  Log(L"homeCityTechsInUnits: HomeCity techs listed in a proto are researched there%ls%ls (multiplayer unverified)",
      g_uhcHcGatherCheck != 0 ? L"; they wait for a land gather point" : L"", g_log ? L"; logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
