# Test SYCL cmake helpers and variables setup
set(SYCL_BUILDING_SYSTEM_TEST_ROOT ${PROJECT_SOURCE_DIR}/test/cpp/sycl)
set(SYCL_BUILDING_SYSTEM_TEST_SRCS ${SYCL_BUILDING_SYSTEM_TEST_ROOT}/simple_sycl_kernel.cpp)

sycl_add_library(simple_sycl_kernel STATIC ${SYCL_BUILDING_SYSTEM_TEST_SRCS})

add_executable(test_sycl_building_system
  ${PROJECT_SOURCE_DIR}/test/cpp/sycl/main.cpp
  ${PROJECT_SOURCE_DIR}/test/cpp/sycl/test_simple_sycl_kernel.cpp)
target_link_libraries(test_sycl_building_system gtest)
target_link_libraries(test_sycl_building_system simple_sycl_kernel)

add_dependencies(test_sycl_building_system simple_sycl_kernel)

if(INSTALL_TEST)
  install(TARGETS test_sycl_building_system DESTINATION bin)
endif()
