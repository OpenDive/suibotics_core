#[test_only]
module swarm_logistics::drone_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use swarm_logistics::drone;

    const DRONE_OWNER: address = @0xDEADBEEF;

    #[test]
    fun test_drone_creation() {
        let scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone = drone::new_drone(
                DRONE_OWNER,
                drone::fully_autonomous(),
                85, // 85% autonomy level
                1500, // 1.5kg payload
                10000, // 10km range
                b"Test Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Test basic properties
            assert!(drone::drone_owner(&drone) == DRONE_OWNER, 0);
            assert!(drone::autonomy_level(&drone) == 85, 1);
            assert!(drone::payload_capacity(&drone) == 1500, 2);
            assert!(drone::max_range(&drone) == 10000, 3);
            assert!(drone::operation_mode(&drone) == drone::fully_autonomous(), 4);
            assert!(drone::drone_status(&drone) == drone::status_available(), 5);
            assert!(drone::drone_battery_level(&drone) == 100, 6);

            transfer::public_transfer(drone, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_drone_status_updates() {
        let scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let mut drone = drone::new_drone(
                DRONE_OWNER,
                drone::hybrid(),
                70,
                2000,
                15000,
                b"Test Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Test status changes
            drone::set_drone_status(&mut drone, drone::status_busy());
            assert!(drone::drone_status(&drone) == drone::status_busy(), 0);

            drone::set_drone_status(&mut drone, drone::status_charging());
            assert!(drone::drone_status(&drone) == drone::status_charging(), 1);

            // Test location updates
            drone::set_drone_location(&mut drone, b"37.7849,-122.4094".to_string());
            assert!(drone::current_location(&drone) == b"37.7849,-122.4094".to_string(), 2);

            // Test battery updates
            drone::set_drone_battery_level(&mut drone, 75);
            assert!(drone::drone_battery_level(&drone) == 75, 3);

            transfer::public_transfer(drone, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_drone_validation_functions() {
        let scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone = drone::new_drone(
                DRONE_OWNER,
                drone::fully_autonomous(),
                90,
                2000,
                12000,
                b"Test Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            // Test validation functions
            assert!(drone::is_drone_available(&drone) == true, 0);
            assert!(drone::can_carry_payload(&drone, 1500) == true, 1);
            assert!(drone::can_carry_payload(&drone, 2500) == false, 2);
            assert!(drone::is_valid_operation_mode(drone::fully_autonomous()) == true, 3);
            assert!(drone::is_valid_operation_mode(5) == false, 4);
            assert!(drone::is_valid_autonomy_level(90) == true, 5);
            assert!(drone::is_valid_autonomy_level(150) == false, 6);

            transfer::public_transfer(drone, DRONE_OWNER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_drone_financials() {
        let scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone_id = sui::object::id_from_address(@0x1);
            let mut financials = drone::new_drone_financials(
                drone_id,
                test_scenario::ctx(scenario)
            );

            // Test initial state
            assert!(drone::financials_maintenance_fund(&financials) == 0, 0);

            // Test cost operations
            drone::add_operational_cost(&mut financials, 1000);
            drone::deduct_maintenance_fund(&mut financials, 0); // Should not fail with 0

            transfer::public_transfer(financials, DRONE_OWNER);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_invalid_autonomy_level() {
        let scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            // This should fail because autonomy level > 100
            let _drone = drone::new_drone(
                DRONE_OWNER,
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