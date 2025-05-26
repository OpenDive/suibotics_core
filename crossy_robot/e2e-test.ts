#!/usr/bin/env ts-node

/**
 * Crossy Robot E2E Test
 * 
 * This script simulates the complete game flow:
 * 1. User creates a game
 * 2. Robot listens for GameCreated event and connects
 * 3. User sends movement commands
 * 4. Robot listens for RobotMoved events and simulates movement
 */

import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { fromB64 } from '@mysten/sui/utils';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Configuration
const DEPLOYMENT_INFO_PATH = './deployment_info.json';
const GAME_COST = 50_000_000; // 0.05 SUI in MIST
const GAS_BUDGET = parseInt(process.env.GAS_BUDGET || '10000000');
const TEST_TIMEOUT = parseInt(process.env.TEST_TIMEOUT_MS || '30000');
const MOVEMENT_DELAY = parseInt(process.env.MOVEMENT_DELAY_MS || '2000');

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

interface GameState {
  gameId: string;
  user: string;
  robot?: string;
  status: number;
  createdAt: number;
}

class CrossyRobotE2ETest {
  private client: SuiClient;
  private userKeypair: Ed25519Keypair;
  private robotKeypair: Ed25519Keypair;
  private packageId: string;
  private gameState: GameState | null = null;
  private eventSubscription: any = null;
  private testResults = {
    gameCreated: false,
    robotConnected: false,
    movementsExecuted: 0,
    eventsReceived: 0
  };

  constructor() {
    // Initialize Sui client
    this.client = new SuiClient({
      url: process.env.SUI_RPC_URL || getFullnodeUrl('testnet')
    });

    // Initialize wallets
    this.userKeypair = this.createKeypairFromEnv('USER_PRIVATE_KEY');
    this.robotKeypair = this.createKeypairFromEnv('ROBOT_PRIVATE_KEY');

    // Load deployment info
    this.packageId = this.loadPackageId();

    console.log('🤖 Crossy Robot E2E Test Initialized');
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
      console.log('💡 You can export private keys from Sui wallet or generate new ones');
      process.exit(1);
    }

    try {
      return Ed25519Keypair.fromSecretKey(fromB64(privateKey));
    } catch (error) {
      console.error(`❌ Invalid private key format for ${envVar}`);
      console.log('💡 Private key should be base64 encoded');
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
      console.log('💡 Make sure deployment_info.json exists and contains package_id');
      process.exit(1);
    }
  }

  private async checkWalletBalances(): Promise<void> {
    console.log('💰 Checking wallet balances...');
    
    const userBalance = await this.getWalletBalance(this.userKeypair.getPublicKey().toSuiAddress());
    const robotBalance = await this.getWalletBalance(this.robotKeypair.getPublicKey().toSuiAddress());
    
    console.log(`👤 User balance: ${(userBalance / 1_000_000_000).toFixed(3)} SUI`);
    console.log(`🤖 Robot balance: ${(robotBalance / 1_000_000_000).toFixed(3)} SUI`);
    
    if (userBalance < GAME_COST + GAS_BUDGET) {
      console.error('❌ User wallet has insufficient balance for game creation');
      console.log('💡 Need at least 0.06 SUI (0.05 for game + gas)');
      process.exit(1);
    }
    
    console.log('✅ Wallet balances sufficient');
    console.log('');
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

  private async startEventListener(): Promise<void> {
    console.log('👂 Starting event listener...');
    
    try {
      // Subscribe to events from our package
      this.eventSubscription = await this.client.subscribeEvent({
        filter: { Package: this.packageId },
        onMessage: (event) => {
          this.handleEvent(event);
        }
      });
      
      console.log('✅ Event listener started');
      console.log('');
    } catch (error) {
      console.error('❌ Failed to start event listener:', error);
      throw error;
    }
  }

  private handleEvent(event: any): void {
    this.testResults.eventsReceived++;
    
    const eventType = event.type.split('::').pop();
    console.log(`📡 Event received: ${eventType}`);
    
    switch (eventType) {
      case 'GameCreated':
        this.handleGameCreatedEvent(event);
        break;
      case 'RobotConnected':
        this.handleRobotConnectedEvent(event);
        break;
      case 'RobotMoved':
        this.handleRobotMovedEvent(event);
        break;
      default:
        console.log(`❓ Unknown event type: ${eventType}`);
    }
  }

  private async handleGameCreatedEvent(event: any): Promise<void> {
    const { game_id, user, payment_amount } = event.parsedJson;
    
    console.log(`🎮 GameCreated event detected!`);
    console.log(`   Game ID: ${game_id}`);
    console.log(`   User: ${user}`);
    console.log(`   Payment: ${payment_amount / 1_000_000_000} SUI`);
    
    // Store game state
    this.gameState = {
      gameId: game_id,
      user: user,
      status: 0, // WAITING_FOR_ROBOT
      createdAt: Date.now()
    };
    
    // Robot automatically connects
    console.log('🤖 Robot: Detected new game, connecting...');
    await this.robotConnectToGame(game_id);
  }

  private handleRobotConnectedEvent(event: any): void {
    const { game_id, robot, timestamp } = event.parsedJson;
    
    console.log(`🔗 RobotConnected event detected!`);
    console.log(`   Game ID: ${game_id}`);
    console.log(`   Robot: ${robot}`);
    console.log(`   Timestamp: ${timestamp}`);
    
    if (this.gameState && this.gameState.gameId === game_id) {
      this.gameState.robot = robot;
      this.gameState.status = 1; // ACTIVE
      this.testResults.robotConnected = true;
    }
    
    console.log('✅ Robot successfully connected and received payment!');
    console.log('');
  }

  private handleRobotMovedEvent(event: any): void {
    const { game_id, direction, timestamp } = event.parsedJson;
    
    const directionName = DIRECTION_NAMES[direction] || 'UNKNOWN';
    console.log(`🎯 RobotMoved event detected!`);
    console.log(`   Game ID: ${game_id}`);
    console.log(`   Direction: ${direction} (${directionName})`);
    console.log(`   Timestamp: ${timestamp}`);
    
    // Simulate robot physical movement
    console.log(`🤖 Robot: Executing physical movement: ${directionName}`);
    this.testResults.movementsExecuted++;
    console.log('');
  }

  private async createGame(): Promise<string> {
    console.log('🎮 User: Creating new game...');
    
    try {
      const tx = new Transaction();
      
      // Split coins for exact payment
      const [coin] = tx.splitCoins(tx.gas, [tx.pure(GAME_COST)]);
      
      // Create game
      tx.moveCall({
        target: `${this.packageId}::crossy_robot::create_game`,
        arguments: [
          coin,
          tx.object('0x6'), // Clock object
        ],
      });
      
      // Execute transaction
      const result = await this.client.signAndExecuteTransactionBlock({
        signer: this.userKeypair,
        transactionBlock: tx,
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
        change.objectType.includes('Game')
      );
      
      if (!gameObject) {
        throw new Error('Game object not found in transaction result');
      }
      
      const gameId = gameObject.objectId;
      console.log(`✅ Game created successfully!`);
      console.log(`   Game ID: ${gameId}`);
      console.log(`   Transaction: ${result.digest}`);
      console.log('');
      
      this.testResults.gameCreated = true;
      return gameId;
      
    } catch (error) {
      console.error('❌ Failed to create game:', error);
      throw error;
    }
  }

  private async robotConnectToGame(gameId: string): Promise<void> {
    try {
      const tx = new TransactionBlock();
      
      tx.moveCall({
        target: `${this.packageId}::crossy_robot::connect_robot`,
        arguments: [
          tx.object(gameId),
          tx.object('0x6'), // Clock object
        ],
      });
      
      const result = await this.client.signAndExecuteTransactionBlock({
        signer: this.robotKeypair,
        transactionBlock: tx,
        options: {
          showEffects: true,
        },
      });
      
      if (result.effects?.status?.status !== 'success') {
        throw new Error(`Robot connection failed: ${result.effects?.status?.error}`);
      }
      
      console.log(`✅ Robot connected to game!`);
      console.log(`   Transaction: ${result.digest}`);
      console.log('');
      
    } catch (error) {
      console.error('❌ Robot failed to connect:', error);
      throw error;
    }
  }

  private async sendMovementCommand(gameId: string, direction: number): Promise<void> {
    const directionName = DIRECTION_NAMES[direction];
    console.log(`👤 User: Sending movement command: ${directionName}...`);
    
    try {
      const tx = new TransactionBlock();
      
      tx.moveCall({
        target: `${this.packageId}::crossy_robot::move_robot`,
        arguments: [
          tx.object(gameId),
          tx.pure(direction),
          tx.object('0x6'), // Clock object
        ],
      });
      
      const result = await this.client.signAndExecuteTransactionBlock({
        signer: this.userKeypair,
        transactionBlock: tx,
        options: {
          showEffects: true,
        },
      });
      
      if (result.effects?.status?.status !== 'success') {
        throw new Error(`Movement command failed: ${result.effects?.status?.error}`);
      }
      
      console.log(`✅ Movement command sent: ${directionName}`);
      console.log(`   Transaction: ${result.digest}`);
      console.log('');
      
    } catch (error) {
      console.error(`❌ Failed to send movement command:`, error);
      throw error;
    }
  }

  private async waitForCondition(
    condition: () => boolean,
    timeoutMs: number,
    description: string
  ): Promise<void> {
    const startTime = Date.now();
    
    while (!condition() && (Date.now() - startTime) < timeoutMs) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    if (!condition()) {
      throw new Error(`Timeout waiting for: ${description}`);
    }
  }

  private async delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  public async runTest(): Promise<void> {
    try {
      console.log('🚀 Starting Crossy Robot E2E Test...');
      console.log('');
      
      // Check wallet balances
      await this.checkWalletBalances();
      
      // Start event listener
      await this.startEventListener();
      
      // Step 1: User creates game
      const gameId = await this.createGame();
      
      // Step 2: Wait for robot to connect (triggered by GameCreated event)
      console.log('⏳ Waiting for robot to connect...');
      await this.waitForCondition(
        () => this.testResults.robotConnected,
        TEST_TIMEOUT,
        'robot connection'
      );
      
      // Step 3: Send movement commands
      const testMovements = [DIRECTIONS.UP, DIRECTIONS.RIGHT, DIRECTIONS.DOWN, DIRECTIONS.LEFT];
      
      for (const direction of testMovements) {
        await this.delay(MOVEMENT_DELAY);
        await this.sendMovementCommand(gameId, direction);
        
        // Wait a bit for the event to be processed
        await this.delay(500);
      }
      
      // Wait for all movement events to be processed
      console.log('⏳ Waiting for all movement events...');
      await this.delay(2000);
      
      // Display results
      this.displayResults();
      
    } catch (error) {
      console.error('❌ Test failed:', error);
      process.exit(1);
    } finally {
      // Cleanup
      if (this.eventSubscription) {
        await this.eventSubscription.unsubscribe();
      }
    }
  }

  private displayResults(): void {
    console.log('');
    console.log('🎉 E2E Test Complete!');
    console.log('');
    console.log('📊 Test Results:');
    console.log(`   ✅ Game created: ${this.testResults.gameCreated ? 'YES' : 'NO'}`);
    console.log(`   ✅ Robot connected: ${this.testResults.robotConnected ? 'YES' : 'NO'}`);
    console.log(`   ✅ Movements executed: ${this.testResults.movementsExecuted}`);
    console.log(`   ✅ Events received: ${this.testResults.eventsReceived}`);
    console.log('');
    
    const allTestsPassed = 
      this.testResults.gameCreated &&
      this.testResults.robotConnected &&
      this.testResults.movementsExecuted > 0 &&
      this.testResults.eventsReceived >= 3; // GameCreated + RobotConnected + RobotMoved events
    
    if (allTestsPassed) {
      console.log('🎊 ALL TESTS PASSED! 🎊');
      console.log('🤖 Crossy Robot contract is working perfectly!');
    } else {
      console.log('❌ Some tests failed. Check the logs above.');
      process.exit(1);
    }
  }
}

// Main execution
async function main() {
  const test = new CrossyRobotE2ETest();
  await test.runTest();
}

// Run the test
if (require.main === module) {
  main().catch(console.error);
} 