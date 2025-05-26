address 0xRobotID {
module DidRegistry {
    use sui::object::{UID, ID, move_to, borrow_global_mut};
    use sui::dynamic_fields::{DynamicField, DynamicFieldInfo};
    use sui::tx_context::TxContext;
    use std::vector;
    use IdentityTypes::{DIDInfo, KeyInfo, ServiceInfo};

    /// Name of the dynamic field map for DIDInfo children.
    const DID_MAP: vector<u8> = b"did_map";

    /// Initialize the registry (one-time).
    public entry fun init_registry(ctx: &mut TxContext) {
        let map = DynamicFieldInfo::new<vector<u8>, ID<DIDInfo>>(DID_MAP);
        DynamicFieldInfo::publish(ctx, map);
    }

    /// Register a new DID with initial key.
    public entry fun register_did(
        ctx: &mut TxContext,
        name: vector<u8>,             // human-readable label
        initial_pubkey: vector<u8>,   // Ed25519 public key
        purpose: vector<u8>           // authentication, assertion, etc.
    ) {
        let controller = TxContext::sender(ctx);
        let ts = TxContext::timestamp(ctx);

        // Mint the DIDInfo object under controller
        let did = DIDInfo { id: UID::new(ctx), controller, created_at: ts };
        move_to(ctx, did);

        // Index by name: name -> DIDInfo object ID
        let idx = DynamicField { name: name.clone(), value: ID::of(did.id) };
        DynamicFieldInfo::create_dynamic_field(ctx, DID_MAP, idx);

        // Create initial KeyInfo dynamic field under this DIDInfo
        let key_info = KeyInfo { pubkey: initial_pubkey, purpose, revoked: false };
        let key_field = DynamicField { name: b"key_0".to_vec(), value: key_info };
        DynamicFieldInfo::create_dynamic_field(ctx, DID_MAP, key_field);
    }

    /// Add or rotate a key for an existing DID.
    public entry fun add_key(
        ctx: &mut TxContext,
        did_id: ID<DIDInfo>,
        key_id: vector<u8>,
        pubkey: vector<u8>,
        purpose: vector<u8>
    ) {
        let sender = TxContext::sender(ctx);
        let did = borrow_global_mut<DIDInfo>(ID::id_of(&did_id));
        assert!(sender == did.controller, 1);

        let key_info = KeyInfo { pubkey, purpose, revoked: false };
        let field = DynamicField { name: key_id, value: key_info };
        DynamicFieldInfo::create_dynamic_field(ctx, ID::id_of(&did_id), field);
    }

    /// Revoke a key by setting its `revoked` flag true.
    public entry fun revoke_key(
        ctx: &mut TxContext,
        did_id: ID<DIDInfo>,
        key_id: vector<u8>
    ) {
        let sender = TxContext::sender(ctx);
        let did = borrow_global_mut<DIDInfo>(ID::id_of(&did_id));
        assert!(sender == did.controller, 2);

        let mut df = DynamicFieldInfo::borrow_mut(ctx, ID::id_of(&did_id), key_id);
        df.value.revoked = true;
    }

    /// Add a service endpoint to the DID Document.
    public entry fun add_service(
        ctx: &mut TxContext,
        did_id: ID<DIDInfo>,
        svc_id: vector<u8>,
        svc_type: vector<u8>,
        endpoint: vector<u8>
    ) {
        let sender = TxContext::sender(ctx);
        let did = borrow_global_mut<DIDInfo>(ID::id_of(&did_id));
        assert!(sender == did.controller, 3);

        let svc = ServiceInfo { id: svc_id.clone(), type_: svc_type, endpoint };
        let field = DynamicField { name: svc_id, value: svc };
        DynamicFieldInfo::create_dynamic_field(ctx, ID::id_of(&did_id), field);
    }
}
}