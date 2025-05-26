#!/bin/bash

# Simple Crossy Robot Testnet Deployment Script
# Quick deployment without extensive logging

set -e

echo "🤖 Deploying Crossy Robot Game to Testnet..."

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
echo "🔨 Building Crossy Robot contract..."
sui move build

# Run tests
echo "🧪 Running tests..."
sui move test

# Deploy
echo "🚀 Publishing Crossy Robot to testnet..."
RESULT=$(sui client publish --gas-budget 100000000 --json)

# Extract package ID
PACKAGE_ID=$(echo "$RESULT" | jq -r '.objectChanges[] | select(.type == "published") | .packageId')
TX_DIGEST=$(echo "$RESULT" | jq -r '.digest')

echo ""
echo "✅ Crossy Robot deployment successful!"
echo "🎮 Package ID: $PACKAGE_ID"
echo "🔗 Transaction: $TX_DIGEST"
echo "🌐 Explorer: https://suiscan.xyz/testnet/object/$PACKAGE_ID"
echo "💰 Game Cost: 0.05 SUI per game"
echo ""

# Save deployment info
cat > deployment_info.json << EOF
{
  "package_id": "$PACKAGE_ID",
  "tx_digest": "$TX_DIGEST",
  "network": "testnet",
  "game_cost_sui": "0.05",
  "game_cost_mist": 50000000,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "💾 Deployment info saved to deployment_info.json"
echo ""
echo "🎯 Next Steps:"
echo "  1. Build frontend to create games and control robots"
echo "  2. Implement robot listeners for GameCreated/RobotMoved events"
echo "  3. Start playing! Users pay 0.05 SUI, robots earn and move"
echo ""
echo "🤖 Your robot control game is live! 🎮" 