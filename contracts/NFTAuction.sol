// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./FractionToken.sol";

contract NFTAuction is ReentrancyGuard {
    bool public started;
    bool public ended;

    uint public endAt;
    uint public highestBid;

    uint public auctionIndex;

    address public seller;
    address public highestBidder;

    address public immutable devWallet;
    address public immutable stakeContract;
    
    mapping(uint => address) public Winners;
    mapping(uint => mapping(address => uint)) public bids;

    FToken public immutable fToken;

    event Start(uint auctionId, uint period);
    event Bid(address indexed sender, uint amount);
    event Withdraw(address indexed bidder, uint amount);
    event End(address winner, uint amount);

    constructor(
        address _fToken,
        address _dev, 
        address _stake
    ) {
        devWallet = _dev;
        stakeContract = _stake;

        fToken = FToken(_fToken);
    }

    function start(
        uint _startingBid,
        uint _period
    ) external {
        require(!started, "started");
        
        highestBid = _startingBid;
        seller = msg.sender;

        auctionIndex++;
        started = true;
        ended = false;
        endAt = block.timestamp + _period;

        highestBidder = address(0);

        emit Start(auctionIndex, _period);
    }

    function bid() external payable nonReentrant {
        require(started, "Not started");
        require(block.timestamp < endAt, "Ended");

        uint userAmount;
        unchecked {
            userAmount = bids[auctionIndex][msg.sender] + msg.value;
        }
        require(userAmount > highestBid, "Amount is low");

        highestBid = userAmount;
        highestBidder = msg.sender;
        bids[auctionIndex][msg.sender] = userAmount;

        emit Bid(msg.sender, bids[auctionIndex][msg.sender]);
    }

    function withdraw(uint auctionId) external nonReentrant {
        require(Winners[auctionId] != msg.sender, "Winner cant withdraw");
        require(bids[auctionId][msg.sender] > 0, "Not bidder");
        
        uint bal = bids[auctionId][msg.sender];
        delete bids[auctionId][msg.sender];

        payable(msg.sender).transfer(bal);

        emit Withdraw(msg.sender, bal);
    }

    function end() external {
        require(started, "Not started");
        require(block.timestamp >= endAt, "Not ended");
        require(!ended, "Already ended");
        require(seller == msg.sender, "Not seller");

        ended = true;
        if (highestBidder != address(0)) {
            // sent 5% to the dev wallet
            uint devAmount = highestBid * 500 / 1e4;
            payable(devWallet).transfer(devAmount);

            payable(stakeContract).transfer(highestBid - devAmount);

            fToken.auctionMint(highestBidder);
            Winners[auctionIndex] = highestBidder;
        }

        emit End(highestBidder, highestBid);
    }

    receive() external payable {}
}
