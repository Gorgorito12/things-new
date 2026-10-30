// uhc.cfg reader. The format is one key per line followed by whitespace-separated arguments;
// blank lines and lines starting with '#' are ignored. Keys are case-insensitive. The UHC
// patcher's syntax is accepted too, since it writes it: key=value, and "//" comments anywhere.
#pragma once

#include <map>
#include <optional>
#include <string>
#include <vector>

namespace uhc {

class Config {
 public:
  using Args = std::vector<std::string>;

  // Returns false if the file could not be read; an empty file is a valid, empty config.
  bool Load(const std::wstring& path);

  bool Has(const std::string& key) const;
  // Arguments of the first line with this key, or nullptr.
  const Args* First(const std::string& key) const;
  // Every line with this key, in file order.
  const std::vector<Args>* All(const std::string& key) const;
  // The first argument parsed as a decimal int; nullopt if the key is absent or malformed.
  std::optional<int> Int(const std::string& key) const;

  const std::map<std::string, std::vector<Args>>& entries() const { return entries_; }

 private:
  std::map<std::string, std::vector<Args>> entries_;  // keys are lowercase
};

}  // namespace uhc
