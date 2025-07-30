# ============================================================================
# setup.sh - Initial project setup
# ============================================================================

#!/bin/bash
set -e

echo "🚀 Setting up URIP Smart Contracts..."

# Check if foundry is installed
if ! command -v forge &> /dev/null; then
    echo "❌ Foundry not found. Please install Foundry first:"
    echo "curl -L https://foundry.paradigm.xyz | bash"
    echo "foundryup"
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install foundry-rs/forge-std --no-commit

# Create necessary directories
mkdir -p script
mkdir -p test
mkdir -p deployments

# Copy environment file
if [ ! -f .env ]; then
    cp .env.example .env
    echo "📝 Created .env file. Please update with your configuration."
fi

# Build contracts
echo "🔨 Building contracts..."
forge build

# Run tests
echo "🧪 Running tests..."
forge test

echo "✅ Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Update .env file with your private key and RPC URL"
echo "2. Run 'make deploy-lisk-sepolia' to deploy to testnet"
echo "3. Use the deployed addresses to interact with contracts"