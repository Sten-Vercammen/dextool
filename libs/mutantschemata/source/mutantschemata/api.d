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

import microrm.exception;
import microrm.queries;
import microrm.schema;
/*import dextool.plugin.mutate.backend.type: Mutation, SourceLoc, Offset;

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
}*/

struct TestStruct {
    int x;
    int y;
}

// imports for easier testing as of now
import std.conv : text, to;
import std.range;
import std.algorithm;
import std.array;
import std.stdio;

// Extern D functions callable by .cpp-files
extern (C++) int externInsert(){
    API api = API("Totally_test_db");
    return api.insertAPI();
}

extern (C++) void externSelect(){
    API api = API("Totally_test_db");
    api.selectAPI();
}

// Extern C++ function callable by D-files
extern (C++) void runSchemata();

void schemata(){
    runSchemata();
}

struct API {

    //private Path fpath;
    //private Mutation[] ops;
    private Microrm db;

    this(string dbpath){
        db = Microrm(dbpath);
        db.run(buildSchema!TestStruct);
    }

    int insertAPI(){
        // testcode for interfacing with c++ code and microrm
        writeln("inserting!");
        db.run(delete_!TestStruct);

        for (int i = 0; i < 10; i++){
            for (int j = 0; j < 10; j++){
                db.run(insert!TestStruct.insert, TestStruct(i, j));
            }
        }
        return 0;
    }

    void selectAPI(){
        // testcode for interfacing with c++ code and microrm
        writeln("selecting!");

        auto tests = db.run(select!TestStruct).array;

        foreach (t; tests){
            writeln(t);
        }
    }
    /*
    this(Path filepath, Mutation[] operators, string dbpath){
        this.fpath = filepath;
        this.ops = operators;
        this.db = Microrm(dbpath);
    }*/

    /*
    Path getFilepath(){
        return this.fpath;
    }

    Mutation[] getOperators(){
        return this.ops;
    }*/
}
