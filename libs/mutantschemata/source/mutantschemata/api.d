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

// imports for easier testing
import std.conv : text, to;
import std.range;
import std.algorithm;
import std.array;
import std.stdio;

import logger = std.experimental.logger;

import microrm.exception;
import microrm.queries;
import microrm.schema;
import dextool.type: Path;

import dextool.plugin.mutate.backend.type: Mutation, SourceLoc, Offset;
import dextool.plugin.mutate.backend.database.schema: MutationTbl, MutationPointTbl;

struct SchemataMutant {
    SourceLoc loc;
    Offset offset; // necessary?
    Mutation mut;
    int inject;
    // string code; //could be stored in SchemataFile (same for all mutants in one file)
}
struct SchemataFile {
    Path fpath;
    SchemataMutant[] mutants;
    int[] inject;
}

SchemataApi makeSchemata(Path db){
    SchemataApi sa = new SchemataApi(db);
    return sa;
}

// C++ interface
extern (C++) interface SchemataApiCpp {
    void apiInsert();
    void apiSelect();
}

// Extern C++ function callable by D-files
extern (C++) void runSchemataCpp(SchemataApiCpp);

// D class callable by C++ code
class SchemataApi: SchemataApiCpp {
    struct TestStruct {
        int x;
        int y;
    }
    private Microrm db;

    this(string path){
        db = Microrm(path);
        db.run(buildSchema!TestStruct);
        db.run(delete_!TestStruct);
    }
    extern (C++) void apiInsert(){
        import std.random;
        auto rnd = Random(unpredictableSeed);
        writeln("inserting!");
        db.run(insert!TestStruct.insert, TestStruct(uniform(0, 1024, rnd), uniform(0, 1024, rnd)));
    }
    extern (C++) void apiSelect(){
        apiSelect!(TestStruct);
        apiSelect!(MutationPointTbl, "id == 100");
    }
    auto apiSelect(T)(){
        writeln("selecting!");
        auto res = db.run(select!T).array;
        foreach (r; res){
            writeln(r);
        }
        return res;
    }
    void apiSelect(T, string condition)(){
        writeln("selecting with condition!");
        auto res = db.run(select!(T).where(condition)).array;
        foreach (r; res){
            writeln(r);
        }
    }
    void runSchemata(Path file){
        runSchemataCpp(this);
    }
    void apiClose(){
        db.close();
    }
    // TODO: need to use mutant and not TestStruct
}
