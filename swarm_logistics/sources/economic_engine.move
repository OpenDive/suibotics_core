/// Economic Engine - Dynamic Pricing and Financial Management
/// Handles market-driven pricing, revenue distribution, and autonomous financial operations
module swarm_logistics::economic_engine {
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
    use swarm_logistics::drone::{Self as drone_mod};

    // ==================== ECONOMIC STRUCTURES ====================

    /// Central economic coordination system
    public struct EconomicEngine has key, store {
        id: UID,
        total_network_revenue: u64,
        total_transactions: u64,
        active_pricing_models: vector<ID>,
        revenue_pools: vector<ID>,
        market_conditions: MarketConditions,
        pricing_algorithm: u8,          // 0=Fixed, 1=Dynamic, 2=Auction, 3=AI
        base_delivery_rate: u64,        // Base rate in MIST (1 SUI = 1B MIST)
        surge_multiplier: u64,          // Current surge pricing multiplier (100 = 1.0x)
        network_efficiency_score: u64,  // 0-100 network performance
    }

    /// Dynamic pricing model for different scenarios
    public struct PricingModel has key, store {
        id: UID,
        model_name: String,
        base_rate: u64,                 // Base rate in MIST
        distance_rate: u64,             // Rate per kilometer
        weight_rate: u64,               // Rate per gram
        urgency_multipliers: vector<u64>, // Multipliers for different urgency levels
        time_multipliers: vector<u64>,  // Time-of-day multipliers
        weather_multipliers: vector<u64>, // Weather condition multipliers
        demand_elasticity: u64,         // How responsive pricing is to demand (0-100)
        minimum_price: u64,             // Minimum delivery price
        maximum_price: u64,             // Maximum delivery price
        active: bool,
    }

    /// Market conditions affecting pricing
    public struct MarketConditions has store, drop {
        demand_level: u8,               // 0=Low, 1=Medium, 2=High, 3=Critical
        supply_level: u8,               // Available drone capacity
        weather_impact: u8,             // Weather affecting operations
        traffic_density: u8,            // Air traffic density
        fuel_cost_index: u64,           // Relative fuel/energy costs
        competition_factor: u64,        // Market competition level
        seasonal_factor: u64,           // Seasonal demand patterns
        last_updated: u64,
    }

    /// Revenue distribution pool
    public struct RevenuePool has key, store {
        id: UID,
        pool_type: u8,                  // 0=Drone, 1=Owner, 2=Platform, 3=Maintenance, 4=Insurance
        total_balance: Balance<SUI>,
        pending_distributions: vector<PendingDistribution>,
        distribution_rules: DistributionRules,
        last_distribution: u64,
        distribution_frequency: u64,    // Milliseconds between distributions
    }

    /// Pending revenue distribution
    public struct PendingDistribution has store, drop {
        recipient: address,
        amount: u64,
        distribution_type: u8,          // 0=Performance, 1=Ownership, 2=Maintenance, 3=Bonus
        earned_timestamp: u64,
        order_id: Option<ID>,
        performance_score: u64,         // 0-100 performance rating
    }

    /// Distribution rules for revenue sharing
    public struct DistributionRules has store, drop {
        drone_percentage: u64,          // Percentage to drone operator
        owner_percentage: u64,          // Percentage to drone owner
        platform_percentage: u64,      // Percentage to platform
        maintenance_percentage: u64,    // Percentage to maintenance fund
        insurance_percentage: u64,      // Percentage to insurance fund
        performance_bonus_pool: u64,    // Percentage for performance bonuses
        minimum_payout: u64,            // Minimum amount for payout
    }

    /// Market maker for price discovery
    public struct MarketMaker has key, store {
        id: UID,
        region: String,
        order_book: vector<PriceOrder>,
        current_market_price: u64,
        price_history: vector<PricePoint>,
        volume_24h: u64,
        volatility_index: u64,          // Price volatility measure
        liquidity_score: u64,           // Market liquidity rating
    }

    /// Price order in the market
    public struct PriceOrder has store, drop {
        order_id: ID,
        order_type: u8,                 // 0=Buy, 1=Sell
        price: u64,
        quantity: u64,                  // Number of delivery slots
        timestamp: u64,
        expires_at: u64,
    }

    /// Historical price point
    public struct PricePoint has store, drop {
        timestamp: u64,
        price: u64,
        volume: u64,
        market_conditions: u8,          // Encoded market state
    }

    /// Autonomous treasury management
    public struct Treasury has key, store {
        id: UID,
        operating_balance: Balance<SUI>,
        reserve_balance: Balance<SUI>,
        investment_balance: Balance<SUI>,
        total_assets: u64,
        total_liabilities: u64,
        liquidity_ratio: u64,           // Current liquidity health
        investment_strategy: u8,        // 0=Conservative, 1=Moderate, 2=Aggressive
        auto_rebalance: bool,
        last_rebalance: u64,
    }

    /// Financial performance metrics
    public struct PerformanceMetrics has key, store {
        id: UID,
        period_start: u64,
        period_end: u64,
        total_revenue: u64,
        total_costs: u64,
        net_profit: u64,
        profit_margin: u64,             // Percentage
        roi: u64,                       // Return on investment
        delivery_count: u64,
        average_delivery_value: u64,
        customer_satisfaction: u64,     // 0-100 rating
        drone_utilization: u64,         // 0-100 utilization rate
    }

    // ==================== ERROR CODES ====================
    const E_INSUFFICIENT_BALANCE: u64 = 1;
    const E_INVALID_PRICING_MODEL: u64 = 2;
    const E_DISTRIBUTION_FAILED: u64 = 3;
    const E_MARKET_CLOSED: u64 = 4;
    const E_TREASURY_LOCKED: u64 = 5;

    // ==================== CONSTANTS ====================
    
    // Pricing algorithms
    const PRICING_FIXED: u8 = 0;
    const PRICING_DYNAMIC: u8 = 1;
    const PRICING_AUCTION: u8 = 2;
    const PRICING_AI: u8 = 3;

    // Pool types
    const POOL_DRONE: u8 = 0;
    const POOL_OWNER: u8 = 1;
    const POOL_PLATFORM: u8 = 2;
    const POOL_MAINTENANCE: u8 = 3;
    const POOL_INSURANCE: u8 = 4;

    // Market conditions
    const DEMAND_LOW: u8 = 0;
    const DEMAND_MEDIUM: u8 = 1;
    const DEMAND_HIGH: u8 = 2;
    const DEMAND_CRITICAL: u8 = 3;

    // Distribution types
    const DIST_PERFORMANCE: u8 = 0;
    const DIST_OWNERSHIP: u8 = 1;
    const DIST_MAINTENANCE: u8 = 2;
    const DIST_BONUS: u8 = 3;

    // Investment strategies
    const STRATEGY_CONSERVATIVE: u8 = 0;
    const STRATEGY_MODERATE: u8 = 1;
    const STRATEGY_AGGRESSIVE: u8 = 2;

    // ==================== INITIALIZATION ====================

    /// Create economic engine for testing
    #[test_only]
    public fun create_test_economic_engine(ctx: &mut TxContext): EconomicEngine {
        let market_conditions = MarketConditions {
            demand_level: DEMAND_MEDIUM,
            supply_level: 2,
            weather_impact: 0,
            traffic_density: 1,
            fuel_cost_index: 100,
            competition_factor: 100,
            seasonal_factor: 100,
            last_updated: 0,
        };

        EconomicEngine {
            id: object::new(ctx),
            total_network_revenue: 0,
            total_transactions: 0,
            active_pricing_models: vector::empty(),
            revenue_pools: vector::empty(),
            market_conditions,
            pricing_algorithm: PRICING_DYNAMIC,
            base_delivery_rate: 1000000000, // 1 SUI base rate
            surge_multiplier: 100,          // 1.0x multiplier
            network_efficiency_score: 100,
        }
    }

    /// Initialize the economic engine
    fun init(ctx: &mut TxContext) {
        let market_conditions = MarketConditions {
            demand_level: DEMAND_MEDIUM,
            supply_level: 2,
            weather_impact: 0,
            traffic_density: 1,
            fuel_cost_index: 100,
            competition_factor: 100,
            seasonal_factor: 100,
            last_updated: 0,
        };

        let engine = EconomicEngine {
            id: object::new(ctx),
            total_network_revenue: 0,
            total_transactions: 0,
            active_pricing_models: vector::empty(),
            revenue_pools: vector::empty(),
            market_conditions,
            pricing_algorithm: PRICING_DYNAMIC,
            base_delivery_rate: 1000000000, // 1 SUI base rate
            surge_multiplier: 100,          // 1.0x multiplier
            network_efficiency_score: 100,
        };
        transfer::share_object(engine);
    }

    // ==================== DYNAMIC PRICING ====================

    /// Create a new pricing model
    public fun create_pricing_model(
        model_name: String,
        base_rate: u64,
        distance_rate: u64,
        weight_rate: u64,
        urgency_multipliers: vector<u64>,
        ctx: &mut TxContext
    ): PricingModel {
        PricingModel {
            id: object::new(ctx),
            model_name,
            base_rate,
            distance_rate,
            weight_rate,
            urgency_multipliers,
            time_multipliers: vector[80, 90, 100, 110, 120, 130, 120, 110], // 24h multipliers
            weather_multipliers: vector[100, 120, 150, 180, 200], // Clear to storm
            demand_elasticity: 50,
            minimum_price: base_rate / 2,
            maximum_price: base_rate * 5,
            active: true,
        }
    }

    /// Calculate dynamic delivery price
    public fun calculate_delivery_price(
        engine: &EconomicEngine,
        pricing_model: &PricingModel,
        distance_km: u64,
        weight_grams: u64,
        urgency_level: u8,
        time_of_day: u8,
        weather_condition: u8,
        current_demand: u8
    ): u64 {
        if (!pricing_model.active) {
            return pricing_model.base_rate
        };

        // Base calculation
        let mut price = pricing_model.base_rate;
        
        // Distance component
        price = price + (distance_km * pricing_model.distance_rate);
        
        // Weight component
        price = price + (weight_grams * pricing_model.weight_rate / 1000); // Per kg
        
        // Urgency multiplier
        if ((urgency_level as u64) < vector::length(&pricing_model.urgency_multipliers)) {
            let urgency_mult = *vector::borrow(&pricing_model.urgency_multipliers, (urgency_level as u64));
            price = (price * urgency_mult) / 100;
        };
        
        // Time of day multiplier
        if ((time_of_day as u64) < vector::length(&pricing_model.time_multipliers)) {
            let time_mult = *vector::borrow(&pricing_model.time_multipliers, (time_of_day as u64));
            price = (price * time_mult) / 100;
        };
        
        // Weather multiplier
        if ((weather_condition as u64) < vector::length(&pricing_model.weather_multipliers)) {
            let weather_mult = *vector::borrow(&pricing_model.weather_multipliers, (weather_condition as u64));
            price = (price * weather_mult) / 100;
        };
        
        // Demand surge pricing
        let demand_multiplier = calculate_demand_multiplier(current_demand, pricing_model.demand_elasticity);
        price = (price * demand_multiplier) / 100;
        
        // Apply network surge multiplier
        price = (price * engine.surge_multiplier) / 100;
        
        // Enforce min/max bounds
        if (price < pricing_model.minimum_price) {
            pricing_model.minimum_price
        } else if (price > pricing_model.maximum_price) {
            pricing_model.maximum_price
        } else {
            price
        }
    }

    /// Calculate demand-based multiplier
    fun calculate_demand_multiplier(demand_level: u8, elasticity: u64): u64 {
        match (demand_level) {
            DEMAND_LOW => 80,      // 20% discount
            DEMAND_MEDIUM => 100,  // Normal price
            DEMAND_HIGH => 130,    // 30% surge
            DEMAND_CRITICAL => 200, // 100% surge
            _ => 100,
        }
    }

    /// Update market conditions
    public fun update_market_conditions(
        engine: &mut EconomicEngine,
        demand_level: u8,
        supply_level: u8,
        weather_impact: u8,
        traffic_density: u8,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        engine.market_conditions.demand_level = demand_level;
        engine.market_conditions.supply_level = supply_level;
        engine.market_conditions.weather_impact = weather_impact;
        engine.market_conditions.traffic_density = traffic_density;
        engine.market_conditions.last_updated = current_time;
        
        // Update surge multiplier based on supply/demand
        engine.surge_multiplier = calculate_surge_multiplier(demand_level, supply_level);
    }

    /// Calculate surge pricing multiplier
    fun calculate_surge_multiplier(demand: u8, supply: u8): u64 {
        // Simple supply/demand calculation
        let demand_score = (demand as u64) * 25; // 0-75
        let supply_score = (supply as u64) * 25; // 0-75
        
        if (demand_score > supply_score) {
            100 + (demand_score - supply_score) // Surge pricing
        } else {
            100 - ((supply_score - demand_score) / 2) // Discount pricing
        }
    }

    // ==================== REVENUE DISTRIBUTION ====================

    /// Create revenue pool
    public fun create_revenue_pool(
        pool_type: u8,
        distribution_rules: DistributionRules,
        distribution_frequency: u64,
        ctx: &mut TxContext
    ): RevenuePool {
        RevenuePool {
            id: object::new(ctx),
            pool_type,
            total_balance: balance::zero(),
            pending_distributions: vector::empty(),
            distribution_rules,
            last_distribution: 0,
            distribution_frequency,
        }
    }

    /// Add revenue to pool
    public fun add_revenue_to_pool(
        pool: &mut RevenuePool,
        payment: Coin<SUI>,
        recipient: address,
        distribution_type: u8,
        performance_score: u64,
        order_id: Option<ID>,
        clock: &Clock
    ) {
        let amount = coin::value(&payment);
        let current_time = clock::timestamp_ms(clock);
        
        // Add to pool balance
        balance::join(&mut pool.total_balance, coin::into_balance(payment));
        
        // Create pending distribution
        let distribution = PendingDistribution {
            recipient,
            amount,
            distribution_type,
            earned_timestamp: current_time,
            order_id,
            performance_score,
        };
        
        vector::push_back(&mut pool.pending_distributions, distribution);
    }

    /// Process revenue distributions
    public fun process_revenue_distributions(
        pool: &mut RevenuePool,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        // Check if distribution is due
        if (current_time - pool.last_distribution < pool.distribution_frequency) {
            return
        };
        
        // Process all pending distributions
        while (!vector::is_empty(&pool.pending_distributions)) {
            let distribution = vector::pop_back(&mut pool.pending_distributions);
            
            // Calculate final amount with performance bonus
            let final_amount = calculate_performance_adjusted_amount(
                distribution.amount,
                distribution.performance_score,
                &pool.distribution_rules
            );
            
            // Ensure sufficient balance
            if (balance::value(&pool.total_balance) >= final_amount) {
                let payout = coin::from_balance(
                    balance::split(&mut pool.total_balance, final_amount),
                    ctx
                );
                transfer::public_transfer(payout, distribution.recipient);
            };
        };
        
        pool.last_distribution = current_time;
    }

    /// Calculate performance-adjusted payout amount
    fun calculate_performance_adjusted_amount(
        base_amount: u64,
        performance_score: u64,
        rules: &DistributionRules
    ): u64 {
        let mut adjusted_amount = base_amount;
        
        // Apply performance bonus/penalty
        if (performance_score > 80) {
            // Bonus for high performance
            let bonus = (base_amount * (performance_score - 80)) / 100;
            adjusted_amount = adjusted_amount + bonus;
        } else if (performance_score < 60) {
            // Penalty for low performance
            let penalty = (base_amount * (60 - performance_score)) / 100;
            adjusted_amount = if (adjusted_amount > penalty) { 
                adjusted_amount - penalty 
            } else { 
                adjusted_amount / 2 
            };
        };
        
        // Ensure minimum payout
        if (adjusted_amount < rules.minimum_payout) {
            rules.minimum_payout
        } else {
            adjusted_amount
        }
    }

    // ==================== MARKET MAKING ====================

    /// Create market maker for region
    public fun create_market_maker(
        region: String,
        initial_price: u64,
        ctx: &mut TxContext
    ): MarketMaker {
        MarketMaker {
            id: object::new(ctx),
            region,
            order_book: vector::empty(),
            current_market_price: initial_price,
            price_history: vector::empty(),
            volume_24h: 0,
            volatility_index: 0,
            liquidity_score: 100,
        }
    }

    /// Add price order to market
    public fun add_market_order(
        market: &mut MarketMaker,
        order_id: ID,
        order_type: u8,
        price: u64,
        quantity: u64,
        expires_at: u64,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        let order = PriceOrder {
            order_id,
            order_type,
            price,
            quantity,
            timestamp: current_time,
            expires_at,
        };
        
        vector::push_back(&mut market.order_book, order);
        
        // Update market price based on new order
        update_market_price(market, price, quantity, current_time);
    }

    /// Update market price based on trading activity
    fun update_market_price(
        market: &mut MarketMaker,
        trade_price: u64,
        volume: u64,
        timestamp: u64
    ) {
        // Simple price update - weighted average
        let weight = if (volume > 10) { 20 } else { volume * 2 };
        let old_weight = 100 - weight;
        
        market.current_market_price = 
            (market.current_market_price * old_weight + trade_price * weight) / 100;
        
        // Add to price history
        let price_point = PricePoint {
            timestamp,
            price: trade_price,
            volume,
            market_conditions: 0, // Simplified
        };
        
        vector::push_back(&mut market.price_history, price_point);
        
        // Update 24h volume
        market.volume_24h = market.volume_24h + volume;
        
        // Calculate volatility (simplified)
        market.volatility_index = calculate_volatility(&market.price_history);
    }

    /// Calculate price volatility
    fun calculate_volatility(price_history: &vector<PricePoint>): u64 {
        let history_length = vector::length(price_history);
        if (history_length < 2) {
            return 0
        };
        
        // Simple volatility calculation - price range over time
        let recent_count = if (history_length > 10) { 10 } else { history_length };
        let mut min_price = 0;
        let mut max_price = 0;
        let mut i = history_length - recent_count;
        
        while (i < history_length) {
            let point = vector::borrow(price_history, i);
            if (min_price == 0 || point.price < min_price) {
                min_price = point.price;
            };
            if (point.price > max_price) {
                max_price = point.price;
            };
            i = i + 1;
        };
        
        if (min_price > 0) {
            ((max_price - min_price) * 100) / min_price // Percentage volatility
        } else {
            0
        }
    }

    // ==================== TREASURY MANAGEMENT ====================

    /// Create autonomous treasury
    public fun create_treasury(
        initial_balance: Coin<SUI>,
        investment_strategy: u8,
        ctx: &mut TxContext
    ): Treasury {
        let balance_amount = coin::value(&initial_balance);
        
        Treasury {
            id: object::new(ctx),
            operating_balance: coin::into_balance(initial_balance),
            reserve_balance: balance::zero(),
            investment_balance: balance::zero(),
            total_assets: balance_amount,
            total_liabilities: 0,
            liquidity_ratio: 100,
            investment_strategy,
            auto_rebalance: true,
            last_rebalance: 0,
        }
    }

    /// Rebalance treasury allocations
    public fun rebalance_treasury(
        treasury: &mut Treasury,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        if (!treasury.auto_rebalance) {
            return
        };
        
        let total_balance = balance::value(&treasury.operating_balance) +
                           balance::value(&treasury.reserve_balance) +
                           balance::value(&treasury.investment_balance);
        
        // Calculate target allocations based on strategy
        let (operating_target, reserve_target, investment_target) = match (treasury.investment_strategy) {
            STRATEGY_CONSERVATIVE => (60, 30, 10), // 60% operating, 30% reserve, 10% investment
            STRATEGY_MODERATE => (50, 25, 25),     // Balanced approach
            STRATEGY_AGGRESSIVE => (40, 20, 40),   // Higher investment allocation
            _ => (60, 30, 10),
        };
        
        // Rebalance (simplified - would need more complex logic for actual transfers)
        treasury.total_assets = total_balance;
        treasury.liquidity_ratio = calculate_liquidity_ratio(treasury);
        treasury.last_rebalance = current_time;
    }

    /// Calculate treasury liquidity ratio
    fun calculate_liquidity_ratio(treasury: &Treasury): u64 {
        let liquid_assets = balance::value(&treasury.operating_balance) +
                           balance::value(&treasury.reserve_balance);
        let total_assets = treasury.total_assets;
        
        if (total_assets > 0) {
            (liquid_assets * 100) / total_assets
        } else {
            0
        }
    }

    // ==================== PERFORMANCE METRICS ====================

    /// Create performance metrics tracker
    public fun create_performance_metrics(
        period_start: u64,
        period_end: u64,
        ctx: &mut TxContext
    ): PerformanceMetrics {
        PerformanceMetrics {
            id: object::new(ctx),
            period_start,
            period_end,
            total_revenue: 0,
            total_costs: 0,
            net_profit: 0,
            profit_margin: 0,
            roi: 0,
            delivery_count: 0,
            average_delivery_value: 0,
            customer_satisfaction: 100,
            drone_utilization: 0,
        }
    }

    /// Update performance metrics
    public fun update_performance_metrics(
        metrics: &mut PerformanceMetrics,
        revenue: u64,
        costs: u64,
        delivery_count: u64,
        satisfaction_score: u64
    ) {
        metrics.total_revenue = metrics.total_revenue + revenue;
        metrics.total_costs = metrics.total_costs + costs;
        metrics.net_profit = if (metrics.total_revenue > metrics.total_costs) {
            metrics.total_revenue - metrics.total_costs
        } else {
            0
        };
        
        metrics.delivery_count = metrics.delivery_count + delivery_count;
        
        if (metrics.total_revenue > 0) {
            metrics.profit_margin = (metrics.net_profit * 100) / metrics.total_revenue;
        };
        
        if (metrics.delivery_count > 0) {
            metrics.average_delivery_value = metrics.total_revenue / metrics.delivery_count;
        };
        
        // Update customer satisfaction (weighted average)
        metrics.customer_satisfaction = 
            (metrics.customer_satisfaction * 9 + satisfaction_score) / 10;
    }

    // ==================== CONSTRUCTOR FUNCTIONS ====================

    /// Create distribution rules
    public fun create_distribution_rules(
        drone_percentage: u64,
        owner_percentage: u64,
        platform_percentage: u64,
        maintenance_percentage: u64,
        insurance_percentage: u64,
        performance_bonus_pool: u64,
        minimum_payout: u64
    ): DistributionRules {
        DistributionRules {
            drone_percentage,
            owner_percentage,
            platform_percentage,
            maintenance_percentage,
            insurance_percentage,
            performance_bonus_pool,
            minimum_payout,
        }
    }

    // ==================== GETTER FUNCTIONS ====================

    public fun engine_total_revenue(engine: &EconomicEngine): u64 {
        engine.total_network_revenue
    }

    public fun engine_surge_multiplier(engine: &EconomicEngine): u64 {
        engine.surge_multiplier
    }

    public fun engine_efficiency_score(engine: &EconomicEngine): u64 {
        engine.network_efficiency_score
    }

    public fun pricing_model_base_rate(model: &PricingModel): u64 {
        model.base_rate
    }

    public fun pool_balance(pool: &RevenuePool): u64 {
        balance::value(&pool.total_balance)
    }

    public fun pool_pending_count(pool: &RevenuePool): u64 {
        vector::length(&pool.pending_distributions)
    }

    public fun market_current_price(market: &MarketMaker): u64 {
        market.current_market_price
    }

    public fun market_volatility(market: &MarketMaker): u64 {
        market.volatility_index
    }

    public fun treasury_total_assets(treasury: &Treasury): u64 {
        treasury.total_assets
    }

    public fun treasury_liquidity_ratio(treasury: &Treasury): u64 {
        treasury.liquidity_ratio
    }

    public fun metrics_profit_margin(metrics: &PerformanceMetrics): u64 {
        metrics.profit_margin
    }

    public fun metrics_roi(metrics: &PerformanceMetrics): u64 {
        metrics.roi
    }
} 