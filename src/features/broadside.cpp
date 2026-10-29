// broadsideMuzzleLimit: more cannons per side in a ship's broadside.
//
// A BroadsideAttack action (protoaction type 29h: the normal ranged attack of most ships, and the
// actions of PowerBroadside and the ironclad's long-range power) gives each muzzle of its owner's
// model a firing slot when the action is set up, in FUN_0050339A: one slot per MuzzleR attach
// point, then one per MuzzleL point. Each group is clamped to 6 (`mov esi,6` at 0x5033D5), or to
// 1 when the action has <SingleUsePlayer> (cold block 0x6A8236). A volley fires one projectile per
// slot, so a stock ship fires at most 6 per side whatever its model has (the Tekkousen's has 10).
//
// broadsideMuzzleLimit <N> [<UnitType>] [log] replaces the 6 with N (1..255: the muzzle index is
// passed on as a byte) for ships whose proto has <UnitType> (a marker, a stock type or a proto
// name), or for every ship when no type is given. The model still decides how many muzzles there
// are, and <SingleUsePlayer> actions keep 1. The hooks are in hooks/broadside_hooks.asm.
#include <charconv>
#include <cstdint>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr int kMinLimit = 1;
constexpr int kMaxLimit = 255;  // 0x4A98F8 reads the muzzle index of a slot as a byte
constexpr int kMaxLogLines = 500;

int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* ProtoName(const char* unit) {
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

bool ParseLimit(const std::string& text, std::int32_t* limit) {
  int value = 0;
  const auto [end, ec] = std::from_chars(text.data(), text.data() + text.size(), value);
  if (ec != std::errc() || end != text.data() + text.size() || value < kMinLimit || value > kMaxLimit) {
    return false;
  }
  *limit = value;
  return true;
}

}  // namespace

extern "C" {
std::int32_t g_uhcBroadsideType = -1;    // marker unittype ID, set on each database load
std::int32_t g_uhcBroadsideAll = 0;      // 1 when no UnitType is given: every ship
std::int32_t g_uhcBroadsideLimit = 6;    // muzzles per side
const char* g_uhcBroadsideAction = nullptr;  // the action whose limit the hook set last (for "log")

void UhcBroadsideLimitHook();
void UhcBroadsideLogHook();

// Called by the log hook at the MuzzleL clamp of an action whose limit the first hook set:
// [action+80h] already holds its MuzzleR slots; leftMuzzles is the model's MuzzleL count (0 or -1
// without a model) and limit the clamp it is about to get. An action is set up when it is created,
// but the lines are capped in case something sets actions up far more often.
void __stdcall UhcBroadsideLogSetup(const char* action, std::int32_t leftMuzzles, std::int32_t limit) {
  if (g_logLines > kMaxLogLines) {
    return;
  }
  if (++g_logLines > kMaxLogLines) {
    uhc::Log(L"broadsideMuzzleLimit: %d broadside set-ups logged; the next ones are not", kMaxLogLines);
    return;
  }
  const char* unit = Field<const char*>(action, 0x10);
  const std::int32_t left = leftMuzzles <= 0 ? 0 : (leftMuzzles < limit ? leftMuzzles : limit);
  uhc::Log(L"broadsideMuzzleLimit: unit %d (%hs) has %d right and %d left muzzle slots (limit %d per side)",
           unit == nullptr ? -1 : Field<std::int32_t>(unit, 0x10), ProtoName(unit), Field<std::int32_t>(action, 0x80),
           left, limit);
}
}

namespace uhc {

Outcome ApplyBroadsideMuzzleLimit(const Config& config) {
  const auto* lines = config.All("broadsideMuzzleLimit");
  if (lines == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (lines->size() != 1) {
    Log(L"broadsideMuzzleLimit: %u lines, expected one; feature not applied", static_cast<unsigned>(lines->size()));
    return Outcome::kFailed;
  }
  const Config::Args& args = lines->front();
  std::int32_t limit = 0;
  if (args.empty() || !ParseLimit(args.front(), &limit)) {
    Log(L"broadsideMuzzleLimit: expected \"broadsideMuzzleLimit <N> [UnitType] [log]\" with N from %d to %d, "
        L"got \"%hs\"; feature not applied",
        kMinLimit, kMaxLimit, args.empty() ? "" : args.front().c_str());
    return Outcome::kFailed;
  }
  std::string typeName;
  bool log = false;
  for (std::size_t i = 1; i < args.size(); ++i) {
    if (_stricmp(args[i].c_str(), "log") == 0) {
      log = true;
    } else if (typeName.empty()) {
      typeName = args[i];
    } else {
      Log(L"broadsideMuzzleLimit: unexpected argument %hs (expected: <N> [UnitType] [log]); feature not applied",
          args[i].c_str());
      return Outcome::kFailed;
    }
  }

  if (!VerifyAll("broadsideMuzzleLimit",
                 {&sites::kBroadsideInitHead, &sites::kBroadsideMuzzleCap, &sites::kBroadsideMuzzleClampR,
                  &sites::kBroadsideMuzzleReload, &sites::kBroadsideMuzzleClampL, &sites::kBroadsideSingleUseCap,
                  &sites::kBroadsideClampCold})) {
    return Outcome::kFailed;
  }

  g_uhcBroadsideLimit = limit;
  g_uhcBroadsideAll = typeName.empty() ? 1 : 0;
  if (!typeName.empty() && !RequestAbstractUnitType(typeName.c_str(), &g_uhcBroadsideType)) {
    return Outcome::kFailed;
  }
  // mov esi,6 at 0x5033D5, six bytes into the site.
  if (!WriteJmp(sites::kBroadsideMuzzleCap.va + 6, reinterpret_cast<const void*>(&UhcBroadsideLimitHook), 5)) {
    return Outcome::kFailed;
  }
  // The MuzzleL clamp, cmp eax,esi / mov [esp+1Ch],eax (6 bytes) before the jg at 0x5034E8.
  if (log && !WriteJmp(sites::kBroadsideMuzzleClampL.va, reinterpret_cast<const void*>(&UhcBroadsideLogHook), 6)) {
    return Outcome::kFailed;
  }
  if (typeName.empty()) {
    Log(L"broadsideMuzzleLimit: every ship uses up to %d muzzles per side in a broadside (stock 6; "
        L"SingleUsePlayer attacks keep 1)%ls (multiplayer unverified)",
        limit, log ? L", every set-up logged" : L"");
  } else {
    Log(L"broadsideMuzzleLimit: ships of unittype %hs use up to %d muzzles per side in a broadside (stock 6; "
        L"SingleUsePlayer attacks keep 1)%ls (multiplayer unverified)",
        typeName.c_str(), limit, log ? L", every set-up logged" : L"");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
