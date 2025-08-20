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
