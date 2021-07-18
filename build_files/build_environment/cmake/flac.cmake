# ***** BEGIN GPL LICENSE BLOCK *****
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# ***** END GPL LICENSE BLOCK *****

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
