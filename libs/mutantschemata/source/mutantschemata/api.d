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

import mutantschemata.d_string: cppToD, dToCpp;
import mutantschemata.externals;
import mutantschemata.utility: findInclude;

import miniorm : Miniorm, buildSchema, delete_, insert, select;
import dextool.type: Path;
import dextool.plugin.mutate.backend.database: MutationPointTbl;
import dextool.compilation_db: CompileCommandDB;

import std.range: front;
import std.array: array, empty;

import logger = std.experimental.logger;

// Entry point for Dextool mutate
SchemataApi makeSchemataApi(Path db, CompileCommandDB ccdb) {
    SchemataApi sa = new SchemataApi(db, ccdb);
    return sa;
}
struct SchemataFileString {
    string fpath;
    SchemataMutant[] mutants;
    string code;
}
SchemataFileString convert(SchemataFile sf) {
    return SchemataFileString(cppToD!CppStr(sf.fpath),
                                sf.mutants,
                                cppToD!CppStr(sf.code));
}

// D class, connection to C++ code in /cpp_source
class SchemataApi: SchemataApiCpp {
    private Miniorm db;
    private CompileCommandDB ccdb;

    this(Path path, CompileCommandDB c) {
        ccdb = c;
        db = Miniorm(path);
    }
    // Override of functions in external interface
    extern (C++) void apiInsertSchemataMutant(SchemataMutant sm) {
        apiInsert!SchemataMutant(sm);
    }
    extern (C++) void apiInsertSchemataFile(SchemataFile sf){
        apiInsert!SchemataFileString(convert(sf));
    }
    extern (C++) SchemataMutant apiSelectSchemataMutant() {
        return sanitize(apiSelect!SchemataMutant());
    }
    extern (C++) SchemataMutant apiSelectSchemataMutant(CppBytes cb) {
        return sanitize(apiSelect!SchemataMutant(cppToD!CppBytes(cb)));
    }
    extern (C++) SchemataMutant apiSelectSchemataMutant(CppStr cs){
        return sanitize(apiSelect!SchemataMutant(cppToD!CppStr(cs)));
    }
    extern (C++) SchemataMutant apiSelectMutant() {
        return sanitize(apiSelect!MutationPointTbl());
    }
    extern (C++) SchemataMutant apiSelectMutant(CppBytes cb) {
        return sanitize(apiSelect!MutationPointTbl(cppToD!CppBytes(cb)));
    }
    extern (C++) SchemataMutant apiSelectMutant(CppStr cs) {
        return sanitize(apiSelect!MutationPointTbl(cppToD!CppStr(cs)));
    }
    extern (C++) void apiBuildMutant() {
        apiBuildSchema!SchemataMutant();
    }
    extern (C++) void apiBuildFile() {
        apiBuildSchema!SchemataFileString();
    }
    extern (C++) void apiDeleteMutant() {
        apiDelete!SchemataMutant();
    }
    extern (C++) void apiDeleteMutant(CppBytes cb) {
        apiDelete!SchemataMutant(cppToD!CppBytes(cb));
    }
    extern (C++) void apiDeleteMutant(CppStr cs) {
        apiDelete!SchemataMutant(cppToD!CppStr(cs));
    }
    extern (C++) void apiDeleteFile() {
        apiDelete!SchemataFileString();
    }
    extern (C++) void apiDeleteFile(CppBytes cb) {
        apiDelete!SchemataFileString(cppToD!CppBytes(cb));
    }
    extern (C++) void apiDeleteFile(CppStr cs) {
        apiDelete!SchemataFileString(cppToD!CppStr(cs));
    }
    extern (C++) CppStr apiFindInclude(CppStr cs_file, CppStr cs_include) {
        return dToCpp(findInclude(ccdb, Path(cppToD!CppStr(cs_file)), Path(cppToD!CppStr(cs_include))));
    }
    void apiInsert(T)(T t){
        db.run(insert!T.insert, t);
    }
    T[] apiSelect(T)(string condition = "") {
        auto query = (condition != "") ? db.run(select!T.where(condition)) : db.run(select!T);
        return query.array;
    }
    void apiBuildSchema(T)() {
        db.run(buildSchema!T);
    }
    void apiDelete(T)(string condition = "") {
        (condition != "") ? db.run(delete_!T.where(condition)) : db.run(delete_!T);
    }
    SchemataMutant sanitize(T)(T[] t) {
        return t.empty ? createSchemataMutant() : createSchemataMutant(t.front);
    }
    SchemataMutant createSchemataMutant() {
        return SchemataMutant(SourceLoc(0,0), Offset(0,0), -1);
    }
    SchemataMutant createSchemataMutant(SchemataMutant sm) {
        return sm;
    }
    SchemataMutant createSchemataMutant(MutationPointTbl mpt) {
        return SchemataMutant(SourceLoc(mpt.line, mpt.column), Offset(mpt.offset_begin, mpt.offset_end), -1);
    }
    void apiClose() {
        db.close();
    }

    // TODO: extend so that dextool mutate can send what type of mutants etc
    void runSchemata(Path file) {
        runSchemataCpp(this, dToCpp(file));
    }
}
