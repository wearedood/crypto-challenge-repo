// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title GasOptimizer
 * @dev Advanced gas optimization utilities for Base blockchain smart contracts
 * @author Crypto Challenge Repository
 * @notice Provides tools for analyzing, optimizing, and monitoring gas usage in DeFi protocols
 */
contract GasOptimizer is Ownable, ReentrancyGuard {
    // Gas optimization constants
    uint256 public constant MAX_BATCH_SIZE = 100;
    uint256 public constant GAS_BUFFER = 21000;
    uint256 public constant OPTIMIZATION_THRESHOLD = 50000;

    // Gas usage tracking
    struct GasMetrics {
        uint256 totalGasUsed;
        uint256 averageGasPerTx;
        uint256 optimizationsSaved;
        uint256 transactionCount;
        uint256 lastUpdated;
    }

    // Function gas profiles
    struct FunctionProfile {
        string functionName;
        uint256 baseGasCost;
        uint256 optimizedGasCost;
        uint256 savingsPercentage;
        bool isOptimized;
    }

    // State variables
    GasMetrics public globalMetrics;
    mapping(bytes4 => FunctionProfile) public functionProfiles;
    mapping(address => GasMetrics) public contractMetrics;
    
    // Gas price tracking
    uint256 public currentGasPrice;
    uint256 public averageGasPrice;

    // Events
    event GasOptimizationApplied(bytes4 indexed functionSig, uint256 gasSaved);
    event BatchOperationCompleted(uint256 operations, uint256 totalGasSaved);
    event GasPriceUpdated(uint256 newPrice, uint256 timestamp);

    constructor() {}

    /**
     * @dev Analyze gas usage for a specific function
     */
    function analyzeFunction(
        bytes4 _functionSig,
        string memory _functionName,
        uint256 _baseGasCost
    ) external onlyOwner {
        functionProfiles[_functionSig] = FunctionProfile({
            functionName: _functionName,
            baseGasCost: _baseGasCost,
            optimizedGasCost: 0,
            savingsPercentage: 0,
            isOptimized: false
        });
    }

    /**
     * @dev Apply gas optimization to a function
     */
    function optimizeFunction(
        bytes4 _functionSig,
        uint256 _optimizedGasCost
    ) external onlyOwner {
        FunctionProfile storage profile = functionProfiles[_functionSig];
        require(profile.baseGasCost > 0, "Function not analyzed");
        
        profile.optimizedGasCost = _optimizedGasCost;
        profile.isOptimized = true;
        
        if (profile.baseGasCost > _optimizedGasCost) {
            uint256 savings = profile.baseGasCost - _optimizedGasCost;
            profile.savingsPercentage = (savings * 100) / profile.baseGasCost;
            
            globalMetrics.optimizationsSaved += savings;
            
            emit GasOptimizationApplied(_functionSig, savings);
        }
    }

    /**
     * @dev Batch multiple operations to save gas
     */
    function batchOperations(
        address[] calldata _targets,
        bytes[] calldata _data
    ) external nonReentrant returns (uint256 totalGasSaved) {
        require(_targets.length == _data.length, "Array length mismatch");
        require(_targets.length <= MAX_BATCH_SIZE, "Batch size too large");
        
        uint256 initialGas = gasleft();
        uint256 individualGasCost = _targets.length * GAS_BUFFER;
        
        // Execute batch operations
        for (uint256 i = 0; i < _targets.length; i++) {
            (bool success, ) = _targets[i].call(_data[i]);
            require(success, "Batch operation failed");
        }
        
        uint256 actualGasUsed = initialGas - gasleft();
        totalGasSaved = individualGasCost > actualGasUsed ? 
            individualGasCost - actualGasUsed : 0;
        
        emit BatchOperationCompleted(_targets.length, totalGasSaved);
        return totalGasSaved;
    }

    /**
     * @dev Calculate optimal gas limit for transaction
     */
    function calculateOptimalGasLimit(
        bytes4 _functionSig,
        uint256 _complexity
    ) external view returns (uint256 optimalLimit) {
        FunctionProfile memory profile = functionProfiles[_functionSig];
        
        if (profile.isOptimized && profile.optimizedGasCost > 0) {
            optimalLimit = profile.optimizedGasCost + GAS_BUFFER;
        } else if (profile.baseGasCost > 0) {
            optimalLimit = profile.baseGasCost + GAS_BUFFER;
        } else {
            // Fallback calculation based on complexity
            optimalLimit = (_complexity * 50000) + GAS_BUFFER;
        }
        
        return optimalLimit;
    }

    /**
     * @dev Get gas optimization recommendations
     */
    function getOptimizationRecommendations(
        bytes4 _functionSig
    ) external view returns (
        string memory recommendation,
        uint256 potentialSavings,
        bool shouldOptimize
    ) {
        FunctionProfile memory profile = functionProfiles[_functionSig];
        
        if (profile.baseGasCost == 0) {
            return ("Function not analyzed", 0, false);
        }
        
        if (profile.isOptimized) {
            return ("Already optimized", 0, false);
        }
        
        if (profile.baseGasCost > OPTIMIZATION_THRESHOLD) {
            potentialSavings = (profile.baseGasCost * 20) / 100; // Estimate 20% savings
            return (
                "High gas usage detected - consider optimization",
                potentialSavings,
                true
            );
        }
        
        return ("Gas usage within acceptable range", 0, false);
    }

    /**
     * @dev Track gas usage for a contract
     */
    function trackContractGasUsage(
        address _contract,
        uint256 _gasUsed
    ) external {
        GasMetrics storage metrics = contractMetrics[_contract];
        
        metrics.totalGasUsed += _gasUsed;
        metrics.transactionCount += 1;
        metrics.averageGasPerTx = metrics.totalGasUsed / metrics.transactionCount;
        metrics.lastUpdated = block.timestamp;
        
        // Update global metrics
        globalMetrics.totalGasUsed += _gasUsed;
        globalMetrics.transactionCount += 1;
        globalMetrics.averageGasPerTx = globalMetrics.totalGasUsed / globalMetrics.transactionCount;
        globalMetrics.lastUpdated = block.timestamp;
    }

    /**
     * @dev Get gas efficiency score for a contract
     */
    function getEfficiencyScore(address _contract) external view returns (uint256 score) {
        GasMetrics memory metrics = contractMetrics[_contract];
        
        if (metrics.transactionCount == 0) {
            return 0;
        }
        
        // Calculate efficiency score (0-100)
        uint256 avgGas = metrics.averageGasPerTx;
        uint256 globalAvg = globalMetrics.averageGasPerTx;
        
        if (globalAvg == 0) {
            return 50; // Default score
        }
        
        if (avgGas <= globalAvg) {
            // Better than average
            score = 50 + ((globalAvg - avgGas) * 50) / globalAvg;
        } else {
            // Worse than average
            score = 50 - ((avgGas - globalAvg) * 50) / globalAvg;
        }
        
        return score > 100 ? 100 : score;
    }

    /**
     * @dev Update gas price for optimization calculations
     */
    function updateGasPrice(uint256 _newGasPrice) external {
        currentGasPrice = _newGasPrice;
        // Simple average calculation
        averageGasPrice = (averageGasPrice + _newGasPrice) / 2;
        
        emit GasPriceUpdated(_newGasPrice, block.timestamp);
    }

    /**
     * @dev Get current gas metrics
     */
    function getCurrentMetrics() external view returns (
        uint256 totalGas,
        uint256 avgGasPerTx,
        uint256 totalSavings,
        uint256 txCount
    ) {
        return (
            globalMetrics.totalGasUsed,
            globalMetrics.averageGasPerTx,
            globalMetrics.optimizationsSaved,
            globalMetrics.transactionCount
        );
    }

    /**
     * @dev Emergency gas optimization for high-priority transactions
     */
    function emergencyOptimization(
        address _target,
        bytes calldata _data,
        uint256 _maxGasPrice
    ) external payable nonReentrant returns (bool success) {
        require(currentGasPrice <= _maxGasPrice, "Gas price too high");
        
        uint256 initialGas = gasleft();
        (success, ) = _target.call{gas: initialGas - 5000}(_data);
        
        uint256 gasUsed = initialGas - gasleft();
        trackContractGasUsage(_target, gasUsed);
        
        return success;
    }
}
