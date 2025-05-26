#[test_only]
module swarm_logistics::economic_engine_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::object;
    use std::string;
    use std::vector;
    use std::option;
    use swarm_logistics::economic_engine;

    // Test addresses
    const ADMIN: address = @0x1;
    const DRONE_OPERATOR: address = @0x2;
    const CUSTOMER: address = @0x3;
    const INVESTOR: address = @0x4;

    // Test constants
    const INITIAL_BALANCE: u64 = 100_000_000_000; // 100 SUI
    const BASE_RATE: u64 = 1_000_000_000; // 1 SUI
    const DISTANCE_RATE: u64 = 100_000_000; // 0.1 SUI per km
    const WEIGHT_RATE: u64 = 1_000_000; // 0.001 SUI per gram

    #[test]
    fun test_pricing_model_creation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, ADMIN);
        {
            let urgency_multipliers = vector[100, 120, 150, 200]; // Normal, High, Urgent, Emergency
            
            let pricing_model = economic_engine::create_pricing_model(
                string::utf8(b"Standard Delivery"),
                BASE_RATE,
                DISTANCE_RATE,
                WEIGHT_RATE,
                urgency_multipliers,
                test_scenario::ctx(scenario)
            );

            // Test pricing model properties
            assert!(economic_engine::pricing_model_base_rate(&pricing_model) == BASE_RATE, 0);

            transfer::public_transfer(pricing_model, ADMIN);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_dynamic_pricing_calculation() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            // Create economic engine
            let engine = create_test_engine(test_scenario::ctx(scenario));
            
            let urgency_multipliers = vector[100, 120, 150, 200];
            let pricing_model = economic_engine::create_pricing_model(
                string::utf8(b"Dynamic Pricing"),
                BASE_RATE,
                DISTANCE_RATE,
                WEIGHT_RATE,
                urgency_multipliers,
                test_scenario::ctx(scenario)
            );

            // Test basic pricing calculation
            let price = economic_engine::calculate_delivery_price(
                &engine,
                &pricing_model,
                10,  // 10 km distance
                1000, // 1 kg weight
                1,   // High urgency
                12,  // Noon time
                0,   // Clear weather
                1    // Medium demand
            );

            // Price should be: base + (10 * distance_rate) + (1000 * weight_rate / 1000) + multipliers
            // = 1000000000 + (10 * 100000000) + (1000 * 1000000 / 1000) + multipliers
            // = 1000000000 + 1000000000 + 1000000 + multipliers
            assert!(price > BASE_RATE, 0);
            assert!(price > BASE_RATE + DISTANCE_RATE * 10, 1);

            transfer::public_transfer(engine, ADMIN);
            transfer::public_transfer(pricing_model, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_market_conditions_update() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = create_test_engine(test_scenario::ctx(scenario));
            let initial_surge = economic_engine::engine_surge_multiplier(&engine);

            // Update market conditions to high demand, low supply
            economic_engine::update_market_conditions(
                &mut engine,
                2, // High demand
                1, // Low supply
                1, // Some weather impact
                2, // High traffic
                &clock
            );

            let new_surge = economic_engine::engine_surge_multiplier(&engine);
            
            // Surge multiplier should increase due to high demand and low supply
            assert!(new_surge > initial_surge, 0);

            transfer::public_transfer(engine, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_revenue_pool_operations() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let distribution_rules = economic_engine::create_distribution_rules(
                60, // drone_percentage
                20, // owner_percentage
                10, // platform_percentage
                5,  // maintenance_percentage
                3,  // insurance_percentage
                2,  // performance_bonus_pool
                100_000_000 // minimum_payout (0.1 SUI)
            );

            let mut revenue_pool = economic_engine::create_revenue_pool(
                0, // POOL_DRONE
                distribution_rules,
                86400000, // 24 hours distribution frequency
                test_scenario::ctx(scenario)
            );

            // Add revenue to pool
            let payment = coin::mint_for_testing<SUI>(5_000_000_000, test_scenario::ctx(scenario)); // 5 SUI
            economic_engine::add_revenue_to_pool(
                &mut revenue_pool,
                payment,
                DRONE_OPERATOR,
                0, // DIST_PERFORMANCE
                85, // High performance score
                option::none(),
                &clock
            );

            // Check pool balance
            assert!(economic_engine::pool_balance(&revenue_pool) == 5_000_000_000, 0);
            assert!(economic_engine::pool_pending_count(&revenue_pool) == 1, 1);

            transfer::public_transfer(revenue_pool, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_revenue_distribution_processing() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let distribution_rules = economic_engine::create_distribution_rules(
                60, 20, 10, 5, 3, 2, 100_000_000
            );

            let mut revenue_pool = economic_engine::create_revenue_pool(
                0, // POOL_DRONE
                distribution_rules,
                1000, // 1 second distribution frequency for testing
                test_scenario::ctx(scenario)
            );

            // Add revenue
            let payment = coin::mint_for_testing<SUI>(2_000_000_000, test_scenario::ctx(scenario)); // 2 SUI
            economic_engine::add_revenue_to_pool(
                &mut revenue_pool,
                payment,
                DRONE_OPERATOR,
                0, // DIST_PERFORMANCE
                90, // Excellent performance
                option::none(),
                &clock
            );

            // Advance time to trigger distribution
            clock::increment_for_testing(&mut clock, 2000);

            // Process distributions
            economic_engine::process_revenue_distributions(
                &mut revenue_pool,
                &clock,
                test_scenario::ctx(scenario)
            );

            // Pool should have processed the distribution
            assert!(economic_engine::pool_pending_count(&revenue_pool) == 0, 0);

            transfer::public_transfer(revenue_pool, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_market_maker_operations() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut market_maker = economic_engine::create_market_maker(
                string::utf8(b"North America"),
                BASE_RATE, // Initial price
                test_scenario::ctx(scenario)
            );

            let initial_price = economic_engine::market_current_price(&market_maker);
            assert!(initial_price == BASE_RATE, 0);

            // Add market orders
            let order_id = object::id_from_address(@0x123);
            economic_engine::add_market_order(
                &mut market_maker,
                order_id,
                0, // Buy order
                BASE_RATE + 100_000_000, // Higher price
                10, // Quantity
                clock::timestamp_ms(&clock) + 3600000, // Expires in 1 hour
                &clock
            );

            // Market price should be updated
            let new_price = economic_engine::market_current_price(&market_maker);
            assert!(new_price != initial_price, 1);

            // Check volatility calculation
            let volatility = economic_engine::market_volatility(&market_maker);
            assert!(volatility >= 0, 2);

            transfer::public_transfer(market_maker, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_treasury_management() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let initial_balance = coin::mint_for_testing<SUI>(INITIAL_BALANCE, test_scenario::ctx(scenario));
            
            let mut treasury = economic_engine::create_treasury(
                initial_balance,
                1, // STRATEGY_MODERATE
                test_scenario::ctx(scenario)
            );

            // Check initial state
            assert!(economic_engine::treasury_total_assets(&treasury) == INITIAL_BALANCE, 0);
            assert!(economic_engine::treasury_liquidity_ratio(&treasury) == 100, 1);

            // Test rebalancing
            economic_engine::rebalance_treasury(&mut treasury, &clock);

            // Treasury should maintain its properties after rebalancing
            assert!(economic_engine::treasury_total_assets(&treasury) == INITIAL_BALANCE, 2);
            assert!(economic_engine::treasury_liquidity_ratio(&treasury) > 0, 3);

            transfer::public_transfer(treasury, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_performance_metrics() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let current_time = clock::timestamp_ms(&clock);
            
            let mut metrics = economic_engine::create_performance_metrics(
                current_time,
                current_time + 86400000, // 24 hour period
                test_scenario::ctx(scenario)
            );

            // Update metrics with some data
            economic_engine::update_performance_metrics(
                &mut metrics,
                10_000_000_000, // 10 SUI revenue
                6_000_000_000,  // 6 SUI costs
                50, // 50 deliveries
                85  // 85% satisfaction
            );

            // Check calculated metrics
            assert!(economic_engine::metrics_profit_margin(&metrics) == 40, 0); // (10-6)/10 * 100 = 40%
            
            // Update again to test accumulation
            economic_engine::update_performance_metrics(
                &mut metrics,
                5_000_000_000, // 5 more SUI revenue
                2_000_000_000, // 2 more SUI costs
                25, // 25 more deliveries
                90  // 90% satisfaction
            );

            // Profit margin should be updated: (15-8)/15 * 100 = 46.67% ≈ 46%
            assert!(economic_engine::metrics_profit_margin(&metrics) >= 45, 1);

            transfer::public_transfer(metrics, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_surge_pricing_scenarios() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let mut engine = create_test_engine(test_scenario::ctx(scenario));
            let urgency_multipliers = vector[100, 120, 150, 200];
            let pricing_model = economic_engine::create_pricing_model(
                string::utf8(b"Surge Test"),
                BASE_RATE,
                DISTANCE_RATE,
                WEIGHT_RATE,
                urgency_multipliers,
                test_scenario::ctx(scenario)
            );

            // Test low demand scenario
            economic_engine::update_market_conditions(
                &mut engine,
                0, // Low demand
                3, // High supply
                0, // Clear weather
                0, // Low traffic
                &clock
            );

            let low_demand_price = economic_engine::calculate_delivery_price(
                &engine,
                &pricing_model,
                5, 500, 0, 12, 0, 0
            );

            // Test high demand scenario
            economic_engine::update_market_conditions(
                &mut engine,
                3, // Critical demand
                0, // Very low supply
                2, // Bad weather
                3, // High traffic
                &clock
            );

            let high_demand_price = economic_engine::calculate_delivery_price(
                &engine,
                &pricing_model,
                5, 500, 0, 12, 2, 3
            );

            // High demand price should be significantly higher
            assert!(high_demand_price > low_demand_price, 0);
            assert!(high_demand_price > low_demand_price * 150 / 100, 1); // At least 50% higher

            transfer::public_transfer(engine, ADMIN);
            transfer::public_transfer(pricing_model, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_multiple_revenue_pools() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            let drone_rules = economic_engine::create_distribution_rules(
                70, 15, 10, 3, 2, 0, 50_000_000
            );
            let owner_rules = economic_engine::create_distribution_rules(
                0, 80, 15, 3, 2, 0, 100_000_000
            );

            let mut drone_pool = economic_engine::create_revenue_pool(
                0, // POOL_DRONE
                drone_rules,
                3600000, // 1 hour
                test_scenario::ctx(scenario)
            );

            let mut owner_pool = economic_engine::create_revenue_pool(
                1, // POOL_OWNER
                owner_rules,
                86400000, // 24 hours
                test_scenario::ctx(scenario)
            );

            // Add revenue to both pools
            let drone_payment = coin::mint_for_testing<SUI>(3_000_000_000, test_scenario::ctx(scenario));
            let owner_payment = coin::mint_for_testing<SUI>(2_000_000_000, test_scenario::ctx(scenario));

            economic_engine::add_revenue_to_pool(
                &mut drone_pool,
                drone_payment,
                DRONE_OPERATOR,
                0, 80, option::none(), &clock
            );

            economic_engine::add_revenue_to_pool(
                &mut owner_pool,
                owner_payment,
                CUSTOMER,
                1, 75, option::none(), &clock
            );

            // Check both pools have correct balances
            assert!(economic_engine::pool_balance(&drone_pool) == 3_000_000_000, 0);
            assert!(economic_engine::pool_balance(&owner_pool) == 2_000_000_000, 1);
            assert!(economic_engine::pool_pending_count(&drone_pool) == 1, 2);
            assert!(economic_engine::pool_pending_count(&owner_pool) == 1, 3);

            transfer::public_transfer(drone_pool, ADMIN);
            transfer::public_transfer(owner_pool, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_treasury_investment_strategies() {
        let mut scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        let clock = clock::create_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        {
            // Test conservative strategy
            let conservative_balance = coin::mint_for_testing<SUI>(INITIAL_BALANCE, test_scenario::ctx(scenario));
            let mut conservative_treasury = economic_engine::create_treasury(
                conservative_balance,
                0, // STRATEGY_CONSERVATIVE
                test_scenario::ctx(scenario)
            );

            // Test aggressive strategy
            let aggressive_balance = coin::mint_for_testing<SUI>(INITIAL_BALANCE, test_scenario::ctx(scenario));
            let mut aggressive_treasury = economic_engine::create_treasury(
                aggressive_balance,
                2, // STRATEGY_AGGRESSIVE
                test_scenario::ctx(scenario)
            );

            // Rebalance both
            economic_engine::rebalance_treasury(&mut conservative_treasury, &clock);
            economic_engine::rebalance_treasury(&mut aggressive_treasury, &clock);

            // Both should maintain their total assets
            assert!(economic_engine::treasury_total_assets(&conservative_treasury) == INITIAL_BALANCE, 0);
            assert!(economic_engine::treasury_total_assets(&aggressive_treasury) == INITIAL_BALANCE, 1);

            // Both should have reasonable liquidity ratios
            assert!(economic_engine::treasury_liquidity_ratio(&conservative_treasury) > 0, 2);
            assert!(economic_engine::treasury_liquidity_ratio(&aggressive_treasury) > 0, 3);

            transfer::public_transfer(conservative_treasury, ADMIN);
            transfer::public_transfer(aggressive_treasury, ADMIN);
        };

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    // ==================== HELPER FUNCTIONS ====================

    fun create_test_engine(ctx: &mut TxContext): economic_engine::EconomicEngine {
        // Create a test economic engine
        economic_engine::create_test_economic_engine(ctx)
    }
} 