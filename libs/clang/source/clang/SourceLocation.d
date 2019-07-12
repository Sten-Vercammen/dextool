/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg, Joakim Brännström (joakim.brannstrom dottli gmx.com)
 * Version: 1.1
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * History:
 *  1.0 initial release. 2012-01-29 $(BR)
 *    Jacob Carlborg
 *
 *  1.1 additional features missing compared to cindex.py. 2015-03-07 $(BR)
 *    Joakim Brännström
 */
module clang.SourceLocation;

import std.typecons;

import clang.c.Index;

import clang.File;
import clang.TranslationUnit;
import clang.Util;

/// A SourceLocation represents a particular location within a source file.
struct SourceLocation {
    import std.format : FormatSpec, format, formattedWrite, formatValue;

    mixin CX;

    struct Location {
        File file;
        uint line;
        uint column;
        uint offset;

        string toString() @safe const {
            import std.exception : assumeUnique;
            import std.format : FormatSpec;

            char[] buf;
            buf.reserve(100);
            auto fmt = FormatSpec!char("%s");
            toString((const(char)[] s) { buf ~= s; }, fmt);
            auto trustedUnique(T)(T t) @trusted {
                return assumeUnique(t);
            }

            return trustedUnique(buf);
        }

        void toString(Writer, Char)(scope Writer w, FormatSpec!Char fmt) const {
            formattedWrite(w, "[%s line=%d column=%d offset=%d]", file.name, line, column, offset);
        }
    }

    // ugly hack. Must fix to something that works for both File and string.
    struct Location2 {
        string file;
        uint line;
        uint column;
        uint offset;

        string toString() @safe const {
            import std.exception : assumeUnique;
            import std.format : FormatSpec;

            char[] buf;
            buf.reserve(100);
            auto fmt = FormatSpec!char("%s");
            toString((const(char)[] s) { buf ~= s; }, fmt);
            auto trustedUnique(T)(T t) @trusted {
                return assumeUnique(t);
            }

            return trustedUnique(buf);
        }

        void toString(Writer, Char)(scope Writer w, FormatSpec!Char fmt) const {
            formattedWrite(w, "[%s line=%d column=%d offset=%d]", file, line, column, offset);
        }
    }

    /// Retrieve a NULL (invalid) source location.
    static SourceLocation empty() {
        auto r = clang_getNullLocation();
        return SourceLocation(r);
    }

    /** Retrieves the source location associated with a given file/line/column
     * in a particular translation unit.
     * TODO consider moving to TranslationUnit instead
     *
     * Params:
     *  tu = translation unit to derive location from.
     *  file = a file in tu.
     *  line = text line. Starting at 1.
     *  offset = offset into the line. Starting at 1.
     */
    static Nullable!SourceLocation fromPosition(ref TranslationUnit tu,
            ref File file, uint line, uint offset) {

        auto rval = Nullable!SourceLocation();
        auto r = SourceLocation(clang_getLocation(tu, file, line, offset));
        if (r.file !is null) {
            rval = SourceLocation(r);
        }

        return rval;
    }

    /** Retrieves the source location associated with a given character offset
     * in a particular translation unit.
     * TODO consider moving to TranslationUnit instead
     */
    static SourceLocation fromOffset(ref TranslationUnit tu, ref File file, uint offset) {
        auto r = clang_getLocationForOffset(tu, file, offset);
        return SourceLocation(r);
    }

    /// Get the file represented by this source location.
    /// TODO implement with a cache, this is inefficient.
    @property File file() const @safe {
        return spelling.file;
    }

    /// Get the line represented by this source location.
    @property uint line() const @trusted {
        uint result;
        clang_getSpellingLocation(cx, null, &result, null, null);
        return result;
    }

    /// Get the column represented by this source location.
    @property uint column() const @trusted {
        uint result;
        clang_getSpellingLocation(cx, null, null, &result, null);
        return result;
    }

    /// Get the file offset represented by this source location.
    @property uint offset() const @trusted {
        uint result;
        clang_getSpellingLocation(cx, null, null, null, &result);
        return result;
    }

    /// The path the SourceLocation point to.
    @property string path() const @trusted {
        File file;
        clang_getSpellingLocation(cx, &file.cx, null, null, null);
        return file.name;
    }

    /** Returns if the given source location is in the main file of the
     * corresponding translation unit.
     */
    @property bool isFromMainFile() const @trusted {
        return clang_Location_isFromMainFile(cx) != 0;
    }

    /** Retrieve the file, line, column, and offset represented by
     * the given source location.
     *
     * If the location refers into a macro expansion, retrieves the
     * location of the macro expansion.
     *
     * Location within a source file that will be decomposed into its parts.
     *
     * file [out] if non-NULL, will be set to the file to which the given
     * source location points.
     *
     * line [out] if non-NULL, will be set to the line to which the given
     * source location points.
     *
     * column [out] if non-NULL, will be set to the column to which the given
     * source location points.
     *
     * offset [out] if non-NULL, will be set to the offset into the
     * buffer to which the given source location points.
     */
    @property Location expansion() const @trusted {
        Location data;

        clang_getExpansionLocation(cx, &data.file.cx, &data.line, &data.column, &data.offset);

        return data;
    }

    /** Retrieve the file, line, column, and offset represented by
     * the given source location, as specified in a # line directive.
     *
     * Example: given the following source code in a file somefile.c
     * ---
     * #123 "dummy.c" 1
     *
     * static int func()
     * {
     *     return 0;
     * }
     * ---
     * the location information returned by this function would be
     * ---
     * File: dummy.c Line: 124 Column: 12
     * ---
     * whereas clang_getExpansionLocation would have returned
     * ---
     * File: somefile.c Line: 3 Column: 12
     * ---
     *
     *  filename [out] if non-NULL, will be set to the filename of the
     * source location. Note that filenames returned will be for "virtual" files,
     * which don't necessarily exist on the machine running clang - e.g. when
     * parsing preprocessed output obtained from a different environment. If
     * a non-NULL value is passed in, remember to dispose of the returned value
     * using \c clang_disposeString() once you've finished with it. For an invalid
     * source location, an empty string is returned.
     *
     *  line [out] if non-NULL, will be set to the line number of the
     * source location. For an invalid source location, zero is returned.
     *
     *  column [out] if non-NULL, will be set to the column number of the
     * source location. For an invalid source location, zero is returned.
     */
    auto presumed() const @trusted {
        Location2 data;
        CXString cxstring;

        clang_getPresumedLocation(cx, &cxstring, &data.line, &data.column);
        data.file = toD(cxstring);

        return data;
    }

    /** Retrieve the file, line, column, and offset represented by
     * the given source location.
     *
     * If the location refers into a macro instantiation, return where the
     * location was originally spelled in the source file.
     *
     * The location within a source file that will be decomposed into its
     * parts.
     *
     * file [out] if non-NULL, will be set to the file to which the given
     * source location points.
     *
     * line [out] if non-NULL, will be set to the line to which the given
     * source location points.
     *
     * column [out] if non-NULL, will be set to the column to which the given
     * source location points.
     *
     * offset [out] if non-NULL, will be set to the offset into the
     * buffer to which the given source location points.
     */
    @property Location spelling() const @trusted {
        Location data;

        clang_getSpellingLocation(cx, &data.file.cx, &data.line, &data.column, &data.offset);

        return data;
    }

    string toString() @safe const {
        import std.exception : assumeUnique;

        char[] buf;
        buf.reserve(100);
        auto fmt = FormatSpec!char("%s");
        toString((const(char)[] s) { buf ~= s; }, fmt);
        auto trustedUnique(T)(T t) @trusted {
            return assumeUnique(t);
        }

        return trustedUnique(buf);
    }

    void toString(Writer, Char)(scope Writer w, FormatSpec!Char fmt) const {
        if (isValid)
            formatValue(w, spelling, fmt);
    }
}
