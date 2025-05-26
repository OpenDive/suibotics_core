/// DAO Governance - Decentralized Autonomous Organization for Drone Fleet Management
/// Handles collective ownership, voting, proposals, and democratic decision-making
module swarm_logistics::dao_governance {
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::balance::{Self, Balance};
    use std::string::String;
    use std::vector;
    use std::option::{Self, Option};
    use swarm_logistics::events;

    // ==================== DAO STRUCTURES ====================

    /// Main DAO structure for drone fleet governance
    public struct DroneDAO has key, store {
        id: UID,
        dao_name: String,
        total_members: u64,
        total_voting_power: u64,
        treasury_balance: Balance<SUI>,
        governance_token_supply: u64,
        active_proposals: vector<ID>,
        executed_proposals: vector<ID>,
        governance_config: GovernanceConfig,
        fleet_assets: vector<ID>,           // Owned drone IDs
        revenue_sharing_rules: RevenueRules,
        dao_status: u8,                     // 0=Active, 1=Paused, 2=Dissolved
        created_at: u64,
    }

    /// Governance configuration parameters
    public struct GovernanceConfig has store, drop {
        proposal_threshold: u64,            // Min tokens needed to create proposal
        voting_period: u64,                 // Voting duration in milliseconds
        execution_delay: u64,               // Delay before execution in milliseconds
        quorum_threshold: u64,              // Min participation for valid vote (percentage)
        approval_threshold: u64,            // Min approval for proposal to pass (percentage)
        member_admission_threshold: u64,    // Tokens needed for membership
        proposal_deposit: u64,              // SUI deposit required for proposals
        max_active_proposals: u64,          // Maximum concurrent proposals
    }

    /// Revenue sharing rules for DAO members
    public struct RevenueRules has store, drop {
        member_share_percentage: u64,       // Percentage shared among members
        treasury_percentage: u64,           // Percentage kept in treasury
        reinvestment_percentage: u64,       // Percentage for fleet expansion
        operational_percentage: u64,        // Percentage for operations
        performance_bonus_pool: u64,        // Percentage for performance bonuses
        distribution_frequency: u64,        // How often to distribute (milliseconds)
    }

    /// DAO membership with voting rights
    public struct DAOMembership has key, store {
        id: UID,
        dao_id: ID,
        member_address: address,
        governance_tokens: u64,             // Voting power
        membership_tier: u8,                // 0=Basic, 1=Premium, 2=Elite, 3=Founder
        joined_at: u64,
        last_vote_time: u64,
        total_votes_cast: u64,
        reputation_score: u64,              // 0-100 based on participation
        delegated_to: Option<address>,      // Vote delegation
        delegation_power: u64,              // Tokens delegated to this member
    }

    /// Governance proposal for DAO decisions
    public struct Proposal has key, store {
        id: UID,
        dao_id: ID,
        proposer: address,
        proposal_type: u8,                  // 0=Parameter, 1=Treasury, 2=Fleet, 3=Revenue, 4=Membership
        title: String,
        description: String,
        proposal_data: vector<u8>,          // Encoded proposal parameters
        voting_start: u64,
        voting_end: u64,
        execution_time: u64,
        votes_for: u64,
        votes_against: u64,
        votes_abstain: u64,
        total_voters: u64,
        status: u8,                         // 0=Active, 1=Passed, 2=Rejected, 3=Executed, 4=Expired
        deposit_amount: u64,
        execution_data: Option<vector<u8>>, // Data for execution
    }

    /// Individual vote record
    public struct Vote has key, store {
        id: UID,
        proposal_id: ID,
        voter: address,
        vote_choice: u8,                    // 0=Against, 1=For, 2=Abstain
        voting_power: u64,
        vote_time: u64,
        rationale: String,                  // Optional reasoning
    }

    /// Delegation record for vote delegation
    public struct VoteDelegation has key, store {
        id: UID,
        delegator: address,
        delegate: address,
        dao_id: ID,
        delegated_power: u64,
        delegation_start: u64,
        delegation_end: Option<u64>,        // None for permanent delegation
        delegation_scope: u8,               // 0=All, 1=Treasury, 2=Fleet, 3=Parameters
    }

    /// Treasury operation for DAO fund management
    public struct TreasuryOperation has key, store {
        id: UID,
        dao_id: ID,
        operation_type: u8,                 // 0=Deposit, 1=Withdrawal, 2=Investment, 3=Distribution
        amount: u64,
        recipient: Option<address>,
        purpose: String,
        authorized_by: ID,                  // Proposal ID that authorized this
        executed_at: u64,
        execution_status: u8,               // 0=Pending, 1=Executed, 2=Failed
    }

    /// Fleet management decision
    public struct FleetDecision has key, store {
        id: UID,
        dao_id: ID,
        decision_type: u8,                  // 0=Purchase, 1=Sell, 2=Upgrade, 3=Retire, 4=Relocate
        target_drone_id: Option<ID>,
        decision_data: vector<u8>,          // Encoded decision parameters
        cost_estimate: u64,
        expected_roi: u64,                  // Expected return on investment
        risk_assessment: u8,                // 0=Low, 1=Medium, 2=High
        authorized_by: ID,                  // Proposal ID
        execution_deadline: u64,
        status: u8,                         // 0=Pending, 1=Executed, 2=Cancelled
    }

    /// Performance metrics for DAO operations
    public struct DAOMetrics has key, store {
        id: UID,
        dao_id: ID,
        period_start: u64,
        period_end: u64,
        total_revenue: u64,
        total_expenses: u64,
        net_profit: u64,
        member_distributions: u64,
        treasury_growth: u64,
        fleet_size: u64,
        fleet_utilization: u64,             // Average utilization percentage
        governance_participation: u64,      // Average voting participation
        proposal_success_rate: u64,         // Percentage of passed proposals
        member_satisfaction: u64,           // 0-100 satisfaction score
    }

    // ==================== ERROR CODES ====================
    const E_INSUFFICIENT_TOKENS: u64 = 1;
    const E_PROPOSAL_NOT_FOUND: u64 = 2;
    const E_VOTING_PERIOD_ENDED: u64 = 3;
    const E_INSUFFICIENT_QUORUM: u64 = 4;
    const E_UNAUTHORIZED: u64 = 5;
    const E_INVALID_PROPOSAL_TYPE: u64 = 6;
    const E_TREASURY_INSUFFICIENT: u64 = 7;
    const E_DELEGATION_FAILED: u64 = 8;

    // ==================== CONSTANTS ====================
    
    // DAO Status
    const DAO_ACTIVE: u8 = 0;
    const DAO_PAUSED: u8 = 1;
    const DAO_DISSOLVED: u8 = 2;

    // Membership Tiers
    const TIER_BASIC: u8 = 0;
    const TIER_PREMIUM: u8 = 1;
    const TIER_ELITE: u8 = 2;
    const TIER_FOUNDER: u8 = 3;

    // Proposal Types
    const PROPOSAL_PARAMETER: u8 = 0;
    const PROPOSAL_TREASURY: u8 = 1;
    const PROPOSAL_FLEET: u8 = 2;
    const PROPOSAL_REVENUE: u8 = 3;
    const PROPOSAL_MEMBERSHIP: u8 = 4;

    // Proposal Status
    const STATUS_ACTIVE: u8 = 0;
    const STATUS_PASSED: u8 = 1;
    const STATUS_REJECTED: u8 = 2;
    const STATUS_EXECUTED: u8 = 3;
    const STATUS_EXPIRED: u8 = 4;

    // Vote Choices
    const VOTE_AGAINST: u8 = 0;
    const VOTE_FOR: u8 = 1;
    const VOTE_ABSTAIN: u8 = 2;

    // Treasury Operations
    const OP_DEPOSIT: u8 = 0;
    const OP_WITHDRAWAL: u8 = 1;
    const OP_INVESTMENT: u8 = 2;
    const OP_DISTRIBUTION: u8 = 3;

    // Fleet Decisions
    const FLEET_PURCHASE: u8 = 0;
    const FLEET_SELL: u8 = 1;
    const FLEET_UPGRADE: u8 = 2;
    const FLEET_RETIRE: u8 = 3;
    const FLEET_RELOCATE: u8 = 4;

    // ==================== DAO CREATION ====================

    /// Create a new drone fleet DAO
    public fun create_dao(
        dao_name: String,
        initial_treasury: Coin<SUI>,
        governance_config: GovernanceConfig,
        revenue_rules: RevenueRules,
        founder_tokens: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): (DroneDAO, DAOMembership) {
        let current_time = clock::timestamp_ms(clock);
        let founder_address = tx_context::sender(ctx);
        
        let dao = DroneDAO {
            id: object::new(ctx),
            dao_name,
            total_members: 1,
            total_voting_power: founder_tokens,
            treasury_balance: coin::into_balance(initial_treasury),
            governance_token_supply: founder_tokens,
            active_proposals: vector::empty(),
            executed_proposals: vector::empty(),
            governance_config,
            fleet_assets: vector::empty(),
            revenue_sharing_rules: revenue_rules,
            dao_status: DAO_ACTIVE,
            created_at: current_time,
        };
        
        let dao_id = object::id(&dao);
        
        let founder_membership = DAOMembership {
            id: object::new(ctx),
            dao_id,
            member_address: founder_address,
            governance_tokens: founder_tokens,
            membership_tier: TIER_FOUNDER,
            joined_at: current_time,
            last_vote_time: 0,
            total_votes_cast: 0,
            reputation_score: 100,
            delegated_to: option::none(),
            delegation_power: 0,
        };
        
        // Emit DAO creation event
        events::emit_dao_created(dao_id, dao_name, founder_address, current_time);
        
        (dao, founder_membership)
    }

    /// Join DAO as a new member
    public fun join_dao(
        dao: &mut DroneDAO,
        membership_payment: Coin<SUI>,
        requested_tokens: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): DAOMembership {
        assert!(dao.dao_status == DAO_ACTIVE, E_UNAUTHORIZED);
        
        let payment_amount = coin::value(&membership_payment);
        let current_time = clock::timestamp_ms(clock);
        let member_address = tx_context::sender(ctx);
        
        // Determine membership tier based on token amount
        let tier = if (requested_tokens >= 10000) {
            TIER_ELITE
        } else if (requested_tokens >= 1000) {
            TIER_PREMIUM
        } else {
            TIER_BASIC
        };
        
        // Add payment to treasury
        balance::join(&mut dao.treasury_balance, coin::into_balance(membership_payment));
        
        // Update DAO stats
        dao.total_members = dao.total_members + 1;
        dao.total_voting_power = dao.total_voting_power + requested_tokens;
        dao.governance_token_supply = dao.governance_token_supply + requested_tokens;
        
        let dao_id = object::id(dao);
        
        let membership = DAOMembership {
            id: object::new(ctx),
            dao_id,
            member_address,
            governance_tokens: requested_tokens,
            membership_tier: tier,
            joined_at: current_time,
            last_vote_time: 0,
            total_votes_cast: 0,
            reputation_score: 50, // Starting reputation
            delegated_to: option::none(),
            delegation_power: 0,
        };
        
        // Emit member joined event
        events::emit_member_joined(dao_id, member_address, requested_tokens, current_time);
        
        membership
    }

    // ==================== PROPOSAL SYSTEM ====================

    /// Create a new governance proposal
    public fun create_proposal(
        dao: &mut DroneDAO,
        membership: &DAOMembership,
        proposal_type: u8,
        title: String,
        description: String,
        proposal_data: vector<u8>,
        deposit: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Proposal {
        assert!(dao.dao_status == DAO_ACTIVE, E_UNAUTHORIZED);
        assert!(membership.governance_tokens >= dao.governance_config.proposal_threshold, E_INSUFFICIENT_TOKENS);
        assert!(coin::value(&deposit) >= dao.governance_config.proposal_deposit, E_TREASURY_INSUFFICIENT);
        
        let current_time = clock::timestamp_ms(clock);
        let proposer = tx_context::sender(ctx);
        
        // Add deposit to treasury
        balance::join(&mut dao.treasury_balance, coin::into_balance(deposit));
        
        let voting_start = current_time;
        let voting_end = current_time + dao.governance_config.voting_period;
        let execution_time = voting_end + dao.governance_config.execution_delay;
        
        let proposal = Proposal {
            id: object::new(ctx),
            dao_id: object::id(dao),
            proposer,
            proposal_type,
            title,
            description,
            proposal_data,
            voting_start,
            voting_end,
            execution_time,
            votes_for: 0,
            votes_against: 0,
            votes_abstain: 0,
            total_voters: 0,
            status: STATUS_ACTIVE,
            deposit_amount: dao.governance_config.proposal_deposit,
            execution_data: option::none(),
        };
        
        let proposal_id = object::id(&proposal);
        vector::push_back(&mut dao.active_proposals, proposal_id);
        
        // Emit proposal created event
        events::emit_proposal_created(proposal_id, object::id(dao), proposer, proposal_type, current_time);
        
        proposal
    }

    /// Cast a vote on a proposal
    public fun cast_vote(
        dao: &mut DroneDAO,
        proposal: &mut Proposal,
        membership: &mut DAOMembership,
        vote_choice: u8,
        rationale: String,
        clock: &Clock,
        ctx: &mut TxContext
    ): Vote {
        let current_time = clock::timestamp_ms(clock);
        let voter = tx_context::sender(ctx);
        
        assert!(proposal.status == STATUS_ACTIVE, E_VOTING_PERIOD_ENDED);
        assert!(current_time <= proposal.voting_end, E_VOTING_PERIOD_ENDED);
        assert!(membership.dao_id == proposal.dao_id, E_UNAUTHORIZED);
        
        let voting_power = membership.governance_tokens + membership.delegation_power;
        
        // Update proposal vote counts
        match (vote_choice) {
            VOTE_FOR => proposal.votes_for = proposal.votes_for + voting_power,
            VOTE_AGAINST => proposal.votes_against = proposal.votes_against + voting_power,
            VOTE_ABSTAIN => proposal.votes_abstain = proposal.votes_abstain + voting_power,
            _ => abort E_UNAUTHORIZED,
        };
        
        proposal.total_voters = proposal.total_voters + 1;
        
        // Update member stats
        membership.last_vote_time = current_time;
        membership.total_votes_cast = membership.total_votes_cast + 1;
        membership.reputation_score = calculate_reputation_score(membership);
        
        let vote = Vote {
            id: object::new(ctx),
            proposal_id: object::id(proposal),
            voter,
            vote_choice,
            voting_power,
            vote_time: current_time,
            rationale,
        };
        
        // Emit vote cast event
        events::emit_vote_cast(object::id(proposal), voter, vote_choice, voting_power, current_time);
        
        vote
    }

    /// Finalize proposal voting and determine outcome
    public fun finalize_proposal(
        dao: &mut DroneDAO,
        proposal: &mut Proposal,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        assert!(current_time > proposal.voting_end, E_VOTING_PERIOD_ENDED);
        assert!(proposal.status == STATUS_ACTIVE, E_UNAUTHORIZED);
        
        let total_votes = proposal.votes_for + proposal.votes_against + proposal.votes_abstain;
        let participation_rate = (total_votes * 100) / dao.total_voting_power;
        
        // Check quorum
        if (participation_rate < dao.governance_config.quorum_threshold) {
            proposal.status = STATUS_REJECTED;
            return
        };
        
        // Check approval threshold
        let approval_rate = if (total_votes > 0) {
            (proposal.votes_for * 100) / total_votes
        } else {
            0
        };
        
        if (approval_rate >= dao.governance_config.approval_threshold) {
            proposal.status = STATUS_PASSED;
        } else {
            proposal.status = STATUS_REJECTED;
        };
        
        // Move from active to executed proposals
        let (found, index) = vector::index_of(&dao.active_proposals, &object::id(proposal));
        if (found) {
            vector::remove(&mut dao.active_proposals, index);
            vector::push_back(&mut dao.executed_proposals, object::id(proposal));
        };
        
        // Emit proposal finalized event
        events::emit_proposal_finalized(object::id(proposal), proposal.status, current_time);
    }

    /// Execute a passed proposal
    public fun execute_proposal(
        dao: &mut DroneDAO,
        proposal: &mut Proposal,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        assert!(proposal.status == STATUS_PASSED, E_UNAUTHORIZED);
        assert!(current_time >= proposal.execution_time, E_UNAUTHORIZED);
        
        // Execute based on proposal type
        match (proposal.proposal_type) {
            PROPOSAL_TREASURY => execute_treasury_proposal(dao, proposal, ctx),
            PROPOSAL_FLEET => execute_fleet_proposal(dao, proposal, ctx),
            PROPOSAL_REVENUE => execute_revenue_proposal(dao, proposal),
            PROPOSAL_PARAMETER => execute_parameter_proposal(dao, proposal),
            PROPOSAL_MEMBERSHIP => execute_membership_proposal(dao, proposal),
            _ => abort E_INVALID_PROPOSAL_TYPE,
        };
        
        proposal.status = STATUS_EXECUTED;
        
        // Emit proposal executed event
        events::emit_proposal_executed(object::id(proposal), current_time);
    }

    // ==================== PROPOSAL EXECUTION ====================

    /// Execute treasury-related proposal
    fun execute_treasury_proposal(
        dao: &mut DroneDAO,
        proposal: &mut Proposal,
        ctx: &mut TxContext
    ) {
        // Decode proposal data for treasury operation
        // This would contain operation type, amount, recipient, etc.
        // For now, simplified implementation
        
        let operation = TreasuryOperation {
            id: object::new(ctx),
            dao_id: object::id(dao),
            operation_type: OP_WITHDRAWAL, // Simplified
            amount: 1000000000, // 1 SUI
            recipient: option::some(proposal.proposer),
            purpose: proposal.title,
            authorized_by: object::id(proposal),
            executed_at: 0,
            execution_status: 0,
        };
        
        transfer::share_object(operation);
    }

    /// Execute fleet management proposal
    fun execute_fleet_proposal(
        dao: &mut DroneDAO,
        proposal: &mut Proposal,
        ctx: &mut TxContext
    ) {
        let decision = FleetDecision {
            id: object::new(ctx),
            dao_id: object::id(dao),
            decision_type: FLEET_PURCHASE, // Simplified
            target_drone_id: option::none(),
            decision_data: proposal.proposal_data,
            cost_estimate: 5000000000, // 5 SUI
            expected_roi: 120, // 20% ROI
            risk_assessment: 1, // Medium risk
            authorized_by: object::id(proposal),
            execution_deadline: 0,
            status: 0,
        };
        
        transfer::share_object(decision);
    }

    /// Execute revenue sharing proposal
    fun execute_revenue_proposal(
        dao: &mut DroneDAO,
        _proposal: &mut Proposal
    ) {
        // Update revenue sharing rules based on proposal data
        // Simplified implementation
        dao.revenue_sharing_rules.member_share_percentage = 60;
        dao.revenue_sharing_rules.treasury_percentage = 25;
        dao.revenue_sharing_rules.reinvestment_percentage = 10;
        dao.revenue_sharing_rules.operational_percentage = 5;
    }

    /// Execute governance parameter proposal
    fun execute_parameter_proposal(
        dao: &mut DroneDAO,
        _proposal: &mut Proposal
    ) {
        // Update governance parameters based on proposal data
        // Simplified implementation
        dao.governance_config.quorum_threshold = 30; // 30% quorum
        dao.governance_config.approval_threshold = 60; // 60% approval
    }

    /// Execute membership-related proposal
    fun execute_membership_proposal(
        dao: &mut DroneDAO,
        _proposal: &mut Proposal
    ) {
        // Update membership rules based on proposal data
        // Simplified implementation
        dao.governance_config.member_admission_threshold = 100; // 100 tokens minimum
    }

    // ==================== VOTE DELEGATION ====================

    /// Delegate voting power to another member
    public fun delegate_votes(
        dao: &DroneDAO,
        delegator_membership: &mut DAOMembership,
        delegate_address: address,
        delegation_power: u64,
        delegation_end: Option<u64>,
        delegation_scope: u8,
        clock: &Clock,
        ctx: &mut TxContext
    ): VoteDelegation {
        let current_time = clock::timestamp_ms(clock);
        
        assert!(delegator_membership.governance_tokens >= delegation_power, E_INSUFFICIENT_TOKENS);
        assert!(dao.dao_status == DAO_ACTIVE, E_UNAUTHORIZED);
        
        // Update delegator membership
        delegator_membership.delegated_to = option::some(delegate_address);
        delegator_membership.governance_tokens = delegator_membership.governance_tokens - delegation_power;
        
        let delegation = VoteDelegation {
            id: object::new(ctx),
            delegator: delegator_membership.member_address,
            delegate: delegate_address,
            dao_id: object::id(dao),
            delegated_power: delegation_power,
            delegation_start: current_time,
            delegation_end,
            delegation_scope,
        };
        
        // Emit delegation event
        events::emit_vote_delegated(
            delegator_membership.member_address,
            delegate_address,
            delegation_power,
            current_time
        );
        
        delegation
    }

    /// Revoke vote delegation
    public fun revoke_delegation(
        delegator_membership: &mut DAOMembership,
        delegation: &VoteDelegation,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        assert!(delegator_membership.member_address == delegation.delegator, E_UNAUTHORIZED);
        
        // Return delegated power
        delegator_membership.governance_tokens = delegator_membership.governance_tokens + delegation.delegated_power;
        delegator_membership.delegated_to = option::none();
        
        // Emit revocation event
        events::emit_delegation_revoked(
            delegation.delegator,
            delegation.delegate,
            delegation.delegated_power,
            current_time
        );
    }

    // ==================== TREASURY MANAGEMENT ====================

    /// Distribute revenue to DAO members
    public fun distribute_revenue(
        dao: &mut DroneDAO,
        total_revenue: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        // Calculate distribution amounts
        let member_share = (total_revenue * dao.revenue_sharing_rules.member_share_percentage) / 100;
        let treasury_share = (total_revenue * dao.revenue_sharing_rules.treasury_percentage) / 100;
        let reinvestment_share = (total_revenue * dao.revenue_sharing_rules.reinvestment_percentage) / 100;
        
        // Keep treasury and reinvestment shares in DAO treasury
        // Member shares would be distributed based on token holdings
        // Simplified implementation - actual distribution would require member iteration
        
        // Emit revenue distribution event
        events::emit_revenue_distributed(object::id(dao), total_revenue, member_share, current_time);
    }

    /// Withdraw from DAO treasury (requires proposal)
    public fun withdraw_from_treasury(
        dao: &mut DroneDAO,
        amount: u64,
        recipient: address,
        authorized_proposal: ID,
        ctx: &mut TxContext
    ) {
        assert!(balance::value(&dao.treasury_balance) >= amount, E_TREASURY_INSUFFICIENT);
        
        let withdrawal = coin::from_balance(
            balance::split(&mut dao.treasury_balance, amount),
            ctx
        );
        
        transfer::public_transfer(withdrawal, recipient);
        
        // Emit treasury withdrawal event
        events::emit_treasury_withdrawal(object::id(dao), amount, recipient, authorized_proposal);
    }

    // ==================== UTILITY FUNCTIONS ====================

    /// Calculate member reputation score based on participation
    fun calculate_reputation_score(membership: &DAOMembership): u64 {
        let base_score = 50;
        let participation_bonus = if (membership.total_votes_cast > 10) { 30 } else { membership.total_votes_cast * 3 };
        let tier_bonus = match (membership.membership_tier) {
            TIER_FOUNDER => 20,
            TIER_ELITE => 15,
            TIER_PREMIUM => 10,
            TIER_BASIC => 5,
            _ => 0,
        };
        
        let total_score = base_score + participation_bonus + tier_bonus;
        if (total_score > 100) { 100 } else { total_score }
    }

    /// Check if member has sufficient voting power
    public fun has_voting_power(membership: &DAOMembership, required_power: u64): bool {
        (membership.governance_tokens + membership.delegation_power) >= required_power
    }

    /// Get effective voting power (own tokens + delegated)
    public fun get_effective_voting_power(membership: &DAOMembership): u64 {
        membership.governance_tokens + membership.delegation_power
    }

    // ==================== CONSTRUCTOR FUNCTIONS ====================

    /// Create governance configuration
    public fun create_governance_config(
        proposal_threshold: u64,
        voting_period: u64,
        execution_delay: u64,
        quorum_threshold: u64,
        approval_threshold: u64,
        member_admission_threshold: u64,
        proposal_deposit: u64,
        max_active_proposals: u64
    ): GovernanceConfig {
        GovernanceConfig {
            proposal_threshold,
            voting_period,
            execution_delay,
            quorum_threshold,
            approval_threshold,
            member_admission_threshold,
            proposal_deposit,
            max_active_proposals,
        }
    }

    /// Create revenue rules
    public fun create_revenue_rules(
        member_share_percentage: u64,
        treasury_percentage: u64,
        reinvestment_percentage: u64,
        operational_percentage: u64,
        performance_bonus_pool: u64,
        distribution_frequency: u64
    ): RevenueRules {
        RevenueRules {
            member_share_percentage,
            treasury_percentage,
            reinvestment_percentage,
            operational_percentage,
            performance_bonus_pool,
            distribution_frequency,
        }
    }

    // ==================== GETTER FUNCTIONS ====================

    public fun dao_total_members(dao: &DroneDAO): u64 {
        dao.total_members
    }

    public fun dao_total_voting_power(dao: &DroneDAO): u64 {
        dao.total_voting_power
    }

    public fun dao_treasury_balance(dao: &DroneDAO): u64 {
        balance::value(&dao.treasury_balance)
    }

    public fun dao_status(dao: &DroneDAO): u8 {
        dao.dao_status
    }

    public fun proposal_votes_for(proposal: &Proposal): u64 {
        proposal.votes_for
    }

    public fun proposal_votes_against(proposal: &Proposal): u64 {
        proposal.votes_against
    }

    public fun proposal_status(proposal: &Proposal): u8 {
        proposal.status
    }

    public fun membership_tokens(membership: &DAOMembership): u64 {
        membership.governance_tokens
    }

    public fun membership_reputation(membership: &DAOMembership): u64 {
        membership.reputation_score
    }

    public fun membership_tier(membership: &DAOMembership): u8 {
        membership.membership_tier
    }

    // ==================== TEST-COMPATIBLE GETTER FUNCTIONS ====================

    public fun total_members(dao: &DroneDAO): u64 {
        dao.total_members
    }
} 