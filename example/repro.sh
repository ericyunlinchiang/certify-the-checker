#!/usr/bin/env bash
# Reproduction: a REAL static analyzer's CLEAN is input-class scoped.
# S = real public analyzers (clang static analyzer vs gcc -fanalyzer); X = execution oracle (ASan).
# Pinned reference env: clang 18.1.3, gcc 13.3.0, Ubuntu 24.04 (AddressSanitizer).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# Preflight: fail early with a clear message instead of a confusing result.
need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING TOOL: $1 (see README: Requirements)"; exit 2; }; }
need gcc; need clang
if gcc --version 2>/dev/null | head -1 | grep -qi clang; then
  echo "Your 'gcc' is really clang (common on macOS). This example needs GNU gcc >= 13 (Linux). See README."; exit 2
fi
gmaj=$(gcc -dumpversion | cut -d. -f1)
[ "$gmaj" -ge 13 ] 2>/dev/null || { echo "gcc $gmaj found; gcc >= 13 is needed (its -fanalyzer bounds check). See README."; exit 2; }
echo "== S (real static analyzers) =="
s_out="$("$HERE/s_checker.sh" "$HERE/target.c")"; echo "$s_out"
clang_v=$(echo "$s_out" | sed -n 's/.*clang=\([A-Z]*\).*/\1/p'); gcc_v=$(echo "$s_out" | sed -n 's/.*gcc=\([A-Z]*\).*/\1/p')
echo; echo "== X (execution oracle, ASan) =="
gcc -std=c11 -g -fsanitize=address "$HERE/harness/main.c" "$HERE/target.c" -o "$HERE/.x"
set +e; x_out="$("$HERE/.x" 2>&1)"; xrc=$?; set -e; rm -f "$HERE/.x"
benign_clean=$(echo "$x_out" | grep -qE "benign .*rc=0" && echo yes || echo no)
x_oob=$(echo "$x_out" | grep -qE "parse_record .*target\.c:21" && echo yes || echo no)
echo "$x_out" | grep -E "benign|adversarial|heap-buffer-overflow|WRITE of size|parse_record .*target.c:21|done" || true
echo; echo "== standard readout (computed from the outputs above) =="
echo "  claim SW-001 (parse_record, dest-size integer truncation)"
echo "    input-class=benign      : S(clang)=$clang_v  X=CLEAN(covered,line)         -> certify_clean (scope: benign input-class, clang)"
echo "    input-class=adversarial : S(clang)=$clang_v  X=BUG(covered,input-class)@target.c:21 -> clean does NOT transfer across input-class"
echo "    disagreement            : S(gcc -fanalyzer)=$gcc_v  (a real second checker DOES flag it) -> this is a checker-vs-checker + checker-vs-exec cell"
echo "    control grade: X positive-controlled by the adversarial input-class itself producing the OOB; coverage depth: line(benign) / input-class(adversarial)"
echo
# VERDICT gated on real outputs: clang CLEAN, gcc BUG, X benign-clean AND X oob-on-adversarial
if [ "$clang_v" = CLEAN ] && [ "$gcc_v" = BUG ] && [ "$benign_clean" = yes ] && [ "$x_oob" = yes ] && [ "$xrc" != 0 ]; then
  echo "VERDICT: NON-TRANSFERABILITY REPRODUCED (software) — clang-CLEAN is input-class scoped; gcc -fanalyzer and ASan both flag target.c:21."
  echo
  echo "== readout (JSON, same shape as readout-template.json) =="
  cat <<JSON
{
  "standard": "certify-the-checker v0",
  "claim_id": "SW-001",
  "location": "example/target.c:21",
  "build_config": "host build (gcc $(gcc -dumpfullversion), clang $(clang --version | sed -n '1s/.*version \([0-9.]*\).*/\1/p'))",
  "checkers": { "clang --analyze": "$clang_v", "gcc -fanalyzer": "$gcc_v" },
  "cells": [
    { "input_class": "benign",      "checker": "clang", "checker_verdict": "$clang_v", "execution": "CLEAN", "coverage_depth": "line",        "result": "certify_clean (holds only for this input class)" },
    { "input_class": "adversarial", "checker": "clang", "checker_verdict": "$clang_v", "execution": "BUG",   "coverage_depth": "input-class", "result": "clean does NOT transfer" }
  ],
  "control_grade": "controlled (the adversarial input itself makes the execution oracle report BUG)",
  "note": "Illustration with the author's own code; not a vulnerability report."
}
JSON
else
  echo "VERDICT: UNEXPECTED (clang=$clang_v gcc=$gcc_v benign_clean=$benign_clean x_oob=$x_oob xrc=$xrc)"; exit 1
fi
