// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
// PORTFOLIO TRACKER (untuk monitoring)
// ============================================================================

contract PortfolioTracker {
    struct UserPortfolio {
        mapping(address => uint256) assetTokenBalances;
        uint256 uripBalance;
        uint256 totalInvestedUSD;
        uint256 lastUpdate;
    }

    mapping(address => UserPortfolio) public portfolios;
    address[] public trackedUsers;

    event PortfolioUpdated(
        address indexed user,
        uint256 totalValue,
        uint256 timestamp
    );

    function updatePortfolio(
        address user,
        address[] memory assetTokens,
        uint256[] memory balances,
        uint256 uripBalance,
        uint256 totalInvested
    ) external {
        require(assetTokens.length == balances.length, "Array length mismatch");

        UserPortfolio storage portfolio = portfolios[user];

        // Update asset token balances
        for (uint i = 0; i < assetTokens.length; i++) {
            portfolio.assetTokenBalances[assetTokens[i]] = balances[i];
        }

        portfolio.uripBalance = uripBalance;
        portfolio.totalInvestedUSD = totalInvested;
        portfolio.lastUpdate = block.timestamp;

        // Add to tracked users if not already tracked
        bool isTracked = false;
        for (uint i = 0; i < trackedUsers.length; i++) {
            if (trackedUsers[i] == user) {
                isTracked = true;
                break;
            }
        }
        if (!isTracked) {
            trackedUsers.push(user);
        }

        emit PortfolioUpdated(user, totalInvested, block.timestamp);
    }

    function getUserAssetBalance(
        address user,
        address assetToken
    ) external view returns (uint256) {
        return portfolios[user].assetTokenBalances[assetToken];
    }

    function getUserURIPBalance(address user) external view returns (uint256) {
        return portfolios[user].uripBalance;
    }

    function getTotalInvestment(address user) external view returns (uint256) {
        return portfolios[user].totalInvestedUSD;
    }
}
