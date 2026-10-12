#!/usr/bin/env python
"""
hitmap.py - turn recorded function addresses into a btrfs function hit map.

Outputs (in results/):
  hitmap.csv   function, kind, n_baseline_inputs_hitting, n_janus_inputs_hitting
  summary.txt  totals: btrfs functions, hit by baseline, hit by Janus, Janus-only, never hit

'kind':
  btrfs   = defined in exactly one fs/btrfs/*.o  -> a real btrfs function
  inline  = same name defined in several btrfs objects -> almost always a header
            'static inline' helper copied into each file; reported separately
Works with python2 (container) and python3.
"""
from __future__ import print_function
import collections, glob, os, subprocess, sys

LKL = os.environ.get('LKL', '/tmp/jc/lkl')
EXE = os.environ.get('EXE', LKL + '/tools/lkl/executor')
HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, 'results')


def sh(cmd):
    return subprocess.check_output(cmd, shell=True).decode('utf-8', 'replace')


# 1. where does the program expect to be loaded (0 for PIE, 0x400000 for non-PIE)?
link_base = 0
for line in sh('readelf -lW %s' % EXE).splitlines():
    if line.strip().startswith('LOAD'):
        link_base = int(line.split()[2], 16)
        break

# 2. address -> function name, from the executor's symbol table
addr2name = {}
for line in sh('nm --defined-only %s' % EXE).splitlines():
    p = line.split()
    if len(p) == 3 and p[1] in 'tTwW':
        addr2name[int(p[0], 16)] = p[2]

# 3. the universe: every function defined in a btrfs object file
defined_in = collections.defaultdict(set)
for obj in sorted(glob.glob(LKL + '/fs/btrfs/*.o')):
    base = os.path.basename(obj)
    if base.startswith('built-in') or base.startswith('.'):
        continue
    for line in sh('nm --defined-only %s' % obj).splitlines():
        p = line.split()
        if len(p) == 3 and p[1] in 'tT':
            defined_in[p[2]].add(base)
kind = dict((f, 'btrfs' if len(o) == 1 else 'inline') for f, o in defined_in.items())


# 4. count how many inputs hit each function
def load(sub):
    counts = collections.Counter()
    files = sorted(glob.glob(os.path.join(RES, sub, '*.txt')))
    unmapped = 0
    for fn in files:
        names = set()
        for line in open(fn):
            line = line.strip()
            if not line:
                continue
            name = addr2name.get(int(line, 16) + link_base)
            if name:
                names.add(name)
            else:
                unmapped += 1
        counts.update(names)
    return counts, len(files), unmapped


base_c, n_base, um1 = load('baseline')
jan_c, n_jan, um2 = load('janus')

# 5. write the table
with open(os.path.join(RES, 'hitmap.csv'), 'w') as f:
    f.write('function,kind,objects,baseline_inputs,janus_inputs\n')
    for fn in sorted(kind):
        f.write('%s,%s,%s,%d,%d\n' % (fn, kind[fn], ' '.join(sorted(defined_in[fn])),
                                      base_c[fn], jan_c[fn]))

# 6. summary
lines = []
for k in ('btrfs', 'inline'):
    fs = [f for f in kind if kind[f] == k]
    hb = set(f for f in fs if base_c[f])
    hj = set(f for f in fs if jan_c[f])
    lines += ['[%s functions]  total=%d' % (k, len(fs)),
              '  hit by baseline (%d seed runs)   : %d (%.1f%%)' % (n_base, len(hb), 100.0 * len(hb) / max(1, len(fs))),
              '  hit by Janus queue (%d inputs)   : %d (%.1f%%)' % (n_jan, len(hj), 100.0 * len(hj) / max(1, len(fs))),
              '  hit by Janus but NOT baseline    : %d' % len(hj - hb),
              '  hit by baseline but NOT Janus    : %d' % len(hb - hj),
              '  never hit by either (candidates) : %d' % (len(fs) - len(hb | hj)), '']
own = [f for f in kind if kind[f] == 'btrfs']
janus_only = sorted((f for f in own if jan_c[f] and not base_c[f]), key=lambda f: -jan_c[f])
lines.append('Top Janus-only btrfs functions (name: #inputs hitting it):')
lines += ['  %s: %d' % (f, jan_c[f]) for f in janus_only[:40]]
if um1 or um2:
    lines.append('\n(note: %d recorded addresses did not map to a symbol)' % (um1 + um2))
text = '\n'.join(lines)
print(text)
with open(os.path.join(RES, 'summary.txt'), 'w') as f:
    f.write(text + '\n')
print('\nwrote %s and summary.txt' % os.path.join(RES, 'hitmap.csv'))
