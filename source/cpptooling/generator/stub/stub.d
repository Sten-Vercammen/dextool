/// Written in the D programming language.
/// Date: 2015, Joakim Brännström
/// License: GPL
/// Author: Joakim Brännström (joakim.brannstrom@gmx.com)
///
/// This program is free software; you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation; either version 2 of the License, or
/// (at your option) any later version.
///
/// This program is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
/// GNU General Public License for more details.
///
/// You should have received a copy of the GNU General Public License
/// along with this program; if not, write to the Free Software
/// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
module cpptooling.generator.stub.stub;

import std.typecons : Typedef;

import logger = std.experimental.logger;

/// Prefix used for prepending generated code with a unique string to avoid name collisions.
alias StubPrefix = Typedef!(string, string.init, "StubPrefix");

interface StubController {
    /// Process AST node belonging to filename.
    bool doFile(string filename);

    /// Process AST node that is a class.
    bool doClass();

    /// File to include in the generated header.
    StubGenerator.HdrFilename getIncludeFile();

    ClassController getClass();
}

interface ClassController {
    bool useObjectPool();

    StubPrefix getClassPrefix();
    //MethodController getMethod();
}

struct StubGenerator {
    import std.typecons : Typedef;

    import cpptooling.data.representation : CppRoot;
    import cpptooling.utility.conv : str;
    import dsrcgen.cpp : CppModule, CppHModule;

    alias HdrFilename = Typedef!(string, string.init, "HdrFilename");

    this(StubController ctrl) {
        this.ctrl = ctrl;
    }

    void translate(CppRoot root) {
        tr = .translate(root, ctrl);
    }

    /** Generate the C++ header file of the stub.
     * Params:
     *  filename = intended output filename, used for ifdef guard.
     */
    string outputHdr(HdrFilename filename) {
        import std.string : translate;

        dchar[dchar] table = ['.' : '_', '-' : '_'];

        ///TODO add user defined header.
        auto o = CppHModule(translate(filename.str, table));
        o.content.include(ctrl.getIncludeFile.str);
        o.content.sep(2);
        o.content.text(tr.toString());

        return o.render;
    }

    string outputImpl(HdrFilename filename) {
        ///TODO add user defined header.
        auto o = new CppModule;
        o.suppressIndent(1);
        o.include(filename.str);
        o.sep(2);

        return o.render;
    }

private:
    StubController ctrl;
    CppRoot tr;
}

private:
import cpptooling.data.representation : CppRoot, CppClass, CFunction;

/// Structurally transformed the input to a stub implementation.
CppRoot translate(CppRoot input, StubController ctrl) {
    CppRoot tr;

    foreach (c; input.classRange()) {
        tr.put(translateClass(input, c, ctrl.getClass()));
    }

    foreach (f; input.funcRange()) {
        tr.put(translateCFunc(input, f));
    }

    return tr;
}

CppClass translateClass(CppRoot root, CppClass input, ClassController ctrl) {
    import cpptooling.data.representation : CppAccess, CppClassNesting,
        CppClassInherit, CppClassName, CppClassVirtual, AccessType, VirtualType,
        whereIsClass, toStringNs;
    import cpptooling.utility.conv : str;

    if (input.isVirtual) {
        auto ns = CppClassNesting(whereIsClass(root, input.id()).toStringNs());
        auto inherit = CppClassInherit(input.name, ns, CppAccess(AccessType.Public));
        auto name = CppClassName(ctrl.getClassPrefix().str ~ input.name.str);

        auto c = CppClass(name, [inherit]);

        return c;
    } else {
        return input;
    }
}

CFunction translateCFunc(CppRoot root, CFunction func) {
    return func;
}