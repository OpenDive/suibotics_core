/// Order management system for autonomous drone deliveries
module swarm_logistics::order_management {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use std::string::String;
    use std::vector;
    use std::option::{Self, Option};
    use swarm_logistics::drone::{Self as drone_mod, Drone};

    // ==================== EVENTS ====================
    
    /// Event emitted when a new order is created
    public struct OrderCreatedEvent has copy, drop {
        order_id: ID,
        order_number: u64,
        customer: address,
        pickup_location: String,
        dropoff_location: String,
        payment_amount: u64,
        priority_level: u8,
        created_at: u64,
    }

    /// Event emitted when an order is assigned to a drone
    public struct OrderAssignedEvent has copy, drop {
        order_id: ID,
        drone_id: ID,
        assigned_at: u64,
        estimated_completion: u64,
    }

    /// Event emitted when order status is updated
    public struct OrderStatusUpdatedEvent has copy, drop {
        order_id: ID,
        new_status: u8,
        updated_at: u64,
    }

    /// Event emitted when an order is completed
    public struct OrderCompletedEvent has copy, drop {
        order_id: ID,
        order_number: u64,
        drone_payout: u64,
        platform_fee: u64,
    }

    /// Event emitted when an order is cancelled
    public struct OrderCancelledEvent has copy, drop {
        order_id: ID,
        order_number: u64,
        refund_amount: u64,
    }

    /// Order management system
    public struct OrderManager has key, store {
        id: UID,
        total_orders: u64,
        active_orders: u64,
        completed_orders: u64,
        total_revenue: u64,
        average_delivery_time: u64,
    }

    /// Individual delivery order
    public struct DeliveryOrder has key, store {
        id: UID,
        order_id: u64,
        customer: address,
        pickup_location: String,
        dropoff_location: String,
        package_weight: u64,
        package_dimensions: vector<u64>, // [length, width, height] in mm
        priority_level: u8,
        special_instructions: String,
        payment_amount: u64,
        escrow_balance: Balance<SUI>,
        assigned_drone: Option<ID>,
        status: u8,
        created_at: u64,
        pickup_deadline: u64,
        delivery_deadline: u64,
        estimated_delivery_time: u64,
        actual_pickup_time: Option<u64>,
        actual_delivery_time: Option<u64>,
        route_hash: Option<String>,
        tracking_updates: vector<String>,
    }

    /// Order assignment capability for drones
    public struct OrderAssignment has key, store {
        id: UID,
        order_id: ID,
        drone_id: ID,
        assigned_at: u64,
        estimated_completion: u64,
        fuel_cost_estimate: u64,
        distance_estimate: u64,
    }

    // ==================== ERROR CODES ====================
    const E_ORDER_NOT_FOUND: u64 = 1;
    const E_INVALID_STATUS: u64 = 2;
    const E_UNAUTHORIZED: u64 = 3;
    const E_INSUFFICIENT_PAYMENT: u64 = 4;
    const E_ORDER_ALREADY_ASSIGNED: u64 = 5;
    const E_INVALID_PRIORITY: u64 = 6;
    const E_PACKAGE_TOO_HEAVY: u64 = 7;
    const E_DEADLINE_PASSED: u64 = 8;

    // ==================== ORDER STATUS CONSTANTS ====================
    const ORDER_CREATED: u8 = 0;
    const ORDER_PAYMENT_CONFIRMED: u8 = 1;
    const ORDER_ASSIGNED: u8 = 2;
    const ORDER_PICKED_UP: u8 = 3;
    const ORDER_IN_TRANSIT: u8 = 4;
    const ORDER_DELIVERED: u8 = 5;
    const ORDER_COMPLETED: u8 = 6;
    const ORDER_CANCELLED: u8 = 7;
    const ORDER_REFUNDED: u8 = 8;

    // ==================== PRIORITY LEVELS ====================
    const PRIORITY_STANDARD: u8 = 0;
    const PRIORITY_EXPRESS: u8 = 1;
    const PRIORITY_EMERGENCY: u8 = 2;

    // ==================== PACKAGE LIMITS ====================
    const MAX_PACKAGE_WEIGHT: u64 = 5000; // 5kg in grams
    const MIN_PAYMENT_AMOUNT: u64 = 100; // Minimum payment in SUI

    /// Initialize the order management system
    public fun create_order_manager(ctx: &mut TxContext): OrderManager {
        OrderManager {
            id: object::new(ctx),
            total_orders: 0,
            active_orders: 0,
            completed_orders: 0,
            total_revenue: 0,
            average_delivery_time: 0,
        }
    }

    /// Create a new delivery order
    public fun create_order(
        manager: &mut OrderManager,
        pickup_location: String,
        dropoff_location: String,
        package_weight: u64,
        package_dimensions: vector<u64>,
        priority_level: u8,
        special_instructions: String,
        payment: Coin<SUI>,
        pickup_deadline: u64,
        delivery_deadline: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): DeliveryOrder {
        // Validate inputs
        assert!(package_weight <= MAX_PACKAGE_WEIGHT, E_PACKAGE_TOO_HEAVY);
        assert!(priority_level <= PRIORITY_EMERGENCY, E_INVALID_PRIORITY);
        assert!(coin::value(&payment) >= MIN_PAYMENT_AMOUNT, E_INSUFFICIENT_PAYMENT);
        
        let current_time = clock::timestamp_ms(clock);
        assert!(pickup_deadline > current_time, E_DEADLINE_PASSED);
        assert!(delivery_deadline > pickup_deadline, E_DEADLINE_PASSED);

        let order_id = manager.total_orders;
        manager.total_orders = manager.total_orders + 1;
        manager.active_orders = manager.active_orders + 1;

        let payment_amount = coin::value(&payment);
        let escrow_balance = coin::into_balance(payment);

        let order = DeliveryOrder {
            id: object::new(ctx),
            order_id,
            customer: tx_context::sender(ctx),
            pickup_location,
            dropoff_location,
            package_weight,
            package_dimensions,
            priority_level,
            special_instructions,
            payment_amount,
            escrow_balance,
            assigned_drone: option::none(),
            status: ORDER_CREATED,
            created_at: current_time,
            pickup_deadline,
            delivery_deadline,
            estimated_delivery_time: 0,
            actual_pickup_time: option::none(),
            actual_delivery_time: option::none(),
            route_hash: option::none(),
            tracking_updates: vector::empty(),
        };

        // Emit order created event
        event::emit(OrderCreatedEvent {
            order_id: object::uid_to_inner(&order.id),
            order_number: order_id,
            customer: tx_context::sender(ctx),
            pickup_location,
            dropoff_location,
            payment_amount,
            priority_level,
            created_at: current_time,
        });

        order
    }

    /// Assign order to a drone (called by autonomous drone)
    public fun assign_order_to_drone(
        order: &mut DeliveryOrder,
        drone: &Drone,
        estimated_completion: u64,
        estimated_fuel_cost: u64,
        estimated_distance: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): OrderAssignment {
        assert!(order.status == ORDER_CREATED || order.status == ORDER_PAYMENT_CONFIRMED, E_INVALID_STATUS);
        assert!(option::is_none(&order.assigned_drone), E_ORDER_ALREADY_ASSIGNED);

        let current_time = clock::timestamp_ms(clock);
        assert!(order.pickup_deadline > current_time, E_DEADLINE_PASSED);

        // Verify drone can handle this order
        assert!(drone_mod::can_carry_payload(drone, order.package_weight), E_PACKAGE_TOO_HEAVY);
        assert!(drone_mod::is_drone_available(drone), E_INVALID_STATUS);

        let drone_id = object::id(drone);
        order.assigned_drone = option::some(drone_id);
        order.status = ORDER_ASSIGNED;
        order.estimated_delivery_time = estimated_completion;

        // Add tracking update
        vector::push_back(&mut order.tracking_updates, 
            b"Order assigned to drone - preparation in progress".to_string());

        let assignment = OrderAssignment {
            id: object::new(ctx),
            order_id: object::id(order),
            drone_id,
            assigned_at: current_time,
            estimated_completion,
            fuel_cost_estimate: estimated_fuel_cost,
            distance_estimate: estimated_distance,
        };

        // Emit assignment event
        event::emit(OrderAssignedEvent {
            order_id: object::uid_to_inner(&order.id),
            drone_id,
            assigned_at: current_time,
            estimated_completion,
        });

        assignment
    }

    /// Update order status (called by assigned drone)
    public fun update_order_status(
        order: &mut DeliveryOrder,
        new_status: u8,
        update_message: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(order.status < ORDER_COMPLETED, E_INVALID_STATUS);
        assert!(new_status > order.status && new_status <= ORDER_REFUNDED, E_INVALID_STATUS);

        let current_time = clock::timestamp_ms(clock);
        order.status = new_status;

        // Record timing for specific status updates
        if (new_status == ORDER_PICKED_UP) {
            order.actual_pickup_time = option::some(current_time);
        } else if (new_status == ORDER_DELIVERED) {
            order.actual_delivery_time = option::some(current_time);
        };

        // Add tracking update
        vector::push_back(&mut order.tracking_updates, update_message);

        // Emit status update event
        event::emit(OrderStatusUpdatedEvent {
            order_id: object::uid_to_inner(&order.id),
            new_status,
            updated_at: current_time,
        });
    }

    /// Complete order and release payment (called by customer or automated)
    public fun complete_order(
        manager: &mut OrderManager,
        order: &mut DeliveryOrder,
        drone_payout_address: address,
        platform_fee_address: address,
        ctx: &mut TxContext
    ) {
        assert!(order.status == ORDER_DELIVERED, E_INVALID_STATUS);
        assert!(tx_context::sender(ctx) == order.customer, E_UNAUTHORIZED);

        order.status = ORDER_COMPLETED;
        manager.active_orders = manager.active_orders - 1;
        manager.completed_orders = manager.completed_orders + 1;
        manager.total_revenue = manager.total_revenue + order.payment_amount;

        // Calculate payouts (90% to drone, 10% platform fee)
        let total_amount = balance::value(&order.escrow_balance);
        let platform_fee = total_amount * 10 / 100;
        let drone_payout = total_amount - platform_fee;

        // Split the payment
        let drone_payment = coin::take(&mut order.escrow_balance, drone_payout, ctx);
        let platform_payment = coin::take(&mut order.escrow_balance, platform_fee, ctx);

        // Transfer payments
        transfer::public_transfer(drone_payment, drone_payout_address);
        transfer::public_transfer(platform_payment, platform_fee_address);

        // Update delivery metrics
        if (option::is_some(&order.actual_delivery_time) && option::is_some(&order.actual_pickup_time)) {
            let pickup_time = *option::borrow(&order.actual_pickup_time);
            let delivery_time = *option::borrow(&order.actual_delivery_time);
            let total_delivery_time = delivery_time - pickup_time;
            
            // Update average delivery time (simple moving average)
            manager.average_delivery_time = (
                manager.average_delivery_time * (manager.completed_orders - 1) + total_delivery_time
            ) / manager.completed_orders;
        };

        // Add final tracking update
        vector::push_back(&mut order.tracking_updates, 
            b"Order completed successfully - payment released".to_string());

        // Emit completion event
        event::emit(OrderCompletedEvent {
            order_id: object::uid_to_inner(&order.id),
            order_number: order.order_id,
            drone_payout,
            platform_fee,
        });
    }

    /// Cancel order and refund customer
    public fun cancel_order(
        manager: &mut OrderManager,
        order: &mut DeliveryOrder,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == order.customer, E_UNAUTHORIZED);
        assert!(order.status < ORDER_PICKED_UP, E_INVALID_STATUS);

        order.status = ORDER_CANCELLED;
        manager.active_orders = manager.active_orders - 1;

        // Refund the full amount to customer
        let refund_amount = balance::value(&order.escrow_balance);
        let refund = coin::take(&mut order.escrow_balance, refund_amount, ctx);
        transfer::public_transfer(refund, order.customer);

        // Add tracking update
        vector::push_back(&mut order.tracking_updates, 
            b"Order cancelled by customer - full refund issued".to_string());

        // Emit cancellation event
        event::emit(OrderCancelledEvent {
            order_id: object::uid_to_inner(&order.id),
            order_number: order.order_id,
            refund_amount,
        });
    }

    // ==================== GETTER FUNCTIONS ====================

    public fun get_order_status(order: &DeliveryOrder): u8 {
        order.status
    }

    public fun get_order_id(order: &DeliveryOrder): u64 {
        order.order_id
    }

    public fun get_customer(order: &DeliveryOrder): address {
        order.customer
    }

    public fun get_payment_amount(order: &DeliveryOrder): u64 {
        order.payment_amount
    }

    public fun get_package_weight(order: &DeliveryOrder): u64 {
        order.package_weight
    }

    public fun get_priority_level(order: &DeliveryOrder): u8 {
        order.priority_level
    }

    public fun get_assigned_drone(order: &DeliveryOrder): &Option<ID> {
        &order.assigned_drone
    }

    public fun get_tracking_updates(order: &DeliveryOrder): &vector<String> {
        &order.tracking_updates
    }

    public fun is_order_assigned(order: &DeliveryOrder): bool {
        option::is_some(&order.assigned_drone)
    }

    public fun get_total_orders(manager: &OrderManager): u64 {
        manager.total_orders
    }

    public fun get_active_orders(manager: &OrderManager): u64 {
        manager.active_orders
    }

    public fun get_completed_orders(manager: &OrderManager): u64 {
        manager.completed_orders
    }

    public fun get_average_delivery_time(manager: &OrderManager): u64 {
        manager.average_delivery_time
    }

    // ==================== TEST-COMPATIBLE GETTER FUNCTIONS ====================

    public fun package_weight(order: &DeliveryOrder): u64 {
        order.package_weight
    }

    public fun order_id(order: &DeliveryOrder): u64 {
        order.order_id
    }

    public fun order_status(order: &DeliveryOrder): u8 {
        order.status
    }

    public fun customer(order: &DeliveryOrder): address {
        order.customer
    }

    public fun payment_amount(order: &DeliveryOrder): u64 {
        order.payment_amount
    }

    public fun priority_level(order: &DeliveryOrder): u8 {
        order.priority_level
    }

    public fun pickup_location(order: &DeliveryOrder): String {
        order.pickup_location
    }

    public fun dropoff_location(order: &DeliveryOrder): String {
        order.dropoff_location
    }
} 