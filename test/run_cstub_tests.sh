#!/bin/bash
set -e

C_NONE='\e[m'
C_RED='\e[1;31m'
C_YELLOW='\e[1;33m'
C_GREEN='\e[1;32m'

source ./func_tests.sh

# Test strategy.
# Stage 1. Generation.
#  - Test stub generation of varying difficulty. The principal is a golden file that the result is compared to.
#  - Test compiling generated code with gcc. Generated binary and execute.
# Stage 2. Distributed.
#  - Test stub generation of many files, both including and excluding.
#  Stage 3. Functionality.
#  - Implement tests that uses the generated stubs.

setup_test_env
TOOL_BIN="$TOOL_BIN ctestdouble"

echo "Stage 1"
ROOT_DIR="testdata/cstub/stage_1"
for IN_SRC in $ROOT_DIR/*.h; do
    inhdr_base=$(basename ${IN_SRC})
    out_hdr="$OUTDIR/test_double.hpp"
    out_impl="$OUTDIR/test_double.cpp"

    case "$IN_SRC" in
        *param_main*)
            test_gen_code "$OUTDIR" "$ROOT_DIR/$inhdr_base" "--debug --main=Stub"
            out_hdr="$OUTDIR/stub.hpp"
            out_impl="$OUTDIR/stub.cpp"
            ;;
        *test_include_stdlib*)
            test_gen_code "$OUTDIR" "$ROOT_DIR/$inhdr_base" "--debug" "" "-nostdinc"
            ;;
        # Test examples
        # *somefile*)
        #     test_gen_code "$OUTDIR" "$IN_SRC" "--debug" "|& grep -i $grepper"
        # ;;
        *)
            test_gen_code "$OUTDIR" "$ROOT_DIR/$inhdr_base" "--debug" ;;
    esac

    case "$IN_SRC" in
        *)
            test_compare_code "${IN_SRC%.h}.hpp.ref" "$out_hdr" "${IN_SRC%.h}.cpp.ref" "$out_impl" ;;
    esac

    case "$IN_SRC" in
        # *functions*)
        #     test_compile_code "$OUTDIR" "-Itestdata/cstub/stage_1" "$out_impl" main1.cpp "-Wpedantic" ;;
        # *variables*) ;;
        # Compile examples
        *)
            test_compile_code "$OUTDIR" "-Itestdata/cstub/stage_1" "$out_impl" main1.cpp "-Wpedantic -Werror" ;;
    esac

    clean_test_env
done

echo "Stage 2"
INCLUDES="-Itestdata/cstub/stage_2 -Itestdata/cstub/stage_2/include"
ROOT_DIR="testdata/cstub/stage_2"
for IN_SRC in $ROOT_DIR/*.h; do
    inhdr_base=$(basename ${IN_SRC})
    out_hdr="$OUTDIR/test_double.hpp"
    out_impl="$OUTDIR/test_double.cpp"

    case "$IN_SRC" in
        *param_exclude_one_file*)
            test_gen_code "$OUTDIR" "$ROOT_DIR/$inhdr_base" "--debug --file-exclude=.*/$inhdr_base" "" "$INCLUDES"
            ;;
        *param_exclude_many_files*)
            test_gen_code "$OUTDIR" "$ROOT_DIR/$inhdr_base" "--debug --file-exclude=.*/$inhdr_base --file-exclude='.*/include/b\.[h,c]'" "" "$INCLUDES"
            ;;
        *param_restrict*)
            test_gen_code "$OUTDIR" "$ROOT_DIR/$inhdr_base" "--debug --file-restrict=.*/$inhdr_base --file-restrict=.*/include/b.h" "" "$INCLUDES"
            ;;
        *param_include*)
            test_gen_code "$OUTDIR" "$ROOT_DIR/$inhdr_base" "--debug --td-include=b.h --td-include=stdio.h" "" "$INCLUDES"
            ;;
        *) ;;
    esac

    test_compare_code "${IN_SRC%.h}.hpp.ref" "$out_hdr" "${IN_SRC%.h}.cpp.ref" "$out_impl"

    test_compile_code "$OUTDIR" "$INCLUDES" "$out_impl" main1.cpp

    clean_test_env
done

teardown_test_env

exit 0
