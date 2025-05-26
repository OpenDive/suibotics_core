address 0xRobotID {
module CredentialRegistry {
    use sui::object::{UID, ID, move_to, borrow_global_mut};
    use sui::tx_context::TxContext;
    use IdentityTypes::CredentialInfo;

    /// Issue a new credential: links a credential hash to a subject DID
    public entry fun issue_credential(
        ctx: &mut TxContext,
        subject: ID<DIDInfo>,
        schema: vector<u8>,
        data_hash: vector<u8>
    ) {
        let issuer = TxContext::sender(ctx);
        let ts = TxContext::timestamp(ctx);
        let cred = CredentialInfo {
            id: UID::new(ctx),
            subject,
            issuer,
            schema,
            data_hash,
            revoked: false,
            issued_at: ts
        };
        move_to(ctx, cred);
    }

    /// Revoke an existing credential (issuer-only)
    public entry fun revoke_credential(
        ctx: &mut TxContext,
        cred_id: ID<CredentialInfo>
    ) {
        let caller = TxContext::sender(ctx);
        let mut cred = borrow_global_mut<CredentialInfo>(ID::id_of(&cred_id));
        assert!(caller == cred.issuer, 4);
        cred.revoked = true;
    }
}
}