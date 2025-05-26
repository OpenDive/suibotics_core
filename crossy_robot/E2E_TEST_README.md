# Crossy Robot E2E Testing

This directory contains an event-driven end-to-end test that simulates the complete Crossy Robot game flow using real blockchain interactions.

## What This Test Does

The test simulates the real-world interaction between users and robots:

1. **User** creates a game by paying 0.05 SUI
2. **Robot** listens for `GameCreated` event and automatically connects
3. **User** sends movement commands (UP, RIGHT, DOWN, LEFT)
4. **Robot** listens for `RobotMoved` events and simulates physical movement
5. **Verification** ensures all events are captured and processed correctly

## Quick Start

### 1. Install Dependencies
```bash
npm install
```

### 2. Set Up Wallets
Create a `.env` file with your wallet private keys:
```bash
cp env.example .env
# Edit .env with your actual private keys
```

### 3. Fund Wallets
Make sure both wallets have testnet SUI:
- **User wallet**: Needs ~0.1 SUI (0.05 for game + gas)
- **Robot wallet**: Needs ~0.05 SUI for gas

Get testnet tokens from: https://faucet.sui.io/

### 4. Run the Test
```bash
npm test
```

## Prerequisites

### Required Files
- `deployment_info.json` - Contains the deployed contract package ID
- `.env` - Contains wallet private keys (create from `env.example`)

### Wallet Setup
You need two separate wallets:
1. **User Wallet** - Creates games and sends movement commands
2. **Robot Wallet** - Connects to games and receives payments

#### Getting Private Keys
From Sui CLI:
```bash
# Export private key for existing wallet
sui keytool export <address> --key-scheme ed25519

# Or create new wallets
sui client new-address ed25519
```

From Sui Wallet Browser Extension:
1. Go to Settings → Export Private Key
2. Copy the base64 encoded private key

## Configuration

### Environment Variables
```bash
# Required
USER_PRIVATE_KEY=your_user_wallet_private_key_here
ROBOT_PRIVATE_KEY=your_robot_wallet_private_key_here

# Optional
SUI_NETWORK=testnet
SUI_RPC_URL=https://fullnode.testnet.sui.io:443
GAS_BUDGET=10000000
TEST_TIMEOUT_MS=30000
MOVEMENT_DELAY_MS=2000
```

### Test Parameters
- **Game Cost**: 0.05 SUI (50,000,000 MIST)
- **Gas Budget**: 10 SUI (configurable)
- **Test Timeout**: 30 seconds (configurable)
- **Movement Delay**: 2 seconds between commands (configurable)

## Expected Output

```
🤖 Crossy Robot E2E Test Initialized
📦 Package ID: 0x026e404cc7799d16f55c8e44e1a13868bbe58d48a38aebc6739e04c62d857d94
👤 User Address: 0x1234...
🤖 Robot Address: 0x5678...

💰 Checking wallet balances...
👤 User balance: 0.150 SUI
🤖 Robot balance: 0.100 SUI
✅ Wallet balances sufficient

👂 Starting event listener...
✅ Event listener started

🎮 User: Creating new game...
✅ Game created successfully!
   Game ID: 0xabc123...
   Transaction: DEF456...

📡 Event received: GameCreated
🎮 GameCreated event detected!
   Game ID: 0xabc123...
   User: 0x1234...
   Payment: 0.05 SUI
🤖 Robot: Detected new game, connecting...
✅ Robot connected to game!
   Transaction: GHI789...

📡 Event received: RobotConnected
🔗 RobotConnected event detected!
   Game ID: 0xabc123...
   Robot: 0x5678...
   Timestamp: 1234567890
✅ Robot successfully connected and received payment!

👤 User: Sending movement command: UP...
✅ Movement command sent: UP
   Transaction: JKL012...

📡 Event received: RobotMoved
🎯 RobotMoved event detected!
   Game ID: 0xabc123...
   Direction: 0 (UP)
   Timestamp: 1234567891
🤖 Robot: Executing physical movement: UP

[... more movements ...]

🎉 E2E Test Complete!

📊 Test Results:
   ✅ Game created: YES
   ✅ Robot connected: YES
   ✅ Movements executed: 4
   ✅ Events received: 6

🎊 ALL TESTS PASSED! 🎊
🤖 Crossy Robot contract is working perfectly!
```

## Troubleshooting

### Common Issues

#### "Private key not found"
- Make sure `.env` file exists with correct private keys
- Private keys should be base64 encoded
- Copy `env.example` to `.env` and fill in your keys

#### "Insufficient balance"
- User wallet needs at least 0.06 SUI (0.05 for game + gas)
- Robot wallet needs at least 0.05 SUI for gas
- Get testnet tokens from https://faucet.sui.io/

#### "Could not load deployment info"
- Make sure `deployment_info.json` exists
- Run deployment script first: `./deploy_testnet.sh`
- Check that package_id is valid

#### "Event listener failed"
- Check network connectivity
- Verify RPC URL is correct
- Try restarting the test

#### "Transaction failed"
- Check wallet balances
- Verify contract is deployed correctly
- Check gas budget settings

### Debug Mode
For more detailed logging, you can modify the script to add debug output or check transaction details on the Sui explorer.

## What This Tests

### Core Functionality
- ✅ Game creation with correct payment
- ✅ Robot connection and payment receipt
- ✅ Movement command execution
- ✅ Event emission and capture

### Event System
- ✅ `GameCreated` events are emitted and parseable
- ✅ `RobotConnected` events are emitted and parseable
- ✅ `RobotMoved` events are emitted and parseable
- ✅ Event timing and ordering

### Economic Flow
- ✅ 0.05 SUI payment from user to robot
- ✅ Gas cost estimation and execution
- ✅ Balance tracking throughout game lifecycle

### Integration
- ✅ Sui TypeScript SDK integration
- ✅ Real blockchain interaction
- ✅ WebSocket event subscription
- ✅ Transaction building and signing

## Next Steps

After successful testing, you can:

1. **Build Frontend** - Create a web interface using similar patterns
2. **Implement Physical Robots** - Use the event listening pattern for real robots
3. **Add More Features** - Extend the contract and test new functionality
4. **Deploy to Mainnet** - Use the same testing approach on mainnet

## Notes

- This test uses real testnet transactions and consumes real SUI
- Each test run creates new game objects on the blockchain
- Events are captured in real-time using WebSocket connections
- The test validates the complete user journey from game creation to robot movement

This E2E test proves that the Crossy Robot contract works correctly in a real blockchain environment!