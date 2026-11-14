// nextResearchFree: a tech effect type='Data' subtype='NextResearchIsFree' on a ProtoUnit target makes
// the next research queued in a building of that proto free. SetNextResearchFree is the same subtype.
//
// A research is paid when its action starts: 0x8D946A at 0x9E67E1 (Research) and at 0x9D54CF
// (CommandResearch). Each action then keeps a copy of the cost for the refund of a cancel (0x9E68A0,
// 0x9D5548). Both go through the shared payment (researchpay.h). The effect adds its amount to a count
// kept by the player's copy of the proto. With a count above 0 this key claims the payment with a share
// of 0: the payment is skipped and the copy of the cost is emptied, so a cancel refunds nothing and spends
// the count. The count is not in saved games: a load applies the tech's effects again, so it is back to
// what the effects give.
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../log.h"
#include "../researchpay.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

namespace {

constexpr int kMaxLogLines = 200;

std::unordered_map<const char*, std::int32_t> g_free;  // by the player's copy of the proto
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

void ForgetOnDataLoad(char*) { g_free.clear(); }

// The proto of the unit that researches, the player's copy.
const char* ProtoOf(const char* action) {
  const char* unit = *reinterpret_cast<const char* const*>(action + 0x10);
  return unit != nullptr ? *reinterpret_cast<const char* const*>(unit + 0x5C) : nullptr;
}

bool Claim(const char* researcher, const char*, const char*, float* share, bool) {
  const char* proto = researcher != nullptr ? *reinterpret_cast<const char* const*>(researcher + 0x5C) : nullptr;
  const auto found = proto != nullptr ? g_free.find(proto) : g_free.end();
  if (found == g_free.end() || found->second <= 0) {
    return false;
  }
  *share = 0.0f;
  return true;
}

void Started(char* action, float, bool claimed) {
  if (!claimed) {
    return;
  }
  const char* proto = ProtoOf(action);
  const auto found = proto != nullptr ? g_free.find(proto) : g_free.end();
  if (found == g_free.end() || found->second <= 0) {
    return;
  }
  --found->second;
  LogLine(L"a free research", proto, found->second);
}

}  // namespace

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
  if (!AddResearchPayer("nextResearchFree", &Claim, &Started) || !AddTechSubtype("NextResearchIsFree", &ChangeCount) ||
      !AddTechSubtype("SetNextResearchFree", &ChangeCount) || !OnDatabaseLoad(&ForgetOnDataLoad)) {
    return Outcome::kFailed;
  }
  Log(L"nextResearchFree: the Data subtype NextResearchIsFree is on");
  return Outcome::kApplied;
}

}  // namespace uhc
