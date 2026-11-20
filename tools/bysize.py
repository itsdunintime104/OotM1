"""GPU encoder time per frame grouped by render-target size, gameplay frames (>= 5000) of one log. Read-only.
Usage: python3 -I bysize.py <log> [top N]"""
import collections
import re
import sys

G = re.compile(r'\[gpuprof\] F(\d+)\s+\d+\s+([\d.]+) us (?:render pass \d+ (\d+x\d+) colors (\d+) depth (\d+) loads \d+ draws (\d+)|compute / copy)')
us = collections.Counter(); n = collections.Counter(); dr = collections.Counter(); frames = set()
for line in open(sys.argv[1], errors='replace'):
    m = G.search(line)
    if not m or int(m.group(1)) < 5000:
        continue
    frames.add(int(m.group(1)))
    k = ('%s c%s d%s' % (m.group(3), m.group(4), m.group(5))) if m.group(3) else 'compute / copy'
    us[k] += float(m.group(2)); n[k] += 1; dr[k] += int(m.group(6) or 0)
f = max(1, len(frames))
print('%d sampled frames; encoder time %.2f ms a frame (sum of durations; they overlap)' % (f, sum(us.values()) / f / 1000))
for k, v in us.most_common(int(sys.argv[2]) if len(sys.argv) > 2 else 12):
    print('  %-22s %6.2f ms  %5.1f encoders  %6.0f draws a frame' % (k, v / f / 1000, n[k] / f, dr[k] / f))
