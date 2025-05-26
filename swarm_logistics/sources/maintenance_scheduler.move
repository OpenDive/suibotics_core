/// Maintenance Scheduling Business Logic
/// Handles autonomous maintenance planning, predictive maintenance, and resource allocation
module swarm_logistics::maintenance_scheduler {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::clock::{Self, Clock};
    use std::string::String;
    use std::vector;
    use std::option::{Self, Option};
    use swarm_logistics::drone::{Self as drone_mod, Drone};

    // ==================== MAINTENANCE STRUCTURES ====================

    /// Central maintenance coordination system
    public struct MaintenanceScheduler has key {
        id: UID,
        scheduled_maintenance: vector<ID>,
        active_maintenance: vector<ID>,
        completed_maintenance: vector<ID>,
        maintenance_facilities: vector<ID>,
        total_maintenance_sessions: u64,
        average_maintenance_time: u64,
        predictive_accuracy: u64,      // Percentage accuracy of predictions
        cost_savings_from_prediction: u64, // Cost saved through predictive maintenance
    }

    /// Individual maintenance session
    public struct MaintenanceSession has key, store {
        id: UID,
        drone_id: ID,
        maintenance_type: u8,          // 0=Routine, 1=Predictive, 2=Emergency, 3=Upgrade
        priority: u8,                  // 0=Low, 1=Medium, 2=High, 3=Critical
        scheduled_time: u64,
        estimated_duration: u64,
        actual_start_time: Option<u64>,
        actual_end_time: Option<u64>,
        assigned_facility: Option<ID>,
        required_parts: vector<String>,
        required_skills: vector<u8>,   // Skill codes required
        maintenance_cost: u64,
        status: u8,                    // 0=Scheduled, 1=InProgress, 2=Completed, 3=Cancelled
        completion_notes: String,
    }

    /// Maintenance facility
    public struct MaintenanceFacility has key, store {
        id: UID,
        facility_name: String,
        location: String,
        capacity: u8,                  // Number of drones that can be serviced simultaneously
        current_load: u8,              // Current number of drones being serviced
        available_skills: vector<u8>,  // Available maintenance skills
        operating_hours: String,       // "start_hour,end_hour" in 24h format
        efficiency_rating: u64,        // 0-100 efficiency score
        total_sessions_completed: u64,
        average_session_time: u64,
    }

    /// Predictive maintenance analysis
    public struct PredictiveAnalysis has key, store {
        id: UID,
        drone_id: ID,
        analysis_timestamp: u64,
        flight_hours: u64,
        battery_cycles: u64,
        component_wear_scores: vector<u64>, // Wear scores for different components
        environmental_exposure: u64,   // Cumulative environmental stress
        predicted_failures: vector<PredictedFailure>,
        maintenance_recommendations: vector<MaintenanceRecommendation>,
        confidence_score: u64,         // 0-100 confidence in predictions
        next_analysis_due: u64,
    }

    /// Predicted component failure
    public struct PredictedFailure has store, drop {
        component_id: u8,              // Component identifier
        failure_probability: u64,      // 0-100 probability of failure
        estimated_failure_time: u64,   // Estimated time until failure
        severity: u8,                  // 0=Minor, 1=Moderate, 2=Severe, 3=Critical
        recommended_action: u8,        // 0=Monitor, 1=Schedule, 2=Immediate, 3=Ground
    }

    /// Maintenance recommendation
    public struct MaintenanceRecommendation has store, drop {
        maintenance_type: u8,
        recommended_time: u64,
        estimated_cost: u64,
        priority_score: u64,
        expected_benefit: String,      // Description of expected benefits
        required_downtime: u64,
    }

    /// Resource allocation optimizer
    public struct ResourceAllocator has key, store {
        id: UID,
        region: String,
        available_technicians: vector<TechnicianProfile>,
        parts_inventory: vector<PartInventory>,
        allocation_efficiency: u64,
        last_optimization: u64,
        optimization_frequency: u64,
    }

    /// Technician profile and availability
    public struct TechnicianProfile has store, drop {
        technician_id: String,
        skill_levels: vector<u64>,     // Skill level (0-100) for each skill type
        availability_schedule: String, // JSON encoded schedule
        current_assignment: Option<ID>, // Current maintenance session
        efficiency_rating: u64,
        total_sessions_completed: u64,
    }

    /// Parts inventory tracking
    public struct PartInventory has store, drop {
        part_id: String,
        part_name: String,
        current_stock: u64,
        minimum_stock: u64,
        cost_per_unit: u64,
        supplier_lead_time: u64,       // Days to restock
        last_restocked: u64,
        usage_rate: u64,               // Parts used per month
    }

    // ==================== ERROR CODES ====================
    const E_FACILITY_OVERLOADED: u64 = 1;
    const E_INSUFFICIENT_PARTS: u64 = 2;
    const E_NO_QUALIFIED_TECHNICIAN: u64 = 3;
    const E_MAINTENANCE_CONFLICT: u64 = 4;
    const E_INVALID_SCHEDULE: u64 = 5;

    // ==================== CONSTANTS ====================
    
    // Maintenance types
    const MAINTENANCE_ROUTINE: u8 = 0;
    const MAINTENANCE_PREDICTIVE: u8 = 1;
    const MAINTENANCE_EMERGENCY: u8 = 2;
    const MAINTENANCE_UPGRADE: u8 = 3;

    // Priority levels
    const PRIORITY_LOW: u8 = 0;
    const PRIORITY_MEDIUM: u8 = 1;
    const PRIORITY_HIGH: u8 = 2;
    const PRIORITY_CRITICAL: u8 = 3;

    // Session status
    const STATUS_SCHEDULED: u8 = 0;
    const STATUS_IN_PROGRESS: u8 = 1;
    const STATUS_COMPLETED: u8 = 2;
    const STATUS_CANCELLED: u8 = 3;

    // Component IDs
    const COMPONENT_BATTERY: u8 = 0;
    const COMPONENT_MOTORS: u8 = 1;
    const COMPONENT_PROPELLERS: u8 = 2;
    const COMPONENT_SENSORS: u8 = 3;
    const COMPONENT_NAVIGATION: u8 = 4;
    const COMPONENT_COMMUNICATION: u8 = 5;

    // Recommended actions
    const ACTION_MONITOR: u8 = 0;
    const ACTION_SCHEDULE: u8 = 1;
    const ACTION_IMMEDIATE: u8 = 2;
    const ACTION_GROUND: u8 = 3;

    // Skill types
    const SKILL_MECHANICAL: u8 = 0;
    const SKILL_ELECTRICAL: u8 = 1;
    const SKILL_SOFTWARE: u8 = 2;
    const SKILL_DIAGNOSTICS: u8 = 3;
    const SKILL_CALIBRATION: u8 = 4;

    // ==================== INITIALIZATION ====================

    /// Initialize the maintenance scheduler
    fun init(ctx: &mut TxContext) {
        let scheduler = MaintenanceScheduler {
            id: object::new(ctx),
            scheduled_maintenance: vector::empty(),
            active_maintenance: vector::empty(),
            completed_maintenance: vector::empty(),
            maintenance_facilities: vector::empty(),
            total_maintenance_sessions: 0,
            average_maintenance_time: 7200000, // 2 hours default
            predictive_accuracy: 85,           // 85% accuracy
            cost_savings_from_prediction: 0,
        };
        transfer::share_object(scheduler);
    }

    /// Create maintenance scheduler for testing
    #[test_only]
    public fun create_test_scheduler(ctx: &mut TxContext): MaintenanceScheduler {
        MaintenanceScheduler {
            id: object::new(ctx),
            scheduled_maintenance: vector::empty(),
            active_maintenance: vector::empty(),
            completed_maintenance: vector::empty(),
            maintenance_facilities: vector::empty(),
            total_maintenance_sessions: 0,
            average_maintenance_time: 7200000, // 2 hours default
            predictive_accuracy: 85,           // 85% accuracy
            cost_savings_from_prediction: 0,
        }
    }

    // ==================== MAINTENANCE SCHEDULING ====================

    /// Schedule routine maintenance for a drone
    public fun schedule_routine_maintenance(
        scheduler: &mut MaintenanceScheduler,
        drone_id: ID,
        scheduled_time: u64,
        estimated_duration: u64,
        required_parts: vector<String>,
        clock: &Clock,
        ctx: &mut TxContext
    ): MaintenanceSession {
        let current_time = clock::timestamp_ms(clock);
        
        let session = MaintenanceSession {
            id: object::new(ctx),
            drone_id,
            maintenance_type: MAINTENANCE_ROUTINE,
            priority: PRIORITY_MEDIUM,
            scheduled_time,
            estimated_duration,
            actual_start_time: option::none(),
            actual_end_time: option::none(),
            assigned_facility: option::none(),
            required_parts,
            required_skills: vector[SKILL_MECHANICAL, SKILL_ELECTRICAL],
            maintenance_cost: calculate_maintenance_cost(MAINTENANCE_ROUTINE, estimated_duration),
            status: STATUS_SCHEDULED,
            completion_notes: b"".to_string(),
        };

        let session_id = object::uid_to_inner(&session.id);
        vector::push_back(&mut scheduler.scheduled_maintenance, session_id);
        scheduler.total_maintenance_sessions = scheduler.total_maintenance_sessions + 1;

        session
    }

    /// Schedule predictive maintenance based on analysis
    public fun schedule_predictive_maintenance(
        scheduler: &mut MaintenanceScheduler,
        analysis: &PredictiveAnalysis,
        recommended_time: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): MaintenanceSession {
        let current_time = clock::timestamp_ms(clock);
        let drone_id = analysis.drone_id;
        
        // Determine priority based on predicted failures
        let priority = calculate_predictive_priority(analysis);
        
        // Estimate duration based on predicted issues
        let estimated_duration = estimate_predictive_duration(analysis);
        
        // Determine required parts based on predictions
        let required_parts = determine_required_parts(analysis);
        
        let session = MaintenanceSession {
            id: object::new(ctx),
            drone_id,
            maintenance_type: MAINTENANCE_PREDICTIVE,
            priority,
            scheduled_time: recommended_time,
            estimated_duration,
            actual_start_time: option::none(),
            actual_end_time: option::none(),
            assigned_facility: option::none(),
            required_parts,
            required_skills: vector[SKILL_DIAGNOSTICS, SKILL_MECHANICAL, SKILL_ELECTRICAL],
            maintenance_cost: calculate_maintenance_cost(MAINTENANCE_PREDICTIVE, estimated_duration),
            status: STATUS_SCHEDULED,
            completion_notes: b"Predictive maintenance based on analysis".to_string(),
        };

        let session_id = object::uid_to_inner(&session.id);
        vector::push_back(&mut scheduler.scheduled_maintenance, session_id);
        scheduler.total_maintenance_sessions = scheduler.total_maintenance_sessions + 1;

        session
    }

    /// Schedule emergency maintenance
    public fun schedule_emergency_maintenance(
        scheduler: &mut MaintenanceScheduler,
        drone_id: ID,
        issue_description: String,
        clock: &Clock,
        ctx: &mut TxContext
    ): MaintenanceSession {
        let current_time = clock::timestamp_ms(clock);
        
        let session = MaintenanceSession {
            id: object::new(ctx),
            drone_id,
            maintenance_type: MAINTENANCE_EMERGENCY,
            priority: PRIORITY_CRITICAL,
            scheduled_time: current_time, // Immediate
            estimated_duration: 3600000,  // 1 hour emergency response
            actual_start_time: option::none(),
            actual_end_time: option::none(),
            assigned_facility: option::none(),
            required_parts: vector::empty(), // TBD during diagnosis
            required_skills: vector[SKILL_DIAGNOSTICS, SKILL_MECHANICAL, SKILL_ELECTRICAL, SKILL_SOFTWARE],
            maintenance_cost: calculate_maintenance_cost(MAINTENANCE_EMERGENCY, 3600000),
            status: STATUS_SCHEDULED,
            completion_notes: issue_description,
        };

        let session_id = object::uid_to_inner(&session.id);
        vector::push_back(&mut scheduler.scheduled_maintenance, session_id);
        scheduler.total_maintenance_sessions = scheduler.total_maintenance_sessions + 1;

        session
    }

    /// Calculate maintenance cost based on type and duration
    fun calculate_maintenance_cost(maintenance_type: u8, duration: u64): u64 {
        let base_rate = match (maintenance_type) {
            MAINTENANCE_ROUTINE => 50000,    // 0.05 SUI per hour
            MAINTENANCE_PREDICTIVE => 75000, // 0.075 SUI per hour
            MAINTENANCE_EMERGENCY => 150000, // 0.15 SUI per hour
            MAINTENANCE_UPGRADE => 100000,   // 0.1 SUI per hour
            _ => 50000,
        };
        
        let hours = duration / 3600000; // Convert milliseconds to hours
        base_rate * hours
    }

    /// Calculate priority for predictive maintenance
    fun calculate_predictive_priority(analysis: &PredictiveAnalysis): u8 {
        let failure_count = vector::length(&analysis.predicted_failures);
        let confidence = analysis.confidence_score;
        
        if (failure_count > 2 && confidence > 80) {
            PRIORITY_CRITICAL
        } else if (failure_count > 1 || confidence > 90) {
            PRIORITY_HIGH
        } else if (failure_count > 0) {
            PRIORITY_MEDIUM
        } else {
            PRIORITY_LOW
        }
    }

    /// Estimate duration for predictive maintenance
    fun estimate_predictive_duration(analysis: &PredictiveAnalysis): u64 {
        let failure_count = vector::length(&analysis.predicted_failures);
        let base_duration = 3600000; // 1 hour base
        
        base_duration + (failure_count * 1800000) // +30 minutes per predicted failure
    }

    /// Determine required parts based on analysis
    fun determine_required_parts(analysis: &PredictiveAnalysis): vector<String> {
        let mut parts = vector::empty<String>();
        let failure_count = vector::length(&analysis.predicted_failures);
        
        // Simplified part determination - real implementation would analyze specific failures
        if (failure_count > 0) {
            vector::push_back(&mut parts, b"battery_pack".to_string());
            vector::push_back(&mut parts, b"motor_brushes".to_string());
        };
        
        parts
    }

    // ==================== PREDICTIVE MAINTENANCE ====================

    /// Perform predictive analysis on a drone
    public fun perform_predictive_analysis(
        drone_id: ID,
        flight_hours: u64,
        battery_cycles: u64,
        environmental_exposure: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): PredictiveAnalysis {
        let current_time = clock::timestamp_ms(clock);
        
        // Calculate component wear scores
        let component_wear_scores = calculate_component_wear(
            flight_hours,
            battery_cycles,
            environmental_exposure
        );
        
        // Predict potential failures
        let predicted_failures = predict_component_failures(&component_wear_scores, current_time);
        
        // Generate maintenance recommendations
        let recommendations = generate_maintenance_recommendations(&predicted_failures, current_time);
        
        // Calculate confidence score
        let confidence_score = calculate_prediction_confidence(flight_hours, battery_cycles);
        
        PredictiveAnalysis {
            id: object::new(ctx),
            drone_id,
            analysis_timestamp: current_time,
            flight_hours,
            battery_cycles,
            component_wear_scores,
            environmental_exposure,
            predicted_failures,
            maintenance_recommendations: recommendations,
            confidence_score,
            next_analysis_due: current_time + 604800000, // 1 week
        }
    }

    /// Calculate wear scores for different components
    fun calculate_component_wear(
        flight_hours: u64,
        battery_cycles: u64,
        environmental_exposure: u64
    ): vector<u64> {
        let mut wear_scores = vector::empty<u64>();
        
        // Battery wear (heavily influenced by cycles)
        let battery_wear = (battery_cycles * 100) / 1000; // Assume 1000 cycle lifespan
        vector::push_back(&mut wear_scores, battery_wear);
        
        // Motor wear (influenced by flight hours)
        let motor_wear = (flight_hours * 100) / 2000; // Assume 2000 hour lifespan
        vector::push_back(&mut wear_scores, motor_wear);
        
        // Propeller wear (influenced by flight hours and environment)
        let prop_wear = ((flight_hours * 50) + (environmental_exposure * 25)) / 1500;
        vector::push_back(&mut wear_scores, prop_wear);
        
        // Sensor wear (influenced by environment)
        let sensor_wear = (environmental_exposure * 100) / 5000;
        vector::push_back(&mut wear_scores, sensor_wear);
        
        // Navigation wear (influenced by flight hours)
        let nav_wear = (flight_hours * 100) / 3000;
        vector::push_back(&mut wear_scores, nav_wear);
        
        // Communication wear (influenced by flight hours)
        let comm_wear = (flight_hours * 100) / 4000;
        vector::push_back(&mut wear_scores, comm_wear);
        
        wear_scores
    }

    /// Predict component failures based on wear scores
    fun predict_component_failures(
        wear_scores: &vector<u64>,
        current_time: u64
    ): vector<PredictedFailure> {
        let mut failures = vector::empty<PredictedFailure>();
        let mut component_id = 0;
        
        while (component_id < vector::length(wear_scores)) {
            let wear_score = *vector::borrow(wear_scores, component_id);
            
            if (wear_score > 70) { // High wear threshold
                let failure_prob = if (wear_score > 90) { 80 } else { 50 };
                let time_to_failure = if (wear_score > 90) { 604800000 } else { 2592000000 }; // 1 week or 1 month
                
                let failure = PredictedFailure {
                    component_id: (component_id as u8),
                    failure_probability: failure_prob,
                    estimated_failure_time: current_time + time_to_failure,
                    severity: if (wear_score > 90) { 3 } else { 2 }, // Critical or Severe
                    recommended_action: if (wear_score > 90) { ACTION_IMMEDIATE } else { ACTION_SCHEDULE },
                };
                
                vector::push_back(&mut failures, failure);
            };
            
            component_id = component_id + 1;
        };
        
        failures
    }

    /// Generate maintenance recommendations
    fun generate_maintenance_recommendations(
        predicted_failures: &vector<PredictedFailure>,
        current_time: u64
    ): vector<MaintenanceRecommendation> {
        let mut recommendations = vector::empty<MaintenanceRecommendation>();
        let failure_count = vector::length(predicted_failures);
        
        if (failure_count > 0) {
            let recommendation = MaintenanceRecommendation {
                maintenance_type: MAINTENANCE_PREDICTIVE,
                recommended_time: current_time + 86400000, // 1 day from now
                estimated_cost: 150000, // 0.15 SUI
                priority_score: 80,
                expected_benefit: b"Prevent component failures and extend drone lifespan".to_string(),
                required_downtime: 7200000, // 2 hours
            };
            
            vector::push_back(&mut recommendations, recommendation);
        };
        
        recommendations
    }

    /// Calculate confidence in predictions
    fun calculate_prediction_confidence(flight_hours: u64, battery_cycles: u64): u64 {
        // More data = higher confidence
        let data_score = if (flight_hours > 100 && battery_cycles > 50) { 90 }
                        else if (flight_hours > 50 && battery_cycles > 25) { 75 }
                        else if (flight_hours > 20 && battery_cycles > 10) { 60 }
                        else { 40 };
        
        data_score
    }

    // ==================== FACILITY MANAGEMENT ====================

    /// Create a maintenance facility
    public fun create_maintenance_facility(
        facility_name: String,
        location: String,
        capacity: u8,
        available_skills: vector<u8>,
        operating_hours: String,
        ctx: &mut TxContext
    ): MaintenanceFacility {
        MaintenanceFacility {
            id: object::new(ctx),
            facility_name,
            location,
            capacity,
            current_load: 0,
            available_skills,
            operating_hours,
            efficiency_rating: 100,
            total_sessions_completed: 0,
            average_session_time: 7200000, // 2 hours default
        }
    }

    /// Assign maintenance session to facility
    public fun assign_session_to_facility(
        session: &mut MaintenanceSession,
        facility: &mut MaintenanceFacility
    ) {
        assert!(facility.current_load < facility.capacity, E_FACILITY_OVERLOADED);
        
        session.assigned_facility = option::some(object::uid_to_inner(&facility.id));
        facility.current_load = facility.current_load + 1;
    }

    /// Start maintenance session
    public fun start_maintenance_session(
        scheduler: &mut MaintenanceScheduler,
        session: &mut MaintenanceSession,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        session.actual_start_time = option::some(current_time);
        session.status = STATUS_IN_PROGRESS;
        
        // Move from scheduled to active
        let session_id = object::uid_to_inner(&session.id);
        let (found, index) = vector::index_of(&scheduler.scheduled_maintenance, &session_id);
        if (found) {
            vector::remove(&mut scheduler.scheduled_maintenance, index);
            vector::push_back(&mut scheduler.active_maintenance, session_id);
        };
    }

    /// Complete maintenance session
    public fun complete_maintenance_session(
        scheduler: &mut MaintenanceScheduler,
        session: &mut MaintenanceSession,
        facility: &mut MaintenanceFacility,
        completion_notes: String,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        session.actual_end_time = option::some(current_time);
        session.status = STATUS_COMPLETED;
        session.completion_notes = completion_notes;
        
        // Update facility
        facility.current_load = facility.current_load - 1;
        facility.total_sessions_completed = facility.total_sessions_completed + 1;
        
        // Calculate actual duration and update averages
        if (option::is_some(&session.actual_start_time)) {
            let start_time = option::extract(&mut session.actual_start_time);
            let duration = current_time - start_time;
            
            // Update facility average
            facility.average_session_time = 
                (facility.average_session_time + duration) / 2;
            
            // Update scheduler average
            scheduler.average_maintenance_time = 
                (scheduler.average_maintenance_time + duration) / 2;
        };
        
        // Move from active to completed
        let session_id = object::uid_to_inner(&session.id);
        let (found, index) = vector::index_of(&scheduler.active_maintenance, &session_id);
        if (found) {
            vector::remove(&mut scheduler.active_maintenance, index);
            vector::push_back(&mut scheduler.completed_maintenance, session_id);
        };
    }

    // ==================== RESOURCE ALLOCATION ====================

    /// Create resource allocator for region
    public fun create_resource_allocator(
        region: String,
        optimization_frequency: u64,
        ctx: &mut TxContext
    ): ResourceAllocator {
        ResourceAllocator {
            id: object::new(ctx),
            region,
            available_technicians: vector::empty(),
            parts_inventory: vector::empty(),
            allocation_efficiency: 100,
            last_optimization: 0,
            optimization_frequency,
        }
    }

    /// Add technician to resource pool
    public fun add_technician(
        allocator: &mut ResourceAllocator,
        technician_id: String,
        skill_levels: vector<u64>,
        availability_schedule: String
    ) {
        let technician = TechnicianProfile {
            technician_id,
            skill_levels,
            availability_schedule,
            current_assignment: option::none(),
            efficiency_rating: 100,
            total_sessions_completed: 0,
        };
        
        vector::push_back(&mut allocator.available_technicians, technician);
    }

    /// Add parts to inventory
    public fun add_parts_inventory(
        allocator: &mut ResourceAllocator,
        part_id: String,
        part_name: String,
        initial_stock: u64,
        minimum_stock: u64,
        cost_per_unit: u64,
        supplier_lead_time: u64,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        let inventory = PartInventory {
            part_id,
            part_name,
            current_stock: initial_stock,
            minimum_stock,
            cost_per_unit,
            supplier_lead_time,
            last_restocked: current_time,
            usage_rate: 0, // Will be calculated over time
        };
        
        vector::push_back(&mut allocator.parts_inventory, inventory);
    }

    /// Optimize resource allocation
    public fun optimize_resource_allocation(
        allocator: &mut ResourceAllocator,
        pending_sessions: &vector<ID>,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        // Check if optimization is needed
        if (current_time - allocator.last_optimization < allocator.optimization_frequency) {
            return
        };
        
        // Simplified optimization - assign technicians to sessions based on skills
        optimize_technician_assignments(allocator, pending_sessions);
        
        // Check inventory levels and trigger restocking if needed
        check_inventory_levels(allocator, current_time);
        
        allocator.last_optimization = current_time;
    }

    /// Optimize technician assignments
    fun optimize_technician_assignments(
        allocator: &mut ResourceAllocator,
        _pending_sessions: &vector<ID>
    ) {
        // Simplified assignment logic
        // Real implementation would match technician skills with session requirements
        let technician_count = vector::length(&allocator.available_technicians);
        
        if (technician_count > 0) {
            allocator.allocation_efficiency = 95; // Good allocation
        } else {
            allocator.allocation_efficiency = 50; // Poor allocation
        };
    }

    /// Check inventory levels and trigger restocking
    fun check_inventory_levels(allocator: &mut ResourceAllocator, current_time: u64) {
        let mut i = 0;
        let inventory_count = vector::length(&allocator.parts_inventory);
        
        while (i < inventory_count) {
            let inventory = vector::borrow_mut(&mut allocator.parts_inventory, i);
            
            if (inventory.current_stock <= inventory.minimum_stock) {
                // Trigger restocking (simplified)
                inventory.current_stock = inventory.current_stock + 100; // Restock 100 units
                inventory.last_restocked = current_time;
            };
            
            i = i + 1;
        };
    }

    // ==================== GETTER FUNCTIONS ====================

    public fun scheduler_total_sessions(scheduler: &MaintenanceScheduler): u64 {
        scheduler.total_maintenance_sessions
    }

    public fun scheduler_average_time(scheduler: &MaintenanceScheduler): u64 {
        scheduler.average_maintenance_time
    }

    public fun scheduler_predictive_accuracy(scheduler: &MaintenanceScheduler): u64 {
        scheduler.predictive_accuracy
    }

    public fun scheduler_scheduled_count(scheduler: &MaintenanceScheduler): u64 {
        vector::length(&scheduler.scheduled_maintenance)
    }

    public fun scheduler_active_count(scheduler: &MaintenanceScheduler): u64 {
        vector::length(&scheduler.active_maintenance)
    }

    public fun session_drone_id(session: &MaintenanceSession): ID {
        session.drone_id
    }

    public fun session_maintenance_type(session: &MaintenanceSession): u8 {
        session.maintenance_type
    }

    public fun session_priority(session: &MaintenanceSession): u8 {
        session.priority
    }

    public fun session_status(session: &MaintenanceSession): u8 {
        session.status
    }

    public fun session_cost(session: &MaintenanceSession): u64 {
        session.maintenance_cost
    }

    public fun facility_capacity(facility: &MaintenanceFacility): u8 {
        facility.capacity
    }

    public fun facility_current_load(facility: &MaintenanceFacility): u8 {
        facility.current_load
    }

    public fun facility_efficiency(facility: &MaintenanceFacility): u64 {
        facility.efficiency_rating
    }

    public fun analysis_confidence(analysis: &PredictiveAnalysis): u64 {
        analysis.confidence_score
    }

    public fun analysis_failure_count(analysis: &PredictiveAnalysis): u64 {
        vector::length(&analysis.predicted_failures)
    }

    public fun allocator_efficiency(allocator: &ResourceAllocator): u64 {
        allocator.allocation_efficiency
    }

    public fun allocator_technician_count(allocator: &ResourceAllocator): u64 {
        vector::length(&allocator.available_technicians)
    }

    public fun allocator_parts_count(allocator: &ResourceAllocator): u64 {
        vector::length(&allocator.parts_inventory)
    }
} 