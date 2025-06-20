#[test_only]
module crossy_robot::crowd_robot_tests {
    use sui::test_scenario::{Self as ts};
    use sui::clock;
    use crossy_robot::crowd_robot::{Self, Game};

    // Test addresses
    const CREATOR: address = @0xa11ce;
    const PLAYER1: address = @0xb0b;
    const PLAYER2: address = @0xca51e;
    const PLAYER3: address = @0xdead;

    // Test constants
    const GAME_DURATION_MS: u64 = 120_000; // 2 minutes

    #[test]
    fun test_create_game_success() {
        let mut scenario = ts::begin(CREATOR);
        
        // Create clock at timestamp 1000
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000);
        
        // Create game
        crowd_robot::create_game(&clock, ts::ctx(&mut scenario));
        
        // Move to next transaction to access shared object
        ts::next_tx(&mut scenario, CREATOR);
        
        // Take the shared game object
        let game = ts::take_shared<Game>(&scenario);
        
        // Verify game state
        let (creator, players, status, created_at, end_time, total_moves) = 
            crowd_robot::get_game_info(&game);
        
        assert!(creator == CREATOR, 0);
        assert!(vector::length(&players) == 0, 1); // No players yet
        assert!(status == 0, 2); // STATUS_WAITING
        assert!(created_at == 1000, 3);
        assert!(end_time == 1000 + GAME_DURATION_MS, 4); // 2 minutes later
        assert!(total_moves == 0, 5);
        
        // Test view functions
        assert!(crowd_robot::is_waiting(&game), 6);
        assert!(!crowd_robot::is_active(&game), 7);
        assert!(!crowd_robot::is_ended(&game), 8);
        assert!(!crowd_robot::has_expired(&game, &clock), 9);
        assert!(crowd_robot::time_remaining(&game, &clock) == GAME_DURATION_MS, 10);
        assert!(crowd_robot::get_player_count(&game) == 0, 11);
        
        // Return shared object
        ts::return_shared(game);
        
        // Clean up
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_first_move_activates_game() {
        let mut scenario = ts::begin(CREATOR);
        
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000);
        
        // Create game
        crowd_robot::create_game(&clock, ts::ctx(&mut scenario));
        
        // First player makes a move
        ts::next_tx(&mut scenario, PLAYER1);
        clock::set_for_testing(&mut clock, 2000); // 1 second later
        
        let mut game = ts::take_shared<Game>(&scenario);
        crowd_robot::move_robot(&mut game, 0, &clock, ts::ctx(&mut scenario)); // UP
        
        // Verify game is now active
        let (creator, players, status, _created_at, _end_time, total_moves) = 
            crowd_robot::get_game_info(&game);
        
        assert!(creator == CREATOR, 0);
        assert!(vector::length(&players) == 1, 1); // One player now
        assert!(*vector::borrow(&players, 0) == PLAYER1, 2);
        assert!(status == 1, 3); // STATUS_ACTIVE
        assert!(total_moves == 1, 4);
        
        // Test view functions
        assert!(!crowd_robot::is_waiting(&game), 5);
        assert!(crowd_robot::is_active(&game), 6);
        assert!(!crowd_robot::is_ended(&game), 7);
        assert!(crowd_robot::has_player_participated(&game, PLAYER1), 8);
        assert!(!crowd_robot::has_player_participated(&game, PLAYER2), 9);
        
        ts::return_shared(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_crowd_control_multiple_players() {
        let mut scenario = ts::begin(CREATOR);
        
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000);
        
        // Create game
        crowd_robot::create_game(&clock, ts::ctx(&mut scenario));
        
        // Multiple players take turns
        ts::next_tx(&mut scenario, PLAYER1);
        clock::set_for_testing(&mut clock, 2000);
        let mut game = ts::take_shared<Game>(&scenario);
        crowd_robot::move_robot(&mut game, 0, &clock, ts::ctx(&mut scenario)); // UP
        ts::return_shared(game);
        
        ts::next_tx(&mut scenario, PLAYER2);
        clock::set_for_testing(&mut clock, 3000);
        let mut game = ts::take_shared<Game>(&scenario);
        crowd_robot::move_robot(&mut game, 1, &clock, ts::ctx(&mut scenario)); // DOWN
        ts::return_shared(game);
        
        ts::next_tx(&mut scenario, PLAYER3);
        clock::set_for_testing(&mut clock, 4000);
        let mut game = ts::take_shared<Game>(&scenario);
        crowd_robot::move_robot(&mut game, 2, &clock, ts::ctx(&mut scenario)); // LEFT
        ts::return_shared(game);
        
        // Player1 moves again
        ts::next_tx(&mut scenario, PLAYER1);
        clock::set_for_testing(&mut clock, 5000);
        let mut game = ts::take_shared<Game>(&scenario);
        crowd_robot::move_robot(&mut game, 3, &clock, ts::ctx(&mut scenario)); // RIGHT
        
        // Verify final state
        let (_creator, players, _status, _created_at, _end_time, total_moves) = 
            crowd_robot::get_game_info(&game);
        
        assert!(vector::length(&players) == 3, 0); // Three unique players
        assert!(total_moves == 4, 1); // Four total moves
        assert!(crowd_robot::get_player_count(&game) == 3, 2);
        
        // Verify all players are tracked
        assert!(crowd_robot::has_player_participated(&game, PLAYER1), 3);
        assert!(crowd_robot::has_player_participated(&game, PLAYER2), 4);
        assert!(crowd_robot::has_player_participated(&game, PLAYER3), 5);
        
        ts::return_shared(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_all_movement_directions() {
        let mut scenario = ts::begin(CREATOR);
        
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000);
        
        crowd_robot::create_game(&clock, ts::ctx(&mut scenario));
        
        ts::next_tx(&mut scenario, PLAYER1);
        let mut game = ts::take_shared<Game>(&scenario);
        
        // Test all 8 directions
        let directions = vector[0u8, 1u8, 2u8, 3u8, 4u8, 5u8, 6u8, 7u8];
        let mut i = 0;
        while (i < vector::length(&directions)) {
            let direction = *vector::borrow(&directions, i);
            clock::increment_for_testing(&mut clock, 1000);
            crowd_robot::move_robot(&mut game, direction, &clock, ts::ctx(&mut scenario));
            i = i + 1;
        };
        
        // Verify 8 moves were made
        let (_creator, _players, _status, _created_at, _end_time, total_moves) = 
            crowd_robot::get_game_info(&game);
        assert!(total_moves == 8, 0);
        
        ts::return_shared(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_game_expires_after_two_minutes() {
        let mut scenario = ts::begin(CREATOR);
        
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000);
        
        crowd_robot::create_game(&clock, ts::ctx(&mut scenario));
        
        // Make a move to activate the game
        ts::next_tx(&mut scenario, PLAYER1);
        clock::set_for_testing(&mut clock, 2000);
        let mut game = ts::take_shared<Game>(&scenario);
        crowd_robot::move_robot(&mut game, 0, &clock, ts::ctx(&mut scenario));
        
        // Advance time to just before expiration
        clock::set_for_testing(&mut clock, 1000 + GAME_DURATION_MS - 1);
        assert!(!crowd_robot::has_expired(&game, &clock), 0);
        assert!(crowd_robot::time_remaining(&game, &clock) == 1, 1);
        
        // Advance time to exactly expiration
        clock::set_for_testing(&mut clock, 1000 + GAME_DURATION_MS);
        assert!(crowd_robot::has_expired(&game, &clock), 2);
        assert!(crowd_robot::time_remaining(&game, &clock) == 0, 3);
        
        // Try to move after expiration - should auto-end the game
        crowd_robot::move_robot(&mut game, 1, &clock, ts::ctx(&mut scenario));
        
        // Game should now be ended
        assert!(crowd_robot::is_ended(&game), 4);
        assert!(!crowd_robot::is_active(&game), 5);
        
        ts::return_shared(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_manual_game_ending() {
        let mut scenario = ts::begin(CREATOR);
        
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000);
        
        crowd_robot::create_game(&clock, ts::ctx(&mut scenario));
        
        // Advance time past expiration
        ts::next_tx(&mut scenario, PLAYER1);
        clock::set_for_testing(&mut clock, 1000 + GAME_DURATION_MS + 1000);
        
        let mut game = ts::take_shared<Game>(&scenario);
        crowd_robot::end_game(&mut game, &clock, ts::ctx(&mut scenario));
        
        // Verify game is ended
        assert!(crowd_robot::is_ended(&game), 0);
        
        ts::return_shared(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = crowd_robot)]
    fun test_move_after_game_ended() {
        let mut scenario = ts::begin(CREATOR);
        
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000);
        
        crowd_robot::create_game(&clock, ts::ctx(&mut scenario));
        
        // End game manually
        ts::next_tx(&mut scenario, PLAYER1);
        clock::set_for_testing(&mut clock, 1000 + GAME_DURATION_MS + 1000);
        let mut game = ts::take_shared<Game>(&scenario);
        crowd_robot::end_game(&mut game, &clock, ts::ctx(&mut scenario));
        
        // Try to move after game ended (should fail)
        crowd_robot::move_robot(&mut game, 0, &clock, ts::ctx(&mut scenario));
        
        ts::return_shared(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = crowd_robot)]
    fun test_invalid_direction() {
        let mut scenario = ts::begin(CREATOR);
        
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000);
        
        crowd_robot::create_game(&clock, ts::ctx(&mut scenario));
        
        ts::next_tx(&mut scenario, PLAYER1);
        let mut game = ts::take_shared<Game>(&scenario);
        
        // Try invalid direction (8 is invalid, max is 7)
        crowd_robot::move_robot(&mut game, 8, &clock, ts::ctx(&mut scenario));
        
        ts::return_shared(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = crowd_robot)]
    fun test_end_game_before_expiration() {
        let mut scenario = ts::begin(CREATOR);
        
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
        clock::set_for_testing(&mut clock, 1000);
        
        crowd_robot::create_game(&clock, ts::ctx(&mut scenario));
        
        // Try to end game before expiration (should fail)
        ts::next_tx(&mut scenario, PLAYER1);
        clock::set_for_testing(&mut clock, 2000); // Only 1 second later
        let mut game = ts::take_shared<Game>(&scenario);
        crowd_robot::end_game(&mut game, &clock, ts::ctx(&mut scenario));
        
        ts::return_shared(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_direction_names() {
        // Test all direction name mappings
        assert!(crowd_robot::get_direction_name(0) == b"up", 0);
        assert!(crowd_robot::get_direction_name(1) == b"down", 1);
        assert!(crowd_robot::get_direction_name(2) == b"left", 2);
        assert!(crowd_robot::get_direction_name(3) == b"right", 3);
        assert!(crowd_robot::get_direction_name(4) == b"up_right", 4);
        assert!(crowd_robot::get_direction_name(5) == b"up_left", 5);
        assert!(crowd_robot::get_direction_name(6) == b"down_left", 6);
        assert!(crowd_robot::get_direction_name(7) == b"down_right", 7);
        assert!(crowd_robot::get_direction_name(99) == b"invalid", 8);
    }

    #[test]
    fun test_constants() {
        // Test that constants are accessible
        assert!(crowd_robot::get_game_duration() == 120_000, 0); // 2 minutes
    }
} 