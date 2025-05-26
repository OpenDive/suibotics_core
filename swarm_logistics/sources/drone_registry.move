/// Autonomous drone registration and self-management system
module swarm_logistics::drone_registry {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::clock::{Self, Clock};
    use std::string::String;
    use std::option::{Self, Option};
    use swarm_logistics::types::{
        Self, Drone, DroneFinancials, RevenueShare, OwnershipModel, DroneRegistered,
        E_INVALID_OPERATION_MODE, E_INVALID_AUTONOMY_LEVEL, E_UNAUTHORIZED_ACCESS
    };

    /// Global registry of all drones in the swarm
    public struct DroneRegistry has key {
        id: UID,
        total_drones: u64,
        active_drones: u64,
        total_deliveries: u64,
        network_reputation: u64,
    }

    /// Capability for drone self-management
    public struct DroneCapability has key, store {
        id: UID,
        drone_id: ID,
        can_self_manage: bool,
        can_coordinate: bool,
        can_emergency_assist: bool,
    }

    /// Initialize the drone registry
    fun init(ctx: &mut TxContext) {
        let registry = DroneRegistry {
            id: object::new(ctx),
            total_drones: 0,
            active_drones: 0,
            total_deliveries: 0,
            network_reputation: 100, // Start with perfect reputation
        };
        transfer::share_object(registry);
    }

    /// Drone registers itself in the network
    public fun self_register_drone(
        registry: &mut DroneRegistry,
        operation_mode: u8,
        autonomy_level: u8,
        payload_capacity: u64,
        max_range: u64,
        service_area: String,
        initial_location: String,
        ownership_model: OwnershipModel,
        clock: &Clock,
        ctx: &mut TxContext
    ): (Drone, DroneFinancials, DroneCapability) {
        // Validate inputs
        assert!(types::is_valid_operation_mode(operation_mode), E_INVALID_OPERATION_MODE);
        assert!(types::is_valid_autonomy_level(autonomy_level), E_INVALID_AUTONOMY_LEVEL);

        let current_time = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);

        // Create the drone
        let drone_uid = object::new(ctx);
        let drone_id = object::uid_to_inner(&drone_uid);
        
        let drone = Drone {
            id: drone_uid,
            owner: sender,
            operation_mode,
            autonomy_level,
            status: types::STATUS_AVAILABLE,
            current_location: initial_location,
            battery_level: 100, // Start fully charged
            payload_capacity,
            max_range,
            service_area,
            delivery_count: 0,
            success_rate: 100, // Start with perfect rating
            earnings_balance: 0,
            last_maintenance: current_time,
            maintenance_due: current_time + (30 * 24 * 60 * 60 * 1000), // 30 days
            created_at: current_time,
            swarm_reputation: 100,
            coordination_history: vector::empty(),
        };

        // Create financial management
        let revenue_share = RevenueShare {
            drone_percentage: 60,
            owner_percentage: 30,
            platform_percentage: 5,
            maintenance_percentage: 5,
        };

        let financials = DroneFinancials {
            id: object::new(ctx),
            drone_id,
            total_earnings: 0,
            maintenance_fund: 0,
            upgrade_fund: 0,
            insurance_fund: 0,
            operational_costs: 0,
            revenue_share,
        };

        // Create capability for autonomous operations
        let capability = DroneCapability {
            id: object::new(ctx),
            drone_id,
            can_self_manage: autonomy_level >= 50,
            can_coordinate: autonomy_level >= 70,
            can_emergency_assist: autonomy_level >= 80,
        };

        // Update registry
        registry.total_drones = registry.total_drones + 1;
        registry.active_drones = registry.active_drones + 1;

        // Emit registration event
        event::emit(DroneRegistered {
            drone_id,
            owner: sender,
            operation_mode,
            autonomy_level,
            timestamp: current_time,
        });

        (drone, financials, capability)
    }

    /// Drone updates its own status autonomously
    public fun update_self_status(
        drone: &mut Drone,
        capability: &DroneCapability,
        new_status: u8,
        current_location: String,
        battery_level: u8,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Verify the drone can self-manage
        assert!(capability.can_self_manage, E_UNAUTHORIZED_ACCESS);
        assert!(capability.drone_id == types::drone_id(drone), E_UNAUTHORIZED_ACCESS);

        // Update drone status
        drone.status = new_status;
        drone.current_location = current_location;
        drone.battery_level = battery_level;

        // Auto-schedule maintenance if needed
        if (battery_level < 20 || types::is_maintenance_due(drone, clock::timestamp_ms(clock))) {
            drone.status = types::STATUS_MAINTENANCE;
        };
    }

    /// Autonomous decision making for order acceptance
    public fun evaluate_order_autonomous(
        drone: &Drone,
        pickup_location: String,
        dropoff_location: String,
        package_weight: u64,
        payment_amount: u64,
        priority: u8,
        clock: &Clock
    ): (bool, u64) {
        // Basic autonomous decision algorithm
        let should_accept = true;
        let estimated_time = 3600000; // 1 hour default

        // Check if drone is available
        if (!types::is_drone_available(drone)) {
            return (false, 0)
        };

        // Check payload capacity
        if (!types::can_carry_payload(drone, package_weight)) {
            return (false, 0)
        };

        // Check if maintenance is due
        if (types::is_maintenance_due(drone, clock::timestamp_ms(clock))) {
            return (false, 0)
        };

        // Simple profitability check
        let estimated_cost = calculate_delivery_cost(drone, pickup_location, dropoff_location);
        if (payment_amount < estimated_cost * 120 / 100) { // Require 20% profit margin
            should_accept = false;
        };

        // Adjust for priority
        if (priority == types::PRIORITY_EMERGENCY) {
            should_accept = true; // Always accept emergency orders
            estimated_time = estimated_time * 80 / 100; // 20% faster
        };

        (should_accept, estimated_time)
    }

    /// Calculate estimated delivery cost
    fun calculate_delivery_cost(
        drone: &Drone,
        pickup_location: String,
        dropoff_location: String
    ): u64 {
        // Simplified cost calculation
        // In reality, this would use GPS coordinates and routing algorithms
        let base_cost = 1000000; // 1 SUI in MIST
        let distance_factor = 100; // Simplified distance calculation
        
        base_cost + distance_factor * 10000 // Add distance-based cost
    }

    /// Drone requests to join a swarm coordination event
    public fun request_swarm_coordination(
        drone: &mut Drone,
        capability: &DroneCapability,
        coordination_type: u8,
        location: String,
        ctx: &mut TxContext
    ) {
        assert!(capability.can_coordinate, E_UNAUTHORIZED_ACCESS);
        assert!(capability.drone_id == types::drone_id(drone), E_UNAUTHORIZED_ACCESS);

        // Add to coordination history
        let event_id = object::id_from_address(@0x1); // Placeholder
        vector::push_back(&mut drone.coordination_history, event_id);

        // Limit history to last 10 events
        if (vector::length(&drone.coordination_history) > 10) {
            vector::remove(&mut drone.coordination_history, 0);
        };
    }

    /// Update drone reputation based on performance
    public fun update_reputation(
        drone: &mut Drone,
        registry: &mut DroneRegistry,
        performance_score: u64, // 0-100
        ctx: &mut TxContext
    ) {
        // Update individual drone reputation
        drone.swarm_reputation = (drone.swarm_reputation * 9 + performance_score) / 10;

        // Update network-wide reputation
        registry.network_reputation = (registry.network_reputation * 99 + performance_score) / 100;
    }

    /// Autonomous maintenance scheduling
    public fun schedule_autonomous_maintenance(
        drone: &mut Drone,
        financials: &mut DroneFinancials,
        maintenance_type: u8,
        estimated_cost: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Check if drone has sufficient funds
        assert!(financials.maintenance_fund >= estimated_cost, E_INSUFFICIENT_FUNDS);

        // Schedule maintenance
        drone.status = types::STATUS_MAINTENANCE;
        drone.maintenance_due = clock::timestamp_ms(clock) + (30 * 24 * 60 * 60 * 1000); // Next month

        // Deduct from maintenance fund
        financials.maintenance_fund = financials.maintenance_fund - estimated_cost;
        financials.operational_costs = financials.operational_costs + estimated_cost;
    }

    /// Get drone statistics
    public fun get_drone_stats(drone: &Drone): (u64, u64, u64, u64) {
        (
            drone.delivery_count,
            drone.success_rate,
            drone.earnings_balance,
            drone.swarm_reputation
        )
    }

    /// Get registry statistics
    public fun get_registry_stats(registry: &DroneRegistry): (u64, u64, u64, u64) {
        (
            registry.total_drones,
            registry.active_drones,
            registry.total_deliveries,
            registry.network_reputation
        )
    }

    /// Check if drone can perform emergency assistance
    public fun can_provide_emergency_assistance(
        drone: &Drone,
        capability: &DroneCapability
    ): bool {
        capability.can_emergency_assist && 
        types::is_drone_available(drone) && 
        drone.battery_level > 50
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}