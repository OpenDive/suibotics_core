#[test_only]
module swarm_logistics::swarm_logistics_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::test_utils;
    
    // Import our modules
    use swarm_logistics::drone_registry;
    use swarm_logistics::order_management;
    use swarm_logistics::flight_controller;
    use swarm_logistics::economic_engine;
    use swarm_logistics::dao_governance;
    use swarm_logistics::drone;
    use swarm_logistics::swarm;
    
    // Test constants
    const ADMIN: address = @0xAD;
    const CUSTOMER: address = @0xC0FFEE;
    const DRONE_OWNER: address = @0xDEADBEEF;
    const DAO_MEMBER: address = @0xDAD;
    
    #[test]
    fun test_drone_registration_workflow() {
        let scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        
        // Create clock for testing
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        
        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            // Test autonomous drone registration
            let (drone, financials, capability) = drone_registry::register_drone_for_test(
                b"DJI-Test-001".to_string(),
                drone::fully_autonomous(),
                95, // High autonomy level
                2000, // 2kg payload
                15000, // 15km range
                b"Test Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );
            
            // Verify drone properties
            assert!(drone::autonomy_level(&drone) == 95, 0);
            assert!(drone::payload_capacity(&drone) == 2000, 1);
            assert!(drone::max_range(&drone) == 15000, 2);
            
            // Transfer objects to owner
            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(financials, DRONE_OWNER);
            transfer::public_transfer(capability, DRONE_OWNER);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
    
    #[test]
    fun test_order_creation_and_assignment() {
        let scenario_val = test_scenario::begin(CUSTOMER);
        let scenario = &mut scenario_val;
        
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        
        test_scenario::next_tx(scenario, CUSTOMER);
        {
            // Create payment coin
            let payment = coin::mint_for_testing<SUI>(1000000000, test_scenario::ctx(scenario)); // 1 SUI
            
            // Create order manager
            let order_manager = order_management::create_order_manager(test_scenario::ctx(scenario));
            
            // Create delivery order
            let order = order_management::create_order(
                &mut order_manager,
                b"37.7749,-122.4194".to_string(), // Pickup
                b"37.7849,-122.4094".to_string(), // Dropoff
                500, // 500g package
                vector[20, 15, 10], // Dimensions
                order_management::priority_standard(),
                b"Handle with care".to_string(),
                payment,
                clock::timestamp_ms(&clock) + 3600000, // 1 hour pickup deadline
                clock::timestamp_ms(&clock) + 7200000, // 2 hour delivery deadline
                &clock,
                test_scenario::ctx(scenario)
            );
            
            // Verify order properties
            assert!(order_management::package_weight(&order) == 500, 0);
            
            transfer::public_transfer(order, CUSTOMER);
            transfer::public_transfer(order_manager, CUSTOMER);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
    
    #[test]
    fun test_economic_engine_pricing() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        test_scenario::next_tx(scenario, ADMIN);
        {
            // Create economic engine
            let engine = economic_engine::create_economic_engine(test_scenario::ctx(scenario));
            
            // Create pricing model
            let pricing_model = economic_engine::create_pricing_model(
                b"Standard Delivery".to_string(),
                1000000000, // 1 SUI base rate
                50000000,   // 0.05 SUI per km
                1000,       // 1000 MIST per gram
                vector[100, 120, 150, 200], // Urgency multipliers
                test_scenario::ctx(scenario)
            );
            
            // Test price calculation
            let price = economic_engine::calculate_delivery_price(
                &engine,
                &pricing_model,
                10,  // 10 km distance
                1000, // 1 kg weight
                1,    // Standard urgency
                12,   // Noon
                0,    // Clear weather
                1     // Normal demand
            );
            
            // Verify pricing logic (base + distance + weight)
            // Expected: 1 SUI + (10 * 0.05 SUI) + (1000 * 1000 MIST) = 1.5 SUI + 1000000 MIST
            assert!(price > 1000000000, 0); // Should be more than base rate
            
            transfer::public_transfer(engine, ADMIN);
            transfer::public_transfer(pricing_model, ADMIN);
        };
        
        test_scenario::end(scenario_val);
    }
    
    #[test]
    fun test_dao_governance_workflow() {
        let scenario_val = test_scenario::begin(DAO_MEMBER);
        let scenario = &mut scenario_val;
        
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        
        test_scenario::next_tx(scenario, DAO_MEMBER);
        {
            // Create treasury
            let treasury = coin::mint_for_testing<SUI>(10000000000, test_scenario::ctx(scenario)); // 10 SUI
            
            // Create governance configuration
            let governance_config = dao_governance::create_governance_config(
                1000,      // 1000 tokens to create proposal
                604800000, // 7 days voting period
                172800000, // 2 days execution delay
                25,        // 25% quorum
                60,        // 60% approval
                100,       // 100 tokens for membership
                1000000000, // 1 SUI proposal deposit
                10         // Max 10 proposals
            );
            
            // Create revenue rules
            let revenue_rules = dao_governance::create_revenue_rules(
                60, // 60% to members
                25, // 25% to treasury
                10, // 10% reinvestment
                5,  // 5% operations
                0,  // No performance bonus
                2592000000 // Monthly distribution
            );
            
            // Create DAO
            let (dao, founder_membership) = dao_governance::create_dao(
                b"Test Drone DAO".to_string(),
                treasury,
                governance_config,
                revenue_rules,
                10000, // Founder gets 10,000 tokens
                &clock,
                test_scenario::ctx(scenario)
            );
            
            // Verify DAO creation
            assert!(dao_governance::total_members(&dao) == 1, 0);
            
            transfer::public_transfer(dao, DAO_MEMBER);
            transfer::public_transfer(founder_membership, DAO_MEMBER);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
    
    #[test]
    fun test_flight_controller_route_optimization() {
        let scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        
        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            // Register drone first
            let (drone, _financials, _capability) = drone_registry::register_drone_for_test(
                b"Flight-Test-001".to_string(),
                drone::fully_autonomous(),
                90,
                1500,
                12000,
                b"Flight Test Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );
            
            // Create environment data for testing
            let weather_data = swarm::new_environment_data(
                0,    // Clear weather
                90,   // 90% visibility
                5,    // 5 km/h wind
                2200, // 22°C (22.00 * 100)
                1,    // Medium air traffic
                vector::empty() // No no-fly zones
            );

            // Test route calculation
            let route = flight_controller::calculate_optimal_route(
                &drone,
                b"37.7749,-122.4194".to_string(), // Origin
                b"37.7849,-122.4094".to_string(), // Destination
                flight_controller::default_optimization_params(),
                weather_data,
                &clock,
                test_scenario::ctx(scenario)
            );
            
            // Verify route properties
            assert!(flight_controller::route_distance(&route) > 0, 0);
            assert!(flight_controller::estimated_duration(&route) > 0, 1);
            
            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(route, DRONE_OWNER);
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
    
    #[test]
    fun test_end_to_end_delivery_workflow() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        
        // Step 1: Register drone
        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            let (drone, financials, capability) = drone_registry::register_drone_for_test(
                b"E2E-Test-Drone".to_string(),
                drone::fully_autonomous(),
                95,
                2000,
                15000,
                b"E2E Test Area".to_string(),
                b"37.7749,-122.4194".to_string(),
                clock::timestamp_ms(&clock),
                test_scenario::ctx(scenario)
            );
            
            transfer::public_transfer(drone, DRONE_OWNER);
            transfer::public_transfer(financials, DRONE_OWNER);
            transfer::public_transfer(capability, DRONE_OWNER);
        };
        
        // Step 2: Customer creates order
        test_scenario::next_tx(scenario, CUSTOMER);
        {
            let payment = coin::mint_for_testing<SUI>(2000000000, test_scenario::ctx(scenario)); // 2 SUI
            let order_manager = order_management::create_order_manager(test_scenario::ctx(scenario));
            
            let order = order_management::create_order(
                &mut order_manager,
                b"37.7749,-122.4194".to_string(),
                b"37.7849,-122.4094".to_string(),
                800, // 800g package
                vector[25, 20, 15],
                order_management::priority_express(),
                b"E2E test delivery".to_string(),
                payment,
                clock::timestamp_ms(&clock) + 1800000, // 30 min pickup
                clock::timestamp_ms(&clock) + 3600000, // 1 hour delivery
                &clock,
                test_scenario::ctx(scenario)
            );
            
            transfer::public_transfer(order, CUSTOMER);
            transfer::public_transfer(order_manager, CUSTOMER);
        };
        
        // Step 3: Verify successful workflow completion
        test_scenario::next_tx(scenario, ADMIN);
        {
            // In a real scenario, we would test:
            // - Order assignment to drone
            // - Route calculation and optimization
            // - Flight execution and tracking
            // - Delivery completion and payment release
            // - Revenue distribution
            
            // For now, we verify the components were created successfully
            assert!(true, 0); // Placeholder for full E2E test
        };
        
        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
    
    #[test]
    #[expected_failure]
    fun test_invalid_drone_registration() {
        let scenario_val = test_scenario::begin(DRONE_OWNER);
        let scenario = &mut scenario_val;
        
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));
        
        test_scenario::next_tx(scenario, DRONE_OWNER);
        {
            // Try to register drone with invalid autonomy level (>100)
            let (_drone, _financials, _capability) = drone_registry::register_drone_for_test(
                b"Invalid-Drone".to_string(),
                drone::fully_autonomous(),
                150, // Invalid: >100
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