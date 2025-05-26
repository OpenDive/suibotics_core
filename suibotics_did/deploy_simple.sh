#!/bin/bash

# Simple Suibotics Core Testnet Deployment Script
# Quick deployment without extensive logging

set -e

echo "🚀 Deploying Suibotics Core to Testnet..."

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
echo "🔨 Building package..."
sui move build

# Run tests
echo "🧪 Running tests..."
sui move test

# Deploy
echo "📦 Publishing to testnet..."
RESULT=$(sui client publish --gas-budget 100000000 --json)

# Extract package ID
PACKAGE_ID=$(echo "$RESULT" | jq -r '.objectChanges[] | select(.type == "published") | .packageId')
TX_DIGEST=$(echo "$RESULT" | jq -r '.digest')

echo ""
echo "✅ Deployment successful!"
echo "📦 Package ID: $PACKAGE_ID"
echo "🔗 Transaction: $TX_DIGEST"
echo "🌐 Explorer: https://suiscan.xyz/testnet/object/$PACKAGE_ID"
echo ""

# Save deployment info
echo "{\"package_id\":\"$PACKAGE_ID\",\"tx_digest\":\"$TX_DIGEST\",\"network\":\"testnet\"}" > deployment_info.json
echo "💾 Deployment info saved to deployment_info.json" 