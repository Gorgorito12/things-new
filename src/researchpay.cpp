// A research is paid when its action is set up, which is when it is queued: 0x8D946A(player, cost) at 0x9E67E1 in
// the Research action's start 0x9E667A (EBP = the action) and at 0x9D54CF in the CommandResearch action's
// 0x9D543F (ESI = the action). On success each start writes the tech ID to [action+68h], then copies the cost
// into the action for a cancel's refund: 0x480A73 at 0x9E68A0 (to +74h) and at 0x9D5548 (to +7Ch).
//
// Both payment calls go to UhcResearchPay (hooks/researchpay_hooks.asm), which asks the payers in order. With no
// claim it pays as stock. A claim with share 0 skips the payment; a share between 0 and 1 pays a scaled copy of
// the cost, built in a local list, so the tech's own cost is never written. The copy that follows gets the same
// share (0x4E2617 fills it with 0, 0x480B94 scales it), so a cancel refunds what was paid, never more.
// PreviewResearchPay asks the same claims in the same order for a display of the price, and changes nothing.
#include "researchpay.h"

#include <cstdint>
#include <cstring>
#include <vector>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

extern "C" {
void UhcResearchPayHook();
void UhcCommandResearchPayHook();
}

namespace {

constexpr std::size_t kMaxPayers = 4;
constexpr std::uint32_t kResearchCopyCall = 0x009E68A0;         // to [action+74h]
constexpr std::uint32_t kCommandResearchCopyCall = 0x009D5548;  // to [action+7Ch]
constexpr std::uint32_t kResListCount = 0x00C6DF38;             // the entries of every ResList

using PayFn = bool(__thiscall*)(void* player, const void* cost);
using CostCopyFn = void*(__thiscall*)(void* cost, const void* from);
using CostFillFn = void(__thiscall*)(void* cost, float value);
using CostScaleFn = void(__thiscall*)(void* cost, float factor);
const auto kPay = reinterpret_cast<PayFn>(0x008D946A);
const auto kCostCopy = reinterpret_cast<CostCopyFn>(0x00480A73);
const auto kCostFill = reinterpret_cast<CostFillFn>(0x004E2617);
const auto kCostScale = reinterpret_cast<CostScaleFn>(0x00480B94);

struct Payer {
  const char* feature;
  uhc::ResearchPayClaim claim;
  uhc::ResearchPayStarted started;
};

Payer g_payers[kMaxPayers] = {};
std::size_t g_payerCount = 0;
bool g_installed = false;

// The payment just claimed and paid, for the copy that follows it.
const Payer* g_pending = nullptr;
const char* g_pendingAction = nullptr;
float g_pendingShare = 1.0f;

// A ResList laid out as the game's: +0 the encoded entries, +4 the encoded total.
struct ResList {
  std::uint32_t* entries;
  std::uint32_t total;
};

float ClampShare(float share) { return share < 0.0f ? 0.0f : (share > 1.0f ? 1.0f : share); }

bool PayShare(void* player, const void* cost, float share) {
  if (share <= 0.0f) {
    return true;
  }
  const auto* list = static_cast<const ResList*>(cost);
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(kResListCount);
  if (share >= 1.0f || list == nullptr || list->entries == nullptr || count <= 0) {
    return kPay(player, cost);
  }
  std::vector<std::uint32_t> entries(list->entries, list->entries + count);
  ResList scaled{entries.data(), list->total};
  kCostScale(&scaled, share);
  return kPay(player, &scaled);
}

void* CopyCost(void* cost, const void* from, std::uint32_t offset) {
  void* result = kCostCopy(cost, from);
  char* action = static_cast<char*>(cost) - offset;
  const Payer* payer = action == g_pendingAction ? g_pending : nullptr;
  const float share = payer != nullptr ? g_pendingShare : 1.0f;
  g_pending = nullptr;
  g_pendingAction = nullptr;
  if (share <= 0.0f) {
    kCostFill(cost, 0.0f);
  } else if (share < 1.0f) {
    kCostScale(cost, share);
  }
  for (std::size_t i = 0; i < g_payerCount; ++i) {
    const bool claimed = payer == &g_payers[i];
    g_payers[i].started(action, claimed ? share : 1.0f, claimed);
  }
  return result;
}

void* __fastcall CopyResearchCost(void* cost, void*, const void* from) { return CopyCost(cost, from, 0x74); }
void* __fastcall CopyCommandResearchCost(void* cost, void*, const void* from) { return CopyCost(cost, from, 0x7C); }

}  // namespace

// From the two hooks, instead of the payment. The action is the one being set up.
extern "C" bool __stdcall UhcResearchPay(const char* action, void* player, const void* cost) {
  g_pending = nullptr;
  const char* researcher = *reinterpret_cast<const char* const*>(action + 0x10);
  for (std::size_t i = 0; i < g_payerCount; ++i) {
    float share = 1.0f;
    if (!g_payers[i].claim(researcher, static_cast<const char*>(player), static_cast<const char*>(cost), &share,
                           false)) {
      continue;
    }
    share = ClampShare(share);
    if (!PayShare(player, cost, share)) {
      return false;  // the research does not start; nothing was spent
    }
    g_pending = &g_payers[i];
    g_pendingAction = action;
    g_pendingShare = share;
    return true;
  }
  return kPay(player, cost);
}

namespace uhc {

bool AddResearchPayer(const char* feature, ResearchPayClaim claim, ResearchPayStarted started) {
  if (g_payerCount == kMaxPayers) {
    Log(L"research payment: more than %u keys", static_cast<unsigned>(kMaxPayers));
    return false;
  }
  if (!g_installed) {
    if (!VerifyAll(feature, {&sites::kResearchPayCall, &sites::kCommandResearchPayCall,
                             &sites::kResearchCostCopyCall, &sites::kCommandResearchCostCopyCall,
                             &sites::kResListCopy, &sites::kResListScale}) ||
        !WriteCall(sites::kResearchPayCall.va, reinterpret_cast<const void*>(&UhcResearchPayHook)) ||
        !WriteCall(sites::kCommandResearchPayCall.va, reinterpret_cast<const void*>(&UhcCommandResearchPayHook)) ||
        !WriteCall(kResearchCopyCall, reinterpret_cast<const void*>(&CopyResearchCost)) ||
        !WriteCall(kCommandResearchCopyCall, reinterpret_cast<const void*>(&CopyCommandResearchCost))) {
      return false;
    }
    g_installed = true;
  }
  g_payers[g_payerCount++] = {feature, claim, started};
  return true;
}

const char* PreviewResearchPay(const char* researcher, const char* player, const char* cost, float* share) {
  for (std::size_t i = 0; i < g_payerCount; ++i) {
    float claimed = 1.0f;
    if (g_payers[i].claim(researcher, player, cost, &claimed, true)) {
      *share = ClampShare(claimed);
      return g_payers[i].feature;
    }
  }
  *share = 1.0f;
  return nullptr;
}

}  // namespace uhc
