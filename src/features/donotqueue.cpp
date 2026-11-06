// doNotQueue: <DoNotQueue/> in a proto trains it ahead of what waits in the building.
//
// The queue routine 0x9CE2BE adds each new Train action at the end of the unit's action list with
// 0x494894 (the call at 0x9CE81A). The list is at [manager+14h]: +0 the count, +8 the pointers. It
// also holds the unit's other actions (idle, Maintain...), and the building works on the first Train or
// Research action of the list. After the stock add, the hook moves the new action before the first
// of them, behind any action of a tagged proto, so those keep their order. An action already training
// waits with its progress, and goes on when the tagged one is done. The proto IDs are read once and are
// the same for every player.
//
// Shipments: the home city holds a queue of the cards sent, {data, count, capacity} at [hc+288h]. Only the
// first entry advances, and the send 0x85A724 adds at the end with 0x857204 (the call at 0x85AD38). A card
// whose tech has the stock flag DoNotQueue moves in the same way: before the first card without the flag.
// What was on its way keeps its progress, as the entry holds it.
#include <cstdint>
#include <cstdlib>
#include <cstring>
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
constexpr std::size_t kShipQueue = 0x288;
constexpr std::int32_t kTechDoNotQueue = 0x1A;  // the flag's bit
constexpr std::uintptr_t kGameGlobal = 0x00C66234;

// Each entry owns its cost list and nothing points into an entry, so entries move as plain bytes.
struct ShipEntry {
  std::int32_t card;
  std::int32_t tech;
  float points;
  float progress;
  char cost[8];
};
static_assert(sizeof(ShipEntry) == 0x18);

using AddActionFn = bool(__thiscall*)(char* manager, char* action, std::int32_t a, std::int32_t b, std::int32_t c);
using ShipAddFn = std::int32_t(__thiscall*)(char* queue, const void* entry);
using PlayerTechFn = const char*(__thiscall*)(const char* player, std::int32_t tech);
using TechFlagFn = bool(__thiscall*)(const char* tech, std::int32_t bit);
const auto kAddAction = reinterpret_cast<AddActionFn>(0x00494894);
const auto kShipAdd = reinterpret_cast<ShipAddFn>(0x00857204);
const auto kPlayerTech = reinterpret_cast<PlayerTechFn>(0x00511924);
const auto kTechFlag = reinterpret_cast<TechFlagFn>(0x0044D863);

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

template <typename T>
T Field(const char* base, std::size_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

bool CardFirst(const char* hc, const ShipEntry& entry) {
  const char* tech = kPlayerTech(Field<const char*>(hc, 0x08), entry.tech);
  return tech != nullptr && kTechFlag(tech, kTechDoNotQueue);
}

// The home city screen's shipment models name their card by its place in the queue, on the local player's only.
void MoveVisuals(const char* hc, std::int32_t to, std::int32_t from) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* player = Field<const char*>(hc, 0x08);
  if (game == nullptr || player == nullptr || Field<std::int32_t>(game, 0x3C0) != Field<std::int32_t>(player, 0x00)) {
    return;
  }
  const char* scene = Field<const char*>(hc, 0xA4);
  if (scene == nullptr) {
    scene = hc;
  }
  char* const* models = Field<char* const*>(scene, 0x134);
  const std::int32_t count = Field<std::int32_t>(scene, 0x138);
  for (std::int32_t i = 0; i < count; ++i) {
    if (models[i] != nullptr) {
      auto* place = reinterpret_cast<std::int32_t*>(models[i] + 0x2C);
      if (*place >= to && *place < from) {
        ++*place;
      }
    }
  }
}

// Replaces the call of the add in the send. Its result is the place of the new entry, which the send gives to
// the shipment's models.
std::int32_t __fastcall AddCard(char* queue, void*, const void* entry) {
  const std::int32_t from = kShipAdd(queue, entry);
  if (from <= 0) {
    return from;
  }
  const char* hc = queue - kShipQueue;
  auto* list = *reinterpret_cast<ShipEntry**>(queue);
  if (!CardFirst(hc, list[from])) {
    return from;
  }
  std::int32_t to = 0;
  while (to < from && CardFirst(hc, list[to])) {
    ++to;
  }
  if (to >= from) {
    return from;
  }
  const ShipEntry moved = list[from];
  std::memmove(list + to + 1, list + to, static_cast<std::size_t>(from - to) * sizeof(ShipEntry));
  list[to] = moved;
  MoveVisuals(hc, to, from);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"doNotQueue: card with tech %d goes from place %d to place %d of the shipments", moved.tech, from, to);
  }
  return to;
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
  if (!VerifyAll("doNotQueue", {&sites::kTrainQueueAddCall, &sites::kShipQueueAddCall}) ||
      !AddProtoTagHandler("DoNotQueue", &ReadDoNotQueue) ||
      !WriteCall(sites::kTrainQueueAddCall.va, reinterpret_cast<const void*>(&AddAction)) ||
      !WriteCall(sites::kShipQueueAddCall.va, reinterpret_cast<const void*>(&AddCard))) {
    return Outcome::kFailed;
  }
  Log(L"doNotQueue: the proto tag DoNotQueue and the cards with the tech flag DoNotQueue are on");
  return Outcome::kApplied;
}

}  // namespace uhc
