// xsErrorLog [maxLines]: writes the XS compiler's and runtime's messages to the log.
//
// The game shows only the last message, "XS: Error 0003: could not compile file 'aiLoaderStandard.xs'",
// and the cause goes to a callback that the shipped game leaves empty: both reporters format and
// print only when [log] is set, so the text is lost. The heads of the two reporters take the same
// arguments as the stock formatter 0x435D99 needs, so the key formats them itself and leaves the stock
// code as it is:
// - FUN_0043A3A4, void cdecl(int* log, char* file, int line, char* format, ...), with 8 callers;
// - FUN_00A5667F, void cdecl(int* log, char* format, ...), which carries Error 0003.
// Neither runs in a clean game, so the key costs nothing there. Nothing here changes the game.
#include <windows.h>

#include <cstdarg>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>

#include "../features.h"
#include "../generated/sites.h"
#include "../log.h"
#include "../patch.h"

extern "C" {
void UhcXsReportHook();
void UhcXsMessageHook();
}

namespace {

constexpr std::size_t kBuffer = 0x400;
constexpr long kDefaultLines = 200;

using FormatFn = int(__cdecl*)(char* buffer, std::size_t size, const char* format, va_list args);
const auto kFormat = reinterpret_cast<FormatFn>(0x00435D99);

long g_maxLines = kDefaultLines;
volatile long g_lines = 0;

void Write(const char* file, std::int32_t line, const char* format, va_list args) {
  if (format == nullptr) {
    return;
  }
  char text[kBuffer] = {};
  kFormat(text, kBuffer, format, args);
  text[kBuffer - 1] = '\0';
  std::size_t length = std::strlen(text);
  while (length > 0 && (text[length - 1] == '\n' || text[length - 1] == '\r')) {
    text[--length] = '\0';
  }
  const long number = InterlockedIncrement(&g_lines);
  if (number > g_maxLines) {
    if (number == g_maxLines + 1) {
      uhc::Log(L"xsErrorLog: stopped at %ld lines", g_maxLines);
    }
    return;
  }
  if (file != nullptr && line > 0) {
    uhc::Log(L"xsErrorLog: %hs(%d): %hs", file, line, text);
  } else if (file != nullptr) {
    uhc::Log(L"xsErrorLog: %hs: %hs", file, text);
  } else {
    uhc::Log(L"xsErrorLog: %hs", text);
  }
}

}  // namespace

extern "C" {

// args points at the reporter's first argument.
void __stdcall UhcXsReport(void** args) {
  Write(static_cast<const char*>(args[1]), static_cast<std::int32_t>(reinterpret_cast<std::intptr_t>(args[2])),
        static_cast<const char*>(args[3]), reinterpret_cast<va_list>(args + 4));
}

void __stdcall UhcXsMessage(void** args) {
  Write(nullptr, 0, static_cast<const char*>(args[1]), reinterpret_cast<va_list>(args + 2));
}
}

namespace uhc {

Outcome ApplyXsErrorLog(const Config& config) {
  const Config::Args* args = config.First("xsErrorLog");
  if (args == nullptr) {
    return Outcome::kNotConfigured;
  }
  for (const std::string& arg : *args) {
    char* end = nullptr;
    const long lines = std::strtol(arg.c_str(), &end, 10);
    if (end == arg.c_str() || *end != '\0' || lines <= 0) {
      Log(L"xsErrorLog: unknown option %hs; feature not applied", arg.c_str());
      return Outcome::kFailed;
    }
    g_maxLines = lines;
  }
  if (!VerifyAll("xsErrorLog", {&sites::kXsReportHead, &sites::kXsMessageHead, &sites::kXsFormat}) ||
      !WriteJmp(sites::kXsReportHead.va, reinterpret_cast<const void*>(&UhcXsReportHook), 6) ||
      !WriteJmp(sites::kXsMessageHead.va, reinterpret_cast<const void*>(&UhcXsMessageHook), 6)) {
    return Outcome::kFailed;
  }
  Log(L"xsErrorLog: the XS messages go to this log, at most %ld lines", g_maxLines);
  return Outcome::kApplied;
}

}  // namespace uhc
