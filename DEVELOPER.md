# vim: filetype=markdown

This file contains information useful to a developer of Dextool.

# Setup
Compared to a normal installation of Dextool a developer have additional needs
such as compiling a full debug build (contracts activated) and compiling the
tests.

Example:
```sh
mkdir build
cd build
# to run with coverage add -DTEST_WITH_COV=ON. Coverage is found in build/coverage
cmake -Wdev -DCMAKE_BUILD_TYPE=Debug -DBUILD_TEST=ON ..
```

This gives access to the make target _test_.

To run the tests:
```sh
# build and run the unit tests
make check

# build and run the integration tests
make check_integration
```

# API Documentation

This describes how to build the API documentation for Dextool (all plugins and the support libraries).

Re-configure cmake with the documentation directive on:
```sh
cd build
cmake -DBUILD_DOC=ON ..
```

For the documentation tool to run it requires that dmd has created the `.json` files with type information. This is done by rebuilding all modules:
```sh
make clean
make all
```

Now lets generate the documentation with the tool.
```sh
./tools/build_doc.d --ddox
```

If you do not have access to internet, remove the `--ddox` parameter.

# Plugin Test Strategy

## C/C++ Test Double Generator
The strategy for the test doubles is divided into three stages.

1. Test code generation for different aspects of the languages.
    The focus isn't on the functional aspects but rather that the generated test doubles are "correct". Correct as in C/C++ code that compiles and
    "looks good" to a human.
2. Test the parameters and other types of user-defined input.
    How it affects generated test doubles.
3. Test the functional aspects of the generated test doubles.
    Does the adapter work?
    Is the generated google mock definition possible to use with the adapter?
    Is the behavior of the test double what the user needs?

# Design of Component Tests

The idea is that individual unit tests are spread out in the program. As it
should be in idiomatic D.

The testing of multiple components is to be kept separate from the unit
tests. For the following reasons:
 - I foresee that the component tests will increase the time it takes to run
   the whole test suite. By keeping component tests in one place, it is easy to
   split them off to a separate binary to enable a fast write-compile-test
   cycle with "fast" tests while keeping the "slow" tests for the automated CI
   of PR's.
 - Unit tests are placed within the tested unit, while component tests do not
   fit inside a single unit.

# Definitions

## Unit tests
Tests in a D module. It can be everything from individual functions to multiple
classes. But it must be within the same module.

 - See plugin/xyz/ut_main.d

## CI
Continues Integration

## Component tests
Functional tests of multiple D modules.

 - See source/test/component

## Integration tests
Test the final binaries behavior from the users perspective. An example would be
"golden file"-tests.

 - See plugin/xyz/test/integration.d
 - See test/integration_main.d

## PR

Pull Request
