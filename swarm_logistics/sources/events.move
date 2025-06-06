/// Event structures and error codes for the swarm logistics system
module swarm_logistics::events {
    use sui::object::ID;
    use std::string::String;
    use std::option::Option;
    use std::vector;

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

    // ==================== DAO GOVERNANCE EVENTS ====================

    /// Event emitted when a DAO is created
    public struct DAOCreated has copy, drop {
        dao_id: ID,
        dao_name: String,
        founder: address,
        timestamp: u64,
    }

    /// Event emitted when a member joins a DAO
    public struct MemberJoined has copy, drop {
        dao_id: ID,
        member: address,
        tokens: u64,
        timestamp: u64,
    }

    /// Event emitted when a proposal is created
    public struct ProposalCreated has copy, drop {
        proposal_id: ID,
        dao_id: ID,
        proposer: address,
        proposal_type: u8,
        timestamp: u64,
    }

    /// Event emitted when a vote is cast
    public struct VoteCast has copy, drop {
        proposal_id: ID,
        voter: address,
        vote_choice: u8,
        voting_power: u64,
        timestamp: u64,
    }

    /// Event emitted when a proposal is finalized
    public struct ProposalFinalized has copy, drop {
        proposal_id: ID,
        status: u8,
        timestamp: u64,
    }

    /// Event emitted when a proposal is executed
    public struct ProposalExecuted has copy, drop {
        proposal_id: ID,
        timestamp: u64,
    }

    /// Event emitted when votes are delegated
    public struct VoteDelegated has copy, drop {
        delegator: address,
        delegate: address,
        power: u64,
        timestamp: u64,
    }

    /// Event emitted when delegation is revoked
    public struct DelegationRevoked has copy, drop {
        delegator: address,
        delegate: address,
        power: u64,
        timestamp: u64,
    }

    /// Event emitted when revenue is distributed
    public struct RevenueDistributed has copy, drop {
        dao_id: ID,
        total_revenue: u64,
        member_share: u64,
        timestamp: u64,
    }

    /// Event emitted when treasury withdrawal occurs
    public struct TreasuryWithdrawal has copy, drop {
        dao_id: ID,
        amount: u64,
        recipient: address,
        authorized_by: ID,
    }

    // ==================== ERROR CODES ====================
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

    // ==================== ERROR CODE GETTER FUNCTIONS ====================

    public fun e_invalid_operation_mode(): u64 { E_INVALID_OPERATION_MODE }
    public fun e_insufficient_battery(): u64 { E_INSUFFICIENT_BATTERY }
    public fun e_payload_too_heavy(): u64 { E_PAYLOAD_TOO_HEAVY }
    public fun e_out_of_range(): u64 { E_OUT_OF_RANGE }
    public fun e_drone_not_available(): u64 { E_DRONE_NOT_AVAILABLE }
    public fun e_invalid_autonomy_level(): u64 { E_INVALID_AUTONOMY_LEVEL }
    public fun e_maintenance_overdue(): u64 { E_MAINTENANCE_OVERDUE }
    public fun e_insufficient_funds(): u64 { E_INSUFFICIENT_FUNDS }
    public fun e_invalid_coordinates(): u64 { E_INVALID_COORDINATES }
    public fun e_airspace_conflict(): u64 { E_AIRSPACE_CONFLICT }
    public fun e_emergency_active(): u64 { E_EMERGENCY_ACTIVE }
    public fun e_unauthorized_access(): u64 { E_UNAUTHORIZED_ACCESS }
    public fun e_invalid_proposal(): u64 { E_INVALID_PROPOSAL }
    public fun e_voting_period_ended(): u64 { E_VOTING_PERIOD_ENDED }
    public fun e_swarm_coordination_failed(): u64 { E_SWARM_COORDINATION_FAILED }

    // ==================== EVENT CONSTRUCTOR FUNCTIONS ====================

    /// Create new drone registered event
    public fun new_drone_registered_event(
        drone_id: ID,
        owner: address,
        operation_mode: u8,
        autonomy_level: u8,
        timestamp: u64,
    ): DroneRegistered {
        DroneRegistered {
            drone_id,
            owner,
            operation_mode,
            autonomy_level,
            timestamp,
        }
    }

    /// Create new order created event
    public fun new_order_created_event(
        order_id: ID,
        customer: address,
        pickup_location: String,
        dropoff_location: String,
        payment_amount: u64,
        timestamp: u64,
    ): OrderCreated {
        OrderCreated {
            order_id,
            customer,
            pickup_location,
            dropoff_location,
            payment_amount,
            timestamp,
        }
    }

    /// Create new order accepted event
    public fun new_order_accepted_event(
        order_id: ID,
        drone_id: ID,
        estimated_completion: u64,
        timestamp: u64,
    ): OrderAccepted {
        OrderAccepted {
            order_id,
            drone_id,
            estimated_completion,
            timestamp,
        }
    }

    /// Create new delivery completed event
    public fun new_delivery_completed_event(
        order_id: ID,
        drone_id: ID,
        actual_delivery_time: u64,
        customer_rating: Option<u8>,
        timestamp: u64,
    ): DeliveryCompleted {
        DeliveryCompleted {
            order_id,
            drone_id,
            actual_delivery_time,
            customer_rating,
            timestamp,
        }
    }

    /// Create new swarm coordination event
    public fun new_swarm_coordination_event(
        event_type: u8,
        participating_drones: vector<ID>,
        location: String,
        timestamp: u64,
    ): SwarmCoordination {
        SwarmCoordination {
            event_type,
            participating_drones,
            location,
            timestamp,
        }
    }

    /// Create new emergency declared event
    public fun new_emergency_declared_event(
        drone_id: ID,
        emergency_type: u8,
        location: String,
        severity: u8,
        timestamp: u64,
    ): EmergencyDeclared {
        EmergencyDeclared {
            drone_id,
            emergency_type,
            location,
            severity,
            timestamp,
        }
    }

    // ==================== DAO EVENT EMISSION FUNCTIONS ====================

    /// Emit DAO created event
    public fun emit_dao_created(
        dao_id: ID,
        dao_name: String,
        founder: address,
        timestamp: u64,
    ) {
        sui::event::emit(DAOCreated {
            dao_id,
            dao_name,
            founder,
            timestamp,
        });
    }

    /// Emit member joined event
    public fun emit_member_joined(
        dao_id: ID,
        member: address,
        tokens: u64,
        timestamp: u64,
    ) {
        sui::event::emit(MemberJoined {
            dao_id,
            member,
            tokens,
            timestamp,
        });
    }

    /// Emit proposal created event
    public fun emit_proposal_created(
        proposal_id: ID,
        dao_id: ID,
        proposer: address,
        proposal_type: u8,
        timestamp: u64,
    ) {
        sui::event::emit(ProposalCreated {
            proposal_id,
            dao_id,
            proposer,
            proposal_type,
            timestamp,
        });
    }

    /// Emit vote cast event
    public fun emit_vote_cast(
        proposal_id: ID,
        voter: address,
        vote_choice: u8,
        voting_power: u64,
        timestamp: u64,
    ) {
        sui::event::emit(VoteCast {
            proposal_id,
            voter,
            vote_choice,
            voting_power,
            timestamp,
        });
    }

    /// Emit proposal finalized event
    public fun emit_proposal_finalized(
        proposal_id: ID,
        status: u8,
        timestamp: u64,
    ) {
        sui::event::emit(ProposalFinalized {
            proposal_id,
            status,
            timestamp,
        });
    }

    /// Emit proposal executed event
    public fun emit_proposal_executed(
        proposal_id: ID,
        timestamp: u64,
    ) {
        sui::event::emit(ProposalExecuted {
            proposal_id,
            timestamp,
        });
    }

    /// Emit vote delegated event
    public fun emit_vote_delegated(
        delegator: address,
        delegate: address,
        power: u64,
        timestamp: u64,
    ) {
        sui::event::emit(VoteDelegated {
            delegator,
            delegate,
            power,
            timestamp,
        });
    }

    /// Emit delegation revoked event
    public fun emit_delegation_revoked(
        delegator: address,
        delegate: address,
        power: u64,
        timestamp: u64,
    ) {
        sui::event::emit(DelegationRevoked {
            delegator,
            delegate,
            power,
            timestamp,
        });
    }

    /// Emit revenue distributed event
    public fun emit_revenue_distributed(
        dao_id: ID,
        total_revenue: u64,
        member_share: u64,
        timestamp: u64,
    ) {
        sui::event::emit(RevenueDistributed {
            dao_id,
            total_revenue,
            member_share,
            timestamp,
        });
    }

    /// Emit treasury withdrawal event
    public fun emit_treasury_withdrawal(
        dao_id: ID,
        amount: u64,
        recipient: address,
        authorized_by: ID,
    ) {
        sui::event::emit(TreasuryWithdrawal {
            dao_id,
            amount,
            recipient,
            authorized_by,
        });
    }
} 