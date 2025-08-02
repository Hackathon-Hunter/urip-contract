// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/mocks/MockUSDT.sol";

contract Deploy1_MockUSDT is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOYING MOCK USDT ===");
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Mock USDT
        MockUSDT usdt = new MockUSDT();

        vm.stopBroadcast();

        console.log("\n=== DEPLOYMENT COMPLETED ===");
        console.log("MockUSDT deployed at:", address(usdt));
        console.log("Contract details:");
        console.log("  Name:", usdt.name());
        console.log("  Symbol:", usdt.symbol());
        console.log("  Decimals:", usdt.decimals());
        console.log("  Initial Supply:", usdt.totalSupply());
        console.log("\n=== REMIX VERIFICATION ===");
        console.log("To verify on Remix:");
        console.log("1. Go to https://remix.ethereum.org");
        console.log("2. Create new file: MockUSDT.sol");
        console.log("3. Copy src/mocks/MockUSDT.sol content");
        console.log("4. Compile with Solidity ^0.8.19");
        console.log("5. Use Lisk Sepolia network");
        console.log("6. At address:", address(usdt));
        
        console.log("\n=== TEST COMMANDS ===");
        console.log("Get 1000 USDT from faucet:");
        console.log("cast send", address(usdt), '"faucet()" --rpc-url https://rpc.sepolia-api.lisk.com --private-key $PRIVATE_KEY');
        
        console.log("\nCheck balance:");
        console.log("cast call", address(usdt), '"balanceOf(address)(uint256)"', deployer, "--rpc-url https://rpc.sepolia-api.lisk.com");
    }
}