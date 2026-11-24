# Certify-the-Checker — a Standard for Scoped Certification of a Checker's CLEAN Verdict (v0)

## Plain-language version (read this first)

When a code checker says "no issues found" (CLEAN), that is a statement about what was checked, not about the code. This
standard asks you to report a CLEAN result together with its scope:

1. **What it was run on**: build settings and the kinds of input that were tried.
2. **How deep the testing went**: did the risky line run at all; did every branch run; did the risky condition actually
   happen; was every kind of input tried.
3. **Whether the test could have failed**: show it on a known bug first ("known-bug sanity check").

Then compare the checker with actually running the code (for example under AddressSanitizer), one kind of input at a time,
and report the whole table. Words used below, in plain terms:

| Term in this document | Plain meaning |
|---|---|
| S, the checker | the static analyzer, linter or AI reviewer being evaluated |
| X, execution oracle | running the code and watching for errors (sanitizers, tests) |
| F, formal oracle | an optional proof or model-checking tool |
| tau | the score cut-off a checker uses to say CLEAN or BUG |
| certify-clean | checker says CLEAN, and running the code under the stated settings and inputs also found nothing |
| non-transferability | a CLEAN that holds for some settings or inputs but fails for others |
| white-cell | a false negative: checker says CLEAN, running the code finds a real bug |
| corner | a known real bug (for example from a public advisory) that nothing in your setup observes |
| coverage gap | the risky code never ran, so running the code says nothing about it |
| positive control, CONTROLLED | a known-bug sanity check: the test was shown able to fail |
| axiom accounting | list every assumption your result depends on |
| cube-grade | a result produced under the full independence rules in section 7; anything else is advisory |

The rest of this document is the precise version.

## Abstract
Static analyzers and LLM-generated checkers emit CLEAN (no-finding) verdicts. A CLEAN verdict is easy to over-trust. This
standard defines how to CERTIFY and, crucially, BOUND such a verdict by composing the checker with independent oracles and
reporting a scoped disagreement/limitation map. It never issues a portable safety certificate. The core result it is built
to express: **a clean verdict is scoped to the configuration and input class under which it was obtained, and does not
transfer to another configuration or input class of the same unit.**

## 1. A composition contract
What this standard defines is a stable CONTRACT that lets heterogeneous producers be composed into one coherent
certification system, rather than any single oracle. The contract is the interface defined below: the verdict format, the
join key, the coverage-depth levels, the positive-control grades, the independence protocol, and the axiom accounting. A
static checker (S), a formal oracle (F), or an execution oracle (X) may be composed in, provided it honors the contract.
The contract is domain-neutral: it applies to any checker on any target. A worked example is given in section 8.

## 2. Producers
- S — the checker under certification (e.g. a static or LLM-generated checker). Emits a per-claim score; a threshold tau maps
  the score to BUG or CLEAN.
- X — an execution oracle. Emits BUG, CLEAN, or NOTRIGGER, plus a coverage flag, a build configuration, and an oracle kind.
- F — an optional formal oracle. Advisory unless it meets the cube-grade conditions (section 7).
Each producer is scoped and run independently; no producer reads another producer's verdicts.

## 3. Core definitions
- certify-clean(claim, tau): S=CLEAN AND X=CLEAN AND the claim's line was covered, under a STATED build configuration and
  input set, AND the property carries a positive control (section 4). It is nominal-run and coverage scoped. It is never a
  proof of absence and never a portable safety certificate. Every certify-clean states its coverage level (section 5), its
  configuration and input-class tag, and its control grade.
- Non-transferability (the central law): a certify-clean obtained under configuration or input class C does not transfer to
  a configuration or input class C' of the same unit where a defect is observable. The mechanism is made precise by coverage
  depth (section 5): a line can execute many times while the defect's triggering condition or input class is never exercised.
- white-cell(claim, tau): S=CLEAN AND X=BUG, line covered. A cell that a checker-trusting view does not predict.
- corner(claim): a known-real defect (external ground truth, e.g. a public advisory) that no producer observes under the run
  configuration. Distinct from a coverage gap.
- coverage-gap(claim): the line was not executed; the execution oracle is silent and says nothing about the claim.

## 4. Property positive control
A property's CLEAN has a grade. CONTROLLED: the property's BUG path has been demonstrated on a planted positive (a mutant or
a crafted input that must flip CLEAN to BUG). UNCONTROLLED otherwise. An uncontrolled CLEAN is a lower tier and may not alone
support certify-clean. Report the grade per property.

## 5. Coverage depth
"Covered" is stratified, weakest to strongest: LINE < BRANCH < CONDITION < INPUT-CLASS. Below LINE, a run may reach
NONE or only PART of the relevant lines (for example the faulting line but not the root cause). A certify-clean states the level it
reached. Line coverage (the defect line executed) is the floor and does not imply the defect's triggering condition or input
class was ever exercised. This stratification is the precise account of why a clean verdict fails to transfer.

## 6. Reporting rules
- R1 Report a trade-off curve over tau, never a single threshold.
- R2 The deliverable is a scoped disagreement/limitation map, never a certified-safe claim.
- R3 Every certify-clean carries its (configuration, input-class) tag; a claim stated without it is malformed.
- R4 Coverage is reported explicitly (covered / total); thin cells are shown, not hidden behind an aggregate.
- R5 X=BUG is trusted; X=CLEAN is coverage, not correctness; white-cells and corners are first-class, not footnotes.

## 7. Axiom accounting, independence, cube-grade
- Axiom accounting: every result lists its declared axioms; a result that depends on an undeclared axiom is void. Declare the
  common target anchor, the S-threshold rule, that X=CLEAN is coverage not proof, the certify-clean definition, the
  white-cell/corner definitions, and any producer-specific transform (e.g. a source normalization, a host substitution).
- Independence protocol: a shared target manifest (shared targets, never shared verdicts) issued before any matched run;
  any sealed property/configuration carries a publicly verifiable timestamp made before the checker is produced (a private
  timestamp is insufficient for a released claim); projecting one producer's frozen results onto another's positions is a
  projection, never a re-run informed by those positions; once any party has seen a producer's output or an external answer,
  it may not thereafter direct a different producer's scope, build, or configuration for the same target.
- Cube-grade vs advisory: a verdict is cube-grade only if it answers a shared-manifest cell, was run independently, and
  declares its axioms; otherwise it is advisory and never gates. A thin or absent producer never downgrades a certify-clean;
  it only withholds corroboration.

## 8. Worked example (independently reproducible)
This example ILLUSTRATES the definitions; it is not a cube-grade result (the independence protocol of section 7 is not
exercised — it is the author's own code). It is tagged per R3: config host build, input-class {benign, adversarial},
coverage depth line / input-class, execution positive-controlled by the adversarial input itself.
### 8.1 Integer truncation in a record parser (illustrative)
A small record parser whose destination size is computed in a narrow integer type and truncates. Two REAL public static
analyzers disagree on it: one (a clang static-analyzer run) is silent and returns CLEAN — a genuine under-approximation —
while another (gcc's -fanalyzer) flags the write line as a heap buffer overflow. An execution oracle observes a heap
out-of-bounds write under an adversarial input class, while the benign input class is clean. So the silent analyzer's CLEAN
is scoped to the benign input class and does not transfer; and the two real checkers' disagreement is itself a cell on the
map. (The author's own illustrative code; tool versions are pinned in the repository README; run it with
tools/run_example.sh examples/01-integer-truncation. Further examples, including one where the checker finds a bug that the
tests never reach, are in examples/.)

## 9. What this standard is not
It does not certify safety. It does not rank tools. It does not claim a portable guarantee for any function. It reports where
checkers and oracles are blind, with each claim tagged by the configuration, input class, coverage depth, and control grade
under which it holds.
