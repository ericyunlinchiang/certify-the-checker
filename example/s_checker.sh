#!/usr/bin/env bash
# S producers = REAL public static analyzers (no strawman). Reports each analyzer's verdict on the target.
# clang static analyzer is silent (CLEAN); gcc -fanalyzer flags the dest-size truncation (BUG). Both are real.
set -uo pipefail
T="${1:?usage: s_checker.sh target.c}"
clang_out="$(clang --analyze -Xclang -analyzer-output=text "$T" 2>&1)"
if echo "$clang_out" | grep -qiE "warning:|error:"; then clang_v=BUG; else clang_v=CLEAN; fi
gcc_out="$(gcc -fanalyzer -c "$T" -o /dev/null 2>&1)"
if echo "$gcc_out" | grep -qiE "warning:|error:"; then gcc_v=BUG; else gcc_v=CLEAN; fi
gcc_line="$(echo "$gcc_out" | grep -oE 'target\.c:[0-9]+' | head -1)"
echo "clang_analyze=$clang_v  (clang $(clang --version | sed -n '1s/.*version \([0-9.]*\).*/\1/p'))"
echo "gcc_fanalyzer=$gcc_v${gcc_line:+ at $gcc_line}  (gcc $(gcc -dumpfullversion))"
# machine line for the readout to parse:
echo "S_FIELDS clang=$clang_v gcc=$gcc_v gcc_line=${gcc_line:-none}"
