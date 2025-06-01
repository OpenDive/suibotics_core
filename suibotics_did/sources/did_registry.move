module suibotics_did::did_registry {
    use sui::object::{new};
    use sui::dynamic_field;
    use sui::tx_context::{sender};
    use sui::transfer::share_object;
    use sui::transfer::public_transfer;
    use std::option;
    use suibotics_did::identity_types::{
        DIDInfo, KeyInfo, 
        new_did_info, transfer_did_info, new_key_info, new_service_info,
        did_info_id_mut, did_info_controller, revoke_key_info,
        validate_address, validate_name, validate_public_key, validate_purpose,
        validate_endpoint, validate_key_id, 
        emit_did_registered, emit_key_added, emit_key_revoked, emit_service_added,
        e_name_already_exists, e_key_already_exists, e_key_not_found, e_invalid_controller,
        e_batch_too_large, e_batch_size_mismatch, e_empty_field, e_invalid_public_key,
        e_service_already_exists, e_service_not_found, max_batch_size,
        KeyFieldKey, ServiceFieldKey, new_key_field_key, new_service_field_key,
        ServiceInfo, did_info_id,
        DIDDocumentData, VerificationMethodData, ServiceData,
        new_did_document_data, new_verification_method_data, new_service_data,
        add_verification_method, add_authentication_key, add_service_to_doc,
        key_info_pubkey, key_info_purpose, key_info_revoked,
        service_info_id, service_info_type, service_info_endpoint, did_info_created_at,
        emit_service_removed, emit_service_updated
    };

    /// Global registry for name-to-DID mappings
    public struct DIDRegistry has key {
        id: UID,
        total_dids: u64,  // Track total DIDs for statistics
    }

    /// Initialize the registry as a shared object
    fun init(ctx: &mut TxContext) {
        let registry = DIDRegistry {
            id: new(ctx),
            total_dids: 0,
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

        // Add to controller reverse lookup
        let controller_key = address_to_string(controller);
        if (dynamic_field::exists_(&registry.id, controller_key)) {
            let did_list: &mut vector<address> = dynamic_field::borrow_mut(&mut registry.id, controller_key);
            vector::push_back(did_list, did_id);
        } else {
            let did_list = vector[did_id];
            dynamic_field::add(&mut registry.id, controller_key, did_list);
        };
        
        // Update registry statistics
        registry.total_dids = registry.total_dids + 1;

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
        assert!(!dynamic_field::exists_(did_info_id_mut(did), service_field_key), e_service_already_exists());

        let svc = new_service_info(svc_id, svc_type, endpoint);
        dynamic_field::add(did_info_id_mut(did), service_field_key, svc);

        // Emit event
        emit_service_added(sui::object::uid_to_address(did_info_id_mut(did)), svc_id, svc_type, endpoint, ts);
    }

    /// Remove a service endpoint from the DID Document
    public entry fun remove_service(
        did: &mut DIDInfo,
        svc_id: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender_addr = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        // Validate inputs
        validate_key_id(&svc_id);
        
        // Verify sender is the DID controller
        assert!(sender_addr == did_info_controller(did), e_invalid_controller());

        // Create type-safe service field key
        let service_field_key = new_service_field_key(svc_id);

        // Check if service exists before trying to remove it
        assert!(dynamic_field::exists_(did_info_id_mut(did), service_field_key), e_service_not_found());

        // Remove the service from dynamic fields
        let removed_service: ServiceInfo = dynamic_field::remove(did_info_id_mut(did), service_field_key);
        
        // Emit event
        emit_service_removed(sui::object::uid_to_address(did_info_id_mut(did)), svc_id, ts);
    }

    /// Update a service endpoint in the DID Document
    public entry fun update_service(
        did: &mut DIDInfo,
        svc_id: vector<u8>,
        new_svc_type: vector<u8>,
        new_endpoint: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender_addr = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        // Validate inputs
        validate_key_id(&svc_id);
        validate_purpose(&new_svc_type);
        validate_endpoint(&new_endpoint);
        
        // Verify sender is the DID controller
        assert!(sender_addr == did_info_controller(did), e_invalid_controller());

        // Create type-safe service field key
        let service_field_key = new_service_field_key(svc_id);

        // Check if service exists before trying to update it
        assert!(dynamic_field::exists_(did_info_id_mut(did), service_field_key), e_service_not_found());

        // Get the current service to capture old values for event
        let current_service: &ServiceInfo = dynamic_field::borrow(did_info_id_mut(did), service_field_key);
        let old_type = *service_info_type(current_service);
        let old_endpoint = *service_info_endpoint(current_service);

        // Remove old service and add new one (Move doesn't support in-place mutation of dynamic fields)
        let old_service: ServiceInfo = dynamic_field::remove(did_info_id_mut(did), service_field_key);
        
        let updated_service = new_service_info(svc_id, new_svc_type, new_endpoint);
        dynamic_field::add(did_info_id_mut(did), service_field_key, updated_service);

        // Emit event
        emit_service_updated(
            sui::object::uid_to_address(did_info_id_mut(did)), 
            svc_id, 
            old_type, 
            new_svc_type, 
            old_endpoint, 
            new_endpoint, 
            ts
        );
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

    // === BATCH OPERATIONS ===

    /// Batch operation result for tracking success/failure of individual operations
    public struct BatchResult has copy, drop {
        index: u64,
        success: bool,
        error_code: u64,
    }

    /// Create a new BatchResult (for testing purposes)
    public fun new_batch_result(index: u64, success: bool, error_code: u64): BatchResult {
        BatchResult { index, success, error_code }
    }

    /// Batch register multiple DIDs in a single transaction
    /// Returns vector of BatchResult indicating success/failure for each operation
    public entry fun register_dids_batch(
        registry: &mut DIDRegistry,
        names: vector<vector<u8>>,
        pubkeys: vector<vector<u8>>,
        purposes: vector<vector<u8>>,
        ctx: &mut TxContext
    ): vector<BatchResult> {
        let batch_size = vector::length(&names);
        assert!(batch_size <= max_batch_size(), e_batch_too_large());
        assert!(batch_size == vector::length(&pubkeys), e_batch_size_mismatch());
        assert!(batch_size == vector::length(&purposes), e_batch_size_mismatch());
        
        let mut results = vector::empty<BatchResult>();
        let controller = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        let mut i = 0;
        while (i < batch_size) {
            let name = *vector::borrow(&names, i);
            let pubkey = *vector::borrow(&pubkeys, i);
            let purpose = *vector::borrow(&purposes, i);
            
            // Validate inputs and check if name exists
            let mut success = true;
            let mut error_code = 0;
            
            if (vector::is_empty(&name) || vector::length(&name) > 255) {
                success = false;
                error_code = e_empty_field();
            } else if (vector::length(&pubkey) != 32) {
                success = false;
                error_code = e_invalid_public_key();
            } else if (vector::is_empty(&purpose)) {
                success = false;
                error_code = e_empty_field();
            } else if (dynamic_field::exists_(&registry.id, name)) {
                success = false;
                error_code = e_name_already_exists();
            };
            
            if (success) {
                // Create the DIDInfo object
                let mut did = new_did_info(controller, ts, ctx);
                let did_id = sui::object::uid_to_address(did_info_id_mut(&mut did));

                // Store name mapping in the registry
                dynamic_field::add(&mut registry.id, name, controller);

                // Add to controller reverse lookup
                let controller_key = address_to_string(controller);
                if (dynamic_field::exists_(&registry.id, controller_key)) {
                    let did_list: &mut vector<address> = dynamic_field::borrow_mut(&mut registry.id, controller_key);
                    vector::push_back(did_list, did_id);
                } else {
                    let did_list = vector[did_id];
                    dynamic_field::add(&mut registry.id, controller_key, did_list);
                };
                
                // Update registry statistics
                registry.total_dids = registry.total_dids + 1;

                // Create initial KeyInfo and attach it to the DIDInfo using type-safe key
                let key_info = new_key_info(pubkey, purpose);
                let key_field_key = new_key_field_key(b"key_0");
                dynamic_field::add(did_info_id_mut(&mut did), key_field_key, key_info);

                // Emit events
                emit_did_registered(did_id, controller, name, ts);
                emit_key_added(did_id, b"key_0", purpose, ts);

                // Transfer DIDInfo to the controller
                transfer_did_info(did, controller);
            };
            
            vector::push_back(&mut results, BatchResult {
                index: i,
                success,
                error_code,
            });
            
            i = i + 1;
        };
        
        results
    }

    /// Batch add keys to multiple DIDs
    public fun add_keys_batch(
        dids: &mut vector<DIDInfo>,
        key_ids: vector<vector<u8>>,
        pubkeys: vector<vector<u8>>,
        purposes: vector<vector<u8>>,
        ctx: &mut TxContext
    ): vector<BatchResult> {
        let batch_size = vector::length(dids);
        assert!(batch_size <= max_batch_size(), e_batch_too_large());
        assert!(batch_size == vector::length(&key_ids), e_batch_size_mismatch());
        assert!(batch_size == vector::length(&pubkeys), e_batch_size_mismatch());
        assert!(batch_size == vector::length(&purposes), e_batch_size_mismatch());
        
        let mut results = vector::empty<BatchResult>();
        let sender_addr = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        let mut i = 0;
        while (i < batch_size) {
            let did = vector::borrow_mut(dids, i);
            let key_id = *vector::borrow(&key_ids, i);
            let pubkey = *vector::borrow(&pubkeys, i);
            let purpose = *vector::borrow(&purposes, i);
            
            let mut success = true;
            let mut error_code = 0;
            
            // Validate access control
            if (sender_addr != did_info_controller(did)) {
                success = false;
                error_code = e_invalid_controller();
            } else if (vector::is_empty(&key_id)) {
                success = false;
                error_code = e_empty_field();
            } else if (vector::length(&pubkey) != 32) {
                success = false;
                error_code = e_invalid_public_key();
            } else if (vector::is_empty(&purpose)) {
                success = false;
                error_code = e_empty_field();
            } else {
                let key_field_key = new_key_field_key(key_id);
                if (dynamic_field::exists_(did_info_id_mut(did), key_field_key)) {
                    success = false;
                    error_code = e_key_already_exists();
                };
            };
            
            if (success) {
                let key_info = new_key_info(pubkey, purpose);
                let key_field_key = new_key_field_key(key_id);
                dynamic_field::add(did_info_id_mut(did), key_field_key, key_info);
                
                emit_key_added(sui::object::uid_to_address(did_info_id_mut(did)), key_id, purpose, ts);
            };
            
            vector::push_back(&mut results, BatchResult {
                index: i,
                success,
                error_code,
            });
            
            i = i + 1;
        };
        
        results
    }

    /// Batch revoke keys from multiple DIDs
    public fun revoke_keys_batch(
        dids: &mut vector<DIDInfo>,
        key_ids: vector<vector<u8>>,
        ctx: &mut TxContext
    ): vector<BatchResult> {
        let batch_size = vector::length(dids);
        assert!(batch_size <= max_batch_size(), e_batch_too_large());
        assert!(batch_size == vector::length(&key_ids), e_batch_size_mismatch());
        
        let mut results = vector::empty<BatchResult>();
        let sender_addr = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        let mut i = 0;
        while (i < batch_size) {
            let did = vector::borrow_mut(dids, i);
            let key_id = *vector::borrow(&key_ids, i);
            
            let mut success = true;
            let mut error_code = 0;
            
            // Validate access control
            if (sender_addr != did_info_controller(did)) {
                success = false;
                error_code = e_invalid_controller();
            } else if (vector::is_empty(&key_id)) {
                success = false;
                error_code = e_empty_field();
            } else {
                let key_field_key = new_key_field_key(key_id);
                if (!dynamic_field::exists_(did_info_id_mut(did), key_field_key)) {
                    success = false;
                    error_code = e_key_not_found();
                };
            };
            
            if (success) {
                let key_field_key = new_key_field_key(key_id);
                let key_info: &mut KeyInfo = dynamic_field::borrow_mut(did_info_id_mut(did), key_field_key);
                revoke_key_info(key_info);
                
                emit_key_revoked(sui::object::uid_to_address(did_info_id_mut(did)), key_id, ts);
            };
            
            vector::push_back(&mut results, BatchResult {
                index: i,
                success,
                error_code,
            });
            
            i = i + 1;
        };
        
        results
    }

    /// Batch add services to multiple DIDs
    public fun add_services_batch(
        dids: &mut vector<DIDInfo>,
        service_ids: vector<vector<u8>>,
        service_types: vector<vector<u8>>,
        endpoints: vector<vector<u8>>,
        ctx: &mut TxContext
    ): vector<BatchResult> {
        let batch_size = vector::length(dids);
        assert!(batch_size <= max_batch_size(), e_batch_too_large());
        assert!(batch_size == vector::length(&service_ids), e_batch_size_mismatch());
        assert!(batch_size == vector::length(&service_types), e_batch_size_mismatch());
        assert!(batch_size == vector::length(&endpoints), e_batch_size_mismatch());
        
        let mut results = vector::empty<BatchResult>();
        let sender_addr = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        let mut i = 0;
        while (i < batch_size) {
            let did = vector::borrow_mut(dids, i);
            let service_id = *vector::borrow(&service_ids, i);
            let service_type = *vector::borrow(&service_types, i);
            let endpoint = *vector::borrow(&endpoints, i);
            
            let mut success = true;
            let mut error_code = 0;
            
            // Validate access control and inputs
            if (sender_addr != did_info_controller(did)) {
                success = false;
                error_code = e_invalid_controller();
            } else if (vector::is_empty(&service_id)) {
                success = false;
                error_code = e_empty_field();
            } else if (vector::is_empty(&service_type)) {
                success = false;
                error_code = e_empty_field();
            } else if (vector::is_empty(&endpoint) || vector::length(&endpoint) > 2000) {
                success = false;
                error_code = e_empty_field();
            } else {
                let service_field_key = new_service_field_key(service_id);
                if (dynamic_field::exists_(did_info_id_mut(did), service_field_key)) {
                    success = false;
                    error_code = e_service_already_exists();
                };
            };
            
            if (success) {
                let svc = new_service_info(service_id, service_type, endpoint);
                let service_field_key = new_service_field_key(service_id);
                dynamic_field::add(did_info_id_mut(did), service_field_key, svc);
                
                emit_service_added(sui::object::uid_to_address(did_info_id_mut(did)), service_id, service_type, endpoint, ts);
            };
            
            vector::push_back(&mut results, BatchResult {
                index: i,
                success,
                error_code,
            });
            
            i = i + 1;
        };
        
        results
    }

    /// Batch update services across multiple DIDs
    public fun update_services_batch(
        dids: &mut vector<DIDInfo>,
        service_ids: vector<vector<u8>>,
        new_service_types: vector<vector<u8>>,
        new_endpoints: vector<vector<u8>>,
        ctx: &mut TxContext
    ): vector<BatchResult> {
        let batch_size = vector::length(dids);
        assert!(batch_size <= max_batch_size(), e_batch_too_large());
        assert!(batch_size == vector::length(&service_ids), e_batch_size_mismatch());
        assert!(batch_size == vector::length(&new_service_types), e_batch_size_mismatch());
        assert!(batch_size == vector::length(&new_endpoints), e_batch_size_mismatch());
        
        let mut results = vector::empty<BatchResult>();
        let sender_addr = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        let mut i = 0;
        while (i < batch_size) {
            let did = vector::borrow_mut(dids, i);
            let service_id = *vector::borrow(&service_ids, i);
            let new_service_type = *vector::borrow(&new_service_types, i);
            let new_endpoint = *vector::borrow(&new_endpoints, i);
            
            let mut success = true;
            let mut error_code = 0;
            
            // Validate access control and inputs
            if (sender_addr != did_info_controller(did)) {
                success = false;
                error_code = e_invalid_controller();
            } else if (vector::is_empty(&service_id)) {
                success = false;
                error_code = e_empty_field();
            } else if (vector::is_empty(&new_service_type)) {
                success = false;
                error_code = e_empty_field();
            } else if (vector::is_empty(&new_endpoint) || vector::length(&new_endpoint) > 2000) {
                success = false;
                error_code = e_empty_field();
            } else {
                let service_field_key = new_service_field_key(service_id);
                if (!dynamic_field::exists_(did_info_id_mut(did), service_field_key)) {
                    success = false;
                    error_code = e_service_not_found();
                };
            };
            
            if (success) {
                let service_field_key = new_service_field_key(service_id);
                let old_service: ServiceInfo = dynamic_field::remove(did_info_id_mut(did), service_field_key);
                
                // Capture old values for event
                let old_type = *service_info_type(&old_service);
                let old_endpoint = *service_info_endpoint(&old_service);
                
                // Create new service with updated values
                let new_service = new_service_info(service_id, new_service_type, new_endpoint);
                dynamic_field::add(did_info_id_mut(did), service_field_key, new_service);
                
                emit_service_updated(
                    sui::object::uid_to_address(did_info_id_mut(did)), 
                    service_id, 
                    old_type, 
                    new_service_type, 
                    old_endpoint, 
                    new_endpoint, 
                    ts
                );
            };
            
            vector::push_back(&mut results, BatchResult {
                index: i,
                success,
                error_code,
            });
            
            i = i + 1;
        };
        
        results
    }

    // === BATCH OPERATION UTILITIES ===

    /// Count successful operations in batch results
    public fun count_batch_successes(results: &vector<BatchResult>): u64 {
        let mut success_count = 0;
        let mut i = 0;
        while (i < vector::length(results)) {
            let result = vector::borrow(results, i);
            if (result.success) {
                success_count = success_count + 1;
            };
            i = i + 1;
        };
        success_count
    }

    /// Get failed operation indices from batch results
    public fun get_batch_failures(results: &vector<BatchResult>): vector<u64> {
        let mut failures = vector::empty<u64>();
        let mut i = 0;
        while (i < vector::length(results)) {
            let result = vector::borrow(results, i);
            if (!result.success) {
                vector::push_back(&mut failures, result.index);
            };
            i = i + 1;
        };
        failures
    }

    /// Check if entire batch succeeded
    public fun is_batch_fully_successful(results: &vector<BatchResult>): bool {
        let mut i = 0;
        while (i < vector::length(results)) {
            let result = vector::borrow(results, i);
            if (!result.success) {
                return false
            };
            i = i + 1;
        };
        true
    }

    // === REVERSE LOOKUP FUNCTIONS ===

    /// Get DID controller by name (enhanced with Option return)
    public fun get_did_controller_by_name(
        registry: &DIDRegistry,
        name: vector<u8>
    ): option::Option<address> {
        if (dynamic_field::exists_(&registry.id, name)) {
            option::some(*dynamic_field::borrow(&registry.id, name))
        } else {
            option::none()
        }
    }

    /// Get all DIDs controlled by a specific address
    public fun get_dids_by_controller(
        registry: &DIDRegistry,
        controller: address
    ): vector<address> {
        let controller_key = address_to_string(controller);
        if (dynamic_field::exists_(&registry.id, controller_key)) {
            *dynamic_field::borrow(&registry.id, controller_key)
        } else {
            vector::empty<address>()
        }
    }

    /// Get registry statistics
    public fun get_registry_stats(registry: &DIDRegistry): u64 {
        registry.total_dids
    }

    /// Check if a DID name exists in the registry
    public fun did_name_exists(
        registry: &DIDRegistry,
        name: vector<u8>
    ): bool {
        dynamic_field::exists_(&registry.id, name)
    }

    // === HELPER FUNCTIONS ===

    /// Convert address to string for indexing (simple approach)
    fun address_to_string(addr: address): vector<u8> {
        // Create a unique key by prefixing with "controller_" and converting address
        let mut key = b"controller_";
        // Convert address to u256 then to bytes
        let addr_u256 = sui::address::to_u256(addr);
        let mut temp = addr_u256;
        
        if (temp == 0) {
            vector::push_back(&mut key, 0);
        } else {
            while (temp > 0) {
                vector::push_back(&mut key, ((temp % 256) as u8));
                temp = temp / 256;
            };
        };
        key
    }
}