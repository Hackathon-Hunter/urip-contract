// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/URIPContracts.sol";

// ============================================================================
// TEST CONTRACT
// ============================================================================

contract URIPTest is Test {
    AssetToken public appleToken;
    AssetToken public teslaToken;
    URIPToken public uripToken;
    PurchaseManager public purchaseManager;
    MockUSDT public usdt;

    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public oracle = address(0x3);

    function setUp() public {
        // Deploy mock USDT
        usdt = new MockUSDT();

        // Deploy asset tokens
        appleToken = new AssetToken(
            "Tokenized Apple Stock",
            "tAAPL",
            "AAPL",
            "STOCK",
            150 * 1e8 // $150 dengan 8 decimals
        );

        teslaToken = new AssetToken(
            "Tokenized Tesla Stock",
            "tTSLA",
            "TSLA",
            "STOCK",
            200 * 1e8 // $200 dengan 8 decimals
        );

        // Deploy URIP mutual fund token
        uripToken = new URIPToken(
            "URIP Mutual Fund",
            "URIP",
            1e18, // Initial NAV = $1
            200 // 2% management fee (200 basis points)
        );

        // Deploy purchase manager
        purchaseManager = new PurchaseManager();

        // Setup roles
        appleToken.grantRole(appleToken.ORACLE_ROLE(), oracle);
        teslaToken.grantRole(teslaToken.ORACLE_ROLE(), oracle);

        // Setup purchase manager
        purchaseManager.setSupportedPaymentToken(address(usdt), true);
        purchaseManager.setSupportedAssetToken(address(appleToken), true);
        purchaseManager.setSupportedAssetToken(address(teslaToken), true);
        purchaseManager.setURIPFund(address(uripToken));

        // Grant minter role to purchase manager
        appleToken.grantRole(
            appleToken.MINTER_ROLE(),
            address(purchaseManager)
        );
        teslaToken.grantRole(
            teslaToken.MINTER_ROLE(),
            address(purchaseManager)
        );
        uripToken.grantRole(uripToken.MINTER_ROLE(), address(purchaseManager));

        // Give USDT to users
        usdt.mint(user1, 10000 * 1e6); // 10k USDT
        usdt.mint(user2, 10000 * 1e6); // 10k USDT
    }

    function testAssetTokenDeployment() public {
        assertEq(appleToken.name(), "Tokenized Apple Stock");
        assertEq(appleToken.symbol(), "tAAPL");

        (uint256 price, uint256 lastUpdate) = appleToken.getCurrentPrice();
        assertEq(price, 150 * 1e8);
        assertTrue(lastUpdate > 0);
    }

    function testPriceUpdate() public {
        // Test oracle price update
        vm.prank(oracle);
        appleToken.updatePrice(155 * 1e8);

        (uint256 newPrice, ) = appleToken.getCurrentPrice();
        assertEq(newPrice, 155 * 1e8);
    }

    function testDirectAssetPurchase() public {
        uint256 paymentAmount = 300 * 1e6; // $300 USDT

        vm.startPrank(user1);
        usdt.approve(address(purchaseManager), paymentAmount);

        uint256 balanceBefore = appleToken.balanceOf(user1);

        purchaseManager.purchaseAssetToken(
            address(usdt),
            address(appleToken),
            paymentAmount
        );

        uint256 balanceAfter = appleToken.balanceOf(user1);

        // Should receive ~2 tokens ($300 / $150 per token)
        assertTrue(balanceAfter > balanceBefore);
        console.log("AAPL tokens received:", balanceAfter);
        vm.stopPrank();
    }

    function testMutualFundPurchase() public {
        uint256 investmentAmount = 1000 * 1e6; // $1000 USDT

        vm.startPrank(user1);
        usdt.approve(address(purchaseManager), investmentAmount);

        uint256 balanceBefore = uripToken.balanceOf(user1);

        purchaseManager.purchaseMutualFund(address(usdt), investmentAmount);

        uint256 balanceAfter = uripToken.balanceOf(user1);

        // Should receive 1000 URIP tokens (NAV = $1)
        assertTrue(balanceAfter > balanceBefore);
        console.log("URIP tokens received:", balanceAfter);
        vm.stopPrank();
    }

    function testNAVUpdate() public {
        // First, add some assets to fund
        vm.prank(user1);
        usdt.approve(address(purchaseManager), 1000 * 1e6);

        vm.prank(user1);
        purchaseManager.purchaseMutualFund(address(usdt), 1000 * 1e6);

        // Update NAV to simulate portfolio growth
        uripToken.updateNAV(1100 * 1e6); // Portfolio now worth $1100

        (uint256 newNAV, ) = uripToken.getCurrentNAV();
        console.log("New NAV:", newNAV);

        // NAV should be higher than initial $1
        assertTrue(newNAV > 1e18);
    }

    function testAssetAllocation() public {
        // Set asset allocation untuk fund
        uripToken.setAssetAllocation(address(appleToken), 6000); // 60%
        uripToken.setAssetAllocation(address(teslaToken), 4000); // 40%

        assertEq(uripToken.assetAllocations(address(appleToken)), 6000);
        assertEq(uripToken.assetAllocations(address(teslaToken)), 4000);
    }

    function testFundRedemption() public {
        // First purchase some fund
        vm.startPrank(user1);
        usdt.approve(address(purchaseManager), 1000 * 1e6);
        purchaseManager.purchaseMutualFund(address(usdt), 1000 * 1e6);

        uint256 uripBalance = uripToken.balanceOf(user1);
        console.log("URIP balance before redemption:", uripBalance);

        // Redeem half
        uint256 redeemAmount = uripBalance / 2;
        vm.stopPrank();

        // Grant minter role untuk redemption (in real scenario, ini handle oleh purchase manager)
        uripToken.grantRole(uripToken.MINTER_ROLE(), address(this));
        uint256 usdReceived = uripToken.redeemFund(user1, redeemAmount);

        console.log("USD received from redemption:", usdReceived);
        assertTrue(usdReceived > 0);
    }

    function testFailUnauthorizedMinting() public {
        // Should fail - user1 doesn't have minter role
        vm.prank(user1);
        appleToken.mint(user1, 100);
    }

    function testFailInvalidPriceUpdate() public {
        // Should fail - price cannot be 0
        vm.prank(oracle);
        appleToken.updatePrice(0);
    }

    function testEmergencyPause() public {
        // Test pause functionality
        appleToken.pause();

        vm.expectRevert("Pausable: paused");
        appleToken.mint(user1, 100);

        appleToken.unpause();
        appleToken.mint(user1, 100); // Should work now
    }
}
