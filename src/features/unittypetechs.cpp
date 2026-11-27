// unitTypeTechs: the Data tech effects subtype="AddUnitType" and "RemoveUnitType", with unittype="<AbstractType>".
//
// An abstract type is a bit of the proto: the buffer [proto+30h], with [proto+34h] bits, indexed from the first
// abstract ID [db+19B0h]. The per-player clone 0x67E011 builds its own buffer and copies the bits one by one, so
// writing a player's copy changes that player alone, and the is-a test 0x44D7FA reads it at once.
//
// Stock's table of protos by type, read through 0x453326 (the KB's counts and queries by type, and so an AI's),
// is built from the data and shared by every player: a type added here is not in it. Nothing here changes that.
//
// A type the base proto has is never lost when an AddUnitType ends, and comes back when a RemoveUnitType ends.
// Several techs count: the bit is (base has it or some AddUnitType runs) and no RemoveUnitType runs.
#include <compare>
#include <cstdint>
#include <cstdlib>
#include <map>
#include <string>

#include "../features.h"
#include "../log.h"
#include "../techsubtypes.h"
#include "../unittypes.h"

namespace {

constexpr std::uintptr_t kGameGlobal = 0x00C66234;
constexpr std::size_t kWorld = 0x13C;
constexpr std::size_t kDatabase = 0x140;
constexpr std::size_t kFirstAbstract = 0x19B0;
constexpr std::size_t kProtoBits = 0x30;
constexpr std::size_t kProtoBitCount = 0x34;
constexpr int kMaxLogLines = 200;

struct Key {
  const char* proto;
  std::int32_t type;
  auto operator<=>(const Key&) const = default;
};

struct Count {
  std::int32_t added = 0;
  std::int32_t removed = 0;
};

std::map<Key, Count> g_counts;  // by the player's copy
const char* g_world = nullptr;
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::size_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* Game() { return *reinterpret_cast<const char* const*>(kGameGlobal); }

// The bit's index in the buffer, or -1.
std::int32_t BitOf(const char* proto, std::int32_t type) {
  const char* game = Game();
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, kDatabase);
  if (database == nullptr) {
    return -1;
  }
  const std::int32_t bit = type - Field<std::int32_t>(database, kFirstAbstract);
  return bit >= 0 && bit < Field<std::int32_t>(proto, kProtoBitCount) ? bit : -1;
}

bool HasBit(const char* proto, std::int32_t bit) {
  const auto* bits = Field<const std::uint8_t*>(proto, kProtoBits);
  return bits != nullptr && (bits[bit >> 3] & (1u << (bit & 7))) != 0;
}

void Change(char* proto, const char* base, std::int32_t type, bool add, bool unapply) {
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, kWorld);
  if (world != g_world) {
    g_counts.clear();  // another game: its copies are not these
    g_world = world;
  }
  const std::int32_t bit = BitOf(proto, type);
  auto* bits = Field<std::uint8_t*>(proto, kProtoBits);
  if (bit < 0 || bits == nullptr) {
    uhc::Log(L"unitTypeTechs: proto %hs has no bit for type %d; effect ignored", Field<const char*>(proto, 0x10), type);
    return;
  }
  Count& count = g_counts[{proto, type}];
  std::int32_t& which = add ? count.added : count.removed;
  which += unapply ? -1 : 1;
  if (which < 0) {
    which = 0;
  }
  const bool wanted = (HasBit(base, bit) || count.added > 0) && count.removed == 0;
  const std::uint8_t mask = static_cast<std::uint8_t>(1u << (bit & 7));
  if (wanted) {
    bits[bit >> 3] |= mask;
  } else {
    bits[bit >> 3] = static_cast<std::uint8_t>(bits[bit >> 3] & ~mask);
  }
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"unitTypeTechs: proto %hs (player's copy), %ls%ls type %d: bit %ls", Field<const char*>(proto, 0x10),
             unapply ? L"end of " : L"", add ? L"AddUnitType" : L"RemoveUnitType", type, wanted ? L"on" : L"off");
  }
}

void AddType(char* proto, const char* base, std::int32_t type, bool unapply) { Change(proto, base, type, true, unapply); }

void RemoveType(char* proto, const char* base, std::int32_t type, bool unapply) {
  Change(proto, base, type, false, unapply);
}

void NewDatabase(char*) {
  g_counts.clear();
  g_world = nullptr;
  g_logLines = 0;
}

}  // namespace

namespace uhc {

Outcome ApplyUnitTypeTechs(const Config& config) {
  const Config::Args* args = config.First("unitTypeTechs");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"unitTypeTechs: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!AddTechTypeSubtype("AddUnitType", &AddType) || !AddTechTypeSubtype("RemoveUnitType", &RemoveType) ||
      !OnDatabaseLoad(&NewDatabase)) {
    return Outcome::kFailed;
  }
  Log(L"unitTypeTechs: Data effects AddUnitType and RemoveUnitType change one player's copy of a proto");
  return Outcome::kApplied;
}

}  // namespace uhc
