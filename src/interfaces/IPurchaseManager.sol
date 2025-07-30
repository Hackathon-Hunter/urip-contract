// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPurchaseManager {
    function purchaseAssetToken(
        address paymentToken,
        address assetToken,
        uint256 paymentAmount
    ) external;
    function purchaseMutualFund(
        address paymentToken,
        uint256 paymentAmount
    ) external;
    function setSupportedPaymentToken(address token, bool supported) external;
    function setSupportedAssetToken(
        address assetToken,
        bool supported
    ) external;
}
