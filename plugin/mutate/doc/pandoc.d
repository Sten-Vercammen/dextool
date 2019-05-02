#!/usr/bin/env dub
/+ dub.sdl:
    name "pandoc"
+/
/** This script produces a PDF of the requirements, design and test
 * documentation for the Dextool mutation testing plugin.
 *
 * Dependent on the following packages (Ubuntu):
 * `sudo apt install texlive-bibtex-extra biber pandoc pandoc-citeproc`
 */

import std.algorithm;
import std.array;
import std.ascii;
import std.conv;
import std.file;
import std.process;
import std.path;
import core.stdc.stdlib;
import std.range;
import std.stdio;
import std.string;
import logger = std.experimental.logger;

void main(string[] args) {
    const string root = getcwd();

    const latex_dir = buildPath(root, "latex");
    if (exists(latex_dir)) {
        run(["rm", "-r", latex_dir]);
    }
    mkdir(latex_dir);

    chdir(latex_dir);
    scope (exit)
        chdir(root);

    const metadata = buildPath(root, "metadata.yaml");
    const latex_template = buildPath(root, "default.latex");
    const biblio = buildPath(root, "references.bib");
    const output = "dextool_srs_sdd_svc";

    auto dat = Pandoc(metadata, latex_template, biblio);

    string[] design_chapters;
    design_chapters ~= "use_cases.md";
    design_chapters ~= "purpose.md";
    design_chapters ~= "security.md";
    design_chapters ~= "architecture.md";
    design_chapters ~= "mutations.md";
    design_chapters ~= "analyzer/analyzer.md";
    design_chapters ~= "test_mutant/basis.md";
    design_chapters ~= "usability/sanity_check.md";
    design_chapters ~= "usability/report.md";
    design_chapters ~= "future_work.md";

    // dfmt off
    pandoc(
        dat,
        chain(design_chapters.map!(a => buildPath(root, "design", a)),
              ["definitions.md", "abbrevations.md", "appendix.md", "references.md"].map!(a => buildPath(root, a))).array,
        output);
    // dfmt on
}

string home() {
    return expandTilde("~");
}

struct Pandoc {
    string metadata;
    string latexTemplate;
    string biblio;
}

void pandoc(Pandoc dat, string[] files, const string output) {
    // dfmt off
    auto cmd = ["pandoc",
         "--template", dat.latexTemplate,
         "-f", "markdown_github+citations+yaml_metadata_block+tex_math_dollars+raw_tex",
         "-S",
         "--standalone",
         "--toc",
         "--bibliography", dat.biblio,
         //"--biblio", dat.biblio,
         //"--biblatex", "-M", "biblio-style=numeric-comp",
         //"--csl", "chicago-author-date.csl",
         "--natbib", "-M", "biblio-style=unsrtnat", "-M", "biblio-title=heading=none",
         //"--to", "latex",
         //"-o", output ~ ".pdf",
         "-o", output ~ ".latex",
         dat.metadata,
    ] ~ files;
    // dfmt on

    run(cmd);
    // generates the aux
    run(["pdflatex", output ~ ".latex"]);
    // generate first pass of the resolution of references
    try {
        run(["bibtex", output ~ ".aux"]);
    } catch (Exception e) {
    }
    // resolve pass 1
    run(["pdflatex", output ~ ".latex"]);
    // resolve pass 2
    run(["pdflatex", output ~ ".latex"]);
}

auto run(string[] cmd) {
    writeln("run: ", cmd.joiner(" "));
    auto res = execute(cmd);
    writeln(res.output);

    if (res.status != 0)
        throw new Exception("Command failed");

    return res;
}
