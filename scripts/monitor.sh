# ============================================================================
# monitor.sh - Contract monitoring script
# ============================================================================

#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NETWORK="lisk_sepolia"
INTERVAL=30  # seconds

while [[ $# -gt 0 ]]; do
    case $1 in
        --network)
            NETWORK="$2"
            shift 2
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --network NETWORK    Target network"
            echo "  --interval SECONDS   Monitoring interval (default: 30)"
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}👀 Monitoring URIP contracts on $NETWORK${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}"
echo ""

# Monitoring loop
while true; do
    clear
    echo -e "${BLUE}=== URIP Contract Monitor ===${NC}"
    echo -e "${YELLOW}Network: $NETWORK${NC}"
    echo -e "${YELLOW}Time: $(date)${NC}"
    echo ""
    
    # Mock monitoring data - replace with actual contract calls
    echo -e "${GREEN}💰 Asset Prices:${NC}"
    echo "  AAPL: $150.25 (+0.5%)"
    echo "  TSLA: $198.50 (-0.8%)"
    echo "  GOOGL: $2785.00 (+1.2%)"
    echo "  GOLD: $1995.00 (-0.3%)"
    echo ""
    
    echo -e "${GREEN}📊 URIP Fund Stats:${NC}"
    echo "  NAV: $1.0234"
    echo "  Total Supply: 50,000 URIP"
    echo "  Total Assets: $51,170"
    echo ""
    
    echo -e "${GREEN}📈 Trading Volume (24h):${NC}"
    echo "  Apple Tokens: $12,500"
    echo "  Tesla Tokens: $8,750"
    echo "  URIP Fund: $25,000"
    echo ""
    
    echo -e "${YELLOW}Next update in $INTERVAL seconds...${NC}"
    sleep $INTERVAL
done