/// Example demonstrating Economic Engine and DAO Governance features
/// Shows how to create a DAO, manage dynamic pricing, and conduct governance
module swarm_logistics::economic_dao_example {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::string;
    use std::vector;
    use std::option;
    use swarm_logistics::economic_engine::{Self, EconomicEngine, PricingModel, RevenuePool, Treasury, PerformanceMetrics};
    use swarm_logistics::dao_governance::{Self, DroneDAO, DAOMembership, Proposal, GovernanceConfig, RevenueRules};

    // ==================== ECONOMIC ENGINE EXAMPLES ====================

    /// Example: Create and use dynamic pricing model
    public fun example_dynamic_pricing(
        engine: &EconomicEngine,
        clock: &Clock,
        ctx: &mut TxContext
    ): (PricingModel, u64) {
        // Create a dynamic pricing model for urban deliveries
        let pricing_model = economic_engine::create_pricing_model(
            string::utf8(b"Urban Express Delivery"),
            2000000000,  // 2 SUI base rate
            100000000,   // 0.1 SUI per km
            1000,        // 1000 MIST per gram
            vector[100, 120, 150, 200], // Urgency multipliers: Normal, Express, Rush, Emergency
            ctx
        );

        // Calculate price for a sample delivery
        let delivery_price = economic_engine::calculate_delivery_price(
            engine,
            &pricing_model,
            5,    // 5 km distance
            500,  // 500 grams
            2,    // Rush urgency
            14,   // 2 PM (peak hours)
            1,    // Light rain weather
            2     // High demand
        );

        (pricing_model, delivery_price)
    }

    /// Example: Revenue distribution system
    public fun example_revenue_distribution(
        initial_payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ): RevenuePool {
        // Create distribution rules
        let distribution_rules = economic_engine::create_distribution_rules(
            50,        // 50% to drone
            25,        // 25% to owner
            10,        // 10% to platform
            10,        // 10% to maintenance
            5,         // 5% to insurance
            0,         // No bonus pool for this example
            100000000  // 0.1 SUI minimum
        );

        // Create revenue pool
        let mut revenue_pool = economic_engine::create_revenue_pool(
            0, // Drone pool type
            distribution_rules,
            86400000, // Daily distribution (24 hours in milliseconds)
            ctx
        );

        // Add revenue to pool
        economic_engine::add_revenue_to_pool(
            &mut revenue_pool,
            initial_payment,
            @0x123, // Recipient address
            0,      // Performance distribution type
            85,     // 85% performance score
            option::none(), // No specific order ID
            clock
        );

        revenue_pool
    }

    /// Example: Treasury management
    public fun example_treasury_management(
        initial_funds: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Treasury {
        // Create autonomous treasury with moderate investment strategy
        let mut treasury = economic_engine::create_treasury(
            initial_funds,
            1, // Moderate investment strategy
            ctx
        );

        // Rebalance treasury allocations
        economic_engine::rebalance_treasury(&mut treasury, clock);

        treasury
    }

    /// Example: Performance metrics tracking
    public fun example_performance_metrics(
        clock: &Clock,
        ctx: &mut TxContext
    ): PerformanceMetrics {
        let current_time = clock::timestamp_ms(clock);
        let period_start = current_time - 2592000000; // 30 days ago
        
        // Create performance tracker
        let mut metrics = economic_engine::create_performance_metrics(
            period_start,
            current_time,
            ctx
        );

        // Update with sample data
        economic_engine::update_performance_metrics(
            &mut metrics,
            50000000000, // 50 SUI revenue
            20000000000, // 20 SUI costs
            150,         // 150 deliveries
            88           // 88% customer satisfaction
        );

        metrics
    }

    // ==================== DAO GOVERNANCE EXAMPLES ====================

    /// Example: Create a drone fleet DAO
    public fun example_create_dao(
        initial_treasury: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ): (DroneDAO, DAOMembership) {
        // Configure governance parameters
        let governance_config = dao_governance::create_governance_config(
            1000,      // 1000 tokens to create proposal
            604800000, // 7 days voting period
            172800000, // 2 days execution delay
            25,        // 25% quorum required
            60,        // 60% approval required
            100,       // 100 tokens for membership
            1000000000, // 1 SUI proposal deposit
            10         // Max 10 concurrent proposals
        );

        // Configure revenue sharing
        let revenue_rules = dao_governance::create_revenue_rules(
            60,   // 60% to members
            25,   // 25% to treasury
            10,   // 10% for reinvestment
            5,    // 5% for operations
            0,    // No performance bonus
            2592000000 // Monthly distribution
        );

        // Create the DAO
        dao_governance::create_dao(
            string::utf8(b"SkyNet Delivery DAO"),
            initial_treasury,
            governance_config,
            revenue_rules,
            10000, // Founder gets 10,000 tokens
            clock,
            ctx
        )
    }

    /// Example: DAO membership and voting
    public fun example_dao_voting(
        dao: &mut DroneDAO,
        membership_payment: Coin<SUI>,
        proposal_deposit: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ): (DAOMembership, Proposal) {
        // Join DAO as new member
        let mut membership = dao_governance::join_dao(
            dao,
            membership_payment,
            5000, // Request 5000 governance tokens
            clock,
            ctx
        );

        // Create a governance proposal
        let proposal = dao_governance::create_proposal(
            dao,
            &membership,
            1, // Treasury proposal type
            string::utf8(b"Fund New Drone Purchase"),
            string::utf8(b"Proposal to allocate 100 SUI from treasury to purchase 2 new delivery drones for the San Francisco region. Expected ROI: 25% annually."),
            vector[1, 100, 0, 0, 0, 0, 0, 0], // Encoded proposal data (simplified)
            proposal_deposit,
            clock,
            ctx
        );

        (membership, proposal)
    }

    /// Example: Vote delegation
    public fun example_vote_delegation(
        dao: &DroneDAO,
        delegator_membership: &mut DAOMembership,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Delegate 2000 tokens to another member for 30 days
        let delegation_end = clock::timestamp_ms(clock) + 2592000000; // 30 days
        
        let delegation = dao_governance::delegate_votes(
            dao,
            delegator_membership,
            @0x456, // Delegate address
            2000,   // Delegate 2000 tokens
            option::some(delegation_end),
            0,      // All proposal types
            clock,
            ctx
        );
        
        // Transfer delegation object to sender
        transfer::public_transfer(delegation, tx_context::sender(ctx));
    }

    /// Example: Complete governance workflow
    public fun example_complete_governance_workflow(
        dao: &mut DroneDAO,
        proposal: &mut Proposal,
        membership: &mut DAOMembership,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Cast vote on proposal
        let _vote = dao_governance::cast_vote(
            dao,
            proposal,
            membership,
            1, // Vote FOR
            string::utf8(b"This investment will improve our delivery capacity and member returns."),
            clock,
            ctx
        );

        // Simulate time passing (voting period ends)
        // In real usage, this would happen naturally over time

        // Finalize proposal (check if it passed)
        dao_governance::finalize_proposal(dao, proposal, clock);

        // If proposal passed, execute it
        if (dao_governance::proposal_status(proposal) == 1) { // STATUS_PASSED
            dao_governance::execute_proposal(dao, proposal, clock, ctx);
        };
    }

    // ==================== INTEGRATED EXAMPLES ====================

    /// Example: Economic DAO with integrated pricing and governance
    public fun example_integrated_economic_dao(
        initial_treasury: Coin<SUI>,
        membership_payment: Coin<SUI>,
        proposal_deposit: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ): (DroneDAO, DAOMembership, PricingModel) {
        // Create DAO
        let (mut dao, founder_membership) = example_create_dao(initial_treasury, clock, ctx);

        // Join as member
        let _member_membership = dao_governance::join_dao(
            &mut dao,
            membership_payment,
            3000, // 3000 tokens
            clock,
            ctx
        );

        // Create pricing proposal
        let _pricing_proposal = dao_governance::create_proposal(
            &mut dao,
            &founder_membership,
            0, // Parameter proposal type
            string::utf8(b"Update Dynamic Pricing Algorithm"),
            string::utf8(b"Proposal to implement AI-driven dynamic pricing with surge multipliers based on real-time demand and weather conditions."),
            vector[3, 150, 200, 80, 120], // Encoded pricing parameters
            proposal_deposit,
            clock,
            ctx
        );

        // Create corresponding pricing model
        let pricing_model = economic_engine::create_pricing_model(
            string::utf8(b"DAO Managed Dynamic Pricing"),
            1500000000,  // 1.5 SUI base rate
            80000000,    // 0.08 SUI per km
            800,         // 800 MIST per gram
            vector[100, 130, 160, 220], // Updated urgency multipliers
            ctx
        );

        (dao, founder_membership, pricing_model)
    }

    /// Example: Revenue sharing with DAO governance
    public fun example_dao_revenue_sharing(
        dao: &mut DroneDAO,
        total_revenue: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Distribute revenue according to DAO rules
        dao_governance::distribute_revenue(dao, total_revenue, clock, ctx);

        // Example: Propose changes to revenue sharing
        // This would typically be done by a member with sufficient tokens
        // The proposal would then be voted on by all members
    }

    // ==================== UTILITY FUNCTIONS ====================

    /// Get sample governance configuration
    public fun sample_governance_config(): GovernanceConfig {
        dao_governance::create_governance_config(
            500,       // Lower threshold for testing
            86400000,  // 1 day for testing
            3600000,   // 1 hour delay
            20,        // 20% quorum
            55,        // 55% approval
            50,        // 50 tokens minimum
            500000000, // 0.5 SUI deposit
            5          // 5 concurrent proposals
        )
    }

    /// Get sample revenue rules
    public fun sample_revenue_rules(): RevenueRules {
        dao_governance::create_revenue_rules(
            65,   // Higher member share
            20,   // Lower treasury share
            10,   // Reinvestment
            5,    // Operations
            0,    // No bonus pool
            604800000 // Weekly distribution
        )
    }

    /// Calculate expected returns for DAO members
    public fun calculate_member_returns(
        membership: &DAOMembership,
        total_dao_tokens: u64,
        total_revenue: u64,
        member_share_percentage: u64
    ): u64 {
        let member_tokens = dao_governance::membership_tokens(membership);
        let member_share = (total_revenue * member_share_percentage) / 100;
        (member_share * member_tokens) / total_dao_tokens
    }

    /// Estimate DAO treasury growth
    public fun estimate_treasury_growth(
        current_balance: u64,
        monthly_revenue: u64,
        treasury_percentage: u64,
        months: u64
    ): u64 {
        let monthly_treasury_income = (monthly_revenue * treasury_percentage) / 100;
        current_balance + (monthly_treasury_income * months)
    }

    // ==================== DEMO SCENARIOS ====================

    /// Demo: High-frequency trading scenario
    public fun demo_high_frequency_pricing(
        engine: &EconomicEngine,
        pricing_model: &PricingModel,
        clock: &Clock
    ): vector<u64> {
        let mut prices = vector::empty<u64>();
        
        // Simulate pricing throughout the day
        let mut hour = 0;
        while (hour < 24) {
            let price = economic_engine::calculate_delivery_price(
                engine,
                pricing_model,
                3,    // 3 km average delivery
                300,  // 300g average package
                1,    // Express delivery
                (hour as u8), // Current hour
                0,    // Clear weather
                if (hour >= 11 && hour <= 13) { 2 } else { 1 } // High demand during lunch
            );
            vector::push_back(&mut prices, price);
            hour = hour + 1;
        };
        
        prices
    }

    /// Demo: DAO decision making process
    public fun demo_dao_decision_process(): vector<u8> {
        // Simulate a complete DAO decision lifecycle
        vector[
            0, // Proposal created
            1, // Voting period active
            2, // Quorum reached
            3, // Proposal passed
            4, // Execution delay
            5, // Proposal executed
            6  // Results implemented
        ]
    }
} 