from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
import sys

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import PercentFormatter


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATASET_ROOT = ROOT / "dataset" / "lttng" / "function-coverage-counts"
DEFAULT_LLVM_ROOT = ROOT / "dataset" / "llvm"
OUTDIR = "plots"
FILESYSTEMS = ["ext4", "f2fs", "nfs"]
STORAGE_APPS = ["sqlite", "redis", "aistore"]
MACRO_APPS = ["fio", "dbench", "filebench", "mlperf"]
XFSTEST_TYPES = ["specific", "generic"]
DEFAULT_BYTES_PER_LOC = 32


@dataclass(frozen=True)
class CoverageSummary:
    filesystem: str
    label: str
    merged_files: int
    total_functions: int
    used_functions: int
    removed_functions: int
    total_loc: int
    removed_loc: int
    removed_bytes: int
    total_bytes: int
    remaining_bytes: int

    @property
    def coverage_pct(self) -> float:
        if not self.total_functions:
            return 0.0
        return 100.0 * self.used_functions / self.total_functions

    @property
    def removed_loc_pct(self) -> float:
        if not self.total_loc:
            return 0.0
        return 100.0 * self.removed_loc / self.total_loc

    @property
    def removed_bytes_pct(self) -> float:
        if not self.total_bytes:
            return 0.0
        return 100.0 * self.removed_bytes / self.total_bytes

    @property
    def times_smaller(self) -> float:
        if self.remaining_bytes <= 0:
            return float("inf")
        return self.total_bytes / self.remaining_bytes


def configure_style() -> None:
    mpl.rcParams.update(
        {
            "font.family": "serif",
            "font.serif": ["Times New Roman", "Times", "DejaVu Serif"],
            "font.size": 12,
            "axes.titlesize": 13,
            "axes.labelsize": 12,
            "legend.fontsize": 10,
            "xtick.labelsize": 10,
            "ytick.labelsize": 10,
            "figure.facecolor": "white",
            "axes.facecolor": "white",
            "axes.spines.top": False,
            "axes.spines.right": False,
            "axes.grid": True,
            "grid.color": "0.90",
            "grid.linewidth": 0.8,
            "grid.alpha": 1.0,
            "grid.linestyle": "-",
            "axes.axisbelow": True,
        }
    )


def collect_count_files(directory: Path) -> list[Path]:
    if not directory.exists():
        return []
    return sorted(path for path in directory.rglob("*.count") if path.is_file())


def read_count_file(path: Path) -> dict[str, int]:
    data: dict[str, int] = defaultdict(int)
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or ":" not in line:
                continue
            name, value = line.split(":", 1)
            try:
                data[name.strip()] += int(value.strip())
            except ValueError:
                continue
    return dict(data)


def merge_count_files(paths: list[Path]) -> dict[str, int]:
    merged: dict[str, int] = defaultdict(int)
    for path in paths:
        for name, value in read_count_file(path).items():
            merged[name] += value
    return dict(merged)


def read_loc_map(path: Path) -> dict[str, int]:
    loc_map: dict[str, int] = {}
    if not path.exists():
        return loc_map

    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("[") or ":" not in line:
                continue
            name, value = line.split(":", 1)
            try:
                loc = int(value.strip())
            except ValueError:
                continue
            function_name = name.strip()
            if function_name in loc_map:
                loc_map[function_name] = max(loc_map[function_name], loc)
            else:
                loc_map[function_name] = loc
    return loc_map


def summarize_counts(
    filesystem: str,
    label: str,
    counts: dict[str, int],
    loc_map: dict[str, int],
    merged_files: int,
    bytes_per_loc: int,
) -> CoverageSummary:
    total_functions = len(loc_map)
    used_functions = sum(1 for function in loc_map if counts.get(function, 0) > 0)
    removed_functions = total_functions - used_functions
    total_loc = sum(loc_map.values())
    removed_loc = sum(loc for function, loc in loc_map.items() if counts.get(function, 0) == 0)
    removed_bytes = removed_loc * bytes_per_loc
    total_bytes = total_loc * bytes_per_loc
    remaining_bytes = total_bytes - removed_bytes
    return CoverageSummary(
        filesystem=filesystem,
        label=label,
        merged_files=merged_files,
        total_functions=total_functions,
        used_functions=used_functions,
        removed_functions=removed_functions,
        total_loc=total_loc,
        removed_loc=removed_loc,
        removed_bytes=removed_bytes,
        total_bytes=total_bytes,
        remaining_bytes=remaining_bytes,
    )


def filesystem_dir_for_workload(dataset_root: Path, workload: str, filesystem: str) -> Path:
    if workload in {"fio", "mlperf"}:
        return dataset_root / workload / f"{filesystem}-counts"
    return dataset_root / workload / filesystem


def xfstests_dir_for(dataset_root: Path, filesystem: str, variant: str) -> Path:
    if variant == "specific":
        return dataset_root / "xfstests" / f"{filesystem}_{filesystem}_counts"
    return dataset_root / "xfstests" / f"{filesystem}_generic_counts"


def merge_suite_summary(
    dataset_root: Path,
    llvm_root: Path,
    workload: str,
    filesystem: str,
    bytes_per_loc: int,
    xfstests_variant: str | None = None,
) -> CoverageSummary:
    if workload == "xfstests":
        if xfstests_variant is None:
            raise ValueError("xfstests_variant is required for xfstests workloads")
        data_dir = xfstests_dir_for(dataset_root, filesystem, xfstests_variant)
        label = xfstests_variant
    else:
        data_dir = filesystem_dir_for_workload(dataset_root, workload, filesystem)
        label = workload

    count_files = collect_count_files(data_dir)
    merged = merge_count_files(count_files)
    loc_map = read_loc_map(llvm_root / f"{filesystem}_c_functions_loc.txt")
    return summarize_counts(
        filesystem=filesystem,
        label=label,
        counts=merged,
        loc_map=loc_map,
        merged_files=len(count_files),
        bytes_per_loc=bytes_per_loc,
    )


def build_suite_matrix(
    dataset_root: Path,
    llvm_root: Path,
    workloads: list[str],
    bytes_per_loc: int,
) -> dict[str, dict[str, CoverageSummary]]:
    matrix: dict[str, dict[str, CoverageSummary]] = {}
    for workload in workloads:
        matrix[workload] = {}
        for filesystem in FILESYSTEMS:
            matrix[workload][filesystem] = merge_suite_summary(
                dataset_root=dataset_root,
                llvm_root=llvm_root,
                workload=workload,
                filesystem=filesystem,
                bytes_per_loc=bytes_per_loc,
            )
    return matrix


def build_xfstests_matrix(
    dataset_root: Path,
    llvm_root: Path,
    bytes_per_loc: int,
) -> dict[str, dict[str, CoverageSummary]]:
    matrix: dict[str, dict[str, CoverageSummary]] = {variant: {} for variant in XFSTEST_TYPES}
    for filesystem in FILESYSTEMS:
        for variant in XFSTEST_TYPES:
            matrix[variant][filesystem] = merge_suite_summary(
                dataset_root=dataset_root,
                llvm_root=llvm_root,
                workload="xfstests",
                filesystem=filesystem,
                bytes_per_loc=bytes_per_loc,
                xfstests_variant=variant,
            )
    return matrix


def aggregate_by_filesystem(matrix: dict[str, dict[str, CoverageSummary]]) -> dict[str, CoverageSummary]:
    aggregated: dict[str, CoverageSummary] = {}
    for filesystem in FILESYSTEMS:
        summaries = [per_fs[filesystem] for per_fs in matrix.values() if filesystem in per_fs]
        if not summaries:
            continue
        total_functions = sum(summary.total_functions for summary in summaries)
        used_functions = sum(summary.used_functions for summary in summaries)
        removed_functions = sum(summary.removed_functions for summary in summaries)
        total_loc = sum(summary.total_loc for summary in summaries)
        removed_loc = sum(summary.removed_loc for summary in summaries)
        removed_bytes = sum(summary.removed_bytes for summary in summaries)
        total_bytes = sum(summary.total_bytes for summary in summaries)
        remaining_bytes = sum(summary.remaining_bytes for summary in summaries)
        aggregated[filesystem] = CoverageSummary(
            filesystem=filesystem,
            label="aggregate",
            merged_files=sum(summary.merged_files for summary in summaries),
            total_functions=total_functions,
            used_functions=used_functions,
            removed_functions=removed_functions,
            total_loc=total_loc,
            removed_loc=removed_loc,
            removed_bytes=removed_bytes,
            total_bytes=total_bytes,
            remaining_bytes=remaining_bytes,
        )
    return aggregated


def make_series_map(matrix: dict[str, dict[str, CoverageSummary]], metric: str) -> dict[str, list[float]]:
    series_map: dict[str, list[float]] = {}
    for label, per_fs in matrix.items():
        series_map[label] = [getattr(per_fs[filesystem], metric) for filesystem in FILESYSTEMS]
    return series_map


def prettify_label(label: str) -> str:
    mapping = {
        "sqlite": "SQLite",
        "redis": "Redis",
        "aistore": "NVIDIA AI Store",
        "fio": "FIO",
        "dbench": "DBench",
        "filebench": "Filebench",
        "mlperf": "MLPerf Storage",
        "specific": "File system specific tests",
        "generic": "Generic tests",
    }
    return mapping.get(label, label)


def draw_grouped_bar_subplot(
    ax: plt.Axes,
    x_labels: list[str],
    series_map: dict[str, list[float]],
    ylabel: str,
    xlabel: str,
    ylim: tuple[float, float] | None = None,
    percent_axis: bool = False,
    legend_ncol: int | None = None,
) -> None:
    series_names = list(series_map)
    x = np.arange(len(x_labels), dtype=float)
    bar_width = 0.82 / max(len(series_names), 1)
    offsets = (np.arange(len(series_names), dtype=float) - (len(series_names) - 1) / 2.0) * bar_width
    palette = ["#2f3b52", "#6b7a8f", "#c96f4a", "#7b9e89", "#9b8abf"]

    for index, series_name in enumerate(series_names):
        values = series_map[series_name]
        bars = ax.bar(
            x + offsets[index],
            values,
            width=bar_width,
            color=palette[index % len(palette)],
            label=prettify_label(series_name),
            edgecolor="white",
            linewidth=0.6,
        )

        for bar in bars:
            height = bar.get_height()
            if height <= 0:
                continue
            label = f"{height:.1f}" if percent_axis else f"{int(height):,}"
            ax.annotate(
                label,
                (bar.get_x() + bar.get_width() / 2.0, height),
                xytext=(0, 2),
                textcoords="offset points",
                ha="center",
                va="bottom",
                fontsize=10,
                color="#444444",
                rotation=90 if not percent_axis and height > 10000 else 0,
            )

    ax.set_ylabel(ylabel)
    ax.set_xlabel(xlabel)
    ax.set_xticks(x)
    ax.set_xticklabels([filesystem.upper() for filesystem in x_labels])
    ax.tick_params(axis="x", length=0)
    if percent_axis:
        ax.yaxis.set_major_formatter(PercentFormatter(xmax=100))
        if ylim is None:
            ylim = (0, 100)
    if ylim is not None:
        ax.set_ylim(*ylim)
    if legend_ncol is None:
        legend_ncol = min(len(series_names), 4)
    ax.legend(frameon=False, ncol=legend_ncol, loc="upper center", bbox_to_anchor=(0.5, 1.16))


def save_figure(fig: plt.Figure, outdir: Path, stem: str) -> None:
    outdir.mkdir(parents=True, exist_ok=True)
    fig.savefig(outdir / f"{stem}.png", dpi=300, bbox_inches="tight")
    fig.savefig(outdir / f"{stem}.pdf", bbox_inches="tight")
    plt.close(fig)


def write_summary_reports(
    outdir: Path,
    title: str,
    matrix: dict[str, dict[str, CoverageSummary]],
) -> None:
    outdir.mkdir(parents=True, exist_ok=True)
    txt_path = outdir / f"{title}.txt"
    csv_path = outdir / f"{title}.csv"

    with txt_path.open("w", encoding="utf-8") as handle:
        handle.write(f"[{title}]\n")
        for label, per_fs in matrix.items():
            handle.write(f"  [{label}]\n")
            for filesystem in FILESYSTEMS:
                summary = per_fs[filesystem]
                handle.write(
                    f"    {filesystem:<8} {summary.used_functions:>4}/{summary.total_functions:<4} "
                    f"non-zero  ({summary.coverage_pct:6.2f}%)  "
                    f"[{summary.merged_files} files merged]  "
                    f"loc_removed={summary.removed_loc}  bytes_removed={summary.removed_bytes}  "
                    f"bytes_reduction={summary.removed_bytes_pct:6.2f}%\n"
                )

    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "suite",
                "label",
                "filesystem",
                "merged_files",
                "used_functions",
                "total_functions",
                "coverage_pct",
                "removed_functions",
                "removed_loc",
                "removed_loc_pct",
                "removed_bytes",
                "total_bytes",
                "remaining_bytes",
                "removed_bytes_pct",
                "times_smaller",
            ]
        )
        for label, per_fs in matrix.items():
            for filesystem, summary in per_fs.items():
                writer.writerow(
                    [
                        title,
                        label,
                        filesystem,
                        summary.merged_files,
                        summary.used_functions,
                        summary.total_functions,
                        f"{summary.coverage_pct:.4f}",
                        summary.removed_functions,
                        summary.removed_loc,
                        f"{summary.removed_loc_pct:.4f}",
                        summary.removed_bytes,
                        summary.total_bytes,
                        summary.remaining_bytes,
                        f"{summary.removed_bytes_pct:.4f}",
                        f"{summary.times_smaller:.4f}" if np.isfinite(summary.times_smaller) else "inf",
                    ]
                )


def plot_single_suite_coverage(
    outdir: Path,
    ylabel: str,
    xlabel: str,
    matrix: dict[str, dict[str, CoverageSummary]],
    stem: str,
) -> None:
    fig, ax = plt.subplots(figsize=(7.2, 3.9), constrained_layout=True)
    series_map = make_series_map(matrix, "coverage_pct")
    draw_grouped_bar_subplot(
        ax,
        FILESYSTEMS,
        series_map,
        ylabel=ylabel,
        xlabel=xlabel,
        ylim=(0, 100),
        percent_axis=True,
        legend_ncol=len(series_map),
    )
    save_figure(fig, outdir, stem)


def plot_single_suite_removed_loc(
    outdir: Path,
    ylabel: str,
    xlabel: str,
    matrix: dict[str, dict[str, CoverageSummary]],
    stem: str,
) -> None:
    fig, ax = plt.subplots(figsize=(7.2, 3.9), constrained_layout=True)
    series_map = make_series_map(matrix, "removed_loc")
    draw_grouped_bar_subplot(
        ax,
        FILESYSTEMS,
        series_map,
        ylabel=ylabel,
        xlabel=xlabel,
        percent_axis=False,
    )
    save_figure(fig, outdir, stem)


def plot_single_panel_bytes_reduction(
    outdir: Path,
    matrices: dict[str, dict[str, dict[str, CoverageSummary]]],
    stem: str,
) -> None:
    fig, ax = plt.subplots(figsize=(7.6, 4.1), constrained_layout=True)
    aggregated = {label: aggregate_by_filesystem(matrix) for label, matrix in matrices.items()}
    series_map = {
        label: [per_fs[filesystem].removed_bytes_pct for filesystem in FILESYSTEMS]
        for label, per_fs in aggregated.items()
    }
    x = np.arange(len(FILESYSTEMS), dtype=float)
    series_names = list(series_map)
    bar_width = 0.82 / max(len(series_names), 1)
    offsets = (np.arange(len(series_names), dtype=float) - (len(series_names) - 1) / 2.0) * bar_width
    palette = ["#2f3b52", "#6b7a8f", "#c96f4a", "#7b9e89", "#9b8abf"]

    for index, series_name in enumerate(series_names):
        values = series_map[series_name]
        bars = ax.bar(
            x + offsets[index],
            values,
            width=bar_width,
            color=palette[index % len(palette)],
            label=prettify_label(series_name),
            edgecolor="white",
            linewidth=0.6,
        )
        for filesystem, bar in zip(FILESYSTEMS, bars, strict=True):
            summary = aggregated[series_name][filesystem]
            text = f"{summary.times_smaller:.1f}x smaller" if np.isfinite(summary.times_smaller) else "inf"
            ax.annotate(
                text,
                (bar.get_x() + bar.get_width() / 2.0, bar.get_height()),
                xytext=(0, 2),
                textcoords="offset points",
                ha="center",
                va="bottom",
                fontsize=10,
                color="#444444",
                rotation=90,
            )

    ax.set_ylabel("Binary Bytes Potential Reduced (%)")
    ax.set_xlabel("File System\n(bars show percentage of bytes that could be removed by eliminating zero-coverage functions;\ntext shows how many times smaller the binary would be after removal)")
    ax.set_xticks(x)
    ax.set_xticklabels([filesystem.upper() for filesystem in FILESYSTEMS])
    ax.yaxis.set_major_formatter(PercentFormatter(xmax=100))
    ax.set_ylim(0, 100)
    ax.legend(frameon=False, ncol=3, loc="upper center", bbox_to_anchor=(0.5, 1.16))
    save_figure(fig, outdir, stem)


def build_all_figures(dataset_root: Path, llvm_root: Path, outdir: Path, bytes_per_loc: int) -> None:
    storage_matrix = build_suite_matrix(dataset_root, llvm_root, STORAGE_APPS, bytes_per_loc)
    macro_matrix = build_suite_matrix(dataset_root, llvm_root, MACRO_APPS, bytes_per_loc)
    xfstests_matrix = build_xfstests_matrix(dataset_root, llvm_root, bytes_per_loc)

    write_summary_reports(outdir, "storage_apps_coverage", storage_matrix)
    write_summary_reports(outdir, "macrobench_coverage", macro_matrix)
    write_summary_reports(outdir, "xfstests_coverage", xfstests_matrix)

    plot_single_suite_coverage(
        outdir,
        "Triggered FS Functions (%)",
        "File System\n(bars show percentage of covered functions for each storage application)",
        storage_matrix,
        "storage_apps_coverage",
    )
    plot_single_suite_coverage(
        outdir,
        "Triggered FS Functions (%)",
        "File System\n(bars show percentage of covered functions for each xfstests type)",
        xfstests_matrix,
        "xfstests_coverage",
    )
    plot_single_suite_coverage(
        outdir,
        "Triggered FS Functions (%)",
        "File System\n(bars show percentage of covered functions for each macro benchmark)",
        macro_matrix,
        "macrobench_coverage",
    )

    plot_single_suite_removed_loc(
        outdir,
        "Potential Lines of Code to be Removed",
        "File System\n(bars show removable lines of code from zero-coverage functions for each storage application)",
        storage_matrix,
        "removed_loc_storage",
    )
    plot_single_suite_removed_loc(
        outdir,
        "Potential Lines of Code to be Removed",
        "File System\n(bars show removable lines of code from zero-coverage functions for each xfstests type)",
        xfstests_matrix,
        "removed_loc_xfstests",
    )
    plot_single_suite_removed_loc(
        outdir,
        "Potential Lines of Code to be Removed",
        "File System\n(bars show removable lines of code from zero-coverage functions for each macro benchmark)",
        macro_matrix,
        "removed_loc_macro",
    )
    plot_single_panel_bytes_reduction(
        outdir,
        {
            "Storage App.": storage_matrix,
            "XFSTests": xfstests_matrix,
            "Macro Bench.": macro_matrix,
        },
        "removed_bytes",
    )


def main() -> int:
    configure_style()

    parser = argparse.ArgumentParser(description="Generate paper-style coverage plots from LTTng count files.")
    parser.add_argument(
        "-o",
        "--outdir",
        default=OUTDIR,
        help=f"Output directory for plots and summaries (default: {OUTDIR}).",
    )
    parser.add_argument(
        "--dataset-root",
        default=str(DEFAULT_DATASET_ROOT),
        help="Root directory for dataset/lttng/function-coverage-counts.",
    )
    parser.add_argument(
        "--llvm-root",
        default=str(DEFAULT_LLVM_ROOT),
        help="Root directory containing the llvm function LOC maps.",
    )
    parser.add_argument(
        "--bytes-per-loc",
        type=int,
        default=DEFAULT_BYTES_PER_LOC,
        help="Heuristic conversion factor from LOC to bytes for the removal-size plot.",
    )
    args = parser.parse_args()

    dataset_root = Path(args.dataset_root)
    llvm_root = Path(args.llvm_root)
    outdir = Path(args.outdir)

    if not dataset_root.exists():
        print(f"Error: dataset root not found: {dataset_root}")
        return 1
    if not llvm_root.exists():
        print(f"Error: llvm root not found: {llvm_root}")
        return 1

    build_all_figures(dataset_root, llvm_root, outdir, args.bytes_per_loc)
    return 0


if __name__ == "__main__":
    sys.exit(main())
