// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// Import the contracts we need to interface with
interface IURIPDAOGovernance {
    enum ProposalCategory {
        FUND_MANAGEMENT,
        PROTOCOL_GOVERNANCE,
        TREASURY_MANAGEMENT,
        EMERGENCY_ACTION
    }

    function createProposal(
        string memory title,
        string memory description,
        string[] memory actionDescriptions,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        ProposalCategory category
    ) external returns (uint256);
}

interface IURIPToken {
    function setAssetAllocation(
        address assetToken,
        uint256 allocationBasisPoints
    ) external;
    function pause() external;
    function unpause() external;
}

interface IPurchaseManager {
    function pause() external;
    function unpause() external;
    function emergencyWithdraw(address token, uint256 amount) external;
}

/**
 * @title URIPGovernanceIntegration
 * @dev Integration layer between governance and core URIP contracts
 */
contract URIPGovernanceIntegration is AccessControl {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant FUND_MANAGER_ROLE = keccak256("FUND_MANAGER_ROLE");

    IURIPDAOGovernance public immutable governance;
    IURIPToken public immutable uripToken;
    IPurchaseManager public immutable purchaseManager;

    // Governance-controlled parameters
    struct GovernanceParams {
        uint256 managementFee; // Annual management fee (basis points)
        uint256 performanceFee; // Performance fee (basis points)
        uint256 maxAssetAllocation; // Maximum allocation per asset (basis points)
        uint256 rebalanceThreshold; // Threshold for automatic rebalancing
        bool emergencyPaused; // Emergency pause state
    }

    GovernanceParams public governanceParams;

    // Asset whitelist managed by governance
    mapping(address => bool) public whitelistedAssets;
    mapping(address => uint256) public assetAllocationLimits;

    // Portfolio constraints
    struct PortfolioConstraints {
        uint256 maxAssets; // Maximum number of assets in portfolio
        uint256 minAssetWeight; // Minimum weight per asset (basis points)
        uint256 maxAssetWeight; // Maximum weight per asset (basis points)
        uint256 maxVolatilityAssets; // Max number of high volatility assets
    }

    PortfolioConstraints public portfolioConstraints;

    // Risk management parameters
    struct RiskParameters {
        uint256 maxDailyDrawdown; // Maximum daily drawdown (basis points)
        uint256 maxPortfolioVolatility; // Maximum portfolio volatility
        uint256 liquidityReserve; // Minimum liquidity reserve (basis points)
        uint256 stressTestFrequency; // Stress test frequency in days
    }

    RiskParameters public riskParameters;

    // Events
    event GovernanceParamsUpdated(GovernanceParams params);
    event AssetWhitelisted(address indexed asset, bool whitelisted);
    event AllocationLimitUpdated(address indexed asset, uint256 limit);
    event PortfolioConstraintsUpdated(PortfolioConstraints constraints);
    event RiskParametersUpdated(RiskParameters parameters);
    event EmergencyActionExecuted(string action, address target);

    constructor(
        address _governance,
        address _uripToken,
        address _purchaseManager
    ) {
        governance = IURIPDAOGovernance(_governance);
        uripToken = IURIPToken(_uripToken);
        purchaseManager = IPurchaseManager(_purchaseManager);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNANCE_ROLE, _governance);
        _grantRole(FUND_MANAGER_ROLE, msg.sender);

        // Initialize default parameters
        _initializeDefaultParams();
    }

    function _initializeDefaultParams() internal {
        governanceParams = GovernanceParams({
            managementFee: 200, // 2% annual
            performanceFee: 2000, // 20% on profits
            maxAssetAllocation: 3000, // 30% max per asset
            rebalanceThreshold: 500, // 5% deviation triggers rebalance
            emergencyPaused: false
        });

        portfolioConstraints = PortfolioConstraints({
            maxAssets: 50, // Maximum 50 assets
            minAssetWeight: 100, // 1% minimum weight
            maxAssetWeight: 3000, // 30% maximum weight
            maxVolatilityAssets: 10 // Max 10 high volatility assets
        });

        riskParameters = RiskParameters({
            maxDailyDrawdown: 500, // 5% max daily drawdown
            maxPortfolioVolatility: 2000, // 20% max portfolio volatility
            liquidityReserve: 1000, // 10% liquidity reserve
            stressTestFrequency: 30 // Monthly stress tests
        });
    }

    // ============================================================================
    // GOVERNANCE-CONTROLLED FUNCTIONS
    // ============================================================================

    /**
     * @dev Update governance parameters (only callable by governance)
     */
    function updateGovernanceParams(
        uint256 _managementFee,
        uint256 _performanceFee,
        uint256 _maxAssetAllocation,
        uint256 _rebalanceThreshold
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_managementFee <= 1000, "Management fee too high"); // Max 10%
        require(_performanceFee <= 5000, "Performance fee too high"); // Max 50%
        require(_maxAssetAllocation <= 5000, "Max allocation too high"); // Max 50%
        require(_rebalanceThreshold <= 2000, "Rebalance threshold too high"); // Max 20%

        governanceParams.managementFee = _managementFee;
        governanceParams.performanceFee = _performanceFee;
        governanceParams.maxAssetAllocation = _maxAssetAllocation;
        governanceParams.rebalanceThreshold = _rebalanceThreshold;

        emit GovernanceParamsUpdated(governanceParams);
    }

    /**
     * @dev Whitelist or blacklist assets for trading
     */
    function setAssetWhitelist(
        address[] memory assets,
        bool[] memory whitelisted
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(assets.length == whitelisted.length, "Array length mismatch");

        for (uint256 i = 0; i < assets.length; i++) {
            whitelistedAssets[assets[i]] = whitelisted[i];
            emit AssetWhitelisted(assets[i], whitelisted[i]);
        }
    }

    /**
     * @dev Set allocation limits for specific assets
     */
    function setAssetAllocationLimits(
        address[] memory assets,
        uint256[] memory limits
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(assets.length == limits.length, "Array length mismatch");

        for (uint256 i = 0; i < assets.length; i++) {
            require(
                limits[i] <= governanceParams.maxAssetAllocation,
                "Limit exceeds max"
            );
            assetAllocationLimits[assets[i]] = limits[i];
            emit AllocationLimitUpdated(assets[i], limits[i]);
        }
    }

    /**
     * @dev Update portfolio constraints
     */
    function updatePortfolioConstraints(
        uint256 _maxAssets,
        uint256 _minAssetWeight,
        uint256 _maxAssetWeight,
        uint256 _maxVolatilityAssets
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_maxAssets > 0 && _maxAssets <= 100, "Invalid max assets");
        require(_minAssetWeight < _maxAssetWeight, "Invalid weight range");
        require(
            _maxAssetWeight <= governanceParams.maxAssetAllocation,
            "Weight exceeds max allocation"
        );

        portfolioConstraints = PortfolioConstraints({
            maxAssets: _maxAssets,
            minAssetWeight: _minAssetWeight,
            maxAssetWeight: _maxAssetWeight,
            maxVolatilityAssets: _maxVolatilityAssets
        });

        emit PortfolioConstraintsUpdated(portfolioConstraints);
    }

    /**
     * @dev Update risk management parameters
     */
    function updateRiskParameters(
        uint256 _maxDailyDrawdown,
        uint256 _maxPortfolioVolatility,
        uint256 _liquidityReserve,
        uint256 _stressTestFrequency
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(_maxDailyDrawdown <= 2000, "Drawdown limit too high"); // Max 20%
        require(_maxPortfolioVolatility <= 5000, "Volatility limit too high"); // Max 50%
        require(_liquidityReserve <= 3000, "Liquidity reserve too high"); // Max 30%
        require(_stressTestFrequency >= 7, "Test frequency too high"); // Min weekly

        riskParameters = RiskParameters({
            maxDailyDrawdown: _maxDailyDrawdown,
            maxPortfolioVolatility: _maxPortfolioVolatility,
            liquidityReserve: _liquidityReserve,
            stressTestFrequency: _stressTestFrequency
        });

        emit RiskParametersUpdated(riskParameters);
    }

    // ============================================================================
    // FUND MANAGEMENT FUNCTIONS
    // ============================================================================

    /**
     * @dev Execute fund rebalancing based on governance decision
     */
    function executeFundRebalancing(
        address[] memory assetTokens,
        uint256[] memory newAllocations
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(
            assetTokens.length == newAllocations.length,
            "Array length mismatch"
        );
        require(
            assetTokens.length <= portfolioConstraints.maxAssets,
            "Too many assets"
        );

        uint256 totalAllocation = 0;

        // Validate allocations
        for (uint256 i = 0; i < assetTokens.length; i++) {
            require(whitelistedAssets[assetTokens[i]], "Asset not whitelisted");
            require(
                newAllocations[i] >= portfolioConstraints.minAssetWeight,
                "Allocation too low"
            );
            require(
                newAllocations[i] <= portfolioConstraints.maxAssetWeight,
                "Allocation too high"
            );

            // Check asset-specific limits
            uint256 assetLimit = assetAllocationLimits[assetTokens[i]];
            if (assetLimit > 0) {
                require(newAllocations[i] <= assetLimit, "Exceeds asset limit");
            }

            totalAllocation += newAllocations[i];

            // Update allocation in URIP token contract
            uripToken.setAssetAllocation(assetTokens[i], newAllocations[i]);
        }

        require(totalAllocation <= 10000, "Total allocation exceeds 100%");
    }

    /**
     * @dev Execute emergency pause of the system
     */
    function executeEmergencyPause() external onlyRole(GOVERNANCE_ROLE) {
        governanceParams.emergencyPaused = true;

        // Pause all contracts
        uripToken.pause();
        purchaseManager.pause();

        emit EmergencyActionExecuted("EMERGENCY_PAUSE", address(0));
    }

    /**
     * @dev Execute emergency unpause of the system
     */
    function executeEmergencyUnpause() external onlyRole(GOVERNANCE_ROLE) {
        governanceParams.emergencyPaused = false;

        // Unpause all contracts
        uripToken.unpause();
        purchaseManager.unpause();

        emit EmergencyActionExecuted("EMERGENCY_UNPAUSE", address(0));
    }

    /**
     * @dev Emergency withdrawal of funds to treasury
     */
    function executeEmergencyWithdrawal(
        address token,
        uint256 amount,
        address treasury
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(treasury != address(0), "Invalid treasury address");

        // Execute withdrawal from purchase manager
        purchaseManager.emergencyWithdraw(token, amount);

        // Transfer to treasury
        IERC20(token).transfer(treasury, amount);

        emit EmergencyActionExecuted("EMERGENCY_WITHDRAWAL", token);
    }

    // ============================================================================
    // PROPOSAL CREATION HELPERS
    // ============================================================================

    /**
     * @dev Create a proposal for updating management fees
     */
    function createFeeUpdateProposal(
        string memory title,
        string memory description,
        uint256 newManagementFee,
        uint256 newPerformanceFee
    ) external returns (uint256) {
        string[] memory actionDescriptions = new string[](1);
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        actionDescriptions[0] = string(
            abi.encodePacked(
                "Update management fee to ",
                _toString(newManagementFee),
                " basis points and performance fee to ",
                _toString(newPerformanceFee),
                " basis points"
            )
        );
        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "updateGovernanceParams(uint256,uint256,uint256,uint256)",
            newManagementFee,
            newPerformanceFee,
            governanceParams.maxAssetAllocation,
            governanceParams.rebalanceThreshold
        );

        return
            governance.createProposal(
                title,
                description,
                actionDescriptions,
                targets,
                values,
                calldatas,
                IURIPDAOGovernance.ProposalCategory.PROTOCOL_GOVERNANCE
            );
    }

    /**
     * @dev Create a proposal for asset whitelist update
     */
    function createAssetWhitelistProposal(
        string memory title,
        string memory description,
        address[] memory assets,
        bool[] memory whitelisted
    ) external returns (uint256) {
        string[] memory actionDescriptions = new string[](1);
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        actionDescriptions[0] = "Update asset whitelist for multiple assets";
        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "setAssetWhitelist(address[],bool[])",
            assets,
            whitelisted
        );

        return
            governance.createProposal(
                title,
                description,
                actionDescriptions,
                targets,
                values,
                calldatas,
                IURIPDAOGovernance.ProposalCategory.FUND_MANAGEMENT
            );
    }

    /**
     * @dev Create a proposal for emergency pause
     */
    function createEmergencyPauseProposal(
        string memory title,
        string memory description
    ) external returns (uint256) {
        string[] memory actionDescriptions = new string[](1);
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        actionDescriptions[
            0
        ] = "Execute emergency pause of all system operations";
        targets[0] = address(this);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("executeEmergencyPause()");

        return
            governance.createProposal(
                title,
                description,
                actionDescriptions,
                targets,
                values,
                calldatas,
                IURIPDAOGovernance.ProposalCategory.EMERGENCY_ACTION
            );
    }

    // ============================================================================
    // VIEW FUNCTIONS
    // ============================================================================

    /**
     * @dev Check if rebalancing is needed based on current allocations
     */
    function isRebalancingNeeded() external view returns (bool, string memory) {
        // This would integrate with price oracles and current allocations
        // For now, return a simple check
        return (false, "No rebalancing needed");
    }

    /**
     * @dev Get current portfolio risk metrics
     */
    function getPortfolioRiskMetrics()
        external
        view
        returns (
            uint256 currentVolatility,
            uint256 dailyDrawdown,
            uint256 liquidityRatio,
            bool riskLimitsBreached
        )
    {
        // This would calculate real-time risk metrics
        // For now, return placeholder values
        return (1500, 200, 1200, false); // 15% volatility, 2% drawdown, 12% liquidity
    }

    /**
     * @dev Get governance parameters
     */
    function getGovernanceParams()
        external
        view
        returns (GovernanceParams memory)
    {
        return governanceParams;
    }

    /**
     * @dev Check if asset is eligible for trading
     */
    function isAssetEligible(address asset) external view returns (bool) {
        return whitelistedAssets[asset];
    }

    /**
     * @dev Get asset allocation limit
     */
    function getAssetAllocationLimit(
        address asset
    ) external view returns (uint256) {
        uint256 specificLimit = assetAllocationLimits[asset];
        return
            specificLimit > 0
                ? specificLimit
                : governanceParams.maxAssetAllocation;
    }

    // ============================================================================
    // UTILITY FUNCTIONS
    // ============================================================================

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
}

/**
 * @title URIPTreasuryManager
 * @dev Manages protocol treasury funds with governance oversight
 */
contract URIPTreasuryManager is AccessControl, ReentrancyGuard {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    IURIPDAOGovernance public immutable governance;

    // Treasury allocations
    mapping(address => uint256) public allocatedFunds; // token => amount
    mapping(address => uint256) public spentFunds; // token => spent amount

    // Budget categories
    enum BudgetCategory {
        DEVELOPMENT,
        MARKETING,
        OPERATIONS,
        PARTNERSHIPS,
        RESEARCH,
        EMERGENCY_RESERVE
    }

    struct BudgetAllocation {
        uint256 amount;
        uint256 spent;
        uint256 period; // Budget period in seconds
        uint256 lastReset; // Last budget reset timestamp
        bool active;
    }

    mapping(BudgetCategory => mapping(address => BudgetAllocation))
        public budgets;

    // Events
    event FundsAllocated(
        address indexed token,
        uint256 amount,
        BudgetCategory category
    );
    event FundsSpent(
        address indexed token,
        uint256 amount,
        BudgetCategory category,
        string purpose
    );
    event BudgetUpdated(
        BudgetCategory category,
        address token,
        uint256 newAmount
    );
    event EmergencyWithdrawal(
        address indexed token,
        uint256 amount,
        address recipient
    );

    constructor(address _governance) {
        governance = IURIPDAOGovernance(_governance);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNANCE_ROLE, _governance);
        _grantRole(TREASURER_ROLE, msg.sender);
    }

    /**
     * @dev Allocate funds to budget categories (governance only)
     */
    function allocateBudget(
        BudgetCategory category,
        address token,
        uint256 amount,
        uint256 period
    ) external onlyRole(GOVERNANCE_ROLE) {
        require(amount > 0, "Invalid amount");
        require(period >= 30 days, "Period too short");

        budgets[category][token] = BudgetAllocation({
            amount: amount,
            spent: 0,
            period: period,
            lastReset: block.timestamp,
            active: true
        });

        emit BudgetUpdated(category, token, amount);
    }

    /**
     * @dev Spend from allocated budget
     */
    function spendFromBudget(
        BudgetCategory category,
        address token,
        uint256 amount,
        string memory purpose,
        address recipient
    ) external onlyRole(TREASURER_ROLE) nonReentrant {
        BudgetAllocation storage budget = budgets[category][token];
        require(budget.active, "Budget not active");

        // Check if budget period has expired and reset if needed
        if (block.timestamp >= budget.lastReset + budget.period) {
            budget.spent = 0;
            budget.lastReset = block.timestamp;
        }

        require(budget.spent + amount <= budget.amount, "Insufficient budget");
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );

        budget.spent += amount;
        spentFunds[token] += amount;

        IERC20(token).transfer(recipient, amount);

        emit FundsSpent(token, amount, category, purpose);
    }

    /**
     * @dev Emergency withdrawal (governance only)
     */
    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyRole(GOVERNANCE_ROLE) nonReentrant {
        require(recipient != address(0), "Invalid recipient");
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );

        IERC20(token).transfer(recipient, amount);

        emit EmergencyWithdrawal(token, amount, recipient);
    }

    /**
     * @dev Get remaining budget for category
     */
    function getRemainingBudget(
        BudgetCategory category,
        address token
    ) external view returns (uint256) {
        BudgetAllocation memory budget = budgets[category][token];
        if (!budget.active) return 0;

        // Check if budget period has expired
        if (block.timestamp >= budget.lastReset + budget.period) {
            return budget.amount; // Budget resets
        }

        return budget.amount > budget.spent ? budget.amount - budget.spent : 0;
    }

    /**
     * @dev Get treasury balance
     */
    function getTreasuryBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
