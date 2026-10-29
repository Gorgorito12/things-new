// transformUpdatesLOS: a unit that changes proto in place takes the line of sight of its new proto.
//
// Each unit has its own base LOS at [[unit+B4h]+90h]. Stock copies it from the proto's <LOS>
// ([proto+48h]) when the unit is created, when it is built, and when a tech changes that proto's
// LOS. FUN_009C754C changes a live unit into another proto (TransformUnit tech effects, the
// revolution, the construction-object transforms): it takes the unit off the visibility map,
// calls setProto 0x4981F3, rebuilds its HP, build points and obstruction, and puts it back on the
// map, but never copies the new proto's LOS. The unit keeps the old proto's LOS until something
// else resets it. The hook (hooks/transform_hooks.asm) runs just before setProto, between the
// visibility remove and add, as build completion FUN_006A1F82 does: a unit whose LOS still equals
// its old proto's takes the new proto's (the player's copy, so its LOS techs count). A unit with
// another value (a foundation's footprint LOS, a knocked-out hero's 6) keeps it.
//
// Units that a transform replaces with a new unit (uiTransformSelectedUnit, e.g. wall -> gate;
// trUnitChangeProtoUnit) get the new proto's LOS in stock and never reach the hook.
#include <bit>
#include <cstdint>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace {

bool g_log = false;  // "transformUpdatesLOS log": one line per unit transformed in place

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

// LOS values are compared and copied as raw dwords, as stock copies them: no float operation
// touches the simulation.
float AsFloat(std::uint32_t bits) {
  return std::bit_cast<float>(bits);
}

}  // namespace

extern "C" {
void UhcTransformLosHook();

// Called by the hook at 0x9C763F with the unit and the proto setProto is about to install;
// [unit+5Ch] is still the old proto.
void __stdcall UhcTransformLos(char* unit, const char* newProto) {
  const char* oldProto = Field<const char*>(unit, 0x5C);
  char* block = Field<char*>(unit, 0xB4);
  if (oldProto == nullptr || newProto == nullptr || block == nullptr) {
    return;
  }
  const std::uint32_t unitLos = Field<std::uint32_t>(block, 0x90);
  const std::uint32_t oldLos = Field<std::uint32_t>(oldProto, 0x48);
  const std::uint32_t newLos = Field<std::uint32_t>(newProto, 0x48);
  if (unitLos != oldLos) {
    if (g_log) {
      uhc::Log(L"transformUpdatesLOS: unit %d (%hs -> %hs) keeps its own LOS %.6g (its proto's is %.6g)",
               Field<std::int32_t>(unit, 0x10), ProtoName(oldProto), ProtoName(newProto),
               static_cast<double>(AsFloat(unitLos)), static_cast<double>(AsFloat(oldLos)));
    }
    return;
  }
  *reinterpret_cast<std::uint32_t*>(block + 0x90) = newLos;
  if (g_log) {
    uhc::Log(L"transformUpdatesLOS: unit %d (%hs -> %hs) LOS %.6g -> %.6g", Field<std::int32_t>(unit, 0x10),
             ProtoName(oldProto), ProtoName(newProto), static_cast<double>(AsFloat(unitLos)),
             static_cast<double>(AsFloat(newLos)));
  }
}
}

namespace uhc {

Outcome ApplyTransformUpdatesLos(const Config& config) {
  const Config::Args* args = config.First("transformUpdatesLOS");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"transformUpdatesLOS: unknown argument %hs (expected: log); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  g_log = log;
  if (!VerifyAll("transformUpdatesLOS",
                 {&sites::kTransformSetProto, &sites::kTransformProtoLookup, &sites::kTransformPushProto,
                  &sites::kTransformVisRemove, &sites::kTransformVisAdd, &sites::kLosBuildCopyRead,
                  &sites::kLosBuildCopyWrite, &sites::kLosGetter})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kTransformSetProto.va, reinterpret_cast<const void*>(&UhcTransformLosHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"transformUpdatesLOS: units transformed in place (TransformUnit, revolution) take their new proto's "
      L"LOS%ls (multiplayer unverified)",
      log ? L", every transform logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
