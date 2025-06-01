#[test_only]
module suibotics_did::batch_operations_tests {
    use sui::test_scenario::{Self as ts};
    
    use suibotics_did::did_registry::{Self, DIDRegistry, BatchResult, count_batch_successes, get_batch_failures, is_batch_fully_successful, new_batch_result};
    use suibotics_did::credential_registry::{Self, CredentialRegistry};

    // Test addresses
    const ALICE: address = @0xa11ce;
    const BOB: address = @0xb0b;
    const CHARLIE: address = @0xc4a12;

    // Test helper to create a dummy public key
    fun dummy_pubkey(): vector<u8> {
        let mut key = vector::empty<u8>();
        let mut i = 0;
        while (i < 32) {
            vector::push_back(&mut key, (i as u8));
            i = i + 1;
        };
        key
    }

    // Test helper to create another dummy public key  
    fun dummy_pubkey_2(): vector<u8> {
        let mut key = vector::empty<u8>();
        let mut i = 0;
        while (i < 32) {
            vector::push_back(&mut key, ((i + 100) as u8));
            i = i + 1;
        };
        key
    }

    // Test helper to create a dummy data hash
    fun dummy_hash(): vector<u8> {
        let mut hash = vector::empty<u8>();
        let mut i = 0;
        while (i < 32) {
            vector::push_back(&mut hash, ((i * 2) as u8));
            i = i + 1;
        };
        hash
    }

    #[test]
    fun test_batch_did_registration() {
        let mut scenario = ts::begin(ALICE);
        
        // Create registry
        did_registry::test_init(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Prepare batch data
        let names = vector[b"device_001", b"device_002", b"device_003"];
        let pubkeys = vector[dummy_pubkey(), dummy_pubkey_2(), dummy_pubkey()];
        let purposes = vector[b"authentication", b"assertion", b"keyAgreement"];
        
        // Execute batch registration
        let results = did_registry::register_dids_batch(
            &mut registry,
            names,
            pubkeys,
            purposes,
            ts::ctx(&mut scenario)
        );
        
        // Verify all operations succeeded
        assert!(vector::length(&results) == 3, 1);
        assert!(is_batch_fully_successful(&results), 2);
        assert!(count_batch_successes(&results) == 3, 3);
        
        let failures = get_batch_failures(&results);
        assert!(vector::length(&failures) == 0, 4);
        
        ts::return_shared(registry);
        ts::end(scenario);
    }

    #[test]
    fun test_batch_credential_issuance() {
        let mut scenario = ts::begin(ALICE);
        
        // Create credential registry
        credential_registry::test_init(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut cred_registry = ts::take_shared<CredentialRegistry>(&scenario);
        
        // Prepare batch credential data
        let subjects = vector[BOB, CHARLIE, ALICE];
        let issuers = vector[ALICE, ALICE, ALICE]; // Alice issues to all
        let schemas = vector[b"DeviceCert", b"FirmwareAttest", b"ServiceAuth"];
        let hashes = vector[dummy_hash(), dummy_hash(), dummy_hash()];
        
        // Execute batch credential issuance
        let results = credential_registry::issue_credentials_batch(
            &mut cred_registry,
            subjects,
            issuers,
            schemas,
            hashes,
            ts::ctx(&mut scenario)
        );
        
        // Verify all operations succeeded
        assert!(vector::length(&results) == 3, 1);
        assert!(credential_registry::is_batch_fully_successful(&results), 2);
        assert!(credential_registry::count_batch_successes(&results) == 3, 3);
        
        ts::return_shared(cred_registry);
        ts::end(scenario);
    }

    #[test]
    fun test_batch_key_operations() {
        let mut scenario = ts::begin(ALICE);
        
        // Create registry and register some DIDs first
        did_registry::test_init(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Register DIDs first
        let names = vector[b"device_a", b"device_b"];
        let pubkeys = vector[dummy_pubkey(), dummy_pubkey_2()];
        let purposes = vector[b"authentication", b"authentication"];
        
        let _reg_results = did_registry::register_dids_batch(
            &mut registry,
            names,
            pubkeys,
            purposes,
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::next_tx(&mut scenario, ALICE);
        
        // Get the DIDs that were created
        let did_a = ts::take_from_sender(&scenario);
        let did_b = ts::take_from_sender(&scenario);
        let mut dids = vector[did_a, did_b];
        
        // Add keys in batch
        let key_ids = vector[b"signing_key", b"signing_key"];
        let new_pubkeys = vector[dummy_pubkey_2(), dummy_pubkey()];
        let key_purposes = vector[b"assertion", b"assertion"];
        
        let add_results = did_registry::add_keys_batch(
            &mut dids,
            key_ids,
            new_pubkeys,
            key_purposes,
            ts::ctx(&mut scenario)
        );
        
        // Verify key addition succeeded
        assert!(vector::length(&add_results) == 2, 1);
        assert!(is_batch_fully_successful(&add_results), 2);
        
        // Revoke keys in batch
        let revoke_key_ids = vector[b"signing_key", b"signing_key"];
        let revoke_results = did_registry::revoke_keys_batch(
            &mut dids,
            revoke_key_ids,
            ts::ctx(&mut scenario)
        );
        
        // Verify key revocation succeeded
        assert!(vector::length(&revoke_results) == 2, 3);
        assert!(is_batch_fully_successful(&revoke_results), 4);
        
        // Return DIDs
        let did_a = vector::pop_back(&mut dids);
        let did_b = vector::pop_back(&mut dids);
        ts::return_to_sender(&scenario, did_a);
        ts::return_to_sender(&scenario, did_b);
        vector::destroy_empty(dids);
        
        ts::end(scenario);
    }

    #[test, expected_failure(abort_code = 10)]
    fun test_batch_size_limit() {
        let mut scenario = ts::begin(ALICE);
        
        // Create registry
        did_registry::test_init(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Try to register 51 DIDs (exceeds limit of 50)
        let mut names = vector::empty<vector<u8>>();
        let mut pubkeys = vector::empty<vector<u8>>();
        let mut purposes = vector::empty<vector<u8>>();
        
        let mut i = 0;
        while (i < 51) {
            vector::push_back(&mut names, b"device");
            vector::push_back(&mut pubkeys, dummy_pubkey());
            vector::push_back(&mut purposes, b"authentication");
            i = i + 1;
        };
        
        // This should abort with error code 10 (batch too large)
        let _results = did_registry::register_dids_batch(
            &mut registry,
            names,
            pubkeys,
            purposes,
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::end(scenario);
    }

    #[test]
    fun test_batch_result_utilities() {
        // Create mixed results for testing utility functions
        let mut results = vector::empty<BatchResult>();
        vector::push_back(&mut results, new_batch_result(0, true, 0));
        vector::push_back(&mut results, new_batch_result(1, false, 5));
        vector::push_back(&mut results, new_batch_result(2, true, 0));
        vector::push_back(&mut results, new_batch_result(3, false, 7));
        
        // Test utility functions
        assert!(count_batch_successes(&results) == 2, 1);
        assert!(!is_batch_fully_successful(&results), 2);
        
        let failures = get_batch_failures(&results);
        assert!(vector::length(&failures) == 2, 3);
        assert!(*vector::borrow(&failures, 0) == 1, 4);
        assert!(*vector::borrow(&failures, 1) == 3, 5);
        
        // Test all success case
        let mut all_success = vector::empty<BatchResult>();
        vector::push_back(&mut all_success, new_batch_result(0, true, 0));
        vector::push_back(&mut all_success, new_batch_result(1, true, 0));
        
        assert!(count_batch_successes(&all_success) == 2, 6);
        assert!(is_batch_fully_successful(&all_success), 7);
        
        let no_failures = get_batch_failures(&all_success);
        assert!(vector::length(&no_failures) == 0, 8);
    }

    #[test]
    fun test_partial_success_handling() {
        let mut scenario = ts::begin(ALICE);
        
        // Create registry
        did_registry::test_init(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // First register one DID to create a name collision
        did_registry::register_did(
            &mut registry,
            b"device_001",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::next_tx(&mut scenario, ALICE);
        
        // Now try batch registration with duplicate name
        let names = vector[b"device_new", b"device_001", b"device_another"]; // device_001 already exists
        let pubkeys = vector[dummy_pubkey(), dummy_pubkey_2(), dummy_pubkey()];
        let purposes = vector[b"authentication", b"assertion", b"keyAgreement"];
        
        let results = did_registry::register_dids_batch(
            &mut registry,
            names,
            pubkeys,
            purposes,
            ts::ctx(&mut scenario)
        );
        
        // Should have partial success: operations 0 and 2 succeed, operation 1 fails
        assert!(vector::length(&results) == 3, 1);
        assert!(!is_batch_fully_successful(&results), 2);
        assert!(count_batch_successes(&results) == 2, 3);
        
        let failures = get_batch_failures(&results);
        assert!(vector::length(&failures) == 1, 4);
        assert!(*vector::borrow(&failures, 0) == 1, 5); // Index 1 failed (duplicate name)
        
        ts::return_shared(registry);
        ts::end(scenario);
    }
} 