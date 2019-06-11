/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

All the external items used in the api between C++ and D code
*/
module mutantschemata.externals;

// External C++ string implementation
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
        void put(char);
    }
    extern (C++) CppBytes getBytes();
    extern (C++) CppStr getStr();
    extern (C++) CppStr createCppStr();
}

// External C++ types
extern (C++, CppType) {
    extern (C++) struct SourceLoc {
        uint line;
        uint column;
    }
    extern (C++) struct Offset {
        uint begin;
        uint end;
    }
    extern (C++) struct SchemataMutant {
        SourceLoc loc;
        Offset offset;
        int inject;

        void print();
    }
    extern (C++) struct SchemataFile {
        CppStr fpath;
        SchemataMutant[] mutants;
        CppStr code;
    }
}

// External C++ interface
extern (C++) interface SchemataApiCpp {
    void apiInsertSchemataMutant(SchemataMutant);
    void apiInsertSchemataFile(SchemataFile);
    SchemataMutant apiSelectSchemataMutant();
    SchemataMutant apiSelectSchemataMutant(CppBytes);
    SchemataMutant apiSelectSchemataMutant(CppStr);
    SchemataMutant apiSelectMutant();
    SchemataMutant apiSelectMutant(CppBytes);
    SchemataMutant apiSelectMutant(CppStr);
    void apiBuildMutant();
    void apiBuildFile();
    void apiDeleteMutant(CppBytes);
    void apiDeleteMutant(CppStr);
    void apiDeleteMutant(CppBytes);
    void apiDeleteFile();
    void apiDeleteFile(CppBytes);
    void apiDeleteFile(CppBytes);
    CppStr apiFindInclude(CppStr, CppStr);
}

// External C++ functions
extern (C++) void runSchemataCpp(SchemataApiCpp, CppStr);