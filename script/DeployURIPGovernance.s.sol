// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "../src/URIPDAOGovernance.sol";
import "../src/URIPGovernanceIntegration.sol";
import "../src/URIPContracts.sol";
import "../src/mocks/MockUSDT.sol";

/**
 * @title DeployURIPGovernance
 * @dev Deployment script for URIP governance system
 */
contract DeployURIPGovernance is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock USDT for testing
        MockUSDT usdt = new MockUSDT();
        console.log("Mock USDT deployed at:", address(usdt));

        // Deploy URIP Token (governance token)
        URIPToken uripToken = new URIPToken(
            "URIP Fund Token",
            "URIP",
            1e18, // Initial NAV: $1.00
            200 // 2% management fee
        );
        console.log("URIP Token deployed at:", address(uripToken));

        // Deploy Apple Asset Token for testing
        AssetToken appleToken = new AssetToken(
            "Tokenized Apple Stock",
            "tAAPL",
            150 * 1e8 // $150 initial price
        );
        console.log("Apple Token deployed at:", address(appleToken));

        // Deploy Purchase Manager
        PurchaseManager purchaseManager = new PurchaseManager();
        console.log("Purchase Manager deployed at:", address(purchaseManager));

        // Deploy Treasury Manager first (needed for governance)
        URIPTreasuryManager treasuryManager = new URIPTreasuryManager(
            address(0)
        ); // Will update after governance deployment
        console.log("Treasury Manager deployed at:", address(treasuryManager));

        // Deploy DAO Governance
        URIPDAOGovernance governance = new URIPDAOGovernance(
            address(uripToken),
            address(treasuryManager)
        );
        console.log("DAO Governance deployed at:", address(governance));

        // Update treasury manager with governance address
        treasuryManager.grantRole(
            treasuryManager.GOVERNANCE_ROLE(),
            address(governance)
        );

        // Deploy Governance Integration
        URIPGovernanceIntegration integration = new URIPGovernanceIntegration(
            address(governance),
            address(uripToken),
            address(purchaseManager)
        );
        console.log(
            "Governance Integration deployed at:",
            address(integration)
        );

        // Deploy Governance Helper
        URIPGovernanceHelper helper = new URIPGovernanceHelper(
            address(governance)
        );
        console.log("Governance Helper deployed at:", address(helper));

        // Configure Purchase Manager
        purchaseManager.setSupportedPaymentToken(address(usdt), true);
        purchaseManager.setSupportedAssetToken(address(appleToken), true);
        purchaseManager.setURIPFund(address(uripToken));

        // Configure URIP Token with governance
        uripToken.grantRole(
            uripToken.FUND_MANAGER_ROLE(),
            address(integration)
        );

        // Configure Asset Tokens
        appleToken.grantRole(appleToken.ORACLE_ROLE(), msg.sender);

        // Grant roles for testing
        governance.grantRole(governance.TIMELOCK_ROLE(), msg.sender);
        integration.grantRole(
            integration.GOVERNANCE_ROLE(),
            address(governance)
        );

        // Setup initial governance parameters
        address[] memory initialAssets = new address[](1);
        bool[] memory whitelisted = new bool[](1);
        initialAssets[0] = address(appleToken);
        whitelisted[0] = true;

        integration.setAssetWhitelist(initialAssets, whitelisted);

        // Mint some URIP tokens for testing governance
        uripToken.mint(msg.sender, 1000000 * 1e18); // 1M URIP tokens

        // Transfer some USDT for testing
        usdt.mint(msg.sender, 100000 * 1e6); // 100k USDT

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== URIP Governance Deployment Summary ===");
        console.log("USDT:", address(usdt));
        console.log("URIP Token:", address(uripToken));
        console.log("Apple Token:", address(appleToken));
        console.log("Purchase Manager:", address(purchaseManager));
        console.log("DAO Governance:", address(governance));
        console.log("Treasury Manager:", address(treasuryManager));
        console.log("Governance Integration:", address(integration));
        console.log("Governance Helper:", address(helper));
        console.log("==========================================");
    }
}

/**
 * @title URIPGovernanceTest
 * @dev Comprehensive test suite for URIP governance system
 */
contract URIPGovernanceTest is Test {
    // Contracts
    URIPDAOGovernance governance;
    URIPGovernanceIntegration integration;
    URIPTreasuryManager treasury;
    URIPGovernanceHelper helper;
    URIPToken uripToken;
    AssetToken appleToken;
    AssetToken teslaToken;
    PurchaseManager purchaseManager;
    MockUSDT usdt;

    // Test addresses
    address admin = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    address user3 = address(0x4);
    address proposer = address(0x5);

    // Test constants
    uint256 constant INITIAL_URIP_SUPPLY = 1000000 * 1e18; // 1M URIP
    uint256 constant PROPOSAL_THRESHOLD = 10000 * 1e18; // 10k URIP
    uint256 constant VOTING_PERIOD = 7 days;

    function setUp() public {
        vm.startPrank(admin);

        // Deploy contracts
        usdt = new MockUSDT();

        uripToken = new URIPToken("URIP Fund", "URIP", 1e18, 200);

        appleToken = new AssetToken("Apple Token", "tAAPL", 150 * 1e8);
        teslaToken = new AssetToken("Tesla Token", "tTSLA", 800 * 1e8);

        purchaseManager = new PurchaseManager();

        treasury = new URIPTreasuryManager(address(0));

        governance = new URIPDAOGovernance(
            address(uripToken),
            address(treasury)
        );

        integration = new URIPGovernanceIntegration(
            address(governance),
            address(uripToken),
            address(purchaseManager)
        );

        helper = new URIPGovernanceHelper(address(governance));

        // Setup roles and permissions
        treasury.grantRole(treasury.GOVERNANCE_ROLE(), address(governance));
        uripToken.grantRole(
            uripToken.FUND_MANAGER_ROLE(),
            address(integration)
        );
        integration.grantRole(
            integration.GOVERNANCE_ROLE(),
            address(governance)
        );
        governance.grantRole(governance.TIMELOCK_ROLE(), admin);

        // Configure purchase manager
        purchaseManager.setSupportedPaymentToken(address(usdt), true);
        purchaseManager.setSupportedAssetToken(address(appleToken), true);
        purchaseManager.setSupportedAssetToken(address(teslaToken), true);
        purchaseManager.setURIPFund(address(uripToken));

        // Whitelist assets
        address[] memory assets = new address[](2);
        bool[] memory whitelisted = new bool[](2);
        assets[0] = address(appleToken);
        assets[1] = address(teslaToken);
        whitelisted[0] = true;
        whitelisted[1] = true;
        integration.setAssetWhitelist(assets, whitelisted);

        // Distribute URIP tokens for testing
        uripToken.mint(proposer, PROPOSAL_THRESHOLD * 3); // 30k URIP
        uripToken.mint(user1, 100000 * 1e18); // 100k URIP
        uripToken.mint(user2, 50000 * 1e18); // 50k URIP
        uripToken.mint(user3, 25000 * 1e18); // 25k URIP

        vm.stopPrank();
    }

    // ============================================================================
    // PROPOSAL CREATION TESTS
    // ============================================================================

    function test_CreateFundManagementProposal() public {
        vm.startPrank(proposer);

        address[] memory assets = new address[](2);
        uint256[] memory allocations = new uint256[](2);
        assets[0] = address(appleToken);
        assets[1] = address(teslaToken);
        allocations[0] = 6000; // 60%
        allocations[1] = 4000; // 40%

        uint256 proposalId = governance.createFundRebalancingProposal(
            "Portfolio Rebalancing Q1 2025",
            "Rebalance portfolio to 60% Apple, 40% Tesla based on market analysis",
            assets,
            allocations,
            address(uripToken)
        );

        assertEq(proposalId, 1);
        assertEq(
            uint(governance.getProposalState(proposalId)),
            uint(URIPDAOGovernance.ProposalStatus.ACTIVE)
        );

        vm.stopPrank();
    }

    function test_CreateFeeUpdateProposal() public {
        vm.startPrank(proposer);

        uint256 proposalId = integration.createFeeUpdateProposal(
            "Reduce Management Fee",
            "Reduce management fee from 2% to 1.5% to remain competitive",
            150, // 1.5%
            2000 // 20% performance fee
        );

        assertEq(proposalId, 1);

        vm.stopPrank();
    }

    function test_CreateEmergencyProposal() public {
        vm.startPrank(proposer);

        uint256 proposalId = integration.createEmergencyPauseProposal(
            "Emergency System Pause",
            "Pause system due to detected vulnerability in oracle pricing"
        );

        assertEq(proposalId, 1);

        vm.stopPrank();
    }

    // ============================================================================
    // VOTING TESTS
    // ============================================================================

    function test_VotingProcess() public {
        // Create proposal
        vm.startPrank(proposer);
        address[] memory assets = new address[](1);
        uint256[] memory allocations = new uint256[](1);
        assets[0] = address(appleToken);
        allocations[0] = 10000; // 100%

        uint256 proposalId = governance.createFundRebalancingProposal(
            "Full Apple Allocation",
            "Allocate 100% to Apple stock",
            assets,
            allocations,
            address(uripToken)
        );
        vm.stopPrank();

        // Users vote
        vm.startPrank(user1);
        governance.castVote(proposalId, 1, "I support this allocation");
        vm.stopPrank();

        vm.startPrank(user2);
        governance.castVote(
            proposalId,
            0,
            "Too risky to put everything in one stock"
        );
        vm.stopPrank();

        vm.startPrank(user3);
        governance.castVote(proposalId, 2, "I abstain from this decision");
        vm.stopPrank();

        // Check vote weights
        assertTrue(governance.hasVoted(proposalId, user1));
        assertTrue(governance.hasVoted(proposalId, user2));
        assertTrue(governance.hasVoted(proposalId, user3));

        assertEq(governance.getVote(proposalId, user1), 1);
        assertEq(governance.getVote(proposalId, user2), 0);
        assertEq(governance.getVote(proposalId, user3), 2);
    }

    function test_VotingWithDelegation() public {
        // User1 delegates to user2
        vm.startPrank(user1);
        governance.delegate(user2);
        vm.stopPrank();

        // Check voting power
        uint256 user2Power = governance.getVotingPower(user2);
        assertEq(user2Power, 150000 * 1e18); // 50k + 100k delegated

        // Create and vote on proposal
        vm.startPrank(proposer);
        address[] memory assets = new address[](1);
        uint256[] memory allocations = new uint256[](1);
        assets[0] = address(appleToken);
        allocations[0] = 5000;

        uint256 proposalId = governance.createFundRebalancingProposal(
            "Test Proposal",
            "Test delegation voting",
            assets,
            allocations,
            address(uripToken)
        );
        vm.stopPrank();

        // User2 votes with delegated power
        vm.startPrank(user2);
        governance.castVote(proposalId, 1, "Voting with delegated power");
        vm.stopPrank();

        // Check proposal votes reflect delegation
        (, , , , , , , , , uint256 forVotes, , ) = governance
            .getProposalDetails(proposalId);
        assertEq(forVotes, 150000 * 1e18);
    }

    function test_ProposalExecution() public {
        // Create proposal
        vm.startPrank(proposer);
        address[] memory assets = new address[](2);
        uint256[] memory allocations = new uint256[](2);
        assets[0] = address(appleToken);
        assets[1] = address(teslaToken);
        allocations[0] = 7000; // 70%
        allocations[1] = 3000; // 30%

        uint256 proposalId = governance.createFundRebalancingProposal(
            "Rebalance Portfolio",
            "70% Apple, 30% Tesla allocation",
            assets,
            allocations,
            address(uripToken)
        );
        vm.stopPrank();

        // Vote in favor (enough to reach quorum and approval)
        vm.startPrank(user1);
        governance.castVote(proposalId, 1, "Good allocation");
        vm.stopPrank();

        vm.startPrank(user2);
        governance.castVote(proposalId, 1, "Agree");
        vm.stopPrank();

        // Fast forward past voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        // Finalize proposal
        governance.finalizeProposal(proposalId);
        assertEq(
            uint(governance.getProposalState(proposalId)),
            uint(URIPDAOGovernance.ProposalStatus.SUCCEEDED)
        );

        // Fast forward past execution delay
        vm.warp(block.timestamp + 2 days + 1);

        // Execute proposal
        vm.startPrank(admin);
        governance.executeProposal(proposalId);
        vm.stopPrank();

        assertEq(
            uint(governance.getProposalState(proposalId)),
            uint(URIPDAOGovernance.ProposalStatus.EXECUTED)
        );

        // Check that allocations were updated
        assertEq(uripToken.assetAllocations(address(appleToken)), 7000);
        assertEq(uripToken.assetAllocations(address(teslaToken)), 3000);
    }

    // ============================================================================
    // GOVERNANCE INTEGRATION TESTS
    // ============================================================================

    function test_GovernanceParameterUpdate() public {
        // Create fee update proposal
        vm.startPrank(proposer);
        uint256 proposalId = integration.createFeeUpdateProposal(
            "Lower Management Fee",
            "Reduce fee to stay competitive",
            150, // 1.5%
            1800 // 18%
        );
        vm.stopPrank();

        // Vote and execute
        vm.startPrank(user1);
        governance.castVote(proposalId, 1, "Lower fees are good");
        vm.stopPrank();

        vm.startPrank(user2);
        governance.castVote(proposalId, 1, "Agree");
        vm.stopPrank();

        // Fast forward and execute
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        governance.finalizeProposal(proposalId);

        vm.warp(block.timestamp + 5 days + 1); // Protocol governance has 5 day delay
        vm.startPrank(admin);
        governance.executeProposal(proposalId);
        vm.stopPrank();

        // Check updated parameters
        URIPGovernanceIntegration.GovernanceParams memory params = integration
            .getGovernanceParams();
        assertEq(params.managementFee, 150);
        assertEq(params.performanceFee, 1800);
    }

    function test_AssetWhitelistUpdate() public {
        // Deploy new asset
        AssetToken newAsset = new AssetToken("New Asset", "NEW", 100 * 1e8);

        // Create whitelist proposal
        vm.startPrank(proposer);
        address[] memory assets = new address[](1);
        bool[] memory whitelisted = new bool[](1);
        assets[0] = address(newAsset);
        whitelisted[0] = true;

        uint256 proposalId = integration.createAssetWhitelistProposal(
            "Add New Asset",
            "Whitelist new asset for trading",
            assets,
            whitelisted
        );
        vm.stopPrank();

        // Vote and execute
        vm.startPrank(user1);
        governance.castVote(proposalId, 1, "Good new asset");
        vm.stopPrank();

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        governance.finalizeProposal(proposalId);

        vm.warp(block.timestamp + 2 days + 1);
        vm.startPrank(admin);
        governance.executeProposal(proposalId);
        vm.stopPrank();

        // Check asset is whitelisted
        assertTrue(integration.isAssetEligible(address(newAsset)));
    }

    function test_EmergencyPause() public {
        // Create emergency pause proposal
        vm.startPrank(proposer);
        uint256 proposalId = integration.createEmergencyPauseProposal(
            "Emergency Pause",
            "Pause due to security issue"
        );
        vm.stopPrank();

        // Vote and execute quickly (emergency proposal)
        vm.startPrank(user1);
        governance.castVote(proposalId, 1, "Emergency action needed");
        vm.stopPrank();

        vm.startPrank(user2);
        governance.castVote(proposalId, 1, "Agree");
        vm.stopPrank();

        vm.startPrank(user3);
        governance.castVote(proposalId, 1, "Safety first");
        vm.stopPrank();

        // Fast forward and execute (emergency has shorter periods)
        vm.warp(block.timestamp + 3 days + 1);
        governance.finalizeProposal(proposalId);

        vm.warp(block.timestamp + 1 days + 1);
        vm.startPrank(admin);
        governance.executeProposal(proposalId);
        vm.stopPrank();

        // Check system is paused
        URIPGovernanceIntegration.GovernanceParams memory params = integration
            .getGovernanceParams();
        assertTrue(params.emergencyPaused);
    }

    // ============================================================================
    // TREASURY MANAGEMENT TESTS
    // ============================================================================

    function test_TreasuryBudgetAllocation() public {
        // Setup treasury with funds
        usdt.mint(address(treasury), 1000000 * 1e6); // 1M USDT

        // Allocate budget through governance
        vm.startPrank(admin); // Admin has governance role for testing
        treasury.allocateBudget(
            URIPTreasuryManager.BudgetCategory.DEVELOPMENT,
            address(usdt),
            100000 * 1e6, // 100k USDT
            90 days
        );
        vm.stopPrank();

        // Check budget allocation
        uint256 remaining = treasury.getRemainingBudget(
            URIPTreasuryManager.BudgetCategory.DEVELOPMENT,
            address(usdt)
        );
        assertEq(remaining, 100000 * 1e6);
    }

    function test_TreasurySpending() public {
        // Setup treasury and budget
        usdt.mint(address(treasury), 1000000 * 1e6);

        vm.startPrank(admin);
        treasury.grantRole(treasury.TREASURER_ROLE(), user1);
        treasury.allocateBudget(
            URIPTreasuryManager.BudgetCategory.MARKETING,
            address(usdt),
            50000 * 1e6, // 50k USDT
            30 days
        );
        vm.stopPrank();

        // Spend from budget
        vm.startPrank(user1);
        treasury.spendFromBudget(
            URIPTreasuryManager.BudgetCategory.MARKETING,
            address(usdt),
            10000 * 1e6, // 10k USDT
            "Marketing campaign Q1",
            user2
        );
        vm.stopPrank();

        // Check remaining budget
        uint256 remaining = treasury.getRemainingBudget(
            URIPTreasuryManager.BudgetCategory.MARKETING,
            address(usdt)
        );
        assertEq(remaining, 40000 * 1e6);

        // Check recipient received funds
        assertEq(usdt.balanceOf(user2), 10000 * 1e6);
    }

    // ============================================================================
    // HELPER FUNCTION TESTS
    // ============================================================================

    function test_GetActiveProposals() public {
        // Create multiple proposals
        vm.startPrank(proposer);

        address[] memory assets = new address[](1);
        uint256[] memory allocations = new uint256[](1);
        assets[0] = address(appleToken);
        allocations[0] = 5000;

        governance.createFundRebalancingProposal(
            "Proposal 1",
            "Test 1",
            assets,
            allocations,
            address(uripToken)
        );
        governance.createFundRebalancingProposal(
            "Proposal 2",
            "Test 2",
            assets,
            allocations,
            address(uripToken)
        );
        governance.createFundRebalancingProposal(
            "Proposal 3",
            "Test 3",
            assets,
            allocations,
            address(uripToken)
        );

        vm.stopPrank();

        // Get active proposals
        uint256[] memory activeProposals = helper.getActiveProposals();
        assertEq(activeProposals.length, 3);
        assertEq(activeProposals[0], 1);
        assertEq(activeProposals[1], 2);
        assertEq(activeProposals[2], 3);
    }

    function test_BatchVoting() public {
        // Create multiple proposals
        vm.startPrank(proposer);

        address[] memory assets = new address[](1);
        uint256[] memory allocations = new uint256[](1);
        assets[0] = address(appleToken);
        allocations[0] = 5000;

        governance.createFundRebalancingProposal(
            "Proposal 1",
            "Test 1",
            assets,
            allocations,
            address(uripToken)
        );
        governance.createFundRebalancingProposal(
            "Proposal 2",
            "Test 2",
            assets,
            allocations,
            address(uripToken)
        );

        vm.stopPrank();

        // Batch vote
        vm.startPrank(user1);
        uint256[] memory proposalIds = new uint256[](2);
        uint8[] memory support = new uint8[](2);
        string[] memory reasons = new string[](2);

        proposalIds[0] = 1;
        proposalIds[1] = 2;
        support[0] = 1; // For
        support[1] = 0; // Against
        reasons[0] = "Support proposal 1";
        reasons[1] = "Against proposal 2";

        helper.batchVote(proposalIds, support, reasons);
        vm.stopPrank();

        // Check votes were cast
        assertTrue(governance.hasVoted(1, user1));
        assertTrue(governance.hasVoted(2, user1));
        assertEq(governance.getVote(1, user1), 1);
        assertEq(governance.getVote(2, user1), 0);
    }

    // ============================================================================
    // EDGE CASE AND SECURITY TESTS
    // ============================================================================

    function test_FailInsufficientTokensForProposal() public {
        vm.startPrank(user3); // User3 has only 25k tokens, needs 10k minimum

        address[] memory assets = new address[](1);
        uint256[] memory allocations = new uint256[](1);
        assets[0] = address(appleToken);
        allocations[0] = 5000;

        // This should succeed as user3 has 25k > 10k threshold
        governance.createFundRebalancingProposal(
            "Test",
            "Test",
            assets,
            allocations,
            address(uripToken)
        );

        vm.stopPrank();

        // Now test with insufficient tokens
        address lowTokenUser = address(0x999);
        uripToken.mint(lowTokenUser, 5000 * 1e18); // Only 5k tokens

        vm.startPrank(lowTokenUser);
        vm.expectRevert("Insufficient voting power");
        governance.createFundRebalancingProposal(
            "Test",
            "Test",
            assets,
            allocations,
            address(uripToken)
        );
        vm.stopPrank();
    }

    function test_FailDoubleVoting() public {
        // Create proposal
        vm.startPrank(proposer);
        address[] memory assets = new address[](1);
        uint256[] memory allocations = new uint256[](1);
        assets[0] = address(appleToken);
        allocations[0] = 5000;

        uint256 proposalId = governance.createFundRebalancingProposal(
            "Test",
            "Test",
            assets,
            allocations,
            address(uripToken)
        );
        vm.stopPrank();

        // First vote
        vm.startPrank(user1);
        governance.castVote(proposalId, 1, "First vote");

        // Try to vote again
        vm.expectRevert("Already voted");
        governance.castVote(proposalId, 0, "Second vote");
        vm.stopPrank();
    }

    function test_FailExecuteBeforeDelay() public {
        // Create and pass proposal
        vm.startPrank(proposer);
        address[] memory assets = new address[](1);
        uint256[] memory allocations = new uint256[](1);
        assets[0] = address(appleToken);
        allocations[0] = 5000;

        uint256 proposalId = governance.createFundRebalancingProposal(
            "Test",
            "Test",
            assets,
            allocations,
            address(uripToken)
        );
        vm.stopPrank();

        // Vote
        vm.startPrank(user1);
        governance.castVote(proposalId, 1, "Support");
        vm.stopPrank();

        vm.startPrank(user2);
        governance.castVote(proposalId, 1, "Support");
        vm.stopPrank();

        // Fast forward past voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        governance.finalizeProposal(proposalId);

        // Try to execute before delay
        vm.startPrank(admin);
        vm.expectRevert("Execution delay not met");
        governance.executeProposal(proposalId);
        vm.stopPrank();
    }

    function test_EmergencyCancelProposal() public {
        // Create proposal
        vm.startPrank(proposer);
        address[] memory assets = new address[](1);
        uint256[] memory allocations = new uint256[](1);
        assets[0] = address(appleToken);
        allocations[0] = 5000;

        uint256 proposalId = governance.createFundRebalancingProposal(
            "Test",
            "Test",
            assets,
            allocations,
            address(uripToken)
        );
        vm.stopPrank();

        // Emergency cancel
        vm.startPrank(admin); // Admin has emergency role
        governance.emergencyCancelProposal(proposalId);
        vm.stopPrank();

        assertEq(
            uint(governance.getProposalState(proposalId)),
            uint(URIPDAOGovernance.ProposalStatus.CANCELLED)
        );
    }

    // ============================================================================
    // UTILITY FUNCTIONS
    // ============================================================================

    function _createTestProposal() internal returns (uint256) {
        vm.startPrank(proposer);
        address[] memory assets = new address[](1);
        uint256[] memory allocations = new uint256[](1);
        assets[0] = address(appleToken);
        allocations[0] = 5000;

        uint256 proposalId = governance.createFundRebalancingProposal(
            "Test Proposal",
            "Test Description",
            assets,
            allocations,
            address(uripToken)
        );
        vm.stopPrank();
        return proposalId;
    }

    function _passProposal(uint256 proposalId) internal {
        vm.startPrank(user1);
        governance.castVote(proposalId, 1, "Support");
        vm.stopPrank();

        vm.startPrank(user2);
        governance.castVote(proposalId, 1, "Support");
        vm.stopPrank();

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        governance.finalizeProposal(proposalId);
    }
}

/**
 * @title URIPGovernanceIntegrationScript
 * @dev Script for interacting with deployed governance contracts
 */
contract URIPGovernanceIntegrationScript is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        // Load deployed contract addresses (update with actual addresses)
        address governanceAddress = vm.envAddress("GOVERNANCE_ADDRESS");
        address integrationAddress = vm.envAddress("INTEGRATION_ADDRESS");
        address uripTokenAddress = vm.envAddress("URIP_TOKEN_ADDRESS");

        URIPDAOGovernance governance = URIPDAOGovernance(governanceAddress);
        URIPGovernanceIntegration integration = URIPGovernanceIntegration(
            integrationAddress
        );
        IERC20 uripToken = IERC20(uripTokenAddress);

        vm.startBroadcast(privateKey);

        // Example: Create a fee reduction proposal
        uint256 proposalId = integration.createFeeUpdateProposal(
            "Reduce Management Fee to 1.5%",
            "Market conditions favor lower fees to attract more investors and remain competitive with traditional funds.",
            150, // 1.5% management fee
            2000 // 20% performance fee
        );

        console.log("Created fee update proposal with ID:", proposalId);

        // Example: Vote on an existing proposal (if you have one)
        // governance.castVote(1, 1, "I support lower fees for better competitiveness");

        // Example: Check voting power
        uint256 votingPower = governance.getVotingPower(msg.sender);
        console.log("Your voting power:", votingPower);

        // Example: Get active proposals
        URIPGovernanceHelper helper = URIPGovernanceHelper(
            vm.envAddress("HELPER_ADDRESS")
        );
        uint256[] memory activeProposals = helper.getActiveProposals();
        console.log("Number of active proposals:", activeProposals.length);

        vm.stopBroadcast();
    }
}

/**
 * @title URIPGovernanceMonitor
 * @dev Script for monitoring governance activity
 */
contract URIPGovernanceMonitor is Script {
    function run() public view {
        address governanceAddress = vm.envAddress("GOVERNANCE_ADDRESS");
        URIPDAOGovernance governance = URIPDAOGovernance(governanceAddress);

        uint256 proposalCount = governance.proposalCount();
        console.log("Total proposals created:", proposalCount);

        for (uint256 i = 1; i <= proposalCount; i++) {
            URIPDAOGovernance.ProposalStatus status = governance
                .getProposalState(i);
            console.log("Proposal", i, "status:", uint(status));

            (
                string memory title,
                string memory description,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                uint256 startTime,
                uint256 endTime,
                ,
                uint256 forVotes,
                uint256 againstVotes,
                uint256 abstainVotes
            ) = governance.getProposalDetails(i);

            console.log("Title:", title);
            console.log("For votes:", forVotes);
            console.log("Against votes:", againstVotes);
            console.log("Abstain votes:", abstainVotes);

            if (block.timestamp <= endTime) {
                console.log(
                    "Time remaining:",
                    (endTime - block.timestamp) / 3600,
                    "hours"
                );
            }

            console.log("---");
        }
    }
}
