#!/bin/bash
# ============================================================================
# deploy-governance.sh - URIP DAO Governance Deployment Script
# ============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║       URIP DAO GOVERNANCE              ║"
echo "║         DEPLOYMENT SCRIPT              ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Default values
NETWORK="lisk_sepolia"
CREATE_TEST_PROPOSALS=false
URIP_TOKEN_ADDRESS="0xcCe179a6A57060E393bbEA8F6b987E156BEf4f76"

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
        --urip-token)
            URIP_TOKEN_ADDRESS="$2"
            shift 2
            ;;
        --with-test-proposals)
            CREATE_TEST_PROPOSALS=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --network NETWORK          Target network (default: lisk_sepolia)"
            echo "  --local                    Deploy to local network"
            echo "  --urip-token ADDRESS       URIP token address (required)"
            echo "  --with-test-proposals      Create test proposals after deployment"
            echo "  -h, --help                 Show this help"
            echo ""
            echo "Example:"
            echo "  $0 --network lisk_sepolia --urip-token 0x123... --with-test-proposals"
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

if [ -z "$URIP_TOKEN_ADDRESS" ]; then
    echo -e "${RED}❌ URIP Token address not provided${NC}"
    echo -e "${YELLOW}Please provide URIP token address:${NC}"
    echo "$0 --urip-token 0x123..."
    echo ""
    echo "Or set environment variable:"
    echo "export URIP_TOKEN_ADDRESS=0x123..."
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

echo -e "${GREEN}✅ Prerequisites checked${NC}"
echo -e "${YELLOW}📡 Network: $NETWORK${NC}"
echo -e "${YELLOW}🔗 RPC URL: $RPC_URL${NC}"
echo -e "${YELLOW}🆔 Chain ID: $CHAIN_ID${NC}"
echo -e "${YELLOW}🏦 URIP Token: $URIP_TOKEN_ADDRESS${NC}"
echo ""

# Validate URIP token address format
if [[ ! $URIP_TOKEN_ADDRESS =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo -e "${RED}❌ Invalid URIP token address format${NC}"
    exit 1
fi

# Build contracts
echo -e "${BLUE}🔨 Building contracts...${NC}"
forge build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful${NC}"

# Export environment variables for the script
export URIP_TOKEN_ADDRESS="$URIP_TOKEN_ADDRESS"

# Deploy governance contracts
echo ""
echo -e "${BLUE}🚀 Deploying DAO Governance...${NC}"

forge script script/DeployGovernance.s.sol:DeployGovernance \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Governance deployment failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ DAO Governance deployment successful!${NC}"

# Extract deployment addresses
echo ""
echo -e "${BLUE}📋 Extracting contract addresses...${NC}"

RUN_LATEST=$(find broadcast/DeployGovernance.s.sol/$CHAIN_ID -name "run-latest.json" 2>/dev/null || echo "")

if [ -f "$RUN_LATEST" ]; then
    if command -v jq &> /dev/null; then
        GOVERNANCE_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "URIPDAOGovernance") | .contractAddress' "$RUN_LATEST" 2>/dev/null || echo "")
        HELPER_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "URIPDAOHelper") | .contractAddress' "$RUN_LATEST" 2>/dev/null || echo "")
    fi
fi


# Create comprehensive deployment summary
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SUMMARY_FILE="deployments/governance_${NETWORK}_${TIMESTAMP}.json"

mkdir -p deployments

cat > $SUMMARY_FILE << EOF
{
  "deployment": {
    "network": "$NETWORK",
    "chainId": "$CHAIN_ID",
    "timestamp": "$(date -Iseconds)",
    "deployer": "$(cast wallet address $PRIVATE_KEY 2>/dev/null || echo 'N/A')",
    "rpcUrl": "$RPC_URL",
    "explorer": "$EXPLORER"
  },
  "contracts": {
    "uripToken": "$URIP_TOKEN_ADDRESS",
    "daoGovernance": "${GOVERNANCE_ADDRESS:-"Check deployment logs"}",
    "daoHelper": "${HELPER_ADDRESS:-"Check deployment logs"}"
  },
  "governance": {
    "proposalThreshold": "1000 URIP tokens",
    "votingPeriod": "7 days",
    "timelockPeriod": "2 days",
    "quorumPercentage": "10%",
    "requireQuorum": true
  },
  "features": {
    "rebalancingProposals": true,
    "tokenBasedVoting": true,
    "timelockSecurity": true,
    "emergencyControls": true,
    "helperContract": true,
    "templateProposals": true
  }
}
EOF

echo -e "${GREEN}💾 Deployment summary saved to: $SUMMARY_FILE${NC}"

# Display final summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       DEPLOYMENT COMPLETED             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}📄 Deployed Contracts:${NC}"
echo "  • DAO Governance: ${GOVERNANCE_ADDRESS:-"Check logs"}"
echo "  • DAO Helper: ${HELPER_ADDRESS:-"Check logs"}"
echo "  • URIP Token: $URIP_TOKEN_ADDRESS"
echo ""

echo -e "${YELLOW}⚙️  Governance Settings:${NC}"
echo "  • Proposal Threshold: 1,000 URIP tokens"
echo "  • Voting Period: 7 days"
echo "  • Timelock Period: 2 days"
echo "  • Quorum Required: 10%"
echo ""

if [ -n "$EXPLORER" ] && [ "$NETWORK" != "local" ]; then
    echo -e "${YELLOW}🔍 Block Explorer: $EXPLORER${NC}"
    echo ""
fi

echo -e "${BLUE}🎯 How to Use the DAO:${NC}"
echo ""
echo -e "${YELLOW}1. Create a Rebalancing Proposal:${NC}"
echo "   Call: governance.createRebalancingProposal("
echo "     'Title', 'Description', [assets], [allocations])"
echo ""
echo -e "${YELLOW}2. Vote on Proposals:${NC}"
echo "   Call: governance.castVote(proposalId, support, reason)"
echo "   • support: true (for) or false (against)"
echo "   • Your voting power = your URIP token balance"
echo ""
echo -e "${YELLOW}3. Execute Approved Proposals:${NC}"
echo "   Call: governance.executeProposal(proposalId)"
echo "   • Only after voting period + timelock"
echo ""
echo -e "${YELLOW}4. Use Helper Contract for Easy Proposals:${NC}"
echo "   Call: helper.createSimpleRebalancing(...)"
echo "   Call: helper.createTemplateProposal(...)"
echo ""

echo -e "${PURPLE}🔧 Next Steps:${NC}"
echo ""
echo -e "${YELLOW}• Transfer admin roles to multisig for security${NC}"
echo -e "${YELLOW}• Create your first rebalancing proposal${NC}"
echo -e "${YELLOW}• Educate URIP holders about governance${NC}"
echo -e "${YELLOW}• Monitor proposal activity and voting${NC}"
echo ""

if [ "$NETWORK" == "local" ]; then
    echo -e "${BLUE}💡 Local Testing Tips:${NC}"
    echo "   • Make sure Anvil is running: anvil"
    echo "   • Use test accounts from Anvil output"
    echo "   • URIP holders can immediately create proposals"
    echo ""
fi

echo -e "${GREEN}🎉 DAO Governance is ready for community participation!${NC}"
echo -e "${GREEN}🗳️  URIP holders can now vote on fund management decisions!${NC}"
echo ""

# Offer to open explorer
if [ "$NETWORK" != "local" ] && [ -n "$GOVERNANCE_ADDRESS" ] && command -v xdg-open &> /dev/null 2>&1; then
    read -p "Open governance contract in block explorer? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        xdg-open "$EXPLORER/address/$GOVERNANCE_ADDRESS"
    fi
fi

# Save key addresses for future use
if [ -n "$GOVERNANCE_ADDRESS" ]; then
    echo "export GOVERNANCE_ADDRESS=$GOVERNANCE_ADDRESS" >> .env.governance
    echo "export HELPER_ADDRESS=$HELPER_ADDRESS" >> .env.governance
    echo "export URIP_TOKEN_ADDRESS=$URIP_TOKEN_ADDRESS" >> .env.governance
    echo ""
    echo -e "${GREEN}💾 Contract addresses saved to .env.governance${NC}"
    echo -e "${YELLOW}   Source this file: source .env.governance${NC}"
fi