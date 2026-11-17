#! /usr/bin/env python3

import argparse
import itertools
import json
import math
import pathlib

"""Example script to programatically generate a JSON configuration file for a parameter sweep"""

def sweep_circles_spatial3D_fp32() -> dict:
    # const std::vector<float> TARGET_ENV_VOLUMES = {1000, 3375, 8000, 15625, 27000, 42875, 64000, 91125, 125000, 166375, 216000, 274625, 343000, 421875, 512000, 614125, 729000, 857375, 1000000, 1157625, 1331000, 1520875, 1728000, 1953125, 2197000};
    ENV_WIDTHS = [10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130]
    COMM_RADII = [1.0]
    DENSITY = [1.0]
    REPETITIONS = 3
    BASE_SEED = 12
    STEPS = 1000
    VALIDATION = False
    simulations = []
    for width, radius, density in itertools.product(ENV_WIDTHS, COMM_RADII, DENSITY):
        agent_count = math.ceil((width ** 3) * density)
        for rep in range(REPETITIONS):
            simulations.append({
                "seed": BASE_SEED + rep,
                "steps": STEPS,
                "agent_count": agent_count,
                "env_width": width,
                "comm_radius": radius,
                "validation": VALIDATION,
            })
    obj = {"circles_spatial3D_fp32": simulations}
    return obj

def sweep_circles_spatial3D_fp64() -> dict:
    # const std::vector<float> TARGET_ENV_VOLUMES = {1000, 3375, 8000, 15625, 27000, 42875, 64000, 91125, 125000, 166375, 216000, 274625, 343000, 421875, 512000, 614125, 729000, 857375, 1000000, 1157625, 1331000, 1520875, 1728000, 1953125, 2197000};
    ENV_WIDTHS = [10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130]
    COMM_RADII = [1.0]
    DENSITY = [1.0]
    REPETITIONS = 3
    BASE_SEED = 12
    STEPS = 1000
    VALIDATION = False
    simulations = []
    for width, radius, density in itertools.product(ENV_WIDTHS, COMM_RADII, DENSITY):
        agent_count = math.ceil((width ** 3) * density)
        for rep in range(REPETITIONS):
            simulations.append({
                "seed": BASE_SEED + rep,
                "steps": STEPS,
                "agent_count": agent_count,
                "env_width": width,
                "comm_radius": radius,
                "validation": VALIDATION,
            })
    obj = {"circles_spatial3D_fp64": simulations}
    return obj


def main() -> None:
    parser = argparse.ArgumentParser(description="Example Benchmark configuration generator")
    parser.add_argument("-o", "--output", type=pathlib.Path, help="output json path", default=None)
    args = parser.parse_args()

    obj = {
        "benchmarks": {
            **sweep_circles_spatial3D_fp32(),
            **sweep_circles_spatial3D_fp64(),
        }
    }

    total_simulations = sum([len(x) for x in obj["benchmarks"]])
    num_benchmarks = len(obj["benchmarks"])

    if args.output is not None:
        output_path = pathlib.Path(args.output)
        if output_path.is_dir():
            raise FileExistsError(f"{output_path} is a directory")
        with open(output_path, "w") as f:
            json.dump(obj, f, indent=2)
        print(f"config written to '{output_path.absolute()}' ({num_benchmarks} benchmarks, {total_simulations} simulations)")
    else:
        print(json.dumps(obj, indent=2))


if __name__ == "__main__":
    main()