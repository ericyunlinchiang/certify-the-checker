#!/usr/bin/env bash
# Run every example and print the results table ("gallery").
# Usage: tools/run_all.sh [--check]   (--check compares with examples/expected-results.txt and fails on a difference)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING TOOL: $1 (see README: Requirements)"; exit 2; }; }
need gcc; need clang
if gcc --version 2>/dev/null | head -1 | grep -qi clang; then
  echo "Your 'gcc' is really clang (common on macOS). These examples need GNU gcc >= 13 on Linux. See README."; exit 2; fi
gmaj=$(gcc -dumpversion | cut -d. -f1)
[ "$gmaj" -ge 13 ] 2>/dev/null || { echo "gcc $gmaj found; gcc >= 13 is needed. See README."; exit 2; }
command -v cppcheck >/dev/null 2>&1 || echo "(cppcheck not installed: its column will show SKIPPED)"
res="$(mktemp)"; trap 'rm -f "$res"' EXIT
for d in "$ROOT"/examples/*/; do "$ROOT/tools/run_example.sh" "$d" --quiet | grep '^RESULT' >> "$res"; done
echo
echo "| example | clang --analyze | gcc -fanalyzer | cppcheck | running the code (per input class) |"
echo "|---|---|---|---|---|"
while read -r _ name c g p rest; do
  echo "| $name | ${c#clang=} | ${g#gcc=} | ${p#cppcheck=} | ${rest#exec: } |"
done < "$res"
if [ "${1:-}" = "--check" ]; then
  if diff <(sed 's/^RESULT //' "$res") "$ROOT/examples/expected-results.txt" >/dev/null; then
    echo; echo "CHECK: results match examples/expected-results.txt"
  else echo; echo "CHECK: results DIFFER from examples/expected-results.txt (other tool versions?)"
    diff <(sed 's/^RESULT //' "$res") "$ROOT/examples/expected-results.txt"; exit 1; fi
fi
