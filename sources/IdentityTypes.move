address 0xRobotID {
    module IdentityTypes {
        use sui::object::UID;
        use sui::object::ID;

        /// A DID object resource. Owned by its controller.
        struct DIDInfo has key {
            id: UID,
            controller: address,
            created_at: u64,        // timestamp in milliseconds
        }

        /// A verification method (public key) attached to a DIDInfo.
        struct KeyInfo has store {
            pubkey: vector<u8>,     // raw Ed25519 public key bytes
            purpose: vector<u8>,    // e.g. b"authentication"
            revoked: bool,          // revocation flag
        }

        /// A service endpoint entry in a DID Document.
        struct ServiceInfo has store {
            id: vector<u8>,         // fragment, e.g. b"mqtt1"
            type_: vector<u8>,      // e.g. b"MQTTBroker"
            endpoint: vector<u8>,   // e.g. b"wss://host:port"
        }

        /// An on-chain verifiable credential record.
        struct CredentialInfo has key {
            id: UID,
            subject: ID<DIDInfo>,   // DID object this credential refers to
            issuer: address,        // controller address of the issuer DID
            schema: vector<u8>,     // e.g. b"FirmwareCertV1"
            data_hash: vector<u8>,  // SHA-256 hash of the off-chain VC JSON
            revoked: bool,          // revocation flag
            issued_at: u64,         // issuance timestamp
        }
    }
}