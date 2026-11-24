#!/usr/bin/env bash
# Run every example and print the results table.
# Usage: tools/run_all.sh [--check]
#   --check  compares the results with examples/expected-results.txt and fails on any difference.
#            It checks that you get the SAME results as the README (reproducibility), not that a checker is good.
# Set CTC_OUT=<dir> to keep all raw outputs and readout.json files (CI does this and publishes them).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
need() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING TOOL: $1 (see README: Requirements, or use the Dockerfile)"; exit 2; }; }
need gcc; need clang; need gcov; need python3
if gcc --version 2>/dev/null | head -1 | grep -qi clang; then
  echo "Your 'gcc' is really clang (common on macOS). Use the Dockerfile (see README)."; exit 2; fi
gmaj=$(gcc -dumpversion | cut -d. -f1)
[ "$gmaj" -ge 13 ] 2>/dev/null || { echo "gcc $gmaj found; gcc >= 13 is needed. Use the Dockerfile (see README)."; exit 2; }
command -v cppcheck >/dev/null 2>&1 || echo "(cppcheck not installed: its column shows SKIPPED and --check will report a difference)"
res="$(mktemp)"; trap 'rm -f "$res"' EXIT
for d in "$ROOT"/examples/*/; do "$ROOT/tools/run_example.sh" "$d" --quiet | grep '^RESULT' >> "$res"; done
echo
echo "| example | clang --analyze | gcc -fanalyzer | cppcheck | running the code (per kind of input) |"
echo "|---|---|---|---|---|"
while read -r _ name c g p rest; do
  echo "| $name | ${c#clang=} | ${g#gcc=} | ${p#cppcheck=} | ${rest#exec: } |"
done < "$res"
if [ -n "${CTC_OUT:-}" ]; then
  python3 - "$CTC_OUT" <<'PY'
import json, glob, os, sys
out = sys.argv[1]
docs = [json.load(open(f)) for f in sorted(glob.glob(os.path.join(out, '*', 'readout.json')))]
json.dump({'standard': 'certify-the-checker v0', 'readouts': docs}, open(os.path.join(out, 'results.json'), 'w'), indent=2)
print('\nall readouts: %s' % os.path.join(out, 'results.json'))
PY
fi
if [ "${1:-}" = "--check" ]; then
  if diff <(sed 's/^RESULT //' "$res") "$ROOT/examples/expected-results.txt" >/dev/null; then
    echo; echo "CHECK: same results as examples/expected-results.txt (reproduced)"
  else echo; echo "CHECK: results DIFFER from examples/expected-results.txt (other tool versions?)"
    diff <(sed 's/^RESULT //' "$res") "$ROOT/examples/expected-results.txt"; exit 1; fi
fi
