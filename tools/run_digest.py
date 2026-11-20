#!/usr/bin/env python3
"""Extend the run digest (docs/data) from run logs and per-frame tables, so that the large files can be deleted.
  runs.tsv        one row per per-frame table: the runsum.py line (frames from 4500 with more than 1500 draws)
  ab_phases.tsv   every "[ab] phase N" line of every log
  logs.tsv        one row per log: date, bytes, lines, GPU error lines, picture size, the switches that alternate
A run or a log whose name is already in the digest is skipped: give each run its own file name.
Usage: python3 -I tools/run_digest.py <digest folder> <folder with *.log and *.tsv> [<folder> ...]"""
import datetime
import glob
import os
import re
import subprocess
import sys

AB = re.compile(r"\[ab\] phase (\d+) (\S+): (\d+) frames, GPU p50 ([\d.]+) / p90 ([\d.]+) / mean ([\d.]+) ms, "
                r"frame p50 ([\d.]+) / p90 ([\d.]+) / mean ([\d.]+) ms.*?passes ([\d.]+)")
SW = re.compile(r"\] (DM_[A-Z0-9_]+): on in the DM_AB phases")
CROP = re.compile(r"WindowCrop \d+,\d+ (\d+x\d+)")
ERR = re.compile(r"gpu error", re.I)
FIRST = re.compile(r"^\S+\s+")
HEADS = {
    "runs.tsv": "run\tdate\tsummary (gameplay frames from 4500 with more than 1500 draws)\n",
    "ab_phases.tsv": "log\tphase\tlabel\tframes\tgpu_p50\tgpu_p90\tgpu_mean\tframe_p50\tframe_p90\tframe_mean\tpasses\n",
    "logs.tsv": "log\tdate\tbytes\tlines\tgpu_error_lines\tpicture\tab_switches\tab_lines\n",
}


def stamp(path: str) -> str:
    return datetime.datetime.fromtimestamp(os.path.getmtime(path)).strftime("%Y-%m-%d %H:%M")


def known(path: str, head: str) -> set[str]:
    """The names in the first column of a digest table; the table is made with its header when it does not exist."""
    if not os.path.exists(path):
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(head)
    with open(path, encoding="utf-8") as fh:
        return {ln.split("\t", 1)[0] for ln in fh.readlines()[1:]}


def is_frame_table(path: str) -> bool:
    with open(path, errors="replace") as fh:
        return "nvn-per-frame" in fh.readline()


def add_tables(out: str, folders: list[str]) -> int:
    path = os.path.join(out, "runs.tsv")
    have = known(path, HEADS["runs.tsv"])
    runsum = os.path.join(os.path.dirname(os.path.abspath(__file__)), "runsum.py")
    done = 0
    with open(path, "a", encoding="utf-8") as fh:
        for t in sorted(p for f in folders for p in glob.glob(os.path.join(f, "*.tsv"))):
            name = os.path.basename(t)[:-4]
            if name in have or not is_frame_table(t):
                continue
            r = subprocess.run([sys.executable, "-I", runsum, t], capture_output=True, text=True, check=False)
            ok = r.returncode == 0 and r.stdout.strip()
            line = r.stdout.strip().splitlines()[-1] if ok else "no summary (table has another layout or too few frames)"
            fh.write(name + "\t" + stamp(t) + "\t" + FIRST.sub("", line) + "\n")
            have.add(name)
            done += 1
    return done


def add_logs(out: str, folders: list[str]) -> tuple[int, int]:
    lpath, apath = os.path.join(out, "logs.tsv"), os.path.join(out, "ab_phases.tsv")
    have = known(lpath, HEADS["logs.tsv"])
    known(apath, HEADS["ab_phases.tsv"])
    nlog = nab = 0
    with open(apath, "a", encoding="utf-8") as ab, open(lpath, "a", encoding="utf-8") as lg:
        for p in sorted(q for f in folders for q in glob.glob(os.path.join(f, "*.log"))):
            name = os.path.basename(p)[:-4]
            if name in have:
                continue
            n = err = k = 0
            crop = ""
            sw: list[str] = []
            with open(p, errors="replace") as fh:
                for ln in fh:
                    n += 1
                    if "[ab] phase" in ln:
                        m = AB.search(ln)
                        if m:
                            ab.write(name + "\t" + "\t".join(m.groups()) + "\n")
                            k += 1
                    elif "WindowCrop" in ln:
                        m = CROP.search(ln)
                        if m:
                            crop = m.group(1)
                    elif "on in the DM_AB phases" in ln:
                        m = SW.search(ln)
                        if m and m.group(1) not in sw:
                            sw.append(m.group(1))
                    if ERR.search(ln):
                        err += 1
            lg.write(f"{name}\t{stamp(p)}\t{os.path.getsize(p)}\t{n}\t{err}\t{crop}\t{','.join(sw)}\t{k}\n")
            have.add(name)
            nlog += 1
            nab += k
    return nlog, nab


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out, folders = sys.argv[1], sys.argv[2:]
    os.makedirs(out, exist_ok=True)
    tables = add_tables(out, folders)
    logs, phases = add_logs(out, folders)
    print(f"added: {tables} per-frame tables, {logs} logs, {phases} A/B lines")


main()
