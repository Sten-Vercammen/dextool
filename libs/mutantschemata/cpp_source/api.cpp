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

void runSchemataCpp (SchemataApiCpp *sac){
    std::cout << "run schemata cpp" << std::endl;

    {
        // using CppBytes
        CppString::CppBytes cb_condition = CppString::getStr("id == 101", 9);
        SchemataMutant sm = sac->apiSelectMutant(cb_condition);

        // testprints
        std::cout << "SchemataMutant: " << std::endl;
        std::cout << "SourceLoc line: " << sm.loc.line << ", col: " << sm.loc.column << std::endl;
        std::cout << "Offset begin: " << sm.offset.begin << ", end: " << sm.offset.end << std::endl;
    }

    {
        // using CppStr
        CppString::CppStr cs_condition = CppString::getStr2("id == 101");
        SchemataMutant sm = sac->apiSelectMutant(cs_condition);

        // testprints
        std::cout << "SchemataMutant: " << std::endl;
        std::cout << "SourceLoc line: " << sm.loc.line << ", col: " << sm.loc.column << std::endl;
        std::cout << "Offset begin: " << sm.offset.begin << ", end: " << sm.offset.end << std::endl;
    }

    //sac->apiInsert(sm);
    //sac->apiInsert(sm);
}
