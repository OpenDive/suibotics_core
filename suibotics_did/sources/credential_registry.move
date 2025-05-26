module suibotics_did::credential_registry {
    use sui::tx_context::{TxContext, sender};
    use suibotics_did::identity_types::{
        CredentialInfo, new_credential_info, transfer_credential_info,
        credential_info_issuer, revoke_credential_info, credential_info_revoked,
        credential_info_subject, credential_info_schema, credential_info_data_hash,
        credential_info_issued_at, validate_address, validate_schema, validate_data_hash,
        e_invalid_controller
    };

    /// Issue a new credential: creates a credential object and transfers it to the subject
    public entry fun issue_credential(
        subject: address,             // Address of the subject DID controller
        schema: vector<u8>,
        data_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        let issuer = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        // Validation is handled in new_credential_info
        let cred = new_credential_info(subject, issuer, schema, data_hash, ts, ctx);
        
        // Transfer credential to the subject
        transfer_credential_info(cred, subject);
    }

    /// Revoke an existing credential (issuer-only)
    public entry fun revoke_credential(
        cred: &mut CredentialInfo,
        ctx: &mut TxContext
    ) {
        let caller = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        assert!(caller == credential_info_issuer(cred), e_invalid_controller());
        revoke_credential_info(cred, ts);
    }

    /// Check if a credential is revoked
    public fun is_revoked(cred: &CredentialInfo): bool {
        credential_info_revoked(cred)
    }

    /// Get credential issuer
    public fun get_issuer(cred: &CredentialInfo): address {
        credential_info_issuer(cred)
    }

    /// Get credential subject
    public fun get_subject(cred: &CredentialInfo): address {
        credential_info_subject(cred)
    }

    /// Get credential schema
    public fun get_schema(cred: &CredentialInfo): &vector<u8> {
        credential_info_schema(cred)
    }

    /// Get credential data hash
    public fun get_data_hash(cred: &CredentialInfo): &vector<u8> {
        credential_info_data_hash(cred)
    }

    /// Get credential issuance timestamp
    public fun get_issued_at(cred: &CredentialInfo): u64 {
        credential_info_issued_at(cred)
    }
}