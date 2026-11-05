// What both builds do once they have a cfg: dllmain.cpp (the loader's UHC.dll) and engineext.cpp
// (dinput8.dll).
#pragma once

#include <string>

namespace uhc {

// The executable's folder, with a trailing backslash; empty if it cannot be read.
std::wstring ExeFolder();

// Makes the exe's folder the working directory, loads the cfg at `path` and applies every feature.
void ApplyFeatures(const std::wstring& path);

}  // namespace uhc
