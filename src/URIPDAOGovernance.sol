// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// Interface for URIP Token
interface IURIPToken {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function setAssetAllocation(
        address assetToken,
        uint256 allocationBasisPoints
    ) external;
    function getAllAssetAllocations()
        external
        view
        returns (address[] memory assets, uint256[] memory allocations);
    function getAssetCount() external view returns (uint256);
    function getUnderlyingAsset(uint256 index) external view returns (address);
}

/**
 * @title URIPDAOGovernance
 * @dev DAO governance system for URIP fund asset allocation decisions
 *
 * PURPOSE:
 * - Allow URIP token holders to vote on fund rebalancing proposals
 * - Democratic decision-making for asset allocation changes
 * - Simple majority voting with URIP token-based voting power
 * - Ensure community control over fund composition
 *
 * KEY FEATURES:
 * 1. Rebalancing Proposals: Propose new asset allocation percentages
 * 2. Simple Majority Voting: 51% of participating votes needed to pass
 * 3. URIP-based Voting Power: 1 URIP token = 1 vote
 * 4. Proposal Lifecycle: Create → Vote → Execute → Complete
 * 5. Timelock Security: Delay between approval and execution
 *
 * FLOW OVERVIEW:
 * 1. URIP holder creates rebalancing proposal
 * 2. Community votes for 7 days
 * 3. If majority approves, 2-day timelock begins
 * 4. After timelock, anyone can execute the rebalancing
 * 5. New allocations are applied to URIP fund
 */
contract URIPDAOGovernance is AccessControl, ReentrancyGuard, Pausable {
    // ============================================================================
    // ROLES & CONSTANTS
    // ============================================================================

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // ============================================================================
    // ENUMS & STRUCTS
    // ============================================================================

    enum ProposalStatus {
        Active, // Currently accepting votes
        Succeeded, // Passed, waiting for timelock
        Defeated, // Failed to reach majority
        Executed, // Successfully executed
        Cancelled // Cancelled by emergency role
    }

    struct RebalancingProposal {
        uint256 id; // Proposal ID
        string title; // Proposal title
        string description; // Detailed description
        address proposer; // Who created the proposal
        uint256 startTime; // When voting started
        uint256 endTime; // When voting ends
        uint256 executionTime; // When execution is allowed (after timelock)
        // Proposed allocations
        address[] assetTokens; // Asset token addresses
        uint256[] newAllocations; // New allocation percentages (basis points)
        // Voting data
        uint256 forVotes; // Votes in favor
        uint256 againstVotes; // Votes against
        uint256 totalVotingPower; // Total voting power when proposal was created
        // Status
        ProposalStatus status; // Current status
        // Voting tracking
        mapping(address => bool) hasVoted; // Track who has voted
        mapping(address => bool) voteChoice; // Track vote choices (true = for, false = against)
    }

    struct GovernanceSettings {
        uint256 proposalThreshold; // Minimum URIP tokens needed to create proposal
        uint256 votingPeriod; // Voting duration in seconds (7 days)
        uint256 timelockPeriod; // Delay before execution (2 days)
        uint256 quorumPercentage; // Minimum participation (basis points)
        bool requireQuorum; // Whether quorum is required
    }

    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    IURIPToken public immutable uripToken;

    GovernanceSettings public settings;

    mapping(uint256 => RebalancingProposal) public proposals;
    uint256 public proposalCount;

    // Voting delegation (optional feature)
    mapping(address => address) public delegates;
    mapping(address => uint256) public delegatedVotes;

    // ============================================================================
    // EVENTS
    // ============================================================================

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        address[] assetTokens,
        uint256[] newAllocations
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votingPower,
        string reason
    );

    event ProposalStatusChanged(
        uint256 indexed proposalId,
        ProposalStatus oldStatus,
        ProposalStatus newStatus
    );

    event ProposalExecuted(
        uint256 indexed proposalId,
        address indexed executor
    );

    event VoteDelegated(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount
    );

    event GovernanceSettingsUpdated(GovernanceSettings settings);

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    /**
     * @dev Initialize DAO governance with URIP token
     * @param _uripToken Address of URIP token contract
     *
     * PURPOSE: Set up governance system with sensible defaults
     * FLOW: Deploy → Set URIP token → Configure default settings → Ready for proposals
     */
    constructor(address _uripToken) {
        require(_uripToken != address(0), "Invalid URIP token address");

        uripToken = IURIPToken(_uripToken);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);

        // Set default governance settings
        settings = GovernanceSettings({
            proposalThreshold: 1000 * 1e18, // 1,000 URIP tokens to propose
            votingPeriod: 7 days, // 7 days to vote
            timelockPeriod: 2 days, // 2 days before execution
            quorumPercentage: 1000, // 10% participation required
            requireQuorum: true // Quorum is required
        });
    }

    // ============================================================================
    // PROPOSAL CREATION
    // ============================================================================

    /**
     * @dev Create a new rebalancing proposal
     * @param title Short title for the proposal
     * @param description Detailed explanation of the rebalancing
     * @param assetTokens Array of asset token addresses
     * @param newAllocations Array of new allocation percentages (basis points)
     * @return proposalId The ID of the created proposal
     *
     * PURPOSE: Allow URIP holders to propose fund rebalancing
     * CALLED BY: URIP token holders with sufficient tokens
     * FLOW:
     * 1. Check proposer has enough URIP tokens
     * 2. Validate proposed allocations sum to 100%
     * 3. Create proposal with voting period
     * 4. Community can now vote on the proposal
     *
     * EXAMPLE: Rebalance from 50/50 AAPL/NVDA to 60/40
     * - title: "Increase Apple allocation to 60%"
     * - assetTokens: [aaplToken, nvdaToken]
     * - newAllocations: [6000, 4000] (60%, 40%)
     */
    function createRebalancingProposal(
        string memory title,
        string memory description,
        address[] memory assetTokens,
        uint256[] memory newAllocations
    ) external whenNotPaused returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(assetTokens.length > 0, "Must specify at least one asset");
        require(
            assetTokens.length == newAllocations.length,
            "Array length mismatch"
        );

        // Check proposer has enough URIP tokens
        uint256 proposerBalance = uripToken.balanceOf(msg.sender);
        require(
            proposerBalance >= settings.proposalThreshold,
            "Insufficient URIP tokens to propose"
        );

        // Validate allocations
        _validateAllocations(assetTokens, newAllocations);

        // Create new proposal
        proposalCount++;
        uint256 proposalId = proposalCount;

        RebalancingProposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.title = title;
        proposal.description = description;
        proposal.proposer = msg.sender;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + settings.votingPeriod;
        proposal.executionTime = proposal.endTime + settings.timelockPeriod;
        proposal.assetTokens = assetTokens;
        proposal.newAllocations = newAllocations;
        proposal.status = ProposalStatus.Active;
        proposal.totalVotingPower = uripToken.totalSupply();

        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            assetTokens,
            newAllocations
        );

        return proposalId;
    }

    /**
     * @dev Validate that proposed allocations are valid
     * @param assetTokens Array of asset token addresses
     * @param allocations Array of allocation percentages
     */
    function _validateAllocations(
        address[] memory assetTokens,
        uint256[] memory allocations
    ) internal pure {
        uint256 totalAllocation = 0;

        // Check each allocation is valid
        for (uint256 i = 0; i < allocations.length; i++) {
            require(
                assetTokens[i] != address(0),
                "Invalid asset token address"
            );
            require(allocations[i] <= 10000, "Allocation cannot exceed 100%");
            totalAllocation += allocations[i];
        }

        // Total must equal 100% (10000 basis points)
        require(totalAllocation == 10000, "Total allocation must equal 100%");

        // Check for duplicate assets
        for (uint256 i = 0; i < assetTokens.length; i++) {
            for (uint256 j = i + 1; j < assetTokens.length; j++) {
                require(
                    assetTokens[i] != assetTokens[j],
                    "Duplicate asset token"
                );
            }
        }
    }

    // ============================================================================
    // VOTING SYSTEM
    // ============================================================================

    /**
     * @dev Cast a vote on a proposal
     * @param proposalId ID of the proposal to vote on
     * @param support True to vote for, false to vote against
     * @param reason Optional reason for the vote
     *
     * PURPOSE: Allow URIP holders to vote on rebalancing proposals
     * CALLED BY: URIP token holders during voting period
     * FLOW:
     * 1. Check proposal is active and in voting period
     * 2. Check voter hasn't already voted
     * 3. Calculate voting power (URIP balance + delegated votes)
     * 4. Record vote and update vote counts
     * 5. Check if proposal should be finalized
     *
     * EXAMPLE: Vote on rebalancing proposal
     * - User has 5,000 URIP tokens = 5,000 voting power
     * - Votes "for" the rebalancing proposal
     * - Vote is recorded and counted toward majority
     */
    function castVote(
        uint256 proposalId,
        bool support,
        string memory reason
    ) external whenNotPaused {
        require(proposalId <= proposalCount, "Invalid proposal ID");

        RebalancingProposal storage proposal = proposals[proposalId];
        require(
            proposal.status == ProposalStatus.Active,
            "Proposal not active"
        );
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        // Calculate voting power (own tokens + delegated votes)
        uint256 votingPower = _getVotingPower(msg.sender);
        require(votingPower > 0, "No voting power");

        // Record vote
        proposal.hasVoted[msg.sender] = true;
        proposal.voteChoice[msg.sender] = support;

        if (support) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }

        emit VoteCast(proposalId, msg.sender, support, votingPower, reason);

        // Check if proposal should be finalized early (if total supply has voted)
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        if (totalVotes >= proposal.totalVotingPower) {
            _finalizeProposal(proposalId);
        }
    }

    /**
     * @dev Get voting power for an address (own balance + delegated votes)
     * @param account Address to check voting power for
     * @return votingPower Total voting power amount for the address
     */
    function _getVotingPower(address account) internal view returns (uint256) {
        uint256 balance = uripToken.balanceOf(account);
        uint256 delegated = delegatedVotes[account];
        return balance + delegated;
    }

    /**
     * @dev Finalize a proposal after voting period ends
     * @param proposalId ID of the proposal to finalize
     *
     * PURPOSE: Determine if proposal passed or failed
     * CALLED BY: Anyone after voting period ends, or automatically
     * FLOW:
     * 1. Check if voting period has ended
     * 2. Calculate vote percentages
     * 3. Check if quorum was met (if required)
     * 4. Determine if majority voted for
     * 5. Set status to Succeeded or Defeated
     */
    function finalizeProposal(uint256 proposalId) external {
        require(proposalId <= proposalCount, "Invalid proposal ID");

        RebalancingProposal storage proposal = proposals[proposalId];
        require(
            proposal.status == ProposalStatus.Active,
            "Proposal not active"
        );
        require(block.timestamp > proposal.endTime, "Voting period not ended");

        _finalizeProposal(proposalId);
    }

    /**
     * @dev Internal function to finalize proposal
     */
    function _finalizeProposal(uint256 proposalId) internal {
        RebalancingProposal storage proposal = proposals[proposalId];

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        ProposalStatus oldStatus = proposal.status;

        // Check quorum if required
        if (settings.requireQuorum) {
            uint256 requiredQuorum = (proposal.totalVotingPower *
                settings.quorumPercentage) / 10000;
            if (totalVotes < requiredQuorum) {
                proposal.status = ProposalStatus.Defeated;
                emit ProposalStatusChanged(
                    proposalId,
                    oldStatus,
                    ProposalStatus.Defeated
                );
                return;
            }
        }

        // Check if majority voted for
        if (proposal.forVotes > proposal.againstVotes) {
            proposal.status = ProposalStatus.Succeeded;
            emit ProposalStatusChanged(
                proposalId,
                oldStatus,
                ProposalStatus.Succeeded
            );
        } else {
            proposal.status = ProposalStatus.Defeated;
            emit ProposalStatusChanged(
                proposalId,
                oldStatus,
                ProposalStatus.Defeated
            );
        }
    }

    // ============================================================================
    // PROPOSAL EXECUTION
    // ============================================================================

    /**
     * @dev Execute a successful proposal after timelock period
     * @param proposalId ID of the proposal to execute
     *
     * PURPOSE: Apply approved rebalancing to the URIP fund
     * CALLED BY: Anyone after timelock period ends
     * FLOW:
     * 1. Check proposal succeeded and timelock period passed
     * 2. Apply new asset allocations to URIP fund
     * 3. Mark proposal as executed
     * 4. Fund is now rebalanced according to community vote
     *
     * EXAMPLE: Execute approved 60/40 AAPL/NVDA rebalancing
     * - Proposal passed with 65% support
     * - Timelock period (2 days) has passed
     * - Execute → URIP fund now has 60% AAPL, 40% NVDA
     */
    function executeProposal(uint256 proposalId) external nonReentrant {
        require(proposalId <= proposalCount, "Invalid proposal ID");

        RebalancingProposal storage proposal = proposals[proposalId];
        require(
            proposal.status == ProposalStatus.Succeeded,
            "Proposal not succeeded"
        );
        require(
            block.timestamp >= proposal.executionTime,
            "Timelock period not ended"
        );

        // Apply new allocations to URIP fund
        for (uint256 i = 0; i < proposal.assetTokens.length; i++) {
            uripToken.setAssetAllocation(
                proposal.assetTokens[i],
                proposal.newAllocations[i]
            );
        }

        // Mark as executed
        ProposalStatus oldStatus = proposal.status;
        proposal.status = ProposalStatus.Executed;

        emit ProposalStatusChanged(
            proposalId,
            oldStatus,
            ProposalStatus.Executed
        );
        emit ProposalExecuted(proposalId, msg.sender);
    }

    // ============================================================================
    // VOTE DELEGATION (OPTIONAL FEATURE)
    // ============================================================================

    /**
     * @dev Delegate voting power to another address
     * @param delegatee Address to delegate votes to
     *
     * PURPOSE: Allow passive investors to delegate voting to active participants
     * CALLED BY: URIP holders who want others to vote on their behalf
     * FLOW: User delegates → Delegatee can vote with combined power → More participation
     */
    function delegate(address delegatee) external {
        require(delegatee != msg.sender, "Cannot delegate to self");
        require(delegatee != address(0), "Cannot delegate to zero address");

        address currentDelegate = delegates[msg.sender];
        uint256 delegatorBalance = uripToken.balanceOf(msg.sender);

        // Remove previous delegation
        if (currentDelegate != address(0)) {
            delegatedVotes[currentDelegate] -= delegatorBalance;
        }

        // Set new delegation
        delegates[msg.sender] = delegatee;
        delegatedVotes[delegatee] += delegatorBalance;

        emit VoteDelegated(msg.sender, delegatee, delegatorBalance);
    }

    /**
     * @dev Remove vote delegation
     *
     * PURPOSE: Allow users to take back their voting power
     */
    function removeDelegation() external {
        address currentDelegate = delegates[msg.sender];
        require(currentDelegate != address(0), "No delegation to remove");

        uint256 delegatorBalance = uripToken.balanceOf(msg.sender);
        delegatedVotes[currentDelegate] -= delegatorBalance;
        delegates[msg.sender] = address(0);

        emit VoteDelegated(msg.sender, address(0), 0);
    }

    // ============================================================================
    // VIEW FUNCTIONS
    // ============================================================================

    /**
     * @dev Get complete proposal information
     * @param proposalId ID of the proposal
     * @return id Proposal ID
     * @return title Proposal title
     * @return description Proposal description
     * @return proposer Address of proposal creator
     * @return startTime When voting started
     * @return endTime When voting ends
     * @return executionTime When execution is allowed
     * @return assetTokens Array of asset token addresses
     * @return newAllocations Array of proposed allocations
     * @return forVotes Number of votes in favor
     * @return againstVotes Number of votes against
     * @return totalVotingPower Total voting power when created
     * @return status Current proposal status
     */
    function getProposal(
        uint256 proposalId
    )
        external
        view
        returns (
            uint256 id,
            string memory title,
            string memory description,
            address proposer,
            uint256 startTime,
            uint256 endTime,
            uint256 executionTime,
            address[] memory assetTokens,
            uint256[] memory newAllocations,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 totalVotingPower,
            ProposalStatus status
        )
    {
        require(proposalId <= proposalCount, "Invalid proposal ID");
        RebalancingProposal storage proposal = proposals[proposalId];

        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.startTime,
            proposal.endTime,
            proposal.executionTime,
            proposal.assetTokens,
            proposal.newAllocations,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.totalVotingPower,
            proposal.status
        );
    }

    /**
     * @dev Check if an address has voted on a proposal
     * @param proposalId ID of the proposal
     * @param voter Address to check
     * @return hasVoted Whether the address has voted
     * @return voteChoice Their vote choice (if voted)
     */
    function getVoteStatus(
        uint256 proposalId,
        address voter
    ) external view returns (bool hasVoted, bool voteChoice) {
        require(proposalId <= proposalCount, "Invalid proposal ID");
        RebalancingProposal storage proposal = proposals[proposalId];

        return (proposal.hasVoted[voter], proposal.voteChoice[voter]);
    }

    /**
     * @dev Get voting power for an address
     * @param account Address to check
     * @return votingPower Current voting power
     */
    function getVotingPower(address account) external view returns (uint256) {
        return _getVotingPower(account);
    }

    /**
     * @dev Get current URIP fund allocations for comparison
     * @return assetTokens Current asset addresses in the fund
     * @return currentAllocations Current allocation percentages (basis points)
     */
    function getCurrentAllocations()
        external
        view
        returns (
            address[] memory assetTokens,
            uint256[] memory currentAllocations
        )
    {
        return uripToken.getAllAssetAllocations();
    }

    /**
     * @dev Get all active proposals
     * @return activeProposalIds Array of proposal IDs that are currently active for voting
     */
    function getActiveProposals() external view returns (uint256[] memory) {
        uint256[] memory activeProposals = new uint256[](proposalCount);
        uint256 activeCount = 0;

        for (uint256 i = 1; i <= proposalCount; i++) {
            if (proposals[i].status == ProposalStatus.Active) {
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

    // ============================================================================
    // ADMIN FUNCTIONS
    // ============================================================================

    /**
     * @dev Update governance settings
     * @param newSettings New governance settings
     *
     * PURPOSE: Allow admin to adjust governance parameters
     */
    function updateGovernanceSettings(
        GovernanceSettings memory newSettings
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            newSettings.proposalThreshold > 0,
            "Invalid proposal threshold"
        );
        require(newSettings.votingPeriod >= 1 days, "Voting period too short");
        require(
            newSettings.timelockPeriod >= 1 days,
            "Timelock period too short"
        );
        require(
            newSettings.quorumPercentage <= 10000,
            "Invalid quorum percentage"
        );

        settings = newSettings;
        emit GovernanceSettingsUpdated(newSettings);
    }

    /**
     * @dev Emergency cancel a proposal
     * @param proposalId ID of the proposal to cancel
     *
     * PURPOSE: Cancel proposal in emergency situations
     */
    function emergencyCancelProposal(
        uint256 proposalId
    ) external onlyRole(EMERGENCY_ROLE) {
        require(proposalId <= proposalCount, "Invalid proposal ID");

        RebalancingProposal storage proposal = proposals[proposalId];
        require(
            proposal.status == ProposalStatus.Active ||
                proposal.status == ProposalStatus.Succeeded,
            "Cannot cancel proposal"
        );

        ProposalStatus oldStatus = proposal.status;
        proposal.status = ProposalStatus.Cancelled;

        emit ProposalStatusChanged(
            proposalId,
            oldStatus,
            ProposalStatus.Cancelled
        );
    }

    /**
     * @dev Pause governance in emergency
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause governance
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
}
