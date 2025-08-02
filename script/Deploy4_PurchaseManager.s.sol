// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/URIPContracts.sol";

contract Deploy4_PurchaseManager is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOYING PURCHASE MANAGER ===");
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Purchase Manager
        PurchaseManager purchaseManager = new PurchaseManager();

        vm.stopBroadcast();

        console.log("\n=== DEPLOYMENT COMPLETED ===");
        console.log("PurchaseManager deployed at:", address(purchaseManager));

        console.log("\n=== REMIX VERIFICATION ===");
        console.log("To verify on Remix:");
        console.log("1. Go to https://remix.ethereum.org");
        console.log("2. Create new file: URIPContracts.sol");
        console.log("3. Copy src/URIPContracts.sol content");
        console.log("4. Import OpenZeppelin contracts");
        console.log("5. Compile with Solidity ^0.8.19");
        console.log("6. Deploy PurchaseManager contract (no constructor args)");
        console.log("7. At address:", address(purchaseManager));

        console.log("\n=== SETUP INSTRUCTIONS ===");
        console.log("After deploying all contracts, you need to setup:");
        console.log("1. Set supported payment tokens (USDT)");
        console.log("2. Set supported asset tokens");
        console.log("3. Set URIP fund address");
        console.log("4. Grant MINTER_ROLE to Purchase Manager on all tokens");
        console.log("\nUse Deploy5_Setup.s.sol for automated setup");

        console.log("\n=== MANUAL SETUP COMMANDS ===");
        console.log("// Replace addresses with your deployed contracts");
        console.log('USDT_ADDRESS="0x..."');
        console.log('URIP_ADDRESS="0x..."');
        console.log('NVDA_ADDRESS="0x..."');
        console.log('MANAGER_ADDRESS="', address(purchaseManager), '"');
        console.log("");
        console.log("// Set supported payment token (USDT)");
        console.log(
            'cast send $MANAGER_ADDRESS "setSupportedPaymentToken(address,bool)" $USDT_ADDRESS true --rpc-url https://rpc.sepolia-api.lisk.com --private-key $PRIVATE_KEY'
        );
        console.log("");
        console.log("// Set URIP fund");
        console.log(
            'cast send $MANAGER_ADDRESS "setURIPFund(address)" $URIP_ADDRESS --rpc-url https://rpc.sepolia-api.lisk.com --private-key $PRIVATE_KEY'
        );
        console.log("");
        console.log("// Set supported asset token");
        console.log(
            'cast send $MANAGER_ADDRESS "setSupportedAssetToken(address,bool)" $NVDA_ADDRESS true --rpc-url https://rpc.sepolia-api.lisk.com --private-key $PRIVATE_KEY'
        );
        console.log("");
        console.log("// Grant minter role to manager (on each token)");
        console.log(
            'cast send $NVDA_ADDRESS "grantRole(bytes32,address)" 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6 $MANAGER_ADDRESS --rpc-url https://rpc.sepolia-api.lisk.com --private-key $PRIVATE_KEY'
        );
        console.log(
            'cast send $URIP_ADDRESS "grantRole(bytes32,address)" 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6 $MANAGER_ADDRESS --rpc-url https://rpc.sepolia-api.lisk.com --private-key $PRIVATE_KEY'
        );
    }
}
