# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(zstd_native_library VERSION 0.0.1 LANGUAGES C)

add_library(zstd_native SHARED
  "zstd_native.c"
)

set_target_properties(zstd_native PROPERTIES
  PUBLIC_HEADER zstd_native.h
  OUTPUT_NAME "zstd_native"
)

target_compile_definitions(zstd_native PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(zstd_native PRIVATE "-Wl,-z,max-page-size=16384")
endif()

include(cmake/zstd.cmake)

target_link_libraries(zstd_native PRIVATE zstd)

# On windows and macos this is needed
target_include_directories(zstd_native PRIVATE ${ZSTD_SOURCE_DIR}/lib)
