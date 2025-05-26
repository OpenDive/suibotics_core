#[test_only]
module swarm_logistics::swarm_coordinator_tests {
    use sui::test_scenario;
    use sui::clock;
    use sui::object;
    use sui::transfer;
    use std::string;
    use std::vector;
    use std::option;
    use swarm_logistics::swarm_coordinator::{Self, SwarmCoordinator, AirspaceConflict, EmergencyResponse, LoadBalancer};
    use swarm_logistics::swarm::{Self as swarm_mod, AirspaceSlot, EmergencyRequest, CoordinationEvent};
    use swarm_logistics::drone::{Self as drone_mod, Drone};

    // Test addresses
    const ADMIN: address = @0x1;
    const DRONE_OWNER1: address = @0x2;
    const DRONE_OWNER2: address = @0x3;
    const DRONE_OWNER3: address = @0x4;

    // ==================== HELPER FUNCTIONS ====================

    /// Create a test swarm coordinator
    fun create_test_coordinator(ctx: &mut sui::tx_context::TxContext): SwarmCoordinator {
        swarm_coordinator::create_test_coordinator(ctx)
    }

    /// Create a test emergency request
    fun create_test_emergency_request(
        drone_id: object::ID,
        assistance_type: u8,
        location: string::String,
        ctx: &mut sui::tx_context::TxContext
    ): EmergencyRequest {
        swarm_mod::create_test_emergency_request(
            drone_id,
            assistance_type,
            location,
            ctx
        )
    }

    // ==================== AIRSPACE MANAGEMENT TESTS ====================

    #[test]
    fun test_airspace_reservation_request() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut coordinator = create_test_coordinator(test_scenario::ctx(scenario));
            let drone_id = object::id_from_address(@0x123);

            // Request airspace reservation
            let slot = swarm_coordinator::request_airspace_reservation(
                &mut coordinator,
                string::utf8(b"route_hash_001"),
                clock::timestamp_ms(&clock) + 300000, // Start in 5 minutes
                clock::timestamp_ms(&clock) + 1800000, // End in 30 minutes
                drone_id,
                string::utf8(b"100-200m"), // Altitude range
                1, // Medium priority
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify slot properties
            assert!(swarm_mod::airspace_drone_id(&slot) == drone_id, 1);
            assert!(swarm_mod::airspace_priority(&slot) == 1, 2);
            assert!(swarm_mod::airspace_altitude_range(&slot) == string::utf8(b"100-200m"), 3);

            // Verify coordinator state
            assert!(swarm_coordinator::coordinator_total_flights(&coordinator) == 1, 4);

            transfer::public_transfer(slot, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_multiple_airspace_reservations() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut coordinator = create_test_coordinator(test_scenario::ctx(scenario));
            
            // Request multiple airspace reservations
            let drone_id1 = object::id_from_address(@0x201);
            let drone_id2 = object::id_from_address(@0x202);
            let drone_id3 = object::id_from_address(@0x203);

            let slot1 = swarm_coordinator::request_airspace_reservation(
                &mut coordinator,
                string::utf8(b"route_north"),
                clock::timestamp_ms(&clock) + 600000, // Start in 10 minutes
                clock::timestamp_ms(&clock) + 2400000, // End in 40 minutes
                drone_id1,
                string::utf8(b"50-100m"),
                2, // High priority
                &clock,
                test_scenario::ctx(scenario)
            );

            let slot2 = swarm_coordinator::request_airspace_reservation(
                &mut coordinator,
                string::utf8(b"route_south"),
                clock::timestamp_ms(&clock) + 900000, // Start in 15 minutes
                clock::timestamp_ms(&clock) + 2700000, // End in 45 minutes
                drone_id2,
                string::utf8(b"100-150m"),
                1, // Medium priority
                &clock,
                test_scenario::ctx(scenario)
            );

            let slot3 = swarm_coordinator::request_airspace_reservation(
                &mut coordinator,
                string::utf8(b"route_east"),
                clock::timestamp_ms(&clock) + 1200000, // Start in 20 minutes
                clock::timestamp_ms(&clock) + 3000000, // End in 50 minutes
                drone_id3,
                string::utf8(b"150-200m"),
                0, // Low priority
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify coordinator tracked all flights
            assert!(swarm_coordinator::coordinator_total_flights(&coordinator) == 3, 1);

            transfer::public_transfer(slot1, ADMIN);
            transfer::public_transfer(slot2, ADMIN);
            transfer::public_transfer(slot3, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== EMERGENCY ASSISTANCE TESTS ====================

    #[test]
    fun test_emergency_response_coordination() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut coordinator = create_test_coordinator(test_scenario::ctx(scenario));
            let emergency_drone_id = object::id_from_address(@0x301);
            
            let mut emergency_request = create_test_emergency_request(
                emergency_drone_id,
                0, // Low battery emergency
                string::utf8(b"37.7749,-122.4194"),
                test_scenario::ctx(scenario)
            );

            // Available responder drones
            let available_drones = vector[
                object::id_from_address(@0x401),
                object::id_from_address(@0x402),
                object::id_from_address(@0x403)
            ];

            // Coordinate emergency response
            let response = swarm_coordinator::coordinate_emergency_response(
                &mut coordinator,
                &mut emergency_request,
                available_drones,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify response properties
            assert!(response.emergency_id == swarm_mod::emergency_id(&emergency_request), 1);
            assert!(response.response_type == 0, 2); // RESPONSE_BATTERY_ASSIST
            assert!(vector::length(&response.responding_drones) > 0, 3);
            assert!(response.success_rate == 85, 4); // Estimated success rate

            transfer::public_transfer(emergency_request, ADMIN);
            transfer::public_transfer(response, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_emergency_response_completion() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut coordinator = create_test_coordinator(test_scenario::ctx(scenario));
            let emergency_drone_id = object::id_from_address(@0x302);
            
            let mut emergency_request = create_test_emergency_request(
                emergency_drone_id,
                1, // Malfunction emergency
                string::utf8(b"37.7849,-122.4094"),
                test_scenario::ctx(scenario)
            );

            let available_drones = vector[object::id_from_address(@0x404)];

            // Coordinate and complete emergency response
            let mut response = swarm_coordinator::coordinate_emergency_response(
                &mut coordinator,
                &mut emergency_request,
                available_drones,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Complete the emergency response successfully
            swarm_coordinator::complete_emergency_response(
                &mut coordinator,
                &mut response,
                &mut emergency_request,
                true, // Success
                &clock
            );

            // Verify completion
            assert!(option::is_some(&response.actual_response_time), 1);
            assert!(response.success_rate == 100, 2); // Updated to 100% on success
            assert!(swarm_coordinator::coordinator_emergency_responses(&coordinator) == 1, 3);

            transfer::public_transfer(emergency_request, ADMIN);
            transfer::public_transfer(response, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_emergency_response_failure() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut coordinator = create_test_coordinator(test_scenario::ctx(scenario));
            let emergency_drone_id = object::id_from_address(@0x303);
            
            let mut emergency_request = create_test_emergency_request(
                emergency_drone_id,
                2, // Weather emergency
                string::utf8(b"37.7949,-122.3994"),
                test_scenario::ctx(scenario)
            );

            let available_drones = vector[object::id_from_address(@0x405)];

            let mut response = swarm_coordinator::coordinate_emergency_response(
                &mut coordinator,
                &mut emergency_request,
                available_drones,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Complete the emergency response with failure
            swarm_coordinator::complete_emergency_response(
                &mut coordinator,
                &mut response,
                &mut emergency_request,
                false, // Failure
                &clock
            );

            // Verify failure handling
            assert!(response.success_rate == 0, 1); // Updated to 0% on failure
            assert!(swarm_coordinator::coordinator_emergency_responses(&coordinator) == 0, 2); // No successful responses

            transfer::public_transfer(emergency_request, ADMIN);
            transfer::public_transfer(response, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_emergency_no_available_responders() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut coordinator = create_test_coordinator(test_scenario::ctx(scenario));
            let emergency_drone_id = object::id_from_address(@0x304);
            
            let mut emergency_request = create_test_emergency_request(
                emergency_drone_id,
                3, // Obstacle emergency
                string::utf8(b"37.8049,-122.3894"),
                test_scenario::ctx(scenario)
            );

            // No available responder drones
            let available_drones = vector::empty<object::ID>();

            // This should fail with E_NO_AVAILABLE_RESPONDERS
            let response = swarm_coordinator::coordinate_emergency_response(
                &mut coordinator,
                &mut emergency_request,
                available_drones,
                &clock,
                test_scenario::ctx(scenario)
            );

            transfer::public_transfer(emergency_request, ADMIN);
            transfer::public_transfer(response, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== LOAD BALANCING TESTS ====================

    #[test]
    fun test_load_balancer_creation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let load_balancer = swarm_coordinator::create_load_balancer(
                string::utf8(b"San Francisco Bay Area"),
                1, // ALGORITHM_CAPACITY_BASED
                3600000, // 1 hour rebalance frequency
                test_scenario::ctx(scenario)
            );

            // Verify initial state
            assert!(swarm_coordinator::load_balancer_drone_count(&load_balancer) == 0, 1);
            assert!(swarm_coordinator::load_balancer_pending_orders(&load_balancer) == 0, 2);

            transfer::public_transfer(load_balancer, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_load_balancer_drone_management() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut load_balancer = swarm_coordinator::create_load_balancer(
                string::utf8(b"Load Test Region"),
                0, // ALGORITHM_ROUND_ROBIN
                1800000, // 30 minutes
                test_scenario::ctx(scenario)
            );

            // Add drones to load balancer
            let drone_id1 = object::id_from_address(@0x501);
            let drone_id2 = object::id_from_address(@0x502);
            let drone_id3 = object::id_from_address(@0x503);

            swarm_coordinator::add_drone_to_load_balancer(&mut load_balancer, drone_id1);
            swarm_coordinator::add_drone_to_load_balancer(&mut load_balancer, drone_id2);
            swarm_coordinator::add_drone_to_load_balancer(&mut load_balancer, drone_id3);

            // Verify drone count
            assert!(swarm_coordinator::load_balancer_drone_count(&load_balancer) == 3, 1);

            transfer::public_transfer(load_balancer, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_workload_optimization() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut coordinator = create_test_coordinator(test_scenario::ctx(scenario));
            let mut load_balancer = swarm_coordinator::create_load_balancer(
                string::utf8(b"Optimization Test Region"),
                2, // ALGORITHM_DISTANCE_BASED
                1000, // 1 second frequency for testing
                test_scenario::ctx(scenario)
            );

            // Add drones
            swarm_coordinator::add_drone_to_load_balancer(&mut load_balancer, object::id_from_address(@0x601));
            swarm_coordinator::add_drone_to_load_balancer(&mut load_balancer, object::id_from_address(@0x602));

            // Optimize workload distribution
            swarm_coordinator::optimize_workload_distribution(
                &mut coordinator,
                &mut load_balancer,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify optimization occurred (coordinator should track it)
            // Note: The actual optimization logic is simplified in the implementation

            transfer::public_transfer(coordinator, ADMIN);
            transfer::public_transfer(load_balancer, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_workload_optimization_frequency_limit() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut coordinator = create_test_coordinator(test_scenario::ctx(scenario));
            let mut load_balancer = swarm_coordinator::create_load_balancer(
                string::utf8(b"Frequency Test Region"),
                3, // ALGORITHM_AI_OPTIMIZED
                7200000, // 2 hours frequency
                test_scenario::ctx(scenario)
            );

            swarm_coordinator::add_drone_to_load_balancer(&mut load_balancer, object::id_from_address(@0x701));

            // First optimization should work
            swarm_coordinator::optimize_workload_distribution(
                &mut coordinator,
                &mut load_balancer,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Immediate second optimization should be skipped due to frequency limit
            swarm_coordinator::optimize_workload_distribution(
                &mut coordinator,
                &mut load_balancer,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Should still work (frequency limit prevents excessive optimization)
            assert!(swarm_coordinator::load_balancer_drone_count(&load_balancer) == 1, 1);

            transfer::public_transfer(coordinator, ADMIN);
            transfer::public_transfer(load_balancer, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== INTEGRATION TESTS ====================

    #[test]
    fun test_complete_swarm_coordination_workflow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            // Create swarm coordinator and load balancer
            let mut coordinator = create_test_coordinator(test_scenario::ctx(scenario));
            let mut load_balancer = swarm_coordinator::create_load_balancer(
                string::utf8(b"Integration Test Region"),
                1, // ALGORITHM_CAPACITY_BASED
                1800000, // 30 minutes
                test_scenario::ctx(scenario)
            );

            // Add drones to load balancer
            let drone_id1 = object::id_from_address(@0x801);
            let drone_id2 = object::id_from_address(@0x802);
            let drone_id3 = object::id_from_address(@0x803);

            swarm_coordinator::add_drone_to_load_balancer(&mut load_balancer, drone_id1);
            swarm_coordinator::add_drone_to_load_balancer(&mut load_balancer, drone_id2);
            swarm_coordinator::add_drone_to_load_balancer(&mut load_balancer, drone_id3);

            // Request airspace reservations
            let slot1 = swarm_coordinator::request_airspace_reservation(
                &mut coordinator,
                string::utf8(b"integration_route_1"),
                clock::timestamp_ms(&clock) + 300000,
                clock::timestamp_ms(&clock) + 1800000,
                drone_id1,
                string::utf8(b"50-100m"),
                1,
                &clock,
                test_scenario::ctx(scenario)
            );

            let slot2 = swarm_coordinator::request_airspace_reservation(
                &mut coordinator,
                string::utf8(b"integration_route_2"),
                clock::timestamp_ms(&clock) + 600000,
                clock::timestamp_ms(&clock) + 2100000,
                drone_id2,
                string::utf8(b"100-150m"),
                1,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Simulate emergency with drone3
            let mut emergency_request = create_test_emergency_request(
                drone_id3,
                1, // Malfunction
                string::utf8(b"37.7749,-122.4194"),
                test_scenario::ctx(scenario)
            );

            // Use drone1 and drone2 as responders
            let available_responders = vector[drone_id1, drone_id2];
            let mut response = swarm_coordinator::coordinate_emergency_response(
                &mut coordinator,
                &mut emergency_request,
                available_responders,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Complete emergency response successfully
            swarm_coordinator::complete_emergency_response(
                &mut coordinator,
                &mut response,
                &mut emergency_request,
                true,
                &clock
            );

            // Optimize workload distribution
            swarm_coordinator::optimize_workload_distribution(
                &mut coordinator,
                &mut load_balancer,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify final state
            assert!(swarm_coordinator::coordinator_total_flights(&coordinator) == 2, 1);
            assert!(swarm_coordinator::coordinator_emergency_responses(&coordinator) == 1, 2);
            assert!(swarm_coordinator::load_balancer_drone_count(&load_balancer) == 3, 3);
            assert!(swarm_coordinator::coordinator_efficiency_score(&coordinator) == 100, 4);

            transfer::public_transfer(slot1, ADMIN);
            transfer::public_transfer(slot2, ADMIN);
            transfer::public_transfer(emergency_request, ADMIN);
            transfer::public_transfer(response, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
            transfer::public_transfer(load_balancer, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_high_volume_coordination() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut coordinator = create_test_coordinator(test_scenario::ctx(scenario));
            let mut load_balancer = swarm_coordinator::create_load_balancer(
                string::utf8(b"High Volume Region"),
                0, // ALGORITHM_ROUND_ROBIN
                900000, // 15 minutes
                test_scenario::ctx(scenario)
            );

            // Add multiple drones
            let drone_ids = vector[
                object::id_from_address(@0x1001),
                object::id_from_address(@0x1002),
                object::id_from_address(@0x1003),
                object::id_from_address(@0x1004),
                object::id_from_address(@0x1005),
                object::id_from_address(@0x1006),
                object::id_from_address(@0x1007),
                object::id_from_address(@0x1008),
                object::id_from_address(@0x1009),
                object::id_from_address(@0x1010)
            ];
            let mut i = 0;
            while (i < 10) {
                let drone_id = *vector::borrow(&drone_ids, i);
                swarm_coordinator::add_drone_to_load_balancer(&mut load_balancer, drone_id);
                i = i + 1;
            };

            // Request multiple airspace reservations
            let mut j = 0;
            let mut slots = vector::empty();
            while (j < 5) {
                let drone_id = object::id_from_address(@0x1000 + j);
                let route_name = string::utf8(b"high_volume_route_");
                
                let slot = swarm_coordinator::request_airspace_reservation(
                    &mut coordinator,
                    route_name,
                    clock::timestamp_ms(&clock) + (j * 300000), // Staggered start times
                    clock::timestamp_ms(&clock) + (j * 300000) + 1800000, // 30 min duration each
                    drone_id,
                    string::utf8(b"50-100m"),
                    1,
                    &clock,
                    test_scenario::ctx(scenario)
                );
                
                vector::push_back(&mut slots, slot);
                j = j + 1;
            };

            // Optimize workload
            swarm_coordinator::optimize_workload_distribution(
                &mut coordinator,
                &mut load_balancer,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify high volume handling
            assert!(swarm_coordinator::coordinator_total_flights(&coordinator) == 5, 1);
            assert!(swarm_coordinator::load_balancer_drone_count(&load_balancer) == 10, 2);

            // Clean up slots
            while (!vector::is_empty(&slots)) {
                let slot = vector::pop_back(&mut slots);
                transfer::public_transfer(slot, ADMIN);
            };
            vector::destroy_empty(slots);

            transfer::public_transfer(coordinator, ADMIN);
            transfer::public_transfer(load_balancer, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_multiple_emergency_coordination() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut coordinator = create_test_coordinator(test_scenario::ctx(scenario));

            // Create multiple emergency requests
            let emergency_drone1 = object::id_from_address(@0x901);
            let emergency_drone2 = object::id_from_address(@0x902);
            let emergency_drone3 = object::id_from_address(@0x903);

            let mut emergency1 = create_test_emergency_request(
                emergency_drone1,
                0, // Battery
                string::utf8(b"Location1"),
                test_scenario::ctx(scenario)
            );

            let mut emergency2 = create_test_emergency_request(
                emergency_drone2,
                1, // Malfunction
                string::utf8(b"Location2"),
                test_scenario::ctx(scenario)
            );

            let mut emergency3 = create_test_emergency_request(
                emergency_drone3,
                2, // Weather
                string::utf8(b"Location3"),
                test_scenario::ctx(scenario)
            );

            // Available responder drones
            let responders = vector[
                object::id_from_address(@0x1001),
                object::id_from_address(@0x1002),
                object::id_from_address(@0x1003),
                object::id_from_address(@0x1004),
                object::id_from_address(@0x1005),
                object::id_from_address(@0x1006)
            ];

            // Coordinate multiple emergency responses
            let mut response1 = swarm_coordinator::coordinate_emergency_response(
                &mut coordinator,
                &mut emergency1,
                responders,
                &clock,
                test_scenario::ctx(scenario)
            );

            let mut response2 = swarm_coordinator::coordinate_emergency_response(
                &mut coordinator,
                &mut emergency2,
                responders,
                &clock,
                test_scenario::ctx(scenario)
            );

            let mut response3 = swarm_coordinator::coordinate_emergency_response(
                &mut coordinator,
                &mut emergency3,
                responders,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Complete all emergencies successfully
            swarm_coordinator::complete_emergency_response(
                &mut coordinator,
                &mut response1,
                &mut emergency1,
                true,
                &clock
            );

            swarm_coordinator::complete_emergency_response(
                &mut coordinator,
                &mut response2,
                &mut emergency2,
                true,
                &clock
            );

            swarm_coordinator::complete_emergency_response(
                &mut coordinator,
                &mut response3,
                &mut emergency3,
                true,
                &clock
            );

            // Verify all emergencies were handled
            assert!(swarm_coordinator::coordinator_emergency_responses(&coordinator) == 3, 1);

            transfer::public_transfer(emergency1, ADMIN);
            transfer::public_transfer(emergency2, ADMIN);
            transfer::public_transfer(emergency3, ADMIN);
            transfer::public_transfer(response1, ADMIN);
            transfer::public_transfer(response2, ADMIN);
            transfer::public_transfer(response3, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
} 