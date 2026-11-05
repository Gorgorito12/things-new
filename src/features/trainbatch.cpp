// trainBatchSize: <TrainBatchSize>N</TrainBatchSize> in a proto limits how many of it share one Train
// action. <DontTrainInBatches>1</DontTrainInBatches> is a size of 1 (an explicit size wins), and
// <ForceBatchTrain> is read and does nothing: the trains it changes elsewhere do not exist here.
// The tech effect type="Data" subtype="TrainBatchSize" changes the size for one player's copy of the
// proto (base: the tag's size, or the stock 5), through the stock value function 0x7F892A; the hook
// forwards the player, whose copy 0x45311B finds.
//
// Stock takes the limit from one call, 0x8D051B (0x9CE645, in the routine that queues units in a
// building): the player's [+2ACh] when a tech set it, else the database's default of [+178h]. The routine
// then fills the last Train action up to the limit and opens a new one for the rest. The hook keeps that
// call and replaces its result for a proto with the tag.
//
// The new action takes all that remains, whatever the limit, so a Shift+click of 5 is one action of 5.
// So the routine's four calls go through a wrapper that asks for more than the tag allows in pieces of
// that size, and each piece is queued and paid by the stock routine. Values are read once, kept by proto
// ID, and are the same for every player. The hook is in hooks/trainbatch_hooks.asm.
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

extern "C" void UhcTrainBatchHook();

namespace {

constexpr std::uint32_t kLimitCall = 0x009CE645;
constexpr std::uint32_t kQueueCalls[] = {0x007560B5, 0x007CAF6E, 0x007D797A, 0x009EBF03};
constexpr int kMaxLogLines = 200;

using QueueFn = bool(__thiscall*)(void* building, std::int32_t a, std::int32_t b, std::int32_t proto,
                                  std::int32_t count, std::int32_t c, std::int32_t d, std::int32_t e);
const auto kQueue = reinterpret_cast<QueueFn>(0x009CE2BE);
using PlayerProtoFn = const char*(__thiscall*)(const char* player, std::int32_t id);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
constexpr float kStockDefault = 5.0f;

std::unordered_map<std::int32_t, std::int32_t> g_sizes;  // filled while protos load, read-only after
std::unordered_map<std::int32_t, bool> g_explicit;        // protos whose size came from <TrainBatchSize>
struct TechSize {
  std::int32_t id;  // the proto ID the copy had: a reused pointer with another ID is ignored
  float value;
};
std::unordered_map<const char*, TechSize> g_techSizes;  // by the player's copy of the proto
bool g_log = false;
int g_logLines = 0;

// The size for a player's copy: the tech's, else the tag's, else none (-1).
std::int32_t SizeFor(const char* copy, std::int32_t id) {
  if (copy != nullptr && !g_techSizes.empty()) {
    const auto tech = g_techSizes.find(copy);
    if (tech != g_techSizes.end() && tech->second.id == id) {
      const long value = std::lround(tech->second.value);
      return value < 1 ? 1 : static_cast<std::int32_t>(value);
    }
  }
  const auto found = g_sizes.find(id);
  return found == g_sizes.end() ? -1 : found->second;
}

void ChangeSize(char* proto, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 8);
  const auto tag = g_sizes.find(*reinterpret_cast<const std::int32_t*>(base + 8));
  const float baseValue = tag == g_sizes.end() ? kStockDefault : static_cast<float>(tag->second);
  auto inserted = g_techSizes.emplace(proto, TechSize{id, baseValue});
  if (inserted.first->second.id != id) {
    inserted.first->second = TechSize{id, baseValue};  // the pointer was another proto's copy before
  }
  float& value = inserted.first->second.value;
  const float before = value;
  kEffectValue(relativity, &value, baseValue, amount, unapply);
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"trainBatchSize: proto %d, tech subtype TrainBatchSize, relativity %u, amount %g%ls: %g -> %g", id,
             relativity, static_cast<double>(amount), unapply ? L" (removed)" : L"", static_cast<double>(before),
             static_cast<double>(value));
  }
}

void ForgetOnDataLoad(char*) { g_techSizes.clear(); }

// A flag written as an element: absent text or anything but 0 is on.
bool FlagOn(const char* node) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  return text == nullptr || text[0] == L'\0' || _wtoi(text) != 0;
}

bool __cdecl ReadTrainBatchSize(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  const int size = text != nullptr ? _wtoi(text) : 0;
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 8);
  if (size < 1) {
    uhc::Log(L"trainBatchSize: proto %d: <TrainBatchSize> needs a number from 1, ignored", id);
    return true;
  }
  g_sizes[id] = size;
  g_explicit[id] = true;
  if (g_log) {
    uhc::Log(L"trainBatchSize: proto %d has %d", id, size);
  }
  return true;
}

bool __cdecl ReadDontTrainInBatches(void*, const char* node, char* proto) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 8);
  if (!FlagOn(node)) {
    return true;
  }
  if (g_explicit.count(id) == 0) {
    g_sizes[id] = 1;
  }
  if (g_log) {
    uhc::Log(L"trainBatchSize: proto %d has DontTrainInBatches: one per action%ls", id,
             g_explicit.count(id) == 0 ? L"" : L" (its TrainBatchSize wins)");
  }
  return true;
}

bool __cdecl ReadForceBatchTrain(void*, const char* node, char* proto) {
  if (g_log && FlagOn(node)) {
    uhc::Log(L"trainBatchSize: proto %d has ForceBatchTrain, which changes nothing in this engine",
             *reinterpret_cast<const std::int32_t*>(proto + 8));
  }
  return true;
}

// Replaces the calls of the queue routine.
bool __fastcall Queue(void* building, void*, std::int32_t a, std::int32_t b, std::int32_t proto, std::int32_t count,
                      std::int32_t c, std::int32_t d, std::int32_t e) {
  // `building` is the unit's action manager: [+4] its unit, and [unit+44h] the player (0x9CE63F..0x9CE642).
  const char* unit = building == nullptr ? nullptr
                                         : *reinterpret_cast<const char* const*>(reinterpret_cast<const char*>(building) + 4);
  const char* player = unit == nullptr ? nullptr : *reinterpret_cast<const char* const*>(unit + 0x44);
  const std::int32_t size = SizeFor(player == nullptr ? nullptr : kPlayerProto(player, proto), proto);
  if (size < 1 || count <= size) {
    return kQueue(building, a, b, proto, count, c, d, e);
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"trainBatchSize: proto %d: %d asked, in pieces of %d", proto, count, size);
  }
  bool queued = false;
  for (std::int32_t left = count; left > 0; left -= size) {
    if (!kQueue(building, a, b, proto, left < size ? left : size, c, d, e)) {
      break;
    }
    queued = true;
  }
  return queued;
}

}  // namespace

// From the hook, with the stock limit, the proto being queued and the player.
extern "C" std::int32_t __stdcall UhcTrainBatchLimit(std::int32_t stock, std::int32_t proto, const char* player) {
  const std::int32_t size = SizeFor(player == nullptr ? nullptr : kPlayerProto(player, proto), proto);
  if (size < 1) {
    return stock;
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"trainBatchSize: proto %d queues up to %d per action (stock %d)", proto, size, stock);
  }
  return size;
}

namespace uhc {

Outcome ApplyTrainBatchSize(const Config& config) {
  const Config::Args* args = config.First("trainBatchSize");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"trainBatchSize: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("trainBatchSize", {&sites::kTrainBatchLimitCall, &sites::kTrainBatchProtoArg, &sites::kTrainQueueCall1,
                                    &sites::kTrainQueueCall2, &sites::kTrainQueueCall3, &sites::kTrainQueueCall4}) ||
      !AddProtoTagHandler("TrainBatchSize", &ReadTrainBatchSize) ||
      !AddProtoTagHandler("DontTrainInBatches", &ReadDontTrainInBatches) ||
      !AddProtoTagHandler("ForceBatchTrain", &ReadForceBatchTrain) ||
      !AddTechSubtype("TrainBatchSize", &ChangeSize) || !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !WriteJmp(kLimitCall, reinterpret_cast<const void*>(&UhcTrainBatchHook), 5)) {
    return Outcome::kFailed;
  }
  for (const std::uint32_t call : kQueueCalls) {
    if (!WriteCall(call, reinterpret_cast<const void*>(&Queue))) {
      return Outcome::kFailed;
    }
  }
  Log(L"trainBatchSize: the proto tags TrainBatchSize, DontTrainInBatches and ForceBatchTrain are on, and the Data "
      L"subtype TrainBatchSize");
  return Outcome::kApplied;
}

}  // namespace uhc
