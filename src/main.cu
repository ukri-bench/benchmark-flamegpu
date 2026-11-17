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

nlohmann::json batch_circles_spatial3d_fp32(const nlohmann::json& runs, Arguments& args) {
    nlohmann::json data;

    std::vector<CirclesSpatial3DFP32RunData> benchmark_data = {};
    for (const auto& run : runs) {
        const auto seed        = run.at("seed").get<std::int64_t>();
        const auto steps       = run.at("steps").get<std::uint32_t>();
        const auto agent_count = run.at("agent_count").get<std::uint32_t>();
        const auto width       = run.at("env_width").get<float>();
        const auto comm_radius = run.at("comm_radius").get<float>();
        const auto validation  = run.at("validation").get<bool>();

        printf("run_circles_spatial3D_fp32(%d, %" PRId64 ", %u, %u, %f, %f, %d)\n", args.device, seed, steps, agent_count, width, comm_radius, validation);
        if (!args.dry_run) {
            benchmark_data.push_back(run_circles_spatial3D_fp32(args.device, seed, steps, agent_count, width, comm_radius, validation));
        }
    }

    for (const auto& run_data : benchmark_data) {
        data.push_back(run_data);
    }
    return data;
}

nlohmann::json batch_circles_spatial3d_fp64(const nlohmann::json& runs, Arguments& args) {
    nlohmann::json data;

    std::vector<CirclesSpatial3DFP64RunData> benchmark_data = {};
    for (const auto& run : runs) {
        const auto seed        = run.at("seed").get<std::int64_t>();
        const auto steps       = run.at("steps").get<std::uint32_t>();
        const auto agent_count = run.at("agent_count").get<std::uint32_t>();
        const auto width       = run.at("env_width").get<double>();
        const auto comm_radius = run.at("comm_radius").get<double>();
        const auto validation  = run.at("validation").get<bool>();

        printf("run_circles_spatial3D_fp64(%d, %" PRId64 ", %u, %u, %f, %f, %d)\n", args.device, seed, steps, agent_count, width, comm_radius, validation);
        if (!args.dry_run) {
            benchmark_data.push_back(run_circles_spatial3D_fp64(args.device, seed, steps, agent_count, width, comm_radius, validation));
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

    for (const auto& s : args.models) {
        printf("s: %s\n", s.c_str());
    }

    // Parse the config argument
    std::ifstream cfg_file(args.config_path);
    if (!cfg_file.is_open()) {
        std::fprintf(stderr, "Error: Failed to open config file '%s'\n", args.config_path.string().c_str());
        return EXIT_FAILURE;
    }
    const nlohmann::json cfg = nlohmann::json::parse(cfg_file, nullptr, true, true);

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
    // Run the benchmark(s), if none were specified or the specific model was included via the cli
    auto modelEnabled = [&](std::string_view model) {
        if (args.models.empty()) return true;
        return std::find(args.models.begin(), args.models.end(), model) != args.models.end();
    };
    // Iterate the configuration file benchmark structure, executing relevant benchmarks
    for (const auto& [model, runs] : cfg.at("benchmarks").items()) {
        if (modelEnabled(model)) continue;
        if (model == "circles_spatial3D_fp32") {
            json_root["benchmarks"][model] = batch_circles_spatial3d_fp32(runs, args);
        } else if (model == "circles_spatial3D_fp64") {
            json_root["benchmarks"][model] = batch_circles_spatial3d_fp64(runs, args);
        } else {
            std::fprintf(stderr, "Warning: Unknown benchmark model '%s'\n", model.c_str());
        }
    }

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
