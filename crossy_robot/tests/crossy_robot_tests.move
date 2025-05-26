/*
#[test_only]
module crossy_robot::crossy_robot_tests;
// uncomment this line to import the module
// use crossy_robot::crossy_robot;

const ENotImplemented: u64 = 0;

#[test]
fun test_crossy_robot() {
    // pass
}

#[test, expected_failure(abort_code = ::crossy_robot::crossy_robot_tests::ENotImplemented)]
fun test_crossy_robot_fail() {
    abort ENotImplemented
}
*/

#[test_only]
module crossy_robot::crossy_robot_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::test_utils;
    use crossy_robot::crossy_robot::{Self, Game};

    // Test addresses
    const USER: address = @0xa11ce;
    const ROBOT: address = @0xb0b;
    const GAME_COST: u64 = 50_000_000; // 0.05 SUI

    #[test]
    fun test_create_game_success() {
        let mut scenario = ts::begin(USER);
        let ctx = ts::ctx(&mut scenario);
        
        // Create clock
        let clock = clock::create_for_testing(ctx);
        
        // Create payment coin
        let payment = coin::mint_for_testing<SUI>(GAME_COST, ctx);
        
        // Create game
        let game = crossy_robot::create_game(payment, &clock, ctx);
        
        // Verify game state
        let (user, robot, status, _created_at) = crossy_robot::get_game_info(&game);
        assert!(user == USER, 0);
        assert!(option::is_none(&robot), 1);
        assert!(crossy_robot::is_waiting_for_robot(&game), 2);
        assert!(!crossy_robot::is_active(&game), 3);
        
        // Clean up
        test_utils::destroy(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_create_game_invalid_payment() {
        let mut scenario = ts::begin(USER);
        let ctx = ts::ctx(&mut scenario);
        
        let clock = clock::create_for_testing(ctx);
        let wrong_payment = coin::mint_for_testing<SUI>(GAME_COST + 1, ctx); // Wrong amount
        
        let game = crossy_robot::create_game(wrong_payment, &clock, ctx);
        
        test_utils::destroy(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_robot_connect_success() {
        let mut scenario = ts::begin(USER);
        let ctx = ts::ctx(&mut scenario);
        
        let clock = clock::create_for_testing(ctx);
        let payment = coin::mint_for_testing<SUI>(GAME_COST, ctx);
        let mut game = crossy_robot::create_game(payment, &clock, ctx);
        
        // Switch to robot
        ts::next_tx(&mut scenario, ROBOT);
        let ctx = ts::ctx(&mut scenario);
        
        // Robot connects
        let received_payment = crossy_robot::connect_robot(&mut game, &clock, ctx);
        
        // Verify game state
        let (user, robot_opt, status, _created_at) = crossy_robot::get_game_info(&game);
        assert!(user == USER, 0);
        assert!(option::is_some(&robot_opt), 1);
        assert!(*option::borrow(&robot_opt) == ROBOT, 2);
        assert!(crossy_robot::is_active(&game), 3);
        assert!(!crossy_robot::is_waiting_for_robot(&game), 4);
        
        // Verify payment received
        assert!(coin::value(&received_payment) == GAME_COST, 5);
        
        // Clean up
        coin::burn_for_testing(received_payment);
        test_utils::destroy(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_robot_connect_already_active() {
        let mut scenario = ts::begin(USER);
        let ctx = ts::ctx(&mut scenario);
        
        let clock = clock::create_for_testing(ctx);
        let payment = coin::mint_for_testing<SUI>(GAME_COST, ctx);
        let mut game = crossy_robot::create_game(payment, &clock, ctx);
        
        // First robot connects
        ts::next_tx(&mut scenario, ROBOT);
        let ctx = ts::ctx(&mut scenario);
        let payment1 = crossy_robot::connect_robot(&mut game, &clock, ctx);
        
        // Second robot tries to connect (should fail)
        ts::next_tx(&mut scenario, @0xc4a12);
        let ctx = ts::ctx(&mut scenario);
        let payment2 = crossy_robot::connect_robot(&mut game, &clock, ctx);
        
        // Clean up
        coin::burn_for_testing(payment1);
        coin::burn_for_testing(payment2);
        test_utils::destroy(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_move_robot_all_directions() {
        let mut scenario = ts::begin(USER);
        let ctx = ts::ctx(&mut scenario);
        
        let clock = clock::create_for_testing(ctx);
        let payment = coin::mint_for_testing<SUI>(GAME_COST, ctx);
        let mut game = crossy_robot::create_game(payment, &clock, ctx);
        
        // Robot connects
        ts::next_tx(&mut scenario, ROBOT);
        let ctx = ts::ctx(&mut scenario);
        let received_payment = crossy_robot::connect_robot(&mut game, &clock, ctx);
        
        // Test all movement directions
        ts::next_tx(&mut scenario, USER);
        let ctx = ts::ctx(&mut scenario);
        
        crossy_robot::move_robot(&game, 0, &clock, ctx); // up
        crossy_robot::move_robot(&game, 1, &clock, ctx); // down
        crossy_robot::move_robot(&game, 2, &clock, ctx); // left
        crossy_robot::move_robot(&game, 3, &clock, ctx); // right
        crossy_robot::move_robot(&game, 4, &clock, ctx); // up_right
        crossy_robot::move_robot(&game, 5, &clock, ctx); // up_left
        crossy_robot::move_robot(&game, 6, &clock, ctx); // down_left
        crossy_robot::move_robot(&game, 7, &clock, ctx); // down_right
        
        // Clean up
        coin::burn_for_testing(received_payment);
        test_utils::destroy(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 5)]
    fun test_move_robot_game_not_active() {
        let mut scenario = ts::begin(USER);
        let ctx = ts::ctx(&mut scenario);
        
        let clock = clock::create_for_testing(ctx);
        let payment = coin::mint_for_testing<SUI>(GAME_COST, ctx);
        let game = crossy_robot::create_game(payment, &clock, ctx);
        
        // Try to move without robot connected (should fail)
        crossy_robot::move_robot(&game, 0, &clock, ctx);
        
        test_utils::destroy(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 4)]
    fun test_move_robot_invalid_direction() {
        let mut scenario = ts::begin(USER);
        let ctx = ts::ctx(&mut scenario);
        
        let clock = clock::create_for_testing(ctx);
        let payment = coin::mint_for_testing<SUI>(GAME_COST, ctx);
        let mut game = crossy_robot::create_game(payment, &clock, ctx);
        
        // Robot connects
        ts::next_tx(&mut scenario, ROBOT);
        let ctx = ts::ctx(&mut scenario);
        let received_payment = crossy_robot::connect_robot(&mut game, &clock, ctx);
        
        // Try invalid direction (should fail)
        ts::next_tx(&mut scenario, USER);
        let ctx = ts::ctx(&mut scenario);
        crossy_robot::move_robot(&game, 8, &clock, ctx); // Invalid direction
        
        coin::burn_for_testing(received_payment);
        test_utils::destroy(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_direction_names() {
        // Test direction name function
        assert!(crossy_robot::get_direction_name(0) == b"up", 0);
        assert!(crossy_robot::get_direction_name(1) == b"down", 1);
        assert!(crossy_robot::get_direction_name(2) == b"left", 2);
        assert!(crossy_robot::get_direction_name(3) == b"right", 3);
        assert!(crossy_robot::get_direction_name(4) == b"up_right", 4);
        assert!(crossy_robot::get_direction_name(5) == b"up_left", 5);
        assert!(crossy_robot::get_direction_name(6) == b"down_left", 6);
        assert!(crossy_robot::get_direction_name(7) == b"down_right", 7);
        assert!(crossy_robot::get_direction_name(99) == b"invalid", 8);
    }
}
