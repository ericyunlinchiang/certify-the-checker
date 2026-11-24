# Certify-the-Checker v0

A short standard for certifying, and bounding, a checker's CLEAN (no-finding) verdict, plus one reproducible worked example.

Contents:
- STANDARD-v0.md             - the standard (a composition contract for scoped certification of a CLEAN verdict)
- software-example-repro.zip - the worked example (integer truncation; a real analyzer's CLEAN is input-class scoped)
- PROVENANCE.md              - where each element comes from
- AUTHORS, LICENSES.md, LICENSE-CC-BY-4.0, LICENSE-Apache-2.0

Run the example: unzip software-example-repro.zip and run ./repro.sh (clang, gcc, AddressSanitizer, bash).
The example is the author's own illustrative code; it is not a vulnerability report.
