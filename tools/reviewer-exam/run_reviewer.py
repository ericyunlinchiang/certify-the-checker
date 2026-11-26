#!/usr/bin/env python3
"""Ask a reviewer every question and save its answers.

Built-in baselines (no AI needed) show what a score means:
  always-defect   says DEFECT to everything (a "flag everything" reviewer)
  always-safe     says SAFE to everything
  random          coin flip (seeded)
Your own reviewer: --cmd "your command". It gets one prompt on stdin and must print DEFECT or SAFE
(the first of the two words found in its output counts; anything else is recorded as NO-ANSWER).

Usage:
  run_reviewer.py questions.jsonl answers.jsonl --baseline always-defect
  run_reviewer.py questions.jsonl answers.jsonl --cmd "my-reviewer --model x"
"""
import argparse, json, random, re, shlex, subprocess, sys

PROMPT = """You are reviewing C/C++ code. Look ONLY at lines {s} to {e} of {file} (line numbers are on the left;
the other lines are context). Is there a defect in those lines: a bug that makes the program behave wrongly for some
reachable input or state (memory error, wrong result, wrong state, crash)? Style issues are not defects.
Answer with one word on the first line: DEFECT or SAFE.

{code}
"""
WORD = re.compile(r'\b(DEFECT|SAFE)\b')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('questions'); ap.add_argument('answers')
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--baseline', choices=['always-defect', 'always-safe', 'random'])
    g.add_argument('--cmd')
    ap.add_argument('--seed', type=int, default=1); ap.add_argument('--timeout', type=int, default=300)
    a = ap.parse_args()
    rnd = random.Random(a.seed)
    with open(a.questions) as qf, open(a.answers, 'w') as out:
        for line in qf:
            q = json.loads(line)
            if a.baseline == 'always-defect':
                ans = 'DEFECT'
            elif a.baseline == 'always-safe':
                ans = 'SAFE'
            elif a.baseline == 'random':
                ans = rnd.choice(['DEFECT', 'SAFE'])
            else:
                prompt = PROMPT.format(s=q['lines'][0], e=q['lines'][1], file=q['file'], code=q['code'])
                try:
                    r = subprocess.run(shlex.split(a.cmd), input=prompt, capture_output=True, text=True,
                                       timeout=a.timeout)
                    m = WORD.search(r.stdout.upper())
                    ans = m.group(1) if m else 'NO-ANSWER'
                except (subprocess.TimeoutExpired, OSError) as e:
                    print(f"{q['id']}: reviewer failed: {e}", file=sys.stderr)
                    ans = 'NO-ANSWER'
            out.write(json.dumps({'id': q['id'], 'answer': ans}) + '\n')

if __name__ == '__main__':
    main()
