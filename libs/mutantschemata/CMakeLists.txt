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
target_link_libraries(dextool_mutantschemata_cpp_source)

### The D-library
file(GLOB_RECURSE SRC_FILES ${CMAKE_CURRENT_LIST_DIR}/source/mutantschemata/*.d)
set(flags "-I${CMAKE_CURRENT_LIST_DIR}/source -I${CMAKE_SOURCE_DIR}/source -I${CMAKE_SOURCE_DIR}/clang -I${CMAKE_SOURCE_DIR}/libclang -I${CMAKE_SOURCE_DIR}/plugin/source -I${CMAKE_SOURCE_DIR}/vendor/d2sqlite3/source -I${CMAKE_SOURCE_DIR}/vendor/sumtype/src -I${CMAKE_SOURCE_DIR}/libs/microrm/source -I${CMAKE_SOURCE_DIR}/plugin/mutate/source")
set(deps "dextool_d2sqlite3;dextool_sumtype;dextool_microrm;dextool_mutantschemata_cpp_source")

compile_d_static_lib(dextool_mutantschemata "${SRC_FILES}" "${flags}" "" "${deps}")

#list(APPEND SRC_FILES
#    ${CMAKE_CURRENT_LIST_DIR}/ut_main.d
#)

#compile_d_unittest(microrm "${SRC_FILES}" "${flags}" "" "${deps}")
