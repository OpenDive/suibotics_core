/// Autonomous Flight Controller and Route Optimization System
module swarm_logistics::flight_controller {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::clock::{Self, Clock};
    use std::string::String;
    use std::vector;
    use std::option::{Self, Option};
    use swarm_logistics::drone::{Self as drone_mod, Drone};
    use swarm_logistics::swarm::{Self as swarm_mod, EnvironmentData};

    // ==================== EVENTS ====================
    
    /// Event emitted when a route is calculated
    public struct RouteCalculatedEvent has copy, drop {
        drone_id: ID,
        route_id: ID,
        origin: String,
        destination: String,
        estimated_time: u64,
        estimated_energy: u64,
        optimization_score: u64,
    }

    /// Event emitted when route is dynamically adjusted
    public struct RouteAdjustedEvent has copy, drop {
        drone_id: ID,
        route_id: ID,
        adjustment_reason: u8,
        new_waypoint: String,
        time_impact: u64,
    }

    /// Event emitted when obstacle is detected and avoided
    public struct ObstacleAvoidedEvent has copy, drop {
        drone_id: ID,
        obstacle_type: u8,
        location: String,
        avoidance_action: u8,
        safety_margin: u64,
    }

    /// Event emitted when emergency landing is initiated
    public struct EmergencyLandingEvent has copy, drop {
        drone_id: ID,
        reason: u8,
        landing_location: String,
        battery_remaining: u8,
    }

    // ==================== CORE STRUCTURES ====================

    /// Optimized flight route with waypoints and parameters
    public struct FlightRoute has key, store {
        id: UID,
        drone_id: ID,
        origin: String,              // GPS coordinates "lat,lng"
        destination: String,         // GPS coordinates "lat,lng"
        waypoints: vector<Waypoint>,
        total_distance: u64,         // meters
        estimated_flight_time: u64,  // milliseconds
        estimated_energy_cost: u64,  // battery percentage
        weather_factor: u64,         // 0-100 impact score
        traffic_factor: u64,         // 0-100 congestion score
        optimization_score: u64,     // 0-100 overall route quality
        created_at: u64,
        status: u8,                  // 0=Planned, 1=Active, 2=Completed, 3=Aborted
        current_waypoint_index: u64,
        alternative_routes: vector<ID>, // Backup route IDs
    }

    /// Individual waypoint in a flight route
    public struct Waypoint has store {
        coordinates: String,         // GPS "lat,lng"
        altitude: u64,              // meters above ground
        speed: u64,                 // km/h
        action: u8,                 // 0=Transit, 1=Pickup, 2=Dropoff, 3=Charge, 4=Avoid
        estimated_arrival: u64,     // timestamp
        safety_radius: u64,         // meters for obstacle avoidance
    }

    /// Real-time navigation state for autonomous flight
    public struct NavigationState has key, store {
        id: UID,
        drone_id: ID,
        current_route: Option<ID>,
        current_position: String,    // GPS coordinates
        current_altitude: u64,       // meters
        current_speed: u64,          // km/h
        heading: u64,               // degrees (0-359)
        target_waypoint: Option<Waypoint>,
        obstacles_detected: vector<Obstacle>,
        weather_conditions: EnvironmentData,
        flight_mode: u8,            // 0=Auto, 1=Manual, 2=Emergency, 3=Landing
        last_update: u64,
        autonomous_decisions: vector<AutonomousDecision>,
    }

    /// Detected obstacle requiring avoidance
    public struct Obstacle has store {
        obstacle_type: u8,          // 0=Aircraft, 1=Building, 2=Weather, 3=NoFlyZone, 4=Bird
        location: String,           // GPS coordinates
        size_estimate: u64,         // meters diameter
        movement_vector: String,    // "speed,direction" if moving
        threat_level: u8,           // 0=Low, 1=Medium, 2=High, 3=Critical
        detection_time: u64,
        avoidance_action: u8,       // 0=Altitude, 1=Lateral, 2=Speed, 3=Land
    }

    /// Record of autonomous decisions made by the flight controller
    public struct AutonomousDecision has store {
        decision_type: u8,          // 0=RouteChange, 1=SpeedAdjust, 2=AltitudeChange, 3=EmergencyLand
        trigger_reason: String,
        parameters: String,         // JSON-encoded decision parameters
        confidence_score: u64,      // 0-100 AI confidence in decision
        timestamp: u64,
        outcome: Option<u8>,        // 0=Success, 1=Failed, 2=Partial (set after execution)
    }

    /// Route optimization parameters and constraints
    public struct OptimizationParams has store {
        priority_weight: u64,       // 0-100 (speed vs efficiency)
        energy_efficiency: u64,     // 0-100 importance of battery conservation
        safety_margin: u64,         // 0-100 extra safety buffer
        weather_sensitivity: u64,   // 0-100 how much weather affects routing
        traffic_avoidance: u64,     // 0-100 importance of avoiding congestion
        altitude_preference: u8,    // 0=Low, 1=Medium, 2=High preferred altitude
    }

    // ==================== ERROR CODES ====================
    const E_INVALID_COORDINATES: u64 = 1;
    const E_ROUTE_NOT_FOUND: u64 = 2;
    const E_DRONE_NOT_AVAILABLE: u64 = 3;
    const E_INSUFFICIENT_BATTERY: u64 = 4;
    const E_WEATHER_UNSAFE: u64 = 5;
    const E_AIRSPACE_RESTRICTED: u64 = 6;
    const E_OBSTACLE_CRITICAL: u64 = 7;
    const E_NAVIGATION_FAILURE: u64 = 8;

    // ==================== CONSTANTS ====================

    // Route status
    const ROUTE_PLANNED: u8 = 0;
    const ROUTE_ACTIVE: u8 = 1;
    const ROUTE_COMPLETED: u8 = 2;
    const ROUTE_ABORTED: u8 = 3;

    // Waypoint actions
    const ACTION_TRANSIT: u8 = 0;
    const ACTION_PICKUP: u8 = 1;
    const ACTION_DROPOFF: u8 = 2;
    const ACTION_CHARGE: u8 = 3;
    const ACTION_AVOID: u8 = 4;

    // Flight modes
    const FLIGHT_AUTO: u8 = 0;
    const FLIGHT_MANUAL: u8 = 1;
    const FLIGHT_EMERGENCY: u8 = 2;
    const FLIGHT_LANDING: u8 = 3;

    // Obstacle types
    const OBSTACLE_AIRCRAFT: u8 = 0;
    const OBSTACLE_BUILDING: u8 = 1;
    const OBSTACLE_WEATHER: u8 = 2;
    const OBSTACLE_NO_FLY_ZONE: u8 = 3;
    const OBSTACLE_BIRD: u8 = 4;

    // Decision types
    const DECISION_ROUTE_CHANGE: u8 = 0;
    const DECISION_SPEED_ADJUST: u8 = 1;
    const DECISION_ALTITUDE_CHANGE: u8 = 2;
    const DECISION_EMERGENCY_LAND: u8 = 3;

    // Avoidance actions
    const AVOID_ALTITUDE: u8 = 0;
    const AVOID_LATERAL: u8 = 1;
    const AVOID_SPEED: u8 = 2;
    const AVOID_LAND: u8 = 3;

    // ==================== ROUTE OPTIMIZATION FUNCTIONS ====================

    /// Calculate optimal route between two points
    public fun calculate_optimal_route(
        drone: &Drone,
        origin: String,
        destination: String,
        optimization_params: OptimizationParams,
        weather_data: EnvironmentData,
        clock: &Clock,
        ctx: &mut TxContext
    ): FlightRoute {
        let current_time = clock::timestamp_ms(clock);
        let drone_id = drone_mod::drone_id(drone);

        // Validate coordinates (simplified validation)
        assert!(vector::length(&origin.bytes()) > 0, E_INVALID_COORDINATES);
        assert!(vector::length(&destination.bytes()) > 0, E_INVALID_COORDINATES);

        // Check drone availability and battery
        assert!(drone_mod::is_drone_available(drone), E_DRONE_NOT_AVAILABLE);
        assert!(drone_mod::drone_battery_level(drone) > 30, E_INSUFFICIENT_BATTERY);

        // Calculate route parameters using optimization algorithm
        let (waypoints, distance, flight_time, energy_cost) = calculate_route_parameters(
            origin,
            destination,
            &optimization_params,
            &weather_data
        );

        // Calculate optimization score based on multiple factors
        let optimization_score = calculate_optimization_score(
            flight_time,
            energy_cost,
            &optimization_params,
            &weather_data
        );

        let route = FlightRoute {
            id: object::new(ctx),
            drone_id,
            origin,
            destination,
            waypoints,
            total_distance: distance,
            estimated_flight_time: flight_time,
            estimated_energy_cost: energy_cost,
            weather_factor: calculate_weather_impact(&weather_data),
            traffic_factor: 50, // Placeholder for traffic calculation
            optimization_score,
            created_at: current_time,
            status: ROUTE_PLANNED,
            current_waypoint_index: 0,
            alternative_routes: vector::empty(),
        };

        // Emit route calculation event
        event::emit(RouteCalculatedEvent {
            drone_id,
            route_id: object::uid_to_inner(&route.id),
            origin,
            destination,
            estimated_time: flight_time,
            estimated_energy: energy_cost,
            optimization_score,
        });

        route
    }

    /// Create navigation state for autonomous flight
    public fun initialize_navigation(
        drone: &Drone,
        route: &FlightRoute,
        initial_position: String,
        weather_conditions: EnvironmentData,
        clock: &Clock,
        ctx: &mut TxContext
    ): NavigationState {
        let current_time = clock::timestamp_ms(clock);
        let drone_id = drone_mod::drone_id(drone);

        // Get first waypoint as target
        let target_waypoint = if (vector::length(&route.waypoints) > 0) {
            option::some(*vector::borrow(&route.waypoints, 0))
        } else {
            option::none()
        };

        NavigationState {
            id: object::new(ctx),
            drone_id,
            current_route: option::some(object::uid_to_inner(&route.id)),
            current_position: initial_position,
            current_altitude: 100, // Default altitude
            current_speed: 0,
            heading: 0,
            target_waypoint,
            obstacles_detected: vector::empty(),
            weather_conditions,
            flight_mode: FLIGHT_AUTO,
            last_update: current_time,
            autonomous_decisions: vector::empty(),
        }
    }

    /// Update navigation state with real-time data
    public fun update_navigation_state(
        nav_state: &mut NavigationState,
        new_position: String,
        new_altitude: u64,
        new_speed: u64,
        new_heading: u64,
        detected_obstacles: vector<Obstacle>,
        weather_update: EnvironmentData,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);

        nav_state.current_position = new_position;
        nav_state.current_altitude = new_altitude;
        nav_state.current_speed = new_speed;
        nav_state.heading = new_heading;
        nav_state.obstacles_detected = detected_obstacles;
        nav_state.weather_conditions = weather_update;
        nav_state.last_update = current_time;

        // Process obstacles and make autonomous decisions
        process_obstacles_and_decide(nav_state, current_time);
    }

    /// Make autonomous navigation decision based on current state
    public fun make_autonomous_decision(
        nav_state: &mut NavigationState,
        route: &mut FlightRoute,
        clock: &Clock
    ): AutonomousDecision {
        let current_time = clock::timestamp_ms(clock);
        
        // Analyze current situation
        let decision = if (has_critical_obstacles(nav_state)) {
            // Emergency landing decision
            AutonomousDecision {
                decision_type: DECISION_EMERGENCY_LAND,
                trigger_reason: b"Critical obstacle detected".to_string(),
                parameters: b"{\"action\":\"emergency_land\",\"reason\":\"obstacle\"}".to_string(),
                confidence_score: 95,
                timestamp: current_time,
                outcome: option::none(),
            }
        } else if (should_adjust_altitude(nav_state)) {
            // Altitude adjustment decision
            AutonomousDecision {
                decision_type: DECISION_ALTITUDE_CHANGE,
                trigger_reason: b"Weather conditions require altitude change".to_string(),
                parameters: b"{\"new_altitude\":150,\"reason\":\"weather\"}".to_string(),
                confidence_score: 80,
                timestamp: current_time,
                outcome: option::none(),
            }
        } else if (should_adjust_speed(nav_state)) {
            // Speed adjustment decision
            AutonomousDecision {
                decision_type: DECISION_SPEED_ADJUST,
                trigger_reason: b"Optimizing speed for conditions".to_string(),
                parameters: b"{\"new_speed\":45,\"reason\":\"optimization\"}".to_string(),
                confidence_score: 70,
                timestamp: current_time,
                outcome: option::none(),
            }
        } else {
            // Route optimization decision
            AutonomousDecision {
                decision_type: DECISION_ROUTE_CHANGE,
                trigger_reason: b"Minor route optimization".to_string(),
                parameters: b"{\"waypoint_adjustment\":\"minor\"}".to_string(),
                confidence_score: 60,
                timestamp: current_time,
                outcome: option::none(),
            }
        };

        // Record the decision
        vector::push_back(&mut nav_state.autonomous_decisions, decision);

        // Keep only last 20 decisions
        if (vector::length(&nav_state.autonomous_decisions) > 20) {
            vector::remove(&mut nav_state.autonomous_decisions, 0);
        };

        decision
    }

    /// Execute obstacle avoidance maneuver
    public fun execute_obstacle_avoidance(
        nav_state: &mut NavigationState,
        route: &mut FlightRoute,
        obstacle: &Obstacle,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        let drone_id = nav_state.drone_id;

        // Determine avoidance action based on obstacle type and threat level
        let avoidance_action = if (obstacle.threat_level >= 3) {
            AVOID_LAND // Critical threat - emergency landing
        } else if (obstacle.obstacle_type == OBSTACLE_AIRCRAFT) {
            AVOID_ALTITUDE // Aircraft - change altitude
        } else if (obstacle.obstacle_type == OBSTACLE_WEATHER) {
            AVOID_LATERAL // Weather - lateral avoidance
        } else {
            AVOID_SPEED // Default - speed adjustment
        };

        // Execute the avoidance maneuver
        match (avoidance_action) {
            AVOID_ALTITUDE => {
                nav_state.current_altitude = nav_state.current_altitude + 50; // Climb 50m
            },
            AVOID_LATERAL => {
                // Adjust heading by 15 degrees
                nav_state.heading = (nav_state.heading + 15) % 360;
            },
            AVOID_SPEED => {
                // Reduce speed by 20%
                nav_state.current_speed = nav_state.current_speed * 80 / 100;
            },
            AVOID_LAND => {
                nav_state.flight_mode = FLIGHT_EMERGENCY;
                // Emit emergency landing event
                event::emit(EmergencyLandingEvent {
                    drone_id,
                    reason: obstacle.obstacle_type,
                    landing_location: nav_state.current_position,
                    battery_remaining: 50, // Placeholder
                });
            },
            _ => {} // No action
        };

        // Emit obstacle avoidance event
        event::emit(ObstacleAvoidedEvent {
            drone_id,
            obstacle_type: obstacle.obstacle_type,
            location: obstacle.location,
            avoidance_action,
            safety_margin: obstacle.size_estimate + 20,
        });

        // Record autonomous decision
        let decision = AutonomousDecision {
            decision_type: DECISION_ROUTE_CHANGE,
            trigger_reason: b"Obstacle avoidance maneuver".to_string(),
            parameters: b"{\"avoidance_type\":\"obstacle\"}".to_string(),
            confidence_score: 90,
            timestamp: current_time,
            outcome: option::some(0), // Success
        };

        vector::push_back(&mut nav_state.autonomous_decisions, decision);
    }

    // ==================== HELPER FUNCTIONS ====================

    /// Calculate route parameters using optimization algorithm
    fun calculate_route_parameters(
        origin: String,
        destination: String,
        params: &OptimizationParams,
        weather: &EnvironmentData
    ): (vector<Waypoint>, u64, u64, u64) {
        // Simplified route calculation - in reality this would use complex algorithms
        let waypoints = vector::empty<Waypoint>();
        
        // Add origin waypoint
        vector::push_back(&mut waypoints, Waypoint {
            coordinates: origin,
            altitude: 100,
            speed: 50,
            action: ACTION_TRANSIT,
            estimated_arrival: 0,
            safety_radius: 50,
        });

        // Add destination waypoint
        vector::push_back(&mut waypoints, Waypoint {
            coordinates: destination,
            altitude: 100,
            speed: 30,
            action: ACTION_DROPOFF,
            estimated_arrival: 1800000, // 30 minutes
            safety_radius: 30,
        });

        let distance = 5000; // 5km placeholder
        let flight_time = 1800000; // 30 minutes
        let energy_cost = 25; // 25% battery

        (waypoints, distance, flight_time, energy_cost)
    }

    /// Calculate optimization score based on multiple factors
    fun calculate_optimization_score(
        flight_time: u64,
        energy_cost: u64,
        params: &OptimizationParams,
        weather: &EnvironmentData
    ): u64 {
        // Simplified scoring algorithm
        let time_score = if (flight_time < 1800000) 90 else 70; // Under 30 min = good
        let energy_score = if (energy_cost < 30) 90 else 60; // Under 30% = good
        let weather_score = if (weather.weather_condition == 0) 100 else 70; // Clear = best
        
        (time_score + energy_score + weather_score) / 3
    }

    /// Calculate weather impact on flight
    fun calculate_weather_impact(weather: &EnvironmentData): u64 {
        match (weather.weather_condition) {
            0 => 10,  // Clear - minimal impact
            1 => 30,  // Rain - moderate impact
            2 => 50,  // Snow - high impact
            3 => 40,  // Wind - moderate-high impact
            4 => 80,  // Storm - severe impact
            _ => 20   // Unknown - low impact
        }
    }

    /// Process detected obstacles and make decisions
    fun process_obstacles_and_decide(nav_state: &mut NavigationState, current_time: u64) {
        let i = 0;
        let len = vector::length(&nav_state.obstacles_detected);
        
        while (i < len) {
            let obstacle = vector::borrow(&nav_state.obstacles_detected, i);
            
            if (obstacle.threat_level >= 2) { // High or critical threat
                // Record decision to avoid
                let decision = AutonomousDecision {
                    decision_type: DECISION_ROUTE_CHANGE,
                    trigger_reason: b"High threat obstacle detected".to_string(),
                    parameters: b"{\"threat_level\":\"high\"}".to_string(),
                    confidence_score: 85,
                    timestamp: current_time,
                    outcome: option::none(),
                };
                
                vector::push_back(&mut nav_state.autonomous_decisions, decision);
            };
            
            i = i + 1;
        };
    }

    /// Check if there are critical obstacles requiring immediate action
    fun has_critical_obstacles(nav_state: &NavigationState): bool {
        let i = 0;
        let len = vector::length(&nav_state.obstacles_detected);
        
        while (i < len) {
            let obstacle = vector::borrow(&nav_state.obstacles_detected, i);
            if (obstacle.threat_level >= 3) {
                return true
            };
            i = i + 1;
        };
        
        false
    }

    /// Determine if altitude adjustment is needed
    fun should_adjust_altitude(nav_state: &NavigationState): bool {
        nav_state.weather_conditions.weather_condition >= 2 || // Snow or worse
        nav_state.current_altitude < 50 // Too low
    }

    /// Determine if speed adjustment is needed
    fun should_adjust_speed(nav_state: &NavigationState): bool {
        nav_state.weather_conditions.wind_speed > 30 || // High wind
        nav_state.current_speed > 60 // Too fast
    }

    // ==================== GETTER FUNCTIONS ====================

    public fun route_id(route: &FlightRoute): ID {
        object::uid_to_inner(&route.id)
    }

    public fun route_status(route: &FlightRoute): u8 {
        route.status
    }

    public fun route_estimated_time(route: &FlightRoute): u64 {
        route.estimated_flight_time
    }

    public fun route_estimated_energy(route: &FlightRoute): u64 {
        route.estimated_energy_cost
    }

    public fun route_optimization_score(route: &FlightRoute): u64 {
        route.optimization_score
    }

    public fun navigation_current_position(nav_state: &NavigationState): String {
        nav_state.current_position
    }

    public fun navigation_flight_mode(nav_state: &NavigationState): u8 {
        nav_state.flight_mode
    }

    public fun navigation_obstacles_count(nav_state: &NavigationState): u64 {
        vector::length(&nav_state.obstacles_detected)
    }

    public fun navigation_decisions_count(nav_state: &NavigationState): u64 {
        vector::length(&nav_state.autonomous_decisions)
    }

    // ==================== SETTER FUNCTIONS ====================

    public fun set_route_status(route: &mut FlightRoute, status: u8) {
        route.status = status;
    }

    public fun advance_waypoint(route: &mut FlightRoute) {
        if (route.current_waypoint_index < vector::length(&route.waypoints) - 1) {
            route.current_waypoint_index = route.current_waypoint_index + 1;
        };
    }

    public fun set_flight_mode(nav_state: &mut NavigationState, mode: u8) {
        nav_state.flight_mode = mode;
    }

    /// Create default optimization parameters
    public fun default_optimization_params(): OptimizationParams {
        OptimizationParams {
            priority_weight: 70,
            energy_efficiency: 80,
            safety_margin: 90,
            weather_sensitivity: 85,
            traffic_avoidance: 75,
            altitude_preference: 1, // Medium altitude
        }
    }

    /// Create emergency optimization parameters (prioritize safety)
    public fun emergency_optimization_params(): OptimizationParams {
        OptimizationParams {
            priority_weight: 100,
            energy_efficiency: 50,
            safety_margin: 100,
            weather_sensitivity: 100,
            traffic_avoidance: 100,
            altitude_preference: 0, // Low altitude for emergency
        }
    }
} 