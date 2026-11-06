#include <algorithm>
#include <cstdio>
#include <cfloat>
#include <vector>
#include "circles_spatial3D_fp64.h"
#include "flamegpu/flamegpu.h"

// Include/use some FLAME GPU internal objects/methods for convenience. These are not considered part of the public API so may breaking changes may occur without a major version increase
#include "flamegpu/detail/SteadyClockTimer.h"

namespace {

/**
 * Agent function (with local scope) where each circle agent outputs their public information to a message list (id, 3d position in space)
 */
FLAMEGPU_AGENT_FUNCTION(output_message, flamegpu::MessageNone, flamegpu::MessageSpatial3D) {
    FLAMEGPU->message_out.setVariable<int>("id", FLAMEGPU->getVariable<int>("id"));
    FLAMEGPU->message_out.setLocation(
        FLAMEGPU->getVariable<double>("x"),
        FLAMEGPU->getVariable<double>("y"),
        FLAMEGPU->getVariable<double>("z"));
    return flamegpu::ALIVE;
}

/**
 * Agent function (with local scope) where each circle agent updates it's location based on information from the input spatial3D message list (containing the position of other agents)
 */
FLAMEGPU_AGENT_FUNCTION(move, flamegpu::MessageSpatial3D, flamegpu::MessageNone) {
    const int ID = FLAMEGPU->getVariable<int>("id");
    const double REPULSE_FACTOR = FLAMEGPU->environment.getProperty<double>("repulse");
    const double RADIUS = FLAMEGPU->message_in.radius();
    double fx = 0.0;
    double fy = 0.0;
    double fz = 0.0;
    const double x1 = FLAMEGPU->getVariable<double>("x");
    const double y1 = FLAMEGPU->getVariable<double>("y");
    const double z1 = FLAMEGPU->getVariable<double>("z");
    int count = 0;
    for (const auto message : FLAMEGPU->message_in(x1, y1, z1)) {
        if (message.getVariable<int>("id") != ID) {
            const double x2 = message.getVariable<float>("x");
            const double y2 = message.getVariable<float>("y");
            const double z2 = message.getVariable<float>("z");
            double x21 = x2 - x1;
            double y21 = y2 - y1;
            double z21 = z2 - z1;
            const double separation = sqrt(x21*x21 + y21*y21 + z21*z21);
            if (separation < RADIUS && separation > 0.0) {
                double k = sin((separation / RADIUS) * 3.141 * -2) * REPULSE_FACTOR;
                // Normalise without recalculating separation
                x21 /= separation;
                y21 /= separation;
                z21 /= separation;
                fx += k * x21;
                fy += k * y21;
                fz += k * z21;
                count++;
            }
        }
    }
    fx /= count > 0 ? count : 1;
    fy /= count > 0 ? count : 1;
    fz /= count > 0 ? count : 1;
    FLAMEGPU->setVariable<double>("x", x1 + fx);
    FLAMEGPU->setVariable<double>("y", y1 + fy);
    FLAMEGPU->setVariable<double>("z", z1 + fz);
    FLAMEGPU->setVariable<double>("drift", sqrt(fx*fx + fy*fy + fz*fz));  // todo: runtime conditional via templating?
    return flamegpu::ALIVE;
}

/**
 * flamegpu step function which does light-weight validation by changes in state.
 */
FLAMEGPU_STEP_FUNCTION(Validation) {
    static double prevTotalDrift = DBL_MAX;
    static unsigned int driftDropped = 0;
    static unsigned int driftIncreased = 0;
    // This value should decline? as the model moves towards a steady equlibrium state
    // Once an equilibrium state is reached, it is likely to oscillate between 2-4? values
    double totalDrift = FLAMEGPU->agent("Circle").sum<double>("drift");
    if (totalDrift <= prevTotalDrift) {
        driftDropped++;
    } else {
        driftIncreased++;
    }
    prevTotalDrift = totalDrift;
    // printf("Avg Drift: %g\n", totalDrift / FLAMEGPU->agent("Circle").count());
    printf("%.2f%% Drift correct\n", 100 * driftDropped / static_cast<double>(driftDropped + driftIncreased));
}

/**
 * FLAMEGPU Init function which generates the population on the host
 */
FLAMEGPU_INIT_FUNCTION(generate_population) {
    // Seed a host prng using the same seed as the device prng (but this is a different engine)
    std::mt19937_64 rng(FLAMEGPU->random.getSeed());
    const auto ENV_MIN = FLAMEGPU->environment.getProperty<double>("ENV_MIN");
    const auto ENV_MAX = FLAMEGPU->environment.getProperty<double>("ENV_MAX");
    std::uniform_real_distribution<double> dist(ENV_MIN, ENV_MAX);

    // Generate the agents with random uniform initial locations
    const auto AGENT_COUNT = FLAMEGPU->environment.getProperty<std::uint32_t>("AGENT_COUNT");
    auto circle = FLAMEGPU->agent("Circle");
    for (unsigned int i = 0; i < AGENT_COUNT; i++) {
        auto agent = circle.newAgent();
        agent.setVariable<double>("x", dist(rng));
        agent.setVariable<double>("y", dist(rng));
        agent.setVariable<double>("z", dist(rng));
    }
}


}  // namespace

// Run an individual simulation, using
const CirclesSpatial3DFP64RunData run_circles_spatial3D_fp64(
    const std::int32_t DEVICE,
    const std::uint64_t SEED,
    const std::uint32_t STEPS,
    const std::uint32_t AGENT_COUNT,
    const double ENV_WIDTH,
    const double COMM_RADIUS,
    const bool VALIDATION) {
    // construct and start recording a timer for the full model definition and execution
    auto timer = flamegpu::detail::SteadyClockTimer();
    timer.start();

    flamegpu::ModelDescription model("circles_spatial3D_fp64");
    // Calculate environment bounds.
    const double ENV_MIN = -0.5 * ENV_WIDTH;
    const double ENV_MAX = ENV_MIN + ENV_WIDTH;
    {   // Location message
        flamegpu::MessageSpatial3D::Description message = model.newMessage<flamegpu::MessageSpatial3D>("location");
        message.newVariable<int>("id");
        message.setRadius(COMM_RADIUS);
        message.setMin(ENV_MIN, ENV_MIN, ENV_MIN);
        message.setMax(ENV_MAX, ENV_MAX, ENV_MAX);
    }
    {   // Circle agent
        flamegpu::AgentDescription agent = model.newAgent("Circle");
        agent.newVariable<int>("id");
        agent.newVariable<double>("x");
        agent.newVariable<double>("y");
        agent.newVariable<double>("z");

        // if(validation) { // todo: runtime conditional via templating?
            agent.newVariable<double>("drift");  // Store the distance moved here, for validation
        // }
        agent.newFunction("output_message", output_message).setMessageOutput("location");
        agent.newFunction("move", move).setMessageInput("location");
    }

    // Global environment variables.
    {
        flamegpu::EnvironmentDescription env = model.Environment();
        env.newProperty("repulse", 0.05);
        env.newProperty("ENV_MIN", ENV_MIN);
        env.newProperty("ENV_MAX", ENV_MAX);
        env.newProperty("AGENT_COUNT", AGENT_COUNT);
    }

    // Add the init function which will generate the population of agents
    model.addInitFunction(generate_population);

    // If validation is required, add the step function which performs drift validation to the model
    if (VALIDATION) {
        model.addStepFunction(Validation);
    }

    // Add each agent function in their own layer.
    flamegpu::LayerDescription layer_0 = model.newLayer();
    layer_0.addAgentFunction(output_message);

    flamegpu::LayerDescription layer_1 = model.newLayer();
    layer_1.addAgentFunction(move);

    // Create the simulation object
    flamegpu::CUDASimulation simulation(model);

    // Set simulation configuration properties
    simulation.SimulationConfig().timing = false;
    simulation.SimulationConfig().telemetry = false;
    simulation.SimulationConfig().verbosity = flamegpu::Verbosity::Quiet;
    simulation.SimulationConfig().random_seed = SEED;
    simulation.SimulationConfig().steps = STEPS;
    simulation.CUDAConfig().device_id = DEVICE;

    // Execute
    simulation.simulate();

    // Stop the timer
    timer.stop();

    // Build the output data structure containing information about this simulation
    CirclesSpatial3DFP64RunData outputs;
    outputs.device = DEVICE;
    outputs.seed = SEED;
    outputs.steps = STEPS;
    outputs.agent_count = AGENT_COUNT;
    outputs.env_width = ENV_WIDTH;
    outputs.comm_radius = COMM_RADIUS;
    outputs.validation = VALIDATION;
    outputs.agent_updates = AGENT_COUNT * STEPS;
    outputs.validation_result = false;  // todo
    // Store timing information for output
    outputs.s_total = timer.getElapsedSeconds();
    outputs.s_rtc = simulation.getElapsedTimeRTCInitialisation();
    outputs.s_simulation = simulation.getElapsedTimeSimulation();
    outputs.s_init = simulation.getElapsedTimeInitFunctions();
    std::vector<double> s_steps = simulation.getElapsedTimeSteps();
    outputs.s_steps = std::accumulate(s_steps.begin(), s_steps.end(), 0.);
    outputs.s_exit = simulation.getElapsedTimeExitFunctions();

    // Compute and store the figure of merit (agent updates per second)
    outputs.agent_updates_per_s_total = outputs.agent_updates / outputs.s_total;

    // Return the data about this simulation
    return outputs;
}
