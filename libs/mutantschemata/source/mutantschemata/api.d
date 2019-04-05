/**
Copyright: Copyright (c) 2017, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

/*
discussed earlier, this api should handle:
- filepath
- mutant[]
    - location
    - mutant kind (operator)
    - mutant_nr (injects)
    - code of mutant

Mutant schema provides:
- Code
- injects

Meant to function as an api for schemata using and providing schemata with db
*/

module mutantschemata.api;

import logger = std.experimental.logger;

import microrm;
import dextool.plugin.mutate.backend.type: Mutation, SourceLoc, Offset;

import dextool.type: Path;


struct SchemataMutant {
    SourceLoc loc;
    Offset offset; // necessary?
    Mutation mut;
    int inject;
    // string code; //could be stored in SchemataFile (same for all mutants in one file)
}

struct SchemataFile {
    SchemataMutant[] mutants;
    Path fpath;
    string code;
}

enum apiSchema = buildSchema!(SchemataFile);

struct API {
    private Path fpath;
    private Mutation[] ops;
    private Microrm db;

    this(Path filepath, Mutation[] operators, string dbpath){
        this.fpath = filepath;
        this.ops = operators;
        this.db = Microrm(dbpath);
    }

    Path getFilepath(){
        return this.fpath;
    }

    Mutation[] getOperators(){
        return this.ops;
    }

    /* check clang_extensions for example
    void generateMutants(SchemataFile sf){
        extern (C++) void runSchemata(Path sf.fpath);
    }
    */
}
