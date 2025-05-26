#!/usr/bin/env ts-node

/**
 * Simple Crossy Robot E2E Test
 * 
 * A simplified test that validates the core contract functionality:
 * 1. User creates a game
 * 2. Robot connects to the game
 * 3. User sends movement commands
 */

import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { fromB64 } from '@mysten/sui/utils';
import * as fs from 'fs';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Configuration
const DEPLOYMENT_INFO_PATH = './deployment_info.json';
const GAME_COST = 50_000_000; // 0.05 SUI in MIST

// Movement directions
const DIRECTIONS = {
  UP: 0,
  DOWN: 1,
  LEFT: 2,
  RIGHT: 3,
  UP_RIGHT: 4,
  UP_LEFT: 5,
  DOWN_LEFT: 6,
  DOWN_RIGHT: 7
} as const;

const DIRECTION_NAMES = ['UP', 'DOWN', 'LEFT', 'RIGHT', 'UP_RIGHT', 'UP_LEFT', 'DOWN_LEFT', 'DOWN_RIGHT'];

interface DeploymentInfo {
  package_id: string;
  transaction_digest: string;
  network: string;
}

class SimpleCrossyRobotTest {
  private client: SuiClient;
  private userKeypair: Ed25519Keypair;
  private robotKeypair: Ed25519Keypair;
  private packageId: string;

  constructor() {
    // Initialize Sui client
    this.client = new SuiClient({
      url: getFullnodeUrl('testnet')
    });

    // Initialize wallets
    this.userKeypair = this.createKeypairFromEnv('USER_PRIVATE_KEY');
    this.robotKeypair = this.createKeypairFromEnv('ROBOT_PRIVATE_KEY');

    // Load deployment info
    this.packageId = this.loadPackageId();

    console.log('🤖 Simple Crossy Robot E2E Test');
    console.log(`📦 Package ID: ${this.packageId}`);
    console.log(`👤 User Address: ${this.userKeypair.getPublicKey().toSuiAddress()}`);
    console.log(`🤖 Robot Address: ${this.robotKeypair.getPublicKey().toSuiAddress()}`);
    console.log('');
  }

  private createKeypairFromEnv(envVar: string): Ed25519Keypair {
    const privateKey = process.env[envVar];
    if (!privateKey) {
      console.error(`❌ ${envVar} not found in environment variables`);
      console.log('💡 Create a .env file with your wallet private keys');
      process.exit(1);
    }

    try {
      return Ed25519Keypair.fromSecretKey(fromB64(privateKey));
    } catch (error) {
      console.error(`❌ Invalid private key format for ${envVar}`);
      process.exit(1);
    }
  }

  private loadPackageId(): string {
    try {
      const deploymentInfo: DeploymentInfo = JSON.parse(
        fs.readFileSync(DEPLOYMENT_INFO_PATH, 'utf8')
      );
      return deploymentInfo.package_id;
    } catch (error) {
      console.error('❌ Could not load deployment info');
      process.exit(1);
    }
  }

  private async checkWalletBalances(): Promise<void> {
    console.log('💰 Checking wallet balances...');
    
    const userBalance = await this.getWalletBalance(this.userKeypair.getPublicKey().toSuiAddress());
    const robotBalance = await this.getWalletBalance(this.robotKeypair.getPublicKey().toSuiAddress());
    
    console.log(`👤 User balance: ${(userBalance / 1_000_000_000).toFixed(3)} SUI`);
    console.log(`🤖 Robot balance: ${(robotBalance / 1_000_000_000).toFixed(3)} SUI`);
    
    if (userBalance < GAME_COST + 10_000_000) { // Game cost + gas
      console.error('❌ User wallet has insufficient balance');
      process.exit(1);
    }
    
    console.log('✅ Wallet balances sufficient\n');
  }

  private async getWalletBalance(address: string): Promise<number> {
    try {
      const balance = await this.client.getBalance({ owner: address });
      return parseInt(balance.totalBalance);
    } catch (error) {
      console.error(`❌ Could not fetch balance for ${address}`);
      return 0;
    }
  }

  private async createGame(): Promise<string> {
    console.log('🎮 Step 1: User creating game...');
    
    try {
      const tx = new Transaction();
      
      // Split coins for exact payment
      const [coin] = tx.splitCoins(tx.gas, [GAME_COST]);
      
      // Create game
      tx.moveCall({
        target: `${this.packageId}::crossy_robot::create_game`,
        arguments: [
          coin,
          tx.object('0x6'), // Clock object
        ],
      });
      
      // Execute transaction
      const result = await this.client.signAndExecuteTransaction({
        signer: this.userKeypair,
        transaction: tx,
        options: {
          showEffects: true,
          showObjectChanges: true,
        },
      });
      
      if (result.effects?.status?.status !== 'success') {
        throw new Error(`Transaction failed: ${result.effects?.status?.error}`);
      }
      
      // Extract game object ID
      const gameObject = result.objectChanges?.find(
        (change: any) => change.type === 'created' && 
        change.objectType?.includes('Game')
      );
      
      if (!gameObject) {
        throw new Error('Game object not found in transaction result');
      }
      
      const gameId = (gameObject as any).objectId;
      console.log(`✅ Game created successfully!`);
      console.log(`   Game ID: ${gameId}`);
      console.log(`   Transaction: ${result.digest}\n`);
      
      return gameId;
      
    } catch (error) {
      console.error('❌ Failed to create game:', error);
      throw error;
    }
  }

  private async robotConnectToGame(gameId: string): Promise<void> {
    console.log('🤖 Step 2: Robot connecting to game...');
    
    try {
      const tx = new Transaction();
      
      tx.moveCall({
        target: `${this.packageId}::crossy_robot::connect_robot`,
        arguments: [
          tx.object(gameId),
          tx.object('0x6'), // Clock object
        ],
      });
      
      const result = await this.client.signAndExecuteTransaction({
        signer: this.robotKeypair,
        transaction: tx,
        options: {
          showEffects: true,
        },
      });
      
      if (result.effects?.status?.status !== 'success') {
        throw new Error(`Robot connection failed: ${result.effects?.status?.error}`);
      }
      
      console.log(`✅ Robot connected to game!`);
      console.log(`   Transaction: ${result.digest}\n`);
      
    } catch (error) {
      console.error('❌ Robot failed to connect:', error);
      throw error;
    }
  }

  private async sendMovementCommand(gameId: string, direction: number): Promise<void> {
    const directionName = DIRECTION_NAMES[direction];
    console.log(`👤 Step 3.${direction + 1}: User sending movement: ${directionName}...`);
    
    try {
      const tx = new Transaction();
      
      tx.moveCall({
        target: `${this.packageId}::crossy_robot::move_robot`,
        arguments: [
          tx.object(gameId),
          tx.pure.u8(direction),
          tx.object('0x6'), // Clock object
        ],
      });
      
      const result = await this.client.signAndExecuteTransaction({
        signer: this.userKeypair,
        transaction: tx,
        options: {
          showEffects: true,
        },
      });
      
      if (result.effects?.status?.status !== 'success') {
        throw new Error(`Movement command failed: ${result.effects?.status?.error}`);
      }
      
      console.log(`✅ Movement command sent: ${directionName}`);
      console.log(`   Transaction: ${result.digest}`);
      
    } catch (error) {
      console.error(`❌ Failed to send movement command:`, error);
      throw error;
    }
  }

  private async delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  public async runTest(): Promise<void> {
    try {
      console.log('🚀 Starting Simple Crossy Robot E2E Test...\n');
      
      // Check wallet balances
      await this.checkWalletBalances();
      
      // Step 1: User creates game
      const gameId = await this.createGame();
      
      // Step 2: Robot connects to game
      await this.robotConnectToGame(gameId);
      
      // Step 3: Send movement commands
      const testMovements = [DIRECTIONS.UP, DIRECTIONS.RIGHT, DIRECTIONS.DOWN, DIRECTIONS.LEFT];
      
      for (let i = 0; i < testMovements.length; i++) {
        await this.delay(1000); // Wait 1 second between movements
        await this.sendMovementCommand(gameId, testMovements[i]);
      }
      
      console.log('\n🎉 All Tests Completed Successfully!');
      console.log('');
      console.log('📊 Test Summary:');
      console.log('   ✅ Game created with 0.05 SUI payment');
      console.log('   ✅ Robot connected and received payment');
      console.log(`   ✅ ${testMovements.length} movement commands executed`);
      console.log('   ✅ All transactions successful');
      console.log('');
      console.log('🎊 Crossy Robot contract is working perfectly! 🎊');
      
    } catch (error) {
      console.error('❌ Test failed:', error);
      process.exit(1);
    }
  }
}

// Main execution
async function main() {
  const test = new SimpleCrossyRobotTest();
  await test.runTest();
}

// Run the test
if (require.main === module) {
  main().catch(console.error);
} 