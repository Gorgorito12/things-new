// playerIcon <avatarId>: the player's icon in a LAN lobby. The local player's slot gets the avatar <avatarId> of the
// data's avatar_*.xml tables, in place of the civ's portrait, and keeps it when the player changes civ.
//
// Stock already has the field: each lobby slot has a string setting GamePlayer<N>AvatarID, shared through the lobby
// settings like the civ (the setter sends it to the host, which sends it to every peer). When it changes, the slot's
// handler 0x776BED (case 0x776DEA) looks it up in the avatar table loaded from data\avatar_*.xml and puts the
// record's image on the slot's icon. ESO wrote it from the online profile; in a LAN game nothing writes it, and the
// civ portrait FUN_00774D56 sets on every civ change (and AI personality change) covers it again.
//
// The two calls of FUN_00774D56 (0x776FFC, after a civ change; 0x7773DD, after an AI personality change) go through
// a hook that runs it, then, for a slot that is not an AI's:
// - if the slot is the local player's ([slot+14h], the flag that enables its own controls) and its AvatarID is not
//   the cfg's value, writes it with the stock setter 0xA26361;
// - if its AvatarID is not empty, runs the slot's handler for that field again, so the avatar goes back over the civ
//   portrait. A name that is not in the table leaves the civ portrait, as stock does.
// AI slots ([slot+1Ch]) keep the civ portrait, as the stock handler does. A peer without this key shows another
// player's avatar when it has the same avatar_*.xml entry and texture, until that player's next civ change.
#include <windows.h>

#include <cstdint>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

namespace uhc {
namespace {

// The game's string: a pointer to the characters, with its header 10h bytes before them.
struct GameString {
  wchar_t* text = nullptr;
};

using StringCtorFn = GameString*(__thiscall*)(GameString*, const wchar_t*);
using StringDtorFn = void(__thiscall*)(GameString*);
using SettingGetFn = bool(__thiscall*)(void* lobby, int id, GameString* out);
using SettingSetFn = bool(__thiscall*)(void* lobby, int id, const GameString* value);
using SlotHandlerFn = void(__thiscall*)(void* slot, void* settings, int id, int flags);

const auto kStringCtor = reinterpret_cast<StringCtorFn>(0x00401A12);
const auto kStringDtor = reinterpret_cast<StringDtorFn>(0x004010CA);
const auto kSettingGetString = reinterpret_cast<SettingGetFn>(0x00A263C7);
const auto kSettingSetString = reinterpret_cast<SettingSetFn>(0x00A26361);
const auto kSlotHandler = reinterpret_cast<SlotHandlerFn>(0x00776BED);

constexpr std::uint32_t kCivPortraitCallA = 0x00776FFC;
constexpr std::uint32_t kCivPortraitCallB = 0x007773DD;

// Slot of the lobby page: [+0Ch] the lobby settings, [+14h] the local player's slot, [+18h] its index (0..7),
// [+1Ch] an AI's slot. The lobby settings: [+8] the session, [+20h] the settings table.
// Setting ID of a player field: 3Ah + (index + 1) * 18h + field; AvatarID is field 10.
constexpr int kFieldAvatarId = 10;
constexpr int kHandlerFlags = 0x10;  // the flag the handler tests before it reads a field

std::wstring g_avatar;

std::wstring ReadString(void* lobby, int id) {
  GameString value;
  std::wstring text;
  if (kSettingGetString(lobby, id, &value) && value.text != nullptr) {
    text = value.text;
  }
  kStringDtor(&value);
  return text;
}

}  // namespace

extern "C" {

void __stdcall UhcPlayerIconAfterPortrait(std::uint8_t* slot) {
  void* const lobby = *reinterpret_cast<void**>(slot + 0x0C);
  if (lobby == nullptr || *reinterpret_cast<void**>(static_cast<std::uint8_t*>(lobby) + 8) == nullptr ||
      slot[0x1C] != 0) {
    return;
  }
  const int index = *reinterpret_cast<int*>(slot + 0x18);
  if (index < 0 || index >= 8) {
    return;
  }
  const int id = 0x3A + (index + 1) * 0x18 + kFieldAvatarId;
  std::wstring avatar = ReadString(lobby, id);
  if (slot[0x14] != 0 && avatar != g_avatar) {
    GameString value;
    kStringCtor(&value, g_avatar.c_str());
    kSettingSetString(lobby, id, &value);
    kStringDtor(&value);
    Log(L"playerIcon: player %d's AvatarID set to \"%ls\" (was \"%ls\")", index + 1, g_avatar.c_str(),
        avatar.c_str());
    avatar = g_avatar;
  }
  if (!avatar.empty()) {
    kSlotHandler(slot, *reinterpret_cast<void**>(static_cast<std::uint8_t*>(lobby) + 0x20), id, kHandlerFlags);
  }
}

void UhcPlayerIconHook();

}  // extern "C"

Outcome ApplyPlayerIcon(const Config& config) {
  const auto* args = config.First("playerIcon");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  if (args->size() != 1 || (*args)[0].empty() || (*args)[0].size() > 63) {
    Log(L"playerIcon: give one avatar ID (the id of an <avatar> in data\\avatar_*.xml), up to 63 characters");
    return Outcome::kFailed;
  }
  for (unsigned char c : (*args)[0]) {
    if (c < 0x21 || c > 0x7E) {
      Log(L"playerIcon: the avatar ID may hold only printable ASCII characters, no spaces");
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("playerIcon",
                 {&sites::kPlayerIconCallCiv, &sites::kPlayerIconCallPersonality, &sites::kPlayerIconCivPortrait,
                  &sites::kPlayerIconSlotHandler, &sites::kPlayerIconAvatarCase, &sites::kPlayerIconSettingGet,
                  &sites::kPlayerIconSettingSet, &sites::kPlayerIconStringCtor, &sites::kPlayerIconStringDtor})) {
    return Outcome::kFailed;
  }
  g_avatar.assign((*args)[0].begin(), (*args)[0].end());
  if (!WriteCall(kCivPortraitCallA, reinterpret_cast<const void*>(&UhcPlayerIconHook)) ||
      !WriteCall(kCivPortraitCallB, reinterpret_cast<const void*>(&UhcPlayerIconHook))) {
    return Outcome::kFailed;
  }
  Log(L"playerIcon: the local player's lobby icon is avatar \"%ls\"", g_avatar.c_str());
  return Outcome::kApplied;
}

}  // namespace uhc
