#!/bin/bash

# Simple Crossy Robot Testnet Deployment Script
# Quick deployment without extensive logging

set -e

echo "🤖 Deploying Crossy Robot Games to Testnet..."

# Switch to testnet
echo "📡 Switching to testnet..."
sui client switch --env testnet

# Request faucet (in case balance is low)
echo "💰 Requesting testnet tokens..."
if sui client faucet 2>&1 | grep -q "For testnet tokens"; then
    echo "⚠️  Please get tokens from https://faucet.sui.io/ if needed"
else
    echo "✅ Faucet request completed"
fi

# Verify we're on testnet
if ! sui client envs | grep -q "testnet.*\*"; then
    echo "❌ Not on testnet! Please check your environment."
    sui client envs
    exit 1
fi

# Build the package
echo "🔨 Building Crossy Robot contracts..."
sui move build

# Run tests
echo "🧪 Running tests..."
sui move test

# Deploy
echo "🚀 Publishing Crossy Robot contracts to testnet..."
RESULT=$(sui client publish --gas-budget 100000000 --json)

# Extract package ID
PACKAGE_ID=$(echo "$RESULT" | jq -r '.objectChanges[] | select(.type == "published") | .packageId')
TX_DIGEST=$(echo "$RESULT" | jq -r '.digest')

echo ""
echo "✅ Crossy Robot deployment successful!"
echo "🎮 Package ID: $PACKAGE_ID"
echo "🔗 Transaction: $TX_DIGEST"
echo "🌐 Explorer: https://suiscan.xyz/testnet/object/$PACKAGE_ID"
echo ""
echo "📦 Deployed Contracts:"
echo "  • crossy_robot - Pay-to-play (0.05 SUI per game)"
echo "  • crowd_robot - Free crowd-controlled (2-minute games)"
echo ""

# Save deployment info
cat > deployment_info.json << EOF
{
  "package_id": "$PACKAGE_ID",
  "tx_digest": "$TX_DIGEST",
  "network": "testnet",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contracts": {
    "crossy_robot": {
      "description": "Pay-to-play robot control game",
      "game_cost_sui": "0.05",
      "game_cost_mist": 50000000,
      "functions": ["create_game", "connect_robot", "move_robot"]
    },
    "crowd_robot": {
      "description": "Free crowd-controlled robot game",
      "game_duration_minutes": 2,
      "game_cost": "free",
      "functions": ["create_game", "move_robot", "end_game"]
    }
  }
}
EOF

echo "💾 Deployment info saved to deployment_info.json"
echo ""
echo "🎯 Next Steps:"
echo "  1. Build frontend to create games and control robots"
echo "  2. Implement robot listeners for GameCreated/RobotMoved events"
echo "  3. Choose your game mode:"
echo "     • crossy_robot - Pay 0.05 SUI, robot earns payment"
echo "     • crowd_robot - Free crowd-controlled, 2-minute games"
echo ""
echo "🤖 Your robot control games are live! 🎮" 