#!/usr/bin/env ts-node

/**
 * Key Generation Utility for Crossy Robot E2E Testing
 * 
 * This script generates Ed25519 keypairs and displays:
 * - Private key (base64 encoded, for .env file)
 * - Public key (hex encoded)
 * - Sui address (for wallet identification)
 */

import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';

interface KeyInfo {
  role: string;
  privateKey: string;
  publicKey: string;
  suiAddress: string;
}

function generateKeypair(role: string): KeyInfo {
  const keypair = new Ed25519Keypair();
  
  return {
    role,
    privateKey: keypair.getSecretKey(),
    publicKey: keypair.getPublicKey().toBase64(),
    suiAddress: keypair.getPublicKey().toSuiAddress()
  };
}

function displayKeyInfo(keyInfo: KeyInfo): void {
  console.log(`🔑 ${keyInfo.role} Wallet:`);
  console.log(`   Private Key: ${keyInfo.privateKey}`);
  console.log(`   Public Key:  ${keyInfo.publicKey}`);
  console.log(`   Sui Address: ${keyInfo.suiAddress}`);
  console.log('');
}

function generateEnvFile(userKey: KeyInfo, robotKey: KeyInfo): string {
  return `# Crossy Robot E2E Test Configuration
# Generated on ${new Date().toISOString()}

# User wallet private key (creates games)
USER_PRIVATE_KEY=${userKey.privateKey}

# Robot wallet private key (connects to games)
ROBOT_PRIVATE_KEY=${robotKey.privateKey}

# Sui network configuration
SUI_NETWORK=testnet
SUI_RPC_URL=https://fullnode.testnet.sui.io:443

# Optional: Custom gas budget (default: 10000000)
GAS_BUDGET=10000000

# Optional: Test configuration
TEST_TIMEOUT_MS=30000
MOVEMENT_DELAY_MS=2000

# Wallet addresses for reference:
# User Address:  ${userKey.suiAddress}
# Robot Address: ${robotKey.suiAddress}
`;
}

async function main() {
  console.log('🤖 Crossy Robot Key Generator\n');
  
  // Generate keypairs
  console.log('🔐 Generating new keypairs...\n');
  
  const userKey = generateKeypair('User');
  const robotKey = generateKeypair('Robot');
  
  // Display key information
  displayKeyInfo(userKey);
  displayKeyInfo(robotKey);
  
  // Generate .env file content
  const envContent = generateEnvFile(userKey, robotKey);
  
  console.log('📄 .env file content:');
  console.log('─'.repeat(60));
  console.log(envContent);
  console.log('─'.repeat(60));
  console.log('');
  
  // Instructions
  console.log('📋 Next Steps:');
  console.log('');
  console.log('1. Copy the .env content above to a .env file:');
  console.log('   echo "..." > .env');
  console.log('');
  console.log('2. Fund both wallets with testnet SUI:');
  console.log('   🌐 Visit: https://faucet.sui.io/');
  console.log(`   👤 User Address:  ${userKey.suiAddress}`);
  console.log(`   🤖 Robot Address: ${robotKey.suiAddress}`);
  console.log('');
  console.log('3. Required balances:');
  console.log('   👤 User wallet:  ~0.1 SUI (0.05 for game + gas)');
  console.log('   🤖 Robot wallet: ~0.05 SUI (for gas)');
  console.log('');
  console.log('4. Run the E2E test:');
  console.log('   npm test');
  console.log('');
  console.log('🔒 Security Note:');
  console.log('   These are test keys for testnet only!');
  console.log('   Never use generated keys for mainnet or real funds!');
}

// Run the generator
if (require.main === module) {
  main().catch(console.error);
} 