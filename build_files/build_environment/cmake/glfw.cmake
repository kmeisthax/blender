# SPDX-License-Identifier: GPL-2.0-or-later

if("${CMAKE_SYSTEM_NAME}" STREQUAL "iOS")
  set(GLFW_EXTRA_ARGS
    -DBUILD_SHARED_LIBS=ON
    -DOPENGL_gl_LIBRARY=OpenGLES
    -DOPENGL_INCLUDE_DIR=${OSX_SDK_ROOT}/System/Library/Frameworks/OpenGLES.framework/Headers)
else()
  set(GLFW_EXTRA_ARGS)
endif()

ExternalProject_Add(external_glfw
  URL file://${PACKAGE_DIR}/${GLFW_FILE}
  DOWNLOAD_DIR ${DOWNLOAD_DIR}
  URL_HASH ${GLFW_HASH_TYPE}=${GLFW_HASH}
  PREFIX ${BUILD_DIR}/glfw
  CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${LIBDIR}/glfw -Wno-dev ${DEFAULT_CMAKE_FLAGS} ${GLFW_EXTRA_ARGS}
  INSTALL_DIR ${LIBDIR}/glfw
)
