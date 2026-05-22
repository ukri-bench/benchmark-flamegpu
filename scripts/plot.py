#! /usr/bin/env python3
"""Combine and plot benchmark-flamegpu data from multiple json files"""

import argparse
import json
import math
import os
import pathlib
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

def cli() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Combine and plot benchmark-flamegpu from multiple runs")
    parser.add_argument("json_paths", type=pathlib.Path, nargs="+", help="Paths to JSON files containing benchmark-flamegpu data")
    parser.add_argument("-o", "--output", type=pathlib.Path, help="Path to a directory for output files")
    parser.add_argument("--show", action="store_true", help="Sequentially display each plot interactively")
    parser.add_argument("--format", choices=["png", "svg"], default="png", help="The output format for figures written to disk (default png)")
    parser.add_argument("--subplots", action="store_true", help="Render a plot per benchmark model, useful when comparing many benchmark runs")
    args = parser.parse_args()
    return args

def json_to_df(f: os.PathLike) -> pd.DataFrame:    
    path = pathlib.Path(f)
    if not path.is_file():
        raise RuntimeError(f"'{path}' is not a file")
    
    with open(path, 'r') as fp:
        data = json.load(fp)
    
    if "metadata" not in data:
        raise RuntimeError(f"Required key 'metadata' not found in '{path}'")

    if "build" not in data["metadata"]:
        raise RuntimeError(f"Required key 'metadata' not found in '{path}'")

    if "runtime" not in data["metadata"]:
        raise RuntimeError(f"Required key 'metadata' not found in '{path}'")

    if "benchmarks" not in data:
        raise RuntimeError(f"Required key 'benchmarks' not found in '{path}'")
    
    # Todo: make this more flexible once other benchmarks are added
    if not data["benchmarks"]:
        raise RuntimeError(f"'benchmarks' in '{path}' has no members / data")

    # flatten each benchmark into a dataframe
    df_list = []
    for name, benchmark_data in data["benchmarks"].items():
        temp_df = pd.DataFrame(benchmark_data)
        temp_df["benchmark_name"] = name
        df_list.append(temp_df)

    # combine the benchmark dataframes 
    df = pd.concat(df_list, ignore_index=True)

    # embed metadata in each row
    metadata = {**data["metadata"]["build"], **data["metadata"]["runtime"]}
    df = df.assign(**metadata)

    return df

def load_data(json_paths: list[os.PathLike]) -> dict[pathlib.Path, pd.DataFrame]:
    dfs = []
    for path in json_paths:
        df = json_to_df(path)
        if not df.empty:
            dfs.append(df)
    return pd.concat(dfs, ignore_index=True) if dfs else pd.DataFrame()

def plot(df: pd.DataFrame, output_path: pathlib.Path | None,  output_format: str, show: bool, use_subplots: bool) -> bool:
    if df.empty:
        print("No data to plot")
        return False

    # Combine the gpu_name and gpu_toolkit into a single field to use as 
    df = df.copy()
    df["GPU / Toolkit"] = df["gpu_name"] + " - " + df["gpu_toolkit"]
    # Get the number of unique values of this for the number of hues
    num_hues = len(df["GPU / Toolkit"].unique())

    # Rename the benchmark_name column just for rendering purposes
    df = df.rename(columns={
        "benchmark_name": "Benchmark Model",
    })


    # Plot the agent count against agent updates per second, comparing different devices and gpu toolkits
    # Todo: make this produce multiple plots, with more factor determining the different builds to compare
    sns.set_style(style="darkgrid")
    sns.set_palette(sns.husl_palette(num_hues))

    # Conditionally plot onto different axes if subplots is set, with one subplot per model
    subplot_dfs = [("", df)]
    if use_subplots:
        unique_benchmark_models = df["Benchmark Model"].unique()
        subplot_dfs = [(model, df[df["Benchmark Model"] == model]) for model in unique_benchmark_models]

    # Compute the shape of the subplots, by taking the sqrt of the number of subplots to get the number of rows.
    num_subplots = len(subplot_dfs)
    subplot_nrows = int(math.floor(math.sqrt(num_subplots)))
    subplot_ncols = int(math.ceil(num_subplots / subplot_nrows))

    # Create the figure with subplots
    fig, _ = plt.subplots(subplot_nrows, subplot_ncols, figsize=(16, 9), layout="constrained", squeeze=False, sharex=True, sharey=True)

    # Store legend data to ensure a single shared legend can be used
    all_legend_handles = []
    all_legend_labels = []

    # Iterate the axes and model data, plotting each
    for ax, (model_name, df) in zip(fig.axes, subplot_dfs):
        plot = sns.lineplot(
            ax=ax,
            data = df,
            x="agent_count",
            y="agent_updates_per_s_total",
            hue="GPU / Toolkit",
            style="Benchmark Model",
            markers=True,
            errorbar=("pi", 100), # show full range with the error bars
            estimator="median", # plot the median, to avoid errors when the first run is an outlier breaking seaborn bars
            err_style="bars",
        )
        ax.set_title(f"{model_name}")
        ax.set_xlabel("Agent Count")
        ax.set_ylabel("Agent Updates per Second")
        if not use_subplots:
            ax.legend(bbox_to_anchor=(1.02, 1), loc="upper left")

    fig.suptitle("ukri-bench/benchmark-flamegpu")

    # Set axes limits after the loop, so upper ranges are correct
    for ax in fig.axes:
        ax.set_xlim(left=0)
        ax.set_ylim(bottom=0)

    if output_path:
        output_path.mkdir(parents=True, exist_ok=True)
        # todo: multiple files etc
        output_file = output_path / f"benchmark-flamegpu.{output_format}"
        plt.savefig(output_file, dpi=300)
        print(f"Figure saved to '{output_file}'")

    if show:
        plt.show()
    
    return True

def main():
    args = cli()
    dataframes = load_data(args.json_paths)
    # Todo: Preprocess multiple values for repetitions? and produce numeric outputs not just plots? (maybe a diff script)
    success = plot(dataframes, args.output, args.format, args.show, args.subplots)
    return success

if __name__ == "__main__":
    main()
