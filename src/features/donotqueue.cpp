// doNotQueue: <DoNotQueue/> in a proto trains it ahead of what waits in the building.
//
// The queue routine 0x9CE2BE adds each new Train action at the end of the unit's action list with
// 0x494894 (the call at 0x9CE81A). The list is at [manager+14h]: +0 the count, +8 the pointers. It
// also holds the unit's other actions (idle, Maintain...), and the building works on the first Train or
// Research action of the list. After the stock add, the hook moves the new action before the first
// of them, behind any action of a tagged proto, so those keep their order. An action already training
// waits with its progress, and goes on when the tagged one is done. The proto IDs are read once and are
// the same for every player.
#include <cstdint>
#include <cstdlib>
#include <string>
#include <unordered_set>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"

namespace {

constexpr std::size_t kActionList = 0x14;
constexpr std::uint8_t kResearchAction = 0x0C;
constexpr std::uint8_t kTrainAction = 0x0D;
constexpr int kMaxLogLines = 200;

using AddActionFn = bool(__thiscall*)(char* manager, char* action, std::int32_t a, std::int32_t b, std::int32_t c);
const auto kAddAction = reinterpret_cast<AddActionFn>(0x00494894);

std::unordered_set<std::int32_t> g_protos;  // filled while protos load, read-only after
bool g_log = false;
int g_logLines = 0;

bool __cdecl ReadDoNotQueue(void*, const char*, char* proto) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 8);
  g_protos.insert(id);
  if (g_log) {
    uhc::Log(L"doNotQueue: proto %d has the tag", id);
  }
  return true;
}

// The proto of a Train action, or -1: the first entry of [action+70h], 14h bytes each, +0 the proto ID.
std::int32_t TrainProto(const char* action) {
  if (static_cast<std::uint8_t>(action[0x60]) != kTrainAction ||
      *reinterpret_cast<const std::int32_t*>(action + 0x74) <= 0) {
    return -1;
  }
  return **reinterpret_cast<const std::int32_t* const*>(action + 0x70);
}

bool Tagged(const char* action) { return g_protos.count(TrainProto(action)) != 0; }

bool InQueue(const char* action) {
  const auto type = static_cast<std::uint8_t>(action[0x60]);
  return type == kResearchAction || type == kTrainAction;
}

// Replaces the call of the add in the queue routine.
bool __fastcall AddAction(char* manager, void*, char* action, std::int32_t a, std::int32_t b, std::int32_t c) {
  if (!kAddAction(manager, action, a, b, c)) {
    return false;
  }
  if (!Tagged(action)) {
    return true;
  }
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(manager + kActionList);
  char** list = *reinterpret_cast<char***>(manager + kActionList + 8);
  std::int32_t from = count - 1;
  while (from >= 0 && list[from] != action) {
    --from;
  }
  std::int32_t to = 0;
  while (to < from && !InQueue(list[to])) {
    ++to;
  }
  while (to < from && Tagged(list[to])) {
    ++to;
  }
  if (from < 0 || to >= from) {
    return true;
  }
  for (std::int32_t i = from; i > to; --i) {
    list[i] = list[i - 1];
  }
  list[to] = action;
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"doNotQueue: proto %d goes from place %d to place %d of %d", TrainProto(action), from, to, count);
  }
  return true;
}

}  // namespace

namespace uhc {

Outcome ApplyDoNotQueue(const Config& config) {
  const Config::Args* args = config.First("doNotQueue");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"doNotQueue: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("doNotQueue", {&sites::kTrainQueueAddCall}) || !AddProtoTagHandler("DoNotQueue", &ReadDoNotQueue) ||
      !WriteCall(sites::kTrainQueueAddCall.va, reinterpret_cast<const void*>(&AddAction))) {
    return Outcome::kFailed;
  }
  Log(L"doNotQueue: the proto tag DoNotQueue is on");
  return Outcome::kApplied;
}

}  // namespace uhc
