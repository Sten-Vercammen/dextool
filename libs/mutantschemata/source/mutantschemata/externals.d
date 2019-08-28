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
        /*SchemataMutant apiSelectMutant();
        SchemataMutant apiSelectMutant(CppBytes);
        SchemataMutant apiSelectMutant(CppStr);*/
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
    void runSchemataCpp(SchemataApiCpp, CppStr, CppStr, CppStr);

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
        ulong line;
        ulong column;
    }
    struct Offset {
        ulong begin;
        ulong end;
    }
    struct SchemataMutant {
        int id;         // a way to differentiate each mutant (will be the same as x in "MUTANT_NR = x")
        SourceLoc loc;  // for reporting purposes, specifies which line the mutant is on and where it begins
        Offset offset;  // begin and end of where the insertion will be (Ex: a + b, the offset will specify where the + begins, and where it ends)
        //CppStr inject;  // the characters we want to insert instead of original expression (Ex: a + b -> a - b, then this variable will be "-")

        void print();   // helperfunction, only for printing when testing
    }
    struct SchemataFile {
        CppStr fpath;
        SchemataMutant[] mutants;
        CppStr code;
    }
