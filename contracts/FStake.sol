// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FStake is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public rewardAmount;
    uint256 public lastRewardRate;
    uint256 public totalStakedAmount;

    mapping(address => uint) private userPending;
    mapping(address => uint) public rewardRate;
    mapping(address => uint) public stakedBalance;

    IERC20 public immutable fToken;

    event Stake(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event WithdrawReward(address indexed user, uint256 amount);

    /**
     * @notice Constructor. 
     * @param _fToken  address of FToken
     */
    constructor(
        IERC20 _fToken
    ) {
        require(address(_fToken) != address(0), "Zero address");
        fToken = _fToken;
    }
    
    /**
     * @notice View function to see pending Reward.
     * @param user  user address
     */
    function pendingReward(address user)
        public
        view
        returns (uint256 pendingAmount)
    {
        unchecked {
            pendingAmount = userPending[user] + (totalStakedAmount == 0 ? 0 :
                (stakedBalance[user] * (lastRewardRate - rewardRate[user])) / (totalStakedAmount * 1e4));
        }
    }

    /**
     * @notice Function for users to stake FToken.
     * @param amount  amount of FToken
     */
    function stake(uint amount) external nonReentrant {
        require(amount > 0, "Invalid amount");

        address msgSender = msg.sender;
        fToken.safeTransferFrom(msgSender, address(this), amount);

        userPending[msgSender] = pendingReward(msgSender);

        stakedBalance[msgSender] += amount;
        rewardRate[msgSender] = lastRewardRate;

        totalStakedAmount += amount;

        emit Stake(msgSender, amount);
    }

    function withdraw(uint amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        address msgSender = msg.sender;
        require(stakedBalance[msgSender] >= amount, "Bigger amount");

        userPending[msgSender] = pendingReward(msgSender);

        if(amount == stakedBalance[msgSender]) {
            delete stakedBalance[msgSender];
            delete rewardRate[msgSender];
        } else {
            unchecked {
                stakedBalance[msgSender] -= amount;
            }
        }

        unchecked {
            totalStakedAmount -= amount;
        }

        fToken.safeTransfer(msgSender, amount);

        emit Withdraw(msgSender, amount);
    }

    function withdrawReward() external nonReentrant {
        address msgSender = msg.sender;
        uint reward = pendingReward(msgSender);
        require(reward > 0, "No reward");

        rewardRate[msgSender] = lastRewardRate;

        payable(msgSender).transfer(reward);

        emit WithdrawReward(msgSender, reward);
    }

    receive() external payable {
        unchecked { lastRewardRate += msg.value * 1e4; }
    }
}
