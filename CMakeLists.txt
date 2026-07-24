cmake_minimum_required(VERSION 3.28...3.30)

include(cmake/common/bootstrap.cmake NO_POLICY_SCOPE)
project(${_name} VERSION ${_version})

include(compilerconfig)
include(defaults)
include(helpers)

add_library(${CMAKE_PROJECT_NAME} MODULE)
add_library(OBS::${CMAKE_PROJECT_NAME} ALIAS ${CMAKE_PROJECT_NAME})

find_package(libobs REQUIRED)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE OBS::libobs)
target_compile_features(${CMAKE_PROJECT_NAME} PRIVATE cxx_std_17)
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE src)
target_sources(
  ${CMAKE_PROJECT_NAME}
  PRIVATE src/calibration-math.cpp src/calibration-math.hpp
          src/platform-eyedropper.hpp src/white-balance-filter.cpp
)

if(OS_MACOS)
  enable_language(OBJCXX)
  find_library(APPKIT AppKit REQUIRED)
  target_sources(${CMAKE_PROJECT_NAME} PRIVATE src/platform-eyedropper-macos.mm)
  target_compile_options(
    ${CMAKE_PROJECT_NAME} PRIVATE "$<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>"
  )
  target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE "${APPKIT}")
elseif(OS_WINDOWS)
  target_sources(
    ${CMAKE_PROJECT_NAME} PRIVATE src/platform-eyedropper-windows.cpp
  )
  target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE user32 gdi32)
else()
  message(FATAL_ERROR "White Balance currently supports macOS and Windows")
endif()

set_target_properties_plugin(${CMAKE_PROJECT_NAME} PROPERTIES OUTPUT_NAME ${_name})

include(CTest)
if(BUILD_TESTING)
  add_executable(
    calibration-math-tests tests/calibration-math.test.cpp
                           src/calibration-math.cpp
  )
  target_compile_features(calibration-math-tests PRIVATE cxx_std_17)
  target_include_directories(calibration-math-tests PRIVATE src)
  if(MSVC)
    target_compile_options(calibration-math-tests PRIVATE /UNDEBUG)
  else()
    target_compile_options(calibration-math-tests PRIVATE -UNDEBUG)
  endif()
  add_test(NAME calibration-math-tests COMMAND calibration-math-tests)

  if(OS_MACOS AND EXISTS "/Applications/OBS.app/Contents/Frameworks/libobs.framework/libobs")
    add_executable(plugin-smoke tests/plugin-smoke.mm)
    target_compile_options(plugin-smoke PRIVATE -fobjc-arc -UNDEBUG)
    target_link_libraries(plugin-smoke PRIVATE OBS::libobs "${APPKIT}")
    set_target_properties(
      plugin-smoke
      PROPERTIES
        BUILD_RPATH
        "${CMAKE_CURRENT_SOURCE_DIR}/.deps/Frameworks;/Applications/OBS.app/Contents/Frameworks"
    )
    add_dependencies(plugin-smoke ${CMAKE_PROJECT_NAME})
    add_test(
      NAME plugin-smoke
      COMMAND
        plugin-smoke
        "/Applications/OBS.app/Contents/Frameworks/libobs-opengl.dylib"
        "$<TARGET_FILE:${CMAKE_PROJECT_NAME}>" "${CMAKE_CURRENT_SOURCE_DIR}/data"
    )
    set_tests_properties(
      plugin-smoke
      PROPERTIES
        ENVIRONMENT
        "DYLD_FRAMEWORK_PATH=${CMAKE_CURRENT_SOURCE_DIR}/.deps/Frameworks:/Applications/OBS.app/Contents/Frameworks;DYLD_LIBRARY_PATH=${CMAKE_CURRENT_SOURCE_DIR}/.deps/obs-deps-2025-07-11-universal/lib"
    )
  endif()
endif()
