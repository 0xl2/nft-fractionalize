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

    event MintRequested(
        uint256 vaultId, 
        uint256[] nftIds, 
        address sender
    );
    event Mint(
        uint256 vaultId,
        uint256[] nftIds,
        uint256 d2Amount,
        address sender
    );

    constructor(address storeAddress) {
        nftStore = NFTStore(storeAddress);
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
            require(
                nftStore.nft(vaultId).ownerOf(nftId) == address(this),
                "Not received"
            );
        }
        
        uint256 amount;
        unchecked {
            amount = nftIds.length * 10**18;
        }

        IFToken(nftStore.fToken(vaultId)).mint(msg.sender, amount);
    }

    function requestMint(uint256 vaultId, uint256[] memory nftIds)
        external
        payable
        nonReentrant
    {
        for (uint256 i = 0; i < nftIds.length; ++i) {
            require(
                nftStore.nft(vaultId).ownerOf(nftIds[i]) != address(this),
                "Already owner"
            );
            nftStore.nft(vaultId).safeTransferFrom(
                msg.sender,
                address(this),
                nftIds[i]
            );
            require(
                nftStore.nft(vaultId).ownerOf(nftIds[i]) == address(this),
                "Not received"
            );
            nftStore.setRequester(vaultId, nftIds[i], msg.sender);
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

    function mint(uint256 vaultId, uint256[] memory nftIds, uint256 d2Amount)
        external
        payable
        nonReentrant
    {
        _mint(vaultId, nftIds);
        emit Mint(vaultId, nftIds, d2Amount, msg.sender);
    }
}