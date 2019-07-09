/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

C++ types for easier communication between C++ and D code.
*/
#ifndef TYPE_CPP
#define TYPE_CPP

#include "cpp_string.hpp"

namespace CppType {

struct SourceLoc {
    unsigned int line;
    unsigned int column;
};
struct Offset {
    unsigned int begin;
    unsigned int end;
};
struct SchemataMutant {
    SourceLoc loc;
    Offset offset;
    int inject;

    void print();
};
struct SchemataFile {
    CppString::CppStr fpath;
    CppString::CppStr code;
    SchemataMutant mutants[];
};

}

#endif
