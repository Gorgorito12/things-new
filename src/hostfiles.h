// The files of this build, which differ between the loader's UHC.dll (dllmain.cpp) and the dinput8.dll
// that runs beside another DLL (engineext.cpp). Both paths are relative to the exe's folder.
#pragma once

namespace uhc {

extern const wchar_t kLogFile[];    // the log
extern const wchar_t kDataFolder[];  // the default folder of the keys' data files, with a final backslash

}  // namespace uhc
