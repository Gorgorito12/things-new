// The payment of a research, shared by every key that changes what a research costs (nextResearchFree,
// researchGrants): one call at each of the two payment sites (0x9E67E1 Research, 0x9D54CF CommandResearch) and
// at each of the two copies of the cost into the action for a cancel's refund (0x9E68A0, 0x9D5548).
#pragma once

namespace uhc {

// Asked before a research is paid, in the order the keys added them (their kFeatures order), until one claims
// it. `action` is the Research or CommandResearch action being set up ([action+10h] its unit; its tech is not
// written yet), `player` the paying player, `cost` the tech's cost list (a ResList). Return true to claim the
// payment with *share of the cost, 0 (free) to 1 (the full cost); the claim spends nothing yet.
using ResearchPayClaim = bool (*)(const char* action, const char* player, const char* cost, float* share);

// Called for every research that was paid and whose action is set up, claimed or not, for each key in order:
// [action+68h] is the tech ID, and the refund copy holds what was paid. `claimed` is set for the key whose claim
// it was, with its share; the others get 1. A claim whose share the player could not pay is dropped: that
// research does not start, and nothing is called.
using ResearchPayStarted = void (*)(char* action, float share, bool claimed);

// Writes the hooks the first time, after checking the stock bytes of the four sites.
bool AddResearchPayer(const char* feature, ResearchPayClaim claim, ResearchPayStarted started);

}  // namespace uhc
