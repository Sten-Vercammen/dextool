/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.


Types created for specific use in the mutant schemata API
*/
module mutantschemata.type;

import std.typecons: Tuple;

import mutantschemata.externals;

import dextool.type: AbsolutePath;
import dextool.compilation_db: CompileCommandDB;

struct SchemataFileString {
    string fpath;
    SchemataMutant[] mutants;
    string code;
}

struct SchemataInformation {
    AbsolutePath databasePath;
    CompileCommandDB compileCommand;
    AbsolutePath compileCommandPath;
    bool isActive;

    this (AbsolutePath db, CompileCommandDB ccdb, AbsolutePath ccdbPath, bool active) @safe {
        this.databasePath = db;
        this.compileCommand = ccdb;
        this.compileCommandPath = ccdbPath;
        this.isActive = active;
    }
}

const string MUTANT_NR = "MUTANT_NR";

alias execVal = Tuple!(int, "status", string, "output");
