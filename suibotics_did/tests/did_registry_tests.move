#[test_only]
module suibotics_did::did_registry_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::tx_context::{Self, TxContext};
    use sui::object;
    use sui::dynamic_field;
    use std::option;
    use std::vector;
    
    use suibotics_did::did_registry::{Self, DIDRegistry};
    use suibotics_did::identity_types::{
        DIDInfo, KeyInfo, ServiceInfo,
        did_info_controller, key_info_pubkey, key_info_purpose, key_info_revoked,
        service_info_id, service_info_type, service_info_endpoint,
        e_name_already_exists, e_key_already_exists, e_key_not_found, e_invalid_controller
    };

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

    // Helper to convert b"string" to vector<u8>
    fun string_to_vector(s: vector<u8>): vector<u8> {
        s
    }

    #[test]
    fun test_register_did_success() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        // Initialize registry
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        // Get the shared registry
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Register a DID
        did_registry::register_did(
            &mut registry,
            b"alice_did",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::next_tx(&mut scenario, ALICE);
        
        // Verify the DIDInfo was created and transferred to Alice
        let did = ts::take_from_sender<DIDInfo>(&scenario);
        assert!(did_info_controller(&did) == ALICE, 0);
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }

    #[test]
    fun test_get_did_controller() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        // Initialize registry
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Register a DID
        did_registry::register_did(
            &mut registry,
            b"alice_did",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        // Test get_did_controller
        let mut controller_opt = did_registry::get_did_controller(&registry, b"alice_did");
        assert!(option::is_some(&controller_opt), 0);
        assert!(option::extract(&mut controller_opt) == ALICE, 1);
        
        // Test non-existent DID
        let no_controller = did_registry::get_did_controller(&registry, b"nonexistent");
        assert!(option::is_none(&no_controller), 2);
        
        ts::return_shared(registry);
        ts::end(scenario);
    }

    #[test, expected_failure(abort_code = 4)]
    fun test_register_did_name_already_exists() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Register first DID
        did_registry::register_did(
            &mut registry,
            b"alice_did",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::next_tx(&mut scenario, BOB);
        
        // Try to register with the same name - should fail
        did_registry::register_did(
            &mut registry,
            b"alice_did",
            dummy_pubkey_2(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::end(scenario);
    }

    #[test]
    fun test_add_key_success() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Register a DID
        did_registry::register_did(
            &mut registry,
            b"alice_did",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::next_tx(&mut scenario, ALICE);
        
        // Take the DID and add a new key
        let mut did = ts::take_from_sender<DIDInfo>(&scenario);
        
        did_registry::add_key(
            &mut did,
            b"key_1",
            dummy_pubkey_2(),
            b"assertion",
            ts::ctx(&mut scenario)
        );
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }

    #[test, expected_failure(abort_code = 1)]
    fun test_add_key_invalid_controller() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Register a DID as Alice
        did_registry::register_did(
            &mut registry,
            b"alice_did",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::next_tx(&mut scenario, BOB); // Switch to Bob
        
        // Try to add key as Bob - should fail
        let mut did = ts::take_from_address<DIDInfo>(&scenario, ALICE);
        
        did_registry::add_key(
            &mut did,
            b"key_1",
            dummy_pubkey_2(),
            b"assertion",
            ts::ctx(&mut scenario)
        );
        
        ts::return_to_address(ALICE, did);
        ts::end(scenario);
    }

    #[test, expected_failure(abort_code = 3)]
    fun test_add_key_already_exists() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Register a DID
        did_registry::register_did(
            &mut registry,
            b"alice_did",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut did = ts::take_from_sender<DIDInfo>(&scenario);
        
        // Add a key
        did_registry::add_key(
            &mut did,
            b"key_1",
            dummy_pubkey_2(),
            b"assertion",
            ts::ctx(&mut scenario)
        );
        
        // Try to add the same key ID again - should fail
        did_registry::add_key(
            &mut did,
            b"key_1",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }

    #[test]
    fun test_revoke_key_success() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Register a DID
        did_registry::register_did(
            &mut registry,
            b"alice_did",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut did = ts::take_from_sender<DIDInfo>(&scenario);
        
        // Add a key to revoke
        did_registry::add_key(
            &mut did,
            b"key_to_revoke",
            dummy_pubkey_2(),
            b"assertion",
            ts::ctx(&mut scenario)
        );
        
        // Revoke the key
        did_registry::revoke_key(
            &mut did,
            b"key_to_revoke",
            ts::ctx(&mut scenario)
        );
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }

    #[test, expected_failure(abort_code = 2)]
    fun test_revoke_key_not_found() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Register a DID
        did_registry::register_did(
            &mut registry,
            b"alice_did",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut did = ts::take_from_sender<DIDInfo>(&scenario);
        
        // Try to revoke a non-existent key - should fail
        did_registry::revoke_key(
            &mut did,
            b"nonexistent_key",
            ts::ctx(&mut scenario)
        );
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }

    #[test]
    fun test_add_service_success() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Register a DID
        did_registry::register_did(
            &mut registry,
            b"alice_did",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut did = ts::take_from_sender<DIDInfo>(&scenario);
        
        // Add a service endpoint
        did_registry::add_service(
            &mut did,
            b"mqtt_service",
            b"MQTTBroker",
            b"wss://mqtt.example.com:8883",
            ts::ctx(&mut scenario)
        );
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }

    #[test, expected_failure(abort_code = 1)]
    fun test_add_service_invalid_controller() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Register a DID as Alice
        did_registry::register_did(
            &mut registry,
            b"alice_did",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::next_tx(&mut scenario, BOB); // Switch to Bob
        
        // Try to add service as Bob - should fail
        let mut did = ts::take_from_address<DIDInfo>(&scenario, ALICE);
        
        did_registry::add_service(
            &mut did,
            b"mqtt_service",
            b"MQTTBroker",
            b"wss://mqtt.example.com:8883",
            ts::ctx(&mut scenario)
        );
        
        ts::return_to_address(ALICE, did);
        ts::end(scenario);
    }

    #[test]
    fun test_key_service_id_collision_prevention() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Register a DID
        did_registry::register_did(
            &mut registry,
            b"alice_did",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut did = ts::take_from_sender<DIDInfo>(&scenario);
        
        // Add a key with ID "endpoint1"
        did_registry::add_key(
            &mut did,
            b"endpoint1",
            dummy_pubkey_2(),
            b"assertion",
            ts::ctx(&mut scenario)
        );
        
        // Add a service with the same ID "endpoint1" - should NOT collide
        did_registry::add_service(
            &mut did,
            b"endpoint1",
            b"MQTTBroker",
            b"wss://mqtt.example.com:8883",
            ts::ctx(&mut scenario)
        );
        
        // Verify both exist and can be retrieved
        assert!(did_registry::has_key(&did, b"endpoint1"), 0);
        assert!(did_registry::has_service(&did, b"endpoint1"), 1);
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }
} 