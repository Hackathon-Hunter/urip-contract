// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/URIPContracts.sol";

contract Deploy2_URIPToken is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOYING URIP TOKEN ===");
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy URIP Mutual Fund Token
        URIPToken uripToken = new URIPToken(
            "URIP Global Mixed Fund", // name
            "URIP", // symbol
            1e18, // $1 initial NAV (18 decimals)
            200 // 2% management fee (200 basis points)
        );

        vm.stopBroadcast();

        console.log("\n=== DEPLOYMENT COMPLETED ===");
        console.log("URIPToken deployed at:", address(uripToken));

        // Get fund stats
        (
            uint256 totalValue,
            uint256 nav,
            uint256 totalTokens,
            uint256 managementFee
        ) = uripToken.getFundStats();

        console.log("Contract details:");
        console.log("  Name:", uripToken.name());
        console.log("  Symbol:", uripToken.symbol());
        console.log("  Decimals:", uripToken.decimals());
        console.log("  Initial NAV:", nav);
        console.log("  Management Fee:", managementFee, "basis points");
        console.log("  Total Supply:", totalTokens);

        console.log("\n=== REMIX VERIFICATION ===");
        console.log("To verify on Remix:");
        console.log("1. Go to https://remix.ethereum.org");
        console.log("2. Create new file: URIPContracts.sol");
        console.log("3. Copy src/URIPContracts.sol content");
        console.log("4. Import OpenZeppelin contracts");
        console.log("5. Compile with Solidity ^0.8.19");
        console.log("6. Deploy URIPToken contract");
        console.log("7. Constructor args:");
        console.log('   - name: "URIP Global Mixed Fund"');
        console.log('   - symbol: "URIP"');
        console.log("   - initialNAV: 1000000000000000000 (1e18)");
        console.log("   - managementFee: 200");
        console.log("8. At address:", address(uripToken));

        console.log("\n=== TEST COMMANDS ===");
        console.log("Check current NAV:");
        console.log(
            "cast call",
            address(uripToken),
            '"getCurrentNAV()(uint256,uint256)" --rpc-url https://rpc.sepolia-api.lisk.com'
        );

        console.log("\nCheck fund stats:");
        console.log(
            "cast call",
            address(uripToken),
            '"getFundStats()(uint256,uint256,uint256,uint256)" --rpc-url https://rpc.sepolia-api.lisk.com'
        );
    }
}
