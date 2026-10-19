#pragma once

#include <cstdint>
#include <string>
#include <nlohmann/json.hpp>

/**
 * Structure containing information about a single simulation run
 */
struct SchellingArray2Di32RunData {
    // inputs
    std::int32_t device = 0;
    std::uint64_t seed = 0u;
    std::uint32_t steps = 0u;
    std::uint32_t agent_count = 0u;
    std::uint32_t populated_count = 0u;
    std::uint32_t grid_width = 0u;
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

// @ todo replace parameters to fit schelling
NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(SchellingArray2Di32RunData, device, seed, steps, agent_count, populated_count, grid_width, validation, agent_updates, validation_result, s_total, s_rtc, s_simulation, s_init, s_steps, s_exit, agent_updates_per_s_total);

/**
 * Run a single invocation of the schelling benchmark model (using array2D messaging, with most computation utilising 32-bit integers)
 *
 * Returns a struct containing benchmark data (required configuration information + performance data for this simulation)
 */
 // @ todo replace parameters to fit schelling
const SchellingArray2Di32RunData run_schelling_array2D_i32(
    const std::int32_t DEVICE,
    const std::uint64_t SEED,
    const std::uint32_t STEPS,
    const std::uint32_t POPULATED_COUNT,
    const std::uint32_t GRID_WIDTH,
    const bool VALIDATION
);
