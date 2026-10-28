cmake_minimum_required(VERSION 3.20)

project(hmux_resource_conformance_cpp LANGUAGES CXX)

set(HMUX_BUILD_TESTS OFF CACHE BOOL "" FORCE)
add_subdirectory(
    "${CMAKE_CURRENT_LIST_DIR}/../../../cpp"
    "${CMAKE_CURRENT_BINARY_DIR}/hmux-sdk"
)

add_executable(hmux-resource-conformance-cpp main.cpp)
target_link_libraries(hmux-resource-conformance-cpp PRIVATE hmux::sdk)
target_compile_features(hmux-resource-conformance-cpp PRIVATE cxx_std_20)

if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(
        hmux-resource-conformance-cpp
        PRIVATE
            -Wall
            -Wextra
            -Wpedantic
    )
endif()
