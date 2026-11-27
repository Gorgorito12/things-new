// A model hung on a unit, as the stock aura update does (0x9D054A..0x9D059C): the rings of unitResourceAuras
// and displayedRange, and the rank marks of veterancyBonus. A model is a visual of the unit: nothing here
// reaches the simulation.
#pragma once

#include <cstdint>

namespace uhc {

enum class ModelHang {
  kRetry,     // the unit has no visual yet
  kAlready,   // the unit has it
  kHung,      // on the unit now
  kNotInGame  // the engine took it and shows nothing: its file is not in the game
};

// Checks the sites of these functions, for the key's log.
bool VerifyUnitModels(const char* key);

// The ID of a model's path, as the tactics parser finds it (0x5FC91C); -1 before the table exists.
std::int32_t ModelOfPath(const wchar_t* path);

// The index that means "no such bone": the model's own file says where it goes.
std::int32_t NoBone();

ModelHang HangUnitModel(char* unit, std::int32_t model, std::int32_t bone);
bool UnitHasModel(const char* unit, std::int32_t model);
void RemoveUnitModel(char* unit, std::int32_t model);

// The same on a visual that has no unit, such as the placement ghost's [[0xC67300]+200h]: the three stock functions
// (0x9C04F3, 0x9C28DE, 0x9C2885) read nothing of the unit but its visual [unit+60h], so they run on a block whose
// +60h is the visual. The visual must be of a unit visual's class (the caller checks its vtable).
ModelHang HangVisualModel(char* visual, std::int32_t model, std::int32_t bone);
bool VisualHasModel(char* visual, std::int32_t model);
void RemoveVisualModel(char* visual, std::int32_t model);

}  // namespace uhc
