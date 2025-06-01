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
        e_name_already_exists, e_key_already_exists, e_key_not_found, e_invalid_controller,
        // Import DID document structures for testing
        DIDDocumentData, did_document_verification_methods, did_document_services,
        did_document_authentication, verification_method_id, verification_method_revoked,
        service_data_id, service_data_type
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

    #[test]
    fun test_did_document_resolution() {
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
        
        // Add additional keys and services
        did_registry::add_key(
            &mut did,
            b"key_1",
            dummy_pubkey_2(),
            b"assertion",
            ts::ctx(&mut scenario)
        );
        
        did_registry::add_service(
            &mut did,
            b"mqtt_service",
            b"MQTTBroker",
            b"wss://mqtt.example.com:8883",
            ts::ctx(&mut scenario)
        );
        
        // Build DID document using the basic resolver
        let doc = did_registry::build_basic_did_document(&did, b"did:sui:alice");
        
        // Verify the DID document structure
        let verification_methods = did_document_verification_methods(&doc);
        let services = did_document_services(&doc);
        let authentication = did_document_authentication(&doc);
        
        // Should have 2 verification methods (key_0 and key_1)
        assert!(vector::length(verification_methods) == 2, 0);
        
        // Should have 1 service (mqtt_service)
        assert!(vector::length(services) == 1, 1);
        
        // Should have 1 authentication key (key_0 with authentication purpose)
        assert!(vector::length(authentication) == 1, 2);
        
        // Verify key_0 exists and is for authentication
        let vm0 = vector::borrow(verification_methods, 0);
        assert!(*verification_method_id(vm0) == b"key_0", 3);
        assert!(!verification_method_revoked(vm0), 4);
        
        // Verify service exists
        let svc0 = vector::borrow(services, 0);
        assert!(*service_data_id(svc0) == b"mqtt_service", 5);
        assert!(*service_data_type(svc0) == b"MQTTBroker", 6);
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }

    #[test]
    fun test_custom_did_document_resolution() {
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
        
        // Add custom keys and services
        did_registry::add_key(
            &mut did,
            b"custom_key",
            dummy_pubkey_2(),
            b"assertion",
            ts::ctx(&mut scenario)
        );
        
        did_registry::add_service(
            &mut did,
            b"custom_service",
            b"CustomAPI",
            b"https://api.example.com",
            ts::ctx(&mut scenario)
        );
        
        // Build DID document with specific key and service IDs
        let key_ids = vector[b"key_0", b"custom_key"];
        let service_ids = vector[b"custom_service"];
        
        let doc = did_registry::build_did_document(&did, b"did:sui:custom", key_ids, service_ids);
        
        // Verify the custom DID document
        let verification_methods = did_document_verification_methods(&doc);
        let services = did_document_services(&doc);
        
        // Should have 2 verification methods
        assert!(vector::length(verification_methods) == 2, 0);
        
        // Should have 1 service
        assert!(vector::length(services) == 1, 1);
        
        // Find the custom service
        let svc = vector::borrow(services, 0);
        assert!(*service_data_id(svc) == b"custom_service", 2);
        assert!(*service_data_type(svc) == b"CustomAPI", 3);
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }

    #[test]
    fun test_remove_service_success() {
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
        
        // Add a service to remove
        did_registry::add_service(
            &mut did,
            b"temp_service",
            b"TempAPI",
            b"https://temp.example.com",
            ts::ctx(&mut scenario)
        );
        
        // Verify service exists
        assert!(did_registry::has_service(&did, b"temp_service"), 0);
        
        // Remove the service
        did_registry::remove_service(
            &mut did,
            b"temp_service",
            ts::ctx(&mut scenario)
        );
        
        // Verify service no longer exists
        assert!(!did_registry::has_service(&did, b"temp_service"), 1);
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }

    #[test]
    fun test_update_service_success() {
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
        
        // Add a service to update
        did_registry::add_service(
            &mut did,
            b"api_service",
            b"OldAPI",
            b"https://old.example.com",
            ts::ctx(&mut scenario)
        );
        
        // Update the service
        did_registry::update_service(
            &mut did,
            b"api_service",
            b"NewAPI",
            b"https://new.example.com",
            ts::ctx(&mut scenario)
        );
        
        // Verify service was updated by checking it still exists
        assert!(did_registry::has_service(&did, b"api_service"), 0);
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }

    #[test]
    fun test_service_lifecycle_management() {
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
        
        // Test complete service lifecycle: add -> update -> remove
        
        // 1. Add service
        did_registry::add_service(
            &mut did,
            b"lifecycle_service",
            b"InitialAPI",
            b"https://initial.example.com",
            ts::ctx(&mut scenario)
        );
        
        assert!(did_registry::has_service(&did, b"lifecycle_service"), 0);
        
        // 2. Update service
        did_registry::update_service(
            &mut did,
            b"lifecycle_service",
            b"UpdatedAPI",
            b"https://updated.example.com",
            ts::ctx(&mut scenario)
        );
        
        assert!(did_registry::has_service(&did, b"lifecycle_service"), 1);
        
        // 3. Remove service
        did_registry::remove_service(
            &mut did,
            b"lifecycle_service",
            ts::ctx(&mut scenario)
        );
        
        assert!(!did_registry::has_service(&did, b"lifecycle_service"), 2);
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }
} 