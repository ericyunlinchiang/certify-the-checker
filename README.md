# Certify-the-Checker

[![examples](https://github.com/ericyunlinchiang/certify-the-checker/actions/workflows/examples.yml/badge.svg)](https://github.com/ericyunlinchiang/certify-the-checker/actions/workflows/examples.yml)

**When a code checker says "no issues found", how far can you trust it?**

This repository has:

1. a short standard (`STANDARD-v0.md`) for writing down what a "no issues" (CLEAN) result really covers;
2. four small bug examples you can run in about a minute, with three real, free checkers and a sanitizer run.

You do not need a security background. If you have used a linter, a static analyzer or unit tests, you have what you need.

## Can your checker catch these?

Results on Ubuntu 24.04 (gcc 13.3.0, clang 18.1.3, cppcheck 2.13.0). "Running the code" = AddressSanitizer + UBSan, one run
per kind of input.

| example | clang --analyze | gcc -fanalyzer | cppcheck | running the code (per kind of input) |
|---|---|---|---|---|
| 01-integer-truncation | CLEAN | BUG | CLEAN | normal=CLEAN large=BUG |
| 02-off-by-one | CLEAN | CLEAN | CLEAN | normal=CLEAN boundary=BUG |
| 03-signed-length | CLEAN | CLEAN | CLEAN | normal=CLEAN negative=BUG |
| 04-use-after-free | BUG | BUG | BUG | normal=CLEAN error=CLEAN error-read=BUG |

What the table says:

- **02 and 03**: all three checkers say CLEAN, yet the code breaks on one kind of input.
- **01**: the checkers disagree with each other.
- **04**: all three find the bug. cppcheck also reports a double free on line 12 that never happens when the code runs. A
  finding needs checking too.
- In every row, normal input runs fine. A test suite with only normal inputs would pass.

**Tried another checker?** (Coverity, CodeQL, Semgrep, Infer, Clang-Tidy, an AI reviewer...) Please share the result using
the "Checker result" issue template. See `CONTRIBUTING.md`.

## The idea in one paragraph

A checker's CLEAN result is true only for what was actually checked: the build settings you used and the kinds of input you
ran. Change either one and the result may no longer hold. So a CLEAN result should never be reported alone. Report it
together with:

- **what you ran it on** (build settings, kinds of input);
- **how deep the testing went** (the line ran / every branch ran / the risky condition was hit / every kind of input was tried);
- **whether your test can fail at all**, proven on a planted bug.

The standard gives names and a format for this, so different tools can be compared and combined.

## Quick start (about 1 minute)

Requirements: Linux, GNU **gcc 13 or newer**, **clang**, bash; **cppcheck** is optional. On Ubuntu:
`sudo apt-get install gcc clang cppcheck`. On macOS the `gcc` command is clang, so use a Linux machine, VM or container.

```
git clone https://github.com/ericyunlinchiang/certify-the-checker.git
cd certify-the-checker
tools/run_all.sh            # prints the table above
tools/run_example.sh examples/02-off-by-one     # one example in detail, with a JSON readout
```

`tools/run_all.sh --check` also compares your table with `examples/expected-results.txt`. Different tool versions can give
different answers, and that is part of the point.

## Use it on your own checker (4 steps)

1. **Pick a claim.** One place in your code where your checker says CLEAN, or where it reports a finding.
2. **Run it for real.** Execute that code under a sanitizer or with tests, for each kind of input you care about (normal,
   empty, very large, negative, malformed...). Note whether the line, the branch or the risky condition was actually reached.
3. **Prove your test can fail.** Plant a small bug, or use an input that should fail, and check that your run reports it.
   If it never can, your CLEAN is "uncontrolled".
4. **Write it down** using `readout-template.json`: one entry per kind of input, with the checker's verdict, the execution
   result and the coverage depth. Report the whole table, not one summary number.

## Words used in the standard

| Word | Meaning |
|---|---|
| S | the checker you want to evaluate (static analyzer, linter, AI-generated rule) |
| X | an execution check: actually running the code, e.g. with AddressSanitizer or tests |
| F | an optional formal tool (model checker, prover) |
| CLEAN / BUG | "no issue found" / "issue found" |
| NOTRIGGER | the code was never reached, so execution says nothing |
| certify-clean | S says CLEAN and X ran that code and also saw no problem, for the stated settings and inputs |
| does not transfer | a CLEAN that holds for some settings or inputs but fails for others |
| white-cell | S says CLEAN but X finds a real bug: the checker missed something |
| coverage depth | how thoroughly it was exercised: line < branch < condition < kind of input |
| controlled | the test was shown able to fail, on a planted bug |
| tau | the score cut-off a checker uses to decide CLEAN vs BUG |

## Files

- `STANDARD-v0.md`: the standard
- `examples/`: four examples (`target.c`, `harness.c`, `example.env` each) and `expected-results.txt`
- `tools/run_example.sh`, `tools/run_all.sh`: run one example or all of them
- `readout-template.json`: fill this in for your own results
- `CONTRIBUTING.md`, `CITATION.cff`, `PROVENANCE.md`, `AUTHORS`, `LICENSES.md`, `LICENSE-Apache-2.0`, `LICENSE-CC-BY-4.0`
- `SHA256SUMS`: check the files with `sha256sum -c SHA256SUMS`

## License

Text: CC BY 4.0. Code: Apache-2.0. Author: Eric Chiang. Issues, results and new examples are welcome.
