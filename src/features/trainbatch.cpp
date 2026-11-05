// trainBatchSize: <TrainBatchSize>N</TrainBatchSize> in a proto limits how many of it share one Train
// action.
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

extern "C" void UhcTrainBatchHook();

namespace {

constexpr std::uint32_t kLimitCall = 0x009CE645;
constexpr std::uint32_t kQueueCalls[] = {0x007560B5, 0x007CAF6E, 0x007D797A, 0x009EBF03};
constexpr int kMaxLogLines = 200;

using QueueFn = bool(__thiscall*)(void* building, std::int32_t a, std::int32_t b, std::int32_t proto,
                                  std::int32_t count, std::int32_t c, std::int32_t d, std::int32_t e);
const auto kQueue = reinterpret_cast<QueueFn>(0x009CE2BE);

std::unordered_map<std::int32_t, std::int32_t> g_sizes;  // filled while protos load, read-only after
bool g_log = false;
int g_logLines = 0;

bool __cdecl ReadTrainBatchSize(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  const int size = text != nullptr ? _wtoi(text) : 0;
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + 8);
  if (size < 1) {
    uhc::Log(L"trainBatchSize: proto %d: <TrainBatchSize> needs a number from 1, ignored", id);
    return true;
  }
  g_sizes[id] = size;
  if (g_log) {
    uhc::Log(L"trainBatchSize: proto %d has %d", id, size);
  }
  return true;
}

// Replaces the calls of the queue routine.
bool __fastcall Queue(void* building, void*, std::int32_t a, std::int32_t b, std::int32_t proto, std::int32_t count,
                      std::int32_t c, std::int32_t d, std::int32_t e) {
  const auto found = g_sizes.find(proto);
  if (found == g_sizes.end() || count <= found->second) {
    return kQueue(building, a, b, proto, count, c, d, e);
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"trainBatchSize: proto %d: %d asked, in pieces of %d", proto, count, found->second);
  }
  bool queued = false;
  for (std::int32_t left = count; left > 0; left -= found->second) {
    if (!kQueue(building, a, b, proto, left < found->second ? left : found->second, c, d, e)) {
      break;
    }
    queued = true;
  }
  return queued;
}

}  // namespace

// From the hook, with the stock limit and the proto being queued.
extern "C" std::int32_t __stdcall UhcTrainBatchLimit(std::int32_t stock, std::int32_t proto) {
  const auto found = g_sizes.find(proto);
  if (found == g_sizes.end()) {
    return stock;
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"trainBatchSize: proto %d queues up to %d per action (stock %d)", proto, found->second, stock);
  }
  return found->second;
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
      !WriteJmp(kLimitCall, reinterpret_cast<const void*>(&UhcTrainBatchHook), 5)) {
    return Outcome::kFailed;
  }
  for (const std::uint32_t call : kQueueCalls) {
    if (!WriteCall(call, reinterpret_cast<const void*>(&Queue))) {
      return Outcome::kFailed;
    }
  }
  Log(L"trainBatchSize: the proto tag TrainBatchSize is on");
  return Outcome::kApplied;
}

}  // namespace uhc
