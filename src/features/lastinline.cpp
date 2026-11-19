// fastLastInLine [log] [verify]: the "last in line" recompute of a player's tech tree through an index.
//
// FUN_004918A8 (thiscall(tree, Player*), ret 4; called by the tech status update 0x491A40 at 0x491A39 for each live
// player on every world update, and by the forced update 0x852850) runs when the tree's byte [tree+11h] is set. That
// byte is set when a HomeCity tech changes status (activation 0x94CF27, obtainable 0x94C33A, unobtainable 0x94CDB3,
// through 0x94AE8C): every home city shipment. The recompute, in its cold chunk 0x68FB0C, sets or clears status bit 16
// ("last in line") of every entry of the tree:
//   - a null entry is left alone;
//   - bit 22 (ForceLastInLine) set: bit 16 set;
//   - else, if some other entry j (the template record [[db+5D9Ch]+0Ch]+24h*j when j's entry is null) has in its
//     definition's prerequisites a "TechStatus active <this tech>" (0x94BC1D) and the player can obtain j (0x4C5725):
//     bit 16 cleared;
//   - else bit 16 cleared when bit 32 (YPNeverLastInLine) is set, set otherwise.
// Then, for the local player ([game+3C0h]), the UI object [game+920h] gets its vtable slot 1 with 0.
// Finding "some other entry j" is a scan of every entry and its prerequisites: entries x (entries + prerequisites)
// tests, 1.7e8 in a 10,552-tech tree, about 300 ms; the scan runs again after every shipment of any player.
//
// The key computes the same bits with an index built from the template records once per data load: for each tech ID
// t, the techs j whose definition has a TechStatus prerequisite of type 1, status 2 (active) and tech t. For entry i
// it tests only those j, in ascending order, with the stock 0x94BC1D and 0x4C5725, so the decision is the stock one;
// it only skips the j that cannot pass the first test. Both tests write no memory (docs/performance.md, §9), so
// testing fewer of them changes nothing else. The bits are the same, so players may set the key differently.
//
// The hook replaces the head of 0x4918A8 (hooks/lastinline_hooks.asm). When the index does not match the tree (a
// tree of another size, no database) it hands the call to the stock code.
// `verify` lets the stock loop run as well: the key computes its bits first without writing them, and a second hook
// at the loop's exit (0x68FC1B) compares them with what the stock loop wrote, entry by entry, and logs the times of
// both. `log` writes a line per recompute.
#include <windows.h>

#include <cstdint>
#include <cstdlib>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database, +3C0h local player ID, +920h a UI object
constexpr std::uint32_t kRecordStride = 0x24;      // template status records, [[db+5D9Ch]+0Ch]
constexpr int kMaxMismatchLines = 20;
constexpr std::uint32_t kLastInLineScanExit = 0x0068FC1B;  // mov eax,[0C66234h], inside sites::kLastInLineScan

// bool thiscall(entry, techId), ret 4: the entry's definition has a "TechStatus active techId" prerequisite.
using HasActivePrereqFn = bool(__thiscall*)(const void* entry, std::int32_t techId);
const auto kHasActivePrereq = reinterpret_cast<HasActivePrereqFn>(0x0094BC1D);
// bool thiscall(Player*, techId), ret 4: the player can obtain the tech.
using CanObtainFn = bool(__thiscall*)(void* player, std::int32_t techId);
const auto kCanObtain = reinterpret_cast<CanObtainFn>(0x004C5725);
// void thiscall(ui, 0): what the stock recompute tail-jumps to for the local player.
using UiRefreshFn = void(__thiscall*)(void* ui, std::int32_t);

template <typename T>
T& Field(const void* base, std::uint32_t offset) {
  return *reinterpret_cast<T*>(const_cast<char*>(static_cast<const char*>(base)) + offset);
}

char* Game() { return *reinterpret_cast<char**>(kGameGlobal); }

bool g_log = false;
bool g_verify = false;

// The index: g_first[t]..g_first[t+1] in g_dependents are the template indices j whose definition requires tech ID t
// active; slot `count` stands for the ID -1 (a prerequisite whose tech was not found, and what the stock loop uses
// for an entry without a definition). Built for one database, template array and count.
std::vector<std::uint32_t> g_first;
std::vector<std::int32_t> g_dependents;
bool g_built = false;
const char* g_builtDatabase = nullptr;
const char* g_builtRecords = nullptr;
std::int32_t g_builtCount = -1;

// Counters for the log.
std::uint64_t g_recomputes = 0;
std::uint64_t g_fallbacks = 0;
std::uint64_t g_tests = 0;
double g_ticksPerMs = 0.0;
std::int64_t g_ticks = 0;

// `verify`: the bits the key computed for the recompute in progress (0 = entry left alone, 1 = set, 2 = cleared).
std::vector<std::uint8_t> g_expected;
const void* g_pendingTree = nullptr;
std::int32_t g_pendingPlayer = -1;
LARGE_INTEGER g_stockStart{};
std::int64_t g_fastTicks = 0;
std::uint64_t g_checked = 0;
std::uint64_t g_checkedEntries = 0;
std::uint64_t g_mismatches = 0;
int g_mismatchLines = 0;

std::int64_t Now() {
  LARGE_INTEGER t{};
  QueryPerformanceCounter(&t);
  return t.QuadPart;
}

double Ms(std::int64_t ticks) { return g_ticksPerMs > 0.0 ? static_cast<double>(ticks) / g_ticksPerMs : 0.0; }

// A definition's prerequisites: array at def+1Ch, its length in the byte def+20h (0x94BC1D, 0x4C5DBD). A TechStatus
// prerequisite has type byte +5 = 1, status byte +0Ch (2 = active) and the tech ID at +8.
void Build(const char* database, const char* records, std::int32_t count) {
  g_first.assign(static_cast<std::size_t>(count) + 2, 0);
  g_dependents.clear();
  g_built = true;
  g_builtDatabase = database;
  g_builtRecords = records;
  g_builtCount = count;
  std::vector<std::vector<std::int32_t>> lists(static_cast<std::size_t>(count) + 1);
  std::size_t total = 0;
  std::size_t outOfRange = 0;
  for (std::int32_t j = 0; j < count; ++j) {
    const char* def = Field<const char*>(records, kRecordStride * static_cast<std::uint32_t>(j));
    if (def == nullptr) {
      continue;
    }
    const char* const* list = Field<const char* const*>(def, 0x1C);
    const std::uint8_t length = Field<std::uint8_t>(def, 0x20);
    for (std::uint8_t k = 0; list != nullptr && k < length; ++k) {
      const char* p = list[k];
      if (p == nullptr || Field<std::uint8_t>(p, 0x05) != 1 || Field<std::uint8_t>(p, 0x0C) != 2) {
        continue;
      }
      const std::int32_t target = Field<std::int32_t>(p, 0x08);
      if (target < -1 || target >= count) {
        ++outOfRange;  // matches no entry: their IDs are 0..count-1, or -1
        continue;
      }
      auto& l = lists[static_cast<std::size_t>(target == -1 ? count : target)];
      if (l.empty() || l.back() != j) {  // one entry per (target, j)
        l.push_back(j);
        ++total;
      }
    }
  }
  g_dependents.reserve(total);
  std::size_t named = 0;
  for (std::int32_t t = 0; t <= count; ++t) {
    g_first[static_cast<std::size_t>(t)] = static_cast<std::uint32_t>(g_dependents.size());
    const auto& l = lists[static_cast<std::size_t>(t)];
    named += l.empty() ? 0 : 1;
    g_dependents.insert(g_dependents.end(), l.begin(), l.end());
  }
  g_first[static_cast<std::size_t>(count) + 1] = static_cast<std::uint32_t>(g_dependents.size());
  uhc::Log(L"fastLastInLine: index of %d techs: %u named in a TechStatus active prerequisite, %u (tech, dependent) "
           L"pairs%ls",
           count, static_cast<unsigned>(named), static_cast<unsigned>(total),
           outOfRange != 0 ? L"; some prerequisites name a tech outside the tree and are ignored" : L"");
}

// From the database load hook: the next recompute builds the index of the new techtree.
void ResetForDataLoad(char*) { g_built = false; }

// The tech ID a status entry or template record stands for: [[x]+0], or -1 for a null definition (as the stock loop).
std::int32_t TechId(const void* entry) {
  const std::int32_t* def = Field<const std::int32_t*>(entry, 0x00);
  return def == nullptr ? -1 : *def;
}

// Computes bit 16 of every entry as the stock loop does. With `write`, writes it; otherwise stores it in g_expected.
// Returns false when the index does not fit this tree (the caller then runs the stock code).
bool Compute(const char* tree, void* player, bool write) {
  char* game = Game();
  const char* database = game == nullptr ? nullptr : Field<const char*>(game, 0x140);
  const char* templates = database == nullptr ? nullptr : Field<const char*>(database, 0x5D9C);
  const char* records = templates == nullptr ? nullptr : Field<const char*>(templates, 0x0C);
  const std::int32_t templateCount = templates == nullptr ? -1 : Field<std::int32_t>(templates, 0x10);
  const char* const* entries = Field<const char* const*>(tree, 0x04);
  const std::int32_t count = Field<std::int32_t>(tree, 0x08);
  if (records == nullptr || templateCount <= 0 || count != templateCount || entries == nullptr) {
    return false;
  }
  if (!g_built || database != g_builtDatabase || records != g_builtRecords || templateCount != g_builtCount) {
    Build(database, records, templateCount);
  }
  if (!write) {
    g_expected.assign(static_cast<std::size_t>(count), 0);
  }
  for (std::int32_t i = 0; i < count; ++i) {
    const char* e = entries[i];
    if (e == nullptr) {
      continue;
    }
    const std::uint32_t bitCount = Field<std::uint32_t>(e, 0x08);
    std::uint8_t* bits = Field<std::uint8_t*>(e, 0x04);
    bool set;
    if (bitCount > 0x16 && (bits[2] & 0x40) != 0) {  // ForceLastInLine
      set = true;
    } else {
      bool found = false;
      const std::int32_t id = TechId(e);
      if (id >= -1 && id < count) {
        const std::size_t slot = static_cast<std::size_t>(id == -1 ? count : id);
        const std::uint32_t end = g_first[slot + 1];
        for (std::uint32_t k = g_first[slot]; k < end && !found; ++k) {
          const std::int32_t j = g_dependents[k];
          if (j == i) {
            continue;
          }
          const char* pj = entries[j];
          if (pj == nullptr) {
            pj = records + kRecordStride * static_cast<std::uint32_t>(j);
          }
          ++g_tests;
          found = kHasActivePrereq(pj, id) && kCanObtain(player, TechId(pj));
        }
      }
      set = !found && !(bitCount > 0x20 && (bits[4] & 0x01) != 0);  // YPNeverLastInLine keeps it clear
    }
    if (write) {
      bits[2] = static_cast<std::uint8_t>(set ? (bits[2] | 0x01) : (bits[2] & 0xFE));
    } else {
      g_expected[static_cast<std::size_t>(i)] = set ? 1 : 2;
    }
  }
  return true;
}

void AtExit() {
  if (g_verify) {
    uhc::Log(L"fastLastInLine verify: %llu recomputes checked against the stock loop (%llu entries), %llu bits "
             L"differ",
             g_checked, g_checkedEntries, g_mismatches);
  } else {
    uhc::Log(L"fastLastInLine: %llu recomputes (%llu dependency tests, %.1f ms in all), %llu handed to the stock code",
             g_recomputes, g_tests, Ms(g_ticks), g_fallbacks);
  }
}

}  // namespace

extern "C" {

void UhcLastInLineHook();
void UhcLastInLineVerifyEndHook();

// From the head of 0x4918A8 (the player is not null, [tree+11h] is set). Returns 0 when it did the recompute (the
// hook returns), 1 when the stock code must run (the hook re-executes the head and enters it).
std::uint32_t __stdcall UhcLastInLine(char* tree, char* player) {
  const std::int64_t start = Now();
  if (g_verify) {
    g_pendingTree = nullptr;
    if (Compute(tree, player, false)) {
      g_pendingTree = tree;
      g_pendingPlayer = Field<std::int32_t>(player, 0x00);
      g_fastTicks = Now() - start;
      QueryPerformanceCounter(&g_stockStart);
    } else {
      ++g_fallbacks;
    }
    return 1;
  }
  if (!Compute(tree, player, true)) {
    ++g_fallbacks;
    return 1;
  }
  Field<std::uint8_t>(tree, 0x11) = 0;
  const std::int64_t ticks = Now() - start;
  g_ticks += ticks;
  ++g_recomputes;
  if (g_log) {
    uhc::Log(L"fastLastInLine: player %d, %d entries, %.2f ms", Field<std::int32_t>(player, 0x00),
             Field<std::int32_t>(tree, 0x08), Ms(ticks));
  }
  char* game = Game();
  void* ui = game == nullptr ? nullptr : Field<void*>(game, 0x920);
  if (ui != nullptr && Field<std::int32_t>(player, 0x00) == Field<std::int32_t>(game, 0x3C0)) {
    UiRefreshFn refresh = (*reinterpret_cast<UiRefreshFn**>(ui))[1];
    refresh(ui, 0);
  }
  return 0;
}

// `verify`, at the stock loop's exit 0x68FC1B (EBP = the tree): compares its bits with the key's.
void __stdcall UhcLastInLineCompare(const char* tree) {
  const std::int64_t stockTicks = Now() - g_stockStart.QuadPart;
  if (tree == nullptr || tree != g_pendingTree) {
    return;
  }
  g_pendingTree = nullptr;
  const char* const* entries = Field<const char* const*>(tree, 0x04);
  const std::int32_t count = Field<std::int32_t>(tree, 0x08);
  std::uint64_t differ = 0;
  for (std::int32_t i = 0; i < count && static_cast<std::size_t>(i) < g_expected.size(); ++i) {
    const char* e = entries[i];
    const std::uint8_t want = g_expected[static_cast<std::size_t>(i)];
    if (e == nullptr || want == 0) {
      if ((e == nullptr) != (want == 0)) {
        ++differ;
      }
      continue;
    }
    const bool stockSet = (Field<const std::uint8_t*>(e, 0x04)[2] & 0x01) != 0;
    if (stockSet != (want == 1)) {
      ++differ;
      if (g_mismatchLines < kMaxMismatchLines) {
        ++g_mismatchLines;
        uhc::Log(L"fastLastInLine verify: MISMATCH, player %d, entry %d (tech %d): stock %ls bit 16, the key %ls it",
                 g_pendingPlayer, i, TechId(e), stockSet ? L"set" : L"cleared", want == 1 ? L"sets" : L"clears");
      }
    }
  }
  ++g_checked;
  g_checkedEntries += static_cast<std::uint64_t>(count);
  g_mismatches += differ;
  uhc::Log(L"fastLastInLine verify: player %d, %d entries: %llu bits differ; the key %.2f ms, the stock loop %.1f ms",
           g_pendingPlayer, count, differ, Ms(g_fastTicks), Ms(stockTicks));
}
}

namespace uhc {

Outcome ApplyFastLastInLine(const Config& config) {
  const auto* args = config.First("fastLastInLine");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      g_log = true;
    } else if (_stricmp(arg.c_str(), "verify") == 0) {
      g_verify = true;
    } else {
      Log(L"fastLastInLine: unknown argument '%hs' (expected: [log] [verify]); feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("fastLastInLine", {&sites::kLastInLineHead, &sites::kLastInLineScan,
                                       &sites::kProtoTechHasActivePrereq, &sites::kPrereqListGet,
                                       &sites::kPlayerCanObtainTechHead, &sites::kTechTemplateFallback})) {
    return Outcome::kFailed;
  }
  LARGE_INTEGER frequency{};
  if (QueryPerformanceFrequency(&frequency) && frequency.QuadPart > 0) {
    g_ticksPerMs = static_cast<double>(frequency.QuadPart) / 1000.0;
  }
  if (!OnDatabaseLoad(&ResetForDataLoad)) {
    return Outcome::kFailed;
  }
  if (g_verify &&
      !WriteJmp(kLastInLineScanExit, reinterpret_cast<const void*>(&UhcLastInLineVerifyEndHook), 5)) {
    return Outcome::kFailed;
  }
  if (!WriteJmp(sites::kLastInLineHead.va, reinterpret_cast<const void*>(&UhcLastInLineHook), 9)) {
    return Outcome::kFailed;
  }
  std::atexit(AtExit);
  if (g_verify) {
    Log(L"fastLastInLine: verify mode: the stock loop recomputes \"last in line\" and every recompute is compared with "
        L"the key's");
  } else {
    Log(L"fastLastInLine: \"last in line\" is recomputed through an index of the TechStatus prerequisites%ls (same "
        L"bits as stock)",
        g_log ? L", log" : L"");
  }
  return Outcome::kApplied;
}

}  // namespace uhc
