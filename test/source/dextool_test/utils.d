/**
Copyright: Copyright (c) 2015-2019, Joakim Brännström. All rights reserved.
License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
Author: Joakim Brännström (joakim.brannstrom@gmx.com)
*/
module dextool_test.utils;

import scriptlike;

import std.range : isInputRange;
import std.typecons : Flag;
public import std.typecons : Yes, No;

import logger = std.experimental.logger;

enum dextoolExePath = "path_to_dextool/dextool_debug";

import dextool_test.builders : BuildCommandRun;

auto buildArtifacts() {
    return Path("build");
}

auto gmockLib() {
    return buildArtifacts ~ "libgmock_gtest.a";
}

private void delegate(string) oldYap = null;
private string[] yapLog;

static this() {
    scriptlikeCustomEcho = (string s) => dextoolYap(s);
    echoOn;
}

void dextoolYap(string msg) nothrow {
    yapLog ~= msg;
}

void dextoolYap(T...)(T args) {
    import std.format : format;

    yapLog ~= format(args);
}

string[] getYapLog() {
    return yapLog.dup;
}

void resetYapLog() {
    yapLog.length = 0;
}

void echoOn() {
    .scriptlikeEcho = true;
}

void echoOff() {
    .scriptlikeEcho = false;
}

string escapePath(in Path p) {
    import scriptlike : escapeShellArg;

    return p.raw.dup.escapeShellArg;
}

deprecated("to be removed") auto runAndLog(T)(T args_) {
    import std.traits : Unqual;

    static if (is(Unqual!T == Path)) {
        string args = args_.escapePath;
    } else static if (is(Unqual!T == Args)) {
        string args = args_.data;
    } else {
        string args = args_;
    }

    auto status = tryRunCollect(args);

    yap("Exit status: ", status.status);
    yap(status.output);
    return status;
}

void syncMkdirRecurse(string p) nothrow {
    synchronized {
        try {
            mkdirRecurse(p);
        } catch (Exception e) {
        }
    }
}

struct TestEnv {
    import std.ascii : newline;

    private Path outdir_;
    private string outdir_suffix;
    private Path dextool_;

    this(Path dextool) {
        this.dextool_ = dextool.absolutePath;
    }

    Path outdir() const nothrow {
        try {
            return ((buildArtifacts ~ outdir_).stripExtension ~ outdir_suffix).absolutePath;
        } catch (Exception e) {
            return ((buildArtifacts ~ outdir_).stripExtension ~ outdir_suffix);
        }
    }

    Path dextool() const {
        return dextool_;
    }

    string toString() {
        // dfmt off
        return only(
                    ["dextool:", dextool.toString],
                    ["outdir:", outdir.toString],
                    )
            .map!(a => leftJustifier(a[0], 10).text ~ a[1])
            .joiner(newline)
            .text;
        // dfmt on
    }

    void setOutput(Path outdir__) {
        this.outdir_ = outdir__;
    }

    /** Setup the test environment
     *
     * Example of using the outputSuffix.
     * ---
     * mixin(envSetup(globalTestdir, No.setupEnv));
     * testEnv.outputSuffix("foo");
     * testEnv.setupEnv;
     * ---
     */
    void outputSuffix(string suffix) {
        this.outdir_suffix = suffix;
    }

    void setupEnv() {
        yap("Test environment:", newline, toString);
        syncMkdirRecurse(outdir.toString);
        cleanOutdir;
    }

    void cleanOutdir() nothrow {
        // ensure logs are empty
        const auto d = outdir();

        string[] files;

        try {
            files = dirEntries(d, SpanMode.depth).filter!(a => a.isFile)
                .map!(a => a.name)
                .array();
        } catch (Exception e) {
        }

        foreach (a; files) {
            // tryRemove can fail, usually duo to I/O when tests are ran in
            // parallel.
            try {
                tryRemove(Path(a));
            } catch (Exception e) {
            }
        }
    }

    void setup(Path outdir__) {
        setOutput(outdir__);
        setupEnv;
    }

    void teardown() {
        auto stdout_path = outdir ~ "console.log";
        File logfile;
        try {
            logfile = File(stdout_path.toString, "w");
        } catch (Exception e) {
            logger.trace(e.msg);
            return;
        }

        // Use when saving error data for later analyze
        foreach (l; getYapLog) {
            logfile.writeln(l);
        }
        resetYapLog();
    }
}

//TODO deprecated, use envSetup instead.
string EnvSetup(string logdir) {
    return envSetup(logdir, Yes.setupEnv);
}

string envSetup(string logdir, Flag!"setupEnv" setupEnv = Yes.setupEnv) {
    import std.format : format;

    auto txt = `
    import scriptlike;

    auto testEnv = TestEnv(Path("%s"));

    // Setup and cleanup
    scope (exit) {
        testEnv.teardown();
    }
    chdir(thisExePath.dirName);

    {
        import std.traits : fullyQualifiedName;
        int _ = 0;
        testEnv.setOutput(Path("%s/" ~ fullyQualifiedName!_));
    }
`;

    txt = format(txt, dextoolExePath, logdir);

    if (setupEnv) {
        txt ~= "\ntestEnv.setupEnv();\n";
    }

    return txt;
}

struct GR {
    Path gold;
    Path result;
}

auto removeJunk(R)(R r, Flag!"skipComments" skipComments) {
    import std.algorithm : filter;
    import std.range : tee;

    // dfmt off
    return r
        // remove comments
        .filter!(a => !skipComments || !(a.value.strip.length > 2 && a.value.strip[0 .. 2] == "//"))
        // remove the line with the version
        .filter!(a => !(a.value.length > 39 && a.value[0 .. 39] == "/// @brief Generated by dextool version"))
        .filter!(a => !(a.value.length > 32 && a.value[0 .. 32] == "/// Generated by dextool version"))
        // remove empty lines
        .filter!(a => a.value.strip.length != 0);
    // dfmt on
}

/** Sorted compare of gold and result.
 *
 * TODO remove this function when all tests are converted to using BuildCompare.
 *
 * max_diff is arbitrarily chosen to 5.
 * The purpose is to limit the amount of text that is dumped.
 * The reasoning is that it is better to give more than one line as feedback.
 */
deprecated("to be removed") void compare(in Path gold, in Path result,
        Flag!"sortLines" sortLines, Flag!"skipComments" skipComments = Yes.skipComments) {
    import std.stdio : File;

    yap("Comparing gold:", gold.raw);
    yap("        result:", result.raw);

    File goldf;
    File resultf;

    try {
        goldf = File(gold.escapePath);
        resultf = File(result.escapePath);
    } catch (ErrnoException ex) {
        throw new ErrorLevelException(-1, ex.msg);
    }

    auto maybeSort(T)(T lines) {
        import std.array : array;
        import std.algorithm : sort;

        if (sortLines) {
            return sort!((a, b) => a[1] < b[1])(lines.array()).array();
        }

        return lines.array();
    }

    bool diff_detected = false;
    immutable max_diff = 5;
    int accumulated_diff;
    // dfmt off
    foreach (g, r;
             lockstep(maybeSort(goldf
                                .byLineCopy()
                                .enumerate
                                .removeJunk(skipComments)),
                      maybeSort(resultf
                                .byLineCopy()
                                .enumerate
                                .removeJunk(skipComments))
                      )) {
        if (g[1] != r[1] && accumulated_diff < max_diff) {
            // +1 of index because editors start counting lines from 1
            yap("Line ", g[0] + 1, " gold:", g[1]);
            yap("Line ", r[0] + 1, "  out:", r[1], "\n");
            diff_detected = true;
            ++accumulated_diff;
        }
    }
    // dfmt on

    //TODO replace with enforce
    if (diff_detected) {
        yap("Output is different from reference file (gold): " ~ gold.escapePath);
        throw new ErrorLevelException(-1,
                "Output is different from reference file (gold): " ~ gold.escapePath);
    }
}

deprecated("to be removed") bool stdoutContains(const string txt) {
    import std.string : indexOf;

    return getYapLog().joiner().array().indexOf(txt) != -1;
}

/// Check if a log contains the fragment txt.
bool sliceContains(const string[] log, const string txt) {
    import std.string : indexOf;

    return log.dup.joiner().array().indexOf(txt) != -1;
}

/// Check if the logged stdout data contains the input range.
bool stdoutContains(T)(const T gold_lines) if (isInputRange!T) {
    auto result_lines = getYapLog().map!(a => a.splitLines).joiner().array();
    return sliceContains(result_lines, gold_lines);
}

/// Check if the log contains the input range.
bool sliceContains(T)(const string[] log, const T gold_lines) if (isInputRange!T) {
    import std.array : array;
    import std.range : enumerate;
    import std.string : indexOf;
    import std.traits : isArray;

    enum ContainState {
        NotFoundFirstLine,
        Comparing,
        BlockFound,
        BlockNotFound
    }

    ContainState state;

    auto result_lines = log;
    size_t gold_idx, result_idx;

    while (!state.among(ContainState.BlockFound, ContainState.BlockNotFound)) {
        string result_line;
        // ensure it doesn't do an out-of-range indexing
        if (result_idx < result_lines.length) {
            result_line = result_lines[result_idx];
        }

        switch (state) with (ContainState) {
        case NotFoundFirstLine:
            if (result_line.indexOf(gold_lines[0].strip) != -1) {
                state = Comparing;
                ++gold_idx;
            } else if (result_lines.length == result_idx) {
                state = BlockNotFound;
            }
            break;
        case Comparing:
            if (gold_lines.length == gold_idx) {
                state = BlockFound;
            } else if (result_lines.length == result_idx) {
                state = BlockNotFound;
            } else if (result_line.indexOf(gold_lines[gold_idx].strip) == -1) {
                state = BlockNotFound;
            } else {
                ++gold_idx;
            }
            break;
        default:
        }

        if (state == ContainState.BlockNotFound && result_lines.length == result_idx) {
            yap("Error: log do not contain the reference lines");
            yap(" Expected: " ~ gold_lines[0]);
        } else if (state == ContainState.BlockNotFound) {
            yap("Error: Difference from reference. Line ", gold_idx);
            yap(" Expected: " ~ gold_lines[gold_idx]);
            yap("   Actual: " ~ result_line);
        }

        if (state.among(ContainState.BlockFound, ContainState.BlockNotFound)) {
            break;
        }

        ++result_idx;
    }

    return state == ContainState.BlockFound;
}

/// Check if the logged stdout contains the golden block.
///TODO refactor function. It is unnecessarily complex.
bool stdoutContains(in Path gold) {
    import std.array : array;
    import std.range : enumerate;
    import std.stdio : File;

    yap("Contains gold:", gold.raw);

    File goldf;

    try {
        goldf = File(gold.escapePath);
    } catch (ErrnoException ex) {
        yap(ex.msg);
        return false;
    }

    bool status = stdoutContains(goldf.byLine.array());

    if (!status) {
        yap("Output do not contain the reference file (gold): " ~ gold.escapePath);
        return false;
    }

    return true;
}

/** Run dextool.
 *
 * Return: The runtime in ms.
 */
deprecated("to be removed") auto runDextool(T)(in T input,
        const ref TestEnv testEnv, in string[] pre_args, in string[] flags) {
    import std.traits : isArray;
    import std.algorithm : min;

    Args args;
    args ~= testEnv.dextool;
    args ~= pre_args.dup;
    args ~= "--out=" ~ testEnv.outdir.escapePath;

    static if (isArray!T) {
        foreach (f; input) {
            args ~= "--in=" ~ f.escapePath;
        }
    } else {
        if (input.escapePath.length > 0) {
            args ~= "--in=" ~ input.escapePath;
        }
    }

    if (flags.length > 0) {
        args ~= "--";
        args ~= flags.dup;
    }

    import std.datetime;

    StopWatch sw;
    sw.start;
    auto output = runAndLog(args.data);
    sw.stop;
    yap("Dextool execution time was ms: " ~ sw.peek().msecs.text);

    if (output.status != 0) {
        auto l = min(100, output.output.length);

        throw new ErrorLevelException(output.status, output.output[0 .. l].dup);
    }

    return sw.peek.msecs;
}

deprecated("to be removed") auto filesToDextoolInFlags(T)(const T in_files) {
    Args args;

    static if (isArray!T) {
        foreach (f; input) {
            args ~= "--in=" ~ f.escapePath;
        }
    } else {
        if (input.escapePath.length > 0) {
            args ~= "--in=" ~ input.escapePath;
        }
    }

    return args;
}

/** Construct an execution of dextool with needed arguments.
 */
auto makeDextool(const ref TestEnv testEnv) {
    import dextool_test.builders : BuildDextoolRun;

    return BuildDextoolRun(testEnv.dextool.escapePath, testEnv.outdir.escapePath);
}

/** Construct an execution of a command.
 */
auto makeCommand(string command) {
    return BuildCommandRun(command);
}

/** Construct an execution of a command.
 */
auto makeCommand(const ref TestEnv testEnv, string command) {
    return BuildCommandRun(command, testEnv.outdir.escapePath);
}

auto makeCompare(const ref TestEnv env) {
    import dextool_test.golden : BuildCompare;

    return BuildCompare(env.outdir.escapePath);
}

deprecated("to be removed") void compareResult(T...)(Flag!"sortLines" sortLines,
        Flag!"skipComments" skipComments, in T args) {
    static assert(args.length >= 1);

    foreach (a; args) {
        if (existsAsFile(a.gold)) {
            compare(a.gold, a.result, sortLines, skipComments);
        }
    }
}

string testId(uint line = __LINE__) {
    import std.conv : to;

    // assuming it is always the UDA for a test and thus +1 to get the correct line
    return "id:" ~ (line + 1).to!string() ~ " ";
}

/**
 * Params:
 *  dir = directory to perform the recursive search in
 *  ext = extension of the files to match (including dot)
 *
 * Returns: a list of all files with the extension
 */
auto recursiveFilesWithExtension(Path dir, string ext) {
    // dfmt off
    return std.file.dirEntries(dir.toString, SpanMode.depth)
        .filter!(a => a.isFile)
        .filter!(a => extension(a.name) == ext)
        .map!(a => Path(a));
    // dfmt on
}

/// Shallow copy the content while keeping the executable bit from `src` to `dst`.
void dirContentCopy(string src, string dst) {
    import std.algorithm;
    import std.file;
    import std.path;
    import core.sys.posix.sys.stat;

    assert(src.isDir);
    assert(dst.isDir);

    foreach (f; dirEntries(src, SpanMode.shallow).filter!"a.isFile") {
        auto dst_f = buildPath(dst, f.name.baseName);
        copy(f.name, dst_f);
        auto attrs = getAttributes(f.name);
        if (attrs & S_IXUSR)
            setAttributes(dst_f, attrs | S_IXUSR);
    }
}
