// detonationDeath: <DetonationProtoAction>Name</DetonationProtoAction> in a proto fires that action around
// the unit when it dies.
//
// Every death goes through one queue: TakeDamage, a lifespan, a delete and the rest ask 0x4B4DC2, and the
// queue's drain 0x493D46 calls the kill handler 0x4B4F70 for each, from a single call, 0x493D8F. The key
// wraps that call. Before the stock handler runs, the unit still exists, so the stock area damage
// 0x4C9D89 gets it as the attacker, in the same call the game makes for a unit that hits around
// itself (0x6A4A6B). Units that die from the blast join the queue, and the drain reads its count again,
// so a chain runs one by one and does not recurse.
//
// The action is the player's copy, so a tech that changes its damage counts. The names are read once and
// are the same for every player.
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <string>
#include <unordered_map>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"

namespace {

constexpr std::uint32_t kKillCall = 0x00493D8F;
constexpr std::size_t kUnitState = 4;       // bit array; +8h its size in bits
constexpr std::size_t kUnitId = 0x10;
constexpr std::size_t kUnitPosition = 0x14;
constexpr std::size_t kUnitProto = 0x5C;
constexpr std::size_t kProtoId = 8;
constexpr std::size_t kProtoActions = 0x44;  // the action set
constexpr std::size_t kActionList = 0x1C;    // in the set: the array of actions, its count at +20h
constexpr std::size_t kActionId = 4;
constexpr std::size_t kActionFlags = 0x64;   // bit array; +68h its size in bits
constexpr std::size_t kActionNames = 0x1FD8; // in the database: the names by action ID, the count at +1FDCh
constexpr std::uint32_t kDeadBit = 11;       // the kill handler returns at once when it is set
constexpr std::uint32_t kAreaFlagBit = 6;    // what the stock caller reads and passes on
constexpr std::uint32_t kZeroVector = 0x00CF0618;
constexpr int kMaxLogLines = 200;

using KillFn = void(__thiscall*)(char* unit, std::uint32_t a, std::uint32_t b, std::uint32_t c);
const auto kKill = reinterpret_cast<KillFn>(0x004B4F70);
using AreaFn = void(__thiscall*)(const char* world, std::int32_t unit, char* action, const void* point, float multiplier,
                                 std::int32_t a, std::int32_t b, std::int32_t c, std::int32_t* hit, std::uint32_t flag,
                                 const void* offset);
const auto kArea = reinterpret_cast<AreaFn>(0x004C9D89);

struct Detonation {
  std::wstring name;
  std::int32_t action = -2;  // -2: not looked up yet, -1: the proto has no action of that name
  std::wstring command;      // <DetonationCommand>: the proto command that detonates (a delete)
  float threshold = -1.0f;   // <DetonationHitpointThreshold>: the HP ratio that detonates by itself
  float decay = -1.0f;       // <DetonationHitpointDecay>: HP lost per second under the threshold
};

std::unordered_map<std::int32_t, Detonation> g_protos;  // by proto ID; the map's shape is fixed after the load
bool g_log = false;
int g_logLines = 0;

bool Bit(const char* owner, std::size_t array, std::uint32_t bit) {
  const auto* bits = *reinterpret_cast<const std::uint8_t* const*>(owner + array);
  const std::uint32_t size = *reinterpret_cast<const std::uint32_t*>(owner + array + 4);
  return bits != nullptr && bit < size && (bits[bit / 8] & (1u << (bit % 8))) != 0;
}

const char* Game() { return *reinterpret_cast<const char* const*>(0x00C66234); }

// The action of the player's copy with that name, by its ID in the database's list of names.
char* FindAction(const char* proto, Detonation& detonation) {
  const char* game = Game();
  const char* db = *reinterpret_cast<const char* const*>(game + 0x140);
  const char* set = *reinterpret_cast<const char* const*>(proto + kProtoActions);
  if (set == nullptr) {
    return nullptr;
  }
  const auto* names = *reinterpret_cast<const wchar_t* const* const*>(db + kActionNames);
  const std::int32_t nameCount = *reinterpret_cast<const std::int32_t*>(db + kActionNames + 4);
  char* const* actions = *reinterpret_cast<char* const* const*>(set + kActionList);
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(set + kActionList + 4);
  for (std::int32_t i = 0; i < count; ++i) {
    const std::int32_t id = *reinterpret_cast<const std::int32_t*>(actions[i] + kActionId);
    if (detonation.action >= 0) {
      if (id == detonation.action) {
        return actions[i];
      }
      continue;
    }
    if (id >= 0 && id < nameCount && names[id] != nullptr && _wcsicmp(names[id], detonation.name.c_str()) == 0) {
      detonation.action = id;
      return actions[i];
    }
  }
  if (detonation.action == -2) {
    detonation.action = -1;
    uhc::Log(L"detonationDeath: proto %d has no action %ls", *reinterpret_cast<const std::int32_t*>(proto + kProtoId),
             detonation.name.c_str());
  }
  return nullptr;
}

bool __cdecl ReadDetonation(void*, const char* node, char* proto) {
  const wchar_t* text = *reinterpret_cast<const wchar_t* const*>(node + 0x14);
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  if (text == nullptr || text[0] == L'\0') {
    uhc::Log(L"detonationDeath: proto %d: <DetonationProtoAction> names no action, ignored", id);
    return true;
  }
  g_protos[id].name = text;
  if (g_log) {
    uhc::Log(L"detonationDeath: proto %d fires %ls", id, text);
  }
  return true;
}

const wchar_t* NodeText(const char* node) { return *reinterpret_cast<const wchar_t* const*>(node + 0x14); }

bool __cdecl ReadCommand(void*, const char* node, char* proto) {
  const wchar_t* text = NodeText(node);
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  if (text == nullptr || text[0] == L'\0') {
    uhc::Log(L"detonationDeath: proto %d: <DetonationCommand> names no command, ignored", id);
    return true;
  }
  g_protos[id].command = text;
  if (g_log) {
    uhc::Log(L"detonationDeath: proto %d detonates on its command %ls (a delete)", id, text);
  }
  return true;
}

bool ReadRatio(const char* node, char* proto, const wchar_t* tag, float* out, float low, float high) {
  const wchar_t* text = NodeText(node);
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  wchar_t* end = nullptr;
  const double value = text == nullptr ? -1.0 : std::wcstod(text, &end);
  if (text == nullptr || end == text || !(value >= low) || !(value <= high)) {
    uhc::Log(L"detonationDeath: proto %d: <%ls> needs a number from %g to %g, ignored", id, tag, static_cast<double>(low),
             static_cast<double>(high));
    return true;
  }
  *out = static_cast<float>(value);
  return true;
}

bool __cdecl ReadThreshold(void*, const char* node, char* proto) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  float value = -1.0f;
  ReadRatio(node, proto, L"DetonationHitpointThreshold", &value, 0.0f, 1.0f);
  if (value >= 0.0f) {
    g_protos[id].threshold = value;
    if (g_log) {
      uhc::Log(L"detonationDeath: proto %d detonates at %.0f %% of its hit points", id, static_cast<double>(value * 100.0f));
    }
  }
  return true;
}

bool __cdecl ReadDecay(void*, const char* node, char* proto) {
  const std::int32_t id = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  float value = -1.0f;
  ReadRatio(node, proto, L"DetonationHitpointDecay", &value, 0.0f, 1.0e6f);
  if (value >= 0.0f) {
    g_protos[id].decay = value;
    if (g_log) {
      uhc::Log(L"detonationDeath: proto %d loses %.2f hit points a second under its threshold", id,
               static_cast<double>(value));
    }
  }
  return true;
}

void Detonate(char* unit, std::uint32_t a, std::uint32_t b, std::uint32_t c) {
  const char* proto = *reinterpret_cast<const char* const*>(unit + kUnitProto);
  if (proto == nullptr) {
    return;
  }
  const std::int32_t protoId = *reinterpret_cast<const std::int32_t*>(proto + kProtoId);
  const auto found = g_protos.find(protoId);
  if (found == g_protos.end() || found->second.action == -1 || Bit(unit, kUnitState, kDeadBit)) {
    return;
  }
  const char* game = Game();
  const char* world = game == nullptr ? nullptr : *reinterpret_cast<const char* const*>(game + 0x13C);
  if (world == nullptr) {
    return;
  }
  char* action = FindAction(proto, found->second);
  if (action == nullptr) {
    return;
  }
  const auto* position = reinterpret_cast<const float*>(unit + kUnitPosition);
  std::int32_t hit = 0;
  kArea(world, *reinterpret_cast<const std::int32_t*>(unit + kUnitId), action, position, 1.0f, 0, 0, -1, &hit,
        Bit(action, kActionFlags, kAreaFlagBit) ? 1 : 0, reinterpret_cast<const void*>(kZeroVector));
  if (g_log && g_logLines < kMaxLogLines) {
    ++g_logLines;
    uhc::Log(L"detonationDeath: unit %d, proto %d, at %.1f, %.1f, kill flags %u %u %u", *reinterpret_cast<std::int32_t*>(unit + kUnitId),
             protoId, static_cast<double>(position[0]), static_cast<double>(position[2]), a & 0xFF, b & 0xFF, c & 0xFF);
  }
}

// Replaces the drain's call of the kill handler.
void __fastcall Kill(char* unit, void*, std::uint32_t a, std::uint32_t b, std::uint32_t c) {
  Detonate(unit, a, b, c);
  kKill(unit, a, b, c);
}

}  // namespace

namespace uhc {

Outcome ApplyDetonationDeath(const Config& config) {
  const Config::Args* args = config.First("detonationDeath");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"detonationDeath: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("detonationDeath", {&sites::kDetonationKillCall, &sites::kDetonationAreaHead}) ||
      !AddProtoTagHandler("DetonationProtoAction", &ReadDetonation) ||
      !AddProtoTagHandler("DetonationCommand", &ReadCommand) ||
      !AddProtoTagHandler("DetonationHitpointThreshold", &ReadThreshold) ||
      !AddProtoTagHandler("DetonationHitpointDecay", &ReadDecay) ||
      !WriteCall(kKillCall, reinterpret_cast<const void*>(&Kill))) {
    return Outcome::kFailed;
  }
  Log(L"detonationDeath: the proto tag DetonationProtoAction is on");
  return Outcome::kApplied;
}

}  // namespace uhc
