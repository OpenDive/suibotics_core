module suibotics_did::identity_types {
    use sui::object::{new};
    use sui::transfer::{transfer, public_transfer};
    use sui::event;

    // === ERROR CONSTANTS (STANDARDIZED ACROSS ALL MODULES) ===

    // Core validation errors (1-9)
    const E_INVALID_CONTROLLER: u64 = 1;
    const E_KEY_NOT_FOUND: u64 = 2; 
    const E_KEY_ALREADY_EXISTS: u64 = 3;
    const E_NAME_ALREADY_EXISTS: u64 = 4;
    const E_INVALID_PUBLIC_KEY: u64 = 5;
    const E_INVALID_DATA_HASH: u64 = 6;
    const E_EMPTY_FIELD: u64 = 7;
    const E_FIELD_TOO_LONG: u64 = 8;
    const E_INVALID_ADDRESS: u64 = 9;

    // Batch operation errors (10-19)
    const E_BATCH_TOO_LARGE: u64 = 10;
    const E_BATCH_SIZE_MISMATCH: u64 = 11;
    const E_BATCH_EMPTY: u64 = 12;

    // Credential-specific errors (20-29)  
    const E_CREDENTIAL_NOT_FOUND: u64 = 20;
    const E_CREDENTIAL_ALREADY_REVOKED: u64 = 21;
    const E_UNAUTHORIZED_REVOCATION: u64 = 22;
    const E_INVALID_SCHEMA: u64 = 23;
    #[allow(unused_const)]
    const E_CREDENTIAL_EXPIRED: u64 = 24;

    // Service management errors (30-39)
    const E_SERVICE_NOT_FOUND: u64 = 30;
    const E_SERVICE_ALREADY_EXISTS: u64 = 31;
    #[allow(unused_const)]
    const E_INVALID_SERVICE_TYPE: u64 = 32;
    #[allow(unused_const)]
    const E_INVALID_ENDPOINT: u64 = 33;

    // Registry errors (40-49)
    #[allow(unused_const)]
    const E_REGISTRY_NOT_FOUND: u64 = 40;
    #[allow(unused_const)]
    const E_REGISTRY_FULL: u64 = 41;
    #[allow(unused_const)]
    const E_INDEX_CORRUPTED: u64 = 42;

    // Future expansion (50+)
    // Reserved for future error categories

    // === ERROR CODE ACCESSOR FUNCTIONS ===

    /// Get error code for invalid controller
    public fun e_invalid_controller(): u64 { E_INVALID_CONTROLLER }

    /// Get error code for key not found
    public fun e_key_not_found(): u64 { E_KEY_NOT_FOUND }

    /// Get error code for key already exists
    public fun e_key_already_exists(): u64 { E_KEY_ALREADY_EXISTS }

    /// Get error code for name already exists
    public fun e_name_already_exists(): u64 { E_NAME_ALREADY_EXISTS }

    /// Get error code for invalid public key
    public fun e_invalid_public_key(): u64 { E_INVALID_PUBLIC_KEY }

    /// Get error code for invalid data hash
    public fun e_invalid_data_hash(): u64 { E_INVALID_DATA_HASH }

    /// Get error code for empty field
    public fun e_empty_field(): u64 { E_EMPTY_FIELD }

    /// Get error code for field too long
    public fun e_field_too_long(): u64 { E_FIELD_TOO_LONG }

    /// Get error code for invalid address
    public fun e_invalid_address(): u64 { E_INVALID_ADDRESS }

    /// Get error code for batch too large
    public fun e_batch_too_large(): u64 { E_BATCH_TOO_LARGE }

    /// Get error code for batch size mismatch
    public fun e_batch_size_mismatch(): u64 { E_BATCH_SIZE_MISMATCH }

    /// Get error code for empty batch
    public fun e_batch_empty(): u64 { E_BATCH_EMPTY }

    /// Get error code for credential not found
    public fun e_credential_not_found(): u64 { E_CREDENTIAL_NOT_FOUND }

    /// Get error code for credential already revoked
    public fun e_credential_already_revoked(): u64 { E_CREDENTIAL_ALREADY_REVOKED }

    /// Get error code for unauthorized revocation
    public fun e_unauthorized_revocation(): u64 { E_UNAUTHORIZED_REVOCATION }

    /// Get error code for invalid schema
    public fun e_invalid_schema(): u64 { E_INVALID_SCHEMA }

    /// Get error code for service not found
    public fun e_service_not_found(): u64 { E_SERVICE_NOT_FOUND }

    /// Get error code for service already exists
    public fun e_service_already_exists(): u64 { E_SERVICE_ALREADY_EXISTS }

    // Constants for validation
    const ED25519_PUBLIC_KEY_LENGTH: u64 = 32;
    const SHA256_HASH_LENGTH: u64 = 32;
    const MAX_NAME_LENGTH: u64 = 255;
    const MAX_SCHEMA_LENGTH: u64 = 255;
    const MAX_ENDPOINT_LENGTH: u64 = 2000;

    // Batch operation constants
    const MAX_BATCH_SIZE: u64 = 50;

    // === BATCH OPERATION CONSTANTS ACCESSOR FUNCTIONS ===
    
    /// Get maximum batch size for operations
    public fun max_batch_size(): u64 { MAX_BATCH_SIZE }

    // Type-safe dynamic field keys to prevent collisions
    public struct KeyFieldKey has copy, drop, store {
        key_id: vector<u8>,
    }

    public struct ServiceFieldKey has copy, drop, store {
        service_id: vector<u8>,
    }

    // Constructor functions for field keys
    public fun new_key_field_key(key_id: vector<u8>): KeyFieldKey {
        KeyFieldKey { key_id }
    }

    public fun new_service_field_key(service_id: vector<u8>): ServiceFieldKey {
        ServiceFieldKey { service_id }
    }

    // Accessor functions for field keys
    public fun key_field_key_id(key: &KeyFieldKey): &vector<u8> {
        &key.key_id
    }

    public fun service_field_key_id(key: &ServiceFieldKey): &vector<u8> {
        &key.service_id
    }

    // Events
    public struct DIDRegistered has copy, drop {
        did_id: address,
        controller: address,
        name: vector<u8>,
        timestamp: u64,
    }

    public struct KeyAdded has copy, drop {
        did_id: address,
        key_id: vector<u8>,
        purpose: vector<u8>,
        timestamp: u64,
    }

    public struct KeyRevoked has copy, drop {
        did_id: address,
        key_id: vector<u8>,
        timestamp: u64,
    }

    public struct ServiceAdded has copy, drop {
        did_id: address,
        service_id: vector<u8>,
        service_type: vector<u8>,
        endpoint: vector<u8>,
        timestamp: u64,
    }

    public struct ServiceRemoved has copy, drop {
        did_id: address,
        service_id: vector<u8>,
        timestamp: u64,
    }

    public struct ServiceUpdated has copy, drop {
        did_id: address,
        service_id: vector<u8>,
        old_type: vector<u8>,
        new_type: vector<u8>,
        old_endpoint: vector<u8>,
        new_endpoint: vector<u8>,
        timestamp: u64,
    }

    public struct CredentialIssued has copy, drop {
        credential_id: address,
        subject: address,
        issuer: address,
        schema: vector<u8>,
        timestamp: u64,
    }

    public struct CredentialRevoked has copy, drop {
        credential_id: address,
        issuer: address,
        timestamp: u64,
    }

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
    public struct ServiceInfo has store, drop {
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

    // DID Document representation structures
    public struct DIDDocumentData has drop {
        id: vector<u8>,                    // DID string
        controller: address,               // Controller address
        verification_methods: vector<VerificationMethodData>,
        authentication: vector<vector<u8>>, // Key IDs for authentication
        services: vector<ServiceData>,
        created_at: u64,
    }

    public struct VerificationMethodData has drop {
        id: vector<u8>,                    // Key ID
        key_type: vector<u8>,              // "Ed25519VerificationKey2020"
        controller: vector<u8>,            // DID string
        public_key_bytes: vector<u8>,      // Raw public key
        purpose: vector<u8>,               // "authentication", "assertion", etc.
        revoked: bool,
    }

    public struct ServiceData has drop {
        id: vector<u8>,                    // Service ID
        service_type: vector<u8>,          // "MQTTBroker", etc.
        service_endpoint: vector<u8>,      // Endpoint URL
    }

    // Validation helper functions
    public fun validate_address(addr: address) {
        assert!(addr != @0x0, E_INVALID_ADDRESS);
    }

    public fun validate_name(name: &vector<u8>) {
        assert!(!std::vector::is_empty(name), E_EMPTY_FIELD);
        assert!(std::vector::length(name) <= MAX_NAME_LENGTH, E_FIELD_TOO_LONG);
    }

    public fun validate_public_key(pubkey: &vector<u8>) {
        assert!(!std::vector::is_empty(pubkey), E_EMPTY_FIELD);
        assert!(std::vector::length(pubkey) == ED25519_PUBLIC_KEY_LENGTH, E_INVALID_PUBLIC_KEY);
    }

    public fun validate_schema(schema: &vector<u8>) {
        assert!(!std::vector::is_empty(schema), E_EMPTY_FIELD);
        assert!(std::vector::length(schema) <= MAX_SCHEMA_LENGTH, E_FIELD_TOO_LONG);
    }

    public fun validate_data_hash(data_hash: &vector<u8>) {
        assert!(!std::vector::is_empty(data_hash), E_EMPTY_FIELD);
        assert!(std::vector::length(data_hash) == SHA256_HASH_LENGTH, E_INVALID_DATA_HASH);
    }

    public fun validate_purpose(purpose: &vector<u8>) {
        assert!(!std::vector::is_empty(purpose), E_EMPTY_FIELD);
    }

    public fun validate_endpoint(endpoint: &vector<u8>) {
        assert!(!std::vector::is_empty(endpoint), E_EMPTY_FIELD);
        assert!(std::vector::length(endpoint) <= MAX_ENDPOINT_LENGTH, E_FIELD_TOO_LONG);
    }

    public fun validate_key_id(key_id: &vector<u8>) {
        assert!(!std::vector::is_empty(key_id), E_EMPTY_FIELD);
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
        // Validate inputs
        validate_address(subject);
        validate_address(issuer);
        validate_schema(&schema);
        validate_data_hash(&data_hash);

        let cred = CredentialInfo {
            id: new(ctx),
            subject,
            issuer,
            schema,
            data_hash,
            revoked: false,
            issued_at,
        };

        // Emit event
        event::emit(CredentialIssued {
            credential_id: sui::object::uid_to_address(&cred.id),
            subject,
            issuer,
            schema,
            timestamp: issued_at,
        });

        cred
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
    public fun credential_info_id(cred: &CredentialInfo): &UID {
        &cred.id
    }

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

    public fun revoke_credential_info(cred: &mut CredentialInfo, timestamp: u64) {
        cred.revoked = true;
        
        // Emit event
        event::emit(CredentialRevoked {
            credential_id: sui::object::uid_to_address(&cred.id),
            issuer: cred.issuer,
            timestamp,
        });
    }

    // Public event creation functions for cross-module access
    public fun emit_did_registered(
        did_id: address,
        controller: address,
        name: vector<u8>,
        timestamp: u64
    ) {
        event::emit(DIDRegistered {
            did_id,
            controller,
            name,
            timestamp,
        });
    }

    public fun emit_key_added(
        did_id: address,
        key_id: vector<u8>,
        purpose: vector<u8>,
        timestamp: u64
    ) {
        event::emit(KeyAdded {
            did_id,
            key_id,
            purpose,
            timestamp,
        });
    }

    public fun emit_key_revoked(
        did_id: address,
        key_id: vector<u8>,
        timestamp: u64
    ) {
        event::emit(KeyRevoked {
            did_id,
            key_id,
            timestamp,
        });
    }

    public fun emit_service_added(
        did_id: address,
        service_id: vector<u8>,
        service_type: vector<u8>,
        endpoint: vector<u8>,
        timestamp: u64
    ) {
        event::emit(ServiceAdded {
            did_id,
            service_id,
            service_type,
            endpoint,
            timestamp,
        });
    }

    public fun emit_service_removed(
        did_id: address,
        service_id: vector<u8>,
        timestamp: u64
    ) {
        event::emit(ServiceRemoved {
            did_id,
            service_id,
            timestamp,
        });
    }

    public fun emit_service_updated(
        did_id: address,
        service_id: vector<u8>,
        old_type: vector<u8>,
        new_type: vector<u8>,
        old_endpoint: vector<u8>,
        new_endpoint: vector<u8>,
        timestamp: u64
    ) {
        event::emit(ServiceUpdated {
            did_id,
            service_id,
            old_type,
            new_type,
            old_endpoint,
            new_endpoint,
            timestamp,
        });
    }

    // Constructor functions for DID document structures
    public fun new_did_document_data(
        id: vector<u8>,
        controller: address,
        created_at: u64,
    ): DIDDocumentData {
        DIDDocumentData {
            id,
            controller,
            verification_methods: vector::empty(),
            authentication: vector::empty(),
            services: vector::empty(),
            created_at,
        }
    }

    public fun new_verification_method_data(
        id: vector<u8>,
        key_type: vector<u8>,
        controller: vector<u8>,
        public_key_bytes: vector<u8>,
        purpose: vector<u8>,
        revoked: bool,
    ): VerificationMethodData {
        VerificationMethodData {
            id,
            key_type,
            controller,
            public_key_bytes,
            purpose,
            revoked,
        }
    }

    public fun new_service_data(
        id: vector<u8>,
        service_type: vector<u8>,
        service_endpoint: vector<u8>,
    ): ServiceData {
        ServiceData {
            id,
            service_type,
            service_endpoint,
        }
    }

    // Mutator functions for DID document
    public fun add_verification_method(doc: &mut DIDDocumentData, vm: VerificationMethodData) {
        vector::push_back(&mut doc.verification_methods, vm);
    }

    public fun add_authentication_key(doc: &mut DIDDocumentData, key_id: vector<u8>) {
        vector::push_back(&mut doc.authentication, key_id);
    }

    public fun add_service_to_doc(doc: &mut DIDDocumentData, service: ServiceData) {
        vector::push_back(&mut doc.services, service);
    }

    // Accessor functions for DID document structures
    public fun did_document_id(doc: &DIDDocumentData): &vector<u8> {
        &doc.id
    }

    public fun did_document_controller(doc: &DIDDocumentData): address {
        doc.controller
    }

    public fun did_document_verification_methods(doc: &DIDDocumentData): &vector<VerificationMethodData> {
        &doc.verification_methods
    }

    public fun did_document_authentication(doc: &DIDDocumentData): &vector<vector<u8>> {
        &doc.authentication
    }

    public fun did_document_services(doc: &DIDDocumentData): &vector<ServiceData> {
        &doc.services
    }

    public fun did_document_created_at(doc: &DIDDocumentData): u64 {
        doc.created_at
    }

    // Accessor functions for VerificationMethodData
    public fun verification_method_id(vm: &VerificationMethodData): &vector<u8> {
        &vm.id
    }

    public fun verification_method_key_type(vm: &VerificationMethodData): &vector<u8> {
        &vm.key_type
    }

    public fun verification_method_controller(vm: &VerificationMethodData): &vector<u8> {
        &vm.controller
    }

    public fun verification_method_public_key_bytes(vm: &VerificationMethodData): &vector<u8> {
        &vm.public_key_bytes
    }

    public fun verification_method_purpose(vm: &VerificationMethodData): &vector<u8> {
        &vm.purpose
    }

    public fun verification_method_revoked(vm: &VerificationMethodData): bool {
        vm.revoked
    }

    // Accessor functions for ServiceData
    public fun service_data_id(svc: &ServiceData): &vector<u8> {
        &svc.id
    }

    public fun service_data_type(svc: &ServiceData): &vector<u8> {
        &svc.service_type
    }

    public fun service_data_endpoint(svc: &ServiceData): &vector<u8> {
        &svc.service_endpoint
    }
}