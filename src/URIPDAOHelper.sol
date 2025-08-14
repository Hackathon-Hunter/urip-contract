// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./URIPDAOGovernance.sol";

/**
 * @title URIPDAOHelper
 * @dev Helper contract for easier DAO interaction and common governance operations
 *
 * PURPOSE:
 * - Simplify common governance operations for frontend
 * - Provide batch operations and convenience functions
 * - Calculate voting statistics and proposal analytics
 * - Generate pre-built proposal templates
 *
 * BENEFITS:
 * - Reduce gas costs with batch operations
 * - Easier frontend integration
 * - Better user experience with proposal templates
 * - Analytics and statistics for governance dashboard
 */
contract URIPDAOHelper {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    URIPDAOGovernance public immutable governance;
    IURIPToken public immutable uripToken;

    // ============================================================================
    // STRUCTS FOR BETTER DATA ORGANIZATION
    // ============================================================================

    struct ProposalSummary {
        uint256 id;
        string title;
        address proposer;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 forPercentage;
        uint256 againstPercentage;
        URIPDAOGovernance.ProposalStatus status;
        bool canExecute;
        uint256 timeUntilExecution;
    }

    struct AllocationChange {
        address assetToken;
        string assetSymbol;
        uint256 currentAllocation;
        uint256 proposedAllocation;
        int256 change; // Positive for increase, negative for decrease
    }

    struct VotingStats {
        uint256 totalProposals;
        uint256 activeProposals;
        uint256 succeededProposals;
        uint256 defeatedProposals;
        uint256 executedProposals;
        uint256 totalVotingPower;
        uint256 averageParticipation;
    }

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    constructor(address _governance) {
        governance = URIPDAOGovernance(_governance);
        uripToken = governance.uripToken();
    }

    // ============================================================================
    // PROPOSAL CREATION HELPERS
    // ============================================================================

    /**
     * @dev Create a simple rebalancing proposal between two assets
     * @param title Proposal title
     * @param description Proposal description
     * @param asset1 First asset token address
     * @param asset1Allocation New allocation for asset1 (basis points)
     * @param asset2 Second asset token address
     * @param asset2Allocation New allocation for asset2 (basis points)
     * @return proposalId Created proposal ID
     *
     * PURPOSE: Simplify creation of common 2-asset rebalancing proposals
     * EXAMPLE: Rebalance AAPL/NVDA from 50/50 to 60/40
     */
    function createSimpleRebalancing(
        string memory title,
        string memory description,
        address asset1,
        uint256 asset1Allocation,
        address asset2,
        uint256 asset2Allocation
    ) external returns (uint256) {
        require(
            asset1Allocation + asset2Allocation == 10000,
            "Allocations must sum to 100%"
        );

        address[] memory assets = new address[](2);
        uint256[] memory allocations = new uint256[](2);

        assets[0] = asset1;
        assets[1] = asset2;
        allocations[0] = asset1Allocation;
        allocations[1] = asset2Allocation;

        return
            governance.createRebalancingProposal(
                title,
                description,
                assets,
                allocations
            );
    }

    /**
     * @dev Create a proposal with preset templates
     * @param templateType Type of rebalancing template
     * @param assets Array of asset addresses (must match template requirements)
     * @return proposalId Created proposal ID
     *
     * TEMPLATES:
     * 0 = Equal Weight (all assets get equal allocation)
     * 1 = Conservative (60/40 split for 2 assets)
     * 2 = Aggressive (80/20 split for 2 assets)
     * 3 = Balanced (50/30/20 split for 3 assets)
     */
    function createTemplateProposal(
        uint256 templateType,
        address[] memory assets
    ) external returns (uint256) {
        require(assets.length > 0, "Must specify assets");

        uint256[] memory allocations = new uint256[](assets.length);
        string memory title;
        string memory description;

        if (templateType == 0) {
            // Equal Weight
            require(assets.length <= 10, "Too many assets for equal weight");
            uint256 equalWeight = 10000 / assets.length;
            uint256 remainder = 10000 % assets.length;

            for (uint256 i = 0; i < assets.length; i++) {
                allocations[i] = equalWeight;
                if (i == 0) allocations[i] += remainder; // Add remainder to first asset
            }
            title = "Equal Weight Rebalancing";
            description = "Rebalance all assets to equal weights for maximum diversification";
        } else if (templateType == 1) {
            // Conservative 60/40
            require(
                assets.length == 2,
                "Conservative template requires exactly 2 assets"
            );
            allocations[0] = 6000; // 60%
            allocations[1] = 4000; // 40%
            title = "Conservative 60/40 Rebalancing";
            description = "Conservative rebalancing with 60% allocation to primary asset and 40% to secondary asset";
        } else if (templateType == 2) {
            // Aggressive 80/20
            require(
                assets.length == 2,
                "Aggressive template requires exactly 2 assets"
            );
            allocations[0] = 8000; // 80%
            allocations[1] = 2000; // 20%
            title = "Aggressive 80/20 Rebalancing";
            description = "Aggressive rebalancing with 80% allocation to primary asset and 20% to secondary asset";
        } else if (templateType == 3) {
            // Balanced 50/30/20
            require(
                assets.length == 3,
                "Balanced template requires exactly 3 assets"
            );
            allocations[0] = 5000; // 50%
            allocations[1] = 3000; // 30%
            allocations[2] = 2000; // 20%
            title = "Balanced 50/30/20 Rebalancing";
            description = "Balanced three-asset allocation with decreasing weights";
        } else {
            revert("Invalid template type");
        }

        return
            governance.createRebalancingProposal(
                title,
                description,
                assets,
                allocations
            );
    }
}
