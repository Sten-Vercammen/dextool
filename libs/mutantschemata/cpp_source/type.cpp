/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

C++ types for easier communication between C++ and D code.
*/
#include "type.hpp"
#include <iostream>

namespace CppType {

void SchemataMutant::print(){
    std::cout << "SchemataMutant: " << std::endl;
    std::cout << "id: " << id << std::endl;
    std::cout << "SourceLoc line: " << loc.line << ", col: " << loc.column << std::endl;
    std::cout << "Offset begin: " << offset.begin << ", end: " << offset.end << std::endl;
    std::cout << "Inject: " << inject << std::endl;
}

}
