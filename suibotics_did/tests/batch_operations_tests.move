#[test_only]
module suibotics_did::batch_operations_tests {
    use sui::test_scenario::{Self as ts};
    use std::vector;
    
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

    // Test helper to create a dummy data hash
    fun dummy_hash(): vector<u8> {
        let mut hash = vector::empty<u8>();
        let mut i = 0;
        while (i < 32) {
            vector::push_back(&mut hash, ((i + 100) as u8));
            i = i + 1;
        };
        hash
    }

    #[test]
    fun test_batch_did_registration_success() {
        let mut scenario = ts::begin(ALICE);
        
        // Create registry
        did_registry::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Prepare batch data for 3 DIDs
        let names = vector[b"device1", b"device2", b"device3"];
        let pubkeys = vector[dummy_pubkey(), dummy_pubkey(), dummy_pubkey()];
        let purposes = vector[b"auth", b"auth", b"auth"];
        
        // Register batch DIDs
        let results = did_registry::register_dids_batch(&mut registry, names, pubkeys, purposes, ts::ctx(&mut scenario));
        
        // Verify all succeeded
        assert!(vector::length(&results) == 3, 1);
        assert!(count_batch_successes(&results) == 3, 2);
        assert!(is_batch_fully_successful(&results), 3);
        assert!(vector::length(&get_batch_failures(&results)) == 0, 4);
        
        ts::return_shared(registry);
        ts::end(scenario);
    }

    #[test]
    fun test_batch_did_registration_partial_failure() {
        let mut scenario = ts::begin(ALICE);
        
        // Create registry
        did_registry::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Prepare batch data with one invalid pubkey (wrong length)
        let names = vector[b"device1", b"device2", b"device3"];
        let mut invalid_key = vector::empty<u8>();
        vector::push_back(&mut invalid_key, 1); // Only 1 byte instead of 32
        let pubkeys = vector[dummy_pubkey(), invalid_key, dummy_pubkey()];
        let purposes = vector[b"auth", b"auth", b"auth"];
        
        // Register batch DIDs
        let results = did_registry::register_dids_batch(&mut registry, names, pubkeys, purposes, ts::ctx(&mut scenario));
        
        // Verify partial success
        assert!(vector::length(&results) == 3, 1);
        assert!(count_batch_successes(&results) == 2, 2); // 2 succeeded, 1 failed
        assert!(!is_batch_fully_successful(&results), 3);
        assert!(vector::length(&get_batch_failures(&results)) == 1, 4);
        
        // Check failure is at index 1
        let failures = get_batch_failures(&results);
        assert!(*vector::borrow(&failures, 0) == 1, 5);
        
        ts::return_shared(registry);
        ts::end(scenario);
    }

    #[test]
    fun test_batch_credential_operations() {
        let mut scenario = ts::begin(ALICE);
        
        // Create registries
        did_registry::init_for_testing(ts::ctx(&mut scenario));
        credential_registry::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut cred_registry = ts::take_shared<CredentialRegistry>(&scenario);
        
        // Batch issue credentials
        let subjects = vector[BOB, CHARLIE, BOB];
        let issuers = vector[ALICE, ALICE, ALICE];
        let schemas = vector[b"FirmwareAttestation", b"DeviceCertificate", b"SecurityUpdate"];
        let data_hashes = vector[dummy_hash(), dummy_hash(), dummy_hash()];
        
        let results = credential_registry::issue_credentials_batch(&mut cred_registry, subjects, issuers, schemas, data_hashes, ts::ctx(&mut scenario));
        
        // Verify all credentials issued successfully
        assert!(vector::length(&results) == 3, 1);
        assert!(credential_registry::count_batch_successes(&results) == 3, 2);
        assert!(credential_registry::is_batch_fully_successful(&results), 3);
        
        // Verify registry count updated
        assert!(credential_registry::get_total_credentials(&cred_registry) == 3, 4);
        
        ts::return_shared(cred_registry);
        ts::end(scenario);
    }

    #[test]
    fun test_batch_credential_validation() {
        let mut scenario = ts::begin(ALICE);
        
        // Create registries
        credential_registry::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut cred_registry = ts::take_shared<CredentialRegistry>(&scenario);
        
        // Batch with invalid data (wrong hash length)
        let subjects = vector[BOB, CHARLIE];
        let issuers = vector[ALICE, ALICE];
        let schemas = vector[b"Valid", b"Valid"];
        let mut invalid_hash = vector::empty<u8>();
        vector::push_back(&mut invalid_hash, 1); // Only 1 byte instead of 32
        let data_hashes = vector[dummy_hash(), invalid_hash];
        
        let results = credential_registry::issue_credentials_batch(&mut cred_registry, subjects, issuers, schemas, data_hashes, ts::ctx(&mut scenario));
        
        // Verify partial success (first succeeds, second fails)
        assert!(vector::length(&results) == 2, 1);
        assert!(credential_registry::count_batch_successes(&results) == 1, 2);
        assert!(!credential_registry::is_batch_fully_successful(&results), 3);
        
        let failures = credential_registry::get_batch_failures(&results);
        assert!(vector::length(&failures) == 1, 4);
        assert!(*vector::borrow(&failures, 0) == 1, 5); // Second operation failed
        
        ts::return_shared(cred_registry);
        ts::end(scenario);
    }

    #[test, expected_failure(abort_code = 10)]
    fun test_batch_size_limit_exceeded() {
        let mut scenario = ts::begin(ALICE);
        
        // Create registry
        did_registry::init_for_testing(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Create batch that exceeds size limit (51 > 50)
        let mut large_names = vector::empty<vector<u8>>();
        let mut large_pubkeys = vector::empty<vector<u8>>();
        let mut large_purposes = vector::empty<vector<u8>>();
        
        let mut i = 0;
        while (i < 51) {
            vector::push_back(&mut large_names, b"device");
            vector::push_back(&mut large_pubkeys, dummy_pubkey());
            vector::push_back(&mut large_purposes, b"auth");
            i = i + 1;
        };
        
        // This should fail with E_BATCH_TOO_LARGE (abort code 10)
        did_registry::register_dids_batch(&mut registry, large_names, large_pubkeys, large_purposes, ts::ctx(&mut scenario));
        
        ts::return_shared(registry);
        ts::end(scenario);
    }

    #[test]
    fun test_batch_result_utilities() {
        // Test utility functions with sample results using helper function
        let mut results = vector::empty<BatchResult>();
        
        // Add some test results using the helper function
        vector::push_back(&mut results, new_batch_result(0, true, 0));
        vector::push_back(&mut results, new_batch_result(1, false, 5));
        vector::push_back(&mut results, new_batch_result(2, true, 0));
        vector::push_back(&mut results, new_batch_result(3, false, 7));
        
        // Test count successes
        assert!(count_batch_successes(&results) == 2, 1);
        
        // Test get failures
        let failures = get_batch_failures(&results);
        assert!(vector::length(&failures) == 2, 2);
        assert!(*vector::borrow(&failures, 0) == 1, 3);
        assert!(*vector::borrow(&failures, 1) == 3, 4);
        
        // Test not fully successful
        assert!(!is_batch_fully_successful(&results), 5);
        
        // Test fully successful case
        let mut all_success = vector::empty<BatchResult>();
        vector::push_back(&mut all_success, new_batch_result(0, true, 0));
        vector::push_back(&mut all_success, new_batch_result(1, true, 0));
        
        assert!(is_batch_fully_successful(&all_success), 6);
        assert!(count_batch_successes(&all_success) == 2, 7);
        assert!(vector::length(&get_batch_failures(&all_success)) == 0, 8);
    }
} 