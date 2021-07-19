# SPDX-License-Identifier: GPL-2.0-or-later

if(WITH_WEBP)
  set(WITH_TIFF_WEBP ON)
else()
  set(WITH_TIFF_WEBP OFF)
endif()

set(TIFF_EXTRA_ARGS
  -DZLIB_LIBRARY=${LIBDIR}/zlib/lib/${ZLIB_LIBRARY}
  -DZLIB_INCLUDE_DIR=${LIBDIR}/zlib/include
  -DPNG_STATIC=ON
  -DBUILD_SHARED_LIBS=OFF
  -Dlzma=OFF
  -Djbig=OFF
  -Dzstd=OFF
  -Dwebp=${WITH_TIFF_WEBP}
)

if("${CMAKE_SYSTEM_NAME}" STREQUAL "iOS")
  set(TIFF_PATCH_COMMAND ${PATCH_CMD} -p 0 -d ${BUILD_DIR}/tiff/src/external_tiff < ${PATCH_DIR}/tiff.diff)
endif()

ExternalProject_Add(external_tiff
  URL file://${PACKAGE_DIR}/${TIFF_FILE}
  DOWNLOAD_DIR ${DOWNLOAD_DIR}
  URL_HASH ${TIFF_HASH_TYPE}=${TIFF_HASH}
  PREFIX ${BUILD_DIR}/tiff
  PATCH_COMMAND ${TIFF_PATCH_COMMAND}
  CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${LIBDIR}/tiff ${DEFAULT_CMAKE_FLAGS} ${TIFF_EXTRA_ARGS}
  INSTALL_DIR ${LIBDIR}/tiff
)

add_dependencies(
  external_tiff
  external_zlib
)

if(WIN32 AND BUILD_MODE STREQUAL Debug)
  ExternalProject_Add_Step(external_tiff after_install
    COMMAND ${CMAKE_COMMAND} -E copy ${LIBDIR}/tiff/lib/tiffd${LIBEXT} ${LIBDIR}/tiff/lib/tiff${LIBEXT}
    DEPENDEES install
  )
endif()
