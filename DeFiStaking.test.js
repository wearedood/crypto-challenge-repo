// SPDX-License-Identifier: MIT
// DeFiStaking Contract Test Suite
// Comprehensive testing for DeFi staking functionality

const { expect } = require('chai');
const { ethers } = require('hardhat');
const { time, loadFixture } = require('@nomicfoundation/hardhat-network-helpers');

describe('DeFiStaking Contract', function () {
    // Test fixtures for contract deployment
    async function deployDeFiStakingFixture() {
        const [owner, user1, user2, user3] = await ethers.getSigners();

        // Deploy mock ERC20 tokens for testing
        const MockERC20 = await ethers.getContractFactory('MockERC20');
        const stakingToken = await MockERC20.deploy('Staking Token', 'STK', ethers.parseEther('1000000'));
        const rewardToken = await MockERC20.deploy('Reward Token', 'RWD', ethers.parseEther('1000000'));

        // Deploy DeFiStaking contract
        const DeFiStaking = await ethers.getContractFactory('DeFiStaking');
        const defiStaking = await DeFiStaking.deploy();

        // Transfer tokens to users for testing
        await stakingToken.transfer(user1.address, ethers.parseEther('10000'));
        await stakingToken.transfer(user2.address, ethers.parseEther('10000'));
        await stakingToken.transfer(user3.address, ethers.parseEther('10000'));

        // Transfer reward tokens to contract owner
        await rewardToken.transfer(owner.address, ethers.parseEther('100000'));

        return {
            defiStaking,
            stakingToken,
            rewardToken,
            owner,
            user1,
            user2,
            user3
        };
    }

    describe('Deployment', function () {
        it('Should deploy successfully', async function () {
            const { defiStaking, owner } = await loadFixture(deployDeFiStakingFixture);
            expect(await defiStaking.owner()).to.equal(owner.address);
        });

        it('Should initialize with zero pools', async function () {
            const { defiStaking } = await loadFixture(deployDeFiStakingFixture);
            expect(await defiStaking.poolLength()).to.equal(0);
        });

        it('Should have emergency withdrawal disabled by default', async function () {
            const { defiStaking } = await loadFixture(deployDeFiStakingFixture);
            expect(await defiStaking.emergencyWithdrawEnabled()).to.equal(false);
        });
    });

    describe('Pool Management', function () {
        it('Should add a new pool successfully', async function () {
            const { defiStaking, stakingToken, rewardToken, owner } = await loadFixture(deployDeFiStakingFixture);
            
            await expect(defiStaking.addPool(
                stakingToken.address,
                rewardToken.address,
                ethers.parseEther('1'), // 1 token per second
                ethers.parseEther('100'), // min stake 100 tokens
                86400 // 1 day lock period
            )).to.emit(defiStaking, 'PoolAdded').withArgs(0, stakingToken.address, rewardToken.address);
            
            expect(await defiStaking.poolLength()).to.equal(1);
        });

        it('Should only allow owner to add pools', async function () {
            const { defiStaking, stakingToken, rewardToken, user1 } = await loadFixture(deployDeFiStakingFixture);
            
            await expect(defiStaking.connect(user1).addPool(
                stakingToken.address,
                rewardToken.address,
                ethers.parseEther('1'),
                ethers.parseEther('100'),
                86400
            )).to.be.revertedWith('Ownable: caller is not the owner');
        });
    });

    describe('Staking Functionality', function () {
        beforeEach(async function () {
            const { defiStaking, stakingToken, rewardToken } = await loadFixture(deployDeFiStakingFixture);
            // Add a test pool
            await defiStaking.addPool(
                stakingToken.address,
                rewardToken.address,
                ethers.parseEther('1'),
                ethers.parseEther('100'),
                0 // no lock period for basic tests
            );
        });

        it('Should allow users to stake tokens', async function () {
            const { defiStaking, stakingToken, user1 } = await loadFixture(deployDeFiStakingFixture);
            const stakeAmount = ethers.parseEther('1000');
            
            // Approve tokens
            await stakingToken.connect(user1).approve(defiStaking.address, stakeAmount);
            
            // Stake tokens
            await expect(defiStaking.connect(user1).stake(0, stakeAmount, 0))
                .to.emit(defiStaking, 'Staked')
                .withArgs(user1.address, 0, stakeAmount);
        });
    });
});
