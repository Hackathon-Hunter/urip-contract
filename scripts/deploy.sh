#!/bin/bash
# ============================================================================
# deploy.sh - URIP deployment with AAPL and NVDA
# ============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║         URIP DEPLOYMENT                ║"
echo "║         AAPL + NVDA Example            ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Default values
NETWORK="lisk_sepolia"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --local)
            NETWORK="local"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --network NETWORK    Target network (default: lisk_sepolia)"
            echo "  --local              Deploy to local network"
            echo "  -h, --help           Show this help"
            echo ""
            echo "This script deploys:"
            echo "  • Mock USDT (for testing)"
            echo "  • Apple Token (tAAPL)"
            echo "  • NVIDIA Token (tNVDA)"
            echo "  • URIP Fund (50% AAPL, 50% NVDA)"
            echo "  • Purchase Manager"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ Foundry not found. Please install Foundry first:${NC}"
    echo "curl -L https://foundry.paradigm.xyz | bash"
    echo "foundryup"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}❌ PRIVATE_KEY not set${NC}"
    echo -e "${YELLOW}Please set your private key:${NC}"
    echo "export PRIVATE_KEY=your_private_key_here"
    exit 1
fi

# Set network configuration
case $NETWORK in
    "lisk_sepolia")
        RPC_URL="https://rpc.sepolia-api.lisk.com"
        CHAIN_ID="4202"
        EXPLORER="https://sepolia-blockscout.lisk.com"
        ;;
    "local")
        RPC_URL="http://localhost:8545"
        CHAIN_ID="31337"
        EXPLORER="http://localhost:8545"
        ;;
    *)
        echo -e "${RED}❌ Unsupported network: $NETWORK${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}📡 Network: $NETWORK${NC}"
echo -e "${YELLOW}🔗 RPC URL: $RPC_URL${NC}"
echo -e "${YELLOW}🆔 Chain ID: $CHAIN_ID${NC}"
echo ""

# Build contracts
echo -e "${BLUE}🔨 Building contracts...${NC}"
forge build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful${NC}"

# Deploy contracts
echo ""
echo -e "${BLUE}🚀 Deploying contracts...${NC}"

forge script script/Deploy.s.sol:Deploy \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Deployment successful!${NC}"

# Get the latest run file to extract addresses
RUN_LATEST=$(find broadcast/Deploy.s.sol/$CHAIN_ID -name "run-latest.json" 2>/dev/null || echo "")

if [ -f "$RUN_LATEST" ]; then
    echo ""
    echo -e "${BLUE}📋 Extracting contract addresses...${NC}"
    
    # Extract addresses using jq if available, otherwise manual parsing
    if command -v jq &> /dev/null; then
        USDT_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "MockUSDT") | .contractAddress' "$RUN_LATEST" 2>/dev/null || echo "")
        AAPL_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "AssetToken" and (.arguments[] | contains("tAAPL"))) | .contractAddress' "$RUN_LATEST" 2>/dev/null || echo "")
        NVDA_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "AssetToken" and (.arguments[] | contains("tNVDA"))) | .contractAddress' "$RUN_LATEST" 2>/dev/null || echo "")
        URIP_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "URIPToken") | .contractAddress' "$RUN_LATEST" 2>/dev/null || echo "")
        MANAGER_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "PurchaseManager") | .contractAddress' "$RUN_LATEST" 2>/dev/null || echo "")
    fi
fi

# Create deployment summary
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SUMMARY_FILE="deployments/deploy_${NETWORK}_${TIMESTAMP}.json"

mkdir -p deployments

cat > $SUMMARY_FILE << EOF
{
  "network": "$NETWORK",
  "chainId": "$CHAIN_ID",
  "timestamp": "$(date -Iseconds)",
  "rpcUrl": "$RPC_URL",
  "explorer": "$EXPLORER",
  "contracts": {
    "mockUSDT": "${USDT_ADDRESS:-"Check deployment logs"}",
    "appleToken": "${AAPL_ADDRESS:-"Check deployment logs"}",
    "nvidiaToken": "${NVDA_ADDRESS:-"Check deployment logs"}",
    "uripToken": "${URIP_ADDRESS:-"Check deployment logs"}",
    "purchaseManager": "${MANAGER_ADDRESS:-"Check deployment logs"}"
  },
  "assets": {
    "AAPL": {
      "name": "Tokenized Apple Stock",
      "symbol": "tAAPL",
      "initialPrice": "$230.00",
      "allocation": "50%"
    },
    "NVDA": {
      "name": "Tokenized NVIDIA Stock", 
      "symbol": "tNVDA",
      "initialPrice": "$140.00",
      "allocation": "50%"
    }
  },
  "fund": {
    "name": "URIP Mutual Fund",
    "symbol": "URIP",
    "initialNAV": "$1.00",
    "managementFee": "2%"
  }
}
EOF

echo -e "${GREEN}💾 Deployment summary saved to: $SUMMARY_FILE${NC}"

# Display final summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          DEPLOYMENT COMPLETED          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📄 Deployed Assets:${NC}"
echo "  • Apple Stock Token (tAAPL) - $230.00"
echo "  • NVIDIA Stock Token (tNVDA) - $140.00"
echo "  • URIP Fund (50% AAPL + 50% NVDA)"
echo "  • Mock USDT (for testing)"
echo "  • Purchase Manager (trading hub)"
echo ""

if [ -n "$EXPLORER" ] && [ "$NETWORK" != "local" ]; then
    echo -e "${YELLOW}🔍 Explorer: $EXPLORER${NC}"
fi

echo -e "${YELLOW}📋 Summary File: $SUMMARY_FILE${NC}"
echo ""

echo -e "${BLUE}🎯 Quick Start Guide:${NC}"
echo ""
echo -e "${YELLOW}1. Get Test USDT:${NC}"
echo "   • Call faucet() on USDT contract"
echo "   • You'll receive 1,000 USDT for testing"
echo ""
echo -e "${YELLOW}2. Approve USDT:${NC}"
echo "   • approve(purchaseManager, amount) on USDT"
echo "   • This allows trading"
echo ""
echo -e "${YELLOW}3. Buy Assets:${NC}"
echo "   • purchaseAssetToken(usdt, appleToken, amount)"
echo "   • purchaseAssetToken(usdt, nvidiaToken, amount)"
echo "   • purchaseURIPFund(usdt, amount)"
echo ""
echo -e "${YELLOW}4. Check Balances:${NC}"
echo "   • balanceOf(yourAddress) on any token"
echo ""
echo -e "${YELLOW}5. Sell Assets:${NC}"
echo "   • sellAssetToken(usdt, appleToken, amount)"
echo "   • sellURIPFund(usdt, amount)"
echo ""

if [ "$NETWORK" == "local" ]; then
    echo -e "${BLUE}💡 Local Testing:${NC}"
    echo "   • Make sure Anvil is running: anvil"
    echo "   • Use account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    echo "   • Private key available in Anvil output"
fi

echo ""
echo -e "${GREEN}🎉 Ready to trade tokenized assets!${NC}"
echo ""

# Offer to open explorer
if [ "$NETWORK" != "local" ] && command -v xdg-open &> /dev/null 2>&1; then
    read -p "Open block explorer? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        xdg-open "$EXPLORER"
    fi
fi