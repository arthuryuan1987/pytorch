set(TEST_SYCL_ROOT ${PROJECT_SOURCE_DIR}/test/cpp/sycl)
set(TEST_SYCL_SYCL_SRCS ${TEST_SYCL_ROOT}/simple_kernel.cpp)
set(TEST_SYCL_CPP_SRCS
  ${TEST_SYCL_ROOT}/main.cpp
  ${TEST_SYCL_ROOT}/test_simple_kernel.cpp)

sycl_add_executable(
  test_sycl
  SYCL_SOURCES ${TEST_SYCL_SYCL_SRCS}
  CPP_SOURCES ${TEST_SYCL_CPP_SRCS})
sycl_target_link_libraries(test_sycl gtest)

if(INSTALL_TEST)
  sycl_executable_target_install(test_sycl)
endif()
