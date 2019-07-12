/**
Copyright: Copyright (c) 2017, Joakim Brännström. All rights reserved.
License: MPL-2
Author: Joakim Brännström (joakim.brannstrom@gmx.com)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.
*/
module dextool_test.builders;

import core.thread : Thread;
import core.time : dur, msecs;
import logger = std.experimental.logger;
import std.algorithm : map, min, each, joiner;
import std.array : array, Appender;
import std.datetime.stopwatch : StopWatch;
import std.path : buildPath;
import std.range : isInputRange;
import std.stdio : File;
import std.string : join;
import std.traits : ReturnType;
import std.typecons : Yes, No, Flag;

static import core.thread;
static import std.process;

import dextool_test.types;

/** Build the command line arguments and working directory to use when invoking
 * dextool.
 */
struct BuildDextoolRun {
    import std.ascii : newline;

    private {
        string dextool;
        string workdir_;
        string test_outputdir;
        string[] args_;
        string[] post_args;
        string[] flags_;

        /// Data to stream into stdin upon execute.
        string stdin_data;

        /// if the output from running the command should be saved to a logfile
        bool save_output = true;

        /// if --debug is added to the arguments
        bool arg_debug = true;

        /// Throw an exception if the exit status is NOT zero
        bool throw_on_exit_status = true;
    }

    /**
     * Params:
     *  dextool = the executable to run
     *  workdir = directory to run the executable from
     */
    this(string dextool, string workdir) {
        this.dextool = dextool;
        this.workdir_ = workdir;
        this.test_outputdir = workdir;
    }

    this(Path dextool, Path workdir) {
        this(dextool.toString, workdir.toString);
    }

    Path workdir() {
        return Path(workdir_);
    }

    auto setWorkdir(T)(T v) {
        static if (is(T == string))
            workdir_ = v;
        else static if (is(T == typeof(null)))
            workdir_ = null;
        else
            workdir_ = v.toString;
        return this;
    }

    auto setStdin(string v) {
        this.stdin_data = v;
        return this;
    }

    auto throwOnExitStatus(bool v) {
        this.throw_on_exit_status = v;
        return this;
    }

    auto flags(string[] v) {
        this.flags_ = v;
        return this;
    }

    auto addFlag(T)(T v) {
        this.flags_ ~= v;
        return this;
    }

    auto addDefineFlag(string v) {
        this.flags_ ~= ["-D", v];
        return this;
    }

    auto addIncludeFlag(string v) {
        this.flags_ ~= ["-I", v];
        return this;
    }

    auto addIncludeFlag(Path v) {
        this.flags_ ~= ["-I", v.toString];
        return this;
    }

    auto args(string[] v) {
        this.args_ = v;
        return this;
    }

    auto addArg(T)(T v) {
        this.args_ ~= v;
        return this;
    }

    auto addArg(Path v) {
        this.args_ ~= v.toString;
        return this;
    }

    auto addInputArg(string v) {
        post_args ~= ["--in", v];
        return this;
    }

    auto addInputArg(string[] v) {
        post_args ~= v.map!(a => ["--in", a]).joiner.array();
        return this;
    }

    auto addInputArg(Path v) {
        post_args ~= ["--in", v.toString];
        return this;
    }

    auto addInputArg(Path[] v) {
        post_args ~= v.map!(a => ["--in", a.toString]).joiner.array();
        return this;
    }

    auto postArg(string[] v) {
        this.post_args = v;
        return this;
    }

    auto addPostArg(T)(T v) {
        this.post_args ~= v;
        return this;
    }

    auto addPostArg(Path v) {
        this.post_args ~= v.toString;
        return this;
    }

    /// Activate debugging mode of the dextool binary
    auto argDebug(bool v) {
        arg_debug = v;
        return this;
    }

    deprecated("replaced by saveOutput") auto yapOutput(bool v) {
        save_output = v;
        return this;
    }

    auto saveOutput(bool v) {
        save_output = v;
        return this;
    }

    auto run() {
        string[] cmd;
        cmd ~= dextool;
        cmd ~= args_.dup;
        cmd ~= post_args;
        if (workdir_.length != 0)
            cmd ~= "--out=" ~ workdir_;

        if (arg_debug) {
            cmd ~= "--debug";
        }

        if (flags_.length > 0) {
            cmd ~= "--";
            cmd ~= flags_.dup;
        }

        logger.tracef("run: %-(%s %)", cmd);

        StopWatch sw;
        ReturnType!(std.process.tryWait) exit_;
        exit_.status = -1;
        Appender!(string[]) stdout_;
        Appender!(string[]) stderr_;

        sw.start;
        try {
            auto pipe_mode = std.process.Redirect.stdout | std.process.Redirect.stderr;
            if (stdin_data.length != 0)
                pipe_mode |= std.process.Redirect.stdin;

            auto p = std.process.pipeProcess(cmd, pipe_mode);
            if (stdin_data.length != 0) {
                p.stdin.writeln(stdin_data);
                p.stdin.close;
            }

            for (;;) {
                exit_ = std.process.tryWait(p.pid);

                foreach (l; p.stdout.byLineCopy)
                    stdout_.put(l);
                foreach (l; p.stderr.byLineCopy)
                    stderr_.put(l);

                if (exit_.terminated)
                    break;
                core.thread.Thread.sleep(20.msecs);
            }
            sw.stop;
        } catch (Exception e) {
            stderr_ ~= [e.msg];
            sw.stop;
        }

        auto rval = BuildCommandRunResult(exit_.status == 0, exit_.status,
                stdout_.data, stderr_.data, sw.peek.total!"msecs", cmd);
        if (save_output) {
            auto f = File(nextFreeLogfile(test_outputdir), "w");
            f.writef("%s", rval);
        }

        if (throw_on_exit_status && exit_.status != 0) {
            import std.algorithm : joiner;
            import std.array : join;
            import std.range : only;

            throw new ErrorLevelException(exit_.status, only(stdout_.data,
                    stderr_.data).joiner.join(newline));
        } else {
            return rval;
        }
    }
}

/** Build the command line arguments and working directory to use when invoking
 * a command.
 */
struct BuildCommandRun {
    import std.ascii : newline;

    private {
        string command;
        string workdir_;
        string[] args_;
        string[] post_args;

        /// Data to stream into stdin upon execute.
        string stdin_data;

        bool run_in_outdir;

        /// if the output from running the command should be saved to a file.
        bool save_output = true;

        /// Throw an exception if the exit status is NOT zero
        bool throw_on_exit_status = true;
    }

    this(string command) {
        this.command = command;
        run_in_outdir = false;
    }

    /**
     * Params:
     *  command = the executable to run
     *  workdir = directory to run the executable from
     */
    this(string command, string workdir) {
        this.command = command;
        this.workdir_ = workdir;
        run_in_outdir = true;
    }

    this(string command, Path workdir) {
        this(command, workdir.toString);
    }

    Path workdir() {
        return Path(workdir_);
    }

    auto setWorkdir(Path v) {
        workdir_ = v.toString;
        return this;
    }

    /// If the command to run is in workdir.
    auto commandInOutdir(bool v) {
        run_in_outdir = v;
        return this;
    }

    auto throwOnExitStatus(bool v) {
        this.throw_on_exit_status = v;
        return this;
    }

    auto setStdin(string v) {
        this.stdin_data = v;
        return this;
    }

    auto args(string[] v) {
        this.args_ = v;
        return this;
    }

    auto postArgs(string[] v) {
        this.post_args = v;
        return this;
    }

    auto addArg(string v) {
        this.args_ ~= v;
        return this;
    }

    auto addArg(Path v) {
        this.args_ ~= v.toString;
        return this;
    }

    auto addArg(string[] v) {
        this.args_ ~= v;
        return this;
    }

    auto addPostArg(string v) {
        this.post_args ~= v;
        return this;
    }

    auto addPostArg(Path v) {
        this.post_args ~= v.toString;
        return this;
    }

    auto addPostArg(string[] v) {
        this.post_args ~= v;
        return this;
    }

    auto addFileFromOutdir(string v) {
        this.args_ ~= buildPath(workdir_, v);
        return this;
    }

    deprecated("replaced by saveOutput") auto yapOutput(bool v) {
        save_output = v;
        return this;
    }

    auto saveOutput(bool v) {
        save_output = v;
        return this;
    }

    auto run() {
        import std.path : buildPath;

        string[] cmd;
        if (run_in_outdir)
            cmd ~= buildPath(workdir.toString, command);
        else
            cmd ~= command;
        cmd ~= args_.dup;
        cmd ~= post_args;

        StopWatch sw;
        ReturnType!(std.process.tryWait) exit_;
        exit_.status = -1;
        Appender!(string[]) stdout_;
        Appender!(string[]) stderr_;

        sw.start;
        try {
            auto pipe_mode = std.process.Redirect.stdout | std.process.Redirect.stderr;
            if (stdin_data.length != 0)
                pipe_mode |= std.process.Redirect.stdin;

            auto p = std.process.pipeProcess(cmd, pipe_mode);
            if (stdin_data.length != 0) {
                p.stdin.writeln(stdin_data);
                p.stdin.close;
            }

            for (;;) {
                exit_ = std.process.tryWait(p.pid);

                foreach (l; p.stdout.byLineCopy)
                    stdout_.put(l);
                foreach (l; p.stderr.byLineCopy)
                    stderr_.put(l);

                if (exit_.terminated)
                    break;
                core.thread.Thread.sleep(10.msecs);
            }

            sw.stop;
        } catch (Exception e) {
            stderr_ ~= [e.msg];
            sw.stop;
        }

        auto rval = BuildCommandRunResult(exit_.status == 0, exit_.status,
                stdout_.data, stderr_.data, sw.peek.total!"msecs", cmd);
        if (save_output) {
            auto f = File(nextFreeLogfile(workdir_), "w");
            f.writef("%s", rval);
        }

        if (throw_on_exit_status && exit_.status != 0) {
            throw new ErrorLevelException(exit_.status, stderr_.data.join(newline));
        } else {
            return rval;
        }
    }
}

private auto nextFreeLogfile(string workdir) {
    import std.file : exists;
    import std.path : baseName, buildPath;
    import std.string : format;

    int idx;
    string f;
    do {
        f = buildPath(workdir, format("run_command%s.log", idx));
        ++idx;
    }
    while (exists(f));

    return f;
}

struct BuildCommandRunResult {
    import std.ascii : newline;
    import std.format : FormatSpec;

    /// convenient value which is true when exit status is zero.
    const bool success;
    /// actual exit status
    const int status;
    /// captured output
    string[] stdout;
    string[] stderr;
    /// time to execute the command. TODO: change to Duration after DMD v2.076
    const long executionMsecs;

    private string[] cmd;

    void toString(Writer, Char)(scope Writer w, FormatSpec!Char fmt) const {
        import std.algorithm : joiner;
        import std.format : formattedWrite;
        import std.range.primitives : put;

        formattedWrite(w, "run: %s", cmd.dup.joiner(" "));
        put(w, newline);

        formattedWrite(w, "exit status: %s", status);
        put(w, newline);
        formattedWrite(w, "execution time ms: %s", executionMsecs);
        put(w, newline);

        put(w, "stdout:");
        put(w, newline);
        this.stdout.each!((a) { put(w, a); put(w, newline); });

        put(w, "stderr:");
        put(w, newline);
        this.stderr.each!((a) { put(w, a); put(w, newline); });
    }

    string toString() @safe pure const {
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
}
