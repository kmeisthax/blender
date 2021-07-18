# SPDX-License-Identifier: GPL-2.0-or-later

if("${CMAKE_SYSTEM_NAME}" STREQUAL "iOS")
  #libflac needs some extra help to find the OGG library, don't know why.
  set(FLAC_EXTRA_ARGS --with-ogg=${LIBDIR}/ogg)
else()
  set(FLAC_EXTRA_ARGS)
endif()

ExternalProject_Add(external_flac
  URL file://${PACKAGE_DIR}/${FLAC_FILE}
  DOWNLOAD_DIR ${DOWNLOAD_DIR}
  URL_HASH ${FLAC_HASH_TYPE}=${FLAC_HASH}
  PREFIX ${BUILD_DIR}/flac
  CONFIGURE_COMMAND ${CONFIGURE_ENV} && cd ${BUILD_DIR}/flac/src/external_flac/ && ${CONFIGURE_COMMAND} --prefix=${LIBDIR}/flac --disable-shared --enable-static ${FLAC_EXTRA_ARGS}
  BUILD_COMMAND ${CONFIGURE_ENV} && cd ${BUILD_DIR}/flac/src/external_flac/ && make -j${MAKE_THREADS}
  INSTALL_COMMAND ${CONFIGURE_ENV} && cd ${BUILD_DIR}/flac/src/external_flac/ && make install
  INSTALL_DIR ${LIBDIR}/flac
)

if(MSVC)
  set_target_properties(external_flac PROPERTIES FOLDER Mingw)
endif()
