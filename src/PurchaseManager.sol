// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Interface imports for interacting with AssetToken and URIPToken
interface IAssetToken {
    struct AssetInfo {
        string symbol;
        string assetType;
        uint256 currentPrice;
        uint256 lastUpdate;
        bool isActive;
    }

    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;

    function getCurrentPrice() external view returns (uint256, uint256);

    function getTokenAmount(uint256 usdAmount) external view returns (uint256);

    function getUSDValue(uint256 tokenAmount) external view returns (uint256);

    function getAssetInfo() external view returns (AssetInfo memory);

    function balanceOf(address account) external view returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);
}

interface IURIPToken {
    function purchaseFund(address to, uint256 usdAmount) external;

    function redeemFund(
        address from,
        uint256 tokenAmount
    ) external returns (uint256);

    function getTokenAmount(uint256 usdAmount) external view returns (uint256);

    function getUSDValue(uint256 tokenAmount) external view returns (uint256);

    function getCurrentNAV() external view returns (uint256, uint256);

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
        );

    function getAllAssetAllocations()
        external
        view
        returns (address[] memory assets, uint256[] memory allocations);

    function balanceOf(address account) external view returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);
}

/**
 * @title PurchaseManager
 * @dev Central hub for all asset and fund purchases/sales with comprehensive trading features
 *
 * PURPOSE:
 * - Handle all buy/sell transactions for both individual assets and URIP fund
 * - Manage payment tokens (USDT, USDC, etc.) and asset tokens
 * - Execute proper token minting/burning flow with fee management
 * - Provide comprehensive market data and trading information
 * - Ensure proper fund flow and custody management
 *
 * CORE FUNCTIONALITY:
 * 1. Individual Asset Trading: Buy/sell tokenized assets (Apple, Tesla, Gold, etc.)
 * 2. URIP Fund Trading: Buy/sell diversified mutual fund tokens
 * 3. Market Data: Get prices, supported tokens, trading limits
 * 4. Fee Management: Calculate and collect trading fees
 * 5. Security: Trading limits, access control, emergency functions
 *
 * FLOW OVERVIEW:
 * Buy Assets: User pays USDT → PurchaseManager → Mint AssetTokens → User receives tokens
 * Sell Assets: User has tokens → PurchaseManager → Burn tokens → User receives USDT
 * Buy URIP: User pays USDT → PurchaseManager → Mint URIP tokens → User receives URIP
 * Sell URIP: User has URIP → PurchaseManager → Burn URIP → User receives USDT
 */
contract PurchaseManager is AccessControl, Pausable, ReentrancyGuard {
    // ============================================================================
    // ROLES & CONSTANTS
    // ============================================================================

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    // Supported payment tokens (USDT, USDC, etc.)
    mapping(address => bool) public supportedPaymentTokens;
    address[] public paymentTokensList; // Array to track all payment tokens

    // Supported asset tokens for individual asset trading
    mapping(address => bool) public supportedAssetTokens;
    address[] public assetTokensList; // Array to track all asset tokens

    // URIP fund contract address
    address public uripFund;

    // Treasury address for collecting fees
    address public treasury;

    // Fee structure (in basis points: 100 = 1%)
    struct FeeStructure {
        uint256 purchaseFee; // Fee for buying assets (basis points)
        uint256 redemptionFee; // Fee for selling assets (basis points)
        uint256 uripPurchaseFee; // Fee for buying URIP fund (basis points)
        uint256 uripRedemptionFee; // Fee for selling URIP fund (basis points)
    }

    FeeStructure public fees;

    // Trading limits
    struct TradingLimits {
        uint256 minPurchaseAmount; // Minimum purchase amount in USD (8 decimals)
        uint256 maxPurchaseAmount; // Maximum purchase amount in USD (8 decimals)
        uint256 dailyLimit; // Daily trading limit per user (8 decimals)
        bool limitsEnabled; // Whether limits are enforced
    }

    TradingLimits public tradingLimits;

    // Daily trading tracking
    mapping(address => mapping(uint256 => uint256)) public dailyTradingVolume; // user => day => volume

    // ============================================================================
    // EVENTS
    // ============================================================================

    event AssetTokenPurchased(
        address indexed buyer,
        address indexed assetToken,
        address indexed paymentToken,
        uint256 paymentAmount,
        uint256 tokensReceived,
        uint256 assetPrice,
        uint256 feeAmount
    );

    event AssetTokenSold(
        address indexed seller,
        address indexed assetToken,
        address indexed paymentToken,
        uint256 tokensSold,
        uint256 usdReceived,
        uint256 assetPrice,
        uint256 feeAmount
    );

    event URIPFundPurchased(
        address indexed buyer,
        address indexed paymentToken,
        uint256 paymentAmount,
        uint256 uripTokensReceived,
        uint256 navAtPurchase,
        uint256 feeAmount
    );

    event URIPFundSold(
        address indexed seller,
        address indexed paymentToken,
        uint256 uripTokensSold,
        uint256 usdReceived,
        uint256 navAtSale,
        uint256 feeAmount
    );

    event PaymentTokenUpdated(address indexed token, bool supported);
    event AssetTokenUpdated(address indexed token, bool supported);
    event URIPFundUpdated(address indexed oldFund, address indexed newFund);
    event FeesUpdated(FeeStructure fees);
    event TradingLimitsUpdated(TradingLimits limits);

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    /**
     * @dev Initialize PurchaseManager with default settings
     *
     * PURPOSE: Set up the contract with secure defaults and proper access control
     * FLOW: Deploy → Set roles → Initialize fees → Set trading limits → Ready for configuration
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);

        // Initialize default fee structure (0.1% fees)
        fees = FeeStructure({
            purchaseFee: 10, // 0.1%
            redemptionFee: 10, // 0.1%
            uripPurchaseFee: 5, // 0.05%
            uripRedemptionFee: 5 // 0.05%
        });

        // Initialize default trading limits
        tradingLimits = TradingLimits({
            minPurchaseAmount: 1 * 1e8, // $1 minimum
            maxPurchaseAmount: 100000 * 1e8, // $100,000 maximum
            dailyLimit: 50000 * 1e8, // $50,000 daily limit
            limitsEnabled: true
        });

        treasury = msg.sender; // Set deployer as initial treasury
    }

    // ============================================================================
    // INDIVIDUAL ASSET TRADING
    // ============================================================================

    /**
     * @dev Purchase individual asset tokens (e.g., Apple, Tesla tokens)
     * @param paymentToken Token used for payment (USDT, USDC, etc.)
     * @param assetToken Asset token to purchase (e.g., tAAPL, tTSLA)
     * @param paymentAmount Amount of payment token to spend (decimals depend on payment token)
     *
     * PURPOSE: Allow users to buy individual tokenized assets with full fee and limit management
     * CALLED BY: Users from frontend or directly from wallet
     * FLOW:
     * 1. User approves USDT spending to PurchaseManager
     * 2. User calls purchaseAssetToken(USDT, tAAPL, $1000)
     * 3. Contract validates: payment token supported ✓, asset token supported ✓, limits ✓
     * 4. Contract calculates fee and net amount
     * 5. Contract transfers USDT from user and fee to treasury
     * 6. Contract gets current asset price and calculates tokens to mint
     * 7. Contract mints asset tokens to user
     * 8. User receives tokenized assets in their wallet
     *
     * EXAMPLE: Buy $1000 worth of Apple tokens
     * - Input: USDT address, tAAPL address, 1000 USDT
     * - Fee: $1 (0.1%)
     * - Net: $999
     * - If AAPL = $150, user gets: 6.66 tAAPL tokens
     */
    function purchaseAssetToken(
        address paymentToken,
        address assetToken,
        uint256 paymentAmount
    ) external whenNotPaused nonReentrant {
        require(
            supportedPaymentTokens[paymentToken],
            "Payment token not supported"
        );
        require(supportedAssetTokens[assetToken], "Asset token not supported");
        require(paymentAmount > 0, "Amount must be greater than 0");

        // Convert payment amount to USD (8 decimals) - assuming payment tokens have 6 decimals like USDT
        uint256 usdAmount = _convertToUSD(paymentToken, paymentAmount);

        // Check trading limits
        _checkTradingLimits(msg.sender, usdAmount);

        // Calculate fee
        uint256 feeAmount = (usdAmount * fees.purchaseFee) / 10000;
        uint256 netAmount = usdAmount - feeAmount;

        // Get current asset price and calculate tokens to receive
        (uint256 assetPrice, ) = IAssetToken(assetToken).getCurrentPrice();
        uint256 tokensToReceive = IAssetToken(assetToken).getTokenAmount(
            netAmount
        );

        // Transfer payment from user
        IERC20(paymentToken).transferFrom(
            msg.sender,
            address(this),
            paymentAmount
        );

        // Transfer fee to treasury if fee > 0
        if (feeAmount > 0) {
            uint256 feeInPaymentToken = _convertFromUSD(
                paymentToken,
                feeAmount
            );
            IERC20(paymentToken).transfer(treasury, feeInPaymentToken);
        }

        // Mint asset tokens to user
        IAssetToken(assetToken).mint(msg.sender, tokensToReceive);

        // Update daily trading volume
        _updateDailyVolume(msg.sender, usdAmount);

        emit AssetTokenPurchased(
            msg.sender,
            assetToken,
            paymentToken,
            paymentAmount,
            tokensToReceive,
            assetPrice,
            feeAmount
        );
    }

    /**
     * @dev Sell individual asset tokens for payment tokens
     * @param paymentToken Token to receive as payment (USDT, USDC, etc.)
     * @param assetToken Asset token to sell (e.g., tAAPL, tTSLA)
     * @param tokenAmount Amount of asset tokens to sell (18 decimals)
     *
     * PURPOSE: Allow users to sell individual tokenized assets and receive USD
     * CALLED BY: Users from frontend or directly from wallet
     * FLOW:
     * 1. User has asset tokens in wallet (e.g., 6.66 tAAPL)
     * 2. User calls sellAssetToken(USDT, tAAPL, 6.66)
     * 3. Contract validates: payment token supported ✓, asset token supported ✓, user has tokens ✓
     * 4. Contract calculates current USD value of tokens
     * 5. Contract calculates fee and net USD amount
     * 6. Contract burns asset tokens from user
     * 7. Contract transfers net USDT to user and fee to treasury
     * 8. User receives USD in their wallet
     *
     * EXAMPLE: Sell 6.66 Apple tokens
     * - User has: 6.66 tAAPL tokens
     * - Current AAPL price: $155 (increased!)
     * - Gross value: 6.66 × $155 = $1,032.30
     * - Fee: $1.03 (0.1%)
     * - Net received: $1,031.27 USDT
     */
    function sellAssetToken(
        address paymentToken,
        address assetToken,
        uint256 tokenAmount
    ) external whenNotPaused nonReentrant {
        require(
            supportedPaymentTokens[paymentToken],
            "Payment token not supported"
        );
        require(supportedAssetTokens[assetToken], "Asset token not supported");
        require(tokenAmount > 0, "Amount must be greater than 0");
        require(
            IERC20(assetToken).balanceOf(msg.sender) >= tokenAmount,
            "Insufficient token balance"
        );

        // Calculate USD value of tokens being sold
        uint256 usdValue = IAssetToken(assetToken).getUSDValue(tokenAmount);

        // Check trading limits
        _checkTradingLimits(msg.sender, usdValue);

        // Calculate fee
        uint256 feeAmount = (usdValue * fees.redemptionFee) / 10000;
        uint256 netUSDAmount = usdValue - feeAmount;

        // Convert to payment token amount
        uint256 paymentAmount = _convertFromUSD(paymentToken, netUSDAmount);
        uint256 feeInPaymentToken = _convertFromUSD(paymentToken, feeAmount);

        // Ensure contract has enough payment tokens
        require(
            IERC20(paymentToken).balanceOf(address(this)) >=
                paymentAmount + feeInPaymentToken,
            "Insufficient contract balance"
        );

        // Get current asset price for event
        (uint256 assetPrice, ) = IAssetToken(assetToken).getCurrentPrice();

        // Burn asset tokens from user
        IAssetToken(assetToken).burn(msg.sender, tokenAmount);

        // Transfer payment to user
        IERC20(paymentToken).transfer(msg.sender, paymentAmount);

        // Transfer fee to treasury if fee > 0
        if (feeInPaymentToken > 0) {
            IERC20(paymentToken).transfer(treasury, feeInPaymentToken);
        }

        // Update daily trading volume
        _updateDailyVolume(msg.sender, usdValue);

        emit AssetTokenSold(
            msg.sender,
            assetToken,
            paymentToken,
            tokenAmount,
            netUSDAmount,
            assetPrice,
            feeAmount
        );
    }

    // ============================================================================
    // URIP FUND TRADING
    // ============================================================================

    /**
     * @dev Purchase URIP mutual fund tokens
     * @param paymentToken Token used for payment (USDT, USDC, etc.)
     * @param paymentAmount Amount of payment token to spend
     *
     * PURPOSE: Allow users to invest in diversified URIP fund with single transaction
     * CALLED BY: Users who want diversified exposure instead of individual assets
     * FLOW:
     * 1. User approves USDT spending to PurchaseManager
     * 2. User calls purchaseURIPFund(USDT, $5000)
     * 3. Contract validates: payment token supported ✓, URIP fund set ✓, limits ✓
     * 4. Contract calculates fee (lower fee for fund) and net amount
     * 5. Contract transfers USDT from user and fee to treasury
     * 6. Contract gets current URIP NAV and calculates tokens to mint
     * 7. Contract calls URIP contract to mint fund tokens to user
     * 8. User receives diversified portfolio exposure through URIP tokens
     *
     * EXAMPLE: Invest $5000 in URIP fund
     * - Input: USDT address, 5000 USDT
     * - Fee: $2.50 (0.05% - lower fee for fund)
     * - Net: $4,997.50
     * - If URIP NAV = $1.05, user gets: 4,759.52 URIP tokens
     * - User now owns portion of diversified portfolio
     */
    function purchaseURIPFund(
        address paymentToken,
        uint256 paymentAmount
    ) external whenNotPaused nonReentrant {
        require(
            supportedPaymentTokens[paymentToken],
            "Payment token not supported"
        );
        require(uripFund != address(0), "URIP fund not set");
        require(paymentAmount > 0, "Amount must be greater than 0");

        // Convert payment amount to USD (8 decimals)
        uint256 usdAmount = _convertToUSD(paymentToken, paymentAmount);

        // Check trading limits
        _checkTradingLimits(msg.sender, usdAmount);

        // Calculate fee
        uint256 feeAmount = (usdAmount * fees.uripPurchaseFee) / 10000;
        uint256 netAmount = usdAmount - feeAmount;

        // Calculate URIP tokens to receive
        uint256 uripTokensToReceive = IURIPToken(uripFund).getTokenAmount(
            netAmount
        );

        // Get current NAV for event
        (uint256 currentNAV, ) = IURIPToken(uripFund).getCurrentNAV();

        // Transfer payment from user
        IERC20(paymentToken).transferFrom(
            msg.sender,
            address(this),
            paymentAmount
        );

        // Transfer fee to treasury if fee > 0
        if (feeAmount > 0) {
            uint256 feeInPaymentToken = _convertFromUSD(
                paymentToken,
                feeAmount
            );
            IERC20(paymentToken).transfer(treasury, feeInPaymentToken);
        }

        // Purchase URIP fund tokens
        IURIPToken(uripFund).purchaseFund(msg.sender, netAmount);

        // Update daily trading volume
        _updateDailyVolume(msg.sender, usdAmount);

        emit URIPFundPurchased(
            msg.sender,
            paymentToken,
            paymentAmount,
            uripTokensToReceive,
            currentNAV,
            feeAmount
        );
    }

    /**
     * @dev Sell URIP mutual fund tokens for payment tokens
     * @param paymentToken Token to receive as payment (USDT, USDC, etc.)
     * @param uripTokenAmount Amount of URIP tokens to sell (18 decimals)
     *
     * PURPOSE: Allow users to exit from diversified URIP fund and receive USD
     * CALLED BY: Users who want to exit their fund position
     * FLOW:
     * 1. User has URIP tokens in wallet (e.g., 4,759.52 URIP)
     * 2. User calls sellURIPFund(USDT, 4759.52)
     * 3. Contract validates: payment token supported ✓, URIP fund set ✓, user has tokens ✓
     * 4. Contract calculates current USD value based on NAV
     * 5. Contract calculates fee and net USD amount
     * 6. Contract calls URIP contract to burn tokens and get actual USD received
     * 7. Contract transfers net USDT to user and fee to treasury
     * 8. User receives USD representing their share of the fund
     *
     * EXAMPLE: Sell 4,759.52 URIP tokens
     * - User has: 4,759.52 URIP tokens
     * - Current NAV: $1.08 (fund gained value!)
     * - Gross value: 4,759.52 × $1.08 = $5,140.28
     * - Fee: $2.57 (0.05%)
     * - Net received: $5,137.71 USDT
     * - Profit: $137.71 from fund performance
     */
    function sellURIPFund(
        address paymentToken,
        uint256 uripTokenAmount
    ) external whenNotPaused nonReentrant {
        require(
            supportedPaymentTokens[paymentToken],
            "Payment token not supported"
        );
        require(uripFund != address(0), "URIP fund not set");
        require(uripTokenAmount > 0, "Amount must be greater than 0");
        require(
            IERC20(uripFund).balanceOf(msg.sender) >= uripTokenAmount,
            "Insufficient URIP balance"
        );

        // Calculate USD value of URIP tokens being sold
        uint256 usdValue = IURIPToken(uripFund).getUSDValue(uripTokenAmount);

        // Check trading limits
        _checkTradingLimits(msg.sender, usdValue);

        // Calculate fee
        uint256 feeAmount = (usdValue * fees.uripRedemptionFee) / 10000;

        // Get current NAV for event
        (uint256 currentNAV, ) = IURIPToken(uripFund).getCurrentNAV();

        // Redeem URIP tokens (this will burn tokens and return actual USD amount received)
        uint256 actualUSDReceived = IURIPToken(uripFund).redeemFund(
            msg.sender,
            uripTokenAmount
        );

        // Apply fee to actual amount received
        uint256 netUSDAmount = actualUSDReceived - feeAmount;

        // Convert to payment token amount
        uint256 paymentAmount = _convertFromUSD(paymentToken, netUSDAmount);
        uint256 feeInPaymentToken = _convertFromUSD(paymentToken, feeAmount);

        // Ensure contract has enough payment tokens
        require(
            IERC20(paymentToken).balanceOf(address(this)) >=
                paymentAmount + feeInPaymentToken,
            "Insufficient contract balance"
        );

        // Transfer payment to user
        IERC20(paymentToken).transfer(msg.sender, paymentAmount);

        // Transfer fee to treasury if fee > 0
        if (feeInPaymentToken > 0) {
            IERC20(paymentToken).transfer(treasury, feeInPaymentToken);
        }

        // Update daily trading volume
        _updateDailyVolume(msg.sender, actualUSDReceived);

        emit URIPFundSold(
            msg.sender,
            paymentToken,
            uripTokenAmount,
            netUSDAmount,
            currentNAV,
            feeAmount
        );
    }

    // ============================================================================
    // GET ALL SUPPORTED TOKENS & ASSETS
    // ============================================================================

    /**
     * @dev Get all supported payment tokens
     * @return tokens Array of payment token addresses
     * @return names Array of token names
     * @return symbols Array of token symbols
     *
     * PURPOSE: Provide frontend with list of all accepted payment methods
     * CALLED BY: Frontend applications, wallets, integrations
     * FLOW: Query contract → Get all payment tokens → Display to user
     *
     * EXAMPLE RETURN:
     * - tokens: [0x123...(USDT), 0x456...(USDC)]
     * - names: ["Tether USD", "USD Coin"]
     * - symbols: ["USDT", "USDC"]
     */
    function getAllSupportedPaymentTokens()
        external
        view
        returns (
            address[] memory tokens,
            string[] memory names,
            string[] memory symbols
        )
    {
        uint256 count = 0;

        // Count active payment tokens
        for (uint256 i = 0; i < paymentTokensList.length; i++) {
            if (supportedPaymentTokens[paymentTokensList[i]]) {
                count++;
            }
        }

        // Create arrays with exact size
        tokens = new address[](count);
        names = new string[](count);
        symbols = new string[](count);

        // Populate arrays
        uint256 index = 0;
        for (uint256 i = 0; i < paymentTokensList.length; i++) {
            if (supportedPaymentTokens[paymentTokensList[i]]) {
                tokens[index] = paymentTokensList[i];

                // Get token info (handle potential failures)
                try IERC20Extended(paymentTokensList[i]).name() returns (
                    string memory name
                ) {
                    names[index] = name;
                } catch {
                    names[index] = "Unknown";
                }

                try IERC20Extended(paymentTokensList[i]).symbol() returns (
                    string memory symbol
                ) {
                    symbols[index] = symbol;
                } catch {
                    symbols[index] = "???";
                }

                index++;
            }
        }
    }

    /**
     * @dev Get all supported asset tokens with their current prices
     * @return tokens Array of asset token addresses
     * @return names Array of token names
     * @return symbols Array of token symbols
     * @return prices Array of current prices (8 decimals USD)
     * @return lastUpdated Array of last price update timestamps
     * @return assetTypes Array of asset types (STOCK, COMMODITY, etc.)
     *
     * PURPOSE: Provide comprehensive market data for all tradeable assets
     * CALLED BY: Frontend for market overview, trading interfaces, portfolio displays
     * FLOW: Query contract → Get all assets → Get current prices → Display market data
     *
     * EXAMPLE RETURN:
     * - tokens: [0x789...(tAAPL), 0xABC...(tTSLA), 0xDEF...(tXAU)]
     * - names: ["Tokenized Apple Stock", "Tokenized Tesla Stock", "Tokenized Gold"]
     * - symbols: ["tAAPL", "tTSLA", "tXAU"]
     * - prices: [15000000000, 20000000000, 200000000000] ($150.00, $200.00, $2000.00)
     * - lastUpdated: [1640995200, 1640995300, 1640995400]
     * - assetTypes: ["STOCK", "STOCK", "COMMODITY"]
     */
    function getAllSupportedAssetsWithPrices()
        external
        view
        returns (
            address[] memory tokens,
            string[] memory names,
            string[] memory symbols,
            uint256[] memory prices,
            uint256[] memory lastUpdated,
            string[] memory assetTypes
        )
    {
        uint256 count = 0;

        // Count active asset tokens
        for (uint256 i = 0; i < assetTokensList.length; i++) {
            if (supportedAssetTokens[assetTokensList[i]]) {
                count++;
            }
        }

        // Create arrays with exact size
        tokens = new address[](count);
        names = new string[](count);
        symbols = new string[](count);
        prices = new uint256[](count);
        lastUpdated = new uint256[](count);
        assetTypes = new string[](count);

        // Populate arrays
        uint256 index = 0;
        for (uint256 i = 0; i < assetTokensList.length; i++) {
            if (supportedAssetTokens[assetTokensList[i]]) {
                address token = assetTokensList[i];
                tokens[index] = token;

                // Get basic token info
                try IAssetToken(token).name() returns (string memory name) {
                    names[index] = name;
                } catch {
                    names[index] = "Unknown Asset";
                }

                try IAssetToken(token).symbol() returns (string memory symbol) {
                    symbols[index] = symbol;
                } catch {
                    symbols[index] = "???";
                }

                // Get price data
                try IAssetToken(token).getCurrentPrice() returns (
                    uint256 price,
                    uint256 timestamp
                ) {
                    prices[index] = price;
                    lastUpdated[index] = timestamp;
                } catch {
                    prices[index] = 0;
                    lastUpdated[index] = 0;
                }

                // FIXED: Get asset info using struct return
                try IAssetToken(token).getAssetInfo() returns (
                    IAssetToken.AssetInfo memory info
                ) {
                    assetTypes[index] = info.assetType;
                    // Use price from AssetInfo if getCurrentPrice failed
                    if (prices[index] == 0) {
                        prices[index] = info.currentPrice;
                        lastUpdated[index] = info.lastUpdate;
                    }
                } catch {
                    assetTypes[index] = "UNKNOWN";
                }

                index++;
            }
        }
    }

    /**
     * @dev Get URIP fund information with current NAV and allocation data
     * @return fundAddress URIP fund contract address
     * @return name Fund name
     * @return symbol Fund symbol
     * @return currentNAV Current Net Asset Value per token (18 decimals)
     * @return lastNAVUpdate Timestamp of last NAV update
     * @return totalValue Total fund asset value (8 decimals USD)
     * @return totalTokens Total URIP tokens in circulation
     * @return managementFee Annual management fee (basis points)
     * @return assetCount Number of underlying assets
     * @return isActive Whether fund is active for trading
     *
     * PURPOSE: Provide comprehensive URIP fund information for investors
     * CALLED BY: Frontend for fund overview, investment decisions, portfolio tracking
     * FLOW: Query contract → Get fund data → Display fund information
     *
     * EXAMPLE RETURN:
     * - fundAddress: 0x123...
     * - name: "URIP Global Mixed Fund"
     * - symbol: "URIP"
     * - currentNAV: 1050000000000000000 ($1.05)
     * - totalValue: 1000000000 ($10,000.00)
     * - totalTokens: 9523809523809523809523 (9,523.81 URIP tokens)
     * - managementFee: 200 (2% annual)
     * - assetCount: 8 (8 different assets in portfolio)
     * - isActive: true
     */
    function getURIPFundInfo()
        external
        view
        returns (
            address fundAddress,
            string memory name,
            string memory symbol,
            uint256 currentNAV,
            uint256 lastNAVUpdate,
            uint256 totalValue,
            uint256 totalTokens,
            uint256 managementFee,
            uint256 assetCount,
            bool isActive
        )
    {
        fundAddress = uripFund;

        if (uripFund == address(0)) {
            // Return empty data if no fund is set
            return (address(0), "", "", 0, 0, 0, 0, 0, 0, false);
        }

        // Get basic token info
        try IURIPToken(uripFund).name() returns (string memory _name) {
            name = _name;
        } catch {
            name = "URIP Fund";
        }

        try IURIPToken(uripFund).symbol() returns (string memory _symbol) {
            symbol = _symbol;
        } catch {
            symbol = "URIP";
        }

        // Get NAV data
        try IURIPToken(uripFund).getCurrentNAV() returns (
            uint256 nav,
            uint256 timestamp
        ) {
            currentNAV = nav;
            lastNAVUpdate = timestamp;
        } catch {
            currentNAV = 0;
            lastNAVUpdate = 0;
        }

        // Get fund statistics
        try IURIPToken(uripFund).getFundStats() returns (
            uint256 _totalValue,
            uint256 _nav,
            uint256 _totalTokens,
            uint256 _managementFee,
            uint256 _assetCount,
            bool _isActive
        ) {
            totalValue = _totalValue;
            totalTokens = _totalTokens;
            managementFee = _managementFee;
            assetCount = _assetCount;
            isActive = _isActive;
        } catch {
            totalValue = 0;
            totalTokens = 0;
            managementFee = 0;
            assetCount = 0;
            isActive = false;
        }
    }

    /**
     * @dev Get URIP fund asset allocations
     * @return assets Array of underlying asset addresses
     * @return allocations Array of allocation percentages (basis points)
     * @return assetNames Array of asset names
     * @return assetSymbols Array of asset symbols
     * @return assetPrices Array of current asset prices
     *
     * PURPOSE: Show detailed fund composition to investors
     * CALLED BY: Frontend for fund analysis, portfolio breakdown displays
     * FLOW: Query fund allocations → Get asset details → Display portfolio composition
     *
     * EXAMPLE: URIP fund composition
     * - assets: [tAAPL, tTSLA, tXAU]
     * - allocations: [3000, 2000, 1500] (30%, 20%, 15%)
     * - assetNames: ["Tokenized Apple Stock", "Tokenized Tesla Stock", "Tokenized Gold"]
     * - assetSymbols: ["tAAPL", "tTSLA", "tXAU"]
     * - assetPrices: [15000000000, 20000000000, 200000000000]
     */
    function getURIPFundAllocations()
        external
        view
        returns (
            address[] memory assets,
            uint256[] memory allocations,
            string[] memory assetNames,
            string[] memory assetSymbols,
            uint256[] memory assetPrices
        )
    {
        if (uripFund == address(0)) {
            // Return empty arrays if no fund is set
            return (
                new address[](0),
                new uint256[](0),
                new string[](0),
                new string[](0),
                new uint256[](0)
            );
        }

        try IURIPToken(uripFund).getAllAssetAllocations() returns (
            address[] memory _assets,
            uint256[] memory _allocations
        ) {
            assets = _assets;
            allocations = _allocations;

            uint256 length = assets.length;
            assetNames = new string[](length);
            assetSymbols = new string[](length);
            assetPrices = new uint256[](length);

            // Get detailed info for each asset
            for (uint256 i = 0; i < length; i++) {
                try IAssetToken(assets[i]).name() returns (string memory name) {
                    assetNames[i] = name;
                } catch {
                    assetNames[i] = "Unknown Asset";
                }

                try IAssetToken(assets[i]).symbol() returns (
                    string memory symbol
                ) {
                    assetSymbols[i] = symbol;
                } catch {
                    assetSymbols[i] = "???";
                }

                try IAssetToken(assets[i]).getCurrentPrice() returns (
                    uint256 price,
                    uint256
                ) {
                    assetPrices[i] = price;
                } catch {
                    assetPrices[i] = 0;
                }
            }
        } catch {
            // Return empty arrays if call fails
            return (
                new address[](0),
                new uint256[](0),
                new string[](0),
                new string[](0),
                new uint256[](0)
            );
        }
    }

    // ============================================================================
    // ENHANCED PRICE INFORMATION
    // ============================================================================

    /**
     * @dev Get detailed price information for a specific asset
     * @param assetToken Asset token address
     * @return currentPrice Current price in USD (8 decimals)
     * @return lastUpdate Timestamp of last price update
     * @return assetSymbol Asset symbol (e.g., "AAPL")
     * @return assetType Asset type (e.g., "STOCK")
     * @return isActive Whether asset is active for trading
     * @return tokenName Full token name
     * @return tokenSymbol Token symbol (e.g., "tAAPL")
     *
     * PURPOSE: Provide detailed asset information for trading decisions
     * CALLED BY: Frontend when user selects specific asset, trading forms
     * FLOW: User selects asset → Get detailed info → Display in trading interface
     */
    function getAssetPriceInfo(
        address assetToken
    )
        external
        view
        returns (
            uint256 currentPrice,
            uint256 lastUpdate,
            string memory assetSymbol,
            string memory assetType,
            bool isActive,
            string memory tokenName,
            string memory tokenSymbol
        )
    {
        require(supportedAssetTokens[assetToken], "Asset token not supported");

        // Get price data
        try IAssetToken(assetToken).getCurrentPrice() returns (
            uint256 price,
            uint256 timestamp
        ) {
            currentPrice = price;
            lastUpdate = timestamp;
        } catch {
            currentPrice = 0;
            lastUpdate = 0;
        }

        try IAssetToken(assetToken).getAssetInfo() returns (
            IAssetToken.AssetInfo memory info
        ) {
            assetSymbol = info.symbol;
            assetType = info.assetType;
            isActive = info.isActive;
            if (currentPrice == 0) {
                currentPrice = info.currentPrice;
                lastUpdate = info.lastUpdate;
            }
        } catch {
            assetSymbol = "???";
            assetType = "UNKNOWN";
            isActive = false;
        }

        // Get token info
        try IAssetToken(assetToken).name() returns (string memory name) {
            tokenName = name;
        } catch {
            tokenName = "Unknown Token";
        }

        try IAssetToken(assetToken).symbol() returns (string memory symbol) {
            tokenSymbol = symbol;
        } catch {
            tokenSymbol = "???";
        }
    }

    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================

    /**
     * @dev Convert payment token amount to USD (8 decimals)
     * @param paymentToken Address of payment token
     * @param amount Amount in payment token's native decimals
     * @return USD amount (8 decimals)
     *
     * PURPOSE: Standardize all amounts to USD for internal calculations
     * FLOW: Payment token amount → Convert to USD → Use for calculations
     */
    function _convertToUSD(
        address paymentToken,
        uint256 amount
    ) internal pure returns (uint256) {
        // For USDT (6 decimals) and USDC (6 decimals), convert to 8 decimals
        // This is a simplified conversion assuming 1:1 USD peg
        // In production, you might want to use price oracles for other tokens
        return amount * 100; // Convert from 6 decimals to 8 decimals
    }

    /**
     * @dev Convert USD amount (8 decimals) to payment token amount
     * @param paymentToken Address of payment token
     * @param usdAmount USD amount (8 decimals)
     * @return Amount in payment token's native decimals
     *
     * PURPOSE: Convert USD back to payment token for transfers
     * FLOW: USD amount → Convert to payment token → Transfer to user
     */
    function _convertFromUSD(
        address paymentToken,
        uint256 usdAmount
    ) internal pure returns (uint256) {
        // For USDT (6 decimals) and USDC (6 decimals), convert from 8 decimals
        // This is a simplified conversion assuming 1:1 USD peg
        return usdAmount / 100; // Convert from 8 decimals to 6 decimals
    }

    /**
     * @dev Check if trading amount is within limits
     * @param user User address
     * @param usdAmount USD amount to check (8 decimals)
     *
     * PURPOSE: Enforce trading limits for security and compliance
     * FLOW: Check min/max limits → Check daily limit → Allow or reject trade
     */
    function _checkTradingLimits(
        address user,
        uint256 usdAmount
    ) internal view {
        if (!tradingLimits.limitsEnabled) return;

        require(
            usdAmount >= tradingLimits.minPurchaseAmount,
            "Amount below minimum"
        );
        require(
            usdAmount <= tradingLimits.maxPurchaseAmount,
            "Amount above maximum"
        );

        // Check daily limit
        uint256 today = block.timestamp / 86400; // Current day
        uint256 todayVolume = dailyTradingVolume[user][today];
        require(
            todayVolume + usdAmount <= tradingLimits.dailyLimit,
            "Daily limit exceeded"
        );
    }

    /**
     * @dev Update user's daily trading volume
     * @param user User address
     * @param usdAmount USD amount to add to daily volume (8 decimals)
     *
     * PURPOSE: Track user trading volume for limit enforcement
     * FLOW: Execute trade → Update daily volume → Track for next trade
     */
    function _updateDailyVolume(address user, uint256 usdAmount) internal {
        uint256 today = block.timestamp / 86400; // Current day
        dailyTradingVolume[user][today] += usdAmount;
    }

    /**
     * @dev Add token to payment tokens list if not already present
     * @param token Token address to add
     */
    function _addToPaymentTokensList(address token) internal {
        for (uint256 i = 0; i < paymentTokensList.length; i++) {
            if (paymentTokensList[i] == token) {
                return; // Already in list
            }
        }
        paymentTokensList.push(token);
    }

    /**
     * @dev Add token to asset tokens list if not already present
     * @param token Token address to add
     */
    function _addToAssetTokensList(address token) internal {
        for (uint256 i = 0; i < assetTokensList.length; i++) {
            if (assetTokensList[i] == token) {
                return; // Already in list
            }
        }
        assetTokensList.push(token);
    }

    // ============================================================================
    // CONFIGURATION FUNCTIONS
    // ============================================================================

    /**
     * @dev Set supported payment token status
     * @param token Payment token address
     * @param supported Whether token is supported
     *
     * PURPOSE: Configure which tokens can be used for payments
     * CALLED BY: Admin to add/remove payment methods
     * FLOW: Admin decision → Configure token → Users can use for trading
     */
    function setSupportedPaymentToken(
        address token,
        bool supported
    ) external onlyRole(MANAGER_ROLE) {
        supportedPaymentTokens[token] = supported;

        if (supported) {
            _addToPaymentTokensList(token);
        }

        emit PaymentTokenUpdated(token, supported);
    }

    /**
     * @dev Set supported asset token status
     * @param assetToken Asset token address
     * @param supported Whether token is supported
     *
     * PURPOSE: Configure which assets can be traded
     * CALLED BY: Admin to add/remove tradeable assets
     * FLOW: New asset deployed → Admin configures → Users can trade asset
     */
    function setSupportedAssetToken(
        address assetToken,
        bool supported
    ) external onlyRole(MANAGER_ROLE) {
        supportedAssetTokens[assetToken] = supported;

        if (supported) {
            _addToAssetTokensList(assetToken);
        }

        emit AssetTokenUpdated(assetToken, supported);
    }

    /**
     * @dev Set URIP fund contract address
     * @param _uripFund URIP fund contract address
     *
     * PURPOSE: Configure the mutual fund contract
     * CALLED BY: Admin during setup or fund upgrade
     * FLOW: URIP fund deployed → Admin sets address → Users can trade fund
     */
    function setURIPFund(address _uripFund) external onlyRole(MANAGER_ROLE) {
        address oldFund = uripFund;
        uripFund = _uripFund;
        emit URIPFundUpdated(oldFund, _uripFund);
    }

    /**
     * @dev Update fee structure
     * @param _fees New fee structure
     *
     * PURPOSE: Adjust trading fees for different operations
     * CALLED BY: Admin or governance for fee optimization
     * FLOW: Fee analysis → Admin updates → New fees apply to trades
     */
    function setFees(
        FeeStructure memory _fees
    ) external onlyRole(MANAGER_ROLE) {
        require(_fees.purchaseFee <= 1000, "Purchase fee too high"); // Max 10%
        require(_fees.redemptionFee <= 1000, "Redemption fee too high"); // Max 10%
        require(_fees.uripPurchaseFee <= 500, "URIP purchase fee too high"); // Max 5%
        require(_fees.uripRedemptionFee <= 500, "URIP redemption fee too high"); // Max 5%

        fees = _fees;
        emit FeesUpdated(_fees);
    }

    /**
     * @dev Update trading limits
     * @param _limits New trading limits
     *
     * PURPOSE: Adjust trading limits for security and compliance
     * CALLED BY: Admin for risk management or regulatory compliance
     * FLOW: Risk assessment → Admin updates limits → Limits enforced on trades
     */
    function setTradingLimits(
        TradingLimits memory _limits
    ) external onlyRole(MANAGER_ROLE) {
        require(
            _limits.minPurchaseAmount <= _limits.maxPurchaseAmount,
            "Invalid limits"
        );
        require(
            _limits.maxPurchaseAmount <= _limits.dailyLimit,
            "Max purchase exceeds daily limit"
        );

        tradingLimits = _limits;
        emit TradingLimitsUpdated(_limits);
    }

    /**
     * @dev Set treasury address
     * @param _treasury New treasury address
     *
     * PURPOSE: Configure where trading fees are collected
     * CALLED BY: Admin for treasury management
     * FLOW: Treasury decision → Admin updates → Fees go to new treasury
     */
    function setTreasury(
        address _treasury
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
    }

    // ============================================================================
    // VIEW FUNCTIONS - ENHANCED
    // ============================================================================

    /**
     * @dev Get user's remaining daily trading limit
     * @param user User address
     * @return Remaining USD amount that can be traded today (8 decimals)
     *
     * PURPOSE: Help users understand their trading capacity
     * CALLED BY: Frontend to show remaining limits, prevent failed transactions
     * FLOW: User checks limit → See remaining amount → Plan trades accordingly
     */
    function getRemainingDailyLimit(
        address user
    ) external view returns (uint256) {
        if (!tradingLimits.limitsEnabled) return type(uint256).max;

        uint256 today = block.timestamp / 86400;
        uint256 todayVolume = dailyTradingVolume[user][today];

        return
            tradingLimits.dailyLimit > todayVolume
                ? tradingLimits.dailyLimit - todayVolume
                : 0;
    }

    /**
     * @dev Get user's trading volume for specific day
     * @param user User address
     * @param day Day number (block.timestamp / 86400)
     * @return Trading volume for that day (8 decimals)
     *
     * PURPOSE: Track user trading history and patterns
     * CALLED BY: Analytics, compliance monitoring, user dashboards
     */
    function getDailyTradingVolume(
        address user,
        uint256 day
    ) external view returns (uint256) {
        return dailyTradingVolume[user][day];
    }

    /**
     * @dev Calculate purchase preview (how many tokens user would receive)
     * @param paymentToken Payment token address
     * @param assetToken Asset token address (use address(0) for URIP fund)
     * @param paymentAmount Payment amount
     * @return tokensToReceive Amount of tokens user would receive
     * @return feeAmount Fee amount in USD (8 decimals)
     * @return netAmount Net amount after fees in USD (8 decimals)
     *
     * PURPOSE: Show users exactly what they'll get before trading
     * CALLED BY: Frontend trading forms, user interfaces
     * FLOW: User enters amount → Get preview → User confirms → Execute trade
     */
    function getpurchasePreview(
        address paymentToken,
        address assetToken,
        uint256 paymentAmount
    )
        external
        view
        returns (uint256 tokensToReceive, uint256 feeAmount, uint256 netAmount)
    {
        require(
            supportedPaymentTokens[paymentToken],
            "Payment token not supported"
        );

        uint256 usdAmount = _convertToUSD(paymentToken, paymentAmount);

        if (assetToken == address(0)) {
            // URIP fund purchase
            require(uripFund != address(0), "URIP fund not set");
            feeAmount = (usdAmount * fees.uripPurchaseFee) / 10000;
            netAmount = usdAmount - feeAmount;
            tokensToReceive = IURIPToken(uripFund).getTokenAmount(netAmount);
        } else {
            // Individual asset purchase
            require(
                supportedAssetTokens[assetToken],
                "Asset token not supported"
            );
            feeAmount = (usdAmount * fees.purchaseFee) / 10000;
            netAmount = usdAmount - feeAmount;
            tokensToReceive = IAssetToken(assetToken).getTokenAmount(netAmount);
        }
    }

    /**
     * @dev Calculate redemption preview (how much USD user would receive)
     * @param paymentToken Payment token address
     * @param assetToken Asset token address (use address(0) for URIP fund)
     * @param tokenAmount Token amount to sell
     * @return usdToReceive Amount of USD user would receive (8 decimals)
     * @return feeAmount Fee amount in USD (8 decimals)
     * @return grossAmount Gross amount before fees in USD (8 decimals)
     *
     * PURPOSE: Show users exactly what they'll receive before selling
     * CALLED BY: Frontend selling forms, user interfaces
     * FLOW: User enters sell amount → Get preview → User confirms → Execute sale
     */
    function getRedemptionPreview(
        address paymentToken,
        address assetToken,
        uint256 tokenAmount
    )
        external
        view
        returns (uint256 usdToReceive, uint256 feeAmount, uint256 grossAmount)
    {
        require(
            supportedPaymentTokens[paymentToken],
            "Payment token not supported"
        );

        if (assetToken == address(0)) {
            // URIP fund redemption
            require(uripFund != address(0), "URIP fund not set");
            grossAmount = IURIPToken(uripFund).getUSDValue(tokenAmount);
            feeAmount = (grossAmount * fees.uripRedemptionFee) / 10000;
        } else {
            // Individual asset redemption
            require(
                supportedAssetTokens[assetToken],
                "Asset token not supported"
            );
            grossAmount = IAssetToken(assetToken).getUSDValue(tokenAmount);
            feeAmount = (grossAmount * fees.redemptionFee) / 10000;
        }

        usdToReceive = grossAmount - feeAmount;
    }

    /**
     * @dev Get comprehensive market overview
     * @return totalAssets Number of supported assets
     * @return totalPaymentTokens Number of supported payment tokens
     * @return uripFundActive Whether URIP fund is available
     * @return totalTradingVolume24h Total trading volume in last 24 hours (if tracked)
     * @return feesCollected24h Total fees collected in last 24 hours (if tracked)
     *
     * PURPOSE: Provide market overview and statistics
     * CALLED BY: Dashboards, analytics, market overview pages
     */
    function getMarketOverview()
        external
        view
        returns (
            uint256 totalAssets,
            uint256 totalPaymentTokens,
            bool uripFundActive,
            uint256 totalTradingVolume24h,
            uint256 feesCollected24h
        )
    {
        // Count active assets
        for (uint256 i = 0; i < assetTokensList.length; i++) {
            if (supportedAssetTokens[assetTokensList[i]]) {
                totalAssets++;
            }
        }

        // Count active payment tokens
        for (uint256 i = 0; i < paymentTokensList.length; i++) {
            if (supportedPaymentTokens[paymentTokensList[i]]) {
                totalPaymentTokens++;
            }
        }

        uripFundActive = uripFund != address(0);

        // For now, return 0 for volume and fees - could be implemented with additional tracking
        totalTradingVolume24h = 0;
        feesCollected24h = 0;
    }

    // ============================================================================
    // EMERGENCY FUNCTIONS
    // ============================================================================

    /**
     * @dev Pause contract in emergency
     *
     * PURPOSE: Stop all trading in case of emergency
     * CALLED BY: Manager in emergency situations
     * FLOW: Emergency detected → Manager pauses → All trading stops
     */
    function pause() external onlyRole(MANAGER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract
     *
     * PURPOSE: Resume trading after emergency is resolved
     * CALLED BY: Manager after emergency resolution
     * FLOW: Emergency resolved → Manager unpauses → Trading resumes
     */
    function unpause() external onlyRole(MANAGER_ROLE) {
        _unpause();
    }

    /**
     * @dev Emergency withdrawal of tokens from contract
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     *
     * PURPOSE: Recover funds in emergency situations
     * CALLED BY: Admin in extreme emergency
     * FLOW: Emergency → Admin withdraws → Funds secured
     */
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "Invalid token address");
        IERC20(token).transfer(msg.sender, amount);
    }

    /**
     * @dev Emergency withdrawal of ETH from contract
     *
     * PURPOSE: Recover ETH in emergency situations
     * CALLED BY: Admin in extreme emergency
     * FLOW: Emergency → Admin withdraws ETH → Funds secured
     */
    function emergencyWithdrawETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }

    // ============================================================================
    // RECEIVE FUNCTION
    // ============================================================================

    /**
     * @dev Allow contract to receive ETH
     *
     * PURPOSE: Enable ETH deposits if needed for gas or operations
     */
    receive() external payable {}
}

// Extended ERC20 interface for token info
interface IERC20Extended {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}
