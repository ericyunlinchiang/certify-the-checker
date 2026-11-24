# Worked example: a real analyzer's CLEAN is input-class scoped

A demonstration that a REAL static
analyzer's CLEAN verdict is scoped to the input class under which it holds.

Target `target.c` parses [u16 count][count x u32]; the destination size is computed in a 16-bit type and TRUNCATES, so a
large count overflows the heap buffer on write.
- S (static): two REAL public analyzers DISAGREE. clang static analyzer (`clang --analyze`) is SILENT = CLEAN; gcc
  `-fanalyzer` FLAGS target.c:21 ("heap-based buffer overflow [CWE-122]"). clang's CLEAN is a genuine under-approximation.
- X (execution): AddressSanitizer observes a heap out-of-bounds WRITE at target.c:21 under the ADVERSARIAL input class; the
  benign input class is clean.

This is an ILLUSTRATION, not a cube-grade result: the independence protocol is not exercised (our own code), and the example
is tagged by its scope. Example tags: config = host build; coverage depth = line (benign) / input-class (adversarial);
control grade = X positive-controlled by the adversarial input itself.

## Run
`./example/repro.sh` from the repository root (needs Linux, GNU gcc >= 13, clang, bash). See the top-level README.

## Pinned reference environment
clang 18.1.3, gcc 13.3.0, Ubuntu 24.04 (AddressSanitizer). Other toolchain versions may analyze differently; the point is
that at least one real analyzer (clang here) returns CLEAN while execution finds the bug under the adversarial input class.

## Expected
- clang=CLEAN, gcc -fanalyzer=BUG@target.c:21, X benign=CLEAN, X adversarial=BUG@target.c:21.
- VERDICT: NON-TRANSFERABILITY REPRODUCED (software).

All code here is the author's own; illustrative, not a vulnerability report.
License: code Apache-2.0, text CC BY 4.0 (see the package LICENSES.md). Author: Eric Chiang.
