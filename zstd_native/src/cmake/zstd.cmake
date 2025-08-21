# set(GIT_REPOSITORY "https://github.com/facebook/zstd.git")
set(GIT_REPOSITORY "https://gitee.com/mirrors/facebook-zstd.git")
set(GIT_TAG "v1.5.7")
set(SOURCE_SUBDIR "build/cmake")

set(ZSTD_BUILD_PROGRAMS OFF)
set(ZSTD_BUILD_STATIC OFF)
set(ZSTD_BUILD_SHARED ON)

if(WIN32)
    include(ExternalProject)

    # TMP_DIR      = <prefix>/tmp
    # STAMP_DIR    = <prefix>/src/<name>-stamp
    # DOWNLOAD_DIR = <prefix>/src
    # SOURCE_DIR   = <prefix>/src/<name>
    # BINARY_DIR   = <prefix>/src/<name>-build
    # INSTALL_DIR  = <prefix>
    # LOG_DIR      = <STAMP_DIR>

    ExternalProject_Add(
        external_zstd
        PREFIX "${CMAKE_CURRENT_BINARY_DIR}/external"
        GIT_REPOSITORY ${GIT_REPOSITORY}
        GIT_TAG ${GIT_TAG}
        SOURCE_SUBDIR ${SOURCE_SUBDIR}
        CMAKE_ARGS
        -DZSTD_BUILD_PROGRAMS=${ZSTD_BUILD_PROGRAMS}
        -DZSTD_BUILD_STATIC=${ZSTD_BUILD_STATIC}
        -DZSTD_BUILD_SHARED=${ZSTD_BUILD_SHARED}
        -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
    )

    ExternalProject_Get_Property(external_zstd SOURCE_DIR)
    ExternalProject_Get_Property(external_zstd INSTALL_DIR)

    set(ZSTD_SOURCE_DIR ${SOURCE_DIR})
    set(ZSTD_INSTALL_DIR ${INSTALL_DIR})

    add_library(zstd SHARED IMPORTED GLOBAL)
    set_target_properties(zstd PROPERTIES
        IMPORTED_LOCATION "${ZSTD_INSTALL_DIR}/bin/zstd.dll"
        IMPORTED_IMPLIB "${ZSTD_INSTALL_DIR}/lib/zstd.lib"
    )
    add_dependencies(zstd external_zstd)
else()
    include(FetchContent)

    FetchContent_Declare(
        zstd
        # DOWNLOAD_EXTRACT_TIMESTAMP TRUE
        # URL "https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz"
        GIT_REPOSITORY ${GIT_REPOSITORY}
        GIT_TAG ${GIT_TAG}
        SOURCE_SUBDIR ${SOURCE_SUBDIR}
    )

    FetchContent_MakeAvailable(zstd)
    add_library(zstd ALIAS libzstd_shared)
endif()
