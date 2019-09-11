/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.


Meant to function as an api for schemata using and providing schemata with db
*/
module mutantschemata.api;

import mutantschemata.d_string: cppToD, dToCpp;
import mutantschemata.externals;
import mutantschemata.utility: findInclude, sanitize, convertToFs;
import mutantschemata.db_handler;
import mutantschemata.type;
import mutantschemata.execute;

import dextool.type: AbsolutePath, Path, ExitStatusType;
import dextool.compilation_db: CompileCommandDB;
import dextool.plugin.mutate.config: ConfigMutationTest;
import dextool.plugin.mutate.backend.watchdog: StaticTime, ProgressivWatchdog;
//import dextool.plugin.mutate.backend.type: Mutation;

import std.range: front;
import std.array: Appender, appender, array, empty, join;
import std.datetime.stopwatch : StopWatch;
import core.time: dur;
import std.conv: to;

import logger = std.experimental.logger;

// Entry point for Dextool mutate
SchemataApi makeSchemataApi(SchemataInformation si) @trusted {
    SchemataApi sa = new SchemataApi(si);
    return sa;
}

// D class, connection to C++ code in /cpp_source
extern (C++) class SchemataApi: SchemataApiCpp {
    private DBHandler handler;
    private CompileCommandDB ccdb;
    private AbsolutePath ccdbPath;
    private AbsolutePath mainFile;
    private Appender!(Path[]) files_appender;

    this (SchemataInformation si) {
        handler = DBHandler(si.databasePath);
        ccdb = si.compileCommand;
        ccdbPath = si.compileCommandPath;
    }

    // Override of functions in external interface
    void apiInsertSchemataMutant(SchemataMutant sm) {
        handler.insertInDB!SchemataMutant(sm);
    }
    void apiInsertSchemataFile(SchemataFile sf){
        handler.insertInDB!SchemataFileString(convertToFs(sf));
    }
    SchemataMutant apiSelectSchemataMutant(CppStr cs){
        return sanitize(handler.selectFromDB!SchemataMutant(cppToD!CppStr(cs)));
    }
    void apiBuildMutant() {
        handler.buildSchemaDB!SchemataMutant();
    }
    void apiBuildFile() {
        handler.buildSchemaDB!SchemataFileString();
    }
    void apiDeleteMutant(CppStr cs) {
        handler.deleteInDB!SchemataMutant(cppToD!CppStr(cs));
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
    // not part of api
    SchemataMutant[] selectMutants(CppStr condition) {
        return handler.selectFromDB!SchemataMutant(cppToD!CppStr(condition));
    }
    // not part of api, will be called by Dextool mutate
    void addFileToMutate(Path file) @trusted {
        files_appender.put(file);
    }
    void runSchemataAnalyzer() @trusted {
        runSchemataCpp(this, dToCpp(files_appender.data.join(",")), dToCpp(ccdbPath));
    }
}
void setEnvironmentVariable(string value) {
    // TODO: this does not seem to work as intended. Could as well be done on cpp-side
    import std.process: environment;
    try {
        environment[MUTANT_NR] = value;
    } catch (Exception e) {
        logger.warning(e.msg);
    }
}
ExitStatusType runSchemataTester(SchemataApi sa, ConfigMutationTest config) @trusted {
    // TODO: Error handling!
    logger.info("Preparing for mutation testing by checking that the program and tests compile without any errors (all mutants injected)");

    // compile
    auto compileResult = preCompileSut(config);
    if (compileResult.status != 0) {
        logger.info(compileResult.output);
        logger.error("Compiler command failed: ", compileResult.status);
        return ExitStatusType.Errors;
    }
    logger.info("Compiled successfull");

    // run and measure test suite
    auto testSuite = measureTestDuration(config.mutationTester);
    logger.info("Test execution successfull");

    // set timeout for the testsuite
    auto watchdog = StaticTime!StopWatch(1.dur!"hours");                        // unreasonable time, but this is temporary (should use the timeout-algorithm in original version)

    sa.apiBuildMutant();    // only needed for testing the selecting of mutants
    // get all unknown mutants from db (inserted from cpp-side when created)
    SchemataMutant[] mutants = sa.selectMutants(dToCpp("status = 0"));          // should be all mutants since no status have been set on them (except the killedByCompiler ones)

    foreach (m; mutants) {
        // set environment variable to current mutant
        setEnvironmentVariable(to!string(m.mut_id));                            // this should activate the current mutant
        // run the tests again
        auto status = schemataTester(config, watchdog);        // will execute the mutant activated by the environment variable
    }

    return ExitStatusType.Ok;
}

/* runSchemataTester-algorithm
0. Compile the project with all mutants inserted
1. get all unknown mutants in db and execute them
2. loop over all mutants
    3. set environment variable to mutant_id
    4. execute testsuite
    5. parse testresult
    6. write result in mutant.status
7. write result to db (can be just a print for now)*/
