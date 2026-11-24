# Certify-the-Checker

[![examples](https://github.com/ericyunlinchiang/certify-the-checker/actions/workflows/examples.yml/badge.svg)](https://github.com/ericyunlinchiang/certify-the-checker/actions/workflows/examples.yml)

**A "no issues found" result from a code checker is only true for what was actually checked.** This repo shows that with
six small, runnable C examples. It also gives a short reporting format for writing down what a CLEAN result really covers.
It is for anyone who uses linters, static analyzers or AI code review. No security background needed.

## What this shows, and what it does not

Shows:
- on six small examples written for this repo, three free checkers (clang, gcc -fanalyzer, cppcheck) sometimes say CLEAN when
  running the code finds a bug, and sometimes find a bug the tests never reach;
- why "the line ran in my tests" is weaker than "the risky case was tested", measured with coverage.

Does not show:
- how often this happens in real projects (these are six hand-written teaching examples);
- that any of these tools is bad. Results depend on tool versions and flags, which are listed below.

## Results

Ubuntu 24.04: gcc 13.3.0 (`-Wall -Wextra -fanalyzer`), clang 18.1.3 (`--analyze`), cppcheck 2.13.0 (`--enable=all`).
"Running the code" = AddressSanitizer + UBSan, one run per kind of input. CI re-runs this table on every change and
publishes all raw outputs (the "raw-outputs" artifact of each Actions run).

| example | clang --analyze | gcc -fanalyzer | cppcheck | running the code (per kind of input) |
|---|---|---|---|---|
| 01-integer-truncation | CLEAN | BUG | CLEAN | normal=CLEAN large=BUG |
| 02-off-by-one | CLEAN | CLEAN | CLEAN | normal=CLEAN boundary=BUG |
| 03-signed-length | CLEAN | CLEAN | CLEAN | normal=CLEAN negative=BUG |
| 04-use-after-free | BUG | BUG | BUG | normal=CLEAN error=CLEAN error-read=BUG |
| 05-untested-error-path | CLEAN | BUG | BUG | normal=CLEAN |
| 06-divide-by-zero | BUG | CLEAN | CLEAN | normal=CLEAN empty=BUG |

What the table says:

- **02, 03**: all three checkers say CLEAN, yet the code breaks on one kind of input.
- **05**: the opposite. Two checkers find the bug, but the tests (normal input only) never reach it: the root-cause line
  ran 0 times. Running the code is not automatically better.
- **01, 06**: the checkers disagree with each other. 06 is not a memory bug.
- **04**: all three find it; cppcheck also reports a double free on line 12 that never happens at run time.
- In every row, normal input passes. A test suite with only normal inputs would pass too.

**Tried another checker or an AI reviewer?** Please share the result with the "Checker result" issue template.

## FAQ

### Does "no issues found" from a static analyzer mean my code is safe?
No. It means the checker found nothing with its rules, flags and version. In this repo, examples 02 and 03 pass clang
--analyze, gcc -fanalyzer and cppcheck with no findings, yet both crash on one kind of input.

### Does the clang static analyzer catch off-by-one errors?
Not in example 02 (clang 18.1.3, `--analyze`): a loop written with `<=` instead of `<` writes one element past a 16-byte
stack buffer, and clang reports nothing. gcc -fanalyzer and cppcheck also report nothing. AddressSanitizer catches it on
the boundary input.

### Does gcc -fanalyzer catch a buffer overflow caused by integer truncation?
Yes in example 01 (gcc 13.3.0): it flags the heap overflow when a buffer size is computed in 16 bits. clang --analyze and
cppcheck do not.

### Does cppcheck find use-after-free?
Yes in example 04 (cppcheck 2.13.0). It also reports a double free on line 12 that never happens when the code runs, so a
finding needs checking too.

### Is running the code with AddressSanitizer enough?
No. It only sees what your inputs reach. In example 05 the tests use normal input only: the line that causes the bug runs
0 times, AddressSanitizer reports nothing, while gcc -fanalyzer and cppcheck find the bug.

### What is the difference between line coverage and testing the risky case?
A line can run many times without the dangerous condition ever happening. In example 02, the buggy line runs 9 times on
normal input; the bug only appears when the count equals the buffer size. This repo measures both with gcov.

### How should I report a static analysis or code review result?
Report the CLEAN or BUG verdict together with the build settings, the kinds of input that were tried, how deep the testing
went, and whether the test was shown able to fail. `STANDARD-v0.md` defines a short format for this, and
`readout-template.json` is a fill-in version.

### Can I use this for AI code reviewers?
Yes. An AI reviewer is just another checker: give it the same code, record its verdict per example and per run, and compare
with running the code. Please share results with the "Checker result" issue template.

## Related work

- **NIST SARD / Juliet test suite** (https://samate.nist.gov/SARD/): a large labelled corpus of synthetic C/C++ and Java
  test cases for scoring analyzers at scale. This repo is the opposite end: a few tiny cases you can read in a minute, plus
  a format for stating what a CLEAN result covers. The two are complementary.
- **Static analyzer benchmark suites and comparison harnesses** run many tools over many cases and report scores. This repo
  does not rank tools; it shows, case by case, why a CLEAN verdict needs its build settings, input kinds and coverage
  depth stated next to it.

## Quick start (about 1 minute)

With Docker (any OS):

```
git clone https://github.com/ericyunlinchiang/certify-the-checker.git
cd certify-the-checker
docker build -t certify-the-checker . && docker run --rm certify-the-checker
```

Without Docker: Linux with GNU **gcc 13+**, **clang**, **python3**; **cppcheck** optional.
Ubuntu 24.04: `sudo apt-get install gcc clang cppcheck python3`. Ubuntu 22.04 ships an older gcc: use Docker. On macOS the
`gcc` command is clang: use Docker.

```
tools/run_all.sh                                   # the table above
tools/run_example.sh examples/02-off-by-one        # one example in detail: lines, coverage, readout.json
```

`tools/run_all.sh --check` compares your table with `examples/expected-results.txt`. A match means **you reproduced the
same results**. It does not mean a checker is good. Other tool versions can give different results.

## How results are decided

- Each example lists its **bug lines** in `example.env`: the root cause and the line where it goes wrong (for example
  01: line 17 computes the size in 16 bits, line 21 writes past the buffer).
- A checker **finds the bug** if it reports any bug line. Other lines it reports are printed as notes.
- Running the code: **BUG** if AddressSanitizer/UBSan reports an error in the example; **CLEAN** if it runs normally;
  **NOTRIGGER** if no bug line ran at all.
- **Coverage depth** is measured with gcov for each kind of input: `none` (no bug line ran) < `partial` (some ran, often
  not the root cause) < `line` (all ran) < `branch` (and every branch in the function went both ways) < `input-class`
  (the input actually triggered the bug).
- **Controlled** means at least one input makes the run report BUG. A run is only shown able to fail if that happens.

Each run writes a `readout.json` that follows `schema/readout.schema.json` (checked in CI by `tools/validate_readout.py`).

## Use it on your own code (4 steps)

1. **Pick a claim.** One place where your checker says CLEAN, or reports a finding.
2. **Run it for real**, under a sanitizer or with tests, once per kind of input you care about (normal, empty, very
   large, negative, malformed...). Measure whether the risky line and branches actually ran (gcov or llvm-cov).
3. **Show your test can fail**: use an input or a planted bug that must be reported.
4. **Write it down** in the `readout-template.json` format, one cell per kind of input, and report the whole table.

The scripts here are built for the curated examples, where the bug lines are known. On your own code you supply the kinds
of input and decide which lines matter; to add an example to this repo, see `CONTRIBUTING.md`.

## Words used

| Word | Meaning |
|---|---|
| CLEAN / BUG | "no issue found" / "issue found" |
| checker (S) | the tool being evaluated: static analyzer, linter, AI reviewer |
| running the code (X) | executing it and watching for errors, e.g. with AddressSanitizer |
| certify-clean | checker says CLEAN and running the code found nothing, for the stated settings and inputs |
| does not transfer | a CLEAN that holds for some settings or inputs but fails for others |
| white-cell | a false negative: checker says CLEAN, running the code finds a real bug |
| coverage depth | how thoroughly the risky code was exercised (see above) |
| controlled | the test was shown able to fail |

`STANDARD-v0.md` starts with a plain-language version, then the precise one.

## Files

- `STANDARD-v0.md`: the standard
- `examples/NN-name/`: `target.c` (the bug), `harness.c` (runs one kind of input), `example.env` (bug lines, inputs)
- `examples/expected-results.txt`: the table above, machine-readable
- `tools/run_all.sh`, `tools/run_example.sh`, `tools/readout.py`, `tools/validate_readout.py`, `tools/make_digest.sh`
- `schema/readout.schema.json`, `readout-template.json`
- `Dockerfile`, `.github/workflows/examples.yml` (CI), `.github/ISSUE_TEMPLATE/`
- `docs/`: the project web page (GitHub Pages); `CHANGELOG.md`: what changed in each version
- `DIGEST.md`: the whole repo in one file, for pasting into an AI assistant that cannot open links; `llms.txt`: short index
- `CONTRIBUTING.md`, `CITATION.cff`, `PROVENANCE.md`, `AUTHORS`, `LICENSES.md`, `LICENSE-Apache-2.0`, `LICENSE-CC-BY-4.0`
- `SHA256SUMS`: check with `sha256sum -c SHA256SUMS`

## License

Text: CC BY 4.0. Code: Apache-2.0. Author: Eric Chiang. Issues, results and new examples are welcome.
