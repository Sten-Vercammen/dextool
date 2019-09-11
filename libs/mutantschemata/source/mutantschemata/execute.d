/**
Copyright: Copyright (c) 2019, Niklas Pettersson. All rights reserved.
License: MPL-2
Author: Niklas Pettersson (nikpe353@student.liu.se)

This Source Code Form is subject to the terms of the Mozilla Public License,
v.2.0. If a copy of the MPL was not distributed with this file, You can obtain
one at http://mozilla.org/MPL/2.0/.


The execution parts of the mutantschemata api.
*/
module mutantschemata.execute;

import std.typecons: Nullable;
import std.meta: Alias;
import core.time: Duration, dur;
import std.algorithm: among;
import std.datetime.stopwatch: StopWatch;
import std.exception : collectException;

import logger = std.experimental.logger;

import mutantschemata.type;
import mutantschemata.externals;

import dextool.type: ExitStatusType, ShellCommand;
import dextool.plugin.mutate.config: ConfigMutationTest;
import dextool.plugin.mutate.backend.type: Mutation;
import dextool.plugin.mutate.backend.watchdog: StaticTime, ProgressivWatchdog;
import dextool.plugin.mutate.backend.utility: rndSleep;

/*
*   Compiles the project with the given build-script and flags.
*   Return: true if compilation was successfull, false if any mutants injected caused errors.
*/
execVal preCompileSut(ConfigMutationTest mutationTest) {
    import std.process: execute;
    typeof (return) rval;

    try {
        rval = execute(mutationTest.mutationCompile.program ~ mutationTest.mutationCompile.arguments);
    } catch (Exception e) {
        // unable to for example execute the compiler
        logger.error(e.msg);
    }

    return rval;
}

Nullable!ProgressivWatchdog preMeasureTestSuite(ConfigMutationTest config) {
    typeof (return) rval;

    if (config.mutationTesterRuntime.isNull) {
        logger.info("Measuring the time to run the tests: ", config.mutationTester);
        auto tester = measureTestDuration(config.mutationTester);
        if (tester.status == ExitStatusType.Ok) {
            // The sampling of the test suite become too unreliable when the timeout is <1s.
            // This is a quick and dirty fix.
            // A proper fix requires an update of the sampler in runTester.
            auto t = tester.runtime < 1.dur!"seconds" ? 1.dur!"seconds" : tester.runtime;
            logger.info("Tester measured to: ", t);
            rval = ProgressivWatchdog(t);
        } else {
            logger.error("Test suite is unreliable. It must return exit status '0' when running with unmodified mutants");
        }
    } else {
        rval =  ProgressivWatchdog(config.mutationTesterRuntime.get);
    }
    return rval;
}

/*
*   Test the project with the given test-script and flags.
*   Return: Mutation.status for
*/
Mutation.Status schemataTester(ConfigMutationTest config, StaticTime!StopWatch watchdog) @trusted {
    import dextool.plugin.mutate.backend.linux_process : spawnSession, tryWait, kill, wait;

    typeof (return) rval;

    try {
        auto p = spawnSession(config.mutationTester.program ~ config.mutationTester.arguments);
        // trusted: killing the process started in this scope
        void cleanup() @safe nothrow {
            import core.sys.posix.signal : SIGKILL;

            if (rval.among(Mutation.Status.timeout, Mutation.Status.unknown)) {
                kill(p, SIGKILL);
                wait(p);
            }
        }

        scope (exit)
            cleanup;

        rval = Mutation.Status.timeout;
        watchdog.start;
        while (watchdog.isOk) {
            auto res = tryWait(p);
            if (res.terminated) {
                if (res.status == 0)
                    rval = Mutation.Status.alive;
                else
                    rval = Mutation.Status.killed;
                break;
            }

            rndSleep(10.dur!"msecs", 50);
        }
    } catch (Exception e) {
        // unable to for example execute the test suite
        logger.warning(e.msg);
        rval = Mutation.Status.unknown;
    }
    return rval;
}

struct MeasureResult {
    ExitStatusType status;
    Duration runtime;
}

MeasureResult measureTestDuration(ShellCommand cmd) nothrow {
    if (cmd.program.length == 0) {
        collectException(logger.error("No test suite runner specified (--mutant-tester)"));
        return MeasureResult(ExitStatusType.Errors);
    }

    auto any_failure = ExitStatusType.Ok;

    void fun() {
        import std.process : execute;

        auto res = execute(cmd.program ~ cmd.arguments);
        if (res.status != 0)
            any_failure = ExitStatusType.Errors;
    }

    import std.datetime.stopwatch : benchmark;
    import std.algorithm : minElement, map;
    import core.time : dur;

    try {
        auto bench = benchmark!fun(3);

        if (any_failure != ExitStatusType.Ok)
            return MeasureResult(ExitStatusType.Errors);

        auto a = (cast(long)((bench[0].total!"msecs") / 3.0)).dur!"msecs";
        return MeasureResult(ExitStatusType.Ok, a);
    } catch (Exception e) {
        collectException(logger.error(e.msg));
        return MeasureResult(ExitStatusType.Errors);
    }
}
