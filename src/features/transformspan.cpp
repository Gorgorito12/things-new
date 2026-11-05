// transformSpan: the attribute transformspan="<seconds>" on a TransformUnit effect: when the time ends,
// the units that effect transformed turn back into what they were.
//
// Stock's TransformUnit (apply 0x7FBBAF) changes each alive, built unit of fromprotoid in place with
// 0x9C754C, which keeps the unit's ID, and nothing ever turns it back. The key reads the attribute
// in a wrapper of the effect's setData slot, knows which effect is running through a wrapper of its
// apply slot, and records each unit in the wrapper of the call 0x7FBC79. A world tick turns the unit
// back with the same 0x9C754C, so whatever that function keeps (HP by proportion, transformInventory,
// transformUpdatesLOS) applies both ways.
//
// A unit is turned back only if it is still alive, built, and of the proto this key gave it: a unit
// transformed again by something else stays what it is. A second transformspan on a pending unit
// keeps the first proto and the new end, and a TransformUnit without the attribute ends the pending
// one.
//
// Saved games: the table lives in this DLL, so a copy of each entry lives on the unit, as two modifiers
// of stats nothing reads (the unit's actions are in the save). When another game is running (see
// SyncWorld) the table is rebuilt from them. A modifier's value is written in place, which is the
// only write here into a unit's actions; it runs in the simulation on every machine.
#include <cstdint>
#include <cstdlib>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../modifiers.h"
#include "../patch.h"
#include "../transformcalls.h"
#include "../worldtick.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr std::int32_t kStatFrom = 0x60;           // a modifier's value: the proto to go back to
constexpr std::int32_t kStatEnd = 0x61;            // the game time to do it, in tenths of a second
constexpr std::int32_t kMarkerExtraMs = 5000;      // the marker outlives the entry by this
constexpr float kDoneMarker = -1.0f;
constexpr int kMaxLogLines = 200;

using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
using SetDataFn = bool(__thiscall*)(void* effect, const void* node);
using ApplyFn = void(__thiscall*)(void* effect, void* a, void* b, void* c, void* d);
using TransformFn = void(__thiscall*)(char* unit, std::int32_t proto);
using ModifierFn = std::int32_t(__thiscall*)(char* unit, std::int32_t stat, float value, float, float, std::int32_t,
                                             std::int32_t operation, std::int32_t ms, std::int32_t, std::int32_t,
                                             std::int32_t exclusive);
using IsBuiltFn = bool(__thiscall*)(const char* unit);
using IsAliveFn = bool(__thiscall*)(const char* unit);

const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);
const auto kModifier = reinterpret_cast<ModifierFn>(0x004DD22D);
const auto kIsBuilt = reinterpret_cast<IsBuiltFn>(0x0044DDB4);

struct Pending {
  std::int32_t unit;
  std::int32_t from;
  std::int32_t to;
  std::uint32_t end;  // game time, ms
};

SetDataFn g_setData = nullptr;
ApplyFn g_apply = nullptr;
std::unordered_map<const void*, std::int32_t> g_spans;  // effect -> ms; written while the data loads
std::vector<Pending> g_pending;                         // in the order the effects ran
std::int32_t g_runningSpan = 0;                         // of the effect in its apply
std::uint32_t g_nextEnd = 0;
const char* g_world = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* World() {
  const char* game = Field<const char*>(reinterpret_cast<const char*>(kGameGlobal), 0);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

bool Reached(std::uint32_t now, std::uint32_t time) { return static_cast<std::int32_t>(now - time) >= 0; }

bool LogLine() {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return false;
  }
  ++g_logLines;
  return true;
}

// Units by ID: [world+0Ch] array, [world+10h] count; the low 18 bits index the array and [unit+10h]
// must equal the full ID.
char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char**>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

std::int32_t ProtoId(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  return proto == nullptr ? -1 : Field<std::int32_t>(proto, 8);
}

bool Alive(const char* unit) {
  const auto alive = Field<IsAliveFn>(Field<const char*>(unit, 0), 0xA4);
  return alive(unit);
}

// The marker of that stat on a unit, or nullptr. Its value is at +68h.
char* FindMarker(const char* unit, std::int32_t stat) {
  const char* list = uhc::modifiers::ModifierList(unit);
  if (list == nullptr) {
    return nullptr;
  }
  char* found = nullptr;
  auto visit = [&](const char* action) {
    if (Field<std::int32_t>(action, 0x64) != stat) {
      return true;
    }
    found = const_cast<char*>(action);
    return false;
  };
  uhc::modifiers::WalkModifiers(list, visit, 0);
  return found;
}

void SetMarker(char* unit, std::int32_t stat, float value, std::int32_t ms) {
  if (char* marker = FindMarker(unit, stat)) {
    *reinterpret_cast<float*>(marker + 0x68) = value;
    return;
  }
  kModifier(unit, stat, value, -1.0f, -1.0f, 0, 1, ms, -1, -1, 0);
}

void UpdateNextEnd() {
  if (g_pending.empty()) {
    return;
  }
  g_nextEnd = g_pending.front().end;
  for (const Pending& entry : g_pending) {
    if (static_cast<std::int32_t>(entry.end - g_nextEnd) < 0) {
      g_nextEnd = entry.end;
    }
  }
}

// The table again, from the markers of a game that just started or loaded.
void Rebuild(const char* world) {
  g_pending.clear();
  const std::int32_t count = Field<std::int32_t>(world, 0x10);
  char* const* units = Field<char* const*>(world, 0x0C);
  for (std::int32_t i = 0; i < count; ++i) {
    const char* unit = units[i];
    if (unit == nullptr) {
      continue;
    }
    const char* from = FindMarker(unit, kStatFrom);
    const char* end = from == nullptr ? nullptr : FindMarker(unit, kStatEnd);
    if (end == nullptr || Field<float>(from, 0x68) < 0.0f) {
      continue;
    }
    g_pending.push_back({Field<std::int32_t>(unit, 0x10), static_cast<std::int32_t>(Field<float>(from, 0x68)),
                         ProtoId(unit), static_cast<std::uint32_t>(Field<float>(end, 0x68)) * 100});
  }
  UpdateNextEnd();
  if (!g_pending.empty()) {
    uhc::Log(L"transformSpan: %u pending unit(s) found in the saved game", static_cast<unsigned>(g_pending.size()));
  }
}

// A new or loaded game can reuse the old world's address, so the test is the step count [world+F8h],
// which rises by 1 per step, and the game time going back. The tick sees every step.
void SyncWorld(const char* world, std::uint32_t now) {
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  if (world != g_world || !Reached(now, g_lastTime) || step - g_lastStep > 1) {
    g_world = world;
    Rebuild(world);
  }
  g_lastTime = now;
  g_lastStep = step;
}

void TurnBack(const char* world, const Pending& entry) {
  char* unit = UnitById(world, entry.unit);
  if (unit == nullptr || !Alive(unit)) {
    if (LogLine()) {
      uhc::Log(L"transformSpan: unit %d is gone", entry.unit);
    }
    return;
  }
  if (char* marker = FindMarker(unit, kStatFrom)) {
    *reinterpret_cast<float*>(marker + 0x68) = kDoneMarker;
  }
  if (ProtoId(unit) != entry.to) {
    if (LogLine()) {
      uhc::Log(L"transformSpan: unit %d is proto %d now, not %d: left as it is", entry.unit, ProtoId(unit), entry.to);
    }
    return;
  }
  uhc::TransformUnit(unit, entry.from);
  if (LogLine()) {
    uhc::Log(L"transformSpan: unit %d turned back, proto %d -> %d, game time %.1f s", entry.unit, entry.to, ProtoId(unit),
             static_cast<double>(Field<std::uint32_t>(world, 0x108)) / 1000.0);
  }
}

void Tick(char* world, std::int32_t) {
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  SyncWorld(world, now);
  if (g_pending.empty() || !Reached(now, g_nextEnd)) {
    return;
  }
  std::vector<Pending> due;
  std::size_t kept = 0;
  for (const Pending& entry : g_pending) {
    if (Reached(now, entry.end)) {
      due.push_back(entry);
    } else {
      g_pending[kept++] = entry;
    }
  }
  g_pending.resize(kept);
  UpdateNextEnd();
  for (const Pending& entry : due) {
    TurnBack(world, entry);
  }
}

bool __fastcall SetData(void* effect, void*, const void* node) {
  const bool ok = g_setData(effect, node);
  const void* text = nullptr;
  if (ok && node != nullptr && kXmlAttribute(node, "transformspan", &text) && text != nullptr) {
    const double seconds = std::atof(kXmlText(text));
    if (seconds > 0.0) {
      g_spans[effect] = static_cast<std::int32_t>(seconds * 1000.0 + 0.5);
      if (g_log) {
        uhc::Log(L"transformSpan: an effect lasts %.1f s", seconds);
      }
    }
  }
  return ok;
}

void __fastcall Apply(void* effect, void*, void* a, void* b, void* c, void* d) {
  const auto found = g_spans.find(effect);
  g_runningSpan = found == g_spans.end() ? 0 : found->second;
  g_apply(effect, a, b, c, d);
  g_runningSpan = 0;
}

// Takes the call of 0x9C754C in the effect's apply.
void Transform(char* unit, std::int32_t proto) {
  const std::int32_t was = ProtoId(unit);
  const std::int32_t id = Field<std::int32_t>(unit, 0x10);
  Pending* pending = nullptr;
  for (Pending& entry : g_pending) {
    if (entry.unit == id) {
      pending = &entry;
    }
  }
  uhc::TransformUnit(unit, proto);
  if (g_runningSpan == 0) {
    if (pending != nullptr) {  // a lasting transform ends the timed one
      if (char* marker = FindMarker(unit, kStatFrom)) {
        *reinterpret_cast<float*>(marker + 0x68) = kDoneMarker;
      }
      g_pending.erase(g_pending.begin() + (pending - g_pending.data()));
      UpdateNextEnd();
    }
    return;
  }
  const char* world = World();
  if (world == nullptr) {
    return;
  }
  const std::uint32_t end = Field<std::uint32_t>(world, 0x108) + static_cast<std::uint32_t>(g_runningSpan);
  const std::int32_t from = pending != nullptr ? pending->from : was;
  if (pending != nullptr) {
    pending->to = proto;
    pending->end = end;
  } else {
    g_pending.push_back({id, from, proto, end});
  }
  UpdateNextEnd();
  // The markers go on after the transform: they must outlive anything it rebuilds.
  const std::int32_t markerMs = g_runningSpan + kMarkerExtraMs;
  SetMarker(unit, kStatFrom, static_cast<float>(from), markerMs);
  SetMarker(unit, kStatEnd, static_cast<float>((end + 99) / 100), markerMs);
  if (LogLine()) {
    uhc::Log(L"transformSpan: unit %d, proto %d -> %d, back to %d in %.1f s, at game time %.1f s", id, was, proto, from,
             static_cast<double>(g_runningSpan) / 1000.0, static_cast<double>(end - g_runningSpan) / 1000.0);
  }
}

}  // namespace

namespace uhc {

Outcome ApplyTransformSpan(const Config& config) {
  const Config::Args* args = config.First("transformSpan");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"transformSpan: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("transformSpan", {&sites::kTransformEffectSetDataSlot, &sites::kTransformEffectApplySlot,
                                   &sites::kSnareApply, &sites::kXmlAttribute,
                                   &sites::kXmlText, &sites::kTransformProtoLookup})) {
    return Outcome::kFailed;
  }
  g_setData = *reinterpret_cast<SetDataFn*>(sites::kTransformEffectSetDataSlot.va);
  g_apply = *reinterpret_cast<ApplyFn*>(sites::kTransformEffectApplySlot.va);
  if (!WriteDword(sites::kTransformEffectSetDataSlot.va, reinterpret_cast<std::uintptr_t>(&SetData)) ||
      !WriteDword(sites::kTransformEffectApplySlot.va, reinterpret_cast<std::uintptr_t>(&Apply)) ||
      !SetTransformEffectWrapper(&Transform) || !AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  Log(L"transformSpan: TransformUnit effects take transformspan");
  return Outcome::kApplied;
}

}  // namespace uhc
