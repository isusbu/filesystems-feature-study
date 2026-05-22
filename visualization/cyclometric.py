from __future__ import annotations

import argparse
import csv
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
import sys

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATASET_ROOT = ROOT / "dataset" / "cyclometric"
OUTDIR = "plots"
FILESYSTEMS = ["ext4", "f2fs", "nfs"]
METRIC_ORDER = ["MCC Reduction", "NLOC Savings"]


@dataclass(frozen=True)
class CyclometricSample:
    filesystem: str
    analysis: str
    mcc_active: int
    mcc_dead: int
    mcc_dead_pct: float
    nloc_active: int
    nloc_dead: int
    nloc_dead_pct: float


@dataclass(frozen=True)
class CyclometricSummary:
    filesystem: str
    samples: int
    mcc_before: float
    mcc_after: float
    mcc_reduction_pct: float
    nloc_before: float
    nloc_after: float
    nloc_reduction_pct: float


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


def parse_percent(value: str) -> float:
    return float(value.strip().rstrip("%"))


def parse_cyclometric_file(path: Path) -> list[CyclometricSample]:
    samples: list[CyclometricSample] = []
    lines = path.read_text(encoding="utf-8").splitlines()

    analysis_pattern = re.compile(r"^\s*ANALYSIS:\s*(.+?)\s*$")
    mcc_active_pattern = re.compile(r"^\s*MCC active\s*:\s*(\d+)\s*$")
    mcc_dead_pattern = re.compile(r"^\s*MCC dead\s*:\s*(\d+)\s*$")
    mcc_dead_pct_pattern = re.compile(r"^\s*MCC dead %\s*:\s*([\d.]+)%\s*$")
    nloc_active_pattern = re.compile(r"^\s*NLOC active\s*:\s*(\d+)\s*$")
    nloc_dead_pattern = re.compile(r"^\s*NLOC dead\s*:\s*(\d+)\s*$")
    nloc_dead_pct_pattern = re.compile(r"^\s*NLOC dead %\s*:\s*([\d.]+)%\s*$")

    current_analysis = None
    current_metrics: dict[str, str] = {}

    def flush() -> None:
        nonlocal current_analysis, current_metrics
        if not current_analysis:
            return
        filesystem = path.stem.replace("_results", "")
        required = [
            "mcc_active",
            "mcc_dead",
            "mcc_dead_pct",
            "nloc_active",
            "nloc_dead",
            "nloc_dead_pct",
        ]
        if not all(key in current_metrics for key in required):
            current_analysis = None
            current_metrics = {}
            return
        samples.append(
            CyclometricSample(
                filesystem=filesystem,
                analysis=current_analysis,
                mcc_active=int(current_metrics["mcc_active"]),
                mcc_dead=int(current_metrics["mcc_dead"]),
                mcc_dead_pct=float(current_metrics["mcc_dead_pct"]),
                nloc_active=int(current_metrics["nloc_active"]),
                nloc_dead=int(current_metrics["nloc_dead"]),
                nloc_dead_pct=float(current_metrics["nloc_dead_pct"]),
            )
        )
        current_analysis = None
        current_metrics = {}

    for line in lines:
        analysis_match = analysis_pattern.match(line)
        if analysis_match:
            flush()
            current_analysis = analysis_match.group(1).strip()
            continue

        if current_analysis is None:
            continue

        match = mcc_active_pattern.match(line)
        if match:
            current_metrics["mcc_active"] = match.group(1)
            continue
        match = mcc_dead_pattern.match(line)
        if match:
            current_metrics["mcc_dead"] = match.group(1)
            continue
        match = mcc_dead_pct_pattern.match(line)
        if match:
            current_metrics["mcc_dead_pct"] = match.group(1)
            continue
        match = nloc_active_pattern.match(line)
        if match:
            current_metrics["nloc_active"] = match.group(1)
            continue
        match = nloc_dead_pattern.match(line)
        if match:
            current_metrics["nloc_dead"] = match.group(1)
            continue
        match = nloc_dead_pct_pattern.match(line)
        if match:
            current_metrics["nloc_dead_pct"] = match.group(1)
            continue

    flush()
    return samples


def collect_samples(dataset_root: Path) -> list[CyclometricSample]:
    samples: list[CyclometricSample] = []
    for filesystem in FILESYSTEMS:
        path = dataset_root / f"{filesystem}_results.txt"
        if not path.exists():
            continue
        samples.extend(parse_cyclometric_file(path))
    return samples


def summarize_samples(samples: list[CyclometricSample]) -> list[CyclometricSummary]:
    grouped: dict[str, list[CyclometricSample]] = defaultdict(list)
    for sample in samples:
        grouped[sample.filesystem].append(sample)

    summaries: list[CyclometricSummary] = []
    for filesystem in FILESYSTEMS:
        items = grouped.get(filesystem, [])
        if not items:
            continue
        mcc_before = float(np.mean([item.mcc_active + item.mcc_dead for item in items]))
        mcc_after = float(np.mean([item.mcc_active for item in items]))
        nloc_before = float(np.mean([item.nloc_active + item.nloc_dead for item in items]))
        nloc_after = float(np.mean([item.nloc_active for item in items]))
        mcc_reduction_pct = 100.0 * (mcc_before - mcc_after) / mcc_before if mcc_before else 0.0
        nloc_reduction_pct = 100.0 * (nloc_before - nloc_after) / nloc_before if nloc_before else 0.0
        summaries.append(
            CyclometricSummary(
                filesystem=filesystem,
                samples=len(items),
                mcc_before=mcc_before,
                mcc_after=mcc_after,
                mcc_reduction_pct=mcc_reduction_pct,
                nloc_before=nloc_before,
                nloc_after=nloc_after,
                nloc_reduction_pct=nloc_reduction_pct,
            )
        )
    return summaries


def write_summary(outdir: Path, samples: list[CyclometricSample]) -> Path:
    outdir.mkdir(parents=True, exist_ok=True)
    csv_path = outdir / "cyclometric_summary.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "filesystem",
                "analysis",
                "mcc_active",
                "mcc_dead",
                "mcc_dead_pct",
                "mcc_before",
                "mcc_after",
                "mcc_reduction_pct",
                "nloc_active",
                "nloc_dead",
                "nloc_dead_pct",
                "nloc_before",
                "nloc_after",
                "nloc_reduction_pct",
            ]
        )
        for sample in samples:
            mcc_before = sample.mcc_active + sample.mcc_dead
            nloc_before = sample.nloc_active + sample.nloc_dead
            writer.writerow(
                [
                    sample.filesystem,
                    sample.analysis,
                    sample.mcc_active,
                    sample.mcc_dead,
                    f"{sample.mcc_dead_pct:.2f}",
                    mcc_before,
                    sample.mcc_active,
                    f"{100.0 * sample.mcc_dead / mcc_before:.2f}",
                    sample.nloc_active,
                    sample.nloc_dead,
                    f"{sample.nloc_dead_pct:.2f}",
                    nloc_before,
                    sample.nloc_active,
                    f"{100.0 * sample.nloc_dead / nloc_before:.2f}",
                ]
            )
    return csv_path


def plot_cyclometric(samples: list[CyclometricSample], outdir: Path) -> None:
    outdir.mkdir(parents=True, exist_ok=True)
    summaries = summarize_samples(samples)
    # Single-panel MCC-only plot with minimal styling
    fig, ax = plt.subplots(1, 1, figsize=(7.0, 4.3), constrained_layout=True)

    colors = {"before": "#2f3b52", "after": "#c96f4a"}
    x = np.arange(len(FILESYSTEMS), dtype=float)

    # MCC values
    before = [summary.mcc_before for summary in summaries]
    after = [summary.mcc_after for summary in summaries]
    reductions = [summary.mcc_reduction_pct for summary in summaries]

    before_mean = [float(np.mean(before[i::len(FILESYSTEMS)])) if before else 0.0 for i in range(len(FILESYSTEMS))]
    after_mean = [float(np.mean(after[i::len(FILESYSTEMS)])) if after else 0.0 for i in range(len(FILESYSTEMS))]
    reduction_mean = [float(np.mean(reductions[i::len(FILESYSTEMS)])) if reductions else 0.0 for i in range(len(FILESYSTEMS))]

    width = 0.28
    before_bars = ax.bar(x - width / 2, before_mean, width=width, color=colors["before"], label="Before Debloating", edgecolor="white", linewidth=0.6)
    after_bars = ax.bar(x + width / 2, after_mean, width=width, color=colors["after"], label="After Debloating", edgecolor="white", linewidth=0.6)

    for idx in range(len(FILESYSTEMS)):
        before_value = before_mean[idx]
        after_value = after_mean[idx]
        reduction_value = reduction_mean[idx]
        ax.annotate(
            f"{reduction_value:.1f}% smaller",
            (x[idx], max(before_value, after_value)),
            xytext=(0, 12),
            textcoords="offset points",
            ha="center",
            va="bottom",
            fontsize=10,
            color="#444444",
        )

    for bar in list(before_bars) + list(after_bars):
        height = bar.get_height()
        ax.annotate(
            f"{height:,.0f}",
            (bar.get_x() + bar.get_width() / 2.0, height),
            xytext=(0, 2),
            textcoords="offset points",
            ha="center",
            va="bottom",
            fontsize=9,
            color="#444444",
        )

    ax.set_xticks(x)
    ax.set_xticklabels([filesystem.upper() for filesystem in FILESYSTEMS])
    ax.set_xlabel("File System\n(McCabe’s Cyclomatic Complexity (MCC) before vs after debloating)")
    ax.set_ylabel("MCC Complexity Units")
    ax.legend(frameon=False, ncol=2, loc="upper center", bbox_to_anchor=(0.5, 1.08))

    # Enforce minimal styling: remove top/right spines and disable horizontal grid lines
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.grid(False, axis="y")
    ax.grid(False, axis="x")

    fig.savefig(outdir / "cyclometric_improvements.png", dpi=300, bbox_inches="tight")
    fig.savefig(outdir / "cyclometric_improvements.pdf", bbox_inches="tight")
    plt.close(fig)


def main() -> int:
    configure_style()

    parser = argparse.ArgumentParser(description="Plot cyclometric MCC and NLOC improvements.")
    parser.add_argument(
        "-d",
        "--dataset-root",
        default=str(DEFAULT_DATASET_ROOT),
        help="Directory containing ext4_results.txt, f2fs_results.txt, and nfs_results.txt.",
    )
    parser.add_argument(
        "-o",
        "--outdir",
        default=OUTDIR,
        help=f"Output directory for plots and summaries (default: {OUTDIR}).",
    )
    args = parser.parse_args()

    dataset_root = Path(args.dataset_root)
    outdir = Path(args.outdir)

    if not dataset_root.exists():
        print(f"Error: dataset root not found: {dataset_root}")
        return 1

    samples = collect_samples(dataset_root)
    if not samples:
        print(f"Error: no cyclometric samples found in {dataset_root}")
        return 1

    write_summary(outdir, samples)
    plot_cyclometric(samples, outdir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
