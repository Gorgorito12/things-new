// randomCost: a unit whose price is rolled in a range, a new price after each purchase.
//
//   <RandomCost resourcetype="Gold" min="80" max="120"/>   in a proto; one per resource, repeated as needed
//
// Each tag replaces that resource of the proto's <Cost> with a whole number rolled in [min, max]. The price is rolled
// in advance: the cost getter 0x480B1E, which the train button, its rollover, the "can afford" checks, the AI and the
// Train action's payment all read, returns the price of the player's next purchase of that proto. So what the button
// shows is what is paid. After each purchase the next price is rolled.
//
// The roll. Price n of a player's proto is hash(game seed, player, proto ID, n, resource) in [min, max], n being the
// number of that player's purchases of that proto that were not refunded. Nothing else changes it: no randomness at
// the time of the call, no local state, so every machine and every call gets the same price. The game seed is the
// state of the synced random streams at the first world update of the game (a read, not a draw).
//
// Stock changes on top of the rolled price. A tech that changes the cost (the player's copy of the proto, [+70h])
// scales it by the copy's cost over the base proto's cost for that resource (or adds the difference when the base
// cost is 0); the result is rounded to a whole number. The getter then applies <CostEscalation> and the count as
// stock does. Shipments, free units and the free Train flag do not pay: no roll is used.
//
// The purchases. The Train enqueue FUN_009EAC35 pays per unit (getter then payment 0x8D946A, once per unit) or in a
// batch (action flag 14h: the getter for N units, one payment), then writes one entry per paid unit whose cost record
// [entry+8] it fills from the getter again. The two payments advance n (by 1, or by N: a batch pays N times the same
// price) and note each paid index; the record call takes the noted index, so each entry holds the price it paid. The
// three refunds of an entry's record (the cancel, a queue emptied by a state change, a failed spawn) refund that
// record, as stock, and take n back by one, so a cancel brings back the price it consumed instead of skipping it.
//
// Saved games. The seed and every non-zero n are saved markers (savedmarkers.h, stat 68h) on one living unit: a world
// tick writes them when they change and moves them when their unit dies. A game that starts or loads reads them back
// (one walk over the units), so the prices after a load are those the game would have had.
#include <windows.h>

#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <deque>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"
#include "../savedmarkers.h"
#include "../unittypes.h"
#include "../worldtick.h"

extern "C" {
void UhcRandomCostCopyHook();
void UhcRandomCostPayBatchHook();
void UhcRandomCostPayOneHook();
void UhcRandomCostRecordHook();
void UhcRandomCostRefundCancelHook();
void UhcRandomCostRefundAllHook();
void UhcRandomCostRefundSpawnHook();
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::uint32_t kSyncRng = 0x00C66588;     // the synced random: [+4] streams of 12 bytes, word 0 the state
constexpr int kSeedStreams = 3;                    // streams 0..2 (stream 2 is the combat one)
constexpr int kPlayers = 16;
constexpr std::size_t kProtoCost = 0x70;  // a proto's cost list
constexpr int kMaxLines = 400;

// Saved markers (savedmarkers.h): word 0 is 'RC' << 16 | kind.
constexpr std::int32_t kStat = 0x68;
constexpr std::uint32_t kTag = 0x52430000;
constexpr std::uint32_t kTagMask = 0xFFFF0000;
constexpr std::uint32_t kKindSeed = 0;   // word 1 the seed, word 2 kSeedSet
constexpr std::uint32_t kKindCount = 1;  // word 1 the player, word 2 the proto ID, word 3 n
constexpr std::uint32_t kSeedSet = 0x53454544;

using ResListCopyFn = char*(__thiscall*)(char* dst, const char* src);
const auto kResListCopy = reinterpret_cast<ResListCopyFn>(0x00480A73);
using ResListGetFn = float(__thiscall*)(const char* list, std::int32_t resource);
const auto kResListGet = reinterpret_cast<ResListGetFn>(0x0044EFFF);
using ResListSetFn = void(__thiscall*)(char* list, std::int32_t resource, float value);
const auto kResListSet = reinterpret_cast<ResListSetFn>(0x0058EF83);
using PayFn = bool(__thiscall*)(char* player, char* cost);
const auto kPay = reinterpret_cast<PayFn>(0x008D946A);
using RefundFn = bool(__thiscall*)(char* player, char* cost);
const auto kRefund = reinterpret_cast<RefundFn>(0x008D7004);
using CostGetterFn = bool(__thiscall*)(char* player, std::int32_t protoId, char* cost, std::int32_t count);
const auto kCostGetter = reinterpret_cast<CostGetterFn>(0x00480B1E);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
using ResourceByNameFn = std::int32_t(__thiscall*)(void* context, const char* name);
const auto kResourceByName = reinterpret_cast<ResourceByNameFn>(0x0044709C);
using UnitTestFn = bool(__thiscall*)(const char* unit);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Range {
  std::int32_t resource;
  std::int32_t min;
  std::int32_t max;
  char name[16];  // the resource as the tag names it, for the log
};

struct Tagged {
  std::int32_t protoId;
  std::vector<Range> ranges;
};

struct Paid {  // a unit paid in the enqueue that runs now, waiting for its entry
  std::int32_t player;
  std::int32_t protoId;
  std::int32_t index;
};

bool g_log = false;
int g_lines = 0;

// Read with the protos, in data order: the same on every machine.
std::vector<Tagged> g_tagged;
std::vector<std::int32_t> g_slotOf;  // by proto ID: the index in g_tagged, or -1

// The game the counts belong to.
const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
std::uint32_t g_seed = 0;
bool g_haveSeed = false;
std::vector<std::int32_t> g_counts[kPlayers];  // by slot
bool g_dirty = false;
bool g_strayMarkers = false;      // markers on more than one unit: the next write frees the others
std::int32_t g_carrier = -1;      // the unit that holds the markers
std::uint32_t g_carrierWord = 0;  // word 0 of one of its markers

std::deque<Paid> g_paid;
std::int32_t g_forceIndex = -1;  // the record call: the index the entry paid

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

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

const char* World() {
  const char* game = Game();
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

const char* BaseProto(std::int32_t id) {
  const char* game = Game();
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  if (database == nullptr || id < 0 || id >= Field<std::int32_t>(database, 0x58)) {
    return nullptr;
  }
  return Field<const char* const*>(database, 0x54)[id];
}

int SlotOf(std::int32_t protoId) {
  return protoId >= 0 && protoId < static_cast<std::int32_t>(g_slotOf.size()) ? g_slotOf[protoId] : -1;
}

std::int32_t& Count(int player, int slot) {
  std::vector<std::int32_t>& counts = g_counts[player];
  if (counts.size() < g_tagged.size()) {
    counts.resize(g_tagged.size(), 0);
  }
  return counts[slot];
}

std::uint64_t Mix(std::uint64_t z) {  // splitmix64's finalizer
  z += 0x9E3779B97F4A7C15ull;
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
  return z ^ (z >> 31);
}

std::int32_t Roll(std::int32_t player, std::int32_t protoId, std::int32_t n, const Range& range) {
  std::uint64_t h = Mix(g_seed);
  h = Mix(h ^ static_cast<std::uint32_t>(player));
  h = Mix(h ^ static_cast<std::uint32_t>(protoId));
  h = Mix(h ^ static_cast<std::uint32_t>(n));
  h = Mix(h ^ static_cast<std::uint32_t>(range.resource));
  const std::uint64_t span = static_cast<std::uint64_t>(range.max - range.min) + 1;
  return range.min + static_cast<std::int32_t>(h % span);
}

// --- Units and markers ---------------------------------------------------------------------------------------

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

bool IsOurs(char* marker) { return (uhc::markers::Word(marker, 0) & kTagMask) == kTag; }

void FreeOurs(char* unit) {
  uhc::markers::ForEach(unit, kStat, [](char* marker) {
    if (IsOurs(marker)) {
      uhc::markers::Free(marker);
    }
    return true;
  });
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
        uhc::markers::Free(marker);
        return unit;
      }
    }
  }
  return nullptr;
}

bool WriteMarker(char* unit, std::uint32_t kind, std::uint32_t w1, std::uint32_t w2, std::uint32_t w3) {
  char* marker = uhc::markers::Take(unit, kStat);
  if (marker == nullptr) {
    return false;
  }
  uhc::markers::Word(marker, 0) = kTag | kind;
  uhc::markers::Word(marker, 1) = w1;
  uhc::markers::Word(marker, 2) = w2;
  uhc::markers::Word(marker, 3) = w3;
  return true;
}

void FreeStrays(const char* world, std::int32_t keep) {
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  for (std::int32_t i = 0; table != nullptr && i < count; ++i) {
    if (table[i] != nullptr && Field<std::int32_t>(table[i], 0x10) != keep) {
      FreeOurs(table[i]);
    }
  }
  g_strayMarkers = false;
}

// Writes the seed and the counts on the carrier, a new one if it is gone. From the world tick only.
void WriteMarkers(const char* world) {
  char* unit = UnitById(world, g_carrier);
  const bool keep = unit != nullptr && IsAlive(unit) && !IsDead(unit);
  if (unit != nullptr) {
    FreeOurs(unit);
  }
  if (!keep) {
    unit = PickCarrier(world);
    if (unit == nullptr) {
      return;  // no unit to hold them: try again at the next tick
    }
  }
  bool ok = WriteMarker(unit, kKindSeed, g_seed, kSeedSet, 0);
  for (int p = 0; p < kPlayers && ok; ++p) {
    for (std::size_t s = 0; s < g_counts[p].size() && s < g_tagged.size() && ok; ++s) {
      if (g_counts[p][s] != 0) {
        ok = WriteMarker(unit, kKindCount, static_cast<std::uint32_t>(p),
                         static_cast<std::uint32_t>(g_tagged[s].protoId), static_cast<std::uint32_t>(g_counts[p][s]));
      }
    }
  }
  if (!ok) {
    FreeOurs(unit);
    return;  // try again at the next tick
  }
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  if (g_log && id != g_carrier) {
    Line(L"randomCost: the seed and the counts are kept on unit %d", id);
  }
  if (g_strayMarkers) {
    FreeStrays(world, id);
  }
  g_carrier = id;
  g_carrierWord = kTag | kKindSeed;
  g_dirty = false;
}

// A game that just started or loaded: the seed and counts its markers keep. One walk, reads only.
void Rebuild(const char* world) {
  for (auto& counts : g_counts) {
    counts.assign(g_tagged.size(), 0);
  }
  g_paid.clear();
  g_haveSeed = false;
  g_seed = 0;
  g_carrier = -1;
  g_carrierWord = 0;
  g_dirty = false;
  g_strayMarkers = false;
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* table = Field<char* const*>(world, 0x0C);
  int carriers = 0;
  int restored = 0;
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
      found = true;
      const std::uint32_t kind = uhc::markers::Word(marker, 0) & 0xFFFF;
      if (kind == kKindSeed && uhc::markers::Word(marker, 2) == kSeedSet) {
        g_seed = uhc::markers::Word(marker, 1);
        g_haveSeed = true;
      } else if (kind == kKindCount) {
        const auto player = static_cast<std::int32_t>(uhc::markers::Word(marker, 1));
        const int slot = SlotOf(static_cast<std::int32_t>(uhc::markers::Word(marker, 2)));
        if (player >= 0 && player < kPlayers && slot >= 0) {
          Count(player, slot) = static_cast<std::int32_t>(uhc::markers::Word(marker, 3));
          ++restored;
        }
      }
      return true;
    });
    if (found) {
      ++carriers;
      g_carrier = Field<std::int32_t>(unit, 0x10);
      g_carrierWord = kTag | kKindSeed;
    }
  }
  if (carriers > 1) {
    g_dirty = true;  // the next write keeps one set
    g_strayMarkers = true;
  }
  if (carriers > 0) {
    Line(L"randomCost: loaded: seed %08X, %d count(s)", g_seed, restored);
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

// The seed: the synced streams' states at the game's first world update. A read: the draws stay stock.
std::uint32_t ReadSeed() {
  const char* rng = reinterpret_cast<const char*>(kSyncRng);
  const char* streams = Field<const char*>(rng, 4);
  if (streams == nullptr) {
    return 0;
  }
  std::uint64_t h = 0;
  for (int s = 0; s < kSeedStreams; ++s) {
    h = Mix(h ^ Field<std::uint32_t>(streams, 12 * s));
  }
  return static_cast<std::uint32_t>(h ^ (h >> 32));
}

void Tick(char* world, std::int32_t) {
  if (g_tagged.empty() || world != World()) {
    return;
  }
  Sync();
  g_paid.clear();  // an enqueue is over: what it did not write is gone
  if (!g_haveSeed) {
    g_seed = ReadSeed();
    g_haveSeed = true;
    g_dirty = true;
    Line(L"randomCost: new game: seed %08X", g_seed);
  }
  if (g_dirty || (g_carrier >= 0 && !CarrierValid(world))) {
    WriteMarkers(world);
  }
}

void ForgetTags(char*) {
  g_tagged.clear();
  g_slotOf.clear();
  for (auto& counts : g_counts) {
    counts.clear();
  }
  g_paid.clear();
  g_world = nullptr;  // the next call reads the markers again, with the new slots
}

std::string Attribute(const char* node, const char* name, bool* present) {
  const void* value = nullptr;
  *present = node != nullptr && kXmlAttribute(node, name, &value) && value != nullptr;
  if (!*present) {
    return {};
  }
  const char* text = kXmlText(value);
  return text != nullptr ? text : "";
}

bool ParseWhole(const std::string& text, std::int32_t* out) {
  if (text.empty()) {
    return false;
  }
  char* end = nullptr;
  const double value = std::strtod(text.c_str(), &end);
  while (end != nullptr && (*end == ' ' || *end == '\t')) {
    ++end;
  }
  if (end == nullptr || *end != '\0' || !std::isfinite(value) || value < 0.0 || value > 1000000.0) {
    return false;
  }
  *out = static_cast<std::int32_t>(std::floor(value + 0.5));
  return true;
}

bool __cdecl ReadRandomCost(void* context, const char* node, char* proto) {
  const std::int32_t id = Field<std::int32_t>(proto, 8);
  bool hasResource = false;
  bool hasMin = false;
  bool hasMax = false;
  const std::string resourceName = Attribute(node, "resourcetype", &hasResource);
  const std::string minText = Attribute(node, "min", &hasMin);
  const std::string maxText = Attribute(node, "max", &hasMax);
  const std::int32_t resource = hasResource ? kResourceByName(context, resourceName.c_str()) : -1;
  Range range{resource, 0, 0, {}};
  strncpy_s(range.name, resourceName.c_str(), _TRUNCATE);
  if (!hasResource || resource < 0) {
    uhc::Log(L"randomCost: proto %d: <RandomCost resourcetype=\"%hs\">: no such resource, tag ignored", id,
             resourceName.c_str());
    return true;
  }
  if (!hasMin || !hasMax || !ParseWhole(minText, &range.min) || !ParseWhole(maxText, &range.max)) {
    uhc::Log(L"randomCost: proto %d: <RandomCost resourcetype=\"%hs\" min=\"%hs\" max=\"%hs\">: min and max must be "
             L"numbers from 0 to 1000000, tag ignored",
             id, resourceName.c_str(), minText.c_str(), maxText.c_str());
    return true;
  }
  if (range.min > range.max) {
    uhc::Log(L"randomCost: proto %d: <RandomCost resourcetype=\"%hs\">: min %d is above max %d, tag ignored", id,
             resourceName.c_str(), range.min, range.max);
    return true;
  }
  if (id < 0) {
    return true;
  }
  int slot = SlotOf(id);
  if (slot < 0) {
    if (static_cast<std::size_t>(id) >= g_slotOf.size()) {
      g_slotOf.resize(static_cast<std::size_t>(id) + 1, -1);
    }
    slot = static_cast<int>(g_tagged.size());
    g_slotOf[id] = slot;
    g_tagged.push_back({id, {}});
  }
  std::vector<Range>& ranges = g_tagged[slot].ranges;
  for (Range& existing : ranges) {
    if (existing.resource == resource) {
      existing = range;  // a repeated resource: the last tag wins
      return true;
    }
  }
  ranges.push_back(range);
  if (g_log) {
    uhc::Log(L"randomCost: proto %d: %hs from %d to %d", id, resourceName.c_str(), range.min, range.max);
  }
  return true;
}

// The tagged resources of a cost list, for the log: "97 Gold, 12 Wood".
void Describe(const char* cost, const Tagged& tagged, wchar_t* out, std::size_t size) {
  out[0] = L'\0';
  std::size_t used = 0;
  for (const Range& range : tagged.ranges) {
    const int written = _snwprintf_s(out + used, size - used, _TRUNCATE, L"%ls%g %hs", used == 0 ? L"" : L", ",
                                     static_cast<double>(kResListGet(cost, range.resource)), range.name);
    if (written < 0) {
      return;
    }
    used += static_cast<std::size_t>(written);
  }
}

}  // namespace

// The getter's copy of the player's proto's cost into its result. Then the tagged resources get the price of the
// player's next purchase (or of the entry being written), scaled by the techs. EBX, EDI from the hook.
extern "C" void __stdcall UhcRandomCostCopy(char* dst, const char* src, const char* proto, const char* player) {
  kResListCopy(dst, src);
  if (proto == nullptr || player == nullptr || *reinterpret_cast<char* const*>(dst) == nullptr) {
    return;
  }
  const std::int32_t protoId = Field<std::int32_t>(proto, 8);
  const int slot = SlotOf(protoId);
  const std::int32_t playerId = Field<std::int32_t>(player, 0);
  if (slot < 0 || playerId < 0 || playerId >= kPlayers) {
    return;
  }
  Sync();
  const std::int32_t n = g_forceIndex >= 0 ? g_forceIndex : Count(playerId, slot);
  const char* base = BaseProto(protoId);
  for (const Range& range : g_tagged[slot].ranges) {
    const float rolled = static_cast<float>(Roll(playerId, protoId, n, range));
    const float current = kResListGet(src, range.resource);
    const float stock = base != nullptr ? kResListGet(base + kProtoCost, range.resource) : current;
    float price = stock > 0.0f ? rolled * (current / stock) : rolled + current;
    price = std::floor(price + 0.5f);
    kResListSet(dst, range.resource, price < 0.0f ? 0.0f : price);
  }
}

// The Train enqueue's payment of `count` units of the proto at once. A paid tagged proto moves the player's count on
// and notes the index each unit paid, for its entry.
extern "C" bool __stdcall UhcRandomCostPay(char* player, char* cost, std::int32_t protoId, std::int32_t count) {
  const bool paid = kPay(player, cost);
  const int slot = SlotOf(protoId);
  if (!paid || slot < 0 || player == nullptr || count <= 0) {
    return paid;
  }
  const std::int32_t playerId = Field<std::int32_t>(player, 0);
  if (playerId < 0 || playerId >= kPlayers) {
    return paid;
  }
  Sync();
  std::int32_t& n = Count(playerId, slot);
  const std::int32_t first = n;
  for (std::int32_t i = 0; i < count; ++i) {
    g_paid.push_back({playerId, protoId, first});
  }
  n += count;
  g_dirty = true;
  if (g_log && g_lines < kMaxLines) {
    wchar_t paidText[160];
    Describe(cost, g_tagged[slot], paidText, sizeof(paidText) / sizeof(paidText[0]));
    char* next = nullptr;
    wchar_t nextText[160] = L"?";
    // The next price, as the getter will give it (a local cost list from the player's proto).
    std::uint32_t list[2] = {};
    std::uint32_t values[16] = {};
    if (*reinterpret_cast<const std::int32_t*>(0x00C6DF38) <= 16) {
      list[0] = reinterpret_cast<std::uint32_t>(values);
      next = reinterpret_cast<char*>(list);
      if (kCostGetter(player, protoId, next, 1)) {
        Describe(next, g_tagged[slot], nextText, sizeof(nextText) / sizeof(nextText[0]));
      }
    }
    Line(L"randomCost: player %d paid %ls for %d of proto %d (purchase %d%ls); next price %ls", playerId, paidText,
         count, protoId, first, count > 1 ? L", a batch" : L"", nextText);
  }
  return paid;
}

// The Train enqueue's getter call for an entry's cost record: the price that entry paid, when the payment noted it.
extern "C" bool __stdcall UhcRandomCostRecord(char* player, std::int32_t protoId, char* cost, std::int32_t count) {
  if (player != nullptr && SlotOf(protoId) >= 0 && !g_paid.empty()) {
    const Paid front = g_paid.front();
    if (front.player == Field<std::int32_t>(player, 0) && front.protoId == protoId) {
      g_paid.pop_front();
      g_forceIndex = front.index;
      const bool ok = kCostGetter(player, protoId, cost, count);
      g_forceIndex = -1;
      return ok;
    }
  }
  return kCostGetter(player, protoId, cost, count);
}

// A refund of a Train entry's cost record [entry+8]: stock, then the player's count of the proto goes back by one.
extern "C" bool __stdcall UhcRandomCostRefund(char* player, char* cost) {
  const bool ok = kRefund(player, cost);
  if (player == nullptr || cost == nullptr) {
    return ok;
  }
  const std::int32_t protoId = *reinterpret_cast<const std::int32_t*>(cost - 8);
  const int slot = SlotOf(protoId);
  const std::int32_t playerId = Field<std::int32_t>(player, 0);
  if (slot < 0 || playerId < 0 || playerId >= kPlayers) {
    return ok;
  }
  Sync();
  std::int32_t& n = Count(playerId, slot);
  if (n > 0) {
    --n;
    g_dirty = true;
  }
  if (g_log && g_lines < kMaxLines) {
    wchar_t text[160];
    Describe(cost, g_tagged[slot], text, sizeof(text) / sizeof(text[0]));
    Line(L"randomCost: player %d refunded %ls for proto %d; purchases back to %d", playerId, text, protoId, n);
  }
  return ok;
}

namespace uhc {

Outcome ApplyRandomCost(const Config& config) {
  const Config::Args* args = config.First("randomCost");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"randomCost: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("randomCost", {&sites::kRandomCostGetterCopy, &sites::kRandomCostPayBatch, &sites::kRandomCostPayOne,
                                &sites::kRandomCostRecord, &sites::kRandomCostRefundCancel, &sites::kRandomCostRefundAll,
                                &sites::kRandomCostRefundSpawn})) {
    return Outcome::kFailed;
  }
  if (!AddProtoTagHandler("RandomCost", &ReadRandomCost) || !OnDatabaseLoad(&ForgetTags) || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  if (!WriteCall(sites::kRandomCostGetterCopy.va + 6, reinterpret_cast<const void*>(&UhcRandomCostCopyHook)) ||
      !WriteCall(sites::kRandomCostPayBatch.va + 0x20, reinterpret_cast<const void*>(&UhcRandomCostPayBatchHook)) ||
      !WriteCall(sites::kRandomCostPayOne.va + 0x1D, reinterpret_cast<const void*>(&UhcRandomCostPayOneHook)) ||
      !WriteCall(sites::kRandomCostRecord.va + 0x11, reinterpret_cast<const void*>(&UhcRandomCostRecordHook)) ||
      !WriteCall(sites::kRandomCostRefundCancel.va + 9, reinterpret_cast<const void*>(&UhcRandomCostRefundCancelHook)) ||
      !WriteCall(sites::kRandomCostRefundAll.va + 0x0A, reinterpret_cast<const void*>(&UhcRandomCostRefundAllHook)) ||
      !WriteCall(sites::kRandomCostRefundSpawn.va + 0x0E, reinterpret_cast<const void*>(&UhcRandomCostRefundSpawnHook))) {
    return Outcome::kFailed;
  }
  Log(L"randomCost: <RandomCost> is read; the cost getter, the Train payments, entry costs and refunds are hooked");
  return Outcome::kApplied;
}

}  // namespace uhc
