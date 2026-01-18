import os
import sys
import matplotlib.pyplot as plt

TOP_N = 100
OUTDIR = "plots"


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

    top = sorted_items[:TOP_N]
    rest = sorted_items[TOP_N:]

    labels = [k for k, _ in top]
    values = [v for _, v in top]

    if rest:
        labels.append("Others")
        values.append(sum(v for _, v in rest))

    plt.figure(figsize=(16, 6))
    plt.bar(labels, values)
    plt.xticks(rotation=90)
    plt.ylabel("Count")
    plt.title(f"Function hitmap – {os.path.basename(filename).replace(".count", "").replace("ext4-session-", "")} (Top {TOP_N} calls)")
    plt.tight_layout()

    out = os.path.join(OUTDIR, f"{os.path.basename(filename)}_hitmap.png")
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
    plt.xticks(rotation=45, ha="right")
    plt.ylim(0, 100)
    plt.tight_layout()

    out = os.path.join(OUTDIR, "non_zero_summary.png")
    plt.savefig(out, dpi=200)
    plt.close()


def main(files):
    os.makedirs(OUTDIR, exist_ok=True)

    non_zero_results = {}

    for file in files:
        data = read_file(file)
        plot_function_counts(file, data)
        non_zero_results[os.path.basename(file).replace(".count", "").replace("ext4-session-", "")] = non_zero_percentage(data)

    plot_non_zero_percentages(non_zero_results)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python hitmaps.py file1.txt file2.txt ...")
        sys.exit(1)

    main(sys.argv[1:])
