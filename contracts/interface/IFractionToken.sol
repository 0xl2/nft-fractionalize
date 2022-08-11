// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IFractionToken {
    function setNoLongerFractionTokenTrue() external;

    function setAuctionContractAddress(address) external;

    function getNftAddress() external view returns(address);

    function getNftId() external view returns(uint256);

    function getNoLongerFractionToken() external view returns(bool);
}