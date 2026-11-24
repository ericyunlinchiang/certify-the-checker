#!/usr/bin/env bash
# Run one example: three static checkers on target.c, then the code itself under AddressSanitizer/UBSan,
# once per input class. Prints a table, then a JSON readout (same shape as readout-template.json).
# Usage: tools/run_example.sh examples/<name> [--quiet]
set -uo pipefail
DIR="$(cd "${1:?usage: tools/run_example.sh examples/<name>}" && pwd)"
QUIET="${2:-}"
# shellcheck disable=SC1091
source "$DIR/example.env"   # TITLE FUNC BUG_LINE CLASSES
T="$DIR/target.c"; NAME="$(basename "$DIR")"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# --- static checkers: verdict = BUG if the checker reports the bug line, else CLEAN ---
lines_of() { grep -oE "target\.c:[0-9]+" | cut -d: -f2 | sort -un | tr '\n' ' ' | sed 's/ $//'; }
verdict_of() { if echo " $1 " | grep -q " $BUG_LINE "; then echo BUG; else echo CLEAN; fi; }
clang_l="$(cd "$DIR" && clang --analyze -o /dev/null target.c 2>&1 | grep -E "warning:|error:" | lines_of)"
gcc_l="$(cd "$DIR" && gcc -fanalyzer -c target.c -o /dev/null 2>&1 | grep -E "warning:|error:" | lines_of)"
if command -v cppcheck >/dev/null 2>&1; then
  cpp_l="$(cd "$DIR" && cppcheck --enable=warning --quiet target.c 2>&1 | grep -E "(error|warning):" | lines_of)"; cpp_v="$(verdict_of "$cpp_l")"
else cpp_l=""; cpp_v="SKIPPED"; fi
clang_v="$(verdict_of "$clang_l")"; gcc_v="$(verdict_of "$gcc_l")"

# --- execution: one process per input class under ASan+UBSan ---
gcc -std=c11 -g -O0 -fsanitize=address,undefined -fno-sanitize-recover=all "$DIR/harness.c" "$T" -o "$WORK/x" 2>"$WORK/build.log" \
  || { echo "BUILD FAILED"; cat "$WORK/build.log"; exit 3; }
declare -A XV XL
for c in $CLASSES; do
  out="$("$WORK/x" "$c" 2>&1)"; rc=$?
  if echo "$out" | grep -qE "ERROR: AddressSanitizer|runtime error:" && echo "$out" | grep -qE "in $FUNC |target\.c:[0-9]+"; then
    XV[$c]=BUG; XL[$c]="$(echo "$out" | grep -E "(in $FUNC .*)?target\.c:[0-9]+" | head -1 | grep -oE "target\.c:[0-9]+" | cut -d: -f2)"
    [ -z "${XL[$c]}" ] && XL[$c]="$(echo "$out" | grep -oE "target\.c:[0-9]+" | head -1 | cut -d: -f2)"
  elif [ "$rc" = 0 ]; then XV[$c]=CLEAN; XL[$c]=""
  else XV[$c]="ERROR(rc=$rc)"; XL[$c]=""; fi
done

if [ "$QUIET" != "--quiet" ]; then
  echo "== $NAME: $TITLE (bug line: target.c:$BUG_LINE)"
  printf "  %-16s %-8s %s\n" "checker" "verdict" "lines it reported"
  printf "  %-16s %-8s %s\n" "clang --analyze" "$clang_v" "${clang_l:--}"
  printf "  %-16s %-8s %s\n" "gcc -fanalyzer" "$gcc_v" "${gcc_l:--}"
  printf "  %-16s %-8s %s\n" "cppcheck" "$cpp_v" "${cpp_l:--}"
  echo "  execution (ASan/UBSan), one run per input class:"
  for c in $CLASSES; do printf "    %-12s %s%s\n" "$c" "${XV[$c]}" "${XL[$c]:+ at target.c:${XL[$c]}}"; done
  for k in clang gcc cpp; do eval l=\$${k}_l; kn=$k; [ $k = cpp ] && kn=cppcheck
    for n in $l; do [ "$n" != "$BUG_LINE" ] && echo "  note: $kn also reported line $n; no execution run confirmed a bug there."; done; done
fi
# machine-readable line for tools/run_all.sh
xs=""; for c in $CLASSES; do xs="$xs $c=${XV[$c]}"; done
echo "RESULT $NAME clang=$clang_v gcc=$gcc_v cppcheck=$cpp_v exec:${xs}"
if [ "$QUIET" != "--quiet" ]; then
  echo "  readout (JSON):"
  { printf '{\n  "standard": "certify-the-checker v0",\n  "claim_id": "%s",\n  "location": "examples/%s/target.c:%s",\n' "$NAME" "$NAME" "$BUG_LINE"
    printf '  "build_config": "host build, gcc %s, clang %s, cppcheck %s",\n' "$(gcc -dumpfullversion)" \
      "$(clang --version | sed -n '1s/.*version \([0-9.]*\).*/\1/p')" "$(cppcheck --version 2>/dev/null | awk '{print $2}')"
    printf '  "checkers": { "clang --analyze": "%s", "gcc -fanalyzer": "%s", "cppcheck": "%s" },\n  "cells": [\n' "$clang_v" "$gcc_v" "$cpp_v"
    first=1; for c in $CLASSES; do [ $first = 1 ] || printf ',\n'; first=0
      printf '    { "input_class": "%s", "execution": "%s" }' "$c" "${XV[$c]}"; done
    printf '\n  ],\n  "note": "Illustration with the author'"'"'s own code; not a vulnerability report."\n}\n'; } | sed 's/^/  /'
fi
