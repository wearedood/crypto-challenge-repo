# DeFi Staking Contract Tutorial

## 🚀 Complete Guide to Using the DeFiStaking Contract

### Overview
The DeFiStaking contract is an advanced DeFi protocol that enables users to stake ERC20 tokens and earn rewards. This tutorial provides step-by-step instructions for developers and users.

## 📋 Prerequisites

- Node.js (v16 or higher)
- Hardhat development environment
- MetaMask or compatible Web3 wallet
- Basic understanding of Solidity and DeFi concepts

## 🛠️ Setup Instructions

### 1. Install Dependencies
```bash
npm install @openzeppelin/contracts
npm install @nomicfoundation/hardhat-toolbox
npm install hardhat
```

### 2. Deploy the Contract
```javascript
const DeFiStaking = await ethers.getContractFactory('DeFiStaking');
const defiStaking = await DeFiStaking.deploy();
await defiStaking.deployed();
console.log('DeFiStaking deployed to:', defiStaking.address);
```

## 💰 Basic Usage Examples

### Adding a Staking Pool (Owner Only)
```javascript
// Add a new staking pool
await defiStaking.addPool(
    stakingTokenAddress,    // ERC20 token to stake
    rewardTokenAddress,     // ERC20 token for rewards
    ethers.parseEther('1'), // 1 token per second reward rate
    ethers.parseEther('100'), // minimum stake: 100 tokens
    86400                   // lock period: 1 day (in seconds)
);
```

### Staking Tokens
```javascript
// 1. Approve tokens for staking
const stakeAmount = ethers.parseEther('1000');
await stakingToken.approve(defiStaking.address, stakeAmount);

// 2. Stake tokens in pool 0 with no additional lock
await defiStaking.stake(0, stakeAmount, 0);
```

### Claiming Rewards
```javascript
// Claim pending rewards from pool 0
await defiStaking.claimRewards(0);
```

### Unstaking Tokens
```javascript
// Unstake 500 tokens from pool 0
const unstakeAmount = ethers.parseEther('500');
await defiStaking.unstake(0, unstakeAmount);
```

## 🔒 Advanced Features

### Compound Staking
```javascript
// Enable compound staking (auto-reinvest rewards)
await defiStaking.setCompoundStaking(0, true);
```

### Emergency Withdrawal
```javascript
// Emergency unstake (may forfeit rewards)
await defiStaking.emergencyUnstake(0);
```

## 📊 Querying Contract State

### Check Pool Information
```javascript
const poolInfo = await defiStaking.poolInfo(0);
console.log('Staking Token:', poolInfo.stakingToken);
console.log('Reward Token:', poolInfo.rewardToken);
console.log('Reward Per Second:', poolInfo.rewardPerSecond.toString());
```

### Check User Stake
```javascript
const userStake = await defiStaking.userInfo(0, userAddress);
console.log('Staked Amount:', userStake.amount.toString());
console.log('Staking Time:', new Date(userStake.stakingTime * 1000));
```

### Calculate Pending Rewards
```javascript
const pendingRewards = await defiStaking.pendingRewards(0, userAddress);
console.log('Pending Rewards:', ethers.formatEther(pendingRewards));
```

## ⚠️ Security Best Practices

1. **Always approve exact amounts** - Don't approve unlimited tokens
2. **Verify pool parameters** - Check reward rates and lock periods
3. **Monitor gas costs** - Use appropriate gas limits
4. **Test on testnets first** - Never deploy directly to mainnet
5. **Keep private keys secure** - Use hardware wallets for large amounts

## 🐛 Common Issues & Solutions

### Issue: Transaction Reverts with 'Insufficient Balance'
**Solution:** Ensure you have enough tokens and have approved the contract

### Issue: 'Pool does not exist'
**Solution:** Verify the pool ID exists using `poolLength()`

### Issue: 'Tokens still locked'
**Solution:** Wait for the lock period to expire or use emergency withdrawal

## 📈 Integration Examples

### Frontend Integration (React)
```javascript
import { ethers } from 'ethers';

const StakingComponent = () => {
  const [contract, setContract] = useState(null);
  
  const connectContract = async () => {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    const signer = provider.getSigner();
    const stakingContract = new ethers.Contract(
      CONTRACT_ADDRESS,
      CONTRACT_ABI,
      signer
    );
    setContract(stakingContract);
  };
  
  const stakeTokens = async (poolId, amount) => {
    try {
      const tx = await contract.stake(poolId, ethers.parseEther(amount), 0);
      await tx.wait();
      console.log('Staking successful!');
    } catch (error) {
      console.error('Staking failed:', error);
    }
  };
  
  return (
    <div>
      <button onClick={connectContract}>Connect Wallet</button>
      <button onClick={() => stakeTokens(0, '100')}>Stake 100 Tokens</button>
    </div>
  );
};
```

## 🎯 Next Steps

1. **Deploy to testnet** - Test all functionality
2. **Add monitoring** - Track pool performance
3. **Implement governance** - Add voting mechanisms
4. **Optimize gas** - Batch operations where possible
5. **Add analytics** - Track user behavior and rewards

## 📚 Additional Resources

- [OpenZeppelin Documentation](https://docs.openzeppelin.com/)
- [Hardhat Documentation](https://hardhat.org/docs)
- [Ethereum Development Guide](https://ethereum.org/en/developers/)
- [DeFi Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)

---

**⚡ Pro Tip:** Always test your integration thoroughly on testnets before deploying to mainnet. The DeFi space moves fast, but security should never be compromised!
