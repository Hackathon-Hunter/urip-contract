// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/URIPContracts.sol";
import "../src/mocks/MockUSDT.sol";

contract DeployURIP is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Mock USDT untuk testing
        MockUSDT usdt = new MockUSDT();
        console.log("Mock USDT deployed at:", address(usdt));

        // Deploy Asset Tokens - Global Mix Portfolio

        // US S&P 500 Stocks
        AssetToken nvdaToken = deployAssetToken(
            "Tokenized NVIDIA Stock",
            "tNVDA",
            "NVDA",
            "STOCK_SP500",
            140 * 1e8 // ~$140
        );

        AssetToken msftToken = deployAssetToken(
            "Tokenized Microsoft Stock",
            "tMSFT",
            "MSFT",
            "STOCK_SP500",
            415 * 1e8 // ~$415
        );

        AssetToken aaplToken = deployAssetToken(
            "Tokenized Apple Stock",
            "tAAPL",
            "AAPL",
            "STOCK_SP500",
            230 * 1e8 // ~$230
        );

        AssetToken googToken = deployAssetToken(
            "Tokenized Alphabet Stock",
            "tGOOG",
            "GOOG",
            "STOCK_SP500",
            175 * 1e8 // ~$175
        );

        // Singapore SGX Stock
        AssetToken dbsToken = deployAssetToken(
            "Tokenized DBS Group Holdings",
            "tD05",
            "D05",
            "STOCK_SGX",
            35 * 1e8 // ~$35 SGD
        );

        // Indonesia IDX Stock
        AssetToken brenToken = deployAssetToken(
            "Tokenized Barito Renewables",
            "tBREN",
            "BREN",
            "STOCK_IDX",
            4200 // ~IDR 4,200 (converted to USD equivalent)
        );

        // Thailand BKK Stock
        AssetToken deltaToken = deployAssetToken(
            "Tokenized Delta Electronics",
            "tDELTA",
            "DELTA",
            "STOCK_BKK",
            175 * 1e8 // ~175 THB (converted to USD equivalent)
        );

        // Malaysia MYX Stock
        AssetToken maybankToken = deployAssetToken(
            "Tokenized Maybank",
            "tMAYBANK",
            "MAYBANK",
            "STOCK_MYX",
            10 * 1e8 // ~10 MYR (converted to USD equivalent)
        );

        // Precious Metals
        AssetToken goldToken = deployAssetToken(
            "Tokenized Gold",
            "tXAU",
            "XAU",
            "COMMODITY_METAL",
            2650 * 1e8 // ~$2,650 per oz
        );

        AssetToken silverToken = deployAssetToken(
            "Tokenized Silver",
            "tXAG",
            "XAG",
            "COMMODITY_METAL",
            31 * 1e8 // ~$31 per oz
        );

        // Cryptocurrency
        AssetToken btcToken = deployAssetToken(
            "Tokenized Bitcoin",
            "tBTC",
            "BTC",
            "CRYPTOCURRENCY",
            100000 * 1e8 // ~$100,000
        );

        // Deploy URIP Mutual Fund
        URIPToken uripToken = new URIPToken(
            "URIP Global Mixed Fund",
            "URIP",
            1e18, // $1 initial NAV
            200 // 2% management fee
        );
        console.log("URIP Token deployed at:", address(uripToken));

        // Deploy Purchase Manager
        PurchaseManager purchaseManager = new PurchaseManager();
        console.log("Purchase Manager deployed at:", address(purchaseManager));

        // Setup Purchase Manager
        setupPurchaseManager(
            purchaseManager,
            usdt,
            nvdaToken,
            msftToken,
            aaplToken,
            googToken,
            dbsToken,
            brenToken,
            deltaToken,
            maybankToken,
            goldToken,
            silverToken,
            btcToken,
            uripToken
        );

        // Setup URIP Fund Allocations
        setupFundAllocations(
            uripToken,
            nvdaToken,
            msftToken,
            aaplToken,
            googToken,
            dbsToken,
            brenToken,
            deltaToken,
            maybankToken,
            goldToken,
            silverToken,
            btcToken
        );

        vm.stopBroadcast();

        // Save deployment addresses
        saveDeploymentInfo(
            address(usdt),
            address(nvdaToken),
            address(msftToken),
            address(aaplToken),
            address(googToken),
            address(dbsToken),
            address(brenToken),
            address(deltaToken),
            address(maybankToken),
            address(goldToken),
            address(silverToken),
            address(btcToken),
            address(uripToken),
            address(purchaseManager)
        );
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
        console.log(
            string(abi.encodePacked(symbol, " deployed at:")),
            address(token)
        );
        return token;
    }

    function setupPurchaseManager(
        PurchaseManager manager,
        MockUSDT usdt,
        AssetToken nvda,
        AssetToken msft,
        AssetToken aapl,
        AssetToken goog,
        AssetToken dbs,
        AssetToken bren,
        AssetToken delta,
        AssetToken maybank,
        AssetToken gold,
        AssetToken silver,
        AssetToken btc,
        URIPToken urip
    ) internal {
        // Set supported payment token
        manager.setSupportedPaymentToken(address(usdt), true);

        // Set supported asset tokens
        manager.setSupportedAssetToken(address(nvda), true);
        manager.setSupportedAssetToken(address(msft), true);
        manager.setSupportedAssetToken(address(aapl), true);
        manager.setSupportedAssetToken(address(goog), true);
        manager.setSupportedAssetToken(address(dbs), true);
        manager.setSupportedAssetToken(address(bren), true);
        manager.setSupportedAssetToken(address(delta), true);
        manager.setSupportedAssetToken(address(maybank), true);
        manager.setSupportedAssetToken(address(gold), true);
        manager.setSupportedAssetToken(address(silver), true);
        manager.setSupportedAssetToken(address(btc), true);

        // Set URIP fund
        manager.setURIPFund(address(urip));

        // Grant minter roles
        nvda.grantRole(nvda.MINTER_ROLE(), address(manager));
        msft.grantRole(msft.MINTER_ROLE(), address(manager));
        aapl.grantRole(aapl.MINTER_ROLE(), address(manager));
        goog.grantRole(goog.MINTER_ROLE(), address(manager));
        dbs.grantRole(dbs.MINTER_ROLE(), address(manager));
        bren.grantRole(bren.MINTER_ROLE(), address(manager));
        delta.grantRole(delta.MINTER_ROLE(), address(manager));
        maybank.grantRole(maybank.MINTER_ROLE(), address(manager));
        gold.grantRole(gold.MINTER_ROLE(), address(manager));
        silver.grantRole(silver.MINTER_ROLE(), address(manager));
        btc.grantRole(btc.MINTER_ROLE(), address(manager));
        urip.grantRole(urip.MINTER_ROLE(), address(manager));

        console.log("Purchase Manager setup completed");
    }

    function setupFundAllocations(
        URIPToken urip,
        AssetToken nvda,
        AssetToken msft,
        AssetToken aapl,
        AssetToken goog,
        AssetToken dbs,
        AssetToken bren,
        AssetToken delta,
        AssetToken maybank,
        AssetToken gold,
        AssetToken silver,
        AssetToken btc
    ) internal {
        // Diversified Global Portfolio Allocation
        // US Tech Giants (40% total)
        urip.setAssetAllocation(address(nvda), 1200); // 12% - NVIDIA
        urip.setAssetAllocation(address(msft), 1000); // 10% - Microsoft
        urip.setAssetAllocation(address(aapl), 1000); // 10% - Apple
        urip.setAssetAllocation(address(goog), 800); // 8% - Google

        // Asian Markets (25% total)
        urip.setAssetAllocation(address(dbs), 800); // 8% - DBS Singapore
        urip.setAssetAllocation(address(bren), 600); // 6% - Barito Indonesia
        urip.setAssetAllocation(address(delta), 600); // 6% - Delta Thailand
        urip.setAssetAllocation(address(maybank), 500); // 5% - Maybank Malaysia

        // Alternative Assets (35% total)
        urip.setAssetAllocation(address(gold), 1500); // 15% - Gold
        urip.setAssetAllocation(address(silver), 800); // 8% - Silver
        urip.setAssetAllocation(address(btc), 1200); // 12% - Bitcoin

        console.log("URIP Fund allocations set - Global Diversified Portfolio");
        console.log(
            "US Stocks: 40%, Asian Stocks: 25%, Alternative Assets: 35%"
        );
    }

    function saveDeploymentInfo(
        address usdt,
        address nvda,
        address msft,
        address aapl,
        address goog,
        address dbs,
        address bren,
        address delta,
        address maybank,
        address gold,
        address silver,
        address btc,
        address urip,
        address manager
    ) internal {
        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "network": "lisk_sepolia",\n',
                '  "timestamp": "',
                vm.toString(block.timestamp),
                '",\n',
                '  "description": "URIP Global Mixed Assets Fund",\n',
                '  "contracts": {\n',
                '    "MockUSDT": "',
                vm.toString(usdt),
                '",\n',
                '    "NVIDIA_Token": "',
                vm.toString(nvda),
                '",\n',
                '    "Microsoft_Token": "',
                vm.toString(msft),
                '",\n',
                '    "Apple_Token": "',
                vm.toString(aapl),
                '",\n',
                '    "Google_Token": "',
                vm.toString(goog),
                '",\n',
                '    "DBS_Token": "',
                vm.toString(dbs),
                '",\n',
                '    "Barito_Token": "',
                vm.toString(bren),
                '",\n',
                '    "Delta_Token": "',
                vm.toString(delta),
                '",\n',
                '    "Maybank_Token": "',
                vm.toString(maybank),
                '",\n',
                '    "Gold_Token": "',
                vm.toString(gold),
                '",\n',
                '    "Silver_Token": "',
                vm.toString(silver),
                '",\n',
                '    "Bitcoin_Token": "',
                vm.toString(btc),
                '",\n',
                '    "URIPToken": "',
                vm.toString(urip),
                '",\n',
                '    "PurchaseManager": "',
                vm.toString(manager),
                '"\n',
                "  },\n",
                '  "allocations": {\n',
                '    "US_Stocks": "40%",\n',
                '    "Asian_Stocks": "25%",\n',
                '    "Alternative_Assets": "35%"\n',
                "  }\n",
                "}"
            )
        );

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Global Mixed Assets Portfolio Deployed:");
        console.log("US Stocks (40%): NVDA, MSFT, AAPL, GOOG");
        console.log("Asian Stocks (25%): DBS, BREN, DELTA, MAYBANK");
        console.log("Alternative Assets (35%): XAU, XAG, BTC");
        console.log(deploymentInfo);
        console.log("===========================");
    }
}
