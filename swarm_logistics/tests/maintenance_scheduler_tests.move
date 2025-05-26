#[test_only]
module swarm_logistics::maintenance_scheduler_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, ID};
    use sui::coin;
    use sui::sui::SUI;
    use std::string;
    use std::vector;
    use std::option;
    use swarm_logistics::maintenance_scheduler::{Self, MaintenanceScheduler, MaintenanceSession, MaintenanceFacility, PredictiveAnalysis, ResourceAllocator};
    use swarm_logistics::drone::{Self, Drone};

    // Test addresses
    const ADMIN: address = @0x1;
    const TECHNICIAN: address = @0x2;
    const FACILITY_MANAGER: address = @0x3;

    // ==================== MAINTENANCE SCHEDULING TESTS ====================

    #[test]
    fun test_routine_maintenance_scheduling() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            // Create maintenance scheduler
            let scheduler = maintenance_scheduler::create_test_scheduler(test_scenario::ctx(scenario));
            transfer::public_share_object(scheduler);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut scheduler = test_scenario::take_shared<MaintenanceScheduler>(scenario);
            let current_time = clock::timestamp_ms(&clock);
            
            // Create a test drone ID
            let drone_id = object::id_from_address(@0x123);
            
            // Schedule routine maintenance
            let required_parts = vector[
                string::utf8(b"battery_pack"),
                string::utf8(b"propeller_set")
            ];
            
            let session = maintenance_scheduler::schedule_routine_maintenance(
                &mut scheduler,
                drone_id,
                current_time + 86400000, // 1 day from now
                7200000, // 2 hours
                required_parts,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify session properties
            assert!(maintenance_scheduler::session_drone_id(&session) == drone_id, 1);
            assert!(maintenance_scheduler::session_maintenance_type(&session) == 0, 2); // ROUTINE
            assert!(maintenance_scheduler::session_priority(&session) == 1, 3); // MEDIUM
            assert!(maintenance_scheduler::session_status(&session) == 0, 4); // SCHEDULED
            assert!(maintenance_scheduler::session_cost(&session) > 0, 5);

            // Verify scheduler state
            assert!(maintenance_scheduler::scheduler_scheduled_count(&scheduler) == 1, 6);
            assert!(maintenance_scheduler::scheduler_total_sessions(&scheduler) == 1, 7);

            transfer::public_transfer(session, ADMIN);
            test_scenario::return_shared(scheduler);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_emergency_maintenance_scheduling() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            maintenance_scheduler::init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut scheduler = test_scenario::take_shared<MaintenanceScheduler>(scenario);
            let drone_id = object::id_from_address(@0x456);
            
            let session = maintenance_scheduler::schedule_emergency_maintenance(
                &mut scheduler,
                drone_id,
                string::utf8(b"Motor failure detected during flight"),
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify emergency properties
            assert!(maintenance_scheduler::session_maintenance_type(&session) == 2, 1); // EMERGENCY
            assert!(maintenance_scheduler::session_priority(&session) == 3, 2); // CRITICAL
            assert!(maintenance_scheduler::session_status(&session) == 0, 3); // SCHEDULED

            transfer::public_transfer(session, ADMIN);
            test_scenario::return_shared(scheduler);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_maintenance_session_lifecycle() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            maintenance_scheduler::init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut scheduler = test_scenario::take_shared<MaintenanceScheduler>(scenario);
            let drone_id = object::id_from_address(@0x789);
            
            // Create facility
            let mut facility = maintenance_scheduler::create_maintenance_facility(
                string::utf8(b"Main Service Center"),
                string::utf8(b"San Francisco"),
                5, // capacity
                vector[0, 1, 2], // mechanical, electrical, software skills
                string::utf8(b"8,18"), // 8 AM to 6 PM
                test_scenario::ctx(scenario)
            );

            // Schedule maintenance
            let mut session = maintenance_scheduler::schedule_routine_maintenance(
                &mut scheduler,
                drone_id,
                clock::timestamp_ms(&clock) + 3600000, // 1 hour from now
                7200000, // 2 hours
                vector[string::utf8(b"battery_pack")],
                &clock,
                test_scenario::ctx(scenario)
            );

            // Assign to facility
            maintenance_scheduler::assign_session_to_facility(&mut session, &mut facility);
            assert!(maintenance_scheduler::facility_current_load(&facility) == 1, 1);

            // Start session
            maintenance_scheduler::start_maintenance_session(&mut scheduler, &mut session, &clock);
            assert!(maintenance_scheduler::session_status(&session) == 1, 2); // IN_PROGRESS
            assert!(maintenance_scheduler::scheduler_active_count(&scheduler) == 1, 3);

            // Complete session
            maintenance_scheduler::complete_maintenance_session(
                &mut scheduler,
                &mut session,
                &mut facility,
                string::utf8(b"Battery replaced successfully"),
                &clock
            );
            assert!(maintenance_scheduler::session_status(&session) == 2, 4); // COMPLETED
            assert!(maintenance_scheduler::facility_current_load(&facility) == 0, 5);

            transfer::public_transfer(session, ADMIN);
            transfer::public_transfer(facility, ADMIN);
            test_scenario::return_shared(scheduler);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== PREDICTIVE ANALYSIS TESTS ====================

    #[test]
    fun test_predictive_analysis_creation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let drone_id = object::id_from_address(@0xABC);
            
            let analysis = maintenance_scheduler::perform_predictive_analysis(
                drone_id,
                500,  // 500 flight hours
                200,  // 200 battery cycles
                1000, // Environmental exposure
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify analysis properties
            assert!(maintenance_scheduler::analysis_confidence(&analysis) > 0, 1);
            
            // High usage should predict some failures
            let failure_count = maintenance_scheduler::analysis_failure_count(&analysis);
            assert!(failure_count > 0, 2);

            transfer::public_transfer(analysis, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_predictive_maintenance_scheduling() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            maintenance_scheduler::init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut scheduler = test_scenario::take_shared<MaintenanceScheduler>(scenario);
            let drone_id = object::id_from_address(@0xDEF);
            
            // Create predictive analysis
            let analysis = maintenance_scheduler::perform_predictive_analysis(
                drone_id,
                800,  // High flight hours
                300,  // High battery cycles
                2000, // High environmental exposure
                &clock,
                test_scenario::ctx(scenario)
            );

            // Schedule predictive maintenance based on analysis
            let session = maintenance_scheduler::schedule_predictive_maintenance(
                &mut scheduler,
                &analysis,
                clock::timestamp_ms(&clock) + 172800000, // 2 days from now
                &clock,
                test_scenario::ctx(scenario)
            );

            // Verify predictive maintenance properties
            assert!(maintenance_scheduler::session_maintenance_type(&session) == 1, 1); // PREDICTIVE
            assert!(maintenance_scheduler::session_priority(&session) >= 2, 2); // HIGH or CRITICAL
            assert!(maintenance_scheduler::session_cost(&session) > 0, 3);

            transfer::public_transfer(analysis, ADMIN);
            transfer::public_transfer(session, ADMIN);
            test_scenario::return_shared(scheduler);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_low_usage_predictive_analysis() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let drone_id = object::id_from_address(@0x111);
            
            // Low usage drone
            let analysis = maintenance_scheduler::perform_predictive_analysis(
                drone_id,
                50,   // Low flight hours
                10,   // Low battery cycles
                100,  // Low environmental exposure
                &clock,
                test_scenario::ctx(scenario)
            );

            // Low usage should have fewer predicted failures
            let failure_count = maintenance_scheduler::analysis_failure_count(&analysis);
            assert!(failure_count == 0, 1); // Should have no predicted failures
            
            // Confidence should be lower due to less data
            let confidence = maintenance_scheduler::analysis_confidence(&analysis);
            assert!(confidence < 80, 2);

            transfer::public_transfer(analysis, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== FACILITY MANAGEMENT TESTS ====================

    #[test]
    fun test_facility_creation_and_management() {
        let mut scenario_val = test_scenario::begin(FACILITY_MANAGER);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, FACILITY_MANAGER);
        {
            let facility = maintenance_scheduler::create_maintenance_facility(
                string::utf8(b"Advanced Repair Center"),
                string::utf8(b"Los Angeles"),
                10, // High capacity
                vector[0, 1, 2, 3, 4], // All skill types
                string::utf8(b"0,24"), // 24/7 operation
                test_scenario::ctx(scenario)
            );

            // Verify facility properties
            assert!(maintenance_scheduler::facility_capacity(&facility) == 10, 1);
            assert!(maintenance_scheduler::facility_current_load(&facility) == 0, 2);
            assert!(maintenance_scheduler::facility_efficiency(&facility) == 100, 3);

            transfer::public_transfer(facility, FACILITY_MANAGER);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_facility_capacity_management() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            maintenance_scheduler::init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut scheduler = test_scenario::take_shared<MaintenanceScheduler>(scenario);
            
            // Create small capacity facility
            let mut facility = maintenance_scheduler::create_maintenance_facility(
                string::utf8(b"Small Service Center"),
                string::utf8(b"Oakland"),
                2, // Small capacity
                vector[0, 1], // Limited skills
                string::utf8(b"9,17"), // 9 AM to 5 PM
                test_scenario::ctx(scenario)
            );

            // Create multiple sessions
            let drone_id1 = object::id_from_address(@0x001);
            let drone_id2 = object::id_from_address(@0x002);
            
            let mut session1 = maintenance_scheduler::schedule_routine_maintenance(
                &mut scheduler,
                drone_id1,
                clock::timestamp_ms(&clock) + 3600000,
                3600000,
                vector[],
                &clock,
                test_scenario::ctx(scenario)
            );

            let mut session2 = maintenance_scheduler::schedule_routine_maintenance(
                &mut scheduler,
                drone_id2,
                clock::timestamp_ms(&clock) + 3600000,
                3600000,
                vector[],
                &clock,
                test_scenario::ctx(scenario)
            );

            // Assign sessions to facility
            maintenance_scheduler::assign_session_to_facility(&mut session1, &mut facility);
            assert!(maintenance_scheduler::facility_current_load(&facility) == 1, 1);

            maintenance_scheduler::assign_session_to_facility(&mut session2, &mut facility);
            assert!(maintenance_scheduler::facility_current_load(&facility) == 2, 2);

            transfer::public_transfer(session1, ADMIN);
            transfer::public_transfer(session2, ADMIN);
            transfer::public_transfer(facility, ADMIN);
            test_scenario::return_shared(scheduler);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_facility_overload_protection() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            maintenance_scheduler::init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut scheduler = test_scenario::take_shared<MaintenanceScheduler>(scenario);
            
            // Create facility with capacity 1
            let mut facility = maintenance_scheduler::create_maintenance_facility(
                string::utf8(b"Tiny Service Center"),
                string::utf8(b"Berkeley"),
                1, // Capacity of 1
                vector[0],
                string::utf8(b"9,17"),
                test_scenario::ctx(scenario)
            );

            // Create two sessions
            let mut session1 = maintenance_scheduler::schedule_routine_maintenance(
                &mut scheduler,
                object::id_from_address(@0x001),
                clock::timestamp_ms(&clock) + 3600000,
                3600000,
                vector[],
                &clock,
                test_scenario::ctx(scenario)
            );

            let mut session2 = maintenance_scheduler::schedule_routine_maintenance(
                &mut scheduler,
                object::id_from_address(@0x002),
                clock::timestamp_ms(&clock) + 3600000,
                3600000,
                vector[],
                &clock,
                test_scenario::ctx(scenario)
            );

            // First assignment should succeed
            maintenance_scheduler::assign_session_to_facility(&mut session1, &mut facility);
            
            // Second assignment should fail (facility overloaded)
            maintenance_scheduler::assign_session_to_facility(&mut session2, &mut facility);

            transfer::public_transfer(session1, ADMIN);
            transfer::public_transfer(session2, ADMIN);
            transfer::public_transfer(facility, ADMIN);
            test_scenario::return_shared(scheduler);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== RESOURCE ALLOCATION TESTS ====================

    #[test]
    fun test_resource_allocator_creation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let allocator = maintenance_scheduler::create_resource_allocator(
                string::utf8(b"Bay Area Region"),
                86400000, // Daily optimization
                test_scenario::ctx(scenario)
            );

            // Verify initial state
            assert!(maintenance_scheduler::allocator_efficiency(&allocator) == 100, 1);
            assert!(maintenance_scheduler::allocator_technician_count(&allocator) == 0, 2);
            assert!(maintenance_scheduler::allocator_parts_count(&allocator) == 0, 3);

            transfer::public_transfer(allocator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_technician_management() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut allocator = maintenance_scheduler::create_resource_allocator(
                string::utf8(b"Central Valley"),
                86400000,
                test_scenario::ctx(scenario)
            );

            // Add technicians with different skill levels
            maintenance_scheduler::add_technician(
                &mut allocator,
                string::utf8(b"TECH001"),
                vector[90, 85, 70, 95, 80], // High skill levels
                string::utf8(b"{\"monday\": \"9-17\", \"tuesday\": \"9-17\"}")
            );

            maintenance_scheduler::add_technician(
                &mut allocator,
                string::utf8(b"TECH002"),
                vector[75, 90, 95, 80, 85], // Different skill profile
                string::utf8(b"{\"monday\": \"8-16\", \"tuesday\": \"8-16\"}")
            );

            // Verify technician count
            assert!(maintenance_scheduler::allocator_technician_count(&allocator) == 2, 1);

            transfer::public_transfer(allocator, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_parts_inventory_management() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut allocator = maintenance_scheduler::create_resource_allocator(
                string::utf8(b"Southern California"),
                86400000,
                test_scenario::ctx(scenario)
            );

            // Add various parts to inventory
            maintenance_scheduler::add_parts_inventory(
                &mut allocator,
                string::utf8(b"BATT001"),
                string::utf8(b"High-Capacity Battery Pack"),
                50,  // Initial stock
                10,  // Minimum stock
                25000000, // 0.025 SUI per unit
                7,   // 7 days lead time
                &clock
            );

            maintenance_scheduler::add_parts_inventory(
                &mut allocator,
                string::utf8(b"PROP001"),
                string::utf8(b"Carbon Fiber Propeller Set"),
                100, // Initial stock
                20,  // Minimum stock
                5000000, // 0.005 SUI per unit
                3,   // 3 days lead time
                &clock
            );

            // Verify parts count
            assert!(maintenance_scheduler::allocator_parts_count(&allocator) == 2, 1);

            transfer::public_transfer(allocator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_resource_optimization() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut allocator = maintenance_scheduler::create_resource_allocator(
                string::utf8(b"Test Region"),
                3600000, // Hourly optimization for testing
                test_scenario::ctx(scenario)
            );

            // Add resources
            maintenance_scheduler::add_technician(
                &mut allocator,
                string::utf8(b"TECH001"),
                vector[90, 85, 70, 95, 80],
                string::utf8(b"{\"availability\": \"full\"}")
            );

            maintenance_scheduler::add_parts_inventory(
                &mut allocator,
                string::utf8(b"PART001"),
                string::utf8(b"Test Part"),
                100,
                20,
                1000000,
                5,
                &clock
            );

            // Create pending sessions
            let pending_sessions = vector[
                object::id_from_address(@0x001),
                object::id_from_address(@0x002)
            ];

            // Optimize allocation
            maintenance_scheduler::optimize_resource_allocation(
                &mut allocator,
                &pending_sessions,
                &clock
            );

            // Verify optimization occurred
            let efficiency = maintenance_scheduler::allocator_efficiency(&allocator);
            assert!(efficiency > 0, 1);

            transfer::public_transfer(allocator, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== INTEGRATION TESTS ====================

    #[test]
    fun test_complete_maintenance_workflow() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            maintenance_scheduler::init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut scheduler = test_scenario::take_shared<MaintenanceScheduler>(scenario);
            let drone_id = object::id_from_address(@0xFFF);

            // 1. Perform predictive analysis
            let analysis = maintenance_scheduler::perform_predictive_analysis(
                drone_id,
                600,  // Moderate usage
                150,  // Moderate battery cycles
                800,  // Moderate environmental exposure
                &clock,
                test_scenario::ctx(scenario)
            );

            // 2. Schedule predictive maintenance if needed
            let mut session = if (maintenance_scheduler::analysis_failure_count(&analysis) > 0) {
                maintenance_scheduler::schedule_predictive_maintenance(
                    &mut scheduler,
                    &analysis,
                    clock::timestamp_ms(&clock) + 86400000, // 1 day from now
                    &clock,
                    test_scenario::ctx(scenario)
                )
            } else {
                // Schedule routine maintenance instead
                maintenance_scheduler::schedule_routine_maintenance(
                    &mut scheduler,
                    drone_id,
                    clock::timestamp_ms(&clock) + 86400000,
                    7200000,
                    vector[string::utf8(b"battery_pack")],
                    &clock,
                    test_scenario::ctx(scenario)
                )
            };

            // 3. Create facility and assign session
            let mut facility = maintenance_scheduler::create_maintenance_facility(
                string::utf8(b"Integrated Service Center"),
                string::utf8(b"San Jose"),
                3,
                vector[0, 1, 2, 3, 4],
                string::utf8(b"6,22"),
                test_scenario::ctx(scenario)
            );

            maintenance_scheduler::assign_session_to_facility(&mut session, &mut facility);

            // 4. Start and complete maintenance
            maintenance_scheduler::start_maintenance_session(&mut scheduler, &mut session, &clock);
            maintenance_scheduler::complete_maintenance_session(
                &mut scheduler,
                &mut session,
                &mut facility,
                string::utf8(b"Maintenance completed successfully"),
                &clock
            );

            // Verify final state
            assert!(maintenance_scheduler::session_status(&session) == 2, 1); // COMPLETED
            assert!(maintenance_scheduler::facility_current_load(&facility) == 0, 2);

            transfer::public_transfer(analysis, ADMIN);
            transfer::public_transfer(session, ADMIN);
            transfer::public_transfer(facility, ADMIN);
            test_scenario::return_shared(scheduler);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_multiple_concurrent_maintenance() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            maintenance_scheduler::init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut scheduler = test_scenario::take_shared<MaintenanceScheduler>(scenario);
            
            // Create multiple facilities
            let mut facility1 = maintenance_scheduler::create_maintenance_facility(
                string::utf8(b"North Facility"),
                string::utf8(b"San Francisco"),
                2,
                vector[0, 1, 2],
                string::utf8(b"8,20"),
                test_scenario::ctx(scenario)
            );

            let mut facility2 = maintenance_scheduler::create_maintenance_facility(
                string::utf8(b"South Facility"),
                string::utf8(b"San Jose"),
                3,
                vector[0, 1, 2, 3, 4],
                string::utf8(b"6,22"),
                test_scenario::ctx(scenario)
            );

            // Schedule multiple maintenance sessions
            let mut sessions = vector::empty<MaintenanceSession>();
            let mut i = 0;
            while (i < 4) {
                let drone_id = object::id_from_address(@0x100 + i);
                let session = maintenance_scheduler::schedule_routine_maintenance(
                    &mut scheduler,
                    drone_id,
                    clock::timestamp_ms(&clock) + (i * 3600000), // Staggered times
                    3600000 + (i * 1800000), // Varying durations
                    vector[],
                    &clock,
                    test_scenario::ctx(scenario)
                );
                vector::push_back(&mut sessions, session);
                i = i + 1;
            };

            // Assign sessions to facilities
            let session1 = vector::pop_back(&mut sessions);
            let session2 = vector::pop_back(&mut sessions);
            let session3 = vector::pop_back(&mut sessions);
            let session4 = vector::pop_back(&mut sessions);

            let mut session1 = session1;
            let mut session2 = session2;
            let mut session3 = session3;
            let mut session4 = session4;

            maintenance_scheduler::assign_session_to_facility(&mut session1, &mut facility1);
            maintenance_scheduler::assign_session_to_facility(&mut session2, &mut facility1);
            maintenance_scheduler::assign_session_to_facility(&mut session3, &mut facility2);
            maintenance_scheduler::assign_session_to_facility(&mut session4, &mut facility2);

            // Verify facility loads
            assert!(maintenance_scheduler::facility_current_load(&facility1) == 2, 1);
            assert!(maintenance_scheduler::facility_current_load(&facility2) == 2, 2);
            assert!(maintenance_scheduler::scheduler_scheduled_count(&scheduler) == 4, 3);

            transfer::public_transfer(session1, ADMIN);
            transfer::public_transfer(session2, ADMIN);
            transfer::public_transfer(session3, ADMIN);
            transfer::public_transfer(session4, ADMIN);
            transfer::public_transfer(facility1, ADMIN);
            transfer::public_transfer(facility2, ADMIN);
            test_scenario::return_shared(scheduler);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== PERFORMANCE TESTS ====================

    #[test]
    fun test_high_volume_scheduling() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            maintenance_scheduler::init(test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut scheduler = test_scenario::take_shared<MaintenanceScheduler>(scenario);
            let mut sessions = vector::empty<MaintenanceSession>();
            
            // Schedule 10 maintenance sessions
            let mut i = 0;
            while (i < 10) {
                let drone_id = object::id_from_address(@0x200 + i);
                let session = maintenance_scheduler::schedule_routine_maintenance(
                    &mut scheduler,
                    drone_id,
                    clock::timestamp_ms(&clock) + (i * 3600000),
                    3600000,
                    vector[],
                    &clock,
                    test_scenario::ctx(scenario)
                );
                vector::push_back(&mut sessions, session);
                i = i + 1;
            };

            // Verify all sessions were scheduled
            assert!(maintenance_scheduler::scheduler_scheduled_count(&scheduler) == 10, 1);
            assert!(maintenance_scheduler::scheduler_total_sessions(&scheduler) == 10, 2);

            // Clean up sessions
            while (!vector::is_empty(&sessions)) {
                let session = vector::pop_back(&mut sessions);
                transfer::public_transfer(session, ADMIN);
            };

            test_scenario::return_shared(scheduler);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }
} 