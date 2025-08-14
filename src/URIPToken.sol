// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title URIPToken
 * @dev URIP Mutual Fund Token - Represents diversified portfolio of tokenized assets
 *
 * PURPOSE:
 * - Enable investment in diversified portfolio with single token
 * - Automatically manage asset allocation across multiple assets
 * - Calculate Net Asset Value (NAV) based on underlying assets
 * - Allow easy entry/exit from diversified portfolio
 *
 * FLOW:
 * 1. User buys URIP → purchaseFund() → Mint URIP tokens
 * 2. Fund manager sets allocations → setAssetAllocation()
 * 3. Portfolio value changes → updateNAV() → NAV adjusts
 * 4. User sells URIP → redeemFund() → Burn URIP, get USD
 */
contract URIPToken is ERC20, AccessControl, Pausable, ReentrancyGuard {
    // ============================================================================
    // ROLES & CONSTANTS
    // ============================================================================

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant FUND_MANAGER_ROLE = keccak256("FUND_MANAGER_ROLE");

    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    struct FundInfo {
        uint256 totalAssetValue; // Total value of all underlying assets (USD, 8 decimals)
        uint256 navPerToken; // Net Asset Value per token (18 decimals)
        uint256 lastNavUpdate; // Timestamp of last NAV update
        uint256 managementFee; // Annual management fee (basis points: 200 = 2%)
        bool isActive; // Whether fund is active for trading
    }

    FundInfo public fundInfo;

    // Asset allocation tracking
    mapping(address => uint256) public assetAllocations; // Asset address → allocation (basis points)
    address[] public underlyingAssets; // Array of all assets in portfolio
    mapping(address => bool) public isUnderlyingAsset; // Quick check if asset is in portfolio

    // Purchase/redemption tracking
    mapping(address => uint256) public totalInvested; // User → total USD invested
    mapping(address => uint256) public purchaseTime; // User → last purchase time

    // ============================================================================
    // EVENTS
    // ============================================================================

    event NAVUpdated(
        uint256 oldNAV,
        uint256 newNAV,
        uint256 totalAssetValue,
        uint256 timestamp
    );

    event FundPurchased(
        address indexed buyer,
        uint256 usdAmount,
        uint256 tokensReceived,
        uint256 navAtPurchase
    );

    event FundRedeemed(
        address indexed redeemer,
        uint256 tokensRedeemed,
        uint256 usdAmount,
        uint256 navAtRedemption
    );

    event AssetAllocationUpdated(
        address indexed asset,
        uint256 oldAllocation,
        uint256 newAllocation
    );

    event AssetAdded(address indexed asset, uint256 allocation);
    event AssetRemoved(address indexed asset);

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    /**
     * @dev Initialize URIP mutual fund token
     * @param _name Fund name (e.g., "URIP Global Mixed Fund")
     * @param _symbol Fund symbol (e.g., "URIP")
     * @param _initialNAV Initial NAV per token (18 decimals, typically 1e18 = $1.00)
     * @param _managementFee Annual management fee in basis points (200 = 2%)
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialNAV,
        uint256 _managementFee
    ) ERC20(_name, _symbol) {
        require(_managementFee <= 1000, "Management fee too high"); // Max 10%

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(FUND_MANAGER_ROLE, msg.sender);

        fundInfo = FundInfo({
            totalAssetValue: 0,
            navPerToken: _initialNAV,
            lastNavUpdate: block.timestamp,
            managementFee: _managementFee,
            isActive: true
        });
    }

    // ============================================================================
    // FUND PURCHASE & REDEMPTION
    // ============================================================================

    /**
     * @dev Purchase URIP fund tokens with USD
     * @param to Address to receive URIP tokens
     * @param usdAmount Amount in USD to invest (8 decimals)
     *
     * PURPOSE: Allow users to invest in diversified portfolio
     * CALLED BY: PurchaseManager when user wants to buy URIP fund
     * FLOW: User pays USD → purchaseFund() → Mint URIP tokens → Update fund metrics
     */
    function purchaseFund(
        address to,
        uint256 usdAmount
    ) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(fundInfo.isActive, "Fund not active");
        require(usdAmount > 0, "Amount must be greater than 0");
        require(to != address(0), "Cannot purchase for zero address");

        // Calculate tokens to mint based on current NAV
        uint256 tokensToMint = (usdAmount * 1e18) / fundInfo.navPerToken;

        // Update fund metrics
        fundInfo.totalAssetValue += usdAmount;
        totalInvested[to] += usdAmount;
        purchaseTime[to] = block.timestamp;

        // Mint tokens
        _mint(to, tokensToMint);

        emit FundPurchased(to, usdAmount, tokensToMint, fundInfo.navPerToken);
    }

    /**
     * @dev Redeem URIP fund tokens for USD
     * @param from Address to burn tokens from
     * @param tokenAmount Amount of URIP tokens to redeem (18 decimals)
     * @return usdAmount Amount of USD to pay out (8 decimals)
     *
     * PURPOSE: Allow users to exit from diversified portfolio
     * CALLED BY: PurchaseManager when user wants to sell URIP fund
     * FLOW: User requests redemption → redeemFund() → Burn URIP tokens → Return USD value
     */
    function redeemFund(
        address from,
        uint256 tokenAmount
    )
        external
        onlyRole(MINTER_ROLE)
        whenNotPaused
        nonReentrant
        returns (uint256 usdAmount)
    {
        require(balanceOf(from) >= tokenAmount, "Insufficient balance");
        require(tokenAmount > 0, "Amount must be greater than 0");

        // Calculate USD amount based on current NAV
        usdAmount = (tokenAmount * fundInfo.navPerToken) / 1e18;

        // Ensure fund has enough assets to pay out
        require(
            usdAmount <= fundInfo.totalAssetValue,
            "Insufficient fund assets"
        );

        // Update fund metrics
        fundInfo.totalAssetValue -= usdAmount;

        // Proportionally reduce user's total invested amount
        uint256 userBalance = balanceOf(from);
        if (userBalance > 0) {
            uint256 reductionRatio = (tokenAmount * 1e18) / userBalance;
            uint256 investmentReduction = (totalInvested[from] *
                reductionRatio) / 1e18;
            totalInvested[from] -= investmentReduction;
        }

        // Burn tokens
        _burn(from, tokenAmount);

        emit FundRedeemed(from, tokenAmount, usdAmount, fundInfo.navPerToken);
    }

    // ============================================================================
    // NAV CALCULATION & UPDATES
    // ============================================================================

    /**
     * @dev Update NAV based on current underlying asset values
     * @param newTotalAssetValue New total value of all underlying assets (8 decimals)
     *
     * PURPOSE: Keep fund NAV synchronized with real asset values
     * CALLED BY: Fund manager or automated system
     * FLOW: Asset prices change → Calculate total portfolio value → updateNAV()
     */
    function updateNAV(
        uint256 newTotalAssetValue
    ) external onlyRole(FUND_MANAGER_ROLE) whenNotPaused {
        uint256 oldNAV = fundInfo.navPerToken;

        // Calculate new NAV: (Total Asset Value / Total Tokens) = NAV per token
        if (totalSupply() > 0) {
            fundInfo.navPerToken = (newTotalAssetValue * 1e18) / totalSupply();
        } else {
            // If no tokens exist, keep initial NAV
            fundInfo.navPerToken = 1e18; // $1.00
        }

        fundInfo.totalAssetValue = newTotalAssetValue;
        fundInfo.lastNavUpdate = block.timestamp;

        emit NAVUpdated(
            oldNAV,
            fundInfo.navPerToken,
            newTotalAssetValue,
            block.timestamp
        );
    }

    // ============================================================================
    // ASSET ALLOCATION MANAGEMENT
    // ============================================================================

    /**
     * @dev Set allocation percentage for an asset
     * @param assetToken Address of the asset token contract
     * @param allocationBasisPoints Allocation in basis points (1000 = 10%, 10000 = 100%)
     *
     * PURPOSE: Define what percentage of fund should be allocated to each asset
     * CALLED BY: Fund manager or DAO governance
     * FLOW: Strategy decision → setAssetAllocation() → Rebalancing occurs
     */
    function setAssetAllocation(
        address assetToken,
        uint256 allocationBasisPoints
    ) external onlyRole(FUND_MANAGER_ROLE) whenNotPaused {
        require(assetToken != address(0), "Invalid asset token address");
        require(
            allocationBasisPoints <= 10000,
            "Allocation cannot exceed 100%"
        );

        uint256 oldAllocation = assetAllocations[assetToken];

        // Add to underlying assets array if new asset
        if (!isUnderlyingAsset[assetToken] && allocationBasisPoints > 0) {
            underlyingAssets.push(assetToken);
            isUnderlyingAsset[assetToken] = true;
            emit AssetAdded(assetToken, allocationBasisPoints);
        }

        // Remove from underlying assets if allocation set to 0
        if (isUnderlyingAsset[assetToken] && allocationBasisPoints == 0) {
            _removeAssetFromArray(assetToken);
            isUnderlyingAsset[assetToken] = false;
            emit AssetRemoved(assetToken);
        }

        assetAllocations[assetToken] = allocationBasisPoints;
        emit AssetAllocationUpdated(
            assetToken,
            oldAllocation,
            allocationBasisPoints
        );
    }

    /**
     * @dev Remove asset from underlying assets array
     * @param assetToRemove Asset token address to remove
     */
    function _removeAssetFromArray(address assetToRemove) internal {
        for (uint256 i = 0; i < underlyingAssets.length; i++) {
            if (underlyingAssets[i] == assetToRemove) {
                underlyingAssets[i] = underlyingAssets[
                    underlyingAssets.length - 1
                ];
                underlyingAssets.pop();
                break;
            }
        }
    }

    /**
     * @dev Get all asset allocations
     * @return assets Array of asset token addresses
     * @return allocations Array of allocation percentages (basis points)
     *
     * PURPOSE: Return complete portfolio allocation for front-end display
     */
    function getAllAssetAllocations()
        external
        view
        returns (address[] memory assets, uint256[] memory allocations)
    {
        uint256 length = underlyingAssets.length;
        assets = new address[](length);
        allocations = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            assets[i] = underlyingAssets[i];
            allocations[i] = assetAllocations[underlyingAssets[i]];
        }
    }

    /**
     * @dev Get allocation percentages in human-readable format
     * @return assets Array of asset token addresses
     * @return percentages Array of allocation percentages (e.g., 1500 = 15.00%)
     *
     * PURPOSE: Return allocation data formatted for display (15.00% instead of 1500 basis points)
     */
    function getAllocationPercentages()
        external
        view
        returns (address[] memory assets, uint256[] memory percentages)
    {
        (assets, percentages) = this.getAllAssetAllocations();

        // percentages are already in basis points, which can be displayed as:
        // 1500 basis points = 15.00% (just divide by 100 in frontend)
    }

    /**
     * @dev Get detailed allocation information
     * @return assets Array of asset addresses
     * @return allocations Array of allocation basis points
     * @return percentageStrings Array of percentage strings for display
     * @return totalAllocation Total allocation percentage
     *
     * PURPOSE: Comprehensive allocation data for detailed portfolio view
     */
    function getDetailedAllocations()
        external
        view
        returns (
            address[] memory assets,
            uint256[] memory allocations,
            string[] memory percentageStrings,
            uint256 totalAllocation
        )
    {
        uint256 length = underlyingAssets.length;
        assets = new address[](length);
        allocations = new uint256[](length);
        percentageStrings = new string[](length);
        totalAllocation = 0;

        for (uint256 i = 0; i < length; i++) {
            assets[i] = underlyingAssets[i];
            allocations[i] = assetAllocations[underlyingAssets[i]];
            totalAllocation += allocations[i];

            // Convert basis points to percentage string (e.g., 1500 → "15.00%")
            percentageStrings[i] = _basisPointsToPercentageString(
                allocations[i]
            );
        }
    }

    /**
     * @dev Convert basis points to percentage string
     * @param basisPoints Allocation in basis points
     * @return Percentage string (e.g., "15.00%")
     */
    function _basisPointsToPercentageString(
        uint256 basisPoints
    ) internal pure returns (string memory) {
        uint256 percentage = basisPoints / 100; // Convert to percentage * 100
        uint256 wholePart = percentage / 100;
        uint256 decimalPart = percentage % 100;

        string memory wholeStr = _toString(wholePart);
        string memory decimalStr = decimalPart < 10
            ? string(abi.encodePacked("0", _toString(decimalPart)))
            : _toString(decimalPart);

        return string(abi.encodePacked(wholeStr, ".", decimalStr, "%"));
    }

    // ============================================================================
    // VIEW FUNCTIONS
    // ============================================================================

    /**
     * @dev Get current NAV and last update time
     * @return navPerToken Current NAV per token (18 decimals)
     * @return lastUpdate Timestamp of last NAV update
     *
     * PURPOSE: Provide current fund valuation data
     */
    function getCurrentNAV()
        external
        view
        returns (uint256 navPerToken, uint256 lastUpdate)
    {
        return (fundInfo.navPerToken, fundInfo.lastNavUpdate);
    }

    /**
     * @dev Get comprehensive fund statistics
     * @return totalValue Total fund asset value (8 decimals)
     * @return nav Current NAV per token (18 decimals)
     * @return totalTokens Total URIP tokens in circulation
     * @return managementFee Annual management fee (basis points)
     * @return assetCount Number of underlying assets
     * @return isActive Whether fund is active
     *
     * PURPOSE: Provide complete fund overview for dashboards
     */
    function getFundStats()
        external
        view
        returns (
            uint256 totalValue,
            uint256 nav,
            uint256 totalTokens,
            uint256 managementFee,
            uint256 assetCount,
            bool isActive
        )
    {
        return (
            fundInfo.totalAssetValue,
            fundInfo.navPerToken,
            totalSupply(),
            fundInfo.managementFee,
            underlyingAssets.length,
            fundInfo.isActive
        );
    }

    /**
     * @dev Get user's investment information
     * @param user User address
     * @return tokenBalance User's URIP token balance
     * @return currentValue Current USD value of user's holdings
     * @return totalInvestedAmount Total USD amount user has invested
     * @return profitLoss Current profit/loss amount
     * @return lastPurchase Timestamp of user's last purchase
     *
     * PURPOSE: Provide user-specific investment performance data
     */
    function getUserInvestmentInfo(
        address user
    )
        external
        view
        returns (
            uint256 tokenBalance,
            uint256 currentValue,
            uint256 totalInvestedAmount,
            int256 profitLoss,
            uint256 lastPurchase
        )
    {
        tokenBalance = balanceOf(user);
        currentValue = (tokenBalance * fundInfo.navPerToken) / 1e18;
        totalInvestedAmount = totalInvested[user];
        profitLoss = int256(currentValue) - int256(totalInvestedAmount);
        lastPurchase = purchaseTime[user];
    }

    /**
     * @dev Get number of underlying assets
     * @return Number of assets in portfolio
     */
    function getAssetCount() external view returns (uint256) {
        return underlyingAssets.length;
    }

    /**
     * @dev Get underlying asset at specific index
     * @param index Index in the assets array
     * @return Asset token address
     */
    function getUnderlyingAsset(uint256 index) external view returns (address) {
        require(index < underlyingAssets.length, "Index out of bounds");
        return underlyingAssets[index];
    }

    /**
     * @dev Calculate USD value for given URIP token amount
     * @param tokenAmount Amount of URIP tokens (18 decimals)
     * @return usdValue USD value (8 decimals)
     */
    function getUSDValue(
        uint256 tokenAmount
    ) external view returns (uint256 usdValue) {
        return (tokenAmount * fundInfo.navPerToken) / 1e18;
    }

    /**
     * @dev Calculate URIP token amount for given USD value
     * @param usdAmount USD amount (8 decimals)
     * @return tokenAmount URIP token amount (18 decimals)
     */
    function getTokenAmount(
        uint256 usdAmount
    ) external view returns (uint256 tokenAmount) {
        require(fundInfo.navPerToken > 0, "NAV not set");
        return (usdAmount * 1e18) / fundInfo.navPerToken;
    }

    // ============================================================================
    // ADMINISTRATIVE FUNCTIONS
    // ============================================================================

    /**
     * @dev Update management fee
     * @param newFee New management fee in basis points
     */
    function setManagementFee(
        uint256 newFee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFee <= 1000, "Management fee too high"); // Max 10%
        fundInfo.managementFee = newFee;
    }

    /**
     * @dev Activate/deactivate fund for trading
     * @param active Whether fund should be active
     */
    function setFundActive(bool active) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fundInfo.isActive = active;
    }

    /**
     * @dev Pause contract in emergency
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ============================================================================
    // UTILITY FUNCTIONS
    // ============================================================================

    /**
     * @dev Convert uint256 to string
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // ============================================================================
    // OVERRIDES
    // ============================================================================

    /**
     * @dev Override transfer function to respect pause state
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override whenNotPaused {
        super._update(from, to, value);
    }
}
