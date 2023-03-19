// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./LiquidityPool.sol";

contract LPStaking {
    LiquidityPool public lpContract;
    uint256 public totalRewards;
    uint256 public totalStaked;
    uint256 public rewardsPerToken;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public rewards;

    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);
    event RewardsClaimed(address indexed staker, uint256 amount);

    constructor(LiquidityPool _lpContract) {
        lpContract = _lpContract;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Must stake non-zero amount");
        require(lpContract.lpToken().allowance(msg.sender, address(this)) >= amount, "Must approve LP token first");
        require(lpContract.lpToken().transferFrom(msg.sender, address(this), amount), "Transfer failed");
        uint256 currentRewards = _updateRewards();
        balances[msg.sender] += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
        if (currentRewards > 0) {
            rewards[msg.sender] += (currentRewards * amount) / totalStaked;
        }
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Must withdraw non-zero amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        uint256 currentRewards = _updateRewards();
        balances[msg.sender] -= amount;
        totalStaked -= amount;
        require(lpContract.lpToken().transfer(msg.sender, amount), "Transfer failed");
        emit Withdrawn(msg.sender, amount);
        if (currentRewards > 0) {
            rewards[msg.sender] += (currentRewards * amount) / totalStaked;
        }
    }

    function claimRewards() external {
        uint256 currentRewards = _updateRewards();
        require(rewards[msg.sender] > 0, "No rewards to claim");
        uint256 amountToClaim = (rewards[msg.sender] * balances[msg.sender]) / totalStaked;
        rewards[msg.sender] -= amountToClaim;
        totalRewards -= amountToClaim;
        (bool success, ) = msg.sender.call{value: amountToClaim}("");
        require(success, "ETH transfer failed");
        emit RewardsClaimed(msg.sender, amountToClaim);
    }

    function _updateRewards() internal returns (uint256) {
        uint256 currentBalance = address(this).balance - totalRewards;
        uint256 currentRewardsPerToken = rewardsPerToken;
        if (totalStaked > 0) {
            currentRewardsPerToken += ((currentBalance * 1e18) / totalStaked);
            uint256 rewardsToAdd = (currentRewardsPerToken - rewardsPerToken) * totalStaked / 1e18;
            totalRewards += rewardsToAdd;
            rewardsPerToken = currentRewardsPerToken;
            return rewardsToAdd;
        } else {
            rewardsPerToken = currentRewardsPerToken;
            return 0;
        }
    }

    receive() external payable {
        _updateRewards();
    }
}
