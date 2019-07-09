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

// External C++ interface
extern (C++):
    interface SchemataApiCpp {
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
    void runSchemataCpp(SchemataApiCpp, CppStr);

// External C++ string implementation
extern (C++, CppString):
    struct CppBytes {
        void* ptr;
        int length;

        void destroy();
    }
    struct CppStr {
        void* cppStr;

        const(void)* ptr();
        int length();
        void destroy();
        void put(char);
    }
    CppBytes getBytes();
    CppStr getStr();
    CppStr createCppStr();


// External C++ types
extern (C++, CppType):
    struct SourceLoc {
        uint line;
        uint column;
    }
    struct Offset {
        uint begin;
        uint end;
    }
    struct SchemataMutant {
        SourceLoc loc;
        Offset offset;
        int inject;

        void print();
    }
    struct SchemataFile {
        CppStr fpath;
        SchemataMutant[] mutants;
        CppStr code;
    }
