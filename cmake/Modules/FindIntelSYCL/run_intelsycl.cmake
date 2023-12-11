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


##########################################################################
# This file runs the dpcpp commands to produce the desired output file along with
# the dependency file needed by CMake to compute dependencies.  In addition the
# file checks the output of each command and if the command fails it deletes the
# output files.

# Input variables
#
# verbose:BOOL=<>          OFF: Be as quiet as possible (default)
#                          ON : Describe each step
#
# generated_file:STRING=<> File to generate.  This argument must be passed in.

cmake_policy(PUSH)
cmake_policy(SET CMP0007 NEW)
cmake_policy(SET CMP0010 NEW)
if(NOT generated_file)
  message(FATAL_ERROR "You must specify generated_file on the command line")
endif()

set(CMAKE_COMMAND "@CMAKE_COMMAND@") # path
set(source_file "@source_file@") # path
set(IntelSYCL_generated_dependency_file "@IntelSYCL_generated_dependency_file@") # path
set(cmake_dependency_file "@cmake_dependency_file@") # path
set(IntelSYCL_HOST_COMPILER "@IntelSYCL_HOST_COMPILER@") # path
set(generated_file_path "@generated_file_path@") # path
set(generated_file_internal "@generated_file@") # path
set(IntelSYCL_executable "@IntelSYCL_EXECUTABLE@") # path
set(IntelSYCL_flags @IntelSYCL_flags@) # list

list(REMOVE_DUPLICATES IntelSYCL_INCLUDE_DIRS)
set(IntelSYCL_include_args)
foreach(dir ${IntelSYCL_INCLUDE_DIRS})
  # Extra quotes are added around each flag to help Intel SYCL parse out flags with spaces.
  list(APPEND IntelSYCL_include_args "-I${dir}")
endforeach()

# Clean up list of compile definitions, add -D flags, and append to IntelSYCL_flags
list(REMOVE_DUPLICATES IntelSYCL_COMPILE_DEFINITIONS)
foreach(def ${IntelSYCL_COMPILE_DEFINITIONS})
  list(APPEND IntelSYCL_flags "-D${def}")
endforeach()

set(IntelSYCL_host_compiler_flags "")
foreach(flag ${CMAKE_HOST_FLAGS})
  # Extra quotes are added around each flag to help Intel SYCL parse out flags with spaces.
  string(APPEND IntelSYCL_host_compiler_flags ",\"${flag}\"")
endforeach()
if (IntelSYCL_host_compiler_flags)
  set(IntelSYCL_host_compiler_flags "-fsycl-host-compiler-options=${IntelSYCL_host_compiler_flags}")
endif()

set(IntelSYCL_host_compiler "-fsycl-host-compiler=${IntelSYCL_HOST_COMPILER}")

# IntelSYCL_execute_process - Executes a command with optional command echo and status message.
#
#   status  - Status message to print if verbose is true
#   command - COMMAND argument from the usual execute_process argument structure
#   ARGN    - Remaining arguments are the command with arguments
#
#   IntelSYCL_result - return value from running the command
#
# Make this a macro instead of a function, so that things like RESULT_VARIABLE
# and other return variables are present after executing the process.
macro(IntelSYCL_execute_process status command)
  set(_command ${command})
  if(NOT "x${_command}" STREQUAL "xCOMMAND")
    message(FATAL_ERROR "Malformed call to IntelSYCL_execute_process.  Missing COMMAND as second argument. (command = ${command})")
  endif()
  if(verbose)
    execute_process(COMMAND "${CMAKE_COMMAND}" -E echo -- ${status})
    # Now we need to build up our command string.  We are accounting for quotes
    # and spaces, anything else is left up to the user to fix if they want to
    # copy and paste a runnable command line.
    set(IntelSYCL_execute_process_string)
    foreach(arg ${ARGN})
      # If there are quotes, excape them, so they come through.
      string(REPLACE "\"" "\\\"" arg ${arg})
      # Args with spaces need quotes around them to get them to be parsed as a single argument.
      if(arg MATCHES " ")
        list(APPEND IntelSYCL_execute_process_string "\"${arg}\"")
      else()
        list(APPEND IntelSYCL_execute_process_string ${arg})
      endif()
    endforeach()
    # Echo the command
    execute_process(COMMAND ${CMAKE_COMMAND} -E echo ${IntelSYCL_execute_process_string})
  endif()
  # Run the command
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE IntelSYCL_result )
endmacro()

# Delete the target file
IntelSYCL_execute_process(
  "Removing ${generated_file}"
  COMMAND "${CMAKE_COMMAND}" -E remove "${generated_file}"
  )

# Generate the code
IntelSYCL_execute_process(
  "Generating ${generated_file}"
  COMMAND "${IntelSYCL_executable}"
  "${source_file}"
  -o "${generated_file}"
  ${IntelSYCL_flags}
  ${IntelSYCL_include_args}
  ${IntelSYCL_host_compiler}
  ${IntelSYCL_host_compiler_flags}
  )

if(IntelSYCL_result)
  IntelSYCL_execute_process(
    "Removing ${generated_file}"
    COMMAND "${CMAKE_COMMAND}" -E remove "${generated_file}"
    )
  message(FATAL_ERROR "Error generating file ${generated_file}")
else()
  if(verbose)
    message("Generated ${generated_file} successfully.")
  endif()
endif()

cmake_policy(POP)
