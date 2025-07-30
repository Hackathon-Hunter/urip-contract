// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IURIPToken {
    function purchaseFund(address to, uint256 usdAmount) external;
    function redeemFund(
        address from,
        uint256 tokenAmount
    ) external returns (uint256);
    function updateNAV(uint256 newTotalAssetValue) external;
    function getCurrentNAV() external view returns (uint256, uint256);
    function setAssetAllocation(
        address assetToken,
        uint256 allocationBasisPoints
    ) external;
}
