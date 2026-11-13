// overhealHitpointBars [UnitType ...] [segment[=RRGGBB]] [bar=<texture>] [stat[=Label]] [log]: the
// HP bars and HP texts of marked units take InitialHitpoints as 100 %, not MaxHitpoints; with
// "segment" the HP above it shows.
//
// A unit is created with its proto's InitialHitpoints ([proto+9Ch], 0x498390 in FUN_00498274)
// and is healed up to MaxHitpoints ([proto+98h]); a Hitpoints tech adds the same amount to both
// (0x8F97DD). Every HP display reads the max: the floating bars (0x45FAAF) and the selection
// group bar and 'Group Health' (0x4C5014) take the health ratio FUN_0045F295, HP / max clamped to
// 1; the three HP texts print 'HP/max' with the max from FUN_00480408 (or a copy of it inlined in
// the stat row, 0x4D7575), and '%d/%d (%d+%d)' when that max is above the database proto's
// MaxHitpoints. A mod that gives infantry and cavalry MaxHitpoints = 1.1 x InitialHitpoints, so a fresh
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
// segment colour (the shared floating bar hooks, floatingbars.h). The stat row's HP text uses the UI markup <color=r, g, b> for the colour. A unit
// at or below its 100 %, and every unmarked unit (whose HP never exceeds its max), keeps the stock
// bar and texts. The selection panel's bar under the portrait is one of three progress bar gadgets
// (green, yellow, red) of uiunitselection.xml, looked up by name at panel creation; "segment" adds
// no gadget and shows the overheal on the game's own green one ([panel+310h]): after each refresh
// (0x4C83DF), while every selected unit is at or above its 100 % and the group's average overheal
// share is above 0, the green part is filled short (1 - that share) and the bar's background
// drawable [bar+140h] gets the overheal texture (vtable +7Ch, as the setter 0x5CAF02 calls it), so the
// right end shows it. The texture is "bar=<texture>", else ui\uhc\health_overheal (the orange bar of
// tools/make_bar.py, in the segment's default colour) when art\ui\uhc\health_overheal.ddt is in the game
// folder, else the game's ui\ingame\ingame_ui_health_yellow. When the overheal ends the UI data's
// texture, ui\ingame\ui_health_bar, is put back.
//
// "stat[=Label]": the stat panel gets an "Overheal" row right after the HP row (0x4D76DB) for a
// marked unit, 'overheal/capacity' (HP above the 100 % / max above it, truncated like the HP row),
// written with the calls of the stock "Group Health" row (0x69A9D3), whose label is a literal too.
// The label is the text after '=' ('_' for a space; UTF-8 or ANSI), or a string table entry when it
// is a number.
#include <windows.h>

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
#include "../floatingbars.h"
#include "../generated/sites.h"
#include "../techsubtypes.h"
#include "../unitpanel.h"
#include "../log.h"
#include "../patch.h"
#include "../unittypes.h"

namespace {

constexpr std::size_t kMaxTypes = 8;  // the size of g_uhcOverhealTypes
constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +13Ch world
constexpr std::uint32_t kSegmentPlayer = 0x804F5648;  // a floating bar kind ('OVH', negative: no player has it)
constexpr std::uint32_t kDefaultSegmentColour = 0xFFFF8C00;  // ARGB orange

// Proto names already logged with "log"; only the game thread touches them.
std::set<std::string, std::less<>> g_loggedProtos;
std::set<std::string, std::less<>> g_loggedSegments;
std::uint32_t g_segmentColour = kDefaultSegmentColour;

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

struct Hook {
  std::uint32_t va;
  std::size_t length;  // the stolen instruction: a call (5) or an fld / mov (6)
  void (*target)();
};

// The engine's string: one pointer to a wide, reference-counted buffer; null is empty.
struct BString {
  wchar_t* text;
};

// UI gadgets (docs/engine-symbols.md, "Hit points").
constexpr std::uint32_t kLabelStyle = 0x00D6F5D0;    // the Group Health row's label style (vtable +84h)
constexpr std::uint32_t kValueStyle = 0x00C6657C;    // its value style
constexpr std::int32_t kStatPanelRows = 9;           // StackLabel/StackValue 0..8 (0x9BBAD1)
constexpr wchar_t kBarBackground[] = L"ui\\ingame\\ui_health_bar";  // the bars' background in the UI data

using ProgressGadgetFn = char*(__cdecl*)(std::int32_t handle);
using GadgetReleaseFn = std::int32_t(__cdecl*)(std::int32_t handle);
using ProgressFillFn = void(__thiscall*)(char* bar, float fill);
using DrawableTextureFn = void(__thiscall*)(void* drawable, const BString* texture, std::int32_t unused);
using GadgetRefFn = std::int32_t*(__thiscall*)(std::int32_t* ref, std::int32_t handle);  // ref: handle, gadget
using BStringFromWideFn = BString*(__thiscall*)(BString* self, const wchar_t* text);
using BStringFromIdFn = BString*(__thiscall*)(BString* self, std::int32_t stringId);
using BStringSetFn = BString*(__thiscall*)(BString* self, const BString* source);
using BStringFreeFn = void(__thiscall*)(BString* self);
using MaxHitpointsFn = float(__thiscall*)(const char* unit);
using GadgetStyleFn = void(__thiscall*)(char* gadget, const void* style);
using GadgetTextFn = void(__thiscall*)(char* gadget, const BString* text);
using GadgetUpdateFn = void(__thiscall*)(char* gadget);
const auto kProgressGadget = reinterpret_cast<ProgressGadgetFn>(0x0044B8B8);
const auto kGadgetRelease = reinterpret_cast<GadgetReleaseFn>(0x0040431B);
const auto kProgressFill = reinterpret_cast<ProgressFillFn>(0x00590772);
const auto kGadgetRef = reinterpret_cast<GadgetRefFn>(0x004C519C);
const auto kBStringFromWide = reinterpret_cast<BStringFromWideFn>(0x00401A12);
const auto kBStringFromId = reinterpret_cast<BStringFromIdFn>(0x0058EA52);
const auto kBStringSet = reinterpret_cast<BStringSetFn>(0x0040196F);
const auto kBStringFree = reinterpret_cast<BStringFreeFn>(0x004010CA);
const auto kMaxHitpoints = reinterpret_cast<MaxHitpointsFn>(0x00480408);

template <typename Fn>
Fn VirtualAt(const char* object, std::uint32_t offset) {
  return *reinterpret_cast<const Fn*>(*reinterpret_cast<const char* const*>(object) + offset);
}

const char* GameWorld() {
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  return game == nullptr ? nullptr : Field<const char*>(game, 0x13C);
}

// The unit with this ID in the world's table ([world+0Ch], count [world+10h]), as the engine looks
// it up (ID & 3FFFFh, then the stored ID must match); null if it is gone.
const char* UnitById(const char* world, std::int32_t id) {
  if (world == nullptr || id < 0 || (id & 0x3FFFF) >= Field<std::int32_t>(world, 0x10)) {
    return nullptr;
  }
  const char* unit = Field<const char* const*>(world, 0x0C)[id & 0x3FFFF];
  return unit != nullptr && Field<std::int32_t>(unit, 0x10) == id ? unit : nullptr;
}

// The portrait gadget's handle, looked up again when the panel is another one or was rebuilt (its
// green bar has another handle).
const char* g_portraitPanel = nullptr;
std::int32_t g_portraitGreen = 0;
bool g_portraitBackground = false;  // the green bar has the overheal texture now
bool g_portraitFillLogged = false;
std::wstring g_portraitTexture;
// The portrait bar's overheal texture when "bar=" names none: the shipped orange bar when its file is in the
// game folder (the working directory), else the game's yellow one.
constexpr wchar_t kShippedBarFile[] = L"art\\ui\\uhc\\health_overheal.ddt";
constexpr wchar_t kShippedBarTexture[] = L"ui\\uhc\\health_overheal";
constexpr wchar_t kStockBarTexture[] = L"ui\\ingame\\ingame_ui_health_yellow";

// The stat row: its label (a literal, or a string table ID when g_statLabelId >= 0).
bool g_statRow = false;
std::wstring g_statLabel = L"Overheal";
std::int32_t g_statLabelId = -1;
bool g_statLogged = false;


// Sets a stat row gadget's text as the Group Health row does: the style, the text, the update
// (vtable +84h, +80h, +54h), then an empty help text ([gadget+68h]).
void SetRowText(char* gadget, const void* style, const wchar_t* text) {
  BString value;
  kBStringFromWide(&value, text);
  VirtualAt<GadgetStyleFn>(gadget, 0x84)(gadget, style);
  VirtualAt<GadgetTextFn>(gadget, 0x80)(gadget, &value);
  VirtualAt<GadgetUpdateFn>(gadget, 0x54)(gadget);
  kBStringFree(&value);
  BString empty;
  kBStringFromWide(&empty, L"");
  kBStringSet(reinterpret_cast<BString*>(gadget + 0x68), &empty);
  kBStringFree(&empty);
}

// A row gadget from its handle, as 0x69A9D3 gets it (the reference is released at once; the panel
// keeps the gadget).
char* RowGadget(std::int32_t handle) {
  std::int32_t ref[2] = {0, 0};
  std::int32_t* result = kGadgetRef(ref, handle);
  char* gadget = reinterpret_cast<char*>(static_cast<std::uintptr_t>(static_cast<std::uint32_t>(result[1])));
  if (result[1] != 0) {
    kGadgetRelease(result[0]);
  }
  return gadget;
}

// "Sobrecuración", "Over_heal" (a space), or "12345" (a string table ID); UTF-8, else ANSI.
bool ParseLabel(const std::string& text, std::wstring* label, std::int32_t* stringId) {
  if (text.empty()) {
    return false;
  }
  if (text.find_first_not_of("0123456789") == std::string::npos) {
    *stringId = std::atoi(text.c_str());
    return true;
  }
  wchar_t wide[64];
  int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.c_str(), -1, wide, 64);
  if (length == 0) {
    length = MultiByteToWideChar(CP_ACP, 0, text.c_str(), -1, wide, 64);
  }
  if (length == 0) {
    return false;
  }
  for (wchar_t& c : wide) {
    c = c == L'_' ? L' ' : c;
  }
  *label = wide;
  return true;
}

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
void UhcOverhealTextStatHook();
void UhcOverhealTextStatSplitHook();
void UhcOverhealPortraitHook();
void UhcOverhealStatRowHook();
float UhcOverhealReferenceOf(const char* unit);  // overheal_hooks.asm, cdecl; the max for an unmarked unit
std::int32_t UhcOverhealMarked(const char* proto);

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

// From the shared floating bar hook (floatingbars.h), after the unit's own bar was queued at pos: queues the
// overheal segment when HP is above the reference (the max for an unmarked unit, so never). The record's fill is
// the segment's share of the bar, at most 1. A foundation's bar is its build fraction: no segment.
void OverhealBarQueued(const char* unit, const float* pos, bool constructing, bool) {
  if (constructing) {
    return;
  }
  const float reference = UhcOverhealReferenceOf(unit);
  const float hp = Field<float>(unit, 0x64);
  if (!(reference > 1e-6f) || !(hp > reference)) {
    return;
  }
  float share = (hp - reference) / reference;
  share = share < 1.0f ? share : 1.0f;
  uhc::QueueFloatingBar(pos, share, kSegmentPlayer);
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

// From the shared renderer loop hook, for a segment record: its six vertices, written by the stock loop like a full
// bar (fill = the segment's share), become the right end of the bar. The left ones (v0, v2, v3, at P - scale/2 x B)
// move right by scale x (1 - share) x B; every vertex takes the fill part of the texture (u 1.0 on the left, 0.5 on
// the right, as for a full bar) and the segment colour.
void OverhealSegmentVertices(const uhc::FloatingBarRecord& record, uhc::FloatingBarVertex* vertices,
                             const char* camera) {
  float share = record.fill;
  share = share < 0.0f ? 0.0f : (share > 1.0f ? 1.0f : share);
  const float shift = record.scale * (1.0f - share);
  const float* right = reinterpret_cast<const float*>(camera + 0x28);  // B, the camera's right vector
  for (int k = 0; k < 6; ++k) {
    uhc::FloatingBarVertex& vertex = vertices[k];
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

// From the portrait hook (0x4C83DF), after the selection panel filled the group's colour bar. While
// the group has an overheal the green bar, the game's own gadget, shows it: the mask (green) stops at
// 1 - the group's average overheal share ((HP - 100 %) / 100 %, at most 1; 0 for a unit at or below
// its 100 % or unmarked), and the rest shows the bar's background, whose texture is the overheal one
// while it lasts (vtable +7Ch of the bar's drawable [bar+140h], as the game's setter 0x5CAF02 calls it). The group: unit IDs [group+10h], count [group+14h]
// (FUN_004C4FB5).
void __stdcall UhcOverhealPortrait(char* panel, const char* group) {
  if (panel == nullptr || group == nullptr) {
    return;
  }
  const std::int32_t green = Field<std::int32_t>(panel, 0x310);
  if (panel != g_portraitPanel || green != g_portraitGreen) {
    g_portraitPanel = panel;
    g_portraitGreen = green;
    g_portraitBackground = false;  // a new gadget has the UI data's background
  }
  float share = 0.0f;
  std::int32_t units = 0;
  // The stock bar is full only when every unit of the group is at or above its 100 % (the average
  // of the ratios, each clamped to 1).
  if (Field<float>(group, 0x1C) >= 0.999f) {
    const char* world = GameWorld();
    const auto* ids = Field<const std::int32_t*>(group, 0x10);
    const std::int32_t count = Field<std::int32_t>(group, 0x14);
    float sum = 0.0f;
    for (std::int32_t i = 0; ids != nullptr && i < count; ++i) {
      const char* unit = UnitById(world, ids[i]);
      if (unit == nullptr) {
        continue;
      }
      ++units;
      const char* proto = Field<const char*>(unit, 0x5C);
      if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
        continue;
      }
      const float reference = UhcOverhealReferenceOf(unit);
      const float hp = Field<float>(unit, 0x64);
      if (reference > 1e-6f && hp > reference) {
        const float part = (hp - reference) / reference;
        sum += part < 1.0f ? part : 1.0f;
      }
    }
    share = units > 0 ? sum / static_cast<float>(units) : 0.0f;
  }
  const bool overheal = share > 0.0f;
  if (!overheal && !g_portraitBackground) {
    return;  // the bar is as the game left it
  }
  char* bar = kProgressGadget(green);
  if (bar == nullptr) {
    return;
  }
  kGadgetRelease(green);
  void* background = Field<void*>(bar, 0x140);  // the bar's drawable: it keeps its size, only the texture changes
  if (background == nullptr) {
    return;
  }
  if (overheal != g_portraitBackground) {
    BString texture;
    kBStringFromWide(&texture, overheal ? g_portraitTexture.c_str() : kBarBackground);
    const auto setTexture = reinterpret_cast<DrawableTextureFn>((*reinterpret_cast<void***>(background))[0x7C / 4]);
    setTexture(background, &texture, -1);
    kBStringFree(&texture);
    g_portraitBackground = overheal;
  }
  if (!overheal) {
    return;
  }
  kProgressFill(bar, 1.0f - share);  // the mask (the HP part) from the left, the background shows the rest
  if (g_uhcOverhealLog != 0 && !g_portraitFillLogged) {
    g_portraitFillLogged = true;
    uhc::Log(L"overhealHitpointBars: the portrait bar shows an overheal of %.1f %% of the bar (%d units; logged once)",
             static_cast<double>(share * 100.0f), units);
  }
}

// From the stat row hook (0x4D76DB, right after the HP row; row = the next free row): writes the
// overheal row for the panel's unit when it is marked. True if it did; the hook then counts it.
bool __stdcall UhcOverhealStatRow(const char* panel, const char* unit, std::int32_t row) {
  if (panel == nullptr || unit == nullptr || row < 0 || row >= kStatPanelRows) {
    return false;
  }
  const char* proto = Field<const char*>(unit, 0x5C);
  if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
    return false;
  }
  char* label = RowGadget(Field<std::int32_t>(panel, 0x174 + row * 4));
  char* value = RowGadget(Field<std::int32_t>(panel, 0x198 + row * 4));
  if (label == nullptr || value == nullptr) {
    return false;
  }
  // Truncated like the HP row's '%d/%d' (fistp with the chop rounding), so the numbers add up.
  const int reference = static_cast<int>(UhcOverhealReferenceOf(unit));
  const int hp = static_cast<int>(Field<float>(unit, 0x64));
  const int maxHp = static_cast<int>(kMaxHitpoints(unit));
  const int overheal = hp > reference ? hp - reference : 0;
  const int capacity = maxHp > reference ? maxHp - reference : 0;
  wchar_t text[96];
  if (overheal > 0 && g_uhcOverhealTextColor != 0) {
    swprintf_s(text, L"<color=%.2f, %.2f, %.2f>%d/%d</color>", ((g_segmentColour >> 16) & 0xFF) / 255.0,
               ((g_segmentColour >> 8) & 0xFF) / 255.0, (g_segmentColour & 0xFF) / 255.0, overheal, capacity);
  } else {
    swprintf_s(text, L"%d/%d", overheal, capacity);
  }
  if (g_statLabelId >= 0) {
    BString name;
    kBStringFromId(&name, g_statLabelId);
    SetRowText(label, reinterpret_cast<const void*>(kLabelStyle), name.text == nullptr ? L"" : name.text);
    kBStringFree(&name);
  } else {
    SetRowText(label, reinterpret_cast<const void*>(kLabelStyle), g_statLabel.c_str());
  }
  SetRowText(value, reinterpret_cast<const void*>(kValueStyle), text);
  if (g_uhcOverhealLog != 0 && !g_statLogged) {
    g_statLogged = true;
    uhc::Log(L"overhealHitpointBars: stat row %d of unit %d (%hs): overheal %ls (logged once)", row,
             Field<std::int32_t>(unit, 0x10), Field<const char*>(proto, 0x10), text);
  }
  return true;
}

// The minimized interface's row (unitpanel.cpp): the same numbers as the stat row, which that
// interface never fills. It shows for a marked unit once it has overheal: the row is shared.
bool __stdcall UhcOverhealUnitPanel(const char* panel, const char* unit) {
  const char* proto = Field<const char*>(unit, 0x5C);
  if (proto == nullptr || UhcOverhealMarked(proto) == 0) {
    return false;
  }
  const int reference = static_cast<int>(UhcOverhealReferenceOf(unit));
  const int hp = static_cast<int>(Field<float>(unit, 0x64));
  const int maxHp = static_cast<int>(kMaxHitpoints(unit));
  if (hp <= reference || maxHp <= reference) {
    return false;
  }
  wchar_t text[96];
  if (g_uhcOverhealTextColor != 0) {
    swprintf_s(text, L"<color=%.2f, %.2f, %.2f>%d/%d</color>", ((g_segmentColour >> 16) & 0xFF) / 255.0,
               ((g_segmentColour >> 8) & 0xFF) / 255.0, (g_segmentColour & 0xFF) / 255.0, hp - reference,
               maxHp - reference);
  } else {
    swprintf_s(text, L"%d/%d", hp - reference, maxHp - reference);
  }
  wchar_t label[96];
  if (g_statLabelId >= 0) {
    BString name;
    kBStringFromId(&name, g_statLabelId);
    swprintf_s(label, L"%ls:", name.text == nullptr ? L"" : name.text);
    kBStringFree(&name);
  } else {
    swprintf_s(label, L"%ls:", g_statLabel.c_str());
  }
  return uhc::SetUnitPanelRow(panel, label, text);
}
}

namespace {

// The Data subtype MaxHPOnly: the stock subtype Hitpoints rescales the HP of the units that stand (0xA0036E), so a
// unit at 100 % stays there; this one writes only MaxHitpoints [proto+98h], so that room for overheal grows and
// the units keep their HP.
using EffectValueFn = void(__cdecl*)(std::uint8_t relativity, float* target, float base, float amount, bool unapply);
const auto kEffectValue = reinterpret_cast<EffectValueFn>(0x007F892A);
constexpr std::uint32_t kProtoMaxHp = 0x98;
int g_maxHpLogLines = 0;

void ChangeMaxHpOnly(char* proto, const char* base, float amount, std::uint8_t relativity, bool unapply) {
  auto* value = reinterpret_cast<float*>(proto + kProtoMaxHp);
  const float before = *value;
  kEffectValue(relativity, value, *reinterpret_cast<const float*>(base + kProtoMaxHp), amount, unapply);
  if (g_maxHpLogLines < 40) {
    ++g_maxHpLogLines;
    uhc::Log(L"overhealHitpointBars: MaxHPOnly on proto %d, relativity %u, amount %g%ls: max %g -> %g",
             *reinterpret_cast<const std::int32_t*>(proto + 8), relativity, static_cast<double>(amount),
             unapply ? L" (removed)" : L"", static_cast<double>(before), static_cast<double>(*value));
  }
}

}  // namespace

namespace uhc {

Outcome ApplyOverhealHitpointBars(const Config& config) {
  const Config::Args* args = config.First("overhealHitpointBars");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }

  std::vector<std::string> typeNames;
  bool log = false;
  bool segment = false;
  g_portraitTexture.clear();
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
    } else if (_strnicmp(arg.c_str(), "bar=", 4) == 0 && arg.size() > 4) {
      g_portraitTexture.assign(arg.begin() + 4, arg.end());
    } else if (_strnicmp(arg.c_str(), "stat", 4) == 0 && (arg.size() == 4 || arg[4] == '=')) {
      g_statRow = true;
      if (arg.size() > 4 && !ParseLabel(arg.substr(5), &g_statLabel, &g_statLabelId)) {
        Log(L"overhealHitpointBars: %hs: expected stat or stat=<label> (a word, '_' for a space, or a string table "
            L"ID); feature not applied",
            arg.c_str());
        return Outcome::kFailed;
      }
    } else if (typeNames.size() == kMaxTypes) {
      Log(L"overhealHitpointBars: more than %u unit types (expected: [UnitType ...] [segment[=RRGGBB]] [stat[=Label]] "
          L"[log]); feature not applied",
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
                            {&sites::kOverhealTextStat, &sites::kOverhealTextStatSplit,
                             &sites::kOverhealPortraitTail, &sites::kOverhealPortraitColours,
                             &sites::kHealthBarGadgets, &sites::kProgressGadget,
                             &sites::kGadgetRelease, &sites::kProgressFill,
                             &sites::kBStringFromWide, &sites::kBStringFree})) {
    return Outcome::kFailed;
  }
  if (g_statRow && !VerifyAll("overhealHitpointBars stat",
                              {&sites::kOverhealStatRow, &sites::kGroupHealthRow, &sites::kGadgetRef,
                               &sites::kGadgetRelease, &sites::kBStringFromWide, &sites::kBStringSet,
                               &sites::kBStringFree, &sites::kBStringFromId})) {
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
  if (segment && g_portraitTexture.empty()) {
    const bool shipped = GetFileAttributesW(kShippedBarFile) != INVALID_FILE_ATTRIBUTES;
    g_portraitTexture = shipped ? kShippedBarTexture : kStockBarTexture;
    if (!shipped) {
      Log(L"overhealHitpointBars: %ls is not in the game folder: the portrait bar shows the overheal with %ls",
          kShippedBarFile, kStockBarTexture);
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
        {0x004D7651, 5, &UhcOverhealTextStatHook},       // push '%d/%d': the stat row
        {0x0069A9C0, 5, &UhcOverhealTextStatSplitHook},  // push '%d/%d (%d+%d)': the stat row
        {0x004C83DF, 9, &UhcOverhealPortraitHook},       // lea ecx,[esp+70h] / call 4010CAh: the portrait bar
    };
    for (const Hook& hook : segmentHooks) {
      if (!WriteJmp(hook.va, reinterpret_cast<const void*>(hook.target), hook.length)) {
        return Outcome::kFailed;
      }
    }
    // The segment record: queued after the unit's bar, drawn over its right end (floatingbars.h).
    if (!AddFloatingBarQueued(&OverhealBarQueued, "overhealHitpointBars segment") ||
        !AddFloatingBarKind(kSegmentPlayer, &OverhealSegmentVertices, "overhealHitpointBars segment")) {
      return Outcome::kFailed;
    }
  }
  // mov edi,2 / mov [esp+2Ch],edi: the row counter after the HP row.
  if (g_statRow && !WriteJmp(0x004D76DB, reinterpret_cast<const void*>(&UhcOverhealStatRowHook), 9)) {
    return Outcome::kFailed;
  }
  if (g_statRow && !AddUnitPanelRow(&UhcOverhealUnitPanel)) {
    return Outcome::kFailed;
  }

  std::string names;
  for (const std::string& name : typeNames) {
    names += names.empty() ? name : ", " + name;
  }
  wchar_t segmentText[384] = L"";
  if (segment) {
    _snwprintf_s(segmentText, _TRUNCATE,
                 L", HP above it shown as a segment and texts coloured %06X, the portrait bar's end with %ls",
                 g_segmentColour & 0xFFFFFFu, g_portraitTexture.c_str());
  }
  wchar_t statText[96] = L"";
  if (g_statRow && g_statLabelId >= 0) {
    swprintf_s(statText, L", an overheal stat row labelled by string %d", g_statLabelId);
  } else if (g_statRow) {
    swprintf_s(statText, L", an overheal stat row labelled '%ls'", g_statLabel.c_str());
  }
  if (!AddTechSubtype("MaxHPOnly", &ChangeMaxHpOnly)) {
    Log(L"overhealHitpointBars: no Data subtype MaxHPOnly; the bars work as before");
  }
  Log(L"overhealHitpointBars: HP bars and HP texts of units of unittype %hs take InitialHitpoints as 100 %%%ls%ls%ls "
      L"(display only)",
      names.c_str(), segmentText, statText, log ? L", the first unit of each proto logged" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
