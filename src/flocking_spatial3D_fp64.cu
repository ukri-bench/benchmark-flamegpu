#include <algorithm>
#include <cstdio>
#include <cfloat>
#include <vector>
#include "flocking_spatial3D_fp64.h"
#include "flamegpu/flamegpu.h"

// Include/use some FLAME GPU internal objects/methods for convenience. These are not considered part of the public API so may breaking changes may occur without a major version increase
#include "flamegpu/detail/SteadyClockTimer.h"

namespace {

    /**
     * Get the length of a vector
     * @param x x component of the vector
     * @param y y component of the vector
     * @return the length of the vector
     */ 
    FLAMEGPU_HOST_DEVICE_FUNCTION double vec3Length(const double x, const double y) {
        return sqrt(x * x + y * y);
    }

    /**
     * Multiply a vector by a scalar value in-place
     * @param x x component of the vector
     * @param y y component of the vector
     * @param multiplier scalar value to multiply by
     */ 
    FLAMEGPU_HOST_DEVICE_FUNCTION void vec3Mult(double &x, double &y, const double multiplier) {
        x *= multiplier;
        y *= multiplier;
    }

    /**
     * Divide a vector by a scalar value in-place
     * @param x x component of the vector
     * @param y y component of the vector
     * @param divisor scalar value to divide by
     */ 
    FLAMEGPU_HOST_DEVICE_FUNCTION void vec3Div(double &x, double &y, const double divisor) {
        x /= divisor;
        y /= divisor;
    }

    /**
     * Ensure that the x and y position are withini the defined boundary area, wrapping to the far side if out of bounds.
     * Performs the operation in place
     * @param x x component of the vector
     * @param y y component of the vector
     * @param MIN_POSITION the minimum value for each component
     * @param MAX_POSITION the maximum value for each component
     */
    FLAMEGPU_HOST_DEVICE_FUNCTION void wrapPosition(double &x, double &y, const double MIN_POSITION, const double MAX_POSITION) {
        const double WIDTH = MAX_POSITION - MIN_POSITION;
        if (x < MIN_POSITION) {
            x += WIDTH;
        }
        if (y < MIN_POSITION) {
            y += WIDTH;
        }
        
        if (x > MAX_POSITION) {
            x -= WIDTH;
        }
        if (y > MAX_POSITION) {
            y -= WIDTH;
        }
    }

    /**
     * outputdata agent function for Boid agents, which outputs publicly visible properties to a message list
     */
    FLAMEGPU_AGENT_FUNCTION(outputdata, flamegpu::MessageNone, flamegpu::MessageSpatial2D) {
        // Output each agents publicly visible properties.
        FLAMEGPU->message_out.setVariable<flamegpu::id_t>("id", FLAMEGPU->getID());
        FLAMEGPU->message_out.setVariable<double>("x", FLAMEGPU->getVariable<double>("x"));
        FLAMEGPU->message_out.setVariable<double>("y", FLAMEGPU->getVariable<double>("y"));
        FLAMEGPU->message_out.setVariable<double>("fx", FLAMEGPU->getVariable<double>("fx"));
        FLAMEGPU->message_out.setVariable<double>("fy", FLAMEGPU->getVariable<double>("fy"));
        return flamegpu::ALIVE;
    }

    /**
     * inputdata agent function for Boid agents, which reads data from neighbouring Boid agents, to perform the boid flocking model.
     */
    FLAMEGPU_AGENT_FUNCTION(inputdata, flamegpu::MessageSpatial2D, flamegpu::MessageNone) {
        // Agent properties in local register
        const flamegpu::id_t id = FLAMEGPU->getID();
        // Agent position
        double agent_x = FLAMEGPU->getVariable<double>("x");
        double agent_y = FLAMEGPU->getVariable<double>("y");
        // Agent velocity
        double agent_fx = FLAMEGPU->getVariable<double>("fx");
        double agent_fy = FLAMEGPU->getVariable<double>("fy");

        // Boids perceived center
        double perceived_centre_x = 0.0;
        double perceived_centre_y = 0.0;
        int perceived_count = 0;

        // Boids global velocity matching
        double global_velocity_x = 0.0;
        double global_velocity_y = 0.0;

        // Total change in velocity
        double velocity_change_x = 0.0;
        double velocity_change_y = 0.0;

        const double INTERACTION_RADIUS = FLAMEGPU->environment.getProperty<double>("INTERACTION_RADIUS");
        const double SEPARATION_RADIUS = FLAMEGPU->environment.getProperty<double>("SEPARATION_RADIUS");
        // Iterate location messages, accumulating relevant data and counts.
        for (const auto message : FLAMEGPU->message_in.wrap(agent_x, agent_y)) {
            // Ignore self messages.
            if (message.getVariable<flamegpu::id_t>("id") != id) {
                // Get the message location and velocity.
                const float message_x = message.getVirtualX();
                const float message_y = message.getVirtualY();

                // Check interaction radius
                const double separation = vec3Length(agent_x - message_x, agent_y - message_y);

                if (separation < INTERACTION_RADIUS) {
                    // Update the perceived centre
                    perceived_centre_x += message_x;
                    perceived_centre_y += message_y;
                    perceived_count++;

                    // Update perceived velocity matching
                    const double message_fx = message.getVariable<double>("fx");
                    const double message_fy = message.getVariable<double>("fy");
                    global_velocity_x += message_fx;
                    global_velocity_y += message_fy;

                    // Update collision centre
                    if (separation < (SEPARATION_RADIUS)) {  // dependant on model size
                        // Rule 3) Avoid other nearby boids (Separation)
                        double normalizedSeparation = (separation / SEPARATION_RADIUS);
                        double invNormSep = (1.0f - normalizedSeparation);
                        double invSqSep = invNormSep * invNormSep;

                        const double collisionScale = FLAMEGPU->environment.getProperty<double>("COLLISION_SCALE");
                        velocity_change_x += collisionScale * (agent_x - message_x) * invSqSep;
                        velocity_change_y += collisionScale * (agent_y - message_y) * invSqSep;
                    }
                }
            }
        }

        if (perceived_count) {
            // Divide positions/velocities by relevant counts.
            vec3Div(perceived_centre_x, perceived_centre_y, perceived_count);
            vec3Div(global_velocity_x, global_velocity_y, perceived_count);

            // Rule 1) Steer towards perceived centre of flock (Cohesion)
            const double STEER_SCALE = FLAMEGPU->environment.getProperty<double>("STEER_SCALE");
            const double steer_velocity_x = (perceived_centre_x - agent_x) * STEER_SCALE;
            const double steer_velocity_y = (perceived_centre_y - agent_y) * STEER_SCALE;

            velocity_change_x += steer_velocity_x;
            velocity_change_y += steer_velocity_y;

            // Rule 2) Match neighbours speeds (Alignment)
            const double MATCH_SCALE = FLAMEGPU->environment.getProperty<double>("MATCH_SCALE");
            const double match_velocity_x = global_velocity_x * MATCH_SCALE;
            const double match_velocity_y = global_velocity_y * MATCH_SCALE;

            velocity_change_x += match_velocity_x - agent_fx;
            velocity_change_y += match_velocity_y - agent_fy;
        }

        // Global scale of velocity change
        vec3Mult(velocity_change_x, velocity_change_y, FLAMEGPU->environment.getProperty<double>("GLOBAL_SCALE"));

        // Update agent velocity
        agent_fx += velocity_change_x;
        agent_fy += velocity_change_y;

        // Bound velocity
        double agent_fscale = vec3Length(agent_fx, agent_fy);
        if (agent_fscale > 1) {
            vec3Div(agent_fx, agent_fy, agent_fscale);
        }

        double minSpeed = 0.5;
        if (agent_fscale < minSpeed) {
            // Normalise
            vec3Div(agent_fx, agent_fy, agent_fscale);

            // Scale to min
            vec3Mult(agent_fx, agent_fy, minSpeed);
        }

        // Apply the velocity
        const double TIME_SCALE = FLAMEGPU->environment.getProperty<double>("TIME_SCALE");
        agent_x += agent_fx * TIME_SCALE;
        agent_y += agent_fy * TIME_SCALE;

        // Wramp position
        const double MIN_POSITION = FLAMEGPU->environment.getProperty<double>("MIN_POSITION");
        const double MAX_POSITION = FLAMEGPU->environment.getProperty<double>("MAX_POSITION");
        wrapPosition(agent_x, agent_y, MIN_POSITION, MAX_POSITION);

        // Update global agent memory.
        FLAMEGPU->setVariable<double>("x", agent_x);
        FLAMEGPU->setVariable<double>("y", agent_y);

        FLAMEGPU->setVariable<double>("fx", agent_fx);
        FLAMEGPU->setVariable<double>("fy", agent_fy);

        return flamegpu::ALIVE;
    }

}  // namespace

// Run an individual simulation, using
const FlockingSpatial3DFP64RunData run_flocking_spatial3D_fp64(
    const std::int32_t DEVICE,
    const std::uint64_t SEED,
    const std::uint32_t STEPS,
    const std::uint32_t AGENT_COUNT,
    const float ENV_WIDTH,
    const float COMM_RADIUS,
    const bool VALIDATION) {
    // construct and start recording a timer for the full model definition and execution
    auto timer = flamegpu::detail::SteadyClockTimer();
    timer.start();

    flamegpu::ModelDescription model("Boids Spatial3D");

    // Environment variables with default values
    flamegpu::EnvironmentDescription env = model.Environment();

    // Population size to generate, if no agents are loaded from disk
    env.newProperty("POPULATION_TO_GENERATE", 80000u);

    // Environment Bounds

    env.newProperty("MIN_POSITION", 0.0f);
    env.newProperty("MAX_POSITION", 400.0f);

    // Initialisation parameter(s)
    env.newProperty("INITIAL_SPEED", 1.0f); // always start with a speed of 1.0

    // Interaction radius
    env.newProperty("INTERACTION_RADIUS", 5.0f);
    env.newProperty("SEPARATION_RADIUS", 1.0f);

    // Global Scalers
    env.newProperty("TIME_SCALE", 1.0f); // 1.0 for benchmarking to behave the same as the other simulators.
    env.newProperty("GLOBAL_SCALE", 1.0f); // 1.0 for comparing to other benchmarks

    // Rule scalers
    env.newProperty("STEER_SCALE", 0.03f); // cohere scale?  0.03
    env.newProperty("COLLISION_SCALE", 0.015f); // separate_scale? 0.015
    env.newProperty("MATCH_SCALE", 0.05f); // match 0.05


    // Define the Location 2D spatial message list
    flamegpu::MessageSpatial2D::Description message = model.newMessage<flamegpu::MessageSpatial2D>("location");
    // Set the range and bounds.
    message.setRadius(env.getProperty<double>("INTERACTION_RADIUS"));
    message.setMin(env.getProperty<double>("MIN_POSITION"), env.getProperty<double>("MIN_POSITION"));
    message.setMax(env.getProperty<double>("MAX_POSITION"), env.getProperty<double>("MAX_POSITION"));

    // A message to hold the location of an agent.
    message.newVariable<flamegpu::id_t>("id");
    // Spatial 2D messages implicitly have double members x and y, so they do not need to be defined
    message.newVariable<double>("fx");
    message.newVariable<double>("fy");
    message.newVariable<double>("fz");

    // Boid agent
    flamegpu::AgentDescription agent = model.newAgent("Boid");
    agent.newVariable<double>("x");
    agent.newVariable<double>("y");
    agent.newVariable<double>("fx");
    agent.newVariable<double>("fy");
    // Define the agents methods
    flamegpu::AgentFunctionDescription outputdataDescription = agent.newFunction("outputdata", outputdata);
    outputdataDescription.setMessageOutput("location");
    flamegpu::AgentFunctionDescription inputdataDescription = agent.newFunction("inputdata", inputdata);
    inputdataDescription.setMessageInput("location");

    // Specify agent method dependencies, i.e. the exeuction order within a layer.
    model.addExecutionRoot(outputdataDescription);
    inputdataDescription.dependsOn(outputdataDescription);
    // Build the execution graph
    model.generateLayers();

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
    FlockingSpatial3DFP64RunData outputs;
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
