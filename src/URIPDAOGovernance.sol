// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title IURIPDAOGovernance
 * @dev Interface for URIP DAO Governance
 */
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

    function castVote(
        uint256 proposalId,
        uint8 support,
        string memory reason
    ) external;

    function getVotingPower(address account) external view returns (uint256);
}

/**
 * @title URIPDAOGovernance
 * @dev Comprehensive DAO governance system for URIP platform
 * Handles fund management decisions, protocol governance, and treasury management
 */
contract URIPDAOGovernance is
    IURIPDAOGovernance,
    AccessControl,
    ReentrancyGuard,
    Pausable
{
    // ============================================================================
    // CONSTANTS & ROLES
    // ============================================================================

    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    uint256 public constant BASIS_POINTS = 10000;

    enum ProposalStatus {
        PENDING,
        ACTIVE,
        SUCCEEDED,
        DEFEATED,
        EXECUTED,
        CANCELLED,
        EXPIRED
    }

    // ============================================================================
    // STRUCTS
    // ============================================================================

    struct ProposalConfig {
        uint256 quorumPercentage; // Required quorum (basis points)
        uint256 approvalThreshold; // Required approval percentage (basis points)
        uint256 votingPeriod; // Voting duration in seconds
        uint256 executionDelay; // Delay before execution (timelock)
        uint256 proposalThreshold; // Min tokens to create proposal
    }

    struct Proposal {
        uint256 id;
        string title;
        string description;
        string[] actionDescriptions; // Human-readable action descriptions
        address[] targets; // Target contracts for execution
        uint256[] values; // ETH values for each call
        bytes[] calldatas; // Function call data
        ProposalCategory category;
        ProposalStatus status;
        address proposer;
        uint256 startTime;
        uint256 endTime;
        uint256 executionTime; // When proposal can be executed
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) votes; // 0=against, 1=for, 2=abstain
    }

    struct VotingPower {
        uint256 delegatedFrom; // Total delegated to this address
        address delegatedTo; // Who this voter delegated to
    }

    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    IERC20 public immutable governanceToken; // URIP token

    mapping(ProposalCategory => ProposalConfig) public proposalConfigs;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => VotingPower) public votingPowers;

    uint256 public proposalCount;

    // Advisory board
    mapping(address => bool) public advisoryBoard;
    uint256 public advisoryBoardSize;

    // Treasury management
    address public treasuryAddress;
    mapping(address => bool) public authorizedExecutors;

    // ============================================================================
    // EVENTS
    // ============================================================================

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalCategory category,
        string title
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 support,
        uint256 weight,
        string reason
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    event VotingPowerDelegated(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount
    );

    event AdvisoryBoardUpdated(address indexed member, bool added);
    event ProposalConfigUpdated(ProposalCategory category);

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    constructor(address _governanceToken, address _treasury) {
        governanceToken = IERC20(_governanceToken);
        treasuryAddress = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TIMELOCK_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);

        // Initialize default proposal configurations
        _initializeProposalConfigs();
    }

    // ============================================================================
    // PROPOSAL CONFIGURATION
    // ============================================================================

    function _initializeProposalConfigs() internal {
        // Fund Management Proposals
        proposalConfigs[ProposalCategory.FUND_MANAGEMENT] = ProposalConfig({
            quorumPercentage: 1000, // 10%
            approvalThreshold: 5100, // 51%
            votingPeriod: 7 days,
            executionDelay: 2 days,
            proposalThreshold: 10000 * 1e18 // 10k URIP tokens
        });

        // Protocol Governance Proposals
        proposalConfigs[ProposalCategory.PROTOCOL_GOVERNANCE] = ProposalConfig({
            quorumPercentage: 1500, // 15%
            approvalThreshold: 6000, // 60%
            votingPeriod: 10 days,
            executionDelay: 5 days,
            proposalThreshold: 50000 * 1e18 // 50k URIP tokens
        });

        // Treasury Management Proposals
        proposalConfigs[ProposalCategory.TREASURY_MANAGEMENT] = ProposalConfig({
            quorumPercentage: 2000, // 20%
            approvalThreshold: 6600, // 66%
            votingPeriod: 14 days,
            executionDelay: 7 days,
            proposalThreshold: 100000 * 1e18 // 100k URIP tokens
        });

        // Emergency Action Proposals
        proposalConfigs[ProposalCategory.EMERGENCY_ACTION] = ProposalConfig({
            quorumPercentage: 2500, // 25%
            approvalThreshold: 7500, // 75%
            votingPeriod: 3 days,
            executionDelay: 1 days,
            proposalThreshold: 250000 * 1e18 // 250k URIP tokens
        });
    }

    // ============================================================================
    // PROPOSAL CREATION
    // ============================================================================

    function createProposal(
        string memory title,
        string memory description,
        string[] memory actionDescriptions,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        ProposalCategory category
    ) external override returns (uint256) {
        require(targets.length == values.length, "Array length mismatch");
        require(targets.length == calldatas.length, "Array length mismatch");
        require(
            targets.length == actionDescriptions.length,
            "Array length mismatch"
        );
        require(targets.length > 0, "Empty proposal");

        ProposalConfig memory config = proposalConfigs[category];
        uint256 voterPower = getVotingPower(msg.sender);

        require(
            voterPower >= config.proposalThreshold,
            "Insufficient voting power"
        );

        proposalCount++;
        uint256 proposalId = proposalCount;

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.actionDescriptions = actionDescriptions;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.calldatas = calldatas;
        newProposal.category = category;
        newProposal.status = ProposalStatus.ACTIVE;
        newProposal.proposer = msg.sender;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + config.votingPeriod;
        newProposal.executionTime = newProposal.endTime + config.executionDelay;

        emit ProposalCreated(proposalId, msg.sender, category, title);

        return proposalId;
    }

    // ============================================================================
    // FUND MANAGEMENT INTEGRATION
    // ============================================================================

    /**
     * @dev Create proposal for fund rebalancing
     * This integrates with the URIP fund management system
     */
    function createFundRebalancingProposal(
        string memory title,
        string memory description,
        address[] memory assetTokens,
        uint256[] memory newAllocations,
        address uripFundContract
    ) external returns (uint256) {
        require(
            assetTokens.length == newAllocations.length,
            "Array length mismatch"
        );

        string[] memory actionDescriptions = new string[](assetTokens.length);
        address[] memory targets = new address[](assetTokens.length);
        uint256[] memory values = new uint256[](assetTokens.length);
        bytes[] memory calldatas = new bytes[](assetTokens.length);

        for (uint256 i = 0; i < assetTokens.length; i++) {
            actionDescriptions[i] = string(
                abi.encodePacked(
                    "Set allocation for asset to ",
                    _toString(newAllocations[i]),
                    " basis points"
                )
            );
            targets[i] = uripFundContract;
            values[i] = 0;
            calldatas[i] = abi.encodeWithSignature(
                "setAssetAllocation(address,uint256)",
                assetTokens[i],
                newAllocations[i]
            );
        }

        return
            this.createProposal(
                title,
                description,
                actionDescriptions,
                targets,
                values,
                calldatas,
                ProposalCategory.FUND_MANAGEMENT
            );
    }

    // ============================================================================
    // VOTING
    // ============================================================================

    function castVote(
        uint256 proposalId,
        uint8 support,
        string memory reason
    ) external override whenNotPaused {
        require(support <= 2, "Invalid vote type");

        Proposal storage proposal = proposals[proposalId];
        require(
            proposal.status == ProposalStatus.ACTIVE,
            "Proposal not active"
        );
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        address voter = msg.sender;
        uint256 weight = getVotingPower(voter);
        require(weight > 0, "No voting power");

        proposal.hasVoted[voter] = true;
        proposal.votes[voter] = support;

        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(proposalId, voter, support, weight, reason);

        // Check if proposal can be finalized early
        _checkEarlyFinalization(proposalId);
    }

    // ============================================================================
    // PROPOSAL EXECUTION
    // ============================================================================

    function executeProposal(uint256 proposalId) external payable nonReentrant {
        Proposal storage proposal = proposals[proposalId];

        require(
            proposal.status == ProposalStatus.SUCCEEDED,
            "Proposal not succeeded"
        );
        require(
            block.timestamp >= proposal.executionTime,
            "Execution delay not met"
        );
        require(
            hasRole(TIMELOCK_ROLE, msg.sender) ||
                authorizedExecutors[msg.sender],
            "Not authorized to execute"
        );

        proposal.status = ProposalStatus.EXECUTED;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{
                value: proposal.values[i]
            }(proposal.calldatas[i]);
            require(success, "Execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    function _checkEarlyFinalization(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        ProposalConfig memory config = proposalConfigs[proposal.category];

        uint256 totalVotes = proposal.forVotes +
            proposal.againstVotes +
            proposal.abstainVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        uint256 quorumRequired = (totalSupply * config.quorumPercentage) /
            BASIS_POINTS;

        if (totalVotes >= quorumRequired) {
            if (block.timestamp >= proposal.endTime) {
                _finalizeProposal(proposalId);
            }
        }
    }

    function finalizeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(
            proposal.status == ProposalStatus.ACTIVE,
            "Proposal not active"
        );
        require(block.timestamp >= proposal.endTime, "Voting period not ended");

        _finalizeProposal(proposalId);
    }

    function _finalizeProposal(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        ProposalConfig memory config = proposalConfigs[proposal.category];

        uint256 totalVotes = proposal.forVotes +
            proposal.againstVotes +
            proposal.abstainVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        uint256 quorumRequired = (totalSupply * config.quorumPercentage) /
            BASIS_POINTS;

        if (totalVotes >= quorumRequired) {
            uint256 approvalRequired = (totalVotes * config.approvalThreshold) /
                BASIS_POINTS;
            proposal.status = proposal.forVotes >= approvalRequired
                ? ProposalStatus.SUCCEEDED
                : ProposalStatus.DEFEATED;
        } else {
            proposal.status = ProposalStatus.DEFEATED;
        }
    }

    // ============================================================================
    // VOTING POWER MANAGEMENT
    // ============================================================================

    function getVotingPower(
        address account
    ) public view override returns (uint256) {
        uint256 balance = governanceToken.balanceOf(account);
        uint256 delegated = votingPowers[account].delegatedFrom;

        // If user has delegated their power, they can't vote with their own balance
        if (votingPowers[account].delegatedTo != address(0)) {
            return delegated;
        }

        return balance + delegated;
    }

    function delegate(address delegatee) external {
        address currentDelegate = votingPowers[msg.sender].delegatedTo;
        uint256 voterBalance = governanceToken.balanceOf(msg.sender);

        // Remove previous delegation
        if (currentDelegate != address(0)) {
            votingPowers[currentDelegate].delegatedFrom -= voterBalance;
        }

        // Add new delegation
        if (delegatee != address(0)) {
            votingPowers[delegatee].delegatedFrom += voterBalance;
        }

        votingPowers[msg.sender].delegatedTo = delegatee;

        emit VotingPowerDelegated(msg.sender, delegatee, voterBalance);
    }

    // ============================================================================
    // EMERGENCY FUNCTIONS
    // ============================================================================

    function emergencyCancelProposal(
        uint256 proposalId
    ) external onlyRole(EMERGENCY_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(
            proposal.status == ProposalStatus.ACTIVE ||
                proposal.status == ProposalStatus.SUCCEEDED,
            "Cannot cancel proposal"
        );

        proposal.status = ProposalStatus.CANCELLED;
        emit ProposalCancelled(proposalId);
    }

    function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    function emergencyUnpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }

    // ============================================================================
    // VIEW FUNCTIONS
    // ============================================================================

    function getProposalState(
        uint256 proposalId
    ) external view returns (ProposalStatus) {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.status != ProposalStatus.ACTIVE) {
            return proposal.status;
        }

        if (block.timestamp > proposal.endTime + 30 days) {
            return ProposalStatus.EXPIRED;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalStatus.ACTIVE;
        }

        // Proposal has ended, check if it succeeded
        ProposalConfig memory config = proposalConfigs[proposal.category];
        uint256 totalVotes = proposal.forVotes +
            proposal.againstVotes +
            proposal.abstainVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        uint256 quorumRequired = (totalSupply * config.quorumPercentage) /
            BASIS_POINTS;

        if (totalVotes >= quorumRequired) {
            uint256 approvalRequired = (totalVotes * config.approvalThreshold) /
                BASIS_POINTS;
            return
                proposal.forVotes >= approvalRequired
                    ? ProposalStatus.SUCCEEDED
                    : ProposalStatus.DEFEATED;
        }

        return ProposalStatus.DEFEATED;
    }

    function hasVoted(
        uint256 proposalId,
        address account
    ) external view returns (bool) {
        return proposals[proposalId].hasVoted[account];
    }

    function getVote(
        uint256 proposalId,
        address account
    ) external view returns (uint8) {
        require(
            proposals[proposalId].hasVoted[account],
            "Account has not voted"
        );
        return proposals[proposalId].votes[account];
    }

    // ============================================================================
    // ADMIN FUNCTIONS
    // ============================================================================

    function updateProposalConfig(
        ProposalCategory category,
        uint256 quorumPercentage,
        uint256 approvalThreshold,
        uint256 votingPeriod,
        uint256 executionDelay,
        uint256 proposalThreshold
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(quorumPercentage <= BASIS_POINTS, "Invalid quorum");
        require(approvalThreshold <= BASIS_POINTS, "Invalid threshold");

        proposalConfigs[category] = ProposalConfig({
            quorumPercentage: quorumPercentage,
            approvalThreshold: approvalThreshold,
            votingPeriod: votingPeriod,
            executionDelay: executionDelay,
            proposalThreshold: proposalThreshold
        });

        emit ProposalConfigUpdated(category);
    }

    function setAuthorizedExecutor(
        address executor,
        bool authorized
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        authorizedExecutors[executor] = authorized;
    }

    function updateTreasuryAddress(
        address newTreasury
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newTreasury != address(0), "Invalid treasury address");
        treasuryAddress = newTreasury;
    }

    function addAdvisoryBoardMember(
        address member
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!advisoryBoard[member], "Already advisory board member");
        advisoryBoard[member] = true;
        advisoryBoardSize++;
        emit AdvisoryBoardUpdated(member, true);
    }

    function removeAdvisoryBoardMember(
        address member
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(advisoryBoard[member], "Not advisory board member");
        advisoryBoard[member] = false;
        advisoryBoardSize--;
        emit AdvisoryBoardUpdated(member, false);
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
 * @title URIPGovernanceHelper
 * @dev Helper contract for common governance operations
 */
contract URIPGovernanceHelper {
    URIPDAOGovernance public immutable governance;

    constructor(address _governance) {
        governance = URIPDAOGovernance(_governance);
    }

    /**
     * @dev Get all active proposals
     */
    function getActiveProposals() external view returns (uint256[] memory) {
        uint256 proposalCount = governance.proposalCount();
        uint256[] memory activeProposals = new uint256[](proposalCount);
        uint256 activeCount = 0;

        for (uint256 i = 1; i <= proposalCount; i++) {
            if (
                governance.getProposalState(i) ==
                URIPDAOGovernance.ProposalStatus.ACTIVE
            ) {
                activeProposals[activeCount] = i;
                activeCount++;
            }
        }

        // Resize array to actual size
        uint256[] memory result = new uint256[](activeCount);
        for (uint256 i = 0; i < activeCount; i++) {
            result[i] = activeProposals[i];
        }

        return result;
    }

    /**
     * @dev Batch vote on multiple proposals
     */
    function batchVote(
        uint256[] memory proposalIds,
        uint8[] memory support,
        string[] memory reasons
    ) external {
        require(proposalIds.length == support.length, "Array length mismatch");
        require(proposalIds.length == reasons.length, "Array length mismatch");

        for (uint256 i = 0; i < proposalIds.length; i++) {
            governance.castVote(proposalIds[i], support[i], reasons[i]);
        }
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

    event FundsAllocated(
        address indexed token,
        uint256 amount,
        BudgetCategory category
    );
    event FundsSpent(
        address indexed token,
        uint256 amount,
        BudgetCategory category
    );
    event BudgetReset(BudgetCategory category, address indexed token);

    constructor(address _governance) {
        governance = IURIPDAOGovernance(_governance);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TREASURER_ROLE, msg.sender);
    }

    function allocateFunds(
        address token,
        uint256 amount,
        BudgetCategory category
    ) external onlyRole(GOVERNANCE_ROLE) {
        allocatedFunds[token] += amount;

        BudgetAllocation storage budget = budgets[category][token];
        budget.amount += amount;
        budget.active = true;

        if (budget.lastReset == 0) {
            budget.lastReset = block.timestamp;
            budget.period = 30 days; // Default 30-day budget period
        }

        emit FundsAllocated(token, amount, category);
    }

    function spendFunds(
        address token,
        uint256 amount,
        BudgetCategory category,
        address recipient
    ) external onlyRole(TREASURER_ROLE) nonReentrant {
        BudgetAllocation storage budget = budgets[category][token];
        require(budget.active, "Budget not active");
        require(budget.amount >= budget.spent + amount, "Insufficient budget");

        budget.spent += amount;
        spentFunds[token] += amount;

        // Transfer funds (assumes ERC20 token)
        IERC20(token).transfer(recipient, amount);

        emit FundsSpent(token, amount, category);
    }

    function resetBudget(
        BudgetCategory category,
        address token
    ) external onlyRole(GOVERNANCE_ROLE) {
        BudgetAllocation storage budget = budgets[category][token];
        budget.spent = 0;
        budget.lastReset = block.timestamp;

        emit BudgetReset(category, token);
    }
}
