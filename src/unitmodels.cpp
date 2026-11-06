#include "unitmodels.h"

#include "generated/sites.h"
#include "patch.h"

namespace {

constexpr std::uint32_t kModelTable = 0x00C66240;
constexpr std::uint32_t kBoneTable = 0x00D6F478;

using ModelIdFn = std::int32_t(__thiscall*)(void* table, const wchar_t* path, std::int32_t a, std::int32_t b, std::int32_t c);
using BoneIdFn = std::int32_t(__thiscall*)(void* table, const char* name);
using ModelByIdFn = const void*(__thiscall*)(void* table, std::int32_t model);
using HasModelFn = bool(__thiscall*)(const char* unit, std::int32_t model);
using AttachModelFn = bool(__thiscall*)(char* unit, const void* object, std::int32_t bone, std::int32_t flag);
using RemoveModelFn = void(__thiscall*)(char* unit, std::int32_t model);

const auto kModelId = reinterpret_cast<ModelIdFn>(0x0058F68F);
const auto kBoneId = reinterpret_cast<BoneIdFn>(0x0058E506);
const auto kModelById = reinterpret_cast<ModelByIdFn>(0x00405E83);
const auto kHasModel = reinterpret_cast<HasModelFn>(0x009C28DE);
const auto kAttachModel = reinterpret_cast<AttachModelFn>(0x009C04F3);
const auto kRemoveModel = reinterpret_cast<RemoveModelFn>(0x009C2885);

}  // namespace

namespace uhc {

bool VerifyUnitModels(const char* key) {
  return VerifyAll(key, {&sites::kModelById, &sites::kUnitHasModel, &sites::kUnitAttachModel, &sites::kUnitRemoveModel,
                         &sites::kModelPathLookup, &sites::kBoneNameLookup});
}

std::int32_t ModelOfPath(const wchar_t* path) {
  void* table = *reinterpret_cast<void**>(kModelTable);
  return table == nullptr ? -1 : kModelId(table, path, 1, 0, 0);
}

std::int32_t NoBone() { return kBoneId(reinterpret_cast<void*>(kBoneTable), "bonethatdoesntexist"); }

ModelHang HangUnitModel(char* unit, std::int32_t model, std::int32_t bone) {
  void* table = *reinterpret_cast<void**>(kModelTable);
  if (unit == nullptr || table == nullptr) {
    return ModelHang::kRetry;
  }
  if (kHasModel(unit, model)) {
    return ModelHang::kAlready;
  }
  const void* object = kModelById(table, model);
  if (object == nullptr || !kAttachModel(unit, object, bone, 0)) {
    return ModelHang::kRetry;
  }
  return kHasModel(unit, model) ? ModelHang::kHung : ModelHang::kNotInGame;
}

bool UnitHasModel(const char* unit, std::int32_t model) { return kHasModel(unit, model); }

void RemoveUnitModel(char* unit, std::int32_t model) { kRemoveModel(unit, model); }

}  // namespace uhc
