// shipmentCounts: per-player counts of the home city shipments made in each age, for the Data subtype
// FreeHomeCityUnitByShipmentCount (with `unittype`, `includeself` and this key's `age`) and the XS syscall
// xsGetShipmentCount.
//
// A card is shipped by FUN_00858299 when its transit ends (the shipment queue's update, 0x66AEA0): it activates
// the card's tech with call 94CF27h at 0x8584FF, which applies the tech's effects there and then. The key
// redirects that call (hooks/shipmentcount_hooks.asm): before it, it notes the player and its age ([player+50h],
// what kbGetAge returns: cAge1 = 0); after it, it counts the shipment in that age. So while the card's own
// effects run, the counts do not hold it yet: `includeself` adds it.
//
// The subtype is a Player target (techsubtypes.h, AddTechPlayerSubtype). Its unittype, age and includeself are
// packed into the effect's field +10h when the techtree is read; when it applies it becomes the stock
// FreeHomeCityUnit (subtype 37h) with the proto and amount x count, so the units come the stock way (the home
// city gather point, the same checks).
//
// The counts belong to the world they were made in and restart with a new one; a saved game does not keep them.
#include <windows.h>

#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <utility>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../syscalls.h"
#include "../techsubtypes.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint32_t kShipActivateCall = 0x008584FF;
constexpr std::int32_t kFreeHomeCityUnit = 0x37;
constexpr int kPlayers = 16;
constexpr int kAges = 5;  // cAge1..cAge5; a higher age counts in the last one
constexpr std::uint32_t kProtoMask = 0x00FFFFFF;
constexpr int kAgeShift = 24;
constexpr std::uint32_t kSelfBit = 0x10000000;
constexpr std::size_t kTypeNames = 0x190;       // in the database: the unit type name table
constexpr std::size_t kFirstAbstract = 0x19B0;  // in the database: the first abstract type's ID
constexpr int kMaxLines = 200;

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
using NameBucketFn = std::int32_t(__thiscall*)(const void* table, const char* name);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
using NameFindFn = bool(__thiscall*)(const void* table, const char* name, std::int32_t bucket, std::int32_t* id);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

bool g_log = false;
int g_lines = 0;
const char* g_world = nullptr;              // the world the counts belong to
std::int32_t g_counts[kPlayers][kAges] = {};  // shipments made, by player and age

// The shipment being made: its player and age while its tech activates.
bool g_shipping = false;
std::int32_t g_shipPlayer = -1;
std::int32_t g_shipAge = 0;

void Line(const wchar_t* format, ...) {
  if (g_lines >= kMaxLines) {
    return;
  }
  wchar_t text[512];
  va_list args;
  va_start(args, format);
  _vsnwprintf_s(text, _TRUNCATE, format, args);
  va_end(args);
  ++g_lines;
  uhc::Log(L"%ls%ls", text, g_lines == kMaxLines ? L" (no more lines are logged)" : L"");
}

// The counts restart with each world: a new game, a loaded one, a scenario.
void FollowWorld() {
  const char* world = World();
  if (world != g_world) {
    g_world = world;
    std::memset(g_counts, 0, sizeof(g_counts));
    g_shipping = false;
  }
}

int AgeIndex(std::int32_t age) { return age < 0 ? 0 : (age >= kAges ? kAges - 1 : age); }

// age: -1 for every age, else cAge1 = 0 .. cAge5 = 4.
std::int32_t Count(std::int32_t player, std::int32_t age) {
  if (player < 0 || player >= kPlayers) {
    return 0;
  }
  FollowWorld();
  if (age >= 0) {
    return g_counts[player][AgeIndex(age)];
  }
  std::int32_t total = 0;
  for (int a = 0; a < kAges; ++a) {
    total += g_counts[player][a];
  }
  return total;
}

const wchar_t* TechName(std::int32_t id) {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (database == nullptr) {
    return L"?";
  }
  const wchar_t* const* names = Field<const wchar_t* const*>(database, 0x3824);
  if (names == nullptr || id < 0 || id >= Field<std::int32_t>(database, 0x3828) || names[id] == nullptr) {
    return L"?";
  }
  return names[id];
}

std::string Attribute(const char* node, const char* name) {
  const void* value = nullptr;
  if (node == nullptr || !kXmlAttribute(node, name, &value) || value == nullptr) {
    return {};
  }
  const char* text = kXmlText(value);
  return text == nullptr ? std::string() : std::string(text);
}

// While the techtree is read: unittype (a proto), includeself, age, packed into the effect's field +10h.
bool ParseEffect(void* db, char* effect, const char* node) {
  const std::string unit = Attribute(node, "unittype");
  const char* table = static_cast<const char*>(db) + kTypeNames;
  std::int32_t proto = -1;
  if (unit.empty() || !kNameFind(table, unit.c_str(), kNameBucket(table, unit.c_str()), &proto) || proto < 0 ||
      proto >= Field<std::int32_t>(static_cast<const char*>(db), kFirstAbstract) ||
      static_cast<std::uint32_t>(proto) > kProtoMask) {
    Line(L"shipmentCounts: a FreeHomeCityUnitByShipmentCount effect names %hs, which is not a proto; effect dropped",
         unit.empty() ? "no unittype" : unit.c_str());
    return false;
  }
  std::uint32_t packed = static_cast<std::uint32_t>(proto);
  const std::string age = Attribute(node, "age");
  if (!age.empty()) {
    char* end = nullptr;
    const long value = std::strtol(age.c_str(), &end, 10);
    if (end == age.c_str() || *end != 0 || value < 1 || value > kAges) {
      Line(L"shipmentCounts: age=\"%hs\" is not 1 to %d (Age I to V); effect dropped", age.c_str(), kAges);
      return false;
    }
    packed |= static_cast<std::uint32_t>(value) << kAgeShift;
  }
  const std::string self = Attribute(node, "includeself");
  if (_stricmp(self.c_str(), "true") == 0 || self == "1") {
    packed |= kSelfBit;
  }
  *reinterpret_cast<std::uint32_t*>(effect + 0x10) = packed;
  return true;
}

// When the effect applies: the stock FreeHomeCityUnit with amount x the count.
std::int32_t RunEffect(char* player, std::int32_t* field, float* amount) {
  const auto packed = static_cast<std::uint32_t>(*field);
  const std::int32_t proto = static_cast<std::int32_t>(packed & kProtoMask);
  const int age = static_cast<int>((packed >> kAgeShift) & 0xF);  // 0: every age, 1..5: Age I..V
  const bool self = (packed & kSelfBit) != 0;
  const std::int32_t playerId = Field<std::int32_t>(player, 0x00);
  std::int32_t count = Count(playerId, age - 1);
  const bool current = self && g_shipping && g_shipPlayer == playerId && (age == 0 || g_shipAge == age - 1);
  if (current) {
    ++count;
  }
  const float units = *amount * static_cast<float>(count);
  if (g_log) {
    Line(L"shipmentCounts: player %d, FreeHomeCityUnitByShipmentCount proto %d, %ls%ls: %d shipment(s)%ls x %.2f = "
         L"%.2f unit(s)",
         playerId, proto, age == 0 ? L"every age" : L"age ", age == 0 ? L"" : std::to_wstring(age).c_str(), count,
         current ? L" (this one included)" : L"", *amount, units);
  }
  if (!(units >= 1.0f)) {
    return uhc::kPlayerSubtypeDone;  // nothing to send
  }
  *field = proto;
  *amount = units;
  return kFreeHomeCityUnit;
}

// XS: int xsGetShipmentCount(int playerID, int age): age cAge1..cAge5, or -1 for every age.
std::int32_t __cdecl XsGetShipmentCount(std::int32_t player, std::int32_t age) {
  if (age < -1) {
    return 0;
  }
  return Count(player, age);
}

}  // namespace

extern "C" {

void UhcShipActivateHook();  // hooks/shipmentcount_hooks.asm

// Before the card's tech activates: entry = its status entry, player = the shipping player.
void __stdcall UhcShipBegin(const char* entry, const char* player) {
  if (player == nullptr) {
    return;
  }
  FollowWorld();
  g_shipping = true;
  g_shipPlayer = Field<std::int32_t>(player, 0x00);
  g_shipAge = AgeIndex(Field<std::int32_t>(player, 0x50));
  if (g_log) {
    const char* def = entry == nullptr ? nullptr : Field<const char*>(entry, 0x00);
    const std::int32_t tech = def == nullptr ? -1 : Field<std::int32_t>(def, 0x00);
    Line(L"shipmentCounts: player %d ships tech %d (%ls) in age %d", g_shipPlayer, tech, TechName(tech),
         g_shipAge + 1);
  }
}

// After it: the shipment counts.
void __stdcall UhcShipEnd() {
  if (!g_shipping) {
    return;
  }
  g_shipping = false;
  if (g_shipPlayer < 0 || g_shipPlayer >= kPlayers) {
    return;
  }
  ++g_counts[g_shipPlayer][g_shipAge];
  if (g_log) {
    const std::int32_t* c = g_counts[g_shipPlayer];
    Line(L"shipmentCounts: player %d has shipped %d, %d, %d, %d, %d in ages I to V", g_shipPlayer, c[0], c[1], c[2],
         c[3], c[4]);
  }
}
}

namespace uhc {

Outcome ApplyShipmentCounts(const Config& config) {
  const Config::Args* args = config.First("shipmentCounts");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"shipmentCounts: unexpected argument %hs (expected: [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("shipmentCounts", {&sites::kShipActivateCall, &sites::kShipQueueCaller,
                                    &sites::kFreeHomeCityUnitCase})) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!AddTechPlayerSubtype("FreeHomeCityUnitByShipmentCount", &ParseEffect, &RunEffect) ||
      !InstallSyscallHooks("shipmentCounts")) {
    return Outcome::kFailed;
  }
  SyscallDef def;
  def.group = SyscallGroup::kXs;
  def.retType = kSyscallInt;
  def.name = "xsGetShipmentCount";
  def.fn = reinterpret_cast<const void*>(&XsGetShipmentCount);
  def.comment = "int xsGetShipmentCount(int playerID, int age): the home city shipments the player made in that age "
                "(cAge1..cAge5), or in every age with -1, in this game.";
  SyscallParam player;
  player.type = kSyscallInt;
  player.intValue = -1;
  SyscallParam age;
  age.type = kSyscallInt;
  age.intValue = -1;
  def.params = {player, age};
  def.source = "shipmentCounts";
  AddSyscall(std::move(def));
  if (!WriteCall(kShipActivateCall, reinterpret_cast<const void*>(&UhcShipActivateHook))) {
    return Outcome::kFailed;
  }
  Log(L"shipmentCounts: shipments are counted per player and age; the Data subtype FreeHomeCityUnitByShipmentCount "
      L"and the XS syscall xsGetShipmentCount read them%ls (multiplayer unverified)",
      log ? L"; each shipment and each effect is logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
