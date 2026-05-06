#!/usr/bin/env python3
"""Merge all .count files in a directory into a single count file."""

import argparse
import os
import sys
from collections import defaultdict


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


def merge(directory, output):
    totals = defaultdict(int)
    files = [f for f in os.listdir(directory) if f.endswith(".count")]
    if not files:
        print(f"No .count files found in {directory}", file=sys.stderr)
        sys.exit(1)

    for fname in files:
        path = os.path.join(directory, fname)
        for key, val in parse_count_file(path).items():
            totals[key] += val

    with open(output, "w") as f:
        for key, val in sorted(totals.items()):
            f.write(f"{key}: {val}\n")

    print(f"Merged {len(files)} files into {output} ({len(totals)} keys)")


def main():
    parser = argparse.ArgumentParser(description="Merge .count files in a directory")
    parser.add_argument("directory", help="Directory containing .count files")
    parser.add_argument("-o", "--output", default="merged.count", help="Output file (default: merged.count)")
    args = parser.parse_args()

    if not os.path.isdir(args.directory):
        print(f"Not a directory: {args.directory}", file=sys.stderr)
        sys.exit(1)

    merge(args.directory, args.output)


if __name__ == "__main__":
    main()
