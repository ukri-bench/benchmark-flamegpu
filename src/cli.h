#pragma once

#include <inttypes.h>
#include <cfloat>
#include <filesystem>
#include <set>
#include <string>
#include <vector>


// CLI related code
// CLI11 causes a memory leak in cudafe for CUDA 12.x, so is only used in .cpp file(s)

/**
 * Struct containing values which can be configured using the CLI
 */
struct Arguments {
    // The GPU index to use
    std::int32_t device = 0;
    // The number of times each simulation is repeated
    std::uint32_t repetitions = 3u;
    // The number of steps for each simulation
    std::uint32_t steps = 1000u;
    // PRNG seed
    std::uint64_t seed = 0u;
    // If validation should be performed for this run?
    bool validation = false;
    // If a dry run should be performed
    bool dry_run = false;
    // The output path for performance data
    std::filesystem::path output_path = std::filesystem::current_path() / "benchmark-flamegpu.json";
    // Vector of selected model names
    std::vector<std::string> models = {};
};

/**
 * Define and parse the command line interface
 */
Arguments parse_cli(int argc, const char ** argv);
