// Keys that widen one of the game's "is this proto of abstract type N" tests (0x44CAC4,
// bool thiscall(proto, int index), the proto's bitset [proto+30h]) at specific call sites, by
// redirecting the call to a wrapper that keeps the stock answer and adds a case:
//
// wonderCivUnitType Proto ...: the age-up wonder placement accepts, for a civ that ages up with
//   wonders, a unit of type 16h (0x7E6919, 0x7E8050). The listed protos are accepted too.
// trainSingleAbstractType [UnitType]: the unit-creation function 0x9CE2BE (reached from the Train
//   action) treats abstract types 16h, 1, 5Ch and 5Dh (AbstractMonk) specially, creating one unit
//   (0x9CE573, 0x9CE767, the 5Dh tests). Units of the marker type (default
//   AbstractTrainLimitOne) are trained one at a time too.
#include <cstdint>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../namelists.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

using IsType = bool(__thiscall*)(const void* proto, std::int32_t index);
const auto kIsType = reinterpret_cast<IsType>(0x0044CAC4);

uhc::ProtoIdList g_wonderUnits;
std::int32_t g_trainSingleType = -1;
bool g_wonderLogged = false;
bool g_trainLogged = false;

// The call sites are thiscall: ECX = proto, one stack argument, callee pops it. __fastcall with an
// unused EDX has the same frame.
bool __fastcall WonderUnitTest(const char* proto, void* /*edx*/, std::int32_t index) {
  if (kIsType(proto, index)) {
    return true;
  }
  if (proto != nullptr && g_wonderUnits.IndexOf(*reinterpret_cast<const std::int32_t*>(proto + 4)) >= 0) {
    if (!g_wonderLogged) {
      g_wonderLogged = true;
      uhc::Log(L"wonderCivUnitType: %hs accepted for the wonder age-up", *reinterpret_cast<char* const*>(proto + 0x10));
    }
    return true;
  }
  return false;
}

// 0x44CAC4 takes the type's bit in the proto's abstract-type bitset: its unittype ID minus the
// proto count [database+19B0h] (abstract types follow the protos in the unittype table).
std::int32_t AbstractBit(std::int32_t typeId) {
  const char* game = *reinterpret_cast<char* const*>(0x00C66234);
  const char* database = game == nullptr ? nullptr : *reinterpret_cast<char* const*>(game + 0x140);
  if (database == nullptr) {
    return -1;
  }
  return typeId - *reinterpret_cast<const std::int32_t*>(database + 0x19B0);
}

bool __fastcall TrainSingleTest(const char* proto, void* /*edx*/, std::int32_t index) {
  if (kIsType(proto, index)) {
    return true;
  }
  if (g_trainSingleType >= 0 && kIsType(proto, AbstractBit(g_trainSingleType))) {
    if (!g_trainLogged) {
      g_trainLogged = true;
      uhc::Log(L"trainSingleAbstractType: %hs is trained one at a time", *reinterpret_cast<char* const*>(proto + 0x10));
    }
    return true;
  }
  return false;
}

}  // namespace

namespace uhc {

Outcome ApplyWonderCivUnitType(const Config& config) {
  const Config::Args* args = config.First("wonderCivUnitType");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (args->empty()) {
    Log(L"wonderCivUnitType: no proto listed");
    return Outcome::kFailed;
  }
  if (!VerifyAll("wonderCivUnitType", {&sites::kWonderAgeUnit1, &sites::kWonderAgeUnit2, &sites::kProtoByName})) {
    return Outcome::kFailed;
  }
  g_wonderUnits.Set("wonderCivUnitType", *args);
  if (!WriteCall(sites::kWonderAgeUnit1.va, reinterpret_cast<const void*>(&WonderUnitTest)) ||
      !WriteCall(sites::kWonderAgeUnit2.va, reinterpret_cast<const void*>(&WonderUnitTest))) {
    return Outcome::kFailed;
  }
  Log(L"wonderCivUnitType: %zu proto(s) may place the age-up wonder of a wonder civ", args->size());
  return Outcome::kApplied;
}

Outcome ApplyTrainSingleAbstractType(const Config& config) {
  const Config::Args* args = config.First("trainSingleAbstractType");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  const char* type = args->empty() ? "AbstractTrainLimitOne" : args->front().c_str();
  if (!VerifyAll("trainSingleAbstractType", {&sites::kTrainSingle1, &sites::kTrainSingle2})) {
    return Outcome::kFailed;
  }
  if (!RequestAbstractUnitType(type, &g_trainSingleType)) {
    return Outcome::kFailed;
  }
  if (!WriteCall(sites::kTrainSingle1.va, reinterpret_cast<const void*>(&TrainSingleTest)) ||
      !WriteCall(sites::kTrainSingle2.va, reinterpret_cast<const void*>(&TrainSingleTest))) {
    return Outcome::kFailed;
  }
  Log(L"trainSingleAbstractType: units of unittype %hs are trained one at a time", type);
  return Outcome::kApplied;
}

}  // namespace uhc
