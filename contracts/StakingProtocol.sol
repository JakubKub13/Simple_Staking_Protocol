// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./interfaces/IERC20.sol";

contract StakingRewards {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    address public owner;

    /* STATE VARIABLES NEEDED TO KEEP TRACK OF THE REWARDS */
    // Duration of reward
    uint public duration;
    // Time that the reward finishes
    uint public finishAt;
    // Last time this contract was updated
    uint public updatedAt;
    // Reward user earns per second
    uint public rewardRate;
    // Reward per token stored --> the sum of reward rate * duration divided by total supply
    uint public rewardPerTokenStored;
    // Reward per token stored per user
    mapping(address => uint) public userRewardPerTokenPaid;
    // Keep track of rewards that the user has earned
    mapping(address => uint) public rewards;

    /* STATE VARIABLES NEEDED TO KEEP TRACK OF THE TOTAL SUPPLY OF STAKING TOKEN AND AMOUNT STAKED PER USER */
    uint public totalSupply;
    mapping(address => uint) public balanceOf;

    constructor(address _stakingToken, address _rewardsToken) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not an Owner");
        _;
    }

// Modifier is called when user stakes and withdraws we will be able to track rewardPerToken() and userRewardPerTokenPaid
     modifier updateReward(address _account) {
         rewardPerTokenStored = rewardPerToken();
         updatedAt = lastTimeRewardApplicable();

         if (_account != address(0)) {
             rewards[_account] = earned(_account);
             userRewardPerTokenPaid[_account] = rewardPerTokenStored;
         }
         _;
    }

    function setRewardsDuration(uint _duration) external onlyOwner {
        require(finishAt < block.timestamp, "Reward duration not finished");
        duration = _duration;
    }

// Owner can call to send reward tokens into this contract and set the reward rate 
    function modifyRewardAmount(uint _amount) external onlyOwner updateReward(address(0)) {
        if (block.timestamp > finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = rewardRate * (finishAt - block.timestamp);
            rewardRate = (remainingRewards + _amount) / duration;
        }

        require(rewardRate > 0, "Reward rate = 0");
        require(rewardRate * duration <= rewardsToken.balanceOf(address(this)), "Reward amount > balance");

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

// Users can call this function to stake their tokens
    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "Amount = 0");
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;  // keeps track of amount of tokens staked by msg.sender
        totalSupply += _amount; // keeps track of total amount of tokens staked inside this contract
    }

// Users can call this function and will be able to withdraw staked tokens
    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "Amount = 0");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(block.timestamp, finishAt);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * 
            (lastTimeRewardApplicable() - updatedAt) * 1e18
        ) / totalSupply;
    }

// This function will calculate the amount of rewards earned by account       
    function earned(address _account) public view returns (uint) {
        return (balanceOf[_account] * 
            (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18
         + rewards[_account];
    }

// User will be able to call this function to get the reward token 
    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}