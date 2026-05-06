#!/usr/bin/env python3
"""
For every workload/fs directory under a root, merge .count files and report
the non-zero percentage. Results are written to a text file.

Usage:
    python3 pipeline/analyze.py file-system-paper-data/function-coverage-counts \
        -o results.txt
"""

import argparse
import os
import sys
from collections import defaultdict


# ── shared helpers ────────────────────────────────────────────────────────────

def parse_count_file(path):
    counts = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or ":" not in line:
                continue
            key, _, val = line.partition(":")
            try:
                counts[key.strip()] = int(val.strip())
            except ValueError:
                pass
    return counts


def merge_dir(directory):
    """Return merged totals dict for all .count files in directory."""
    totals = defaultdict(int)
    files = [f for f in os.listdir(directory) if f.endswith(".count")]
    for fname in files:
        for key, val in parse_count_file(os.path.join(directory, fname)).items():
            totals[key] += val
    return totals, len(files)


def nonzero_stats(totals):
    """Return (nonzero_count, total_count, percentage) for a totals dict."""
    total = len(totals)
    nonzero = sum(1 for v in totals.values() if v != 0)
    pct = nonzero / total * 100 if total else 0.0
    return nonzero, total, pct


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Merge & analyse all workload count files")
    parser.add_argument("root", help="Root directory containing workload subdirectories")
    parser.add_argument("-o", "--output", default="results.txt", help="Output report file")
    parser.add_argument("--save-merged", action="store_true",
                        help="Save merged .count file next to each fs directory")
    args = parser.parse_args()

    root = args.root
    if not os.path.isdir(root):
        print(f"Not a directory: {root}", file=sys.stderr)
        sys.exit(1)

    lines = []

    workloads = sorted(
        d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d))
    )

    for workload in workloads:
        workload_path = os.path.join(root, workload)
        fs_dirs = sorted(
            d for d in os.listdir(workload_path)
            if os.path.isdir(os.path.join(workload_path, d))
        )

        lines.append(f"\n[{workload}]")

        for fs in fs_dirs:
            fs_path = os.path.join(workload_path, fs)
            totals, n_files = merge_dir(fs_path)

            if not totals:
                lines.append(f"  {fs:<30} no .count files found")
                continue

            nonzero, total, pct = nonzero_stats(totals)
            lines.append(f"  {fs:<30} {nonzero:>4}/{total:<4} non-zero  ({pct:6.2f}%)  [{n_files} files merged]")

            if args.save_merged:
                out_path = os.path.join(fs_path, "merged.count")
                with open(out_path, "w") as f:
                    for key, val in sorted(totals.items()):
                        f.write(f"{key}: {val}\n")

    lines.append("\n" + "=" * 60)
    report = "\n".join(lines)

    with open(args.output, "w") as f:
        f.write(report + "\n")

    print(report)
    print(f"\nReport saved to {args.output}")


if __name__ == "__main__":
    main()
