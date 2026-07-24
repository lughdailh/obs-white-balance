cmake_minimum_required(VERSION 3.24)
project(obs-white-balance VERSION 0.1.2 LANGUAGES C CXX OBJCXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(OBS_APP "/Applications/OBS.app" CACHE PATH "Path to OBS.app")
set(OBS_SOURCE_DIR "" CACHE PATH "Path to matching OBS Studio source")
if(NOT APPLE)
  message(FATAL_ERROR "Version 0.1 supports macOS only")
endif()
if(NOT EXISTS "${OBS_SOURCE_DIR}/libobs/obs-module.h")
  message(FATAL_ERROR "Run scripts/fetch-obs-source.sh and set OBS_SOURCE_DIR")
endif()
if(NOT EXISTS "${OBS_APP}/Contents/Frameworks/libobs.framework/libobs")
  message(FATAL_ERROR "libobs.framework not found in ${OBS_APP}")
endif()

add_library(obs-white-balance MODULE src/calibration-math.cpp
            src/white-balance-filter.mm)
target_include_directories(obs-white-balance PRIVATE src)
target_include_directories(obs-white-balance SYSTEM PRIVATE
                           "${OBS_SOURCE_DIR}/libobs")
target_compile_options(obs-white-balance PRIVATE -Wall -Wextra -Wpedantic
                       "$<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>")
find_library(APPKIT AppKit REQUIRED)
target_link_libraries(obs-white-balance PRIVATE
                      "${OBS_APP}/Contents/Frameworks/libobs.framework/libobs"
                      "${APPKIT}")
set_target_properties(obs-white-balance PROPERTIES PREFIX "" SUFFIX ".so"
  BUILD_RPATH "${OBS_APP}/Contents/Frameworks")

include(CTest)
if(BUILD_TESTING)
  add_executable(calibration-math-tests tests/calibration-math.test.cpp
                 src/calibration-math.cpp)
  target_include_directories(calibration-math-tests PRIVATE src)
  add_test(NAME calibration-math-tests COMMAND calibration-math-tests)

  add_executable(plugin-smoke tests/plugin-smoke.mm)
  target_include_directories(plugin-smoke SYSTEM PRIVATE
                             "${OBS_SOURCE_DIR}/libobs")
  target_compile_options(plugin-smoke PRIVATE -fobjc-arc)
  target_link_libraries(plugin-smoke PRIVATE
                        "${OBS_APP}/Contents/Frameworks/libobs.framework/libobs"
                        "${APPKIT}")
  set_target_properties(plugin-smoke PROPERTIES
                        BUILD_RPATH "${OBS_APP}/Contents/Frameworks")
  add_dependencies(plugin-smoke obs-white-balance)
  add_test(
    NAME plugin-smoke
    COMMAND plugin-smoke
            "${OBS_APP}/Contents/Frameworks/libobs-opengl.dylib"
            "$<TARGET_FILE:obs-white-balance>"
            "${CMAKE_CURRENT_SOURCE_DIR}/data")
endif()

set(BUNDLE "${CMAKE_BINARY_DIR}/obs-white-balance.plugin")
add_custom_command(TARGET obs-white-balance POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E rm -rf "${BUNDLE}"
  COMMAND "${CMAKE_COMMAND}" -E make_directory "${BUNDLE}/Contents/MacOS"
          "${BUNDLE}/Contents/Resources/locale"
  COMMAND "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:obs-white-balance>"
          "${BUNDLE}/Contents/MacOS/obs-white-balance"
  COMMAND "${CMAKE_COMMAND}" -E copy packaging/macos/Info.plist
          "${BUNDLE}/Contents/Info.plist"
  COMMAND "${CMAKE_COMMAND}" -E copy data/white-balance.effect
          "${BUNDLE}/Contents/Resources/white-balance.effect"
  COMMAND "${CMAKE_COMMAND}" -E copy data/locale/en-US.ini data/locale/ca-ES.ini
          "${BUNDLE}/Contents/Resources/locale"
  WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
