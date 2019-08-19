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
import mutantschemata.utility: findInclude, sanitize, convertToFs;
import mutantschemata.db_handler;
import mutantschemata.type;

import dextool.type: AbsolutePath, Path;
import dextool.plugin.mutate.backend.database: MutationPointTbl;
import dextool.compilation_db: CompileCommandDB;

import std.range: front;
import std.array: Appender, appender, array, empty, join;

import logger = std.experimental.logger;

// Entry point for Dextool mutate
SchemataApi makeSchemataApi(Path db, CompileCommandDB ccdb, AbsolutePath ccdbPath) @trusted {
    SchemataApi sa = new SchemataApi(db, ccdb, ccdbPath);
    return sa;
}

// D class, connection to C++ code in /cpp_source
extern (C++) class SchemataApi: SchemataApiCpp {
    private DBHandler handler;
    private CompileCommandDB ccdb;
    private AbsolutePath ccdbPath;
    private Appender!(Path[]) files_appender;

    this(Path dbPath, CompileCommandDB c, AbsolutePath cPath) {
        handler = DBHandler(dbPath);
        ccdb = c;
        ccdbPath = cPath;
    }

    // Override of functions in external interface
    void apiInsertSchemataMutant(SchemataMutant sm) {
        handler.insertFromDB!SchemataMutant(sm);
    }
    void apiInsertSchemataFile(SchemataFile sf){
        handler.insertFromDB!SchemataFileString(convertToFs(sf));
    }
    SchemataMutant apiSelectSchemataMutant() {
        return sanitize(handler.selectFromDB!SchemataMutant());
    }
    SchemataMutant apiSelectSchemataMutant(CppBytes cb) {
        return sanitize(handler.selectFromDB!SchemataMutant(cppToD!CppBytes(cb)));
    }
    SchemataMutant apiSelectSchemataMutant(CppStr cs){
        return sanitize(handler.selectFromDB!SchemataMutant(cppToD!CppStr(cs)));
    }
    SchemataMutant apiSelectMutant() {
        return sanitize(handler.selectFromDB!MutationPointTbl());
    }
    SchemataMutant apiSelectMutant(CppBytes cb) {
        return sanitize(handler.selectFromDB!MutationPointTbl(cppToD!CppBytes(cb)));
    }
    SchemataMutant apiSelectMutant(CppStr cs) {
        return sanitize(handler.selectFromDB!MutationPointTbl(cppToD!CppStr(cs)));
    }
    void apiBuildMutant() {
        handler.buildSchemaDB!SchemataMutant();
    }
    void apiBuildFile() {
        handler.buildSchemaDB!SchemataFileString();
    }
    void apiDeleteMutant() {
        handler.deleteInDB!SchemataMutant();
    }
    void apiDeleteMutant(CppBytes cb) {
        handler.deleteInDB!SchemataMutant(cppToD!CppBytes(cb));
    }
    void apiDeleteMutant(CppStr cs) {
        handler.deleteInDB!SchemataMutant(cppToD!CppStr(cs));
    }
    void apiDeleteFile() {
        handler.deleteInDB!SchemataFileString();
    }
    void apiDeleteFile(CppBytes cb) {
        handler.deleteInDB!SchemataFileString(cppToD!CppBytes(cb));
    }
    void apiDeleteFile(CppStr cs) {
        handler.deleteInDB!SchemataFileString(cppToD!CppStr(cs));
    }
    CppStr apiFindInclude(CppStr cs_file, CppStr cs_include) {
        return dToCpp(findInclude(ccdb, Path(cppToD!CppStr(cs_file)), Path(cppToD!CppStr(cs_include))));
    }
    void apiClose() @trusted {
        handler.closeDB();
    }
    void addFileToMutate(Path file) @trusted {
        files_appender.put(file);
    }
    void runSchemata() @trusted {
        runSchemataCpp(this, dToCpp(files_appender.data.join(",")), dToCpp(ccdbPath));
    }
}
