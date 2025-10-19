#!/usr/bin/env python3
import re
import sys
from collections import Counter, defaultdict

# Usage: python3 lttng_syscall_stats.py trace.txt

if len(sys.argv) < 2:
    print("Usage: python3 lttng_syscall_stats.py <trace_file>")
    sys.exit(1)

trace_file = sys.argv[1]

# Regex to match syscall events
line_re = re.compile(
    r"syscall_(entry|exit)_([a-zA-Z0-9_]+):.*?\{(.*)\}"
)

# Data structures
syscall_counts = Counter()
syscall_type_counts = defaultdict(lambda: Counter())
arg_values = defaultdict(lambda: defaultdict(Counter))

with open(trace_file) as f:
    for line in f:
        m = line_re.search(line)
        if not m:
            continue

        call_type, syscall_name, args_str = m.groups()
        syscall_counts[syscall_name] += 1
        syscall_type_counts[syscall_name][call_type] += 1

        # Parse args key=value pairs inside { ... }
        args = {}
        for kv in re.finditer(r"(\w+)\s*=\s*([^,}]+)", args_str):
            key, value = kv.groups()
            args[key.strip()] = value.strip()

        # Collect argument stats for known flag-like args
        for k, v in args.items():
            if any(x in k for x in ("flag", "op", "mode")):
                arg_values[syscall_name][k][v] += 1

# --- Print summary ---
print("\n=== Syscall Counts ===")
for name, count in syscall_counts.most_common():
    entry = syscall_type_counts[name]["entry"]
    exit_ = syscall_type_counts[name]["exit"]
    print(f"{name:25s} total={count:6d}  entry={entry:6d}  exit={exit_:6d}")

print("\n=== Argument Value Stats (flags, ops, modes) ===")
for syscall, argdict in arg_values.items():
    print(f"\n{syscall}:")
    for arg, vals in argdict.items():
        print(f"  {arg}:")
        for val, c in vals.most_common():
            print(f"    {val:15s} -> {c}")

print("\nDone.")
