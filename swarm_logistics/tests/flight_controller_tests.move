#[test_only]
module swarm_logistics::flight_controller_tests {
    use sui::test_scenario;
    use sui::clock;
    use sui::object;
    use sui::transfer;
    use std::string;
    use std::vector;
    use std::option;
    use swarm_logistics::flight_controller::{Self, FlightRoute, NavigationState, OptimizationParams, Obstacle, AutonomousDecision};
    use swarm_logistics::drone::{Self as drone_mod, Drone};
    use swarm_logistics::swarm::{Self as swarm_mod, EnvironmentData};

    // Test addresses
    const ADMIN: address = @0x1;
    const DRONE_OWNER: address = @0x2;

    // ==================== ROUTE OPTIMIZATION TESTS ====================

    #[test]
    fun test_optimal_route_calculation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            // Create a test drone
            let drone = drone_mod::new_drone(
                DRONE_OWNER,
                drone_mod::fully_autonomous(),
                85,
                2000,
                15000,
                string::utf8(b"Test Area"),
                string::utf8(b"37.7749,-122.4194"),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Create optimization parameters
            let optimization_params = flight_controller::default_optimization_params();

            // Calculate optimal route
            let route = flight_controller::calculate_optimal_route(
                &drone,
                string::utf8(b"37.7749,-122.4194"), // San Francisco
                string::utf8(b"37.7849,-122.4094"), // Nearby destination
                optimization_params,
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    80, // 80% visibility
                    15, // 15 km/h wind
                    2500, // 25°C temperature (25 * 100)
                    1, // Medium air traffic
                    vector::empty() // No no-fly zones
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify route properties
            assert!(flight_controller::route_status(&route) == 0, 1); // ROUTE_PLANNED
            assert!(flight_controller::route_distance(&route) == 5000, 2); // 5km
            assert!(flight_controller::route_estimated_time(&route) == 1800000, 3); // 30 minutes
            assert!(flight_controller::route_estimated_energy(&route) == 25, 4); // 25% battery
            assert!(flight_controller::route_optimization_score(&route) > 70, 5); // Good score

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_route_with_bad_weather() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone = drone_mod::new_drone(
                DRONE_OWNER,
                drone_mod::fully_autonomous(),
                90,
                1800,
                12000,
                string::utf8(b"Test Area"),
                string::utf8(b"37.7749,-122.4194"),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            let optimization_params = flight_controller::default_optimization_params();

            let route = flight_controller::calculate_optimal_route(
                &drone,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                optimization_params,
                swarm_mod::new_environment_data(
                    4, // Storm
                    30, // Low visibility
                    45, // High wind
                    1000, // 10°C temperature (10 * 100)
                    3, // Critical air traffic
                    vector::empty() // No no-fly zones
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Bad weather should result in lower optimization score
            assert!(flight_controller::route_optimization_score(&route) < 80, 1);

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_emergency_optimization_params() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone = drone_mod::new_drone(
                DRONE_OWNER,
                drone_mod::fully_autonomous(),
                95,
                2000,
                15000,
                string::utf8(b"Emergency Zone"),
                string::utf8(b"37.7749,-122.4194"),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Use emergency optimization parameters
            let emergency_params = flight_controller::emergency_optimization_params();

            let route = flight_controller::calculate_optimal_route(
                &drone,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                emergency_params,
                swarm_mod::new_environment_data(
                    1, // Light rain
                    70, // Good visibility
                    20, // Moderate wind
                    2000, // 20°C temperature (20 * 100)
                    1, // Medium air traffic
                    vector::empty() // No no-fly zones
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Emergency route should still be calculated successfully
            assert!(flight_controller::route_status(&route) == 0, 1);

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== NAVIGATION STATE TESTS ====================

    #[test]
    fun test_navigation_initialization() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone = drone_mod::new_drone(
                DRONE_OWNER,
                drone_mod::fully_autonomous(),
                85,
                2000,
                15000,
                string::utf8(b"Test Area"),
                string::utf8(b"37.7749,-122.4194"),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            let optimization_params = flight_controller::default_optimization_params();

            let route = flight_controller::calculate_optimal_route(
                &drone,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                optimization_params,
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Initialize navigation state
            let nav_state = flight_controller::initialize_navigation(
                &drone,
                &route,
                string::utf8(b"37.7749,-122.4194"),
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify navigation state properties
            assert!(flight_controller::navigation_current_position(&nav_state) == string::utf8(b"37.7749,-122.4194"), 1);
            assert!(flight_controller::navigation_flight_mode(&nav_state) == 0, 2); // FLIGHT_AUTO
            assert!(flight_controller::navigation_obstacles_count(&nav_state) == 0, 3);
            assert!(flight_controller::navigation_decisions_count(&nav_state) == 0, 4);

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
            transfer::public_transfer(nav_state, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_navigation_state_updates() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone = drone_mod::new_drone(
                DRONE_OWNER,
                drone_mod::fully_autonomous(),
                85,
                2000,
                15000,
                string::utf8(b"Test Area"),
                string::utf8(b"37.7749,-122.4194"),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            let optimization_params = flight_controller::default_optimization_params();

            let route = flight_controller::calculate_optimal_route(
                &drone,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                optimization_params,
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            let mut nav_state = flight_controller::initialize_navigation(
                &drone,
                &route,
                string::utf8(b"37.7749,-122.4194"),
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Update navigation state
            flight_controller::update_navigation_state(
                &mut nav_state,
                string::utf8(b"37.7799,-122.4144"), // New position
                120, // New altitude
                45,  // New speed
                90,  // New heading
                vector::empty(), // No obstacles
                swarm_mod::new_environment_data(
                    1, // Light rain
                    75, // Good visibility
                    25, // Moderate wind
                    2200, // 22°C temperature
                    2, // High air traffic
                    vector::empty()
                ),
                &clock
            );

            // Verify updates
            assert!(flight_controller::navigation_current_position(&nav_state) == string::utf8(b"37.7799,-122.4144"), 1);

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
            transfer::public_transfer(nav_state, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== AUTONOMOUS DECISION TESTS ====================

    #[test]
    fun test_autonomous_decision_making() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone = drone_mod::new_drone(
                DRONE_OWNER,
                drone_mod::fully_autonomous(),
                90,
                2000,
                15000,
                string::utf8(b"Test Area"),
                string::utf8(b"37.7749,-122.4194"),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            let optimization_params = flight_controller::default_optimization_params();

            let mut route = flight_controller::calculate_optimal_route(
                &drone,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                optimization_params,
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            let mut nav_state = flight_controller::initialize_navigation(
                &drone,
                &route,
                string::utf8(b"37.7749,-122.4194"),
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Make autonomous decision
            let decision = flight_controller::make_autonomous_decision(
                &mut nav_state,
                &mut route,
                &clock
            );

            // Verify decision was recorded
            assert!(flight_controller::navigation_decisions_count(&nav_state) == 1, 1);

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
            transfer::public_transfer(nav_state, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== OBSTACLE AVOIDANCE TESTS ====================

    #[test]
    fun test_obstacle_avoidance_aircraft() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone = drone_mod::new_drone(
                DRONE_OWNER,
                drone_mod::fully_autonomous(),
                90,
                2000,
                15000,
                string::utf8(b"Test Area"),
                string::utf8(b"37.7749,-122.4194"),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            let optimization_params = flight_controller::default_optimization_params();

            let mut route = flight_controller::calculate_optimal_route(
                &drone,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                optimization_params,
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            let mut nav_state = flight_controller::initialize_navigation(
                &drone,
                &route,
                string::utf8(b"37.7749,-122.4194"),
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Create aircraft obstacle
            let mut obstacles = vector::empty();
            vector::push_back(&mut obstacles, flight_controller::create_test_obstacle(
                0, // OBSTACLE_AIRCRAFT
                string::utf8(b"37.7759,-122.4154"),
                100, // 100m diameter
                2,   // High threat level
                clock::timestamp_ms(&clock)
            ));

            // Update navigation with obstacles
            flight_controller::update_navigation_state(
                &mut nav_state,
                string::utf8(b"37.7749,-122.4194"),
                100, 50, 0,
                obstacles,
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock
            );

            // Execute obstacle avoidance
            let obstacle = flight_controller::create_test_obstacle(
                0, // OBSTACLE_AIRCRAFT
                string::utf8(b"37.7759,-122.4154"),
                100,
                2,
                clock::timestamp_ms(&clock)
            );

            flight_controller::execute_obstacle_avoidance(
                &mut nav_state,
                &mut route,
                &obstacle,
                &clock
            );

            // Verify avoidance was executed (decisions should be recorded)
            assert!(flight_controller::navigation_decisions_count(&nav_state) > 0, 1);

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
            transfer::public_transfer(nav_state, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_critical_obstacle_emergency_landing() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone = drone_mod::new_drone(
                DRONE_OWNER,
                drone_mod::fully_autonomous(),
                90,
                2000,
                15000,
                string::utf8(b"Test Area"),
                string::utf8(b"37.7749,-122.4194"),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            let optimization_params = flight_controller::default_optimization_params();

            let mut route = flight_controller::calculate_optimal_route(
                &drone,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                optimization_params,
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            let mut nav_state = flight_controller::initialize_navigation(
                &drone,
                &route,
                string::utf8(b"37.7749,-122.4194"),
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Create critical obstacle
            let critical_obstacle = flight_controller::create_test_obstacle(
                3, // OBSTACLE_NO_FLY_ZONE
                string::utf8(b"37.7749,-122.4194"), // Same location as drone
                50,
                3, // Critical threat level
                clock::timestamp_ms(&clock)
            );

            // Execute emergency avoidance
            flight_controller::execute_obstacle_avoidance(
                &mut nav_state,
                &mut route,
                &critical_obstacle,
                &clock
            );

            // Should trigger emergency landing mode
            assert!(flight_controller::navigation_flight_mode(&nav_state) == 2, 1); // FLIGHT_EMERGENCY

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
            transfer::public_transfer(nav_state, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== ROUTE STATUS MANAGEMENT TESTS ====================

    #[test]
    fun test_route_status_progression() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone = drone_mod::new_drone(
                DRONE_OWNER,
                drone_mod::fully_autonomous(),
                85,
                2000,
                15000,
                string::utf8(b"Test Area"),
                string::utf8(b"37.7749,-122.4194"),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            let optimization_params = flight_controller::default_optimization_params();

            let mut route = flight_controller::calculate_optimal_route(
                &drone,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                optimization_params,
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Test route status progression
            assert!(flight_controller::route_status(&route) == 0, 1); // ROUTE_PLANNED

            flight_controller::set_route_status(&mut route, 1); // ROUTE_ACTIVE
            assert!(flight_controller::route_status(&route) == 1, 2);

            flight_controller::advance_waypoint(&mut route);
            
            flight_controller::set_route_status(&mut route, 2); // ROUTE_COMPLETED
            assert!(flight_controller::route_status(&route) == 2, 3);

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== INTEGRATION TESTS ====================

    #[test]
    fun test_complete_flight_workflow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            // Create drone
            let drone = drone_mod::new_drone(
                DRONE_OWNER,
                drone_mod::fully_autonomous(),
                95,
                2000,
                15000,
                string::utf8(b"Test Area"),
                string::utf8(b"37.7749,-122.4194"),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Calculate route
            let optimization_params = flight_controller::default_optimization_params();
            let mut route = flight_controller::calculate_optimal_route(
                &drone,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                optimization_params,
                swarm_mod::new_environment_data(
                    1, // Light rain
                    70, // Good visibility
                    20, // Moderate wind
                    2200, // 22°C temperature
                    2, // High air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Initialize navigation
            let mut nav_state = flight_controller::initialize_navigation(
                &drone,
                &route,
                string::utf8(b"37.7749,-122.4194"),
                swarm_mod::new_environment_data(
                    1, // Light rain
                    70, // Good visibility
                    20, // Moderate wind
                    2200, // 22°C temperature
                    2, // High air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Start flight
            flight_controller::set_route_status(&mut route, 1); // ROUTE_ACTIVE

            // Simulate flight progress with updates
            flight_controller::update_navigation_state(
                &mut nav_state,
                string::utf8(b"37.7799,-122.4144"), // Midway position
                110, 40, 45,
                vector::empty(),
                swarm_mod::new_environment_data(
                    2, // Snow
                    50, // Reduced visibility
                    35, // Higher wind
                    2000, // 20°C temperature
                    3, // Critical air traffic
                    vector::empty()
                ),
                &clock
            );

            // Make autonomous decision based on weather change
            let _decision = flight_controller::make_autonomous_decision(
                &mut nav_state,
                &mut route,
                &clock
            );

            // Complete flight
            flight_controller::advance_waypoint(&mut route);
            flight_controller::set_route_status(&mut route, 2); // ROUTE_COMPLETED

            // Verify final state
            assert!(flight_controller::route_status(&route) == 2, 1);
            assert!(flight_controller::navigation_decisions_count(&nav_state) >= 1, 2);

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
            transfer::public_transfer(nav_state, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== ERROR CONDITION TESTS ====================

    #[test]
    #[expected_failure(abort_code = 4)]
    fun test_insufficient_battery_failure() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            // Create drone with low battery
            let mut drone = drone_mod::new_drone(
                DRONE_OWNER,
                drone_mod::fully_autonomous(),
                85,
                2000,
                15000,
                string::utf8(b"Test Area"),
                string::utf8(b"37.7749,-122.4194"),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Set battery to low level
            drone_mod::set_drone_battery_level(&mut drone, 25); // Below 30% threshold

            let optimization_params = flight_controller::default_optimization_params();

            // This should fail due to insufficient battery
            let route = flight_controller::calculate_optimal_route(
                &drone,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                optimization_params,
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_invalid_coordinates_failure() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone = drone_mod::new_drone(
                DRONE_OWNER,
                drone_mod::fully_autonomous(),
                85,
                2000,
                15000,
                string::utf8(b"Test Area"),
                string::utf8(b"37.7749,-122.4194"),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            let optimization_params = flight_controller::default_optimization_params();

            // This should fail due to empty coordinates
            let route = flight_controller::calculate_optimal_route(
                &drone,
                string::utf8(b""), // Empty origin
                string::utf8(b"37.7849,-122.4094"),
                optimization_params,
                swarm_mod::new_environment_data(
                    0, // Clear weather
                    90, // Excellent visibility
                    15, // Light wind
                    2500, // 25°C temperature
                    1, // Medium air traffic
                    vector::empty()
                ),
                &clock,
                test_scenario::ctx(scenario)
            );

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
} 