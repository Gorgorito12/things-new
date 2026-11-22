// shipmentCounts: per-player counts of the home city shipments, by the age of each card (its <age>, the age that
// enables it), for the Data subtype FreeHomeCityUnitByShipmentCount (with `unittype`, `includeself` and this key's
// `age`, one age or a range) and the XS syscalls xsGetShipmentCount and xsGetShipmentCountRange.
//
// A card is sent by FUN_0085A724: it checks the card's age [card+18h] against the player's ([player+50h]), pays,
// then appends an entry {card index, tech ID, ...} to the home city's shipment queue ([hc+288h], entries of 18h).
// The card is shipped later by FUN_00858299 when its transit ends (the queue update 0x4BF86F): it activates the
// card's tech with call 94CF27h at 0x8584FF, which applies the tech's effects there and then. A queued card can
// also be cancelled, by the player or by a Blockade; a cancelled card never ships.
//
// So a card counts when it ships, in the age of the card: the redirected activation call reads the shipping
// entry's card index (+0), finds the card with FUN_0085FFCE(hc+228h, index), as the send and the shipment do, and
// takes its age [card+18h] (the scale of [player+50h] and kbGetAge: Age I = 0; -1, a card with no <age>, counts in
// Age I). The card's effects run with the shipment current, then it is counted. While the card's own effects run
// the counts do not hold it yet: `includeself` adds it.
//
// Saved games: the counts are kept on one unit of the world as saved markers (savedmarkers.h, stat 67h): per
// player one marker with the five counts (16 bits each). A world tick writes them when they change and moves them
// to another unit when theirs dies, transforms or loses them, so the markers are on a living unit at every save. A
// game that starts or loads reads them back (one walk over the units). Older builds also kept a second marker kind
// (2) with the send ages of the queued cards; a save that has one loads, the marker is ignored and dropped at the
// next write.
//
// The subtype is a Player target (techsubtypes.h, AddTechPlayerSubtype). Its unittype, age range and includeself
// are packed into the effect's field +10h when the techtree is read; when it applies it becomes the stock
// FreeHomeCityUnit (subtype 37h) with the proto and amount x count, so the units come the stock way (the home
// city gather point, the same checks).
#include <windows.h>

#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <utility>

#include "../features.h"
#include "../unitinfo.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../savedmarkers.h"
#include "../syscalls.h"
#include "../techsubtypes.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint32_t kShipActivateCall = 0x008584FF;
constexpr std::int32_t kFreeHomeCityUnit = 0x37;
constexpr int kPlayers = 16;
constexpr int kAges = 5;  // cAge1..cAge5; a higher age counts in the last one
constexpr std::uint32_t kProtoMask = 0x00FFFFFF;
constexpr int kFirstAgeShift = 24;  // bits 24..26: the first age of the range, 1..5 (0: every age)
constexpr std::uint32_t kSelfBit = 0x10000000;
constexpr int kLastAgeShift = 29;   // bits 29..31: the last age of the range, 1..5
constexpr std::size_t kTypeNames = 0x190;       // in the database: the unit type name table
constexpr std::size_t kFirstAbstract = 0x19B0;  // in the database: the first abstract type's ID
constexpr int kMaxLines = 200;

// The home city, its cards and its shipment queue.
constexpr std::uint32_t kPlayerAge = 0x50;     // the player's age, cAge1 = 0
constexpr std::uint32_t kHcCards = 0x228;      // the card list: FUN_0085FFCE(list, index) -> card, 28h each
constexpr std::uint32_t kCardAge = 0x18;       // the card's <age>, cAge1 = 0, -1 with none
constexpr std::uint32_t kHcQueue = 0x288;      // entries; +28Ch count
constexpr std::uint32_t kQueueEntrySize = 0x18;  // +0 card index, +4 tech ID

// Saved markers (savedmarkers.h): word 0 is 'SC' << 16 | player << 8 | kind.
constexpr std::int32_t kStat = 0x67;
constexpr std::uint32_t kTag = 0x53430000;
constexpr std::uint32_t kTagMask = 0xFFFF0000;
constexpr std::uint32_t kKindCounts = 1;  // words 1..3: the counts of ages I..V, 16 bits each
constexpr std::uint32_t kKindOldAges = 2; // older builds: the send ages of the queued cards; ignored, dropped

using CardOfFn = const char*(__thiscall*)(const void* list, std::int32_t index);
const auto kCardOf = reinterpret_cast<CardOfFn>(0x0085FFCE);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
using NameBucketFn = std::int32_t(__thiscall*)(const void* table, const char* name);
const auto kNameBucket = reinterpret_cast<NameBucketFn>(0x0058E685);
using NameFindFn = bool(__thiscall*)(const void* table, const char* name, std::int32_t bucket, std::int32_t* id);
const auto kNameFind = reinterpret_cast<NameFindFn>(0x0040295B);
using UnitTestFn = bool(__thiscall*)(const char* unit);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

struct PlayerState {
  std::int32_t counts[kAges];
};

bool g_log = false;
int g_lines = 0;
const char* g_world = nullptr;  // the world the counts belong to
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
PlayerState g_state[kPlayers];
bool g_dirty = false;                 // the markers need writing
std::int32_t g_carrier = -1;          // the unit that holds the markers
std::uint32_t g_carrierWord = 0;      // word 0 of one of its markers

// The shipment being made: its player and its card's age while its tech activates.
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

int AgeIndex(std::int32_t age) { return age < 0 ? 0 : (age >= kAges ? kAges - 1 : age); }

// The name of an age index 0..4 in the log: Age I..Age V.
const wchar_t* AgeName(int index) {
  static const wchar_t* const kNames[kAges] = {L"I", L"II", L"III", L"IV", L"V"};
  return kNames[AgeIndex(index)];
}

// --- Units and players --------------------------------------------------------------------------------------

char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

bool IsAlive(const char* unit) { return (*reinterpret_cast<UnitTestFn const* const*>(unit))[0xA4 / 4](unit); }

bool IsDead(const char* unit) {  // state bit 11: the kill handler returns at once
  const auto* bits = Field<const std::uint8_t*>(unit, 4);
  return bits != nullptr && Field<std::uint32_t>(unit, 8) > 11 && (bits[1] & 0x08) != 0;
}

std::int32_t OwnerOf(const char* unit) {
  const char* owner = Field<const char*>(unit, 0x44);
  return owner == nullptr ? -1 : Field<std::int32_t>(owner, 0);
}

std::int32_t QueueCount(const char* hc) { return Field<std::int32_t>(hc, kHcQueue + 4); }

// The <age> of the card of a shipment queue entry of that home city (cAge1 = 0, -1 with none), or -2 if the entry
// or its card is not found.
std::int32_t CardAge(const char* hc, const char* shipment) {
  if (hc == nullptr || shipment == nullptr) {
    return -2;
  }
  const char* base = Field<const char*>(hc, kHcQueue);
  if (base == nullptr || shipment < base) {
    return -2;
  }
  const auto offset = static_cast<std::uint32_t>(shipment - base);
  if (offset % kQueueEntrySize != 0 || static_cast<std::int32_t>(offset / kQueueEntrySize) >= QueueCount(hc)) {
    return -2;
  }
  const char* card = kCardOf(hc + kHcCards, Field<std::int32_t>(shipment, 0));
  return card == nullptr ? -2 : Field<std::int32_t>(card, kCardAge);
}

// --- Saved markers ------------------------------------------------------------------------------------------

std::uint32_t MarkerWord(std::int32_t player, std::uint32_t kind) {
  return kTag | (static_cast<std::uint32_t>(player) << 8) | kind;
}

bool IsOurs(char* marker) { return (uhc::markers::Word(marker, 0) & kTagMask) == kTag; }

void FreeOurs(char* unit) {
  uhc::markers::ForEach(unit, kStat, [](char* marker) {
    if (IsOurs(marker)) {
      uhc::markers::Free(marker);
    }
    return true;
  });
}

bool HasState(int player) {
  for (const std::int32_t count : g_state[player].counts) {
    if (count != 0) {
      return true;
    }
  }
  return false;
}

bool CarrierValid(const char* world) {
  char* unit = UnitById(world, g_carrier);
  return unit != nullptr && IsAlive(unit) && !IsDead(unit) &&
         uhc::markers::Find(unit, kStat, g_carrierWord) != nullptr;
}

// A living unit that takes a marker, a player's first; nullptr if none.
char* PickCarrier(const char* world) {
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  for (int pass = 0; pass < 2; ++pass) {
    for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
      char* unit = table[i];
      if (unit == nullptr || (pass == 0 && OwnerOf(unit) < 1) || !IsAlive(unit) || IsDead(unit)) {
        continue;
      }
      if (char* marker = uhc::markers::Take(unit, kStat)) {
        uhc::markers::Free(marker);  // a free marker of the stat, reused by the write
        return unit;
      }
    }
  }
  return nullptr;
}

bool WriteMarker(char* unit, std::uint32_t word0, const std::uint32_t (&words)[3]) {
  char* marker = uhc::markers::Take(unit, kStat);
  if (marker == nullptr) {
    return false;
  }
  uhc::markers::Word(marker, 0) = word0;
  for (int w = 0; w < 3; ++w) {
    uhc::markers::Word(marker, w + 1) = words[w];
  }
  return true;
}

// Writes every player's counts on the carrier, a new one if it is gone.
void WriteMarkers(const char* world) {
  bool any = false;
  for (int p = 0; p < kPlayers; ++p) {
    any = any || HasState(p);
  }
  char* unit = UnitById(world, g_carrier);
  const bool keep = unit != nullptr && IsAlive(unit) && !IsDead(unit);
  if (unit != nullptr) {
    FreeOurs(unit);
  }
  if (!any) {
    g_carrier = -1;
    g_dirty = false;
    return;
  }
  if (!keep) {
    unit = PickCarrier(world);
    if (unit == nullptr) {
      return;  // no unit to hold them: try again at the next tick
    }
  }
  std::uint32_t first = 0;
  bool ok = true;
  for (int p = 0; p < kPlayers && ok; ++p) {
    const PlayerState& state = g_state[p];
    if (!HasState(p)) {
      continue;
    }
    std::uint32_t counts[3] = {};
    for (int a = 0; a < kAges; ++a) {
      const std::uint32_t c = state.counts[a] > 0xFFFF ? 0xFFFF : static_cast<std::uint32_t>(state.counts[a]);
      counts[a / 2] |= c << (16 * (a % 2));
    }
    ok = WriteMarker(unit, MarkerWord(p, kKindCounts), counts);
    first = first != 0 ? first : MarkerWord(p, kKindCounts);
  }
  if (!ok) {
    FreeOurs(unit);
    return;  // try again at the next tick
  }
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (g_log && id != g_carrier) {
    Line(L"shipmentCounts: the counts are kept on unit %d", id);
  }
  g_carrier = id;
  g_carrierWord = first;
  g_dirty = false;
}

// A game that just started or loaded: the counts its markers keep. One walk.
void Rebuild(const char* world) {
  for (PlayerState& state : g_state) {
    std::memset(state.counts, 0, sizeof(state.counts));
  }
  g_shipping = false;
  g_carrier = -1;
  g_carrierWord = 0;
  g_dirty = false;
  bool oldAges = false;
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  int carriers = 0;
  for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
    char* unit = table[i];
    if (unit == nullptr) {
      continue;
    }
    bool found = false;
    uhc::markers::ForEach(unit, kStat, [&](char* marker) {
      if (!IsOurs(marker)) {
        return true;
      }
      const std::uint32_t word0 = uhc::markers::Word(marker, 0);
      const int player = static_cast<int>((word0 >> 8) & 0xFF);
      const std::uint32_t kind = word0 & 0xFF;
      if (player >= kPlayers) {
        return true;
      }
      found = true;
      if (kind == kKindCounts) {
        for (int a = 0; a < kAges; ++a) {
          g_state[player].counts[a] =
              static_cast<std::int32_t>((uhc::markers::Word(marker, 1 + a / 2) >> (16 * (a % 2))) & 0xFFFF);
        }
        g_carrierWord = word0;
      } else if (kind == kKindOldAges) {
        oldAges = true;  // an older build's send ages: not used, dropped by the next write
      }
      return true;
    });
    if (found) {
      ++carriers;
      g_carrier = Field<std::int32_t>(unit, 0x10);
    }
  }
  if (oldAges) {
    g_dirty = true;
    Line(L"shipmentCounts: loaded a save of an older build: the send ages it kept are not used, a card counts in "
         L"the age of the card");
  }
  if (carriers > 1) {
    g_dirty = true;  // markers on two units: the next write keeps one set
    for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
      if (table[i] != nullptr && Field<std::int32_t>(table[i], 0x10) != g_carrier) {
        FreeOurs(table[i]);
      }
    }
  }
  if (carriers > 0) {
    for (int p = 0; p < kPlayers; ++p) {
      if (!HasState(p)) {
        continue;
      }
      const PlayerState& s = g_state[p];
      Line(L"shipmentCounts: loaded: player %d has shipped %d, %d, %d, %d, %d cards of ages I to V", p, s.counts[0],
           s.counts[1], s.counts[2], s.counts[3], s.counts[4]);
    }
  }
}

// The counts follow the world: a new game, a loaded one, a scenario rebuilds them from its markers.
void Sync() {
  const char* world = World();
  if (world == nullptr) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  const bool sameGame = world == g_world && now >= g_lastTime && step - g_lastStep <= 1;
  if (!sameGame) {
    g_world = world;
    Rebuild(world);
  }
  g_lastTime = now;
  g_lastStep = step;
}

void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  Sync();
  if (g_dirty || (g_carrier >= 0 && !CarrierValid(world))) {
    WriteMarkers(world);
  }
}

// --- Counts -------------------------------------------------------------------------------------------------

// Ages first..last, cAge1 = 0 .. cAge5 = 4.
std::int32_t Count(std::int32_t player, std::int32_t first, std::int32_t last) {
  if (player < 0 || player >= kPlayers) {
    return 0;
  }
  Sync();
  std::int32_t total = 0;
  for (int a = AgeIndex(first); a <= AgeIndex(last); ++a) {
    total += g_state[player].counts[a];
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

// age="N": one age, 0..4 (Age I to V, the scale of a card's <age> and of cAge1..cAge5); age="NM": two digits, the
// ages N to M, N <= M (age="13": Ages II to IV). Out: the first and last age, 1..5 (Age I to V), as packed.
bool ParseAgeRange(const std::string& text, long* first, long* last) {
  const std::size_t n = text.size();
  if (n < 1 || n > 2) {
    return false;
  }
  for (const char c : text) {
    if (c < '0' || c > static_cast<char>('0' + kAges - 1)) {
      return false;
    }
  }
  *first = text[0] - '0' + 1;
  *last = text[n - 1] - '0' + 1;
  return *first <= *last;
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
    long first = 0;
    long last = 0;
    if (!ParseAgeRange(age, &first, &last)) {
      Line(L"shipmentCounts: age=\"%hs\" is not an age 0 to %d (Age I to V) or two of them for a range, first <= last, "
           L"with no hyphen (13: Ages II to IV); effect dropped",
           age.c_str(), kAges - 1);
      return false;
    }
    packed |= static_cast<std::uint32_t>(first) << kFirstAgeShift;
    packed |= static_cast<std::uint32_t>(last) << kLastAgeShift;
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
  const int first = static_cast<int>((packed >> kFirstAgeShift) & 0x7);  // 0: every age, 1..5: Age I..V (age="0".."4")
  const int last = first == 0 ? kAges : static_cast<int>((packed >> kLastAgeShift) & 0x7);
  const int lo = first == 0 ? 0 : first - 1;
  const int hi = last - 1;
  const bool self = (packed & kSelfBit) != 0;
  const std::int32_t playerId = Field<std::int32_t>(player, 0x00);
  std::int32_t count = Count(playerId, lo, hi);
  const bool current = self && g_shipping && g_shipPlayer == playerId && g_shipAge >= lo && g_shipAge <= hi;
  if (current) {
    ++count;
  }
  const float units = *amount * static_cast<float>(count);
  if (g_log) {
    wchar_t ages[48];
    if (first == 0) {
      wcscpy_s(ages, L"every age");
    } else if (first == last) {
      swprintf_s(ages, L"age=\"%d\" (Age %ls)", lo, AgeName(lo));
    } else {
      swprintf_s(ages, L"age=\"%d%d\" (Ages %ls to %ls)", lo, hi, AgeName(lo), AgeName(hi));
    }
    Line(L"shipmentCounts: player %d, FreeHomeCityUnitByShipmentCount proto %d, %ls: %d shipment(s)%ls x %.2f = "
         L"%.2f unit(s)",
         playerId, proto, ages, count, current ? L" (this one included)" : L"", *amount, units);
  }
  if (!(units >= 1.0f)) {
    return uhc::kPlayerSubtypeDone;  // nothing to send
  }
  *field = proto;
  *amount = units;
  return kFreeHomeCityUnit;
}

bool ValidAge(std::int32_t age) { return age >= 0 && age < kAges; }

// XS: int xsGetShipmentCount(int playerID, int age): age cAge1..cAge5, or -1 for every age.
std::int32_t __cdecl XsGetShipmentCount(std::int32_t player, std::int32_t age) {
  if (age == -1) {
    return Count(player, 0, kAges - 1);
  }
  return ValidAge(age) ? Count(player, age, age) : 0;
}

// XS: int xsGetShipmentCountRange(int playerID, int firstAge, int lastAge): ages cAge1..cAge5, first <= last.
std::int32_t __cdecl XsGetShipmentCountRange(std::int32_t player, std::int32_t first, std::int32_t last) {
  return ValidAge(first) && ValidAge(last) && first <= last ? Count(player, first, last) : 0;
}

}  // namespace

extern "C" {

void UhcShipActivateHook();  // hooks/shipmentcount_hooks.asm

// Before the card's tech activates: entry = its status entry, player = the shipping player, hc = its home city,
// shipment = the queue entry being shipped. The shipment counts in the age of its card.
void __stdcall UhcShipBegin(const char* entry, const char* player, const char* hc, const char* shipment) {
  if (player == nullptr) {
    return;
  }
  Sync();
  g_shipping = true;
  g_shipPlayer = Field<std::int32_t>(player, 0x00);
  const std::int32_t card = CardAge(hc, shipment);
  g_shipAge = AgeIndex(card);  // -1 (no <age>) counts in Age I; -2 (not found) too, logged
  if (g_log) {
    const char* def = entry == nullptr ? nullptr : Field<const char*>(entry, 0x00);
    const std::int32_t tech = def == nullptr ? -1 : Field<std::int32_t>(def, 0x00);
    const std::int32_t now = AgeIndex(Field<std::int32_t>(player, kPlayerAge));
    Line(L"shipmentCounts: player %d ships tech %d (%ls), a card of Age %ls%ls, in Age %ls", g_shipPlayer, tech,
         TechName(tech), AgeName(g_shipAge),
         card == -1 ? L" (it has no <age>)" : (card < -1 ? L" (its card was not found)" : L""), AgeName(now));
  }
}

// After it: the shipment counts, in the age of its card.
void __stdcall UhcShipEnd() {
  if (!g_shipping) {
    return;
  }
  g_shipping = false;
  if (g_shipPlayer < 0 || g_shipPlayer >= kPlayers) {
    return;
  }
  ++g_state[g_shipPlayer].counts[g_shipAge];
  g_dirty = true;
  if (g_log) {
    const std::int32_t* c = g_state[g_shipPlayer].counts;
    Line(L"shipmentCounts: player %d has shipped %d, %d, %d, %d, %d in ages I to V", g_shipPlayer, c[0], c[1], c[2],
         c[3], c[4]);
  }
}
}

namespace {
bool g_unitInfoOn = false;  // the key applied: unitinfo.h answers
}  // namespace

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
                                    &sites::kShipEntryArg, &sites::kShipCardLookup,
                                    &sites::kFreeHomeCityUnitCase})) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!AddTechPlayerSubtype("FreeHomeCityUnitByShipmentCount", &ParseEffect, &RunEffect) ||
      !InstallSyscallHooks("shipmentCounts") || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  SyscallParam player;
  player.type = kSyscallInt;
  player.intValue = -1;
  SyscallParam age;
  age.type = kSyscallInt;
  age.intValue = -1;

  SyscallDef def;
  def.group = SyscallGroup::kXs;
  def.retType = kSyscallInt;
  def.name = "xsGetShipmentCount";
  def.fn = reinterpret_cast<const void*>(&XsGetShipmentCount);
  def.comment = "int xsGetShipmentCount(int playerID, int age): the home city shipments of cards of that age "
                "(cAge1..cAge5; a card with no age is cAge1) that arrived for the player, or of every age with -1, "
                "in this game.";
  def.params = {player, age};
  def.source = "shipmentCounts";
  AddSyscall(std::move(def));

  SyscallDef range;
  range.group = SyscallGroup::kXs;
  range.retType = kSyscallInt;
  range.name = "xsGetShipmentCountRange";
  range.fn = reinterpret_cast<const void*>(&XsGetShipmentCountRange);
  range.comment = "int xsGetShipmentCountRange(int playerID, int firstAge, int lastAge): the home city shipments of "
                  "cards of ages firstAge to lastAge (cAge1..cAge5) that arrived for the player, in this game.";
  range.params = {player, age, age};
  range.source = "shipmentCounts";
  AddSyscall(std::move(range));

  if (!WriteCall(kShipActivateCall, reinterpret_cast<const void*>(&UhcShipActivateHook))) {
    return Outcome::kFailed;
  }
  Log(L"shipmentCounts: shipments are counted per player and the age of each card (its <age>; none: Age I), and "
      L"kept in saved games; the Data subtype FreeHomeCityUnitByShipmentCount and the XS syscalls xsGetShipmentCount "
      L"and xsGetShipmentCountRange read them%ls (multiplayer unverified)",
      log ? L"; each shipment and effect is logged" : L"");
  g_unitInfoOn = true;
  return Outcome::kApplied;
}

}  // namespace uhc

namespace uhc::unitinfo {

bool ShipmentCounts(const char* unit, std::wstring* out) {
  const char* player = !g_unitInfoOn || unit == nullptr ? nullptr : Field<const char*>(unit, 0x44);
  const std::int32_t id = player == nullptr ? -1 : Field<std::int32_t>(player, 0x00);
  if (id < 0 || id >= kPlayers || World() != g_world) {
    return false;
  }
  static const wchar_t* const kAgeNames[] = {L"I", L"II", L"III", L"IV", L"V", L"VI", L"VII", L"VIII"};
  out->clear();
  for (int age = 0; age < kAges && age < 8; ++age) {
    wchar_t text[24];
    swprintf_s(text, L"%ls%ls %d", out->empty() ? L"" : L"  ", kAgeNames[age], g_state[id].counts[age]);
    *out += text;
  }
  return true;
}

}  // namespace uhc::unitinfo
