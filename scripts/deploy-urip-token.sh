#!/bin/bash

# Colors for console output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color
RPC_URL="https://rpc.sepolia-api.lisk.com"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}       URIP TOKEN DEPLOYMENT           ${NC}"
echo -e "${BLUE}========================================${NC}"

# Check if .env file exists and load it
if [ -f .env ]; then
    echo -e "${BLUE}Loading environment variables from .env${NC}"
    source .env
else
    echo -e "${RED}No .env file found. Please create one with the required variables.${NC}"
    exit 1
fi

# Ensure required environment variables are set
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}Error: PRIVATE_KEY is not set in .env${NC}"
    exit 1
fi

if [ -z "$RPC_URL" ]; then
    echo -e "${RED}Error: RPC_URL is not set in .env${NC}"
    exit 1
fi

# Get the network name from the RPC URL
if [[ $RPC_URL == *"sepolia"* ]]; then
    NETWORK="sepolia"
    CHAIN_ID=11155111
    EXPLORER="https://sepolia-blockscout.lisk.com"
elif [[ $RPC_URL == *"goerli"* ]]; then
    NETWORK="goerli"
    CHAIN_ID=5
    EXPLORER="https://goerli.etherscan.io"
elif [[ $RPC_URL == *"mainnet"* ]]; then
    NETWORK="mainnet"
    CHAIN_ID=1
    EXPLORER="https://etherscan.io"
else
    NETWORK="custom"
    echo -e "${BLUE}Custom network detected from RPC URL.${NC}"
    read -p "Please enter the chain ID: " CHAIN_ID
    read -p "Please enter the explorer URL (or press enter to skip): " EXPLORER
fi

echo -e "${BLUE}Network: ${NETWORK}${NC}"
echo -e "${BLUE}Chain ID: ${CHAIN_ID}${NC}"
echo -e "${BLUE}Explorer: ${EXPLORER}${NC}"
echo ""

# Build contracts
echo -e "${BLUE}Building contracts...${NC}"
forge build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful${NC}"

# Deploy UripToken contract
echo ""
echo -e "${BLUE}🚀 Deploying UripToken contract...${NC}"

forge script script/DeployUripToken.s.sol:DeployUripToken \
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
RUN_LATEST=$(find broadcast/DeployUripToken.s.sol/$CHAIN_ID -name "run-latest.json" 2>/dev/null || echo "")

if [ -f "$RUN_LATEST" ]; then
    echo ""
    echo -e "${BLUE}📋 Extracting contract address...${NC}"
    
    # Extract address using jq if available, otherwise manual parsing
    if command -v jq &> /dev/null; then
        URIP_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "URIPToken") | .contractAddress' "$RUN_LATEST" 2>/dev/null || echo "")
    fi
fi

# Create deployment summary
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SUMMARY_FILE="deployments/urip_deploy_${NETWORK}_${TIMESTAMP}.json"

mkdir -p deployments

cat > $SUMMARY_FILE << EOF
{
  "network": "$NETWORK",
  "chainId": "$CHAIN_ID",
  "timestamp": "$(date -Iseconds)",
  "rpcUrl": "$RPC_URL",
  "explorer": "$EXPLORER",
  "contracts": {
    "uripToken": "${URIP_ADDRESS:-"Check deployment logs"}"
  },
  "configuration": {
    "name": "URIP Simple Fund",
    "symbol": "URIP",
    "initialNAV": "$1.00",
    "managementFee": "2%",
    "minter": "0x237B654Dc3C8b01ced3eC3303b0251dfb1ED1453"
  }
}
EOF

echo -e "${GREEN}Deployment summary saved to ${SUMMARY_FILE}${NC}"
echo ""
echo -e "${GREEN}UripToken deployment complete!${NC}"