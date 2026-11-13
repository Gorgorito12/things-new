// ageUpBuildings [log] Proto ...: the age-up button opens its dialog on the listed protos too, not only on the
// Town Center, and a listed proto offers only the politicians its own proto lists.
//
// The command panel already builds the age-up button (uiPoliticianUI(unit, player, revolt)) for any unit whose proto
// lists a tech with the AgeUpgrade or RevoltTech flag. The two pickers that open the dialog, uiPoliticianUI 0x7E686E
// and uiPoliticianUIInSelected 0x7E7EC1, then refuse every unit whose player's proto is not the TownCenter
// ([db+5E08h]), for a civ that isAsianCiv(player, true) 0x454ED7 rejects (an Asian civ needs a unit of abstract type
// 16h there, for its wonders; wonderCivUnitType widens that test, this key leaves it alone). The hooks
// (hooks/ageup_hooks.asm) re-execute the TownCenter compare and, when it fails, accept a listed proto.
//
// The dialog's list builders (FUN_0081A2B8 for the European dialog, FUN_00818EE5) keep each tech status of the next
// age that 0x4C6968(status, unit) accepts: its flags, status and prerequisites, not whether the unit's proto lists
// the tech. On a listed proto the key also requires that the proto's tech list ([proto+E8h], 6-byte entries
// {word id, byte kind 1 = tech, ...}, count [proto+ECh]) holds the tech, so a building shows its own politicians.
// The chosen politician is researched by the unit the dialog was opened on (its ID [dlg+140h]).
#include <cstdint>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../namelists.h"
#include "../patch.h"

namespace {

using CanResearch = bool(__thiscall*)(void* techStatus, void* unit);
const auto kCanResearch = reinterpret_cast<CanResearch>(0x004C6968);

uhc::ProtoIdList g_ageUpProtos;
bool g_ageUpLog = false;
int g_ageUpLogged = 0;
bool g_filterLogged = false;

bool Listed(const char* proto) {
  return proto != nullptr && g_ageUpProtos.IndexOf(*reinterpret_cast<const std::int32_t*>(proto + 4)) >= 0;
}

// True if the proto's command list holds the tech (kind 1).
bool ProtoListsTech(const char* proto, std::int32_t techId) {
  const auto* entries = *reinterpret_cast<const std::uint8_t* const*>(proto + 0xE8);
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(proto + 0xEC);
  if (entries == nullptr || count <= 0) {
    return false;
  }
  for (std::int32_t i = 0; i < count; ++i) {
    const std::uint8_t* entry = entries + 6 * i;
    if (entry[2] == 1 && *reinterpret_cast<const std::uint16_t*>(entry) == static_cast<std::uint16_t>(techId)) {
      return true;
    }
  }
  return false;
}

// Replaces the builders' call 4C6968h (thiscall(status, unit), ret 4); __fastcall with an unused EDX has that frame.
bool __fastcall CanResearchHere(void* techStatus, void* /*edx*/, char* unit) {
  static bool reached = false;
  if (!reached) {
    reached = true;
    uhc::Log(L"hook reached: ageUpBuildings politician list (0x81A44D / 0x819052)");
  }
  if (!kCanResearch(techStatus, unit)) {
    return false;
  }
  const char* proto = unit == nullptr ? nullptr : *reinterpret_cast<const char* const*>(unit + 0x5C);
  if (!Listed(proto)) {
    return true;
  }
  const char* tech = *reinterpret_cast<const char* const*>(techStatus);
  if (tech == nullptr) {
    return false;
  }
  const std::int32_t techId = *reinterpret_cast<const std::int32_t*>(tech);
  const bool here = ProtoListsTech(proto, techId);
  if (g_ageUpLog && !g_filterLogged) {
    g_filterLogged = true;
    uhc::Log(L"ageUpBuildings: list filter on proto %d, first tech %d %ls",
             *reinterpret_cast<const std::int32_t*>(proto + 4), techId, here ? L"listed" : L"not listed");
  }
  return here;
}

}  // namespace

extern "C" {
void UhcAgeUpPickerTcHook();
void UhcAgeUpSelectedTcHook();

// True if the player's proto (its ID at +4, the field the stock TownCenter compare reads) is listed.
bool __stdcall UhcAgeUpListed(const char* proto) {
  if (!Listed(proto)) {
    return false;
  }
  if (g_ageUpLog && g_ageUpLogged < 50) {
    ++g_ageUpLogged;
    uhc::Log(L"ageUpBuildings: the age-up dialog opens on proto %d", *reinterpret_cast<const std::int32_t*>(proto + 4));
  }
  return true;
}
}

namespace uhc {

Outcome ApplyAgeUpBuildings(const Config& config) {
  const Config::Args* args = config.First("ageUpBuildings");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::vector<std::string> names;
  for (const std::string& arg : *args) {
    if (names.empty() && !g_ageUpLog && _stricmp(arg.c_str(), "log") == 0) {
      g_ageUpLog = true;
      continue;
    }
    names.push_back(arg);
  }
  if (names.empty()) {
    Log(L"ageUpBuildings: no proto listed");
    return Outcome::kFailed;
  }
  if (!VerifyAll("ageUpBuildings",
                 {&sites::kAgeUpPickerTc, &sites::kAgeUpPickerAccept, &sites::kAgeUpPickerReject,
                  &sites::kAgeUpSelectedTc, &sites::kAgeUpSelectedAccept, &sites::kAgeUpSelectedReject,
                  &sites::kAgeUpListA, &sites::kAgeUpListB, &sites::kProtoByName})) {
    return Outcome::kFailed;
  }
  g_ageUpProtos.Set("ageUpBuildings", names);
  if (!WriteJmp(sites::kAgeUpPickerTc.va, reinterpret_cast<const void*>(&UhcAgeUpPickerTcHook),
                sites::kAgeUpPickerTc.size) ||
      !WriteJmp(sites::kAgeUpSelectedTc.va, reinterpret_cast<const void*>(&UhcAgeUpSelectedTcHook),
                sites::kAgeUpSelectedTc.size) ||
      !WriteCall(sites::kAgeUpListA.va, reinterpret_cast<const void*>(&CanResearchHere)) ||
      !WriteCall(sites::kAgeUpListB.va, reinterpret_cast<const void*>(&CanResearchHere))) {
    return Outcome::kFailed;
  }
  Log(L"ageUpBuildings: %zu proto(s) open the age-up dialog besides the Town Center, with the politicians they list%ls",
      names.size(), g_ageUpLog ? L" (log)" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
