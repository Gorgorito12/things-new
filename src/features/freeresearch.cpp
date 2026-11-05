// nextResearchFree: a tech effect type='Data' subtype='NextResearchIsFree' on a ProtoUnit target makes
// the next research queued in a building of that proto free. SetNextResearchFree is the same subtype.
//
// A research is paid when its action starts: 0x8D946A at 0x9E67E1 (Research) and at 0x9D54CF
// (CommandResearch). Each action then keeps a copy of the cost for the refund of a cancel (0x9E68A0,
// 0x9D5548). The effect adds its amount to a count kept by the player's copy of the proto. With a count
// above 0 the payment is skipped, and the copy of the cost is emptied, so a cancel refunds nothing and
// spends the count. The count is not in saved games: a load applies the tech's effects again, so it
// is back to what the effects give. The hooks are in hooks/freeresearch_hooks.asm.
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

extern "C" {
void UhcFreeResearchPayHook();
void UhcFreeCommandPayHook();
}

namespace {

constexpr int kMaxLogLines = 200;
constexpr std::uint32_t kCostCopyCalls[] = {0x009E68A0, 0x009D5548};

using PayFn = bool(__thiscall*)(void* player, const void* cost);
using CostCopyFn = void*(__thiscall*)(void* cost, const void* from);
using CostFillFn = void(__thiscall*)(void* cost, float value);
const auto kPay = reinterpret_cast<PayFn>(0x008D946A);
const auto kCostCopy = reinterpret_cast<CostCopyFn>(0x00480A73);
const auto kCostFill = reinterpret_cast<CostFillFn>(0x004E2617);

std::unordered_map<const char*, std::int32_t> g_free;  // by the player's copy of the proto
bool g_skipped = false;                                // the payment just skipped, for the copy that follows
bool g_log = false;
int g_logLines = 0;

void LogLine(const wchar_t* what, const char* proto, std::int32_t count) {
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"nextResearchFree: proto %d: %ls, %d left", *reinterpret_cast<const std::int32_t*>(proto + 8), what, count);
  }
}

void ChangeCount(char* proto, const char*, float amount, std::uint8_t, bool unapply) {
  const std::int32_t delta = static_cast<std::int32_t>(std::lround(amount));
  std::int32_t& count = g_free[proto];
  count = unapply ? (count > delta ? count - delta : 0) : count + delta;
  LogLine(unapply ? L"effect removed" : L"effect applied", proto, count);
}

void ForgetOnDataLoad(char*) {
  g_free.clear();
  g_skipped = false;
}

// Replaces the call of the copy of the cost into the action.
void* __fastcall CostCopy(void* cost, void*, const void* from) {
  void* result = kCostCopy(cost, from);
  if (g_skipped) {
    g_skipped = false;
    kCostFill(cost, 0.0f);
  }
  return result;
}

}  // namespace

// From the two hooks, instead of the payment. The action is the one being started.
extern "C" bool __stdcall UhcFreeResearchPay(const char* action, void* player, const void* cost) {
  const char* unit = *reinterpret_cast<const char* const*>(action + 0x10);
  const char* proto = unit != nullptr ? *reinterpret_cast<const char* const*>(unit + 0x5C) : nullptr;
  const auto found = proto != nullptr ? g_free.find(proto) : g_free.end();
  if (found == g_free.end() || found->second <= 0) {
    return kPay(player, cost);
  }
  --found->second;
  g_skipped = true;
  LogLine(L"a free research", proto, found->second);
  return true;
}

namespace uhc {

Outcome ApplyNextResearchFree(const Config& config) {
  const Config::Args* args = config.First("nextResearchFree");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"nextResearchFree: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("nextResearchFree", {&sites::kResearchPayCall, &sites::kCommandResearchPayCall,
                                      &sites::kResearchCostCopyCall, &sites::kCommandResearchCostCopyCall}) ||
      !AddTechSubtype("NextResearchIsFree", &ChangeCount) || !AddTechSubtype("SetNextResearchFree", &ChangeCount) ||
      !OnDatabaseLoad(&ForgetOnDataLoad) ||
      !WriteCall(sites::kResearchPayCall.va, reinterpret_cast<const void*>(&UhcFreeResearchPayHook)) ||
      !WriteCall(sites::kCommandResearchPayCall.va, reinterpret_cast<const void*>(&UhcFreeCommandPayHook))) {
    return Outcome::kFailed;
  }
  for (const std::uint32_t call : kCostCopyCalls) {
    if (!WriteCall(call, reinterpret_cast<const void*>(&CostCopy))) {
      return Outcome::kFailed;
    }
  }
  Log(L"nextResearchFree: the Data subtype NextResearchIsFree is on");
  return Outcome::kApplied;
}

}  // namespace uhc
