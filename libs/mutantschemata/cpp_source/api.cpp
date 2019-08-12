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
#include <cstring>

void runSchemataCpp(SchemataApiCpp *sac, CppString::CppStr cs){
    std::cout << "here is: " << *cs.cppStr << std::endl;
    //llvm::errs() << "Usage: rewritersample <file,otherfile,...> includeDir workingDir\n";
    // return 1;
    char cstr[cs.cppStr->size()+1];
    strcpy(cstr, cs.cppStr->c_str());




    //TODO fix these, these needs to be provided by the API
    std::string compilationDatabasePath = "/path/to/compilationDatabase";
    std::vector<std::string> filesToMutate = {"path", "relative", "or", "absolute"};


    // creating the strings we want in our fake argv
    std::vector<std::string> arguments = {"-p", compilationDatabasePath};
    arguments.insert(arguments.end(), filesToMutate.begin(), filesToMutate.end());

    // populate the fake argv
    std::vector<char*> argv;
    for (const auto& arg : arguments) {
        argv.push_back((char*)arg.data());
    }
    argv.push_back(nullptr);

    // call setup of clang
    setupClang(argv.size() - 1, argv.data());
}
