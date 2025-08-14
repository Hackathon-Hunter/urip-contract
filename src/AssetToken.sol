// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AssetToken
 * @dev Represents individual tokenized assets (stocks, commodities, etc.)
 *
 * PURPOSE:
 * - Tokenize real-world assets (AAPL, TSLA, Gold, etc.)
 * - Maintain 1:1 backing with real assets in custody
 * - Track real-time prices from oracles
 * - Enable fractional ownership of expensive assets
 *
 * FLOW:
 * 1. Oracle updates asset price → updatePrice()
 * 2. User wants to buy → PurchaseManager calls mint()
 * 3. User wants to sell → PurchaseManager calls burn()
 * 4. Price feeds used by URIP fund for NAV calculation
 */
contract AssetToken is ERC20, AccessControl, Pausable, ReentrancyGuard {
    // ============================================================================
    // ROLES & CONSTANTS
    // ============================================================================

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    struct AssetInfo {
        string symbol; // e.g., "AAPL", "TSLA", "XAU"
        string assetType; // e.g., "STOCK", "COMMODITY", "CRYPTO"
        uint256 currentPrice; // Price in USD (8 decimals: $150.00 = 15000000000)
        uint256 lastUpdate; // Timestamp of last price update
        bool isActive; // Whether asset is active for trading
    }

    AssetInfo public assetInfo;

    // ============================================================================
    // EVENTS
    // ============================================================================

    event PriceUpdated(uint256 oldPrice, uint256 newPrice, uint256 timestamp);

    event AssetMinted(address indexed to, uint256 amount, uint256 priceAtMint);

    event AssetBurned(
        address indexed from,
        uint256 amount,
        uint256 priceAtBurn
    );

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    /**
     * @dev Initialize asset token
     * @param _name Token name (e.g., "Tokenized Apple Stock")
     * @param _symbol Token symbol (e.g., "tAAPL")
     * @param _assetSymbol Real asset symbol (e.g., "AAPL")
     * @param _assetType Asset category (e.g., "STOCK")
     * @param _initialPrice Initial price in USD (8 decimals)
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _assetSymbol,
        string memory _assetType,
        uint256 _initialPrice
    ) ERC20(_name, _symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);

        assetInfo = AssetInfo({
            symbol: _assetSymbol,
            assetType: _assetType,
            currentPrice: _initialPrice,
            lastUpdate: block.timestamp,
            isActive: true
        });
    }

    // ============================================================================
    // PRICE MANAGEMENT (Oracle Functions)
    // ============================================================================

    /**
     * @dev Update asset price from oracle
     * @param newPrice New price in USD (8 decimals)
     *
     * PURPOSE: Keep token price synchronized with real asset price
     * CALLED BY: Price oracle or authorized price updater
     * FLOW: Oracle → updatePrice() → Price stored → Used for calculations
     */
    function updatePrice(
        uint256 newPrice
    ) external onlyRole(ORACLE_ROLE) whenNotPaused {
        require(newPrice > 0, "Price must be greater than 0");

        uint256 oldPrice = assetInfo.currentPrice;
        assetInfo.currentPrice = newPrice;
        assetInfo.lastUpdate = block.timestamp;

        emit PriceUpdated(oldPrice, newPrice, block.timestamp);
    }

    /**
     * @dev Get current asset price and last update time
     * @return price Current price in USD (8 decimals)
     * @return lastUpdate Timestamp of last price update
     *
     * PURPOSE: Provide price data for NAV calculations and user interfaces
     * CALLED BY: URIP fund contract, PurchaseManager, front-end
     */
    function getCurrentPrice()
        external
        view
        returns (uint256 price, uint256 lastUpdate)
    {
        return (assetInfo.currentPrice, assetInfo.lastUpdate);
    }

    // ============================================================================
    // TOKEN MINTING & BURNING (Purchase/Sale Functions)
    // ============================================================================

    /**
     * @dev Mint tokens when real asset is purchased
     * @param to Address to receive tokens
     * @param amount Amount of tokens to mint (18 decimals)
     *
     * PURPOSE: Create tokens backed by real assets in custody
     * CALLED BY: PurchaseManager when user buys assets
     * FLOW: User pays USD → PurchaseManager buys real asset → mint() → User gets tokens
     */
    function mint(
        address to,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(assetInfo.isActive, "Asset not active");
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be greater than 0");

        _mint(to, amount);
        emit AssetMinted(to, amount, assetInfo.currentPrice);
    }

    /**
     * @dev Burn tokens when real asset is sold
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn (18 decimals)
     *
     * PURPOSE: Remove tokens when backing real assets are sold
     * CALLED BY: PurchaseManager when user sells assets
     * FLOW: User requests sale → burn() → Sell real asset → Send USD to user
     */
    function burn(
        address from,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(balanceOf(from) >= amount, "Insufficient balance");
        require(amount > 0, "Amount must be greater than 0");

        _burn(from, amount);
        emit AssetBurned(from, amount, assetInfo.currentPrice);
    }

    // ============================================================================
    // ADMINISTRATIVE FUNCTIONS
    // ============================================================================

    /**
     * @dev Pause contract in emergency
     * PURPOSE: Stop all trading in case of emergency
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract
     * PURPOSE: Resume trading after emergency is resolved
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Activate/deactivate asset for trading
     * @param active Whether asset should be active
     *
     * PURPOSE: Control which assets can be traded
     */
    function setAssetActive(bool active) external onlyRole(DEFAULT_ADMIN_ROLE) {
        assetInfo.isActive = active;
    }

    // ============================================================================
    // VIEW FUNCTIONS
    // ============================================================================

    /**
     * @dev Get complete asset information
     * @return Asset information struct
     *
     * PURPOSE: Provide all asset details for front-end and integrations
     */
    function getAssetInfo() external view returns (AssetInfo memory) {
        return assetInfo;
    }

    /**
     * @dev Calculate USD value of token amount
     * @param tokenAmount Amount of tokens (18 decimals)
     * @return usdValue Value in USD (8 decimals)
     *
     * PURPOSE: Convert token amount to USD value
     * EXAMPLE: 1.5 AAPL tokens * $150.00 = $225.00
     */
    function getUSDValue(
        uint256 tokenAmount
    ) external view returns (uint256 usdValue) {
        return (tokenAmount * assetInfo.currentPrice) / 1e18;
    }

    /**
     * @dev Calculate token amount for USD value
     * @param usdAmount Amount in USD (8 decimals)
     * @return tokenAmount Amount of tokens (18 decimals)
     *
     * PURPOSE: Convert USD amount to token amount
     * EXAMPLE: $225.00 / $150.00 = 1.5 AAPL tokens
     */
    function getTokenAmount(
        uint256 usdAmount
    ) external view returns (uint256 tokenAmount) {
        require(assetInfo.currentPrice > 0, "Price not set");
        return (usdAmount * 1e18) / assetInfo.currentPrice;
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
