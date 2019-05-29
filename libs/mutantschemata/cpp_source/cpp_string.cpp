/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

String implementation for sending strings back and forth between D and C++
*/
#include "cpp_string.hpp"

namespace CppString {

void CppBytes::destroy() {
    delete[] ptr;
}
const void* CppStr::ptr() {
    return cppStr->c_str();
}
int CppStr::length() {
    return cppStr->size();
}
void CppStr::destroy() {
    delete cppStr;
}
void CppStr::put(char c){
    cppStr->append(ONE_CHARACTER, c);
}
CppBytes getBytes(const char* text, int length) {
    CppBytes r;

    r.ptr = new uint8_t[length];
    r.length = length;

    memcpy(r.ptr, text, length);

    return r;
}
CppStr getStr(const char* text) {
    CppStr r;
    r.cppStr = new std::string(text);

    return r;
}
CppStr createCppStr(){
    return getStr("");
}

} // CppString
