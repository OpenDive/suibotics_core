module suibotics_core::identity_types {
    use sui::object::{UID, new};
    use sui::tx_context::TxContext;
    use sui::transfer::{transfer, public_transfer};

    /// A DID object resource. Owned by its controller.
    public struct DIDInfo has key {
        id: UID,
        controller: address,
        created_at: u64,        // timestamp in milliseconds
    }

    /// A verification method (public key) attached to a DIDInfo.
    public struct KeyInfo has store {
        pubkey: vector<u8>,     // raw Ed25519 public key bytes
        purpose: vector<u8>,    // e.g. b"authentication"
        revoked: bool,          // revocation flag
    }

    /// A service endpoint entry in a DID Document.
    public struct ServiceInfo has store {
        id: vector<u8>,         // fragment, e.g. b"mqtt1"
        type_: vector<u8>,      // e.g. b"MQTTBroker"
        endpoint: vector<u8>,   // e.g. b"wss://host:port"
    }

    /// An on-chain verifiable credential record.
    public struct CredentialInfo has key, store {
        id: UID,
        subject: address,       // Address of the subject DID controller
        issuer: address,        // controller address of the issuer DID
        schema: vector<u8>,     // e.g. b"FirmwareCertV1"
        data_hash: vector<u8>,  // SHA-256 hash of the off-chain VC JSON
        revoked: bool,          // revocation flag
        issued_at: u64,         // issuance timestamp
    }

    // Constructor functions for DIDInfo
    public fun new_did_info(controller: address, created_at: u64, ctx: &mut TxContext): DIDInfo {
        DIDInfo {
            id: new(ctx),
            controller,
            created_at,
        }
    }

    public fun transfer_did_info(did: DIDInfo, recipient: address) {
        transfer(did, recipient);
    }

    // Constructor functions for KeyInfo
    public fun new_key_info(pubkey: vector<u8>, purpose: vector<u8>): KeyInfo {
        KeyInfo {
            pubkey,
            purpose,
            revoked: false,
        }
    }

    // Constructor functions for ServiceInfo
    public fun new_service_info(id: vector<u8>, type_: vector<u8>, endpoint: vector<u8>): ServiceInfo {
        ServiceInfo {
            id,
            type_,
            endpoint,
        }
    }

    // Constructor functions for CredentialInfo
    public fun new_credential_info(
        subject: address,
        issuer: address,
        schema: vector<u8>,
        data_hash: vector<u8>,
        issued_at: u64,
        ctx: &mut TxContext
    ): CredentialInfo {
        CredentialInfo {
            id: new(ctx),
            subject,
            issuer,
            schema,
            data_hash,
            revoked: false,
            issued_at,
        }
    }

    public fun transfer_credential_info(cred: CredentialInfo, recipient: address) {
        public_transfer(cred, recipient);
    }

    // Accessor functions for DIDInfo
    public fun did_info_id(did: &DIDInfo): &UID {
        &did.id
    }

    public fun did_info_id_mut(did: &mut DIDInfo): &mut UID {
        &mut did.id
    }

    public fun did_info_controller(did: &DIDInfo): address {
        did.controller
    }

    public fun did_info_created_at(did: &DIDInfo): u64 {
        did.created_at
    }

    // Accessor and mutator functions for KeyInfo
    public fun key_info_pubkey(key: &KeyInfo): &vector<u8> {
        &key.pubkey
    }

    public fun key_info_purpose(key: &KeyInfo): &vector<u8> {
        &key.purpose
    }

    public fun key_info_revoked(key: &KeyInfo): bool {
        key.revoked
    }

    public fun revoke_key_info(key: &mut KeyInfo) {
        key.revoked = true;
    }

    // Accessor functions for ServiceInfo
    public fun service_info_id(svc: &ServiceInfo): &vector<u8> {
        &svc.id
    }

    public fun service_info_type(svc: &ServiceInfo): &vector<u8> {
        &svc.type_
    }

    public fun service_info_endpoint(svc: &ServiceInfo): &vector<u8> {
        &svc.endpoint
    }

    // Accessor and mutator functions for CredentialInfo
    public fun credential_info_subject(cred: &CredentialInfo): address {
        cred.subject
    }

    public fun credential_info_issuer(cred: &CredentialInfo): address {
        cred.issuer
    }

    public fun credential_info_schema(cred: &CredentialInfo): &vector<u8> {
        &cred.schema
    }

    public fun credential_info_data_hash(cred: &CredentialInfo): &vector<u8> {
        &cred.data_hash
    }

    public fun credential_info_revoked(cred: &CredentialInfo): bool {
        cred.revoked
    }

    public fun credential_info_issued_at(cred: &CredentialInfo): u64 {
        cred.issued_at
    }

    public fun revoke_credential_info(cred: &mut CredentialInfo) {
        cred.revoked = true;
    }
}