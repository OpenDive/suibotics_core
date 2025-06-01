#[test_only]
module suibotics_did::reverse_lookup_tests {
    use sui::test_scenario::{Self as ts};
    use std::vector;
    use std::option;
    
    use suibotics_did::did_registry::{Self, DIDRegistry, get_did_controller_by_name, get_dids_by_controller, 
        get_registry_stats, did_name_exists};
    use suibotics_did::identity_types::{DIDInfo, did_info_id};

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

    #[test]
    fun test_did_name_lookup() {
        let mut scenario = ts::begin(ALICE);

        // Create registry
        did_registry::test_init(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);

        // Register a DID
        did_registry::register_did(&mut registry, b"alice_device", dummy_pubkey(), b"authentication", ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);

        // Test name lookup
        let mut controller_opt = get_did_controller_by_name(&registry, b"alice_device");
        assert!(option::is_some(&controller_opt), 1);
        assert!(option::extract(&mut controller_opt) == ALICE, 2);

        // Test non-existent name
        let empty_opt = get_did_controller_by_name(&registry, b"nonexistent");
        assert!(option::is_none(&empty_opt), 3);

        // Test name existence check
        assert!(did_name_exists(&registry, b"alice_device"), 4);
        assert!(!did_name_exists(&registry, b"nonexistent"), 5);

        ts::return_shared(registry);
        ts::end(scenario);
    }

    #[test]
    fun test_controller_reverse_lookup() {
        let mut scenario = ts::begin(ALICE);

        // Create registry
        did_registry::test_init(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);

        // Register multiple DIDs for Alice
        did_registry::register_did(&mut registry, b"alice_device1", dummy_pubkey(), b"authentication", ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        did_registry::register_did(&mut registry, b"alice_device2", dummy_pubkey(), b"authentication", ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, BOB);
        
        // Register one DID for Bob
        did_registry::register_did(&mut registry, b"bob_device", dummy_pubkey(), b"authentication", ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);

        // Test controller reverse lookup
        let alice_dids = get_dids_by_controller(&registry, ALICE);
        assert!(vector::length(&alice_dids) == 2, 1);

        let bob_dids = get_dids_by_controller(&registry, BOB);
        assert!(vector::length(&bob_dids) == 1, 2);

        let charlie_dids = get_dids_by_controller(&registry, CHARLIE);
        assert!(vector::length(&charlie_dids) == 0, 3);

        ts::return_shared(registry);
        ts::end(scenario);
    }

    #[test]
    fun test_registry_statistics() {
        let mut scenario = ts::begin(ALICE);

        // Create registry
        did_registry::test_init(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);

        // Initially no DIDs
        assert!(get_registry_stats(&registry) == 0, 1);

        // Register first DID
        did_registry::register_did(&mut registry, b"alice_device", dummy_pubkey(), b"authentication", ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, BOB);
        
        assert!(get_registry_stats(&registry) == 1, 2);

        // Register second DID
        did_registry::register_did(&mut registry, b"bob_device", dummy_pubkey(), b"authentication", ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, ALICE);
        
        assert!(get_registry_stats(&registry) == 2, 3);

        ts::return_shared(registry);
        ts::end(scenario);
    }
} 