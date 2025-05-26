/// Swarm coordination and emergency assistance functionality
module swarm_logistics::swarm {
    use sui::object::{Self, ID, UID};
    use std::string::String;
    use std::option::Option;
    use std::vector;

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

    /// Environmental conditions affecting drone operations
    public struct EnvironmentData has store, drop {
        weather_condition: u8,       // 0=Clear, 1=Rain, 2=Snow, 3=Wind, 4=Storm
        visibility: u8,              // 0-100 visibility percentage
        wind_speed: u64,             // km/h
        temperature: u64,            // Celsius * 100 (to handle decimals)
        air_traffic_density: u8,     // 0=Low, 1=Medium, 2=High, 3=Critical
        no_fly_zones: vector<String>, // Active no-fly zone coordinates
    }

    // ==================== CONSTANTS ====================

    // Emergency types
    const EMERGENCY_LOW_BATTERY: u8 = 0;
    const EMERGENCY_MALFUNCTION: u8 = 1;
    const EMERGENCY_WEATHER: u8 = 2;
    const EMERGENCY_OBSTACLE: u8 = 3;
    const EMERGENCY_THEFT: u8 = 4;

    // Coordination event types
    const COORD_AIRSPACE_REQUEST: u8 = 0;
    const COORD_EMERGENCY_ASSIST: u8 = 1;
    const COORD_LOAD_BALANCE: u8 = 2;
    const COORD_ROUTE_SHARE: u8 = 3;

    // Emergency urgency levels
    const URGENCY_LOW: u8 = 0;
    const URGENCY_MEDIUM: u8 = 1;
    const URGENCY_HIGH: u8 = 2;
    const URGENCY_CRITICAL: u8 = 3;

    // Emergency status
    const EMERGENCY_OPEN: u8 = 0;
    const EMERGENCY_IN_PROGRESS: u8 = 1;
    const EMERGENCY_RESOLVED: u8 = 2;
    const EMERGENCY_CANCELLED: u8 = 3;

    // Weather conditions
    const WEATHER_CLEAR: u8 = 0;
    const WEATHER_RAIN: u8 = 1;
    const WEATHER_SNOW: u8 = 2;
    const WEATHER_WIND: u8 = 3;
    const WEATHER_STORM: u8 = 4;

    // ==================== CONSTANT GETTER FUNCTIONS ====================

    public fun emergency_low_battery(): u8 { EMERGENCY_LOW_BATTERY }
    public fun emergency_malfunction(): u8 { EMERGENCY_MALFUNCTION }
    public fun emergency_weather(): u8 { EMERGENCY_WEATHER }
    public fun emergency_obstacle(): u8 { EMERGENCY_OBSTACLE }
    public fun emergency_theft(): u8 { EMERGENCY_THEFT }

    public fun coord_airspace_request(): u8 { COORD_AIRSPACE_REQUEST }
    public fun coord_emergency_assist(): u8 { COORD_EMERGENCY_ASSIST }
    public fun coord_load_balance(): u8 { COORD_LOAD_BALANCE }
    public fun coord_route_share(): u8 { COORD_ROUTE_SHARE }

    public fun urgency_low(): u8 { URGENCY_LOW }
    public fun urgency_medium(): u8 { URGENCY_MEDIUM }
    public fun urgency_high(): u8 { URGENCY_HIGH }
    public fun urgency_critical(): u8 { URGENCY_CRITICAL }

    // ==================== CONSTRUCTOR FUNCTIONS ====================

    /// Create new environment data
    public fun new_environment_data(
        weather_condition: u8,
        visibility: u8,
        wind_speed: u64,
        temperature: u64,
        air_traffic_density: u8,
        no_fly_zones: vector<String>
    ): EnvironmentData {
        EnvironmentData {
            weather_condition,
            visibility,
            wind_speed,
            temperature,
            air_traffic_density,
            no_fly_zones,
        }
    }

    /// Create a new emergency request
    public fun new_emergency_request(
        requesting_drone: ID,
        location: String,
        assistance_type: u8,
        urgency: u8,
        timestamp: u64,
        ctx: &mut sui::tx_context::TxContext
    ): EmergencyRequest {
        EmergencyRequest {
            id: sui::object::new(ctx),
            requesting_drone,
            location,
            assistance_type,
            urgency,
            responding_drones: vector::empty(),
            status: EMERGENCY_OPEN,
            created_at: timestamp,
            resolved_at: std::option::none(),
        }
    }

    /// Create a new airspace slot
    public fun new_airspace_slot(
        route_hash: String,
        time_start: u64,
        time_end: u64,
        reserved_by: ID,
        altitude_range: String,
        priority: u8,
        ctx: &mut sui::tx_context::TxContext
    ): AirspaceSlot {
        AirspaceSlot {
            id: sui::object::new(ctx),
            route_hash,
            time_start,
            time_end,
            reserved_by,
            altitude_range,
            priority,
        }
    }

    /// Create a new coordination event
    public fun new_coordination_event(
        event_type: u8,
        participating_drones: vector<ID>,
        location: String,
        timestamp: u64,
        ctx: &mut sui::tx_context::TxContext
    ): CoordinationEvent {
        CoordinationEvent {
            id: sui::object::new(ctx),
            event_type,
            participating_drones,
            location,
            timestamp,
            outcome: 0, // Default to success
            reputation_impact: vector::empty(),
        }
    }

    // ==================== GETTER FUNCTIONS ====================

    public fun emergency_id(request: &EmergencyRequest): ID {
        object::uid_to_inner(&request.id)
    }

    public fun emergency_requesting_drone(request: &EmergencyRequest): ID {
        request.requesting_drone
    }

    public fun emergency_assistance_type(request: &EmergencyRequest): u8 {
        request.assistance_type
    }

    public fun emergency_urgency(request: &EmergencyRequest): u8 {
        request.urgency
    }

    public fun emergency_status(request: &EmergencyRequest): u8 {
        request.status
    }

    public fun airspace_reserved_by(slot: &AirspaceSlot): ID {
        slot.reserved_by
    }

    public fun airspace_time_start(slot: &AirspaceSlot): u64 {
        slot.time_start
    }

    public fun airspace_time_end(slot: &AirspaceSlot): u64 {
        slot.time_end
    }

    public fun airspace_id(slot: &AirspaceSlot): ID {
        object::uid_to_inner(&slot.id)
    }

    public fun coordination_event_id(event: &CoordinationEvent): ID {
        object::uid_to_inner(&event.id)
    }

    // ==================== SETTER FUNCTIONS ====================

    public fun add_responding_drone(request: &mut EmergencyRequest, drone_id: ID) {
        vector::push_back(&mut request.responding_drones, drone_id);
        request.status = EMERGENCY_IN_PROGRESS;
    }

    public fun resolve_emergency(request: &mut EmergencyRequest, timestamp: u64) {
        request.status = EMERGENCY_RESOLVED;
        request.resolved_at = std::option::some(timestamp);
    }

    public fun set_coordination_outcome(event: &mut CoordinationEvent, outcome: u8) {
        event.outcome = outcome;
    }

    // ==================== VALIDATION FUNCTIONS ====================

    public fun is_emergency_active(request: &EmergencyRequest): bool {
        request.status < EMERGENCY_RESOLVED
    }

    public fun is_airspace_available(slot: &AirspaceSlot, current_time: u64): bool {
        current_time < slot.time_start || current_time > slot.time_end
    }

    public fun is_weather_suitable_for_flight(weather: &EnvironmentData): bool {
        weather.weather_condition < WEATHER_STORM && weather.visibility > 50
    }

    // ==================== ENVIRONMENT DATA GETTER FUNCTIONS ====================

    public fun environment_weather_condition(weather: &EnvironmentData): u8 {
        weather.weather_condition
    }

    public fun environment_wind_speed(weather: &EnvironmentData): u64 {
        weather.wind_speed
    }

    public fun environment_visibility(weather: &EnvironmentData): u8 {
        weather.visibility
    }

    public fun environment_temperature(weather: &EnvironmentData): u64 {
        weather.temperature
    }

    public fun environment_air_traffic_density(weather: &EnvironmentData): u8 {
        weather.air_traffic_density
    }

    public fun calculate_coordination_score(
        participating_drones: &vector<ID>,
        outcome: u8
    ): u64 {
        let base_score = if (outcome == 0) { 100 } else { 50 }; // Success vs failure
        let participation_bonus = vector::length(participating_drones) * 10;
        base_score + participation_bonus
    }
} 