module suibotics_core::did_registry {
    use sui::object::{UID, new};
    use sui::dynamic_field;
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::share_object;
    use sui::event;
    use std::option;
    use suibotics_core::identity_types::{
        DIDInfo, KeyInfo, 
        new_did_info, transfer_did_info, new_key_info, new_service_info,
        did_info_id_mut, did_info_controller, revoke_key_info,
        validate_address, validate_name, validate_public_key, validate_purpose,
        validate_endpoint, validate_key_id, DIDRegistered, KeyAdded, KeyRevoked,
        ServiceAdded, E_NAME_ALREADY_EXISTS, E_KEY_ALREADY_EXISTS, E_KEY_NOT_FOUND,
        E_INVALID_CONTROLLER
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
        assert!(!dynamic_field::exists_(&registry.id, name), E_NAME_ALREADY_EXISTS);

        // Create the DIDInfo object
        let mut did = new_did_info(controller, ts, ctx);
        let did_id = sui::object::uid_to_address(did_info_id_mut(&mut did));

        // Store name mapping in the registry
        dynamic_field::add(&mut registry.id, name, controller);

        // Create initial KeyInfo and attach it to the DIDInfo
        let key_info = new_key_info(initial_pubkey, purpose);
        dynamic_field::add(did_info_id_mut(&mut did), b"key_0", key_info);

        // Emit events
        event::emit(DIDRegistered {
            did_id,
            controller,
            name,
            timestamp: ts,
        });

        event::emit(KeyAdded {
            did_id,
            key_id: b"key_0",
            purpose,
            timestamp: ts,
        });

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
        assert!(sender_addr == did_info_controller(did), E_INVALID_CONTROLLER);

        // Check if key ID already exists
        assert!(!dynamic_field::exists_(did_info_id_mut(did), key_id), E_KEY_ALREADY_EXISTS);

        let key_info = new_key_info(pubkey, purpose);
        dynamic_field::add(did_info_id_mut(did), key_id, key_info);

        // Emit event
        event::emit(KeyAdded {
            did_id: sui::object::uid_to_address(did_info_id_mut(did)),
            key_id,
            purpose,
            timestamp: ts,
        });
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
        assert!(sender_addr == did_info_controller(did), E_INVALID_CONTROLLER);

        // Check if key exists before trying to revoke it
        assert!(dynamic_field::exists_(did_info_id_mut(did), key_id), E_KEY_NOT_FOUND);

        let key_info: &mut KeyInfo = dynamic_field::borrow_mut(did_info_id_mut(did), key_id);
        revoke_key_info(key_info);

        // Emit event
        event::emit(KeyRevoked {
            did_id: sui::object::uid_to_address(did_info_id_mut(did)),
            key_id,
            timestamp: ts,
        });
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
        assert!(sender_addr == did_info_controller(did), E_INVALID_CONTROLLER);

        // Check if service ID already exists
        assert!(!dynamic_field::exists_(did_info_id_mut(did), svc_id), E_KEY_ALREADY_EXISTS);

        let svc = new_service_info(svc_id, svc_type, endpoint);
        dynamic_field::add(did_info_id_mut(did), svc_id, svc);

        // Emit event
        event::emit(ServiceAdded {
            did_id: sui::object::uid_to_address(did_info_id_mut(did)),
            service_id: svc_id,
            service_type: svc_type,
            endpoint,
            timestamp: ts,
        });
    }

    /// Get the controller address for a given DID name
    public fun get_did_controller(registry: &DIDRegistry, name: vector<u8>): option::Option<address> {
        if (dynamic_field::exists_(&registry.id, name)) {
            option::some(*dynamic_field::borrow(&registry.id, name))
        } else {
            option::none()
        }
    }
}