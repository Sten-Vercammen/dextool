/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

Headerfile for cpp_string.cpp
String implementation for sending strings back and forth between D and C++
*/
#include <stdint.h>
#include <string.h>
#include <string>

namespace CppString {

struct CppBytes {
    uint8_t* ptr;
    int32_t length;

    void destroy();
};
struct CppStr{
    std::string* cppStr;

    const void* ptr();
    int length();
    void destroy();
};
CppBytes getStr();
CppStr getStr2();

} // CppString
