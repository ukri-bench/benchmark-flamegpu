#include <algorithm>
#include <cstdio>
#include <cfloat>
#include <vector>
#include "schelling_array2D_i32.h"
#include "flamegpu/flamegpu.h"

// Include/use some FLAME GPU internal objects/methods for convenience. These are not considered part of the public API so may breaking changes may occur without a major version increase
#include "flamegpu/detail/SteadyClockTimer.h"

namespace {
    constexpr float THRESHOLD = 0.375; // 0.375 == 3/8s to match integer models

    constexpr unsigned int A = 0;
    constexpr unsigned int B = 1;
    constexpr unsigned int UNOCCUPIED = 2;

    FLAMEGPU_INIT_FUNCTION(create_population) {
        // Use a seeded mt19937 generator
        std::mt19937_64 rng(FLAMEGPU->random.getSeed() + 1);
        // use a uniform generator to determine the initial group of an individual
        std::uniform_real_distribution<float> uniformDist(0, 1);
        // Calcualte the total number of cells
        const unsigned int POPULATED_COUNT = FLAMEGPU->environment.getProperty<unsigned int>("POPULATED_COUNT");
        const unsigned int GRID_WIDTH = FLAMEGPU->environment.getProperty<unsigned int>("GRID_WIDTH");
        const unsigned int CELL_COUNT = GRID_WIDTH * GRID_WIDTH;
        // Generate a population of agents, which are just default initialised for now
        FLAMEGPU->agent("agent").newAgent();  // Bug #1422 workaround (error if resize empty agent vector)
        flamegpu::DeviceAgentVector population = FLAMEGPU->agent("agent").getPopulationData();
        population.resize(CELL_COUNT);

        // Select POPULATED_COUNT unique random integers in the range [0, CELL_COUNT), by shuffling the iota.
        std::vector<unsigned int> shuffledIota(CELL_COUNT);
        std::iota(shuffledIota.begin(), shuffledIota.end(), 0);
        std::shuffle(shuffledIota.begin(), shuffledIota.end(), rng);

        // Then iterate the shuffled iota, the first POPULATED_COUNT agents will randomly select a type/group. The remaining agents will not. 
        // The agent index provides the X and Y coordinate for the position.
        for (unsigned int elementIdx = 0; elementIdx < shuffledIota.size(); elementIdx++) {
            unsigned int idx = shuffledIota[elementIdx];
            flamegpu::AgentVector::Agent instance = population[idx];
            // the position can be computed from the index, given the width.
            unsigned int x = idx % GRID_WIDTH;
            unsigned int y = idx / GRID_WIDTH;
            instance.setVariable<unsigned int, 2>("pos", { x, y });

            // If the elementIDX is below the populated count, generated a populated type, otherwise it is unoccupied
            if (elementIdx < POPULATED_COUNT) {
                unsigned int type = uniformDist(rng) < 0.5 ? A : B;
                instance.setVariable<unsigned int>("type", type);
            }
            else {
                instance.setVariable<unsigned int>("type", UNOCCUPIED);
            }
            instance.setVariable<unsigned int>("happy", 0);
        }
    }

    // Agents output their type
    FLAMEGPU_AGENT_FUNCTION(output_type, flamegpu::MessageNone, flamegpu::MessageArray2D) {
        FLAMEGPU->message_out.setVariable<unsigned int>("type", FLAMEGPU->getVariable<unsigned int>("type"));
        FLAMEGPU->message_out.setIndex(FLAMEGPU->getVariable<unsigned int, 2>("pos", 0), FLAMEGPU->getVariable<unsigned int, 2>("pos", 1));
        return flamegpu::ALIVE;
    }

    // Agents decide whether they are happy or not and whether or not their space is available
    FLAMEGPU_AGENT_FUNCTION(determine_status, flamegpu::MessageArray2D, flamegpu::MessageNone) {
        const unsigned int my_x = FLAMEGPU->getVariable<unsigned int, 2>("pos", 0);
        const unsigned int my_y = FLAMEGPU->getVariable<unsigned int, 2>("pos", 1);

        unsigned int same_type_neighbours = 0;
        unsigned int diff_type_neighbours = 0;

        // Iterate 3x3 Moore neighbourhood (this does not include the central cell)
        unsigned int my_type = FLAMEGPU->getVariable<unsigned int>("type");
        for (auto message : FLAMEGPU->message_in.wrap(my_x, my_y)) {
            int message_type = message.getVariable<unsigned int>("type");
            same_type_neighbours += my_type == message_type;
            diff_type_neighbours += (my_type != message_type) && (message_type != UNOCCUPIED);
        }

        int isHappy = (static_cast<float>(same_type_neighbours) / (same_type_neighbours + diff_type_neighbours)) > THRESHOLD;
        FLAMEGPU->setVariable<unsigned int>("happy", isHappy);
        unsigned int my_next_type = ((my_type != UNOCCUPIED) && isHappy) ? my_type : UNOCCUPIED;
        FLAMEGPU->setVariable<unsigned int>("next_type", my_next_type);
        FLAMEGPU->setVariable<unsigned int>("movement_resolved", (my_type == UNOCCUPIED) || isHappy);
        unsigned int my_availability = (my_type == UNOCCUPIED) || (isHappy == 0);
        FLAMEGPU->setVariable<unsigned int>("available", my_availability);

        return flamegpu::ALIVE;
    }
    FLAMEGPU_AGENT_FUNCTION_CONDITION(is_available) {
        return FLAMEGPU->getVariable<unsigned int>("available") != 0;
    }
    FLAMEGPU_AGENT_FUNCTION(output_available_locations, flamegpu::MessageNone, flamegpu::MessageArray) {
        FLAMEGPU->message_out.setIndex(FLAMEGPU->getIndex());
        FLAMEGPU->message_out.setVariable<flamegpu::id_t>("id", FLAMEGPU->getID());
        return flamegpu::ALIVE;
    }

    FLAMEGPU_HOST_FUNCTION(count_available_spaces) {
        FLAMEGPU->environment.setProperty<unsigned int>("spaces_available", FLAMEGPU->agent("agent").count<unsigned int>("available", 1));
    }

    FLAMEGPU_AGENT_FUNCTION_CONDITION(is_moving) {
        const bool movementResolved = FLAMEGPU->getVariable<unsigned int>("movement_resolved");
        return !movementResolved;
    }
    FLAMEGPU_AGENT_FUNCTION(bid_for_location, flamegpu::MessageArray, flamegpu::MessageBucket) {
        // Select a location
        unsigned int selected_index = FLAMEGPU->random.uniform<unsigned int>(0, FLAMEGPU->environment.getProperty<unsigned int>("spaces_available") - 1);

        // Get the location at that index
        const auto message = FLAMEGPU->message_in.at(selected_index);
        const flamegpu::id_t selected_location = message.getVariable<flamegpu::id_t>("id");

        // Bid for that location
        FLAMEGPU->message_out.setKey(selected_location - 1);
        FLAMEGPU->message_out.setVariable<flamegpu::id_t>("id", FLAMEGPU->getID());
        FLAMEGPU->message_out.setVariable<unsigned int>("type", FLAMEGPU->getVariable<unsigned int>("type"));
        return flamegpu::ALIVE;
    }
    // @todo - device exception triggered when running 
    FLAMEGPU_AGENT_FUNCTION(select_winners, flamegpu::MessageBucket, flamegpu::MessageArray) {
        // First agent in the bucket wins
        for (const auto message : FLAMEGPU->message_in(FLAMEGPU->getID() - 1)) {
            flamegpu::id_t winning_id = message.getVariable<flamegpu::id_t>("id");
            FLAMEGPU->setVariable<unsigned int>("next_type", message.getVariable<unsigned int>("type"));
            FLAMEGPU->setVariable<unsigned int>("available", 0);
            FLAMEGPU->message_out.setIndex(winning_id - 1);
            FLAMEGPU->message_out.setVariable<unsigned int>("won", 1);
            break;
        }
        return flamegpu::ALIVE;
    }

    FLAMEGPU_AGENT_FUNCTION(has_moved, flamegpu::MessageArray, flamegpu::MessageNone) {
        const auto message = FLAMEGPU->message_in.at(FLAMEGPU->getID() - 1);
        if (message.getVariable<unsigned int>("won")) {
            FLAMEGPU->setVariable<unsigned int>("movement_resolved", 1);
        }
        return flamegpu::ALIVE;
    }

    FLAMEGPU_EXIT_CONDITION(movement_resolved) {
        return (FLAMEGPU->agent("agent").count<unsigned int>("movement_resolved", 0) == 0) ? flamegpu::EXIT : flamegpu::CONTINUE;
    }

    FLAMEGPU_AGENT_FUNCTION(update_locations, flamegpu::MessageNone, flamegpu::MessageNone) {
        FLAMEGPU->setVariable<unsigned int>("type", FLAMEGPU->getVariable<unsigned int>("next_type"));
        return flamegpu::ALIVE;
    }

}  // namespace

// Run an individual simulation, using
const SchellingArray2Di32RunData run_schelling_array2D_i32(
    const std::int32_t DEVICE,
    const std::uint64_t SEED,
    const std::uint32_t STEPS,
    const std::uint32_t POPULATED_COUNT,
    const std::uint32_t GRID_WIDTH,
    const bool VALIDATION) {
    // construct and start recording a timer for the full model definition and execution
    auto timer = flamegpu::detail::SteadyClockTimer();
    timer.start();

    flamegpu::util::nvtx::Range("main");
    flamegpu::detail::SteadyClockTimer mainTimer = {};
    mainTimer.start();
    flamegpu::detail::SteadyClockTimer prePopulationTimer = {};
    prePopulationTimer.start();

    // Define the model
    flamegpu::ModelDescription model("Schelling_segregation");

    // Define the message list(s)
    flamegpu::MessageArray2D::Description message = model.newMessage<flamegpu::MessageArray2D>("type_message");
    message.newVariable<unsigned int>("type");
    message.setDimensions(GRID_WIDTH, GRID_WIDTH);

    // Define the agent types
    // Agents representing the cells.
    flamegpu::AgentDescription  agent = model.newAgent("agent");
    agent.newVariable<unsigned int, 2>("pos");
    agent.newVariable<unsigned int>("type");
    agent.newVariable<unsigned int>("next_type");
    agent.newVariable<unsigned int>("happy");
    agent.newVariable<unsigned int>("available");
    agent.newVariable<unsigned int>("movement_resolved");
    // Functions
    agent.newFunction("output_type", output_type).setMessageOutput("type_message");
    agent.newFunction("determine_status", determine_status).setMessageInput("type_message");
    agent.newFunction("update_locations", update_locations);


    // Define a submodel for conflict resolution for agent movement
    // This is necessary for parallel random movement of agents, to resolve conflict between agents moving to the same location
    flamegpu::ModelDescription submodel("plan_movement");
    // Submodels require an exit condition function, so they do not run forever
    submodel.addExitCondition(movement_resolved);
    {
        // Define the submodel environment
        flamegpu::EnvironmentDescription env = submodel.Environment();
        env.newProperty<unsigned int>("spaces_available", 0);

        // Define message lists used within the submodel
        {
            flamegpu::MessageArray::Description message = submodel.newMessage<flamegpu::MessageArray>("available_location_message");
            message.newVariable<flamegpu::id_t>("id");
            message.setLength(GRID_WIDTH*GRID_WIDTH);
        }
        {
            flamegpu::MessageBucket::Description message = submodel.newMessage<flamegpu::MessageBucket>("intent_to_move_message");
            message.newVariable<flamegpu::id_t>("id");
            message.newVariable<unsigned int>("type");
            message.setBounds(0, GRID_WIDTH * GRID_WIDTH);
        }
        {
            flamegpu::MessageArray::Description message = submodel.newMessage<flamegpu::MessageArray>("movement_won_message");
            message.newVariable<unsigned int>("won");
            message.setLength(GRID_WIDTH*GRID_WIDTH);
        }

        // Define agents within the submodel
        flamegpu::AgentDescription  agent = submodel.newAgent("agent");
        agent.newVariable<unsigned int, 2>("pos");
        agent.newVariable<unsigned int>("type");
        agent.newVariable<unsigned int>("next_type");
        agent.newVariable<unsigned int>("happy");
        agent.newVariable<unsigned int>("available");
        agent.newVariable<unsigned int>("movement_resolved");

        // Functions
        auto outputLocationsFunction = agent.newFunction("output_available_locations", output_available_locations);
        outputLocationsFunction.setMessageOutput("available_location_message");
        outputLocationsFunction.setFunctionCondition(is_available);

        auto bidFunction = agent.newFunction("bid_for_location", bid_for_location);
        bidFunction.setFunctionCondition(is_moving);
        bidFunction.setMessageInput("available_location_message");
        bidFunction.setMessageOutput("intent_to_move_message");

        auto selectWinnersFunction = agent.newFunction("select_winners", select_winners);
        selectWinnersFunction.setMessageInput("intent_to_move_message");
        selectWinnersFunction.setMessageOutput("movement_won_message");
        selectWinnersFunction.setMessageOutputOptional(true);

        agent.newFunction("has_moved", has_moved).setMessageInput("movement_won_message");

        // Specify control flow for the submodel (@todo - dependencies)
        // Available agents output their location (indexed by thread ID)
        {
            flamegpu::LayerDescription layer = submodel.newLayer();
            layer.addAgentFunction(output_available_locations);
        }
        // Count the number of available spaces
        {
            flamegpu::LayerDescription layer = submodel.newLayer();
            layer.addHostFunction(count_available_spaces);
        }
        // Unhappy agents bid for a new location
        {
            flamegpu::LayerDescription layer = submodel.newLayer();
            layer.addAgentFunction(bid_for_location);
        }
        // Available locations check if anyone wants to move to them. If so, approve one and mark as unavailable
        // Update next type to the type of the mover
        // Output a message to inform the mover that they have been successful
        {
            flamegpu::LayerDescription layer = submodel.newLayer();
            layer.addAgentFunction(select_winners);
        }
        // Movers mark themselves as resolved
        {
            flamegpu::LayerDescription layer = submodel.newLayer();
            layer.addAgentFunction(has_moved);
        }
    }

    // Attach the submodel to the model, 
    flamegpu::SubModelDescription plan_movement = model.newSubModel("plan_movement", submodel);
    // Bind the agents within the submodel to the same agents outside of the submodel
    plan_movement.bindAgent("agent", "agent", true, true);

    // Add the in-built population init function
    {
        flamegpu::EnvironmentDescription env = model.Environment();
        env.newProperty<unsigned int>("POPULATED_COUNT", POPULATED_COUNT);
        env.newProperty<unsigned int>("GRID_WIDTH", GRID_WIDTH);
        model.addInitFunction(create_population);
    }

    // Define the control flow of the outer/parent model (@todo - use dependencies)
    {   // Layer #1
        flamegpu::LayerDescription layer = model.newLayer();
        layer.addAgentFunction(output_type);
    }
    {   // Layer #2
        flamegpu::LayerDescription layer = model.newLayer();
        layer.addAgentFunction(determine_status);
    }
    {
        flamegpu::LayerDescription layer = model.newLayer();
        layer.addSubModel(plan_movement);
    }
    {
        flamegpu::LayerDescription layer = model.newLayer();
        layer.addAgentFunction(update_locations);
    }
    {   // Trying calling this again to fix vis
        flamegpu::LayerDescription layer = model.newLayer();
        layer.addAgentFunction(determine_status);
    }

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
    SchellingArray2Di32RunData outputs;
    outputs.device = DEVICE;
    outputs.seed = SEED;
    outputs.steps = STEPS;
    outputs.agent_count = GRID_WIDTH * GRID_WIDTH;
    outputs.populated_count = POPULATED_COUNT;
    outputs.grid_width = GRID_WIDTH;
    outputs.validation = VALIDATION;
    outputs.agent_updates = GRID_WIDTH * GRID_WIDTH * STEPS;
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
