import os
import sys
import argparse

import matplotlib.pyplot as plt
import numpy as np


OUTDIR = "plots"


def collect_count_files(directory, recursive=False):
    matched = []
    if recursive:
        for root, _, files in os.walk(directory):
            for name in files:
                if name.endswith(".count"):
                    matched.append(os.path.join(root, name))
    else:
        for name in os.listdir(directory):
            path = os.path.join(directory, name)
            if os.path.isfile(path) and name.endswith(".count"):
                matched.append(path)
    return sorted(matched)


def read_file(path):
    data = {}
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or ":" not in line:
                continue
            k, v = line.split(":", 1)
            data[k.strip()] = int(v.strip())
    return data


def plot_function_counts(filename, data):
    sorted_items = sorted(data.items(), key=lambda x: x[1], reverse=True)
    values = [v for _, v in sorted_items]

    plt.figure(figsize=(8, 5))
    plt.hist(values, bins=50, log=True)
    plt.xlabel("Function call count")
    plt.ylabel("Number of functions (log scale)")
    plt.title("Log distribution of function call counts")
    plt.tight_layout()

    out = os.path.join(OUTDIR, f"{os.path.basename(filename)}_distribution_log.png")
    plt.savefig(out, dpi=200)
    plt.close()

def plot_count_cdf(filename, data):
    values = np.array(sorted(data.values()))
    cdf = np.cumsum(values) / np.sum(values)

    plt.figure(figsize=(8, 5))
    plt.plot(values, cdf)
    plt.xlabel("Function call count")
    plt.ylabel("Cumulative fraction of total calls")
    plt.title("CDF of function call counts")
    plt.grid(True)
    plt.tight_layout()

    out = os.path.join(OUTDIR, f"{os.path.basename(filename)}_cdf.png")
    plt.savefig(out, dpi=200)
    plt.close()

def plot_count_cdf_all(cdf_data):
    # cdf_data: dict[name] = list_of_values
    plt.figure(figsize=(8, 5))

    for name, values in cdf_data.items():
        values = np.array(sorted(values))
        cdf = np.cumsum(values) / np.sum(values)
        plt.plot(values, cdf, label=name)

    plt.xlabel("Function call count")
    plt.ylabel("Cumulative fraction of total calls")
    plt.title("CDF of function call counts")
    plt.grid(True)
    plt.legend()
    plt.tight_layout()

    out = os.path.join(OUTDIR, "all_files_cdf.png")
    plt.savefig(out, dpi=200)
    plt.close()

def non_zero_percentage(data):
    if not data:
        return 0.0
    non_zero = sum(1 for v in data.values() if v != 0)
    return 100.0 * non_zero / len(data)


def plot_non_zero_percentages(results):
    names = list(results.keys())
    values = list(results.values())

    plt.figure(figsize=(10, 5))
    plt.bar(names, values)
    plt.ylabel("coverage percentage (%)")
    plt.title("Ext4 file system function coverage per workload")
    plt.xticks(rotation=90, ha="right")
    plt.ylim(0, 100)
    plt.tight_layout()

    out = os.path.join(OUTDIR, "non_zero_summary.png")
    plt.savefig(out, dpi=200)
    plt.close()


def main(files):
    os.makedirs(OUTDIR, exist_ok=True)

    non_zero_results = {}
    cdf_data = {}

    for file in files:
        data = read_file(file)

        # Preserve per-file distribution plots
        plot_function_counts(file, data)

        # Name used consistently for legends and bar plot
        name = os.path.basename(file).replace(".count", "").replace("ext4-session-", "")

        # Store raw values for joint CDF plot
        cdf_data[name] = list(data.values())

        # Collect non-zero coverage percentages
        non_zero_results[name] = non_zero_percentage(data)

    # New single CDF plot for all workloads
    plot_count_cdf_all(cdf_data)

    # Existing bar chart summary
    plot_non_zero_percentages(non_zero_results)



if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate function-count plots from .count files."
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="One or more .count files to plot.",
    )
    parser.add_argument(
        "-d",
        "--dir",
        dest="directory",
        help="Directory containing .count files to include.",
    )
    parser.add_argument(
        "-r",
        "--recursive",
        action="store_true",
        help="Recursively scan --dir for .count files.",
    )

    args = parser.parse_args()

    files = list(args.files)
    if args.directory:
        if not os.path.isdir(args.directory):
            print(f"Error: directory not found: {args.directory}")
            sys.exit(1)
        files.extend(collect_count_files(args.directory, recursive=args.recursive))

    # Deduplicate while preserving order.
    files = list(dict.fromkeys(files))

    if not files:
        print("Usage: python hitmaps.py [file1.count ...] [--dir DIR] [--recursive]")
        sys.exit(1)

    main(files)
