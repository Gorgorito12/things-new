// Name lists from uhc.cfg resolved against the game data, lazily. civs.xml is read again with the
// rest of the data when a skirmish starts, so a list is resolved on first use and again whenever
// the database or its civ count changes. Called on the game's main thread only.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace uhc {

class CivIdList {
 public:
  // `feature` names the key in the log lines.
  void Set(const char* feature, std::vector<std::string> names);
  bool empty() const { return names_.empty(); }
  const std::vector<std::string>& names() const { return names_; }

  // The position in the cfg list of the civ with this ID, or -1 (also before civs.xml is read).
  int IndexOf(std::int32_t civ);

 private:
  void Resolve(char* database, std::int32_t count);

  const char* feature_ = "";
  std::vector<std::string> names_;
  std::vector<int> index_;  // civ ID -> position in names_, or -1
  const char* database_ = nullptr;
  std::int32_t count_ = -1;
};

class ProtoIdList {
 public:
  void Set(const char* feature, std::vector<std::string> names);
  bool empty() const { return names_.empty(); }
  // The proto IDs of the names that exist in the current data (empty before it is read).
  const std::vector<std::int32_t>& Ids();
  // The position in the cfg list of the proto with this ID, or -1.
  int IndexOf(std::int32_t proto);

 private:
  bool Refresh();

  const char* feature_ = "";
  std::vector<std::string> names_;
  std::vector<std::int32_t> ids_;       // resolved IDs, in cfg order, unknown names left out
  std::vector<std::int32_t> idOfName_;  // per cfg name, -1 if unknown
  const char* database_ = nullptr;
  std::int32_t count_ = -1;
};

// The first civ ID of a player object ([player+20h] list, [player+24h] count), or -1.
std::int32_t FirstCivOfPlayer(const char* player);

}  // namespace uhc
