set(TEST_SYCL_ROOT ${PROJECT_SOURCE_DIR}/test/cpp/sycl)
set(TEST_SYCL_STANDALONE_SYCL_SRCS ${TEST_SYCL_ROOT}/simple_kernel.cpp)
set(TEST_SYCL_STANDALONE_CPP_SRCS
  ${TEST_SYCL_ROOT}/main.cpp
  ${TEST_SYCL_ROOT}/test_simple_kernel.cpp)

sycl_add_executable(
  test_sycl_standalone
  SYCL_SOURCES ${TEST_SYCL_STANDALONE_SYCL_SRCS}
  CPP_SOURCES ${TEST_SYCL_STANDALONE_CPP_SRCS})
sycl_target_link_libraries(test_sycl_standalone gtest)

if(INSTALL_TEST)
  sycl_install_executable_target(test_sycl_standalone DESTINATION bin)
endif()

set(TEST_SYCL_SHARED_SYCL_SRCS ${TEST_SYCL_ROOT}/simple_kernel.cpp)
set(TEST_SYCL_SHARED_CPP_SRCS ${TEST_SYCL_ROOT}/test_simple_kernel.cpp)
set(TEST_SYCL_SHARED_EXE_SRCS ${TEST_SYCL_ROOT}/main.cpp)

sycl_add_library(
  simple_kernel
  SYCL_SOURCES ${TEST_SYCL_SHARED_SYCL_SRCS}
  CPP_SOURCES ${TEST_SYCL_SHARED_CPP_SRCS})
sycl_target_link_libraries(simple_kernel gtest)

add_executable(test_sycl_shared ${TEST_SYCL_SHARED_EXE_SRCS})
target_link_libraries(test_sycl_shared simple_kernel)

if(INSTALL_TEST)
  install(TARGETS test_sycl_shared DESTINATION bin)
  sycl_install_library_target(simple_kernel DESTINATION bin)
endif()
