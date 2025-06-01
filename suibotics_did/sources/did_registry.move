module suibotics_did::did_registry {
    use sui::object::{UID, new};
    use sui::dynamic_field;
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::share_object;
    use sui::event;
    use std::option;
    use suibotics_did::identity_types::{
        DIDInfo, KeyInfo, 
        new_did_info, transfer_did_info, new_key_info, new_service_info,
        did_info_id_mut, did_info_controller, revoke_key_info,
        validate_address, validate_name, validate_public_key, validate_purpose,
        validate_endpoint, validate_key_id, 
        emit_did_registered, emit_key_added, emit_key_revoked, emit_service_added,
        e_name_already_exists, e_key_already_exists, e_key_not_found, e_invalid_controller,
        KeyFieldKey, ServiceFieldKey, new_key_field_key, new_service_field_key,
        ServiceInfo, did_info_id,
        DIDDocumentData, VerificationMethodData, ServiceData,
        new_did_document_data, new_verification_method_data, new_service_data,
        add_verification_method, add_authentication_key, add_service_to_doc,
        key_info_pubkey, key_info_purpose, key_info_revoked,
        service_info_id, service_info_type, service_info_endpoint, did_info_created_at
    };

    /// Global registry for name-to-DID mappings
    public struct DIDRegistry has key {
        id: UID,
    }

    /// Initialize the registry as a shared object
    fun init(ctx: &mut TxContext) {
        let registry = DIDRegistry {
            id: new(ctx),
        };
        share_object(registry);
    }

    /// Test-only initialization function
    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    /// Register a new DID with initial key
    public entry fun register_did(
        registry: &mut DIDRegistry,
        name: vector<u8>,             // human-readable label
        initial_pubkey: vector<u8>,   // Ed25519 public key
        purpose: vector<u8>,          // authentication, assertion, etc.
        ctx: &mut TxContext
    ) {
        let controller = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);

        // Validate inputs
        validate_name(&name);
        validate_public_key(&initial_pubkey);
        validate_purpose(&purpose);
        validate_address(controller);

        // Check if name already exists
        assert!(!dynamic_field::exists_(&registry.id, name), e_name_already_exists());

        // Create the DIDInfo object
        let mut did = new_did_info(controller, ts, ctx);
        let did_id = sui::object::uid_to_address(did_info_id_mut(&mut did));

        // Store name mapping in the registry
        dynamic_field::add(&mut registry.id, name, controller);

        // Create initial KeyInfo and attach it to the DIDInfo using type-safe key
        let key_info = new_key_info(initial_pubkey, purpose);
        let key_field_key = new_key_field_key(b"key_0");
        dynamic_field::add(did_info_id_mut(&mut did), key_field_key, key_info);

        // Emit events
        emit_did_registered(did_id, controller, name, ts);
        emit_key_added(did_id, b"key_0", purpose, ts);

        // Transfer DIDInfo to the controller
        transfer_did_info(did, controller);
    }

    /// Add or rotate a key for an existing DID
    public entry fun add_key(
        did: &mut DIDInfo,
        key_id: vector<u8>,
        pubkey: vector<u8>,
        purpose: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender_addr = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        // Validate inputs
        validate_key_id(&key_id);
        validate_public_key(&pubkey);
        validate_purpose(&purpose);
        
        // Verify sender is the DID controller
        assert!(sender_addr == did_info_controller(did), e_invalid_controller());

        // Create type-safe key field key
        let key_field_key = new_key_field_key(key_id);
        
        // Check if key ID already exists
        assert!(!dynamic_field::exists_(did_info_id_mut(did), key_field_key), e_key_already_exists());

        let key_info = new_key_info(pubkey, purpose);
        dynamic_field::add(did_info_id_mut(did), key_field_key, key_info);

        // Emit event
        emit_key_added(sui::object::uid_to_address(did_info_id_mut(did)), key_id, purpose, ts);
    }

    /// Revoke a key by setting its `revoked` flag true
    public entry fun revoke_key(
        did: &mut DIDInfo,
        key_id: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender_addr = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        // Validate inputs
        validate_key_id(&key_id);
        
        // Verify sender is the DID controller
        assert!(sender_addr == did_info_controller(did), e_invalid_controller());

        // Create type-safe key field key
        let key_field_key = new_key_field_key(key_id);

        // Check if key exists before trying to revoke it
        assert!(dynamic_field::exists_(did_info_id_mut(did), key_field_key), e_key_not_found());

        let key_info: &mut KeyInfo = dynamic_field::borrow_mut(did_info_id_mut(did), key_field_key);
        revoke_key_info(key_info);

        // Emit event
        emit_key_revoked(sui::object::uid_to_address(did_info_id_mut(did)), key_id, ts);
    }

    /// Add a service endpoint to the DID Document
    public entry fun add_service(
        did: &mut DIDInfo,
        svc_id: vector<u8>,
        svc_type: vector<u8>,
        endpoint: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender_addr = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        // Validate inputs
        validate_key_id(&svc_id); // Reuse key_id validation for service_id
        validate_purpose(&svc_type); // Reuse purpose validation for service type
        validate_endpoint(&endpoint);
        
        // Verify sender is the DID controller
        assert!(sender_addr == did_info_controller(did), e_invalid_controller());

        // Create type-safe service field key
        let service_field_key = new_service_field_key(svc_id);

        // Check if service ID already exists
        assert!(!dynamic_field::exists_(did_info_id_mut(did), service_field_key), e_key_already_exists());

        let svc = new_service_info(svc_id, svc_type, endpoint);
        dynamic_field::add(did_info_id_mut(did), service_field_key, svc);

        // Emit event
        emit_service_added(sui::object::uid_to_address(did_info_id_mut(did)), svc_id, svc_type, endpoint, ts);
    }

    /// Get the controller address for a given DID name
    public fun get_did_controller(registry: &DIDRegistry, name: vector<u8>): option::Option<address> {
        if (dynamic_field::exists_(&registry.id, name)) {
            option::some(*dynamic_field::borrow(&registry.id, name))
        } else {
            option::none()
        }
    }

    /// Get a specific key from a DID
    public fun get_key(did: &DIDInfo, key_id: vector<u8>): &KeyInfo {
        let key_field_key = new_key_field_key(key_id);
        dynamic_field::borrow(did_info_id(did), key_field_key)
    }

    /// Get a specific service from a DID
    public fun get_service(did: &DIDInfo, service_id: vector<u8>): &ServiceInfo {
        let service_field_key = new_service_field_key(service_id);
        dynamic_field::borrow(did_info_id(did), service_field_key)
    }

    /// Check if a key exists on a DID
    public fun has_key(did: &DIDInfo, key_id: vector<u8>): bool {
        let key_field_key = new_key_field_key(key_id);
        dynamic_field::exists_(did_info_id(did), key_field_key)
    }

    /// Check if a service exists on a DID
    public fun has_service(did: &DIDInfo, service_id: vector<u8>): bool {
        let service_field_key = new_service_field_key(service_id);
        dynamic_field::exists_(did_info_id(did), service_field_key)
    }

    /// Build a DID document from a DID object with known key and service IDs
    /// Note: This function requires the caller to provide the key and service IDs
    /// since Move doesn't have easy dynamic field enumeration
    public fun build_did_document(
        did: &DIDInfo,
        did_string: vector<u8>,
        key_ids: vector<vector<u8>>,
        service_ids: vector<vector<u8>>
    ): DIDDocumentData {
        let controller = did_info_controller(did);
        let created_at = did_info_created_at(did);
        
        // Create the base DID document
        let mut doc = new_did_document_data(did_string, controller, created_at);
        
        // Add all verification methods
        let mut i = 0;
        while (i < vector::length(&key_ids)) {
            let key_id = *vector::borrow(&key_ids, i);
            
            if (has_key(did, key_id)) {
                let key_info = get_key(did, key_id);
                
                // Create verification method data
                let vm = new_verification_method_data(
                    key_id,
                    b"Ed25519VerificationKey2020",
                    did_string,
                    *key_info_pubkey(key_info),
                    *key_info_purpose(key_info),
                    key_info_revoked(key_info)
                );
                
                add_verification_method(&mut doc, vm);
                
                // Add to authentication if purpose is authentication
                if (*key_info_purpose(key_info) == b"authentication") {
                    add_authentication_key(&mut doc, key_id);
                };
            };
            
            i = i + 1;
        };
        
        // Add all services
        let mut j = 0;
        while (j < vector::length(&service_ids)) {
            let service_id = *vector::borrow(&service_ids, j);
            
            if (has_service(did, service_id)) {
                let service_info = get_service(did, service_id);
                
                let service_data = new_service_data(
                    *service_info_id(service_info),
                    *service_info_type(service_info),
                    *service_info_endpoint(service_info)
                );
                
                add_service_to_doc(&mut doc, service_data);
            };
            
            j = j + 1;
        };
        
        doc
    }

    /// Build a DID document with common default key and service IDs
    /// This is a convenience function for the most common use case
    public fun build_basic_did_document(did: &DIDInfo, did_string: vector<u8>): DIDDocumentData {
        // Try common key IDs
        let key_ids = vector[
            b"key_0",        // Initial key
            b"key_1",        // Additional keys
            b"key_2",
            b"signing_key",
            b"encryption_key"
        ];
        
        // Try common service IDs  
        let service_ids = vector[
            b"mqtt_service",
            b"mqtt1", 
            b"endpoint1",
            b"api_service",
            b"broker"
        ];
        
        build_did_document(did, did_string, key_ids, service_ids)
    }
}