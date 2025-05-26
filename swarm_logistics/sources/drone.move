/// Core drone structures and functionality
module swarm_logistics::drone {
    use sui::object::{Self, ID, UID};
    use std::string::String;
    use std::vector;

    // ==================== DRONE STRUCTURES ====================

    /// Represents an autonomous drone in the delivery network
    public struct Drone has key, store {
        id: UID,
        owner: address,
        operation_mode: u8,          // 0=FullyAutonomous, 1=Teleoperated, 2=Hybrid
        autonomy_level: u8,          // 0-100 (capability level)
        status: u8,                  // 0=Available, 1=Busy, 2=Charging, 3=Maintenance, 4=Offline
        current_location: String,    // GPS coordinates as string
        battery_level: u8,           // 0-100 percentage
        payload_capacity: u64,       // Maximum payload in grams
        max_range: u64,              // Maximum range in meters
        service_area: String,        // Geographic service boundary
        delivery_count: u64,         // Total completed deliveries
        success_rate: u64,           // Success rate percentage (0-100)
        earnings_balance: u64,       // Accumulated earnings in MIST
        last_maintenance: u64,       // Timestamp of last maintenance
        maintenance_due: u64,        // Timestamp when maintenance is due
        created_at: u64,
        // Swarm coordination data
        swarm_reputation: u64,       // Reputation score for swarm coordination
        coordination_history: vector<ID>, // Recent coordination events
    }

    /// Financial management for autonomous drones
    public struct DroneFinancials has key, store {
        id: UID,
        drone_id: ID,
        total_earnings: u64,
        maintenance_fund: u64,       // Auto-allocated for maintenance
        upgrade_fund: u64,           // Saving for hardware upgrades
        insurance_fund: u64,         // Self-insurance for damages
        operational_costs: u64,      // Electricity, wear-and-tear
        revenue_share: RevenueShare,
    }

    /// Revenue sharing configuration
    public struct RevenueShare has store {
        drone_percentage: u8,        // What the drone keeps
        owner_percentage: u8,        // What the owner gets
        platform_percentage: u8,     // Platform fee
        maintenance_percentage: u8,   // Auto-allocated for maintenance
    }

    // ==================== CONSTANTS ====================

    // Operation modes
    const FULLY_AUTONOMOUS: u8 = 0;
    const TELEOPERATED: u8 = 1;
    const HYBRID: u8 = 2;

    // Drone status
    const STATUS_AVAILABLE: u8 = 0;
    const STATUS_BUSY: u8 = 1;
    const STATUS_CHARGING: u8 = 2;
    const STATUS_MAINTENANCE: u8 = 3;
    const STATUS_OFFLINE: u8 = 4;

    // ==================== CONSTRUCTOR FUNCTIONS ====================

    /// Create a new drone
    public fun new_drone(
        owner: address,
        operation_mode: u8,
        autonomy_level: u8,
        payload_capacity: u64,
        max_range: u64,
        service_area: String,
        initial_location: String,
        current_time: u64,
        ctx: &mut sui::tx_context::TxContext
    ): Drone {
        let drone_uid = sui::object::new(ctx);
        Drone {
            id: drone_uid,
            owner,
            operation_mode,
            autonomy_level,
            status: STATUS_AVAILABLE,
            current_location: initial_location,
            battery_level: 100,
            payload_capacity,
            max_range,
            service_area,
            delivery_count: 0,
            success_rate: 100,
            earnings_balance: 0,
            last_maintenance: current_time,
            maintenance_due: current_time + (30 * 24 * 60 * 60 * 1000),
            created_at: current_time,
            swarm_reputation: 100,
            coordination_history: vector::empty(),
        }
    }

    /// Create new drone financials
    public fun new_drone_financials(
        drone_id: ID,
        ctx: &mut sui::tx_context::TxContext
    ): DroneFinancials {
        let revenue_share = RevenueShare {
            drone_percentage: 60,
            owner_percentage: 30,
            platform_percentage: 5,
            maintenance_percentage: 5,
        };

        DroneFinancials {
            id: sui::object::new(ctx),
            drone_id,
            total_earnings: 0,
            maintenance_fund: 0,
            upgrade_fund: 0,
            insurance_fund: 0,
            operational_costs: 0,
            revenue_share,
        }
    }

    // ==================== CONSTANT GETTER FUNCTIONS ====================

    public fun fully_autonomous(): u8 { FULLY_AUTONOMOUS }
    public fun teleoperated(): u8 { TELEOPERATED }
    public fun hybrid(): u8 { HYBRID }

    public fun status_available(): u8 { STATUS_AVAILABLE }
    public fun status_busy(): u8 { STATUS_BUSY }
    public fun status_charging(): u8 { STATUS_CHARGING }
    public fun status_maintenance(): u8 { STATUS_MAINTENANCE }
    public fun status_offline(): u8 { STATUS_OFFLINE }

    // ==================== GETTER FUNCTIONS ====================

    public fun drone_id(drone: &Drone): ID {
        object::uid_to_inner(&drone.id)
    }

    public fun drone_owner(drone: &Drone): address {
        drone.owner
    }

    public fun drone_status(drone: &Drone): u8 {
        drone.status
    }

    public fun drone_battery_level(drone: &Drone): u8 {
        drone.battery_level
    }

    public fun drone_earnings(drone: &Drone): u64 {
        drone.earnings_balance
    }

    public fun drone_delivery_count(drone: &Drone): u64 {
        drone.delivery_count
    }

    public fun drone_success_rate(drone: &Drone): u64 {
        drone.success_rate
    }

    public fun drone_swarm_reputation(drone: &Drone): u64 {
        drone.swarm_reputation
    }

    public fun financials_maintenance_fund(financials: &DroneFinancials): u64 {
        financials.maintenance_fund
    }

    // ==================== SETTER FUNCTIONS ====================

    public fun set_drone_status(drone: &mut Drone, status: u8) {
        drone.status = status;
    }

    public fun set_drone_location(drone: &mut Drone, location: String) {
        drone.current_location = location;
    }

    public fun set_drone_battery_level(drone: &mut Drone, battery_level: u8) {
        drone.battery_level = battery_level;
    }

    public fun set_drone_maintenance_due(drone: &mut Drone, maintenance_due: u64) {
        drone.maintenance_due = maintenance_due;
    }

    public fun update_drone_reputation(drone: &mut Drone, performance_score: u64) {
        drone.swarm_reputation = (drone.swarm_reputation * 9 + performance_score) / 10;
    }

    public fun add_coordination_event(drone: &mut Drone, event_id: ID) {
        vector::push_back(&mut drone.coordination_history, event_id);
        if (vector::length(&drone.coordination_history) > 10) {
            vector::remove(&mut drone.coordination_history, 0);
        };
    }

    public fun deduct_maintenance_fund(financials: &mut DroneFinancials, amount: u64) {
        financials.maintenance_fund = financials.maintenance_fund - amount;
    }

    public fun add_operational_cost(financials: &mut DroneFinancials, amount: u64) {
        financials.operational_costs = financials.operational_costs + amount;
    }

    // ==================== VALIDATION FUNCTIONS ====================

    public fun is_valid_operation_mode(mode: u8): bool {
        mode <= HYBRID
    }

    public fun is_valid_autonomy_level(level: u8): bool {
        level <= 100
    }

    public fun is_drone_available(drone: &Drone): bool {
        drone.status == STATUS_AVAILABLE && drone.battery_level > 20
    }

    public fun can_carry_payload(drone: &Drone, weight: u64): bool {
        weight <= drone.payload_capacity
    }

    public fun is_maintenance_due(drone: &Drone, current_time: u64): bool {
        current_time >= drone.maintenance_due
    }
} 