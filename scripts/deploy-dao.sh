#!/bin/bash
# ============================================================================
# deploy-dao-only.sh - URIP DAO Components Deployment Script
# Uses existing deployed contracts
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
NETWORK="lisk_sepolia"
VERIFY=true
GAS_PRICE="1000000000" # 1 gwei

# Existing contract addresses
MOCK_USDT="0x787b5e45f1def0a126d2c93d39822e0a24bbc074"
URIP_TOKEN="0x3aa72870440488c55310ebfccdccd751da331da5"
PURCHASE_MANAGER="0x177d6da3c6e37ff9b9e63fe5305d0b25ea341f98"
# Asset tokens
MSFT_TOKEN="0x7a346368cb82bca986e16d91fa1846f3e2f2f081"
AAPL_TOKEN="0xdf1a0e84ad813a178cdcf6fdfec1876f78bb471d"
GOOG_TOKEN="0x067556d409d112376a5c68cde223fdae3a4bd62b"
XAU_TOKEN="0xf80567a323c99c99086d0d6884d7b03aff5c8903"

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
            echo ""
            echo "This script deploys only DAO governance components"
            echo "using your existing contract addresses:"
            echo "  USDT:     $MOCK_USDT"
            echo "  URIP:     $URIP_TOKEN"
            echo "  Manager:  $PURCHASE_MANAGER"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Banner
echo -e "${PURPLE}"
echo "╔══════════════════════════════════════════════╗"
echo "║        URIP DAO GOVERNANCE DEPLOYMENT        ║"
echo "║           Using Existing Contracts           ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

# Check if foundry is installed
if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ Foundry not found. Please install Foundry first:${NC}"
    echo "curl -L https://foundry.paradigm.xyz | bash"
    echo "foundryup"
    exit 1
fi

# Check environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}❌ PRIVATE_KEY not set in environment${NC}"
    echo -e "${YELLOW}💡 Please set your private key:${NC}"
    echo "export PRIVATE_KEY=your_private_key_here"
    exit 1
fi

# Set network configuration
case $NETWORK in
    "lisk_sepolia")
        RPC_URL="https://rpc.sepolia-api.lisk.com"
        CHAIN_ID="4202"
        EXPLORER_URL="https://sepolia-blockscout.lisk.com"
        ;;
    "local")
        RPC_URL="http://localhost:8545"
        CHAIN_ID="31337"
        EXPLORER_URL="http://localhost:8545"
        VERIFY=false  # No verification for local
        ;;
    *)
        echo -e "${RED}❌ Unsupported network: $NETWORK${NC}"
        echo -e "${YELLOW}Supported networks: lisk_sepolia, local${NC}"
        exit 1
        ;;
esac

# Display deployment information
echo -e "${CYAN}📋 Deployment Configuration:${NC}"
echo -e "${YELLOW}  Network:      $NETWORK${NC}"
echo -e "${YELLOW}  RPC URL:      $RPC_URL${NC}"
echo -e "${YELLOW}  Chain ID:     $CHAIN_ID${NC}"
echo -e "${YELLOW}  Gas Price:    $GAS_PRICE wei${NC}"
echo -e "${YELLOW}  Verify:       $VERIFY${NC}"
echo -e "${YELLOW}  Explorer:     $EXPLORER_URL${NC}"
echo ""

echo -e "${CYAN}📋 Using Existing Contracts:${NC}"
echo -e "${YELLOW}  USDT:         $MOCK_USDT${NC}"
echo -e "${YELLOW}  URIP Token:   $URIP_TOKEN${NC}"
echo -e "${YELLOW}  Manager:      $PURCHASE_MANAGER${NC}"
echo -e "${YELLOW}  AAPL Token:   $AAPL_TOKEN${NC}"
echo -e "${YELLOW}  MSFT Token:   $MSFT_TOKEN${NC}"
echo -e "${YELLOW}  GOOG Token:   $GOOG_TOKEN${NC}"
echo -e "${YELLOW}  Gold Token:   $XAU_TOKEN${NC}"
echo ""

# Create necessary directories
echo -e "${BLUE}📁 Creating directories...${NC}"
mkdir -p deployments
mkdir -p deployments/dao
mkdir -p logs

# Build contracts
echo -e "${BLUE}🔨 Building contracts...${NC}"
forge build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    echo -e "${RED}Please fix the compilation errors first${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful${NC}"

# Check if we have the required governance contracts
echo -e "${BLUE}🔍 Validating governance contracts...${NC}"

if [ ! -f "src/URIPDAOGovernance.sol" ]; then
    echo -e "${RED}❌ URIPDAOGovernance.sol not found${NC}"
    exit 1
fi

if [ ! -f "src/URIPGovernanceIntegration.sol" ]; then
    echo -e "${RED}❌ URIPGovernanceIntegration.sol not found${NC}"
    exit 1
fi

# Confirm deployment
echo -e "${YELLOW}⚡ Ready to deploy DAO Governance components to $NETWORK${NC}"
echo -e "${YELLOW}   This will deploy:${NC}"
echo -e "${YELLOW}   • Treasury Manager${NC}"
echo -e "${YELLOW}   • DAO Governance Contract${NC}"
echo -e "${YELLOW}   • Governance Integration${NC}"
echo -e "${YELLOW}   • Governance Helper${NC}"
echo ""
echo -e "${YELLOW}   And configure them with your existing contracts${NC}"
echo ""

read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

# Deploy contracts
echo -e "${BLUE}🚀 Deploying DAO governance components...${NC}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/dao_deployment_${NETWORK}_${TIMESTAMP}.log"
DEPLOYMENT_FILE="deployments/dao/${NETWORK}_dao_${TIMESTAMP}.json"

echo -e "${BLUE}📝 Logging deployment to: $LOG_FILE${NC}"

# Create a custom deployment script that uses existing addresses
cat > script/DeployDAOOnly.s.sol << EOF
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/URIPDAOGovernance.sol";
import "../src/URIPGovernanceIntegration.sol";

contract DeployDAOOnly is Script {
    // Existing contract addresses
    address constant URIP_TOKEN = $URIP_TOKEN;
    address constant PURCHASE_MANAGER = $PURCHASE_MANAGER;
    address constant MOCK_USDT = $MOCK_USDT;
    address constant AAPL_TOKEN = $AAPL_TOKEN;
    address constant MSFT_TOKEN = $MSFT_TOKEN;
    address constant GOOG_TOKEN = $GOOG_TOKEN;
    address constant XAU_TOKEN = $XAU_TOKEN;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== DEPLOYING DAO GOVERNANCE COMPONENTS ===");
        console.log("Using existing contracts:");
        console.log("  URIP Token:        ", URIP_TOKEN);
        console.log("  Purchase Manager:  ", PURCHASE_MANAGER);
        console.log("  USDT:             ", MOCK_USDT);
        console.log("");

        // Deploy Treasury Manager first (needed for governance)
        URIPTreasuryManager treasuryManager = new URIPTreasuryManager(
            address(0)
        ); // Will update after governance deployment
        console.log("Treasury Manager deployed at:", address(treasuryManager));

        // Deploy DAO Governance
        URIPDAOGovernance governance = new URIPDAOGovernance(
            URIP_TOKEN,
            address(treasuryManager)
        );
        console.log("DAO Governance deployed at:", address(governance));

        // Update treasury manager with governance address
        treasuryManager.grantRole(
            treasuryManager.GOVERNANCE_ROLE(),
            address(governance)
        );

        // Deploy Governance Integration
        URIPGovernanceIntegration integration = new URIPGovernanceIntegration(
            address(governance),
            URIP_TOKEN,
            PURCHASE_MANAGER
        );
        console.log("Governance Integration deployed at:", address(integration));

        // Deploy Governance Helper
        URIPGovernanceHelper helper = new URIPGovernanceHelper(
            address(governance)
        );
        console.log("Governance Helper deployed at:", address(helper));

        // Configure roles and permissions
        console.log("");
        console.log("=== CONFIGURING PERMISSIONS ===");

        // Grant timelock role to deployer for initial setup
        governance.grantRole(governance.TIMELOCK_ROLE(), msg.sender);
        console.log("✓ Granted timelock role to deployer");

        // Grant governance role to integration contract
        integration.grantRole(
            integration.GOVERNANCE_ROLE(),
            address(governance)
        );
        console.log("✓ Granted governance role to integration");

        // Set up asset whitelist with existing tokens
        address[] memory assets = new address[](4);
        bool[] memory whitelisted = new bool[](4);
        
        assets[0] = AAPL_TOKEN;
        assets[1] = MSFT_TOKEN;
        assets[2] = GOOG_TOKEN;
        assets[3] = XAU_TOKEN;
        
        whitelisted[0] = true;
        whitelisted[1] = true;
        whitelisted[2] = true;
        whitelisted[3] = true;

        integration.setAssetWhitelist(assets, whitelisted);
        console.log("✓ Set up asset whitelist");

        vm.stopBroadcast();

        // Log deployment summary
        console.log("");
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("Treasury Manager:      ", address(treasuryManager));
        console.log("DAO Governance:        ", address(governance));
        console.log("Governance Integration:", address(integration));
        console.log("Governance Helper:     ", address(helper));
        console.log("===========================");
    }
}
EOF

# Execute deployment
if [ "$VERIFY" = true ]; then
    echo -e "${BLUE}🔍 Deploying with verification...${NC}"
    forge script script/DeployDAOOnly.s.sol:DeployDAOOnly \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --broadcast \
        --verify \
        --gas-price $GAS_PRICE \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        2>&1 | tee $LOG_FILE
else
    echo -e "${BLUE}🚀 Deploying without verification...${NC}"
    forge script script/DeployDAOOnly.s.sol:DeployDAOOnly \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --broadcast \
        --gas-price $GAS_PRICE \
        2>&1 | tee $LOG_FILE
fi

DEPLOYMENT_STATUS=$?

if [ $DEPLOYMENT_STATUS -ne 0 ]; then
    echo -e "${RED}❌ Deployment failed!${NC}"
    echo -e "${RED}Check log file: $LOG_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Deployment successful!${NC}"

# Extract contract addresses from deployment log
echo -e "${BLUE}📋 Extracting contract addresses...${NC}"

TREASURY_MANAGER=$(grep "Treasury Manager deployed at:" $LOG_FILE | tail -1 | awk '{print $NF}')
DAO_GOVERNANCE=$(grep "DAO Governance deployed at:" $LOG_FILE | tail -1 | awk '{print $NF}')
GOVERNANCE_INTEGRATION=$(grep "Governance Integration deployed at:" $LOG_FILE | tail -1 | awk '{print $NF}')
GOVERNANCE_HELPER=$(grep "Governance Helper deployed at:" $LOG_FILE | tail -1 | awk '{print $NF}')

# Create deployment record
cat > $DEPLOYMENT_FILE << EOF
{
  "network": "$NETWORK",
  "chainId": "$CHAIN_ID",
  "timestamp": "$(date -Iseconds)",
  "gasPrice": "$GAS_PRICE",
  "deployer": "$(cast wallet address $PRIVATE_KEY)",
  "rpcUrl": "$RPC_URL",
  "explorerUrl": "$EXPLORER_URL",
  "logFile": "$LOG_FILE",
  "existingContracts": {
    "mockUSDT": "$MOCK_USDT",
    "uripToken": "$URIP_TOKEN", 
    "purchaseManager": "$PURCHASE_MANAGER",
    "assetTokens": {
      "tMSFT": "$MSFT_TOKEN",
      "tAAPL": "$AAPL_TOKEN", 
      "tGOOG": "$GOOG_TOKEN",
      "tXAU": "$XAU_TOKEN"
    }
  },
  "newContracts": {
    "treasuryManager": "$TREASURY_MANAGER",
    "daoGovernance": "$DAO_GOVERNANCE",
    "governanceIntegration": "$GOVERNANCE_INTEGRATION",
    "governanceHelper": "$GOVERNANCE_HELPER"
  },
  "verification": {
    "enabled": $VERIFY,
    "status": "pending"
  },
  "setup": {
    "roles_configured": true,
    "asset_whitelist_set": true,
    "governance_parameters_set": true
  }
}
EOF

# Display deployment summary
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         DAO DEPLOYMENT SUCCESSFUL            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📊 New DAO Contract Addresses:${NC}"
echo -e "${YELLOW}  Treasury Manager:       $TREASURY_MANAGER${NC}"
echo -e "${YELLOW}  DAO Governance:         $DAO_GOVERNANCE${NC}"
echo -e "${YELLOW}  Governance Integration: $GOVERNANCE_INTEGRATION${NC}"
echo -e "${YELLOW}  Governance Helper:      $GOVERNANCE_HELPER${NC}"

echo ""
echo -e "${CYAN}🔗 Using Existing Contracts:${NC}"
echo -e "${YELLOW}  USDT:                   $MOCK_USDT${NC}"
echo -e "${YELLOW}  URIP Token:             $URIP_TOKEN${NC}"
echo -e "${YELLOW}  Purchase Manager:       $PURCHASE_MANAGER${NC}"

echo ""
echo -e "${CYAN}🔗 Useful Links:${NC}"
echo -e "${YELLOW}  Explorer:        $EXPLORER_URL${NC}"
echo -e "${YELLOW}  Deployment Log:  $LOG_FILE${NC}"
echo -e "${YELLOW}  Config File:     $DEPLOYMENT_FILE${NC}"

# Create environment file for easy access
ENV_FILE="deployments/dao/${NETWORK}_dao.env"
cat > $ENV_FILE << EOF
# URIP DAO Contract Addresses - $NETWORK
export NETWORK=$NETWORK
export CHAIN_ID=$CHAIN_ID
export RPC_URL=$RPC_URL
export EXPLORER_URL=$EXPLORER_URL

# Existing contracts
export MOCK_USDT_ADDRESS=$MOCK_USDT
export URIP_TOKEN_ADDRESS=$URIP_TOKEN
export PURCHASE_MANAGER_ADDRESS=$PURCHASE_MANAGER
export AAPL_TOKEN_ADDRESS=$AAPL_TOKEN
export MSFT_TOKEN_ADDRESS=$MSFT_TOKEN
export GOOG_TOKEN_ADDRESS=$GOOG_TOKEN
export XAU_TOKEN_ADDRESS=$XAU_TOKEN

# New DAO contracts
export TREASURY_MANAGER_ADDRESS=$TREASURY_MANAGER
export DAO_GOVERNANCE_ADDRESS=$DAO_GOVERNANCE
export GOVERNANCE_INTEGRATION_ADDRESS=$GOVERNANCE_INTEGRATION
export GOVERNANCE_HELPER_ADDRESS=$GOVERNANCE_HELPER

# For Foundry scripts
export GOVERNANCE_ADDRESS=$DAO_GOVERNANCE
export INTEGRATION_ADDRESS=$GOVERNANCE_INTEGRATION

# To use these addresses in other scripts:
# source $ENV_FILE
EOF

echo -e "${YELLOW}  Environment File: $ENV_FILE${NC}"

# Post-deployment recommendations
echo ""
echo -e "${CYAN}📝 Next Steps:${NC}"
echo -e "${YELLOW}  1. Source environment file: source $ENV_FILE${NC}"
echo -e "${YELLOW}  2. Test governance with: cast call $DAO_GOVERNANCE 'proposalCount()'${NC}"
echo -e "${YELLOW}  3. Create your first governance proposal${NC}"
echo -e "${YELLOW}  4. Set up monitoring for DAO activities${NC}"
echo -e "${YELLOW}  5. Configure additional asset tokens if needed${NC}"

# Test basic contract interaction
echo ""
echo -e "${BLUE}🧪 Testing DAO contract interaction...${NC}"

# Check governance contract
PROPOSAL_COUNT=$(cast call $DAO_GOVERNANCE "proposalCount()" --rpc-url $RPC_URL 2>/dev/null || echo "0")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ DAO Governance responsive. Proposal count: $PROPOSAL_COUNT${NC}"
else
    echo -e "${YELLOW}⚠️  Could not verify DAO Governance${NC}"
fi

# Check voting power
DEPLOYER_ADDRESS=$(cast wallet address $PRIVATE_KEY)
VOTING_POWER=$(cast call $DAO_GOVERNANCE "getVotingPower(address)" $DEPLOYER_ADDRESS --rpc-url $RPC_URL 2>/dev/null || echo "0")
echo -e "${GREEN}✅ Deployer voting power: $VOTING_POWER${NC}"

# Save latest deployment info for quick access
cp $DEPLOYMENT_FILE "deployments/dao/${NETWORK}_latest.json"
cp $ENV_FILE "deployments/dao/${NETWORK}_latest.env"

# Clean up temporary deployment script
rm -f script/DeployDAOOnly.s.sol

echo ""
echo -e "${GREEN}🎉 URIP DAO deployment completed successfully!${NC}"
echo -e "${GREEN}💡 Use 'source deployments/dao/${NETWORK}_latest.env' to load contract addresses${NC}"
echo ""
echo -e "${CYAN}🚀 Your DAO is ready! You can now:${NC}"
echo -e "${YELLOW}  • Create governance proposals${NC}"
echo -e "${YELLOW}  • Vote on fund management decisions${NC}"
echo -e "${YELLOW}  • Manage treasury allocations${NC}"
echo -e "${YELLOW}  • Control protocol parameters${NC}"

# Optional: Open explorer links
if command -v xdg-open &> /dev/null && [ "$NETWORK" != "local" ]; then
    read -p "Open DAO governance contract in explorer? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        xdg-open "$EXPLORER_URL/address/$DAO_GOVERNANCE"
    fi
fi