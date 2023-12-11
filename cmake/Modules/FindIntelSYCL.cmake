# Helpers of IntelSYCL_ADD_LIBRARY.
# Use Intel SYCL compiler to build .cpp containing SYCL kernels.

# IntelSYCL_HOST_COMPILER
set(IntelSYCL_HOST_COMPILER "${CMAKE_CXX_COMPILER}"
  CACHE FILEPATH "Host side compiler used by IntelSYCL")

# IntelSYCL_EXECUTABLE
if(DEFINED ENV{IntelSYCL_EXECUTABLE})
  set(IntelSYCL_EXECUTABLE "$ENV{IntelSYCL_EXECUTABLE}" CACHE FILEPATH "The Intel SYCL compiler")
else()
  find_program(IntelSYCL_EXECUTABLE
    NAMES icpx
    PATHS "${SYCL_PACKAGE_DIR}"
    PATH_SUFFIXES bin bin64
    NO_DEFAULT_PATH
    )
endif()

# IntelSYCL_VERBOSE_BUILD
option(IntelSYCL_VERBOSE_BUILD "Print out the commands run while compiling the SYCL source file.  With the Makefile generator this defaults to VERBOSE variable specified on the command line, but can be forced on with this option." OFF)

#####################################################################
## IntelSYCL_INCLUDE_DEPENDENCIES
##

# So we want to try and include the dependency file if it exists.  If
# it doesn't exist then we need to create an empty one, so we can
# include it.

# If it does exist, then we need to check to see if all the files it
# depends on exist.  If they don't then we should clear the dependency
# file and regenerate it later.  This covers the case where a header
# file has disappeared or moved.

macro(IntelSYCL_INCLUDE_DEPENDENCIES dependency_file)
  # Make the output depend on the dependency file itself, which should cause the
  # rule to re-run.
  set(IntelSYCL_DEPEND ${dependency_file})
  if(NOT EXISTS ${dependency_file})
    file(WRITE ${dependency_file} "#FindIntelSYCL.cmake generated file.  Do not edit.\n")
  endif()

  # Always include this file to force CMake to run again next
  # invocation and rebuild the dependencies.
  include(${dependency_file})
endmacro()

##############################################################################
# Separate the OPTIONS out from the sources
##############################################################################
macro(IntelSYCL_GET_SOURCES_AND_OPTIONS _sources _cmake_options _options)
  set( ${_sources} )
  set( ${_cmake_options} )
  set( ${_options} )
  set( _found_options FALSE )
  foreach(arg ${ARGN})
    if("x${arg}" STREQUAL "xOPTIONS")
      set( _found_options TRUE )
    elseif(
        "x${arg}" STREQUAL "xSTATIC" OR
        "x${arg}" STREQUAL "xSHARED" OR
        "x${arg}" STREQUAL "xMODULE"
        )
      list(APPEND ${_cmake_options} ${arg})
    else()
      if ( _found_options )
        list(APPEND ${_options} ${arg})
      else()
        # Assume this is a file
        list(APPEND ${_sources} ${arg})
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
function(IntelSYCL_COMPUTE_BUILD_PATH path build_path)
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
macro(IntelSYCL_WRAP_SRCS sycl_target generated_files)
  # Optional arguments
  set(_argn_list "${ARGN}")
  set(IntelSYCL_flags "")
  set(IntelSYCL_C_OR_CXX CXX)
  set(generated_extension ${CMAKE_${IntelSYCL_C_OR_CXX}_OUTPUT_EXTENSION})

  list(APPEND IntelSYCL_INCLUDE_DIRS "$<TARGET_PROPERTY:${sycl_target},INCLUDE_DIRECTORIES>")

  # Do the same thing with compile definitions
  set(IntelSYCL_COMPILE_DEFINITIONS "$<TARGET_PROPERTY:${sycl_target},COMPILE_DEFINITIONS>")

  IntelSYCL_GET_SOURCES_AND_OPTIONS(_IntelSYCL_wrap_sources _IntelSYCL_wrap_cmake_options __IntelSYCL_wrap_options ${_argn_list})
  set(_IntelSYCL_build_shared_libs FALSE)

  list(FIND _IntelSYCL_wrap_cmake_options SHARED _IntelSYCL_found_SHARED)
  list(FIND _IntelSYCL_wrap_cmake_options MODULE _IntelSYCL_found_MODULE)
  if(_IntelSYCL_found_SHARED GREATER -1 OR _IntelSYCL_found_MODULE GREATER -1)
    set(_IntelSYCL_build_shared_libs TRUE)
  endif()
  # STATIC
  list(FIND _IntelSYCL_wrap_cmake_options STATIC _IntelSYCL_found_STATIC)
  if(_IntelSYCL_found_STATIC GREATER -1)
    set(_IntelSYCL_build_shared_libs FALSE)
  endif()

  if(_IntelSYCL_build_shared_libs)
    # If we are setting up code for a shared library, then we need to add extra flags for
    # compiling objects for shared libraries.
    set(IntelSYCL_HOST_SHARED_FLAGS ${CMAKE_SHARED_LIBRARY_${IntelSYCL_C_OR_CXX}_FLAGS})
  else()
    set(IntelSYCL_HOST_SHARED_FLAGS)
  endif()

  set(_IntelSYCL_host_flags "set(CMAKE_HOST_FLAGS ${CMAKE_${IntelSYCL_C_OR_CXX}_FLAGS} ${IntelSYCL_HOST_SHARED_FLAGS})")

  # Reset the output variable
  set(_IntelSYCL_wrap_generated_files "")
  foreach(file ${_argn_list})
    get_source_file_property(_is_header ${file} HEADER_FILE_ONLY)
    # SYCL kernels are in .cpp file
    if(Not _is_header)
      set( IntelSYCL_compile_to_external_module OFF )
      set(IntelSYCL_HOST_FLAGS ${_IntelSYCL_host_flags})

      # Determine output directory
      IntelSYCL_COMPUTE_BUILD_PATH("${file}" IntelSYCL_build_path)
      set(IntelSYCL_compile_intermediate_directory "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${sycl_target}.dir/${IntelSYCL_build_path}")
      set(IntelSYCL_compile_output_dir "${IntelSYCL_compile_intermediate_directory}")

      get_filename_component( basename ${file} NAME )
      set(generated_file_path "${IntelSYCL_compile_output_dir}/${CMAKE_CFG_INTDIR}")
      set(generated_file_basename "${sycl_target}_generated_${basename}${generated_extension}")
      set(generated_file "${generated_file_path}/${generated_file_basename}")
      set(cmake_dependency_file "${IntelSYCL_compile_intermediate_directory}/${generated_file_basename}.depend")
      set(IntelSYCL_generated_dependency_file "${IntelSYCL_compile_intermediate_directory}/${generated_file_basename}.IntelSYCL-depend")
      set(custom_target_script_pregen "${IntelSYCL_compile_intermediate_directory}/${generated_file_basename}.cmake.pre-gen")
      set(custom_target_script "${IntelSYCL_compile_intermediate_directory}/${generated_file_basename}$<$<BOOL:$<CONFIG>>:.$<CONFIG>>.cmake")

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

      list(APPEND ${sycl_target}_SEPARABLE_COMPILATION_OBJECTS "${generated_file}")

      IntelSYCL_INCLUDE_DEPENDENCIES(${cmake_dependency_file})

      set(IntelSYCL_build_type "Device")

      # Configure the build script
      configure_file("${IntelSYCL_run_intelsycl}" "${custom_target_script_pregen}" @ONLY)
      file(GENERATE
        OUTPUT "${custom_target_script}"
        INPUT "${custom_target_script_pregen}"
        )

      set(main_dep MAIN_DEPENDENCY ${source_file})

      if(IntelSYCL_VERBOSE_BUILD)
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

      set(IntelSYCL_build_comment_string "Building IntelSYCL (${IntelSYCL_build_type}) object ${generated_file_relative_path}")

      # Build the generated file and dependency file ##########################
      add_custom_command(
        OUTPUT ${generated_file}
        # These output files depend on the source_file and the contents of cmake_dependency_file
        ${main_dep}
        DEPENDS ${IntelSYCL_DEPEND}
        DEPENDS ${custom_target_script}
        # Make sure the output directory exists before trying to write to it.
        COMMAND ${CMAKE_COMMAND} -E make_directory "${generated_file_path}"
        COMMAND ${CMAKE_COMMAND} ARGS
          -D verbose:BOOL=${verbose_output}
          -D "generated_file:STRING=${generated_file}"
          -P "${custom_target_script}"
        WORKING_DIRECTORY "${IntelSYCL_compile_intermediate_directory}"
        COMMENT "${IntelSYCL_build_comment_string}"
        )

      # Make sure the build system knows the file is generated.
      set_source_files_properties(${generated_file} PROPERTIES GENERATED TRUE)

      list(APPEND _IntelSYCL_wrap_generated_files ${generated_file})

      # Add the other files that we want cmake to clean on a cleanup ##########
      list(APPEND IntelSYCL_ADDITIONAL_CLEAN_FILES "${cmake_dependency_file}")
      list(REMOVE_DUPLICATES IntelSYCL_ADDITIONAL_CLEAN_FILES)
      set(IntelSYCL_ADDITIONAL_CLEAN_FILES ${IntelSYCL_ADDITIONAL_CLEAN_FILES} CACHE INTERNAL "List of intermediate files that are part of the IntelSYCL dependency scanning.")
    endif()
  endforeach()

  # Set the return parameter
  set(${generated_files} ${_IntelSYCL_wrap_generated_files})
endmacro()

function(_IntelSYCL_get_important_host_flags important_flags flag_string)
  string(REGEX MATCHALL "-fPIC" flags "${flag_string}")
  list(APPEND ${important_flags} ${flags})
  set(${important_flags} ${${important_flags}} PARENT_SCOPE)
endfunction()

###############################################################################
# Custom Intermediate Link
###############################################################################

# Compute the filename to be used by IntelSYCL_INTERMEDIATE_LINK_OBJECTS
function(IntelSYCL_COMPUTE_INTERMEDIATE_LINK_OBJECT_FILE_NAME output_file_var sycl_target object_files)
  if (object_files)
    set(generated_extension ${CMAKE_${IntelSYCL_C_OR_CXX}_OUTPUT_EXTENSION})
    set(output_file "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${sycl_target}.dir/${CMAKE_CFG_INTDIR}/${sycl_target}_intermediate_link${generated_extension}")
  else()
    set(output_file)
  endif()

  set(${output_file_var} "${output_file}" PARENT_SCOPE)
endfunction()

# Setup the build rule for the separable compilation intermediate link file.
function(IntelSYCL_INTERMEDIATE_LINK_OBJECTS output_file sycl_target options object_files)
  if (object_files)

    set_source_files_properties("${output_file}"
      PROPERTIES
      EXTERNAL_OBJECT TRUE # This is an object file not to be compiled, but only
                           # be linked.
      GENERATED TRUE       # This file is generated during the build
      )

    # Flags
    set(IntelSYCL_flags ${IntelSYCL_FLAGS})

    # Host compiler
    set(important_host_flags)
    _IntelSYCL_get_important_host_flags(important_host_flags "${CMAKE_HOST_FLAGS}")

    set(IntelSYCL_host_compiler_flags "")
    foreach(flag ${important_host_flags})
      # Extra quotes are added around each flag to help Intel SYCL parse out flags with spaces.
      string(APPEND IntelSYCL_host_compiler_flags ",\"${flag}\"")
    endforeach()
    set(IntelSYCL_host_compiler_flags "-fsycl-host-compiler-options=${IntelSYCL_host_compiler_flags}")

    list( FIND IntelSYCL_flags "-fsycl-host-compiler=" "-fsycl-host-compiler=${IntelSYCL_HOST_COMPILER}")
    list( FIND IntelSYCL_flags "-fsycl-host-compiler-options=" ${IntelSYCL_host_compiler_flags})

    file(RELATIVE_PATH output_file_relative_path "${CMAKE_BINARY_DIR}" "${output_file}")

    add_custom_command(
      OUTPUT ${output_file}
      DEPENDS ${object_files}
      COMMAND ${IntelSYCL_EXECUTABLE} ${IntelSYCL_flags} ${object_files} -o ${output_file}
      COMMENT "Building IntelSYCL intermediate link file ${output_file_relative_path}"
      )
  endif()
endfunction()

###############################################################################
# ADD LIBRARY
###############################################################################
macro(IntelSYCL_ADD_LIBRARY sycl_target)

  # Separate the sources from the options
  IntelSYCL_GET_SOURCES_AND_OPTIONS(_sources _cmake_options _options ${ARGN})

  # Create custom commands and targets for each file.
  IntelSYCL_WRAP_SRCS(
    ${sycl_target}
    generated_files
    ${_sources}
    ${_cmake_options}
    OPTIONS ${_options}
    )

  # Compute the file name of the intermedate link file used for separable
  # compilation.
  IntelSYCL_COMPUTE_INTERMEDIATE_LINK_OBJECT_FILE_NAME(
    link_file
    ${sycl_target}
    "${${sycl_target}_INTERMEDIATE_LINK_OBJECTS}"
    )

  # Add the library.
  add_library(${sycl_target} ${_cmake_options}
    ${_generated_files}
    ${_sources}
    ${link_file}
    )

  # Add a link phase for custom linkage command
  IntelSYCL_INTERMEDIATE_LINK_OBJECTS("${link_file}" ${sycl_target} "${_options}" "${${sycl_target}_INTERMEDIATE_LINK_OBJECTS}")

  target_link_libraries(${sycl_target} ${IntelSYCL_LINK_LIBRARIES_KEYWORD}
    ${IntelSYCL_LIBRARIES}
    )

endmacro()
