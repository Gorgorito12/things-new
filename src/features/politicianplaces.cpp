// politicianPlacesFix: the European age-up dialog shows only as many politicians as its layout has places, instead of
// crashing on the first politician that has no place.
//
// The dialog binds five places by name when it is built (0x818C5B..0x818DBD, loop to 5 at 0x818DBA): for place n,
// PoliticianDlg-Politician%d at [dlg+198h+4n], PoliticianButton%d at +1ACh, Poli%dPortrait at +1C0h,
// PoliticianHilightPositive%d at +1D4h, Poli%dName at +1E8h, Poli%dCost at +1FCh and Poli%dDescription at +210h, each a
// gadget handle that resolves to nothing when the layout file lacks that name. The European list builder FUN_0081A2B8
// keeps up to five politicians of the next age ([dlg+26Ch], cmp with 5 at 0x81A82A) and fills place n for the n-th:
// it null-checks the portrait, the name and the description, then dereferences the name gadget (EBP) without a check,
// mov eax,[ebp] at 0x81A80C (and at 0x81A63C on the revolution path). With a layout of four places, as the
// stock uipoliticianEuropeandlg.xml, a fifth obtainable politician is an access violation there.
//
// One hook (hooks/politicianplaces_hooks.asm) at 0x81A45A, where an accepted politician is about to take the next
// place: when the place has no PoliticianDlg-Politician%d gadget or no Poli%dName text gadget, the builder ends as it
// does after the fifth (0x81A848), so the dialog lists the politicians it can show. The other builders null-check every
// gadget (FUN_00818EE5) or place their entries by a fixed index of their own data (the Asian and native dialogs).
// UI only: the dialog is the local player's, and the politician chosen is sent as the stock command.
#include <cstdint>
#include <cstdlib>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" void UhcPoliticianPlacesHook();

namespace {

// The UI manager's gadget by handle and type (0 any, 10h text), null when there is none; no reference is taken.
using GadgetLookup = void*(__fastcall*)(void* manager, void* edx, std::int32_t handle, std::int32_t type);
const auto kGadgetLookup = reinterpret_cast<GadgetLookup>(0x0040423C);

constexpr std::int32_t kAnyGadget = 0;
constexpr std::int32_t kTextGadget = 0x10;
constexpr int kStockPlaces = 5;

bool g_log = false;
bool g_logged = false;

bool HasGadget(void* manager, std::int32_t handle, std::int32_t type) {
  return kGadgetLookup(manager, nullptr, handle, type) != nullptr;
}

// The leading places that have both the place panel and its name text.
int PlaceCount(const char* dlg) {
  const char* ui = *reinterpret_cast<const char* const*>(0x00C66244);
  void* manager = ui == nullptr ? nullptr : *reinterpret_cast<void* const*>(ui + 0x44);
  if (manager == nullptr) {
    return 0;
  }
  int places = 0;
  for (; places < kStockPlaces; ++places) {
    const std::int32_t panel = *reinterpret_cast<const std::int32_t*>(dlg + 0x198 + 4 * places);
    const std::int32_t name = *reinterpret_cast<const std::int32_t*>(dlg + 0x1E8 + 4 * places);
    if (!HasGadget(manager, panel, kAnyGadget) || !HasGadget(manager, name, kTextGadget)) {
      break;
    }
  }
  return places;
}

std::int32_t TechId(const char* techStatus) {
  const char* tech = techStatus == nullptr ? nullptr : *reinterpret_cast<const char* const*>(techStatus);
  return tech == nullptr ? -1 : *reinterpret_cast<const std::int32_t*>(tech);
}

}  // namespace

// From the hook, for each politician the builder accepts, before it takes the next place. True: no place is left, so
// the builder ends with the politicians it has.
extern "C" bool __stdcall UhcPoliticianNoPlace(const char* dlg, const char* techStatus) {
  const std::int32_t count = *reinterpret_cast<const std::int32_t*>(dlg + 0x26C);
  const int places = PlaceCount(dlg);
  if (count < places) {
    return false;
  }
  if (!g_logged || g_log) {
    g_logged = true;
    uhc::Log(L"politicianPlacesFix: the European age-up dialog has %d place(s); politician tech %d and any after it "
             L"are left out (%ls)",
             places, TechId(techStatus),
             *reinterpret_cast<const std::uint8_t*>(dlg + 0x144) != 0 ? L"revolutions" : L"age-up");
  }
  return true;
}

namespace uhc {

Outcome ApplyPoliticianPlacesFix(const Config& config) {
  const Config::Args* args = config.First("politicianPlacesFix");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    if (_stricmp(arg.c_str(), "log") != 0) {
      Log(L"politicianPlacesFix: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_log = true;
  }
  if (!VerifyAll("politicianPlacesFix", {&sites::kPoliticianPlaceTake, &sites::kPoliticianListEnd,
                                         &sites::kPoliticianPanelBind, &sites::kPoliticianNameBind,
                                         &sites::kPoliticianNameRead, &sites::kTechStatusTechId,
                                         &sites::kGadgetLookup}) ||
      !WriteJmp(sites::kPoliticianPlaceTake.va, reinterpret_cast<const void*>(&UhcPoliticianPlacesHook), 7)) {
    return Outcome::kFailed;
  }
  Log(L"politicianPlacesFix: the European age-up dialog lists only the politicians its layout has places for");
  return Outcome::kApplied;
}

}  // namespace uhc
