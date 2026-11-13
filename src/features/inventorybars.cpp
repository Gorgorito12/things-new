// inventoryBars [UnitType] [always] [log]: while Alt is held, a unit with a resource inventory shows a second
// floating bar under its HP bar: what it still holds, as a share of what it was created with, in the colour of the
// resource it holds most of.
//
// Stock: holding Alt shows the HP bar of every unit whose proto has the HP bar flag (proto flag 5), with the profile
// option 57h on (FUN_00451F9D: the modifier query 0x473E37(2) into BL at 0x452EBD, read at 0x511D80). Each unit with
// resources has its own inventory at [[unit+B4h]+94h] (+4 a resource list), seeded at creation from its proto's
// resource object [proto+E0h] (+0 the InitialResource list): gathering takes from the inventory, and nothing on
// screen shows how much is left.
//
// The bar is queued right after the unit's HP bar, through the shared floating bar hooks (floatingbars.h), with the
// Alt state the bar chunk read, so it shows for the units whose HP bar shows then. Its kind (player ID 0x80494E00 |
// resource) moves its six vertices one bar height and a gap down the camera's up vector and gives them the resource's
// colour. Display only: reading the inventory changes nothing, and Alt is this machine's key. "always" shows the bars
// with every HP bar, Alt or not (for a test or a video).
#include <windows.h>

#include <bit>
#include <cstdint>
#include <cstdlib>
#include <set>
#include <string>

#include "../features.h"
#include "../floatingbars.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::uint32_t kKind = 0x80494E00;  // 'IN', negative: no player has it; the low byte is the resource
// A resource list is 8 bytes: +0 an array of [kResourceCount] floats, entry r XORed with the dword at
// kEntryKeys + 4r; +4 their total, XORed with [kTotalKey] (ResList total recompute 0x58EF02).
constexpr std::uint32_t kTotalKey = 0x00C6DF10;
constexpr std::uint32_t kEntryKeys = 0x00C6DF14;
constexpr std::uint32_t kResourceCount = 0x00C6DF38;
constexpr std::int32_t kMaxResources = 64;
constexpr float kEpsilon = 1e-6f;  // the engine's "holds this resource" threshold (0xBA1388)
constexpr unsigned kMaxLogLines = 40;

using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

// ARGB per resource ID: 0 Gold, 1 Wood, 2 Food; any other (Fame, XP, a mod's own) the last one.
constexpr std::uint32_t kColours[] = {0xFFFFD23C, 0xFFB4783C, 0xFFE8503C};
std::uint32_t g_otherColour = 0xFF50B4FF;

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +3C0h the local player's ID

bool g_always = false;
bool g_trees = false;         // "trees": trees too, on the no-HP-bar path
std::int32_t g_treeType = -1;  // the built-in unittype Tree, set on each database load
bool g_log = false;
bool g_typeGiven = false;
std::int32_t g_type = -1;  // the UnitType's ID, set on each database load
std::string g_typeName;
std::set<std::int32_t> g_loggedProtos;
std::set<std::int32_t> g_sitesLogged;  // "log": protos whose bar position on the no-HP-bar path was logged
unsigned g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

std::uint32_t Global(std::uint32_t va) {
  return *reinterpret_cast<const std::uint32_t*>(static_cast<std::uintptr_t>(va));
}

// Entry r of a resource list, decoded as ResList get 0x44EFFF does; 0 if the list has no array.
float Amount(const char* list, std::int32_t r) {
  const auto* entries = Field<const std::uint32_t*>(list, 0);
  if (entries == nullptr) {
    return 0.0f;
  }
  return std::bit_cast<float>(entries[r] ^ Global(kEntryKeys + 4u * static_cast<std::uint32_t>(r)));
}

float Total(const char* list) { return std::bit_cast<float>(Field<std::uint32_t>(list, 4) ^ Global(kTotalKey)); }

// Queues the inventory bar of a unit with resources, at the position of its HP bar.
void QueueInventoryBar(const char* unit, const float* position, bool altHeld) {
  const char* proto = Field<const char*>(unit, 0x5C);
  const char* block = Field<const char*>(unit, 0xB4);
  if (proto == nullptr || block == nullptr) {
    return;
  }
  const char* inventory = Field<const char*>(block, 0x94);
  const char* resources = Field<const char*>(proto, 0xE0);
  if (inventory == nullptr || resources == nullptr) {
    return;
  }
  if (g_typeGiven && (g_type < 0 || !kProtoIsType(proto, g_type))) {
    return;
  }
  const std::int32_t count = static_cast<std::int32_t>(Global(kResourceCount));
  if (count <= 0 || count > kMaxResources) {
    return;
  }
  const float initial = Total(resources);
  if (!(initial > kEpsilon)) {
    return;
  }
  const char* held = inventory + 4;
  // The colour: the resource it holds most of; an empty inventory, the one it was created with most of.
  std::int32_t main = -1;
  float most = kEpsilon;
  for (const char* list : {held, resources}) {
    for (std::int32_t r = 0; r < count; ++r) {
      const float amount = Amount(list, r);
      if (amount > most) {
        most = amount;
        main = r;
      }
    }
    if (main >= 0) {
      break;
    }
  }
  if (main < 0) {
    return;
  }
  float fill = Total(held) / initial;
  fill = fill < 0.0f ? 0.0f : (fill > 1.0f ? 1.0f : fill);
  uhc::QueueFloatingBar(position, fill, kKind | static_cast<std::uint32_t>(main & 0xFF));
  if (g_log && g_logLines < kMaxLogLines && g_loggedProtos.insert(Field<std::int32_t>(proto, 0x04)).second) {
    ++g_logLines;
    const char* name = Field<const char*>(proto, 0x10);
    uhc::Log(L"inventoryBars: unit %d (%hs) holds %.1f of %.1f (resource %d most): bar %.0f %% at (%.1f, %.1f, %.1f)"
             L"%ls; logged once per proto",
             Field<std::int32_t>(unit, 0x10), name == nullptr ? "?" : name, static_cast<double>(Total(held)),
             static_cast<double>(initial), main, static_cast<double>(fill * 100.0f), static_cast<double>(position[0]),
             static_cast<double>(position[1]), static_cast<double>(position[2]), altHeld ? L", Alt held" : L"");
  }
}

// After a unit's HP bar was queued (floatingbars.h).
void BarQueued(const char* unit, const float* position, bool constructing, bool altHeld) {
  if (!constructing && (altHeld || g_always)) {
    QueueInventoryBar(unit, position, altHeld);
  }
}

// The six vertices of an inventory bar: one bar height and a gap below the HP bar, in the resource's colour.
void BarVertices(const uhc::FloatingBarRecord& record, uhc::FloatingBarVertex* vertices, const char* camera) {
  const std::uint32_t resource = static_cast<std::uint32_t>(record.player) & 0xFFu;
  const std::uint32_t colour = resource < sizeof(kColours) / sizeof(kColours[0]) ? kColours[resource] : g_otherColour;
  // The quad's half height is scale / 16 along the camera's up vector A (0x45C4AF): the bar is scale / 8 high.
  const float drop = record.scale * 0.17f;
  const float* up = reinterpret_cast<const float*>(camera + 0x1C);
  for (int k = 0; k < 6; ++k) {
    for (int axis = 0; axis < 3; ++axis) {
      vertices[k].position[axis] -= drop * up[axis];
    }
    vertices[k].colour = colour;
  }
}

void ResetForDataLoad(char*) {
  g_loggedProtos.clear();
  g_sitesLogged.clear();
  g_logLines = 0;
}

// FUN_004605C1, thiscall(unit, vec3* out): the size of the unit's visual (its bounding box), into out.
using VisualSizeFn = const float*(__thiscall*)(const char* unit, float* out);
const auto kVisualSize = reinterpret_cast<VisualSizeFn>(0x004605C1);

}  // namespace

extern "C" {

void UhcInventoryNoHpBarHook();  // hooks/inventorybars_hooks.asm
std::int32_t g_uhcInventorySites = 1;   // 0 with "noSites"
std::int32_t g_uhcInventoryAlways = 0;  // 1 with "always"

// From the hook at 0x452F1B, for a unit with no HP bar (a mine, a tree, a bush) while Alt is held, or always: its
// bar goes where the bar chunk's fallback (0x460633) would put an HP bar, the unit's position raised by its visual's
// height plus [[unit+B4h]+24h], times its scale [unit+A8h], plus 1.
void __stdcall UhcInventoryNoHpBar(const char* unit, const float* position, std::int32_t altHeld) {
  if (unit == nullptr || position == nullptr || Field<const char*>(unit, 0xB4) == nullptr) {
    return;
  }
  // Only what the local player ([game+3C0h]) sees now: the visual update also runs for units drawn under the black
  // map and the fog, whose HP bar stock never shows. [[unit+B4h]+ACh] is the mask of the players that see the unit
  // (0x486A60).
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const std::int32_t local = game == nullptr ? -1 : Field<std::int32_t>(game, 0x3C0);
  if (local < 0 || local >= 32 || (Field<std::uint32_t>(Field<const char*>(unit, 0xB4), 0xAC) & (1u << local)) == 0) {
    return;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  if (!g_trees && g_treeType >= 0 && proto != nullptr && kProtoIsType(proto, g_treeType)) {
    return;
  }
  float size[3] = {0.0f, 0.0f, 0.0f};
  const float* box = kVisualSize(unit, size);
  const float height = box == nullptr ? 0.0f : box[1];
  // The fallback's base [[esp+48h]] keeps the height 0 for such a unit (seen in game: a mine at y 0.0 on ground at
  // about 1.3); its own position [unit+14h] has the ground's height.
  const float* ground = reinterpret_cast<const float*>(unit + 0x14);
  float bar[3] = {position[0], ground[1] > position[1] ? ground[1] : position[1], position[2]};
  bar[1] += (height + Field<float>(Field<const char*>(unit, 0xB4), 0x24)) * Field<float>(unit, 0xA8) + 1.0f;
  if (g_log && g_logLines < kMaxLogLines && g_sitesLogged.insert(Field<std::int32_t>(proto, 0x04)).second) {
    ++g_logLines;
    uhc::Log(L"inventoryBars: unit %d with no HP bar at (%.1f, %.1f, %.1f): bar at height %.2f (visual %.2f, offset "
             L"%.2f, scale %.2f)",
             Field<std::int32_t>(unit, 0x10), static_cast<double>(position[0]), static_cast<double>(position[1]),
             static_cast<double>(position[2]), static_cast<double>(bar[1]), static_cast<double>(height),
             static_cast<double>(Field<float>(Field<const char*>(unit, 0xB4), 0x24)),
             static_cast<double>(Field<float>(unit, 0xA8)));
  }
  QueueInventoryBar(unit, bar, altHeld != 0);
}

}  // extern "C"

namespace uhc {

Outcome ApplyInventoryBars(const Config& config) {
  const Config::Args* args = config.First("inventoryBars");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "always") == 0) {
      g_always = true;
      g_uhcInventoryAlways = 1;
    } else if (_stricmp(arg.c_str(), "noSites") == 0) {
      g_uhcInventorySites = 0;
    } else if (_stricmp(arg.c_str(), "trees") == 0) {
      g_trees = true;
    } else if (_strnicmp(arg.c_str(), "other=", 6) == 0) {
      char* end = nullptr;
      const unsigned long rgb = std::strtoul(arg.c_str() + 6, &end, 16);
      if (arg.size() != 12 || end != arg.c_str() + 12) {
        Log(L"inventoryBars: %hs: expected other=RRGGBB (hex); feature not applied", arg.c_str());
        return Outcome::kFailed;
      }
      g_otherColour = 0xFF000000u | static_cast<std::uint32_t>(rgb);
    } else if (!g_typeGiven) {
      g_typeGiven = true;
      g_typeName = arg;
    } else {
      Log(L"inventoryBars: unexpected argument %hs (expected: [UnitType] [always] [noSites] [trees] [other=RRGGBB] [log]); "
          L"feature not applied",
          arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("inventoryBars", {&sites::kIsA, &sites::kIsATrue, &sites::kInventoryNoHpBar,
                                   &sites::kSteadyBarFallback, &sites::kVisualSize}) ||
      !OnDatabaseLoad(&ResetForDataLoad) || (g_typeGiven && !RequestAbstractUnitType(g_typeName.c_str(), &g_type)) ||
      !RequestAbstractUnitType("Tree", &g_treeType) ||
      !AddFloatingBarQueued(&BarQueued, "inventoryBars") || !AddFloatingBarKind(kKind, &BarVertices, "inventoryBars")) {
    return Outcome::kFailed;
  }
  // test al,al / jne 45F78Bh (8 B) at 0x452F1B: the HP bar flag test of the unit visual update.
  if (g_uhcInventorySites != 0 &&
      !WriteJmp(0x00452F1B, reinterpret_cast<const void*>(&UhcInventoryNoHpBarHook), 8)) {
    return Outcome::kFailed;
  }
  Log(L"inventoryBars: units%hs%hs with resources show what they hold under their HP bar %ls%ls (display only)",
      g_typeGiven ? " of unittype " : "", g_typeGiven ? g_typeName.c_str() : "",
      g_always ? L"whenever it shows (always)" : L"while Alt is held",
      g_uhcInventorySites == 0 ? L""
      : g_trees                ? L"; units with no HP bar (mines, bushes, trees) too"
                               : L"; units with no HP bar but trees (mines, bushes) too");
  return Outcome::kApplied;
}

}  // namespace uhc
