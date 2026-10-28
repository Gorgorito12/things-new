cmake_minimum_required(VERSION 3.25)
project(UHC LANGUAGES CXX ASM_MASM)

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
  message(FATAL_ERROR "age3y.exe is 32-bit: configure with -A Win32")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# Static CRT so the DLL drops into a game folder without a VC++ redistributable.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_library(UHC SHARED
  src/dllmain.cpp
  src/config.cpp
  src/log.cpp
  src/patch.cpp
  src/unittypes.cpp
  src/features/ai.cpp
  src/features/fame.cpp
  src/features/heal.cpp
  src/features/limits.cpp
  src/features/misc.cpp
  src/features/shipments.cpp
  src/hooks/ai_hooks.asm
  src/hooks/fame_hooks.asm
  src/hooks/heal_hooks.asm
  src/hooks/limit_hooks.asm
  src/hooks/misc_hooks.asm
  src/hooks/shipment_hooks.asm
  src/hooks/unittype_hooks.asm
)
target_compile_definitions(UHC PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX UNICODE _UNICODE)
# For `include common.inc` in the hook files.
target_include_directories(UHC PRIVATE src/hooks)
target_compile_options(UHC PRIVATE
  $<$<COMPILE_LANGUAGE:CXX>:/W4 /permissive->
  # x86 images link with /SAFESEH; MASM objects must declare their (empty) handler table.
  $<$<COMPILE_LANGUAGE:ASM_MASM>:/safeseh>
)
set_target_properties(UHC PROPERTIES OUTPUT_NAME UHC)
