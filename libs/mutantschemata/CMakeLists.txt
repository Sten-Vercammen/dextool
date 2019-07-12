# vim: filetype=cmake

# the C++ library
set(dextool_mutantschemata_cpp_source_SRC
    ${CMAKE_CURRENT_LIST_DIR}/cpp_source/api.cpp
    ${CMAKE_CURRENT_LIST_DIR}/cpp_source/type.cpp
    ${CMAKE_CURRENT_LIST_DIR}/cpp_source/cpp_string.cpp
)
add_library(dextool_mutantschemata_cpp_source STATIC ${dextool_mutantschemata_cpp_source_SRC})
set_target_properties(dextool_mutantschemata_cpp_source PROPERTIES
    COMPILE_FLAGS "${LIBLLVM_CXX_FLAGS} -O2 -g -I${CMAKE_CURRENT_LIST_DIR}/cpp_source"
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/
    )
# add clang libs
target_link_libraries(dextool_mutantschemata_cpp_source
  clangTooling
  clangFrontendTool
  clangFrontend
  clangDriver
  clangSerialization
  clangCodeGen
  clangParse
  clangSema
  clangStaticAnalyzerFrontend
  clangStaticAnalyzerCheckers
  clangStaticAnalyzerCore
  clangAnalysis
  clangARCMigrate
  clangRewrite
  clangRewriteFrontend
  clangEdit
  clangAST
  clangLex
  clangBasic
  clang
)

### The D-library
file(GLOB_RECURSE SRC_FILES ${CMAKE_CURRENT_LIST_DIR}/source/mutantschemata/*.d)
set(flags "-I${CMAKE_CURRENT_LIST_DIR}/source
    -I${CMAKE_SOURCE_DIR}/libs/dextool/source
    -I${CMAKE_SOURCE_DIR}/libs/clang/source
    -I${CMAKE_SOURCE_DIR}/libs/libclang/source
    -I${CMAKE_SOURCE_DIR}/plugin/mutate/source
    -I${CMAKE_SOURCE_DIR}/vendor/d2sqlite3/source
    -I${CMAKE_SOURCE_DIR}/vendor/sumtype/src
    -I${CMAKE_SOURCE_DIR}/vendor/miniorm/source
    -I${CMAKE_SOURCE_DIR}/libs/dextool_clang_extensions/source
    -I${CMAKE_SOURCE_DIR}/vendor/cachetools/source
    -I${CMAKE_SOURCE_DIR}/vendor/arsd"
)

set(deps "dextool_mutantschemata_cpp_source;dextool_d2sqlite3;dextool_sumtype;dextool_miniorm")

compile_d_static_lib(dextool_mutantschemata "${SRC_FILES}" "${flags}" "" "${deps}")
