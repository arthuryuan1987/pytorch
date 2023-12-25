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

# Linkage of SYCL program involves a sub-phase. Target binary is produced
# at the sub-phase. Target compiler flags need to be specified.

# Input variables
#
# verbose:BOOL=<>          OFF: Be as quiet as possible (default)
#                          ON : Describe each step
#
# output_file:STRING=<> File to generate.  This argument must be passed in.

cmake_policy(PUSH)
cmake_policy(SET CMP0007 NEW)
cmake_policy(SET CMP0010 NEW)
if(NOT output_file)
  message(FATAL_ERROR "You must specify generated_file on the command line")
endif()

set(CMAKE_COMMAND "@CMAKE_COMMAND@") # path
set(SYCL_executable "@SYCL_EXECUTABLE@") # path
set(object_files [==[@object_files@]==]) # list
set(SYCL_link_flags [==[@SYCL_link_flags@]==]) # list
set(SYCL_target_compiler_flags "@SYCL_target_compiler_flags@") # list

# SYCL_execute_process - Executes a command with optional command echo and status message.
#
#   status  - Status message to print if verbose is true
#   command - COMMAND argument from the usual execute_process argument structure
#   ARGN    - Remaining arguments are the command with arguments
#
#   SYCL_result - return value from running the command
#
# Make this a macro instead of a function, so that things like RESULT_VARIABLE
# and other return variables are present after executing the process.
macro(SYCL_execute_process status command)
  set(_command ${command})
  if(NOT "x${_command}" STREQUAL "xCOMMAND")
    message(FATAL_ERROR "Malformed call to SYCL_execute_process.  Missing COMMAND as second argument. (command = ${command})")
  endif()
  set(verbose TRUE)
  if(verbose)
    execute_process(COMMAND "${CMAKE_COMMAND}" -E echo -- ${status})
    # Now we need to build up our command string.  We are accounting for quotes
    # and spaces, anything else is left up to the user to fix if they want to
    # copy and paste a runnable command line.
    set(SYCL_execute_process_string)
    foreach(arg ${ARGN})
      # If there are quotes, excape them, so they come through.
      string(REPLACE "\"" "\\\"" arg ${arg})
      # Args with spaces need quotes around them to get them to be parsed as a single argument.
      if(arg MATCHES " ")
        list(APPEND SYCL_execute_process_string "\"${arg}\"")
      else()
        list(APPEND SYCL_execute_process_string ${arg})
      endif()
    endforeach()
    # Echo the command
    execute_process(COMMAND ${CMAKE_COMMAND} -E echo ${SYCL_execute_process_string})
  endif()
  # Run the command
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE SYCL_result )
endmacro()

# Delete the target file
SYCL_execute_process(
  "Removing ${output_file}"
  COMMAND "${CMAKE_COMMAND}" -E remove "${output_file}"
  )

# Generate the code
SYCL_execute_process(
  "Generating ${output_file}"
  COMMAND ${SYCL_executable}
  ${object_files}
  -o ${output_file}
  ${SYCL_link_flags}
  -Xs
  ${SYCL_target_compiler_flags}
  )

if(SYCL_result)
  SYCL_execute_process(
    "Removing ${output_file}"
    COMMAND "${CMAKE_COMMAND}" -E remove "${output_file}"
    )
  message(FATAL_ERROR "Error generating file ${output_file}")
else()
  if(verbose)
    message("Generated ${output_file} successfully.")
  endif()
endif()

cmake_policy(POP)
