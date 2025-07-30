// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/URIPContracts.sol";

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

        // Deploy Asset Tokens
        AssetToken appleToken = deployAssetToken(
            "Tokenized Apple Stock",
            "tAAPL",
            "AAPL",
            "STOCK",
            150 * 1e8
        );

        AssetToken teslaToken = deployAssetToken(
            "Tokenized Tesla Stock",
            "tTSLA",
            "TSLA",
            "STOCK",
            200 * 1e8
        );

        AssetToken googleToken = deployAssetToken(
            "Tokenized Google Stock",
            "tGOOGL",
            "GOOGL",
            "STOCK",
            2800 * 1e8
        );

        AssetToken goldToken = deployAssetToken(
            "Tokenized Gold",
            "tGOLD",
            "GOLD",
            "COMMODITY",
            2000 * 1e8
        );

        // Deploy URIP Mutual Fund
        URIPToken uripToken = new URIPToken(
            "URIP Mutual Fund",
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
            appleToken,
            teslaToken,
            googleToken,
            goldToken,
            uripToken
        );

        // Setup URIP Fund Allocations
        setupFundAllocations(
            uripToken,
            appleToken,
            teslaToken,
            googleToken,
            goldToken
        );

        vm.stopBroadcast();

        // Save deployment addresses
        saveDeploymentInfo(
            address(usdt),
            address(appleToken),
            address(teslaToken),
            address(googleToken),
            address(goldToken),
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
        AssetToken apple,
        AssetToken tesla,
        AssetToken google,
        AssetToken gold,
        URIPToken urip
    ) internal {
        // Set supported payment token
        manager.setSupportedPaymentToken(address(usdt), true);

        // Set supported asset tokens
        manager.setSupportedAssetToken(address(apple), true);
        manager.setSupportedAssetToken(address(tesla), true);
        manager.setSupportedAssetToken(address(google), true);
        manager.setSupportedAssetToken(address(gold), true);

        // Set URIP fund
        manager.setURIPFund(address(urip));

        // Grant minter roles
        apple.grantRole(apple.MINTER_ROLE(), address(manager));
        tesla.grantRole(tesla.MINTER_ROLE(), address(manager));
        google.grantRole(google.MINTER_ROLE(), address(manager));
        gold.grantRole(gold.MINTER_ROLE(), address(manager));
        urip.grantRole(urip.MINTER_ROLE(), address(manager));

        console.log("Purchase Manager setup completed");
    }

    function setupFundAllocations(
        URIPToken urip,
        AssetToken apple,
        AssetToken tesla,
        AssetToken google,
        AssetToken gold
    ) internal {
        urip.setAssetAllocation(address(apple), 3000); // 30%
        urip.setAssetAllocation(address(tesla), 2500); // 25%
        urip.setAssetAllocation(address(google), 2500); // 25%
        urip.setAssetAllocation(address(gold), 2000); // 20%

        console.log("URIP Fund allocations set");
    }

    function saveDeploymentInfo(
        address usdt,
        address apple,
        address tesla,
        address google,
        address gold,
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
                '  "contracts": {\n',
                '    "MockUSDT": "',
                vm.toString(usdt),
                '",\n',
                '    "AppleToken": "',
                vm.toString(apple),
                '",\n',
                '    "TeslaToken": "',
                vm.toString(tesla),
                '",\n',
                '    "GoogleToken": "',
                vm.toString(google),
                '",\n',
                '    "GoldToken": "',
                vm.toString(gold),
                '",\n',
                '    "URIPToken": "',
                vm.toString(urip),
                '",\n',
                '    "PurchaseManager": "',
                vm.toString(manager),
                '"\n',
                "  }\n",
                "}"
            )
        );

        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log(deploymentInfo);
        console.log("===========================");
    }
}
