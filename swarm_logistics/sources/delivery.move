/// Delivery order management structures and functionality
module swarm_logistics::delivery {
    use sui::object::{Self, ID, UID};
    use std::string::String;
    use std::option::Option;
    use std::vector;

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

    // ==================== CONSTANTS ====================

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

    // ==================== CONSTANT GETTER FUNCTIONS ====================

    public fun order_created(): u8 { ORDER_CREATED }
    public fun order_assigned(): u8 { ORDER_ASSIGNED }
    public fun order_picked_up(): u8 { ORDER_PICKED_UP }
    public fun order_in_transit(): u8 { ORDER_IN_TRANSIT }
    public fun order_delivered(): u8 { ORDER_DELIVERED }
    public fun order_completed(): u8 { ORDER_COMPLETED }
    public fun order_cancelled(): u8 { ORDER_CANCELLED }

    public fun priority_standard(): u8 { PRIORITY_STANDARD }
    public fun priority_express(): u8 { PRIORITY_EXPRESS }
    public fun priority_emergency(): u8 { PRIORITY_EMERGENCY }

    // ==================== GETTER FUNCTIONS ====================

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

    public fun order_pickup_location(order: &DeliveryOrder): String {
        order.pickup_location
    }

    public fun order_dropoff_location(order: &DeliveryOrder): String {
        order.dropoff_location
    }

    public fun order_package_weight(order: &DeliveryOrder): u64 {
        order.package_weight
    }

    public fun order_priority(order: &DeliveryOrder): u8 {
        order.priority_level
    }

    // ==================== SETTER FUNCTIONS ====================

    public fun set_order_status(order: &mut DeliveryOrder, status: u8) {
        order.status = status;
    }

    public fun assign_drone(order: &mut DeliveryOrder, drone_id: ID) {
        order.assigned_drone = std::option::some(drone_id);
        order.status = ORDER_ASSIGNED;
    }

    public fun set_actual_delivery_time(order: &mut DeliveryOrder, delivery_time: u64) {
        order.actual_delivery = std::option::some(delivery_time);
        order.status = ORDER_DELIVERED;
    }

    // ==================== UTILITY FUNCTIONS ====================

    public fun calculate_distance_cost(distance: u64, base_rate: u64): u64 {
        // Simple distance-based pricing
        base_rate + (distance / 1000) * (base_rate / 10)
    }

    public fun is_order_active(order: &DeliveryOrder): bool {
        order.status < ORDER_DELIVERED
    }

    public fun has_special_requirements(order: &DeliveryOrder): bool {
        order.requires_signature || order.requires_refrigeration || order.fragile
    }

    // ==================== TEST HELPER FUNCTIONS ====================

    #[test_only]
    public fun create_test_delivery_order(
        customer: address,
        pickup_location: String,
        dropoff_location: String,
        weight: u64,
        ctx: &mut sui::tx_context::TxContext
    ): DeliveryOrder {
        DeliveryOrder {
            id: object::new(ctx),
            customer,
            pickup_location,
            dropoff_location,
            package_description: std::string::utf8(b"Test package"),
            package_weight: weight,
            package_dimensions: std::string::utf8(b"20,15,10"),
            payment_amount: 1000000000, // 1 SUI
            priority_level: PRIORITY_STANDARD,
            status: ORDER_CREATED,
            assigned_drone: std::option::none(),
            created_at: 0,
            pickup_deadline: 3600000, // 1 hour
            delivery_deadline: 7200000, // 2 hours
            estimated_delivery: 1800000, // 30 minutes
            actual_delivery: std::option::none(),
            requires_signature: false,
            requires_refrigeration: false,
            fragile: false,
            backup_drones: vector::empty(),
            route_optimization_data: std::string::utf8(b"{}"),
        }
    }
} 