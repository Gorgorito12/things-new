// customProtoUnitCommands [file]: adds command type names to the game, so protounitcommands.xml
// entries and the protos' <Command> buttons can use names beyond the compiled-in list.
//
// The database registers its command type names 0..128 (MarketBuy1 .. RansomExplorerAsian) in a
// name table ([db+2648h], count [db+264Ch]) inside FUN_0052277E, one call of 0x537683(db, id,
// name) each; that function accepts only the next ID (id == count). Readers look names up in
// that table (0x5274AB: protounitcommands.xml, the protos' <Command> tags, the command panel).
// The protounitcommands.xml loader keeps one record per type ID in [db+2968h], sized with a
// constant 82h (130) at 0x52711D, and writes record[id] without a bound check; the readers stop
// at that array's count. The key therefore:
// - redirects the last registration call (0x5269FB) to a wrapper that makes it, then registers
//   each listed name with the next ID;
// - raises the record count at 0x52711D by the number of listed names, so their records exist.
//
// File format (default data\uhc\customprotounitcommands.xml, relative to the exe's folder):
//   <ProtoUnitCommandTypes>
//     <CommandType>MyTactic</CommandType>
//   </ProtoUnitCommandTypes>
#include <windows.h>

#include <cctype>
#include <cstdint>
#include <deque>
#include <set>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../xmllist.h"

namespace {

using RegisterName = bool(__thiscall*)(void* db, std::int32_t id, const char* name);
using LookupName = std::int32_t(__thiscall*)(void* db, const char* name);
const auto kRegisterName = reinterpret_cast<RegisterName>(0x00537683);
const auto kLookupName = reinterpret_cast<LookupName>(0x005274AB);

std::deque<std::string> g_names;  // kept alive for the game's lifetime
bool g_logged = false;

// The call site is thiscall (ECX = database, two stack arguments, callee pops them); __fastcall
// with an unused EDX has the same frame.
bool __fastcall RegisterLastCommandType(char* db, void* /*edx*/, std::int32_t id, const char* name) {
  const bool ok = kRegisterName(db, id, name);
  int added = 0;
  int present = 0;
  int refused = 0;
  std::int32_t first = -1;
  std::int32_t last = -1;
  for (const std::string& entry : g_names) {
    if (kLookupName(db, entry.c_str()) >= 0) {
      ++present;
      continue;
    }
    const std::int32_t next = *reinterpret_cast<const std::int32_t*>(db + 0x264C);
    if (!kRegisterName(db, next, entry.c_str())) {
      ++refused;
      continue;
    }
    first = first < 0 ? next : first;
    last = next;
    ++added;
  }
  if (!g_logged) {
    g_logged = true;
    uhc::Log(L"hook reached: customProtoUnitCommands (0x5269FB)");
    uhc::Log(L"customProtoUnitCommands: %d command type(s) added (IDs %d..%d), %d already known, %d refused",
             added, first, last, present, refused);
  }
  return ok;
}

}  // namespace

namespace uhc {

Outcome ApplyCustomProtoUnitCommands(const Config& config) {
  const Config::Args* args = config.First("customProtoUnitCommands");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  std::wstring path;
  std::string text;
  if (!ReadDataListFile(args->empty() ? std::string() : args->front(), L"data\\uhc\\customprotounitcommands.xml",
                        &path, &text)) {
    Log(L"customProtoUnitCommands: cannot read %ls (error %lu)", path.c_str(), GetLastError());
    return Outcome::kFailed;
  }
  int bad = 0;
  const std::deque<XmlListEntry> entries = ParseXmlList(text, "commandtype", &bad);
  if (entries.empty()) {
    Log(L"customProtoUnitCommands: no <CommandType> name in %ls", path.c_str());
    return Outcome::kFailed;
  }
  if (!VerifyAll("customProtoUnitCommands", {&sites::kCmdTypeRegLast, &sites::kCmdTypeRegister, &sites::kCmdTypeLookup,
                                             &sites::kCmdRecordReserve})) {
    return Outcome::kFailed;
  }
  std::set<std::string> seen;
  for (const XmlListEntry& entry : entries) {
    std::string key = entry.name;
    for (char& c : key) {
      c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    if (!seen.insert(key).second) {
      Log(L"customProtoUnitCommands: %hs is listed twice; the second is ignored", entry.name.c_str());
      continue;
    }
    g_names.push_back(entry.name);
  }
  if (bad > 0) {
    Log(L"customProtoUnitCommands: %d entr%ls with an empty or invalid name (letters, digits, _) ignored", bad,
        bad == 1 ? L"y" : L"ies");
  }
  const std::uint32_t records = 0x82 + static_cast<std::uint32_t>(g_names.size());
  if (!WriteDword(sites::kCmdRecordReserve.va + 1, records) ||
      !WriteCall(sites::kCmdTypeRegLast.va, reinterpret_cast<const void*>(&RegisterLastCommandType))) {
    return Outcome::kFailed;
  }
  Log(L"customProtoUnitCommands: %zu command type(s) from %ls; %lu command records", g_names.size(), path.c_str(),
      static_cast<unsigned long>(records));
  return Outcome::kApplied;
}

}  // namespace uhc
