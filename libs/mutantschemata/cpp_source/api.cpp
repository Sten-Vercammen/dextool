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
#include <sstream>

void runSchemataCpp(SchemataApiCpp *sac, CppString::CppStr cs, CppString::CppStr ccdbPath, CppString::CppStr mainFile){
    std::cout << "here is: " << *cs.cppStr << std::endl;
    //llvm::errs() << "Usage: rewritersample <file,otherfile,...> includeDir workingDir\n";
    // return 1;
    char cstr[cs.cppStr->size()+1];
    strcpy(cstr, cs.cppStr->c_str());


    std::string buf;		// Have a buffer string
    std::stringstream ss(cstr);	// Insert the string into a stream

    std::vector<std::string> filesToMutate; // Create vector to hold our words
    while(getline(ss, buf, ',')) {
        filesToMutate.push_back(buf);
    }

    std::string compilationDatabasePath = ccdbPath.cppStr->c_str();

    // creating the strings we want in our fake argv
    std::vector<std::string> arguments = {"-p", compilationDatabasePath};
    arguments.insert(arguments.end(), filesToMutate.begin(), filesToMutate.end());

    // populate the fake argv
    std::vector<const char*> argv;
    for (const auto& arg : arguments) {
        argv.push_back((char*)arg.data());
    }
    argv.push_back(nullptr);

    // call setup of clang
    setupClang(argv.size() - 1, argv.data());
    fixMainFile(mainFile.cppStr->c_str());

    // Simple demonstration of how to create a SchemataMutant, set the variables and insert in database
    // NOTE: apiBuildMutant needs to be called (ONCE) in order to make sure the db has created the table
    /*
    CppType::SchemataMutant sm;
    sm.mut_id = 500;
    sm.loc = {4,5};
    sm.offset = {0,3};
    sm.status = 0;
    sac->apiBuildMutant();
    sac->apiInsertSchemataMutant(sm);
    sm.mut_id = 365;
    sm.status = 3;
    sac->apiInsertSchemataMutant(sm);
    */
}
