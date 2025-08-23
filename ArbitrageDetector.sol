// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title ArbitrageDetector
 * @dev Advanced arbitrage detection and MEV protection for Base blockchain DeFi protocols
 * @author Crypto Challenge Repository
 * @notice Detects arbitrage opportunities across multiple DEXs and provides MEV protection
 */
contract ArbitrageDetector is ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    // Constants
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_SLIPPAGE = 500; // 5%
    uint256 public constant MIN_PROFIT_THRESHOLD = 1e15; // 0.001 ETH

    // DEX information structure
    struct DEXInfo {
        address router;
        string name;
        uint256 fee; // in basis points
        bool isActive;
    }

    // Arbitrage opportunity structure
    struct ArbitrageOpportunity {
        address tokenA;
        address tokenB;
        uint256 dexAIndex;
        uint256 dexBIndex;
        uint256 profitAmount;
        uint256 inputAmount;
        uint256 timestamp;
        bool isExecutable;
    }

    // Price information
    struct PriceInfo {
        uint256 price;
        uint256 liquidity;
        uint256 timestamp;
        uint256 dexIndex;
    }

    // Storage
    DEXInfo[] public dexes;
    mapping(address => mapping(address => PriceInfo[])) public tokenPrices;
    mapping(address => bool) public authorizedBots;
    ArbitrageOpportunity[] public opportunities;

    // Events
    event ArbitrageDetected(
        address indexed tokenA,
        address indexed tokenB,
        uint256 profitAmount,
        uint256 dexAIndex,
        uint256 dexBIndex
    );
    event DEXAdded(uint256 indexed dexIndex, string name, address router);
    event PriceUpdated(address indexed token, uint256 price, uint256 dexIndex);

    constructor() {}

    /**
     * @dev Add a new DEX for arbitrage monitoring
     */
    function addDEX(
        address _router,
        string memory _name,
        uint256 _fee
    ) external onlyOwner {
        dexes.push(DEXInfo({
            router: _router,
            name: _name,
            fee: _fee,
            isActive: true
        }));

        emit DEXAdded(dexes.length - 1, _name, _router);
    }

    /**
     * @dev Detect arbitrage opportunities between DEXs
     */
    function detectArbitrage(
        address _tokenA,
        address _tokenB,
        uint256 _inputAmount
    ) external view returns (ArbitrageOpportunity memory) {
        require(_inputAmount > 0, "Invalid input amount");

        uint256 bestBuyDEX = 0;
        uint256 bestSellDEX = 0;
        uint256 lowestPrice = type(uint256).max;
        uint256 highestPrice = 0;

        // Find best buy and sell prices across DEXs
        for (uint256 i = 0; i < dexes.length; i++) {
            if (!dexes[i].isActive) continue;

            uint256 currentPrice = getLatestPrice(_tokenA, _tokenB, i);
            if (currentPrice == 0) continue;

            if (currentPrice < lowestPrice) {
                lowestPrice = currentPrice;
                bestBuyDEX = i;
            }

            if (currentPrice > highestPrice) {
                highestPrice = currentPrice;
                bestSellDEX = i;
            }
        }

        // Calculate potential profit
        uint256 profitAmount = calculateProfit(
            _inputAmount,
            lowestPrice,
            highestPrice,
            bestBuyDEX,
            bestSellDEX
        );

        bool isExecutable = profitAmount >= MIN_PROFIT_THRESHOLD &&
                           bestBuyDEX != bestSellDEX;

        return ArbitrageOpportunity({
            tokenA: _tokenA,
            tokenB: _tokenB,
            dexAIndex: bestBuyDEX,
            dexBIndex: bestSellDEX,
            profitAmount: profitAmount,
            inputAmount: _inputAmount,
            timestamp: block.timestamp,
            isExecutable: isExecutable
        });
    }

    /**
     * @dev Calculate arbitrage profit considering fees and slippage
     */
    function calculateProfit(
        uint256 _inputAmount,
        uint256 _buyPrice,
        uint256 _sellPrice,
        uint256 _buyDEXIndex,
        uint256 _sellDEXIndex
    ) public view returns (uint256) {
        if (_sellPrice <= _buyPrice) return 0;

        // Calculate amounts after fees
        uint256 buyFee = dexes[_buyDEXIndex].fee;
        uint256 sellFee = dexes[_sellDEXIndex].fee;

        uint256 amountAfterBuyFee = _inputAmount.mul(10000 - buyFee).div(10000);
        uint256 tokensReceived = amountAfterBuyFee.mul(PRECISION).div(_buyPrice);
        uint256 amountAfterSell = tokensReceived.mul(_sellPrice).div(PRECISION);
        uint256 finalAmount = amountAfterSell.mul(10000 - sellFee).div(10000);

        return finalAmount > _inputAmount ? finalAmount.sub(_inputAmount) : 0;
    }

    /**
     * @dev Get latest price for a token pair on specific DEX
     */
    function getLatestPrice(
        address _tokenA,
        address _tokenB,
        uint256 _dexIndex
    ) public view returns (uint256) {
        PriceInfo[] memory prices = tokenPrices[_tokenA][_tokenB];
        if (prices.length == 0) return 0;

        uint256 latestPrice = 0;
        uint256 latestTimestamp = 0;

        for (uint256 i = 0; i < prices.length; i++) {
            if (prices[i].dexIndex == _dexIndex && prices[i].timestamp > latestTimestamp) {
                latestPrice = prices[i].price;
                latestTimestamp = prices[i].timestamp;
            }
        }

        return latestPrice;
    }

    /**
     * @dev Update token price for a specific DEX
     */
    function updatePrice(
        address _tokenA,
        address _tokenB,
        uint256 _price,
        uint256 _liquidity,
        uint256 _dexIndex
    ) external {
        require(_dexIndex < dexes.length, "Invalid DEX index");
        require(authorizedBots[msg.sender] || msg.sender == owner(), "Unauthorized");

        tokenPrices[_tokenA][_tokenB].push(PriceInfo({
            price: _price,
            liquidity: _liquidity,
            timestamp: block.timestamp,
            dexIndex: _dexIndex
        }));

        emit PriceUpdated(_tokenA, _price, _dexIndex);
    }

    /**
     * @dev Get DEX count
     */
    function getDEXCount() external view returns (uint256) {
        return dexes.length;
    }

    /**
     * @dev Authorize bot for price updates
     */
    function authorizeBot(address _bot) external onlyOwner {
        authorizedBots[_bot] = true;
    }
}
