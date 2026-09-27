#!/usr/bin/env python3
"""Print uncovered lines from an lcov report."""
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else 'coverage/lcov.cleaned.info'
found = False
for rec in open(path).read().split('end_of_record'):
    m = re.search(r'SF:(.*)', rec)
    if not m:
        continue
    lines = [x[3:].split(',')[0] for x in rec.splitlines()
             if x.startswith('DA:') and x.endswith(',0')]
    if lines:
        found = True
        print(m.group(1), 'uncovered:', ','.join(lines))
if not found:
    print('all lines covered')
