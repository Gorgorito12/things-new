// autoScout [ScoutTactic [ReturnTactic]] [log]: a unit whose current tactic is ScoutTactic (default "AutoScout")
// explores the map on its own.
//
// The data decides who scouts: a unit gets the behaviour from a tactic of that name in its tactics file, and
// buttons that set it (unitSetTactic, a command every machine runs and saved games keep). A unit whose first
// tactic is the scouting one scouts from birth.
//
// After each world update (the shared wrapper of worldtick.cpp), every 500 ms of game time:
// - every unit of every player (the player's unit list [player+F8h], walked in ID order) whose current tactic
//   [[[proto+44h]+10h][[mgr+A8h]]+8] is the scouting tactic's name ID is a scout;
// - the player's visibility grid ([world+250h]: width +14h, height +18h, dword cells +20h, the player's mask
//   [[world+2D8h]+4*id]; low half explored, high half visible, 0x44E9FE) is summed in blocks of 8x8 cells;
// - a scout that is idle (0x44F1A7), or still on the move order it got from here, gets a new order when it has
//   none, or when its target became explored: the move order of the action manager 0x50E36A (the one the unit
//   order code gives, 0x9444D3), to the unexplored cell nearest to it that its movement type ([proto+1D2h]: 1
//   land, 2 water, 4 air) can stand on (water from the terrain's per-tile water lookup, vtable +194h), skipping
//   blocks another scout of the player has taken and blocks it could not reach, and weighing cells behind its
//   heading against them; the move sets action flag 17h, which the action manager's leash 0x489B15 skips;
// - a scout that stops with its target still unexplored, or is on one target for more than 90 s, gives that
//   block up (it could not get there); with nothing unexplored left in reach, it goes to the block not visible
//   now that was seen longest ago (by game time), the nearest first among equals;
// - a scout's leash anchor [mgr+7Ch] follows it, so that a unit that stops scouting stays where it is.
// Any other action (a fight, a flee) is left alone; the scout goes on once it is idle again.
//
// The switch-off: the head of the command execute 0x7C8E49 (hooks/autoscout_hooks.asm), which the world update
// runs for each command in turn, on every machine. A unit order (command type 0: move, attack, gather,
// garrison; type 9: stop) from the unit's owner to a scout that is not inside another unit first puts it in its
// return tactic (ReturnTactic, or the first tactic of its file that is not the scouting one) through the stock
// setTactic 0x4F7ECD, as the SetTactic command does (0x7D107C); then the order applies. Without that hook (another
// DLL owns the site) the key works without the switch-off, and the Stop-scouting button is the way out.
//
// Everything read is simulation state (no local player, no rendering), the time is the game time [world+108h],
// and the per-unit and per-player tables are only a cache: a loaded game rebuilds them from the units' tactics
// and the grid.
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <map>
#include <set>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../worldtick.h"

extern "C" void UhcAutoScoutCmdHook();

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;
constexpr int kBlock = 8;                  // cells per block side
constexpr std::uint32_t kScanMs = 500;     // game time between scans
constexpr std::uint32_t kTargetMs = 90000; // a target taking longer than this is given up
constexpr int kMaxLogLines = 400;
constexpr int kMaxTries = 3;

struct Vec3 {
  float x, y, z;
};

using DoMoveFn = bool(__thiscall*)(char* mgr, const Vec3* point, float tolerance, char a3, char a4, std::int32_t a5,
                                   char a6, char a7, std::int32_t a8, std::int32_t a9, float a10);
using SetTacticFn = char(__thiscall*)(char* mgr, std::int32_t player, std::int32_t index, std::int32_t a3,
                                      std::int32_t a4, float a5, std::int32_t a6, std::int32_t a7);
using IdleFn = bool(__thiscall*)(const char* mgr);
using AliveFn = bool(__thiscall*)(const char* unit);
using WaterFn = std::uint8_t(__thiscall*)(const char* terrain, std::int32_t x, std::int32_t z);

const auto kDoMove = reinterpret_cast<DoMoveFn>(0x0050E36A);
const auto kSetTactic = reinterpret_cast<SetTacticFn>(0x004F7ECD);
const auto kIdle = reinterpret_cast<IdleFn>(0x0044F1A7);

std::wstring g_scoutName = L"AutoScout";
std::wstring g_returnName;
bool g_log = false;
bool g_switchOff = false;
int g_logLines = 0;

template <typename T>
T Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(static_cast<const char*>(base) + offset);
}

void Note(const wchar_t* format, ...);

const char* World() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

const char* Database() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

char* UnitById(const char* world, std::int32_t id) {
  if (id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  char* unit = Field<char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

std::int32_t OwnerId(const char* unit) {
  const char* player = Field<const char*>(unit, 0x44);
  return player == nullptr ? -1 : Field<std::int32_t>(player, 0);
}

std::int32_t ProtoId(const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  return proto == nullptr ? -1 : Field<std::int32_t>(proto, 8);
}

bool Alive(const char* unit) {
  const auto alive = reinterpret_cast<AliveFn>(Field<const void* const*>(unit, 0)[0xA4 / 4]);
  return alive(unit);
}

// ---- tactic names ----------------------------------------------------------------------------------------------

// The database's tactic names, [db+1FF0h] (count +1FF4h): the IDs a tactic's +8 holds (0x5E0CA6 looks one up).
std::int32_t g_scoutId = -1;
std::int32_t g_returnId = -1;
const char* g_namesDb = nullptr;
std::int32_t g_namesCount = -1;

std::int32_t FindName(const char* db, const std::wstring& name) {
  const char* names = Field<const char*>(db, 0x1FF0);
  const std::int32_t count = Field<std::int32_t>(db, 0x1FF4);
  for (std::int32_t i = 0; names != nullptr && i < count; ++i) {
    const wchar_t* text = Field<const wchar_t*>(names, 4 * i);
    if (text != nullptr && _wcsicmp(text, name.c_str()) == 0) {
      return i;
    }
  }
  return -1;
}

void ResolveNames() {
  const char* db = Database();
  if (db == nullptr) {
    return;
  }
  const std::int32_t count = Field<std::int32_t>(db, 0x1FF4);
  if (db == g_namesDb && count == g_namesCount) {
    return;
  }
  g_namesDb = db;
  g_namesCount = count;
  g_scoutId = FindName(db, g_scoutName);
  g_returnId = g_returnName.empty() ? -1 : FindName(db, g_returnName);
  Note(L"autoScout: %d tactic names; '%ls' is name %d%ls", count, g_scoutName.c_str(), g_scoutId,
       g_returnName.empty() ? L"" : (std::wstring(L", '") + g_returnName + L"' is name " +
                                     std::to_wstring(g_returnId)).c_str());
}

// The unit's tactics: the action set [proto+44h], its tactics +10h (count +14h); the current index [mgr+A8h].
std::int32_t TacticNameAt(const char* set, std::int32_t index) {
  if (set == nullptr || index < 0 || index >= Field<std::int32_t>(set, 0x14)) {
    return -1;
  }
  const char* tactic = Field<const char* const*>(set, 0x10)[index];
  return tactic == nullptr ? -1 : Field<std::int32_t>(tactic, 8);
}

bool Scouting(const char* unit) {
  if (g_scoutId < 0) {
    return false;
  }
  const char* mgr = Field<const char*>(unit, 0x58);
  const char* proto = Field<const char*>(unit, 0x5C);
  if (mgr == nullptr || proto == nullptr) {
    return false;
  }
  return TacticNameAt(Field<const char*>(proto, 0x44), Field<std::int32_t>(mgr, 0xA8)) == g_scoutId;
}

// The tactic a scout goes back to: ReturnTactic when the unit has it, else the first one that is not the scouting one.
std::int32_t ReturnIndex(const char* unit) {
  const char* set = Field<const char*>(Field<const char*>(unit, 0x5C), 0x44);
  if (set == nullptr) {
    return -1;
  }
  const std::int32_t count = Field<std::int32_t>(set, 0x14);
  if (g_returnId >= 0) {
    for (std::int32_t i = 0; i < count; ++i) {
      if (TacticNameAt(set, i) == g_returnId) {
        return i;
      }
    }
  }
  for (std::int32_t i = 0; i < count; ++i) {
    const std::int32_t name = TacticNameAt(set, i);
    if (name >= 0 && name != g_scoutId) {
      return i;
    }
  }
  return -1;
}

// ---- the grid --------------------------------------------------------------------------------------------------

enum Move { kLand = 0, kWater = 1, kAir = 2 };

struct Map {
  const char* world = nullptr;
  std::int32_t w = 0, h = 0;  // cells: x < w, z < h, index x * h + z
  float inv = 0.0f;           // cells per world unit, [terrain+1Ch]
  std::int32_t bw = 0, bh = 0;
  std::vector<std::uint8_t> water;              // per cell
  std::vector<std::int32_t> standCell[3];       // per block and movement: the cell nearest its centre one can stand on
};

Map g_map;

struct PlayerGrid {
  std::vector<std::int32_t> unexploredCell[3];  // per block and movement: an unexplored cell one can stand on, or -1
  std::vector<std::uint8_t> visible;            // per block: a cell of it is visible now
  std::vector<std::uint32_t> lastSeen;          // per block: the game time it was last visible
  std::int32_t unexplored = 0;                  // cells
};

std::map<std::int32_t, PlayerGrid> g_grids;

struct Scout {
  std::int32_t cell = -1;    // target cell
  std::int32_t block = -1;
  bool revisit = false;      // the target is a seen block, not an unexplored one
  std::uint32_t orderTime = 0;
  std::int32_t actionId = 0;
  bool interrupted = false;      // another action took over since the order
  bool moved = false;            // a heading is known
  float lastX = 0.0f, lastZ = 0.0f, headX = 0.0f, headZ = 0.0f;
  std::set<std::int32_t> given;  // blocks this unit could not reach
};

std::map<std::int32_t, Scout> g_scouts;
std::uint32_t g_lastScan = 0;
std::uint32_t g_lastTime = 0;
const char* g_lastWorld = nullptr;

std::int32_t BlockOf(std::int32_t cell) {
  const std::int32_t x = cell / g_map.h;
  const std::int32_t z = cell % g_map.h;
  return (x / kBlock) * g_map.bh + z / kBlock;
}

bool CanStand(std::int32_t cell, int move) {
  if (move == kAir) {
    return true;
  }
  return (g_map.water[cell] != 0) == (move == kWater);
}

bool BuildMap(const char* world) {
  const char* vm = Field<const char*>(world, 0x250);
  const char* terrain = Field<const char*>(world, 0x88);
  if (vm == nullptr || terrain == nullptr || Field<const void*>(vm, 0x20) == nullptr) {
    return false;
  }
  const std::int32_t w = Field<std::int32_t>(vm, 0x14);
  const std::int32_t h = Field<std::int32_t>(vm, 0x18);
  const float inv = Field<float>(terrain, 0x1C);
  if (w <= 0 || h <= 0 || w > 4096 || h > 4096 || !(inv > 0.0f)) {
    return false;
  }
  if (g_map.world == world && g_map.w == w && g_map.h == h) {
    return true;
  }
  g_map = Map{};
  g_map.world = world;
  g_map.w = w;
  g_map.h = h;
  g_map.inv = inv;
  g_map.bw = (w + kBlock - 1) / kBlock;
  g_map.bh = (h + kBlock - 1) / kBlock;
  g_map.water.assign(static_cast<std::size_t>(w) * h, 0);
  const auto water = reinterpret_cast<WaterFn>(Field<const void* const*>(terrain, 0)[0x194 / 4]);
  std::int32_t wet = 0;
  for (std::int32_t x = 0; x < w; ++x) {
    for (std::int32_t z = 0; z < h; ++z) {
      if (water(terrain, x, z) != 0xFF) {
        g_map.water[x * h + z] = 1;
        ++wet;
      }
    }
  }
  const std::size_t blocks = static_cast<std::size_t>(g_map.bw) * g_map.bh;
  for (int move = 0; move < 3; ++move) {
    g_map.standCell[move].assign(blocks, -1);
    for (std::int32_t bx = 0; bx < g_map.bw; ++bx) {
      for (std::int32_t bz = 0; bz < g_map.bh; ++bz) {
        const float cx = bx * kBlock + kBlock / 2.0f;
        const float cz = bz * kBlock + kBlock / 2.0f;
        float best = 1e30f;
        for (std::int32_t x = bx * kBlock; x < std::min(w, (bx + 1) * kBlock); ++x) {
          for (std::int32_t z = bz * kBlock; z < std::min(h, (bz + 1) * kBlock); ++z) {
            const std::int32_t cell = x * h + z;
            const float d = (x + 0.5f - cx) * (x + 0.5f - cx) + (z + 0.5f - cz) * (z + 0.5f - cz);
            if (CanStand(cell, move) && d < best) {
              best = d;
              g_map.standCell[move][bx * g_map.bh + bz] = cell;
            }
          }
        }
      }
    }
  }
  g_grids.clear();
  Note(L"autoScout: map of %d x %d cells (%.2f per metre), %d water cells, %d x %d blocks", w, h,
       static_cast<double>(inv), wet, g_map.bw, g_map.bh);
  return true;
}

// The player's grid in blocks, from the visibility cells.
void Summarize(const char* world, std::int32_t player, std::uint32_t now) {
  PlayerGrid& grid = g_grids[player];
  const std::size_t blocks = static_cast<std::size_t>(g_map.bw) * g_map.bh;
  if (grid.lastSeen.size() != blocks) {
    grid.lastSeen.assign(blocks, 0);
  }
  grid.visible.assign(blocks, 0);
  for (auto& cells : grid.unexploredCell) {
    cells.assign(blocks, -1);
  }
  grid.unexplored = 0;
  const std::int32_t masks = Field<std::int32_t>(world, 0x2DC);
  if (player >= masks) {
    return;
  }
  const std::uint32_t mask = Field<const std::uint32_t*>(world, 0x2D8)[player];
  const std::uint32_t* cells = Field<const std::uint32_t*>(Field<const char*>(world, 0x250), 0x20);
  const std::int32_t w = g_map.w;
  const std::int32_t h = g_map.h;
  for (std::int32_t x = 0; x < w; ++x) {
    const std::int32_t bx = x / kBlock;
    for (std::int32_t z = 0; z < h; ++z) {
      const std::int32_t cell = x * h + z;
      const std::uint32_t bits = cells[cell] & mask;
      const std::int32_t block = bx * g_map.bh + z / kBlock;
      if ((bits & 0xFFFF0000u) != 0) {
        grid.visible[block] = 1;
      }
      if ((bits & 0xFFFFu) != 0) {
        continue;
      }
      ++grid.unexplored;
      for (int move = 0; move < 3; ++move) {
        if (grid.unexploredCell[move][block] < 0 && CanStand(cell, move)) {
          grid.unexploredCell[move][block] = cell;
        }
      }
    }
  }
  for (std::size_t b = 0; b < blocks; ++b) {
    if (grid.visible[b] != 0) {
      grid.lastSeen[b] = now;
    }
  }
}

bool Explored(const char* world, std::int32_t player, std::int32_t cell) {
  if (player >= Field<std::int32_t>(world, 0x2DC)) {
    return true;
  }
  const std::uint32_t mask = Field<const std::uint32_t*>(world, 0x2D8)[player];
  const std::uint32_t* cells = Field<const std::uint32_t*>(Field<const char*>(world, 0x250), 0x20);
  return (cells[cell] & mask & 0xFFFFu) != 0;
}

Vec3 CellPoint(std::int32_t cell, float y) {
  return Vec3{(cell / g_map.h + 0.5f) / g_map.inv, y, (cell % g_map.h + 0.5f) / g_map.inv};
}

int MoveOf(const char* unit) {
  switch (Field<std::uint8_t>(Field<const char*>(unit, 0x5C), 0x1D2)) {
    case 2:
      return kWater;
    case 4:
      return kAir;
    default:
      return kLand;
  }
}

const wchar_t* MoveName(int move) { return move == kAir ? L"air" : move == kWater ? L"water" : L"land"; }

// The target for a scout: the nearest unexplored cell it can stand on, in a block no other scout of the player
// holds and it has not given up; else the reachable block not visible now that was seen longest ago.
bool PickTarget(const char* world, std::int32_t player, const char* unit, Scout& scout,
                const std::set<std::int32_t>& taken, const PlayerGrid& grid) {
  const int move = MoveOf(unit);
  const float ux = Field<float>(unit, 0x14) * g_map.inv;
  const float uz = Field<float>(unit, 0x1C) * g_map.inv;
  const std::size_t blocks = grid.visible.size();
  // The squared distance in cells, up to 4.8 times more for a cell behind the unit's heading: a scout keeps going
  // the way it goes rather than zigzag between two frontiers.
  auto distance = [&](std::int32_t cell) {
    const float dx = cell / g_map.h + 0.5f - ux;
    const float dz = cell % g_map.h + 0.5f - uz;
    const float d2 = dx * dx + dz * dz;
    if (!scout.moved || d2 < 1e-6f) {
      return d2;
    }
    const float bias = 1.6f - 0.6f * (dx * scout.headX + dz * scout.headZ) / std::sqrt(d2);
    return d2 * bias * bias;
  };
  std::int32_t best = -1;
  float bestDistance = 0.0f;
  for (std::size_t b = 0; b < blocks; ++b) {
    const std::int32_t cell = grid.unexploredCell[move][b];
    if (cell < 0 || taken.count(static_cast<std::int32_t>(b)) != 0 || scout.given.count(static_cast<std::int32_t>(b)) != 0) {
      continue;
    }
    const float d = distance(cell);
    if (best < 0 || d < bestDistance) {
      best = cell;
      bestDistance = d;
    }
  }
  if (best >= 0) {
    // The nearest unexplored cell of that block it can stand on.
    const std::int32_t block = BlockOf(best);
    const std::int32_t bx = block / g_map.bh;
    const std::int32_t bz = block % g_map.bh;
    float nearest = distance(best);
    for (std::int32_t x = bx * kBlock; x < std::min(g_map.w, (bx + 1) * kBlock); ++x) {
      for (std::int32_t z = bz * kBlock; z < std::min(g_map.h, (bz + 1) * kBlock); ++z) {
        const std::int32_t cell = x * g_map.h + z;
        if (CanStand(cell, move) && !Explored(world, player, cell) && distance(cell) < nearest) {
          nearest = distance(cell);
          best = cell;
        }
      }
    }
    scout.cell = best;
    scout.block = block;
    scout.revisit = false;
    return true;
  }
  std::uint32_t oldest = 0;
  for (std::size_t b = 0; b < blocks; ++b) {
    const std::int32_t cell = g_map.standCell[move][b];
    if (cell < 0 || grid.visible[b] != 0 || taken.count(static_cast<std::int32_t>(b)) != 0 ||
        scout.given.count(static_cast<std::int32_t>(b)) != 0) {
      continue;
    }
    const float d = distance(cell);
    if (best < 0 || grid.lastSeen[b] < oldest || (grid.lastSeen[b] == oldest && d < bestDistance)) {
      best = cell;
      oldest = grid.lastSeen[b];
      bestDistance = d;
    }
  }
  if (best < 0) {
    if (!scout.given.empty()) {
      scout.given.clear();  // everything was given up: try them again on the next scan
    }
    return false;
  }
  scout.cell = best;
  scout.block = BlockOf(best);
  scout.revisit = true;
  return true;
}

// The action manager's anchor [mgr+7Ch] (x, y, z), where its leash 0x489B15 walks a unit back to when its current
// action has no order and it strays too far (0x489C34 -> 0x50E50E: a move with tolerance 1.0). A scout's anchor
// follows it, so a unit that stops scouting stays where it is instead of walking back to where it was last ordered.
void SetAnchor(char* unit) {
  char* mgr = Field<char*>(unit, 0x58);
  for (std::uint32_t i = 0; i < 3; ++i) {
    *reinterpret_cast<float*>(mgr + 0x7C + 4 * i) = Field<float>(unit, 0x14 + 4 * i);
  }
}

std::int32_t CurrentActionId(const char* mgr) {
  const char* action = Field<const char*>(mgr, 0x24);
  return action == nullptr ? 0 : Field<std::int32_t>(action, 8);
}

void Order(const char* world, char* unit, std::int32_t id, std::int32_t player, Scout& scout,
           std::set<std::int32_t>& taken, const PlayerGrid& grid, std::uint32_t now) {
  char* mgr = Field<char*>(unit, 0x58);
  for (int tries = 0; tries < kMaxTries; ++tries) {
    if (!PickTarget(world, player, unit, scout, taken, grid)) {
      scout.cell = -1;
      return;
    }
    const Vec3 point = CellPoint(scout.cell, Field<float>(unit, 0x18));
    // a4 = 1 sets the move action's flag 17h, which the action manager's leash 0x489B15 honours (0x4B95E4): without
    // it the unit is walked back to its anchor [mgr+7Ch] every few seconds.
    const bool ok = kDoMove(mgr, &point, 0.1f, 0, 1, -1, 0, 0, -1, -1, -1.0f);
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"autoScout: unit %d (proto %d, player %d, %ls) at (%.1f, %.1f) -> %ls cell (%.1f, %.1f), block %d: %ls",
               id, ProtoId(unit), player, MoveName(MoveOf(unit)), static_cast<double>(Field<float>(unit, 0x14)),
               static_cast<double>(Field<float>(unit, 0x1C)), scout.revisit ? L"seen" : L"unexplored",
               static_cast<double>(point.x), static_cast<double>(point.z), scout.block, ok ? L"ordered" : L"refused");
    }
    if (ok) {
      scout.orderTime = now;
      scout.actionId = CurrentActionId(mgr);
      scout.interrupted = false;
      taken.insert(scout.block);
      return;
    }
    scout.given.insert(scout.block);
    scout.cell = -1;
  }
}

void Forget() {
  g_scouts.clear();
  g_grids.clear();
  g_map = Map{};
  g_lastScan = 0;
}

void Scan(char* world, std::uint32_t now);

void Tick(char* world, std::int32_t) {
  if (world != World()) {
    return;
  }
  const std::uint32_t now = Field<std::uint32_t>(world, 0x108);
  if (world != g_lastWorld || now < g_lastTime) {
    Forget();
    g_lastWorld = world;
  }
  g_lastTime = now;
  if (now - g_lastScan < kScanMs && g_lastScan != 0) {
    return;
  }
  g_lastScan = now == 0 ? 1 : now;
  if (!g_log) {
    Scan(world, now);
    return;
  }
  // With log: the cost of the scans, every 120 of them (a real clock, for the log only: it feeds nothing back).
  static int scans = 0;
  static double total = 0.0, longest = 0.0;
  const auto start = std::chrono::steady_clock::now();
  Scan(world, now);
  const double us = std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now() - start).count();
  total += us;
  longest = std::max(longest, us);
  if (++scans == 120) {
    uhc::Log(L"autoScout: 120 scans, %.0f us on average, %.0f us the longest, %zu scout(s), %d x %d cells",
             total / scans, longest, g_scouts.size(), g_map.w, g_map.h);
    scans = 0;
    total = longest = 0.0;
  }
}

void Scan(char* world, std::uint32_t now) {
  ResolveNames();
  if (g_scoutId < 0 || !BuildMap(world)) {
    return;
  }

  // The scouts, by player then by ID.
  std::map<std::int32_t, std::vector<std::int32_t>> scouts;
  const std::int32_t players = Field<std::int32_t>(world, 0x5C);
  for (std::int32_t p = 1; p < players; ++p) {
    const char* player = Field<const char* const*>(world, 0x58)[p];
    if (player == nullptr) {
      continue;
    }
    const std::int32_t* ids = Field<const std::int32_t*>(player, 0xF8);
    const std::int32_t count = Field<std::int32_t>(player, 0xFC);
    for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
      const char* unit = UnitById(world, ids[i]);
      if (unit != nullptr && OwnerId(unit) == p && Scouting(unit) && Alive(unit)) {
        scouts[p].push_back(ids[i]);
      }
    }
  }
  for (auto it = g_scouts.begin(); it != g_scouts.end();) {
    const char* unit = UnitById(world, it->first);
    const auto list = unit == nullptr ? scouts.end() : scouts.find(OwnerId(unit));
    if (list == scouts.end() || !std::binary_search(list->second.begin(), list->second.end(), it->first)) {
      it = g_scouts.erase(it);
    } else {
      ++it;
    }
  }
  for (auto& [player, ids] : scouts) {
    std::sort(ids.begin(), ids.end());
    Summarize(world, player, now);
    const PlayerGrid& grid = g_grids[player];
    std::set<std::int32_t> taken;
    for (const std::int32_t id : ids) {
      const auto found = g_scouts.find(id);
      if (found != g_scouts.end() && found->second.cell >= 0) {
        taken.insert(found->second.block);
      }
    }
    for (const std::int32_t id : ids) {
      char* unit = UnitById(world, id);
      if (Field<std::int32_t>(unit, 0x6C) != -1) {
        continue;  // inside another unit
      }
      Scout& scout = g_scouts[id];
      SetAnchor(unit);
      const float x = Field<float>(unit, 0x14);
      const float z = Field<float>(unit, 0x1C);
      const float step = std::hypot(x - scout.lastX, z - scout.lastZ);
      if (step > 1.0f) {
        if (scout.lastX != 0.0f || scout.lastZ != 0.0f) {
          scout.headX = (x - scout.lastX) / step;
          scout.headZ = (z - scout.lastZ) / step;
          scout.moved = true;
        }
        scout.lastX = x;
        scout.lastZ = z;
      }
      const char* mgr = Field<const char*>(unit, 0x58);
      const bool idle = kIdle(mgr);
      const bool ours = !idle && scout.actionId != 0 && CurrentActionId(mgr) == scout.actionId;
      if (!idle && !ours) {
        scout.interrupted = true;  // another action (a flee, a fight): leave it, scout again once it is idle
        continue;
      }
      bool order = scout.cell < 0;
      if (scout.cell >= 0) {
        const bool explored = !scout.revisit && Explored(world, player, scout.cell);
        const bool late = now - scout.orderTime > kTargetMs;
        if (explored || (scout.revisit && grid.visible[scout.block] != 0)) {
          order = true;
        } else if (idle && scout.interrupted) {
          order = true;  // it stopped for another reason: the same target is still good
        } else if (idle || late) {
          scout.given.insert(scout.block);  // it stopped short of its target: out of its reach
          if (g_log && g_logLines < kMaxLogLines) {
            ++g_logLines;
            const Vec3 point = CellPoint(scout.cell, 0.0f);
            uhc::Log(L"autoScout: unit %d stopped at (%.1f, %.1f), %.1f m from its target (%.1f, %.1f)%ls: block %d given up",
                     id, static_cast<double>(Field<float>(unit, 0x14)), static_cast<double>(Field<float>(unit, 0x1C)),
                     static_cast<double>(std::hypot(Field<float>(unit, 0x14) - point.x, Field<float>(unit, 0x1C) - point.z)),
                     static_cast<double>(point.x), static_cast<double>(point.z), late ? L" (too long)" : L"",
                     scout.block);
          }
          order = true;
        }
        if (order) {
          taken.erase(scout.block);
          scout.cell = -1;
        }
      }
      if (order) {
        Order(world, unit, id, player, scout, taken, grid, now);
      }
    }
  }
}

void Note(const wchar_t* format, ...) {
  if (!g_log || g_logLines >= kMaxLogLines) {
    return;
  }
  ++g_logLines;
  wchar_t text[512];
  va_list args;
  va_start(args, format);
  _vsnwprintf_s(text, _TRUNCATE, format, args);
  va_end(args);
  uhc::Log(L"%ls", text);
}

}  // namespace

// From the hook at the head of the command execute, on every machine, in the world update: a unit order from the
// owner puts a scout back in its return tactic before the order applies.
extern "C" void __stdcall UhcAutoScoutCommand(const char* command) {
  if (command == nullptr || g_scoutId < 0) {
    return;
  }
  const std::uint8_t type = Field<std::uint8_t>(command, 0x81);
  if (type != 0 && type != 9) {
    return;
  }
  const char* world = World();
  if (world == nullptr) {
    return;
  }
  const std::int32_t player = Field<std::int32_t>(command, 0x20);
  const std::int32_t* ids = Field<const std::int32_t*>(command, 0x40);
  const std::int32_t count = Field<std::int32_t>(command, 0x44);
  for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
    char* unit = UnitById(world, ids[i]);
    if (unit == nullptr || OwnerId(unit) != player || Field<std::int32_t>(unit, 0x6C) != -1 || !Scouting(unit)) {
      continue;
    }
    const std::int32_t index = ReturnIndex(unit);
    if (index < 0) {
      continue;
    }
    SetAnchor(unit);
    kSetTactic(Field<char*>(unit, 0x58), player, index, -1, 1, -1.0f, 1, 0);
    g_scouts.erase(ids[i]);
    if (g_log && g_logLines < kMaxLogLines) {
      ++g_logLines;
      uhc::Log(L"autoScout: unit %d (proto %d, player %d) got an order (command type %u): back to tactic %d", ids[i],
               ProtoId(unit), player, static_cast<unsigned>(type), index);
    }
  }
}

namespace uhc {

Outcome ApplyAutoScout(const Config& config) {
  const Config::Args* args = config.First("autoScout");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  int names = 0;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
      continue;
    }
    const bool valid = !arg.empty() && std::all_of(arg.begin(), arg.end(), [](char c) {
      return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_';
    });
    if (!valid || names == 2) {
      Log(L"autoScout: bad argument %hs (expected [ScoutTactic [ReturnTactic]] [log]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    (names == 0 ? g_scoutName : g_returnName) = std::wstring(arg.begin(), arg.end());
    ++names;
  }
  if (!VerifyAll("autoScout", {&sites::kAutoScoutDoMove, &sites::kAutoScoutSetTactic, &sites::kAutoScoutTacticIndex,
                               &sites::kAutoScoutIdle, &sites::kUnitById})) {
    return Outcome::kFailed;
  }
  if (Matches(sites::kAutoScoutCmdExecute)) {
    if (!WriteJmp(sites::kAutoScoutCmdExecute.va, reinterpret_cast<const void*>(&UhcAutoScoutCmdHook), 8)) {
      return Outcome::kFailed;
    }
    g_switchOff = true;
  }
  if (!AddWorldTick(&Tick)) {
    return Outcome::kFailed;
  }
  Log(L"autoScout: units in tactic '%ls' explore the map on their own%ls (multiplayer unverified)", g_scoutName.c_str(),
      g_returnName.empty() ? L"" : (std::wstring(L"; they go back to '") + g_returnName + L"'").c_str());
  if (!g_switchOff) {
    Log(L"autoScout: limited mode: the command execute head 0x7C8E49 is not stock (another DLL patched it), so an order "
        L"does not switch scouting off; use the Stop-scouting button");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
