/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

C++ part of the SchemataApi. Meant to be used by the Mutant Schemata C++ library
in order to call D code and insert/select mutants from db obtained from Dextool mutate.
*/
#include "api.hpp"
#include "rewrite.hpp"

#include <iostream>

void runSchemataCpp(SchemataApiCpp *sac, CppString::CppStr cs){
    CppString::CppStr include = CppString::getStr("fibonacci_example.hpp"); // the file included with "#include "fibonacci_example.hpp""
    std::cout << "trying findInclude from Cpp-side" << std::endl;
    CppString::CppStr res = sac->apiFindInclude(cs, include);
    std::cout << *res.cppStr << std::endl;

    // temporary tests
    {   // using CppBytes
        sac->apiBuildMutant();
        CppType::SchemataMutant before_edit = sac->apiSelectMutant(CppString::getBytes("id == 101", 9));

        // change inject and insert
        before_edit.inject = 5;
        sac->apiInsertSchemataMutant(before_edit);

        // select updated mutant
        CppType::SchemataMutant after_edit = sac->apiSelectSchemataMutant(CppString::getBytes("\"loc.line\" = 14", 15));

        after_edit.print();
    }
    {   // using CppStr
        sac->apiBuildMutant();
        CppType::SchemataMutant before_edit = sac->apiSelectMutant(CppString::getStr("id == 101"));

        // change inject and insert
        before_edit.inject = 97;
        before_edit.loc.line = 900;
        sac->apiInsertSchemataMutant(before_edit);

        // select updated mutant
        CppType::SchemataMutant after_edit = sac->apiSelectSchemataMutant(CppString::getStr("\"loc.line\" = 900"));

        after_edit.print();
    }
}
