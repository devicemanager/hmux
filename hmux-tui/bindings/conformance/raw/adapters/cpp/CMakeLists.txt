cmake_minimum_required(VERSION 3.20)
project(hmux_conformance_cpp LANGUAGES CXX)

set(HMUX_BUILD_TESTS OFF CACHE BOOL "" FORCE)
add_subdirectory("../../../../cpp" hmux-sdk)
find_package(Threads REQUIRED)

add_executable(hmux-conformance-cpp main.cpp)
target_compile_features(hmux-conformance-cpp PRIVATE cxx_std_20)
target_link_libraries(hmux-conformance-cpp PRIVATE hmux::sdk Threads::Threads)
