# Suibotics Core

A decentralized identity and credential management system built on the Sui blockchain, designed specifically for IoT devices and robotics applications.

## Overview

Suibotics Core provides a comprehensive framework for managing digital identities and verifiable credentials in IoT ecosystems. The system enables secure device authentication, credential issuance, and trust establishment between IoT devices, certificate authorities, and service providers.

## Features

### 🔐 Decentralized Identity (DID) Management
- **DID Registration**: Create unique decentralized identifiers for IoT devices
- **Key Management**: Add, revoke, and manage cryptographic keys for devices
- **Service Endpoints**: Register and manage service endpoints for device communication
- **Controller Verification**: Ensure only authorized entities can modify DID documents

### 📜 Verifiable Credentials
- **Credential Issuance**: Issue tamper-proof credentials to devices
- **Schema Validation**: Support for structured credential schemas
- **Revocation Management**: Revoke credentials when necessary
- **Timestamp Tracking**: Track credential issuance and revocation times

### 🛡️ Security Features
- **Input Validation**: Comprehensive validation for all inputs
- **Access Control**: Role-based access control for DID and credential operations
- **Event Logging**: Immutable event logs for all operations
- **Error Handling**: Robust error handling with descriptive error codes

## Architecture

The system consists of three main modules:

1. **IdentityTypes** (`sources/IdentityTypes.move`): Core data structures and validation logic
2. **DidRegistry** (`sources/DidRegistry.move`): DID registration and management
3. **CredentialRegistry** (`sources/CredentialRegistry.move`): Credential issuance and revocation

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
   cd suibotics_core
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

The project includes comprehensive test suites covering all major functionality:

### Test Files
- `tests/did_registry_tests.move`: 13 tests covering DID registration, key management, and service endpoints
- `tests/simple_test.move`: 6 integration tests covering basic workflows
- `tests/suibotics_core_tests.move`: End-to-end scenario tests

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

✅ **18/18 tests passing** - 100% test success rate

**Test Categories:**
- DID Registration and Management
- Key Addition and Revocation
- Service Endpoint Management
- Credential Issuance and Revocation
- Access Control and Security
- Input Validation
- Error Handling

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

### Adding a Key to DID

```move
// Add a new key for signing operations
did_registry::add_key(
    &mut did_info,
    b"signing_key",          // Key identifier
    signing_public_key,      // Public key
    b"assertion",            // Key purpose
    ctx
);
```

### Issuing a Credential

```move
// Issue a firmware attestation credential
credential_registry::issue_credential(
    device_address,          // Credential subject
    b"FirmwareAttestation",  // Credential schema
    firmware_hash,           // Data hash
    ctx
);
```

### Adding a Service Endpoint

```move
// Add an MQTT service endpoint
did_registry::add_service(
    &mut did_info,
    b"mqtt_broker",          // Service ID
    b"MQTTBroker",          // Service type
    b"mqtt://device.local:1883", // Endpoint URL
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

The system emits events for all major operations:

- `DIDRegistered`: When a new DID is registered
- `KeyAdded`: When a key is added to a DID
- `KeyRevoked`: When a key is revoked
- `ServiceAdded`: When a service endpoint is added
- `CredentialIssued`: When a credential is issued
- `CredentialRevoked`: When a credential is revoked

## Development

### Project Structure

```
suibotics_core/
├── sources/
│   ├── IdentityTypes.move      # Core data structures
│   ├── DidRegistry.move        # DID management
│   └── CredentialRegistry.move # Credential management
├── tests/
│   ├── did_registry_tests.move # DID functionality tests
│   ├── simple_test.move        # Integration tests
│   └── suibotics_core_tests.move # End-to-end tests
├── Move.toml                   # Project configuration
└── README.md                   # This file
```

### Contributing

1. Ensure all tests pass: `sui move test`
2. Follow Move coding conventions
3. Add tests for new functionality
4. Update documentation as needed

## License

[Add your license information here]

## Support

For questions and support, please [add contact information or issue tracker link].