#[test_only]
module swarm_logistics::drone_registry_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use swarm_logistics::drone_registry;
    use swarm_logistics::drone;

    const DRONE_OWNER: address = @0xDEADBEEF;

    #[test]
    fun test_drone_registration() {
        let mut scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            // Test drone registration
            let (drone, financials, capability) = drone_registry::register_drone_for_test(
                b"DJI-Mavic-Pro".to_string(),
                drone::fully_autonomous(),
                95, // High autonomy
                2000, // 2kg payload
                15000, // 15km range
                b"San Francisco Bay Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Verify drone was created correctly
            assert!(drone::drone_owner(&drone) == DRONE_OWNER, 0);
            assert!(drone::autonomy_level(&drone) == 95, 1);
            assert!(drone::payload_capacity(&drone) == 2000, 2);
            assert!(drone::operation_mode(&drone) == drone::fully_autonomous(), 3);

            // Verify capability was created
            assert!(drone_registry::can_provide_emergency_assistance(&drone, &capability) == true, 4);

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(financials, DRONE_OWNER);
            transfer::public_transfer(capability, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_autonomous_order_evaluation() {
        let mut scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let (drone, financials, capability) = drone_registry::register_drone_for_test(
                b"Autonomous-Evaluator".to_string(),
                drone::fully_autonomous(),
                90,
                1500,
                12000,
                b"Test Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Test autonomous order evaluation - should accept
            let (should_accept, estimated_time) = drone_registry::evaluate_order_autonomous(
                &drone,
                b"37.7749,-122.4194".to_string(), // Pickup
                b"37.7849,-122.4094".to_string(), // Dropoff
                1000, // 1kg package (within capacity)
                2000000000, // 2 SUI payment (good profit margin)
                0, // Standard priority
                &clock
            );

            assert!(should_accept == true, 0);
            assert!(estimated_time > 0, 1);

            // Test with overweight package - should reject
            let (should_accept_heavy, _) = drone_registry::evaluate_order_autonomous(
                &drone,
                b"37.7749,-122.4194".to_string(),
                b"37.7849,-122.4094".to_string(),
                2000, // 2kg package (exceeds 1.5kg capacity)
                2000000000,
                0,
                &clock
            );

            assert!(should_accept_heavy == false, 2);

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(financials, DRONE_OWNER);
            transfer::public_transfer(capability, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_drone_self_status_update() {
        let mut scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let (mut drone, financials, capability) = drone_registry::register_drone_for_test(
                b"Self-Managing-Drone".to_string(),
                drone::hybrid(),
                75, // Sufficient autonomy for self-management
                1800,
                14000,
                b"Test Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Test self status update
            drone_registry::update_self_status(
                &mut drone,
                &capability,
                drone::status_busy(),
                b"37.7849,-122.4094".to_string(), // New location
                85, // New battery level
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify updates
            assert!(drone::drone_status(&drone) == drone::status_busy(), 0);
            assert!(drone::current_location(&drone) == b"37.7849,-122.4094".to_string(), 1);
            assert!(drone::drone_battery_level(&drone) == 85, 2);

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(financials, DRONE_OWNER);
            transfer::public_transfer(capability, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_autonomous_maintenance_scheduling() {
        let mut scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let (mut drone, mut financials, capability) = drone_registry::register_drone_for_test(
                b"Maintenance-Drone".to_string(),
                drone::fully_autonomous(),
                85,
                1600,
                13000,
                b"Test Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Add some funds to maintenance fund first
            // Note: In a real scenario, this would be done through revenue
            // For testing, we'll assume the drone has earned maintenance funds

            // Test maintenance scheduling
            drone_registry::schedule_autonomous_maintenance(
                &mut drone,
                &mut financials,
                1, // Routine maintenance
                0, // No cost for this test
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify maintenance was scheduled
            assert!(drone::drone_status(&drone) == drone::status_maintenance(), 0);

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(financials, DRONE_OWNER);
            transfer::public_transfer(capability, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_emergency_assistance_capability() {
        let mut scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            // High autonomy drone - should be capable of emergency assistance
            let (drone_high, financials_high, capability_high) = drone_registry::register_drone_for_test(
                b"Emergency-Responder".to_string(),
                drone::fully_autonomous(),
                95, // High autonomy
                2000,
                15000,
                b"Emergency Zone".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Low autonomy drone - should not be capable
            let (drone_low, financials_low, capability_low) = drone_registry::register_drone_for_test(
                b"Basic-Drone".to_string(),
                drone::teleoperated(),
                40, // Low autonomy
                1000,
                8000,
                b"Basic Zone".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Test emergency assistance capability
            assert!(drone_registry::can_provide_emergency_assistance(&drone_high, &capability_high) == true, 0);
            assert!(drone_registry::can_provide_emergency_assistance(&drone_low, &capability_low) == false, 1);

            transfer::public_transfer(drone_high, DRONE_OWNER);
            transfer::public_transfer(financials_high, DRONE_OWNER);
            transfer::public_transfer(capability_high, DRONE_OWNER);
            transfer::public_transfer(drone_low, DRONE_OWNER);
            transfer::public_transfer(financials_low, DRONE_OWNER);
            transfer::public_transfer(capability_low, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_drone_stats_tracking() {
        let scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let (drone, financials, capability) = drone_registry::register_drone_for_test(
                b"Stats-Tracker".to_string(),
                drone::fully_autonomous(),
                88,
                1700,
                12500,
                b"Stats Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Get initial stats
            let (delivery_count, success_rate, earnings, reputation) = drone_registry::get_drone_stats(&drone);

            // Verify initial stats
            assert!(delivery_count == 0, 0);
            assert!(success_rate == 100, 1); // Starts at 100%
            assert!(earnings == 0, 2);
            assert!(reputation == 100, 3); // Starts at 100

            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(financials, DRONE_OWNER);
            transfer::public_transfer(capability, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_invalid_autonomy_registration() {
        let scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            // This should fail due to invalid autonomy level
            let (_drone, _financials, _capability) = drone_registry::register_drone_for_test(
                b"Invalid-Drone".to_string(),
                drone::fully_autonomous(),
                150, // Invalid: > 100
                2000,
                15000,
                b"Test Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
} 