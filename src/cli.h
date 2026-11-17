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
    // If validation should be performed for this run?
    bool validation = false;
    // If a dry run should be performed
    bool dry_run = false;
    // Path to a configuration file
    std::filesystem::path config_path = std::filesystem::current_path() / "config/default.json";
    // The output path for performance data
    std::filesystem::path output_path = std::filesystem::current_path() / "benchmark-flamegpu.json";
    // Vector of selected model names
    std::vector<std::string> models = {};
};

/**
 * Define and parse the command line interface
 */
Arguments parse_cli(int argc, const char ** argv);
