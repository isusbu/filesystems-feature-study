#!/usr/bin/env python3
"""lttng_csv_plot.py

Read CSV outputs from `lttng_syscall_stats.py` and produce SVG plots using plotly.

Features:
- Auto-detects the two CSV outputs: *_syscall_summary.csv and *_syscall_args_summary.csv
- Produces:
  - Top-N syscalls by total count (bar chart)
  - Entry vs Exit counts (grouped bar)
  - Argument value distributions per syscall (one SVG per syscall or for a selected syscall)

Usage:
  python3 lttng_csv_plot.py --input /path/to/trace_syscall_summary.csv --outdir ./plots
  python3 lttng_csv_plot.py --input /path/to/dir-containing-csvs --top 30

Dependencies (put in requirements.txt): pandas, plotly, kaleido
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys
from typing import Optional, List

import pandas as pd
import plotly.express as px
import plotly.io as pio


def find_csv_files(input_path: Path) -> tuple[Optional[Path], Optional[Path]]:
    """Find summary and args CSV files given a file or directory.

    Returns (summary_csv, args_csv) where either may be None.
    """
    if input_path.is_file():
        name = input_path.name
        if name.endswith("_syscall_summary.csv"):
            return input_path, None
        if name.endswith("_syscall_args_summary.csv"):
            return None, input_path
        # unknown - try reading to determine
        # we'll attempt to peek at headers when reading
        return input_path, None

    # directory: glob for expected patterns
    summary = None
    args = None
    for p in input_path.iterdir():
        if p.name.endswith("_syscall_summary.csv"):
            summary = p
        elif p.name.endswith("_syscall_args_summary.csv"):
            args = p
    # fallback: pick any csvs if explicit ones not found
    if not summary:
        csvs = list(input_path.glob("*.csv"))
        if csvs:
            summary = csvs[0]
    return summary, args


def read_summary_csv(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    # tolerate slightly different column names
    name_cols = [c for c in df.columns if c.lower().startswith("syscall")]
    if name_cols:
        df = df.rename(columns={name_cols[0]: "Syscall Name"})

    # ensure required numeric columns exist
    for col in ["Total Count", "Entry Count", "Exit Count"]:
        if col not in df.columns:
            # try lowercase variants
            for c in df.columns:
                if c.lower() == col.lower():
                    df = df.rename(columns={c: col})
                    break
    # coerce numeric
    for col in ["Total Count", "Entry Count", "Exit Count"]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0).astype(int)

    return df


def read_args_csv(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    # expected columns: Syscall Name, Argument, Value, Count
    return df


def make_top_syscalls_plot(df: pd.DataFrame, outpath: Path, top: int = 20):
    df_top = df.sort_values("Total Count", ascending=False).head(top)
    fig = px.bar(
        df_top,
        x="Syscall Name",
        y="Total Count",
        hover_data=["Entry Count", "Exit Count"],
        title=f"Top {len(df_top)} syscalls by total count",
    )
    fig.update_layout(xaxis_tickangle=-45)
    pio.write_image(fig, str(outpath))


def make_entry_exit_plot(df: pd.DataFrame, outpath: Path, top: int = 20):
    df_top = df.sort_values("Total Count", ascending=False).head(top)
    melt = df_top.melt(id_vars=["Syscall Name"], value_vars=["Entry Count", "Exit Count"], var_name="Call Type", value_name="Count")
    fig = px.bar(
        melt,
        x="Syscall Name",
        y="Count",
        color="Call Type",
        barmode="group",
        title=f"Entry vs Exit counts for top {len(df_top)} syscalls",
    )
    fig.update_layout(xaxis_tickangle=-45)
    pio.write_image(fig, str(outpath))


def make_args_plots(df_args: pd.DataFrame, outdir: Path, syscalls: Optional[List[str]] = None, top_values: int = 20):
    # df_args expected columns: Syscall Name, Argument, Value, Count
    if df_args.empty:
        return []

    produced = []
    grouped = df_args.groupby("Syscall Name")
    targets = syscalls if syscalls is not None else sorted(grouped.size().index, key=lambda n: grouped.get_group(n)["Count"].sum() if "Count" in grouped.get_group(n) else 0, reverse=True)

    for sc in targets:
        if sc not in grouped.groups:
            continue
        g = grouped.get_group(sc)
        # for each argument within this syscall, plot top values
        for arg, sub in g.groupby("Argument"):
            ssub = sub.sort_values("Count", ascending=False).head(top_values)
            if ssub.empty:
                continue
            fig = px.bar(ssub, x="Value", y="Count", title=f"{sc} — {arg}")
            fig.update_layout(xaxis_tickangle=-45)
            safe = sc.replace("/", "_").replace(" ", "_")
            fname = outdir / f"syscall_args_{safe}_{arg}.svg"
            pio.write_image(fig, str(fname))
            produced.append(fname)

    return produced


def main(argv: Optional[List[str]] = None):
    p = argparse.ArgumentParser(description="Plot LTTng syscall CSV outputs to SVG using plotly")
    p.add_argument("--input", "-i", required=True, help="CSV file or directory containing CSV outputs")
    p.add_argument("--outdir", "-o", default="./plots", help="Output directory for SVG files")
    p.add_argument("--top", "-t", type=int, default=20, help="Top N syscalls to plot")
    p.add_argument("--syscall", "-s", help="Only produce argument plots for this syscall (exact name)")
    p.add_argument("--no-args", action="store_true", help="Skip generating argument value plots")
    args = p.parse_args(argv)

    inp = Path(args.input)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    summary_csv, args_csv = find_csv_files(inp)

    df_summary = None
    df_args = pd.DataFrame()

    # try to read summary CSV
    if summary_csv and summary_csv.exists():
        try:
            df_summary = read_summary_csv(summary_csv)
        except Exception as e:
            print(f"Failed to read summary CSV {summary_csv}: {e}", file=sys.stderr)

    # try to read args CSV
    if args_csv and args_csv.exists():
        try:
            df_args = read_args_csv(args_csv)
        except Exception as e:
            print(f"Failed to read args CSV {args_csv}: {e}", file=sys.stderr)

    # If user supplied a single CSV file that we couldn't classify, try to inspect its columns
    if df_summary is None and inp.is_file():
        try:
            df_probe = pd.read_csv(inp)
            cols = [c.lower() for c in df_probe.columns]
            if "total count" in cols or any(c.startswith("syscall") for c in cols):
                df_summary = read_summary_csv(inp)
            elif {"argument", "value", "count"}.issubset(set(cols)):
                df_args = df_probe
        except Exception:
            pass

    produced = []

    # Ensure kaleido/engine available when writing SVG
    try:
        pio.kaleido.scope  # type: ignore
    except Exception:
        # We'll still attempt to write; plotly will raise a useful error if kaleido is missing
        pass

    if df_summary is not None and not df_summary.empty:
        top_svg = outdir / "top_syscalls.svg"
        entry_exit_svg = outdir / "top_syscalls_entry_exit.svg"
        make_top_syscalls_plot(df_summary, top_svg, top=args.top)
        make_entry_exit_plot(df_summary, entry_exit_svg, top=args.top)
        produced.extend([top_svg, entry_exit_svg])

    if not args.no_args:
        # If df_args empty but we can guess filename in same dir as summary
        if df_args.empty and summary_csv:
            candidate = summary_csv.parent / (summary_csv.name.replace("_syscall_summary.csv", "_syscall_args_summary.csv"))
            if candidate.exists():
                try:
                    df_args = read_args_csv(candidate)
                except Exception:
                    pass

        if not df_args.empty:
            syscalls = [args.syscall] if args.syscall else None
            prod = make_args_plots(df_args, outdir, syscalls)
            produced.extend(prod)

    if produced:
        print("Produced SVGs:")
        for pth in produced:
            print(" -", pth)
    else:
        print("No plots produced. Check input CSV files and try --help for options.")


if __name__ == "__main__":
    main()
