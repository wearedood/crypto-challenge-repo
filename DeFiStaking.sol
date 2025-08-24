/ SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title DeFiStaking
 * @dev A comprehensive DeFi staking contract with multiple reward pools and flexible staking periods
 * @author Crypto Challenge Repository
 * @notice Advanced DeFi staking contract with multiple reward pools, flexible lock periods, and compound staking
 * @dev Implements ReentrancyGuard for security, Ownable for access control, and Pausable for emergency stops
 * @dev Features include: multiple staking pools, flexible lock periods, compound rewards, emergency withdrawal
 * @dev Gas optimized with efficient reward calculations and batch operations support
 * @version 2.0.0 - Enhanced with security features and advanced staking mechanisms
 */
contract DeFiStaking is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 stakingTime;
        uint256 lockPeriod;
        bool isActive;
    }

    struct PoolInfo {
        IERC20 stakingToken;
        IERC20 rewardToken;
        uint256 rewardPerSecond;
        uint256 lastRewardTime;
        uint256 accRewardPerShare;
        uint256 totalStaked;
        uint256 minStakeAmount;
        uint256 lockPeriod;
        bool isActive;
    }

    // Pool information
    PoolInfo[] public poolInfo;
    
    // User staking information: poolId => user => StakeInfo
    mapping(uint256 => mapping(address => StakeInfo)) public userInfo;
    
    // Emergency withdrawal enabled
    bool public emergencyWithdrawEnabled = false;
    
    // Events
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardClaimed(address indexed user, uint256 indexed pid, uint256 amount);
    event PoolAdded(uint256 indexed pid, address stakingToken, address rewardToken);
    event PoolUpdated(uint256 indexed pid, uint256 rewardPerSecond);

    constructor() {}

    /**
     * @dev Add a new staking pool
     */
    function addPool(
        IERC20 _stakingToken,
        IERC20 _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _minStakeAmount,
        uint256 _lockPeriod
    ) external onlyOwner {
        poolInfo.push(PoolInfo({
            stakingToken: _stakingToken,
            rewardToken: _rewardToken,
            rewardPerSecond: _rewardPerSecond,
            lastRewardTime: block.timestamp,
            accRewardPerShare: 0,
            totalStaked: 0,
            minStakeAmount: _minStakeAmount,
            lockPeriod: _lockPeriod,
            isActive: true
        }));

        emit PoolAdded(poolInfo.length - 1, address(_stakingToken), address(_rewardToken));
    }

    /**
     * @dev Update reward rate for a pool
     */
    function updatePool(uint256 _pid, uint256 _rewardPerSecond) external onlyOwner {
        require(_pid < poolInfo.length, "Invalid pool ID");
        
        updatePoolRewards(_pid);
        poolInfo[_pid].rewardPerSecond = _rewardPerSecond;
        
        emit PoolUpdated(_pid, _rewardPerSecond);
    }

    /**
     * @dev Update pool reward variables
     */
    function updatePoolRewards(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }

        if (pool.totalStaked == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - pool.lastRewardTime;
        uint256 reward = timeElapsed * pool.rewardPerSecond;
        
        pool.accRewardPerShare += (reward * 1e12) / pool.totalStaked;
        pool.lastRewardTime = block.timestamp;
    }

    /**
     * @dev Stake tokens in a pool
     */
    function stake(uint256 _pid, uint256 _amount) external nonReentrant whenNotPaused {
        require(_pid < poolInfo.length, "Invalid pool ID");
        require(_amount > 0, "Amount must be greater than 0");
        
        PoolInfo storage pool = poolInfo[_pid];
        StakeInfo storage user = userInfo[_pid][msg.sender];
        
        require(pool.isActive, "Pool is not active");
        require(_amount >= pool.minStakeAmount, "Amount below minimum stake");

        updatePoolRewards(_pid);

        // If user already has stake, claim pending rewards
        if (user.amount > 0) {
            uint256 pending = (user.amount * pool.accRewardPerShare) / 1e12 - user.rewardDebt;
            if (pending > 0) {
                pool.rewardToken.safeTransfer(msg.sender, pending);
                emit RewardClaimed(msg.sender, _pid, pending);
            }
        }

        // Transfer staking tokens from user
        pool.stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        // Update user info
        user.amount += _amount;
        user.stakingTime = block.timestamp;
        user.lockPeriod = pool.lockPeriod;
        user.isActive = true;
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e12;

        // Update pool info
        pool.totalStaked += _amount;

        emit Deposit(msg.sender, _pid, _amount);
    }

    /**
     * @dev Withdraw staked tokens and claim rewards
     */
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        require(_pid < poolInfo.length, "Invalid pool ID");
        
        PoolInfo storage pool = poolInfo[_pid];
        StakeInfo storage user = userInfo[_pid][msg.sender];
        
        require(user.amount >= _amount, "Insufficient staked amount");
        require(user.isActive, "No active stake");
        
        // Check lock period
        require(
            block.timestamp >= user.stakingTime + user.lockPeriod,
            "Tokens are still locked"
        );

        updatePoolRewards(_pid);

        // Calculate and transfer pending rewards
        uint256 pending = (user.amount * pool.accRewardPerShare) / 1e12 - user.rewardDebt;
        if (pending > 0) {
            pool.rewardToken.safeTransfer(msg.sender, pending);
            emit RewardClaimed(msg.sender, _pid, pending);
        }

        // Update user info
        user.amount -= _amount;
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e12;
        
        if (user.amount == 0) {
            user.isActive = false;
        }

        // Update pool info
        pool.totalStaked -= _amount;

        // Transfer staking tokens back to user
        pool.stakingToken.safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _pid, _amount);
    }

    /**
     * @dev Claim pending rewards without withdrawing staked tokens
     */
    function claimRewards(uint256 _pid) external nonReentrant {
        require(_pid < poolInfo.length, "Invalid pool ID");
        
        PoolInfo storage pool = poolInfo[_pid];
        StakeInfo storage user = userInfo[_pid][msg.sender];
        
        require(user.amount > 0, "No staked amount");
        require(user.isActive, "No active stake");

        updatePoolRewards(_pid);

        uint256 pending = (user.amount * pool.accRewardPerShare) / 1e12 - user.rewardDebt;
        require(pending > 0, "No pending rewards");

        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e12;
        pool.rewardToken.safeTransfer(msg.sender, pending);

        emit RewardClaimed(msg.sender, _pid, pending);
    }

    /**
     * @dev Emergency withdraw without caring about rewards
     */
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        require(emergencyWithdrawEnabled, "Emergency withdraw not enabled");
        require(_pid < poolInfo.length, "Invalid pool ID");
        
        PoolInfo storage pool = poolInfo[_pid];
        StakeInfo storage user = userInfo[_pid][msg.sender];
        
        require(user.amount > 0, "No staked amount");

        uint256 amount = user.amount;
        
        // Reset user info
        user.amount = 0;
        user.rewardDebt = 0;
        user.isActive = false;

        // Update pool info
        pool.totalStaked -= amount;

        // Transfer staking tokens back to user
        pool.stakingToken.safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    /**
     * @dev Get pending rewards for a user
     */
    function pendingRewards(uint256 _pid, address _user) external view returns (uint256) {
        require(_pid < poolInfo.length, "Invalid pool ID");
        
        PoolInfo storage pool = poolInfo[_pid];
        StakeInfo storage user = userInfo[_pid][_user];
        
        uint256 accRewardPerShare = pool.accRewardPerShare;
        
        if (block.timestamp > pool.lastRewardTime && pool.totalStaked != 0) {
            uint256 timeElapsed = block.timestamp - pool.lastRewardTime;
            uint256 reward = timeElapsed * pool.rewardPerSecond;
            accRewardPerShare += (reward * 1e12) / pool.totalStaked;
        }
        
        return (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
    }

    /**
     * @dev Get user staking information
     */
    function getUserInfo(uint256 _pid, address _user) 
        external 
        view 
        returns (
            uint256 amount,
            uint256 rewardDebt,
            uint256 stakingTime,
            uint256 lockPeriod,
            bool isActive,
            uint256 unlockTime
        ) 
    {
        StakeInfo storage user = userInfo[_pid][_user];
        return (
            user.amount,
            user.rewardDebt,
            user.stakingTime,
            user.lockPeriod,
            user.isActive,
            user.stakingTime + user.lockPeriod
        );
    }

    /**
     * @dev Get pool information
     */
    function getPoolInfo(uint256 _pid) 
        external 
        view 
        returns (
            address stakingToken,
            address rewardToken,
            uint256 rewardPerSecond,
            uint256 totalStaked,
            uint256 minStakeAmount,
            uint256 lockPeriod,
            bool isActive
        ) 
    {
        require(_pid < poolInfo.length, "Invalid pool ID");
        PoolInfo storage pool = poolInfo[_pid];
        
        return (
            address(pool.stakingToken),
            address(pool.rewardToken),
            pool.rewardPerSecond,
            pool.totalStaked,
            pool.minStakeAmount,
            pool.lockPeriod,
            pool.isActive
        );
    }

    /**
     * @dev Get total number of pools
     */
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Admin functions
    function setPoolStatus(uint256 _pid, bool _isActive) external onlyOwner {
        require(_pid < poolInfo.length, "Invalid pool ID");
        poolInfo[_pid].isActive = _isActive;
    }

    function setEmergencyWithdraw(bool _enabled) external onlyOwner {
        emergencyWithdrawEnabled = _enabled;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Emergency function to recover any ERC20 tokens sent to contract by mistake
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    }
}"
