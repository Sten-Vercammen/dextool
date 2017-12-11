# REQ-plugin_mutate_early_validation
partof: REQ-plugin_mutate-use_case
###
This plugin should be easy to use in the day-to-day development.

The plugin should be _fast_ when the changes in the code base are _small_.
The plugin should be _fast_ when performing whole program mutation.
    NOTE: will require scaling over a computer cluster.
The plugin should produce a detailed report for the user to understand what mutations have been done and where.
The plugin should on request visualize the changes to the code.
    NOTE: produce the mutated source code.
The plugin should be easy to integrate with an IDE for visual feedback to the user.

# REQ-plugin_mutate_inspection_of_test_proc
partof: REQ-plugin_mutate-use_case
This plugin should replace or simplify parts of the inspection as required by DO-178C.

The type of mutations to implemented should be derived and traced to the following statement and list.

"The inspection should verify that the test procedures have used the required test design methods in DO-178C:
 * Boundary value analysis,
 * Equivalence class partitioning,
 * State machine transition,
 * Variable and Boolean operator usage,
 * Time-related functions test,
 * Robustness range test design for techniques above"

See [[http://www.inf.ed.ac.uk/teaching/courses/st/2016-17/Mutest.pdf]] for inspiration

# REQ-plugin_mutate_test_design_metric
partof: REQ-plugin_mutate_inspection_of_test_proc
###
The plugin should produce metrics for how well the design methods in [[REQ-plugin_mutate_inspection_of_test_proc]] has been carried out.

Regarding code coverage:
The modified condition / decision coverage shows to some extent that boolean operators have been exercised. However, it does not require the observed output to be verified by a testing oracle.

Regarding mutation:
By injecting faults in the source code and executing the test suite on all mutated versions of the program, the quality of the requirements based test can be measured in mutation score. Ideally the mutation operations should be representative of all realistic type of faults that could occur in practice.

# SPC-plugin_mutate_incremental_mutation
partof: REQ-plugin_mutate_early_validation
###
The plugin shall support incremental mutation.

A change of one statement should only generate mutants for that change.
A change to a file should only generate mutants derived from that file.