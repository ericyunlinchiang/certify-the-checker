#!/usr/bin/env python3
"""Turn the raw outputs of tools/run_example.sh into a summary and a readout.json.

Rules (also written in README.md):
- A static checker "finds the bug" if it reports any line listed in BUG_LINES.
- Execution: BUG if AddressSanitizer/UBSan reports an error in target.c for that input class; CLEAN if the run
  exits normally; NOTRIGGER if no bug line was executed (the run says nothing about the bug).
- Coverage depth per input class, measured with gcov:
    input-class  the run triggered the bug (the risky condition was exercised);
    branch       every bug line ran and every branch in the function was taken both ways;
    line         every bug line ran, but some branch in the function was not taken both ways;
    partial      some bug lines ran, others (often the root cause) never ran;
    none         no bug line ran.
  For an input class that triggers the bug, the coverage numbers are not reported: the coverage build has no
  sanitizer, so the bug itself can corrupt the run.
- Control grade: "controlled" if at least one input class makes execution report BUG (the check is shown able to
  fail on this target); otherwise "uncontrolled".
"""
import json, os, re, shlex, sys

def load_env(path):
    env = {}
    for line in open(path):
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        k, v = line.split('=', 1)
        env[k] = ' '.join(shlex.split(v))
    return env

def reported_lines(text):
    return sorted({int(m) for m in re.findall(r'target\.c:(\d+)', text)})

def main():
    d, out = sys.argv[1], sys.argv[2]
    quiet = '--quiet' in sys.argv[3:]
    env = load_env(os.path.join(d, 'example.env'))
    name = os.path.basename(os.path.normpath(d))
    bug = [int(x) for x in env['BUG_LINES'].split()]
    classes = env['CLASSES'].split()

    # static checkers
    checkers = {}
    for key, label in (('clang', 'clang --analyze'), ('gcc', 'gcc -Wall -Wextra -fanalyzer'),
                       ('cppcheck', 'cppcheck --enable=all')):
        p = os.path.join(out, 'static', key + '.txt')
        if not os.path.exists(p):
            checkers[key] = {'label': label, 'verdict': 'SKIPPED', 'lines': []}
            continue
        lines = reported_lines(open(p, errors='replace').read())
        checkers[key] = {'label': label, 'lines': lines,
                         'verdict': 'BUG' if any(l in bug for l in lines) else 'CLEAN'}

    # coverage per class
    cov = {}
    for c in classes:
        info = {'bug_lines_run': {}, 'branches_total': 0, 'branches_taken': 0, 'untaken_branch_lines': []}
        p = os.path.join(out, 'cov', c + '.json')
        try:
            doc = json.loads(open(p).read().strip().splitlines()[0])
            for f in doc['files']:
                if not f['file'].endswith('target.c'):
                    continue
                for ln in f['lines']:
                    n = ln['line_number']
                    if n in bug:
                        info['bug_lines_run'][n] = ln['count']
                    for b in ln.get('branches', []):
                        info['branches_total'] += 1
                        if b['count'] > 0:
                            info['branches_taken'] += 1
                        elif n not in info['untaken_branch_lines']:
                            info['untaken_branch_lines'].append(n)
        except (OSError, ValueError, IndexError, KeyError):
            info['error'] = 'no coverage data'
        for n in bug:
            info['bug_lines_run'].setdefault(n, 0)
        cov[c] = info

    # execution per class
    exe = {}
    for c in classes:
        text = open(os.path.join(out, 'exec', c + '.txt'), errors='replace').read()
        rc = int(open(os.path.join(out, 'exec', c + '.rc')).read().strip() or '0')
        san = ('ERROR: AddressSanitizer' in text or 'runtime error:' in text) and 'target.c:' in text
        any_bug_line_ran = any(v > 0 for v in cov[c]['bug_lines_run'].values())
        if san:
            m = re.search(r'target\.c:(\d+)', text)
            exe[c] = {'verdict': 'BUG', 'line': int(m.group(1)) if m else None}
        elif not any_bug_line_ran:
            exe[c] = {'verdict': 'NOTRIGGER', 'line': None}
        elif rc == 0:
            exe[c] = {'verdict': 'CLEAN', 'line': None}
        else:
            exe[c] = {'verdict': 'ERROR', 'line': None, 'rc': rc}

    def depth(c):
        if exe[c]['verdict'] == 'BUG':
            return 'input-class'
        runs = cov[c]['bug_lines_run']
        if not runs or max(runs.values()) == 0:
            return 'none'
        if min(runs.values()) == 0:
            return 'partial'
        if cov[c]['branches_total'] and cov[c]['branches_taken'] == cov[c]['branches_total']:
            return 'branch'
        return 'line'

    controlled = any(e['verdict'] == 'BUG' for e in exe.values())

    def result(cv, ev, dep):
        if ev == 'NOTRIGGER':
            return 'not covered'
        if cv == 'SKIPPED':
            return 'checker not run'
        if cv == 'CLEAN' and ev == 'BUG':
            return 'checker missed a real bug'
        if cv == 'BUG' and ev == 'BUG':
            return 'both found it'
        if cv == 'BUG' and ev == 'CLEAN':
            return 'checker reports a bug that this input did not trigger'
        if cv == 'CLEAN' and ev == 'CLEAN':
            return 'certify_clean' if controlled else 'clean, but uncontrolled'
        return 'error'

    cells = []
    for key, ch in checkers.items():
        for c in classes:
            dep = depth(c)
            cells.append({'input_class': c, 'checker': ch['label'], 'checker_verdict': ch['verdict'],
                          'execution': exe[c]['verdict'], 'coverage_depth': dep,
                          'result': result(ch['verdict'], exe[c]['verdict'], dep)})

    readout = {
        'standard': 'certify-the-checker v0',
        'claim_id': name,
        'location': 'examples/%s/target.c lines %s' % (name, ' '.join(map(str, bug))),
        'bug_lines_why': env.get('BUG_LINES_WHY', ''),
        'build_config': 'host build: ' + open(os.path.join(out, 'versions.txt')).read().strip()
                        if os.path.exists(os.path.join(out, 'versions.txt')) else 'host build',
        'checkers': {ch['label']: ch['verdict'] for ch in checkers.values()},
        'cells': cells,
        'coverage': {c: ({'note': 'the run hit the bug; coverage not reported'} if exe[c]['verdict'] == 'BUG' else
                         {'bug_lines_run': {str(k): v for k, v in cov[c]['bug_lines_run'].items()},
                          'branches_taken': cov[c]['branches_taken'], 'branches_total': cov[c]['branches_total']})
                     for c in classes},
        'control_grade': 'controlled' if controlled else 'uncontrolled',
        'note': "Illustration with the author's own code; not a vulnerability report.",
    }
    with open(os.path.join(out, 'readout.json'), 'w') as f:
        json.dump(readout, f, indent=2)

    if not quiet:
        print('== %s: %s' % (name, env['TITLE']))
        print('   bug lines: %s  (%s)' % (' '.join(map(str, bug)), env.get('BUG_LINES_WHY', '')))
        print('   %-30s %-8s %s' % ('static checker', 'verdict', 'lines it reported'))
        for ch in checkers.values():
            print('   %-30s %-8s %s' % (ch['label'], ch['verdict'], ' '.join(map(str, ch['lines'])) or '-'))
        print('   running the code (ASan + UBSan), one run per input class, with measured coverage:')
        for c in classes:
            e, v = exe[c], cov[c]
            if e['verdict'] == 'BUG':
                detail = 'the run hit the bug'
            else:
                detail = ', '.join('line %d ran %dx' % (k, n) for k, n in sorted(v['bug_lines_run'].items()))
                detail += '; branches taken %d/%d' % (v['branches_taken'], v['branches_total'])
            print('     %-12s %-9s depth=%-11s %s' % (
                c, e['verdict'] + (' @%d' % e['line'] if e.get('line') else ''), depth(c), detail))
        print('   control grade: %s' % readout['control_grade'])
        for ch in checkers.values():
            for n in ch['lines']:
                if n not in bug:
                    print('   note: %s also reported line %d; it is not a bug line, and no run confirmed a bug there.'
                          % (ch['label'], n))
        print('   readout written: %s' % os.path.join(out, 'readout.json'))
    print('RESULT %s clang=%s gcc=%s cppcheck=%s exec:%s' % (
        name, checkers['clang']['verdict'], checkers['gcc']['verdict'], checkers['cppcheck']['verdict'],
        ''.join(' %s=%s' % (c, exe[c]['verdict']) for c in classes)))

if __name__ == '__main__':
    main()
