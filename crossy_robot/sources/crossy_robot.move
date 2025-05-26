/// Module: crossy_robot
/// A simple robot control game where users pay to control physical robots
module crossy_robot::crossy_robot {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::event;
    use sui::clock::{Self, Clock};
    use std::option::{Self, Option};

    // ===== Error Codes =====
    const E_GAME_NOT_WAITING: u64 = 1;
    const E_GAME_ALREADY_ACTIVE: u64 = 2;
    const E_INVALID_PAYMENT: u64 = 3;
    const E_INVALID_DIRECTION: u64 = 4;
    const E_GAME_NOT_ACTIVE: u64 = 5;

    // ===== Constants =====
    const GAME_COST: u64 = 50_000_000; // 0.05 SUI in MIST

    // ===== Movement Directions =====
    const MOVE_UP: u8 = 0;
    const MOVE_DOWN: u8 = 1;
    const MOVE_LEFT: u8 = 2;
    const MOVE_RIGHT: u8 = 3;
    const MOVE_UP_RIGHT: u8 = 4;
    const MOVE_UP_LEFT: u8 = 5;
    const MOVE_DOWN_LEFT: u8 = 6;
    const MOVE_DOWN_RIGHT: u8 = 7;

    // ===== Game Status =====
    const STATUS_WAITING_FOR_ROBOT: u8 = 0;
    const STATUS_ACTIVE: u8 = 1;
    // TODO: Add STATUS_COMPLETED for game end conditions

    // ===== Structs =====

    /// Represents a game session
    public struct Game has key, store {
        id: UID,
        user: address,           // User who created the game
        robot: Option<address>,  // Robot that connected (None if waiting)
        status: u8,             // Game status
        payment: Option<Coin<SUI>>, // Payment held until robot connects
        created_at: u64,        // Timestamp when game was created
    }

    // ===== Events =====

    /// Emitted when a new game is created
    public struct GameCreated has copy, drop {
        game_id: ID,
        user: address,
        payment_amount: u64,
        timestamp: u64,
    }

    /// Emitted when a robot connects to a game
    public struct RobotConnected has copy, drop {
        game_id: ID,
        robot: address,
        timestamp: u64,
    }

    /// Emitted when a robot moves
    public struct RobotMoved has copy, drop {
        game_id: ID,
        direction: u8,
        timestamp: u64,
    }

    // ===== Public Functions =====

    /// Create a new game with payment
    public fun create_game(
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Game {
        // Validate payment amount
        assert!(coin::value(&payment) == GAME_COST, E_INVALID_PAYMENT);

        let game_id = object::new(ctx);
        let id_copy = object::uid_to_inner(&game_id);
        let timestamp = clock::timestamp_ms(clock);

        let game = Game {
            id: game_id,
            user: tx_context::sender(ctx),
            robot: option::none(),
            status: STATUS_WAITING_FOR_ROBOT,
            payment: option::some(payment),
            created_at: timestamp,
        };

        // Emit game created event
        event::emit(GameCreated {
            game_id: id_copy,
            user: tx_context::sender(ctx),
            payment_amount: GAME_COST,
            timestamp,
        });

        game
    }

    /// Robot connects to a game and receives payment
    public fun connect_robot(
        game: &mut Game,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<SUI> {
        // Validate game is waiting for robot
        assert!(game.status == STATUS_WAITING_FOR_ROBOT, E_GAME_NOT_WAITING);
        assert!(option::is_none(&game.robot), E_GAME_ALREADY_ACTIVE);

        // Update game state
        game.robot = option::some(tx_context::sender(ctx));
        game.status = STATUS_ACTIVE;

        // Extract payment for robot
        let payment = option::extract(&mut game.payment);
        let timestamp = clock::timestamp_ms(clock);

        // Emit robot connected event
        event::emit(RobotConnected {
            game_id: object::uid_to_inner(&game.id),
            robot: tx_context::sender(ctx),
            timestamp,
        });

        payment
    }

    /// Move the robot in specified direction
    public fun move_robot(
        game: &Game,
        direction: u8,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        // Validate game is active
        assert!(game.status == STATUS_ACTIVE, E_GAME_NOT_ACTIVE);
        
        // Validate direction
        assert!(direction <= MOVE_DOWN_RIGHT, E_INVALID_DIRECTION);

        let timestamp = clock::timestamp_ms(clock);

        // Emit robot moved event
        event::emit(RobotMoved {
            game_id: object::uid_to_inner(&game.id),
            direction,
            timestamp,
        });

        // TODO: Add position tracking for game state validation
        // TODO: Implement rate limiting for movement frequency
        // TODO: Validate moves are from game creator only
        // TODO: Add bounds checking for robot position
    }

    // ===== View Functions =====

    /// Get game information
    public fun get_game_info(game: &Game): (address, Option<address>, u8, u64) {
        (game.user, game.robot, game.status, game.created_at)
    }

    /// Check if game is waiting for robot
    public fun is_waiting_for_robot(game: &Game): bool {
        game.status == STATUS_WAITING_FOR_ROBOT
    }

    /// Check if game is active
    public fun is_active(game: &Game): bool {
        game.status == STATUS_ACTIVE
    }

    /// Get movement direction name (for debugging/frontend)
    public fun get_direction_name(direction: u8): vector<u8> {
        if (direction == MOVE_UP) b"up"
        else if (direction == MOVE_DOWN) b"down"
        else if (direction == MOVE_LEFT) b"left"
        else if (direction == MOVE_RIGHT) b"right"
        else if (direction == MOVE_UP_RIGHT) b"up_right"
        else if (direction == MOVE_UP_LEFT) b"up_left"
        else if (direction == MOVE_DOWN_LEFT) b"down_left"
        else if (direction == MOVE_DOWN_RIGHT) b"down_right"
        else b"invalid"
    }

    // ===== Test Functions =====
    
    #[test_only]
    use sui::test_scenario;
    #[test_only]
    use sui::test_utils;

    #[test_only]
    public fun test_init(_ctx: &mut TxContext) {
        // Test initialization function
    }

    // TODO: Implement game end conditions and scoring
    // TODO: Add payment escrow and platform fee system
    // TODO: Integrate with DID system for robot authentication
    // TODO: Add reputation system for robots
    // TODO: Implement multi-robot game support
    // TODO: Add game session timeout functionality
    // TODO: Implement pause/resume game functionality
}


