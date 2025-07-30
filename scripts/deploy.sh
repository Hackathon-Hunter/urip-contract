# ============================================================================
# deploy.sh - Deployment automation
# ============================================================================

#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NETWORK="lisk_sepolia"
VERIFY=true
GAS_PRICE="1000000000" # 1 gwei

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --no-verify)
            VERIFY=false
            shift
            ;;
        --gas-price)
            GAS_PRICE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --network NETWORK    Target network (default: lisk_sepolia)"
            echo "  --no-verify          Skip contract verification"
            echo "  --gas-price PRICE    Gas price in wei (default: 1000000000)"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

# Check environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}❌ PRIVATE_KEY not set in environment${NC}"
    exit 1
fi

# Set RPC URL based on network
case $NETWORK in
    "lisk_sepolia")
        RPC_URL="https://rpc.sepolia-api.lisk.com"
        CHAIN_ID="4202"
        ;;
    "local")
        RPC_URL="http://localhost:8545"
        CHAIN_ID="31337"
        ;;
    *)
        echo -e "${RED}❌ Unsupported network: $NETWORK${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}🚀 Deploying URIP contracts to $NETWORK...${NC}"
echo -e "${YELLOW}Network: $NETWORK${NC}"
echo -e "${YELLOW}RPC URL: $RPC_URL${NC}"
echo -e "${YELLOW}Chain ID: $CHAIN_ID${NC}"
echo -e "${YELLOW}Gas Price: $GAS_PRICE wei${NC}"

# Build contracts
echo -e "${BLUE}🔨 Building contracts...${NC}"
forge build

# Deploy contracts
echo -e "${BLUE}📡 Deploying contracts...${NC}"

if [ "$VERIFY" = true ]; then
    forge script script/DeployURIP.s.sol:DeployURIP \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --broadcast \
        --verify \
        --gas-price $GAS_PRICE
else
    forge script script/DeployURIP.s.sol:DeployURIP \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --broadcast \
        --gas-price $GAS_PRICE
fi

# Save deployment info
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEPLOYMENT_FILE="deployments/${NETWORK}_${TIMESTAMP}.json"

echo -e "${BLUE}💾 Saving deployment info to $DEPLOYMENT_FILE...${NC}"

# Create deployment record (this would be populated by the actual deployment)
cat > $DEPLOYMENT_FILE << EOF
{
  "network": "$NETWORK",
  "chainId": "$CHAIN_ID",
  "timestamp": "$(date -Iseconds)",
  "gasPrice": "$GAS_PRICE",
  "contracts": {
    "note": "Contract addresses will be populated after deployment"
  }
}
EOF

echo -e "${GREEN}✅ Deployment completed!${NC}"
echo -e "${GREEN}📄 Deployment info saved to: $DEPLOYMENT_FILE${NC}"
