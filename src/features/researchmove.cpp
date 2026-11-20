// researchOnTheMove: a unit whose proto has the abstract type ResearchOnTheMove takes orders while it has research
// queued, and the research goes on while it walks, fights or does anything else.
//
// A research is always a background action of the unit's action list (the queue routine 0x9CCB39 adds it with
// `immediate` 0), and the list update 0x485C44 updates every action of the list each tick, current or not. What holds
// the unit is the order code: before it gives a unit a new current action it asks the unit's vtable +8Ch (0x487E74),
// which asks "can take a move" 0x487DED, whose call 0x487E1B of "the queue holds the unit" 0x487D8B answers true while
// the current action is a Train or Research, or the list holds one. That one call is replaced: for a unit of the type
// whose queue holds research only (no Train action, current or in the list), the answer is false, so the order goes
// through as for a unit with an empty queue. A unit that trains stays held, as stock. The other four callers of
// 0x487D8B (a unit filter, an AI test, the repair button, the train command) keep the stock answer: they ask whether
// the unit has a queue, and it does. 0x487DED is asked for every unit every tick (the leash 0x489B15 and the order
// code 0x4FA0B5, traced in game); the wrapper does more than the stock call only when that call answers true.
#include <cstdint>
#include <cstdlib>
#include <string>
#include <unordered_set>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr int kMaxLogLines = 200;
constexpr std::uint8_t kResearchAction = 0x0C;
constexpr std::uint8_t kTrainAction = 0x0D;

using QueueHoldsFn = bool(__thiscall*)(char* manager);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kQueueHolds = reinterpret_cast<QueueHoldsFn>(0x00487D8B);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

bool g_log = false;
int g_logLines = 0;
std::unordered_set<std::int32_t> g_logged;  // unit IDs already logged; only for the log
std::int32_t g_type = -1;

template <typename T>
T Field(const char* base, std::size_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

std::uint8_t ActionType(const char* action) { return static_cast<std::uint8_t>(action[0x60]); }

// True when the manager's current action or any action of its list ([mgr+14h]: +0 count, +8 pointers) is a Train.
bool Trains(const char* manager) {
  const char* current = Field<const char*>(manager, 0x24);
  if (current != nullptr && ActionType(current) == kTrainAction) {
    return true;
  }
  const std::int32_t count = Field<std::int32_t>(manager, 0x14);
  const char* const* list = Field<const char* const*>(manager, 0x1C);
  for (std::int32_t i = 0; i < count; ++i) {
    if (list[i] != nullptr && ActionType(list[i]) == kTrainAction) {
      return true;
    }
  }
  return false;
}

// Replaces the call of 0x487D8B in 0x487DED (thiscall, no argument; the caller reads AL only).
bool __fastcall QueueHoldsUnit(char* manager, void*) {
  static bool traced = false;
  if (!traced) {
    traced = true;
    uhc::Log(L"hook reached: can take a move, queue test (0x487E1B)");
  }
  if (!kQueueHolds(manager)) {
    return false;
  }
  const char* unit = Field<const char*>(manager, 0x04);
  const char* proto = unit != nullptr ? Field<const char*>(unit, 0x5C) : nullptr;
  if (g_type < 0 || proto == nullptr || !kProtoIsType(proto, g_type) || Trains(manager)) {
    return true;
  }
  // The leash and the order code ask every tick, so a unit is logged once (the log never feeds the game).
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (g_log && g_logLines < kMaxLogLines && g_logged.insert(id).second) {
    ++g_logLines;
    uhc::Log(L"researchOnTheMove: unit %d (proto %d) is free to move with research queued", id,
             Field<std::int32_t>(proto, 0x08));
  }
  return false;
}

}  // namespace

namespace uhc {

Outcome ApplyResearchOnTheMove(const Config& config) {
  const Config::Args* args = config.First("researchOnTheMove");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"researchOnTheMove: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("researchOnTheMove", {&sites::kQueueHoldsMoveCall, &sites::kQueueHoldsHead}) ||
      !RequestAbstractUnitType("ResearchOnTheMove", &g_type) ||
      !WriteCall(sites::kQueueHoldsMoveCall.va, reinterpret_cast<const void*>(&QueueHoldsUnit))) {
    return Outcome::kFailed;
  }
  Log(L"researchOnTheMove: a unit of the abstract type ResearchOnTheMove takes orders while it researches "
      L"(multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
