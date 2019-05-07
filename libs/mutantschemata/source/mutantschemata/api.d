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
import mutantschemata.externals;

import microrm.exception;
import microrm.queries;
import microrm.schema;
import dextool.type: Path;
import dextool.plugin.mutate.backend.database.schema: MutationPointTbl;

import logger = std.experimental.logger;

// TODO: clean up imports
import std.conv : text, to;
import std.range;
import std.algorithm;
import std.array;
import std.stdio;

// Entry point for Dextool mutate
SchemataApi makeSchemataApi(Path db) {
    SchemataApi sa = new SchemataApi(db);
    return sa;
}
struct SchemataFileString {
    string fpath;
    SchemataMutant[] mutants;
    string code;
}
SchemataFileString convert(SchemataFile sf) {
    return SchemataFileString(getDString!CppStr(sf.fpath),
                                sf.mutants,
                                getDString!CppStr(sf.code));
}

// D class, connection to C++ code in /cpp_source
class SchemataApi: SchemataApiCpp {
    private Microrm db;

    this(string path) {
        db = Microrm(path);
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
        return sanitize(apiSelect!SchemataMutant(getDString!CppBytes(cb)));
    }
    extern (C++) SchemataMutant apiSelectSchemataMutant(CppStr cs){
        return sanitize(apiSelect!SchemataMutant(getDString!CppStr(cs)));
    }
    extern (C++) SchemataMutant apiSelectMutant() {
        return sanitize(apiSelect!MutationPointTbl());
    }
    extern (C++) SchemataMutant apiSelectMutant(CppBytes cb) {
        return sanitize(apiSelect!MutationPointTbl(getDString!CppBytes(cb)));
    }
    extern (C++) SchemataMutant apiSelectMutant(CppStr cs) {
        return sanitize(apiSelect!MutationPointTbl(getDString!CppStr(cs)));
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
        apiDelete!SchemataMutant(getDString!CppBytes(cb));
    }
    extern (C++) void apiDeleteMutant(CppStr cs) {
        apiDelete!SchemataMutant(getDString!CppStr(cs));
    }
    extern (C++) void apiDeleteFile() {
        apiDelete!SchemataFileString();
    }
    extern (C++) void apiDeleteFile(CppBytes cb) {
        apiDelete!SchemataFileString(getDString!CppBytes(cb));
    }
    extern (C++) void apiDeleteFile(CppStr cs) {
        apiDelete!SchemataFileString(getDString!CppStr(cs));
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
    void apiDelete(T)(string condition = ""){
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
    // TODO: extend so that dextool mutate can send what type of mutants etc
    void runSchemata(Path file) {
        runSchemataCpp(this);
    }
    void apiClose() {
        db.close();
    }
}
