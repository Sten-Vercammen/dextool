/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.

Utility functionality for mutantschemata API.
*/
module mutantschemata.utility;

import mutantschemata.externals;
import mutantschemata.type;
import mutantschemata.d_string;

import dextool.plugin.mutate.backend.database: MutationPointTbl;

import dextool.type: Path, FileName;
import dextool.compilation_db: CompileCommandDB, CompileCommand, ParseFlags, parseFlag, dcf = defaultCompilerFilter;
import dextool.clang: findCompileCommandFromIncludes;

import std.range: front;
import std.array: array, empty;

const string[] NO_FLAGS = [""];

Path findInclude(ref CompileCommandDB ccdb, Path file, Path include) {
    CompileCommand cc = findCompileCommandFromIncludes(ccdb, FileName(file), dcf, NO_FLAGS).original;
    ParseFlags pf = parseFlag(cc, dcf);

    return findIncludePath(pf, include);
}
Path findIncludePath(ParseFlags pf, Path include) {
    import std.algorithm: filter;
    import std.file: isFile;
    import std.array: array, empty;
    import std.range.primitives: front;

    auto res = pf.includes.filter!(includepath => isFile(includepath ~ "/" ~ include)).array;
    return Path(res.empty ? "" : res.front);
}
// creates an empty mutant
SchemataMutant createSchemataMutant() {
    return SchemataMutant(-1, SourceLoc(0,0), Offset(0,0), "");
}
SchemataMutant createSchemataMutant(SchemataMutant sm) {
    return sm;
}
/* will probably not use this since we insert from cpp-side
SchemataMutant createSchemataMutant(MutationPointTbl mpt) {
    return SchemataMutant(SourceLoc(mpt.line, mpt.column), Offset(mpt.offset_begin, mpt.offset_end), -1);
}*/
// sanitizes the select calls from the db.
// returns a "fake" mutant with id = -1 if the query was empty
SchemataMutant sanitize(T)(T[] t) {
    return t.empty ? createSchemataMutant() : createSchemataMutant(t.front);
}
SchemataFileString convertToFs(SchemataFile sf) {
    return SchemataFileString(cppToD!CppStr(sf.fpath),
                                sf.mutants,
                                cppToD!CppStr(sf.code));
}
