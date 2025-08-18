// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/URIPToken.sol";

/**
 * @title DeployUripToken
 * @dev Deployment script for UripToken with specific minter role assignment
 */
contract DeployUripToken is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Address to assign minter role to
        address minterAddress = 0x237B654Dc3C8b01ced3eC3303b0251dfb1ED1453;

        console.log("=== URIP TOKEN DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);
        console.log("Minter Address:", minterAddress);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy URIP Token
        console.log("Deploying URIP Token...");
        URIPToken uripToken = new URIPToken(
            "URIP Simple Fund", // name
            "URIP", // symbol
            1e18, // initial NAV: $1.00
            200 // management fee: 2%
        );
        console.log("URIP Token deployed at:", address(uripToken));

        // Grant minter role to specified address
        console.log("");
        console.log("Setting up permissions...");

        // Revoke minter role from deployer if needed
        // uripToken.revokeRole(uripToken.MINTER_ROLE(), deployer);

        // Grant minter role to specified address
        uripToken.grantRole(uripToken.MINTER_ROLE(), minterAddress);
        console.log("Minter role granted to:", minterAddress);

        vm.stopBroadcast();

        // Print Deployment Summary
        console.log("");
        console.log("=== DEPLOYMENT COMPLETED ===");
        console.log("");
        console.log("Contract Address:");
        console.log("URIP Token: ", address(uripToken));
        console.log("");
        console.log("Configuration:");
        console.log("Name: URIP Simple Fund");
        console.log("Symbol: URIP");
        console.log("Initial NAV: $1.00");
        console.log("Management Fee: 2%");
        console.log("Minter: ", minterAddress);
        console.log("");
    }
}
