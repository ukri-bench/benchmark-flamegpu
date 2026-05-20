#include <inttypes.h>
#include <cfloat>
#include <cstdio>
#include <iostream>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

#include "flamegpu/flamegpu.h"
#include "./cli.h"
#include "./metadata.h"
#include "./circles_spatial3D_fp32.h"
#include "./circles_spatial3D_fp64.h"

// Include/use some FLAME GPU internal objects/methods for convenience. These are not considered part of the public API so may breaking changes may occur without a major version increase
#include "flamegpu/detail/gpu/device_name.hpp"

nlohmann::json sweep_circles_spatial3d_fp32(Arguments args) {
    nlohmann::json data;

    // const std::vector<float> TARGET_ENV_VOLUMES = {1000, 125000, 1000000};
    // const std::vector<float> TARGET_ENV_VOLUMES = {10000, 20000, 30000, 40000, 50000, 60000, 70000, 80000, 90000, 100000, 200000, 300000, 400000, 500000, 600000, 700000, 800000, 900000, 1000000};
    const std::vector<float> TARGET_ENV_VOLUMES = {1000, 3375, 8000, 15625, 27000, 42875, 64000, 91125, 125000, 166375, 216000, 274625, 343000, 421875, 512000, 614125, 729000, 857375, 1000000, 1157625, 1331000, 1520875, 1728000, 1953125, 2197000};

    // Fixed comm radius and (target) agent density
    const float comm_radius = 2.f;
    const float density = 1.f;

    std::vector<CirclesSpatial3DFP32RunData> benchmark_data = {};
    for (const float& targetVolume : TARGET_ENV_VOLUMES) {
        const float width = round(cbrt(targetVolume));
        // const float actualVolume = width * width * width;
        // const float badness = (actualVolume - targetVolume) / targetVolume;
        const std::uint32_t agent_count = static_cast<float>(ceil((width * width * width) * density));
        for (std::uint32_t rep = 0; rep < args.repetitions; rep++) {
            printf("run_circles_spatial3D_fp32(%d, %" PRId64 ", %u, %u, %f, %f, %d)\n", args.device, args.seed, args.steps, agent_count, width, comm_radius, args.validation);
            if (!args.dry_run) {
                CirclesSpatial3DFP32RunData run_data = run_circles_spatial3D_fp32(args.device, args.seed + rep, args.steps, agent_count, width, comm_radius, args.validation);
                benchmark_data.push_back(run_data);
            }
        }
    }

    for (const auto& run_data : benchmark_data) {
        data.push_back(run_data);
    }
    return data;
}


nlohmann::json sweep_circles_spatial3d_fp64(Arguments args) {
    nlohmann::json data;

    // const std::vector<double> TARGET_ENV_VOLUMES = {1000, 125000, 1000000};
    // const std::vector<double> TARGET_ENV_VOLUMES = {10000, 20000, 30000, 40000, 50000, 60000, 70000, 80000, 90000, 100000, 200000, 300000, 400000, 500000, 600000, 700000, 800000, 900000, 1000000};
    const std::vector<double> TARGET_ENV_VOLUMES = {1000, 3375, 8000, 15625, 27000, 42875, 64000, 91125, 125000, 166375, 216000, 274625, 343000, 421875, 512000, 614125, 729000, 857375, 1000000, 1157625, 1331000, 1520875, 1728000, 1953125, 2197000};

    // Fixed comm radius and (target) agent density
    const double comm_radius = 2.0;
    const double density = 1.0;

    std::vector<CirclesSpatial3DFP64RunData> benchmark_data = {};
    for (const double& targetVolume : TARGET_ENV_VOLUMES) {
        const double width = round(cbrt(targetVolume));
        // const double actualVolume = width * width * width;
        // const double badness = (actualVolume - targetVolume) / targetVolume;
        const std::uint32_t agent_count = static_cast<float>(ceil((width * width * width) * density));
        for (std::uint32_t rep = 0; rep < args.repetitions; rep++) {
            printf("run_circles_spatial3D_fp64(%d, %" PRId64 ", %u, %u, %f, %f, %d)\n", args.device, args.seed, args.steps, agent_count, width, comm_radius, args.validation);
            if (!args.dry_run) {
                CirclesSpatial3DFP64RunData run_data = run_circles_spatial3D_fp64(args.device, args.seed + rep, args.steps, agent_count, width, comm_radius, args.validation);
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
    json_root["metadata"]["build"] = {
        {"gpu_toolkit", metadata::gpu_toolkit_identifier()},
        {"BUILD_TYPE", BUILD_TYPE},
        {"FLAMEGPU_SEATBELTS", FLAMEGPU_SEATBELTS},
        {"FLAMEGPU_VERISON", std::string(flamegpu::VERSION_FULL)},
        {"git_describe", metadata::get_git_describe()},
    };

    json_root["metadata"]["runtime"] = {
        {"gpu_driver", metadata::gpu_driver_identifier()},
        {"gpu_idx", args.device},
        {"gpu_name", flamegpu::detail::gpu::getDeviceName(args.device)},
        {"cpu_model_name", metadata::get_cpu_model()},
    };
    // Run the benchmark(s)

    // Sweep over the spatial 3d model with a range of target volumes with a fixed agent density and communication radius
    json_root["benchmarks"]["circles_spatial3D_fp32"] = sweep_circles_spatial3d_fp32(args);

    // Sweep over the spatial 3d model in fp64
    json_root["benchmarks"]["circles_spatial3D_fp64"] = sweep_circles_spatial3d_fp64(args);

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
            fprintf(stderr, "JSON written to '%s'\n", args.output_path.c_str());
        } else {
            fprintf(stderr, "Error: Failed to open '%s' for writing\n", args.output_path.c_str());
        }
    }

    // Cleanup / Ensure profiling / memcheck work correctly
    flamegpu::util::cleanup();

    // Return
    return EXIT_SUCCESS;  // todo: exit code based on validation result?
}
