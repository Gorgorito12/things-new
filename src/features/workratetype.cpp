// workRateByAbstractType: a WorkRate effect on a listed abstract type also reaches the rates a
// unit has for the protos of that type.
//
// Stock: an action's rates are a list of {unittype ID, rate} ([action+0Ch], count [action+10h],
// 0Ch bytes each). The lookup 0x487C45 takes the rate of the target's own proto if the list has it,
// else the first abstract type the target carries. A WorkRate effect (Data subtype 3, case 0x8F987C
// of applyData, 0x8FB11A of unapplyData) changes the one entry it names. So a Settler, which has
// rates for both AbstractMine and Plantation, gets no mining bonus on a Plantation, although the
// Plantation carries AbstractMine.
//
// With the key, when such an effect names a listed type, the same change is made to every entry of
// that action whose key is a proto of the type: same relativity, same amount, the base value from
// the base proto, through the stock value function and setter. A unit with no entry for a proto is
// left alone: it already reads the abstract rate. The stock code then runs unchanged.
//
// A tech with one effect on AbstractMine and one on Plantation therefore counts twice on the
// Plantation while the Plantation carries the type. The hooks are in hooks/workratetype_hooks.asm.
#include <cstdint>
#include <string>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

extern "C" {
void UhcWorkRateApplyHook();
void UhcWorkRateUnapplyHook();
}

namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database
constexpr std::size_t kMaxTypes = 8;
constexpr int kMaxLogLines = 2000;

using ActionByIdFn = const char*(__thiscall*)(const char* actions, std::int32_t id);
using RateGetFn = float(__thiscall*)(const char* action, std::int32_t key);
using RateSetFn = void(__thiscall*)(const char* action, std::int32_t key, float rate);
using EffectValueFn = void(__cdecl*)(std::uint32_t relativity, float* target, float base, float amount,
                                     std::uint32_t unapply);
using ProtoByIdFn = const char*(__thiscall*)(const char* database, std::int32_t id);
using ProtoIsTypeFn = bool(__thiscall*)(const char* proto, std::int32_t typeId);

const auto kActionById = reinterpret_cast<ActionByIdFn>(0x0048D22E);
const auto kRateGet = reinterpret_cast<RateGetFn>(0x0049EBB3);
const auto kRateSet = reinterpret_cast<RateSetFn>(0x005FA2FC);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
const auto kProtoById = reinterpret_cast<ProtoByIdFn>(0x0045316E);
const auto kProtoIsType = reinterpret_cast<ProtoIsTypeFn>(0x0044D7FA);

struct TypeRule {
  std::string name;
  std::int32_t id = -1;              // filled on each database load
  std::vector<std::int32_t> protos;  // the protos of the type, in ID order
  bool built = false;
};

TypeRule g_rules[kMaxTypes];
std::size_t g_ruleCount = 0;
bool g_log = false;
std::string g_logProto;  // "log=<Proto>": only this unit's rates; a line per rate is slow with many units
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

const char* Database() {
  const char* game = *reinterpret_cast<char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x140);
}

void NewDatabase(char*) {
  for (std::size_t i = 0; i < g_ruleCount; ++i) {
    g_rules[i].protos.clear();
    g_rules[i].built = false;
  }
  g_logLines = 0;
}

// Built at the first effect after a load: the protos' types are not read yet when the database load
// callback runs.
void Build(TypeRule& rule) {
  const char* database = Database();
  if (database == nullptr) {
    return;
  }
  rule.built = true;
  const std::int32_t count = Field<std::int32_t>(database, 0x19B0);
  if (rule.id < count) {
    uhc::Log(L"workRateByAbstractType: %hs is a proto, not an abstract type: ignored", rule.name.c_str());
    return;
  }
  for (std::int32_t id = 0; id < count; ++id) {
    const char* proto = kProtoById(database, id);
    if (proto != nullptr && kProtoIsType(proto, rule.id)) {
      rule.protos.push_back(id);
    }
  }
  uhc::Log(L"workRateByAbstractType: %hs has %u protos", rule.name.c_str(),
           static_cast<unsigned>(rule.protos.size()));
}

}  // namespace

// From the WorkRate case of applyData and unapplyData, before the stock change. `relativity` is a
// byte in a pushed dword (0x7F86E4). The stock case does nothing without both action sets or the
// target's action, and this does the same.
extern "C" void __stdcall UhcWorkRateByType(const char* proto, const char* baseProto, std::int32_t actionId,
                                            std::int32_t key, float amount, std::uint32_t relativity,
                                            std::uint32_t unapply) {
  TypeRule* rule = nullptr;
  for (std::size_t i = 0; i < g_ruleCount; ++i) {
    if (g_rules[i].id == key) {
      rule = &g_rules[i];
      break;
    }
  }
  if (rule == nullptr) {
    return;
  }
  const char* actions = Field<const char*>(proto, 0x44);
  const char* baseActions = Field<const char*>(baseProto, 0x44);
  if (actions == nullptr || baseActions == nullptr) {
    return;
  }
  const char* action = kActionById(actions, actionId);
  if (action == nullptr) {
    return;
  }
  if (!rule->built) {
    Build(*rule);
  }
  const char* baseAction = kActionById(baseActions, actionId);
  for (const std::int32_t target : rule->protos) {
    float rate = kRateGet(action, target);
    if (rate <= 0.0f) {
      continue;  // no entry of its own: this unit reads the abstract rate
    }
    const float before = rate;
    const float base = baseAction != nullptr ? kRateGet(baseAction, target) : 1.0f;
    kEffectValue(relativity & 0xFF, &rate, base, amount, unapply);
    kRateSet(action, target, rate);
    if (g_log && g_logLines < kMaxLogLines && (g_logProto.empty() || _stricmp(g_logProto.c_str(), ProtoName(proto)) == 0)) {
      ++g_logLines;
      uhc::Log(L"workRateByAbstractType: %hs, rate for %hs (through %hs): %.3f -> %.3f%ls", ProtoName(proto),
               ProtoName(kProtoById(Database(), target)), rule->name.c_str(), static_cast<double>(before),
               static_cast<double>(rate), unapply != 0 ? L" (effect removed)" : L"");
      if (g_logLines == kMaxLogLines) {
        uhc::Log(L"workRateByAbstractType: log limit reached");
      }
    }
  }
}

namespace uhc {

Outcome ApplyWorkRateByAbstractType(const Config& config) {
  const Config::Args* args = config.First("workRateByAbstractType");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }

  std::vector<std::string> names;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (_strnicmp(arg.c_str(), "log=", 4) == 0) {
      if (arg.size() == 4) {
        Log(L"workRateByAbstractType: log= needs a proto; feature not applied");
        return Outcome::kFailed;
      }
      log = true;
      g_logProto = arg.substr(4);
    } else if (names.size() == kMaxTypes) {
      Log(L"workRateByAbstractType: more than %u types; feature not applied", static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      names.push_back(arg);
    }
  }
  if (names.empty()) {
    names.push_back("AbstractMine");
  }

  if (!VerifyAll("workRateByAbstractType",
                 {&sites::kWorkRateApplyCase, &sites::kWorkRateUnapplyCase, &sites::kActionById,
                  &sites::kActionRateGet, &sites::kActionRateSet, &sites::kEffectValueApply, &sites::kProtoById, &sites::kIsA})) {
    return Outcome::kFailed;
  }
  std::string list;
  for (const std::string& name : names) {
    TypeRule& rule = g_rules[g_ruleCount++];
    rule.name = name;
    if (!RequestAbstractUnitType(rule.name.c_str(), &rule.id)) {
      return Outcome::kFailed;
    }
    list += (list.empty() ? "" : " ") + name;
  }
  if (!OnDatabaseLoad(&NewDatabase)) {
    return Outcome::kFailed;
  }
  g_log = log;
  if (!WriteJmp(sites::kWorkRateApplyCase.va, reinterpret_cast<const void*>(&UhcWorkRateApplyHook), 5) ||
      !WriteJmp(sites::kWorkRateUnapplyCase.va, reinterpret_cast<const void*>(&UhcWorkRateUnapplyHook), 5)) {
    return Outcome::kFailed;
  }
  Log(L"workRateByAbstractType: WorkRate effects on %hs also change the rates units have for the protos of "
      L"those types%ls (multiplayer unverified)",
      list.c_str(), log ? L", each change logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
