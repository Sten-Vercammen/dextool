// Written in the D programming language.
/**
Copyright: Copyright (c) 2016, Joakim Brännström. All rights reserved.
License: MPL-2
Author: Joakim Brännström (joakim.brannstrom@gmx.com)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.
*/
module cpptooling.data.symbol.container;

import logger = std.experimental.logger;

//TODO move TypeKind to .data
import cpptooling.analyzer.type : TypeKind;

import cpptooling.data.representation : CppClass;
import cpptooling.data.symbol.typesymbol;
import cpptooling.data.symbol.types;

version (unittest) {
    import unit_threaded : Name;
    import unit_threaded : shouldEqual;
} else {
    struct Name {
        string name_;
    }
}

/** Contain symbols found during analyze to allow flat, fast lookup.
 *
 * The symbols are stored as copies.
 * It allows the representation to be chnaged.
 *
 * Lookup is done via Fully Qualified Name.
 *
 * BROKEN when doing whole-program analyze. Kept as a reminder.
 *    "Assumtion. The C++ one definition rule is never violated."
 *
 * New design:
 * Lookup via a unique identifier, Unified Symbol Resolution (USR).
 */
@safe struct Container {
    invariant() {
        assert(cppclass.length == t_cppclass.length);
    }

    private {
        //TODO change to using a hash map
        CppClass*[] cppclass;
        TypeSymbol!(CppClass*)[] t_cppclass;

        TypeKind*[USRType] lookup_typekind;
        TypeKind*[] typekind;
    }

    private auto rangeTypeClass() @nogc {
        return t_cppclass;
    }

    private auto typeRange() @nogc const {
        return typekind;
    }

    void put(TypeKind tk)
    in {
        assert(tk.usr.length > 0);
    }
    body {
        if (tk.usr in lookup_typekind) {
            return;
        }

        auto heap = new TypeKind(tk);
        typekind ~= heap;
        lookup_typekind[tk.usr] = heap;

        debug {
            import std.conv : to;
            import cpptooling.analyzer.type;
            import cpptooling.data.type : LocationTag, Location;

            auto latest = *typekind[$ - 1];

            logger.tracef("Stored kind:%s usr:%s repr:%s loc:%s", latest.info.kind.to!string,
                    cast(string) latest.usr, latest.toStringDecl(TypeAttr.init, "x"),
                    latest.loc.kind == LocationTag.Kind.loc ? latest.loc.file : "noloc");
        }
    }

    auto find(T)(USRType usr) const
    out (result) {
        logger.tracef("%sfind usr:%s", result.length == 0 ? "Failed " : "", cast(string) usr);
    }
    body {
        import std.string : toLower;
        import std.range : only, dropOne;
        import std.typecons : NullableRef;

        enum lookup = "lookup_" ~ toLower(T.stringof);
        auto hash = __traits(getMember, typeof(this), lookup);

        auto item = usr in hash;
        if (item is null) {
            return only(TypeKind.init).dropOne;
        }

        auto rval = only(TypeKind(**item));

        return rval;
    }

    /** Duplicate and store the class in the container.
     *
     * Only store classes that are fully analyzed.
     * Changes to parameter cl after storages are NOT reflected in the stored class.
     */
    void put(ref CppClass cl, FullyQualifiedNameType fqn) {
        //TODO change to using a hash map
        if (internalFind!CppClass(fqn).length != 0) {
            return;
        }

        auto heap_c = new CppClass(cl);
        cppclass ~= heap_c;
        t_cppclass ~= TypeSymbol!(CppClass*)(heap_c, fqn);
    }

    import std.typecons : NullableRef;

    // Do not spam log traces because of internal searches via put.
    // For further info see the public find
    private auto internalFind(T)(FullyQualifiedNameType fqn) {
        import std.string : toLower;
        import std.range : only, dropOne;
        import std.typecons : NullableRef;

        enum type_lower = "t_" ~ toLower(T.stringof);
        auto t_objs = __traits(getMember, typeof(this), type_lower);

        foreach (item; t_objs) {
            if (item.fullyQualifiedName == fqn) {
                return only(NullableRef!T(item.get));
            }
        }

        // When this happens the AST doesn't have the declaration.
        // A case when this happens is a pointer to a forward declared class.

        // The only sensible option left is to return a zero length range to
        // still allow range iterators etc to work.
        return only(NullableRef!T((T*).init)).dropOne;
    }

    /** Find the represented object via search parameter.
     *
     * TODO Decouple the compile time arg from the concrete type by basing it
     * on for example an enum. By doing so it removes the dependency of all
     * callers having to specify the type, and knowing the type.
     *
     * Return: ref to object or null
     */
    auto find(T)(FullyQualifiedNameType fqn) {
        logger.trace("searching for: ", cast(string) fqn);

        auto rval = internalFind!T(fqn);

        logger.tracef(rval.length == 0, "No symbol found for '%s'", cast(string) fqn);

        return rval;
    }

    string toString() const {
        import std.algorithm : joiner, map;
        import std.ascii : newline;
        import std.conv : text;
        import std.format : format;
        import std.range : only, chain, takeOne;
        import cpptooling.analyzer.type;
        import cpptooling.data.type : LocationTag;

        // dfmt off
        return chain(
                     only("Container {" ~ newline).joiner,
                     only("classes {" ~ newline).joiner,
                        t_cppclass.map!(a => "  " ~ a.fullyQualifiedName ~ newline).joiner,
                     only("} // classes" ~ newline).joiner,
                     only("types {" ~ newline).joiner,
                        typeRange.map!(a => format("  %s %s -> %s %s%s", a.info.kind.to!string(), cast(string) a.usr, (*a).internalGetFmt, a.loc.kind == LocationTag.Kind.loc ? a.loc.file : "noloc", newline)).joiner,
                     only("} // types" ~ newline).joiner,
                     only("} //Container").joiner,
                    ).text;
        // dfmt on
    }
}

@Name("should be able to use the found class")
unittest {
    import cpptooling.data.representation : CppClass, CppClassName;

    auto c = CppClass(CppClassName("Class"));

    Container cont;
    cont.put(c, c.fullyQualifiedName);

    // not really needed test but independent at two places, see the invariant.
    1.shouldEqual(cont.cppclass.length);

    // should be able to find a stored class by the FQN
    auto found_class = cont.find!CppClass(FullyQualifiedNameType("Class")).front;

    // should be able to use the found class
    "Class".shouldEqual(found_class.name);
}

@Name("should list all contained classes")
unittest {
    import cpptooling.data.representation : CppClass, CppClassName;
    import test.helpers;
    import std.conv : to;

    Container cont;

    for (auto i = 0; i < 3; ++i) {
        auto c = CppClass(CppClassName("Class" ~ to!string(i)));
        cont.put(c, c.fullyQualifiedName);
    }

    cont.toString.shouldEqualPretty("Container {
classes {
  Class0
  Class1
  Class2
} // classes
types {
} // types
} //Container");
}

@Name("Should never be duplicates of content")
unittest {
    import cpptooling.data.representation : CppClass, CppClassName;
    import test.helpers;

    Container cont;

    for (auto i = 0; i < 3; ++i) {
        auto c = CppClass(CppClassName("Class"));
        cont.put(c, c.fullyQualifiedName);
    }

    cont.toString.shouldEqualPretty("Container {
classes {
  Class
} // classes
types {
} // types
} //Container");
}
