#.rst:
# FindSYCL
# --------
#
# .. note::

# The following variables affect the behavior of the macros in the script needed
# to be defined before calling ``SYCL_ADD_EXECUTABLE`` or ``SYCL_ADD_LIBRARY``::
#
#  SYCL_COMPILER
#  -- SYCL compiler's excutable.
#
#  SYCL_FLAGS
#  -- SYCL compiler's compilation command line arguments.
#
#  SYCL_LINK_FLAGS
#  -- SYCL compiler's linkage command line arguments.
#
#  SYCL_HOST_FLAGS
#  -- SYCL compiler's 3rd party host compiler (e.g. gcc) arguments .
#
#  SYCL_TARGET_COMPILER_FLAGS
#  -- SYCL compiler's target compiler (e.g. igc) arguments.
#
#  SYCL_INCLUDE_DIR
#  -- Include directory for SYCL compiler/runtime headers.
#
#  SYCL_LIBRARY_DIR
#  -- Include directory for SYCL compiler/runtime libraries.

# Helpers::
#
#  SYCL_ADD_EXECUTABLE
#  -- See the macro's comments for details.
#
#  SYCL_ADD_LIBRARY
#  -- See the macro's comments for details.
#
#  SYCL_TARGET_LINK_LIBRARIES
#  -- See the macro's comments for detials.
#
#  SYCL_INSTALL_LIBRARY_TARGET
#  -- Install a library target produced by ``SYCL_ADD_LIBRARY``.
#
#  SYCL_INSTALL_EXECUTABLE_TARGET
#  -- Install an executable target produced by ``SYCL_ADD_EXECUTABLE``.
#
#  SYCL_INCLUDE_DIRECTORIES
#  -- Helper to add user specified include directories. Added include
#     directories will be referenced in compile command line of following
#     ``SYCL_ADD_EXECUTABLE`` or ``SYCL_ADD_LIBRARY``.

# The MIT License
#
# License for the specific language governing rights and limitations under
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#


###############################################################################
# Helpers of SYCL_ADD_LIBRARY and SYCL_ADD_EXECUTABLE.
# Use SYCL compiler to build .cpp containing SYCL kernels.

# This macro helps us find the location of helper files we will need the full path to
macro(SYCL_FIND_HELPER_FILE _name _extension)
  set(_full_name "${_name}.${_extension}")
  # CMAKE_CURRENT_LIST_FILE contains the full path to the file currently being
  # processed.  Using this variable, we can pull out the current path, and
  # provide a way to get access to the other files we need local to here.
  get_filename_component(CMAKE_CURRENT_LIST_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
  set(SYCL_${_name} "${CMAKE_CURRENT_LIST_DIR}/FindSYCL/${_full_name}")
  if(NOT EXISTS "${SYCL_${_name}}")
    set(error_message "${_full_name} not found in ${CMAKE_CURRENT_LIST_DIR}/FindSYCL")
    message(FATAL_ERROR "${error_message}")
  endif()
  # Set this variable as internal, so the user isn't bugged with it.
  set(SYCL_${_name} ${SYCL_${_name}} CACHE INTERNAL "Location of ${_full_name}" FORCE)
endmacro()

# SYCL_HOST_COMPILER
set(SYCL_HOST_COMPILER "${CMAKE_CXX_COMPILER}"
  CACHE FILEPATH "Host side compiler used by SYCL")
set(SYCL_INCLUDE_DIRS_USER "")

# SYCL_EXECUTABLE
if(SYCL_COMPILER)
  set(SYCL_EXECUTABLE ${SYCL_COMPILER} CACHE FILEPATH "The Intel SYCL compiler")
else()
  find_program(SYCL_EXECUTABLE
    NAMES icpx
    PATHS "${SYCL_PACKAGE_DIR}"
    PATH_SUFFIXES bin bin64
    NO_DEFAULT_PATH
    )
endif()

set(SYCL_LIBRARIES)
find_library(SYCL_RUNTIME_LIBRARY sycl HINTS ${SYCL_LIBRARY_DIR})
list(APPEND SYCL_LIBRARIES ${SYCL_RUNTIME_LIBRARY})

# SYCL_VERBOSE_BUILD
option(SYCL_VERBOSE_BUILD "Print out the commands run while compiling the SYCL source file.  With the Makefile generator this defaults to VERBOSE variable specified on the command line, but can be forced on with this option." OFF)

#####################################################################
## SYCL_INCLUDE_DEPENDENCIES
##

# So we want to try and include the dependency file if it exists.  If
# it doesn't exist then we need to create an empty one, so we can
# include it.

# If it does exist, then we need to check to see if all the files it
# depends on exist.  If they don't then we should clear the dependency
# file and regenerate it later.  This covers the case where a header
# file has disappeared or moved.

macro(SYCL_INCLUDE_DEPENDENCIES dependency_file)
  # Make the output depend on the dependency file itself, which should cause the
  # rule to re-run.
  set(SYCL_DEPEND ${dependency_file})
  if(NOT EXISTS ${dependency_file})
    file(WRITE ${dependency_file} "#FindSYCL.cmake generated file.  Do not edit.\n")
  endif()

  # Always include this file to force CMake to run again next
  # invocation and rebuild the dependencies.
  include(${dependency_file})
endmacro()

###############################################################################
# Macros
###############################################################################

###############################################################################
# Add include directories to pass to the sycl compiler command.
##############################################################################
macro(SYCL_INCLUDE_DIRECTORIES)
  foreach(dir ${ARGN})
    list(APPEND SYCL_INCLUDE_DIRS_USER ${dir})
  endforeach()
endmacro()


###############################################################################
sycl_find_helper_file(run_sycl cmake)

##############################################################################
# Separate the OPTIONS out from the sources
##############################################################################
macro(SYCL_GET_SOURCES_AND_OPTIONS _sycl_sources _cpp_sources _cmake_options)
  set( ${_cmake_options} )
  set( _found_options FALSE )
  set( _found_sycl_sources FALSE )
  set( _found_cpp_sources FALSE )
  foreach(arg ${ARGN})
    if("x${arg}" STREQUAL "xOPTIONS")
      set( _found_options TRUE )
      set( _found_sycl_sources FALSE )
      set( _found_cpp_sources FALSE )
    elseif(
        "x${arg}" STREQUAL "xEXCLUDE_FROM_ALL" OR
        "x${arg}" STREQUAL "xSTATIC" OR
        "x${arg}" STREQUAL "xSHARED" OR
        "x${arg}" STREQUAL "xMODULE"
        )
      list(APPEND ${_cmake_options} ${arg})
    elseif("x${arg}" STREQUAL "xSYCL_SOURCES")
      set( _found_options FALSE )
      set( _found_sycl_sources TRUE )
      set( _found_cpp_sources FALSE )
    elseif("x${arg}" STREQUAL "xCPP_SOURCES")
      set( _found_options FALSE )
      set( _found_sycl_sources FALSE )
      set( _found_cpp_sources TRUE )
    else()
      if ( _found_options )
        message(FATAL_ERROR "sycl_add_executable/library doesn't support OPTIONS keyword.")
      elseif ( _found_sycl_sources )
        list(APPEND ${_sycl_sources} ${arg})
      elseif ( _found_cpp_sources )
        list(APPEND ${_cpp_sources} ${arg})
      endif()
    endif()
  endforeach()
endmacro()

##############################################################################
# Helper to avoid clashes of files with the same basename but different paths.
# This doesn't attempt to do exactly what CMake internals do, which is to only
# add this path when there is a conflict, since by the time a second collision
# in names is detected it's already too late to fix the first one.  For
# consistency sake the relative path will be added to all files.
##############################################################################
function(SYCL_COMPUTE_BUILD_PATH path build_path)
  # Only deal with CMake style paths from here on out
  file(TO_CMAKE_PATH "${path}" bpath)
  if (IS_ABSOLUTE "${bpath}")
    # Absolute paths are generally unnessary, especially if something like
    # file(GLOB_RECURSE) is used to pick up the files.

    string(FIND "${bpath}" "${CMAKE_CURRENT_BINARY_DIR}" _binary_dir_pos)
    if (_binary_dir_pos EQUAL 0)
      file(RELATIVE_PATH bpath "${CMAKE_CURRENT_BINARY_DIR}" "${bpath}")
    else()
      file(RELATIVE_PATH bpath "${CMAKE_CURRENT_SOURCE_DIR}" "${bpath}")
    endif()
  endif()

  # This recipe is from cmLocalGenerator::CreateSafeUniqueObjectFileName in the
  # CMake source.

  # Remove leading /
  string(REGEX REPLACE "^[/]+" "" bpath "${bpath}")
  # Avoid absolute paths by removing ':'
  string(REPLACE ":" "_" bpath "${bpath}")
  # Avoid relative paths that go up the tree
  string(REPLACE "../" "__/" bpath "${bpath}")
  # Avoid spaces
  string(REPLACE " " "_" bpath "${bpath}")

  # Strip off the filename.  I wait until here to do it, since removin the
  # basename can make a path that looked like path/../basename turn into
  # path/.. (notice the trailing slash).
  get_filename_component(bpath "${bpath}" PATH)

  set(${build_path} "${bpath}" PARENT_SCOPE)
  #message("${build_path} = ${bpath}")
endfunction()

##############################################################################
# This helper macro populates the following variables and setups up custom
# commands and targets to invoke the Intel SYCL compiler to generate C++ source.
# INPUT:
#   sycl_target         - Target name
#   FILE1 .. FILEN      - The remaining arguments are the sources to be wrapped.
# OUTPUT:
#   generated_files     - List of generated files
##############################################################################
macro(SYCL_WRAP_SRCS sycl_target generated_files _cmake_options sources)
  # Optional arguments
  set(SYCL_flags "")
  set(SYCL_C_OR_CXX CXX)
  set(generated_extension ${CMAKE_${SYCL_C_OR_CXX}_OUTPUT_EXTENSION})

  set(SYCL_include_dirs ${SYCL_INCLUDE_DIRS_USER} "${SYCL_INCLUDE_DIR}")
  list(APPEND SYCL_include_dirs "$<TARGET_PROPERTY:${sycl_target},INCLUDE_DIRECTORIES>")

  set(SYCL_compile_definitions "$<TARGET_PROPERTY:${sycl_target},COMPILE_DEFINITIONS>")

  set(_SYCL_build_shared_libs FALSE)
  list(FIND _cmake_options SHARED _SYCL_found_SHARED)
  list(FIND _cmake_options MODULE _SYCL_found_MODULE)
  if(_SYCL_found_SHARED GREATER -1 OR _SYCL_found_MODULE GREATER -1)
    set(_SYCL_build_shared_libs TRUE)
  endif()
  # STATIC
  list(FIND _cmake_options STATIC _SYCL_found_STATIC)
  if(_SYCL_found_STATIC GREATER -1)
    set(_SYCL_build_shared_libs FALSE)
  endif()

  if(_SYCL_build_shared_libs)
    # If we are setting up code for a shared library, then we need to add extra flags for
    # compiling objects for shared libraries.
    set(SYCL_HOST_SHARED_FLAGS ${CMAKE_SHARED_LIBRARY_${SYCL_C_OR_CXX}_FLAGS})
  else()
    set(SYCL_HOST_SHARED_FLAGS)
  endif()

  set(SYCL_host_flags ${CMAKE_${SYCL_C_OR_CXX}_FLAGS} ${SYCL_HOST_SHARED_FLAGS} ${SYCL_HOST_FLAGS})

  # Reset the output variable
  set(_SYCL_wrap_generated_files "")
  foreach(file ${sources})
    get_source_file_property(_is_header ${file} HEADER_FILE_ONLY)
    # SYCL kernels are in .cpp file
    if((${file} MATCHES "\\.cpp$") AND NOT _is_header)

      # Determine output directory
      SYCL_COMPUTE_BUILD_PATH("${file}" SYCL_build_path)
      set(SYCL_compile_intermediate_directory "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${sycl_target}.dir/${SYCL_build_path}")
      set(SYCL_compile_output_dir "${SYCL_compile_intermediate_directory}")

      get_filename_component( basename ${file} NAME )
      set(generated_file_path "${SYCL_compile_output_dir}/${CMAKE_CFG_INTDIR}")
      set(generated_file_basename "${sycl_target}_generated_${basename}${generated_extension}")
      set(generated_file "${generated_file_path}/${generated_file_basename}")
      set(cmake_dependency_file "${SYCL_compile_intermediate_directory}/${generated_file_basename}.depend")
      set(SYCL_generated_dependency_file "${SYCL_compile_intermediate_directory}/${generated_file_basename}.SYCL-depend")
      set(custom_target_script_pregen "${SYCL_compile_intermediate_directory}/${generated_file_basename}.cmake.pre-gen")
      set(custom_target_script "${SYCL_compile_intermediate_directory}/${generated_file_basename}$<$<BOOL:$<CONFIG>>:.$<CONFIG>>.cmake")

      set_source_files_properties("${generated_file}"
        PROPERTIES
        EXTERNAL_OBJECT true # This is an object file not to be compiled, but only be linked.
        )

      # Don't add CMAKE_CURRENT_SOURCE_DIR if the path is already an absolute path.
      get_filename_component(file_path "${file}" PATH)
      if(IS_ABSOLUTE "${file_path}")
        set(source_file "${file}")
      else()
        set(source_file "${CMAKE_CURRENT_SOURCE_DIR}/${file}")
      endif()

      list(APPEND ${sycl_target}_INTERMEDIATE_LINK_OBJECTS "${generated_file}")

      SYCL_INCLUDE_DEPENDENCIES(${cmake_dependency_file})

      set(SYCL_build_type "Device")

      # Configure the build script
      configure_file("${SYCL_run_sycl}" "${custom_target_script_pregen}" @ONLY)
      file(GENERATE
        OUTPUT "${custom_target_script}"
        INPUT "${custom_target_script_pregen}"
        )

      set(main_dep MAIN_DEPENDENCY ${source_file})

      if(SYCL_VERBOSE_BUILD)
        set(verbose_output ON)
      elseif(CMAKE_GENERATOR MATCHES "Makefiles")
        set(verbose_output "$(VERBOSE)")
      # This condition lets us also turn on verbose output when someone
      # specifies CMAKE_VERBOSE_MAKEFILE, even if the generator isn't
      # the Makefiles generator (this is important for us, Ninja users.)
      elseif(CMAKE_VERBOSE_MAKEFILE)
        set(verbose_output ON)
      else()
        set(verbose_output OFF)
      endif()

      set(SYCL_build_comment_string "Building SYCL (${SYCL_build_type}) object ${generated_file_relative_path}")

      # Build the generated file and dependency file ##########################
      add_custom_command(
        OUTPUT ${generated_file}
        # These output files depend on the source_file and the contents of cmake_dependency_file
        ${main_dep}
        DEPENDS ${SYCL_DEPEND}
        DEPENDS ${custom_target_script}
        # Make sure the output directory exists before trying to write to it.
        COMMAND ${CMAKE_COMMAND} -E make_directory "${generated_file_path}"
        COMMAND ${CMAKE_COMMAND} ARGS
          -D verbose:BOOL=${verbose_output}
          -D "generated_file:STRING=${generated_file}"
          -P "${custom_target_script}"
        WORKING_DIRECTORY "${SYCL_compile_intermediate_directory}"
        COMMENT "${SYCL_build_comment_string}"
        )

      # Make sure the build system knows the file is generated.
      set_source_files_properties(${generated_file} PROPERTIES GENERATED TRUE)

      list(APPEND _SYCL_wrap_generated_files ${generated_file})

      # Add the other files that we want cmake to clean on a cleanup ##########
      list(APPEND SYCL_ADDITIONAL_CLEAN_FILES "${cmake_dependency_file}")
      list(REMOVE_DUPLICATES SYCL_ADDITIONAL_CLEAN_FILES)
      set(SYCL_ADDITIONAL_CLEAN_FILES ${SYCL_ADDITIONAL_CLEAN_FILES} CACHE INTERNAL "List of intermediate files that are part of the SYCL dependency scanning.")
    endif()
  endforeach()

  # Set the return parameter
  set(${generated_files} ${_SYCL_wrap_generated_files})
endmacro()

function(_sycl_get_important_host_flags important_flags flag_string)
  string(REGEX MATCHALL "-fPIC" flags "${flag_string}")
  list(APPEND ${important_flags} ${flags})
  set(${important_flags} ${${important_flags}} PARENT_SCOPE)
endfunction()

###############################################################################
# Custom Intermediate Link
###############################################################################

# Compute the filename to be used by SYCL_LINK_DEVICE_OBJECTS
function(SYCL_COMPUTE_DEVICE_OBJECT_FILE_NAME output_file_var sycl_target)
  set(generated_extension ${CMAKE_${SYCL_C_OR_CXX}_OUTPUT_EXTENSION})
  set(output_file "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${sycl_target}.dir/${CMAKE_CFG_INTDIR}/${sycl_target}_sycl_device_obj${generated_extension}")
  set(${output_file_var} "${output_file}" PARENT_SCOPE)
endfunction()

macro(SYCL_LINK_DEVICE_OBJECTS output_file sycl_target sycl_objects)
  set(object_files)
  list(APPEND object_files ${sycl_objects})

  if (object_files)

    set_source_files_properties("${output_file}"
      PROPERTIES
      EXTERNAL_OBJECT TRUE # This is an object file not to be compiled, but only
                           # be linked.
      GENERATED TRUE       # This file is generated during the build
      )

    set(SYCL_device_link_flags)
    set(important_host_flags)
    _sycl_get_important_host_flags(important_host_flags "${SYCL_HOST_FLAGS}")
    set(SYCL_device_link_flags ${link_type_flag} ${important_host_flags} ${SYCL_FLAGS})

    set(SYCL_target_compiler_flags "")
    foreach(flag ${SYCL_TARGET_COMPILER_FLAGS})
      string(APPEND SYCL_target_compiler_flags "${flag} ")
    endforeach()

    file(REAL_PATH working_directory "${output_file}")
    file(RELATIVE_PATH output_file_relative_path "${CMAKE_BINARY_DIR}" "${output_file}")

    if(SYCL_VERBOSE_BUILD)
      set(verbose_output ON)
    elseif(CMAKE_GENERATOR MATCHES "Makefiles")
      set(verbose_output "$(VERBOSE)")
    # This condition lets us also turn on verbose output when someone
    # specifies CMAKE_VERBOSE_MAKEFILE, even if the generator isn't
    # the Makefiles generator (this is important for us, Ninja users.)
    elseif(CMAKE_VERBOSE_MAKEFILE)
      set(verbose_output ON)
    else()
      set(verbose_output OFF)
    endif()

    # Build the generated file and dependency file ##########################
    add_custom_command(
      OUTPUT ${output_file}
      DEPENDS ${object_files}
      COMMAND ${SYCL_EXECUTABLE} -fsycl ${SYCL_device_link_flags} -fsycl-link ${object_files} -o ${output_file}
      COMMENT "Building SYCL link file ${output_file_relative_path}"
      )
  endif()
endmacro()

macro(get_full_name_library_link_options _options full_name)
  set(_link_options "")
  get_filename_component(path ${full_name} DIRECTORY)
  get_filename_component(soname ${full_name} NAME)
  set(_link_options ${_link_options} "-L${path}")
  set(_link_options ${_link_options} "-l:${soname}")
  set(${_options} ${_link_options})
endmacro()

macro(get_static_shared_library_link_options _options tgt)
  set(_link_options "")
  get_property(path TARGET ${tgt} PROPERTY LIBRARY_OUTPUT_DIRECTORY)
  get_property(lib_name TARGET ${tgt} PROPERTY NAME)
  set(_link_options ${_link_options} "-L${path}")
  set(_link_options ${_link_options} "-l${lib_name}")
  set(${_options} ${_link_options})
endmacro()

macro(get_interface_library_link_options _options tgt)
  set(_link_options "")
  get_property(_imported TARGET ${tgt} PROPERTY INTERFACE_LINK_LIBRARIES)
  if(TARGET ${_imported})
    get_property(type TARGET ${imported_tgt} PROPERTY TYPE)
    if(${type} MATCHES STATIC_LIBRARY OR ${type} MATCHES SHARED_LIBRARY)
      get_static_shared_library_link_options(_imported_link_options ${_imported})
      set(_link_options ${_imported_link_options})
    elseif()
      message(FATAL_ERROR "sycl_target_link_libraries doesn't support transitive INTERFACE targets")
    endif()
  elseif(EXISTS ${_imported})
    get_full_name_library_link_options(_fname_link_options ${_imported})
    set(_link_options ${_fname_link_options})
  elseif(NOT ${_imported} STREQUAL "")
    # command
    set(_link_options "${_imported}")
  endif()
  set(${_options} ${_link_options})
endmacro()

###############################################################################
# TARGET LINK LIBRARIES
#
# Preprocess linkage information to produce linkage options ahead of generation
# time, since cannot parse/deduce it from result of generator expression
# $<TARGET_PROPERTY:tgt,INTERFACE_LINK_LIBRARIES> at generation time.
#
# Support full name library, ``STATIC_LIBRARY``|``SHARED_LIBRARY``|
# ``INTERFACE_LIBRARY`` target and linkage option string.
#
# Inheriting transitive link dependencies is not supported.
###############################################################################
macro(SYCL_TARGET_LINK_LIBRARIES target)
  get_property(link_libraries_flags TARGET ${target} PROPERTY LINK_LIBRARIES_FLAGS)
  set(libs ${ARGN})
  foreach(lib ${libs})
    if(TARGET ${lib})
      # target
      get_property(type TARGET ${lib} PROPERTY TYPE)
      if(${type} MATCHES STATIC_LIBRARY OR ${type} MATCHES SHARED_LIBRARY)
        get_static_shared_library_link_options(_static_shared_library_link_options ${lib})
        set(link_libraries_flags
          ${link_libraries_flags}
          ${_static_shared_library_link_options})
        set_property(TARGET ${target} PROPERTY LINK_LIBRARIES_FLAGS ${link_libraries_flags})
        get_property(sub_libs TARGET ${lib} PROPERTY INTERFACE_LINK_LIBRARIES)
        sycl_target_link_libraries(${target} ${sub_libs})
      elseif(${type} MATCHES INTERFACE_LIBRARY)
        get_interface_library_link_options(_imported_link_options ${lib})
        set(link_libraries_flags ${link_libraries_flags} ${_imported_link_options})
        set_property(TARGET ${target} PROPERTY LINK_LIBRARIES_FLAGS ${link_libraries_flags})
      else()
        message(FATAL_ERROR "SYCL_TARGET_LINK_LIBRARIES doesn't support target types except for STATIC|SHARED|INTERFACE")
      endif()
    elseif(EXISTS ${lib})
      # full name
      get_full_name_library_link_options(_fname_link_options ${lib})
      set(link_libraries_flags ${link_libraries_flags} ${_fname_link_options})
      set_property(TARGET ${target} PROPERTY LINK_LIBRARIES_FLAGS ${link_libraries_flags})
    elseif(NOT ${lib} STREQUAL "")
      # linkage option string
      set(link_libraries_flags ${link_libraries_flags} ${lib})
      set_property(TARGET ${target} PROPERTY LINK_LIBRARIES_FLAGS ${link_libraries_flags})
    endif()
  endforeach()
endmacro()

###############################################################################
# INSTALL LIBRARY
# Install a library target produced by ``SYCL_ADD_EXECUTABLE``
###############################################################################
macro(SYCL_INSTALL_LIBRARY_TARGET sycl_target)
  get_property(from TARGET ${sycl_target} PROPERTY IMPORTED_LOCATION)
  install(
    FILES ${from}
    ${ARGN})
endmacro()

###############################################################################
# ADD LIBRARY
# Return an interface library target wrapping a library produced
# by add_custom_target. Output library file can be found by
# ``IMPORTED_LOCATION``. ``INTERFACE_LINK_LIBRARIES`` is set for the target.
#
# sycl_add_libraries(
#   <target_name>
#   [SYCL_SOURCES <sycl_sources>...]
#   [CPP_SOURCES <sycl_sources>...])
#
# ``target_compile_options`` in subsequent is not supported.
# ``target_include_directories`` in subsequent is not supported.
# Only ``SHARED`` CMAKE option is supported. ``STATIC``|``INTERFACE`` and
# other option are not supported.
###############################################################################
macro(SYCL_ADD_LIBRARY sycl_target)

  # Separate the sources from the options
  SYCL_GET_SOURCES_AND_OPTIONS(
    _sycl_sources
    _cpp_sources
    _cmake_options
    ${ARGN})

  if(NOT "${_cmake_options}" STREQUAL "" AND NOT ${_cmake_options} MATCHES SHARED)
    message(FATAL_ERROR "SYCL_ADD_LIBRARY supports SHARED library only.")
  endif()

  # Compile sycl sources
  SYCL_WRAP_SRCS(
    ${sycl_target}
    ${sycl_target}_sycl_objects
    SHARED
    ${_sycl_sources})

  # Compile cpp sources
  set(${sycl_target}_cpp_objects_tgt)
  if(_cpp_sources)
    add_library(${sycl_target}_cpp_objects_tgt OBJECT ${_cpp_sources})
    set_property(TARGET ${sycl_target}_cpp_objects_tgt PROPERTY POSITION_INDEPENDENT_CODE ON)
  endif()

  # Compute the file name of the intermedate link file used for separable
  # compilation.
  SYCL_COMPUTE_IMPORTED_OBJECT_FILE_NAME(link_file ${sycl_target} "lib" ".so")

  # Add a custom linkage target
  SYCL_LINK_OBJECTS(
    ${imported_file}
    ${sycl_target}
    ${sycl_target}_shadow
    SHARED
    ${sycl_target}_cpp_objects_tgt
    ${${sycl_target}_sycl_objects})

  # Create library target.
  add_library(${sycl_target} INTERFACE ${imported_file})
  set_property(TARGET ${sycl_target} PROPERTY IMPORTED_LOCATION "${imported_file}")
  set_property(TARGET ${sycl_target} APPEND PROPERTY INTERFACE_LINK_LIBRARIES ${imported_file})

  sycl_target_link_libraries(${sycl_target} ${SYCL_LIBRARIES})

endmacro()

###############################################################################
# INSTALL EXECUTABLE
# Install an executable target produced by ``SYCL_ADD_EXECUTABLE``.
###############################################################################
macro(SYCL_INSTALL_EXECUTABLE_TARGET sycl_target)
  set(permissions
    WORLD_EXECUTE
    WORLD_READ
    GROUP_EXECUTE
    GROUP_READ
    OWNER_EXECUTE
    OWNER_READ
    OWNER_WRITE)
  install(
    FILES $<TARGET_FILE:${sycl_target}>
    PERMISSIONS ${permissions}
    ${ARGN})
endmacro()

###############################################################################
# ADD EXECUTABLE
# Return an imported executable target wrapping an executable produced
# by add_custom_target. Output executable file can be found by
# ``IMPORTED_LOCATION``.
#
# sycl_add_executable(
#   <target_name>
#   [SYCL_SOURCES <sycl_sources>...]
#   [CPP_SOURCES <sycl_sources>...])
#
# ``target_compile_options`` in subsequent is not supported.
# ``target_include_directories`` in subsequent is not supported.
# CMAKE options (``IMPORTED``|``ALIAS``) are not supported.
###############################################################################
macro(SYCL_ADD_EXECUTABLE sycl_target)

  # Separate the sources from the options
  SYCL_GET_SOURCES_AND_OPTIONS(
    _sycl_sources
    _cxx_sources
    _cmake_options
    ${ARGN})

  # Compile sycl sources
  SYCL_WRAP_SRCS(
    ${sycl_target}
    ${sycl_target}_sycl_objects
    _cmake_options
    ${_sycl_sources})

  # Compute the file name of the intermedate link file used for separable
  # compilation.
  SYCL_COMPUTE_DEVICE_OBJECT_FILE_NAME(device_object ${sycl_target})

  # Add a custom linkage command to produce an imported executable file.
  SYCL_LINK_DEVICE_OBJECTS(
    ${device_object}
    ${sycl_target}
    ${${sycl_target}_sycl_objects})

  add_executable(
    ${sycl_target}
    ${_cmake_options}
    ${_cxx_sources}
    ${${sycl_target}_sycl_objects}
    ${device_object})

  target_link_libraries(${sycl_target} ${SYCL_LIBRARIES})
endmacro()
