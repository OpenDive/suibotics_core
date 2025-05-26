module suibotics_core::did_registry {
    use sui::object::{UID, new};
    use sui::dynamic_field;
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::share_object;
    use std::option;
    use suibotics_core::identity_types::{
        DIDInfo, KeyInfo, 
        new_did_info, transfer_did_info, new_key_info, new_service_info,
        did_info_id_mut, did_info_controller, revoke_key_info
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

        // Create the DIDInfo object
        let mut did = new_did_info(controller, ts, ctx);

        // Store name mapping in the registry
        dynamic_field::add(&mut registry.id, name, controller);

        // Create initial KeyInfo and attach it to the DIDInfo
        let key_info = new_key_info(initial_pubkey, purpose);
        dynamic_field::add(did_info_id_mut(&mut did), b"key_0", key_info);

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
        assert!(sender_addr == did_info_controller(did), 1);

        let key_info = new_key_info(pubkey, purpose);
        dynamic_field::add(did_info_id_mut(did), key_id, key_info);
    }

    /// Revoke a key by setting its `revoked` flag true
    public entry fun revoke_key(
        did: &mut DIDInfo,
        key_id: vector<u8>,
        ctx: &mut TxContext
    ) {
        let sender_addr = sender(ctx);
        assert!(sender_addr == did_info_controller(did), 2);

        let key_info: &mut KeyInfo = dynamic_field::borrow_mut(did_info_id_mut(did), key_id);
        revoke_key_info(key_info);
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
        assert!(sender_addr == did_info_controller(did), 3);

        let svc = new_service_info(svc_id, svc_type, endpoint);
        dynamic_field::add(did_info_id_mut(did), svc_id, svc);
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