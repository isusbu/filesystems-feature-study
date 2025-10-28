#!/usr/bin/env python3
import csv
import re
import sys
from collections import Counter, defaultdict

# Usage: python3 lttng_syscall_stats.py trace.txt
# Analyzes syscall traces from LTTng trace files.
# Produces a summary of syscall counts and argument statistics.
# NOTE: don't modify the traceing results of LTTng, otherwise the parsing may fail.



# regex to match syscall header and to capture all {...} groups on the line
header_re = re.compile(r"syscall_(entry|exit)_([A-Za-z0-9_]+):")
brace_re = re.compile(r"\{([^}]*)\}")
# key=value pairs: capture quoted values or up to the next comma/brace
kv_re = re.compile(r'(\b[\w_]+\b)\s*=\s*("(?:\\.|[^\"])*"|[^,}]+)')



def count_syscalls(trace_file: str) -> tuple[Counter, defaultdict, defaultdict, Counter]:
    """Parse the trace file and count syscalls and their arguments."""
    # data structures
    syscall_counts = Counter()
    syscall_type_counts = defaultdict(lambda: Counter())
    arg_values = defaultdict(lambda: defaultdict(Counter))
    procname_counts = Counter()

    with open(trace_file) as f:
        for line in f:
            h = header_re.search(line)
            if not h:
                continue

            call_type, syscall_name = h.groups()

            # find all {...} blocks on the line and combine them for kv parsing
            braces = [m.group(1) for m in brace_re.finditer(line)]
            if not braces:
                continue

            # check for procname in any brace; if it contains 'lttng' skip this event
            procname = None
            for b in braces:
                mproc = re.search(r'procname\s*=\s*"([^"]+)"', b)
                if mproc:
                    procname = mproc.group(1)
                    break
                mproc2 = re.search(r'procname\s*=\s*([^,\s}]+)', b)
                if mproc2:
                    procname = mproc2.group(1).strip().strip('"')
                    break

            if procname and 'lttng' in procname:
                # drop entities with lttng in procname
                continue
            
            # count procname if found
            if procname:
                procname_counts[procname] += 1

            # count syscall
            syscall_counts[syscall_name] += 1
            syscall_type_counts[syscall_name][call_type] += 1

            # aggregate kvs from all braces
            args_text = ", ".join(braces)
            args = {}
            for kv in kv_re.finditer(args_text):
                key, value = kv.groups()
                v = value.strip()
                if v.startswith('"') and v.endswith('"') and len(v) >= 2:
                    v = v[1:-1]
                args[key.strip()] = v

            # collect argument stats for known flag-like args
            for k, v in args.items():
                if any(x in k for x in ("flag", "op", "mode")):
                    arg_values[syscall_name][k][v] += 1

    return syscall_counts, syscall_type_counts, arg_values, procname_counts

def export_summary_as_csv(syscall_counts: Counter, syscall_type_counts: defaultdict, arg_values: defaultdict, procname_counts: Counter, output_files: list[str]):
    """Export the summary of syscall counts and argument statistics to a CSV file."""
    with open(output_files[0], 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)

        # Write syscall counts
        writer.writerow(["Syscall Name", "Total Count", "Entry Count", "Exit Count"])
        for name, count in syscall_counts.most_common():
            entry = syscall_type_counts[name]["entry"]
            exit_ = syscall_type_counts[name]["exit"]
            writer.writerow([name, count, entry, exit_])

    with open(output_files[1], 'a', newline='') as csvfile:
        writer = csv.writer(csvfile)
        # Write argument value stats
        writer.writerow([])
        writer.writerow(["Syscall Name", "Argument", "Value", "Count"])
        for syscall, argdict in arg_values.items():
            for arg, vals in argdict.items():
                for val, c in vals.most_common():
                    writer.writerow([syscall, arg, val, c])

    with open(output_files[2], 'a', newline='') as csvfile:
        writer = csv.writer(csvfile)
        # Write procname counts
        writer.writerow([])
        writer.writerow(["Process Name", "Count"])
        for pname, count in procname_counts.most_common():
            writer.writerow([pname, count])

def print_summary(syscall_counts: Counter, syscall_type_counts: defaultdict, arg_values: defaultdict, procname_counts: Counter):
    """Print a summary of syscall counts and argument statistics."""
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

    print("\n=== Process Name Counts ===")
    for pname, count in procname_counts.most_common():
        print(f"{pname:25s}  count={count:6d}")

if __name__ == "__main__":
    # check args
    if len(sys.argv) < 2:
        print("Usage: python3 lttng_syscall_stats.py <trace_file>")
        sys.argv.append("trace.txt")  # for testing purposes
        print("No trace file provided, using default: trace.txt")
    
    print("Analyzing syscall traces...")

    # assign the trace file path from the 1st command line argument
    trace_file = sys.argv[1]

    # parse and count syscalls
    syscall_counts, syscall_type_counts, arg_values, procname_counts = count_syscalls(trace_file)

    # export summary as CSV
    output_files = [trace_file + "_syscall_summary.csv", trace_file + "_syscall_args_summary.csv", trace_file + "_procname_summary.csv"]
    export_summary_as_csv(syscall_counts, syscall_type_counts, arg_values, procname_counts, output_files)

    # print the summary
    print_summary(syscall_counts, syscall_type_counts, arg_values, procname_counts)

    print("\nDone.")
