#[test_only]
module swarm_logistics::order_management_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use swarm_logistics::order_management;
    use swarm_logistics::drone;

    const CUSTOMER: address = @0xC0FFEE;
    const DRONE_OWNER: address = @0xDEADBEEF;

    #[test]
    fun test_order_creation() {
        let mut scenario_val = test_scenario::begin(CUSTOMER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, CUSTOMER);
        {
            let payment = coin::mint_for_testing<SUI>(2000000000, test_scenario::ctx(scenario)); // 2 SUI
            let mut order_manager = order_management::create_order_manager(test_scenario::ctx(scenario));

            let order = order_management::create_order(
                &mut order_manager,
                b"37.7749,-122.4194".to_string(), // Pickup location
                b"37.7849,-122.4094".to_string(), // Dropoff location
                800, // 800g package
                vector[25, 20, 15], // Dimensions: 25x20x15 cm
                1, // Express priority
                b"Fragile electronics".to_string(),
                payment,
                clock::timestamp_ms(&clock) + 1800000, // 30 min pickup deadline
                clock::timestamp_ms(&clock) + 3600000, // 1 hour delivery deadline
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify order properties
            assert!(order_management::customer(&order) == CUSTOMER, 0);
            assert!(order_management::package_weight(&order) == 800, 1);
            assert!(order_management::priority_level(&order) == 1, 2);
            assert!(order_management::payment_amount(&order) == 2000000000, 3);
            assert!(order_management::pickup_location(&order) == b"37.7749,-122.4194".to_string(), 4);
            assert!(order_management::dropoff_location(&order) == b"37.7849,-122.4094".to_string(), 5);

            // Verify manager stats
            assert!(order_management::get_total_orders(&order_manager) == 1, 6);
            assert!(order_management::get_active_orders(&order_manager) == 1, 7);

            transfer::public_transfer(order, CUSTOMER);
            transfer::public_transfer(order_manager, CUSTOMER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_order_assignment() {
        let mut scenario_val = test_scenario::begin(CUSTOMER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        // Create order
        test_scenario::next_tx(scenario, CUSTOMER);
        {
            let payment = coin::mint_for_testing<SUI>(1500000000, test_scenario::ctx(scenario)); // 1.5 SUI
            let mut order_manager = order_management::create_order_manager(test_scenario::ctx(scenario));

            let order = order_management::create_order(
                &mut order_manager,
                b"37.7749,-122.4194".to_string(),
                b"37.7849,-122.4094".to_string(),
                600, // 600g package
                vector[20, 15, 10],
                0, // Standard priority
                b"Standard delivery".to_string(),
                payment,
                clock::timestamp_ms(&clock) + 3600000, // 1 hour pickup
                clock::timestamp_ms(&clock) + 7200000, // 2 hour delivery
                &clock,
                test_scenario::ctx(scenario)
            );

            transfer::public_transfer(order, CUSTOMER);
            transfer::public_transfer(order_manager, CUSTOMER);
        };

        // Create drone and assign order
        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let drone = drone::new_drone(
                DRONE_OWNER,
                drone::fully_autonomous(),
                90,
                2000, // Can carry 2kg
                15000,
                b"Service Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );

            transfer::public_transfer(drone, DRONE_OWNER);
        };

        // Test assignment
        test_scenario::next_tx(scenario, CUSTOMER);
        {
            let mut order = test_scenario::take_from_sender<order_management::DeliveryOrder>(scenario);
            let drone = test_scenario::take_from_address<drone::Drone>(scenario, DRONE_OWNER);

            let assignment = order_management::assign_order_to_drone(
                &mut order,
                &drone,
                clock::timestamp_ms(&clock) + 1800000, // 30 min estimated completion
                100000, // Estimated fuel cost
                5000,   // 5km estimated distance
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify assignment
            assert!(order_management::is_order_assigned(&order) == true, 0);

            test_scenario::return_to_sender(scenario, order);
            test_scenario::return_to_address(DRONE_OWNER, drone);
            transfer::public_transfer(assignment, CUSTOMER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_order_status_updates() {
        let mut scenario_val = test_scenario::begin(CUSTOMER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, CUSTOMER);
        {
            let payment = coin::mint_for_testing<SUI>(1000000000, test_scenario::ctx(scenario)); // 1 SUI
            let mut order_manager = order_management::create_order_manager(test_scenario::ctx(scenario));

            let mut order = order_management::create_order(
                &mut order_manager,
                b"37.7749,-122.4194".to_string(),
                b"37.7849,-122.4094".to_string(),
                400,
                vector[15, 10, 8],
                0,
                b"Test package".to_string(),
                payment,
                clock::timestamp_ms(&clock) + 3600000,
                clock::timestamp_ms(&clock) + 7200000,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Test status updates
            order_management::update_order_status(
                &mut order,
                2, // Assigned status
                b"Order assigned to drone".to_string(),
                &clock,
                test_scenario::ctx(scenario)
            );

            assert!(order_management::order_status(&order) == 2, 0);

            order_management::update_order_status(
                &mut order,
                3, // Picked up status
                b"Package picked up".to_string(),
                &clock,
                test_scenario::ctx(scenario)
            );

            assert!(order_management::order_status(&order) == 3, 1);

            transfer::public_transfer(order, CUSTOMER);
            transfer::public_transfer(order_manager, CUSTOMER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_order_cancellation() {
        let mut scenario_val = test_scenario::begin(CUSTOMER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, CUSTOMER);
        {
            let payment = coin::mint_for_testing<SUI>(1000000000, test_scenario::ctx(scenario)); // 1 SUI
            let mut order_manager = order_management::create_order_manager(test_scenario::ctx(scenario));

            let mut order = order_management::create_order(
                &mut order_manager,
                b"37.7749,-122.4194".to_string(),
                b"37.7849,-122.4094".to_string(),
                300,
                vector[10, 8, 5],
                0,
                b"Cancellable order".to_string(),
                payment,
                clock::timestamp_ms(&clock) + 3600000,
                clock::timestamp_ms(&clock) + 7200000,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Cancel the order
            order_management::cancel_order(
                &mut order_manager,
                &mut order,
                test_scenario::ctx(scenario)
            );

            // Verify cancellation
            assert!(order_management::order_status(&order) == 7, 0); // Cancelled status
            assert!(order_management::get_active_orders(&order_manager) == 0, 1);

            transfer::public_transfer(order, CUSTOMER);
            transfer::public_transfer(order_manager, CUSTOMER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_invalid_package_weight() {
        let mut scenario_val = test_scenario::begin(CUSTOMER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, CUSTOMER);
        {
            let payment = coin::mint_for_testing<SUI>(1000000000, test_scenario::ctx(scenario));
            let mut order_manager = order_management::create_order_manager(test_scenario::ctx(scenario));

            // This should fail because package weight > 5kg limit
            let _order = order_management::create_order(
                &mut order_manager,
                b"37.7749,-122.4194".to_string(),
                b"37.7849,-122.4094".to_string(),
                6000, // 6kg - exceeds 5kg limit
                vector[30, 25, 20],
                0,
                b"Too heavy package".to_string(),
                payment,
                clock::timestamp_ms(&clock) + 3600000,
                clock::timestamp_ms(&clock) + 7200000,
                &clock,
                test_scenario::ctx(scenario)
            );
            
            // These transfers won't be reached due to expected failure above
            transfer::public_transfer(_order, CUSTOMER);
            transfer::public_transfer(order_manager, CUSTOMER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_insufficient_payment() {
        let mut scenario_val = test_scenario::begin(CUSTOMER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, CUSTOMER);
        {
            let payment = coin::mint_for_testing<SUI>(50000000, test_scenario::ctx(scenario)); // 0.05 SUI - too low
            let mut order_manager = order_management::create_order_manager(test_scenario::ctx(scenario));

            // This should fail because payment < minimum
            let _order = order_management::create_order(
                &mut order_manager,
                b"37.7749,-122.4194".to_string(),
                b"37.7849,-122.4094".to_string(),
                500,
                vector[15, 10, 8],
                0,
                b"Underpaid order".to_string(),
                payment,
                clock::timestamp_ms(&clock) + 3600000,
                clock::timestamp_ms(&clock) + 7200000,
                &clock,
                test_scenario::ctx(scenario)
            );
            
            // These transfers won't be reached due to expected failure above
            transfer::public_transfer(_order, CUSTOMER);
            transfer::public_transfer(order_manager, CUSTOMER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
} 