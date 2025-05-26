/*
#[test_only]
module suibotics_did::suibotics_did_tests;
// uncomment this line to import the module
// use suibotics_did::suibotics_did;

const ENotImplemented: u64 = 0;

#[test]
fun test_suibotics_did() {
    // pass
}

#[test, expected_failure(abort_code = ::suibotics_did::suibotics_did_tests::ENotImplemented)]
fun test_suibotics_did_fail() {
    abort ENotImplemented
}
*/

#[test_only]
module suibotics_did::integration_tests {
    use sui::test_scenario::{Self as ts};
    use std::vector;
    
    use suibotics_did::did_registry::{Self, DIDRegistry};
    use suibotics_did::credential_registry;
    use suibotics_did::identity_types::{DIDInfo, CredentialInfo, did_info_controller};

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
    fun test_full_identity_workflow() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        // Initialize DID registry
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        // Get the shared registry
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Alice registers her DID
        did_registry::register_did(
            &mut registry,
            b"alice_identity",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::next_tx(&mut scenario, ALICE);
        
        // Verify Alice's DID was created
        let mut alice_did = ts::take_from_sender<DIDInfo>(&scenario);
        assert!(did_info_controller(&alice_did) == ALICE, 0);
        
        // Alice adds a new key to her DID
        did_registry::add_key(
            &mut alice_did,
            b"signing_key",
            dummy_pubkey(),
            b"assertion",
            ts::ctx(&mut scenario)
        );
        
        // Alice adds a service endpoint
        did_registry::add_service(
            &mut alice_did,
            b"iot_service",
            b"IoTDevice",
            b"mqtt://device.example.com:1883",
            ts::ctx(&mut scenario)
        );
        
        ts::return_to_sender(&scenario, alice_did);
        ts::next_tx(&mut scenario, ALICE);
        
        // Alice issues a credential to Bob
        credential_registry::issue_credential(
            BOB,
            b"DeviceCertificate",
            dummy_sha256_hash(),
            ts::ctx(&mut scenario)
        );
        
        ts::next_tx(&mut scenario, BOB);
        
        // Verify Bob received the credential
        let mut bobs_credential = ts::take_from_sender<CredentialInfo>(&scenario);
        assert!(credential_registry::get_subject(&bobs_credential) == BOB, 1);
        assert!(credential_registry::get_issuer(&bobs_credential) == ALICE, 2);
        assert!(!credential_registry::is_revoked(&bobs_credential), 3);
        
        ts::next_tx(&mut scenario, ALICE);
        
        // Alice later revokes the credential
        credential_registry::revoke_credential(&mut bobs_credential, ts::ctx(&mut scenario));
        
        // Verify the credential is now revoked
        assert!(credential_registry::is_revoked(&bobs_credential), 4);
        
        ts::return_to_address(BOB, bobs_credential);
        ts::end(scenario);
    }

    #[test]
    fun test_multi_party_scenario() {
        let mut scenario = ts::begin(ALICE);
        let ctx = ts::ctx(&mut scenario);
        
        // Initialize DID registry
        did_registry::test_init(ctx);
        ts::next_tx(&mut scenario, ALICE);
        
        let mut registry = ts::take_shared<DIDRegistry>(&scenario);
        
        // Alice registers her DID
        did_registry::register_did(
            &mut registry,
            b"alice_ca",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::next_tx(&mut scenario, BOB);
        
        // Bob registers his DID
        did_registry::register_did(
            &mut registry,
            b"bob_device",
            dummy_pubkey(),
            b"authentication",
            ts::ctx(&mut scenario)
        );
        
        ts::return_shared(registry);
        ts::next_tx(&mut scenario, ALICE);
        
        // Alice (acting as CA) issues multiple credentials to Bob
        credential_registry::issue_credential(
            BOB,
            b"FirmwareAttestation",
            dummy_sha256_hash(),
            ts::ctx(&mut scenario)
        );
        
        credential_registry::issue_credential(
            BOB,
            b"ManufacturerCert",
            dummy_sha256_hash(),
            ts::ctx(&mut scenario)
        );
        
        ts::next_tx(&mut scenario, BOB);
        
        // Bob should have received both credentials
        let cred1 = ts::take_from_sender<CredentialInfo>(&scenario);
        let cred2 = ts::take_from_sender<CredentialInfo>(&scenario);
        
        // Verify both credentials are from Alice to Bob
        assert!(credential_registry::get_issuer(&cred1) == ALICE, 0);
        assert!(credential_registry::get_issuer(&cred2) == ALICE, 1);
        assert!(credential_registry::get_subject(&cred1) == BOB, 2);
        assert!(credential_registry::get_subject(&cred2) == BOB, 3);
        
        // Verify they have different schemas
        assert!(credential_registry::get_schema(&cred1) != credential_registry::get_schema(&cred2), 4);
        
        ts::return_to_sender(&scenario, cred1);
        ts::return_to_sender(&scenario, cred2);
        ts::end(scenario);
    }
}
