// deadReplacementAtZeroInventory [log]: a unit with DoNotDieAtZeroHitpoints and DieAtZeroResources (a hunt,
// a herdable, any unit that turns into a body to gather) leaves its <DeadReplacement> when its body is used
// up, not when it falls.
//
// The death replacement FUN_004B4F2F places the proto [proto+F8h] (<DeadReplacement>, handler 0x5FC33B) at the
// unit, once: it sets state bit 29h, and does nothing when that bit is set. It has four callers: the kill
// handler 0x4B4F70 (0x4B527E, skipped for a DeadReplacementWhenDestroyed proto, flag 4Ah), the two removal
// paths of such a proto (0x4E6FC6, 0x6A4013), and the state check FUN_00482152 at 0x4F1680. That last one runs
// when a unit with DieAtZeroResources (flag 0Eh) and without the default DieAtZeroHitpoints (flag 0Dh, cleared
// by DoNotDieAtZeroHitpoints) reaches 0 HP while in the world: the unit becomes a body (state bit 12, owner
// gaia), plays its death sound, and the replacement is placed at once, beside the body that is still there.
// When the body's inventory reaches 0, the state check asks the kill queue (0x4720BF), but the unit update
// FUN_00482F16 marks the body for removal (state bit 7) and the world removes it (0x4726B2 at 0x495D61) in the
// same update, before the queue's drain: the kill handler never runs for it. The two updates that remove a
// unit marked so (0x483155 → 0x495DEC, and 0x5116C2 → 0x6A3FEE) call the removal notice FUN_00495D6B first,
// then place the replacement of a DeadReplacementWhenDestroyed proto (flag 4Ah) only.
//
// Two hooks (hooks/deadrepl_hooks.asm):
// - the replacement's head returns at once when it is called from 0x4F1680 for a unit with those two flags and
//   a replacement, without setting bit 29h, so nothing is placed when the unit falls;
// - the removal notice's head (its only two callers are those removal paths) places the replacement of such a
//   body (state bit 12) through the stock function, at the moment and place a DeadReplacementWhenDestroyed
//   proto gets its own. A body killed by the kill handler (a trigger's Kill) gets it there, as stock does;
//   bit 29h keeps it to one.
// Every other unit is stock. Simulation only, on data the same on every machine.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

constexpr std::uint32_t kCorpseCallReturn = 0x004F1685;  // after call 4B4F2Fh at 0x4F1680
constexpr std::uint32_t kGameGlobal = 0x00C66234;         // game; +140h database
constexpr std::int32_t kFlagDieAtZeroHitpoints = 0x0D;
constexpr std::int32_t kFlagDieAtZeroResources = 0x0E;
constexpr std::int32_t kStateBody = 12;
constexpr std::int32_t kStateReplaced = 0x29;
constexpr unsigned kMaxLogLines = 300;

using ProtoByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
const auto kProtoById = reinterpret_cast<ProtoByIdFn>(0x0045316E);
using ReplaceFn = void(__thiscall*)(char* unit);
const auto kReplace = reinterpret_cast<ReplaceFn>(0x004B4F2F);

bool g_log = false;
unsigned g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

// A bit of a bitset (pointer at +0, bit count at +4), as the stock tests read it.
bool Bit(const char* set, std::int32_t bit) {
  const auto* bits = Field<const std::uint8_t*>(set, 0);
  return bits != nullptr && bit < Field<std::int32_t>(set, 4) && (bits[bit >> 3] & (1u << (bit & 7))) != 0;
}

const char* NameOf(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* ReplacementName(std::int32_t id) {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  return database == nullptr ? "?" : NameOf(kProtoById(database, id));
}

// The proto keeps its body at 0 HP, dies when its inventory is empty, and has a replacement.
bool BodyWithReplacement(const char* proto) {
  return proto != nullptr && Field<std::int32_t>(proto, 0xF8) >= 0 && !Bit(proto + 0x50, kFlagDieAtZeroHitpoints) &&
         Bit(proto + 0x50, kFlagDieAtZeroResources);
}

void LogLine(const char* unit, const char* proto, const wchar_t* what) {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return;
  }
  ++g_logLines;
  const std::int32_t replacement = Field<std::int32_t>(proto, 0xF8);
  const auto* position = reinterpret_cast<const float*>(unit + 0x14);
  uhc::Log(L"deadReplacementAtZeroInventory: unit %d (%hs, at %.1f, %.1f) %ls: DeadReplacement %hs (%d)",
           Field<std::int32_t>(unit, 0x10), NameOf(proto), static_cast<double>(position[0]),
           static_cast<double>(position[2]), what, ReplacementName(replacement), replacement);
  if (g_logLines == kMaxLogLines) {
    uhc::Log(L"deadReplacementAtZeroInventory: %u lines logged; no more", kMaxLogLines);
  }
}

}  // namespace

extern "C" {

void UhcDeadReplacementHook();
void UhcDeadReplacementRemoveHook();

// From the replacement's head, with the caller's return address: 1 skips the call.
std::int32_t __stdcall UhcDeadReplacementSkip(const char* unit, std::uint32_t caller) {
  if (caller != kCorpseCallReturn || unit == nullptr) {
    return 0;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  if (!BodyWithReplacement(proto)) {
    return 0;
  }
  LogLine(unit, proto, L"fell and keeps its body; its replacement waits until the body is used up");
  return 1;
}

// From the removal notice's head: a body whose replacement waited gets it now.
void __stdcall UhcDeadReplacementOnRemove(char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  if (!BodyWithReplacement(proto) || !Bit(unit + 4, kStateBody) || Bit(unit + 4, kStateReplaced)) {
    return;
  }
  LogLine(unit, proto, L"is removed (its body used up): the replacement is placed now");
  kReplace(unit);
}

}  // extern "C"

namespace uhc {

Outcome ApplyDeadReplacementAtZeroInventory(const Config& config) {
  const Config::Args* args = config.First("deadReplacementAtZeroInventory");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"deadReplacementAtZeroInventory: unknown option %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("deadReplacementAtZeroInventory",
                 {&sites::kDeadReplacementHead, &sites::kCorpseReplacementCall, &sites::kRemovalNoticeHead,
                  &sites::kRemovalNoticeCall1, &sites::kRemovalNoticeCall2}) ||
      !WriteJmp(sites::kDeadReplacementHead.va, reinterpret_cast<const void*>(&UhcDeadReplacementHook), 7) ||
      !WriteJmp(sites::kRemovalNoticeHead.va, reinterpret_cast<const void*>(&UhcDeadReplacementRemoveHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"deadReplacementAtZeroInventory: a unit with DoNotDieAtZeroHitpoints and DieAtZeroResources leaves its "
      L"DeadReplacement when its body is used up, not when it falls%ls (multiplayer unverified)",
      g_log ? L"; each case logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
