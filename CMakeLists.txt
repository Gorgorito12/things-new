cmake_minimum_required(VERSION 3.25)
# The version is shown in UHC.log and in the file's properties; bump it for every release
# (docs/developer-guide.md, "Making a release").
project(UHC VERSION 0.4.0 LANGUAGES CXX ASM_MASM)

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
  message(FATAL_ERROR "age3y.exe is 32-bit: configure with -A Win32")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# Static CRT so the DLL drops into a game folder without a VC++ redistributable.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

set(UHC_SOURCES
  src/config.cpp
  src/startup.cpp
  src/floatingtext.cpp
  src/log.cpp
  src/patch.cpp
  src/namelists.cpp
  src/syscalls.cpp
  src/unittypes.cpp
  src/xmllist.cpp
  src/worldtick.cpp
  src/researchpay.cpp
  src/deathobservers.cpp
  src/unitpanel.cpp
  src/unitmodels.cpp
  src/actiontags.cpp
  src/modifytypes.cpp
  src/transformcalls.cpp
  src/prototags.cpp
  src/civtags.cpp
  src/techsubtypes.cpp
  src/d3d9hooks.cpp
  src/menuoptions.cpp
  src/features/abilityslots.cpp
  src/features/abstracttypes.cpp
  src/features/accuracy.cpp
  src/features/ai.cpp
  src/features/bounty.cpp
  src/features/broadside.cpp
  src/features/bwrauras.cpp
  src/features/costescalation.cpp
  src/features/unittypetechs.cpp
  src/features/detonation.cpp
  src/features/annexfacing.cpp
  src/features/hctargets.cpp
  src/features/cratepriority.cpp
  src/features/donotqueue.cpp
  src/features/freeresearch.cpp
  src/features/researchgrants.cpp
  src/features/cantslow.cpp
  src/features/stealthtarget.cpp
  src/features/snarevalues.cpp
  src/features/civfirsttc.cpp
  src/features/datalint.cpp
  src/features/displayrange.cpp
  src/features/linkedresource.cpp
  src/features/xslog.cpp
  src/features/civs.cpp
  src/features/damageovertime.cpp
  src/features/dance.cpp
  src/features/decimalpop.cpp
  src/features/dodge.cpp
  src/features/dopples.cpp
  src/features/fame.cpp
  src/features/farms.cpp
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
  src/features/steadybars.cpp
  src/features/plugins.cpp
  src/features/perf.cpp
  src/features/vertexfill.cpp
  src/features/lastinline.cpp
  src/features/renderer.cpp
  src/features/selection.cpp
  src/features/sharedlimit.cpp
  src/features/shipments.cpp
  src/features/smartheal.cpp
  src/features/snare.cpp
  src/features/sockets.cpp
  src/features/nativepreview.cpp
  src/features/spread.cpp
  src/features/startingtc.cpp
  src/features/techprereq.cpp
  src/features/teams.cpp
  src/features/techrename.cpp
  src/features/pillage.cpp
  src/features/aurastacking.cpp
  src/features/trainbatch.cpp
  src/features/transform.cpp
  src/features/transformspan.cpp
  src/features/transforminv.cpp
  src/features/typetests.cpp
  src/features/kbsyscalls.cpp
  src/features/commandtypes.cpp
  src/features/multiarmor.cpp
  src/features/freeunits.cpp
  src/features/repairwall.cpp
  src/features/compat.cpp
  src/features/gatherfix.cpp
  src/features/smallfixes.cpp
  src/features/impactbones.cpp
  src/features/impacttypes.cpp
  src/features/unitlists.cpp
  src/features/wonderpanel.cpp
  src/features/veterancy.cpp
  src/features/workrate.cpp
  src/features/workratetype.cpp
  src/features/gatherscale.cpp
  src/features/containedrof.cpp
  src/features/unitresource.cpp
  src/features/gatherauras.cpp
  src/features/resourcedebt.cpp
  src/hooks/abilityslot_hooks.asm
  src/hooks/actiontag_hooks.asm
  src/hooks/ai_hooks.asm
  src/hooks/armor_hooks.asm
  src/hooks/freeunit_hooks.asm
  src/hooks/gather_hooks.asm
  src/hooks/foundation_hooks.asm
  src/hooks/impactbone_hooks.asm
  src/hooks/impacttype_hooks.asm
  src/hooks/syscall_hooks.asm
  src/hooks/team_hooks.asm
  src/hooks/unitlist_hooks.asm
  src/hooks/broadside_hooks.asm
  src/hooks/cheat_hooks.asm
  src/hooks/clothfill_hooks.asm
  src/hooks/lastinline_hooks.asm
  src/hooks/menuoptions_hooks.asm
  src/hooks/bwraura_hooks.asm
  src/hooks/civfirsttc_hooks.asm
  src/hooks/civ_hooks.asm
  src/hooks/dance_hooks.asm
  src/hooks/farm_hooks.asm
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
  src/hooks/steadybar_hooks.asm
  src/hooks/shipment_hooks.asm
  src/hooks/smartheal_hooks.asm
  src/hooks/snare_hooks.asm
  src/hooks/socket_hooks.asm
  src/hooks/nativepreview_hooks.asm
  src/hooks/spread_hooks.asm
  src/hooks/startingtc_hooks.asm
  src/hooks/techprereq_hooks.asm
  src/hooks/techrename_hooks.asm
  src/hooks/transform_hooks.asm
  src/hooks/transforminv_hooks.asm
  src/hooks/unittype_hooks.asm
  src/hooks/wonderpanel_hooks.asm
  src/hooks/workrate_hooks.asm
  src/hooks/workratetype_hooks.asm
  src/hooks/gatherscale_hooks.asm
  src/hooks/containedrof_hooks.asm
  src/hooks/unitresource_hooks.asm
  src/hooks/gatherauras_hooks.asm
  src/hooks/resourcedebt_hooks.asm
  src/hooks/hctarget_hooks.asm
  src/hooks/modifytype_hooks.asm
  src/hooks/bounty_hooks.asm
  src/hooks/cantslow_hooks.asm
  src/hooks/stealthtarget_hooks.asm
  src/hooks/datalint_hooks.asm
  src/hooks/snarevalues_hooks.asm
  src/hooks/linkedresource_hooks.asm
  src/hooks/annexfacing_hooks.asm
  src/hooks/xslog_hooks.asm
  src/hooks/prototag_hooks.asm
  src/hooks/sharedlimit_hooks.asm
  src/hooks/pillage_hooks.asm
  src/hooks/aurastacking_hooks.asm
  src/hooks/trainbatch_hooks.asm
  src/hooks/veterancy_hooks.asm
  src/hooks/researchpay_hooks.asm
  src/hooks/researchgrant_hooks.asm
  src/hooks/techsubtype_hooks.asm
  src/hooks/worldtick_hooks.asm
  src/hooks/unitpanelrow_hooks.asm
  src/version.rc
)
# UHC.dll is the DLL the loader runs. dinput8.dll is the same code for a game whose loader runs another
# UHC.dll: it sits beside it (src/engineext.cpp).
add_library(UHC SHARED src/dllmain.cpp ${UHC_SOURCES})
add_library(EngineExt SHARED src/engineext.cpp src/engineext_forward.cpp src/engineext.def ${UHC_SOURCES})
target_compile_definitions(EngineExt PRIVATE UHC_ENGINE_EXT)
# version.h (from src/version.h.in) carries the project version to dllmain.cpp and version.rc.
configure_file(src/version.h.in ${CMAKE_CURRENT_BINARY_DIR}/generated/version.h @ONLY)
foreach(target UHC EngineExt)
  target_compile_definitions(${target} PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX UNICODE _UNICODE)
  target_include_directories(${target} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/generated)
  # For `include common.inc` in the hook files.
  target_include_directories(${target} PRIVATE src/hooks)
  target_compile_options(${target} PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:/W4 /permissive->
    # x86 images link with /SAFESEH; MASM objects must declare their (empty) handler table.
    $<$<COMPILE_LANGUAGE:ASM_MASM>:/safeseh>
  )
endforeach()
set_target_properties(EngineExt PROPERTIES OUTPUT_NAME dinput8)
set_target_properties(UHC PROPERTIES OUTPUT_NAME UHC)
