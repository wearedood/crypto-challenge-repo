// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title YieldFarmingCalculator
 * @dev Advanced yield farming calculator for Base blockchain DeFi protocols
 * @author Crypto Challenge Repository
 */
contract YieldFarmingCalculator {
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    uint256 public constant BASIS_POINTS = 10000;

    struct PoolInfo {
        uint256 totalStaked;
        uint256 rewardPerSecond;
        uint256 depositFee;
        bool isActive;
    }

    PoolInfo[] public pools;

    event APYCalculated(uint256 indexed poolId, uint256 apy);

    function addPool(
        uint256 _rewardPerSecond,
        uint256 _depositFee
    ) external {
        pools.push(PoolInfo({
            totalStaked: 0,
            rewardPerSecond: _rewardPerSecond,
            depositFee: _depositFee,
            isActive: true
        }));
    }

    function calculateAPY(uint256 _poolId) external view returns (uint256) {
        require(_poolId < pools.length, "Invalid pool");
        PoolInfo memory pool = pools[_poolId];
        
        if (pool.totalStaked == 0) return 0;

        uint256 yearlyRewards = pool.rewardPerSecond * SECONDS_PER_YEAR;
        uint256 apy = (yearlyRewards * BASIS_POINTS) / pool.totalStaked;
        
        return apy;
    }

    function calculateCompoundReturns(
        uint256 _principal,
        uint256 _apy,
        uint256 _periods
    ) external pure returns (uint256) {
        require(_principal > 0, "Invalid principal");
        require(_periods > 0, "Invalid periods");

        uint256 amount = _principal;
        for (uint256 i = 0; i < _periods; i++) {
            uint256 interest = (amount * _apy) / BASIS_POINTS;
            amount = amount + interest;
        }

        return amount;
    }

    function getPoolCount() external view returns (uint256) {
        return pools.length;
    }
}
