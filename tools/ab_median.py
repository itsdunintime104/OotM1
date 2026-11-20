#!/usr/bin/env python3
"""The two sides of an in-run A/B from the digest: the median over blocks of each block's p50.
The blocks are split by their label. A run that labels every block "base" has its switch on in the odd blocks,
so those runs are split into even blocks (off) and odd blocks (on).
Usage: python3 -I tools/ab_median.py <ab_phases.tsv> <log name> [<first block> <last block>]
The first blocks of a run hold loading and the walk to the test place: give a range that starts after them."""
import collections
import statistics
import sys


def main() -> None:
    if len(sys.argv) not in (3, 5):
        sys.exit(__doc__)
    table, log = sys.argv[1], sys.argv[2]
    lo, hi = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) == 5 else (0, 10**9)
    rows: list[tuple[int, str, float, float, float]] = []
    with open(table, encoding="utf-8") as fh:
        for ln in fh.readlines()[1:]:
            p = ln.rstrip("\n").split("\t")
            if p[0] == log and lo <= int(p[1]) <= hi:
                rows.append((int(p[1]), p[2], float(p[4]), float(p[7]), float(p[10])))
    if not rows:
        sys.exit(f"no blocks of {log} in that range")
    by_label = len({r[1] for r in rows}) > 1
    sides: dict[str, list[tuple[int, str, float, float, float]]] = collections.defaultdict(list)
    for r in rows:
        sides[r[1] if by_label else ("even blocks (off)" if r[0] % 2 == 0 else "odd blocks (on)")].append(r)
    for side in sorted(sides):
        v = sides[side]
        gpu, frame = [r[2] for r in v], [r[3] for r in v]
        print(f"{log} blocks {v[0][0]}-{v[-1][0]} {side}: {len(v)} blocks; frame p50 median {statistics.median(frame):.2f} ms "
              f"(min {min(frame):.2f}, max {max(frame):.2f}); summed GPU p50 median {statistics.median(gpu):.2f} ms "
              f"(min {min(gpu):.2f}, max {max(gpu):.2f}); passes {statistics.median([r[4] for r in v]):.1f}")


main()
