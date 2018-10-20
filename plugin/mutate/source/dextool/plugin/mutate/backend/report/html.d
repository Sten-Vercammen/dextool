/**
Copyright: Copyright (c) 2018, Joakim Brännström. All rights reserved.
License: MPL-2
Author: Joakim Brännström (joakim.brannstrom@gmx.com)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.
*/
module dextool.plugin.mutate.backend.report.html;

import logger = std.experimental.logger;

import dextool.type : AbsolutePath, Path, DirName;
import dextool.plugin.mutate.backend.database : Database, FileRow,
    FileMutantRow, MutationId;
import dextool.plugin.mutate.backend.report.utility : toSections;
import dextool.plugin.mutate.type : MutationKind, ReportKind, ReportLevel,
    ReportSection;
import dextool.plugin.mutate.backend.interface_ : FilesysIO;
import dextool.plugin.mutate.backend.report.type : FileReport, FilesReporter;
import dextool.plugin.mutate.backend.type : Mutation, Offset, SourceLoc;
import dextool.plugin.mutate.config : ConfigReport;

version (unittest) {
    import unit_threaded : shouldEqual;
}

struct FileIndex {
    Path path;
    string display;
}

@safe final class ReportHtml : FileReport, FilesReporter {
    import std.array : Appender;
    import std.stdio : File, writefln, writeln;
    import std.xml : encode;
    import dextool.set;

    immutable htmlExt = ".html";
    immutable htmlDir = "html";

    const Mutation.Kind[] kinds;
    const ConfigReport conf;
    const AbsolutePath logDir;
    Set!ReportSection sections;
    FilesysIO fio;

    // all files that have been produced.
    Appender!(FileIndex[]) files;

    // the context for the file that is currently being processed.
    FileCtx ctx;

    this(const Mutation.Kind[] kinds, const ConfigReport conf, FilesysIO fio) {
        import std.path : buildPath;

        this.kinds = kinds;
        this.fio = fio;
        this.conf = conf;
        this.logDir = buildPath(conf.logDir, htmlDir).Path.AbsolutePath;

        sections = (conf.reportSection.length == 0 ? conf.reportLevel.toSections
                : conf.reportSection.dup).setFromList;
    }

    override void mutationKindEvent(const MutationKind[]) {
        import std.file : mkdirRecurse;

        mkdirRecurse(this.logDir);
    }

    override FileReport getFileReportEvent(ref Database db, const ref FileRow fr) {
        import std.algorithm : joiner;
        import std.path : pathSplitter, buildPath;
        import std.stdio : File;
        import std.utf : toUTF8;

        const original = fr.file.dup.pathSplitter.joiner("_").toUTF8;
        const report = (original ~ htmlExt).Path;
        files.put(FileIndex(report, fr.file));

        const out_path = buildPath(logDir, report).Path.AbsolutePath;

        ctx = FileCtx.init;
        ctx.processFile = fr.file;
        ctx.out_ = File(out_path, "w");
        ctx.span = Spanner(tokenize(fio.getOutputDir, fr.file));

        ctx.out_.writefln(htmlBegin, encode(original));

        return this;
    }

    override void fileMutantEvent(const ref FileMutantRow fr) {
        import dextool.plugin.mutate.backend.utility : makeMutationText;

        // TODO unnecessary to create the mutation text here.
        // Move it to endFileEvent. This is inefficient.

        auto fin = fio.makeInput(AbsolutePath(ctx.processFile, DirName(fio.getOutputDir)));
        auto txt = makeMutationText(fin, fr.mutationPoint.offset, fr.mutation.kind, fr.lang);
        ctx.span.put(FileMutant(fr.id, fr.mutationPoint.offset,
                txt.original.idup, txt.mutation.idup));
    }

    override void endFileEvent() {
        import std.algorithm : max, each, map;
        import std.format : format;
        import std.range : repeat;

        Set!MutationId ids;
        int line = 1;
        int column = 1;

        foreach (const s; ctx.span.toRange) {
            if (s.tok.loc.line > line)
                column = 1;

            "<br>".repeat(max(0, s.tok.loc.line - line)).each!(a => ctx.out_.writeln(a));
            const spaces = max(0, s.tok.loc.column - column);
            if (spaces > 1)
                "&nbsp;".repeat(spaces).each!(a => ctx.out_.write(a));
            ctx.out_.writeln(`<div style="display: inline;">`);
            ctx.out_.writefln(`<span class="original %s %(mutid%s %)">%s</span>`,
                    s.tok.toName, s.muts.map!(a => a.id), encode(s.tok.spelling));

            foreach (m; s.muts) {
                if (!ids.contains(m.id)) {
                    ids.add(m.id);
                    const org = m.original.encode;
                    const mut = m.mutation.encode;
                    ctx.out_.writefln(`<span id="%s" onmouseenter="fly(event, '%s')" onmouseleave="fly(event, '%s')" class="mutant %s">%s</span>`,
                            m.id, org, org, s.tok.toName, mut);
                    ctx.out_.writefln(`<a href="#%s"></a>`, m.id);
                }
            }
            ctx.out_.writeln(`</div>`);

            line = s.tok.locEnd.line;
            column = s.tok.locEnd.column;
        }

        ctx.out_.writefln(htmlEnd, js_file);
    }

    override void postProcessEvent(ref Database db) {
        import std.datetime : Clock;
        import std.path : buildPath;

        const index_f = buildPath(logDir, "index" ~ htmlExt);
        auto index = File(index_f, "w");

        index.writefln(`<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html;charset=UTF-8">
<title>Mutation Testing Report %s</title>
</head>
<style>body {font-family: monospace; font-size: 14px;}</style>
`, Clock.currTime);
        foreach (f; files.data) {
            index.writefln(`<a href="%s">%s</a>`, f.path, encode(f.display));
        }

        index.writeln(`</body></html>`);
    }

    override void endEvent(ref Database) {
    }
}

@safe:
private:

struct FileCtx {
    import std.stdio;

    Path processFile;
    File out_;

    Spanner span;
}

immutable htmlBegin = `<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html;charset=UTF-8">
<title>%s</title>
</head>
<body onload="javascript:init();">
<div id="mousehover"></div>
<style>
body {font-family: monospace; font-size: 14px;}
.mutant {display:none; background-color: yellow;}
.literal {color: darkred;}
.keyword {color: blue;}
.comment {color: grey;}
#mousehover {
background: grey;
border-radius: 8px;
-moz-border-radius: 8px;
padding: 5px;
display: none;
position: absolute;
background: #2e3639;
color: #fff;
}
</style>
`;

immutable htmlEnd = `<script>%s</script>
</body>
</html>
`;

immutable js_file = `function init() {
    var mutid = window.location.hash.substring(1);
    if(mutid) {
        highlight_mutant(mutid);
    }
}

function highlight_mutant(mutid) {
    var orgs = document.querySelectorAll(".original");
    var muts = document.querySelectorAll(".mutant");

    for (var i=0; i<orgs.length; i++) {
        orgs[i].style.display = "default";
    }

    for (i=0; i<muts.length; i++) {
        muts[i].style.display = "none";
    }

    mut = document.getElementById(mutid);
    if(mut) {
        for(var i=0; i<mut.parentNode.children.length; i++) {
            mut.parentNode.children[i].style.display = 'none';
        }
        clss = document.getElementsByClassName("mutid" + mutid);
        if (clss) {
            for(var i=0; i<clss.length; i++) {
                clss[i].style.display = 'none';
            }
        }
        mut.style.display = 'inline';
    }
}

function fly(evt, html) {
    var el = document.getElementById("mousehover");
    if(evt.type == "mouseenter") {
        el.style.display = "inline";
    } else {
        el.style.display = "none";
    }

    el.innerHTML = html;
    el.style.left = (evt.pageX - el.offsetWidth) + 'px';
    el.style.top = (evt.pageY - el.offsetHeight) + 'px';
}
`;

struct Token {
    import clang.c.Index : CXTokenKind;

    CXTokenKind kind;
    Offset offset;
    SourceLoc loc;
    SourceLoc locEnd;
    string spelling;

    string toId() @safe const {
        import std.format : format;

        return format("%s-%s", offset.begin, offset.end);
    }

    string toName() @safe const {
        import std.conv : to;

        return kind.to!string;
    }

    int opCmp(ref const typeof(this) s) const @safe {
        if (offset.begin > s.offset.begin)
            return 1;
        if (offset.begin < s.offset.begin)
            return -1;
        if (offset.end > s.offset.end)
            return 1;
        if (offset.end < s.offset.end)
            return -1;
        return 0;
    }
}

@("shall be possible to construct in @safe")
@safe unittest {
    import clang.c.Index : CXTokenKind;

    auto tok = Token(CXTokenKind.comment, Offset(1, 2), SourceLoc(1, 2), "smurf");
}

// This is a bit slow, I think. Optimize by reducing the created strings.
// trusted: none of the unsafe accessed data escape this function.
auto tokenize(AbsolutePath base_dir, Path f) @trusted {
    import std.array : appender;
    import std.path : buildPath;
    import std.typecons : Yes;
    import clang.Index;
    import clang.TranslationUnit;
    import cpptooling.analyzer.clang.context;

    const fpath = buildPath(base_dir, f);

    auto ctx = ClangContext(Yes.useInternalHeaders, Yes.prependParamSyntaxOnly);
    auto tu = ctx.makeTranslationUnit(fpath);

    auto toks = appender!(Token[])();
    foreach (ref t; tu.cursor.tokens) {
        auto ext = t.extent;
        auto start = ext.start;
        auto end = ext.end;
        toks.put(Token(t.kind, Offset(start.offset, end.offset),
                SourceLoc(start.line, start.column), SourceLoc(end.line, end.column), t.spelling));
    }

    return toks.data;
}

struct FileMutant {
    MutationId id;
    Offset offset;
    /// the original text that covers the offset.
    string original;
    /// The mutation text that covers the offset.
    string mutation;

    int opCmp(ref const typeof(this) s) const @safe {
        if (offset.begin > s.offset.begin)
            return 1;
        if (offset.begin < s.offset.begin)
            return -1;
        if (offset.end > s.offset.end)
            return 1;
        if (offset.end < s.offset.end)
            return -1;
        return 0;
    }
}

@("shall be possible to construct a FileMutant in @safe")
@safe unittest {
    auto fmut = FileMutant(MutationId(1), Offset(1, 2), "smurf");
}

/*
I get a mutant that have a start/end offset.
I have all tokens.
I can't write the html before I have all mutants for the offset.
Hmm potentially this mean that I can't write any html until I have analyzed all mutants for the file.
This must be so....

How to do it?

From reading https://stackoverflow.com/questions/11389627/span-overlapping-strings-in-a-paragraph
it seems that generating a <span..> for each token with multiple classes in them. A class for each mutant.
then they can be toggled on/off.

a <href> tag to the beginning to jump to the mutant.
*/

/** Provide an interface to travers the tokens and get the overlapping mutants.
 */
struct Spanner {
    import std.container : RedBlackTree, redBlackTree;
    import std.range : isOutputRange;

    alias BTree(T) = RedBlackTree!(T, "a < b", true);

    BTree!Token tokens;
    BTree!FileMutant muts;

    this(Token[] tokens) @trusted {
        this.tokens = new typeof(this.tokens);
        this.muts = new typeof(this.muts)();

        this.tokens.insert(tokens);
    }

    void put(const FileMutant fm) {
        muts.insert(fm);
    }

    SpannerRange toRange() @safe pure {
        return SpannerRange(tokens, muts);
    }

    string toString() @safe pure const {
        import std.array : appender;

        auto buf = appender!string;
        this.toString(buf);
        return buf.data;
    }

    void toString(Writer)(ref Writer w) const if (isOutputRange!(Writer, char)) {
        import std.format : formattedWrite;
        import std.range : put, zip, StoppingPolicy;
        import std.string;
        import std.algorithm : max;
        import std.traits : Unqual;

        ulong sz;

        foreach (ref const t; zip(StoppingPolicy.longest, tokens[], muts[])) {
            auto c0 = format("%s", cast(Unqual!(typeof(t[0]))) t[0]);
            string c1;
            if (t[1] != typeof(t[1]).init)
                c1 = format("%s", cast(Unqual!(typeof(t[1]))) t[1]);
            sz = max(sz, c0.length, c1.length);
            formattedWrite(w, "%s | %s\n", c0.rightJustify(sz), c1);
        }
    }
}

@("shall be possible to construct a Spanner in @safe")
@safe unittest {
    import std.algorithm;
    import std.conv;
    import std.range;
    import clang.c.Index : CXTokenKind;

    auto toks = zip(iota(10), iota(10, 20)).map!(a => Token(CXTokenKind.comment,
            Offset(a[0], a[1]), SourceLoc.init, a[0].to!string)).retro.array;
    auto span = Spanner(toks);

    span.put(FileMutant(MutationId(1), Offset(1, 10), "smurf"));
    span.put(FileMutant(MutationId(1), Offset(9, 15), "donkey"));

    // TODO add checks
}

/**
 *
 * # Overlap Cases
 * 1. Perfekt overlap
 * |--T--|
 * |--M--|
 *
 * 2. Token enclosing mutant
 * |---T--|
 *   |-M-|
 *
 * 3. Mutant beginning inside a token
 * |---T--|
 *   |-M----|
 *
 * 4. Mutant overlapping multiple tokens.
 * |--T--|--T--|
 * |--M--------|
 */
struct SpannerRange {
    alias BTree = Spanner.BTree;

    BTree!Token tokens;
    BTree!FileMutant muts;

    this(BTree!Token tokens, BTree!FileMutant muts) @safe pure {
        this.tokens = tokens;
        this.muts = muts;
        dropMutants;
    }

    Span front() @safe pure nothrow {
        import std.array : appender;

        assert(!empty, "Can't get front of an empty range");
        auto t = tokens.front;

        if (muts.empty)
            return Span(t);

        auto app = appender!(FileMutant[])();
        foreach (m; muts) {
            if (m.offset.begin < t.offset.end)
                app.put(m);
            else
                break;
        }

        return Span(t, app.data);
    }

    void popFront() @safe pure {
        assert(!empty, "Can't pop front of an empty range");
        tokens.removeFront;
        dropMutants;
    }

    bool empty() @safe pure nothrow @nogc {
        return tokens.empty;
    }

    private void dropMutants() @safe pure {
        if (tokens.empty)
            return;

        // removing mutants that the tokens have "passed by"
        const t = tokens.front;
        while (!muts.empty && muts.front.offset.end <= t.offset.begin) {
            muts.removeFront;
        }
    }
}

struct Span {
    import std.range : isOutputRange;

    Token tok;
    FileMutant[] muts;

    string toString() @safe pure const {
        import std.array : appender;
        import std.format : FormatSpec;

        auto buf = appender!string;
        toString(buf);
        return buf.data;
    }

    void toString(Writer)(ref Writer w) const if (isOutputRange!(Writer, char)) {
        import std.format : formattedWrite;
        import std.range : put;

        formattedWrite(w, "%s|%(%s %)", tok, muts);
    }
}

@("shall return a range grouping mutants by the tokens they overlap")
@safe unittest {
    import std.algorithm;
    import std.array : array;
    import std.conv;
    import std.range;
    import clang.c.Index : CXTokenKind;

    auto offsets = zip(iota(0, 150, 10), iota(10, 160, 10)).map!(a => Offset(a[0], a[1])).array;

    auto toks = offsets.map!(a => Token(CXTokenKind.comment, a, SourceLoc.init,
            a.begin.to!string)).retro.array;
    auto span = Spanner(toks);

    span.put(FileMutant(MutationId(1), Offset(0, 10), "perfect overlap"));
    span.put(FileMutant(MutationId(2), Offset(11, 15), "token enclosing mutant"));
    span.put(FileMutant(MutationId(3), Offset(31, 42), "mutant beginning inside a token"));
    span.put(FileMutant(MutationId(4), Offset(50, 80), "mutant overlapping multiple tokens"));

    span.put(FileMutant(MutationId(5), Offset(90, 100), "1 multiple mutants for a token"));
    span.put(FileMutant(MutationId(6), Offset(90, 110), "2 multiple mutants for a token"));

    auto res = span.toRange.array;
    //logger.tracef("%(%s\n%)", res);
    res[0].muts[0].id.shouldEqual(1);
    res[1].muts[0].id.shouldEqual(2);
    res[2].muts.length.shouldEqual(0);
    res[3].muts[0].id.shouldEqual(3);
    res[4].muts[0].id.shouldEqual(3);
    res[5].muts[0].id.shouldEqual(4);
    res[6].muts[0].id.shouldEqual(4);
    res[7].muts[0].id.shouldEqual(4);
    res[8].muts.length.shouldEqual(0);
    res[9].muts.length.shouldEqual(2);
    res[9].muts[0].id.shouldEqual(5);
    res[9].muts[1].id.shouldEqual(6);
    res[10].muts[0].id.shouldEqual(6);
    res[11].muts.length.shouldEqual(0);
}
