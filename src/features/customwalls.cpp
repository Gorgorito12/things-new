// customWalls: a proto that builds like a wall (stock flag WallBuild) lays its own pieces between the clicked
// points, named by tags in its <Unit>, instead of the civ's stone wall.
//
// The wall layout 0x9F66D9 (thiscall(store, player, points, count, -1)) splits each stretch between two clicked
// points into posts and straight pieces. It takes four protos: the connector (the post), the 5-long and 2-long
// straights and the gate (the last only to join an existing gate). They come from the player's civ, the
// civs.xml tags <wall type="Connector|Straight2|Straight5|Gate">proto</wall> (the parser at 0x65A354 keeps
// the names at [civ+1CCh..1E0h], resolved to IDs at [civ+1E4h..1F8h]), or, for a civ without them, from the
// names "WallConnector", "WallStraight5", "WallStraight2" and "CWallGate". So any WallBuild proto enters the
// wall mode (0x7E4762, flag 3Ah), but every one of them lays the civ's stone wall.
//
// The hook (hooks/customwalls_hooks.asm, at 0x9F677A, after the civ lookup) asks UhcCustomWallPieces. When
// the layout was called by the UI, the drag preview (returns to 0x665A01) or the click that orders the wall
// (0x847E11), and the proto on the cursor ([[game+91Ch]+4A4h], the one uiBuildWallAtPointer builds) has
// <WallPiece> tags, the pieces are those. The order the click sends is one build order per piece with its proto,
// so the other machines in a game receive the pieces and need nothing. The AI's walls (0x9F71A5) and the
// layout's third caller (0x741299) keep the civ's pieces.
//
// A second hook (0x508DD4) lets the post of a custom wall stand on a post of the same proto that its owner
// already has, as the stock test does only for "WallConnector": a new wall can start at the end of another.
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <unordered_map>
#include <vector>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"
#include "../prototags.h"

extern "C" void UhcCustomWallLayoutHook();
extern "C" void UhcCustomWallPostHook();

namespace {

constexpr std::uintptr_t kGameGlobal = 0x00C66234;
constexpr std::size_t kGameWorldUi = 0x91C;
constexpr std::size_t kUiCursorProto = 0x4A4;
constexpr std::uint32_t kPreviewReturn = 0x00665A01;
constexpr std::uint32_t kOrderReturn = 0x00847E11;
constexpr int kMaxLogLines = 200;

using PlayerProtoFn = char*(__thiscall*)(const char* player, std::int32_t id);
using PlayerProtoByNameFn = char*(__thiscall*)(const char* player, const char* name);
using XmlAttributeFn = bool(__thiscall*)(const void* node, const char* name, const void** out);
using XmlTextFn = const char*(__thiscall*)(const void* text);
const auto kPlayerProto = reinterpret_cast<PlayerProtoFn>(0x0045311B);
const auto kPlayerProtoByName = reinterpret_cast<PlayerProtoByNameFn>(0x008D1998);
const auto kXmlAttribute = reinterpret_cast<XmlAttributeFn>(0x00598F37);
const auto kXmlText = reinterpret_cast<XmlTextFn>(0x00402733);

enum Piece { kStraight5, kStraight2, kGate, kPieces };

// The names a connector's tags give; an ID of -2 is not looked up yet, -1 not found.
struct WallSet {
  std::string names[kPieces];
  std::int32_t ids[kPieces] = {-2, -2, -2};
  bool warned = false;
};

std::unordered_map<std::int32_t, WallSet> g_sets;  // by the connector's proto ID; filled while protos load
bool g_log = false;
int g_logLines = 0;

template <typename T>
T Field(const char* base, std::size_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

const char* ProtoName(const char* proto) {
  const char* name = proto == nullptr ? nullptr : Field<const char*>(proto, 0x10);
  return name == nullptr ? "?" : name;
}

bool LogLine() { return g_log && g_logLines++ < kMaxLogLines; }

// <WallPiece type="Straight5|Straight2|Gate">proto</WallPiece>; without type, both straights.
bool __cdecl ReadWallPiece(void*, const char* node, char* proto) {
  const char* text = kXmlText(node + 0x14);
  if (text == nullptr || *text == '\0') {
    return true;
  }
  const char* type = nullptr;
  const void* value = nullptr;
  if (kXmlAttribute(node, "type", &value) && value != nullptr) {
    type = kXmlText(value);
  }
  const std::int32_t id = Field<std::int32_t>(proto, 8);
  WallSet& set = g_sets[id];
  if (type == nullptr || *type == '\0') {
    set.names[kStraight5] = text;
    set.names[kStraight2] = text;
  } else if (_stricmp(type, "Straight5") == 0) {
    set.names[kStraight5] = text;
  } else if (_stricmp(type, "Straight2") == 0) {
    set.names[kStraight2] = text;
  } else if (_stricmp(type, "Gate") == 0) {
    set.names[kGate] = text;
  } else {
    uhc::Log(L"customWalls: proto %hs: unknown WallPiece type %hs (Straight5, Straight2 or Gate)", ProtoName(proto), type);
  }
  if (g_log) {
    uhc::Log(L"customWalls: proto %d (%hs) WallPiece %hs = %hs", id, ProtoName(proto), type == nullptr ? "(both straights)" : type,
             text);
  }
  return true;
}

// A missing straight takes the other; a missing gate takes the 5-long straight (the gate only lets a wall join
// an existing gate).
void FillGaps(WallSet& set) {
  if (set.names[kStraight5].empty()) {
    set.names[kStraight5] = set.names[kStraight2];
  }
  if (set.names[kStraight2].empty()) {
    set.names[kStraight2] = set.names[kStraight5];
  }
  if (set.names[kGate].empty()) {
    set.names[kGate] = set.names[kStraight5];
  }
}

// The IDs are the same for every player: the player's copies come from them.
bool Resolve(const char* player, std::int32_t connector, WallSet& set) {
  if (set.ids[0] == -2) {
    FillGaps(set);
    for (int i = 0; i < kPieces; ++i) {
      const char* proto = set.names[i].empty() ? nullptr : kPlayerProtoByName(player, set.names[i].c_str());
      set.ids[i] = proto == nullptr ? -1 : Field<std::int32_t>(proto, 8);
    }
  }
  for (int i = 0; i < kPieces; ++i) {
    if (set.ids[i] < 0) {
      if (!set.warned) {
        set.warned = true;
        uhc::Log(L"customWalls: proto %d: no proto named \"%hs\"; its walls stay the civ's", connector, set.names[i].c_str());
      }
      return false;
    }
  }
  return true;
}

}  // namespace

// From the layout hook. Fills pieces[0..3] (connector, 5-long straight, 2-long straight, gate, the player's
// copies) and returns true when the UI lays a wall of a proto with <WallPiece> tags.
extern "C" bool __stdcall UhcCustomWallPieces(const char* player, std::uint32_t caller, char** pieces) {
  if (player == nullptr || (caller != kPreviewReturn && caller != kOrderReturn)) {
    return false;
  }
  const char* game = *reinterpret_cast<const char* const*>(kGameGlobal);
  const char* ui = game == nullptr ? nullptr : Field<const char*>(game, kGameWorldUi);
  if (ui == nullptr) {
    return false;
  }
  const std::int32_t cursor = Field<std::int32_t>(ui, kUiCursorProto);
  const auto found = g_sets.find(cursor);
  if (found == g_sets.end()) {
    if (caller == kOrderReturn && LogLine()) {
      const char* proto = cursor < 0 ? nullptr : kPlayerProto(player, cursor);
      uhc::Log(L"customWalls: player %d orders a wall of proto %d (%hs), no WallPiece tags: the civ's pieces",
               Field<std::int32_t>(player, 0), cursor, ProtoName(proto));
    }
    return false;
  }
  if (!Resolve(player, cursor, found->second)) {
    return false;
  }
  const WallSet& set = found->second;
  pieces[0] = kPlayerProto(player, cursor);
  pieces[1] = kPlayerProto(player, set.ids[kStraight5]);
  pieces[2] = kPlayerProto(player, set.ids[kStraight2]);
  pieces[3] = kPlayerProto(player, set.ids[kGate]);
  for (int i = 0; i < 4; ++i) {
    if (pieces[i] == nullptr) {
      return false;
    }
  }
  if (caller == kOrderReturn && LogLine()) {
    uhc::Log(L"customWalls: player %d orders a wall of %hs: straights %hs / %hs, gate %hs", Field<std::int32_t>(player, 0),
             ProtoName(pieces[0]), ProtoName(pieces[1]), ProtoName(pieces[2]), ProtoName(pieces[3]));
  }
  return true;
}

// From the overlap hook: true for the connector of a custom wall.
extern "C" bool __stdcall UhcCustomWallPost(const char* proto) {
  return proto != nullptr && g_sets.count(Field<std::int32_t>(proto, 8)) != 0;
}

namespace uhc {

Outcome ApplyCustomWalls(const Config& config) {
  const Config::Args* args = config.First("customWalls");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"customWalls: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("customWalls", {&sites::kWallLayoutCivPieces, &sites::kWallLayoutPiecesMerge, &sites::kWallLayoutStockNames,
                                 &sites::kWallLayoutPreviewReturn, &sites::kWallLayoutOrderReturn, &sites::kWallPostOverlap,
                                 &sites::kPlayerProtoByName, &sites::kPlayerProtoEntry, &sites::kXmlAttribute,
                                 &sites::kXmlText}) ||
      !AddProtoTagHandler("WallPiece", &ReadWallPiece) ||
      !WriteJmp(sites::kWallLayoutCivPieces.va, reinterpret_cast<const void*>(&UhcCustomWallLayoutHook), 6) ||
      !WriteJmp(sites::kWallPostOverlap.va, reinterpret_cast<const void*>(&UhcCustomWallPostHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"customWalls: a WallBuild proto with <WallPiece> tags lays its own wall pieces");
  return Outcome::kApplied;
}

}  // namespace uhc
