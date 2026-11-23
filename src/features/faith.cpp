// faithResource [log]: resource 4 ("SkillPoints") becomes an ordinary resource that a mod can gather and spend
// (a faith villagers gather by praying), cut from the home city's skill points it stands for in the stock game:
// - the skill point total 0x5011C6 returns int(resource 4) plus the home city's unspent skill points [HC+1F4h];
//   every read of resource 4 that is not the plain list entry goes through it (the KB getter behind
//   kbResourceGet 0x86B616, the AI's KB copy loops 0x86D8BD and 0x8767CA, the {resource()} text of the
//   interface, trPlayerResourceCount 0x988538 and the post-game statistics loop 0x500E2C). Its je 501209h becomes
//   a jmp (1 byte at 0x501201): it returns int(resource 4) alone, as the stock function does with no home city.
// - the home city bank FUN_00852924 (game end, its four callers) adds resource 4 to [HC+1F4h] and clears it. The
//   add is skipped by a hook (it can log the amount); the clear (call 49A8C5h with 4, 0, 0) is jumped over, so
//   faith stays in the game if the bank ever runs before its end. The XP half of the bank is not touched.
// - not changed: the setup FUN_006AED5E gives each AI player resource 4 = its home city level + 15 (0x6AEEDC,
//   0x6AF052): that is the AI's budget for the home city cards it buys at the start (measured: 20, then 6 after 14
//   cards), so the AI keeps what it has not spent. An AI script that read its card budget through
//   kbResourceGet(cResourceSkillPoints) adds kbGetHCLevel - 1, the home city's points the total used to add.
// - the praying animation: the Gather action's state change FUN_004ED254 picks the gather animation from the
//   target's unit types (mine, tree, farm, hunt, fish, crate, fire pit, else GatherBush or GatherFarm) and never
//   reads the tactics action's <anim>; at a church the villagers danced. A hook at the head of that chain
//   (0x4ED355) stores the action's own <anim> when the action gathers resource 4 and the gatherer's model has
//   that anim (0x471D24); every other gather keeps the stock choice.
#include <cstdint>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcFaithBankHook();
void UhcFaithGatherAnimHook();
// Read by the gather animation hook: nonzero plays a faith Gather action's own <anim>.
std::int32_t g_uhcFaithAnim = 0;
// Read by the hook: nonzero writes each skipped bank to the log.
std::int32_t g_uhcFaithLog = 0;
}

// Called by the hook (log only): faith = int(resource 4) that the stock code would add, skillPoints = the home
// city's skill points, left as they are.
extern "C" void __stdcall UhcFaithBankSkipped(std::int32_t faith, std::int32_t skillPoints) {
  uhc::Log(L"faithResource: home city bank: %d of resource 4 (faith) not added to the home city's skill points "
           L"(they stay %d)", faith, skillPoints);
}

namespace uhc {

Outcome ApplyFaithResource(const Config& config) {
  const Config::Args* args = config.First("faithResource");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"faithResource: unknown argument '%hs' (expected log); not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("faithResource", {&sites::kFaithTotal, &sites::kFaithBank, &sites::kFaithBankClear,
                                   &sites::kFaithGatherAnim,
                                   &sites::kFaithGatherAnimSet, &sites::kFaithGatherAnimNext,
                                   &sites::kShotsAnimVariant})) {
    return Outcome::kFailed;
  }
  g_uhcFaithLog = log ? 1 : 0;
  g_uhcFaithAnim = 1;
  const std::uint8_t jmpShort = 0xEB;                         // je 501209h -> jmp 501209h
  const std::uint8_t skipClear[] = {0xEB, 0x0C};              // jmp 852A58h over the clear of resource 4
  const bool ok = WriteBytes(sites::kFaithTotal.va, &jmpShort, 1) &&
                  WriteJmp(sites::kFaithBank.va, reinterpret_cast<const void*>(&UhcFaithBankHook), 6) &&
                  WriteBytes(sites::kFaithBankClear.va, skipClear, sizeof(skipClear)) &&
                  WriteJmp(sites::kFaithGatherAnim.va, reinterpret_cast<const void*>(&UhcFaithGatherAnimHook), 7);
  if (!ok) {
    return Outcome::kFailed;
  }
  Log(L"faithResource: resource 4 (SkillPoints) is a plain resource: no home city skill points in its reads, "
      L"not banked into the home city; a faith Gather action plays its own <anim>%ls "
      L"(multiplayer unverified)",
      log ? L" (each skipped bank logged)" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
