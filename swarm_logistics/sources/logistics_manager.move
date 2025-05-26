/// Logistics Management Business Logic
/// Handles package tracking, delivery workflows, and backup coordination
module swarm_logistics::logistics_manager {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::clock::{Self, Clock};
    use std::string::String;
    use std::vector;
    use std::option::{Self, Option};
    use swarm_logistics::delivery::{Self as delivery_mod, DeliveryOrder};
    use swarm_logistics::drone::{Self as drone_mod, Drone};
    use swarm_logistics::events::{Self as events_mod};

    // ==================== LOGISTICS STRUCTURES ====================

    /// Central logistics coordination hub
    public struct LogisticsManager has key {
        id: UID,
        active_deliveries: vector<ID>,
        completed_deliveries: vector<ID>,
        failed_deliveries: vector<ID>,
        total_packages_processed: u64,
        successful_delivery_rate: u64, // Percentage
        average_delivery_time: u64,    // Milliseconds
        backup_activations: u64,
        route_optimizations: u64,
    }

    /// Package tracking throughout delivery lifecycle
    public struct PackageTracker has key, store {
        id: UID,
        order_id: ID,
        package_id: String,
        current_status: u8,     // 0=Created, 1=PickedUp, 2=InTransit, 3=Delivered, 4=Failed
        current_location: String,
        estimated_delivery: u64,
        tracking_history: vector<TrackingEvent>,
        condition_alerts: vector<String>, // Temperature, humidity, shock alerts
        proof_of_delivery: Option<String>, // Digital signature or photo hash
    }

    /// Individual tracking event
    public struct TrackingEvent has store, drop {
        timestamp: u64,
        location: String,
        status: u8,
        drone_id: Option<ID>,
        notes: String,
        environmental_data: String, // JSON encoded sensor data
    }

    /// Multi-package route optimization
    public struct RouteOptimizer has key, store {
        id: UID,
        region: String,
        pending_packages: vector<ID>,
        optimized_routes: vector<OptimizedRoute>,
        consolidation_opportunities: vector<ConsolidationGroup>,
        efficiency_score: u64,      // 0-100 optimization effectiveness
        last_optimization: u64,
        optimization_frequency: u64, // Milliseconds between optimizations
    }

    /// Optimized delivery route for multiple packages
    public struct OptimizedRoute has store, drop {
        route_id: String,
        assigned_drone: ID,
        package_sequence: vector<ID>, // Order of package pickups/deliveries
        total_distance: u64,
        estimated_time: u64,
        fuel_efficiency: u64,
        priority_score: u64,
        weather_factor: u64,
    }

    /// Package consolidation group
    public struct ConsolidationGroup has store, drop {
        group_id: String,
        packages: vector<ID>,
        pickup_location: String,
        delivery_region: String,
        consolidation_savings: u64, // Cost savings from consolidation
        time_window: u64,          // Available time window for consolidation
    }

    /// Backup drone coordination
    public struct BackupCoordinator has key, store {
        id: UID,
        region: String,
        available_backups: vector<ID>,
        active_backups: vector<BackupAssignment>,
        backup_success_rate: u64,
        average_response_time: u64,
        total_backup_activations: u64,
    }

    /// Backup drone assignment
    public struct BackupAssignment has store, drop {
        backup_drone: ID,
        original_drone: ID,
        order_id: ID,
        activation_reason: u8,  // 0=Malfunction, 1=Battery, 2=Weather, 3=Overload
        activation_time: u64,
        handoff_location: String,
        estimated_delay: u64,
        status: u8,            // 0=Assigned, 1=EnRoute, 2=HandoffComplete, 3=Failed
    }

    // ==================== ERROR CODES ====================
    const E_PACKAGE_NOT_FOUND: u64 = 1;
    const E_NO_BACKUP_AVAILABLE: u64 = 2;
    const E_OPTIMIZATION_FAILED: u64 = 3;
    const E_INVALID_CONSOLIDATION: u64 = 4;
    const E_TRACKING_ERROR: u64 = 5;

    // ==================== CONSTANTS ====================
    
    // Package status
    const PACKAGE_CREATED: u8 = 0;
    const PACKAGE_PICKED_UP: u8 = 1;
    const PACKAGE_IN_TRANSIT: u8 = 2;
    const PACKAGE_DELIVERED: u8 = 3;
    const PACKAGE_FAILED: u8 = 4;

    // Backup activation reasons
    const BACKUP_MALFUNCTION: u8 = 0;
    const BACKUP_BATTERY: u8 = 1;
    const BACKUP_WEATHER: u8 = 2;
    const BACKUP_OVERLOAD: u8 = 3;

    // Backup status
    const BACKUP_ASSIGNED: u8 = 0;
    const BACKUP_EN_ROUTE: u8 = 1;
    const BACKUP_HANDOFF_COMPLETE: u8 = 2;
    const BACKUP_FAILED: u8 = 3;

    // ==================== INITIALIZATION ====================

    /// Initialize the logistics manager
    fun init(ctx: &mut TxContext) {
        let manager = LogisticsManager {
            id: object::new(ctx),
            active_deliveries: vector::empty(),
            completed_deliveries: vector::empty(),
            failed_deliveries: vector::empty(),
            total_packages_processed: 0,
            successful_delivery_rate: 100,
            average_delivery_time: 1800000, // 30 minutes default
            backup_activations: 0,
            route_optimizations: 0,
        };
        transfer::share_object(manager);
    }

    // ==================== PACKAGE TRACKING ====================

    /// Create package tracker for new delivery
    public fun create_package_tracker(
        manager: &mut LogisticsManager,
        order: &DeliveryOrder,
        package_id: String,
        clock: &Clock,
        ctx: &mut TxContext
    ): PackageTracker {
        let current_time = clock::timestamp_ms(clock);
        let order_id = delivery_mod::order_id(order);
        
        // Create initial tracking event
        let initial_event = TrackingEvent {
            timestamp: current_time,
            location: delivery_mod::order_pickup_location(order),
            status: PACKAGE_CREATED,
            drone_id: option::none(),
            notes: b"Package created and ready for pickup".to_string(),
            environmental_data: b"{\"temperature\":22,\"humidity\":45}".to_string(),
        };

        let tracker = PackageTracker {
            id: object::new(ctx),
            order_id,
            package_id,
            current_status: PACKAGE_CREATED,
            current_location: delivery_mod::order_pickup_location(order),
            estimated_delivery: current_time + 1800000, // 30 minutes estimate
            tracking_history: vector[initial_event],
            condition_alerts: vector::empty(),
            proof_of_delivery: option::none(),
        };

        // Add to active deliveries
        vector::push_back(&mut manager.active_deliveries, order_id);
        manager.total_packages_processed = manager.total_packages_processed + 1;

        tracker
    }

    /// Update package tracking status
    public fun update_package_tracking(
        tracker: &mut PackageTracker,
        new_status: u8,
        new_location: String,
        drone_id: Option<ID>,
        notes: String,
        environmental_data: String,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        // Create tracking event
        let tracking_event = TrackingEvent {
            timestamp: current_time,
            location: new_location,
            status: new_status,
            drone_id,
            notes,
            environmental_data,
        };

        // Update tracker
        tracker.current_status = new_status;
        tracker.current_location = new_location;
        vector::push_back(&mut tracker.tracking_history, tracking_event);

        // Check for condition alerts
        check_package_conditions(tracker, &environmental_data);
    }

    /// Check package environmental conditions
    fun check_package_conditions(tracker: &mut PackageTracker, environmental_data: &String) {
        // Simplified condition checking - would parse JSON in real implementation
        let data_bytes = environmental_data.as_bytes();
        
        // Check for temperature alerts (simplified)
        if (vector::length(data_bytes) > 20) { // Placeholder condition
            vector::push_back(&mut tracker.condition_alerts, 
                b"Temperature alert: Package may be exposed to extreme conditions".to_string());
        };
    }

    /// Complete package delivery
    public fun complete_package_delivery(
        manager: &mut LogisticsManager,
        tracker: &mut PackageTracker,
        proof_of_delivery: String,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        // Update tracker
        tracker.current_status = PACKAGE_DELIVERED;
        tracker.proof_of_delivery = option::some(proof_of_delivery);
        
        // Add final tracking event
        let final_event = TrackingEvent {
            timestamp: current_time,
            location: tracker.current_location,
            status: PACKAGE_DELIVERED,
            drone_id: option::none(),
            notes: b"Package delivered successfully".to_string(),
            environmental_data: b"{\"delivery_confirmed\":true}".to_string(),
        };
        vector::push_back(&mut tracker.tracking_history, final_event);

        // Move from active to completed
        let order_id = tracker.order_id;
        let (found, index) = vector::index_of(&manager.active_deliveries, &order_id);
        if (found) {
            vector::remove(&mut manager.active_deliveries, index);
            vector::push_back(&mut manager.completed_deliveries, order_id);
        };

        // Update success metrics
        update_delivery_metrics(manager, true, current_time);
    }

    /// Handle package delivery failure
    public fun handle_package_failure(
        manager: &mut LogisticsManager,
        tracker: &mut PackageTracker,
        failure_reason: String,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        // Update tracker
        tracker.current_status = PACKAGE_FAILED;
        
        // Add failure tracking event
        let failure_event = TrackingEvent {
            timestamp: current_time,
            location: tracker.current_location,
            status: PACKAGE_FAILED,
            drone_id: option::none(),
            notes: failure_reason,
            environmental_data: b"{\"delivery_failed\":true}".to_string(),
        };
        vector::push_back(&mut tracker.tracking_history, failure_event);

        // Move from active to failed
        let order_id = tracker.order_id;
        let (found, index) = vector::index_of(&manager.active_deliveries, &order_id);
        if (found) {
            vector::remove(&mut manager.active_deliveries, index);
            vector::push_back(&mut manager.failed_deliveries, order_id);
        };

        // Update failure metrics
        update_delivery_metrics(manager, false, current_time);
    }

    /// Update delivery success metrics
    fun update_delivery_metrics(manager: &mut LogisticsManager, success: bool, _current_time: u64) {
        let total_completed = vector::length(&manager.completed_deliveries);
        let total_failed = vector::length(&manager.failed_deliveries);
        let total_finished = total_completed + total_failed;
        
        if (total_finished > 0) {
            manager.successful_delivery_rate = (total_completed * 100) / total_finished;
        };
    }

    // ==================== ROUTE OPTIMIZATION ====================

    /// Create route optimizer for region
    public fun create_route_optimizer(
        region: String,
        optimization_frequency: u64,
        ctx: &mut TxContext
    ): RouteOptimizer {
        RouteOptimizer {
            id: object::new(ctx),
            region,
            pending_packages: vector::empty(),
            optimized_routes: vector::empty(),
            consolidation_opportunities: vector::empty(),
            efficiency_score: 100,
            last_optimization: 0,
            optimization_frequency,
        }
    }

    /// Add package to route optimization
    public fun add_package_to_optimizer(
        optimizer: &mut RouteOptimizer,
        package_id: ID
    ) {
        vector::push_back(&mut optimizer.pending_packages, package_id);
    }

    /// Optimize delivery routes for multiple packages
    public fun optimize_delivery_routes(
        manager: &mut LogisticsManager,
        optimizer: &mut RouteOptimizer,
        available_drones: vector<ID>,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        // Check if optimization is needed
        if (current_time - optimizer.last_optimization < optimizer.optimization_frequency) {
            return
        };

        // Clear previous optimizations
        optimizer.optimized_routes = vector::empty();
        optimizer.consolidation_opportunities = vector::empty();

        // Find consolidation opportunities
        find_consolidation_opportunities(optimizer);

        // Create optimized routes
        create_optimized_routes(optimizer, &available_drones);

        // Update metrics
        optimizer.last_optimization = current_time;
        manager.route_optimizations = manager.route_optimizations + 1;
        
        // Calculate efficiency score
        optimizer.efficiency_score = calculate_route_efficiency(optimizer);
    }

    /// Find package consolidation opportunities
    fun find_consolidation_opportunities(optimizer: &mut RouteOptimizer) {
        let package_count = vector::length(&optimizer.pending_packages);
        if (package_count < 2) return;

        // Simplified consolidation logic - group packages by region
        // Real implementation would use geographic clustering algorithms
        
        let consolidation = ConsolidationGroup {
            group_id: b"group_001".to_string(),
            packages: optimizer.pending_packages,
            pickup_location: b"Central Hub".to_string(),
            delivery_region: optimizer.region,
            consolidation_savings: 25, // 25% cost savings
            time_window: 3600000,      // 1 hour window
        };

        vector::push_back(&mut optimizer.consolidation_opportunities, consolidation);
    }

    /// Create optimized routes for packages
    fun create_optimized_routes(optimizer: &mut RouteOptimizer, available_drones: &vector<ID>) {
        let drone_count = vector::length(available_drones);
        if (drone_count == 0) return;

        let package_count = vector::length(&optimizer.pending_packages);
        if (package_count == 0) return;

        // Simplified route creation - distribute packages among drones
        let packages_per_drone = if (package_count < drone_count) { 1 } else { package_count / drone_count };
        
        let mut drone_index = 0;
        let mut package_index = 0;
        
        while (drone_index < drone_count && package_index < package_count) {
            let drone_id = *vector::borrow(available_drones, drone_index);
            let mut route_packages = vector::empty<ID>();
            
            // Assign packages to this drone
            let mut assigned = 0;
            while (assigned < packages_per_drone && package_index < package_count) {
                let package_id = *vector::borrow(&optimizer.pending_packages, package_index);
                vector::push_back(&mut route_packages, package_id);
                package_index = package_index + 1;
                assigned = assigned + 1;
            };

            // Create optimized route
            let route = OptimizedRoute {
                route_id: b"route_".to_string(),
                assigned_drone: drone_id,
                package_sequence: route_packages,
                total_distance: 5000,  // 5km estimated
                estimated_time: 1800000, // 30 minutes
                fuel_efficiency: 85,   // 85% efficiency
                priority_score: 75,    // Medium priority
                weather_factor: 90,    // Good weather
            };

            vector::push_back(&mut optimizer.optimized_routes, route);
            drone_index = drone_index + 1;
        };
    }

    /// Calculate route optimization efficiency
    fun calculate_route_efficiency(optimizer: &RouteOptimizer): u64 {
        let route_count = vector::length(&optimizer.optimized_routes);
        let consolidation_count = vector::length(&optimizer.consolidation_opportunities);
        
        // Simplified efficiency calculation
        let base_efficiency = 70;
        let route_bonus = route_count * 5;
        let consolidation_bonus = consolidation_count * 10;
        
        let total_efficiency = base_efficiency + route_bonus + consolidation_bonus;
        if (total_efficiency > 100) { 100 } else { total_efficiency }
    }

    // ==================== BACKUP COORDINATION ====================

    /// Create backup coordinator for region
    public fun create_backup_coordinator(
        region: String,
        ctx: &mut TxContext
    ): BackupCoordinator {
        BackupCoordinator {
            id: object::new(ctx),
            region,
            available_backups: vector::empty(),
            active_backups: vector::empty(),
            backup_success_rate: 100,
            average_response_time: 600000, // 10 minutes
            total_backup_activations: 0,
        }
    }

    /// Add backup drone to coordinator
    public fun add_backup_drone(
        coordinator: &mut BackupCoordinator,
        drone_id: ID
    ) {
        vector::push_back(&mut coordinator.available_backups, drone_id);
    }

    /// Activate backup drone for failed delivery
    public fun activate_backup_drone(
        manager: &mut LogisticsManager,
        coordinator: &mut BackupCoordinator,
        original_drone: ID,
        order_id: ID,
        activation_reason: u8,
        handoff_location: String,
        clock: &Clock,
        ctx: &mut TxContext
    ): Option<BackupAssignment> {
        let current_time = clock::timestamp_ms(clock);
        
        // Check if backup is available
        if (vector::length(&coordinator.available_backups) == 0) {
            return option::none()
        };

        // Select best backup drone (simplified - take first available)
        let backup_drone = vector::remove(&mut coordinator.available_backups, 0);

        // Create backup assignment
        let assignment = BackupAssignment {
            backup_drone,
            original_drone,
            order_id,
            activation_reason,
            activation_time: current_time,
            handoff_location,
            estimated_delay: 900000, // 15 minutes estimated delay
            status: BACKUP_ASSIGNED,
        };

        // Create a copy to return
        let assignment_copy = BackupAssignment {
            backup_drone,
            original_drone,
            order_id,
            activation_reason,
            activation_time: current_time,
            handoff_location,
            estimated_delay: 900000, // 15 minutes estimated delay
            status: BACKUP_ASSIGNED,
        };

        // Add to active backups
        vector::push_back(&mut coordinator.active_backups, assignment);
        
        // Update metrics
        coordinator.total_backup_activations = coordinator.total_backup_activations + 1;
        manager.backup_activations = manager.backup_activations + 1;

        option::some(assignment_copy)
    }

    /// Complete backup handoff
    public fun complete_backup_handoff(
        coordinator: &mut BackupCoordinator,
        assignment_index: u64,
        success: bool,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        if (assignment_index >= vector::length(&coordinator.active_backups)) {
            return
        };

        // Update assignment status and get activation time
        let activation_time = {
            let assignment_ref = vector::borrow(&coordinator.active_backups, assignment_index);
            assignment_ref.activation_time
        };
        
        // Update status separately
        {
            let assignment = vector::borrow_mut(&mut coordinator.active_backups, assignment_index);
            assignment.status = if (success) { BACKUP_HANDOFF_COMPLETE } else { BACKUP_FAILED };
        };

        // Update success rate
        let total_assignments = vector::length(&coordinator.active_backups);
        let mut successful = 0;
        let mut i = 0;
        
        while (i < total_assignments) {
            let assignment = vector::borrow(&coordinator.active_backups, i);
            if (assignment.status == BACKUP_HANDOFF_COMPLETE) {
                successful = successful + 1;
            };
            i = i + 1;
        };

        if (total_assignments > 0) {
            coordinator.backup_success_rate = (successful * 100) / total_assignments;
        };

        // Calculate response time
        let response_time = current_time - activation_time;
        coordinator.average_response_time = (coordinator.average_response_time + response_time) / 2;
    }

    // ==================== GETTER FUNCTIONS ====================

    public fun manager_active_deliveries(manager: &LogisticsManager): u64 {
        vector::length(&manager.active_deliveries)
    }

    public fun manager_completed_deliveries(manager: &LogisticsManager): u64 {
        vector::length(&manager.completed_deliveries)
    }

    public fun manager_success_rate(manager: &LogisticsManager): u64 {
        manager.successful_delivery_rate
    }

    public fun manager_average_delivery_time(manager: &LogisticsManager): u64 {
        manager.average_delivery_time
    }

    public fun tracker_current_status(tracker: &PackageTracker): u8 {
        tracker.current_status
    }

    public fun tracker_current_location(tracker: &PackageTracker): String {
        tracker.current_location
    }

    public fun tracker_alerts_count(tracker: &PackageTracker): u64 {
        vector::length(&tracker.condition_alerts)
    }

    public fun optimizer_efficiency_score(optimizer: &RouteOptimizer): u64 {
        optimizer.efficiency_score
    }

    public fun optimizer_pending_packages(optimizer: &RouteOptimizer): u64 {
        vector::length(&optimizer.pending_packages)
    }

    public fun coordinator_available_backups(coordinator: &BackupCoordinator): u64 {
        vector::length(&coordinator.available_backups)
    }

    public fun coordinator_backup_success_rate(coordinator: &BackupCoordinator): u64 {
        coordinator.backup_success_rate
    }

    // ==================== TEST HELPER FUNCTIONS ====================

    #[test_only]
    public fun create_test_logistics_manager(ctx: &mut TxContext): LogisticsManager {
        LogisticsManager {
            id: object::new(ctx),
            active_deliveries: vector::empty(),
            completed_deliveries: vector::empty(),
            failed_deliveries: vector::empty(),
            total_packages_processed: 0,
            successful_delivery_rate: 100,
            average_delivery_time: 1800000, // 30 minutes default
            backup_activations: 0,
            route_optimizations: 0,
        }
    }
} 