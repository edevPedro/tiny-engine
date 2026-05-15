# CMake generated Testfile for 
# Source directory: /Users/epedro/eCodes/zedia/sistemas-2
# Build directory: /Users/epedro/eCodes/zedia/sistemas-2/build
# 
# This file includes the relevant testing commands required for 
# testing this directory and lists subdirectories to be tested as well.
add_test([=[test_input_map]=] "/Users/epedro/eCodes/zedia/sistemas-2/build/test_input_map")
set_tests_properties([=[test_input_map]=] PROPERTIES  _BACKTRACE_TRIPLES "/Users/epedro/eCodes/zedia/sistemas-2/CMakeLists.txt;141;add_test;/Users/epedro/eCodes/zedia/sistemas-2/CMakeLists.txt;0;")
add_test([=[test_lua_bindings]=] "/Users/epedro/eCodes/zedia/sistemas-2/build/test_lua_bindings")
set_tests_properties([=[test_lua_bindings]=] PROPERTIES  _BACKTRACE_TRIPLES "/Users/epedro/eCodes/zedia/sistemas-2/CMakeLists.txt;142;add_test;/Users/epedro/eCodes/zedia/sistemas-2/CMakeLists.txt;0;")
subdirs("_deps/glfw-build")
subdirs("_deps/sdl2-build")
subdirs("_deps/glad-build")
subdirs("_deps/spng-build")
