/**
Copyright: Copyright (c) 2017, Joakim Brännström. All rights reserved.
License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
Author: Joakim Brännström (joakim.brannstrom@gmx.com)
*/
module dextool_test.generate_mutant;

import std.file : copy;

import dextool_test.utility;

// dfmt off

@(testId ~ "shall produce the mutant specified by the ID")
unittest {
    mixin(EnvSetup(globalTestdir));

    immutable dst = testEnv.outdir ~ "report_one_ror_mutation_point.cpp";

    copy((testData ~ "report_one_ror_mutation_point.cpp").toString, dst.toString);

    makeDextoolAnalyze(testEnv)
        .addInputArg(dst)
        .run;
    auto r = dextool_test.makeDextool(testEnv)
        .setWorkdir(workDir)
        .args(["mutate"])
        .addArg(["generate"])
        .addArg(["--id", "12"])
        .addPostArg(["--db", (testEnv.outdir ~ defaultDb).toString])
        .run;

    testAnyOrder!SubStr([
        "-abs_dextool(x)",
    ]).shouldBeIn(readOutput(testEnv, "report_one_ror_mutation_point.cpp"));
}
