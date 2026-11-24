#!/usr/bin/env bash
# Run one example:
#   1. four static checks on target.c (raw output kept): compiler warnings, clang, gcc -fanalyzer, cppcheck,
#   2. the code itself under AddressSanitizer + UBSan, one run per input class,
#   3. a coverage build (gcov) per input class, to measure how deep each run went.
# Then tools/readout.py prints a summary and writes readout.json (schema: schema/readout.schema.json).
# Usage: tools/run_example.sh examples/<name> [--quiet]
# Raw outputs go to $CTC_OUT/<name>/ if CTC_OUT is set, otherwise to a temporary directory.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$(cd "${1:?usage: tools/run_example.sh examples/<name>}" && pwd)"
QUIET="${2:-}"
NAME="$(basename "$DIR")"
# shellcheck disable=SC1091
source "$DIR/example.env"   # TITLE FUNC BUG_LINES BUG_LINES_WHY CLASSES
if [ -n "${CTC_OUT:-}" ]; then mkdir -p "$CTC_OUT"; OUT="$(cd "$CTC_OUT" && pwd)/$NAME"; rm -rf "$OUT"; mkdir -p "$OUT"; KEEP=1
else OUT="$(mktemp -d)"; KEEP=0; fi
mkdir -p "$OUT/static" "$OUT/exec" "$OUT/cov"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"; [ "$KEEP" = 1 ] || rm -rf "$OUT"' EXIT

# 1. static checkers (run from the example dir so reported paths are "target.c:LINE")
(cd "$DIR" && clang --analyze -o /dev/null target.c) > "$OUT/static/clang.txt" 2>&1
(cd "$DIR" && gcc -Wall -Wextra -fanalyzer -c target.c -o /dev/null) > "$OUT/static/gcc.txt" 2>&1
(cd "$DIR" && gcc -Wall -Wextra -Wconversion -Wsign-conversion -c target.c -o /dev/null) > "$OUT/static/warn.txt" 2>&1
if command -v cppcheck >/dev/null 2>&1; then
  (cd "$DIR" && cppcheck --enable=all --suppress=missingIncludeSystem --suppress=unusedFunction --quiet target.c) \
    > "$OUT/static/cppcheck.txt" 2>&1
else echo "SKIPPED: cppcheck not installed" > "$OUT/static/cppcheck.skipped"; fi

# 2. execution under ASan + UBSan, one process per input class
gcc -std=c11 -g -O0 -fsanitize=address,undefined -fno-sanitize-recover=all \
    "$DIR/harness.c" "$DIR/target.c" -o "$WORK/x_san" 2>"$OUT/exec/build.log" \
  || { echo "BUILD FAILED (sanitizer build)"; cat "$OUT/exec/build.log"; exit 3; }
for c in $CLASSES; do "$WORK/x_san" "$c" > "$OUT/exec/$c.txt" 2>&1; echo $? > "$OUT/exec/$c.rc"; done

# 3. coverage build (no sanitizers), one run per input class, gcov JSON with branch data
cp "$DIR/target.c" "$DIR/harness.c" "$WORK/"
( cd "$WORK" && gcc -std=c11 -g -O0 --coverage -fno-stack-protector \
    harness.c target.c "$ROOT/tools/support/gcov_dump_on_crash.c" -o x_cov ) 2>"$OUT/cov/build.log" \
  || { echo "BUILD FAILED (coverage build)"; cat "$OUT/cov/build.log"; exit 3; }
for c in $CLASSES; do
  ( cd "$WORK" && rm -f ./*.gcda && { ./x_cov "$c" >/dev/null 2>&1 || true; }
    gcov -b --json-format --stdout x_cov-target.gcda > "$OUT/cov/$c.json" 2>/dev/null ) 2>/dev/null
done

echo "gcc $(gcc -dumpfullversion), clang $(clang --version | sed -n '1s/.*version \([0-9.]*\).*/\1/p'), cppcheck $(cppcheck --version 2>/dev/null | awk '{print $2}'), gcov $(gcov --version | head -1 | awk '{print $NF}')" > "$OUT/versions.txt"
python3 "$ROOT/tools/readout.py" "$DIR" "$OUT" ${QUIET:+--quiet}
