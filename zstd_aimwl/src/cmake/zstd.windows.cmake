
# TMP_DIR      = <prefix>/tmp
# STAMP_DIR    = <prefix>/src/<name>-stamp
# DOWNLOAD_DIR = <prefix>/src
# SOURCE_DIR   = <prefix>/src/<name>
# BINARY_DIR   = <prefix>/src/<name>-build
# INSTALL_DIR  = <prefix>
# LOG_DIR      = <STAMP_DIR>

include(ExternalProject)

ExternalProject_Add(
    external_zstd
    PREFIX "${CMAKE_CURRENT_BINARY_DIR}/external"
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    URL "https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz"
    # GIT_REPOSITORY "https://github.com/facebook/zstd.git"
    # GIT_TAG "v1.5.7"
    SOURCE_SUBDIR "build/cmake"
    CMAKE_ARGS
    -DZSTD_BUILD_PROGRAMS=OFF
    -DZSTD_BUILD_STATIC=OFF
    -DZSTD_BUILD_SHARED=ON
    -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
)

ExternalProject_Get_Property(external_zstd SOURCE_DIR)
ExternalProject_Get_Property(external_zstd INSTALL_DIR)

set(zstd_SOURCE_DIR "${SOURCE_DIR}")
set(zstd_INSTALL_DIR "${INSTALL_DIR}")

message(STATUS "zstd_SOURCE_DIR: ${zstd_SOURCE_DIR}")
message(STATUS "zstd_INSTALL_DIR ${zstd_INSTALL_DIR}")

add_library(zstd SHARED IMPORTED)
set_target_properties(zstd PROPERTIES
    IMPORTED_LOCATION "${zstd_INSTALL_DIR}/bin/zstd.dll"
    IMPORTED_IMPLIB "${zstd_INSTALL_DIR}/lib/zstd.lib"
)
add_dependencies(zstd external_zstd)
