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
//
// More projectiles than muzzles: a BroadsideAttack action with <NumberProjectiles>P</NumberProjectiles> (or
// <NumberOfProjectiles>; a tag stock does not read) gets P firing slots per side when the model has fewer, the
// muzzles taken in turn (slot i fires from muzzle i mod the side's count). This is how an ability (a power that
// runs a BroadsideAttack, such as a long-range bombardment) fires more shots than its ship has cannons; a smaller P
// changes nothing. The set-up FUN_0050339A is reached only through its vtable slot 0xB962EC (BroadsideAttack's
// slot 1), which points at a wrapper: the stock set-up, then the slots are added with the arrays' own resize
// (0x401113) to the muzzle array [+68h] and the fire-time array [+74h], and [+80h], the right side's count, grows.
// The schedule 0x4CEE48 gives slot i and slot i + [+80h] the same time, so both sides get P.
#include <charconv>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <map>
#include <string>
#include <utility>
#include <vector>

#include "../actiontags.h"
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
bool g_log = false;

constexpr std::uint32_t kSetupSlot = 0x00B962EC;  // BroadsideAttack's vtable slot 1: the set-up FUN_0050339A
using SetupFn = void(__thiscall*)(char* action, std::int32_t arg);
const auto kSetup = reinterpret_cast<SetupFn>(0x0050339A);
using ResizeFn = bool(__thiscall*)(char* array, std::int32_t count, std::uint8_t keep);
const auto kResize = reinterpret_cast<ResizeFn>(0x00401113);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

// <NumberProjectiles> per {proto ID, action name index}, as numberOfShots keys its tags; filled while the data loads.
std::map<std::pair<std::int32_t, std::int32_t>, std::int32_t> g_projectiles;

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
extern std::int32_t g_uhcBroadsideType;
extern std::int32_t g_uhcBroadsideAll;
}

namespace {

void ForgetProjectiles(char*) { g_projectiles.clear(); }

void ReadProjectiles(const uhc::ActionTag& tag) {
  if (_wcsicmp(tag.name, L"NumberProjectiles") != 0 && _wcsicmp(tag.name, L"NumberOfProjectiles") != 0) {
    return;
  }
  const std::int32_t name = Field<std::int32_t>(tag.action, 0x04);
  if (name < 0 || tag.text == nullptr) {
    return;
  }
  wchar_t* end = nullptr;
  const long value = std::wcstol(tag.text, &end, 10);
  while (end != nullptr && (*end == L' ' || *end == L'\t' || *end == L'\r' || *end == L'\n')) {
    ++end;
  }
  if (end == tag.text || end == nullptr || *end != L'\0' || value < 1 || value > kMaxLimit) {
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"broadsideMuzzleLimit: proto %d, action %d: <%ls>%ls</%ls> is not a whole number from 1 to %d; ignored",
               Field<std::int32_t>(tag.proto, 0x04), name, tag.name, tag.text, tag.name, kMaxLimit);
    }
    return;
  }
  g_projectiles[{Field<std::int32_t>(tag.proto, 0x04), name}] = static_cast<std::int32_t>(value);
}

// The muzzle indices of one side's slots, taken in turn up to `want` slots.
std::vector<std::int32_t> Side(const std::int32_t* muzzles, std::int32_t count, std::int32_t want) {
  std::vector<std::int32_t> out;
  for (std::int32_t i = 0; count > 0 && i < (want > count ? want : count); ++i) {
    out.push_back(muzzles[i % count]);
  }
  return out;
}

// After the stock set-up: P slots per side for an action of a ship the limit applies to.
void AddSlots(char* action) {
  if (g_projectiles.empty()) {
    return;
  }
  const char* protoAction = Field<const char*>(action, 0x04);
  const char* unit = Field<const char*>(action, 0x10);
  const char* proto = unit == nullptr ? nullptr : Field<const char*>(unit, 0x5C);
  // The ships the limit applies to, as the limit hook decides (its g_uhcBroadsideAction is cleared by the log hook).
  if (protoAction == nullptr || proto == nullptr ||
      (g_uhcBroadsideAll == 0 && (g_uhcBroadsideType < 0 || !kProtoIsType(proto, g_uhcBroadsideType)))) {
    return;
  }
  const auto found = g_projectiles.find({Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(protoAction, 0x04)});
  const std::int32_t total = Field<std::int32_t>(action, 0x6C);
  const std::int32_t right = Field<std::int32_t>(action, 0x80);
  const std::int32_t left = total - right;
  if (found == g_projectiles.end() || right < 0 || left < 0 || Field<std::int32_t>(action, 0x78) != total ||
      (found->second <= right && found->second <= left)) {
    return;
  }
  const std::int32_t* muzzles = Field<const std::int32_t*>(action, 0x68);
  const std::vector<std::int32_t> r = Side(muzzles, right, found->second);
  const std::vector<std::int32_t> l = Side(muzzles + right, left, found->second);
  // The schedule gives a left slot the time of the right slot with its index; a left side longer than the right
  // would leave its last slots without a time (never fired), as stock never makes one.
  const std::int32_t rightCount = static_cast<std::int32_t>(r.size());
  const std::int32_t leftCount = static_cast<std::int32_t>(l.size() <= r.size() ? l.size() : r.size());
  const std::int32_t newTotal = rightCount + leftCount;
  if (!kResize(action + 0x68, newTotal, 0) || !kResize(action + 0x74, newTotal, 0)) {
    return;
  }
  auto* slots = Field<std::int32_t*>(action, 0x68);
  auto* times = Field<std::int32_t*>(action, 0x74);
  for (std::int32_t i = 0; i < newTotal; ++i) {
    slots[i] = i < rightCount ? r[i] : l[i - rightCount];
    times[i] = 0;
  }
  *reinterpret_cast<std::int32_t*>(action + 0x80) = rightCount;
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"broadsideMuzzleLimit: unit %d (%hs), action %d: %d projectiles per side over %d right and %d left muzzles: "
             L"%d and %d slots",
             Field<std::int32_t>(unit, 0x10), ProtoName(unit), Field<std::int32_t>(protoAction, 0x04), found->second,
             right, left, rightCount, leftCount);
  }
}

// BroadsideAttack's set-up, thiscall(action, arg), through its vtable slot.
void __fastcall SetupWrapper(char* action, void*, std::int32_t arg) {
  kSetup(action, arg);
  AddSlots(action);
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
      g_log = true;
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
                  &sites::kBroadsideClampCold, &sites::kBroadsideSetupSlot, &sites::kArrayResize})) {
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
  // <NumberProjectiles>: the tag, and the set-up's vtable slot.
  if (!OnDatabaseLoad(&ForgetProjectiles) || !AddActionTagHandler(&ReadProjectiles) ||
      !WriteDword(kSetupSlot, static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(&SetupWrapper)))) {
    return Outcome::kFailed;
  }
  if (typeName.empty()) {
    Log(L"broadsideMuzzleLimit: every ship uses up to %d muzzles per side in a broadside (stock 6; "
        L"SingleUsePlayer attacks keep 1), and <NumberProjectiles> fires that many per side over its muzzles%ls "
        L"(multiplayer unverified)",
        limit, log ? L", every set-up logged" : L"");
  } else {
    Log(L"broadsideMuzzleLimit: ships of unittype %hs use up to %d muzzles per side in a broadside (stock 6; "
        L"SingleUsePlayer attacks keep 1), and <NumberProjectiles> fires that many per side over its muzzles%ls "
        L"(multiplayer unverified)",
        typeName.c_str(), limit, log ? L", every set-up logged" : L"");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
