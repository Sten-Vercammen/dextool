/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

C++ types for easier communication between C++ and D code.
*/
#pragma once

#include "cpp_string.hpp"

namespace CppType {

struct SourceLoc {
    uint64_t line;
    uint64_t column;
};
struct Offset {
    uint64_t begin;
    uint64_t end;
};
struct SchemataMutant {
    uint64_t id;        // primary key for db, not used
    uint64_t mut_id;    // a way to differentiate each mutant (will be the same as x in "MUTANT_NR = x")
    SourceLoc loc;      // for reporting purposes, specifies which line the mutant is on and where it begins
    Offset offset;      // begin and end of where the insertion will be (Ex: a + b, the offset will specify where the + begins, and where it ends)
    //CppString::CppStr inject;     // the characters we want to insert instead of original expression (Ex: a + b -> a - b, then this variable will be "-")
    uint64_t status;    // status of the mutant (unknown, killed, alive, killedByCompiler, timeout)

    void print();
};
struct SchemataFile {
    CppString::CppStr fpath;
    CppString::CppStr code;
    SchemataMutant mutants[];
};

}
