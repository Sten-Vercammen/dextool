/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

Headerfile for api.cpp
C++ part of the SchemataApi. Meant to be used by the Mutant Schemata C++ library
in order to call D code and insert/select mutants from db obtained from Dextool mutate.
*/
#pragma once

#include "type.hpp"
#include "cpp_string.hpp"

class SchemataApiCpp {
public:
    virtual void apiInsertSchemataMutant(CppType::SchemataMutant);
    virtual void apiInsertSchemataFile(CppType::SchemataFile);
    virtual CppType::SchemataMutant apiSelectSchemataMutant(CppString::CppStr);
    virtual void apiBuildMutant();
    virtual void apiBuildFile();
    virtual void apiDeleteMutant(CppString::CppStr);
    virtual void apiDeleteFile(CppString::CppStr);
    virtual CppString::CppStr apiFindInclude(CppString::CppStr, CppString::CppStr);
    virtual void apiClose();
};

void runSchemataCpp (SchemataApiCpp, CppString::CppStr, CppString::CppStr/*, CppString::CppStr*/);
