// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestNFT is ERC721 {
    uint private _tokenid;

    constructor() ERC721("Test NFT", "TNFT") {}

    function mint() external returns(uint tokenId) {
        tokenId = _tokenid + 1;

        _mint(msg.sender, tokenId);
    }
}