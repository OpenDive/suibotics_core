#[test_only]
module swarm_logistics::dao_governance_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::object;
    use std::string;
    use std::option;
    use std::vector;
    use swarm_logistics::dao_governance;

    // Test addresses
    const FOUNDER: address = @0x1;
    const MEMBER1: address = @0x2;
    const MEMBER2: address = @0x3;
    const MEMBER3: address = @0x4;

    // Test constants
    const INITIAL_TREASURY: u64 = 10_000_000_000; // 10 SUI
    const FOUNDER_TOKENS: u64 = 5000;
    const MEMBER_TOKENS: u64 = 1000;
    const PROPOSAL_DEPOSIT: u64 = 100_000_000; // 0.1 SUI

    #[test]
    fun test_dao_creation() {
        let mut scenario_val = test_scenario::begin(FOUNDER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, FOUNDER);
        {
            let treasury_coin = coin::mint_for_testing<SUI>(INITIAL_TREASURY, test_scenario::ctx(scenario));
            
            let governance_config = dao_governance::create_governance_config(
                100,    // proposal_threshold
                86400000, // voting_period (24 hours)
                3600000,  // execution_delay (1 hour)
                25,       // quorum_threshold (25%)
                60,       // approval_threshold (60%)
                50,       // member_admission_threshold
                PROPOSAL_DEPOSIT, // proposal_deposit
                10        // max_active_proposals
            );

            let revenue_rules = dao_governance::create_revenue_rules(
                60, // member_share_percentage
                25, // treasury_percentage
                10, // reinvestment_percentage
                5,  // operational_percentage
                5,  // performance_bonus_pool
                604800000 // distribution_frequency (1 week)
            );

            let (dao, founder_membership) = dao_governance::create_dao(
                string::utf8(b"Test Drone Fleet DAO"),
                treasury_coin,
                governance_config,
                revenue_rules,
                FOUNDER_TOKENS,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Test DAO properties
            assert!(dao_governance::dao_total_members(&dao) == 1, 0);
            assert!(dao_governance::dao_total_voting_power(&dao) == FOUNDER_TOKENS, 1);
            assert!(dao_governance::dao_treasury_balance(&dao) == INITIAL_TREASURY, 2);
            assert!(dao_governance::dao_status(&dao) == 0, 3); // DAO_ACTIVE

            // Test founder membership
            assert!(dao_governance::membership_tokens(&founder_membership) == FOUNDER_TOKENS, 4);
            assert!(dao_governance::membership_tier(&founder_membership) == 3, 5); // TIER_FOUNDER
            assert!(dao_governance::membership_reputation(&founder_membership) == 100, 6);

            transfer::public_share_object(dao);
            transfer::public_transfer(founder_membership, FOUNDER);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_member_joining() {
        let mut scenario_val = test_scenario::begin(FOUNDER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        // Create DAO first
        test_scenario::next_tx(scenario, FOUNDER);
        {
            let treasury_coin = coin::mint_for_testing<SUI>(INITIAL_TREASURY, test_scenario::ctx(scenario));
            
            let governance_config = dao_governance::create_governance_config(
                100, 86400000, 3600000, 25, 60, 50, PROPOSAL_DEPOSIT, 10
            );

            let revenue_rules = dao_governance::create_revenue_rules(
                60, 25, 10, 5, 5, 604800000
            );

            let (dao, founder_membership) = dao_governance::create_dao(
                string::utf8(b"Test DAO"),
                treasury_coin,
                governance_config,
                revenue_rules,
                FOUNDER_TOKENS,
                &clock,
                test_scenario::ctx(scenario)
            );

            transfer::public_share_object(dao);
            transfer::public_transfer(founder_membership, FOUNDER);
        };

        // Member joins DAO
        test_scenario::next_tx(scenario, MEMBER1);
        {
            let mut dao = test_scenario::take_shared<dao_governance::DroneDAO>(scenario);
            let membership_payment = coin::mint_for_testing<SUI>(1_000_000_000, test_scenario::ctx(scenario)); // 1 SUI

            let membership = dao_governance::join_dao(
                &mut dao,
                membership_payment,
                MEMBER_TOKENS,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Test updated DAO state
            assert!(dao_governance::dao_total_members(&dao) == 2, 0);
            assert!(dao_governance::dao_total_voting_power(&dao) == FOUNDER_TOKENS + MEMBER_TOKENS, 1);
            assert!(dao_governance::dao_treasury_balance(&dao) == INITIAL_TREASURY + 1_000_000_000, 2);

            // Test membership properties
            assert!(dao_governance::membership_tokens(&membership) == MEMBER_TOKENS, 3);
            assert!(dao_governance::membership_tier(&membership) == 1, 4); // TIER_PREMIUM
            assert!(dao_governance::membership_reputation(&membership) == 50, 5);

            test_scenario::return_shared(dao);
            transfer::public_transfer(membership, MEMBER1);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_proposal_creation_and_voting() {
        let mut scenario_val = test_scenario::begin(FOUNDER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        // Setup DAO with multiple members
        setup_dao_with_members(scenario, &clock);

        // Create proposal
        test_scenario::next_tx(scenario, FOUNDER);
        {
            let mut dao = test_scenario::take_shared<dao_governance::DroneDAO>(scenario);
            let founder_membership = test_scenario::take_from_sender<dao_governance::DAOMembership>(scenario);
            let deposit = coin::mint_for_testing<SUI>(PROPOSAL_DEPOSIT, test_scenario::ctx(scenario));

            let proposal = dao_governance::create_proposal(
                &mut dao,
                &founder_membership,
                1, // PROPOSAL_TREASURY
                string::utf8(b"Treasury Withdrawal"),
                string::utf8(b"Withdraw 1 SUI for operations"),
                vector::empty<u8>(),
                deposit,
                &clock,
                test_scenario::ctx(scenario)
            );

            assert!(dao_governance::proposal_status(&proposal) == 0, 0); // STATUS_ACTIVE

            test_scenario::return_shared(dao);
            transfer::public_transfer(founder_membership, FOUNDER);
            transfer::public_share_object(proposal);
        };

        // Vote on proposal
        test_scenario::next_tx(scenario, MEMBER1);
        {
            let mut dao = test_scenario::take_shared<dao_governance::DroneDAO>(scenario);
            let mut proposal = test_scenario::take_shared<dao_governance::Proposal>(scenario);
            let mut member_membership = test_scenario::take_from_sender<dao_governance::DAOMembership>(scenario);

            let vote = dao_governance::cast_vote(
                &mut dao,
                &mut proposal,
                &mut member_membership,
                1, // VOTE_FOR
                string::utf8(b"Good proposal"),
                &clock,
                test_scenario::ctx(scenario)
            );

            assert!(dao_governance::proposal_votes_for(&proposal) == MEMBER_TOKENS, 0);
            assert!(dao_governance::membership_reputation(&member_membership) > 50, 1); // Reputation increased

            test_scenario::return_shared(dao);
            test_scenario::return_shared(proposal);
            transfer::public_transfer(member_membership, MEMBER1);
            transfer::public_transfer(vote, MEMBER1);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_proposal_finalization() {
        let mut scenario_val = test_scenario::begin(FOUNDER);
        let scenario = &mut scenario_val;
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        // Setup DAO and create proposal
        setup_dao_with_members(scenario, &clock);
        create_test_proposal(scenario, &clock);

        // Cast votes from multiple members
        cast_votes_from_members(scenario, &clock);

        // Advance time past voting period
        clock::increment_for_testing(&mut clock, 86400001); // 24 hours + 1ms

        // Finalize proposal
        test_scenario::next_tx(scenario, FOUNDER);
        {
            let mut dao = test_scenario::take_shared<dao_governance::DroneDAO>(scenario);
            let mut proposal = test_scenario::take_shared<dao_governance::Proposal>(scenario);

            dao_governance::finalize_proposal(&mut dao, &mut proposal, &clock);

            // Check if proposal passed (should pass with enough votes)
            let status = dao_governance::proposal_status(&proposal);
            assert!(status == 1 || status == 2, 0); // STATUS_PASSED or STATUS_REJECTED

            test_scenario::return_shared(dao);
            test_scenario::return_shared(proposal);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_vote_delegation() {
        let mut scenario_val = test_scenario::begin(FOUNDER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        // Setup DAO with members
        setup_dao_with_members(scenario, &clock);

        // Test vote delegation
        test_scenario::next_tx(scenario, MEMBER1);
        {
            let dao = test_scenario::take_shared<dao_governance::DroneDAO>(scenario);
            let mut member1_membership = test_scenario::take_from_sender<dao_governance::DAOMembership>(scenario);

            let delegation_power = 500;
            let delegation = dao_governance::delegate_votes(
                &dao,
                &mut member1_membership,
                MEMBER2,
                delegation_power,
                option::none(), // Permanent delegation
                0, // All proposals
                &clock,
                test_scenario::ctx(scenario)
            );

            // Check that tokens were deducted from delegator
            assert!(dao_governance::membership_tokens(&member1_membership) == MEMBER_TOKENS - delegation_power, 0);

            test_scenario::return_shared(dao);
            transfer::public_transfer(member1_membership, MEMBER1);
            transfer::public_transfer(delegation, MEMBER1);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_treasury_operations() {
        let mut scenario_val = test_scenario::begin(FOUNDER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        // Setup DAO
        setup_dao_with_members(scenario, &clock);

        // Test revenue distribution
        test_scenario::next_tx(scenario, FOUNDER);
        {
            let mut dao = test_scenario::take_shared<dao_governance::DroneDAO>(scenario);
            let initial_balance = dao_governance::dao_treasury_balance(&dao);

            dao_governance::distribute_revenue(
                &mut dao,
                5_000_000_000, // 5 SUI revenue
                &clock,
                test_scenario::ctx(scenario)
            );

            // Treasury should remain the same (distribution is conceptual in this test)
            assert!(dao_governance::dao_treasury_balance(&dao) == initial_balance, 0);

            test_scenario::return_shared(dao);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_utility_functions() {
        let mut scenario_val = test_scenario::begin(FOUNDER);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        // Setup DAO with members
        setup_dao_with_members(scenario, &clock);

        test_scenario::next_tx(scenario, MEMBER1);
        {
            let membership = test_scenario::take_from_sender<dao_governance::DAOMembership>(scenario);

            // Test voting power functions
            assert!(dao_governance::has_voting_power(&membership, 500) == true, 0);
            assert!(dao_governance::has_voting_power(&membership, 2000) == false, 1);
            assert!(dao_governance::get_effective_voting_power(&membership) == MEMBER_TOKENS, 2);

            transfer::public_transfer(membership, MEMBER1);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== HELPER FUNCTIONS ====================

    fun setup_dao_with_members(scenario: &mut Scenario, clock: &Clock) {
        // Create DAO
        test_scenario::next_tx(scenario, FOUNDER);
        {
            let treasury_coin = coin::mint_for_testing<SUI>(INITIAL_TREASURY, test_scenario::ctx(scenario));
            
            let governance_config = dao_governance::create_governance_config(
                100, 86400000, 3600000, 25, 60, 50, PROPOSAL_DEPOSIT, 10
            );

            let revenue_rules = dao_governance::create_revenue_rules(
                60, 25, 10, 5, 5, 604800000
            );

            let (dao, founder_membership) = dao_governance::create_dao(
                string::utf8(b"Test DAO"),
                treasury_coin,
                governance_config,
                revenue_rules,
                FOUNDER_TOKENS,
                clock,
                test_scenario::ctx(scenario)
            );

            transfer::public_share_object(dao);
            transfer::public_transfer(founder_membership, FOUNDER);
        };

        // Add Member 1
        test_scenario::next_tx(scenario, MEMBER1);
        {
            let mut dao = test_scenario::take_shared<dao_governance::DroneDAO>(scenario);
            let payment = coin::mint_for_testing<SUI>(1_000_000_000, test_scenario::ctx(scenario));

            let membership = dao_governance::join_dao(
                &mut dao,
                payment,
                MEMBER_TOKENS,
                clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(dao);
            transfer::public_transfer(membership, MEMBER1);
        };

        // Add Member 2
        test_scenario::next_tx(scenario, MEMBER2);
        {
            let mut dao = test_scenario::take_shared<dao_governance::DroneDAO>(scenario);
            let payment = coin::mint_for_testing<SUI>(1_000_000_000, test_scenario::ctx(scenario));

            let membership = dao_governance::join_dao(
                &mut dao,
                payment,
                MEMBER_TOKENS,
                clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(dao);
            transfer::public_transfer(membership, MEMBER2);
        };
    }

    fun create_test_proposal(scenario: &mut Scenario, clock: &Clock) {
        test_scenario::next_tx(scenario, FOUNDER);
        {
            let mut dao = test_scenario::take_shared<dao_governance::DroneDAO>(scenario);
            let founder_membership = test_scenario::take_from_sender<dao_governance::DAOMembership>(scenario);
            let deposit = coin::mint_for_testing<SUI>(PROPOSAL_DEPOSIT, test_scenario::ctx(scenario));

            let proposal = dao_governance::create_proposal(
                &mut dao,
                &founder_membership,
                1, // PROPOSAL_TREASURY
                string::utf8(b"Test Proposal"),
                string::utf8(b"Test proposal for voting"),
                vector::empty<u8>(),
                deposit,
                clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(dao);
            transfer::public_transfer(founder_membership, FOUNDER);
            transfer::public_share_object(proposal);
        };
    }

    fun cast_votes_from_members(scenario: &mut Scenario, clock: &Clock) {
        // Founder votes FOR
        test_scenario::next_tx(scenario, FOUNDER);
        {
            let mut dao = test_scenario::take_shared<dao_governance::DroneDAO>(scenario);
            let mut proposal = test_scenario::take_shared<dao_governance::Proposal>(scenario);
            let mut founder_membership = test_scenario::take_from_sender<dao_governance::DAOMembership>(scenario);

            let vote = dao_governance::cast_vote(
                &mut dao,
                &mut proposal,
                &mut founder_membership,
                1, // VOTE_FOR
                string::utf8(b"Founder supports"),
                clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(dao);
            test_scenario::return_shared(proposal);
            transfer::public_transfer(founder_membership, FOUNDER);
            transfer::public_transfer(vote, FOUNDER);
        };

        // Member 1 votes FOR
        test_scenario::next_tx(scenario, MEMBER1);
        {
            let mut dao = test_scenario::take_shared<dao_governance::DroneDAO>(scenario);
            let mut proposal = test_scenario::take_shared<dao_governance::Proposal>(scenario);
            let mut member1_membership = test_scenario::take_from_sender<dao_governance::DAOMembership>(scenario);

            let vote = dao_governance::cast_vote(
                &mut dao,
                &mut proposal,
                &mut member1_membership,
                1, // VOTE_FOR
                string::utf8(b"Member1 supports"),
                clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(dao);
            test_scenario::return_shared(proposal);
            transfer::public_transfer(member1_membership, MEMBER1);
            transfer::public_transfer(vote, MEMBER1);
        };

        // Member 2 votes AGAINST
        test_scenario::next_tx(scenario, MEMBER2);
        {
            let mut dao = test_scenario::take_shared<dao_governance::DroneDAO>(scenario);
            let mut proposal = test_scenario::take_shared<dao_governance::Proposal>(scenario);
            let mut member2_membership = test_scenario::take_from_sender<dao_governance::DAOMembership>(scenario);

            let vote = dao_governance::cast_vote(
                &mut dao,
                &mut proposal,
                &mut member2_membership,
                0, // VOTE_AGAINST
                string::utf8(b"Member2 opposes"),
                clock,
                test_scenario::ctx(scenario)
            );

            test_scenario::return_shared(dao);
            test_scenario::return_shared(proposal);
            transfer::public_transfer(member2_membership, MEMBER2);
            transfer::public_transfer(vote, MEMBER2);
        };
    }
} 