#include "cli.h"

#include <set>
#include <string>
#include <vector>

// Causes memory issues in cudafe for atleast CUDA 12.4, 12.5 & 12.9 with gcc 12, so only include in a .cpp file
#include <CLI/App.hpp>
#include <CLI/Formatter.hpp>
#include <CLI/Config.hpp>
#include <CLI/ExtraValidators.hpp>

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
    std::set<std::string> modelNames = {"circles_spatial3D_fp32", "circles_spatial3D_fp64"};
    app.add_option("--models", args.models, "Subset of the available benchmark models to run")->check(CLI::IsMember(modelNames))->expected(1, -1);

    // Parse the cli
    try {
        app.parse(argc, argv);
    } catch (const CLI::ParseError &e) {
        std::exit(app.exit(e));
    }

    // Return the struct containing CLI args
    return args;
}
