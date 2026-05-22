#!/usr/bin/env python3
"""Generate function-to-LOC maps from code index dumps.

This script reads the index files in `codes/` and writes one output file per
input, keeping only functions that come from `.c` files.
"""

from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
INPUT_FILES = ["ext4.txt", "f2fs.txt", "nfs.txt"]


def parse_entries(path: Path):
    entries = []
    lines = path.read_text().splitlines()
    index_pattern = re.compile(r"^(.*?):(\d+)-(\d+)$")

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        match = index_pattern.match(line)
        if not match or not match.group(1).endswith(".c"):
            i += 1
            continue

        file_path = match.group(1)
        function_name = None
        loc = None

        j = i + 1
        while j < len(lines) and lines[j].strip():
            stripped = lines[j].lstrip()
            if stripped.startswith("Function:"):
                function_name = stripped.split("Function:", 1)[1].strip()
            elif stripped.startswith("LOC:"):
                loc = stripped.split("LOC:", 1)[1].strip().split()[0]
            j += 1

        if function_name and loc:
            entries.append((file_path, function_name, loc))

        i = j

    return entries


def write_output(input_name: str):
    input_path = ROOT / "codes" / input_name
    output_path = ROOT / "codes" / f"{input_path.stem}_c_functions_loc.txt"

    entries = parse_entries(input_path)

    with output_path.open("w") as handle:
        current_path = None
        for file_path, function_name, loc in entries:
            if file_path != current_path:
                if current_path is not None:
                    handle.write("\n")
                handle.write(f"[{file_path}]\n")
                current_path = file_path
            handle.write(f"{function_name}: {loc}\n")

    return output_path, len(entries)


def main():
    for input_name in INPUT_FILES:
        output_path, count = write_output(input_name)
        print(f"Wrote {count} functions to {output_path}")


if __name__ == "__main__":
    main()