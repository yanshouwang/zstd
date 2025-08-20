
include(ExternalProject)

set(ZSTD_SOURCES_DIR ${CMAKE_CURRENT_BINARY_DIR}/zstd)
# set(ZSTD_INSTALL_DIR ${CMAKE_CURRENT_BINARY_DIR}/install/zstd)
# set(ZSTD_INCLUDE_DIR "${ZSTD_INSTALL_DIR}/include" CACHE PATH "zstd include directory." FORCE)
# set(ZSTD_LIBRARIES "${ZSTD_INSTALL_DIR}/lib/libzstd.a" CACHE FILEPATH "zstd library." FORCE)

ExternalProject_Add(
    extern_zstd
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    URL "https://github.com/facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz"
    PREFIX ${ZSTD_SOURCES_DIR}
    SOURCE_SUBDIR
    build/cmake
    CMAKE_ARGS
    -DZSTD_BUILD_PROGRAMS=OFF
    -DZSTD_BUILD_STATIC=OFF
    -DZSTD_BUILD_SHARED=ON
)

# add_library(libzstd_shared SHARED IMPORTED GLOBAL)
# set_property(TARGET libzstd_shared PROPERTY IMPORTED_LOCATION ${ZSTD_LIBRARIES})
# add_dependencies(libzstd_shared extern_zstd)