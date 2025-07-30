// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// ============================================================================
// 1. ASSET TOKEN CONTRACT (untuk individual stocks/commodities)
// ============================================================================

contract AssetToken is ERC20, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    struct AssetInfo {
        string symbol; // e.g., "AAPL", "TSLA"
        string assetType; // e.g., "STOCK", "COMMODITY"
        uint256 currentPrice; // Price dalam USD (dengan 8 decimals)
        uint256 lastUpdate; // Timestamp last price update
        bool isActive; // Asset masih aktif atau tidak
    }

    AssetInfo public assetInfo;

    // Events
    event PriceUpdated(uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event AssetMinted(address indexed to, uint256 amount, uint256 price);
    event AssetBurned(address indexed from, uint256 amount, uint256 price);

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

    // Mint tokens ketika real asset dibeli
    function mint(
        address to,
        uint256 amount
    ) public onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(assetInfo.isActive, "Asset not active");
        _mint(to, amount);
        emit AssetMinted(to, amount, assetInfo.currentPrice);
    }

    // Burn tokens ketika real asset dijual
    function burn(
        address from,
        uint256 amount
    ) public onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(balanceOf(from) >= amount, "Insufficient balance");
        _burn(from, amount);
        emit AssetBurned(from, amount, assetInfo.currentPrice);
    }

    // Update price dari oracle
    function updatePrice(
        uint256 newPrice
    ) public onlyRole(ORACLE_ROLE) whenNotPaused {
        require(newPrice > 0, "Price must be greater than 0");
        uint256 oldPrice = assetInfo.currentPrice;
        assetInfo.currentPrice = newPrice;
        assetInfo.lastUpdate = block.timestamp;
        emit PriceUpdated(oldPrice, newPrice, block.timestamp);
    }

    // Get current asset price
    function getCurrentPrice() public view returns (uint256, uint256) {
        return (assetInfo.currentPrice, assetInfo.lastUpdate);
    }

    // Pause functions
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // Override required functions
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}

// ============================================================================
// 2. URIP TOKEN CONTRACT (untuk mutual fund)
// ============================================================================

contract URIPToken is ERC20, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant FUND_MANAGER_ROLE = keccak256("FUND_MANAGER_ROLE");

    struct FundInfo {
        uint256 totalAssetValue; // Total value dari underlying assets (USD)
        uint256 navPerToken; // Net Asset Value per token
        uint256 lastNavUpdate; // Last NAV calculation timestamp
        uint256 managementFee; // Annual management fee (basis points)
        bool isActive;
    }

    FundInfo public fundInfo;

    // Track underlying assets dalam fund
    mapping(address => uint256) public assetAllocations; // AssetToken address => percentage (basis points)
    address[] public underlyingAssets;

    // Events
    event NAVUpdated(uint256 oldNAV, uint256 newNAV, uint256 timestamp);
    event FundPurchased(address indexed buyer, uint256 amount, uint256 nav);
    event FundRedeemed(address indexed redeemer, uint256 amount, uint256 nav);
    event AssetAllocationUpdated(address indexed asset, uint256 newAllocation);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialNAV,
        uint256 _managementFee
    ) ERC20(_name, _symbol) {
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

    // Purchase fund dengan mint URIP tokens
    function purchaseFund(
        address to,
        uint256 usdAmount
    ) public onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(fundInfo.isActive, "Fund not active");
        require(usdAmount > 0, "Amount must be greater than 0");

        uint256 tokensToMint = (usdAmount * 1e18) / fundInfo.navPerToken;
        _mint(to, tokensToMint);

        fundInfo.totalAssetValue += usdAmount;
        emit FundPurchased(to, tokensToMint, fundInfo.navPerToken);
    }

    // Redeem fund dengan burn URIP tokens
    function redeemFund(
        address from,
        uint256 tokenAmount
    )
        public
        onlyRole(MINTER_ROLE)
        whenNotPaused
        nonReentrant
        returns (uint256 usdAmount)
    {
        require(balanceOf(from) >= tokenAmount, "Insufficient balance");

        usdAmount = (tokenAmount * fundInfo.navPerToken) / 1e18;
        _burn(from, tokenAmount);

        fundInfo.totalAssetValue -= usdAmount;
        emit FundRedeemed(from, tokenAmount, fundInfo.navPerToken);
    }

    // Update NAV berdasarkan underlying asset values
    function updateNAV(
        uint256 newTotalAssetValue
    ) public onlyRole(FUND_MANAGER_ROLE) whenNotPaused {
        uint256 oldNAV = fundInfo.navPerToken;

        if (totalSupply() > 0) {
            fundInfo.navPerToken = (newTotalAssetValue * 1e18) / totalSupply();
        }

        fundInfo.totalAssetValue = newTotalAssetValue;
        fundInfo.lastNavUpdate = block.timestamp;

        emit NAVUpdated(oldNAV, fundInfo.navPerToken, block.timestamp);
    }

    // Set asset allocation untuk fund
    function setAssetAllocation(
        address assetToken,
        uint256 allocationBasisPoints
    ) public onlyRole(FUND_MANAGER_ROLE) whenNotPaused {
        require(
            allocationBasisPoints <= 10000,
            "Allocation cannot exceed 100%"
        );

        if (assetAllocations[assetToken] == 0 && allocationBasisPoints > 0) {
            underlyingAssets.push(assetToken);
        }

        assetAllocations[assetToken] = allocationBasisPoints;
        emit AssetAllocationUpdated(assetToken, allocationBasisPoints);
    }

    // Get current NAV
    function getCurrentNAV() public view returns (uint256, uint256) {
        return (fundInfo.navPerToken, fundInfo.lastNavUpdate);
    }

    // Get fund statistics
    function getFundStats()
        public
        view
        returns (
            uint256 totalValue,
            uint256 nav,
            uint256 totalTokens,
            uint256 managementFee
        )
    {
        return (
            fundInfo.totalAssetValue,
            fundInfo.navPerToken,
            totalSupply(),
            fundInfo.managementFee
        );
    }

    // Pause functions
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}

// ============================================================================
// 3. SIMPLE PURCHASE MANAGER CONTRACT
// ============================================================================

contract PurchaseManager is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // Supported payment tokens (USDT, USDC, etc.)
    mapping(address => bool) public supportedPaymentTokens;

    // Asset tokens yang available untuk purchase
    mapping(address => bool) public supportedAssetTokens;

    // URIP fund contract
    address public uripFund;

    // Events
    event AssetTokenPurchased(
        address indexed buyer,
        address indexed assetToken,
        uint256 amount,
        uint256 price
    );
    event MutualFundPurchased(
        address indexed buyer,
        uint256 usdAmount,
        uint256 tokensReceived
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    // Set supported payment token (USDT, USDC, etc.)
    function setSupportedPaymentToken(
        address token,
        bool supported
    ) public onlyRole(MANAGER_ROLE) {
        supportedPaymentTokens[token] = supported;
    }

    // Set supported asset token
    function setSupportedAssetToken(
        address assetToken,
        bool supported
    ) public onlyRole(MANAGER_ROLE) {
        supportedAssetTokens[assetToken] = supported;
    }

    // Set URIP fund contract
    function setURIPFund(address _uripFund) public onlyRole(MANAGER_ROLE) {
        uripFund = _uripFund;
    }

    // Purchase individual asset token
    function purchaseAssetToken(
        address paymentToken,
        address assetToken,
        uint256 paymentAmount
    ) public whenNotPaused nonReentrant {
        require(
            supportedPaymentTokens[paymentToken],
            "Payment token not supported"
        );
        require(supportedAssetTokens[assetToken], "Asset token not supported");

        // Transfer payment dari user
        IERC20(paymentToken).transferFrom(
            msg.sender,
            address(this),
            paymentAmount
        );

        // Get current price dari asset token
        (uint256 currentPrice, ) = AssetToken(assetToken).getCurrentPrice();

        // Calculate tokens to mint (simplified calculation)
        uint256 tokensToMint = (paymentAmount * 1e18) / currentPrice;

        // Mint asset tokens ke user
        AssetToken(assetToken).mint(msg.sender, tokensToMint);

        emit AssetTokenPurchased(
            msg.sender,
            assetToken,
            tokensToMint,
            currentPrice
        );
    }

    // Purchase mutual fund (URIP)
    function purchaseMutualFund(
        address paymentToken,
        uint256 paymentAmount
    ) public whenNotPaused nonReentrant {
        require(
            supportedPaymentTokens[paymentToken],
            "Payment token not supported"
        );
        require(uripFund != address(0), "URIP fund not set");

        // Transfer payment dari user
        IERC20(paymentToken).transferFrom(
            msg.sender,
            address(this),
            paymentAmount
        );

        // Purchase URIP fund
        URIPToken(uripFund).purchaseFund(msg.sender, paymentAmount);

        emit MutualFundPurchased(msg.sender, paymentAmount, 0); // 0 for now, will be calculated
    }

    // Emergency functions
    function pause() public onlyRole(MANAGER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(MANAGER_ROLE) {
        _unpause();
    }

    // Emergency withdrawal
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).transfer(msg.sender, amount);
    }
}
