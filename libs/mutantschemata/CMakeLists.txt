# vim: filetype=cmake

file(GLOB_RECURSE SRC_FILES ${CMAKE_CURRENT_LIST_DIR}/source/mutantschemata/*.d)

set(flags "-I${CMAKE_CURRENT_LIST_DIR}/source -I${CMAKE_SOURCE_DIR}/source -I${CMAKE_SOURCE_DIR}/clang -I${CMAKE_SOURCE_DIR}/libclang -I${CMAKE_SOURCE_DIR}/plugin/source -I${CMAKE_SOURCE_DIR}/vendor/d2sqlite3/source -I${CMAKE_SOURCE_DIR}/vendor/sumtype/src -I${CMAKE_SOURCE_DIR}/libs/microrm/source -I${CMAKE_SOURCE_DIR}/plugin/mutate/source/ -I${CMAKE_SOURCE_DIR}/source")
set(deps "dextool_d2sqlite3;dextool_sumtype;dextool_microrm;dextool_mutate")

compile_d_static_lib(dextool_mutantschemata "${SRC_FILES}" "${flags}" "" "${deps}")

#list(APPEND SRC_FILES
#    ${CMAKE_CURRENT_LIST_DIR}/ut_main.d
#)

#compile_d_unittest(microrm "${SRC_FILES}" "${flags}" "" "${deps}")
