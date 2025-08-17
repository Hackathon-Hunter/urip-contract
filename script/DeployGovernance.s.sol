// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/URIPDAOGovernance.sol";

/**
 * @title DeployGovernance
 * @dev Simple deployment script for URIP DAO Governance (without helper contract)
 *
 * This script deploys only the core governance contract and sets up basic configuration.
 * Use this if you want a minimal deployment or are having issues with the full deployment.
 */
contract DeployGovernance is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== URIP DAO GOVERNANCE SIMPLE DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);
        console.log("");

        // Get URIP token address from environment
        address uripTokenAddress = vm.envOr("URIP_TOKEN_ADDRESS", address(0));

        if (uripTokenAddress == address(0)) {
            console.log("ERROR: URIP_TOKEN_ADDRESS not provided");
            console.log("Please set URIP_TOKEN_ADDRESS environment variable");
            console.log("Example: export URIP_TOKEN_ADDRESS=0x123...");
            return;
        }

        console.log("URIP Token Address:", uripTokenAddress);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy DAO Governance Contract
        console.log("Deploying DAO Governance Contract...");
        URIPDAOGovernance governance = new URIPDAOGovernance(uripTokenAddress);
        console.log("DAO Governance deployed at:", address(governance));
        console.log("");

        // Set up basic roles
        console.log("Setting up roles...");
        governance.grantRole(governance.EXECUTOR_ROLE(), deployer);
        governance.grantRole(governance.EMERGENCY_ROLE(), deployer);
        console.log("Roles configured");
        console.log("");

        vm.stopBroadcast();

        // Display summary
        console.log("");
        console.log("========================================");
        console.log("     SIMPLE DEPLOYMENT COMPLETED       ");
        console.log("========================================");
        console.log("");
        console.log("CONTRACT ADDRESSES:");
        console.log("URIP Token:     ", uripTokenAddress);
        console.log("DAO Governance: ", address(governance));
        console.log("");
        console.log("GOVERNANCE SETTINGS:");
        console.log("- Proposal Threshold: 1,000 URIP tokens");
        console.log("- Voting Period: 7 days");
        console.log("- Timelock Period: 2 days");
        console.log("- Quorum Required: 10%");
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Create rebalancing proposals");
        console.log("2. URIP holders can vote on proposals");
        console.log("3. Execute approved proposals after timelock");
        console.log("");
        console.log("Simple DAO deployment successful!");
    }
}