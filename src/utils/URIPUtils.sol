// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
// UTILITY FUNCTIONS CONTRACT
// ============================================================================

contract URIPUtils {
    // Calculate percentage dengan basis points (10000 = 100%)
    function calculatePercentage(
        uint256 amount,
        uint256 basisPoints
    ) public pure returns (uint256) {
        return (amount * basisPoints) / 10000;
    }

    // Calculate compound interest
    function calculateCompoundInterest(
        uint256 principal,
        uint256 rate, // Annual rate dalam basis points
        uint256 periods // Number of compounding periods
    ) public pure returns (uint256) {
        uint256 result = principal;
        for (uint256 i = 0; i < periods; i++) {
            result = (result * (10000 + rate)) / 10000;
        }
        return result;
    }

    // Price impact calculation untuk large trades
    function calculatePriceImpact(
        uint256 tradeAmount,
        uint256 liquidity,
        uint256 impactFactor // Basis points
    ) public pure returns (uint256) {
        if (liquidity == 0) return 0;
        return (tradeAmount * impactFactor) / liquidity;
    }

    // Convert different decimal formats
    function convertDecimals(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) public pure returns (uint256) {
        if (fromDecimals == toDecimals) {
            return amount;
        } else if (fromDecimals > toDecimals) {
            return amount / (10 ** (fromDecimals - toDecimals));
        } else {
            return amount * (10 ** (toDecimals - fromDecimals));
        }
    }

    // Calculate NAV untuk mutual fund
    function calculateNAV(
        uint256 totalAssetValue,
        uint256 totalSupply
    ) public pure returns (uint256) {
        if (totalSupply == 0) return 1e18; // Default NAV = $1
        return (totalAssetValue * 1e18) / totalSupply;
    }

    // Calculate management fee
    function calculateManagementFee(
        uint256 assetValue,
        uint256 feeRate, // Annual fee dalam basis points
        uint256 timeElapsed // Seconds since last fee calculation
    ) public pure returns (uint256) {
        uint256 annualSeconds = 365 * 24 * 60 * 60;
        return (assetValue * feeRate * timeElapsed) / (10000 * annualSeconds);
    }
}
