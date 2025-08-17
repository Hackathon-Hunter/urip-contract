// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PurchaseManager.sol";

/**
 * @title DeployPurchaseManager
 * @dev Script to deploy only the PurchaseManager contract
 *
 * Usage:
 * forge script script/DeployPurchaseManager.s.sol:DeployPurchaseManager --rpc-url https://rpc.sepolia-api.lisk.com --broadcast --private-key $PRIVATE_KEY
 */
contract DeployPurchaseManager is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== PURCHASE MANAGER DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);
        console.log("Network: Lisk Sepolia");
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy PurchaseManager
        console.log("Deploying PurchaseManager...");
        PurchaseManager purchaseManager = new PurchaseManager();
        console.log(
            "PurchaseManager deployed at:",
            address(purchaseManager)
        );

        vm.stopBroadcast();

        // Print deployment summary
        console.log("");
        console.log("=== DEPLOYMENT COMPLETED ===");
        console.log("");
        console.log("Contract Address:");
        console.log("PurchaseManager:", address(purchaseManager));
        console.log("");
        console.log("Next Steps:");
        console.log("1. Update deployments/sepolia.json with new address");
        console.log("2. Configure supported payment tokens:");
        console.log(
            "   purchaseManager.setSupportedPaymentToken(USDT_ADDRESS, true)"
        );
        console.log("3. Configure supported asset tokens:");
        console.log(
            "   purchaseManager.setSupportedAssetToken(ASSET_ADDRESS, true)"
        );
        console.log("4. Set URIP fund:");
        console.log("   purchaseManager.setURIPFund(URIP_TOKEN_ADDRESS)");
        console.log(
            "5. Grant necessary roles to the new contract on existing tokens"
        );
        console.log("");
        console.log("Remember to:");
        console.log("- Update your frontend config with the new address");
        console.log("- Verify the contract on block explorer");
        console.log(
            "- Grant MINTER_ROLE to this new PurchaseManager on existing tokens"
        );
    }
}
