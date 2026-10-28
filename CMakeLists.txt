cmake_minimum_required(VERSION 3.25)
project(UHC LANGUAGES CXX)

if(NOT CMAKE_SIZEOF_VOID_P EQUAL 4)
  message(FATAL_ERROR "age3y.exe is 32-bit: configure with -A Win32")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# Static CRT so the DLL drops into a game folder without a VC++ redistributable.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_library(UHC SHARED src/dllmain.cpp)
target_compile_definitions(UHC PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX UNICODE _UNICODE)
target_compile_options(UHC PRIVATE /W4 /permissive-)
set_target_properties(UHC PROPERTIES OUTPUT_NAME UHC)
