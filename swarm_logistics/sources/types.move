/// Core data structures for the autonomous drone delivery system
module swarm_logistics::types {
    use sui::object::{Self, ID, UID};
    use std::string::String;
    use std::option::Option;
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

    // ==================== ORDER STRUCTURES ====================

    /// Delivery order in the system
    public struct DeliveryOrder has key, store {
        id: UID,
        customer: address,
        pickup_location: String,
        dropoff_location: String,
        package_description: String,
        package_weight: u64,         // in grams
        package_dimensions: String,   // "length,width,height" in cm
        payment_amount: u64,         // in MIST
        priority_level: u8,          // 0=Standard, 1=Express, 2=Emergency
        status: u8,                  // 0=Created, 1=Assigned, 2=PickedUp, 3=InTransit, 4=Delivered, 5=Completed, 6=Cancelled
        assigned_drone: Option<ID>,
        created_at: u64,
        pickup_deadline: u64,
        delivery_deadline: u64,
        estimated_delivery: u64,
        actual_delivery: Option<u64>,
        // Special requirements
        requires_signature: bool,
        requires_refrigeration: bool,
        fragile: bool,
        // Autonomous coordination
        backup_drones: vector<ID>,   // Backup drones in case of failure
        route_optimization_data: String, // Encoded route data
    }

    // ==================== SWARM COORDINATION STRUCTURES ====================

    /// Airspace slot for drone coordination
    public struct AirspaceSlot has key, store {
        id: UID,
        route_hash: String,          // Hash of the route
        time_start: u64,
        time_end: u64,
        reserved_by: ID,             // Drone ID
        altitude_range: String,      // "min_alt,max_alt" in meters
        priority: u8,                // 0=Normal, 1=Emergency
    }

    /// Emergency assistance request between drones
    public struct EmergencyRequest has key, store {
        id: UID,
        requesting_drone: ID,
        location: String,
        assistance_type: u8,         // 0=Battery, 1=Pickup, 2=Navigation, 3=Repair
        urgency: u8,                 // 0=Low, 1=Medium, 2=High, 3=Critical
        responding_drones: vector<ID>,
        status: u8,                  // 0=Open, 1=InProgress, 2=Resolved, 3=Cancelled
        created_at: u64,
        resolved_at: Option<u64>,
    }

    /// Swarm coordination event
    public struct CoordinationEvent has key, store {
        id: UID,
        event_type: u8,              // 0=AirspaceRequest, 1=EmergencyAssist, 2=LoadBalance, 3=RouteShare
        participating_drones: vector<ID>,
        location: String,
        timestamp: u64,
        outcome: u8,                 // 0=Success, 1=Failed, 2=Partial
        reputation_impact: vector<u64>, // Reputation changes for each drone
    }

    // ==================== MAINTENANCE STRUCTURES ====================

    /// Maintenance record for drones
    public struct MaintenanceRecord has key, store {
        id: UID,
        drone_id: ID,
        maintenance_type: u8,        // 0=Routine, 1=Repair, 2=Upgrade, 3=Emergency
        scheduled_time: u64,
        actual_time: Option<u64>,
        cost: u64,
        provider: address,           // Maintenance provider
        status: u8,                  // 0=Scheduled, 1=InProgress, 2=Completed, 3=Cancelled
        parts_replaced: vector<String>,
        performance_impact: String,   // JSON data about performance changes
    }

    /// Maintenance provider in the network
    public struct MaintenanceProvider has key, store {
        id: UID,
        provider_address: address,
        location: String,
        services_offered: vector<u8>, // Types of maintenance offered
        reputation: u64,             // 0-100 reputation score
        pricing: vector<u64>,        // Pricing for different service types
        availability: String,        // Schedule availability
        certification_level: u8,    // 0=Basic, 1=Advanced, 2=Certified, 3=Premium
    }

    // ==================== OWNERSHIP STRUCTURES ====================

    /// Different ownership models for drones
    public struct OwnershipModel has store {
        model_type: u8,              // 0=Individual, 1=Fleet, 2=Autonomous, 3=DAO
        voting_power: u64,           // For DAO ownership
        profit_sharing: vector<u8>,  // How profits are distributed
        decision_authority: u8,      // Who can make decisions about the drone
    }

    /// DAO for collective drone ownership
    public struct DroneDAO has key, store {
        id: UID,
        name: String,
        owned_drones: vector<ID>,
        members: vector<address>,
        voting_tokens: u64,
        treasury_balance: u64,
        governance_rules: String,    // JSON encoded governance rules
        active_proposals: vector<ID>,
    }

    /// Proposal for DAO governance
    public struct Proposal has key, store {
        id: UID,
        dao_id: ID,
        proposer: address,
        proposal_type: u8,           // 0=BuyDrone, 1=SellDrone, 2=Upgrade, 3=ChangeRules
        description: String,
        voting_deadline: u64,
        votes_for: u64,
        votes_against: u64,
        executed: bool,
        proposal_data: String,       // JSON encoded proposal details
    }

    // ==================== ENVIRONMENTAL DATA ====================

    /// Environmental conditions affecting drone operations
    public struct EnvironmentData has store {
        weather_condition: u8,       // 0=Clear, 1=Rain, 2=Snow, 3=Wind, 4=Storm
        visibility: u8,              // 0-100 visibility percentage
        wind_speed: u64,             // km/h
        temperature: u64,            // Celsius * 100 (to handle decimals, changed from i32 to u64)
        air_traffic_density: u8,     // 0=Low, 1=Medium, 2=High, 3=Critical
        no_fly_zones: vector<String>, // Active no-fly zone coordinates
    }

    // ==================== EVENTS ====================

    /// Event emitted when a drone registers itself
    public struct DroneRegistered has copy, drop {
        drone_id: ID,
        owner: address,
        operation_mode: u8,
        autonomy_level: u8,
        timestamp: u64,
    }

    /// Event emitted when an order is created
    public struct OrderCreated has copy, drop {
        order_id: ID,
        customer: address,
        pickup_location: String,
        dropoff_location: String,
        payment_amount: u64,
        timestamp: u64,
    }

    /// Event emitted when a drone accepts an order
    public struct OrderAccepted has copy, drop {
        order_id: ID,
        drone_id: ID,
        estimated_completion: u64,
        timestamp: u64,
    }

    /// Event emitted when delivery is completed
    public struct DeliveryCompleted has copy, drop {
        order_id: ID,
        drone_id: ID,
        actual_delivery_time: u64,
        customer_rating: Option<u8>,
        timestamp: u64,
    }

    /// Event emitted for swarm coordination
    public struct SwarmCoordination has copy, drop {
        event_type: u8,
        participating_drones: vector<ID>,
        location: String,
        timestamp: u64,
    }

    /// Event emitted for emergency situations
    public struct EmergencyDeclared has copy, drop {
        drone_id: ID,
        emergency_type: u8,
        location: String,
        severity: u8,
        timestamp: u64,
    }

    // ==================== ERROR CODES ====================

    /// Error codes for the swarm logistics system
    const E_INVALID_OPERATION_MODE: u64 = 1;
    const E_INSUFFICIENT_BATTERY: u64 = 2;
    const E_PAYLOAD_TOO_HEAVY: u64 = 3;
    const E_OUT_OF_RANGE: u64 = 4;
    const E_DRONE_NOT_AVAILABLE: u64 = 5;
    const E_INVALID_AUTONOMY_LEVEL: u64 = 6;
    const E_MAINTENANCE_OVERDUE: u64 = 7;
    const E_INSUFFICIENT_FUNDS: u64 = 8;
    const E_INVALID_COORDINATES: u64 = 9;
    const E_AIRSPACE_CONFLICT: u64 = 10;
    const E_EMERGENCY_ACTIVE: u64 = 11;
    const E_UNAUTHORIZED_ACCESS: u64 = 12;
    const E_INVALID_PROPOSAL: u64 = 13;
    const E_VOTING_PERIOD_ENDED: u64 = 14;
    const E_SWARM_COORDINATION_FAILED: u64 = 15;

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

    // Order status
    const ORDER_CREATED: u8 = 0;
    const ORDER_ASSIGNED: u8 = 1;
    const ORDER_PICKED_UP: u8 = 2;
    const ORDER_IN_TRANSIT: u8 = 3;
    const ORDER_DELIVERED: u8 = 4;
    const ORDER_COMPLETED: u8 = 5;
    const ORDER_CANCELLED: u8 = 6;

    // Priority levels
    const PRIORITY_STANDARD: u8 = 0;
    const PRIORITY_EXPRESS: u8 = 1;
    const PRIORITY_EMERGENCY: u8 = 2;

    // Emergency types
    const EMERGENCY_LOW_BATTERY: u8 = 0;
    const EMERGENCY_MALFUNCTION: u8 = 1;
    const EMERGENCY_WEATHER: u8 = 2;
    const EMERGENCY_OBSTACLE: u8 = 3;
    const EMERGENCY_THEFT: u8 = 4;

    // Ownership models
    const OWNERSHIP_INDIVIDUAL: u8 = 0;
    const OWNERSHIP_FLEET: u8 = 1;
    const OWNERSHIP_AUTONOMOUS: u8 = 2;
    const OWNERSHIP_DAO: u8 = 3;

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

    public fun order_id(order: &DeliveryOrder): ID {
        object::uid_to_inner(&order.id)
    }

    public fun order_status(order: &DeliveryOrder): u8 {
        order.status
    }

    public fun order_customer(order: &DeliveryOrder): address {
        order.customer
    }

    public fun order_payment_amount(order: &DeliveryOrder): u64 {
        order.payment_amount
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

    public fun calculate_distance_cost(distance: u64, base_rate: u64): u64 {
        // Simple distance-based pricing
        base_rate + (distance / 1000) * (base_rate / 10)
    }
}