// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./NFTStore.sol";
import "./interface/IFToken.sol";

contract NFTFraction is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    NFTStore public immutable nftStore;

    bytes4 internal constant ERC721_RECEIVED = 0x150b7a02;

    event MintRequested(
        uint256 vaultId, 
        uint256[] nftIds, 
        address sender
    );
    event Mint(
        uint256 vaultId,
        uint256[] nftIds,
        address sender
    );
    event Redeem(
        uint256 vaultId,
        uint256[] nftIds,
        address sender
    );

    constructor(address _store) {
        nftStore = NFTStore(_store);
    }

    function onERC721Received(
        address, 
        address, 
        uint256, 
        bytes memory
    ) public pure returns(bytes4) {
        return ERC721_RECEIVED;
    }

    function _mint(
        uint256 vaultId, 
        uint256[] memory nftIds
    ) private {
        require(nftIds.length > 0, "Invalid");

        for (uint256 i = 0; i < nftIds.length; ++i) {
            uint256 nftId = nftIds[i];
            require(
                nftStore.nft(vaultId).ownerOf(nftId) != address(this),
                "Already owner"
            );

            nftStore.nft(vaultId).safeTransferFrom(
                msg.sender,
                address(this),
                nftId
            );
        }
        
        uint256 amount;
        unchecked {
            amount = nftIds.length * 10**18;
        }

        IFToken(nftStore.fToken(vaultId)).mint(msg.sender, amount);
    }

    function _redeem(
        uint256 vaultId,
        uint256[] memory nftIds
    ) private {
        for (uint256 i = 0; i < nftIds.length; ++i) {
            uint256 nftId = nftIds[i];

            require(
                nftStore.holdingsContains(vaultId, nftId),
                "NFT not in vault"
            );

            nftStore.nft(vaultId).safeTransferFrom(
                address(this),
                msg.sender,
                nftId
            );
        }
    }

    function requestMint(uint256 vaultId, uint256[] memory nftIds)
        external
        nonReentrant
    {
        for (uint256 i = 0; i < nftIds.length; ++i) {
            uint nftID = nftIds[i];
            require(
                nftStore.nft(vaultId).ownerOf(nftID) != address(this),
                "Already owner"
            );

            nftStore.nft(vaultId).safeTransferFrom(
                msg.sender,
                address(this),
                nftID
            );

            nftStore.setRequester(vaultId, nftID, msg.sender);
        }

        emit MintRequested(vaultId, nftIds, msg.sender);
    }

    function revokeMintRequests(uint256 vaultId, uint256[] memory nftIds)
        external
        nonReentrant
    {
        for (uint256 i = 0; i < nftIds.length; ++i) {
            require(
                nftStore.requester(vaultId, nftIds[i]) == msg.sender,
                "Not requester"
            );

            nftStore.setRequester(vaultId, nftIds[i], address(0));

            nftStore.nft(vaultId).safeTransferFrom(
                address(this),
                msg.sender,
                nftIds[i]
            );
        }
    }

    function approveMintRequest(uint256 vaultId, uint256[] memory nftIds) 
        external
        nonReentrant
    {
        for (uint256 i = 0; i < nftIds.length; ++i) {
            address requester = nftStore.requester(vaultId, nftIds[i]);
            require(requester != address(0), "No request");
            require(
                nftStore.nft(vaultId).ownerOf(nftIds[i]) == address(this),
                "Not owner"
            );

            nftStore.setRequester(vaultId, nftIds[i], address(0));

            IFToken(nftStore.fToken(vaultId)).mint(requester, 10**18);
        }
    }

    function mint(uint256 vaultId, uint256[] memory nftIds)
        external
        nonReentrant
    {
        _mint(vaultId, nftIds);
        emit Mint(vaultId, nftIds, msg.sender);
    }

    function redeem(uint256 vaultId, uint256[] memory nftIds)
        external
        nonReentrant 
    {
        _redeem(vaultId, nftIds);
        emit Redeem(vaultId, nftIds, msg.sender);
    }
}
