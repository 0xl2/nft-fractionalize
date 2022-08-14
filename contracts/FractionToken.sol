// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract FToken is Ownable, ERC20, ERC20Burnable {
    address public auctionContract;

    constructor(
        string memory name, 
        string memory symbol
    ) ERC20(name, symbol) {}

    function setAuction(address _auction) external onlyOwner {
        auctionContract = _auction;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function auctionMint(address to) external {
        require(msg.sender == auctionContract, "Not auction");

        _mint(to, totalSupply() / 100);
    }
}