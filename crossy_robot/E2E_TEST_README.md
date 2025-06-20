# E2E Testing Guide

This document explains how to run End-to-End (E2E) tests for the Crossy Robot contracts on the Sui blockchain.

## Overview

We provide comprehensive E2E testing for both contract variants:

### Original Crossy Robot Contract Tests
- **Pay-to-play robot control game**
- **Robot connection transactions**
- **Direct payment transfers**

### Crowd Robot Contract Tests *(NEW)*
- **Free crowd-controlled games**
- **Multi-player participation**
- **Network stress testing**
- **Player tracking validation**

## Test Files

### Original Contract Tests
- `simple-e2e-test.ts` - Basic functionality validation
- `e2e-test.ts` - Comprehensive event-driven testing

### Crowd Robot Contract Tests *(NEW)*
- `simple-crowd-e2e-test.ts` - Basic crowd control validation
- `crowd-e2e-test.ts` - Comprehensive stress testing with multi-player scenarios

## Prerequisites

1. **Node.js and npm** installed
2. **Sui CLI** installed and configured
3. **Testnet SUI tokens** in your wallets
4. **Contract deployed** on testnet

### Dependencies Installation

```bash
npm install
```

### Required Environment Variables

Create a `.env` file in the `crossy_robot` directory:

```bash
# Required for all tests
USER_PRIVATE_KEY=your_primary_wallet_private_key

# Required for crowd robot tests (multi-player)
PLAYER2_PRIVATE_KEY=your_second_wallet_private_key
PLAYER3_PRIVATE_KEY=your_third_wallet_private_key

# Optional for enhanced stress testing
PLAYER4_PRIVATE_KEY=your_fourth_wallet_private_key
```

**Note:** Use either Sui CLI format (`suiprivkey1...`) or base64 encoded private keys.

### Wallet Balance Requirements

- **Original tests**: 0.1 SUI minimum (for game payments)
- **Crowd robot tests**: 0.05 SUI minimum per wallet (for gas only)

## Running Tests

### Original Contract Tests

**Basic Test:**
```bash
./simple-e2e-test.ts
# or
npx ts-node simple-e2e-test.ts
```

**Comprehensive Test:**
```bash
./e2e-test.ts
# or
npx ts-node e2e-test.ts
```

### Crowd Robot Contract Tests *(NEW)*

**Basic Crowd Control Test:**
```bash
./simple-crowd-e2e-test.ts
# or
npx ts-node simple-crowd-e2e-test.ts
```

**Comprehensive Stress Test:**
```bash
./crowd-e2e-test.ts
# or
npx ts-node crowd-e2e-test.ts
```

## Test Features

### Original Contract Tests

1. **Game Creation** - Pay 0.05 SUI to create game
2. **Robot Connection** - Robot connects and receives payment
3. **Movement Commands** - User controls robot direction
4. **Event Processing** - Real-time blockchain events
5. **Error Handling** - Invalid moves and insufficient funds

### Crowd Robot Contract Tests *(NEW)*

1. **Free Game Creation** - No payment required
2. **Multi-Player Participation** - 3-4 players control same robot
3. **Player Tracking** - Unique participant counting
4. **Stress Testing** - Rapid command submission (15 commands/player)
5. **Time-Based Expiration** - 2-minute game duration
6. **Network Performance** - Measures response times and throughput

## Test Scenarios

### Simple Tests
- Basic contract functionality
- Single transaction flows
- Error condition handling
- ~30 seconds duration

### Comprehensive Tests
- Multi-step workflows
- Event-driven testing
- Real-time monitoring
- Stress testing scenarios
- ~2-3 minutes duration

## Expected Outputs

### Original Contract Test Results
```
🎮 Crossy Robot E2E Test Results:
✅ Game created with 0.05 SUI payment
✅ Robot connected and received payment
✅ Movement commands executed
✅ Events processed correctly
✅ All transactions successful
```

### Crowd Robot Test Results *(NEW)*
```
🎮 Crowd Robot E2E Test Results:
✅ Free game created (no payment required)
✅ Multi-player crowd control: PASSED (3-4 players)
✅ Player tracking: PASSED (unique players recorded)
✅ Movement commands: PASSED (45-60 total moves)
✅ Performance metrics: PASSED (avg response time)
✅ Stress testing: PASSED (high transaction volume)
```

## Troubleshooting

### Common Issues

**1. Insufficient Balance**
```
❌ Wallet has insufficient balance
```
*Solution: Add more SUI to your testnet wallets*

**2. Missing Private Keys**
```
❌ USER_PRIVATE_KEY not found in environment variables
```
*Solution: Create `.env` file with all required private keys*

**3. Contract Not Deployed**
```
❌ Could not load deployment info
```
*Solution: Run deployment script first*

**4. Network Issues**
```
❌ Transaction failed: RPC error
```
*Solution: Wait and retry, or check testnet status*

### Crowd Robot Specific Issues

**1. Insufficient Players**
```
❌ PLAYER2_PRIVATE_KEY not found
```
*Solution: Add at least 3 player wallets for crowd testing*

**2. Stress Test Failures**
```
❌ High transaction volume causing failures
```
*Solution: This is expected during stress testing - check success rate*

## Performance Metrics

### Original Contract Performance
- **Game Creation**: ~1-2 seconds
- **Robot Connection**: ~1-2 seconds  
- **Movement Commands**: ~0.5-1 second each
- **Event Processing**: Real-time

### Crowd Robot Performance *(NEW)*
- **Free Game Creation**: ~1-2 seconds
- **Movement Commands**: ~0.5-1 second each
- **Stress Test Throughput**: 4-8 commands/second
- **Multi-Player Coordination**: Parallel execution
- **Network Capacity**: 45-60 total transactions

## Integration Examples

### Basic Integration
```typescript
// Create game
const tx = new Transaction();
tx.moveCall({
  target: `${packageId}::crowd_robot::create_game`,
  arguments: [tx.object('0x6')], // Clock only
});

// Send movement (any player)
tx.moveCall({
  target: `${packageId}::crowd_robot::move_robot`,
  arguments: [
    tx.object(gameId),
    tx.pure.u8(direction),
    tx.object('0x6')
  ],
});
```

### Event Listening
```typescript
// Listen for crowd robot events
const subscription = await client.subscribeEvent({
  filter: { Package: packageId },
  onMessage: (event) => {
    if (event.type.includes('RobotMoved')) {
      const { player, direction, is_new_player } = event.parsedJson;
      console.log(`Player ${player} moved robot ${direction}`);
      if (is_new_player) {
        console.log('New player joined!');
      }
    }
  }
});
```

## Best Practices

1. **Start with simple tests** before running comprehensive ones
2. **Check wallet balances** before starting
3. **Monitor network conditions** during stress testing
4. **Use multiple wallets** for realistic crowd testing
5. **Expect some failures** during high-volume stress tests
6. **Run tests in sequence** to avoid conflicts

## Support

For issues or questions:
1. Check the troubleshooting section
2. Verify your environment setup
3. Review the test output logs
4. Check deployment status

**Note:** Crowd robot tests are designed for network stress testing and may produce some transaction failures at high volumes - this is expected behavior when testing network limits.