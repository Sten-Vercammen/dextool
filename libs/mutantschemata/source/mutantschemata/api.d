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
import mutantschemata.utility: findInclude, sanitize;
import mutantschemata.db_handler;

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
extern (C++) class SchemataApi: SchemataApiCpp {
    private DBHandler handler;
    private CompileCommandDB ccdb;

    this(Path dbPath, CompileCommandDB c) {
        handler = DBHandler(dbPath);
        ccdb = c;
    }
    // Override of functions in external interface
    //extern (C++)
    void apiInsertSchemataMutant(SchemataMutant sm) {
        handler.insertFromDB!SchemataMutant(sm);
    }
    //extern (C++)
    void apiInsertSchemataFile(SchemataFile sf){
        handler.insertFromDB!SchemataFileString(convert(sf));
    }
    //extern (C++)
    SchemataMutant apiSelectSchemataMutant() {
        return sanitize(handler.selectFromDB!SchemataMutant());
    }
    //extern (C++)
    SchemataMutant apiSelectSchemataMutant(CppBytes cb) {
        return sanitize(handler.selectFromDB!SchemataMutant(cppToD!CppBytes(cb)));
    }
    //extern (C++)
    SchemataMutant apiSelectSchemataMutant(CppStr cs){
        return sanitize(handler.selectFromDB!SchemataMutant(cppToD!CppStr(cs)));
    }
    //extern (C++)
    SchemataMutant apiSelectMutant() {
        return sanitize(handler.selectFromDB!MutationPointTbl());
    }
    //extern (C++)
    SchemataMutant apiSelectMutant(CppBytes cb) {
        return sanitize(handler.selectFromDB!MutationPointTbl(cppToD!CppBytes(cb)));
    }
    //extern (C++)
    SchemataMutant apiSelectMutant(CppStr cs) {
        return sanitize(handler.selectFromDB!MutationPointTbl(cppToD!CppStr(cs)));
    }
    //extern (C++)
    void apiBuildMutant() {
        handler.buildSchemaDB!SchemataMutant();
    }
    //extern (C++)
    void apiBuildFile() {
        handler.buildSchemaDB!SchemataFileString();
    }
    //extern (C++)
    void apiDeleteMutant() {
        handler.deleteInDB!SchemataMutant();
    }
    //extern (C++)
    void apiDeleteMutant(CppBytes cb) {
        handler.deleteInDB!SchemataMutant(cppToD!CppBytes(cb));
    }
    //extern (C++)
    void apiDeleteMutant(CppStr cs) {
        handler.deleteInDB!SchemataMutant(cppToD!CppStr(cs));
    }
    //extern (C++)
    void apiDeleteFile() {
        handler.deleteInDB!SchemataFileString();
    }
    //extern (C++)
    void apiDeleteFile(CppBytes cb) {
        handler.deleteInDB!SchemataFileString(cppToD!CppBytes(cb));
    }
    //extern (C++)
    void apiDeleteFile(CppStr cs) {
        handler.deleteInDB!SchemataFileString(cppToD!CppStr(cs));
    }
    //extern (C++)
    CppStr apiFindInclude(CppStr cs_file, CppStr cs_include) {
        return dToCpp(findInclude(ccdb, Path(cppToD!CppStr(cs_file)), Path(cppToD!CppStr(cs_include))));
    }
    void apiClose(){
        handler.closeDB();
    }
    // TODO: extend so that dextool mutate can send what type of mutants etc
    void runSchemata(Path file) {
        runSchemataCpp(this, dToCpp(file));
    }
}
