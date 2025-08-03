// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "../src/URIPDAOGovernance.sol";
import "../src/URIPContracts.sol";
import "../src/mocks/MockUSDT.sol";

/**
 * @title DeployURIPGovernance
 * @dev Deployment script for URIP governance system using existing contracts
 */
contract DeployURIPGovernance is Script {
    // Existing contract addresses
    address constant MOCK_USDT = 0x787B5E45F1Def0a126d2C93d39822E0a24BBC074;
    address constant URIP_TOKEN = 0x3AA72870440488C55310EbfCCdCCD751dA331Da5;
    address constant PURCHASE_MANAGER =
        0x177d6Da3C6E37fF9b9E63fe5305d0b25Ea341F98;

    // Asset tokens
    address constant MSFT_TOKEN = 0x7a346368Cb82bcA986E16d91fa1846F3E2f2F081;
    address constant AAPL_TOKEN = 0xDf1A0E84Ad813a178CdCF6FDFeC1876F78BB471D;
    address constant GOOG_TOKEN = 0x067556D409D112376A5c68cdE223fdae3A4bd62b;
    address constant XAU_TOKEN = 0xf80567A323c99C99086D0d6884D7B03AFf5c8903;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log(
            "=== DEPLOYING URIP GOVERNANCE USING EXISTING CONTRACTS ==="
        );
        console.log("Using existing contracts:");
        console.log("  USDT:             ", MOCK_USDT);
        console.log("  URIP Token:       ", URIP_TOKEN);
        console.log("  Purchase Manager: ", PURCHASE_MANAGER);
        console.log("  AAPL Token:       ", AAPL_TOKEN);
        console.log("  MSFT Token:       ", MSFT_TOKEN);
        console.log("  GOOG Token:       ", GOOG_TOKEN);
        console.log("  XAU Token:        ", XAU_TOKEN);
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

        // Deploy Governance Helper
        URIPGovernanceHelper helper = new URIPGovernanceHelper(
            address(governance)
        );
        console.log("Governance Helper deployed at:", address(helper));

        // Configure governance roles and permissions
        console.log("");
        console.log("=== CONFIGURING PERMISSIONS ===");

        // Grant timelock role to deployer for initial setup
        governance.grantRole(governance.TIMELOCK_ROLE(), msg.sender);
        console.log("Granted timelock role to deployer");

        // Setup treasury budgets for initial operations
        MockUSDT usdt = MockUSDT(MOCK_USDT);
        console.log("Referenced existing USDT contract");

        // Get references to existing asset tokens for validation
        AssetToken appleToken = AssetToken(AAPL_TOKEN);
        AssetToken msftToken = AssetToken(MSFT_TOKEN);
        AssetToken googToken = AssetToken(GOOG_TOKEN);
        AssetToken xauToken = AssetToken(XAU_TOKEN);

        console.log("Referenced existing asset tokens");

        // Log asset token prices for verification
        console.log("Current asset prices:");
        {
            (uint256 aaplPrice, ) = appleToken.getCurrentPrice();
            (uint256 msftPrice, ) = msftToken.getCurrentPrice();
            (uint256 googPrice, ) = googToken.getCurrentPrice();
            (uint256 xauPrice, ) = xauToken.getCurrentPrice();
            console.log("  AAPL: $", aaplPrice / 1e8);
            console.log("  MSFT: $", msftPrice / 1e8);
            console.log("  GOOG: $", googPrice / 1e8);
            console.log("  XAU:  $", xauPrice / 1e8);
        }

        // Reference existing URIP token
        URIPToken uripToken = URIPToken(URIP_TOKEN);
        (uint256 nav, ) = uripToken.getCurrentNAV();
        console.log("Current URIP NAV: $", nav / 1e18);

        vm.stopBroadcast();

        // Log deployment summary
        console.log("");
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("Existing Contracts:");
        console.log("  USDT:             ", MOCK_USDT);
        console.log("  URIP Token:       ", URIP_TOKEN);
        console.log("  Purchase Manager: ", PURCHASE_MANAGER);
        console.log("  Asset Tokens:");
        console.log("    AAPL:           ", AAPL_TOKEN);
        console.log("    MSFT:           ", MSFT_TOKEN);
        console.log("    GOOG:           ", GOOG_TOKEN);
        console.log("    XAU:            ", XAU_TOKEN);
        console.log("");
        console.log("New DAO Contracts:");
        console.log("  Treasury Manager: ", address(treasuryManager));
        console.log("  DAO Governance:   ", address(governance));
        console.log("  Governance Helper:", address(helper));
        console.log("==========================================");

        console.log("");
        console.log("DAO Governance deployment completed!");
        console.log("Next steps:");
        console.log("  1. Set environment variables:");
        console.log("     export GOVERNANCE_ADDRESS=", address(governance));
        console.log(
            "     export TREASURY_MANAGER_ADDRESS=",
            address(treasuryManager)
        );
        console.log("     export GOVERNANCE_HELPER_ADDRESS=", address(helper));
        console.log("  2. Test governance with minimal proposal");
        console.log("  3. Configure additional treasury budgets as needed");
    }
}