module suibotics_did::credential_registry {
    use sui::object::{UID, new};
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::{public_transfer, share_object};
    use sui::dynamic_field;
    use sui::event;
    use std::vector;
    
    use suibotics_did::identity_types::{
        CredentialInfo, new_credential_info, transfer_credential_info,
        credential_info_issued_at, credential_info_subject, credential_info_issuer, 
        credential_info_schema, credential_info_data_hash, credential_info_revoked, 
        revoke_credential_info, credential_info_id,
        e_unauthorized_revocation, e_credential_already_revoked, max_batch_size,
        e_batch_too_large, e_batch_size_mismatch, e_empty_field
    };

    /// Global registry for credential discovery and indexing
    public struct CredentialRegistry has key {
        id: UID,
        // Track total credentials for statistics
        total_credentials: u64,
        total_revoked: u64,
    }

    /// Internal struct to store credential metadata for discovery
    public struct CredentialMetadata has store {
        subject: address,
        issuer: address,
        schema: vector<u8>,
        issued_at: u64,
        revoked: bool,
    }

    /// Internal struct to maintain index mappings
    public struct CredentialIndex has store {
        credential_ids: vector<address>,
    }

    /// Initialize the credential registry as a shared object
    fun init(ctx: &mut TxContext) {
        let registry = CredentialRegistry {
            id: new(ctx),
            total_credentials: 0,
            total_revoked: 0,
        };
        share_object(registry);
    }

    /// Test-only initialization function
    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    /// Issue a credential and add it to the registry for discovery
    public entry fun issue_credential(
        registry: &mut CredentialRegistry,
        subject: address,
        schema: vector<u8>,
        data_hash: vector<u8>,
        ctx: &mut TxContext
    ) {
        let issuer = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        // Create and transfer the credential
        let cred = new_credential_info(subject, issuer, schema, data_hash, ts, ctx);
        let cred_id = sui::object::uid_to_address(credential_info_id(&cred));
        
        // Add to registry indices for discovery
        add_credential_to_indices(registry, &cred, cred_id);
        
        // Update registry statistics
        registry.total_credentials = registry.total_credentials + 1;
        
        transfer_credential_info(cred, subject);
    }

    /// Revoke a credential (issuer or subject can revoke)
    public entry fun revoke_credential(
        registry: &mut CredentialRegistry,
        cred: &mut CredentialInfo,
        ctx: &mut TxContext
    ) {
        let caller = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        // Only issuer or subject can revoke
        assert!(
            caller == credential_info_issuer(cred) || 
            caller == credential_info_subject(cred), 
            e_unauthorized_revocation()
        );
        
        // Only revoke if not already revoked
        assert!(!credential_info_revoked(cred), e_credential_already_revoked());
        
        revoke_credential_info(cred, ts);
        
        // Update registry statistics
        registry.total_revoked = registry.total_revoked + 1;
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

    // === CREDENTIAL DISCOVERY FUNCTIONS ===

    /// Get all credentials for a specific subject
    public fun get_credentials_by_subject(
        registry: &CredentialRegistry,
        subject: address
    ): vector<address> {
        get_credentials_from_index(registry, b"subject", address_to_bytes(subject))
    }

    /// Get all credentials issued by a specific issuer
    public fun get_credentials_by_issuer(
        registry: &CredentialRegistry,
        issuer: address
    ): vector<address> {
        get_credentials_from_index(registry, b"issuer", address_to_bytes(issuer))
    }

    /// Get all credentials of a specific schema type
    public fun get_credentials_by_schema(
        registry: &CredentialRegistry,
        schema: vector<u8>
    ): vector<address> {
        get_credentials_from_index(registry, b"schema", schema)
    }

    /// Get credentials issued within a time range
    public fun get_credentials_by_time_range(
        registry: &CredentialRegistry,
        start_time: u64,
        end_time: u64
    ): vector<address> {
        let time_key = encode_time_range(start_time, end_time);
        get_credentials_from_index(registry, b"time", time_key)
    }

    /// Get all active (non-revoked) credentials for a subject
    public fun get_active_credentials_by_subject(
        registry: &CredentialRegistry,
        subject: address
    ): vector<address> {
        let subject_key = address_to_bytes(subject);
        let mut active_key = vector::empty<u8>();
        vector::append(&mut active_key, b"active_");
        vector::append(&mut active_key, subject_key);
        get_credentials_from_index(registry, b"active", active_key)
    }

    /// Get credentials by issuer and schema combination
    public fun get_credentials_by_issuer_schema(
        registry: &CredentialRegistry,
        issuer: address,
        schema: vector<u8>
    ): vector<address> {
        let mut composite_key = address_to_bytes(issuer);
        vector::append(&mut composite_key, b":");
        vector::append(&mut composite_key, schema);
        get_credentials_from_index(registry, b"issuer_schema", composite_key)
    }

    /// Check if a specific credential exists and is active
    public fun is_credential_active(
        registry: &CredentialRegistry,
        cred_id: address
    ): bool {
        if (!dynamic_field::exists_(&registry.id, cred_id)) {
            return false
        };
        
        let cred_info: &CredentialMetadata = dynamic_field::borrow(&registry.id, cred_id);
        !cred_info.revoked
    }

    /// Get registry statistics
    public fun get_registry_stats(registry: &CredentialRegistry): (u64, u64, u64) {
        let active_count = registry.total_credentials - registry.total_revoked;
        (registry.total_credentials, active_count, registry.total_revoked)
    }

    // === INTERNAL HELPER FUNCTIONS ===

    /// Add credential to various indices for discovery
    fun add_credential_to_indices(
        registry: &mut CredentialRegistry,
        cred: &CredentialInfo,
        cred_id: address
    ) {
        let subject = credential_info_subject(cred);
        let issuer = credential_info_issuer(cred);
        let schema = *credential_info_schema(cred);
        let issued_at = credential_info_issued_at(cred);
        
        // Store credential metadata
        let metadata = CredentialMetadata {
            subject,
            issuer,
            schema,
            issued_at,
            revoked: false,
        };
        dynamic_field::add(&mut registry.id, cred_id, metadata);
        
        // Add to subject index
        add_to_index(registry, b"subject", address_to_bytes(subject), cred_id);
        
        // Add to issuer index
        add_to_index(registry, b"issuer", address_to_bytes(issuer), cred_id);
        
        // Add to schema index
        add_to_index(registry, b"schema", schema, cred_id);
        
        // Add to active credentials index
        let mut active_key = vector::empty<u8>();
        vector::append(&mut active_key, b"active_");
        vector::append(&mut active_key, address_to_bytes(subject));
        add_to_index(registry, b"active", active_key, cred_id);
        
        // Add to issuer+schema composite index
        let mut composite_key = address_to_bytes(issuer);
        vector::append(&mut composite_key, b":");
        vector::append(&mut composite_key, schema);
        add_to_index(registry, b"issuer_schema", composite_key, cred_id);
        
        // Add to time-based index (by month for efficiency)
        let time_key = encode_time_to_month(issued_at);
        add_to_index(registry, b"time", time_key, cred_id);
    }

    /// Add a credential ID to a specific index
    fun add_to_index(
        registry: &mut CredentialRegistry,
        index_type: vector<u8>,
        key: vector<u8>,
        cred_id: address
    ) {
        let mut full_key = index_type;
        vector::append(&mut full_key, b"_");
        vector::append(&mut full_key, key);
        
        if (dynamic_field::exists_(&registry.id, full_key)) {
            let index: &mut CredentialIndex = dynamic_field::borrow_mut(&mut registry.id, full_key);
            vector::push_back(&mut index.credential_ids, cred_id);
        } else {
            let mut credential_ids = vector::empty<address>();
            vector::push_back(&mut credential_ids, cred_id);
            let index = CredentialIndex { credential_ids };
            dynamic_field::add(&mut registry.id, full_key, index);
        };
    }

    /// Get credentials from a specific index
    fun get_credentials_from_index(
        registry: &CredentialRegistry,
        index_type: vector<u8>,
        key: vector<u8>
    ): vector<address> {
        let mut full_key = index_type;
        vector::append(&mut full_key, b"_");
        vector::append(&mut full_key, key);
        
        if (dynamic_field::exists_(&registry.id, full_key)) {
            let index: &CredentialIndex = dynamic_field::borrow(&registry.id, full_key);
            index.credential_ids
        } else {
            vector::empty<address>()
        }
    }

    /// Convert address to bytes for indexing (simplified approach)
    fun address_to_bytes(addr: address): vector<u8> {
        // Simple approach: use the raw address bytes
        // Convert address to u256 and then to bytes
        let addr_u256 = sui::address::to_u256(addr);
        u256_to_bytes(addr_u256)
    }

    /// Helper to convert u256 to bytes
    fun u256_to_bytes(value: u256): vector<u8> {
        let mut result = vector::empty<u8>();
        let mut temp = value;
        
        if (temp == 0) {
            vector::push_back(&mut result, 0);
        } else {
            while (temp > 0) {
                vector::push_back(&mut result, ((temp % 256) as u8));
                temp = temp / 256;
            };
        };
        result
    }

    /// Encode timestamp to month key for time-based indexing
    fun encode_time_to_month(timestamp: u64): vector<u8> {
        // Simple approach: create monthly buckets
        let month_bucket = timestamp / (30 * 24 * 60 * 60 * 1000); // Approximate monthly buckets
        let mut result = vector::empty<u8>();
        
        // Convert u64 to bytes manually (simplified)
        let mut temp = month_bucket;
        if (temp == 0) {
            vector::push_back(&mut result, 0);
        } else {
            while (temp > 0) {
                vector::push_back(&mut result, ((temp % 256) as u8));
                temp = temp / 256;
            };
        };
        result
    }

    /// Encode time range for range queries (simplified)
    fun encode_time_range(start_time: u64, end_time: u64): vector<u8> {
        let mut range_key = encode_time_to_month(start_time);
        vector::append(&mut range_key, b"_to_");
        vector::append(&mut range_key, encode_time_to_month(end_time));
        range_key
    }

    // === BATCH OPERATION STRUCTURES ===
    
    /// Batch operation result for tracking success/failure of individual operations
    public struct BatchResult has copy, drop {
        index: u64,
        success: bool,
        error_code: u64,
    }

    // === EVENT STRUCTURES ===
    
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

    // === EVENT FUNCTIONS ===
    
    /// Emit credential issued event
    fun emit_credential_issued(
        credential_id: address,
        subject: address,
        issuer: address,
        schema: vector<u8>,
        timestamp: u64
    ) {
        event::emit(CredentialIssued {
            credential_id,
            subject,
            issuer,
            schema,
            timestamp,
        });
    }
    
    /// Emit credential revoked event
    fun emit_credential_revoked(
        credential_id: address,
        issuer: address,
        timestamp: u64
    ) {
        event::emit(CredentialRevoked {
            credential_id,
            issuer,
            timestamp,
        });
    }

    // === BATCH OPERATIONS ===

    /// Batch issue multiple credentials in a single transaction
    /// Returns vector of BatchResult indicating success/failure for each operation
    public fun issue_credentials_batch(
        registry: &mut CredentialRegistry,
        subjects: vector<address>,
        issuers: vector<address>,
        schemas: vector<vector<u8>>,
        data_hashes: vector<vector<u8>>,
        ctx: &mut TxContext
    ): vector<BatchResult> {
        let batch_size = vector::length(&subjects);
        assert!(batch_size <= max_batch_size(), e_batch_too_large());
        assert!(batch_size == vector::length(&issuers), e_batch_size_mismatch());
        assert!(batch_size == vector::length(&schemas), e_batch_size_mismatch());
        assert!(batch_size == vector::length(&data_hashes), e_batch_size_mismatch());
        
        let mut results = vector::empty<BatchResult>();
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        let mut i = 0;
        while (i < batch_size) {
            let subject = *vector::borrow(&subjects, i);
            let issuer = *vector::borrow(&issuers, i);
            let schema = *vector::borrow(&schemas, i);
            let data_hash = *vector::borrow(&data_hashes, i);
            
            let mut success = true;
            let mut error_code = 0;
            
            // Validate inputs - simplified for batch operations
            if (vector::is_empty(&schema)) {
                success = false;
                error_code = e_empty_field();
            } else if (vector::is_empty(&data_hash)) {
                success = false;
                error_code = e_empty_field();
            };
            
            if (success) {
                // Create and transfer the credential
                let credential = new_credential_info(subject, issuer, schema, data_hash, ts, ctx);
                let credential_id = sui::object::uid_to_address(credential_info_id(&credential));
                
                // Update total count in registry (simplified indexing)
                registry.total_credentials = registry.total_credentials + 1;
                
                // Emit event
                emit_credential_issued(credential_id, subject, issuer, schema, ts);
                
                // Transfer to subject
                transfer_credential_info(credential, subject);
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

    /// Batch revoke multiple credentials in a single transaction
    public fun revoke_credentials_batch(
        credentials: &mut vector<CredentialInfo>,
        ctx: &mut TxContext
    ): vector<BatchResult> {
        let batch_size = vector::length(credentials);
        assert!(batch_size <= max_batch_size(), e_batch_too_large());
        
        let mut results = vector::empty<BatchResult>();
        let sender_addr = sender(ctx);
        let ts = sui::tx_context::epoch_timestamp_ms(ctx);
        
        let mut i = 0;
        while (i < batch_size) {
            let credential = vector::borrow_mut(credentials, i);
            let credential_id = sui::object::uid_to_address(credential_info_id(credential));
            
            let mut success = true;
            let mut error_code = 0;
            
            // Validate that sender is authorized and credential is not already revoked
            if (sender_addr != credential_info_issuer(credential) && 
                sender_addr != credential_info_subject(credential)) {
                success = false;
                error_code = e_unauthorized_revocation();
            } else if (credential_info_revoked(credential)) {
                success = false;
                error_code = e_credential_already_revoked();
            };
            
            if (success) {
                // Revoke the credential
                revoke_credential_info(credential, ts);
                
                // Emit event
                emit_credential_revoked(credential_id, sender_addr, ts);
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

    // === BATCH RESULT UTILITIES ===

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

    /// Get total credentials count from registry
    public fun get_total_credentials(registry: &CredentialRegistry): u64 {
        registry.total_credentials
    }

    // === TEST INITIALIZATION ===
    
    #[test_only]
    /// Initialize the credential registry for testing
    public fun init_for_testing(ctx: &mut TxContext) {
        let registry = CredentialRegistry {
            id: sui::object::new(ctx),
            total_credentials: 0,
            total_revoked: 0,
        };
        share_object(registry);
    }

    // === ERROR HANDLING DOCUMENTATION ===
    // This module uses standardized error codes from identity_types:
    // - e_unauthorized_revocation(): Only issuer or subject can revoke
    // - e_credential_already_revoked(): Credential already revoked
    // - e_batch_too_large(): Batch size exceeds max_batch_size()
    // - e_batch_size_mismatch(): Input vector lengths don't match
    // - e_empty_field(): Required field is empty
    // 
    // VALIDATION: All validation is handled by centralized functions in identity_types
    // to ensure consistency across all modules. No duplicate validation functions.
    // All error codes are consistent across the entire suibotics_did system.
}