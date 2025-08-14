// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AssetToken.sol";
import "../src/URIPToken.sol";
import "../src/PurchaseManager.sol";
import "../src/mocks/MockUSDT.sol";

/**
 * @title Deploy
 * @dev Simple deployment script with AAPL and NVDA as example assets
 */
contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== SIMPLE URIP DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Mock USDT for testing
        console.log("1. Deploying Mock USDT...");
        MockUSDT usdt = new MockUSDT();
        console.log("   USDT deployed at:", address(usdt));

        // 2. Deploy Asset Tokens (AAPL and NVDA)
        console.log("");
        console.log("2. Deploying Asset Tokens...");

        AssetToken aaplToken = new AssetToken(
            "Tokenized Apple Stock", // name
            "tAAPL", // symbol
            "AAPL", // asset symbol
            "STOCK", // asset type
            230 * 1e8 // initial price: $230.00
        );
        console.log("   Apple Token (tAAPL) deployed at:", address(aaplToken));

        AssetToken nvdaToken = new AssetToken(
            "Tokenized NVIDIA Stock", // name
            "tNVDA", // symbol
            "NVDA", // asset symbol
            "STOCK", // asset type
            140 * 1e8 // initial price: $140.00
        );
        console.log("   NVIDIA Token (tNVDA) deployed at:", address(nvdaToken));

        // 3. Deploy URIP Mutual Fund Token
        console.log("");
        console.log("3. Deploying URIP Fund...");
        URIPToken uripToken = new URIPToken(
            "URIP Simple Fund", // name
            "URIP", // symbol
            1e18, // initial NAV: $1.00
            200 // management fee: 2%
        );
        console.log("   URIP Token deployed at:", address(uripToken));

        // 4. Deploy Purchase Manager
        console.log("");
        console.log("4. Deploying Purchase Manager...");
        PurchaseManager purchaseManager = new PurchaseManager();
        console.log(
            "   Purchase Manager deployed at:",
            address(purchaseManager)
        );

        // 5. Setup Configuration
        console.log("");
        console.log("5. Setting up configuration...");

        // Set supported payment token (USDT)
        purchaseManager.setSupportedPaymentToken(address(usdt), true);
        console.log("USDT set as payment token");

        // Set supported asset tokens
        purchaseManager.setSupportedAssetToken(address(aaplToken), true);
        purchaseManager.setSupportedAssetToken(address(nvdaToken), true);
        console.log("Asset tokens configured");

        // Set URIP fund in purchase manager
        purchaseManager.setURIPFund(address(uripToken));
        console.log("URIP fund configured");

        // 6. Grant Minter Roles
        console.log("");
        console.log("6. Setting up permissions...");

        // Grant minter role to purchase manager for asset tokens
        aaplToken.grantRole(aaplToken.MINTER_ROLE(), address(purchaseManager));
        nvdaToken.grantRole(nvdaToken.MINTER_ROLE(), address(purchaseManager));
        console.log("Asset token minter roles granted");

        // Grant minter role to purchase manager for URIP token
        uripToken.grantRole(uripToken.MINTER_ROLE(), address(purchaseManager));
        console.log("URIP token minter role granted");

        // 7. Setup URIP Fund Allocations (50% AAPL, 50% NVDA)
        console.log("");
        console.log("7. Setting up fund allocations...");

        uripToken.setAssetAllocation(address(aaplToken), 5000); // 50%
        uripToken.setAssetAllocation(address(nvdaToken), 5000); // 50%
        console.log("Fund allocations: 50% AAPL, 50% NVDA");

        vm.stopBroadcast();

        // 8. Print Deployment Summary
        console.log("");
        console.log("=== DEPLOYMENT COMPLETED ===");
        console.log("");
        console.log("Contract Addresses:");
        console.log("USDT (Mock):     ", address(usdt));
        console.log("Apple Token:     ", address(aaplToken));
        console.log("NVIDIA Token:    ", address(nvdaToken));
        console.log("URIP Fund:       ", address(uripToken));
        console.log("Purchase Manager:", address(purchaseManager));
        console.log("");

        console.log("Asset Prices:");
        console.log("AAPL: $230.00");
        console.log("NVDA: $140.00");
        console.log("URIP NAV: $1.00");
        console.log("");

        console.log("Fund Allocation:");
        console.log("Apple (AAPL): 50%");
        console.log("NVIDIA (NVDA): 50%");
        console.log("");

        console.log("Next Steps:");
        console.log("1. Get test USDT: usdt.faucet()");
        console.log("2. Approve USDT: usdt.approve(purchaseManager, amount)");
        console.log(
            "3. Buy AAPL: purchaseManager.purchaseAssetToken(usdt, aaplToken, amount)"
        );
        console.log(
            "4. Buy NVDA: purchaseManager.purchaseAssetToken(usdt, nvdaToken, amount)"
        );
        console.log(
            "5. Buy URIP: purchaseManager.purchaseURIPFund(usdt, amount)"
        );
        console.log("");

        console.log("Simple URIP deployment successful!");
    }
}
