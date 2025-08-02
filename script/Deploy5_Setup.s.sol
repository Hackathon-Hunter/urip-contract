// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/URIPContracts.sol";
import "../src/mocks/MockUSDT.sol";

contract Deploy5_Setup is Script {
    // UPDATE THESE ADDRESSES WITH YOUR DEPLOYED CONTRACTS
    address constant USDT_ADDRESS = 0x787B5E45F1Def0a126d2C93d39822E0a24BBC074;
    address constant URIP_ADDRESS = address(0); // UPDATE THIS
    address constant MANAGER_ADDRESS = address(0); // UPDATE THIS

    // Asset token addresses - update as needed
    address constant NVDA_ADDRESS = 0x15D4274E25E0DCC90cfDe1f26dec508000f771bD;
    address constant MSFT_ADDRESS = address(0); // UPDATE if deployed
    address constant AAPL_ADDRESS = address(0); // UPDATE if deployed
    address constant GOOG_ADDRESS = address(0); // UPDATE if deployed
    // Add more as needed...

    function run() public {
        require(URIP_ADDRESS != address(0), "Please update URIP_ADDRESS");
        require(MANAGER_ADDRESS != address(0), "Please update MANAGER_ADDRESS");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== SETTING UP URIP CONTRACTS ===");
        console.log("Setup by account:", deployer);
        console.log("");
        console.log("Contract addresses:");
        console.log("  USDT:", USDT_ADDRESS);
        console.log("  URIP:", URIP_ADDRESS);
        console.log("  Manager:", MANAGER_ADDRESS);
        console.log("  NVDA:", NVDA_ADDRESS);

        vm.startBroadcast(deployerPrivateKey);

        // Load contracts
        MockUSDT usdt = MockUSDT(USDT_ADDRESS);
        URIPToken urip = URIPToken(URIP_ADDRESS);
        PurchaseManager manager = PurchaseManager(MANAGER_ADDRESS);
        AssetToken nvda = AssetToken(NVDA_ADDRESS);

        // Setup Purchase Manager
        console.log("\n1. Setting up Purchase Manager...");

        // Set supported payment token
        manager.setSupportedPaymentToken(USDT_ADDRESS, true);
        console.log("✓ USDT set as supported payment token");

        // Set URIP fund
        manager.setURIPFund(URIP_ADDRESS);
        console.log("   ✓ URIP fund address set");

        // Set supported asset tokens
        if (NVDA_ADDRESS != address(0)) {
            manager.setSupportedAssetToken(NVDA_ADDRESS, true);
            console.log("   ✓ NVDA set as supported asset");
        }

        // Add more asset tokens here as needed
        /*
        if (MSFT_ADDRESS != address(0)) {
            manager.setSupportedAssetToken(MSFT_ADDRESS, true);
            console.log("   ✓ MSFT set as supported asset");
        }
        */

        console.log("\n2. Granting MINTER roles...");

        // Grant minter role to Purchase Manager on all tokens
        urip.grantRole(urip.MINTER_ROLE(), MANAGER_ADDRESS);
        console.log("   ✓ URIP minter role granted to Manager");

        if (NVDA_ADDRESS != address(0)) {
            nvda.grantRole(nvda.MINTER_ROLE(), MANAGER_ADDRESS);
            console.log("   ✓ NVDA minter role granted to Manager");
        }

        // Add more tokens here as needed

        console.log("\n3. Setting up URIP fund allocations...");

        // Set asset allocations (only if assets are deployed)
        if (NVDA_ADDRESS != address(0)) {
            urip.setAssetAllocation(NVDA_ADDRESS, 1200); // 12%
            console.log("   ✓ NVDA allocation set to 12%");
        }

        // Add more allocations as you deploy more assets
        /*
        if (MSFT_ADDRESS != address(0)) {
            urip.setAssetAllocation(MSFT_ADDRESS, 1000); // 10%
            console.log("   ✓ MSFT allocation set to 10%");
        }
        */

        vm.stopBroadcast();

        console.log("\n=== SETUP COMPLETED ===");
        console.log("✅ All contracts are now connected and ready to use!");

        console.log("\n=== TEST THE SYSTEM ===");
        console.log("1. Get test USDT from faucet:");
        console.log(
            "cast send",
            USDT_ADDRESS,
            '"faucet()" --rpc-url https://rpc.sepolia-api.lisk.com --private-key $PRIVATE_KEY'
        );

        console.log("\n2. Buy NVDA tokens with 100 USDT:");
        console.log("# First approve USDT spending");
        console.log(
            "cast send",
            USDT_ADDRESS,
            '"approve(address,uint256)"',
            MANAGER_ADDRESS,
            "100000000 --rpc-url https://rpc.sepolia-api.lisk.com --private-key $PRIVATE_KEY"
        );
        console.log("# Then purchase");
        console.log(
            "cast send",
            MANAGER_ADDRESS,
            '"purchaseAssetToken(address,address,uint256)"',
            USDT_ADDRESS,
            NVDA_ADDRESS,
            "100000000 --rpc-url https://rpc.sepolia-api.lisk.com --private-key $PRIVATE_KEY"
        );

        console.log("\n3. Buy URIP fund with 500 USDT:");
        console.log("# First approve USDT spending");
        console.log(
            "cast send",
            USDT_ADDRESS,
            '"approve(address,uint256)"',
            MANAGER_ADDRESS,
            "500000000 --rpc-url https://rpc.sepolia-api.lisk.com --private-key $PRIVATE_KEY"
        );
        console.log("# Then purchase fund");
        console.log(
            "cast send",
            MANAGER_ADDRESS,
            '"purchaseMutualFund(address,uint256)"',
            USDT_ADDRESS,
            "500000000 --rpc-url https://rpc.sepolia-api.lisk.com --private-key $PRIVATE_KEY"
        );

        console.log("\n4. Check your balances:");
        console.log(
            "cast call",
            NVDA_ADDRESS,
            '"balanceOf(address)(uint256)"',
            deployer,
            "--rpc-url https://rpc.sepolia-api.lisk.com"
        );
        console.log(
            "cast call",
            URIP_ADDRESS,
            '"balanceOf(address)(uint256)"',
            deployer,
            "--rpc-url https://rpc.sepolia-api.lisk.com"
        );
    }
}
