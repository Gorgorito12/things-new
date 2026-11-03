cmake_minimum_required(VERSION 3.25)
# The version is shown in UHC.log and in the file's properties; bump it for every release
# (docs/developer-guide.md, "Making a release").
project(UHC VERSION 0.1.0 LANGUAGES CXX ASM_MASM)

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
  src/floatingtext.cpp
  src/log.cpp
  src/patch.cpp
  src/unittypes.cpp
  src/worldtick.cpp
  src/actiontags.cpp
  src/features/abilityslots.cpp
  src/features/abstracttypes.cpp
  src/features/ai.cpp
  src/features/broadside.cpp
  src/features/bwrauras.cpp
  src/features/civfirsttc.cpp
  src/features/damageovertime.cpp
  src/features/dance.cpp
  src/features/decimalpop.cpp
  src/features/dodge.cpp
  src/features/dopples.cpp
  src/features/fame.cpp
  src/features/fileio.cpp
  src/features/gatherrate.cpp
  src/features/heal.cpp
  src/features/hotkeys.cpp
  src/features/instances.cpp
  src/features/lifespan.cpp
  src/features/limits.cpp
  src/features/maintain.cpp
  src/features/misc.cpp
  src/features/notrainneartc.cpp
  src/features/overheal.cpp
  src/features/overhealdecay.cpp
  src/features/overhealsources.cpp
  src/features/perf.cpp
  src/features/shipments.cpp
  src/features/smartheal.cpp
  src/features/snare.cpp
  src/features/sockets.cpp
  src/features/spread.cpp
  src/features/startingtc.cpp
  src/features/techprereq.cpp
  src/features/techrename.cpp
  src/features/transform.cpp
  src/features/transforminv.cpp
  src/features/wonderpanel.cpp
  src/features/workrate.cpp
  src/hooks/abilityslot_hooks.asm
  src/hooks/actiontag_hooks.asm
  src/hooks/ai_hooks.asm
  src/hooks/broadside_hooks.asm
  src/hooks/bwraura_hooks.asm
  src/hooks/civfirsttc_hooks.asm
  src/hooks/dance_hooks.asm
  src/hooks/decimalpop_hooks.asm
  src/hooks/dodge_hooks.asm
  src/hooks/dopple_hooks.asm
  src/hooks/dot_hooks.asm
  src/hooks/fame_hooks.asm
  src/hooks/gatherrate_hooks.asm
  src/hooks/heal_hooks.asm
  src/hooks/hotkey_hooks.asm
  src/hooks/lifespan_hooks.asm
  src/hooks/limit_hooks.asm
  src/hooks/maintain_hooks.asm
  src/hooks/misc_hooks.asm
  src/hooks/notrainneartc_hooks.asm
  src/hooks/overheal_hooks.asm
  src/hooks/overhealsources_hooks.asm
  src/hooks/shipment_hooks.asm
  src/hooks/smartheal_hooks.asm
  src/hooks/snare_hooks.asm
  src/hooks/socket_hooks.asm
  src/hooks/spread_hooks.asm
  src/hooks/startingtc_hooks.asm
  src/hooks/techprereq_hooks.asm
  src/hooks/techrename_hooks.asm
  src/hooks/transform_hooks.asm
  src/hooks/transforminv_hooks.asm
  src/hooks/unittype_hooks.asm
  src/hooks/wonderpanel_hooks.asm
  src/hooks/workrate_hooks.asm
  src/hooks/worldtick_hooks.asm
  src/version.rc
)
target_compile_definitions(UHC PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX UNICODE _UNICODE)
# version.h (from src/version.h.in) carries the project version to dllmain.cpp and version.rc.
configure_file(src/version.h.in ${CMAKE_CURRENT_BINARY_DIR}/generated/version.h @ONLY)
target_include_directories(UHC PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/generated)
# For `include common.inc` in the hook files.
target_include_directories(UHC PRIVATE src/hooks)
target_compile_options(UHC PRIVATE
  $<$<COMPILE_LANGUAGE:CXX>:/W4 /permissive->
  # x86 images link with /SAFESEH; MASM objects must declare their (empty) handler table.
  $<$<COMPILE_LANGUAGE:ASM_MASM>:/safeseh>
)
set_target_properties(UHC PROPERTIES OUTPUT_NAME UHC)
