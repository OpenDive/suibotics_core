# Crossy Robot Deployment Guide 🚀

This guide covers deploying the Crossy Robot game contract to Sui testnet.

## 📋 Prerequisites

Before deploying, ensure you have:

1. **Sui CLI installed**
   ```bash
   # macOS
   brew install sui
   
   # Or download from: https://docs.sui.io/guides/developer/getting-started/sui-install
   ```

2. **Active Sui wallet with testnet tokens**
   ```bash
   # Create new wallet
   sui client new-address ed25519
   
   # Or import existing wallet
   sui client import <private-key>
   
   # Get testnet tokens
   sui client faucet
   # Or visit: https://faucet.sui.io/
   ```

3. **jq for JSON parsing (recommended)**
   ```bash
   brew install jq  # macOS
   ```

## 🎯 Deployment Options

### Option 1: Comprehensive Deployment (Recommended)

Use this for production-ready deployment with full validation:

```bash
./deploy_testnet.sh
```

**Features:**
- ✅ Pre-deployment environment checks
- ✅ Automatic testnet setup
- ✅ Gas balance validation and faucet requests
- ✅ Build and test execution
- ✅ Detailed logging and error handling
- ✅ Post-deployment verification
- ✅ Explorer links and integration examples

### Option 2: Quick Deployment

Use this for rapid testing and development:

```bash
./deploy_simple.sh
```

**Features:**
- ⚡ Fast deployment with minimal checks
- 🎯 Essential steps only
- 📦 Package ID extraction
- 🔗 Explorer links

### Option 3: Manual Deployment

For custom deployment workflows:

```bash
# Switch to testnet
sui client switch --env testnet

# Build and test
sui move build
sui move test

# Deploy
sui client publish --gas-budget 100000000
```

## 📊 Deployment Results

After successful deployment, you'll receive:

### Package Information
- **Package ID**: `0xcf21b35cca41042a29b030ec7f8d7c54d80235b9fcac438cab72fd89616c82ab`
- **Transaction**: `HC3jBPFjwEdFiyHcS3oSy1ydUR36DsVjfschWPTs8Wi1`
- **Network**: `testnet`
- **Game Cost**: `0.05 SUI` per game

### Explorer Links
- **Package**: https://suiscan.xyz/testnet/object/0xcf21b35cca41042a29b030ec7f8d7c54d80235b9fcac438cab72fd89616c82ab
- **Transaction**: https://suiscan.xyz/testnet/tx/HC3jBPFjwEdFiyHcS3oSy1ydUR36DsVjfschWPTs8Wi1

### Contract Functions
- `create_game(payment, clock, ctx)` - Create new game with 0.05 SUI payment
- `connect_robot(game, clock, ctx)` - Robot connects to game and receives payment
- `move_robot(game, direction, clock, ctx)` - Issue movement command (0-7 directions)

### Events
- `GameCreated` - New game available for robots
- `RobotConnected` - Robot accepted the game
- `RobotMoved` - Movement command issued

## 🔧 Integration Examples

### Frontend (TypeScript)
```typescript
const PACKAGE_ID = '0xcf21b35cca41042a29b030ec7f8d7c54d80235b9fcac438cab72fd89616c82ab';

// Create game
const createGame = async () => {
  const payment = /* 0.05 SUI coin */;
  const tx = new TransactionBlock();
  tx.moveCall({
    target: `${PACKAGE_ID}::crossy_robot::create_game`,
    arguments: [payment, clock],
  });
  return await signAndExecute(tx);
};

// Move robot
const moveRobot = async (gameId: string, direction: number) => {
  const tx = new TransactionBlock();
  tx.moveCall({
    target: `${PACKAGE_ID}::crossy_robot::move_robot`,
    arguments: [gameId, direction, clock],
  });
  return await signAndExecute(tx);
};
```

### Robot Listener (Python)
```python
import asyncio
from sui_sdk import SuiClient

PACKAGE_ID = "0xcf21b35cca41042a29b030ec7f8d7c54d80235b9fcac438cab72fd89616c82ab"

# Listen for game events
async def listen_for_games():
    # Subscribe to GameCreated events
    # Parse event data to get game_id
    # Call connect_robot() to accept game
    pass

# Listen for movement events  
async def listen_for_movements():
    # Subscribe to RobotMoved events
    # Parse direction from event
    # Execute physical movement
    pass
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. "Sui CLI not found"
```bash
# Install Sui CLI
brew install sui
# Or visit: https://docs.sui.io/guides/developer/getting-started/sui-install
```

#### 2. "Insufficient gas balance"
```bash
# Request testnet tokens
sui client faucet
# Or visit: https://faucet.sui.io/
```

#### 3. "Not on testnet"
```bash
# Switch to testnet
sui client switch --env testnet

# Verify environment
sui client envs
```

#### 4. "Build failed"
```bash
# Clean and rebuild
rm -rf build/
sui move build
```

#### 5. "Tests failed"
```bash
# Run tests with verbose output
sui move test --verbose
```

### Script Permissions
If you get permission errors:
```bash
chmod +x deploy_testnet.sh deploy_simple.sh
```

### JSON Parsing Issues
If jq is not available:
```bash
# Install jq
brew install jq  # macOS
apt-get install jq  # Ubuntu/Debian
```

## 📁 Generated Files

After deployment, these files are created:

- `deployment_info.json` - Package ID and deployment details
- `deployment_YYYYMMDD_HHMMSS.log` - Detailed deployment logs (comprehensive script only)
- `build/` - Compiled Move bytecode

## 🔄 Redeployment

To redeploy (creates new package):
```bash
# Clean previous build
rm -rf build/ deployment_info.json

# Run deployment script again
./deploy_testnet.sh
```

## 📞 Support

If you encounter issues:

1. Check the deployment logs
2. Verify your Sui CLI version: `sui --version`
3. Ensure you're on testnet: `sui client envs`
4. Check gas balance: `sui client gas`
5. Review the troubleshooting section above

## 🎮 Next Steps

After successful deployment:

1. **Build Frontend**: Create a web interface for users to create games and control robots
2. **Implement Robot Listeners**: Set up physical robots to listen for blockchain events
3. **Test Game Flow**: Create games, connect robots, and issue movement commands
4. **Monitor Events**: Use blockchain explorers to track game activity

Your Crossy Robot game is now live on Sui testnet! 🤖🎮 