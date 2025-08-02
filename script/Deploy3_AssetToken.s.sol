// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/URIPContracts.sol";

contract Deploy3_AssetToken is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOYING ASSET TOKENS ===");
        console.log("Choose which asset to deploy:");
        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy one asset at a time - you can modify this to deploy different assets
        // Comment/uncomment the asset you want to deploy

        // US S&P 500 Stocks
        AssetToken nvdaToken = deployAssetToken(
            "Tokenized NVIDIA Stock",
            "tNVDA",
            "NVDA",
            "STOCK_SP500",
            140 * 1e8 // $140
        );

        /*
        AssetToken msftToken = deployAssetToken(
            "Tokenized Microsoft Stock",
            "tMSFT",
            "MSFT", 
            "STOCK_SP500",
            415 * 1e8  // $415
        );

        AssetToken aaplToken = deployAssetToken(
            "Tokenized Apple Stock",
            "tAAPL",
            "AAPL",
            "STOCK_SP500", 
            230 * 1e8  // $230
        );

        AssetToken googToken = deployAssetToken(
            "Tokenized Alphabet Stock",
            "tGOOG",
            "GOOG",
            "STOCK_SP500",
            175 * 1e8  // $175
        );

        // Singapore SGX Stock
        AssetToken dbsToken = deployAssetToken(
            "Tokenized DBS Group Holdings",
            "tD05",
            "D05",
            "STOCK_SGX",
            35 * 1e8   // $35 SGD
        );

        // Indonesia IDX Stock
        AssetToken brenToken = deployAssetToken(
            "Tokenized Barito Renewables", 
            "tBREN",
            "BREN",
            "STOCK_IDX",
            4200       // IDR 4,200
        );

        // Thailand BKK Stock
        AssetToken deltaToken = deployAssetToken(
            "Tokenized Delta Electronics",
            "tDELTA",
            "DELTA",
            "STOCK_BKK", 
            175 * 1e8  // 175 THB
        );

        // Malaysia MYX Stock
        AssetToken maybankToken = deployAssetToken(
            "Tokenized Maybank",
            "tMAYBANK",
            "MAYBANK",
            "STOCK_MYX",
            10 * 1e8   // 10 MYR
        );

        // Precious Metals
        AssetToken goldToken = deployAssetToken(
            "Tokenized Gold",
            "tXAU",
            "XAU",
            "COMMODITY_METAL",
            2650 * 1e8 // $2,650 per oz
        );

        AssetToken silverToken = deployAssetToken(
            "Tokenized Silver",
            "tXAG", 
            "XAG",
            "COMMODITY_METAL",
            31 * 1e8   // $31 per oz
        );

        // Cryptocurrency
        AssetToken btcToken = deployAssetToken(
            "Tokenized Bitcoin",
            "tBTC",
            "BTC",
            "CRYPTOCURRENCY",
            100000 * 1e8 // $100,000
        );
        */

        vm.stopBroadcast();

        printAssetInfo(nvdaToken);

        console.log("\n=== NEXT STEPS ===");
        console.log(
            "1. Deploy other assets by uncommenting them in the script"
        );
        console.log("2. Verify each contract on Remix");
        console.log(
            "3. Deploy Purchase Manager (Deploy4_PurchaseManager.s.sol)"
        );
        console.log("4. Setup contracts with roles and permissions");
    }

    function deployAssetToken(
        string memory name,
        string memory symbol,
        string memory assetSymbol,
        string memory assetType,
        uint256 initialPrice
    ) internal returns (AssetToken) {
        AssetToken token = new AssetToken(
            name,
            symbol,
            assetSymbol,
            assetType,
            initialPrice
        );

        console.log("\n=== ASSET DEPLOYED ===");
        console.log("Asset:", symbol, "deployed at:", address(token));

        return token;
    }

    function printAssetInfo(AssetToken token) internal view {
        console.log("\n=== DEPLOYMENT COMPLETED ===");
        console.log("Asset Token deployed at:", address(token));
        console.log("Contract details:");
        console.log("  Name:", token.name());
        console.log("  Symbol:", token.symbol());
        console.log("  Decimals:", token.decimals());

        (uint256 price, uint256 lastUpdate) = token.getCurrentPrice();
        console.log("  Current Price:", price);
        console.log("  Last Update:", lastUpdate);

        console.log("\n=== REMIX VERIFICATION ===");
        console.log("To verify on Remix:");
        console.log("1. Go to https://remix.ethereum.org");
        console.log("2. Create new file: URIPContracts.sol");
        console.log("3. Copy src/URIPContracts.sol content");
        console.log("4. Import OpenZeppelin contracts");
        console.log("5. Compile with Solidity ^0.8.19");
        console.log("6. Deploy AssetToken contract with constructor args");
        console.log("7. At address:", address(token));

        console.log("\n=== TEST COMMANDS ===");
        console.log("Check asset price:");
        console.log(
            "cast call",
            address(token),
            '"getCurrentPrice()(uint256,uint256)" --rpc-url https://rpc.sepolia-api.lisk.com'
        );
    }
}
