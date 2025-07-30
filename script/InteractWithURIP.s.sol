// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/URIPContracts.sol";
import "../src/mocks/MockUSDT.sol";

contract InteractWithURIP is Script {
    // Contract addresses (update setelah deployment)
    address constant USDT_ADDRESS = ""; // Update dengan address yang actual
    address constant APPLE_TOKEN_ADDRESS = "";
    address constant URIP_TOKEN_ADDRESS = "";
    address constant PURCHASE_MANAGER_ADDRESS = "";

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        // Load contracts
        MockUSDT usdt = MockUSDT(USDT_ADDRESS);
        AssetToken apple = AssetToken(APPLE_TOKEN_ADDRESS);
        URIPToken urip = URIPToken(URIP_TOKEN_ADDRESS);
        PurchaseManager manager = PurchaseManager(PURCHASE_MANAGER_ADDRESS);

        // Example interactions
        testPurchaseAppleTokens(usdt, manager);
        testPurchaseURIPFund(usdt, manager);
        testPriceUpdate(apple);

        vm.stopBroadcast();
    }

    function testPurchaseAppleTokens(MockUSDT usdt, PurchaseManager manager) internal {
        uint256 amount = 300 * 1e6; // $300 USDT
        
        // Approve USDT
        usdt.approve(address(manager), amount);
        
        // Purchase Apple tokens
        manager.purchaseAssetToken(
            address(usdt),
            APPLE_TOKEN_ADDRESS,
            amount
        );
        
        console.log("Purchased Apple tokens with $300 USDT");
    }

    function testPurchaseURIPFund(MockUSDT usdt, PurchaseManager manager) internal {
        uint256 amount = 1000 * 1e6; // $1000 USDT
        
        // Approve USDT
        usdt.approve(address(manager), amount);
        
        // Purchase URIP fund
        manager.purchaseMutualFund(address(usdt), amount);
        
        console.log("Purchased URIP fund with $1000 USDT");
    }

    function testPriceUpdate(AssetToken apple) internal {
        // Update Apple price to $155 (only if you have oracle role)
        try apple.updatePrice(155 * 1e8) {
            console.log("Updated Apple price to $155");
        } catch {
            console.log("Failed to update price - no oracle role");
        }
    }
}