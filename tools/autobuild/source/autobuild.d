/**
Date: 2016, Joakim Brännström
License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
Author: Joakim Brännström (joakim.brannstrom@gmx.com)
 */
module autobuild;

import std.algorithm : map, splitter, filter, among, each, canFind, count;
import std.array : array;
import std.file : thisExePath, exists, mkdir, remove, dirEntries, SpanMode, chdir;
import std.format : format;
import std.path : buildPath, dirName, extension;
import std.process : execute, spawnShell, Config, wait;
import std.range : only, chain, take;
import std.stdio : stdin, writeln, File, write, writefln;
import std.string : splitLines, toStringz, fromStringz;
import std.typecons : Flag, Yes, No, Tuple;

Flag!"SignalInterrupt" signalInterrupt;
Flag!"TestsPassed" signalExitStatus;

bool skipStaticAnalysis = true;

/// Tag a string as a path and make it absolute+normalized.
struct Path {
    import std.path : absolutePath, buildNormalizedPath;

    private string value_;
    alias value this;

    this(Path p) {
        value_ = p.value_;
    }

    this(string p) {
        value_ = p.absolutePath.buildNormalizedPath;
    }

    string value() @safe pure nothrow const @nogc {
        return value_;
    }

    void opAssign(string rhs) @safe pure {
        value_ = rhs.absolutePath.buildNormalizedPath;
    }

    void opAssign(typeof(this) rhs) @safe pure nothrow {
        value_ = rhs.value_;
    }

    string toString() @safe pure nothrow const @nogc {
        return value_;
    }
}

enum Color {
    red,
    green,
    yellow,
    cancel
}

enum Status {
    Fail,
    Warn,
    Ok,
    Run
}

auto sourcePath() {
    // those that are supported by the developer of Dextool

    // dfmt off
    return only(
                "libs",
                "plugin",
                "source",
               )
        .map!(a => buildPath(thisExePath.dirName, a))
        .array();
    // dfmt on
}

auto gitHEAD() {
    // Initial commit: diff against an empty tree object
    string against = "4b825dc642cb6eb9a060e54bf8d69288fbee4904";

    auto res = execute("git rev-parse --verify HEAD");
    if (res.status == 0) {
        against = res.output;
    }

    return against;
}

auto gitChangdedFiles(string[] file_extensions) {
    string[] a;
    a ~= "git";
    a ~= "diff-index";
    a ~= "--name-status";
    a ~= ["--cached", gitHEAD];

    auto res = execute(a);
    if (res.status != 0) {
        writeln("error: ", res.output);
    }

    // dfmt off
    return res.output
        .splitLines
        .map!(a => a.splitter.array())
        .filter!(a => a.length == 2)
        .filter!(a => a[0].among("M", "A"))
        .filter!(a => canFind(file_extensions, extension(a[1])))
        .map!(a => a[1]);
    // dfmt on
}

void print(T...)(Color c, T args) {
    static immutable string[] escCodes = [
        "\033[31;1m", "\033[32;1m", "\033[33;1m", "\033[0;;m"
    ];
    write(escCodes[c], args, escCodes[Color.cancel]);
}

void println(T...)(Color c, T args) {
    static immutable string[] escCodes = [
        "\033[31;1m", "\033[32;1m", "\033[33;1m", "\033[0;;m"
    ];
    writeln(escCodes[c], args, escCodes[Color.cancel]);
}

void printStatus(T...)(Status s, T args) {
    Color c;
    string txt;

    final switch (s) {
    case Status.Ok:
        c = Color.green;
        txt = "[  OK ] ";
        break;
    case Status.Run:
        c = Color.yellow;
        txt = "[ RUN ] ";
        break;
    case Status.Fail:
        c = Color.red;
        txt = "[ FAIL] ";
        break;
    case Status.Warn:
        c = Color.red;
        txt = "[ WARN] ";
        break;
    }

    print(c, txt);
    writeln(args);
}

void playSound(Flag!"Positive" positive) nothrow {
    static import std.stdio;
    import std.process;

    static Pid last_pid;

    try {
        auto devnull = std.stdio.File("/dev/null", "w");

        if (last_pid !is null && last_pid.processID != 0) {
            // cleanup possible zombie process
            last_pid.wait;
        }

        auto a = ["mplayer", "-nostop-xscreensaver"];
        if (positive)
            a ~= "/usr/share/sounds/KDE-Sys-App-Positive.ogg";
        else
            a ~= "/usr/share/sounds/KDE-Sys-App-Negative.ogg";

        last_pid = spawnProcess(a, std.stdio.stdin, devnull, devnull);
    } catch (ProcessException ex) {
    } catch (Exception ex) {
    }
}

bool sanityCheck() {
    if (!exists("dub.sdl")) {
        writeln("Missing dub.sdl");
        return false;
    }

    return true;
}

void consoleToFile(Path fname, string console) {
    writeln("console log written to -> ", fname);

    auto f = File(fname.toString, "w");
    f.write(console);
}

Path cmakeDir() {
    return buildPath(thisExePath.dirName, "build").Path;
}

void setup() {
    //echoOn;

    if (!exists("build")) {
        mkdir("build");
    }

    auto r = execute([
            "cmake", "-DCMAKE_BUILD_TYPE=Debug", "-DBUILD_TEST=ON", ".."
            ], null, Config.none, size_t.max, cmakeDir);
    writeln(r.output);

    import core.stdc.signal;

    signal(SIGINT, &handleSIGINT);
}

extern (C) void handleSIGINT(int sig) nothrow @nogc @system {
    .signalInterrupt = Yes.SignalInterrupt;
}

void cleanup(Flag!"keepCoverage" keep_cov) {
    import std.algorithm : predSwitch;

    printStatus(Status.Run, "Cleanup");
    scope (failure)
        printStatus(Status.Fail, "Cleanup");

    // dfmt off
    chain(
          dirEntries(".", "trace.*", SpanMode.shallow).map!(a => Path(a)).array(),
          keep_cov.predSwitch(Yes.keepCoverage, string[].init.map!(a => Path(a)).array(),
                              No.keepCoverage, dirEntries(".", "*.lst", SpanMode.shallow).map!(a => Path(a)).array())
         )
        .each!(a => remove(a));
    // dfmt on

    printStatus(Status.Ok, "Cleanup");
}

/** Call appropriate function for for the state.
 *
 * Generate calls to functions of fsm based on st.
 *
 * Params:
 *  fsm = object with methods with prefix st_
 *  st = current state
 */
auto GenerateFsmAction(T, TEnum)(ref T fsm, TEnum st) {
    import std.traits;

    final switch (st) {
        foreach (e; EnumMembers!TEnum) {
            mixin(format(q{
                         case %s.%s.%s:
                           fsm.state%s();
                           break;

                         }, typeof(fsm).stringof, TEnum.stringof, e, e));
        }
    }
}

/// Moore FSM
/// Exceptions are clearly documented with // FSM exception: REASON
struct Fsm {
    enum State {
        Init,
        Reset,
        Wait,
        Start,
        Ut_run,
        Ut_skip,
        Debug_build,
        Integration_test,
        Test_passed,
        Test_failed,
        Doc_check_counter,
        Doc_build,
        Sloc_check_counter,
        Slocs,
        AudioStatus,
        ExitOrRestart,
        Exit
    }

    State st;
    Path[] inotify_paths;

    Flag!"utDebug" flagUtDebug;

    // Signals used to determine next state
    Flag!"UtTestPassed" flagUtTestPassed;
    Flag!"CompileError" flagCompileError;
    Flag!"TotalTestPassed" flagTotalTestPassed;
    int docCount;
    int analyzeCount;

    alias ErrorMsg = Tuple!(Path, "fname", string, "msg", string, "output");
    ErrorMsg[] testErrorLog;

    void run(Path[] inotify_paths, Flag!"Travis" travis,
            Flag!"utDebug" ut_debug, Flag!"utSkip" ut_skip) {
        this.inotify_paths = inotify_paths;
        this.flagUtDebug = ut_debug;

        while (!signalInterrupt) {
            debug {
                writeln("State ", st.to!string);
            }

            GenerateFsmAction(this, st);

            updateTotalTestStatus();

            st = Fsm.next(st, docCount, analyzeCount, flagUtTestPassed,
                    flagCompileError, flagTotalTestPassed, travis, ut_skip);
        }
    }

    void updateTotalTestStatus() {
        if (testErrorLog.length != 0) {
            flagTotalTestPassed = No.TotalTestPassed;
        } else if (flagUtTestPassed == No.UtTestPassed) {
            flagTotalTestPassed = No.TotalTestPassed;
        } else if (flagCompileError == Yes.CompileError) {
            flagTotalTestPassed = No.TotalTestPassed;
        } else {
            flagTotalTestPassed = Yes.TotalTestPassed;
        }
    }

    static State next(State st, int docCount, int analyzeCount,
            Flag!"UtTestPassed" flagUtTestPassed, Flag!"CompileError" flagCompileError,
            Flag!"TotalTestPassed" flagTotalTestPassed, Flag!"Travis" travis,
            Flag!"utSkip" ut_skip) {
        auto next_ = st;

        final switch (st) {
        case State.Init:
            next_ = State.Start;
            break;
        case State.AudioStatus:
            next_ = State.Reset;
            break;
        case State.Reset:
            next_ = State.Wait;
            break;
        case State.Wait:
            next_ = State.Start;
            break;
        case State.Start:
            next_ = State.Ut_run;
            if (ut_skip) {
                next_ = State.Ut_skip;
            }
            break;
        case State.Ut_run:
            next_ = State.ExitOrRestart;
            if (flagUtTestPassed)
                next_ = State.Debug_build;
            break;
        case State.Ut_skip:
            next_ = State.Debug_build;
            break;
        case State.Debug_build:
            next_ = State.Integration_test;
            if (flagCompileError)
                next_ = State.ExitOrRestart;
            break;
        case State.Integration_test:
            next_ = State.ExitOrRestart;
            if (flagTotalTestPassed)
                next_ = State.Test_passed;
            else
                next_ = State.Test_failed;
            break;
        case State.Test_passed:
            next_ = State.Doc_check_counter;
            break;
        case State.Test_failed:
            next_ = State.ExitOrRestart;
            break;
        case State.Doc_check_counter:
            next_ = State.ExitOrRestart;
            if (docCount >= 10 && !travis)
                next_ = State.Doc_build;
            break;
        case State.Doc_build:
            next_ = State.Sloc_check_counter;
            break;
        case State.Sloc_check_counter:
            next_ = State.ExitOrRestart;
            if (analyzeCount >= 10) {
                next_ = State.Slocs;
            }
            break;
        case State.Slocs:
            next_ = State.ExitOrRestart;
            break;
        case State.ExitOrRestart:
            next_ = State.AudioStatus;
            if (travis) {
                next_ = State.Exit;
            }
            break;
        case State.Exit:
            break;
        }

        return next_;
    }

    static void printExitStatus(T...)(int status, T args) {
        if (status == 0)
            printStatus(Status.Ok, args);
        else
            printStatus(Status.Fail, args);
    }

    void stateInit() {
        // force rebuild of doc and show code stat
        docCount = 10;
        analyzeCount = 10;

        writeln("Watching the following paths for changes:");
        inotify_paths.each!writeln;
    }

    void stateAudioStatus() {
        if (!flagCompileError && flagUtTestPassed && testErrorLog.length == 0)
            playSound(Yes.Positive);
        else
            playSound(No.Positive);
    }

    void stateReset() {
        flagCompileError = No.CompileError;
        flagUtTestPassed = No.UtTestPassed;
        testErrorLog.length = 0;
    }

    void stateStart() {
    }

    void stateWait() {
        println(Color.yellow, "================================");

        string[] a;
        a ~= "inotifywait";
        a ~= "-q";
        a ~= "-r";
        a ~= ["-e", "modify"];
        a ~= ["-e", "attrib"];
        a ~= ["-e", "create"];
        a ~= ["-e", "move_self"];
        a ~= ["--format", "%w"];
        a ~= inotify_paths;

        auto r = execute(a, null, Config.none, size_t.max, thisExePath.dirName);

        import core.thread;

        if (signalInterrupt) {
            // do nothing, a SIGINT has been received while sleeping
        } else if (r.status == 0) {
            writeln("Change detected in ", r.output);
            // wait for editor to finish saving the file
            Thread.sleep(dur!("msecs")(500));
        } else {
            enum SLEEP = 10;
            writefln("%-(%s %)", a);
            printStatus(Status.Warn, "Error: ", r.output);
            writeln("sleeping ", SLEEP, "s");
            Thread.sleep(dur!("seconds")(SLEEP));
        }
    }

    void stateUt_run() {
        immutable test_header = "Compile and run unittest";
        printStatus(Status.Run, test_header);

        auto status = spawnShell("make check -j $(nproc)", null, Config.none, cmakeDir).wait;
        flagUtTestPassed = cast(Flag!"UtTestPassed")(status == 0);

        printExitStatus(status, test_header);
    }

    void stateUt_skip() {
        flagUtTestPassed = Yes.UtTestPassed;
    }

    void stateDebug_build() {
        printStatus(Status.Run, "Debug build");

        auto r = spawnShell("make all -j $(nproc)", null, Config.none, cmakeDir).wait;
        flagCompileError = cast(Flag!"CompileError")(r != 0);
        printExitStatus(r, "Debug build with debug symbols");
    }

    void stateIntegration_test() {
        immutable test_header = "Compile and run integration tests";
        printStatus(Status.Run, test_header);

        auto status = spawnShell(`make check_integration -j $(nproc)`, null,
                Config.none, cmakeDir).wait;

        if (status != 0) {
            testErrorLog ~= ErrorMsg(cmakeDir, "integration_test", "failed");
        }

        printExitStatus(status, test_header);
    }

    void stateTest_passed() {
        docCount++;
        analyzeCount++;
        printStatus(Status.Ok, "Test of code generation");
    }

    void stateTest_failed() {
        // separate the log dump to the console from the list of files the logs can be found in.
        // Most common scenario is one failure.
        testErrorLog.each!((a) { writeln(a.output); });
        testErrorLog.each!((a) {
            printStatus(Status.Fail, a.msg, ", log at ", a.fname);
        });

        printStatus(Status.Fail, "Test of code generation");
    }

    void stateDoc_check_counter() {
    }

    void stateDoc_build() {
    }

    void stateSloc_check_counter() {
    }

    void stateSlocs() {
        printStatus(Status.Run, "Code statistics");
        scope (exit)
            printStatus(Status.Ok, "Code statistics");

        string[] a;
        a ~= "dscanner";
        a ~= "--sloc";
        a ~= sourcePath.array();

        auto r = execute(a, null, Config.none, size_t.max, thisExePath.dirName);
        if (r.status == 0) {
            writeln(r.output);
        }

        analyzeCount = 0;
    }

    void stateExitOrRestart() {
    }

    void stateExit() {
        if (flagTotalTestPassed) {
            .signalExitStatus = Yes.TestsPassed;
        } else {
            .signalExitStatus = No.TestsPassed;
        }
        .signalInterrupt = Yes.SignalInterrupt;
    }
}

int main(string[] args) {
    Flag!"keepCoverage" keep_cov;

    chdir(thisExePath.dirName);
    scope (exit)
        cleanup(keep_cov);

    if (!sanityCheck) {
        writeln("error: Sanity check failed");
        return 1;
    }

    import std.getopt;

    bool run_and_exit;
    bool ut_debug;
    bool ut_skip;

    // dfmt off
    auto help_info = getopt(args,
        "run_and_exit", "run the tests in one pass and exit", &run_and_exit,
        "ut_debug", "run tests in single threaded debug mode", &ut_debug,
        "ut_skip", "skip unittests to go straight to the integration tests", &ut_skip);
    // dfmt on

    if (help_info.helpWanted) {
        defaultGetoptPrinter("Usage: autobuild.sh [options]", help_info.options);
        return 0;
    }

    setup();

    // dfmt off
    auto inotify_paths = only(
                              "dub.sdl",
                              "libs",
                              "plugin",
                              "source",
                              "test/source",
                              "test/testdata",
                              "vendor",
        )
        .map!(a => buildPath(thisExePath.dirName, a).Path)
        .array;
    // dfmt on

    import std.stdio;

    (Fsm()).run(inotify_paths, cast(Flag!"Travis") run_and_exit,
            cast(Flag!"utDebug") ut_debug, cast(Flag!"utSkip") ut_skip);

    return signalExitStatus ? 0 : -1;
}
