# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(zstd_aimwl_library VERSION 0.0.1 LANGUAGES C)

add_library(zstd_aimwl SHARED
  "zstd_aimwl.c"
)

set_target_properties(zstd_aimwl PROPERTIES
  PUBLIC_HEADER zstd_aimwl.h
  OUTPUT_NAME "zstd_aimwl"
)

target_compile_definitions(zstd_aimwl PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(zstd_aimwl PRIVATE "-Wl,-z,max-page-size=16384")
endif()

# zstd
if(WIN32)
  include(cmake/external_zstd.cmake)
else()
  include(cmake/zstd.cmake)
endif()

# target_link_libraries(
#     # ${PROJECT_NAME}
#     zstd_aimwl
#     PRIVATE
#     libzstd_shared
# )

# # On windows and macos this is needed
# target_include_directories(
#     # ${PROJECT_NAME}
#     zstd_aimwl
#     PRIVATE
#     ${zstd_SOURCE_DIR}/lib
# )
