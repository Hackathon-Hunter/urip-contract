// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

// ============================================================================
// PRICE ORACLE SIMULATOR (untuk testing)
// ============================================================================

contract MockPriceOracle {
    mapping(string => uint256) public prices;
    mapping(string => uint256) public lastUpdated;

    address public owner;

    constructor() {
        owner = msg.sender;

        // Set initial prices
        prices["AAPL"] = 150 * 1e8;
        prices["TSLA"] = 200 * 1e8;
        prices["GOOGL"] = 2800 * 1e8;
        prices["GOLD"] = 2000 * 1e8;

        lastUpdated["AAPL"] = block.timestamp;
        lastUpdated["TSLA"] = block.timestamp;
        lastUpdated["GOOGL"] = block.timestamp;
        lastUpdated["GOLD"] = block.timestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function updatePrice(
        string memory symbol,
        uint256 newPrice
    ) external onlyOwner {
        prices[symbol] = newPrice;
        lastUpdated[symbol] = block.timestamp;
    }

    function getPrice(
        string memory symbol
    ) external view returns (uint256, uint256) {
        return (prices[symbol], lastUpdated[symbol]);
    }

    // Simulate price fluctuation untuk testing
    function simulateMarketMovement() external onlyOwner {
        // Random price movements (simplified untuk demo)
        uint256 randomSeed = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao))
        ) % 100;

        if (randomSeed < 50) {
            // Prices go up 1-5%
            prices["AAPL"] = (prices["AAPL"] * (101 + (randomSeed % 5))) / 100;
            prices["TSLA"] = (prices["TSLA"] * (101 + (randomSeed % 5))) / 100;
        } else {
            // Prices go down 1-5%
            prices["AAPL"] = (prices["AAPL"] * (99 - (randomSeed % 5))) / 100;
            prices["TSLA"] = (prices["TSLA"] * (99 - (randomSeed % 5))) / 100;
        }

        lastUpdated["AAPL"] = block.timestamp;
        lastUpdated["TSLA"] = block.timestamp;
    }
}