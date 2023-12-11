# XPU backend is built with Intel SYCL
# This file is to load Intel SYCL tool chain components
#
# PYTORCH_FOUND_XPU
# PYTORCH_IntelSYCL_LIBRARIES
# IntelSYCL_INCLUDE_DIRS
#

set(PYTORCH_FOUND_XPU FALSE)

if(IntelSYCL_cmake_included)
  return()
endif()
set(IntelSYCL_cmake_included true)

include(FindPackageHandleStandardArgs)

find_package(IntelSYCL REQUIRED)
if(NOT IntelSYCL_FOUND)
  message(FATAL_ERROR "Cannot find IntelSYCL compiler!")
endif()

# Try to find Intel SYCL version.hpp header
find_file(INTEL_SYCL_VERSION
    NAMES version.hpp
    PATHS
        ${SYCL_INCLUDE_DIR}
    PATH_SUFFIXES
        sycl
        sycl/CL
        sycl/CL/sycl
    NO_DEFAULT_PATH)

if(NOT INTEL_SYCL_VERSION)
  message(FATAL_ERROR "Can NOT find SYCL version file!")
endif()

set(PYTORCH_FOUND_XPU TRUE)

set(IntelSYCL_INCLUDE_DIRS ${SYCL_INCLUDE_DIR})

# Intel SYCL runtime
find_library(PYTORCH_IntelSYCL_LIBRARIES sycl HINTS ${SYCL_LIBRARY_DIR})

set(SYCL_COMPILER_VERSION)
file(READ ${INTEL_SYCL_VERSION} version_contents)
string(REGEX MATCHALL "__SYCL_COMPILER_VERSION +[0-9]+" VERSION_LINE "${version_contents}")
list(LENGTH VERSION_LINE ver_line_num)
if (${ver_line_num} EQUAL 1)
  string(REGEX MATCHALL "[0-9]+" SYCL_COMPILER_VERSION "${VERSION_LINE}")
endif()

# offline compiler of IntelSYCL compiler
set(IGC_OCLOC_VERSION)
find_program(OCLOC_EXEC ocloc)
if(OCLOC_EXEC)
  set(drv_ver_file "${PROJECT_BINARY_DIR}/OCL_DRIVER_VERSION")
  file(REMOVE ${drv_ver_file})
  execute_process(COMMAND ${OCLOC_EXEC} query OCL_DRIVER_VERSION WORKING_DIRECTORY ${PROJECT_BINARY_DIR})
  if(EXISTS ${drv_ver_file})
    file(READ ${drv_ver_file} drv_ver_contents)
    string(STRIP "${drv_ver_contents}" IGC_OCLOC_VERSION)
  endif()
endif()

message(STATUS "XPU found")
