#!/usr/bin/env python3
"""Print the percentage of non-zero entries in a count file."""

import argparse
import sys


def main():
    parser = argparse.ArgumentParser(description="Print non-zero percentage of a count file")
    parser.add_argument("file", help="Count file to analyse")
    args = parser.parse_args()

    total = 0
    nonzero = 0

    with open(args.file) as f:
        for line in f:
            line = line.strip()
            if not line or ":" not in line:
                continue
            _, _, val = line.partition(":")
            try:
                n = int(val.strip())
            except ValueError:
                continue
            total += 1
            if n != 0:
                nonzero += 1

    if total == 0:
        print("No entries found.", file=sys.stderr)
        sys.exit(1)

    pct = nonzero / total * 100
    print(f"Non-zero: {nonzero}/{total} ({pct:.2f}%)")


if __name__ == "__main__":
    main()
