/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

String implementation for sending strings back and forth between D and C++
*/
module mutantschemata.d_string;

import std.stdio;
import std.typecons: RefCounted;
import core.memory: pureFree;
import std.utf: validate;

// the reciever is responsible for deleting the ptr with free
extern (C++, CppString) {
    extern (C++) struct CppBytes {
        void* ptr;
        int length;

        void destroy();
    }
    extern (C++) struct CppStr {
        void* cppStr;

        const(void)* ptr();
        int length();
        void destroy();
    }
    extern (C++) CppBytes getStr();
    extern (C++) CppStr getStr2();
}

struct CppPayload(T) {
    T data;
    alias data this;

    ~this() {
        data.destroy;
    }
}
auto getDString(T)(T t){
    auto cp = RefCounted!(CppPayload!T)(t);

    // if this passes it is OK to duplicate and cast to a D string
    validate(cast(string) cp.refCountedPayload.ptr[0 .. cp.length]);

    return cast(string)(cp.refCountedPayload.ptr[0 .. cp.length].idup);
}
