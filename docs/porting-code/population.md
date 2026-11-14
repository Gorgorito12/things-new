# Code for WoL: Population

Generated from `src/` by `tools/porting_code.py`. Don't edit this page: change `src/` and run the
script. The code is under the [MIT license](../../LICENSE): keep the notice when you copy it.

Read the [porting guide](../porting-to-another-dll.md) first: it says what each hook expects and what it must preserve.
Every feature also needs the core [helpers](helpers.md): the site table, patching and the log.

## decimalPopulation

Contract: [decimalPopulation](../porting-to-another-dll.md#decimalpopulation).

Sites: `BStringFormat` `0x444EFB` (20 B), `RefFuturePopProvider` `0x44CE3A` (10 B), `RefTotalPopProvider` `0x45809D` (10 B), `PopLimit` `0x4581F3` (80 B), `RefPopCapProvider` `0x458244` (10 B), `RefPopReg` `0x5D0B47` (43 B), `RefPopCapReg` `0x5D0BC3` (43 B), `RefFuturePopReg` `0x5D0C3F` (43 B), `RefTotalPopReg` `0x5D0CBB` (43 B), `PopCountParse` `0x5FB92E` (30 B), `PopCapAddParse` `0x5FD719` (30 B), `PopFormatHelp` `0x63F98D` (8 B), `PopFormatCost` `0x63FEC5` (8 B), `TeamPopCap` `0x679694` (38 B), `RefPopProvider` `0x6F2274` (10 B), `PopFormatCapLine` `0x6F2DB5` (8 B), `PopFormatCap` `0x6F2E34` (8 B), `ColorizePopArg` `0x6F576F` (8 B), `ColorizePopFormat` `0x6F580C` (12 B), `PopFormatCost2` `0x70F58F` (8 B), `PopFormatHelp2` `0x70FF3A` (8 B), `PopFormatCost3` `0x710651` (8 B), `XsAiGetAvailableEconomyPop` `0x72A333` (10 B), `XsAiGetCurrentEconomyPop` `0x72A382` (10 B), `XsAiGetEconomyPop` `0x72A3D1` (10 B), `XsAiSetEconomyPop` `0x72A420` (10 B), `XsAiGetAvailableMilitaryPop` `0x72A49B` (10 B), `XsAiGetMilitaryPop` `0x72A4EA` (10 B), `XsAiSetMilitaryPop` `0x72A539` (10 B), `XsAiGetPopNeeds` `0x7319AA` (10 B), `DeckOutOfRange` `0x7EF005` (5 B), `DeckLimit` `0x7EF026` (13 B), `IntEffect` `0x7F899B` (35 B), `XsKbGetPop` `0x885EE5` (10 B), `XsKbGetPopCap` `0x885F34` (10 B), `XsKbGetPopCapAddition` `0x887BB1` (10 B), `XsKbGetPopSlots` `0x887C58` (10 B), `XsKbGetPopulationSlotsByUnitTypeID` `0x887CFF` (10 B), `XsKbGetPopulationSlotsByQueryID` `0x887DA6` (10 B), `XsKbUnitPickSetMinimumPop` `0x88F6C1` (10 B), `XsKbUnitPickGetMinimumPop` `0x88F768` (10 B), `XsKbUnitPickSetMaximumPop` `0x88F7E3` (10 B), `XsKbUnitPickGetMaximumPop` `0x88F88A` (10 B), `PopCapEffectRemove` `0x8D20AB` (8 B), `PopCapEffectAdd` `0x8D87AB` (8 B), `PopCountEffect` `0x8FA835` (29 B), `PopCapAddEffect` `0x8FA8CF` (26 B), `XsTrPlayerGetPopulation` `0x98C439` (10 B), `StartPopBonus` `0xA0D2D1` (9 B).

### src/features/decimalpop.cpp

```cpp
// decimalPopulation: population counts and caps with decimals, e.g. <PopulationCount>0.5.
//
// Stock keeps every population quantity as a whole number: <PopulationCount> ([proto+0D8h]) and
// <PopulationCapAddition> ([proto+0D4h]) are read with "%d" (0x59A71D), the player's population
// ([player+70h], getPop 0x45805C), its queue reservation ([player+78h]) and its cap ([player+74h],
// getCap 0x4581A1) are sums of them, and every test compares those sums, e.g. getPop + reserved +
// count * unitPop <= getCap in the Train add FUN_009EAC35 (44 calls of the two getters; all are
// such compares except the outputs below).
//
// The change is fixed point: every population quantity is stored K times larger (K = 10 by
// default), so every compare stays as it is, and only the places where a population enters or
// leaves the engine change:
// - in: the two tags accept decimals (value * K, rounded); the proto effects PopulationCount and
//   PopulationCapAddition (the int effect FUN_007F899B) get K times the amount when it is absolute
//   or assigned, a base-percent change is rounded to the nearest step (stock truncates it), a
//   percent one multiplies by a whole number as in stock; PopulationCount's "result <= 0 -> 1"
//   becomes K; the player effect PopulationCap gets K times its amount; getCap's limits (base 200, extra
//   0..50, the world's [world+31Ch], the bonus [player+4F4h], 250) get K, through the cap hook of
//   basePop/extraPop (features/limits.cpp), also on the shared-team path; the game-start bonus
//   [player+7Ch] + [world+320h] gets K; the XS setters aiSetEconomyPop, aiSetMilitaryPop,
//   kbUnitPickSet{Minimum,Maximum}Pop multiply their value by K;
// - out: the XS getters divide by K (rounded; kbGetPopSlots rounds up, so a unit that costs
//   population never reads as 0); the formatText data refs pop, popcap, futurepop, totalpop (the
//   top bar's "{totalPop} / {popcap}") become text refs that print the population with its
//   decimals; colorizePop reads a decimal argument and prints it; the unit help, the population
//   costs and the population counter's help print decimals.
// Not adapted: the AI's own debug text (0x7167EB) and the post-game statistics, which are not
// known to show a population. Saved games keep the scaled values: load them with the same K.
// The hooks of the effect PopulationCap, the shared-team cap and the start bonus are in
// hooks/decimalpop_hooks.asm.
#include <array>
#include <climits>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <intrin.h>
#include <string>
#include <utility>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
extern std::int32_t g_uhcPopScale;        // features/limits.cpp; read by the cap hook
extern std::int32_t g_uhcPopStockClamps;  // features/limits.cpp
void __stdcall UhcTraceHook(const char* hookName);
void UhcPopCapEffectAddHook();
void UhcPopCapEffectRemoveHook();
void UhcTeamPopCapHook();
void UhcStartPopBonusHook();
}

namespace uhc {
bool InstallPopLimitHook(const char* feature);  // features/limits.cpp
bool PopLimitHooked();
}  // namespace uhc

namespace {

using uhc::Log;

constexpr int kDefaultScale = 10;
constexpr int kMaxScale = 1000;
constexpr int kMaxLogLines = 200;
constexpr std::int32_t kIntValue = 2;        // data ref value type 2: an int at +4
constexpr std::int32_t kStringValue = 3;     // data ref value type 3: a BString at +4
constexpr std::uint8_t kRelPercent = 0;      // FUN_007F899B: *= (int)(amount + 0.5)
constexpr std::uint8_t kRelAbsolute = 1;     // += (int)amount (also any value but 0, 2, 3)
constexpr std::uint8_t kRelBasePercent = 2;  // += (int)(base * amount - base + 0.5)
constexpr std::uint8_t kRelAssign = 3;       // = (int)(amount + 0.5); any other: += (int)amount

// The engine's string: one pointer to a wide, reference-counted buffer; null is empty.
struct BString {
  wchar_t* text;
};
using BStringAssignFn = void(__thiscall*)(BString* self, const BString* source, std::int32_t, std::int32_t);
const auto kBStringAssign = reinterpret_cast<BStringAssignFn>(0x00443BB8);

// What a data ref provider fills: the evaluator sets type to the ref's registered type.
struct DataRefValue {
  std::int32_t type;
  BString text;  // type 3
};
struct IntRefValue {
  std::int32_t type;
  std::int32_t value;
};

using IntEffectFn = void(__cdecl*)(std::uint32_t rel, std::int32_t* out, std::int32_t base, float amount,
                                   std::uint32_t negate);
const auto kIntEffect = reinterpret_cast<IntEffectFn>(0x007F899B);
using FormatFn = void*(__cdecl*)(void* dest, const wchar_t* format, ...);
const auto kFormat = reinterpret_cast<FormatFn>(0x00444EFB);
using XsFn = std::int32_t(__cdecl*)(std::int32_t, std::int32_t);
using XsWrapperFn = std::int32_t(__cdecl*)();
using RefFn = bool(__stdcall*)(void* value);

bool g_log = false;
int g_logLines = 0;

bool LogLine() { return g_log && g_logLines < kMaxLogLines && ++g_logLines > 0; }

void TraceOnce(bool* traced, const char* name) {
  if (!*traced) {
    *traced = true;
    UhcTraceHook(name);
  }
}

// Whole population -> engine units, for values that come in from data or scripts.
std::int32_t ScaleRounded(double value) {
  return static_cast<std::int32_t>(std::lround(value * g_uhcPopScale));
}

// Engine units -> whole population, rounded half away from zero.
std::int32_t Unscale(std::int32_t value) {
  const std::int32_t k = g_uhcPopScale;
  return value >= 0 ? (value + k / 2) / k : -((-value + k / 2) / k);
}

// Engine units -> whole population, a positive value rounded up (never 0).
std::int32_t UnscaleUp(std::int32_t value) {
  const std::int32_t k = g_uhcPopScale;
  return value > 0 ? (value + k - 1) / k : Unscale(value);
}

// "12", "12.5", "0.333": the population with up to three decimals, trailing zeros dropped.
std::wstring PopText(std::int32_t value) {
  wchar_t text[32];
  const std::int32_t k = g_uhcPopScale;
  if (value % k == 0) {
    swprintf_s(text, L"%d", value / k);
    return text;
  }
  swprintf_s(text, L"%.3f", static_cast<double>(value) / k);
  std::wstring s = text;
  while (!s.empty() && s.back() == L'0') {
    s.pop_back();
  }
  if (!s.empty() && s.back() == L'.') {
    s.pop_back();
  }
  return s;
}

// A decimal number at the start of `text` (after spaces and, for colorizePop, parentheses).
bool CheckDecimal(double v, bool parsed, double* value) {
  if (!parsed || !(v > -1.0e6 && v < 1.0e6)) {
    return false;
  }
  *value = v;
  return true;
}

bool ParseDecimal(const wchar_t* text, double* value) {
  if (text == nullptr) {
    return false;
  }
  while (*text == L' ' || *text == L'\t' || *text == L'(') {
    ++text;
  }
  wchar_t* end = nullptr;
  const double v = std::wcstod(text, &end);
  return CheckDecimal(v, end != text, value);
}

bool ParseDecimal(const char* text, double* value) {
  if (text == nullptr) {
    return false;
  }
  while (*text == ' ' || *text == '\t') {
    ++text;
  }
  char* end = nullptr;
  const double v = std::strtod(text, &end);
  return CheckDecimal(v, end != text, value);
}

// ---- the two proto tags ----

// The out pointer is the handler's own argument slot (lea eax,[esp+0Ch] in FUN_005FB8FA and
// FUN_005FD6E5); the next slot holds the proto, which the handler stores into right after.
const char* ProtoOfParse(const std::int32_t* out) { return *reinterpret_cast<char* const*>(out + 1); }

// `text` is an ANSI copy of the tag's value (0x402733 converts the node's wide text with
// WideCharToMultiByte), which stock reads with sscanf "%d".
bool ParseTag(const char* text, std::int32_t* out, const wchar_t* tag) {
  double value = 0.0;
  if (!ParseDecimal(text, &value)) {
    return false;
  }
  *out = ScaleRounded(value);
  if (*out % g_uhcPopScale != 0 && LogLine()) {
    const char* proto = ProtoOfParse(out);
    const char* name = proto == nullptr ? nullptr : *reinterpret_cast<const char* const*>(proto + 0x10);
    Log(L"decimalPopulation: %hs <%ls>%hs</%ls> = %ls", name == nullptr ? "?" : name, tag, text, tag,
        PopText(*out).c_str());
  }
  return true;
}

// ---- the proto effects ----

void IntEffect(std::uint32_t rel, std::int32_t* out, std::int32_t base, float amount, std::uint32_t negate,
               const wchar_t* subtype) {
  const std::uint8_t relativity = static_cast<std::uint8_t>(rel);
  const std::int32_t before = out == nullptr ? 0 : *out;
  if (relativity == kRelBasePercent) {
    // Stock adds (int)(base * amount - base + 0.5), which truncates toward zero, so a decrease
    // would come out one step high (1.5 x 0.6 -> 1.0, not 0.9). Round it to the nearest step and
    // apply it as an absolute change (same sign handling: negate subtracts).
    const double delta = static_cast<double>(base) * amount - base;
    kIntEffect(kRelAbsolute, out, base, static_cast<float>(std::lround(delta)), negate);
  } else {
    float scaled = amount;
    if (relativity == kRelAssign) {
      scaled = amount * static_cast<float>(g_uhcPopScale);  // stock adds 0.5 and truncates
    } else if (relativity != kRelPercent) {
      // Absolute: stock truncates, so round at the new resolution first.
      scaled = std::round(amount * static_cast<float>(g_uhcPopScale));
    }
    kIntEffect(rel, out, base, scaled, negate);
  }
  if (out != nullptr && LogLine()) {
    Log(L"decimalPopulation: effect %ls, relativity %u, amount %g%ls: %ls -> %ls", subtype, relativity,
        static_cast<double>(amount), (negate & 0xFF) != 0 ? L" (removed)" : L"", PopText(before).c_str(),
        PopText(*out).c_str());
  }
}

// ---- XS ----

enum class XsKind { kGet, kGetUp, kGetKeepNegative, kSetFirst, kSetSecond };
struct XsSyscall {
  const uhc::Site* site;  // push impl / push name: the impl is replaced
  const char* name;
  XsKind kind;
};
const XsSyscall kXs[] = {
    {&uhc::sites::kXsAiGetAvailableEconomyPop, "aiGetAvailableEconomyPop", XsKind::kGet},
    {&uhc::sites::kXsAiGetAvailableMilitaryPop, "aiGetAvailableMilitaryPop", XsKind::kGet},
    {&uhc::sites::kXsAiGetCurrentEconomyPop, "aiGetCurrentEconomyPop", XsKind::kGet},
    {&uhc::sites::kXsAiGetEconomyPop, "aiGetEconomyPop", XsKind::kGet},
    {&uhc::sites::kXsAiGetMilitaryPop, "aiGetMilitaryPop", XsKind::kGet},
    {&uhc::sites::kXsAiGetPopNeeds, "aiGetPopNeeds", XsKind::kGet},
    {&uhc::sites::kXsAiSetEconomyPop, "aiSetEconomyPop", XsKind::kSetFirst},
    {&uhc::sites::kXsAiSetMilitaryPop, "aiSetMilitaryPop", XsKind::kSetFirst},
    {&uhc::sites::kXsKbGetPop, "kbGetPop", XsKind::kGet},
    {&uhc::sites::kXsKbGetPopCap, "kbGetPopCap", XsKind::kGet},
    {&uhc::sites::kXsKbGetPopCapAddition, "kbGetPopCapAddition", XsKind::kGet},
    {&uhc::sites::kXsKbGetPopSlots, "kbGetPopSlots", XsKind::kGetUp},
    {&uhc::sites::kXsKbGetPopulationSlotsByQueryID, "kbGetPopulationSlotsByQueryID", XsKind::kGet},
    {&uhc::sites::kXsKbGetPopulationSlotsByUnitTypeID, "kbGetPopulationSlotsByUnitTypeID", XsKind::kGet},
    {&uhc::sites::kXsKbUnitPickGetMaximumPop, "kbUnitPickGetMaximumPop", XsKind::kGetKeepNegative},
    {&uhc::sites::kXsKbUnitPickGetMinimumPop, "kbUnitPickGetMinimumPop", XsKind::kGetKeepNegative},
    {&uhc::sites::kXsKbUnitPickSetMaximumPop, "kbUnitPickSetMaximumPop", XsKind::kSetSecond},
    {&uhc::sites::kXsKbUnitPickSetMinimumPop, "kbUnitPickSetMinimumPop", XsKind::kSetSecond},
    {&uhc::sites::kXsTrPlayerGetPopulation, "trPlayerGetPopulation", XsKind::kGet},
};
constexpr std::size_t kXsCount = sizeof(kXs) / sizeof(kXs[0]);
bool g_xsTraced[kXsCount] = {};
std::int32_t g_xsLastSet[kXsCount] = {};

XsFn StockImpl(const XsSyscall& xs) {
  std::uint32_t impl = 0;
  std::memcpy(&impl, xs.site->bytes + 1, sizeof(impl));
  return reinterpret_cast<XsFn>(static_cast<std::uintptr_t>(impl));
}

// A value from a script: negative ones (-1, "no limit") stay as they are.
std::int32_t ScaleIn(std::int32_t value) { return value < 0 ? value : value * g_uhcPopScale; }

// The arguments the caller pushed, read in place. The variable-arity wrappers below declare no
// parameters: the caller may have pushed fewer than they read, and a declared parameter's slot can
// be reused by the compiler as scratch space, which would overwrite the caller's frame.
#define UHC_CALLER_ARGS() (reinterpret_cast<const std::uint32_t*>(_AddressOfReturnAddress()) + 1)

// The syscalls are cdecl and take at most two ints; reading two is harmless for the others, and
// the stock impl gets them back unchanged. The setters' result (void or bool) is passed through.
template <std::size_t I>
std::int32_t __cdecl XsWrapper() {
  const std::uint32_t* in = UHC_CALLER_ARGS();
  const std::int32_t a = static_cast<std::int32_t>(in[0]);
  const std::int32_t b = static_cast<std::int32_t>(in[1]);
  const XsSyscall& xs = kXs[I];
  if (!g_xsTraced[I]) {
    g_xsTraced[I] = true;
    std::string text = std::string("decimalPopulation XS ") + xs.name;
    UhcTraceHook(text.c_str());
  }
  const XsFn stock = StockImpl(xs);
  switch (xs.kind) {
    case XsKind::kSetFirst:
    case XsKind::kSetSecond: {
      const std::int32_t value = xs.kind == XsKind::kSetFirst ? a : b;
      const std::int32_t scaled = ScaleIn(value);
      // The AI sets the same values on every update: log a change only.
      if (g_xsLastSet[I] != value && LogLine()) {
        Log(L"decimalPopulation: %hs(%d) stored as %d", xs.name, value, scaled);
      }
      g_xsLastSet[I] = value;
      return xs.kind == XsKind::kSetFirst ? stock(scaled, b) : stock(a, scaled);
    }
    case XsKind::kGetUp:
      return UnscaleUp(stock(a, b));
    case XsKind::kGetKeepNegative: {
      const std::int32_t value = stock(a, b);
      return value < 0 ? value : Unscale(value);
    }
    case XsKind::kGet:
    default:
      return Unscale(stock(a, b));
  }
}

template <std::size_t... I>
constexpr std::array<XsWrapperFn, sizeof...(I)> MakeXsWrappers(std::index_sequence<I...>) {
  return {&XsWrapper<I>...};
}
constexpr auto kXsWrappers = MakeXsWrappers(std::make_index_sequence<kXsCount>{});

// ---- formatText data refs ----

struct PopRef {
  const uhc::Site* reg;       // mov [esp+2Ch],provider ... mov eax,[esp+1Ch] (the type) at +20h
  const uhc::Site* provider;  // the stock int provider
  const char* name;
};
const PopRef kRefs[] = {
    {&uhc::sites::kRefPopReg, &uhc::sites::kRefPopProvider, "pop"},
    {&uhc::sites::kRefPopCapReg, &uhc::sites::kRefPopCapProvider, "popcap"},
    {&uhc::sites::kRefFuturePopReg, &uhc::sites::kRefFuturePopProvider, "futurepop"},
    {&uhc::sites::kRefTotalPopReg, &uhc::sites::kRefTotalPopProvider, "totalpop"},
};
constexpr std::size_t kRefCount = sizeof(kRefs) / sizeof(kRefs[0]);
bool g_refTraced[kRefCount] = {};

// Registered as a text ref (type 3) instead of an int (2): the stock provider fills an int, which
// is printed with its decimals.
template <std::size_t I>
bool __stdcall PopRefProvider(DataRefValue* value) {
  const PopRef& ref = kRefs[I];
  if (!g_refTraced[I]) {
    g_refTraced[I] = true;
    std::string text = std::string("decimalPopulation data ref ") + ref.name;
    UhcTraceHook(text.c_str());
  }
  if (value == nullptr || value->type != kStringValue) {
    return false;
  }
  IntRefValue number{kIntValue, 0};
  if (!reinterpret_cast<RefFn>(static_cast<std::uintptr_t>(ref.provider->va))(&number)) {
    return false;
  }
  const std::wstring text = PopText(number.value);
  const BString source{const_cast<wchar_t*>(text.c_str())};
  kBStringAssign(&value->text, &source, -1, -1);
  return true;
}

using PopRefFn = bool(__stdcall*)(DataRefValue* value);
template <std::size_t... I>
constexpr std::array<PopRefFn, sizeof...(I)> MakeRefProviders(std::index_sequence<I...>) {
  return {&PopRefProvider<I>...};
}
constexpr auto kRefProviders = MakeRefProviders(std::make_index_sequence<kRefCount>{});

// ---- printed populations ----

// The conversion number `index` of a printf format (%% skipped) replaced by %s.
bool ReplaceConversion(const wchar_t* format, int index, std::wstring* out) {
  if (format == nullptr) {
    return false;
  }
  int n = 0;
  for (const wchar_t* p = format; *p != L'\0'; ++p) {
    if (*p != L'%') {
      continue;
    }
    if (p[1] == L'%') {
      ++p;
      continue;
    }
    const wchar_t* q = p + 1;
    while (*q != L'\0' && std::wcschr(L"diouxXeEfgGaAcCsSpn", *q) == nullptr) {
      ++q;
    }
    if (*q == L'\0') {
      return false;
    }
    if (n++ == index) {
      out->assign(format, p);
      out->append(L"%s");
      out->append(q + 1);
      return true;
    }
    p = q;
  }
  return false;
}

// Replaces calls of the BString sprintf 0x444EFB(dest, format, ...) whose argument `Index` is a
// population: it is printed as text with its decimals. Every argument is 4 bytes, so the others
// keep their places; the callers push at most four. Index 0: the unit help and the population
// costs; 1: colorizePop's own "%s%d%s"; 2: the counter help's "%d %s = %d".
constexpr const char* kPopFormatTrace[] = {
    "decimalPopulation printed population (unit help, costs)",
    "decimalPopulation printed population (colorizePop)",
    "decimalPopulation printed population (population help)",
};

template <int Index>
void* __cdecl PopFormat() {
  static bool traced = false;
  TraceOnce(&traced, kPopFormatTrace[Index]);
  const std::uint32_t* in = UHC_CALLER_ARGS();
  void* dest = reinterpret_cast<void*>(static_cast<std::uintptr_t>(in[0]));
  const wchar_t* format = reinterpret_cast<const wchar_t*>(static_cast<std::uintptr_t>(in[1]));
  const std::uint32_t a0 = in[2], a1 = in[3], a2 = in[4], a3 = in[5];
  std::uint32_t args[4] = {a0, a1, a2, a3};
  std::wstring changed;
  if (!ReplaceConversion(format, Index, &changed)) {
    return kFormat(dest, format, a0, a1, a2, a3);
  }
  const std::wstring text = PopText(static_cast<std::int32_t>(args[Index]));
  args[Index] = static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(text.c_str()));
  return kFormat(dest, changed.c_str(), args[0], args[1], args[2], args[3]);
}

}  // namespace

extern "C" {

bool __cdecl UhcPopCountParse(const char* text, std::int32_t* out) {
  static bool traced = false;
  TraceOnce(&traced, "decimalPopulation <PopulationCount> (0x5FB92E)");
  return ParseTag(text, out, L"PopulationCount");
}

bool __cdecl UhcPopCapAddParse(const char* text, std::int32_t* out) {
  static bool traced = false;
  TraceOnce(&traced, "decimalPopulation <PopulationCapAddition> (0x5FD719)");
  return ParseTag(text, out, L"PopulationCapAddition");
}

void __cdecl UhcPopCountEffect(std::uint32_t rel, std::int32_t* out, std::int32_t base, float amount,
                               std::uint32_t negate) {
  static bool traced = false;
  TraceOnce(&traced, "decimalPopulation effect PopulationCount (0x8FA835)");
  IntEffect(rel, out, base, amount, negate, L"PopulationCount");
}

void __cdecl UhcPopCapAddEffect(std::uint32_t rel, std::int32_t* out, std::int32_t base, float amount,
                                std::uint32_t negate) {
  static bool traced = false;
  TraceOnce(&traced, "decimalPopulation effect PopulationCapAddition (0x8FA8CF)");
  IntEffect(rel, out, base, amount, negate, L"PopulationCapAddition");
}

// Replaces colorizePop's argument parse 0x6F2A1D(BString* arg), cdecl. The argument is the ref as
// written, e.g. "colorizePop(15)"; stock splits it with strtok "()" and returns atoi of the second
// token, -1 when there is none. Here: the number after the first '(', now a decimal, in engine
// units; -1 likewise.
std::int32_t __cdecl UhcColorizePopArg(const BString* arg) {
  static bool traced = false;
  TraceOnce(&traced, "decimalPopulation colorizePop argument (0x6F576F)");
  const wchar_t* open = arg == nullptr || arg->text == nullptr ? nullptr : std::wcschr(arg->text, L'(');
  double value = 0.0;
  if (open == nullptr || !ParseDecimal(open + 1, &value)) {
    return -1;
  }
  return ScaleRounded(value);
}

}  // extern "C"

namespace uhc {

Outcome ApplyDecimalPopulation(const Config& config) {
  const Config::Args* args = config.First("decimalPopulation");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  int scale = kDefaultScale;
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
      continue;
    }
    char* end = nullptr;
    const long value = std::strtol(arg.c_str(), &end, 10);
    if (end == arg.c_str() || *end != '\0' || value < 2 || value > kMaxScale) {
      Log(L"decimalPopulation: expected a scale from 2 to %d and/or log, got \"%hs\"", kMaxScale, arg.c_str());
      return Outcome::kFailed;
    }
    scale = static_cast<int>(value);
  }

  const std::initializer_list<const Site*> checks = {
      &sites::kPopCountParse, &sites::kPopCapAddParse, &sites::kPopCountEffect, &sites::kPopCapAddEffect,
      &sites::kIntEffect, &sites::kPopCapEffectAdd, &sites::kPopCapEffectRemove, &sites::kTeamPopCap,
      &sites::kStartPopBonus, &sites::kRefPopReg, &sites::kRefPopCapReg, &sites::kRefFuturePopReg,
      &sites::kRefTotalPopReg, &sites::kRefPopProvider, &sites::kRefPopCapProvider, &sites::kRefFuturePopProvider,
      &sites::kRefTotalPopProvider, &sites::kColorizePopArg, &sites::kColorizePopFormat, &sites::kBStringFormat,
      &sites::kPopFormatHelp, &sites::kPopFormatHelp2, &sites::kPopFormatCost, &sites::kPopFormatCost2,
      &sites::kPopFormatCapLine, &sites::kPopFormatCap};
  if (!VerifyAll("decimalPopulation", checks)) {
    return Outcome::kFailed;
  }
  // This one only prints a cost, so another DLL's wrapper there leaves that line in whole numbers,
  // K times too large, and nothing else.
  const bool costLine = Matches(sites::kPopFormatCost3);
  if (!costLine) {
    Log(L"decimalPopulation: the population cost line at 0x%08X is another DLL's; it stays as it is",
        sites::kPopFormatCost3.va);
  }
  for (const XsSyscall& xs : kXs) {
    if (!VerifyAll("decimalPopulation", {xs.site})) {
      return Outcome::kFailed;
    }
  }
  // The cap hook: basePop/extraPop's (applied before this key), or the same hook with stock's
  // own limits when neither key is set.
  if (!PopLimitHooked()) {
    g_uhcPopStockClamps = 1;
    if (!InstallPopLimitHook("decimalPopulation")) {
      return Outcome::kFailed;
    }
  }
  g_uhcPopScale = scale;
  g_log = log;
  for (std::int32_t& last : g_xsLastSet) {
    last = INT32_MIN;  // the first value of each setter is logged
  }

  // mov eax,1 (b8 01 00 00 00) at 0x8FA849: PopulationCount's floor after an effect.
  constexpr std::uint32_t kPopCountFloorImm = 0x008FA84A;
  // push 3 / pop eax / nop over mov eax,[esp+1Ch]: the ref's registered type becomes 3 (text)
  // instead of 2 (int).
  constexpr std::uint8_t kTextType[] = {0x6A, 0x03, 0x58, 0x90};
  constexpr std::uint32_t kTypeOffset = 0x20;
  bool ok = WriteCall(sites::kPopCountParse.va, reinterpret_cast<const void*>(&UhcPopCountParse)) &&
            WriteCall(sites::kPopCapAddParse.va, reinterpret_cast<const void*>(&UhcPopCapAddParse)) &&
            WriteCall(sites::kPopCountEffect.va, reinterpret_cast<const void*>(&UhcPopCountEffect)) &&
            WriteDword(kPopCountFloorImm, static_cast<std::uint32_t>(scale)) &&
            WriteCall(sites::kPopCapAddEffect.va, reinterpret_cast<const void*>(&UhcPopCapAddEffect)) &&
            WriteJmp(sites::kPopCapEffectAdd.va, reinterpret_cast<const void*>(&UhcPopCapEffectAddHook), 8) &&
            WriteJmp(sites::kPopCapEffectRemove.va, reinterpret_cast<const void*>(&UhcPopCapEffectRemoveHook), 8) &&
            WriteJmp(sites::kTeamPopCap.va, reinterpret_cast<const void*>(&UhcTeamPopCapHook), 0x24) &&
            WriteJmp(sites::kStartPopBonus.va, reinterpret_cast<const void*>(&UhcStartPopBonusHook), 8) &&
            WriteCall(sites::kColorizePopArg.va, reinterpret_cast<const void*>(&UhcColorizePopArg)) &&
            WriteCall(sites::kColorizePopFormat.va, reinterpret_cast<const void*>(&PopFormat<1>)) &&
            WriteCall(sites::kPopFormatHelp.va, reinterpret_cast<const void*>(&PopFormat<0>)) &&
            WriteCall(sites::kPopFormatHelp2.va, reinterpret_cast<const void*>(&PopFormat<0>)) &&
            WriteCall(sites::kPopFormatCost.va, reinterpret_cast<const void*>(&PopFormat<0>)) &&
            WriteCall(sites::kPopFormatCost2.va, reinterpret_cast<const void*>(&PopFormat<0>)) &&
            (!costLine || WriteCall(sites::kPopFormatCost3.va, reinterpret_cast<const void*>(&PopFormat<0>))) &&
            WriteCall(sites::kPopFormatCapLine.va, reinterpret_cast<const void*>(&PopFormat<2>)) &&
            WriteCall(sites::kPopFormatCap.va, reinterpret_cast<const void*>(&PopFormat<0>));
  for (std::size_t i = 0; ok && i < kRefCount; ++i) {
    const auto provider = static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(kRefProviders[i]));
    ok = WriteDword(kRefs[i].reg->va + 4, provider) &&
         WriteBytes(kRefs[i].reg->va + kTypeOffset, kTextType, sizeof(kTextType));
  }
  for (std::size_t i = 0; ok && i < kXsCount; ++i) {
    const auto wrapper = static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(kXsWrappers[i]));
    ok = WriteDword(kXs[i].site->va + 1, wrapper);
  }
  if (!ok) {
    return Outcome::kFailed;
  }
  Log(L"decimalPopulation: population in 1/%d steps (<PopulationCount> and <PopulationCapAddition> take "
      L"decimals; caps%ls, effects, %zu XS syscalls and the population texts scaled)%ls",
      scale, g_uhcPopStockClamps != 0 ? L" (stock limits)" : L" (basePop/extraPop limits)", kXsCount,
      log ? L", decimal values and changes logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/decimalpop_hooks.asm

```asm
; Hooks for decimalPopulation (features/decimalpop.cpp): the player effect PopulationCap, the
; shared-team cap and the game-start cap bonus get the population scale K.
; Each hook is entered through a jmp written over the stock code and leaves through an explicit
; jmp to the continuation verified in tools/gen_sites.py; nothing is relocated.
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcPopScale:SDWORD

.data
popCapAddReturn     dd 008D87B3h    ; movzx eax, word ptr [esp+34h]
popCapRemoveReturn  dd 008D20B3h    ; movzx eax, word ptr [esp+20h]
teamPopCapReturn    dd 006796B8h    ; add ebx, eax
startPopBonusReturn dd 00A0D2D9h    ; push eax

.code

; Replaces 0x8D87AB..0x8D87B2 (fld dword ptr [esp+34h] / fnstcw word ptr [esp+34h]) in the
; player effect switch FUN_008D842B, case 14h (PopulationCap, absolute only): the amount, a
; float, is then truncated by fistp and added to getCap(). It is multiplied by K and rounded
; first, so the truncation keeps an exact integer.
UhcPopCapEffectAddHook PROC
    TRACE_ONCE "decimalPopulation PopulationCap effect (0x8D87AB)"
    fld dword ptr [esp+34h]
    fimul g_uhcPopScale
    frndint
    fnstcw word ptr [esp+34h]
    jmp popCapAddReturn
UhcPopCapEffectAddHook ENDP

; The same at 0x8D20AB..0x8D20B2 (fld / fnstcw at [esp+20h]), where the effect is taken back:
; getCap() minus the truncated amount.
UhcPopCapEffectRemoveHook PROC
    TRACE_ONCE "decimalPopulation PopulationCap effect removed (0x8D20AB)"
    fld dword ptr [esp+20h]
    fimul g_uhcPopScale
    frndint
    fnstcw word ptr [esp+20h]
    jmp popCapRemoveReturn
UhcPopCapEffectRemoveHook ENDP

; Replaces 0x679694..0x6796B7 in getCap's shared-team path (GameTeamSharePop): each ally adds
; min(its raw cap, 200, [world+31Ch]). EAX = that ally's raw cap, already scaled; the 200 and
; the world's limit are scaled here. ECX and EDX are free (stock overwrites both).
UhcTeamPopCapHook PROC
    TRACE_ONCE "decimalPopulation team population cap (0x679694)"
    mov ecx, 0C8h
    imul ecx, g_uhcPopScale
    cmp eax, ecx
    jle belowBase
    mov eax, ecx
belowBase:
    mov ecx, dword ptr ds:[00C66234h]
    mov edx, [ecx+13Ch]
    mov ecx, [edx+31Ch]
    imul ecx, g_uhcPopScale
    cmp eax, ecx
    jle belowWorld
    mov eax, ecx
belowWorld:
    jmp teamPopCapReturn
UhcTeamPopCapHook ENDP

; Replaces 0xA0D2D1..0xA0D2D8 (add eax,ebx / add eax,[esi+320h]) at game start, where each
; player's cap becomes getCap() + [player+7Ch] + [world+320h]: the two bonuses are in whole
; population and get K. EBX is kept as stock leaves it; EDX is free (the next call is a
; thiscall that does not take it).
UhcStartPopBonusHook PROC
    TRACE_ONCE "decimalPopulation start cap bonus (0xA0D2D1)"
    mov edx, ebx
    add edx, dword ptr [esi+320h]
    imul edx, g_uhcPopScale
    add eax, edx
    jmp startPopBonusReturn
UhcStartPopBonusHook ENDP

END
```

### src/features/limits.cpp

```cpp
// Limit features: deckCardCount, basePop/extraPop. The hooks live in hooks/limit_hooks.asm and read
// the values below. decimalPopulation (features/decimalpop.cpp) sets the population scale the cap
// hook multiplies its limits by, and installs that hook itself when basePop/extraPop did not.
#include <cstdint>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
std::int32_t g_uhcDeckCardCount = 25;
std::int32_t g_uhcBasePop = 200;
std::int32_t g_uhcExtraPop = 50;
std::int32_t g_uhcPopScale = 1;         // decimalPopulation's K
std::int32_t g_uhcPopStockClamps = 0;   // 1: keep stock's world clamp and 250 cap (decimalPopulation alone)

void UhcDeckLimitHook();
void UhcPopLimitHook();
void UhcPopLimitBaseHook();
}

namespace uhc {
namespace {

constexpr int kStockDeckMin = 20;  // the function's lower clamp (0x7EF019)
constexpr int kMaxLimit = 10000;

bool g_popLimitHooked = false;

}  // namespace

// The population cap hook (0x4581F3), once: basePop/extraPop, or decimalPopulation without them.
bool InstallPopLimitHook(const char* feature) {
  if (g_popLimitHooked) {
    return true;
  }
  if (!VerifyAll(feature, {&sites::kPopLimit})) {
    return false;
  }
  // 0x4581FC (`lea esi,[ecx+0C8h]`, 6 bytes) is where the negative-extra path rejoins.
  if (!WriteJmp(sites::kPopLimit.va, reinterpret_cast<const void*>(&UhcPopLimitHook), 5) ||
      !WriteJmp(sites::kPopLimit.va + 9, reinterpret_cast<const void*>(&UhcPopLimitBaseHook), 6)) {
    return false;
  }
  g_popLimitHooked = true;
  return true;
}

bool PopLimitHooked() { return g_popLimitHooked; }

// Max deck size (0x7EEFF7): 20 for a bad index, 25 past the end of the table, otherwise the
// table value clamped to 20..25. Both 25s become deckCardCount.
Outcome ApplyDeckCardCount(const Config& config) {
  if (!config.Has("deckCardCount")) {
    return Outcome::kNotConfigured;
  }
  const auto count = config.Int("deckCardCount");
  if (!count || *count < kStockDeckMin || *count > kMaxLimit) {
    Log(L"deckCardCount: expected an integer from %d to %d", kStockDeckMin, kMaxLimit);
    return Outcome::kFailed;
  }
  if (!VerifyAll("deckCardCount", {&sites::kDeckLimit, &sites::kDeckOutOfRange})) {
    return Outcome::kFailed;
  }
  g_uhcDeckCardCount = *count;
  // mov eax, imm32 at 0x7EF005: the imm32 starts one byte in.
  if (!WriteDword(sites::kDeckOutOfRange.va + 1, static_cast<std::uint32_t>(*count)) ||
      !WriteJmp(sites::kDeckLimit.va, reinterpret_cast<const void*>(&UhcDeckLimitHook), 10)) {
    return Outcome::kFailed;
  }
  Log(L"deckCardCount: limit %d", *count);
  return Outcome::kApplied;
}

// Population cap (0x4581F3): stock allows at most 50 extra and 200 base population.
Outcome ApplyPopLimit(const Config& config) {
  const bool hasBase = config.Has("basePop");
  const bool hasExtra = config.Has("extraPop");
  if (!hasBase && !hasExtra) {
    return Outcome::kNotConfigured;
  }
  const auto base = hasBase ? config.Int("basePop") : std::optional<int>(g_uhcBasePop);
  const auto extra = hasExtra ? config.Int("extraPop") : std::optional<int>(g_uhcExtraPop);
  if (!base || !extra || *base < 0 || *base > kMaxLimit || *extra < 0 || *extra > kMaxLimit) {
    Log(L"basePop/extraPop: expected integers from 0 to %d", kMaxLimit);
    return Outcome::kFailed;
  }
  if (!VerifyAll("basePop/extraPop", {&sites::kPopLimit})) {
    return Outcome::kFailed;
  }
  g_uhcBasePop = *base;
  g_uhcExtraPop = *extra;
  if (!InstallPopLimitHook("basePop/extraPop")) {
    return Outcome::kFailed;
  }
  Log(L"basePop/extraPop: base %d, extra %d (stock 250 cap and world clamp removed; "
      L"shared team population at 0x679641 keeps its 200-per-player cap)",
      *base, *extra);
  return Outcome::kApplied;
}

}  // namespace uhc
```

### src/hooks/limit_hooks.asm

```asm
; Hooks for the limit features (deckCardCount, basePop/extraPop; decimalPopulation scales the
; population cap hook).
; Each hook is entered through a jmp written over the stock code and leaves through an explicit
; jmp to the continuation verified in src/generated/sites.h; nothing is relocated.
.686
.model flat, c
option casemap :none

include common.inc

EXTERNDEF g_uhcDeckCardCount:SDWORD
EXTERNDEF g_uhcBasePop:SDWORD
EXTERNDEF g_uhcExtraPop:SDWORD
EXTERNDEF g_uhcPopScale:SDWORD
EXTERNDEF g_uhcPopStockClamps:SDWORD

.data
deckLimitReturn dd 007EF030h    ; ret 4
popLimitReturn  dd 0045823Fh    ; pop esi / add esp,8 / ret

.code

; Replaces 0x7EF026..0x7EF02F (cmp eax,19h / jle / mov eax,19h). EAX holds the deck size.
UhcDeckLimitHook PROC
    TRACE_ONCE "deckCardCount (0x7EF026)"
    cmp eax, g_uhcDeckCardCount
    jle done
    mov eax, g_uhcDeckCardCount
done:
    jmp deckLimitReturn
UhcDeckLimitHook ENDP

; Replaces 0x4581F3..0x45823E. In: ECX = extra population, EAX = population cap,
; EDX = the player data whose [+4F4h] adds a bonus. ESI is free: the continuation pops it.
; Stock also clamps against [[[C66234h]+13Ch]+31Ch] (initialized to 200) and caps at 250;
; basePop/extraPop drop both, or basePop above 200 would have no effect.
; decimalPopulation installs the same hook when neither key is set, with g_uhcPopStockClamps
; = 1 so both clamps stay. Every limit (base, extra, world, bonus, 250) is in whole population and
; is multiplied by g_uhcPopScale (1 without decimalPopulation), the scale of EAX.
UhcPopLimitHook PROC
    TRACE_ONCE "basePop/extraPop/decimalPopulation (0x4581F3)"
    cmp ecx, g_uhcExtraPop
    jle UhcPopLimitBaseHook
    mov ecx, g_uhcExtraPop
UhcPopLimitHook ENDP
; Falls through. Also entered from 0x4581FC, where stock jumps with ECX = 0 when the extra
; population is negative (0x679611); that path must be covered too.
UhcPopLimitBaseHook PROC
    mov esi, g_uhcBasePop
    add esi, ecx
    imul esi, g_uhcPopScale
    cmp eax, esi
    jle capOk
    mov eax, esi
capOk:
    cmp g_uhcPopStockClamps, 0
    je bonus
    mov esi, dword ptr ds:[00C66234h]   ; stock 0x45820A: min(cap, extra + [world+31Ch])
    mov esi, [esi + 13Ch]
    mov esi, [esi + 31Ch]
    add esi, ecx
    imul esi, g_uhcPopScale
    cmp eax, esi
    jle bonus
    mov eax, esi
bonus:
    mov edx, [edx + 4F4h]
    test edx, edx
    jle bonusDone
    imul edx, g_uhcPopScale
    add eax, edx
bonusDone:
    cmp g_uhcPopStockClamps, 0
    je done
    mov esi, 0FAh                       ; stock 0x458234: at most 250
    imul esi, g_uhcPopScale
    cmp eax, esi
    jle done
    mov eax, esi
done:
    jmp popLimitReturn
UhcPopLimitBaseHook ENDP

END
```
