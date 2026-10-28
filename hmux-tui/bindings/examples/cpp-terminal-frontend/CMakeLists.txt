cmake_minimum_required(VERSION 3.20)

project(hmux_cpp_terminal_frontend LANGUAGES CXX)

option(HMUX_FRONTEND_BUILD_TESTS "Build deterministic fake-transport tests" ON)
set(
    HMUX_CPP_SDK_DIR
    "${CMAKE_CURRENT_LIST_DIR}/../../cpp"
    CACHE PATH
    "Path to a local hmux-tui C++ SDK checkout; leave empty to use find_package")

if(HMUX_CPP_SDK_DIR)
    get_filename_component(HMUX_CPP_SDK_DIR "${HMUX_CPP_SDK_DIR}" ABSOLUTE)
    if(NOT EXISTS "${HMUX_CPP_SDK_DIR}/CMakeLists.txt")
        message(FATAL_ERROR "HMUX_CPP_SDK_DIR does not contain the hmux C++ SDK")
    endif()
    set(HMUX_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    add_subdirectory(
        "${HMUX_CPP_SDK_DIR}"
        "${CMAKE_CURRENT_BINARY_DIR}/hmux-sdk"
        EXCLUDE_FROM_ALL)
else()
    find_package(hmux-tui-sdk 1.0 CONFIG REQUIRED)
endif()

add_library(hmux_terminal_frontend_core src/frontend.cpp)
target_link_libraries(hmux_terminal_frontend_core PUBLIC hmux::sdk)
target_include_directories(
    hmux_terminal_frontend_core
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)
target_compile_features(hmux_terminal_frontend_core PUBLIC cxx_std_20)

add_executable(hmux-cpp-terminal-frontend src/main.cpp)
target_link_libraries(hmux-cpp-terminal-frontend PRIVATE hmux_terminal_frontend_core)
target_compile_features(hmux-cpp-terminal-frontend PRIVATE cxx_std_20)

if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(
        hmux_terminal_frontend_core PRIVATE -Wall -Wextra -Wpedantic -Werror)
    target_compile_options(
        hmux-cpp-terminal-frontend PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()

if(HMUX_FRONTEND_BUILD_TESTS)
    enable_testing()
    add_executable(hmux-cpp-terminal-frontend-tests tests/frontend_test.cpp)
    target_link_libraries(
        hmux-cpp-terminal-frontend-tests PRIVATE hmux_terminal_frontend_core)
    target_compile_features(hmux-cpp-terminal-frontend-tests PRIVATE cxx_std_20)
    if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
        target_compile_options(
            hmux-cpp-terminal-frontend-tests
            PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()
    add_test(
        NAME hmux-cpp-terminal-frontend
        COMMAND hmux-cpp-terminal-frontend-tests)
endif()
