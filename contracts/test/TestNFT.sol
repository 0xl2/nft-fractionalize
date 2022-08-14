// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestNFT is ERC721 {
    uint private _tokenid;

    constructor() ERC721("Test NFT", "TNFT") {}

    function mint() external returns(uint) {
        _tokenid++;

        _mint(msg.sender, _tokenid);

        return _tokenid;
    }
}