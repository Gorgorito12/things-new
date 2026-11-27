// dmgPartBoneFix [log]: a damage template's "part" names a bone (bone_debris_2q, oak a death) that the part
// declaration FUN_004F0187 looks up in the global bone name table 0xD6F478 (0x58E506), then in the model's own
// map from that table to its skeleton (0x4F010C). A model loaded before the name was in the table has no entry
// for it, so the game writes "Invalid bone name ... in part declaration for model ..." (0xC0B878) and, when the
// name was new to the table (BL, set where 0x59C213 added it), loads the model again so its map includes the
// name: the loader's call 0x658C35 on the loaded cache entry unloads its Granny file first (0x46E7ED) while
// units still draw it, and the game can crash in its next draw (#78). When the name was already in the table
// (BL clear) the game skips that reload and keeps the part, which then matches no bone of that model.
//
// The key takes that second path every time: `je 658C3Ah` at 0x658C1A becomes a jmp (1 byte), so no model is
// reloaded for a part; the part of that model is left without its bone, as the stock game leaves every later
// model that meets the same name. With `log`, a hook at 0x658C18 instead writes the bone and the model each
// time a reload is skipped (once per bone name in a session, the times BL is set) and then takes the same jmp.
#include <cstdint>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcPartBoneReloadHook();

namespace {

// A game string pointer: UTF-16 (its second byte 0 for an ASCII first character), else ANSI; null as "".
std::wstring GameText(const void* text) {
  if (text == nullptr) {
    return L"";
  }
  const auto* bytes = static_cast<const unsigned char*>(text);
  std::wstring out;
  if (bytes[0] != 0 && bytes[1] == 0) {
    for (const auto* w = static_cast<const wchar_t*>(text); *w != 0 && out.size() < 260; ++w) {
      out += *w;
    }
  } else {
    for (const auto* c = static_cast<const char*>(text); *c != 0 && out.size() < 260; ++c) {
      out += static_cast<wchar_t>(static_cast<unsigned char>(*c));
    }
  }
  return out;
}

unsigned g_skipped = 0;

}  // namespace

// Called by the hook when BL is set: model = the cache entry's file name [edi+4], bone = the part's bone
// attribute ([[esp+44h]+4] at the site).
extern "C" void __stdcall UhcPartBoneReloadSkipped(const void* model, const void* bone) {
  ++g_skipped;
  uhc::Log(L"dmgPartBoneFix: bone \"%ls\" of a damage part is not in model \"%ls\": reload skipped, the part has "
           L"no bone in that model (%u so far)", GameText(bone).c_str(), GameText(model).c_str(), g_skipped);
}

namespace uhc {

Outcome ApplyDmgPartBoneFix(const Config& config) {
  const Config::Args* args = config.First("dmgPartBoneFix");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  bool log = false;
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") == 0) {
      log = true;
    } else {
      Log(L"dmgPartBoneFix: unknown argument '%hs' (expected log); not applied", arg.c_str());
      return Outcome::kFailed;
    }
  }
  if (!VerifyAll("dmgPartBoneFix", {&sites::kPartBoneReload})) {
    return Outcome::kFailed;
  }
  if (log) {
    // 5 bytes over test bl,bl / je / the first byte of the next mov; the hook always leaves to 0x658C3A.
    if (!WriteJmp(sites::kPartBoneReload.va, reinterpret_cast<const void*>(&UhcPartBoneReloadHook), 5)) {
      return Outcome::kFailed;
    }
  } else {
    const std::uint8_t jmpShort = 0xEB;  // je 658C3Ah -> jmp 658C3Ah
    if (!WriteBytes(sites::kPartBoneReload.va + 2, &jmpShort, 1)) {
      return Outcome::kFailed;
    }
  }
  Log(L"dmgPartBoneFix: a damage part whose bone a model lacks no longer reloads the model%ls",
      log ? L" (each skipped reload logged)" : L"");
  return Outcome::kApplied;
}

}  // namespace uhc
