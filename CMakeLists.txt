cmake_minimum_required(VERSION 3.20)

project(engine LANGUAGES C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# Sem CMAKE_BUILD_TYPE (comum em geradores single-config), o CMake não aplica
# CMAKE_C_FLAGS_DEBUG — o depurador não encontra linhas no fonte. Default: Debug.
if(NOT CMAKE_CONFIGURATION_TYPES)
  if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Choose the type of build." FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "RelWithDebInfo" "MinSizeRel")
  endif()
endif()

include(FetchContent)
include(CTest)

set(CMAKE_SKIP_INSTALL_RULES ON CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
option(ENGINE_BUILD_TESTS "Build engine unit tests" ON)

# GLFW
set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(GLFW_INSTALL OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
  glfw
  GIT_REPOSITORY https://github.com/glfw/glfw.git
  GIT_TAG 3.4
)
FetchContent_MakeAvailable(glfw)

# SDL2 — giroscópio do DualShock 4 via SDL_GameController (GLFW não expõe sensores)
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
  SDL2
  GIT_REPOSITORY https://github.com/libsdl-org/SDL.git
  GIT_TAG release-2.30.11
  GIT_SHALLOW TRUE
)
FetchContent_MakeAvailable(SDL2)

# GLAD2 (OpenGL 2.1 loader)
FetchContent_Declare(
  glad
  GIT_REPOSITORY https://github.com/Dav1dde/glad.git
  GIT_TAG v2.0.8
  SOURCE_SUBDIR cmake
)
FetchContent_MakeAvailable(glad)
glad_add_library(glad_gl REPRODUCIBLE LOADER API gl:core=2.1)

# klib (khash)
FetchContent_Declare(
  klib
  GIT_REPOSITORY https://github.com/attractivechaos/klib.git
  GIT_TAG master
)
FetchContent_MakeAvailable(klib)

# Lua
FetchContent_Declare(
  lua
  GIT_REPOSITORY https://github.com/lua/lua.git
  GIT_TAG v5.4.7
)
FetchContent_MakeAvailable(lua)
file(GLOB LUA_SOURCES CONFIGURE_DEPENDS "${lua_SOURCE_DIR}/*.c")
list(FILTER LUA_SOURCES EXCLUDE REGEX ".*/(lua|luac|onelua)\\.c$")
add_library(lua_static STATIC ${LUA_SOURCES})
target_include_directories(lua_static PUBLIC "${lua_SOURCE_DIR}")
if(APPLE)
  target_compile_definitions(lua_static PRIVATE LUA_USE_MACOSX)
elseif(UNIX)
  target_compile_definitions(lua_static PRIVATE LUA_USE_LINUX)
endif()
if(UNIX AND NOT APPLE)
  target_link_libraries(lua_static PUBLIC m)
endif()

# zlib + libspng
find_package(ZLIB REQUIRED)
FetchContent_Declare(
  spng
  GIT_REPOSITORY https://github.com/randy408/libspng.git
  GIT_TAG v0.7.4
)
FetchContent_MakeAvailable(spng)

set(SPNG_TARGET "")
if(TARGET spng_static)
  set(SPNG_TARGET spng_static)
elseif(TARGET spng)
  set(SPNG_TARGET spng)
else()
  add_library(spng_static STATIC "${spng_SOURCE_DIR}/spng/spng.c")
  target_include_directories(spng_static PUBLIC "${spng_SOURCE_DIR}/spng")
  target_link_libraries(spng_static PUBLIC ZLIB::ZLIB)
  target_compile_definitions(spng_static PRIVATE SPNG_STATIC)
  set(SPNG_TARGET spng_static)
endif()

file(GLOB ENGINE_SOURCES CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/src/*.c")
add_executable(${PROJECT_NAME} ${ENGINE_SOURCES})
set_target_properties(${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
target_include_directories(${PROJECT_NAME} PRIVATE "${CMAKE_SOURCE_DIR}/src" "${klib_SOURCE_DIR}")
target_link_libraries(${PROJECT_NAME} PRIVATE glfw glad_gl lua_static ${SPNG_TARGET} SDL2::SDL2-static)

if(APPLE)
  find_library(OPENGL_FRAMEWORK OpenGL REQUIRED)
  target_link_libraries(${PROJECT_NAME} PRIVATE "${OPENGL_FRAMEWORK}")
elseif(UNIX)
  find_package(OpenGL REQUIRED)
  target_link_libraries(${PROJECT_NAME} PRIVATE OpenGL::GL m)
elseif(WIN32)
  target_link_libraries(${PROJECT_NAME} PRIVATE opengl32)
endif()

target_compile_definitions(${PROJECT_NAME} PRIVATE _POSIX_C_SOURCE=200809L)

# Garante -O0 em Debug (breakpoints estáveis) além de -g do toolchain.
target_compile_options(${PROJECT_NAME} PRIVATE $<$<CONFIG:Debug>:-O0>)

if(ENGINE_BUILD_TESTS)
  enable_testing()

  add_executable(test_input_map tests/test_input_map.c src/input_map.c)
  target_include_directories(test_input_map PRIVATE "${CMAKE_SOURCE_DIR}/src")
  target_link_libraries(test_input_map PRIVATE glfw)

  add_executable(test_lua_bindings tests/test_lua_bindings.c src/lua_bindings.c)
  target_include_directories(test_lua_bindings PRIVATE "${CMAKE_SOURCE_DIR}/src" "${lua_SOURCE_DIR}")
  target_link_libraries(test_lua_bindings PRIVATE lua_static)

  add_test(NAME test_input_map COMMAND test_input_map)
  add_test(NAME test_lua_bindings COMMAND test_lua_bindings)
endif()

find_package(Doxygen)
if(DOXYGEN_FOUND)
  set(DOXYGEN_IN ${CMAKE_SOURCE_DIR}/Doxyfile)
  add_custom_target(
    docs
    COMMAND ${DOXYGEN_EXECUTABLE} ${DOXYGEN_IN}
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMENT "Generating API documentation with Doxygen"
    VERBATIM)
endif()
