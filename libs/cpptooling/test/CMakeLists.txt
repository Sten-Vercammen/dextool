# vim: filetype=cmake

set(SRC_FILES
    ${CMAKE_CURRENT_LIST_DIR}/clang_util.d

    ${CMAKE_CURRENT_LIST_DIR}/component/scratch.d

    ${CMAKE_CURRENT_LIST_DIR}/component/generator.d

    ${CMAKE_CURRENT_LIST_DIR}/component/analyzer/cpp_class_visitor.d
    ${CMAKE_CURRENT_LIST_DIR}/component/analyzer/test_clang.d
    ${CMAKE_CURRENT_LIST_DIR}/component/analyzer/type.d
    ${CMAKE_CURRENT_LIST_DIR}/component/analyzer/utility.d

    ${CMAKE_CURRENT_LIST_DIR}/ut_main.d
)

set(flags "-I${CMAKE_SOURCE_DIR}/source -I${CMAKE_SOURCE_DIR}/libs/cpptooling/source -I${CMAKE_SOURCE_DIR}/libs/dextool/source -I${CMAKE_SOURCE_DIR}/libs/clang/source -I${CMAKE_SOURCE_DIR}/libs/libclang/source -I${CMAKE_SOURCE_DIR}/libs/dsrcgen/source -J${CMAKE_SOURCE_DIR}/libs/clang/resources -I${CMAKE_SOURCE_DIR}/vendor/taggedalgebraic/source -I${CMAKE_SOURCE_DIR}/vendor/blob_model/source")

compile_d_unittest(component "${SRC_FILES}" "${flags}" "" "dextool_cpptooling;dextool_blob_model")
