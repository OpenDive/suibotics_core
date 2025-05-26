#[test_only]
module suibotics_core::simple_test {
    use sui::test_scenario::{Self as ts};
    use std::vector;
    
    use suibotics_core::did_registry::{Self, DIDRegistry};
    use suibotics_core::credential_registry;
    use suibotics_core::identity_types::{
        DIDInfo, CredentialInfo, did_info_controller,
        validate_address, validate_name, validate_public_key, validate_schema,
        validate_data_hash, validate_purpose, validate_endpoint, validate_key_id
    };

    // Test addresses
    const ALICE: address = @0xa11ce;
    const BOB: address = @0xb0b;

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

    // Test helper to create a dummy SHA-256 hash
    fun dummy_sha256_hash(): vector<u8> {
        let mut hash = vector::empty<u8>();
        let mut i = 0;
        while (i < 32) {
            vector::push_back(&mut hash, (i as u8));
            i = i + 1;
        };
        hash
    }

    #[test]
    fun test_basic_validation() {
        // Test address validation
        validate_address(ALICE);
        validate_address(BOB);
        
        // Test name validation
        validate_name(&b"alice_did");
        validate_name(&b"a");
        
        // Test public key validation
        validate_public_key(&dummy_pubkey());
        
        // Test schema validation
        validate_schema(&b"FirmwareCertV1");
        
        // Test data hash validation
        validate_data_hash(&dummy_sha256_hash());
        
        // Test purpose validation
        validate_purpose(&b"authentication");
        validate_purpose(&b"assertion");
        
        // Test endpoint validation
        validate_endpoint(&b"wss://mqtt.example.com:8883");
        
        // Test key ID validation
        validate_key_id(&b"key_1");
    }

    #[test]
    fun test_did_registration() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        // Initialize DID registry
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
    fun test_credential_issuance() {
        let mut scenario = ts::begin(ALICE);
        
        // Issue a credential from Alice to Bob
        credential_registry::issue_credential(
            BOB,
            b"FirmwareCertV1",
            dummy_sha256_hash(),
            ts::ctx(&mut scenario)
        );
        
        ts::next_tx(&mut scenario, BOB);
        
        // Verify the credential was transferred to Bob
        let cred = ts::take_from_sender<CredentialInfo>(&scenario);
        
        // Verify credential properties
        assert!(credential_registry::get_subject(&cred) == BOB, 0);
        assert!(credential_registry::get_issuer(&cred) == ALICE, 1);
        assert!(credential_registry::get_schema(&cred) == &b"FirmwareCertV1", 2);
        assert!(credential_registry::get_data_hash(&cred) == &dummy_sha256_hash(), 3);
        assert!(!credential_registry::is_revoked(&cred), 4);
        assert!(credential_registry::get_issued_at(&cred) > 0, 5);
        
        ts::return_to_sender(&scenario, cred);
        ts::end(scenario);
    }

    #[test]
    fun test_credential_revocation() {
        let mut scenario = ts::begin(ALICE);
        
        // Issue a credential
        credential_registry::issue_credential(
            BOB,
            b"TestCredential",
            dummy_sha256_hash(),
            ts::ctx(&mut scenario)
        );
        
        ts::next_tx(&mut scenario, BOB);
        let mut cred = ts::take_from_sender<CredentialInfo>(&scenario);
        
        // Verify it's not revoked initially
        assert!(!credential_registry::is_revoked(&cred), 0);
        
        ts::next_tx(&mut scenario, ALICE);
        
        // Revoke the credential (as the issuer)
        credential_registry::revoke_credential(&mut cred, ts::ctx(&mut scenario));
        
        // Verify it's now revoked
        assert!(credential_registry::is_revoked(&cred), 1);
        
        ts::return_to_address(BOB, cred);
        ts::end(scenario);
    }

    #[test]
    fun test_add_key_to_did() {
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
            dummy_pubkey(),
            b"assertion",
            ts::ctx(&mut scenario)
        );
        
        ts::return_to_sender(&scenario, did);
        ts::end(scenario);
    }

    #[test]
    fun test_add_service_to_did() {
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
} 