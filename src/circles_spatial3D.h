#pragma once

#include <cstdint>
#include <string>
#include <nlohmann/json.hpp>

/**
 * Structure containing information about a single simulation run
 */
struct CirclesSpatial3DRunData {
    // inputs
    std::int32_t device = 0;
    std::uint64_t seed = 0u;
    std::uint32_t steps = 0u;
    std::uint32_t agent_count = 0u;
    float env_width = 0.f;
    float comm_radius = 0.f;
    bool validation = false;

    // computed values
    std::uint64_t agent_updates = 0;
    bool validation_result = false;

    // performance data
    double s_total = 0.f;
    double s_rtc = 0.f;
    double s_simulation = 0.f;
    double s_init = 0.f;
    double s_steps = 0.f;
    double s_exit = 0.f;
    double agent_updates_per_s_total = 0.f;
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(CirclesSpatial3DRunData, device, seed, steps, agent_count, env_width, comm_radius, validation, agent_updates, validation_result, s_total, s_rtc, s_simulation, s_init, s_steps, s_exit, agent_updates_per_s_total);

/**
 * Run a single invocation of the circles benchmark model using spatial 3D data.
 * 
 * Returns a struct containing benchmark data (required configuration information + performance data for this simulation)
 */
const CirclesSpatial3DRunData run_circles_spatial3D(
    const std::int32_t DEVICE,
    const std::uint64_t SEED,
    const std::uint32_t STEPS,
    const std::uint32_t AGENT_COUNT,
    const float ENV_WIDTH,
    const float COMM_RADIUS,
    const bool VALIDATION
);
