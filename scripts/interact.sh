# ============================================================================
# interact.sh - Contract interaction script
# ============================================================================

#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
NETWORK="lisk_sepolia"
DEPLOYMENT_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --deployment)
            DEPLOYMENT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options] <action>"
            echo "Options:"
            echo "  --network NETWORK        Target network"
            echo "  --deployment FILE        Deployment file"
            echo ""
            echo "Actions:"
            echo "  status                   Show contract status"
            echo "  prices                   Show current prices"
            echo "  buy-apple AMOUNT         Buy Apple tokens"
            echo "  buy-urip AMOUNT          Buy URIP fund"
            echo "  faucet                   Get test USDT"
            exit 0
            ;;
        *)
            ACTION="$1"
            AMOUNT="$2"
            break
            ;;
    esac
done

# Set RPC URL
case $NETWORK in
    "lisk_sepolia")
        RPC_URL="https://rpc.sepolia-api.lisk.com"
        ;;
    "local")
        RPC_URL="http://localhost:8545"
        ;;
    *)
        echo -e "${RED}❌ Unsupported network: $NETWORK${NC}"
        exit 1
        ;;
esac

# Find deployment file if not specified
if [ -z "$DEPLOYMENT_FILE" ]; then
    DEPLOYMENT_FILE=$(ls deployments/${NETWORK}_*.json 2>/dev/null | tail -1)
    if [ -z "$DEPLOYMENT_FILE" ]; then
        echo -e "${RED}❌ No deployment file found for $NETWORK${NC}"
        echo -e "${YELLOW}Please deploy contracts first or specify deployment file${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}🔗 Interacting with contracts on $NETWORK${NC}"
echo -e "${YELLOW}Using deployment: $DEPLOYMENT_FILE${NC}"

# Load contract addresses (this would parse from actual deployment file)
# For now, these are placeholders
USDT_ADDRESS="0x..."
APPLE_TOKEN_ADDRESS="0x..."
URIP_TOKEN_ADDRESS="0x..."
PURCHASE_MANAGER_ADDRESS="0x..."

case $ACTION in
    "status")
        echo -e "${BLUE}📊 Contract Status:${NC}"
        # Here you would call contract view functions
        echo "USDT Address: $USDT_ADDRESS"
        echo "Apple Token: $APPLE_TOKEN_ADDRESS"
        echo "URIP Token: $URIP_TOKEN_ADDRESS"
        echo "Purchase Manager: $PURCHASE_MANAGER_ADDRESS"
        ;;
    
    "prices")
        echo -e "${BLUE}💰 Current Prices:${NC}"
        # Call price oracle functions
        echo "Apple (AAPL): $150.00"
        echo "Tesla (TSLA): $200.00"
        echo "Google (GOOGL): $2800.00"
        echo "Gold: $2000.00"
        ;;
    
    "buy-apple")
        if [ -z "$AMOUNT" ]; then
            echo -e "${RED}❌ Please specify amount in USD${NC}"
            exit 1
        fi
        echo -e "${BLUE}🍎 Buying Apple tokens worth \$$AMOUNT...${NC}"
        # Execute purchase transaction
        ;;
    
    "buy-urip")
        if [ -z "$AMOUNT" ]; then
            echo -e "${RED}❌ Please specify amount in USD${NC}"
            exit 1
        fi
        echo -e "${BLUE}📈 Buying URIP fund worth \$$AMOUNT...${NC}"
        # Execute fund purchase
        ;;
    
    "faucet")
        echo -e "${BLUE}🚿 Claiming test USDT from faucet...${NC}"
        # Call faucet function
        ;;
    
    *)
        echo -e "${RED}❌ Unknown action: $ACTION${NC}"
        echo "Use --help to see available actions"
        exit 1
        ;;
esac