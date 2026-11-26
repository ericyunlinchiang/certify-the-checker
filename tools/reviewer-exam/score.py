#!/usr/bin/env python3
"""Score a reviewer's answers against the answer key.

Prints, overall and per bug class:
  recall      = bugs found / bugs present          (high is good)
  precision   = real bugs / DEFECT answers         (low means many false alarms)
  false-alarm = DEFECT on fixed code / fixed code  (low is good)
  no-answer   = questions without a usable answer (counted as wrong)
A reviewer that says DEFECT to everything gets recall 1.00 but false-alarm 1.00: look at both.

Usage: score.py answer-key.jsonl answers.jsonl
"""
import collections, json, sys

def load(path):
    with open(path) as f:
        return {d['id']: d for d in map(json.loads, f)}

def row(name, c):
    tp, fn, fp, tn, na = c['TP'], c['FN'], c['FP'], c['TN'], c['NA']
    f = lambda x, y: f'{x / y:.2f}' if y else '  - '
    return (f"{name:8s} {tp + fn + fp + tn:5d}  recall {f(tp, tp + fn)}  precision {f(tp, tp + fp)}  "
            f"false-alarm {f(fp, fp + tn)}  no-answer {na}")

def main(keyf, ansf):
    key, ans = load(keyf), load(ansf)
    by = collections.defaultdict(collections.Counter)
    for i, k in key.items():
        a = ans.get(i, {}).get('answer', 'NO-ANSWER')
        if a not in ('DEFECT', 'SAFE'):
            for c in ('all', k['class']):
                by[c]['NA'] += 1
            a = 'SAFE' if k['answer'] == 'DEFECT' else 'DEFECT'  # no answer counts as wrong
        cell = {('DEFECT', 'DEFECT'): 'TP', ('DEFECT', 'SAFE'): 'FN',
                ('SAFE', 'DEFECT'): 'FP', ('SAFE', 'SAFE'): 'TN'}[(k['answer'], a)]
        for c in ('all', k['class']):
            by[c][cell] += 1
    for c in ['all'] + sorted(x for x in by if x != 'all'):
        print(row(c, by[c]))

if __name__ == '__main__':
    main(*sys.argv[1:3])
