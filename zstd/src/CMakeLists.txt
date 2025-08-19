# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# project(zstd_library VERSION 0.0.1 LANGUAGES C)

# add_library(zstd SHARED
#   "zstd.c"
# )

# set_target_properties(zstd PROPERTIES
#   PUBLIC_HEADER zstd.h
#   OUTPUT_NAME "zstd"
# )

# target_compile_definitions(zstd PUBLIC DART_SHARED_LIB)

# if (ANDROID)
#   # Support Android 15 16k page size
#   target_link_options(zstd PRIVATE "-Wl,-z,max-page-size=16384")
# endif()

include(FetchContent)

set(ZSTD_BUILD_PROGRAMS OFF)
set(ZSTD_BUILD_STATIC OFF)
set(ZSTD_BUILD_SHARED ON)

FetchContent_Declare(
    zstd
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    URL "https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz"
    SOURCE_SUBDIR build/cmake
)

FetchContent_MakeAvailable(zstd)

# target_link_libraries(
#     ${PROJECT_NAME}
#     PRIVATE
#     libzstd_shared
# )

# On windows and macos this is needed
# target_include_directories(
#     ${PROJECT_NAME}
#     PRIVATE
#     ${zstd_SOURCE_DIR}/lib
# )
