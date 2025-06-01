# Suibotics DID

A production-ready decentralized identity and credential management system built on the Sui blockchain, designed specifically for IoT devices and robotics applications with full W3C DID Core specification compliance.

## Overview

Suibotics DID provides a comprehensive framework for managing digital identities and verifiable credentials in IoT ecosystems. The system enables secure device authentication, credential issuance, and trust establishment between IoT devices, certificate authorities, and service providers. Built with type safety, comprehensive validation, and production-grade error handling.

## Features

### Decentralized Identity (DID) Management
- **DID Registration**: Create unique decentralized identifiers for IoT devices
- **Key Management**: Add, revoke, and manage cryptographic keys with type-safe dynamic field handling
- **Service Endpoints**: Complete service lifecycle management (add, update, remove)
- **Controller Verification**: Ensure only authorized entities can modify DID documents
- **W3C DID Document Resolution**: Full compliance with W3C DID Core specification
- **Type-Safe Architecture**: Prevents key/service ID collisions with wrapper structs

### Verifiable Credentials
- **Credential Issuance**: Issue tamper-proof credentials to devices
- **Schema Validation**: Support for structured credential schemas
- **Revocation Management**: Revoke credentials when necessary
- **Timestamp Tracking**: Track credential issuance and revocation times

### Security Features
- **Input Validation**: Comprehensive validation for all inputs
- **Access Control**: Role-based access control for DID and credential operations
- **Event Logging**: Immutable event logs for all operations with comprehensive change tracking
- **Error Handling**: Robust error handling with descriptive error codes
- **Type Safety**: Dynamic field type confusion prevention with KeyFieldKey/ServiceFieldKey wrappers

### W3C Standards Compliance
- **DID Documents**: Full W3C DID Core specification compliance
- **Verification Methods**: Support for multiple key types and purposes
- **Service Endpoints**: Standards-compliant service registration and management
- **Resolution**: Complete DID document resolution from on-chain data

## Architecture

The system consists of three focused modules with clean separation of concerns:

1. **identity_types** (`sources/identity_types.move`): Core data structures, validation logic, and W3C DID document building
2. **did_registry** (`sources/did_registry.move`): DID registration, key management, and service lifecycle
3. **credential_registry** (`sources/credential_registry.move`): Credential issuance and revocation

### Key Architectural Improvements
- **Type-Safe Dynamic Fields**: Separate namespaces for keys and services prevent ID collisions
- **DID Document Resolution**: On-chain data structures that build W3C-compliant DID documents
- **Service Lifecycle Management**: Complete add → update → remove workflow with audit trails
- **Production-Ready Patterns**: Comprehensive error handling, validation, and event emission

## Prerequisites

- **Sui CLI**: Version 1.49.1 or later
- **Move Language**: Compatible with Sui Move framework

### Installing Sui CLI

```bash
# macOS (using Homebrew)
brew install sui

# Or update existing installation
brew update && brew upgrade sui

# Verify installation
sui --version
```

## Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd suibotics_did
   ```

2. **Build the project**:
   ```bash
   sui move build
   ```

3. **Run tests**:
   ```bash
   sui move test
   ```

## Testing

The project includes comprehensive test suites covering all major functionality with extensive edge case testing:

### Test Files
- `tests/did_registry_tests.move`: 17 tests covering DID registration, key management, service lifecycle, and W3C compliance
- `tests/simple_test.move`: 6 integration tests covering basic workflows
- `tests/suibotics_did_tests.move`: End-to-end scenario tests

### Running Tests

```bash
# Run all tests
sui move test

# Run specific test module
sui move test did_registry_tests

# Run with verbose output
sui move test --verbose
```

### Test Coverage

✅ **24/24 tests passing** - 100% test success rate

**Test Categories:**
- DID Registration and Management
- Key Addition and Revocation
- Service Endpoint Lifecycle Management (add/update/remove)
- W3C DID Document Resolution
- Type-Safe Dynamic Field Handling
- Credential Issuance and Revocation
- Access Control and Security
- Input Validation and Error Handling
- Edge Cases and Collision Prevention

## Usage Examples

### Registering a DID

```move
// Initialize the DID registry
did_registry::test_init(ctx);

// Register a new DID
did_registry::register_did(
    &mut registry,
    b"device_001",           // DID name
    device_public_key,       // Device's public key
    b"authentication",       // Key purpose
    ctx
);
```

### Managing Keys

```move
// Add a new key for signing operations
did_registry::add_key(
    &mut did_info,
    b"signing_key",          // Key identifier
    signing_public_key,      // Public key
    b"assertion",            // Key purpose
    ctx
);

// Revoke a key
did_registry::revoke_key(
    &mut did_info,
    b"signing_key",          // Key identifier to revoke
    ctx
);
```

### Service Lifecycle Management

```move
// Add an MQTT service endpoint
did_registry::add_service(
    &mut did_info,
    b"mqtt_broker",          // Service ID
    b"MQTTBroker",          // Service type
    b"mqtt://device.local:1883", // Endpoint URL
    ctx
);

// Update the service endpoint
did_registry::update_service(
    &mut did_info,
    b"mqtt_broker",          // Service ID
    b"MQTTBroker",          // New service type
    b"mqtt://device.local:8883", // New endpoint URL
    ctx
);

// Remove the service
did_registry::remove_service(
    &mut did_info,
    b"mqtt_broker",          // Service ID to remove
    ctx
);
```

### W3C DID Document Resolution

```move
// Build a complete W3C-compliant DID document
let did_document = did_registry::build_did_document(
    &did_info,
    verification_methods,    // Custom verification methods
    services,               // Custom services
);

// Or build with basic configuration
let basic_document = did_registry::build_basic_did_document(&did_info);
```

### Issuing Credentials

```move
// Issue a firmware attestation credential
credential_registry::issue_credential(
    device_address,          // Credential subject
    b"FirmwareAttestation",  // Credential schema
    firmware_hash,           // Data hash
    ctx
);
```

## Error Codes

The system uses standardized error codes for consistent error handling:

- `1`: Invalid controller (unauthorized access)
- `2`: Key not found
- `3`: Key already exists
- `4`: Name already exists
- `5`: Invalid public key
- `6`: Invalid data hash
- `7`: Empty field
- `8`: Field too long
- `9`: Invalid address

## Events

The system emits comprehensive events for all major operations with detailed change tracking:

### DID Events
- `DIDRegistered`: When a new DID is registered
- `KeyAdded`: When a key is added to a DID
- `KeyRevoked`: When a key is revoked
- `ServiceAdded`: When a service endpoint is added
- `ServiceUpdated`: When a service endpoint is updated (with old/new values)
- `ServiceRemoved`: When a service endpoint is removed

### Credential Events
- `CredentialIssued`: When a credential is issued
- `CredentialRevoked`: When a credential is revoked

## Development

### Project Structure

```
suibotics_did/
├── sources/
│   ├── identity_types.move     # Core data structures & W3C DID document building
│   ├── did_registry.move       # DID management & service lifecycle
│   └── credential_registry.move # Credential management
├── tests/
│   ├── did_registry_tests.move  # DID functionality tests (17 tests)
│   ├── simple_test.move         # Integration tests (6 tests)
│   └── suibotics_did_tests.move # End-to-end tests (1 test)
├── Move.toml                   # Project configuration
├── deploy_testnet.sh           # Comprehensive testnet deployment script
├── deploy_simple.sh            # Simple testnet deployment script
└── README.md                   # This file
```

### Code Statistics
- **Total Source Code**: ~32KB across 3 modules
- **Lines of Code**: 1,029 lines (583 + 377 + 69)
- **Test Coverage**: 24 comprehensive tests
- **Production Readiness**: Type-safe, well-documented, follows Sui best practices

## Deployment

### Testnet Deployment

Two deployment scripts are provided for testnet deployment:

#### Option 1: Comprehensive Deployment (Recommended)
```bash
./deploy_testnet.sh
```

This script provides:
- ✅ Comprehensive pre-deployment checks
- ✅ Automatic environment setup
- ✅ Gas balance verification and faucet requests
- ✅ Build and test validation
- ✅ Detailed logging and error handling
- ✅ Post-deployment verification
- ✅ Explorer links and deployment info

#### Option 2: Quick Deployment
```bash
./deploy_simple.sh
```

This script provides:
- ⚡ Fast deployment with minimal checks
- 🎯 Essential steps only
- 📦 Package ID extraction
- 🔗 Explorer links

### Prerequisites for Deployment
- Sui CLI installed (version 1.49.1+)
- Active Sui wallet
- `jq` installed for JSON parsing (optional but recommended)

### Manual Deployment
If you prefer manual deployment:

```bash
# Switch to testnet
sui client switch --env testnet

# Request testnet tokens
sui client faucet

# Build and test
sui move build
sui move test

# Deploy
sui client publish --gas-budget 100000000
```

### Post-Deployment
After successful deployment, you'll receive:
- **Package ID**: Use this to interact with your deployed modules
- **Transaction Digest**: For verification on blockchain explorers
- **Explorer Links**: View your deployment on Sui explorers

The deployment information is automatically saved to `deployment_info.json` for future reference.

## Standards Compliance

### W3C DID Core Specification
- ✅ DID Method Implementation
- ✅ DID Document Structure
- ✅ Verification Method Support
- ✅ Service Endpoint Management
- ✅ Controller Authorization
- ✅ Resolution Interface

### Security Best Practices
- ✅ Type-Safe Dynamic Field Access
- ✅ Comprehensive Input Validation
- ✅ Access Control Enforcement
- ✅ Event Logging and Audit Trails
- ✅ Error Handling and Recovery

## Contributing

1. Ensure all tests pass: `sui move test`
2. Follow Move coding conventions
3. Add tests for new functionality
4. Update documentation as needed
5. Maintain type safety and validation patterns

## License

[Add your license information here]