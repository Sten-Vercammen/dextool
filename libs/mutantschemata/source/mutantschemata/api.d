/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
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

import mutantschemata.d_string;

import microrm;
import dextool.type: Path;
import dextool.plugin.mutate.backend.database.schema: MutationPointTbl;

import logger = std.experimental.logger;

// TODO: clean up imports
import std.conv : text, to;
import std.range;
import std.algorithm;
import std.array;
import std.stdio;

/* External C++ structs */
extern (C++) struct SourceLoc {
    uint line;
    uint column;
}
extern (C++) struct Offset {
    uint offset_begin;
    uint offset_end;
}
extern (C++) struct SchemataMutant {
    SourceLoc loc;
    Offset offset;
    int inject;
}
// External C++ interface
extern (C++) interface SchemataApiCpp {
    void apiInsert();
    SchemataMutant apiSelectMutant();
    SchemataMutant apiSelectMutant(CppBytes);
    SchemataMutant apiSelectMutant(CppStr);
}
// External C++ functions
extern (C++) void runSchemataCpp(SchemataApiCpp);

// Entry point for Dextool mutate
SchemataApi makeSchemata(Path db){
    writeln("make schemata");
    SchemataApi sa = new SchemataApi(db);
    return sa;
}

// D class, connection to C++ code in /cpp_source
class SchemataApi: SchemataApiCpp {
    // TODO: remove testStruct after Insert is further developed
    struct TestStruct {
        int x;
        int y;
    }
    private Microrm db;

    this(string path) {
        db = Microrm(path);
        db.run(buildSchema!TestStruct);
        db.run(delete_!TestStruct);
    }
    extern (C++) void apiInsert() {
        import std.random;
        auto rnd = Random(unpredictableSeed);
        writeln("inserting!");
        db.run(insert!TestStruct.insert, TestStruct(uniform(0, 1024, rnd), uniform(0, 1024, rnd)));
    }
    extern (C++) SchemataMutant apiSelectMutant() {
        return selectMpt();
    }
    extern (C++) SchemataMutant apiSelectMutant(CppBytes cb) {
        return selectMpt(getDString!CppBytes(cb));
    }
    extern (C++) SchemataMutant apiSelectMutant(CppStr cs) {
        return selectMpt(getDString!CppStr(cs));
    }
    SchemataMutant selectMpt(string condition = ""){
        auto res = apiSelect!MutationPointTbl(condition);
        auto front = res.front;

        return createSchemataMutant(front);
    }
    T[] apiSelect(T)(string condition = "") {
        auto query = (condition != "") ? db.run(select!T.where(condition)) : db.run(select!T);

        return query.array;
    }
    SchemataMutant createSchemataMutant(MutationPointTbl mpt){
        return SchemataMutant(SourceLoc(mpt.line, mpt.column), Offset(mpt.offset_begin, mpt.offset_end), -1);
    }
    void runSchemata(Path file){
        runSchemataCpp(this);
    }
    void apiClose(){
        db.close();
    }
}
