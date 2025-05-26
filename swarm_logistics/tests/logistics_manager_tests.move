#[test_only]
module swarm_logistics::logistics_manager_tests {
    use sui::test_scenario;
    use sui::clock;
    use sui::object;
    use sui::transfer;
    use std::string;
    use std::vector;
    use std::option;
    use swarm_logistics::logistics_manager::{Self, LogisticsManager, PackageTracker, RouteOptimizer, BackupCoordinator};
    use swarm_logistics::delivery::{Self as delivery_mod, DeliveryOrder};
    use swarm_logistics::drone::{Self as drone_mod, Drone};

    // Test addresses
    const ADMIN: address = @0x1;
    const CUSTOMER: address = @0x2;
    const DRONE_OWNER: address = @0x3;

    // ==================== HELPER FUNCTIONS ====================

    /// Create a test logistics manager
    #[test_only]
    public fun create_test_logistics_manager(ctx: &mut sui::tx_context::TxContext): LogisticsManager {
        logistics_manager::create_test_logistics_manager(ctx)
    }

    /// Create a test delivery order
    fun create_test_delivery_order(
        customer: address,
        pickup_location: string::String,
        dropoff_location: string::String,
        weight: u64,
        ctx: &mut sui::tx_context::TxContext
    ): DeliveryOrder {
        delivery_mod::create_test_delivery_order(
            customer,
            pickup_location,
            dropoff_location,
            weight,
            ctx
        )
    }

    // ==================== PACKAGE TRACKING TESTS ====================

    #[test]
    fun test_package_tracker_creation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut manager = create_test_logistics_manager(test_scenario::ctx(scenario));
            
            // Create a test delivery order
            let order = create_test_delivery_order(
                CUSTOMER,
                string::utf8(b"37.7749,-122.4194"), // San Francisco
                string::utf8(b"37.7849,-122.4094"), // Nearby location
                1500, // 1.5kg package
                test_scenario::ctx(scenario)
            );

            // Create package tracker
            let tracker = logistics_manager::create_package_tracker(
                &mut manager,
                &order,
                string::utf8(b"PKG001"),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify tracker properties
            assert!(logistics_manager::tracker_current_status(&tracker) == 0, 1); // PACKAGE_CREATED
            assert!(logistics_manager::tracker_current_location(&tracker) == string::utf8(b"37.7749,-122.4194"), 2);
            assert!(logistics_manager::tracker_alerts_count(&tracker) == 0, 3);

            // Verify manager state
            assert!(logistics_manager::manager_active_deliveries(&manager) == 1, 4);

            transfer::public_transfer(order, CUSTOMER);
            transfer::public_transfer(tracker, ADMIN);
            transfer::public_transfer(manager, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_package_tracking_updates() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut manager = create_test_logistics_manager(test_scenario::ctx(scenario));
            
            let order = create_test_delivery_order(
                CUSTOMER,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                800, // 800g package
                test_scenario::ctx(scenario)
            );

            let mut tracker = logistics_manager::create_package_tracker(
                &mut manager,
                &order,
                string::utf8(b"PKG002"),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Update tracking status to picked up
            logistics_manager::update_package_tracking(
                &mut tracker,
                1, // PACKAGE_PICKED_UP
                string::utf8(b"37.7749,-122.4194"), // Same pickup location
                option::some(object::id_from_address(@0x123)), // Drone ID
                string::utf8(b"Package picked up by drone"),
                string::utf8(b"{\"temperature\":23,\"humidity\":50}"),
                &clock
            );

            assert!(logistics_manager::tracker_current_status(&tracker) == 1, 1);

            // Update to in transit
            logistics_manager::update_package_tracking(
                &mut tracker,
                2, // PACKAGE_IN_TRANSIT
                string::utf8(b"37.7799,-122.4144"), // Midway location
                option::some(object::id_from_address(@0x123)),
                string::utf8(b"Package in transit"),
                string::utf8(b"{\"temperature\":25,\"humidity\":45,\"altitude\":100}"),
                &clock
            );

            assert!(logistics_manager::tracker_current_status(&tracker) == 2, 2);
            assert!(logistics_manager::tracker_current_location(&tracker) == string::utf8(b"37.7799,-122.4144"), 3);

            transfer::public_transfer(order, CUSTOMER);
            transfer::public_transfer(tracker, ADMIN);
            transfer::public_transfer(manager, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_package_delivery_completion() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut manager = create_test_logistics_manager(test_scenario::ctx(scenario));
            
            let order = create_test_delivery_order(
                CUSTOMER,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                1200,
                test_scenario::ctx(scenario)
            );

            let mut tracker = logistics_manager::create_package_tracker(
                &mut manager,
                &order,
                string::utf8(b"PKG003"),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Complete delivery
            logistics_manager::complete_package_delivery(
                &mut manager,
                &mut tracker,
                string::utf8(b"SIGNATURE_HASH_123"),
                &clock
            );

            // Verify completion
            assert!(logistics_manager::tracker_current_status(&tracker) == 3, 1); // PACKAGE_DELIVERED
            assert!(logistics_manager::manager_active_deliveries(&manager) == 0, 2);
            assert!(logistics_manager::manager_completed_deliveries(&manager) == 1, 3);
            assert!(logistics_manager::manager_success_rate(&manager) == 100, 4);

            transfer::public_transfer(order, CUSTOMER);
            transfer::public_transfer(tracker, ADMIN);
            transfer::public_transfer(manager, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_package_delivery_failure() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut manager = create_test_logistics_manager(test_scenario::ctx(scenario));
            
            let order = create_test_delivery_order(
                CUSTOMER,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                900,
                test_scenario::ctx(scenario)
            );

            let mut tracker = logistics_manager::create_package_tracker(
                &mut manager,
                &order,
                string::utf8(b"PKG004"),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Handle delivery failure
            logistics_manager::handle_package_failure(
                &mut manager,
                &mut tracker,
                string::utf8(b"Drone malfunction during delivery"),
                &clock
            );

            // Verify failure handling
            assert!(logistics_manager::tracker_current_status(&tracker) == 4, 1); // PACKAGE_FAILED
            assert!(logistics_manager::manager_active_deliveries(&manager) == 0, 2);
            assert!(logistics_manager::manager_completed_deliveries(&manager) == 0, 3);

            transfer::public_transfer(order, CUSTOMER);
            transfer::public_transfer(tracker, ADMIN);
            transfer::public_transfer(manager, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== ROUTE OPTIMIZATION TESTS ====================

    #[test]
    fun test_route_optimizer_creation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let optimizer = logistics_manager::create_route_optimizer(
                string::utf8(b"San Francisco Bay Area"),
                3600000, // 1 hour optimization frequency
                test_scenario::ctx(scenario)
            );

            // Verify initial state
            assert!(logistics_manager::optimizer_efficiency_score(&optimizer) == 100, 1);
            assert!(logistics_manager::optimizer_pending_packages(&optimizer) == 0, 2);

            transfer::public_transfer(optimizer, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_route_optimization_with_packages() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut manager = create_test_logistics_manager(test_scenario::ctx(scenario));
            let mut optimizer = logistics_manager::create_route_optimizer(
                string::utf8(b"Test Region"),
                1800000, // 30 minutes
                test_scenario::ctx(scenario)
            );

            // Add packages to optimizer
            let package_id1 = object::id_from_address(@0x001);
            let package_id2 = object::id_from_address(@0x002);
            let package_id3 = object::id_from_address(@0x003);

            logistics_manager::add_package_to_optimizer(&mut optimizer, package_id1);
            logistics_manager::add_package_to_optimizer(&mut optimizer, package_id2);
            logistics_manager::add_package_to_optimizer(&mut optimizer, package_id3);

            assert!(logistics_manager::optimizer_pending_packages(&optimizer) == 3, 1);

            // Create available drones
            let available_drones = vector[
                object::id_from_address(@0x101),
                object::id_from_address(@0x102)
            ];

            // Optimize routes
            logistics_manager::optimize_delivery_routes(
                &mut manager,
                &mut optimizer,
                available_drones,
                &clock
            );

            // Verify optimization occurred
            let efficiency = logistics_manager::optimizer_efficiency_score(&optimizer);
            assert!(efficiency > 0, 2);

            transfer::public_transfer(manager, ADMIN);
            transfer::public_transfer(optimizer, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_route_optimization_frequency() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut manager = create_test_logistics_manager(test_scenario::ctx(scenario));
            let mut optimizer = logistics_manager::create_route_optimizer(
                string::utf8(b"Frequency Test Region"),
                7200000, // 2 hours frequency
                test_scenario::ctx(scenario)
            );

            let available_drones = vector[object::id_from_address(@0x201)];

            // First optimization should work
            logistics_manager::optimize_delivery_routes(
                &mut manager,
                &mut optimizer,
                available_drones,
                &clock
            );

            // Immediate second optimization should be skipped due to frequency limit
            logistics_manager::optimize_delivery_routes(
                &mut manager,
                &mut optimizer,
                available_drones,
                &clock
            );

            // Should still have efficiency score from first optimization
            assert!(logistics_manager::optimizer_efficiency_score(&optimizer) > 0, 1);

            transfer::public_transfer(manager, ADMIN);
            transfer::public_transfer(optimizer, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== BACKUP COORDINATION TESTS ====================

    #[test]
    fun test_backup_coordinator_creation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let coordinator = logistics_manager::create_backup_coordinator(
                string::utf8(b"Emergency Response Zone"),
                test_scenario::ctx(scenario)
            );

            // Verify initial state
            assert!(logistics_manager::coordinator_available_backups(&coordinator) == 0, 1);
            assert!(logistics_manager::coordinator_backup_success_rate(&coordinator) == 100, 2);

            transfer::public_transfer(coordinator, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_backup_drone_management() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut coordinator = logistics_manager::create_backup_coordinator(
                string::utf8(b"Backup Management Zone"),
                test_scenario::ctx(scenario)
            );

            // Add backup drones
            let backup_drone1 = object::id_from_address(@0x301);
            let backup_drone2 = object::id_from_address(@0x302);
            let backup_drone3 = object::id_from_address(@0x303);

            logistics_manager::add_backup_drone(&mut coordinator, backup_drone1);
            logistics_manager::add_backup_drone(&mut coordinator, backup_drone2);
            logistics_manager::add_backup_drone(&mut coordinator, backup_drone3);

            assert!(logistics_manager::coordinator_available_backups(&coordinator) == 3, 1);

            transfer::public_transfer(coordinator, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_backup_drone_activation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut manager = create_test_logistics_manager(test_scenario::ctx(scenario));
            let mut coordinator = logistics_manager::create_backup_coordinator(
                string::utf8(b"Activation Test Zone"),
                test_scenario::ctx(scenario)
            );

            // Add backup drone
            let backup_drone_id = object::id_from_address(@0x401);
            logistics_manager::add_backup_drone(&mut coordinator, backup_drone_id);

            // Activate backup for failed delivery
            let original_drone_id = object::id_from_address(@0x501);
            let order_id = object::id_from_address(@0x601);

            let assignment_opt = logistics_manager::activate_backup_drone(
                &mut manager,
                &mut coordinator,
                original_drone_id,
                order_id,
                0, // BACKUP_MALFUNCTION
                string::utf8(b"37.7799,-122.4144"), // Handoff location
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify activation
            assert!(option::is_some(&assignment_opt), 1);
            assert!(logistics_manager::coordinator_available_backups(&coordinator) == 0, 2); // Backup was used

            transfer::public_transfer(manager, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_backup_activation_no_available() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut manager = create_test_logistics_manager(test_scenario::ctx(scenario));
            let mut coordinator = logistics_manager::create_backup_coordinator(
                string::utf8(b"No Backup Zone"),
                test_scenario::ctx(scenario)
            );

            // Try to activate backup when none available
            let assignment_opt = logistics_manager::activate_backup_drone(
                &mut manager,
                &mut coordinator,
                object::id_from_address(@0x502),
                object::id_from_address(@0x602),
                1, // BACKUP_BATTERY
                string::utf8(b"37.7799,-122.4144"),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Should return none
            assert!(option::is_none(&assignment_opt), 1);

            transfer::public_transfer(manager, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_backup_handoff_completion() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut manager = create_test_logistics_manager(test_scenario::ctx(scenario));
            let mut coordinator = logistics_manager::create_backup_coordinator(
                string::utf8(b"Handoff Test Zone"),
                test_scenario::ctx(scenario)
            );

            // Add and activate backup
            logistics_manager::add_backup_drone(&mut coordinator, object::id_from_address(@0x403));
            
            let _assignment_opt = logistics_manager::activate_backup_drone(
                &mut manager,
                &mut coordinator,
                object::id_from_address(@0x503),
                object::id_from_address(@0x603),
                2, // BACKUP_WEATHER
                string::utf8(b"37.7799,-122.4144"),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Complete handoff successfully
            logistics_manager::complete_backup_handoff(
                &mut coordinator,
                0, // First assignment
                true, // Success
                &clock
            );

            // Verify success rate is still 100%
            assert!(logistics_manager::coordinator_backup_success_rate(&coordinator) == 100, 1);

            transfer::public_transfer(manager, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== INTEGRATION TESTS ====================

    #[test]
    fun test_complete_logistics_workflow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            // Create logistics components
            let mut manager = create_test_logistics_manager(test_scenario::ctx(scenario));
            let mut optimizer = logistics_manager::create_route_optimizer(
                string::utf8(b"Integration Test Region"),
                1800000,
                test_scenario::ctx(scenario)
            );
            let mut coordinator = logistics_manager::create_backup_coordinator(
                string::utf8(b"Integration Test Region"),
                test_scenario::ctx(scenario)
            );

            // Create delivery order and package tracker
            let order = create_test_delivery_order(
                CUSTOMER,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                1000,
                test_scenario::ctx(scenario)
            );

            let mut tracker = logistics_manager::create_package_tracker(
                &mut manager,
                &order,
                string::utf8(b"PKG_INTEGRATION"),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Add package to route optimization
            let package_id = object::id_from_address(@0x701);
            logistics_manager::add_package_to_optimizer(&mut optimizer, package_id);

            // Add backup drone
            logistics_manager::add_backup_drone(&mut coordinator, object::id_from_address(@0x801));

            // Optimize routes
            let available_drones = vector[object::id_from_address(@0x901)];
            logistics_manager::optimize_delivery_routes(
                &mut manager,
                &mut optimizer,
                available_drones,
                &clock
            );

            // Simulate package pickup and transit
            logistics_manager::update_package_tracking(
                &mut tracker,
                1, // PICKED_UP
                string::utf8(b"37.7749,-122.4194"),
                option::some(object::id_from_address(@0x901)),
                string::utf8(b"Package picked up"),
                string::utf8(b"{\"temperature\":22}"),
                &clock
            );

            logistics_manager::update_package_tracking(
                &mut tracker,
                2, // IN_TRANSIT
                string::utf8(b"37.7799,-122.4144"),
                option::some(object::id_from_address(@0x901)),
                string::utf8(b"Package in transit"),
                string::utf8(b"{\"temperature\":23}"),
                &clock
            );

            // Complete delivery
            logistics_manager::complete_package_delivery(
                &mut manager,
                &mut tracker,
                string::utf8(b"DELIVERY_PROOF_HASH"),
                &clock
            );

            // Verify final state
            assert!(logistics_manager::tracker_current_status(&tracker) == 3, 1); // DELIVERED
            assert!(logistics_manager::manager_completed_deliveries(&manager) == 1, 2);
            assert!(logistics_manager::manager_success_rate(&manager) == 100, 3);
            assert!(logistics_manager::optimizer_efficiency_score(&optimizer) > 0, 4);
            assert!(logistics_manager::coordinator_available_backups(&coordinator) == 1, 5);

            transfer::public_transfer(order, CUSTOMER);
            transfer::public_transfer(tracker, ADMIN);
            transfer::public_transfer(manager, ADMIN);
            transfer::public_transfer(optimizer, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_multiple_package_coordination() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut manager = create_test_logistics_manager(test_scenario::ctx(scenario));
            let mut optimizer = logistics_manager::create_route_optimizer(
                string::utf8(b"Multi Package Region"),
                3600000,
                test_scenario::ctx(scenario)
            );

            // Create multiple orders and trackers
            let order1 = create_test_delivery_order(
                CUSTOMER,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7849,-122.4094"),
                800,
                test_scenario::ctx(scenario)
            );

            let order2 = create_test_delivery_order(
                CUSTOMER,
                string::utf8(b"37.7749,-122.4194"),
                string::utf8(b"37.7949,-122.3994"),
                1200,
                test_scenario::ctx(scenario)
            );

            let order3 = create_test_delivery_order(
                CUSTOMER,
                string::utf8(b"37.7649,-122.4294"),
                string::utf8(b"37.7749,-122.4194"),
                600,
                test_scenario::ctx(scenario)
            );

            let tracker1 = logistics_manager::create_package_tracker(
                &mut manager,
                &order1,
                string::utf8(b"PKG_MULTI_1"),
                &clock,
                test_scenario::ctx(scenario)
            );

            let tracker2 = logistics_manager::create_package_tracker(
                &mut manager,
                &order2,
                string::utf8(b"PKG_MULTI_2"),
                &clock,
                test_scenario::ctx(scenario)
            );

            let tracker3 = logistics_manager::create_package_tracker(
                &mut manager,
                &order3,
                string::utf8(b"PKG_MULTI_3"),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Add packages to optimizer
            logistics_manager::add_package_to_optimizer(&mut optimizer, object::id_from_address(@0x1001));
            logistics_manager::add_package_to_optimizer(&mut optimizer, object::id_from_address(@0x1002));
            logistics_manager::add_package_to_optimizer(&mut optimizer, object::id_from_address(@0x1003));

            // Optimize with multiple drones
            let available_drones = vector[
                object::id_from_address(@0x2001),
                object::id_from_address(@0x2002)
            ];

            logistics_manager::optimize_delivery_routes(
                &mut manager,
                &mut optimizer,
                available_drones,
                &clock
            );

            // Verify state
            assert!(logistics_manager::manager_active_deliveries(&manager) == 3, 1);
            assert!(logistics_manager::optimizer_pending_packages(&optimizer) == 3, 2);
            assert!(logistics_manager::optimizer_efficiency_score(&optimizer) > 0, 3);

            transfer::public_transfer(order1, CUSTOMER);
            transfer::public_transfer(order2, CUSTOMER);
            transfer::public_transfer(order3, CUSTOMER);
            transfer::public_transfer(tracker1, ADMIN);
            transfer::public_transfer(tracker2, ADMIN);
            transfer::public_transfer(tracker3, ADMIN);
            transfer::public_transfer(manager, ADMIN);
            transfer::public_transfer(optimizer, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_backup_coordination_under_load() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut manager = create_test_logistics_manager(test_scenario::ctx(scenario));
            let mut coordinator = logistics_manager::create_backup_coordinator(
                string::utf8(b"High Load Zone"),
                test_scenario::ctx(scenario)
            );

            // Add multiple backup drones
            logistics_manager::add_backup_drone(&mut coordinator, object::id_from_address(@0x3001));
            logistics_manager::add_backup_drone(&mut coordinator, object::id_from_address(@0x3002));
            logistics_manager::add_backup_drone(&mut coordinator, object::id_from_address(@0x3003));

            // Activate multiple backups
            let _assignment1 = logistics_manager::activate_backup_drone(
                &mut manager,
                &mut coordinator,
                object::id_from_address(@0x4001),
                object::id_from_address(@0x5001),
                0, // MALFUNCTION
                string::utf8(b"Location1"),
                &clock,
                test_scenario::ctx(scenario)
            );

            let _assignment2 = logistics_manager::activate_backup_drone(
                &mut manager,
                &mut coordinator,
                object::id_from_address(@0x4002),
                object::id_from_address(@0x5002),
                1, // BATTERY
                string::utf8(b"Location2"),
                &clock,
                test_scenario::ctx(scenario)
            );

            let _assignment3 = logistics_manager::activate_backup_drone(
                &mut manager,
                &mut coordinator,
                object::id_from_address(@0x4003),
                object::id_from_address(@0x5003),
                2, // WEATHER
                string::utf8(b"Location3"),
                &clock,
                test_scenario::ctx(scenario)
            );

            // All backups should be used
            assert!(logistics_manager::coordinator_available_backups(&coordinator) == 0, 1);

            // Try to activate one more - should fail
            let assignment4 = logistics_manager::activate_backup_drone(
                &mut manager,
                &mut coordinator,
                object::id_from_address(@0x4004),
                object::id_from_address(@0x5004),
                3, // OVERLOAD
                string::utf8(b"Location4"),
                &clock,
                test_scenario::ctx(scenario)
            );

            assert!(option::is_none(&assignment4), 2);

            transfer::public_transfer(manager, ADMIN);
            transfer::public_transfer(coordinator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
} 