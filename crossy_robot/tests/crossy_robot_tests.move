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
    use sui::test_scenario::{Self as ts};
    use sui::coin;
    use sui::sui::SUI;
    use sui::clock;
    use crossy_robot::crossy_robot::{Self, Game};

    // Test addresses
    const USER: address = @0xa11ce;
    const ROBOT: address = @0xb0b;
    const GAME_COST: u64 = 50_000_000; // 0.05 SUI

    #[test]
    fun test_create_game_success() {
        let mut scenario = ts::begin(USER);
        
        // Create clock
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        
        // Create payment coin
        let payment = coin::mint_for_testing<SUI>(GAME_COST, ts::ctx(&mut scenario));
        
        // Create game
        crossy_robot::create_game(payment, &clock, ts::ctx(&mut scenario));
        
        // Move to next transaction to access shared object
        ts::next_tx(&mut scenario, USER);
        
        // Take the shared game object
        let game = ts::take_shared<Game>(&scenario);
        
        // Verify game state
        let (user, robot, _status, _created_at) = crossy_robot::get_game_info(&game);
        assert!(user == USER, 0);
        assert!(robot.is_none(), 1);
        assert!(crossy_robot::is_waiting_for_robot(&game), 2);
        assert!(!crossy_robot::is_active(&game), 3);
        
        // Return shared object
        ts::return_shared(game);
        
        // Clean up
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_create_game_invalid_payment() {
        let mut scenario = ts::begin(USER);
        
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let wrong_payment = coin::mint_for_testing<SUI>(GAME_COST + 1, ts::ctx(&mut scenario)); // Wrong amount
        
        crossy_robot::create_game(wrong_payment, &clock, ts::ctx(&mut scenario));
        
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_robot_connect_success() {
        let mut scenario = ts::begin(USER);
        
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let payment = coin::mint_for_testing<SUI>(GAME_COST, ts::ctx(&mut scenario));
        crossy_robot::create_game(payment, &clock, ts::ctx(&mut scenario));
        
        // Switch to robot
        ts::next_tx(&mut scenario, ROBOT);
        
        // Take the shared game object
        let mut game = ts::take_shared<Game>(&scenario);
        
        // Robot connects
        let received_payment = crossy_robot::connect_robot(&mut game, &clock, ts::ctx(&mut scenario));
        
        // Verify game state
        let (user, robot_opt, _status, _created_at) = crossy_robot::get_game_info(&game);
        assert!(user == USER, 0);
        assert!(robot_opt.is_some(), 1);
        assert!(*robot_opt.borrow() == ROBOT, 2);
        assert!(crossy_robot::is_active(&game), 3);
        assert!(!crossy_robot::is_waiting_for_robot(&game), 4);
        
        // Verify payment received
        assert!(coin::value(&received_payment) == GAME_COST, 5);
        
        // Clean up
        coin::burn_for_testing(received_payment);
        ts::return_shared(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_robot_connect_already_active() {
        let mut scenario = ts::begin(USER);
        
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let payment = coin::mint_for_testing<SUI>(GAME_COST, ts::ctx(&mut scenario));
        crossy_robot::create_game(payment, &clock, ts::ctx(&mut scenario));
        
        // First robot connects
        ts::next_tx(&mut scenario, ROBOT);
        let mut game = ts::take_shared<Game>(&scenario);
        let payment1 = crossy_robot::connect_robot(&mut game, &clock, ts::ctx(&mut scenario));
        ts::return_shared(game);
        
        // Second robot tries to connect (should fail)
        ts::next_tx(&mut scenario, @0xc4a12);
        let mut game = ts::take_shared<Game>(&scenario);
        let payment2 = crossy_robot::connect_robot(&mut game, &clock, ts::ctx(&mut scenario));
        
        // Clean up
        coin::burn_for_testing(payment1);
        coin::burn_for_testing(payment2);
        ts::return_shared(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_move_robot_all_directions() {
        let mut scenario = ts::begin(USER);
        
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let payment = coin::mint_for_testing<SUI>(GAME_COST, ts::ctx(&mut scenario));
        crossy_robot::create_game(payment, &clock, ts::ctx(&mut scenario));
        
        // Robot connects
        ts::next_tx(&mut scenario, ROBOT);
        let mut game = ts::take_shared<Game>(&scenario);
        let received_payment = crossy_robot::connect_robot(&mut game, &clock, ts::ctx(&mut scenario));
        ts::return_shared(game);
        
        // Test all movement directions
        ts::next_tx(&mut scenario, USER);
        let game = ts::take_shared<Game>(&scenario);
        
        crossy_robot::move_robot(&game, 0, &clock, ts::ctx(&mut scenario)); // up
        crossy_robot::move_robot(&game, 1, &clock, ts::ctx(&mut scenario)); // down
        crossy_robot::move_robot(&game, 2, &clock, ts::ctx(&mut scenario)); // left
        crossy_robot::move_robot(&game, 3, &clock, ts::ctx(&mut scenario)); // right
        crossy_robot::move_robot(&game, 4, &clock, ts::ctx(&mut scenario)); // up_right
        crossy_robot::move_robot(&game, 5, &clock, ts::ctx(&mut scenario)); // up_left
        crossy_robot::move_robot(&game, 6, &clock, ts::ctx(&mut scenario)); // down_left
        crossy_robot::move_robot(&game, 7, &clock, ts::ctx(&mut scenario)); // down_right
        
        // Clean up
        coin::burn_for_testing(received_payment);
        ts::return_shared(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 5)]
    fun test_move_robot_game_not_active() {
        let mut scenario = ts::begin(USER);
        
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let payment = coin::mint_for_testing<SUI>(GAME_COST, ts::ctx(&mut scenario));
        crossy_robot::create_game(payment, &clock, ts::ctx(&mut scenario));
        
        // Try to move without robot connected (should fail)
        ts::next_tx(&mut scenario, USER);
        let game = ts::take_shared<Game>(&scenario);
        crossy_robot::move_robot(&game, 0, &clock, ts::ctx(&mut scenario));
        
        ts::return_shared(game);
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 4)]
    fun test_move_robot_invalid_direction() {
        let mut scenario = ts::begin(USER);
        
        let clock = clock::create_for_testing(ts::ctx(&mut scenario));
        let payment = coin::mint_for_testing<SUI>(GAME_COST, ts::ctx(&mut scenario));
        crossy_robot::create_game(payment, &clock, ts::ctx(&mut scenario));
        
        // Robot connects
        ts::next_tx(&mut scenario, ROBOT);
        let mut game = ts::take_shared<Game>(&scenario);
        let received_payment = crossy_robot::connect_robot(&mut game, &clock, ts::ctx(&mut scenario));
        ts::return_shared(game);
        
        // Try invalid direction (should fail)
        ts::next_tx(&mut scenario, USER);
        let game = ts::take_shared<Game>(&scenario);
        crossy_robot::move_robot(&game, 8, &clock, ts::ctx(&mut scenario)); // Invalid direction
        
        coin::burn_for_testing(received_payment);
        ts::return_shared(game);
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
