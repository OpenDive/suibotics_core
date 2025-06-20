/// Module: crowd_robot
/// A crowd-controlled robot game where anyone can create free games and multiple players
/// can collaboratively control a physical robot in real-time for exactly 2 minutes.
/// 
/// Key Features:
/// - Free game creation (no payment required)
/// - Crowd-controlled gameplay (anyone can move the robot)
/// - Time-bounded games (exactly 2 minutes)
/// - Player tracking (records all participants)
/// - Real-time performance testing (no rate limiting)
/// - Precise timestamping for network analysis
module crossy_robot::crowd_robot {
    use sui::event;
    use sui::clock::{Self, Clock};

    // ===== Error Codes =====
    const E_GAME_ALREADY_ENDED: u64 = 1;
    const E_INVALID_DIRECTION: u64 = 2;
    const E_GAME_NOT_ACTIVE: u64 = 3;

    // ===== Constants =====
    
    /// Game duration in milliseconds (2 minutes)
    const GAME_DURATION_MS: u64 = 120_000; // 2 minutes = 120,000 milliseconds

    // ===== Movement Directions =====
    /// 8-directional movement system for robot control
    const MOVE_UP: u8 = 0;
    const MOVE_DOWN: u8 = 1;
    const MOVE_LEFT: u8 = 2;
    const MOVE_RIGHT: u8 = 3;
    const MOVE_UP_RIGHT: u8 = 4;
    const MOVE_UP_LEFT: u8 = 5;
    const MOVE_DOWN_LEFT: u8 = 6;
    const MOVE_DOWN_RIGHT: u8 = 7;

    // ===== Game Status =====
    /// Game lifecycle states
    const STATUS_WAITING: u8 = 0;    // Created, waiting for first move
    const STATUS_ACTIVE: u8 = 1;     // Accepting moves, robot monitoring
    const STATUS_ENDED: u8 = 2;      // Game completed (2 minutes elapsed)

    // ===== Structs =====

    /// Represents a crowd-controlled robot game session
    /// 
    /// Games are created as shared objects so any user can interact with them.
    /// Each game tracks its participants, timing, and statistics for analysis.
    public struct Game has key, store {
        id: UID,
        
        /// Address of the user who created the game
        creator: address,
        
        /// List of unique players who have submitted move commands
        /// Used for tracking participation and analytics
        players: vector<address>,
        
        /// Current game state (WAITING/ACTIVE/ENDED)
        status: u8,
        
        /// Timestamp when the game was created (milliseconds)
        created_at: u64,
        
        /// Calculated end time (created_at + GAME_DURATION_MS)
        /// Used for automatic game termination
        end_time: u64,
        
        /// Total number of move commands submitted
        /// Used for performance analysis and statistics
        total_moves: u64,
    }

    // ===== Events =====

    /// Emitted when a new game is created
    /// 
    /// Robots monitor for this event to begin listening for move commands
    public struct GameCreated has copy, drop {
        game_id: ID,
        creator: address,
        created_at: u64,
        end_time: u64,
    }

    /// Emitted when a player submits a move command
    /// 
    /// Physical robots listen for these events to execute movements in real-time
    public struct RobotMoved has copy, drop {
        game_id: ID,
        player: address,      // Who submitted the move command
        direction: u8,        // Movement direction (0-7)
        timestamp: u64,       // When the command was processed
        move_number: u64,     // Sequential move counter for ordering
        is_new_player: bool,  // True if this is the player's first move
    }

    /// Emitted when a game ends (2 minutes elapsed)
    /// 
    /// Provides statistics for performance analysis
    public struct GameEnded has copy, drop {
        game_id: ID,
        ended_at: u64,
        duration_ms: u64,
        total_moves: u64,
        unique_players: u64,
        creator: address,
    }

    // ===== Public Functions =====

    /// Create a new crowd-controlled robot game
    /// 
    /// Anyone can create a game for free. The game will automatically end after
    /// exactly 2 minutes, regardless of activity level.
    /// 
    /// @param clock - Sui clock object for timestamp precision
    /// @param ctx - Transaction context
    public fun create_game(
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let game_id = object::new(ctx);
        let id_copy = object::uid_to_inner(&game_id);
        let created_at = clock::timestamp_ms(clock);
        let end_time = created_at + GAME_DURATION_MS;

        let game = Game {
            id: game_id,
            creator: tx_context::sender(ctx),
            players: vector::empty<address>(),
            status: STATUS_WAITING,
            created_at,
            end_time,
            total_moves: 0,
        };

        // Emit event for robot monitoring
        event::emit(GameCreated {
            game_id: id_copy,
            creator: tx_context::sender(ctx),
            created_at,
            end_time,
        });

        // Share the game object so anyone can interact with it
        transfer::share_object(game);
    }

    /// Submit a movement command for the robot
    /// 
    /// This function can be called by anyone to control the robot. The first move
    /// transitions the game from WAITING to ACTIVE status. The game automatically
    /// ends after 2 minutes regardless of activity.
    /// 
    /// No rate limiting or spam prevention - designed for network stress testing.
    /// 
    /// @param game - Shared game object to move robot in
    /// @param direction - Movement direction (0-7)
    /// @param clock - Sui clock object for timestamp precision
    /// @param ctx - Transaction context
    public fun move_robot(
        game: &mut Game,
        direction: u8,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        let player = tx_context::sender(ctx);
        
        // Check if game has expired and auto-end if needed
        if (current_time >= game.end_time && game.status != STATUS_ENDED) {
            end_game_internal(game, current_time);
            return
        };
        
        // Validate game is still active
        assert!(game.status != STATUS_ENDED, E_GAME_ALREADY_ENDED);
        
        // Validate direction is within valid range
        assert!(direction <= MOVE_DOWN_RIGHT, E_INVALID_DIRECTION);

        // Activate game on first move
        if (game.status == STATUS_WAITING) {
            game.status = STATUS_ACTIVE;
        };

        // Track if this is a new player
        let is_new_player = !vector::contains(&game.players, &player);
        if (is_new_player) {
            vector::push_back(&mut game.players, player);
        };

        // Increment move counter
        game.total_moves = game.total_moves + 1;

        // Emit movement event for robot execution
        event::emit(RobotMoved {
            game_id: object::uid_to_inner(&game.id),
            player,
            direction,
            timestamp: current_time,
            move_number: game.total_moves,
            is_new_player,
        });

        // Check if game should end after this move
        if (current_time >= game.end_time) {
            end_game_internal(game, current_time);
        };
    }

    /// Manually end a game (callable by anyone after 2 minutes)
    /// 
    /// While games auto-end when moves are submitted after expiration,
    /// this function allows manual cleanup of expired games.
    /// 
    /// @param game - Game to end
    /// @param clock - Clock for timestamp
    public fun end_game(
        game: &mut Game,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        // Only allow ending if game has actually expired
        assert!(current_time >= game.end_time, E_GAME_NOT_ACTIVE);
        
        // Only end if not already ended
        if (game.status != STATUS_ENDED) {
            end_game_internal(game, current_time);
        };
    }

    // ===== Private Functions =====

    /// Internal function to handle game ending logic
    /// 
    /// Centralizes the game ending logic to ensure consistency
    /// whether the game ends automatically or manually.
    fun end_game_internal(game: &mut Game, ended_at: u64) {
        game.status = STATUS_ENDED;
        
        let duration = ended_at - game.created_at;
        let unique_players = vector::length(&game.players);

        // Emit game ended event with statistics
        event::emit(GameEnded {
            game_id: object::uid_to_inner(&game.id),
            ended_at,
            duration_ms: duration,
            total_moves: game.total_moves,
            unique_players,
            creator: game.creator,
        });
    }

    // ===== View Functions =====

    /// Get comprehensive game information
    /// 
    /// Returns all game state for frontend display and analytics
    public fun get_game_info(game: &Game): (
        address,              // creator
        vector<address>,      // players
        u8,                   // status
        u64,                  // created_at
        u64,                  // end_time
        u64                   // total_moves
    ) {
        (
            game.creator,
            game.players,
            game.status,
            game.created_at,
            game.end_time,
            game.total_moves
        )
    }

    /// Check if game is waiting for first move
    public fun is_waiting(game: &Game): bool {
        game.status == STATUS_WAITING
    }

    /// Check if game is actively accepting moves
    public fun is_active(game: &Game): bool {
        game.status == STATUS_ACTIVE
    }

    /// Check if game has ended
    public fun is_ended(game: &Game): bool {
        game.status == STATUS_ENDED
    }

    /// Check if game has expired based on current time
    /// 
    /// Useful for frontends to determine if a game should be considered ended
    /// even if the status hasn't been updated yet.
    public fun has_expired(game: &Game, clock: &Clock): bool {
        clock::timestamp_ms(clock) >= game.end_time
    }

    /// Get time remaining in game (in milliseconds)
    /// 
    /// Returns 0 if game has expired
    public fun time_remaining(game: &Game, clock: &Clock): u64 {
        let current_time = clock::timestamp_ms(clock);
        if (current_time >= game.end_time) {
            0
        } else {
            game.end_time - current_time
        }
    }

    /// Get number of unique players who have participated
    public fun get_player_count(game: &Game): u64 {
        vector::length(&game.players)
    }

    /// Check if a specific address has participated in the game
    public fun has_player_participated(game: &Game, player: address): bool {
        vector::contains(&game.players, &player)
    }

    /// Get movement direction name for debugging/display
    /// 
    /// Converts direction code to human-readable string
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

    /// Get game duration constant (for frontend reference)
    public fun get_game_duration(): u64 {
        GAME_DURATION_MS
    }

    // ===== Test Functions =====
    
    #[test_only]
    public fun test_init(_ctx: &mut TxContext) {
        // Test initialization function
    }
} 