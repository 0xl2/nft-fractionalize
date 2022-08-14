// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./FractionToken.sol";

contract NFTAuction is ReentrancyGuard {
    bool public started;
    bool public ended;

    uint public endAt;
    uint public auctionIndex;

    address public immutable devWallet;
    address public immutable stakeContract;
    
    // auctionIndex => Acution
    mapping(uint => Auction) public auctions;
    mapping(uint => mapping(address => uint)) public bids;

    struct Auction {
        address seller;
        address winner;
        uint256 highestBid;
    }

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
    ) external nonReentrant {
        require(!started, "started");

        started = true;
        ended = false;        
        endAt = block.timestamp + _period;
        
        auctionIndex++;
        auctions[auctionIndex].seller = msg.sender;
        auctions[auctionIndex].highestBid = _startingBid;

        emit Start(auctionIndex, _period);
    }

    function bid() external payable nonReentrant {
        require(started, "Not started");
        require(block.timestamp < endAt, "Ended");

        uint userAmount;
        unchecked { userAmount = bids[auctionIndex][msg.sender] + msg.value; }
        require(userAmount > auctions[auctionIndex].highestBid, "Amount is low");

        auctions[auctionIndex].highestBid = userAmount;
        auctions[auctionIndex].winner = msg.sender;

        bids[auctionIndex][msg.sender] = userAmount;

        emit Bid(msg.sender, bids[auctionIndex][msg.sender]);
    }

    function withdraw(uint auctionId) external nonReentrant {
        require(auctions[auctionIndex].winner != msg.sender, "Winner cant withdraw");
        require(bids[auctionId][msg.sender] > 0, "Nothing withdrawable");
        
        uint bal = bids[auctionId][msg.sender];
        delete bids[auctionId][msg.sender];

        payable(msg.sender).transfer(bal);

        emit Withdraw(msg.sender, bal);
    }

    function end() external nonReentrant {
        require(started, "Not started");
        // !!!!!!!!!!!!!!! this is only for the testing !!!!!!!!!!!!!!!
        // require(block.timestamp >= endAt, "Not ended");
        require(!ended, "Already ended");
        require(auctions[auctionIndex].seller == msg.sender, "Not seller");

        ended = true;
        address winner = auctions[auctionIndex].winner;
        uint highestBid = auctions[auctionIndex].highestBid;

        if (winner != address(0)) {
            // sent 5% to the dev wallet
            uint devAmount = highestBid * 500 / 1e4;
            payable(devWallet).transfer(devAmount);

            // others will be sent to stake contract
            (bool sent,) = stakeContract.call{ value: highestBid - devAmount } ("");
            require(sent, "Failed to send Ether");

            fToken.auctionMint(winner);
        }

        emit End(winner, highestBid);
    }

    receive() external payable {}
}
