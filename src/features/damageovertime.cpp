// damageOverTime: DE-style poison. A <ProtoAction> in protoy.xml that lists
// <AttachProtoUnit>X</AttachProtoUnit> attaches proto unit X to every unit it damages. For X's
// <Lifespan> seconds the damaged unit then takes, every ROF seconds, the damage of X's
// ProtoAction "Attaching", computed by the stock TakeDamage (damage type, damage bonuses,
// armor) and credited to the attacker's player. X is a data definition only: it is never
// created in the world. The hooks are in hooks/dot_hooks.asm.
#include <windows.h>

#include <algorithm>
#include <compare>
#include <cstdint>
#include <cstring>
#include <cwchar>
#include <map>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

// Engine layout (docs/engine-symbols.md, "Damage and poison").
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world, +140h database
constexpr std::int32_t kUnresolved = -2;

using TakeDamageFn = float(__fastcall*)(char* unit, void* unused, std::int32_t player, std::int32_t proto,
                                        char* action, std::int32_t attacker, float multiplier, float damage,
                                        float cap, std::int32_t, std::int32_t, std::int32_t, std::int32_t,
                                        std::int32_t, std::int32_t);
using WorldUpdateFn = bool(__fastcall*)(char* world, void* unused, std::int32_t a, std::int32_t deltaMs);
using PlayerProtoFn = char*(__thiscall*)(char* player, std::int32_t protoId);
using ProtoIdByNameFn = std::int32_t(__thiscall*)(char* database, const char* name);
using IsAliveFn = bool(__thiscall*)(char* unit);

const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kProtoIdByName = reinterpret_cast<ProtoIdByNameFn>(0x005A2346);

template <typename T>
T& Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<T*>(const_cast<char*>(base) + offset);
}

char* Game() { return *reinterpret_cast<char**>(kGameGlobal); }
char* MainWorld() { return Game() == nullptr ? nullptr : Field<char*>(Game(), 0x13C); }
char* Database() { return Game() == nullptr ? nullptr : Field<char*>(Game(), 0x140); }

// Units by ID: [world+0Ch] array, [world+10h] count; the low 18 bits index the array and
// [unit+10h] must equal the full ID.
char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char**>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

char* PlayerById(const char* world, std::int32_t id) {
  if (id < 0 || id >= Field<std::int32_t>(world, 0x5C)) {
    return nullptr;
  }
  return Field<char**>(world, 0x58)[id];
}

// A unit's proto is at [unit+5Ch]; its name, for the log, at [proto+10h].
const char* UnitProtoName(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name != nullptr ? name : "?";
}

// Unit vtable slot 0A4h (0x44D019 for units): alive and damageable, as the stock code tests
// before applying special damage.
bool IsAlive(char* unit) {
  return (*reinterpret_cast<IsAliveFn**>(unit))[0xA4 / 4](unit);
}

// ProtoAction names: [database+1FD8h] holds one UTF-16 string per name index, [+1FDCh] the
// count. An action keeps its name index at +4.
const wchar_t* ActionName(std::int32_t index) {
  const char* database = Database();
  if (database == nullptr || index < 0 || index >= Field<std::int32_t>(database, 0x1FDC)) {
    return L"?";
  }
  const wchar_t* name = Field<const wchar_t**>(database, 0x1FD8)[index];
  return name != nullptr ? name : L"?";
}

std::int32_t ActionNameIndex(const wchar_t* wanted) {
  const char* database = Database();
  if (database == nullptr) {
    return -1;
  }
  const auto names = Field<const wchar_t**>(database, 0x1FD8);
  for (std::int32_t i = 0; i < Field<std::int32_t>(database, 0x1FDC); ++i) {
    if (names[i] != nullptr && _wcsicmp(names[i], wanted) == 0) {
      return i;
    }
  }
  return -1;
}

// A proto's actions: tactics object at [proto+44h], actions at [tactics+1Ch], count [+20h].
char* FindAction(const char* proto, std::int32_t nameIndex) {
  const char* tactics = proto == nullptr ? nullptr : Field<char*>(proto, 0x44);
  if (tactics == nullptr || nameIndex < 0) {
    return nullptr;
  }
  char** actions = Field<char**>(tactics, 0x1C);
  for (std::int32_t i = 0; i < Field<std::int32_t>(tactics, 0x20); ++i) {
    if (actions[i] != nullptr && Field<std::int32_t>(actions[i], 0x04) == nameIndex) {
      return actions[i];
    }
  }
  return nullptr;
}

std::string Narrow(const wchar_t* text) {
  const int size = WideCharToMultiByte(CP_ACP, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (size <= 1) {
    return {};
  }
  std::string out(static_cast<std::size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_ACP, 0, text, -1, out.data(), size, nullptr, nullptr);
  return out;
}

// Game time in ms, [world+108h]; compared with wraparound in mind.
bool Reached(std::uint32_t now, std::uint32_t time) {
  return static_cast<std::int32_t>(now - time) >= 0;
}

struct ActionKey {
  std::int32_t proto;  // the attacker's proto ID
  std::int32_t name;   // the ProtoAction's name index
  auto operator<=>(const ActionKey&) const = default;
};

struct Attachment {
  std::string protoName;  // X, as written in protoy.xml
  std::int32_t proto = kUnresolved;
};

// Filled while protoy.xml is parsed, keyed by proto ID and action name, since every player's
// copy of a proto keeps both.
std::map<ActionKey, Attachment> g_attachments;
std::int32_t g_attachingName = kUnresolved;

struct DotKey {
  std::int32_t target;
  std::int32_t attachment;  // X's proto ID
  std::int32_t player;      // the attacker's player, who owns the damage
  auto operator<=>(const DotKey&) const = default;
};

struct Dot {
  std::int32_t attacker;  // unit ID, -1 once it is gone
  std::uint32_t nextTick;
  std::uint32_t end;
};

// Ordered by key, so every machine applies the ticks in the same order.
std::map<DotKey, Dot> g_dots;
const char* g_dotWorld = nullptr;
std::uint32_t g_lastTime = 0;
std::uint32_t g_lastStep = 0;

extern "C" void UhcDotTakeDamageStock();
extern "C" void UhcDotWorldUpdateStock();
const auto kTakeDamageStock = reinterpret_cast<TakeDamageFn>(&UhcDotTakeDamageStock);
const auto kWorldUpdateStock = reinterpret_cast<WorldUpdateFn>(&UhcDotWorldUpdateStock);

// Resolves X's proto ID and the "Attaching" name index once, logging what a modder needs to
// fix. False if this attachment cannot work.
bool Resolve(Attachment& attachment) {
  if (attachment.proto == kUnresolved) {
    char* database = Database();
    attachment.proto = database == nullptr ? -1 : kProtoIdByName(database, attachment.protoName.c_str());
    if (g_attachingName == kUnresolved) {
      g_attachingName = ActionNameIndex(L"Attaching");
    }
    // Base protos: [database+54h] array, [database+58h] count.
    const char* proto = attachment.proto < 0 || attachment.proto >= Field<std::int32_t>(database, 0x58)
                            ? nullptr
                            : Field<char**>(database, 0x54)[attachment.proto];
    const char* attaching = FindAction(proto, g_attachingName);
    if (proto == nullptr) {
      uhc::Log(L"damageOverTime: %hs is not a proto unit; its attachments are ignored",
               attachment.protoName.c_str());
      attachment.proto = -1;
    } else if (attaching == nullptr) {
      uhc::Log(L"damageOverTime: %hs has no ProtoAction named Attaching (its tactics file must "
               L"define the action); its attachments are ignored",
               attachment.protoName.c_str());
      attachment.proto = -1;
    } else {
      uhc::Log(L"damageOverTime: %hs -> proto %d: Lifespan %.2f s, Attaching every %d ms",
               attachment.protoName.c_str(), attachment.proto, Field<float>(proto, 0xAC),
               Field<std::int32_t>(attaching, 0x34));
    }
  }
  return attachment.proto >= 0;
}

// X's Attaching action in the player's copy of X, so techs that change X apply.
char* PlayerAttaching(const char* world, std::int32_t player, std::int32_t attachment, const char** proto) {
  char* owner = PlayerById(world, player);
  *proto = owner == nullptr ? nullptr : kPlayerProto(owner, attachment);
  return FindAction(*proto, g_attachingName);
}

// The engine's diplomacy filter (FUN_0049AEE0) for a tick whose attacking unit is gone: without
// an attacking unit the engine lets every unit through, so the poison applies it with the
// attacker's player instead. DamageFlags are at [[action+24h]+4] (GAIA 1, Self 2, Ally 4,
// Enemy 8; FFh when the data sets none); a player's relations at [player+1D4h + 4*id], 2 = enemy.
bool DamageAllowed(const char* world, const char* attaching, std::int32_t player, const char* unit) {
  const char* info = Field<const char*>(attaching, 0x24);
  const char* owner = Field<const char*>(unit, 0x44);
  const char* attackerPlayer = PlayerById(world, player);
  if (info == nullptr || owner == nullptr || attackerPlayer == nullptr) {
    return true;
  }
  const std::uint8_t flags = Field<std::uint8_t>(info, 0x04);
  const std::int32_t unitPlayer = Field<std::int32_t>(owner, 0x00);
  if ((unitPlayer == 0 && !(flags & 1)) || (unitPlayer == player && !(flags & 2))) {
    return false;
  }
  const bool enemy = unitPlayer >= 0 && unitPlayer <= 15 &&
                     Field<std::int32_t>(attackerPlayer, 0x1D4 + 4 * static_cast<std::uint32_t>(unitPlayer)) == 2;
  return (flags & (enemy ? 8 : 4)) != 0;
}

// The Attaching ROF, stored in ms at [action+34h]; one second if it is missing.
std::uint32_t TickInterval(const char* attaching) {
  const std::int32_t rof = Field<std::int32_t>(attaching, 0x34);
  return static_cast<std::uint32_t>(rof > 0 ? rof : 1000);
}

// From the database load hook (unittypes.h), before the protos' contents are read: the data
// is loaded at startup and again when a skirmish starts (not when a scenario loads). Each load
// reads the tags again, and running poisons belong to the previous game.
void ResetForDataLoad(char*) {
  if (!g_dots.empty()) {
    uhc::Log(L"damageOverTime: the data was reloaded; %u running poison(s) dropped",
             static_cast<unsigned>(g_dots.size()));
  }
  g_attachments.clear();
  g_attachingName = kUnresolved;
  g_dots.clear();
  g_dotWorld = nullptr;
}

// Drops every poison when another game is running: a new or loaded game can reuse the old
// world's address, so the test is the world's step count [world+F8h], which the world update
// raises by exactly 1 per step (0x481A87), and the game time going back. While poisons run, Tick
// sees every step; with none running, a jump only clears an empty map.
void SyncWorld(const char* world, std::uint32_t now) {
  const std::uint32_t step = Field<std::uint32_t>(world, 0xF8);
  if (world != g_dotWorld || !Reached(now, g_lastTime) || step - g_lastStep > 1) {
    if (!g_dots.empty()) {
      uhc::Log(L"damageOverTime: another game started; %u running poison(s) dropped",
               static_cast<unsigned>(g_dots.size()));
    }
    g_dots.clear();
    g_dotWorld = world;
  }
  g_lastTime = now;
  g_lastStep = step;
}

// One-time diagnostics: each reason is logged the first time it happens, so a modder can see
// why a poison did not start or did no damage without the log growing in long games.
bool g_loggedNoAttaching = false;
bool g_loggedNotAlive = false;
bool g_loggedNoLifespan = false;
bool g_loggedFirstPoison = false;
bool g_loggedFirstTick = false;
// "damageOverTime log" in uhc.cfg: every poison start, refresh, tick and end, for tuning data.
bool g_logEvery = false;

void Attach(char* target, std::int32_t player, std::int32_t attacker, std::int32_t attachment) {
  const char* world = MainWorld();
  const char* proto = nullptr;
  const char* attaching = world == nullptr ? nullptr : PlayerAttaching(world, player, attachment, &proto);
  const std::int32_t targetId = Field<std::int32_t>(target, 0x10);
  if (attaching == nullptr) {
    if (!g_loggedNoAttaching) {
      g_loggedNoAttaching = true;
      uhc::Log(L"damageOverTime: player %d's copy of proto %d has no Attaching action; unit %d not poisoned", player,
               attachment, targetId);
    }
    return;
  }
  if (!IsAlive(target)) {
    if (!g_loggedNotAlive) {
      g_loggedNotAlive = true;
      uhc::Log(L"damageOverTime: unit %d is no longer alive and damageable; not poisoned", targetId);
    }
    return;
  }
  const float lifespan = Field<float>(proto, 0xAC);
  if (!(lifespan > 0.0f)) {
    if (!g_loggedNoLifespan) {
      g_loggedNoLifespan = true;
      uhc::Log(L"damageOverTime: player %d's copy of proto %d has Lifespan %.2f; unit %d not poisoned", player,
               attachment, lifespan, targetId);
    }
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  SyncWorld(world, now);
  const DotKey key{targetId, attachment, player};
  const auto [it, added] = g_dots.try_emplace(key, Dot{attacker, now + TickInterval(attaching), 0});
  Dot& dot = it->second;
  // A new hit by the player's units makes that unit the attacker and restarts the duration
  // (with the current Lifespan); the tick timer keeps running.
  // Capped so the end stays within the 2^31 ms window that Reached() compares.
  dot.attacker = attacker;
  dot.end = now + static_cast<std::uint32_t>(
                      std::min(static_cast<double>(lifespan) * 1000.0, 2147483647.0 - TickInterval(attaching)));
  if (!g_loggedFirstPoison || g_logEvery) {
    g_loggedFirstPoison = true;
    uhc::Log(L"damageOverTime: %ls: unit %d (%hs) by player %d, proto %d, every %u ms until game time %u (now %u, "
             L"%u active)",
             added ? L"poison" : L"poison renewed", targetId, UnitProtoName(target), player, attachment,
             TickInterval(attaching), dot.end, now, static_cast<unsigned>(g_dots.size()));
  }
}

// One tick: the stock TakeDamage with X's Attaching action, called the way the stock
// special-damage callers call it (0x986237 and others): multiplier 1, damage computed from the
// action, no stats slot. Returns the damage dealt.
// The 11th argument turns on the hit notifications (retaliation, attack alerts, the army's
// attacker list). The army code (0x6A3253) reads the attacking unit without a null check, so an
// army unit (AI armies) poisoned by a unit that is gone would crash the game: with no attacking
// unit the tick passes 0 and skips them (the jne at 0x49B929).
float ApplyTick(char* target, char* attaching, const DotKey& key, const Dot& dot) {
  const std::int32_t notify = dot.attacker >= 0 ? 1 : 0;
  return kTakeDamageStock(target, nullptr, key.player, key.attachment, attaching, dot.attacker, 1.0f, 0.0f, 0.0f, 0, 0,
                          1, notify, -2, 1);
}

void Tick(char* world) {
  if (world != MainWorld()) {
    return;  // other worlds run the same update; the function itself compares this with [game+13Ch]
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  SyncWorld(world, now);
  for (auto it = g_dots.begin(); it != g_dots.end();) {
    const DotKey& key = it->first;
    Dot& dot = it->second;
    char* target = UnitById(world, key.target);
    bool alive = target != nullptr && IsAlive(target);
    while (alive && Reached(now, dot.nextTick) && Reached(dot.end, dot.nextTick)) {
      const char* proto = nullptr;
      char* attaching = PlayerAttaching(world, key.player, key.attachment, &proto);
      if (attaching == nullptr) {
        alive = false;  // cannot happen once resolved; drop the poison rather than loop
        break;
      }
      if (UnitById(world, dot.attacker) == nullptr) {
        dot.attacker = -1;
      }
      const float dealt =
          dot.attacker >= 0 || DamageAllowed(world, attaching, key.player, target) ? ApplyTick(target, attaching, key, dot)
                                                                                   : 0.0f;
      if (!g_loggedFirstTick || g_logEvery) {
        g_loggedFirstTick = true;
        uhc::Log(L"damageOverTime: tick: unit %d (%hs) took %.2f damage, %.1f hitpoints left (tick due %u, game "
                 L"time %u)",
                 key.target, UnitProtoName(target), dealt, Field<float>(target, 0x64), dot.nextTick, now);
      }
      dot.nextTick += TickInterval(attaching);
      alive = IsAlive(target);
    }
    if (!alive || Reached(now, dot.end)) {
      if (g_logEvery) {
        uhc::Log(L"damageOverTime: poison on unit %d ended at game time %u: %ls", key.target, now,
                 !alive ? (target == nullptr ? L"unit gone" : L"unit dead or not damageable") : L"expired");
      }
      it = g_dots.erase(it);
    } else {
      ++it;
    }
  }
}

}  // namespace

extern "C" {

// From the tag hook, for each <ProtoAction> child of protoy.xml the stock parser does not know.
// tag is the address of the child's tag-name BString (its UTF-16 text is *tag); the child's text
// is at [node+14h]. [proto+4] is the proto ID, [proto+10h] its name.
void __stdcall UhcDotProtoActionTag(const wchar_t* const* tag, const char* node, const char* proto,
                                    const char* action) {
  if (tag == nullptr || *tag == nullptr || _wcsicmp(*tag, L"AttachProtoUnit") != 0) {
    return;
  }
  const char* protoName = Field<const char*>(proto, 0x10);
  const ActionKey key{Field<std::int32_t>(proto, 0x04), Field<std::int32_t>(action, 0x04)};
  const wchar_t* text = Field<const wchar_t*>(node, 0x14);
  if (text == nullptr || *text == L'\0') {
    uhc::Log(L"damageOverTime: %hs/%ls: empty <AttachProtoUnit>; ignored", protoName, ActionName(key.name));
    return;
  }
  g_attachments[key] = Attachment{Narrow(text)};
  uhc::Log(L"damageOverTime: %hs/%ls attaches %ls", protoName, ActionName(key.name), text);
}

float __fastcall UhcDotTakeDamage(char* unit, void*, std::int32_t player, std::int32_t proto, char* action,
                                  std::int32_t attacker, float multiplier, float damage, float cap, std::int32_t a8,
                                  std::int32_t a9, std::int32_t a10, std::int32_t a11, std::int32_t a12,
                                  std::int32_t a13) {
  const float dealt = kTakeDamageStock(unit, nullptr, player, proto, action, attacker, multiplier, damage, cap, a8, a9,
                                       a10, a11, a12, a13);
  if (dealt > 0.0f && action != nullptr && !g_attachments.empty()) {
    const auto it = g_attachments.find({proto, Field<std::int32_t>(action, 0x04)});
    if (it != g_attachments.end() && Resolve(it->second)) {
      Attach(unit, player, attacker, it->second.proto);
    }
  }
  return dealt;
}

bool __fastcall UhcDotWorldUpdate(char* world, void*, std::int32_t a, std::int32_t deltaMs) {
  const bool result = kWorldUpdateStock(world, nullptr, a, deltaMs);
  if (!g_dots.empty()) {
    Tick(world);
  }
  return result;
}

void* g_uhcDotTakeDamage = reinterpret_cast<void*>(&UhcDotTakeDamage);
void* g_uhcDotWorldUpdate = reinterpret_cast<void*>(&UhcDotWorldUpdate);

void UhcDotTakeDamageHook();
void UhcDotWorldUpdateHook();
void UhcDotProtoActionTagHook();
}

namespace uhc {

Outcome ApplyDamageOverTime(const Config& config) {
  const Config::Args* args = config.First("damageOverTime");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_logEvery = true;
    } else {
      Log(L"damageOverTime: unknown argument %hs (expected: log)", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("damageOverTime", {&sites::kDotTakeDamageEntry, &sites::kDotWorldUpdateEntry,
                                    &sites::kDotProtoActionTag, &sites::kDotProtoActionCall}) ||
      !OnDatabaseLoad(&ResetForDataLoad)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(0x005FA11E, reinterpret_cast<const void*>(&UhcDotProtoActionTagHook), 8) ||
      !WriteJmp(sites::kDotTakeDamageEntry.va, reinterpret_cast<const void*>(&UhcDotTakeDamageHook), 6) ||
      !WriteJmp(sites::kDotWorldUpdateEntry.va, reinterpret_cast<const void*>(&UhcDotWorldUpdateHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"damageOverTime: <AttachProtoUnit> in protoy.xml ProtoActions attaches damage over time "
      L"(multiplayer unverified)");
  return Outcome::kApplied;
}

}  // namespace uhc
