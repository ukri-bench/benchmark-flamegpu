#! /usr/bin/env python3
"""Combine and plot benchmark-flamegpu data from multiple json files"""

import argparse
import json
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

def plot(df: pd.DataFrame, output_path: pathlib.Path | None, show: bool) -> bool:
    if df.empty:
        print("No data to plot")
        return False

    # Combine the gpu_name and gpu_toolkit into a single field to use as 
    df = df.copy()
    df["GPU / Toolkit"] = df["gpu_name"] + " - " + df["gpu_toolkit"]
    
    # Rename the benchmark_name column just for rendering purposes
    df = df.rename(columns={
        "benchmark_name": "Benchmark Model",
    })

    # Plot the agent count against agent updates per second, comparing different devices and gpu toolkits
    # Todo: make this produce multiple plots, with more factor determining the different builds to compare
    sns.set_style(style="darkgrid")
    sns.set_palette("Dark2")

    plt.figure(figsize=(16, 9), layout="constrained")
    plot = sns.lineplot(
        data = df,
        x="agent_count",
        y="agent_updates_per_s_total",
        hue="GPU / Toolkit",
        style="Benchmark Model",
        marker=True,
    )
    plt.title("ukri-bench/benchmark-flamegpu: Througput against Agent Count per GPU/Toolkit per Benchmark Model")
    plt.xlabel("Agent Count")
    plt.ylabel("Agent Updates per Second")
    plt.xlim(left=0)
    plt.ylim(bottom=0)
    plt.legend(bbox_to_anchor=(1.02, 1), loc="upper left")


    if output_path:
        output_path.mkdir(parents=True, exist_ok=True)
        # todo: multiple files etc
        output_file = output_path / "benchmark-flamegpu.png"
        plt.savefig(output_file)
        print(f"Figure saved to '{output_file}'")

    if show:
        plt.show()
    
    return True

def main():
    args = cli()
    dataframes = load_data(args.json_paths)
    # Todo: Preprocess multiple values for repetitions? and produce numeric outputs not just plots? (maybe a diff script)
    success = plot(dataframes, args.output, args.show)
    return success

if __name__ == "__main__":
    main()
