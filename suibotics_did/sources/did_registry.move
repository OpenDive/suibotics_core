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
        ServiceInfo, did_info_id
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
}