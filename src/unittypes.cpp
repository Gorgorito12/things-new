#include "unittypes.h"

#include <string>
#include <vector>

#include "generated/sites.h"
#include "log.h"
#include "patch.h"

namespace {

struct Request {
  std::string name;
  std::int32_t* id;
};

std::vector<Request> g_requests;
bool g_hooked = false;

}  // namespace

extern "C" {
void UhcAbstractUnitTypesHook();

// Called from the hook at the end of FUN_0051A5DC, after the stock abstract types are
// registered. The unittype table is at database+190h; its name count, [database+194h], is the
// next free ID (the stock code asserts IDs are dense). IDs below [database+19B0h] are protos.
// The per-proto unittype bitsets are sized later from [database+194h] - [database+19B0h]
// (0x5F769A), so they grow with every name added here.
void __stdcall UhcRegisterAbstractUnitTypes(char* database) {
  using NameBucket = int(__thiscall*)(void* table, const char* name);
  using FindName = bool(__thiscall*)(void* table, const char* name, int bucket, int* id);
  using AddName = void(__thiscall*)(void* table, const char* name, const int* id);
  const auto nameBucket = reinterpret_cast<NameBucket>(0x0058E685);
  const auto findName = reinterpret_cast<FindName>(0x0040295B);
  const auto addName = reinterpret_cast<AddName>(0x005E3549);

  void* table = database + 0x190;
  const auto count = reinterpret_cast<const std::int32_t*>(database + 0x194);
  const auto protoCount = *reinterpret_cast<const std::int32_t*>(database + 0x19B0);
  for (const Request& request : g_requests) {
    const char* name = request.name.c_str();
    int id = -1;
    const bool existed = findName(table, name, nameBucket(table, name), &id);
    if (!existed) {
      id = *count;
      addName(table, name, &id);
    }
    *request.id = id;
    uhc::Log(L"unit types: %hs -> %d (bit %d of %d)%ls", name, id, id - protoCount, *count - protoCount,
             existed ? L", already defined" : L", added");
  }
}
}

namespace uhc {

bool RequestAbstractUnitType(const char* name, std::int32_t* id) {
  *id = -1;
  if (!g_hooked) {
    if (!VerifyAll("abstract unit types", {&sites::kAbstractTypesEnd})) {
      return false;
    }
    // Replaces pop edi / pop esi / mov al,1 / pop ebx at 0x51BA31; the hook re-executes them.
    if (!WriteJmp(0x0051BA31, reinterpret_cast<const void*>(&UhcAbstractUnitTypesHook), 5)) {
      return false;
    }
    g_hooked = true;
  }
  g_requests.push_back({name, id});
  return true;
}

}  // namespace uhc
