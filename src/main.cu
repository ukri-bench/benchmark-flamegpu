#include <inttypes.h>
#include <cfloat>
#include <cstdio>
#include <iostream>
#include <filesystem>
#include <format>
#include <fstream>
#include <vector>

#include <CLI/App.hpp>
#include <CLI/Formatter.hpp>
#include <CLI/Config.hpp>
#include <nlohmann/json.hpp>

#include "flamegpu/flamegpu.h"
#include "./metadata.h"
#include "./circles_spatial3D.h"


// Include/use some FLAME GPU internal objects/methods for convenience. These are not considered part of the public API so may breaking changes may occur without a major version increase
#include "flamegpu/detail/gpu/device_name.hpp"

/**
 * Struct containing values which can be configured using the CLI
 */
struct Arguments {
    // The GPU index to use
    std::int32_t device = 0;
    // The number of times each simulation is repeated
    std::uint32_t repetitions = 3u;
    // The number of steps for each simulation
    std::uint32_t steps = 200u;
    // PRNG seed
    std::uint64_t seed = 0u;
    // If validation should be performed for this run?
    bool validation = false;
    // If a dry run should be performed
    bool dry_run = false;
    // The output path for performance data
    std::filesystem::path output_path = std::filesystem::current_path() / "benchmark-flamegpu.json";
};

/**
 * Define and parse the command line interface
 */
Arguments parse_cli(int argc, const char ** argv) {
    // Struct containing values to be returned
    Arguments args = {};
    // Define the CLI using CLI11
    CLI::App app{"ukri-bench/benchmark-flamegpu"};
    app.add_option("-d,--device", args.device, "GPU Device ID (0 indexed)")->capture_default_str();
    app.add_option("-r,--repetitions", args.repetitions, "The number of times to repeat each simulation")->capture_default_str();
    app.add_option("-s,--steps", args.steps, "The number of steps for each simulation (> 0)")->check(CLI::PositiveNumber)->capture_default_str();
    app.add_option("--seed", args.seed, "RNG Seed used for simulations")->capture_default_str();  // todo: should this be a seed for the bench, but a different seed per simulation?
    app.add_flag("--validation", args.validation, "Enable validation checks");
    app.add_flag("--dry-run", args.dry_run, "Perform a dry-run");
    app.add_option("-o,--output", args.output_path, "Path to the output file")->capture_default_str();

    // Parse the cli
    try {
        app.parse(argc, argv);
    } catch (const CLI::ParseError &e) {
        std::exit(app.exit(e));
    }
    // Return the struct containing CLI args
    return args;
}


nlohmann::json sweep_circles_spatial3d(Arguments args) {
    nlohmann::json data;

    // const std::vector<float> TARGET_ENV_VOLUMES = {10000, 20000, 30000, 40000, 50000, 60000, 70000, 80000, 90000, 100000, 200000, 300000, 400000, 500000, 600000, 700000, 800000, 900000, 1000000};
    const std::vector<float> TARGET_ENV_VOLUMES = {1000, 125000, 1000000};

    // Fixed comm radius and (target) agent density
    const float comm_radius = 2.f;
    const float density = 1.f;

    std::vector<CirclesSpatial3DRunData> benchmark_data = {};
    for (const float& targetVolume : TARGET_ENV_VOLUMES) {
        const float width = round(cbrt(targetVolume));
        // const float actualVolume = width * width * width;
        // const float badness = (actualVolume - targetVolume) / targetVolume;
        const std::uint32_t agent_count = static_cast<float>(ceil((width * width * width) * density));
        for (std::uint32_t rep = 0; rep < args.repetitions; rep++) {
            printf("%s\n", std::format("run_circles_spatial3D({}, {}, {}, {}, {}, {}, {})", args.device, args.seed, args.steps, agent_count, width, comm_radius, args.validation).c_str());
            if (!args.dry_run) {
                CirclesSpatial3DRunData run_data = run_circles_spatial3D(args.device, args.seed, args.steps, agent_count, width, comm_radius, args.validation);
                benchmark_data.push_back(run_data);
            }
        }
    }

    for (const auto& run_data : benchmark_data) {
        data.push_back(run_data);
    }
    return data;
}

int main(int argc, const char ** argv) {
    // Setup/process CLI
    Arguments args = parse_cli(argc, argv);

    // Define a root json object
    nlohmann::json json_root;

    // Add some metadata for this invocation of the benchmark to the json object
    json_root["metadata"] = {
        {"device_idx", args.device},
        {"device_name", flamegpu::detail::gpu::getDeviceName(args.device)},
        {"gpu_toolkit", metadata::gpu_toolkit_identifier()},
        {"gpu_driver", metadata::gpu_driver_identifier()},
        {"BUILD_TYPE", BUILD_TYPE},
        {"FLAMEGPU_SEATBELTS", FLAMEGPU_SEATBELTS},
        {"FLAMEGPU_VERISON", std::string(flamegpu::VERSION_FULL)},
        {"git_describe", metadata::get_git_describe()},
    };

    // Run the benchmark(s)

    // Sweep over the spatial 3d model with a range of target volumes with a fixed agent density and communication radius
    auto circles_data = sweep_circles_spatial3d(args);
    json_root["benchmarks"]["circles_spatial3D"] = circles_data;

    // Output the json data to stdout and (potentially) disk
    printf("benchmark-flamegpu.json:\n%s\n", json_root.dump(2).c_str());

    // write to disk at the specified location (or in a default file in the working directory?)
    if (!args.dry_run) {
        // Create the directory to write into (in case it does not exist)
        if (args.output_path.has_parent_path()) {
            std::filesystem::create_directories(args.output_path.parent_path());
        }
        // Write out the file to disk, overwriting if the file already exists
        // Todo: add a --force flag?
        std::ofstream file(args.output_path);
        if (file.is_open()) {
            file << json_root.dump(4);
            fprintf(stderr, "%s\n", std::format("JSON written to '{}'", args.output_path.string()).c_str());
        } else {
            fprintf(stderr, "%s\n", std::format("Error: Failed to open '{}' for writing", args.output_path.string()).c_str());
        }
    }

    // Cleanup / Ensure profiling / memcheck work correctly
    flamegpu::util::cleanup();

    // Return
    return EXIT_SUCCESS;  // todo: exit code based on validation result?
}
