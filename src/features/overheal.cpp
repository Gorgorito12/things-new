// overhealHitpointBars [UnitType ...] [segment[=RRGGBB]] [log]: the HP bars and HP texts of marked
// units take InitialHitpoints as 100 %, not MaxHitpoints; with "segment" the HP above it shows.
//
// A unit is created with its proto's InitialHitpoints ([proto+9Ch], 0x498390 in FUN_00498274)
// and is healed up to MaxHitpoints ([proto+98h]); a Hitpoints tech adds the same amount to both
// (0x8F97DD). Every HP display reads the max: the floating bars (0x45FAAF) and the selection
// group bar and 'Group Health' (0x4C5014) take the health ratio FUN_0045F295, HP / max clamped to
// 1; the three HP texts print 'HP/max' with the max from FUN_00480408 (or a copy of it inlined in
// the stat row, 0x4D7575), and '%d/%d (%d+%d)' when that max is above the database proto's
// MaxHitpoints. WoL gives infantry and cavalry MaxHitpoints = 1.1 x InitialHitpoints, so a fresh
// unit shows a 91 % bar and '150/165'.
//
// For a unit whose proto has a marker type (default AbstractOverheal; a stock type or a proto
// name works too, several may be listed) and 1e-6 < InitialHitpoints < MaxHitpoints, the hooks in
// hooks/overheal_hooks.asm replace that max by a reference: InitialHitpoints itself, or
// max x InitialHitpoints / MaxHitpoints when an aura or modifier changed the unit's max (the
// stock rescale 0x9C738B keeps HP / max through such a change, so a full unit stays full). A fresh
// unit then shows a full bar and '150/150', an overhealed one a full bar and '165/150'. The base
// of the '(%d+%d)' split becomes the database proto's InitialHitpoints.
//
// Display only: 0x45F295 and 0x480408 themselves stay stock, so the heal search, transforms,
// modifiers, AI queries and triggers still use the max, and nothing depends on the local player.
// The floating bar is not drawn past 100 %, and the group average stays clamped at 1.
//
// "segment" (Overwatch style): a unit whose HP is above its 100 % gets an orange segment over the
// right end of its full floating bar, (HP - 100 %) / 100 % of the bar's width (all of it from
// twice the 100 %), and its HP texts are coloured the same. The bar keeps its width. The renderer
// FUN_0045C4AF draws every queued bar as one textured quad (ui\hitpoint_bars\hpbar: the fill
// half is a white gradient tinted by the vertex colour, the player's [player+0C8h]) in a single
// draw call; the segment is a second record queued right after the unit's own bar, with a player
// ID no player has, whose six vertices are then moved to the right end of the bar and given the
// segment colour. The stat row's HP text uses the UI markup <color=r, g, b> for the colour. A unit
// at or below its 100 %, and every unmarked unit (whose HP never exceeds its max), keeps the stock
// bar and texts. The selection panel's group bar keeps its three stock
// colours: they are three UI gadgets, and a fourth would need one in the UI data.
#include <cstdint>
#include <cctype>
#include <cstdlib>
#include <cwchar>
#include <cstring>
#include <set>
#include <string>
#include <string_view>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::size_t kMaxTypes = 8;  // the size of g_uhcOverhealTypes
constexpr std::uint32_t kGameGlobal = 0x00C66234;    // game; +13Ch world
constexpr std::uint32_t kDeviceGlobal = 0x00C66044;  // render device; +660h its dynamic vertex buffer
constexpr std::int32_t kSegmentPlayer = static_cast<std::int32_t>(0x804F5648);  // as in overheal_hooks.asm
constexpr std::uint32_t kRecordSize = 0x1C;                  // a queued bar
constexpr std::uint32_t kVertexSize = 0x24;                  // six per bar
constexpr std::uint32_t kDefaultSegmentColour = 0xFFFF8C00;  // ARGB orange

// FUN_0045FB71: queues a floating HP bar, thiscall(world, pos*, scale, fill, player, colour byte).
using QueueBarFn = bool(__fastcall*)(const char* world, void* unused, const float* pos, float scale, float fill,
                                     std::int32_t player, std::uint32_t colourByte);
const auto kQueueBar = reinterpret_cast<QueueBarFn>(0x0045FB71);

// Proto names already logged with "log"; only the game thread touches them.
std::set<std::string, std::less<>> g_loggedProtos;
std::set<std::string, std::less<>> g_loggedSegments;
bool g_loggedDrop = false;
std::uint32_t g_segmentColour = kDefaultSegmentColour;

struct Vertex {  // the renderer's vertex (24h bytes)
  float position[3];
  float normal[3];
  std::uint32_t colour;
  float u;
  float v;
};
static_assert(sizeof(Vertex) == kVertexSize);

struct BarRecord {  // a queued bar (1Ch bytes)
  float position[3];
  float scale;
  float fill;
  std::int32_t player;
  std::uint8_t colourByte;
  std::uint8_t padding[3];
};
static_assert(sizeof(BarRecord) == kRecordSize);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Hook {
  std::uint32_t va;
  std::size_t length;  // the stolen instruction: a call (5) or an fld / mov (6)
  void (*target)();
};

}  // namespace

extern "C" {
// Marker unittype IDs, set on each database load (-1 before); the hooks read the first
// g_uhcOverhealTypeCount of them.
std::int32_t g_uhcOverhealTypes[kMaxTypes] = {-1, -1, -1, -1, -1, -1, -1, -1};
std::int32_t g_uhcOverhealTypeCount = 0;
std::int32_t g_uhcOverhealLog = 0;  // 1 with "overhealHitpointBars ... log"
std::int32_t g_uhcOverhealTextColor = 0;  // 1 with "segment": HP texts above 100 % are coloured
wchar_t g_uhcOverhealFmtPlain[64] = L"%d/%d";  // set with the segment colour
wchar_t g_uhcOverhealFmtSplit[64] = L"%d/%d (%d+%d)";

void UhcOverhealBarHook();
void UhcOverhealGroupHook();
void UhcOverhealPanelMaxHook();
void UhcOverhealStatMaxHook();
void UhcOverhealStatBaseHook();
void UhcOverhealInfoBaseHook();
void UhcOverhealInfoMaxHook();
void UhcOverhealSegmentQueueHook();
void UhcOverhealSegmentRenderHook();
void UhcOverhealSegmentVertexHook();
void UhcOverhealTextStatHook();
void UhcOverhealTextStatSplitHook();

// Called by the hooks (only with "log") each time a unit's reference differs from its max; logs
// the first such unit of each proto name.
void __stdcall UhcOverhealLogReference(const char* unit, float reference, float maxHp) {
  const char* proto = Field<const char*>(unit, 0x5C);  // not null: the hooks checked it
  const char* name = Field<const char*>(proto, 0x10);
  const std::string_view key = name == nullptr ? "?" : name;
  if (g_loggedProtos.find(key) != g_loggedProtos.end()) {
    return;
  }
  g_loggedProtos.emplace(key);
  uhc::Log(L"overhealHitpointBars: unit %d (%hs) HP %.1f is shown against %.1f instead of its max %.1f "
           L"(InitialHitpoints %.1f, MaxHitpoints %.1f); logged once per proto",
           Field<std::int32_t>(unit, 0x10), key.data(), static_cast<double>(Field<float>(unit, 0x64)),
           static_cast<double>(reference), static_cast<double>(maxHp), static_cast<double>(Field<float>(proto, 0x9C)),
           static_cast<double>(Field<float>(proto, 0x98)));
}

// From the bar queue hook (0x45FB6C), after the unit's own bar was queued at pos: queues the
// overheal segment when HP is above the reference (OverhealReference: the max for an unmarked
// unit, so never). The record's fill is the segment's share of the bar, at most 1.
void __stdcall UhcOverhealQueueSegment(const char* unit, const float* pos, float reference) {
  const float hp = Field<float>(unit, 0x64);
  if (!(reference > 1e-6f) || !(hp > reference)) {
    return;
  }
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* world = game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
  if (world == nullptr) {
    return;
  }
  float share = (hp - reference) / reference;
  share = share < 1.0f ? share : 1.0f;
  kQueueBar(world, nullptr, pos, 1.0f, share, kSegmentPlayer, 0xFF);
  if (g_uhcOverhealLog != 0) {
    const char* proto = Field<const char*>(unit, 0x5C);
    const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
    const std::string_view key = name == nullptr ? "?" : name;
    if (g_loggedSegments.find(key) == g_loggedSegments.end()) {
      g_loggedSegments.emplace(key);
      uhc::Log(L"overhealHitpointBars: unit %d (%hs) HP %.1f is above its 100 %% %.1f: overheal segment of %.1f %% "
               L"of the bar; logged once per proto",
               Field<std::int32_t>(unit, 0x10), key.data(), static_cast<double>(hp), static_cast<double>(reference),
               static_cast<double>(share * 100.0f));
    }
  }
}

// From the renderer hook (0x45C4B9), before the vertex lock: when the queue's six vertices per bar
// would not fit in the dynamic vertex buffer ([vb+4] bytes; stock then draws no bar that frame),
// the segment records are removed so that the stock bars are drawn as without the feature.
void __stdcall UhcOverhealSegmentFit(char* world) {
  const std::int32_t count = Field<std::int32_t>(world, 0x8D4);
  const char* device = *reinterpret_cast<const char* const*>(kDeviceGlobal);
  const char* buffer = device == nullptr ? nullptr : Field<const char*>(device, 0x660);
  if (count <= 0 || buffer == nullptr ||
      static_cast<std::uint64_t>(count) * 6 * kVertexSize <= Field<std::uint32_t>(buffer, 4)) {
    return;
  }
  auto* records = Field<BarRecord*>(world, 0x8D0);
  std::int32_t kept = 0;
  for (std::int32_t i = 0; i < count; ++i) {
    if (records[i].player != kSegmentPlayer) {
      records[kept++] = records[i];
    }
  }
  *reinterpret_cast<std::int32_t*>(world + 0x8D4) = kept;
  if (!g_loggedDrop && kept != count) {
    g_loggedDrop = true;
    uhc::Log(L"overhealHitpointBars: %d bars do not fit in the vertex buffer (%u bytes): this frame's %d overheal "
             L"segments were dropped (logged once)",
             count, Field<std::uint32_t>(buffer, 4), count - kept);
  }
}

// From the renderer loop hook (0x45CB72), for a segment record: its six vertices, written by the
// stock loop like a full bar (fill = the segment's share), become the right end of the bar. The
// left ones (v0, v2, v3, at P - scale/2 x B) move right by scale x (1 - share) x B; every vertex
// takes the fill part of the texture (u 1.0 on the left, 0.5 on the right, as for a full bar) and
// the segment colour.
void __stdcall UhcOverhealSegmentVertices(const char* world, std::int32_t offset, Vertex* vertices,
                                          const char* camera) {
  const auto* record = reinterpret_cast<const BarRecord*>(Field<const char*>(world, 0x8D0) + offset);
  float share = record->fill;
  share = share < 0.0f ? 0.0f : (share > 1.0f ? 1.0f : share);
  const float shift = record->scale * (1.0f - share);
  const float* right = reinterpret_cast<const float*>(camera + 0x28);  // B, the camera's right vector
  for (int k = 0; k < 6; ++k) {
    Vertex& vertex = vertices[k];
    const bool left = k == 0 || k == 2 || k == 3;
    if (left) {
      for (int axis = 0; axis < 3; ++axis) {
        vertex.position[axis] += shift * right[axis];
      }
    }
    vertex.u = left ? 1.0f : 0.5f;
    vertex.colour = g_segmentColour;
  }
}
}

namespace uhc {

Outcome ApplyOverhealHitpointBars(const Config& config) {
  const Config::Args* args = config.First("overhealHitpointBars");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }

  std::vector<std::string> typeNames;
  bool log = false;
  bool segment = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else if (_strnicmp(arg.c_str(), "segment", 7) == 0 && (arg.size() == 7 || arg[7] == '=')) {
      segment = true;
      if (arg.size() > 7) {
        char* end = nullptr;
        const unsigned long rgb = std::strtoul(arg.c_str() + 8, &end, 16);
        if (arg.size() != 14 || end != arg.c_str() + 14 || std::isxdigit(static_cast<unsigned char>(arg[8])) == 0) {
          Log(L"overhealHitpointBars: %hs: expected segment or segment=RRGGBB (hex); feature not applied",
              arg.c_str());
          return Outcome::kFailed;
        }
        g_segmentColour = 0xFF000000u | static_cast<std::uint32_t>(rgb);
      }
    } else if (typeNames.size() == kMaxTypes) {
      Log(L"overhealHitpointBars: more than %u unit types (expected: [UnitType ...] [segment[=RRGGBB]] [log]); "
          L"feature not applied",
          static_cast<unsigned>(kMaxTypes));
      return Outcome::kFailed;
    } else {
      typeNames.push_back(arg);
    }
  }
  if (typeNames.empty()) {
    typeNames.push_back("AbstractOverheal");
  }

  if (!VerifyAll("overhealHitpointBars",
                 {&sites::kOverhealBarRatio, &sites::kOverhealGroupRatio, &sites::kOverhealPanelMax,
                  &sites::kOverhealStatMax, &sites::kOverhealStatBase, &sites::kOverhealInfoProto,
                  &sites::kOverhealInfoBase, &sites::kOverhealInfoMax, &sites::kMaxHitpointsGetter,
                  &sites::kHealthRatio, &sites::kInitialHitpointsTag, &sites::kMaxHitpointsTag, &sites::kIsA,
                  &sites::kIsATrue})) {
    return Outcome::kFailed;
  }
  if (segment && !VerifyAll("overhealHitpointBars segment",
                            {&sites::kOverhealSegmentQueue, &sites::kHpBarQueue, &sites::kHpBarRenderStart,
                             &sites::kHpBarRenderLoop, &sites::kDynamicVbLock, &sites::kDynamicVbFull,
                             &sites::kOverhealTextStat, &sites::kOverhealTextStatSplit})) {
    return Outcome::kFailed;
  }
  for (std::size_t i = 0; i < typeNames.size(); ++i) {
    if (!RequestAbstractUnitType(typeNames[i].c_str(), &g_uhcOverhealTypes[i])) {
      return Outcome::kFailed;
    }
  }
  g_uhcOverhealTypeCount = static_cast<std::int32_t>(typeNames.size());
  g_uhcOverhealLog = log ? 1 : 0;

  // Each hook re-does the stolen instruction with the reference in place of the max, then jumps
  // to the instruction after it.
  const Hook hooks[] = {
      {0x0045FAAF, 5, &UhcOverhealBarHook},       // call 45F295h: the floating bar's fill
      {0x004C5014, 5, &UhcOverhealGroupHook},     // call 45F295h: the selection group's average
      {0x00698B35, 5, &UhcOverhealPanelMaxHook},  // call 480408h: unitHitPointsValue's max
      {0x004D7575, 6, &UhcOverhealStatMaxHook},   // mov eax,[ecx+0B4h]: the stat row's inlined max
      {0x004D7615, 6, &UhcOverhealStatBaseHook},  // fld [eax+98h]: the stat row's base
      {0x009AFA2A, 6, &UhcOverhealInfoBaseHook},  // fld [ecx+98h]: ObjectInfo's base
      {0x009AFA4E, 5, &UhcOverhealInfoMaxHook},   // call 480408h: ObjectInfo's max
  };
  for (const Hook& hook : hooks) {
    if (!WriteJmp(hook.va, reinterpret_cast<const void*>(hook.target), hook.length)) {
      return Outcome::kFailed;
    }
  }
  if (segment) {
    // The text colour, as the UI markup <color=r, g, b> takes it (0xBA1E44: '<color=1, 0, 0>').
    const double red = ((g_segmentColour >> 16) & 0xFF) / 255.0;
    const double green = ((g_segmentColour >> 8) & 0xFF) / 255.0;
    const double blue = (g_segmentColour & 0xFF) / 255.0;
    swprintf_s(g_uhcOverhealFmtPlain, L"<color=%.2f, %.2f, %.2f>%%d/%%d</color>", red, green, blue);
    swprintf_s(g_uhcOverhealFmtSplit, L"<color=%.2f, %.2f, %.2f>%%d/%%d (%%d+%%d)</color>", red, green, blue);
    g_uhcOverhealTextColor = 1;
    // Each replaces 5 or 6 bytes and re-does them (a push of the format, or the stolen
    // instructions), then jumps to the next instruction.
    const Hook segmentHooks[] = {
        {0x0045FB6C, 5, &UhcOverhealSegmentQueueHook},   // jmp 4516B3h: after the bar was queued
        {0x0045C4B9, 6, &UhcOverhealSegmentRenderHook},  // mov ebx,[ebp+8D4h]: the renderer's count
        {0x0045CB72, 6, &UhcOverhealSegmentVertexHook},  // add eax,1 / add ecx,1Ch: a record's end
        {0x004D7651, 5, &UhcOverhealTextStatHook},       // push '%d/%d': the stat row
        {0x0069A9C0, 5, &UhcOverhealTextStatSplitHook},  // push '%d/%d (%d+%d)': the stat row
    };
    for (const Hook& hook : segmentHooks) {
      if (!WriteJmp(hook.va, reinterpret_cast<const void*>(hook.target), hook.length)) {
        return Outcome::kFailed;
      }
    }
  }

  std::string names;
  for (const std::string& name : typeNames) {
    names += names.empty() ? name : ", " + name;
  }
  wchar_t segmentText[96] = L"";
  if (segment) {
    swprintf_s(segmentText, L", HP above it shown as a segment and texts coloured %06X", g_segmentColour & 0xFFFFFFu);
  }
  Log(L"overhealHitpointBars: HP bars and HP texts of units of unittype %hs take InitialHitpoints as 100 %%%ls%ls "
      L"(display only)",
      names.c_str(), segmentText, log ? L", the first unit of each proto logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
