// customImpactTypes <Name> [<Name> ...] [log]: impact types beyond the game's 15 (Wood, Stone, Flesh, Animal,
// TerrainGrass, Snow, Dirt, TerrainWater, TerrainDirt, TerrainStone, TerrainSnow, TerrainSand, RoofTile,
// ExitBuilding, Metal; the wchar[32] table at 0xBA4D70, read by FUN_0059F436).
//
// A type name is read in four places, all through FUN_0059F436: a damage template's impacttype (.dmg), a proto's
// <ImpactType>, a terrain type's ImpactType, and the element names of an .impacteffect file. The key makes that
// lookup answer 15 + the name's index for the names given here. An impact effect keeps one list of entries per
// stock type inside its object ([effect + 4 + type * 12], 15 lists, FUN_005FE8CD); the entries of a custom type
// go to a list the DLL keeps for that effect instead, built with the same list add (FUN_00401F74) and the same
// cumulative weights. The spawn FUN_0049C1E5 refuses a type above 14, so at its two calls (the projectile hit and
// the terrain impact) a custom type is played by lending its list to the effect's Metal slot for the stock call,
// which then picks an entry and plays its particle set, sounds and fire as for any type, and giving the slot
// back. Rendering and sound only: nothing here changes the simulation.
#include <cstdint>
#include <cstring>
#include <map>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcImpactTypeNotFoundHook();
extern "C" void UhcImpactEffectAddHook();
extern "C" void UhcImpactEffectWeightsHook();
extern "C" void UhcImpactSpawnUnitHook();
extern "C" void UhcImpactSpawnTerrainHook();

namespace {

constexpr std::int32_t kStockTypes = 15;
constexpr std::int32_t kLentSlot = 14;  // Metal: its list is lent to a custom type for one spawn
constexpr std::size_t kMaxCustom = 64;

// The game's dynamic array of entry pointers, as at [effect + 4 + type * 12].
struct EntryList {
  void** data;
  std::int32_t count;
  std::int32_t capacity;
};

using StringCompare = std::int32_t(__thiscall*)(const void* string, const wchar_t* text, std::int32_t, std::int32_t);
using ListAdd = std::int32_t(__thiscall*)(EntryList* list, void* const* entry);
using Spawn = std::int32_t(__thiscall*)(void* effect, std::uint32_t, std::uint32_t, std::uint32_t, std::uint32_t,
                                        std::uint32_t, std::uint32_t, std::uint32_t, std::uint32_t);
const auto kStringCompare = reinterpret_cast<StringCompare>(0x00443C10);
const auto kListAdd = reinterpret_cast<ListAdd>(0x00401F74);
const auto kSpawn = reinterpret_cast<Spawn>(0x0049C1E5);

std::vector<std::wstring> g_names;
bool g_log = false;
// The custom lists of each impact effect, one per custom name. Data load only; an effect read again (or a
// new one at a freed effect's address) starts from empty lists (g_parsing).
std::map<const void*, std::vector<EntryList>> g_lists;
const void* g_parsing = nullptr;
std::vector<bool> g_loggedSpawn;

}  // namespace

extern "C" std::int32_t __stdcall UhcCustomImpactType(const void* name) {
  for (std::size_t i = 0; i < g_names.size(); ++i) {
    if (kStringCompare(name, g_names[i].c_str(), 0, -1) == 0) {
      return kStockTypes + static_cast<std::int32_t>(i);
    }
  }
  return -1;
}

extern "C" void __stdcall UhcAddCustomImpact(const void* effect, std::int32_t type, void* entry) {
  const std::int32_t index = type - kStockTypes;
  if (index < 0 || index >= static_cast<std::int32_t>(g_names.size())) {
    return;  // cannot happen: only the lookup above makes such types
  }
  std::vector<EntryList>& lists = g_lists[effect];
  if (g_parsing != effect) {
    g_parsing = effect;
    lists.assign(g_names.size(), EntryList{nullptr, 0, 0});  // a new read of this effect
  }
  kListAdd(&lists[static_cast<std::size_t>(index)], &entry);
  static int debugAdds = 0;
  if (g_log && debugAdds++ < 8) uhc::Log(L"DEBUG add effect %p type %d count %d", effect, type, lists[static_cast<std::size_t>(index)].count);
}

extern "C" void __stdcall UhcFinishImpactEffect(const void* effect) {
  if (g_parsing != effect) {
    g_lists.erase(effect);  // read again with no custom entry
  }
  g_parsing = nullptr;
  const auto found = g_lists.find(effect);
  if (found == g_lists.end()) {
    return;
  }
  // As FUN_005FE8CD does for the stock lists: each entry's weight [+20h] (0 counts as 1) becomes the running sum.
  for (EntryList& list : found->second) {
    std::int32_t sum = 0;
    for (std::int32_t i = 0; i < list.count; ++i) {
      char* entry = static_cast<char*>(list.data[i]);
      if (entry == nullptr) {
        continue;
      }
      std::int32_t& weight = *reinterpret_cast<std::int32_t*>(entry + 0x20);
      sum += weight == 0 ? 1 : weight;
      weight = sum;
    }
  }
}

extern "C" std::int32_t __stdcall UhcSpawnCustomImpact(char* effect, const std::uint32_t* args) {
  const std::int32_t index = static_cast<std::int32_t>(args[3]) - kStockTypes;
  const auto found = g_lists.find(effect);
  if (effect == nullptr || index < 0 || index >= static_cast<std::int32_t>(g_names.size()) ||
      found == g_lists.end() || found->second[static_cast<std::size_t>(index)].count <= 0) {
    static int debugMiss = 0;
    if (g_log && debugMiss++ < 8) uhc::Log(L"DEBUG spawn miss effect %p type %d found %d", effect, (int)args[3], found != g_lists.end() ? 1 : 0);
    return -1;  // as the stock spawn does for a type with no entry
  }
  if (g_log && !g_loggedSpawn[static_cast<std::size_t>(index)]) {
    g_loggedSpawn[static_cast<std::size_t>(index)] = true;
    uhc::Log(L"customImpactTypes: first impact of type %ls (%d)", g_names[static_cast<std::size_t>(index)].c_str(),
             kStockTypes + index);
  }
  EntryList* slot = reinterpret_cast<EntryList*>(effect + 4 + kLentSlot * 12);
  const EntryList saved = *slot;
  *slot = found->second[static_cast<std::size_t>(index)];
  const std::int32_t result =
      kSpawn(effect, args[0], args[1], args[2], kLentSlot, args[4], args[5], args[6], args[7]);
  found->second[static_cast<std::size_t>(index)] = *slot;  // the spawn does not change a list; kept in step anyway
  *slot = saved;
  return result;
}

namespace uhc {

Outcome ApplyCustomImpactTypes(const Config& config) {
  const Config::Args* args = config.First("customImpactTypes");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  static const wchar_t* const kStock[] = {L"Wood",        L"Stone",        L"Flesh",       L"Animal",
                                          L"TerrainGrass", L"Snow",         L"Dirt",        L"TerrainWater",
                                          L"TerrainDirt", L"TerrainStone", L"TerrainSnow", L"TerrainSand",
                                          L"RoofTile",    L"ExitBuilding", L"Metal"};
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    std::wstring name(arg.begin(), arg.end());
    bool clash = name.empty() || name.size() >= 32;
    for (const wchar_t* stock : kStock) {
      clash = clash || _wcsicmp(stock, name.c_str()) == 0;
    }
    for (const std::wstring& other : g_names) {
      clash = clash || _wcsicmp(other.c_str(), name.c_str()) == 0;
    }
    if (clash || g_names.size() >= kMaxCustom) {
      Log(L"customImpactTypes: '%hs' is a stock or repeated name, too long (31 at most) or one too many (%u at most); "
          L"not applied",
          arg.c_str(), static_cast<unsigned>(kMaxCustom));
      g_names.clear();
      return Outcome::kFailed;
    }
    g_names.push_back(name);
  }
  if (g_names.empty()) {
    Log(L"customImpactTypes: no type name given; not applied");
    return Outcome::kFailed;
  }
  g_loggedSpawn.assign(g_names.size(), false);
  if (!VerifyAll("customImpactTypes",
                 {&sites::kImpactTypeNotFound, &sites::kImpactEffectAdd, &sites::kImpactEffectWeights,
                  &sites::kImpactSpawnUnit, &sites::kImpactSpawnTerrain, &sites::kStringCompareW, &sites::kImpactSpawn})) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kImpactTypeNotFound.va, reinterpret_cast<const void*>(&UhcImpactTypeNotFoundHook), 7) ||
      !WriteJmp(sites::kImpactEffectAdd.va, reinterpret_cast<const void*>(&UhcImpactEffectAddHook), 0x15) ||
      !WriteJmp(sites::kImpactEffectWeights.va, reinterpret_cast<const void*>(&UhcImpactEffectWeightsHook), 7) ||
      !WriteJmp(sites::kImpactSpawnUnit.va, reinterpret_cast<const void*>(&UhcImpactSpawnUnitHook), 5) ||
      !WriteJmp(sites::kImpactSpawnTerrain.va, reinterpret_cast<const void*>(&UhcImpactSpawnTerrainHook), 5)) {
    return Outcome::kFailed;
  }
  std::wstring list;
  for (std::size_t i = 0; i < g_names.size(); ++i) {
    list += (i == 0 ? L"" : L", ") + g_names[i] + L" (" + std::to_wstring(kStockTypes + static_cast<int>(i)) + L")";
  }
  Log(L"customImpactTypes: %ls", list.c_str());
  return Outcome::kApplied;
}

}  // namespace uhc
