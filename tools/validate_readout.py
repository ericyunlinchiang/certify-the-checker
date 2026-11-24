#!/usr/bin/env python3
"""Check readout.json files against schema/readout.schema.json (required keys and allowed values only; stdlib, no
dependencies). Usage: tools/validate_readout.py FILE [FILE...]"""
import json, os, sys

def check(obj, sch, path, errs):
    if 'enum' in sch and obj not in sch['enum']:
        errs.append('%s: %r not in %s' % (path, obj, sch['enum']))
    t = sch.get('type')
    if t == 'object':
        if not isinstance(obj, dict):
            errs.append('%s: not an object' % path); return
        for k in sch.get('required', []):
            if k not in obj:
                errs.append('%s: missing %s' % (path, k))
        for k, v in obj.items():
            if k in sch.get('properties', {}):
                check(v, sch['properties'][k], path + '.' + k, errs)
            elif isinstance(sch.get('additionalProperties'), dict):
                check(v, sch['additionalProperties'], path + '.' + k, errs)
    elif t == 'array':
        if not isinstance(obj, list):
            errs.append('%s: not a list' % path); return
        if len(obj) < sch.get('minItems', 0):
            errs.append('%s: too few items' % path)
        for i, v in enumerate(obj):
            check(v, sch.get('items', {}), '%s[%d]' % (path, i), errs)
    elif t == 'string' and not isinstance(obj, str):
        errs.append('%s: not a string' % path)

schema = json.load(open(os.path.join(os.path.dirname(__file__), '..', 'schema', 'readout.schema.json')))
bad = 0
for f in sys.argv[1:]:
    errs = []
    check(json.load(open(f)), schema, '$', errs)
    print(('OK   ' if not errs else 'FAIL ') + f)
    for e in errs:
        print('     ' + e)
    bad += bool(errs)
sys.exit(1 if bad else 0)
