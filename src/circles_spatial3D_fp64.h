#pragma once

#include <cstdint>
#include <string>
#include <nlohmann/json.hpp>

/**
 * Structure containing information about a single simulation run
 */
struct CirclesSpatial3DFP64RunData {
    // inputs
    std::int32_t device = 0;
    std::uint64_t seed = 0u;
    std::uint32_t steps = 0u;
    std::uint32_t agent_count = 0u;
    double env_width = 0.;
    double comm_radius = 0.;
    bool validation = false;

    // computed values
    std::uint64_t agent_updates = 0;
    bool validation_result = false;

    // performance data
    double s_total = 0.;
    double s_rtc = 0.;
    double s_simulation = 0.;
    double s_init = 0.;
    double s_steps = 0.;
    double s_exit = 0.;
    double agent_updates_per_s_total = 0.;
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(CirclesSpatial3DFP64RunData, device, seed, steps, agent_count, env_width, comm_radius, validation, agent_updates, validation_result, s_total, s_rtc, s_simulation, s_init, s_steps, s_exit, agent_updates_per_s_total);

/**
 * Run a single invocation of the circles spatial 3D fp64 benchmark model
 * 
 * Note: Spatial messaging is currently only implemented in fp32, so this is not a true/full fp64 benchmark.
 * See https://github.com/FLAMEGPU/FLAMEGPU2/issues/959
 * 
 * Returns a struct containing benchmark data (required configuration information + performance data for this simulation)
 */
const CirclesSpatial3DFP64RunData run_circles_spatial3D_fp64(
    const std::int32_t DEVICE,
    const std::uint64_t SEED,
    const std::uint32_t STEPS,
    const std::uint32_t AGENT_COUNT,
    const double ENV_WIDTH,
    const double COMM_RADIUS,
    const bool VALIDATION
);
