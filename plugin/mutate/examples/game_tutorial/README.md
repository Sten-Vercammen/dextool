# Introduction

This directory contains a game used as a complex example where mutation testing
can be applied.

The test cases are written using [GoogleTest](https://github.com/google/googletest).

## Preparations

If you have installed dextool as a local user I recommend you to create an
alias to the `dextool` binary. It will make the rest of this README easier to
follow because you are able to *just* copy/paste the commands.

Set an alias for dextool:
```sh
alias dextool="path/to/dextool/"
```

**Note**: Change `path/to/dextool` to the correct path to were you previously
installed it. For example: `/home/myUser/dextool/build/bin/dextool`. This is
needed when you want to run dextool in coming steps as well, we therefore
create an alias.

Now that you have done that quality of life improvement we are ready for the
fun stuff.

To setup the mutation testing and coverage environment:
```sh
./setup.sh
```

## Mutation Testing

Dextool need to analyze the source code. This is only required to be done once.
```sh
dextool mutate analyze
```

To run the mutation testing:
```sh
# minimal that we need to run is LCR
dextool mutate test --mutant lcr --mutant lcrb
# the curious minded is recommended to also run these
dextool mutate test --mutant sdl --mutant dcr
```

To generate a report:
```sh
dextool mutate report --style html --section tc_similarity --section tc_min_set --section tc_full_overlap_with_mutation_id --section tc_killed_no_mutants --section tc_full_overlap --mutant lcr --mutant lcrb
```

If you want to forcefully re-test all alive mutants you can use this administration interface:
```sh
dextool mutate admin --operation resetMutant --status alive --to-status unknown
```

## Code Coverage

The directory `build_cov` that the `setup.sh` script created is configured to generated coverage data when the test cases are executed.

To generate the html report:
```sh
cd build_cov
make && make test
lcov -c -d . --output-file coverage.info
genhtml coverage.info --output-directory html
```

The report is located in `build_cov/html/index.html`.
