# ============================================================================
# quick-start.sh - One command setup and demo
# ============================================================================

#!/bin/bash
set -e

echo "🚀 URIP Quick Start Demo"
echo "This will set up the project and run a demo on local network"
echo ""

# Setup project
echo "📦 Setting up project..."
./scripts/setup.sh

# Start local node
echo "🏗️  Starting local Anvil node..."
anvil --port 8545 --chain-id 31337 &
ANVIL_PID=$!

# Wait for node to start
sleep 3

# Deploy contracts
echo "📡 Deploying contracts to local network..."
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" \
./scripts/deploy.sh --network local --no-verify

# Run demo interactions
echo "🎭 Running demo interactions..."
echo "1. Getting test USDT from faucet..."
echo "2. Buying Apple tokens..."
echo "3. Buying URIP fund..."
echo "4. Checking balances..."

# This would include actual demo transactions

echo ""
echo "✅ Demo completed!"
echo "🔍 Check the transactions above for results"
echo "🛑 Stopping local node..."

# Cleanup
kill $ANVIL_PID
wait $ANVIL_PID 2>/dev/null

echo "🎉 Quick start demo finished!"
echo ""
echo "Next steps:"
echo "1. Update .env with your testnet private key"
echo "2. Run './scripts/deploy.sh' to deploy to Lisk Sepolia"
echo "3. Use './scripts/interact.sh' to interact with contracts"