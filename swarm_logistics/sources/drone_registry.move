/// Autonomous drone registration and self-management system
module swarm_logistics::drone_registry {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::clock::{Self, Clock};
    use std::string::String;
    use std::vector;
    use swarm_logistics::drone::{Self as drone_mod, Drone, DroneFinancials};
    use swarm_logistics::events::{Self as events_mod, DroneRegistered};
    
    /// Different ownership models for drones
    public struct OwnershipModel has store, drop {
        model_type: u8,              // 0=Individual, 1=Fleet, 2=Autonomous, 3=DAO
        voting_power: u64,           // For DAO ownership
        profit_sharing: vector<u8>,  // How profits are distributed
        decision_authority: u8,      // Who can make decisions about the drone
    }

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
        _ownership_model: OwnershipModel,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate inputs
        assert!(drone_mod::is_valid_operation_mode(operation_mode), events_mod::e_invalid_operation_mode());
        assert!(drone_mod::is_valid_autonomy_level(autonomy_level), events_mod::e_invalid_autonomy_level());

        let current_time = clock::timestamp_ms(clock);
        let sender = tx_context::sender(ctx);

        // Create the drone using the constructor function
        let drone = drone_mod::new_drone(
            sender,
            operation_mode,
            autonomy_level,
            payload_capacity,
            max_range,
            service_area,
            initial_location,
            current_time,
            ctx
        );

        let drone_id = drone_mod::drone_id(&drone);

        // Create financial management
        let financials = drone_mod::new_drone_financials(drone_id, ctx);

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

        // Note: Event emission will be handled separately
        let _event = events_mod::new_drone_registered_event(
            drone_id,
            sender,
            operation_mode,
            autonomy_level,
            current_time,
        );

        // Transfer objects to the caller
        transfer::public_transfer(drone, sender);
        transfer::public_transfer(financials, sender);
        transfer::public_transfer(capability, sender);
    }

    /// Drone updates its own status autonomously
    public fun update_self_status(
        drone: &mut Drone,
        capability: &DroneCapability,
        new_status: u8,
        current_location: String,
        battery_level: u8,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        // Verify the drone can self-manage
        assert!(capability.can_self_manage, types::e_unauthorized_access());
        assert!(capability.drone_id == types::drone_id(drone), types::e_unauthorized_access());

        // Update drone status using setter functions
        types::set_drone_status(drone, new_status);
        types::set_drone_location(drone, current_location);
        types::set_drone_battery_level(drone, battery_level);

        // Auto-schedule maintenance if needed
        if (battery_level < 20 || types::is_maintenance_due(drone, clock::timestamp_ms(clock))) {
            types::set_drone_status(drone, types::status_maintenance());
        };
    }

    /// Autonomous decision making for order acceptance
    public fun evaluate_order_autonomous(
        drone: &Drone,
        _pickup_location: String,
        _dropoff_location: String,
        package_weight: u64,
        payment_amount: u64,
        priority: u8,
        clock: &Clock
    ): (bool, u64) {
        // Basic autonomous decision algorithm
        let mut should_accept = true;
        let mut estimated_time = 3600000; // 1 hour default

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
        let estimated_cost = calculate_delivery_cost(drone, _pickup_location, _dropoff_location);
        if (payment_amount < estimated_cost * 120 / 100) { // Require 20% profit margin
            should_accept = false;
        };

        // Adjust for priority
        if (priority == types::priority_emergency()) {
            should_accept = true; // Always accept emergency orders
            estimated_time = estimated_time * 80 / 100; // 20% faster
        };

        (should_accept, estimated_time)
    }

    /// Calculate estimated delivery cost
    fun calculate_delivery_cost(
        _drone: &Drone,
        _pickup_location: String,
        _dropoff_location: String
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
        _coordination_type: u8,
        _location: String,
        _ctx: &mut TxContext
    ) {
        assert!(capability.can_coordinate, types::e_unauthorized_access());
        assert!(capability.drone_id == types::drone_id(drone), types::e_unauthorized_access());

        // Add to coordination history
        let event_id = object::id_from_address(@0x1); // Placeholder
        types::add_coordination_event(drone, event_id);
    }

    /// Update drone reputation based on performance
    public fun update_reputation(
        drone: &mut Drone,
        registry: &mut DroneRegistry,
        performance_score: u64, // 0-100
        _ctx: &mut TxContext
    ) {
        // Update individual drone reputation
        types::update_drone_reputation(drone, performance_score);

        // Update network-wide reputation
        registry.network_reputation = (registry.network_reputation * 99 + performance_score) / 100;
    }

    /// Autonomous maintenance scheduling
    public fun schedule_autonomous_maintenance(
        drone: &mut Drone,
        financials: &mut DroneFinancials,
        _maintenance_type: u8,
        estimated_cost: u64,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        // Check if drone has sufficient funds
        assert!(types::financials_maintenance_fund(financials) >= estimated_cost, types::e_insufficient_funds());

        // Schedule maintenance
        types::set_drone_status(drone, types::status_maintenance());
        types::set_drone_maintenance_due(drone, clock::timestamp_ms(clock) + (30 * 24 * 60 * 60 * 1000)); // Next month

        // Deduct from maintenance fund
        types::deduct_maintenance_fund(financials, estimated_cost);
        types::add_operational_cost(financials, estimated_cost);
    }

    /// Get drone statistics
    public fun get_drone_stats(drone: &Drone): (u64, u64, u64, u64) {
        (
            types::drone_delivery_count(drone),
            types::drone_success_rate(drone),
            types::drone_earnings(drone),
            types::drone_swarm_reputation(drone)
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
        types::drone_battery_level(drone) > 50
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }
}