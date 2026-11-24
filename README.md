# Certify-the-Checker

**When a code checker says "no issues found", how far can you trust it?**

This repository has two things:

1. A short standard (`STANDARD-v0.md`) for writing down what a "no issues" (CLEAN) result really covers.
2. A small example you can run in under a minute. It shows a real analyzer saying CLEAN on code that crashes on some inputs.

You do not need a security background. If you have used a linter, a static analyzer, or unit tests, you have what you need.

## The idea in one paragraph

A checker's CLEAN result is true only for what was actually checked: the build settings you used and the kinds of input you
ran. Change either one and the result may no longer hold. So a CLEAN result should never be reported alone. Report it
together with:

- **what you ran it on** (build settings, kinds of input);
- **how deep the testing went** (the line ran / every branch ran / the risky condition was hit / every kind of input was tried);
- **whether your test can fail at all**, proven on a planted bug.

The standard gives names and a format for this, so different tools can be compared and combined.

## Quick start (about 1 minute)

Requirements: Linux, GNU **gcc 13 or newer**, **clang**, bash. Tested on Ubuntu 24.04 with gcc 13.3.0 and clang 18.1.3.
On Ubuntu: `sudo apt-get install gcc clang`. On macOS the `gcc` command is clang, so use a Linux machine or VM.

```
git clone https://github.com/ericyunlinchiang/certify-the-checker.git
cd certify-the-checker
./example/repro.sh
```

You should see (trimmed):

```
clang_analyze=CLEAN  (clang 18.1.3)
gcc_fanalyzer=BUG at target.c:21  (gcc 13.3.0)
benign      (n=4)      : rc=0 (covered; condition n*4>65535 NOT exercised)
ERROR: AddressSanitizer: heap-buffer-overflow ... in parse_record ... target.c:21
VERDICT: NON-TRANSFERABILITY REPRODUCED ...
```

followed by a JSON readout in the same shape as `readout-template.json`.

## What the example shows

`example/target.c` reads a count and then that many 4-byte items. The output buffer size is computed in a 16-bit number, so a
large count wraps around and the buffer is too small.

- clang's static analyzer reports nothing (CLEAN).
- gcc's `-fanalyzer` reports a heap overflow on line 21 (BUG).
- Running the code under AddressSanitizer: normal input is fine; a large count overflows the buffer on line 21.

So clang's CLEAN was true for normal input only. It did not carry over to large inputs, even though line 21 ran in both cases.
"The line ran" is not the same as "the risky case was tested".

## Use it on your own checker (4 steps)

1. **Pick a claim.** One place in your code where your checker says CLEAN, or where it reports a finding.
2. **Run it for real.** Execute that code under a sanitizer or with tests, for each kind of input you care about (normal,
   empty, very large, malformed...). Note whether the line, the branch, or the risky condition was actually reached.
3. **Prove your test can fail.** Plant a small bug, or use an input that should fail, and check that your run reports it.
   If it never can, your CLEAN is "uncontrolled".
4. **Write it down** using `readout-template.json`: one entry per kind of input, with the checker's verdict, the execution
   result, and the coverage depth. Report the whole table, not one summary number.

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
- `example/`: the runnable example (`repro.sh`, the target, the test driver, the analyzer wrapper)
- `readout-template.json`: fill this in for your own results
- `PROVENANCE.md`, `AUTHORS`, `LICENSES.md`, `LICENSE-Apache-2.0`, `LICENSE-CC-BY-4.0`
- `SHA256SUMS`: check the files with `sha256sum -c SHA256SUMS`

## License

Text: CC BY 4.0. Code: Apache-2.0. Author: Eric Chiang. Issues and questions are welcome.
