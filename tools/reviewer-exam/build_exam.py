#!/usr/bin/env python3
"""Build a per-bug-site exam for an AI code reviewer from a repository's own git history.

Each small bug-fix commit gives two questions about the SAME lines:
  - the code before the fix  -> expected answer DEFECT
  - the code after the fix   -> expected answer SAFE   (only for these lines; the file may have other bugs)
The answer key is written to a separate file. Give the reviewer only questions.jsonl.

Usage:
  build_exam.py REPO OUTDIR [--max-lines 30] [--context 30] [--limit 40] [--seed 1]
"""
import argparse, hashlib, json, os, random, re, subprocess, sys

FIX = re.compile(r'\b(fix|fixes|fixed|bug|crash|segfault|leak|overflow|underflow|null|nullptr|use.after|out of bounds|'
                 r'oob|race|deadlock|uninitiali[sz]ed|off.by.one|dangling|double free|hang|incorrect|wrong)\b', re.I)
COSMETIC = re.compile(r'\b(typo|spelling|build|compil\w*|lint|clang|tidy|format\w*|warning|doc|docs|comment|readme|'
                      r'style|ci|meson|cmake|tests?|unit|whitespace|include|header|rename|refactor|clean ?up|revert|'
                      r'log|logging|message|json|schema|validator|unused|32/64)\b', re.I)
MEMORY = re.compile(r'\b(overflow|underflow|null|nullptr|leak|use.after|uaf|out of bounds|oob|bounds|uninitiali[sz]ed|'
                    r'dangling|double free|segfault|crash|abort|memory|buffer|lifetime|asan|ubsan)\b', re.I)
SRC = ('.c', '.cc', '.cpp', '.cxx', '.h', '.hh', '.hpp')

def git(repo, *args):
    return subprocess.run(['git', '-C', repo, *args], check=True, capture_output=True, text=True,
                          errors='replace').stdout

def candidates(repo, max_lines):
    log = git(repo, 'log', '--no-merges', '--format=%H%x09%P%x09%s')
    for line in log.splitlines():
        h, parents, subj = (line.split('\t', 2) + ['', ''])[:3]
        if ' ' in parents.strip() or not parents or not FIX.search(subj) or COSMETIC.search(subj):
            continue
        stat = [l.split('\t') for l in git(repo, 'show', '--numstat', '--format=', h).splitlines() if l]
        src = [s for s in stat if s[2].endswith(SRC) and 'test' not in s[2].lower()]
        if len(src) != 1 or src[0][0] == '-' or int(src[0][0]) + int(src[0][1]) > max_lines:
            continue
        yield h, parents.strip(), src[0][2], subj

def first_hunk(repo, h, path):
    diff = git(repo, 'show', '-U0', '--format=', h, '--', path)
    m = re.search(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', diff, re.M)
    if not m:
        return None
    o, oc, n, nc = int(m[1]), int(m[2] or 1), int(m[3]), int(m[4] or 1)
    # A pure insertion has 0 old lines: point the old side at the line it was inserted after.
    return (o, max(oc, 1)), (n, max(nc, 1))

def snippet(text, start, count, ctx):
    lines = text.splitlines()
    lo, hi = max(1, start - ctx), min(len(lines), start + count - 1 + ctx)
    body = '\n'.join(f'{i:5d}  {lines[i - 1]}' for i in range(lo, hi + 1))
    return body, start, min(len(lines), start + count - 1)

def qid(*parts):
    return hashlib.sha256('|'.join(parts).encode()).hexdigest()[:10]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('repo'); ap.add_argument('outdir')
    ap.add_argument('--max-lines', type=int, default=30); ap.add_argument('--context', type=int, default=30)
    ap.add_argument('--limit', type=int, default=40); ap.add_argument('--seed', type=int, default=1)
    a = ap.parse_args()
    os.makedirs(a.outdir, exist_ok=True)
    qs, key = [], []
    for h, parent, path, subj in candidates(a.repo, a.max_lines):
        hk = first_hunk(a.repo, h, path)
        if not hk:
            continue
        cls = 'memory' if MEMORY.search(subj) else 'logic'
        pair = []
        for side, rev, (start, count), answer in (('before', parent, hk[0], 'DEFECT'), ('after', h, hk[1], 'SAFE')):
            try:
                text = git(a.repo, 'show', f'{rev}:{path}')
            except subprocess.CalledProcessError:
                pair = []
                break  # file missing on one side (added or deleted): skip the whole pair
            body, s, e = snippet(text, start, count, a.context)
            i = qid(os.path.basename(os.path.abspath(a.repo)), h, side)
            pair.append(({'id': i, 'file': path, 'lines': [s, e], 'code': body},
                         {'id': i, 'answer': answer, 'class': cls, 'commit': h, 'side': side, 'subject': subj}))
        for q, k in pair:
            qs.append(q); key.append(k)
        if len(key) >= 2 * a.limit:
            break
    random.Random(a.seed).shuffle(qs)
    with open(os.path.join(a.outdir, 'questions.jsonl'), 'w') as f:
        for q in qs:
            f.write(json.dumps(q) + '\n')
    with open(os.path.join(a.outdir, 'answer-key.jsonl'), 'w') as f:
        for k in key:
            f.write(json.dumps(k) + '\n')
    print(f'{len(qs)} questions from {len(key) // 2} fix commits -> {a.outdir} (keep answer-key.jsonl away from the reviewer)')

if __name__ == '__main__':
    main()
