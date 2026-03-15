# FindSndfileIOS.cmake
# Cross-compile libsndfile as a static library for iOS
# Sets SNDFILE_FOUND, SNDFILE_INCLUDE_DIR, SNDFILE_LIBRARIES

include(FetchContent)

FetchContent_Declare(
    libsndfile_ios
    GIT_REPOSITORY https://github.com/libsndfile/libsndfile.git
    GIT_TAG 1.2.2
    GIT_SHALLOW TRUE
)

FetchContent_GetProperties(libsndfile_ios)
if(NOT libsndfile_ios_POPULATED)
    FetchContent_Populate(libsndfile_ios)

    # Build libsndfile as a static library with minimal features
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    set(BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
    set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
    set(ENABLE_EXTERNAL_LIBS OFF CACHE BOOL "" FORCE)
    set(BUILD_REGTEST OFF CACHE BOOL "" FORCE)
    set(ENABLE_MPEG OFF CACHE BOOL "" FORCE)
    set(INSTALL_MANPAGES OFF CACHE BOOL "" FORCE)
    set(INSTALL_PKGCONFIG_MODULE OFF CACHE BOOL "" FORCE)

    add_subdirectory(${libsndfile_ios_SOURCE_DIR} ${libsndfile_ios_BINARY_DIR} EXCLUDE_FROM_ALL)

    set(SNDFILE_FOUND TRUE)
    set(SNDFILE_INCLUDE_DIR "${libsndfile_ios_SOURCE_DIR}/include" "${libsndfile_ios_BINARY_DIR}/include")
    set(SNDFILE_LIBRARIES sndfile)
endif()
