# SPDX-License-Identifier: GPL-2.0-or-later

####################################################################################################
#
# This is a build system used by platform maintainers to build library dependencies on
# Windows, macOS and Linux.
#
# For users building Blender, we recommend using the precompiled libraries from lib/ on
# Windows and macOS, and install_deps.sh on Linux.
#
# WINDOWS USAGE:
#   Don't call this cmake file yourself, use build_deps.cmd
#   build_deps 2013 x64 / build_deps 2013 x86
#   build_deps 2015 x64 / build_deps 2015 x86
#
# MAC OS X USAGE:
#   Install with homebrew: brew install autoconf automake bison cmake libtool pkg-config yasm
#   Additional requirements for macOS arm64: brew install flex
#   Run "make deps" from main Blender directory
#
# LINUX USAGE:
#   Install compiler cmake autoconf automake libtool yasm tcl
#   Run "make deps" from main Blender directory
#
####################################################################################################

project("BlenderDependencies")
cmake_minimum_required(VERSION 3.5)

include(ExternalProject)
include(cmake/check_software.cmake)
include(cmake/options.cmake)
include(cmake/versions.cmake)
include(cmake/download.cmake)

if(ENABLE_MINGW64)
  include(cmake/setup_mingw64.cmake)
else()
  set(mingw_LIBDIR ${LIBDIR})
endif()

include(cmake/zlib.cmake)
include(cmake/zstd.cmake)
include(cmake/openal.cmake)
include(cmake/png.cmake)
include(cmake/jpeg.cmake)
include(cmake/blosc.cmake)
include(cmake/pthreads.cmake)
include(cmake/openexr.cmake)
include(cmake/brotli.cmake)
include(cmake/freetype.cmake)
include(cmake/freeglut.cmake)
include(cmake/glew.cmake)
include(cmake/alembic.cmake)
include(cmake/clew.cmake)
include(cmake/cuew.cmake)

if(APPLE AND ("${CMAKE_SYSTEM_NAME}" STREQUAL "iOS"))
  #GLFW doesn't have an iOS port and only OpenSubdiv needs it.
else()
  include(cmake/glfw.cmake)
  include(cmake/opensubdiv.cmake)
endif()

include(cmake/sdl.cmake)
if(APPLE AND ("${CMAKE_SYSTEM_NAME}" STREQUAL "iOS"))
  #OpenCOLLADA requires system() which is not available on iOS.
else()
  include(cmake/opencollada.cmake)
endif()
if(APPLE AND ("${CMAKE_SYSTEM_NAME}" STREQUAL "iOS"))
  #LLVM/Clang won't compile for iOS
else()
  include(cmake/llvm.cmake)
endif()
if(APPLE)
  if(("${CMAKE_SYSTEM_NAME}" STREQUAL "iOS"))
    #OpenMP requires LLVM/Clang
  else()
    include(cmake/openmp.cmake)
  endif()
endif()
if(UNIX)
  include(cmake/nasm.cmake)
endif()
include(cmake/openimageio.cmake)
include(cmake/tiff.cmake)
if(WIN32)
  include(cmake/flexbison.cmake)
elseif(UNIX AND NOT APPLE)
  include(cmake/flex.cmake)
endif()
if(APPLE AND ("${CMAKE_SYSTEM_NAME}" STREQUAL "iOS"))
  #OSL requires on-device Clang
else()
  include(cmake/osl.cmake)
endif()
include(cmake/tbb.cmake)
include(cmake/openvdb.cmake)
include(cmake/nanovdb.cmake)
include(cmake/python.cmake)
option(USE_PIP_NUMPY "Install NumPy using pip wheel instead of building from source" OFF)
if(APPLE AND ("${CMAKE_OSX_ARCHITECTURES}" STREQUAL "x86_64"))
  set(USE_PIP_NUMPY ON)
else()
  include(cmake/numpy.cmake)
endif()
include(cmake/python_site_packages.cmake)
include(cmake/package_python.cmake)
if(APPLE AND ("${CMAKE_SYSTEM_NAME}" STREQUAL "iOS"))
  #USD contains PXR, which ships a debugger that requries ptrace.
  #iOS apps cannot have debuggers.
else()
  include(cmake/usd.cmake)
endif()
include(cmake/potrace.cmake)
include(cmake/haru.cmake)
# Boost needs to be included after python.cmake due to the PYTHON_BINARY variable being needed.
include(cmake/boost.cmake)
include(cmake/pugixml.cmake)
if(APPLE AND ("${CMAKE_SYSTEM_NAME}" STREQUAL "iOS"))
  #ISPC needs LLVM and openimagedenoise needs ISPC
  #Embree fails to build on iOS and I don't know why.
else()
  include(cmake/ispc.cmake)
  include(cmake/openimagedenoise.cmake)
  include(cmake/embree.cmake)
endif()
if(NOT APPLE)
  include(cmake/xr_openxr.cmake)
endif()

# OpenColorIO and dependencies.
include(cmake/expat.cmake)
include(cmake/yamlcpp.cmake)
include(cmake/opencolorio.cmake)

if(BLENDER_PLATFORM_ARM)
  include(cmake/sse2neon.cmake)
endif()

if(WITH_WEBP)
  include(cmake/webp.cmake)
endif()

if(NOT WIN32 OR ENABLE_MINGW64)
  include(cmake/gmp.cmake)
  include(cmake/openjpeg.cmake)
  if(NOT WIN32 OR BUILD_MODE STREQUAL Release)
    if(WIN32)
      include(cmake/zlib_mingw.cmake)
    endif()
    include(cmake/lame.cmake)
    include(cmake/ogg.cmake)
    include(cmake/vorbis.cmake)
    include(cmake/theora.cmake)
    include(cmake/opus.cmake)
    include(cmake/vpx.cmake)
    include(cmake/x264.cmake)
    include(cmake/xvidcore.cmake)
    include(cmake/ffmpeg.cmake)
    include(cmake/fftw.cmake)
    include(cmake/sndfile.cmake)
    if(WIN32)
      include(cmake/iconv.cmake)
    endif()
    if(UNIX)
      include(cmake/flac.cmake)
      include(cmake/xml2.cmake)
      if(NOT APPLE)
        include(cmake/spnav.cmake)
        include(cmake/jemalloc.cmake)
      endif()
    endif()
  endif()
endif()

if(UNIX)
  include(cmake/bzip2.cmake)
  include(cmake/ffi.cmake)
  include(cmake/lzma.cmake)
  include(cmake/ssl.cmake)
  include(cmake/sqlite.cmake)
endif()

if(UNIX AND NOT APPLE)
  include(cmake/libglu.cmake)
  include(cmake/mesa.cmake)
  include(cmake/wayland_protocols.cmake)
endif()

include(cmake/harvest.cmake)
