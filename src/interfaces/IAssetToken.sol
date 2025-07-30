// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAssetToken {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function updatePrice(uint256 newPrice) external;
    function getCurrentPrice() external view returns (uint256, uint256);
}
