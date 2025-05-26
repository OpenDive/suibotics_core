# Crossy Robot 🤖🎮

A simple blockchain-based robot control game where users pay to control physical robots in real-time.

## 🎯 **Game Concept**

Crossy Robot is a pay-to-play game where:
1. **Users** create games by paying 0.05 SUI
2. **Physical robots** listen for game events and connect to earn the payment
3. **Users** control the connected robot through blockchain transactions
4. **Robots** execute movements in the physical world based on blockchain events

## 🏗️ **Architecture**

```
┌─────────────┐    0.05 SUI     ┌─────────────────┐
│   Frontend  │ ──────────────► │  Smart Contract │
│   (User)    │                 │   (Sui Blockchain)│
└─────────────┘                 └─────────────────┘
                                         │
                                    Events │
                                         ▼
                                ┌─────────────────┐
                                │ Physical Robot  │
                                │   (Listener)    │
                                └─────────────────┘
```

## 📋 **Game Flow**

### **1. Game Creation**
- User submits 0.05 SUI payment through frontend
- Smart contract creates `Game` object with unique ID
- Emits `GameCreated` event with game details
- Game status: `WAITING_FOR_ROBOT`

### **2. Robot Connection**
- Physical robot monitors blockchain for `GameCreated` events
- Robot calls `connect_robot()` function to accept the game
- 0.05 SUI payment transferred directly to robot
- Emits `RobotConnected` event
- Game status: `ACTIVE`

### **3. Robot Control**
- User clicks movement buttons in frontend
- Each click submits `move_robot()` transaction
- Smart contract emits `RobotMoved` event with direction
- Physical robot listens to events and executes movement

## 🎮 **Movement Directions**

The game supports 8-directional movement:

| Direction | Code | Description |
|-----------|------|-------------|
| Up | 0 | Move forward |
| Down | 1 | Move backward |
| Left | 2 | Move left |
| Right | 3 | Move right |
| Up-Right | 4 | Move diagonally forward-right |
| Up-Left | 5 | Move diagonally forward-left |
| Down-Left | 6 | Move diagonally backward-left |
| Down-Right | 7 | Move diagonally backward-right |

## 📦 **Smart Contract Structure**

### **Core Types**
```move
public struct Game has key, store {
    id: UID,
    user: address,              // Game creator
    robot: Option<address>,     // Connected robot
    status: u8,                // Game status
    payment: Option<Coin<SUI>>, // Payment for robot
    created_at: u64,           // Creation timestamp
}
```

### **Events**
- `GameCreated` - New game available for robots
- `RobotConnected` - Robot accepted the game
- `RobotMoved` - Movement command issued

### **Functions**
- `create_game(payment, clock, ctx)` - Create new game
- `connect_robot(game, clock, ctx)` - Robot connects to game
- `move_robot(game, direction, clock, ctx)` - Issue movement command

## 🚀 **Deployment**

### **Prerequisites**
- Sui CLI installed
- Active Sui wallet with SUI tokens
- `jq` for JSON parsing (optional but recommended)

### **Automated Deployment Scripts**

Two deployment scripts are provided for testnet deployment:

#### **Option 1: Comprehensive Deployment (Recommended)**
```bash
./deploy_testnet.sh
```

This script provides:
- ✅ Comprehensive pre-deployment checks
- ✅ Automatic environment setup and validation
- ✅ Gas balance verification and faucet requests
- ✅ Build and test validation
- ✅ Detailed logging and error handling
- ✅ Post-deployment verification
- ✅ Explorer links and integration examples

#### **Option 2: Quick Deployment**
```bash
./deploy_simple.sh
```

This script provides:
- ⚡ Fast deployment with minimal checks
- 🎯 Essential steps only
- 📦 Package ID extraction
- 🔗 Explorer links and next steps

### **Manual Deployment**
If you prefer manual deployment:

```bash
# Build the contract
sui move build

# Run tests
sui move test

# Deploy to testnet
sui client publish --gas-budget 100000000
```

### **Test Results**
✅ **8/8 tests passing** - 100% test success rate

**Test Coverage:**
- Game creation with valid/invalid payment
- Robot connection success/failure scenarios
- Movement validation for all directions
- Error handling for invalid states

### **Post-Deployment**
After successful deployment, you'll receive:
- **Package ID**: Use this to interact with your deployed contract
- **Transaction Digest**: For verification on blockchain explorers
- **Explorer Links**: View your deployment on Sui explorers
- **Integration Examples**: Ready-to-use code snippets

The deployment information is automatically saved to `deployment_info.json` for future reference.

## 🔧 **Integration Guide**

### **For Frontend Developers**
```typescript
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

### **For Robot Developers**
```python
# Listen for game events
def listen_for_games():
    # Subscribe to GameCreated events
    # Parse event data to get game_id
    # Call connect_robot() to accept game

# Listen for movement events  
def listen_for_movements():
    # Subscribe to RobotMoved events
    # Parse direction from event
    # Execute physical movement
```

## 🎯 **Current MVP Features**

### **✅ Implemented**
- Pay-to-play game creation (0.05 SUI)
- Robot connection and payment transfer
- 8-directional movement commands
- Event-driven architecture
- Comprehensive test suite

### **🚧 Future Enhancements (TODOs)**
- Position tracking for game state validation
- Movement frequency rate limiting
- Game creator validation for moves
- Robot position bounds checking
- Game end conditions and scoring
- Payment escrow and platform fees
- Integration with DID system for robot authentication
- Reputation system for robots
- Multi-robot game support
- Game session timeout functionality
- Pause/resume game functionality

## 💡 **Use Cases**

### **Entertainment**
- Remote robot control games
- Robot racing competitions
- Interactive robot demonstrations

### **Education**
- Blockchain + robotics learning
- Real-time event processing demos
- Decentralized control systems

### **Research**
- Human-robot interaction studies
- Blockchain-based IoT control
- Economic incentives for robot services

## 🔗 **Related Projects**

This is part of the **Suibotics** ecosystem:
- **Suibotics DID**: Decentralized identity system for robots
- **Crossy Robot**: Simple robot control game (this project)
- **Future**: Robot delivery, authentication, and reputation systems

## 📄 **License**

[Add your license information here]

## 🤝 **Contributing**

1. Ensure all tests pass: `sui move test`
2. Follow Move coding conventions
3. Add tests for new functionality
4. Update documentation as needed

## 📞 **Support**

For questions and support, please [add contact information or issue tracker link]. 