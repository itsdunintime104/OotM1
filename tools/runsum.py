"""One line per run: gameplay frames, frame time, GPU span, main thread, late frames. Read-only.
Usage: python3 -I runsum.py <tsv> [<tsv> ...]"""
import collections
import os
import sys


def q(v, x):
    s = sorted(v)
    return s[min(len(s) - 1, int(x * len(s)))] if s else float('nan')


for path in sys.argv[1:]:
    r = collections.defaultdict(dict)
    for line in open(path, errors='replace'):
        p = line.rstrip('\n').split('\t')
        if len(p) == 3 and p[1].startswith('@'):
            try:
                r[int(p[0])][p[1][1:]] = float(p[2])
            except ValueError:
                pass
    fs = [f for f in range(4500, max(r) - 60) if r[f].get('draws', 0) > 1500 and 'gpu_end_ms' in r[f] and 'gpu_beg_ms' in r[f]]
    sp = [r[f]['gpu_end_ms'] - r[f]['gpu_beg_ms'] for f in fs]
    fm = [r[f].get('frame_ms', 0) for f in fs]
    mt = [r[f].get('sub_wall_ms', 0) for f in fs]
    lt = []
    for f in fs:
        a, b = r[f].get('pres_at_ms'), r.get(f - 1, {}).get('pres_at_ms')
        if a is not None and b is not None:
            lt.append(round((a - b) / (1000 / 120)) >= 3)
    print('%-8s %5d frames: frame p50 %.2f p95 %.2f p99 %.2f; over 17.5 ms %4.1f%%; GPU span p50 %.2f p95 %.2f; GPU sum p50 %.2f; main thread p50 %.2f p95 %.2f; sync wait p50 %.2f; draws p50 %.0f; late/1k %.0f' % (
        os.path.basename(path)[:-4], len(fs), q(fm, .5), q(fm, .95), q(fm, .99), 100 * sum(x > 17.5 for x in fm) / max(1, len(fm)), q(sp, .5), q(sp, .95),
        q([r[f].get('gpu_ms', 0) for f in fs], .5), q(mt, .5), q(mt, .95), q([r[f].get('sync_ms', 0) for f in fs], .5), q([r[f].get('draws', 0) for f in fs], .5), 1000 * sum(lt) / max(1, len(lt))))
