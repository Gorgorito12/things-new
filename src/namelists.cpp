#include "namelists.h"

#include "log.h"

namespace uhc {
namespace {

constexpr std::uint32_t kGameGlobal = 0x00C66234;  // game; +140h database

// int thiscall(database, const char* name): the civ's ID (its index in [database+24h]), or -1.
using CivIdByNameFn = std::int32_t(__thiscall*)(char* database, const char* name);
const auto kCivIdByName = reinterpret_cast<CivIdByNameFn>(0x0058E71F);

// int thiscall(database, const char* name): the proto's ID, or -1.
using ProtoIdByNameFn = std::int32_t(__thiscall*)(char* database, const char* name);
const auto kProtoIdByName = reinterpret_cast<ProtoIdByNameFn>(0x005A2346);

template <typename T>
T Field(const char* base, std::uint32_t offset) {
  return *reinterpret_cast<const T*>(base + offset);
}

}  // namespace

void CivIdList::Set(const char* feature, std::vector<std::string> names) {
  feature_ = feature;
  names_ = std::move(names);
  database_ = nullptr;
  count_ = -1;
}

void CivIdList::Resolve(char* database, std::int32_t count) {
  database_ = database;
  count_ = count;
  index_.assign(static_cast<std::size_t>(count), -1);
  for (std::size_t i = 0; i < names_.size(); ++i) {
    const std::int32_t id = kCivIdByName(database, names_[i].c_str());
    if (id < 0 || id >= count) {
      Log(L"%hs: %hs is not a civ in civs.xml; ignored", feature_, names_[i].c_str());
      continue;
    }
    if (index_[static_cast<std::size_t>(id)] < 0) {
      index_[static_cast<std::size_t>(id)] = static_cast<int>(i);
    }
    Log(L"%hs: %hs -> civ %d", feature_, names_[i].c_str(), id);
  }
}

int CivIdList::IndexOf(std::int32_t civ) {
  if (civ < 0 || names_.empty()) {
    return -1;
  }
  char* game = *reinterpret_cast<char**>(kGameGlobal);
  char* database = game == nullptr ? nullptr : Field<char*>(game, 0x140);
  if (database == nullptr) {
    return -1;
  }
  const std::int32_t count = Field<std::int32_t>(database, 0x28);
  if (count <= 0) {
    return -1;  // civs.xml not read yet
  }
  if (database != database_ || count != count_) {
    Resolve(database, count);
  }
  return civ < count ? index_[static_cast<std::size_t>(civ)] : -1;
}

void ProtoIdList::Set(const char* feature, std::vector<std::string> names) {
  feature_ = feature;
  names_ = std::move(names);
  database_ = nullptr;
  count_ = -1;
}

// Protos: [database+54h] array, [database+58h] count.
bool ProtoIdList::Refresh() {
  char* game = *reinterpret_cast<char**>(kGameGlobal);
  char* database = game == nullptr ? nullptr : Field<char*>(game, 0x140);
  if (database == nullptr) {
    return false;
  }
  const std::int32_t count = Field<std::int32_t>(database, 0x58);
  if (count <= 0) {
    return false;  // protoy.xml not read yet
  }
  if (database == database_ && count == count_) {
    return true;
  }
  database_ = database;
  count_ = count;
  ids_.clear();
  idOfName_.assign(names_.size(), -1);
  for (std::size_t i = 0; i < names_.size(); ++i) {
    const std::int32_t id = kProtoIdByName(database, names_[i].c_str());
    if (id < 0 || id >= count) {
      Log(L"%hs: %hs is not a proto in protoy.xml; ignored", feature_, names_[i].c_str());
      continue;
    }
    idOfName_[i] = id;
    ids_.push_back(id);
  }
  Log(L"%hs: %zu of %zu protos found in the data", feature_, ids_.size(), names_.size());
  return true;
}

const std::vector<std::int32_t>& ProtoIdList::Ids() {
  static const std::vector<std::int32_t> kNone;
  return Refresh() ? ids_ : kNone;
}

int ProtoIdList::IndexOf(std::int32_t proto) {
  if (proto < 0 || !Refresh()) {
    return -1;
  }
  for (std::size_t i = 0; i < idOfName_.size(); ++i) {
    if (idOfName_[i] == proto) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

std::int32_t FirstCivOfPlayer(const char* player) {
  if (player == nullptr || Field<std::int32_t>(player, 0x24) <= 0) {
    return -1;
  }
  return *Field<const std::int32_t*>(player, 0x20);
}

}  // namespace uhc
